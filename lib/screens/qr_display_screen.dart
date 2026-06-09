import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/shared_api_service.dart';
import '../services/user_session.dart';
import '../utils/constants.dart';

class QrDisplayScreen extends StatefulWidget {
  const QrDisplayScreen({super.key});

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  String? _token;
  String? _qrData;
  int _secondsLeft = 0;
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _generateToken();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateToken() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _token = null;
      _qrData = null;
    });
    _countdownTimer?.cancel();

    String? serverId = UserSession.instance.currentUser?.serverId;

    // serverId가 없으면 서버에서 이름으로 찾아 연결 시도
    if (serverId == null) {
      final name = UserSession.instance.currentUser?.name;
      if (name != null) {
        final serverData = await SharedApiService.instance.findUserByName(name);
        serverId = serverData?['user_id'] as String?;
        if (serverId != null) {
          final updated = UserSession.instance.currentUser!.copyWith(serverId: serverId);
          await UserSession.instance.update(updated);
        }
      }
    }

    // serverId가 없으면 서버에 새로 등록
    if (serverId == null) {
      final user = UserSession.instance.currentUser!;
      final newServerId = await SharedApiService.instance.createUser(
        name: user.name,
        phone: user.phone,
      );
      if (newServerId != null) {
        final updated = user.copyWith(serverId: newServerId);
        await UserSession.instance.update(updated);
        serverId = newServerId;
      }
    }

    if (serverId == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    const expiresMinutes = 5;
    final token =
        await SharedApiService.instance.generateQrToken(serverId, expiresMinutes: expiresMinutes);

    if (!mounted) return;

    if (token == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    // QR에는 서버 주소 + 토큰을 포함한 딥링크 형태로 저장
    final baseUrl = await SharedApiService.instance.baseUrl;
    final qrData = '$baseUrl/users/qr-login?token=$token';

    setState(() {
      _token = token;
      _qrData = qrData;
      _isLoading = false;
      _secondsLeft = expiresMinutes * 60;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        setState(() {
          _token = null;
          _qrData = null;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'QR 로그인',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(color: AppColors.secondary),
                const SizedBox(height: 16),
                const Text(
                  'QR 코드를 생성하고 있어요...',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ] else if (_hasError) ...[
                _buildErrorState(),
              ] else if (_qrData == null) ...[
                _buildExpiredState(),
              ] else ...[
                _buildQrState(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoServerIdState() {
    return Column(
      children: [
        const Icon(Icons.cloud_off, color: AppColors.textSecondary, size: 64),
        const SizedBox(height: 16),
        const Text(
          '서버에 연결되지 않은 계정입니다',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          '서버가 실행 중인지 확인 후\n다시 시도해주세요',
          style: TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _generateToken,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: AppColors.primaryDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 64),
        const SizedBox(height: 16),
        const Text(
          '서버에 연결할 수 없어요',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '서버가 실행 중인지 확인해주세요',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _generateToken,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: AppColors.primaryDark,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildExpiredState() {
    return Column(
      children: [
        const Icon(Icons.timer_off, color: AppColors.warning, size: 64),
        const SizedBox(height: 16),
        const Text(
          'QR 코드가 만료되었습니다',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _generateToken,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: AppColors.primaryDark,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('새 QR 생성', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildQrState() {
    final timeColor = _secondsLeft < 60 ? AppColors.error : AppColors.success;

    return Column(
      children: [
        const Text(
          '키오스크에서 이 QR을 스캔하세요',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${UserSession.instance.currentUser?.name ?? ''}님의 QR 코드',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 24),

        // QR 코드
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryLight.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: QrImageView(
            data: _qrData!,
            version: QrVersions.auto,
            size: 220,
            backgroundColor: Colors.white,
          ),
        ),

        const SizedBox(height: 24),

        // 유효시간 카운트다운
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: timeColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: timeColor.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer, color: timeColor, size: 18),
              const SizedBox(width: 8),
              Text(
                '유효시간: ${_formatTime(_secondsLeft)}',
                style: TextStyle(
                  color: timeColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        TextButton(
          onPressed: _generateToken,
          child: const Text(
            '새 QR 생성',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
