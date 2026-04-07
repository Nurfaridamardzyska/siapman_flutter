import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../services/attendance_rules.dart';
import '../services/attendance_service.dart';
import '../services/face_detection_service.dart';

class CameraPresensiPage extends StatefulWidget {
  const CameraPresensiPage({super.key});

  @override
  State<CameraPresensiPage> createState() => _CameraPresensiPageState();
}

class _CameraPresensiPageState extends State<CameraPresensiPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  final FaceDetectionService _faceDetectionService = FaceDetectionService();

  bool _isInitialized = false;
  bool _isDetecting = false;
  bool _isProcessingAttendance = false;
  bool _attendanceSent = false;
  bool _isPageClosing = false;

  int _stableFrameCount = 0;
  static const int _requiredStableFrames = 10;

  Size? _previewSize;
  AttendanceMode _attendanceMode = AttendanceMode.outsideHours;
  String _statusText = 'Menyiapkan kamera...';

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _refreshAttendanceMode();
    _initCamera();
  }

  void _refreshAttendanceMode() {
    _attendanceMode = AttendanceRules.getAttendanceMode(DateTime.now());

    if (_attendanceMode == AttendanceMode.outsideHours) {
      _statusText = 'Saat ini di luar jam absensi';
    } else {
      _statusText = 'Mohon arahkan wajah ke lingkaran';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _cameraController?.dispose();
    unawaited(_faceDetectionService.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isPageClosing) {
      return;
    }

    final controller = _cameraController;
    if (controller == null) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller.dispose();
      _cameraController = null;
      _isInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    if (_isPageClosing) {
      return;
    }

    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await controller.initialize();

      if (!mounted || _isPageClosing) {
        await controller.dispose();
        return;
      }

      _previewSize = controller.value.previewSize;
      _cameraController = controller;

      await controller.startImageStream(_processCameraImage);

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = 'Gagal membuka kamera: $e';
        _isInitialized = false;
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final controller = _cameraController;

    if (_isDetecting ||
        _isProcessingAttendance ||
        _attendanceSent ||
        _isPageClosing ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    _isDetecting = true;

    try {
      _refreshAttendanceMode();

      final result = await _faceDetectionService.processCameraImage(
        image,
        _inputRotation(controller.description.sensorOrientation),
      );

      if (!mounted || _isPageClosing) {
        return;
      }

      if (result.faces.isEmpty) {
        _stableFrameCount = 0;
        setState(() {
          _statusText = _attendanceMode == AttendanceMode.outsideHours
              ? 'Saat ini di luar jam absensi'
              : 'Mohon arahkan wajah ke lingkaran';
        });
        return;
      }

      if (!result.isSingleFace) {
        _stableFrameCount = 0;
        setState(() {
          _statusText = 'Pastikan hanya satu wajah';
        });
        return;
      }

      final rect = _mapFaceRectToScreen(result.faces.first.boundingBox);

      if (!_isFaceInsideGuide(rect)) {
        _stableFrameCount = 0;
        setState(() {
          _statusText = 'Posisikan wajah di tengah lingkaran';
        });
        return;
      }

      if (!_isFaceSizeValid(rect)) {
        _stableFrameCount = 0;
        setState(() {
          _statusText = 'Dekatkan wajah ke kamera';
        });
        return;
      }

      if (_attendanceMode == AttendanceMode.outsideHours) {
        _stableFrameCount = 0;
        setState(() {
          _statusText = 'Saat ini di luar jam absensi';
        });
        return;
      }

      _stableFrameCount += 1;

      if (_stableFrameCount < _requiredStableFrames) {
        setState(() {
          _statusText = 'Tahan posisi wajah sebentar...';
        });
        return;
      }

      _stableFrameCount = 0;
      await _captureAndSubmit();
    } catch (_) {
      if (!mounted || _isPageClosing) {
        return;
      }

      setState(() {
        _statusText = 'Kesalahan deteksi wajah';
      });
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _captureAndSubmit() async {
    final controller = _cameraController;

    if (_isProcessingAttendance ||
        _attendanceSent ||
        _isPageClosing ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    _isProcessingAttendance = true;

    try {
      if (mounted) {
        setState(() {
          _statusText = 'Memverifikasi absensi...';
        });
      }

      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }

      final file = await controller.takePicture();

      final response = await AttendanceService.submitAttendance(
        mode: AttendanceRules.getModeValue(_attendanceMode),
        imageFile: File(file.path),
      );

      if (!mounted || _isPageClosing) {
        return;
      }

      if (response.success) {
        setState(() {
          _attendanceSent = true;
          _statusText = response.message;
        });

        await Future.delayed(const Duration(seconds: 2));

        if (!mounted || _isPageClosing) {
          return;
        }

        _isPageClosing = true;
        await controller.dispose();
        _cameraController = null;
        _isInitialized = false;

        if (!mounted) {
          return;
        }

        Navigator.pop(context, {
          'success': true,
          'message': response.message,
        });
      } else {
        setState(() {
          _statusText = response.message;
        });

        await Future.delayed(const Duration(seconds: 1));

        final currentController = _cameraController;
        if (!mounted ||
            _isPageClosing ||
            currentController == null ||
            !currentController.value.isInitialized) {
          return;
        }

        if (!currentController.value.isStreamingImages) {
          await currentController.startImageStream(_processCameraImage);
        }
      }
    } catch (_) {
      if (!mounted || _isPageClosing) {
        return;
      }

      setState(() {
        _statusText = 'Gagal memproses absensi';
      });

      final currentController = _cameraController;
      if (currentController != null &&
          currentController.value.isInitialized &&
          !currentController.value.isStreamingImages) {
        await currentController.startImageStream(_processCameraImage);
      }
    } finally {
      _isProcessingAttendance = false;
    }
  }

  InputImageRotation _inputRotation(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Rect _mapFaceRectToScreen(Rect faceRect) {
    if (_previewSize == null) {
      return faceRect;
    }

    final circleSize = MediaQuery.of(context).size.width * 0.74;

    final imageWidth = _previewSize!.height;
    final imageHeight = _previewSize!.width;

    final scaleX = circleSize / imageWidth;
    final scaleY = circleSize / imageHeight;

    return Rect.fromLTRB(
      faceRect.left * scaleX,
      faceRect.top * scaleY,
      faceRect.right * scaleX,
      faceRect.bottom * scaleY,
    );
  }

  bool _isFaceInsideGuide(Rect faceRect) {
    final circleSize = MediaQuery.of(context).size.width * 0.74;
    final circleCenter = Offset(circleSize / 2, circleSize / 2);
    final circleRadius = circleSize / 2;

    final faceCenter = faceRect.center;
    final distance = (faceCenter - circleCenter).distance;

    return distance < circleRadius * 0.48;
  }

  bool _isFaceSizeValid(Rect faceRect) {
    final circleSize = MediaQuery.of(context).size.width * 0.74;

    return faceRect.width >= circleSize * 0.22 &&
        faceRect.height >= circleSize * 0.22;
  }

  String _modeTitle() {
    switch (_attendanceMode) {
      case AttendanceMode.checkIn:
        return 'Absensi Masuk';
      case AttendanceMode.checkOut:
        return 'Absensi Pulang';
      case AttendanceMode.outsideHours:
        return 'Di Luar Jam';
    }
  }

  double _progressValue() {
    if (_attendanceSent) {
      return 1.0;
    }
    if (_isProcessingAttendance) {
      return 0.92;
    }
    if (_attendanceMode == AttendanceMode.outsideHours) {
      return 0.15;
    }
    if (_statusText.contains('Tahan posisi')) {
      return (_stableFrameCount / _requiredStableFrames).clamp(0.0, 1.0);
    }
    if (_statusText.contains('arahkan') ||
        _statusText.contains('tengah')) {
      return 0.25;
    }
    if (_statusText.contains('Dekatkan')) {
      return 0.35;
    }
    if (_statusText.contains('hanya satu wajah')) {
      return 0.2;
    }
    return 0.18;
  }

  Color _guideColor() {
    if (_attendanceSent) {
      return const Color(0xFF22C55E);
    }
    if (_isProcessingAttendance) {
      return const Color(0xFFD8B4FE);
    }
    if (_attendanceMode == AttendanceMode.outsideHours) {
      return Colors.grey.shade300;
    }
    return const Color(0xFFD8B4FE);
  }

  Color _statusTextColor() {
    if (_attendanceSent) {
      return const Color(0xFF16A34A);
    }
    if (_attendanceMode == AttendanceMode.outsideHours) {
      return const Color(0xFFF59E0B);
    }
    if (_isProcessingAttendance) {
      return const Color(0xFF7C3AED);
    }
    return Colors.black87;
  }

  IconData _statusIcon() {
    if (_attendanceSent) {
      return Icons.check_circle;
    }
    if (_attendanceMode == AttendanceMode.outsideHours) {
      return Icons.access_time_filled;
    }
    if (_isProcessingAttendance) {
      return Icons.verified;
    }
    return Icons.face_retouching_natural;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Lapor Kehadiran',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      body: !_isInitialized || controller == null || !controller.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _statusText,
                        key: ValueKey(_statusText),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _statusTextColor(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                      ),
                      child: Text(_modeTitle()),
                    ),
                    const SizedBox(height: 22),
                    _buildCameraCircle(controller),
                    const SizedBox(height: 28),
                    _buildBottomStatus(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCameraCircle(CameraController controller) {
    final circleSize = MediaQuery.of(context).size.width * 0.74;
    final previewSize = controller.value.previewSize;

    if (previewSize == null) {
      return SizedBox(
        width: circleSize,
        height: circleSize,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      width: circleSize,
      height: circleSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: SizedBox(
              width: circleSize,
              height: circleSize,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: previewSize.height,
                  height: previewSize.width,
                  child: CameraPreview(controller),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) {
              final pulse = _attendanceMode == AttendanceMode.outsideHours
                  ? 1.0
                  : 1.0 + (_pulseController.value * 0.015);

              return Transform.scale(
                scale: pulse,
                child: CustomPaint(
                  size: Size(circleSize, circleSize),
                  painter: _ProgressArcPainter(
                    color: _guideColor(),
                    progress: _progressValue(),
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStatus() {
    final bgColor = _attendanceSent
        ? const Color(0xFFECFDF5)
        : _attendanceMode == AttendanceMode.outsideHours
            ? const Color(0xFFFFF7ED)
            : _isProcessingAttendance
                ? const Color(0xFFF5F3FF)
                : const Color(0xFFF9FAFB);

    final iconColor = _attendanceSent
        ? const Color(0xFF16A34A)
        : _attendanceMode == AttendanceMode.outsideHours
            ? const Color(0xFFF59E0B)
            : _isProcessingAttendance
                ? const Color(0xFF7C3AED)
                : const Color(0xFF374151);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(), color: iconColor),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              _statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressArcPainter extends CustomPainter {
  final Color color;
  final Color backgroundColor;
  final double progress;

  _ProgressArcPainter({
    required this.color,
    required this.backgroundColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 14.0;
    final radius = (size.width < size.height ? size.width : size.height) / 2 -
        strokeWidth / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = -1.5708 + 0.12;
    const totalSweep = 3.14159 * 1.76;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      backgroundPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep * progress,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressArcPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}