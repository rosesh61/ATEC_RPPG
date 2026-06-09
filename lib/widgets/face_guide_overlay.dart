import 'package:flutter/material.dart';
import '../models/face_detection_result.dart';
import '../utils/constants.dart';

class FaceGuideOverlay extends StatelessWidget {
  final FaceDetectionResult? faceResult;
  final Size screenSize;

  const FaceGuideOverlay({
    super.key,
    required this.faceResult,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Center guide circle
        Center(
          child: Container(
            width: screenSize.width * 0.6,
            height: screenSize.width * 0.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _getGuideColor(),
                width: 3,
              ),
            ),
          ),
        ),

        // Face bounding box
        if (faceResult != null && faceResult!.isValid)
          Positioned(
            left: faceResult!.boundingBox.left,
            top: faceResult!.boundingBox.top,
            child: Container(
              width: faceResult!.boundingBox.width,
              height: faceResult!.boundingBox.height,
              decoration: BoxDecoration(
                border: Border.all(
                  color: faceResult!.isCentered
                      ? AppColors.success
                      : AppColors.warning,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

        // Status message
        Positioned(
          top: 60,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Text(
                _getStatusMessage(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getGuideColor() {
    if (faceResult == null || !faceResult!.isValid) {
      return AppColors.error.withOpacity(0.5);
    }
    return faceResult!.isCentered
        ? AppColors.success.withOpacity(0.5)
        : AppColors.warning.withOpacity(0.5);
  }

  String _getStatusMessage() {
    if (faceResult == null || !faceResult!.isValid) {
      return AppStrings.noFaceDetected;
    }
    if (!faceResult!.isCentered) {
      return AppStrings.centerYourFace;
    }
    return AppStrings.keepStill;
  }
}
