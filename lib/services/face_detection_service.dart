import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectionResult {
  final List<Face> faces;
  final bool isSingleFace;

  FaceDetectionResult({
    required this.faces,
    required this.isSingleFace,
  });
}

class FaceDetectionService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      enableClassification: false,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.15,
    ),
  );

  bool _isClosed = false;

  Future<FaceDetectionResult> processCameraImage(
    CameraImage image,
    InputImageRotation rotation,
  ) async {
    if (_isClosed) {
      return FaceDetectionResult(
        faces: const [],
        isSingleFace: false,
      );
    }

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final metadata = InputImageMetadata(
        size: ui.Size(
          image.width.toDouble(),
          image.height.toDouble(),
        ),
        rotation: rotation,
        format: Platform.isIOS
            ? InputImageFormat.bgra8888
            : InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: metadata,
      );

      final faces = await _faceDetector.processImage(inputImage);

      return FaceDetectionResult(
        faces: faces,
        isSingleFace: faces.length == 1,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FaceDetectionService error: $e');
      }

      return FaceDetectionResult(
        faces: const [],
        isSingleFace: false,
      );
    }
  }

  Future<void> dispose() async {
    if (_isClosed) return;
    _isClosed = true;
    await _faceDetector.close();
  }
}