import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/face_detection_result.dart';
import '../utils/camera_image_converter.dart';

class FaceDetectionService {
  FaceDetector? _faceDetector;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: false,
          enableContours: false,
          enableTracking: true,
          enableClassification: false,
          minFaceSize: 0.1,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      _isInitialized = true;
      print('ML Kit face detector initialized successfully');
    } catch (e) {
      print('Error initializing ML Kit face detector: $e');
      rethrow;
    }
  }

  Future<FaceDetectionResult?> detectFaceFromCameraImage(
    CameraImage cameraImage,
    CameraDescription cameraDescription,
    Size screenSize,
  ) async {
    if (!_isInitialized || _faceDetector == null) {
      throw Exception('Face detection service not initialized');
    }

    try {
      final isFrontCamera =
          cameraDescription.lensDirection == CameraLensDirection.front;
      final sensorOrientation = cameraDescription.sensorOrientation;
      final deviceOrientation = _deviceOrientationToDegrees();

      int rotDeg;
      if (isFrontCamera) {
        rotDeg = (360 - ((sensorOrientation + deviceOrientation) % 360)) % 360;
      } else {
        rotDeg = (sensorOrientation - deviceOrientation + 360) % 360;
      }
      // LG 기기(sensorOrientation=270) NV21 변환 후 rotation 보정
      if (isFrontCamera && sensorOrientation == 270) {
        rotDeg = 0;
      }

      final nv21Bytes = CameraImageConverter.toNv21(cameraImage);
      if (nv21Bytes == null) return null;

      final rotation = InputImageRotationValue.fromRawValue(rotDeg) ??
          InputImageRotation.rotation0deg;

      final metadata = InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: cameraImage.width,
      );

      final inputImage = InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: metadata,
      );

      final faces = await _faceDetector!.processImage(inputImage);
      print('ML Kit detected ${faces.length} faces (rotDeg=$rotDeg, size=${cameraImage.width}x${cameraImage.height})');

      if (faces.isEmpty) return null;

      final face = faces.first;
      final mlkitBox = face.boundingBox;

      final bool isRotated90or270 = rotDeg == 90 || rotDeg == 270;
      final imageSize = Size(
        isRotated90or270 ? cameraImage.height.toDouble() : cameraImage.width.toDouble(),
        isRotated90or270 ? cameraImage.width.toDouble() : cameraImage.height.toDouble(),
      );

      final imageAspect = imageSize.width / imageSize.height;
      final screenAspect = screenSize.width / screenSize.height;

      double scale;
      double offsetX = 0;
      double offsetY = 0;

      if (imageAspect > screenAspect) {
        scale = screenSize.height / imageSize.height;
        offsetX = (imageSize.width * scale - screenSize.width) / 2;
      } else {
        scale = screenSize.width / imageSize.width;
        offsetY = (imageSize.height * scale - screenSize.height) / 2;
      }

      Rect screenBoundingBox = Rect.fromLTRB(
        mlkitBox.left * scale - offsetX,
        mlkitBox.top * scale - offsetY,
        mlkitBox.right * scale - offsetX,
        mlkitBox.bottom * scale - offsetY,
      );

      if (isFrontCamera) {
        screenBoundingBox = Rect.fromLTRB(
          screenSize.width - screenBoundingBox.right,
          screenBoundingBox.top,
          screenSize.width - screenBoundingBox.left,
          screenBoundingBox.bottom,
        );
      }

      // originalBoundingBox: rPPG 크롭용 원본 좌표 (rotation0이므로 그대로)
      final originalBoundingBox = mlkitBox;

      // screenBoundingBox가 화면 안에 조금이라도 걸쳐 있으면 isCentered=true
      final isCentered = screenBoundingBox.overlaps(
        Rect.fromLTWH(0, 0, screenSize.width, screenSize.height),
      );

      return FaceDetectionResult(
        boundingBox: screenBoundingBox,
        originalBoundingBox: originalBoundingBox,
        confidence: 1.0,
        isCentered: isCentered,
      );
    } catch (e) {
      print('Error detecting face: $e');
      return null;
    }
  }

  int _deviceOrientationToDegrees() {
    switch (_currentOrientation) {
      case DeviceOrientation.portraitUp:
        return 0;
      case DeviceOrientation.landscapeLeft:
        return 90;
      case DeviceOrientation.portraitDown:
        return 180;
      case DeviceOrientation.landscapeRight:
        return 270;
    }
  }

  DeviceOrientation _currentOrientation = DeviceOrientation.portraitUp;

  void updateOrientation(DeviceOrientation orientation) {
    _currentOrientation = orientation;
  }

  void dispose() {
    _faceDetector?.close();
    _isInitialized = false;
  }
}
