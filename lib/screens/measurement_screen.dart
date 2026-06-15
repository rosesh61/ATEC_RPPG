import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import '../models/face_detection_result.dart';
import '../db/measurement_dao.dart';
import '../services/face_detection_service.dart';
import '../services/user_session.dart';
import '../services/rppg_service.dart';
import '../services/hrv_service.dart';
import '../services/shared_api_service.dart';
import '../utils/camera_image_converter.dart';
import '../utils/constants.dart';
import '../widgets/face_guide_overlay.dart';
import '../widgets/signal_graph.dart';
import 'result_screen.dart';

class MeasurementScreen extends StatefulWidget {
  final int durationSeconds;

  const MeasurementScreen({
    super.key,
    this.durationSeconds = MeasurementConfig.measurementDurationSeconds,
  });

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  CameraController? _cameraController;
  final FaceDetectionService _faceDetectionService = FaceDetectionService();
  final RppgService _rppgService = RppgService();
  final HrvService _hrvService = HrvService();

  bool _isInitialized = false;
  bool _isMeasuring = false;
  FaceDetectionResult? _currentFaceResult;
  FaceDetectionResult? _lastValidFaceResult;
  DateTime? _lastFaceDetectedAt;
  bool _isFaceDetecting = false; // ML Kit 처리 중 플래그 (rPPG와 독립)
  int _frameIndex = 0; // 전체 프레임 카운터
  final List<double> _signalData = [];
  final List<double> _heartRates = [];
  double? _currentHeartRate;

  int _validFrameCount = 0;
  Timer? _measurementTimer;
  bool _isProcessingFrame = false;
  DateTime? _measurementStartTime;
  int _rppgFrameCount = 0; // rPPG 처리된 실제 프레임 수 (fps 계산용)

  // 아바타 말풍선 메시지
  String _avatarMessage = '천천히 숨을 쉬세요.\n편안하게 계세요 😊';
  Timer? _avatarMessageTimer;
  int _avatarMsgIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Request camera permission
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('카메라 권한이 필요합니다')));
          Navigator.pop(context);
        }
        return;
      }

      // Initialize services
      await _faceDetectionService.initialize();
      await _rppgService.initialize();

      // Initialize camera
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _startMeasurement();
      }
    } catch (e) {
      print('Error initializing services: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('초기화 오류: $e')));
        Navigator.pop(context);
      }
    }
  }

  void _startMeasurement() {
    setState(() {
      _isMeasuring = true;
      _validFrameCount = 0;
      _signalData.clear();
      _heartRates.clear();
      _currentHeartRate = null;
      _isProcessingFrame = false;
      _measurementStartTime = DateTime.now();
    });

    _rppgService.reset();
    _startAvatarMessages();

    // Start image stream for real-time processing
    _cameraController!.startImageStream((CameraImage cameraImage) {
      _processFrame(cameraImage);
    });

    // Check measurement completion
    _measurementTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) => _checkMeasurementCompletion(),
    );
  }

  Future<void> _processFrame(CameraImage cameraImage) async {
    if (!_isMeasuring) return;

    _frameIndex++;

    // ML Kit는 5프레임마다 한 번만 실행 (rPPG와 독립)
    if (!_isFaceDetecting && _frameIndex % 5 == 0) {
      _isFaceDetecting = true;
      final screenSize = MediaQuery.of(context).size;
      _faceDetectionService.detectFaceFromCameraImage(
        cameraImage,
        _cameraController!.description,
        screenSize,
      ).then((faceResult) {
        if (faceResult != null) {
          _lastValidFaceResult = faceResult;
          _lastFaceDetectedAt = DateTime.now();
        }
        final effectiveFaceResult = faceResult ??
            (_lastFaceDetectedAt != null &&
                    DateTime.now().difference(_lastFaceDetectedAt!).inMilliseconds < 3000
                ? _lastValidFaceResult
                : null);
        if (mounted) {
          setState(() {
            _currentFaceResult = effectiveFaceResult;
          });
        }
        _isFaceDetecting = false;
      });
    }

    // rPPG는 매 프레임 처리 (ML Kit 대기 없음)
    if (_isProcessingFrame) return;
    _isProcessingFrame = true;

    try {
      // 유효한 얼굴 결과 사용 (3초 캐시)
      final effectiveFaceResult = _lastFaceDetectedAt != null &&
              DateTime.now().difference(_lastFaceDetectedAt!).inMilliseconds < 3000
          ? _lastValidFaceResult
          : null;

      final shouldProcess = effectiveFaceResult != null &&
          effectiveFaceResult.isValid &&
          effectiveFaceResult.isCentered;

      if (shouldProcess) {
        // Convert CameraImage to img.Image for rPPG processing
        final convertedImage = CameraImageConverter.toRgb(cameraImage);

        if (convertedImage != null) {
          // 얼굴 영역 크롭 (너무 작으면 전체 이미지 사용)
          final box = effectiveFaceResult.originalBoundingBox;
          final img.Image faceImage;
          if (box.width > 20 && box.height > 20) {
            faceImage = img.copyCrop(
              convertedImage,
              x: box.left.toInt().clamp(0, convertedImage.width - 1),
              y: box.top.toInt().clamp(0, convertedImage.height - 1),
              width: box.width.toInt().clamp(1, convertedImage.width),
              height: box.height.toInt().clamp(1, convertedImage.height),
            );
          } else {
            faceImage = convertedImage;
          }

          // Process with rPPG service
          final timestamp = DateTime.now().millisecondsSinceEpoch / 1000.0;
          final signal = await _rppgService.processFrame(faceImage, timestamp);

          if (signal != null && mounted) {
            _rppgFrameCount++;
            setState(() {
              _signalData.addAll(signal.signal);
              if (_signalData.length > 300) {
                _signalData.removeRange(0, _signalData.length - 300);
              }

              if (signal.heartRate != null) {
                // 1. UI 업데이트는 매 프레임마다 수행 (화면이 부드럽게 보임)
                _currentHeartRate = signal.heartRate;

                // 2. HRV 계산용 리스트에는 "새로 계산된" 값만 추가
                if (signal.isNewHrCalculation) {
                  print(
                    '✓ New HR value added: ${signal.heartRate!.toStringAsFixed(1)} BPM (Total HR count: ${_heartRates.length + 1})',
                  );
                  _heartRates.add(signal.heartRate!);
                }
              } else {
                // Log when HR is null to track calculation attempts
                if (_validFrameCount % 30 == 0) {
                  // Log every 30 frames (~1 second)
                  print(
                    'HR calculation: buffer=${_rppgService.bufferLength}/${_rppgService.hasEnoughData ? "ready" : "waiting"}, HR=null',
                  );
                }
              }
            });

            _validFrameCount++;
          }
        }
      }
      // Note: Removed automatic reset - now only counts valid frames
      // This allows measurement to continue even if face temporarily moves
    } catch (e) {
      print('Error processing frame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _startAvatarMessages() {
    final messages = AvatarMessages.measuring;
    _avatarMessageTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) {
        if (!mounted) return;
        setState(() {
          _avatarMsgIndex = (_avatarMsgIndex + 1) % messages.length;
          _avatarMessage = messages[_avatarMsgIndex];
        });
      },
    );
  }

  void _resetMeasurement() {
    setState(() {
      _validFrameCount = 0;
      _signalData.clear();
      _heartRates.clear();
      _currentHeartRate = null;
    });
    _rppgService.reset();
  }

  void _checkMeasurementCompletion() {
    if (!_isMeasuring || _measurementStartTime == null) return;

    // Check if measurement duration has elapsed
    final elapsed = DateTime.now().difference(_measurementStartTime!);
    if (elapsed.inSeconds >= widget.durationSeconds) {
      print(
        '${widget.durationSeconds} seconds elapsed - completing measurement (HR count: ${_heartRates.length}, buffer: ${_rppgService.bufferLength})',
      );
      _completeMeasurement();
    }
  }

  void _completeMeasurement() async {
    _measurementTimer?.cancel();

    // Stop image stream
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }

    setState(() {
      _isMeasuring = false;
    });

    if (_heartRates.isEmpty) {
      print(
        '⚠ Measurement failed: No HR values collected (valid frames: $_validFrameCount, buffer: ${_rppgService.bufferLength})',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('심박수를 계산할 수 없습니다. 얼굴을 카메라 중앙에 위치시키고 다시 시도해주세요.'),
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    print(
      '✓ Measurement completed successfully: ${_heartRates.length} HR values collected',
    );

    try {
      final result = _hrvService.calculateFromHeartRates(
        _heartRates,
        widget.durationSeconds,
      );

      // 로컬 DB에 측정 결과 저장
      final userId = UserSession.instance.currentUser?.id;
      final recordId = await MeasurementDao().insert(result.toRecord(userId: userId));
      print('✓ Measurement saved to local DB with id: $recordId');

      // 서버에도 세션 저장 (실패해도 무시)
      final serverId = UserSession.instance.currentUser?.serverId;
      if (serverId != null) {
        final sessionData = {
          'timestamp': result.timestamp.toIso8601String(),
          'type': 'hrv_measurement',
          'heart_rate': result.heartRate,
          'hrv': result.hrv,
          'stress_index': result.stressIndex,
          'stress_level': result.stressLevel,
          'hrv_level': result.hrvLevel,
          'measurement_duration': widget.durationSeconds,
          'rr_intervals': result.rrIntervals,
        };
        final ok = await SharedApiService.instance.saveSession(serverId, sessionData);
        if (ok) await MeasurementDao().markSynced(recordId);
        print(ok
            ? '✓ Measurement saved to server'
            : '⚠ Server save failed (will retry via SyncService)');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ResultScreen(result: result)),
      );
    } catch (e) {
      print('Error calculating results: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('결과 계산 오류: $e')));
    }
  }

  @override
  void dispose() async {
    _measurementTimer?.cancel();
    _avatarMessageTimer?.cancel();

    // Stop image stream if running
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }

    _cameraController?.dispose();
    _faceDetectionService.dispose();
    _rppgService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _cameraController == null) {
      return Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: AppColors.secondary,
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 20),
              const Text(
                '카메라를 준비하고 있어요...',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    final elapsed = _measurementStartTime != null
        ? DateTime.now().difference(_measurementStartTime!).inSeconds
        : 0;
    final progress = (elapsed / widget.durationSeconds).clamp(0.0, 1.0);
    final progressPercent = (progress * 100).toInt();

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          // 카메라 프리뷰 (풀스크린)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),

          // 반투명 상단 오버레이
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 반투명 하단 오버레이
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.75),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 얼굴 가이드 오버레이
          FaceGuideOverlay(
            faceResult: _currentFaceResult,
            screenSize: screenSize,
          ),

          // 상단: 뒤로가기 + AI 아바타 말풍선
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  // 아바타 말풍선
                  Container(
                    constraints: const BoxConstraints(maxWidth: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.primaryLight.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🌿', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _avatarMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 신호 그래프
          if (_isMeasuring && _signalData.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 130,
              child: SignalGraph(
                signalData: _signalData,
                currentHeartRate: _currentHeartRate,
              ),
            ),

          // 하단: 프로그레스 + 상태 텍스트
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  // 심박수 표시 (측정 시작 후)
                  if (_currentHeartRate != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.favorite,
                              color: AppColors.error, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${_currentHeartRate!.toStringAsFixed(0)} BPM',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 프로그레스 바
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.toDouble(),
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.secondary),
                      minHeight: 7,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 상태 텍스트
                  Text(
                    _isMeasuring
                        ? '측정중... $progressPercent%'
                        : AppStrings.measurementComplete,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
