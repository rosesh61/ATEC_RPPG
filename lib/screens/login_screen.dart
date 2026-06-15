import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/face_recognition_service.dart';
import '../services/user_session.dart';
import '../utils/constants.dart';
import '../widgets/avatar_widget.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _faceProcessing = false;
  String _faceStatus = '카메라를 얼굴에 맞춰주세요';
  bool _faceSuccess = false;
  Timer? _faceTimer;

  static const int _voteThresh = 3;
  int _matchVotes = 0;
  int _noMatchVotes = 0;

  @override
  void initState() {
    super.initState();
    FaceRecognitionService.instance.initialize().catchError((_) {});
    _initCamera();
  }

  @override
  void dispose() {
    _faceTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
      _startFaceTimer();
    } catch (e) {
      if (mounted) {
        setState(() => _faceStatus = '카메라를 사용할 수 없습니다: $e');
      }
    }
  }

  void _startFaceTimer() {
    _faceTimer?.cancel();
    _faceTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      _processFaceFrame();
    });
  }

  Future<void> _processFaceFrame() async {
    if (_faceProcessing || _faceSuccess) return;
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    _faceProcessing = true;
    try {
      final xFile = await ctrl.takePicture();
      final bytes = await xFile.readAsBytes();

      if (!FaceRecognitionService.instance.isInitialized) {
        if (mounted) setState(() => _faceStatus = '얼굴 인식 모델 로딩 중...');
        return;
      }

      final descriptor =
          await FaceRecognitionService.instance.extractDescriptorFromJpeg(bytes);

      if (descriptor == null) {
        _matchVotes = 0;
        _noMatchVotes++;
        if (mounted) setState(() => _faceStatus = '얼굴을 인식하지 못했어요. 정면을 봐주세요.');
        return;
      }

      if (mounted) setState(() => _faceStatus = '얼굴 확인 중...');

      final serverData = await UserSession.instance.loginByFace(descriptor);

      if (serverData != null) {
        _matchVotes++;
        _noMatchVotes = 0;
        if (_matchVotes >= _voteThresh) {
          setState(() {
            _faceSuccess = true;
            _faceStatus = '안녕하세요, ${serverData.name}님!';
          });
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) _navigateHome();
        } else {
          if (mounted) setState(() => _faceStatus = '잠시 유지해주세요...');
        }
      } else {
        _matchVotes = 0;
        _noMatchVotes++;
        if (_noMatchVotes >= _voteThresh) {
          if (mounted) setState(() => _faceStatus = '등록되지 않은 얼굴이에요.');
        } else {
          if (mounted) setState(() => _faceStatus = '얼굴을 정면으로 맞춰주세요.');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _faceStatus = '오류가 발생했습니다. 다시 시도해주세요.');
    } finally {
      _faceProcessing = false;
    }
  }

  void _navigateHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          _buildBg(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                AvatarWidget(
                  size: 90,
                  message: _faceSuccess
                      ? '반갑습니다! 🌿'
                      : '카메라를 얼굴에\n맞춰주세요 😊',
                  isAnimating: true,
                ),
                const SizedBox(height: 16),
                // 카메라 프리뷰
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _cameraReady && _cameraController != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                CameraPreview(_cameraController!),
                                CustomPaint(
                                    painter: _CircleGuidePainter(
                                        success: _faceSuccess)),
                              ],
                            )
                          : Container(
                              color: AppColors.glassWhite,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(
                                        color: AppColors.secondary),
                                    const SizedBox(height: 12),
                                    Text(
                                      '카메라 초기화 중...',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 상태 메시지 — 고정 높이로 카메라 영역 크기 변화 방지
                SizedBox(
                  height: 48,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _faceStatus,
                      key: ValueKey(_faceStatus),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        color: _faceSuccess
                            ? AppColors.secondary
                            : AppColors.textSecondary,
                        fontSize: 15,
                        fontWeight:
                            _faceSuccess ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('← 돌아가기',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14)),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBg() {
    return Positioned(
      top: -100,
      left: -100,
      child: Container(
        width: 400,
        height: 400,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            AppColors.primaryLight.withOpacity(0.13),
            Colors.transparent,
          ]),
        ),
      ),
    );
  }
}

class _CircleGuidePainter extends CustomPainter {
  final bool success;
  const _CircleGuidePainter({required this.success});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.45;
    final r = size.width * 0.40;

    final paint = Paint()
      ..color = success
          ? const Color(0xFF4CAF50).withOpacity(0.85)
          : Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(Offset(cx, cy), r, paint);
  }

  @override
  bool shouldRepaint(_CircleGuidePainter old) => old.success != success;
}
