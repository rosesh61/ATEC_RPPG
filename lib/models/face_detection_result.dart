import 'dart:ui';

class FaceDetectionResult {
  final Rect boundingBox; // Screen coordinates (mirrored for front camera)
  final Rect originalBoundingBox; // Original image coordinates (not mirrored)
  final double confidence;
  final bool isCentered;

  FaceDetectionResult({
    required this.boundingBox,
    required this.originalBoundingBox,
    required this.confidence,
    required this.isCentered,
  });

  bool get isValid => confidence > 0.5;
}
