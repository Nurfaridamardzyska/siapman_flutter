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
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.15,
    ),
  );

  bool _isClosed = false;

  Uint8List _convertYUV420ToNV21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final ySize = width * height;
    final uvSize = ySize ~/ 2;
    final nv21 = Uint8List(ySize + uvSize);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yRowStride = yPlane.bytesPerRow;
    final yBytes = yPlane.bytes;

    if (yRowStride == width) {
      nv21.setRange(0, ySize, yBytes);
    } else {
      int yIndex = 0;
      for (int row = 0; row < height; row++) {
        int offset = row * yRowStride;
        for (int col = 0; col < width; col++) {
          nv21[yIndex++] = yBytes[offset + col];
        }
      }
    }

    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    int nv21Index = ySize;
    final halfWidth = width ~/ 2;
    final halfHeight = height ~/ 2;

    for (int row = 0; row < halfHeight; row++) {
      int uIndex = row * uRowStride;
      int vIndex = row * vRowStride;
      for (int col = 0; col < halfWidth; col++) {
        nv21[nv21Index++] = vBytes[vIndex];
        nv21[nv21Index++] = uBytes[uIndex];
        uIndex += uvPixelStride;
        vIndex += uvPixelStride;
      }
    }
    return nv21;
  }

  Future<FaceDetectionResult> processCameraImage(
    CameraImage image,
    InputImageRotation defaultRotation,
  ) async {
    if (_isClosed) {
      return FaceDetectionResult(faces: const [], isSingleFace: false);
    }

    try {
      Uint8List bytes;
      int bytesPerRow;

      if (Platform.isAndroid && image.format.group == ImageFormatGroup.yuv420 && image.planes.length == 3) {
        bytesPerRow = image.width;
        bytes = _convertYUV420ToNV21(image);
      } else {
        bytesPerRow = image.planes.isNotEmpty ? image.planes.first.bytesPerRow : image.width;
        final WriteBuffer allBytes = WriteBuffer();
        for (final plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        bytes = allBytes.done().buffer.asUint8List();
      }

      final format = Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21;

      // Try default rotation first, then fallback to all other rotations
      // This guarantees detection even if device sensorOrientation is reported incorrectly
      final Set<InputImageRotation> rotationsToTry = {
        defaultRotation,
        InputImageRotation.rotation270deg,
        InputImageRotation.rotation90deg,
        InputImageRotation.rotation0deg,
        InputImageRotation.rotation180deg,
      };

      for (final rotation in rotationsToTry) {
        final metadata = InputImageMetadata(
          size: ui.Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: bytesPerRow,
        );

        final inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: metadata,
        );

        final faces = await _faceDetector.processImage(inputImage);

        if (faces.isNotEmpty) {
          return FaceDetectionResult(
            faces: faces,
            isSingleFace: faces.length == 1,
          );
        }
      }

      return FaceDetectionResult(faces: const [], isSingleFace: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FaceDetectionService error: $e');
      }
      return FaceDetectionResult(faces: const [], isSingleFace: false);
    }
  }

  Future<void> dispose() async {
    if (_isClosed) return;
    _isClosed = true;
    await _faceDetector.close();
  }
}