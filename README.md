# ATEC Health — ME rPPG

카메라 기반 비접촉 심박수·HRV·스트레스 측정 Flutter 앱

---

## 소개

스마트폰 전면 카메라만으로 얼굴을 촬영해 심박수(BPM), HRV(RMSSD), 스트레스 지수를 실시간으로 측정합니다.  
ONNX RNN 모델 기반 rPPG 알고리즘과 YuNet + SFace 얼굴 인식 파이프라인을 사용하며, Python REST API 서버와 키오스크(OpenCV)와 연동됩니다.

### 주요 기능

- 카메라 실시간 스트림 → 얼굴 감지 → 36×36 크롭 → rPPG RNN 추론 → 심박수 추출
- RMSSD 기반 HRV 및 스트레스 지수(0~100) 산출
- YuNet + SFace 얼굴 임베딩(128차원)을 이용한 로그인 / 회원가입
- QR 코드를 통한 키오스크 연동 로그인
- 측정 이력 로컬 SQLite 저장 + REST API 서버 동기화
- 다크 테마 (forest green + gold)

---

## 기술 스택

| 항목 | 내용 |
|------|------|
| 프레임워크 | Flutter ^3.8.1 (Dart) |
| 타겟 플랫폼 | Android (주), iOS |
| ML 추론 | ONNX Runtime (`flutter_onnxruntime`) |
| 얼굴 감지 | Google ML Kit Face Detection |
| 얼굴 인식 | YuNet + SFace (ONNX) |
| rPPG 모델 | RNN + Welch PSD + HR 추출 (ONNX 3단계 파이프라인) |
| 로컬 DB | SQLite (`sqflite`) |
| 백엔드 | Python REST API (기본: `http://127.0.0.1:8000`) |

---

## 사전 요구사항

### Flutter 앱 개발 (Android 개발자 필수)

> **Python 가상환경은 필요 없습니다.** Flutter 앱 자체는 `pubspec.yaml`로 패키지를 관리합니다.  
> `requirments.txt`는 Python 백엔드 서버용 conda 환경 파일이며, 서버를 로컬에서 직접 실행할 때만 필요합니다.

| 도구 | 버전 | 설치 링크 |
|------|------|-----------|
| Flutter SDK | ^3.8.1 | https://docs.flutter.dev/get-started/install |
| Android Studio | 최신 | https://developer.android.com/studio |
| Android SDK | API 21+ | Android Studio 내 SDK Manager |
| Java (JDK) | 17+ | Android Studio Bundled JDK |

```bash
# Flutter 설치 확인
flutter doctor
```

### Python 백엔드 서버 (선택 — 서버를 로컬에서 실행할 경우만)

```bash
# conda 환경 생성 (requirments.txt 사용)
conda create --name ai-hrv-app --file requirments.txt

# 활성화
conda activate ai-hrv-app
```

---

## 빠른 시작

### 1. 저장소 클론

```bash
git clone https://github.com/<your-username>/Atec_ME_RPPG.git
cd Atec_ME_RPPG
```

### 2. 패키지 설치

```bash
flutter pub get
```

### 3. 기기 연결 후 실행

```bash
# 연결된 기기 확인
flutter devices

# 실기기에서 실행 (에뮬레이터는 ONNX 성능 저하로 비권장)
flutter run
```

### 4. 서버 URL 설정

앱 실행 후 **서버 설정 화면**에서 Python 백엔드 서버 주소를 입력합니다.  
기본값: `http://127.0.0.1:8000`

---

## 빌드

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS
flutter build ios --release
```

---

## 프로젝트 구조

```
lib/
├── main.dart                          # 앱 진입점
├── db/                                # SQLite DAO
│   ├── database_helper.dart           # 스키마 초기화 (v3)
│   ├── user_dao.dart
│   ├── measurement_dao.dart
│   └── cause_dao.dart
├── models/                            # 데이터 모델
├── services/                          # 비즈니스 로직
│   ├── rppg_service.dart              # ONNX rPPG 추론
│   ├── face_detection_service.dart    # ML Kit 얼굴 감지
│   ├── face_recognition_service.dart  # YuNet + SFace
│   ├── hrv_service.dart               # HRV / 스트레스 계산
│   ├── shared_api_service.dart        # REST API 클라이언트
│   └── user_session.dart              # 세션 관리 싱글톤
├── screens/                           # 화면
└── utils/
    └── constants.dart                 # 색상, 설정값

assets/
├── models/
│   ├── model.onnx                     # rPPG RNN
│   ├── welch_psd.onnx                 # Welch 주기도
│   ├── get_hr.onnx                    # HR 추출
│   ├── face_detection_yunet_2023mar.onnx
│   ├── face_recognition_sface_2021dec.onnx
│   └── state.json                     # RNN 초기 히든 상태
└── images/
    └── atec.png
```

---

## 아키텍처 개요

```
[모바일 앱]  ──HTTP──▶  [Python 백엔드 서버]  ◀──HTTP──  [키오스크 (OpenCV)]
                                  │
                            [서버 공유 DB]

[모바일 앱]  ──별도──▶  [로컬 SQLite]
```

- 모바일 ↔ 키오스크는 **직접 DB 연결 없이** 공통 Python 서버를 통해 `server_id(UUID)`로 간접 연동됩니다.
- QR 코드는 인증 토큰 교환 수단으로 사용됩니다.
- 서버 오프라인 시 로컬 SQLite 우선 동작합니다.

---

## 필수 권한

### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSCameraUsageDescription</key>
<string>얼굴 인식 및 건강 측정에 사용됩니다.</string>
```

---

## 주요 의존성

| 패키지 | 역할 |
|--------|------|
| `camera: 0.11.2+1` | 카메라 스트림 (YUV420) |
| `flutter_onnxruntime: ^1.5.1` | ONNX 모델 추론 |
| `google_mlkit_face_detection: ^0.10.0` | 실시간 얼굴 감지 |
| `sqflite: ^2.4.1` | SQLite 로컬 DB |
| `fl_chart: 1.1.0` | 실시간 rPPG 신호 그래프 |
| `mobile_scanner: ^5.2.3` | QR 스캔 |
| `http: ^1.2.0` | REST API 통신 |

전체 의존성은 [`pubspec.yaml`](pubspec.yaml) 참고.

---

## 알려진 이슈

| 증상 | 원인 | 해결 |
|------|------|------|
| 심박수 미표시 | 신호 버퍼 < 10초 | 측정 시간 늘리기 |
| 얼굴 미감지 | 조명 부족 / 역광 | 밝은 환경에서 테스트 |
| 에뮬레이터에서 느림 | ONNX 최적화 미지원 | 실기기 사용 필수 |
| 서버 연결 실패 | URL 불일치 / 방화벽 | 앱 내 서버 설정 화면에서 URL 수정 |

---

## 상세 문서

인수인계 상세 문서는 [`HANDOVER_REPORT.md`](HANDOVER_REPORT.md)를 참고하세요.  
DB 스키마, API 엔드포인트, rPPG 알고리즘, HRV 계산식 등 전체 아키텍처가 포함되어 있습니다.

---

## 라이선스

Private — ATEC 내부 프로젝트
