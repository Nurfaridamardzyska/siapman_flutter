import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/attendance_rules.dart';
import '../services/attendance_service.dart';
import '../services/face_detection_service.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:screen_brightness/screen_brightness.dart';

class CameraPresensiPage extends StatefulWidget {
  final bool isBypass;

  const CameraPresensiPage({super.key, this.isBypass = false});

  @override
  State<CameraPresensiPage> createState() => _CameraPresensiPageState();
}

class _CameraPresensiPageState extends State<CameraPresensiPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _cameraController;

  bool _isInitialized = false;
  bool _isProcessingAttendance = false;
  bool _isUploadingFrame = false;
  bool _isPreparingCamera = false;
  bool _attendanceSent = false;
  bool _isPageClosing = false;

  bool _isFlashOn = false;
  String _backendStatus = 'Idle';
  double _backendElapsed = 0.0;
  double _backendRequired = 10.0;
  int _currentStep = 0;
  String? _activeSessionId;
  String? _activeLivenessToken;
  Position? _preFetchedPosition;

  final FaceDetectionService _faceDetectionService = FaceDetectionService();
  bool _isProcessingFrame = false;
  bool _eyesWereClosed = false;
  bool _headWasTurned = false;
  double _stableTime = 0.0;
  DateTime? _lastFrameTime;

  AttendanceMode _attendanceMode = AttendanceMode.outsideHours;
  String _statusText = 'Menunggu instruksi...';
  bool _showInstructions = true;

  late final AnimationController _pulseController;

  bool get _effectiveBypass => widget.isBypass && !kReleaseMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    unawaited(AttendanceRules.syncSchedulesFromApi(force: true));
    _refreshAttendanceMode();
    _preFetchLocation();
  }

  Future<void> _preFetchLocation() async {
    if (_effectiveBypass) return;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        _preFetchedPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 5),
        ).catchError((_) => null);
      }
    } catch (_) {}
  }

  Future<void> _initCamera() async {
    if (_cameraController?.value.isInitialized == true) {
      _isPreparingCamera = false;
      return;
    }

    _isPreparingCamera = true;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('Kamera tidak tersedia pada perangkat ini.');
      }

      final camera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      // Matikan flash agar tidak menyala otomatis saat scan wajah
      await controller.setFlashMode(FlashMode.off);
      _isFlashOn = false;
      if (!mounted || _isPageClosing) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      setState(() {
        _isInitialized = true;
        _isPreparingCamera = false;
      });
    } catch (e) {
      if (!mounted || _isPageClosing) {
        return;
      }
      setState(() {
        _statusText = 'Gagal mengakses kamera HP: $e';
        _isInitialized = false;
        _isPreparingCamera = false;
      });
      rethrow;
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      if (_isFlashOn) {
        try { await _cameraController!.setFlashMode(FlashMode.off); } catch (_) {}
        try { await ScreenBrightness().resetScreenBrightness(); } catch (_) {}
        setState(() => _isFlashOn = false);
      } else {
        try { await _cameraController!.setFlashMode(FlashMode.torch); } catch (_) {}
        try { await ScreenBrightness().setScreenBrightness(1.0); } catch (_) {}
        setState(() => _isFlashOn = true);
      }
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  Future<void> _startVerification() async {
    setState(() {
      _showInstructions = false;
      _statusText = 'Menyiapkan kamera HP...';
      _activeSessionId = 'local_session';
      _activeLivenessToken = 'local_token';
      _currentStep = 0;
      _backendStatus = 'Stabilisasi';
      _backendElapsed = 0.0;
      _backendRequired = 10.0;
      _eyesWereClosed = false;
      _headWasTurned = false;
      _stableTime = 0.0;
      _lastFrameTime = DateTime.now();
    });

    try {
      await _initCamera();

      if (!mounted || _isPageClosing) return;

      setState(() {
        _statusText = 'Arahkan wajah ke kamera';
      });

      _startImageStream();
    } catch (e) {
      if (!mounted || _isPageClosing) return;
      setState(() {
        _statusText = 'Gagal memulai verifikasi: $e';
      });
    }
  }

  void _startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    
    _lastFrameTime = DateTime.now();
    _cameraController!.startImageStream((CameraImage image) {
      if (_isProcessingFrame || _isPageClosing || _attendanceSent) return;
      _isProcessingFrame = true;
      _processFrame(image).whenComplete(() {
        _isProcessingFrame = false;
      });
    });
  }

  InputImageRotation _getRotation(int sensorOrientation) {
    if (Platform.isIOS) return InputImageRotation.rotation270deg;
    switch (sensorOrientation) {
      case 90: return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default: return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isPageClosing || _attendanceSent || _currentStep == 3 || _isProcessingAttendance) return;

    try {
      final rotation = _getRotation(_cameraController!.description.sensorOrientation);
      final result = await _faceDetectionService.processCameraImage(image, rotation);
      
      if (!mounted || _isPageClosing) return;

      final now = DateTime.now();
      final dt = now.difference(_lastFrameTime!).inMilliseconds / 1000.0;
      _lastFrameTime = now;

      if (!result.isSingleFace) {
        setState(() {
          _backendStatus = result.faces.isEmpty ? 'Wajah tidak terdeteksi' : 'HANYA BOLEH SATU WAJAH';
          _statusText = _backendStatus;
          _stableTime = 0;
        });
        return;
      }

      final face = result.faces.first;
      
      setState(() {
        if (_currentStep == 0) {
          _backendStatus = 'Stabilisasi';
          _statusText = 'Tahan posisi wajah Anda lurus ke kamera...';
          // Pastikan wajah lurus
          if ((face.headEulerAngleY ?? 0).abs() < 12 && (face.headEulerAngleZ ?? 0).abs() < 12) {
             _stableTime += dt;
             _backendElapsed = _stableTime * 5.0; // max 10
             if (_stableTime > 2.0) {
               _currentStep = 1;
               _backendStatus = 'Tantangan: Kedipkan Mata';
               _statusText = 'Buka lalu tutup kedua mata Anda';
               _backendElapsed = 0;
             }
          } else {
             _stableTime = 0;
             _backendElapsed = 0;
             _statusText = 'Posisikan wajah lurus ke depan';
          }
        } else if (_currentStep == 1) {
          _backendStatus = 'Tantangan: Kedipkan Mata';
          final leftEye = face.leftEyeOpenProbability ?? 1.0;
          final rightEye = face.rightEyeOpenProbability ?? 1.0;
          
          if (leftEye < 0.3 && rightEye < 0.3) {
            _eyesWereClosed = true;
            _statusText = 'Buka mata Anda...';
          } else if (_eyesWereClosed && leftEye > 0.8 && rightEye > 0.8) {
            _currentStep = 2;
            _backendStatus = 'Tantangan: Gelengkan Kepala';
            _statusText = 'Gelengkan kepala ke kiri atau kanan';
          }
        } else if (_currentStep == 2) {
          _backendStatus = 'Tantangan: Gelengkan Kepala';
          final yaw = face.headEulerAngleY ?? 0;
          if (yaw.abs() > 25) {
            _headWasTurned = true;
            _statusText = 'Kembali lurus...';
          } else if (_headWasTurned && yaw.abs() < 12) {
             _currentStep = 3;
             _backendStatus = 'Selesai';
             _statusText = 'Liveness valid, memproses absensi...';
             
             _cameraController?.stopImageStream().then((_) async {
                if (mounted && !_isPageClosing) {
                   // Tambahkan jeda 500ms agar hardware kamera HP Xiaomi/Redmi 
                   // sempat bersiap sebelum mengambil foto (mencegah error code 5)
                   await Future.delayed(const Duration(milliseconds: 500));
                   _captureAndSubmit();
                }
             });
          }
        }
      });
    } catch (e) {
      debugPrint('Local liveness error: $e');
    }
  }

  void _refreshAttendanceMode() {
    _attendanceMode = AttendanceRules.getAttendanceMode(DateTime.now());

    if (_effectiveBypass && _attendanceMode == AttendanceMode.outsideHours) {
      final hour = DateTime.now().hour;
      _attendanceMode = (hour < 15)
          ? AttendanceMode.checkIn
          : AttendanceMode.checkOut;
    }

    if (_attendanceMode == AttendanceMode.outsideHours) {
      _statusText = _effectiveBypass
          ? 'Mode dev aktif. Arahkan wajah ke kamera.'
          : 'Saat ini di luar jam absensi';
    } else {
      _statusText = _effectiveBypass
          ? 'Mode dev aktif. Lanjutkan verifikasi.'
          : 'Arahkan wajah ke kamera';
    }
  }

  Future<void> _restartLivenessSession() async {
    if (_isPageClosing) return;

    setState(() {
      _currentStep = 0;
      _activeSessionId = 'local_session';
      _activeLivenessToken = 'local_token';
      _eyesWereClosed = false;
      _headWasTurned = false;
      _stableTime = 0;
    });

    _startImageStream();
  }

  Future<void> _captureAndSubmit() async {
    if (_isProcessingAttendance || _attendanceSent || _isPageClosing) {
      return;
    }

    _isProcessingAttendance = true;
    try {
      if (mounted) {
        setState(() {
          _statusText = 'Memeriksa lokasi GPS...';
        });
      }

      // Karena fokus penelitian adalah Face Recognition, 
      // pencarian GPS kita tiadakan untuk mempercepat waktu proses.
      double latitude = -6.2088;
      double longitude = 106.8456;

      if (mounted) {
        setState(() {
          _statusText = 'Mengambil foto absensi...';
        });
      }

      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        throw Exception('Kamera belum siap untuk mengambil foto absensi.');
      }

      if (mounted) {
        setState(() {
          _statusText = 'Mengambil foto absensi...';
        });
      }

      final capture = await _cameraController!.takePicture();
      
      if (mounted) {
        setState(() {
          _statusText = 'Memampatkan ukuran foto...';
        });
      }

      // Kompres gambar menggunakan package 'image' agar upload sangat cepat
      final bytes = await File(capture.path).readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      File tempFile = File(capture.path);
      if (decodedImage != null) {
        // Resize maksimal panjang/lebar 600px untuk absensi
        final resizedImage = img.copyResize(decodedImage, width: decodedImage.width > decodedImage.height ? 600 : 0, height: decodedImage.height >= decodedImage.width ? 600 : 0);
        final compressedBytes = img.encodeJpg(resizedImage, quality: 70);
        tempFile = File(capture.path.replaceAll('.jpg', '_compressed.jpg'))..writeAsBytesSync(compressedBytes);
      }

      if (mounted) {
        setState(() {
          _statusText = 'Mengirim data absensi ke server...';
        });
      }

      final response = await AttendanceService.submitAttendance(
        mode: AttendanceRules.getModeValue(_attendanceMode),
        imageFile: tempFile,
        latitude: latitude,
        longitude: longitude,
        sessionId: _activeSessionId ?? '',
        livenessToken: _activeLivenessToken ?? '',
        debugMode: _effectiveBypass,
        localLiveness: true,
      );

      if (!mounted || _isPageClosing) {
        return;
      }

      if (response.success) {
        setState(() {
          _attendanceSent = true;
          _statusText = response.message;
        });

        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted || _isPageClosing) {
          return;
        }

        _isPageClosing = true;
        _isInitialized = false;

        if (Navigator.canPop(context)) {
          Navigator.pop(context, {
            'success': true,
            'message': response.message,
            'type': response.type ?? _attendanceMode.name,
            'openRiwayat': true,
          });
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Absensi Gagal',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              content: Text(response.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }

        setState(() {
          _statusText = response.message;
        });

        await _restartLivenessSession();
      }
    } catch (e) {
      debugPrint('Capture/submit failed: $e');

      if (!mounted || _isPageClosing) {
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Informasi',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(e.toString().replaceAll('Exception: ', '')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (!_isPageClosing) {
                  unawaited(_restartLivenessSession());
                }
              },
              child: const Text(
                'Tutup',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ),
      );

      setState(() {
        _statusText = 'Tertunda: $e';
      });
    } finally {
      _isProcessingAttendance = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isPageClosing) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final controller = _cameraController;
      _cameraController = null;
      _isInitialized = false;
      if (controller != null) {
        unawaited(controller.dispose());
      }
    } else if (state == AppLifecycleState.resumed && !_showInstructions) {
      unawaited(
        _initCamera().then((_) => _startImageStream()).catchError((_) {}),
      );
    }
  }

  @override
  void dispose() {
    _isPageClosing = true;
    try { ScreenBrightness().resetScreenBrightness(); } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
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

    if (_backendStatus.contains('Stabilisasi')) {
      final required = _backendRequired <= 0 ? 10.0 : _backendRequired;
      return (_backendElapsed / required).clamp(0.0, 1.0);
    }
    if (_statusText.contains('Arahkan')) {
      return 0.25;
    }
    if (_statusText.contains('satu wajah')) {
      return 0.2;
    }
    return 0.18;
  }

  Color _guideColor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_attendanceSent) {
      return const Color(0xFF22C55E);
    }
    if (_isProcessingAttendance) {
      return isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
    }
    if (_attendanceMode == AttendanceMode.outsideHours) {
      return Colors.grey.shade400;
    }
    return isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
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
    final colorScheme = Theme.of(context).colorScheme;
    // Force light mode if flash is on so the screen becomes white and text becomes dark
    final isDark = _isFlashOn ? false : Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final primaryColor = isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);

    if (_showInstructions) {
      return _buildInstructionScreen(colorScheme);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: primaryColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Verifikasi Wajah',
          style: GoogleFonts.outfit(
            color: primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_isInitialized && !_isPreparingCamera)
            IconButton(
              icon: Icon(
                _isFlashOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                color: _isFlashOn ? Colors.amber : primaryColor,
              ),
              onPressed: _toggleFlash,
              tooltip: 'Nyalakan/Matikan Senter',
            ),
        ],
      ),
      body: !_isInitialized
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isPreparingCamera)
                      const CircularProgressIndicator()
                    else
                      const Icon(
                        Icons.videocam_off_rounded,
                        color: Colors.redAccent,
                        size: 42,
                      ),
                    const SizedBox(height: 16),
                      Text(
                        _isPreparingCamera ? 'Menyiapkan kamera...' : _statusText,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    if (!_isPreparingCamera) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _startVerification,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
                child: Column(
                  children: [
                    // Small Batik Pattern Decoration at top
                    Opacity(
                      opacity: 0.05,
                      child: Image.asset(
                        'assets/images/batik_pattern.png',
                        height: 40,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildStepIndicator(),
                    const SizedBox(height: 30),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: animation,
                                child: child,
                              ),
                            );
                          },
                      child: Container(
                        key: ValueKey<int>(_currentStep),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _getStepColor(isDark).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _getStepColor(isDark).withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          _getStepInstruction().toUpperCase(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: _getStepColor(isDark),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildCameraCircle(),
                    const SizedBox(height: 24),
                    // Warning label for spoofing
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Gunakan wajah asli. Foto/Video akan ditolak sistem.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: isDark ? Colors.red[300] : Colors.red[700],
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildBottomStatus(),
                  ],
                ),
              ),
            ),
    );
  }

  Color _getStepColor(bool isDark) {
    if (_currentStep == 0) return isDark ? Colors.blue[300]! : Colors.blue[700]!;
    if (_currentStep == 1) return isDark ? Colors.orange[300]! : Colors.orange[700]!;
    if (_currentStep == 2) return isDark ? Colors.purple[300]! : Colors.purple[700]!;
    return isDark ? Colors.green[300]! : Colors.green[700]!;
  }

  String _getStepInstruction() {
    if (_attendanceSent) return 'Absensi Berhasil';
    if (_isProcessingAttendance) return 'Verifikasi Data...';
    if (_backendStatus.contains('HANYA BOLEH SATU WAJAH')) {
      return 'Reset: Satu Wajah';
    }
    
    // Tampilkan pesan status langsung sebagai instruksi utama
    if (_backendStatus != 'Idle') {
      return _backendStatus;
    }

    if (_currentStep == 0) return 'Tahap 1: Tahan Posisi';
    return 'Proses Liveness...';
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepPoint(1, _currentStep >= 1, _currentStep == 0),
        _buildStepLine(_currentStep >= 1),
        _buildStepPoint(2, _currentStep >= 2, _currentStep == 1),
        _buildStepLine(_currentStep >= 2),
        _buildStepPoint(3, _currentStep >= 3, _currentStep == 2),
      ],
    );
  }

  Widget _buildStepPoint(int index, bool isDone, bool isActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: isDone ? 36 : 32,
      height: isDone ? 36 : 32,
      decoration: BoxDecoration(
        color: isDone
            ? Colors.green
            : (isActive ? (isDark ? const Color(0xFFA78BFA) : Colors.blue[700]) : (isDark ? Colors.white10 : Colors.grey[200])),
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: (isDark ? const Color(0xFFA78BFA) : Colors.blue).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : Text(
                '$index',
                style: GoogleFonts.outfit(
                  color: isActive ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildStepLine(bool isDone) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDone ? Colors.green : (isDark ? Colors.white10 : Colors.grey[200]),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildCameraCircle() {
    final circleSize = MediaQuery.of(context).size.width * 0.74;
    final controller = _cameraController;

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
              child: controller == null || !controller.value.isInitialized
                  ? const Center(child: CircularProgressIndicator())
                  : FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: circleSize,
                        // Gunakan perkalian untuk membalik rasio sensor landscape ke portrait
                        height: circleSize * controller.value.aspectRatio,
                        child: CameraPreview(controller),
                      ),
                    ),
            ),
          ),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = _attendanceSent
        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
        : _attendanceMode == AttendanceMode.outsideHours
        ? (isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFF7ED))
        : _isProcessingAttendance
        ? (isDark ? const Color(0xFF2E1065) : const Color(0xFFF5F3FF))
        : colorScheme.surfaceContainerHighest;

    final iconColor = _attendanceSent
        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A))
        : _attendanceMode == AttendanceMode.outsideHours
        ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B))
        : _isProcessingAttendance
        ? (isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED))
        : colorScheme.onSurfaceVariant;

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

  Widget _buildInstructionScreen(ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Batik Background
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.08 : 0.05,
              child: Image.asset(
                'assets/images/batik_pattern.png',
                fit: BoxFit.cover,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),

          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bgColor.withOpacity(0.2),
                    bgColor,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Hero(
                          tag: 'verify_icon',
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: primaryColor.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.face_unlock_rounded,
                              size: 64,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Panduan Verifikasi',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Ikuti panduan berikut agar verifikasi wajah Anda berhasil dan aman.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        // Glassmorphism Card
                        Container(
                          decoration: BoxDecoration(
                            color: isDark 
                              ? Colors.white.withOpacity(0.03) 
                              : const Color(0xFF2563EB).withOpacity(0.02),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: isDark 
                                ? Colors.white.withOpacity(0.08) 
                                : const Color(0xFF2563EB).withOpacity(0.05),
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: Column(
                            children: [
                              _buildInstructionItem(
                                Icons.center_focus_strong_rounded,
                                'Posisikan wajah di dalam frame kamera.',
                                isDark,
                              ),
                              _buildInstructionItem(
                                Icons.light_mode_rounded,
                                'Pastikan cahaya cukup dan hindari cahaya dari belakang.',
                                isDark,
                              ),
                              _buildInstructionItem(
                                Icons.no_accounts_rounded,
                                'Lepas masker, kacamata, atau penutup wajah lainnya.',
                                isDark,
                              ),
                              _buildInstructionItem(
                                Icons.record_voice_over_rounded,
                                'Hadap lurus ke kamera dengan ekspresi normal.',
                                isDark,
                              ),
                              _buildInstructionItem(
                                Icons.gesture_rounded,
                                'Ikuti instruksi challenge seperti berkedip/gerak kepala.',
                                isDark,
                              ),
                              _buildInstructionItem(
                                Icons.person_outline_rounded,
                                'Hanya satu wajah yang terlihat di kamera.',
                                isDark,
                              ),
                              _buildInstructionItem(
                                Icons.security_rounded,
                                'Gunakan wajah asli secara langsung, bukan foto/video.',
                                isDark,
                                isWarning: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Action Button
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _startVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'MULAI VERIFIKASI',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward_rounded, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(
    IconData icon,
    String text,
    bool isDark, {
    bool isWarning = false,
  }) {
    final primaryColor = isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isWarning
                  ? Colors.amber.withOpacity(0.1)
                  : primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isWarning
                    ? Colors.amber.withOpacity(0.2)
                    : primaryColor.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isWarning ? Colors.amber[600] : primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: isWarning ? FontWeight.w700 : FontWeight.w600,
                    color: isWarning 
                      ? (isDark ? Colors.amber[200] : Colors.amber[900])
                      : (isDark ? Colors.white.withOpacity(0.9) : Colors.blueGrey[800]),
                    height: 1.4,
                  ),
                ),
              ],
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
    final radius =
        (size.width < size.height ? size.width : size.height) / 2 -
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
