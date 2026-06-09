import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../services/face_recognition_service.dart';
import '../services/user_session.dart';
import '../utils/constants.dart';
import '../widgets/avatar_widget.dart';
import 'home_screen.dart';

// 지역 목록
const _regions = [
  '서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종',
  '경기', '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주',
];

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedGender;
  String? _selectedRegion;

  // 얼굴 등록
  int _step = 0;
  bool _consentFace = false;
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _faceCapturing = false;
  List<double>? _capturedDescriptor;
  String _faceStatus = '버튼을 눌러 얼굴을 촬영하세요';

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _birthYearController.dispose();
    _phoneController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _onInfoSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('성별을 선택해주세요'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_selectedRegion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지역을 선택해주세요'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _step = 1);
    FaceRecognitionService.instance.initialize().catchError((_) {});
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) setState(() => _faceStatus = '카메라 초기화 실패: $e');
    }
  }

  Future<void> _captureFace() async {
    if (_faceCapturing || _cameraController == null) return;
    setState(() {
      _faceCapturing = true;
      _faceStatus = '촬영 중...';
    });
    try {
      final xFile = await _cameraController!.takePicture();
      final bytes = await xFile.readAsBytes();
      final descriptor = await FaceRecognitionService.instance.extractDescriptorFromJpeg(bytes);
      if (descriptor != null) {
        setState(() {
          _capturedDescriptor = descriptor;
          _faceStatus = '얼굴 등록 완료! 저장 버튼을 눌러주세요.';
        });
      } else {
        setState(() => _faceStatus = '얼굴을 인식하지 못했어요. 다시 시도해주세요.');
      }
    } catch (e, st) {
      print('[_captureFace] 예외: $e\n$st');
      setState(() => _faceStatus = '촬영 중 오류가 발생했습니다.');
    } finally {
      setState(() => _faceCapturing = false);
    }
  }

  Future<void> _submit() async {
    if (_consentFace && _capturedDescriptor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('얼굴 촬영을 완료해주세요.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    final user = User(
      name: _nameController.text.trim(),
      birthYear: int.tryParse(_birthYearController.text.trim()),
      gender: _selectedGender,
      region: _selectedRegion,
      phone: _phoneController.text.trim(),
    );

    await UserSession.instance.register(
      user,
      faceDescriptor: _consentFace ? _capturedDescriptor : null,
    );

    if (!mounted) return;
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
          SafeArea(child: _step == 0 ? _buildInfoStep() : _buildFaceStep()),
        ],
      ),
    );
  }

  // ── Step 0: 정보 입력 ──
  Widget _buildInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Center(
              child: AvatarWidget(
                size: 110,
                message: '반갑습니다! 🌿\n정보를 입력하면\n바로 시작할 수 있어요.',
                isAnimating: true,
              ),
            ),
            const SizedBox(height: 36),
            const Text(
              '처음 오셨군요!\n반갑습니다 😊',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '아래 정보를 모두 입력해주세요',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 36),

            // 이름
            _buildLabel('이름'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 17),
              decoration: _inputDeco(hint: '이름을 입력해주세요', icon: Icons.person_outline),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '이름을 입력해주세요';
                if (v.trim().length < 2) return '이름은 2자 이상 입력해주세요';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // 생년
            _buildLabel('생년 (출생연도)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _birthYearController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 17),
              decoration: _inputDeco(hint: '예) 1990', icon: Icons.cake_outlined),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '생년을 입력해주세요';
                final year = int.tryParse(v.trim());
                final currentYear = DateTime.now().year;
                if (year == null || year < 1900 || year > currentYear) {
                  return '올바른 출생연도를 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // 성별
            _buildLabel('성별'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _genderButton('남성', 'M'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _genderButton('여성', 'F'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 지역
            _buildLabel('지역'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedRegion,
              dropdownColor: AppColors.primaryDark,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 17),
              decoration: _inputDeco(hint: '지역을 선택해주세요', icon: Icons.location_on_outlined),
              items: _regions.map((r) => DropdownMenuItem(
                value: r,
                child: Text(r, style: const TextStyle(color: AppColors.textPrimary)),
              )).toList(),
              onChanged: (v) => setState(() => _selectedRegion = v),
              validator: (v) => v == null ? '지역을 선택해주세요' : null,
            ),
            const SizedBox(height: 20),

            // 전화번호
            _buildLabel('전화번호'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 17),
              decoration: _inputDeco(hint: '010-0000-0000', icon: Icons.phone_outlined),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                LengthLimitingTextInputFormatter(13),
              ],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _onInfoSubmit(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '전화번호를 입력해주세요';
                return null;
              },
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: _onInfoSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('다음', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('← 돌아가기',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _genderButton(String label, String value) {
    final selected = _selectedGender == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = value),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: selected ? AppColors.secondary : AppColors.glassWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.secondary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primaryDark : AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1: 얼굴 등록 ──
  Widget _buildFaceStep() {
    if (_consentFace && !_cameraReady && _cameraController == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Center(
            child: AvatarWidget(
              size: 90,
              message: _capturedDescriptor != null
                  ? '얼굴 등록 완료! 🎉'
                  : '얼굴 인식 로그인을\n등록할 수 있어요 😊',
              isAnimating: true,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '얼굴 인식 등록',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            '얼굴을 등록하면 다음부터 얼굴로\n빠르게 로그인할 수 있어요. (선택사항)',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),

          GestureDetector(
            onTap: () {
              setState(() {
                _consentFace = !_consentFace;
                if (!_consentFace) {
                  _capturedDescriptor = null;
                  _cameraController?.dispose();
                  _cameraController = null;
                  _cameraReady = false;
                  _faceStatus = '버튼을 눌러 얼굴을 촬영하세요';
                }
              });
            },
            child: Row(
              children: [
                Checkbox(
                  value: _consentFace,
                  onChanged: (v) {
                    setState(() {
                      _consentFace = v ?? false;
                      if (!_consentFace) {
                        _capturedDescriptor = null;
                        _cameraController?.dispose();
                        _cameraController = null;
                        _cameraReady = false;
                        _faceStatus = '버튼을 눌러 얼굴을 촬영하세요';
                      }
                    });
                  },
                  activeColor: AppColors.secondary,
                  checkColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.textSecondary),
                ),
                const Expanded(
                  child: Text(
                    '얼굴 정보 수집 및 이용에 동의합니다',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_consentFace) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: _cameraReady && _cameraController != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(_cameraController!),
                          CustomPaint(
                            painter: _OvalGuidePainter(success: _capturedDescriptor != null),
                          ),
                        ],
                      )
                    : Container(
                        color: AppColors.glassWhite,
                        child: const Center(
                          child: CircularProgressIndicator(color: AppColors.secondary),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _faceStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _capturedDescriptor != null ? AppColors.secondary : AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _faceCapturing ? null : _captureFace,
                icon: _faceCapturing
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary),
                      )
                    : const Icon(Icons.camera_alt_outlined, color: AppColors.secondary),
                label: Text(
                  _capturedDescriptor != null ? '다시 촬영' : '얼굴 촬영',
                  style: const TextStyle(color: AppColors.secondary, fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.secondary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.primaryDark,
                disabledBackgroundColor: AppColors.secondary.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(color: AppColors.primaryDark, strokeWidth: 2.5),
                    )
                  : const Text('등록하고 시작하기',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _step = 0),
              child: const Text('← 이전으로',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        const Text('*', style: TextStyle(color: AppColors.secondary, fontSize: 15)),
      ],
    );
  }

  InputDecoration _inputDeco({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.6), fontSize: 15),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 22),
      filled: true,
      fillColor: AppColors.glassWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 2)),
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 13),
    );
  }

  Widget _buildBg() {
    return Stack(
      children: [
        Positioned(
          top: -100, left: -100,
          child: Container(
            width: 400, height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.primaryLight.withOpacity(0.13),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(
          bottom: -60, right: -60,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.secondary.withOpacity(0.08),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _OvalGuidePainter extends CustomPainter {
  final bool success;
  const _OvalGuidePainter({required this.success});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = success ? const Color(0xFF4CAF50).withOpacity(0.85) : Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.42),
        width: size.width * 0.76,
        height: size.height * 0.60,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_OvalGuidePainter old) => old.success != success;
}
