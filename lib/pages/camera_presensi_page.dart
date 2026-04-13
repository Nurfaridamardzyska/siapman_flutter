import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/attendance_rules.dart';
import '../services/attendance_service.dart';
import '../services/api_service.dart';

class CameraPresensiPage extends StatefulWidget {
  const CameraPresensiPage({super.key});

  @override
  State<CameraPresensiPage> createState() => _CameraPresensiPageState();
}

class _MjpegClient {
  final Uri uri;

  _MjpegClient({
    required this.uri,
  });

  Stream<Uint8List> get frames {
    late final StreamController<Uint8List> controller;
    HttpClient? client;
    bool cancelled = false;

    Future<void> pump() async {
      try {
        client = HttpClient()..autoUncompress = false;
        final req = await client!.getUrl(uri);
        final res = await req.close();

        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw HttpException('HTTP ${res.statusCode}', uri: uri);
        }

        final buffer = BytesBuilder(copy: false);
        int startIndex = -1;

        await for (final chunk in res) {
          if (cancelled) {
            break;
          }

          buffer.add(chunk);
          final bytes = buffer.toBytes();

          if (startIndex < 0) {
            startIndex = _indexOfJpegStart(bytes);
          }

          if (startIndex >= 0) {
            final endIndex = _indexOfJpegEnd(bytes, startIndex);
            if (endIndex >= 0) {
              final frame = Uint8List.sublistView(bytes, startIndex, endIndex + 2);
              if (!controller.isClosed) {
                controller.add(frame);
              }

              final remaining = bytes.sublist(endIndex + 2);
              buffer.clear();
              buffer.add(remaining);
              startIndex = _indexOfJpegStart(remaining);
            }
          }
        }

        if (!controller.isClosed) {
          await controller.close();
        }
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
          await controller.close();
        }
      } finally {
        client?.close(force: true);
      }
    }

    controller = StreamController<Uint8List>(
      onListen: pump,
      onCancel: () {
        cancelled = true;
        client?.close(force: true);
      },
    );

    return controller.stream;
  }

  int _indexOfJpegStart(Uint8List bytes) {
    for (var i = 0; i < bytes.length - 1; i++) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD8) {
        return i;
      }
    }
    return -1;
  }

  int _indexOfJpegEnd(Uint8List bytes, int from) {
    for (var i = from; i < bytes.length - 1; i++) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD9) {
        return i;
      }
    }
    return -1;
  }
}

class _CameraPresensiPageState extends State<CameraPresensiPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _isInitialized = false;
  bool _isProcessingAttendance = false;
  bool _attendanceSent = false;
  bool _isPageClosing = false;

  late final Uri _streamUri;
  late final Uri _statusUri;
  late final Uri _resetUri;
  late final Uri _snapshotUri;

  StreamSubscription<Uint8List>? _mjpegSub;
  Timer? _statusTimer;

  Uint8List? _latestFrame;
  String _backendStatus = 'Idle';
  double _backendElapsed = 0.0;
  double _backendRequired = 10.0;
  int _statusFailureCount = 0;
  bool _backendUnavailable = false;

  AttendanceMode _attendanceMode = AttendanceMode.outsideHours;
  String _statusText = 'Menyiapkan kamera...';

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final base = Uri.parse(ApiService.baseUrl);
    final faceBase = Uri(
      scheme: base.scheme,
      host: base.host,
      port: 5001,
    );
    _streamUri = faceBase.replace(path: '/stream');
    _statusUri = faceBase.replace(path: '/status');
    _resetUri = faceBase.replace(path: '/reset');
    _snapshotUri = faceBase.replace(path: '/snapshot');

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _refreshAttendanceMode();
    unawaited(_startBackendStream());
    _startStatusPolling();
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
    _isPageClosing = true;
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    unawaited(_mjpegSub?.cancel());
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isPageClosing) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_mjpegSub?.cancel());
      _mjpegSub = null;
      _isInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_startBackendStream());
    }
  }

  Future<void> _startBackendStream() async {
    if (_isPageClosing) {
      return;
    }

    if (kIsWeb) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitialized = true;
        _backendUnavailable = false;
        _statusFailureCount = 0;
      });
      return;
    }

    await _mjpegSub?.cancel();
    _mjpegSub = _MjpegClient(uri: _streamUri).frames.listen(
      (bytes) {
        if (!mounted || _isPageClosing) {
          return;
        }

        _latestFrame = bytes;
        if (!_isInitialized) {
          setState(() {
            _isInitialized = true;
            _backendUnavailable = false;
            _statusFailureCount = 0;
          });
        } else {
          setState(() {});
        }
      },
      onError: (e) {
        if (!mounted || _isPageClosing) {
          return;
        }
        _setBackendUnavailable('Gagal membuka kamera: $e');
      },
      cancelOnError: false,
    );
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_fetchStatus());
    });
  }

  void _setBackendUnavailable(String message) {
    if (!mounted || _isPageClosing) {
      return;
    }

    _statusTimer?.cancel();
    setState(() {
      _backendUnavailable = true;
      _isInitialized = false;
      _statusText = '$message\n\nJalankan face service di port 5001 lalu tekan Coba Lagi.';
    });
  }

  Future<void> _retryBackendConnection() async {
    if (_isPageClosing) {
      return;
    }

    await _mjpegSub?.cancel();
    _mjpegSub = null;

    if (mounted) {
      setState(() {
        _backendUnavailable = false;
        _statusFailureCount = 0;
        _statusText = 'Mencoba menghubungkan kamera...';
      });
    }

    try {
      await http.post(_resetUri).timeout(const Duration(seconds: 2));
    } catch (_) {}

    unawaited(_startBackendStream());
    _startStatusPolling();
  }

  Future<void> _fetchStatus() async {
    if (_isProcessingAttendance ||
        _attendanceSent ||
        _isPageClosing ||
        _backendUnavailable) {
      return;
    }

    try {
      _refreshAttendanceMode();

      final res = await http.get(_statusUri).timeout(const Duration(seconds: 2));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        _statusFailureCount++;
        if (_statusFailureCount >= 3) {
          _setBackendUnavailable('Face service merespons HTTP ${res.statusCode}');
        }
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final valid = data['valid'] == true;
      final status = data['status']?.toString() ?? 'Idle';
      final elapsed = (data['elapsed'] as num?)?.toDouble() ?? 0.0;
      final required = (data['required'] as num?)?.toDouble() ?? 10.0;

      if (!mounted || _isPageClosing) {
        return;
      }

      setState(() {
        _statusFailureCount = 0;
        _backendUnavailable = false;
        _backendStatus = status;
        _backendElapsed = elapsed;
        _backendRequired = required;

        if (_attendanceMode == AttendanceMode.outsideHours) {
          _statusText = 'Saat ini di luar jam absensi';
        } else if (valid) {
          _statusText = 'Wajah Valid';
        } else if (status == 'Hold still...') {
          _statusText = 'Tahan posisi wajah sebentar...';
        } else if (status == 'Detecting...') {
          _statusText = 'Detecting...';
        } else {
          _statusText = 'Mohon arahkan wajah ke lingkaran';
        }
      });

      if (valid && _attendanceMode != AttendanceMode.outsideHours) {
        await _captureAndSubmit();
      }
    } catch (e) {
      _statusFailureCount++;
      if (_statusFailureCount >= 3) {
        _setBackendUnavailable('Tidak bisa terhubung ke ${_statusUri.host}:${_statusUri.port} ($e)');
      }
      return;
    }
  }

  Future<void> _captureAndSubmit() async {
    if (_isProcessingAttendance ||
        _attendanceSent ||
        _isPageClosing) {
      return;
    }

    _isProcessingAttendance = true;

    _statusTimer?.cancel();
    await _mjpegSub?.cancel();
    _mjpegSub = null;

    try {
      if (mounted) {
        setState(() {
          _statusText = 'Memverifikasi absensi...';
        });
      }

      final bytes = _latestFrame;
      Uint8List? imageBytes = bytes;

      if (kIsWeb || imageBytes == null || imageBytes.isEmpty) {
        final snap = await http
            .get(_snapshotUri)
            .timeout(const Duration(seconds: 3));
        if (snap.statusCode >= 200 && snap.statusCode < 300) {
          imageBytes = snap.bodyBytes;
        }
      }

      if (imageBytes == null || imageBytes.isEmpty) {
        throw Exception('Frame kamera belum tersedia');
      }

      final response = await AttendanceService.submitAttendance(
        mode: AttendanceRules.getModeValue(_attendanceMode),
        imageBytes: imageBytes,
        fileName: 'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
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
        setState(() {
          _statusText = response.message;
        });

        await http.post(_resetUri);

        if (!_isPageClosing) {
          _startStatusPolling();
          unawaited(_startBackendStream());
        }
      }
    } catch (_) {
      if (!mounted || _isPageClosing) {
        return;
      }

      setState(() {
        _statusText = 'Gagal memproses absensi';
      });

      await http.post(_resetUri);

      if (!_isPageClosing) {
        _startStatusPolling();
        unawaited(_startBackendStream());
      }
    } finally {
      _isProcessingAttendance = false;
    }
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

    if (_backendStatus == 'Hold still...' || _statusText.contains('Tahan posisi')) {
      final required = _backendRequired <= 0 ? 10.0 : _backendRequired;
      return (_backendElapsed / required).clamp(0.0, 1.0);
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
      body: !_isInitialized
          ? _buildInitializingState()
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
                        key: UniqueKey(),
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
                    _buildCameraCircle(),
                    const SizedBox(height: 28),
                    _buildBottomStatus(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInitializingState() {
    final showError = _backendUnavailable || _statusText.startsWith('Gagal membuka kamera');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!showError) const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              showError ? 'Kamera belum terhubung' : 'Menyiapkan kamera...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            if (showError) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _retryBackendConnection,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCameraCircle() {
    final circleSize = MediaQuery.of(context).size.width * 0.74;
    final frame = _latestFrame;

    final Widget preview = kIsWeb
        ? Image.network(
            _streamUri.toString(),
            gaplessPlayback: true,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Center(child: CircularProgressIndicator());
            },
          )
        : (frame == null
            ? const Center(child: CircularProgressIndicator())
            : Image.memory(
                frame,
                gaplessPlayback: true,
                fit: BoxFit.cover,
              ));

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
                  width: circleSize,
                  height: circleSize,
                  child: preview,
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