# ATEC ME rPPG 앱 개발 인수인계 보고서

**작성일**: 2026-05-14  
**대상**: 앱 개발 인수 담당자  
**플랫폼**: Flutter (Android / iOS)  
**주요 기능**: 카메라 기반 비접촉 심박수·HRV·스트레스 측정 + 얼굴인식 로그인

---

## 목차

1. [프로젝트 개요](#1-프로젝트-개요)
2. [전체 프로젝트 구조](#2-전체-프로젝트-구조)
3. [핵심 의존성 패키지](#3-핵심-의존성-패키지)
4. [로컬 DB 설계 및 연결법](#4-로컬-db-설계-및-연결법)
5. [서버 API 연결법](#5-서버-api-연결법)
6. [사용자 세션 및 인증 흐름](#6-사용자-세션-및-인증-흐름)
7. [얼굴 감지 파이프라인](#7-얼굴-감지-파이프라인)
8. [얼굴 인식 파이프라인 (ONNX)](#8-얼굴-인식-파이프라인-onnx)
9. [rPPG 신호 처리](#9-rppg-신호-처리)
10. [HRV 계산 알고리즘](#10-hrv-계산-알고리즘)
11. [측정 화면 동작 흐름](#11-측정-화면-동작-흐름)
12. [화면 네비게이션 구조](#12-화면-네비게이션-구조)
13. [데이터 모델 정의](#13-데이터-모델-정의)
14. [ONNX 모델 목록 및 역할](#14-onnx-모델-목록-및-역할)
15. [설정 및 상수](#15-설정-및-상수) 
16. [빌드 및 배포](#16-빌드-및-배포)
17. [알려진 이슈 및 디버깅 가이드](#17-알려진-이슈-및-디버깅-가이드)
18. [파일 경로 참조 표](#18-파일-경로-참조-표)

---

## 1. 프로젝트 개요

| 항목 | 내용 |
|------|------|
| 앱 이름 | ATEC Health (ME rPPG) |
| 버전 | 1.0.0+1 |
| Flutter SDK | ^3.8.1 |
| 핵심 기술 | rPPG (Remote PhotoPlethysmography) via ONNX RNN 모델 |
| 얼굴인식 | YuNet (감지) + SFace (임베딩), OpenCV 키오스크와 동일 파이프라인 |
| 로컬 저장소 | SQLite (sqflite) |
| 백엔드 연동 | REST API (Python 서버, 기본 http://127.0.0.1:8000) |
| 언어/지역화 | 한국어 |
| 테마 | 다크 모드 (forest green + gold) |

### 주요 기능 요약

- 카메라 실시간 스트림에서 얼굴 감지 후 36×36 크롭 → rPPG RNN 모델로 심박수 추출
- 측정 완료 후 RMSSD 기반 HRV, 스트레스 지수(0-100) 산출
- 얼굴 임베딩(128차원)으로 로그인/회원가입
- QR 코드로 키오스크와 토큰 교환 방식 로그인
- 측정 이력 로컬 DB 저장 + 서버 동기화

---

## 2. 전체 프로젝트 구조

```
lib/
├── main.dart                          # 앱 진입점, MaterialApp 설정
├── db/
│   ├── database_helper.dart           # SQLite 초기화, 스키마 정의 (v3)
│   ├── user_dao.dart                  # 사용자 CRUD
│   ├── measurement_dao.dart           # 측정 기록 CRUD
│   └── cause_dao.dart                 # 증상/원인 기록 CRUD
├── models/
│   ├── user.dart                      # 사용자 정보 모델
│   ├── measurement_record.dart        # DB 저장용 측정 모델
│   ├── measurement_result.dart        # 계산된 측정 결과 (일시적)
│   ├── cause_record.dart              # 증상 기록 모델
│   ├── face_detection_result.dart     # 얼굴 감지 결과 (Rect + 상태)
│   └── rppg_signal.dart               # rPPG 프레임 출력 모델
├── services/
│   ├── user_session.dart              # 세션 관리 싱글톤
│   ├── shared_api_service.dart        # HTTP REST API 클라이언트
│   ├── face_detection_service.dart    # ML Kit 얼굴 감지 (바운딩 박스)
│   ├── face_recognition_service.dart  # ONNX YuNet+SFace 인식 파이프라인
│   ├── rppg_service.dart              # ONNX rPPG 추론 (RNN 상태 관리)
│   └── hrv_service.dart               # HRV/스트레스 지수 계산
├── screens/
│   ├── splash_screen.dart             # 세션 복원 후 라우팅
│   ├── welcome_screen.dart            # 랜딩 페이지
│   ├── login_screen.dart              # 이름/얼굴 로그인 (2탭)
│   ├── register_screen.dart           # 2단계 회원가입
│   ├── home_screen.dart               # 메인 대시보드
│   ├── duration_select_screen.dart    # 측정 시간 선택 (45s~5m)
│   ├── measurement_screen.dart        # 실시간 측정 화면 (핵심)
│   ├── result_screen.dart             # 측정 결과 표시
│   ├── history_screen.dart            # 측정 이력 + 차트
│   ├── cause_record_screen.dart       # 스트레스 원인 기록
│   ├── qr_display_screen.dart         # QR 토큰 생성/표시
│   ├── qr_scan_screen.dart            # QR 스캔 (키오스크 로그인)
│   ├── member_check_screen.dart       # 회원 확인
│   ├── storytelling_screen.dart       # 온보딩/튜토리얼
│   └── server_settings_screen.dart    # 서버 URL 설정
├── widgets/
│   ├── avatar_widget.dart             # AI 아바타 (애니메이션 + 말풍선)
│   ├── face_guide_overlay.dart        # 얼굴 가이드 오버레이
│   └── signal_graph.dart             # 실시간 rPPG 신호 그래프
└── utils/
    └── constants.dart                 # 색상, 문자열, 측정 설정값

assets/
├── models/
│   ├── model.onnx                     # rPPG RNN 모델
│   ├── welch_psd.onnx                 # Welch 주기도 모델
│   ├── get_hr.onnx                    # PSD에서 HR 추출 모델
│   ├── face_detection_yunet_2023mar.onnx   # YuNet 얼굴 감지
│   ├── face_recognition_sface_2021dec.onnx # SFace 임베딩
│   └── state.json                    # RNN 초기 히든 상태 텐서
└── images/
    └── atec.png                       # 로고
```

---

## 3. 핵심 의존성 패키지

```yaml
# pubspec.yaml 핵심 패키지

# 카메라
camera: 0.11.2+1                      # 카메라 스트림 (YUV420 raw)

# 이미지 처리
image: 4.5.4                          # YUV→RGB 변환, 크롭, 리사이즈

# 머신러닝
google_mlkit_face_detection: ^0.10.0  # 실시간 얼굴 감지 (빠른 모드)
flutter_onnxruntime: ^1.5.1           # ONNX 모델 추론

# 로컬 DB
sqflite: ^2.4.1                       # SQLite
shared_preferences: ^2.3.0            # Key-Value 저장 (세션, 서버 URL)

# 네트워크
http: ^1.2.0                          # REST API 호출

# UI
fl_chart: 1.1.0                       # 실시간 신호 그래프
qr_flutter: ^4.1.0                    # QR 생성
mobile_scanner: ^5.2.3                # QR 스캔
permission_handler: 12.0.1            # 카메라 권한 요청

# 기타
path: ^1.9.0                          # DB 파일 경로
google_fonts: 6.3.2                   # 폰트

dependency_overrides:
  vector_math: 2.2.0                  # 호환성 패치 (fl_chart 충돌 방지)
```

---

## 4. 로컬 DB 설계 및 연결법

### 4-1. 초기화

**파일**: `lib/db/database_helper.dart`

```dart
// 싱글톤 패턴으로 DB 인스턴스 관리
final db = await DatabaseHelper.instance.database;
```

DB 파일은 앱 전용 디렉토리에 `atec_health.db`로 생성됩니다. 앱 삭제 시 함께 삭제됩니다.

### 4-2. 스키마 (버전 3)

#### users 테이블
```sql
CREATE TABLE users (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL,
  birth_year  INTEGER,
  gender      TEXT,         -- 'M' 또는 'F'
  region      TEXT,
  phone       TEXT,
  server_id   TEXT,         -- 서버에서 발급한 UUID
  created_at  TEXT NOT NULL -- ISO8601 형식
)
```

#### measurements 테이블
```sql
CREATE TABLE measurements (
  id                   INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id              INTEGER,
  heart_rate           REAL NOT NULL,   -- 평균 BPM
  hrv                  REAL NOT NULL,   -- RMSSD (ms)
  stress_index         REAL NOT NULL,   -- 0~100
  stress_level         TEXT NOT NULL,   -- '낮음','보통','높음','매우 높음'
  hrv_level            TEXT NOT NULL,   -- '우수','양호','보통','주의 필요'
  measurement_duration INTEGER NOT NULL, -- 측정 시간 (초)
  rr_intervals         TEXT NOT NULL,   -- JSON 배열 문자열 "[800.0, 820.0, ...]"
  measured_at          TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
)
```

#### cause_records 테이블
```sql
CREATE TABLE cause_records (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id        INTEGER,
  measurement_id INTEGER,
  content        TEXT NOT NULL,   -- "증상|원인" 형식으로 저장
  recorded_at    TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (measurement_id) REFERENCES measurements(id)
)
```

### 4-3. DAO 사용 예시

```dart
// 사용자 저장
final userId = await UserDao().insertUser(user);

// 이름으로 사용자 조회
final user = await UserDao().getUserByName('홍길동');

// 측정 기록 저장
final measurementId = await MeasurementDao().insertMeasurement(record);

// 특정 사용자의 최근 10건 조회
final records = await MeasurementDao().getRecentMeasurements(userId, limit: 10);

// 증상 기록 저장
await CauseDao().insertCause(causeRecord);
```

### 4-4. 마이그레이션 관리

`database_helper.dart`의 `onUpgrade` 콜백에서 버전별 분기 처리합니다.  
현재 버전: 3. 버전을 올릴 때 반드시 `onUpgrade`에 ALTER TABLE 또는 재생성 로직을 추가하세요.

---

## 5. 서버 API 연결법

### 5-1. 서버 URL 설정

**파일**: `lib/services/shared_api_service.dart`

기본 URL: `http://127.0.0.1:8000`  
앱 내 `ServerSettingsScreen`에서 변경 가능. SharedPreferences의 `server_url` 키에 저장됩니다.

```dart
// 서버 URL 가져오기
final prefs = await SharedPreferences.getInstance();
final baseUrl = prefs.getString('server_url') ?? 'http://127.0.0.1:8000';
```

### 5-2. API 엔드포인트 목록

| 엔드포인트 | 메서드 | 설명 |
|-----------|--------|------|
| `/health` | GET | 서버 연결 확인 |
| `/users` | POST | 신규 사용자 등록 |
| `/users?name={name}` | GET | 이름으로 사용자 검색 |
| `/users/{serverId}` | GET | UUID로 사용자 조회 |
| `/users/{serverId}/face` | PUT | 얼굴 디스크립터 업데이트 |
| `/users/face-login` | POST | 얼굴 디스크립터로 로그인 |
| `/users/{serverId}/qr-token` | POST | QR 토큰 생성 |
| `/users/qr-login?token=...` | GET | QR 토큰으로 로그인 |
| `/users/{serverId}/qr-token` | DELETE | QR 토큰 삭제 |
| `/users/{serverId}/sessions` | POST | 측정 결과 저장 |
| `/users/{serverId}/sessions` | GET | 측정 이력 조회 |
| `/users/{serverId}/causes` | POST | 증상/원인 기록 저장 |
| `/users/{serverId}/causes` | GET | 증상/원인 기록 조회 |

### 5-3. 요청/응답 형식

```dart
// 사용자 등록 요청 예시
POST /users
Content-Type: application/json
{
  "name": "홍길동",
  "birth_year": 1990,
  "gender": "M",
  "region": "서울",
  "phone": "010-1234-5678",
  "face_descriptor": [0.12, -0.34, ...]  // 128차원 float 배열 (선택)
}

// 얼굴 로그인 요청 예시
POST /users/face-login
Content-Type: application/json
{
  "face_descriptor": [0.12, -0.34, ...],  // 128차원
  "threshold": 0.363                       // 코사인 유사도 임계값
}

// 측정 결과 저장 예시
POST /users/{serverId}/sessions
Content-Type: application/json
{
  "heart_rate": 72.5,
  "hrv": 35.2,
  "stress_index": 45.0,
  "stress_level": "보통",
  "hrv_level": "양호",
  "measurement_duration": 60,
  "rr_intervals": [820, 810, 835, ...],
  "measured_at": "2026-05-14T10:30:00"
}
```

### 5-4. 타임아웃 및 에러 처리

- 모든 요청: 10초 타임아웃
- 실패 시 `null` 반환 (앱이 죽지 않도록 설계)
- 서버 연결 실패 시 로컬 DB 폴백(fallback) 동작

---

## 6. 사용자 세션 및 인증 흐름

**파일**: `lib/services/user_session.dart` (싱글톤)

### 6-1. 초기화 (앱 시작 시)

```dart
await UserSession.instance.init();
// → SharedPreferences에서 저장된 userId 복원
// → 로컬 DB에서 User 객체 로드
```

### 6-2. 회원가입 흐름

```
1. RegisterScreen에서 정보 입력 (이름, 생년, 성별, 지역, 전화번호)
2. (선택) 얼굴 사진 촬영 → extractDescriptorFromJpeg() → 128차원 벡터
3. UserSession.register(user, faceDescriptor?)
   ├─ 서버 POST /users → serverId(UUID) 수신
   ├─ 로컬 DB에 serverId 포함 사용자 저장
   └─ SharedPreferences에 userId 저장
4. HomeScreen으로 이동
```

### 6-3. 이름 로그인 흐름

```
1. LoginScreen 이름 탭 → 이름 입력
2. UserSession.loginByName(name)
   ├─ 서버 GET /users?name=... → User 정보 수신
   ├─ 로컬 DB에 없으면 삽입, 있으면 serverId 동기화
   └─ SharedPreferences에 userId 저장
3. HomeScreen으로 이동
```

### 6-4. 얼굴 로그인 흐름

```
1. LoginScreen 얼굴 탭 → 카메라 스트림 시작
2. 3프레임 연속 얼굴 감지 → 각 프레임에서 디스크립터 추출
3. UserSession.loginByFace(descriptor)
   ├─ 서버 POST /users/face-login (threshold: 0.363)
   └─ 성공 시 사용자 정보 수신 → 로컬 동기화
4. HomeScreen으로 이동
```

### 6-5. QR 로그인 흐름

```
키오스크 측:
  1. HomeScreen → QrDisplayScreen
  2. POST /users/{serverId}/qr-token → token(UUID) 발급
  3. token을 QR로 렌더링 (qr_flutter)

모바일 측:
  1. QrScanScreen에서 QR 스캔 (mobile_scanner)
  2. GET /users/qr-login?token=... → 사용자 정보 수신
  3. 로그인 완료
```

---

## 7. 얼굴 감지 파이프라인

**파일**: `lib/services/face_detection_service.dart`

**목적**: 실시간으로 얼굴 위치(바운딩 박스)를 파악하여 rPPG 크롭 영역 결정 및 가이드 오버레이 표시.

### 동작 방식

```
CameraImage (YUV420)
  ↓ YUV420 → NV21 변환 (Uint8List)
  ↓ InputImage 생성 (센서 회전각 포함)
  ↓ ML Kit FaceDetector.processImage()
    - performanceMode: fast
    - enableTracking: true
  ↓ 결과 Rect를 스크린 좌표로 변환
    - 전면 카메라: 좌우 반전 적용
    - scale factor: 화면 크기 / 이미지 크기
  ↓ FaceDetectionResult 반환
    - boundingBox: 화면 좌표 (UI 오버레이용)
    - originalBoundingBox: 이미지 좌표 (rPPG 크롭용)
    - isCentered: 중앙 원과 겹치는지 여부
    - confidence: 1.0 (감지됨)
```

**성능 최적화**: 30 FPS 카메라 스트림에서 5프레임마다 1회 실행(≈6 FPS), 결과는 3초간 캐싱.

---

## 8. 얼굴 인식 파이프라인 (ONNX)

**파일**: `lib/services/face_recognition_service.dart`

**목적**: 회원가입 시 얼굴 디스크립터 저장, 로그인 시 디스크립터 비교. OpenCV 키오스크와 동일한 YuNet + SFace 파이프라인 사용.

### 8-1. 사용 모델

| 모델 파일 | 역할 | 입력 | 출력 |
|-----------|------|------|------|
| `face_detection_yunet_2023mar.onnx` | 얼굴 위치 + 5개 랜드마크 검출 | 640×640 BGR Float32 NCHW | 12개 텐서 (cls/obj/bbox/kps × stride) |
| `face_recognition_sface_2021dec.onnx` | 얼굴 임베딩 추출 | 112×112 BGR Float32 NCHW | 128차원 Float32 벡터 |

### 8-2. 전체 파이프라인

```
입력: CameraImage(YUV420) 또는 JPEG bytes

[1단계] 이미지 변환
  CameraImage YUV420 → RGB Image 객체
  JPEG bytes → Image 객체 (decodeJpg)

[2단계] 회전 보정
  전면 카메라: 좌우 반전 (flipHorizontal)
  센서 회전각(0/90/180/270)에 따라 추가 회전

[3단계] YuNet 얼굴 감지
  이미지 → 640×640 리사이즈 (비율 유지, 패딩)
  BGR 순서로 NCHW Float32 텐서 생성
  ONNX 추론 → 12개 출력 텐서 디코딩

  FCOS 방식 디코딩 (stride 8, 16, 32):
    score = sigmoid(cls) × sigmoid(obj)
    bbox = [center_x - l, center_y - t, center_x + r, center_y + b]
    kps = 5개 랜드마크 좌표 (right_eye, left_eye, nose, mouth_right, mouth_left)
  
  → 최고 score 얼굴 선택

[4단계] 랜드마크 기반 얼굴 정렬 (alignCrop)
  5개 랜드마크 → 표준 얼굴 기준점으로 similarity transform 계산
    표준 기준점(112×112 공간):
      right_eye: (38.29, 51.70)
      left_eye:  (73.53, 51.50)
      nose_tip:  (56.02, 71.74)
      mouth_r:   (41.55, 92.37)
      mouth_l:   (70.73, 92.20)
  
  최소자승법으로 affine 파라미터 [a, b, tx, ty] 계산
  역변환(bilinear interpolation) → 112×112 정렬된 얼굴 이미지

[5단계] SFace 임베딩
  112×112 BGR Float32 NCHW → ONNX 추론 → 128차원 벡터

[6단계] 유사도 비교
  두 벡터 간 코사인 유사도 계산
  threshold: 0.363 (동일 인물 판단 기준)
```

### 8-3. 주요 메서드

```dart
// 회원가입용: JPEG 파일에서 디스크립터 추출
List<double>? descriptor = await service.extractDescriptorFromJpeg(jpegBytes);

// 로그인용: 실시간 카메라 프레임에서 디스크립터 추출
List<double>? descriptor = await service.extractDescriptorFromCameraImage(
  cameraImage,
  sensorOrientation: 270,
  deviceOrientation: DeviceOrientation.portraitUp,
  isFrontCamera: true,
);

// 유사도 비교
double similarity = FaceRecognitionService.cosineSimilarity(descriptorA, descriptorB);
bool isSamePerson = similarity >= 0.363;
```

---

## 9. rPPG 신호 처리

**파일**: `lib/services/rppg_service.dart`

### 9-1. 사용 모델

| 모델 | 역할 |
|------|------|
| `model.onnx` | 상태 기반 RNN (프레임별 rPPG 신호값 출력) |
| `welch_psd.onnx` | Welch 주기도: 신호 버퍼 → 주파수별 파워 스펙트럼 |
| `get_hr.onnx` | 파워 스펙트럼 → 심박수(BPM) 추출 |
| `state.json` | RNN 초기 히든 상태 (측정 시작마다 리셋) |

### 9-2. 프레임별 처리 흐름

```
CameraImage에서 얼굴 크롭 (originalBoundingBox 기준)
  ↓ 36×36 리사이즈
  ↓ RGB 정규화 → [0.0, 1.0] Float32
  ↓ 텐서 형태: [1, 1, 36, 36, 3] (B, T, H, W, C)

RNN 추론:
  입력: image_tensor + state_tensors + delta_time(초)
  출력: rPPG 신호값(float) + 업데이트된 state_tensors

신호 버퍼:
  최근 300개 값 유지 (10초 @ 30FPS)
```

### 9-3. 심박수 계산 (30프레임마다)

```
신호 버퍼 300개 → welch_psd.onnx → 주파수-파워 스펙트럼
  → get_hr.onnx → 지배 주파수 → BPM 변환

출력: RppgSignal {
  signal: [float],             // 현재 프레임 신호값
  timestamp: double,           // 경과 시간 (초)
  heartRate: double?,          // null이면 아직 미계산
  isNewHrCalculation: bool     // true면 새로운 HR 계산됨
}
```

### 9-4. 상태 관리

- `init()`: `state.json` 로드하여 RNN 초기 상태 준비
- `reset()`: 측정 시작 시 RNN 상태 초기화
- `dispose()`: ONNX 세션 해제

---

## 10. HRV 계산 알고리즘

**파일**: `lib/services/hrv_service.dart`

### 입력

측정 중 수집된 심박수 목록 (`List<double>`, 유효 범위: 40~200 BPM)

### 계산 순서

```
1. RR 간격 변환
   RR[i] (ms) = 60000 / HR[i]

2. RMSSD (HRV 지표)
   RMSSD = sqrt( Σ(RR[i+1] - RR[i])² / (N-1) )
   → 부교감신경 활성도 반영, 높을수록 회복 良

3. SDNN (표준편차)
   SDNN = sqrt( variance(RR) )

4. 스트레스 지수 (0~100 복합 점수)
   stressIndex = 0.3 × hrComponent
               + 0.5 × hrvComponent
               + 0.2 × variabilityComponent

   hrComponent:          HR 정규화 (60~80 BPM 정상 범위 기준)
   hrvComponent:         RMSSD 임계값 기반 스케일링 (높은 HRV = 낮은 스트레스)
   variabilityComponent: SDNN 기반 변동성 패널티

5. 등급 분류
   스트레스 등급:
     '낮음'    → stressIndex < 30
     '보통'    → 30 ≤ stressIndex < 60
     '높음'    → 60 ≤ stressIndex < 80
     '매우 높음' → stressIndex ≥ 80

   HRV 등급:
     '우수'      → RMSSD > 50ms
     '양호'      → 30ms < RMSSD ≤ 50ms
     '보통'      → 20ms < RMSSD ≤ 30ms
     '주의 필요' → RMSSD ≤ 20ms
```

---

## 11. 측정 화면 동작 흐름

**파일**: `lib/screens/measurement_screen.dart`

### 초기화 순서

```
1. 카메라 권한 확인 (permission_handler)
2. FaceDetectionService 초기화 (ML Kit)
3. RppgService 초기화 (ONNX 모델 로드)
4. 카메라 설정: 전면, medium 해상도, NV21(Android)/BGRA8888(iOS)
5. 이미지 스트림 시작
```

### 프레임 처리 루프 (≈30 FPS)

```
매 프레임:
  ├─ [5프레임마다] 얼굴 감지 비동기 실행
  │   → FaceDetectionService.detect(cameraImage)
  │   → 결과 3초 캐싱
  │   → UI 오버레이 업데이트
  │
  └─ [매 프레임, 얼굴 유효·중앙 정렬 시] rPPG 처리
      → 얼굴 크롭 (originalBoundingBox)
      → YUV420 → RGB 변환
      → RppgService.processFrame() 호출
      → isNewHrCalculation == true이면 _heartRates에 추가
      → 신호값 → 그래프 버퍼에 추가
```

### 측정 완료 후 처리

```
타이머 만료 → 이미지 스트림 정지
  → HrvService.calculate(_heartRates, duration)
  → 로컬 DB 저장 (MeasurementDao)
  → 서버 동기화 (SharedApiService.saveSession) -- 실패해도 계속 진행
  → ResultScreen으로 이동 (MeasurementResult 전달)

예외: 유효한 HR 없으면 SnackBar 경고 후 뒤로 이동
```

### 프레임 카운터 역할

| 변수 | 역할 |
|------|------|
| `_frameIndex` | ML Kit 실행 여부 제어 (5프레임마다) |
| `_rppgFrameCount` | rPPG 처리 프레임 수 카운트 |
| `_validFrameCount` | 유효 측정 프레임 수 (얼굴 감지 성공) |

---

## 12. 화면 네비게이션 구조

```
SplashScreen
  │
  ├─[로그인됨]─→ HomeScreen
  └─[미로그인]─→ WelcomeScreen
                  ├─[시작]─→ StorytellingScreen → LoginScreen
                  └─[QR]──→ QrScanScreen

LoginScreen (탭 2개)
  ├─[이름]──→ 이름 입력 → loginByName() → HomeScreen
  └─[얼굴]──→ 카메라 감지 → loginByFace() → HomeScreen
  └─[회원가입]→ RegisterScreen

RegisterScreen (2단계)
  ├─ Step 0: 정보 입력 → Step 1
  └─ Step 1: 얼굴 촬영(선택) → register() → HomeScreen

HomeScreen (대시보드)
  ├─→ DurationSelectScreen (45s / 1m / 3m / 5m 선택)
  │     └─→ MeasurementScreen
  │           └─→ ResultScreen
  │                 └─→ CauseRecordScreen → HomeScreen
  ├─→ HistoryScreen (탭 2개: 측정 이력 / 증상 이력)
  ├─→ QrDisplayScreen (QR 토큰 표시)
  └─→ ServerSettingsScreen (서버 URL 변경)
```

---

## 13. 데이터 모델 정의

### User
```dart
class User {
  int? id;            // 로컬 DB PK (자동 증가)
  String name;        // 이름 (필수)
  int? birthYear;     // 생년 (ex: 1990)
  String? gender;     // 'M' 또는 'F'
  String? region;     // 지역 (ex: '서울')
  String? phone;      // 전화번호
  String? serverId;   // 서버 UUID
  DateTime createdAt;
}
```

### MeasurementResult (일시적, DB 저장 전)
```dart
class MeasurementResult {
  double heartRate;          // 평균 BPM
  double hrv;                // RMSSD (ms)
  double stressIndex;        // 0~100
  List<double> rrIntervals;  // ms 단위 RR 간격 목록
  DateTime timestamp;
  int measurementDuration;   // 측정 시간 (초)

  String get stressLevel { ... }   // '낮음','보통','높음','매우 높음'
  String get hrvLevel { ... }      // '우수','양호','보통','주의 필요'
}
```

### MeasurementRecord (DB 저장용)
```dart
class MeasurementRecord {
  int? id;
  int? userId;
  double heartRate;
  double hrv;
  double stressIndex;
  String stressLevel;
  String hrvLevel;
  int measurementDuration;
  List<double> rrIntervals;     // DB에 JSON 문자열로 저장
  DateTime measuredAt;
}
```

### CauseRecord (증상 기록)
```dart
class CauseRecord {
  int? id;
  int? userId;
  int? measurementId;
  String symptom;          // 증상
  String cause;            // 원인
  DateTime recordedAt;
  // DB 저장 시: content = "symptom|cause"
}
```

### FaceDetectionResult
```dart
class FaceDetectionResult {
  Rect boundingBox;           // 화면 좌표 (UI 오버레이)
  Rect originalBoundingBox;   // 이미지 좌표 (rPPG 크롭)
  double confidence;          // 감지 신뢰도 (1.0 고정)
  bool isCentered;            // 화면 중앙 원 내부 여부
  bool get isValid => confidence > 0.5;
}
```

### RppgSignal
```dart
class RppgSignal {
  List<double> signal;          // 현재 프레임 신호값
  double timestamp;             // 경과 시간 (초)
  double? heartRate;            // null이면 미계산
  bool isNewHrCalculation;      // true이면 새 HR 계산됨
}
```

---

## 14. ONNX 모델 목록 및 역할

| 파일 | 크기 | 역할 | 입력 형식 | 출력 |
|------|------|------|-----------|------|
| `model.onnx` | - | rPPG RNN | [1,1,36,36,3] + state | 신호값 + 새 state |
| `welch_psd.onnx` | - | Welch 주기도 | 300개 신호값 | 주파수-파워 스펙트럼 |
| `get_hr.onnx` | - | HR 추출 | 스펙트럼 | BPM (float) |
| `face_detection_yunet_2023mar.onnx` | - | 얼굴 감지 + 랜드마크 | [1,3,640,640] BGR | 12개 텐서 (FCOS) |
| `face_recognition_sface_2021dec.onnx` | - | 얼굴 임베딩 | [1,3,112,112] BGR | [1,128] float |

모든 모델은 `pubspec.yaml`의 `assets:` 섹션에 등록되어야 번들됩니다.

```yaml
flutter:
  assets:
    - assets/models/
    - assets/images/
```

---

## 15. 설정 및 상수

**파일**: `lib/utils/constants.dart`

### 색상 테마
```dart
AppColors.primary       = Color(0xFF2D7A4F)  // forest green
AppColors.secondary     = Color(0xFFE8B84B)  // gold
AppColors.darkBg        = Color(0xFF1E4D2B)  // dark green
AppColors.textCream     = Color(0xFFF5F3EE)
AppColors.textLightGreen= Color(0xFFA8D5B5)
```

### 측정 설정
```dart
MeasurementConfig.targetFps              = 30
MeasurementConfig.faceConfidenceThreshold = 0.5
MeasurementConfig.centerThresholdX       = 0.15
MeasurementConfig.centerThresholdY       = 0.15
```

### 얼굴 인식 임계값
- 코사인 유사도 ≥ 0.363 → 동일 인물 (서버/클라이언트 동일 기준)

---

## 16. 빌드 및 배포

### 개발 환경 실행
```bash
flutter pub get
flutter run
```

### Android 빌드
```bash
flutter build apk --release         # APK 파일
flutter build appbundle --release   # Play Store 업로드용
```

### iOS 빌드
```bash
flutter build ios --release
```

### 필수 권한 설정

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>얼굴 인식 및 건강 측정에 사용됩니다.</string>
```

### 주의사항

- `flutter_onnxruntime`은 에뮬레이터에서 성능이 매우 낮음 → 실기기 테스트 필수
- YuNet/SFace 모델은 Android 64-bit(arm64-v8a)에서 최적화됨
- 카메라 해상도 `medium`을 사용 (low: 얼굴 크롭 품질 저하, high: 프레임 드롭)

---

## 17. 알려진 이슈 및 디버깅 가이드

### 자주 발생하는 문제

| 증상 | 원인 | 해결 방법 |
|------|------|-----------|
| HR null 반환 | 신호 버퍼 < 300 프레임 | 측정 시간 늘리기 (최소 10초 필요) |
| 얼굴 미감지 | 조명 부족 / 역광 | 밝은 환경에서 테스트 |
| 바운딩 박스 위치 오류 | 센서 회전 미보정 | `sensorOrientation` 값 확인 |
| 모델 로드 실패 | pubspec.yaml assets 누락 | `assets/models/` 경로 재확인 |
| 서버 연결 실패 | 방화벽 / URL 오류 | ServerSettingsScreen에서 URL 수정 |
| 얼굴 디스크립터 null | JPEG 디코딩 실패 | 카메라 촬영 성공 여부 확인 |
| 측정 완료 후 결과 없음 | 유효 HR 수집 실패 | 얼굴 중앙 유지, 측정 시간 증가 |

### 디버깅 로그 위치

```dart
user_session.dart          // 로그인/회원가입 흐름
rppg_service.dart          // 모델 상태, HR 계산 성공/실패
face_recognition_service.dart  // YuNet/SFace 파이프라인
measurement_screen.dart    // 프레임 카운터, 완료 처리
shared_api_service.dart    // HTTP 요청/응답
```

`flutter logs` 또는 Android Studio Logcat에서 위 파일 이름으로 필터링하면 됩니다.

---

## 18. 파일 경로 참조 표

| 기능 | 파일 경로 |
|------|-----------|
| 앱 진입점 | `lib/main.dart` |
| DB 스키마/초기화 | `lib/db/database_helper.dart` |
| 사용자 CRUD | `lib/db/user_dao.dart` |
| 측정 기록 CRUD | `lib/db/measurement_dao.dart` |
| 증상 기록 CRUD | `lib/db/cause_dao.dart` |
| 세션 관리 | `lib/services/user_session.dart` |
| REST API 클라이언트 | `lib/services/shared_api_service.dart` |
| ML Kit 얼굴 감지 | `lib/services/face_detection_service.dart` |
| ONNX 얼굴 인식 | `lib/services/face_recognition_service.dart` |
| rPPG 추론 | `lib/services/rppg_service.dart` |
| HRV 계산 | `lib/services/hrv_service.dart` |
| 측정 화면 (핵심) | `lib/screens/measurement_screen.dart` |
| 측정 결과 화면 | `lib/screens/result_screen.dart` |
| 설정/상수 | `lib/utils/constants.dart` |
| ONNX 모델 파일 | `assets/models/*.onnx` |
| RNN 초기 상태 | `assets/models/state.json` |
| 의존성 목록 | `pubspec.yaml` |

---

*본 보고서는 2026-05-14 기준 `master` 브랜치 최신 커밋(4ccaeac) 기준으로 작성되었습니다.*

---

## 19. 서버 DB 테이블 목록 (shared_api.py 기준)

서버 DB 파일: `data/hrv_kiosk.db` (모바일 앱 + 키오스크 공용)

| 테이블 | 역할 |
|--------|------|
| `users` | 사용자 기본 정보 (user_id UUID, name, phone, birth_year, birth_month, gender, region) |
| `face_descriptors` | 얼굴 임베딩 128차원 벡터 (user_id 1:1) |
| `qr_tokens` | QR 로그인용 임시 토큰 (만료시간 포함, user_id 1:1) |
| `sessions` | 측정 결과 (heart_rate, hrv, stress_index 등 JSON 저장) |
| `cause_records` | 증상/원인 기록 (symptom, cause, session_id 참조) |
| `smalltalk_sessions` | 키오스크 AI 대화 세션 기록 |

### 모바일 로컬 DB ↔ 서버 DB 대응 관계

```
모바일 로컬 (atec_health.db)      서버 공용 (hrv_kiosk.db)
────────────────────────────────────────────────────────
users.server_id              →    users.user_id (UUID)
measurements                 →    sessions
cause_records                →    cause_records
(없음)                       →    face_descriptors
(없음)                       →    qr_tokens
(없음)                       →    smalltalk_sessions
```

> 모바일 로컬 DB는 오프라인 우선 백업 역할. 서버 DB가 키오스크와 공유하는 마스터 DB.

---

## 20. 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-05-14 | 최초 작성 |
| 2026-06-09 | `cause_records` 서버 동기화 추가 — `shared_api.py` 테이블/엔드포인트 추가, `shared_api_service.dart` saveCause/getCauses 메서드 추가, `cause_record_screen.dart` 서버 API 호출 추가 |



 키오스크와의 DB 연결 방식
  
  결론부터: 모바일 앱과 키오스크는 직접 DB를 공유하지 않습니다. 둘 다 중간에 공통 Python REST API 서버를 통해 간접적으로 연결되어 있습니다.

  [모바일 앱]  ──HTTP──▶  [Python 백엔드 서버]  ◀──HTTP──  [키오스크]
                                  │
                            [서버 DB (공유)]

  [모바일 앱]  ──별도──▶  [로컬 SQLite (앱 전용)]                                                                                                                                

  ---
  연결 고리: server_id (UUID)
  
  모든 동기화의 핵심은 서버에서 발급하는 server_id(UUID)입니다.

  ┌──────────────────────┬──────────────────────────────────┐                                                                                                                      │      저장 위치       │              식별자              │
  ├──────────────────────┼──────────────────────────────────┤
  │ 모바일 로컬 SQLite   │ users.id (로컬 자동증가 PK)      │
  ├──────────────────────┼──────────────────────────────────┤
  │ 서버 DB              │ user_id (UUID)                   │
  ├──────────────────────┼──────────────────────────────────┤                                                                                                                    
  │ 모바일에서 서버 참조 │ users.server_id 컬럼에 UUID 저장 │
  └──────────────────────┴──────────────────────────────────┘

  ---
  QR 코드로 키오스크 연동하는 흐름

  [모바일] HomeScreen → QrDisplayScreen
    1. 서버에 POST /users/{serverId}/qr-token
       → 서버가 UUID 토큰 발급 (5분 유효)                                                                                                                                        
                                                                                                                                                                                     2. 토큰을 QR 이미지로 렌더링                                                                                                                                                 
       QR 내용 = "http://{서버IP}:8000/users/qr-login?token={UUID}"

  [키오스크] QR 스캔
    3. QR에서 URL + token 파싱
    4. GET /users/qr-login?token=... → 서버가 토큰 검증
    5. 사용자 정보 반환 → 키오스크 로그인 완료                                                                                                                                   
    6. DELETE /users/{serverId}/qr-token (토큰 즉시 무효화)                                                                                                                      
                                                                                                                                                                                   중요: QR에 서버 IP까지 포함되어 있어서, 모바일이 QR을 스캔하면 서버 URL이 자동으로 설정되기도 합니다 (qr_scan_screen.dart:55).                                                 

  ---
  측정 데이터 동기화

  측정 완료 후:
    1. 로컬 SQLite에 즉시 저장 (오프라인 대비)
    2. POST /users/{serverId}/sessions 로 서버에도 저장
       → 서버 저장 실패해도 앱은 계속 동작 (로컬 우선)                                                                                                                           
                                                                                                                                                                                   ---
  서버 URL 설정 방법

  - 기본값: http://127.0.0.1:8000 (SharedPreferences에 저장)
  - 앱 내 ServerSettingsScreen에서 수동 변경 가능
  - QR 스캔 시 QR에 포함된 서버 IP로 자동 갱신됨                                                                                                                                 
                                                                                                                                                                                   ---
  요약하면: 모바일 ↔ 키오스크는 DB를 직접 공유하지 않고, 공통 Python 서버 DB를 server_id(UUID)로 매핑해서 간접 연동합니다. QR은 인증 토큰 교환 수단이고, 실제 데이터는 항상
  서버를 통해 흐릅니다.