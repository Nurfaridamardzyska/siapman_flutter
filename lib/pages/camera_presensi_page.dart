import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPresensiPage extends StatefulWidget {
  const CameraPresensiPage({super.key});

  @override
  State<CameraPresensiPage> createState() => _CameraPresensiPageState();
}

class _CameraPresensiPageState extends State<CameraPresensiPage> {
  CameraController? _controller;
  bool _isCameraReady = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  /// ==========================
  /// INISIALISASI KAMERA DEPAN
  /// ==========================
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'Kamera tidak tersedia';
        });
        return;
      }

      // Ambil kamera depan, fallback jika tidak ada
      final camera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (!mounted) return;

      setState(() {
        _isCameraReady = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mengakses kamera';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// ==========================
  /// UI
  /// ==========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lapor Kehadiran'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // ERROR STATE
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          _errorMessage,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    }

    // LOADING STATE
    if (!_isCameraReady || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // CAMERA READY
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_controller!),

        /// Overlay gelap di luar lingkaran
        Container(
          color: const Color.fromRGBO(0, 0, 0, 0.3),
        ),

        /// Lingkaran wajah
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.blueAccent,
                width: 5,
              ),
            ),
          ),
        ),

        /// Instruksi
        Positioned(
          top: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Posisikan wajah pada lingkaran',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        /// Tombol presensi (sementara dummy)
        Positioned(
          bottom: 40,
          left: 40,
          right: 40,
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Presensi dikirim (simulasi)'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Ambil Presensi',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
