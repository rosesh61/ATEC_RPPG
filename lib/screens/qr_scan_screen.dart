import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/shared_api_service.dart';
import '../services/sync_service.dart';
import '../services/user_session.dart';
import '../utils/constants.dart';
import 'home_screen.dart';

/// 키오스크 QR을 스캔해서 서버 주소 자동 저장 + 로그인
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _scanner = MobileScannerController();
  bool _processing = false;
  String? _statusMessage;
  bool _hasError = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() {
      _processing = true;
      _statusMessage = '인증 중...';
      _hasError = false;
    });

    await _scanner.stop();

    // URL 파싱: http://{ip}:8000/users/qr-login?token=xxxx
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.path.endsWith('/qr-login')) {
      _setError('올바른 키오스크 QR이 아닙니다');
      return;
    }

    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) {
      _setError('토큰을 찾을 수 없습니다');
      return;
    }

    // 서버 주소 자동 추출 및 저장 (http://ip:8000)
    final serverUrl = '${uri.scheme}://${uri.host}:${uri.port}';
    await SharedApiService.instance.setBaseUrl(serverUrl);

    // 새 서버 주소로 미동기화 데이터 업로드 (백그라운드)
    SyncService.instance.syncAll();

    // QR 토큰으로 로그인
    final userData = await SharedApiService.instance.loginWithQrToken(token);
    if (userData == null) {
      _setError('QR이 만료되었거나 유효하지 않습니다');
      return;
    }

    // 토큰 무효화
    final serverId = userData['user_id'] as String;
    await SharedApiService.instance.invalidateQrToken(serverId);

    // UserSession에 로그인 처리
    final info = userData['user_info'] as Map<String, dynamic>;
    final user = await UserSession.instance.loginByName(
      info['name'] as String? ?? '',
    );

    if (!mounted) return;

    if (user == null) {
      _setError('사용자 정보를 불러올 수 없습니다');
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _statusMessage = msg;
      _hasError = true;
      _processing = false;
    });
    // 2초 후 스캐너 재시작
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _statusMessage = null;
        _hasError = false;
      });
      _scanner.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'QR 스캔',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          // 카메라 뷰
          MobileScanner(
            controller: _scanner,
            onDetect: _onDetect,
          ),

          // 가이드 오버레이
          CustomPaint(
            painter: _ScanOverlayPainter(),
            child: const SizedBox.expand(),
          ),

          // 상단 안내 텍스트
          Positioned(
            top: 32,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '키오스크 화면의 QR 코드를 스캔하세요',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 상태 메시지
          if (_statusMessage != null)
            Positioned(
              bottom: 80,
              left: 32,
              right: 32,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: _hasError
                      ? AppColors.error.withOpacity(0.9)
                      : AppColors.primaryLight.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_processing && !_hasError)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(
                        _hasError ? Icons.error_outline : Icons.check_circle,
                        color: Colors.white,
                        size: 18,
                      ),
                    const SizedBox(width: 10),
                    Text(
                      _statusMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
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

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.55);
    const boxSize = 260.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final left = cx - boxSize / 2;
    final top = cy - boxSize / 2;
    final scanRect = Rect.fromLTWH(left, top, boxSize, boxSize);

    // 어두운 배경 (스캔 영역 제외)
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dimPaint);

    // 코너 라인
    final cornerPaint = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const cLen = 28.0;
    const r = 16.0;

    // 좌상
    canvas.drawLine(Offset(left + r, top), Offset(left + r + cLen, top), cornerPaint);
    canvas.drawLine(Offset(left, top + r), Offset(left, top + r + cLen), cornerPaint);
    // 우상
    canvas.drawLine(Offset(left + boxSize - r, top), Offset(left + boxSize - r - cLen, top), cornerPaint);
    canvas.drawLine(Offset(left + boxSize, top + r), Offset(left + boxSize, top + r + cLen), cornerPaint);
    // 좌하
    canvas.drawLine(Offset(left + r, top + boxSize), Offset(left + r + cLen, top + boxSize), cornerPaint);
    canvas.drawLine(Offset(left, top + boxSize - r), Offset(left, top + boxSize - r - cLen), cornerPaint);
    // 우하
    canvas.drawLine(Offset(left + boxSize - r, top + boxSize), Offset(left + boxSize - r - cLen, top + boxSize), cornerPaint);
    canvas.drawLine(Offset(left + boxSize, top + boxSize - r), Offset(left + boxSize, top + boxSize - r - cLen), cornerPaint);
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter _) => false;
}
