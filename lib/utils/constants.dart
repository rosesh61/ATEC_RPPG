import 'package:flutter/material.dart';

class AppColors {
  // 자연 테마 - 키오스크 스타일
  static const Color primary = Color(0xFF2D7A4F);       // 신록 그린
  static const Color primaryDark = Color(0xFF1E4D2B);   // 깊은 숲
  static const Color primaryLight = Color(0xFF5AAD77);  // 밝은 초록
  static const Color secondary = Color(0xFFE8B84B);     // 골드
  static const Color secondaryLight = Color(0xFFF5D87E);

  static const Color background = Color(0xFF1E4D2B);    // 배경 (깊은 숲)
  static const Color surface = Color(0xFF245C35);       // 카드 배경
  static const Color surfaceLight = Color(0xFF2D7A4F);  // 밝은 카드

  static const Color success = Color(0xFF5AAD77);
  static const Color warning = Color(0xFFE8B84B);
  static const Color error = Color(0xFFEF5350);

  static const Color textPrimary = Color(0xFFF5F3EE);   // 크림색
  static const Color textSecondary = Color(0xFFA8D5B5); // 연한 초록
  static const Color textGold = Color(0xFFE8B84B);

  // 오버레이/글래스
  static const Color overlay = Color(0x99000000);
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x335AAD77);
}

class AppColors2 {
  // 결과/기록 화면용 라이트 테마 (자연 베이지)
  static const Color background = Color(0xFFF4F3EE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF2D7A4F);
  static const Color textPrimary = Color(0xFF2D5A3D);
  static const Color textSecondary = Color(0xFF5A6B47);
  static const Color border = Color(0xFFC5D4B0);
}

class AppStrings {
  static const String appName = 'ATEC Health';
  static const String measurementTitle = '심박수 측정';
  static const String startMeasurement = '측정 시작';
  static const String measuring = '측정중...';
  static const String centerYourFace = '얼굴을 원 안에 맞춰주세요';
  static const String noFaceDetected = '얼굴이 감지되지 않습니다';
  static const String keepStill = '잘 하고 계세요! 가만히 계세요 😊';
  static const String measurementComplete = '측정 완료';
  static const String heartRate = '심박수';
  static const String hrv = '심박변이도';
  static const String stressLevel = '스트레스 지수';
  static const String bpm = 'BPM';
  static const String ms = 'ms';
  static const String restartMeasurement = '다시 측정';
  static const String back = '돌아가기';
}

class MeasurementConfig {
  static const int measurementDurationSeconds = 50;
  static const int targetFps = 30;
  static const double faceConfidenceThreshold = 0.5;
  static const double centerThresholdX = 0.15;
  static const double centerThresholdY = 0.15;
}

// AI 아바타 말풍선 메시지
class AvatarMessages {
  static const List<String> welcome = [
    '안녕하세요! 😊\n오늘도 건강한 하루 보내세요.',
    '반갑습니다!\n오늘의 건강 상태를 확인해볼까요?',
    '좋은 하루예요!\nHRV 측정으로 건강을 체크해보세요.',
  ];

  static const List<String> measuring = [
    '천천히 숨을 쉬세요.\n편안하게 계세요 😊',
    '잘 하고 계세요!\n조금만 더 기다려주세요.',
    '거의 다 됐어요!\n자세를 유지해주세요.',
  ];

  static const List<String> stressLow = [
    '훌륭해요! 🌿\n스트레스가 낮은 상태예요.',
    '아주 좋아요! 😊\n건강한 상태를 잘 유지하고 계세요.',
  ];

  static const List<String> stressMid = [
    '수고하셨어요! 🌱\n가벼운 스트레칭을 추천드려요.',
    '잘 하셨어요! 😊\n충분한 휴식을 취해보세요.',
  ];

  static const List<String> stressHigh = [
    '오늘 많이 힘드셨죠? 🍃\n천천히 쉬어가세요.',
    '괜찮아요. 😊\n깊게 숨을 들이쉬며 쉬어보세요.',
  ];

  static const List<String> storytelling = [
    '처음 오셨군요!\n천천히 안내해드릴게요 😊',
    '걱정 마세요!\n어렵지 않아요. 함께 해봐요 🌿',
  ];
}
