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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── 탭 ──
  late final TabController _tabController;

  // ── 이름 로그인 ──
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // ── 얼굴 로그인 ──
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _faceProcessing = false;
  String _faceStatus = '카메라를 얼굴에 맞춰주세요';
  bool _faceSuccess = false;
  Timer? _faceTimer;

  // 연속 매칭 투표 (false positive 방지)
  static const int _voteThresh = 3;
  int _matchVotes = 0;
  int _noMatchVotes = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_cameraReady) {
        _initCamera();
      } else if (_tabController.index == 0) {
        _stopFaceLogin();
      }
    });
    FaceRecognitionService.instance.initialize().catchError((_) {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _faceTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  // ── 이름 로그인 ──────────────────────────────────────
  Future<void> _login() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = '이름을 입력해주세요');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = await UserSession.instance.loginByName(name);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user != null) {
      _navigateHome();
    } else {
      setState(() => _errorMessage = '등록된 이름을 찾을 수 없어요.\n새로 등록해주세요.');
    }
  }

  // ── 얼굴 로그인 ──────────────────────────────────────
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

  void _stopFaceLogin() {
    _faceTimer?.cancel();
    _cameraController?.dispose();
    _cameraController = null;
    if (mounted) {
      setState(() {
        _cameraReady = false;
        _faceStatus = '카메라를 얼굴에 맞춰주세요';
        _faceSuccess = false;
        _matchVotes = 0;
        _noMatchVotes = 0;
      });
    }
  }

  Future<void> _processFaceFrame() async {
    if (_faceProcessing || _faceSuccess) return;
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized || !ctrl.value.isStreamingImages) {
      // 스트리밍 없이 단일 프레임 캡처
      await _processFromCapture();
      return;
    }
    // 스트리밍 중이면 단일 캡처 방식 사용
    await _processFromCapture();
  }

  Future<void> _processFromCapture() async {
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
          if (mounted) setState(() => _faceStatus = '등록되지 않은 얼굴이에요. 이름으로 로그인해주세요.');
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

  // ── UI ──────────────────────────────────────────────
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
                // 아바타
                AvatarWidget(
                  size: 90,
                  message: _tabController.index == 1
                      ? (_faceSuccess
                          ? '반갑습니다! 🌿'
                          : '카메라를 얼굴에\n맞춰주세요 😊')
                      : (_errorMessage != null
                          ? '이름을 다시 확인해주세요 😊'
                          : '등록하신 이름을\n입력해주세요! 🌿'),
                  isAnimating: true,
                ),
                const SizedBox(height: 16),
                const Text(
                  '반갑습니다!',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                // 탭바
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    color: AppColors.glassWhite,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.primaryDark,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    tabs: const [
                      Tab(text: '이름으로 로그인'),
                      Tab(text: '얼굴 인식'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 탭 본문
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildNameTab(),
                      _buildFaceTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style:
                const TextStyle(color: AppColors.textPrimary, fontSize: 18),
            decoration: InputDecoration(
              hintText: '이름 입력',
              hintStyle:
                  TextStyle(color: AppColors.textSecondary.withOpacity(0.6)),
              prefixIcon: const Icon(Icons.person_outline,
                  color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.glassWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.secondary, width: 2),
              ),
              errorText: _errorMessage,
              errorStyle: const TextStyle(color: AppColors.error),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.primaryDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primaryDark,
                      ),
                    )
                  : const Text('로그인',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('← 돌아가기',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // 카메라 프리뷰 (화면 높이에 맞게 유연하게)
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _cameraReady && _cameraController != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_cameraController!),
                        // 타원 가이드
                        CustomPaint(painter: _OvalGuidePainter(success: _faceSuccess)),
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
          const SizedBox(height: 12),
          // 상태 메시지
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _faceStatus,
              key: ValueKey(_faceStatus),
              textAlign: TextAlign.center,
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
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('← 돌아가기',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
          ),
          const SizedBox(height: 8),
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

class _OvalGuidePainter extends CustomPainter {
  final bool success;
  const _OvalGuidePainter({required this.success});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.42;
    final rx = size.width * 0.38;
    final ry = size.height * 0.30;

    final paint = Paint()
      ..color = success
          ? const Color(0xFF4CAF50).withOpacity(0.85)
          : Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawOval(Rect.fromCenter(
        center: Offset(cx, cy), width: rx * 2, height: ry * 2), paint);
  }

  @override
  bool shouldRepaint(_OvalGuidePainter old) => old.success != success;
}
