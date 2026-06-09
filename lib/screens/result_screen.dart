import 'package:flutter/material.dart';
import '../models/measurement_result.dart';
import '../utils/constants.dart';
import 'cause_record_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';

class ResultScreen extends StatelessWidget {
  final MeasurementResult result;

  const ResultScreen({super.key, required this.result});

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
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: Column(
                      children: [
                        // 칭찬/격려 아바타 섹션
                        _buildAvatarSection(),
                        const SizedBox(height: 20),

                        // 메인 스트레스 카드
                        _buildStressCard(),
                        const SizedBox(height: 16),

                        // 심박수 + HRV 카드 (가로)
                        Row(
                          children: [
                            Expanded(child: _buildMetricCard(
                              emoji: '💓',
                              title: '심박수',
                              value: result.heartRate.toStringAsFixed(0),
                              unit: 'BPM',
                              subtitle: _hrInterpretation(result.heartRate),
                              color: const Color(0xFFEF5350),
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _buildMetricCard(
                              emoji: '📊',
                              title: 'HRV',
                              value: result.hrv.toStringAsFixed(1),
                              unit: 'ms',
                              subtitle: result.hrvLevel,
                              color: AppColors.primaryLight,
                            )),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 스트레스 미터
                        _buildStressMeter(),
                        const SizedBox(height: 16),

                        // 분석 설명
                        _buildAnalysisCard(),
                        const SizedBox(height: 24),

                        // 액션 버튼
                        _buildActionButtons(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.textPrimary),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            ),
          ),
          const Text(
            '측정 완료',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            _formatDate(result.timestamp),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    final msgs = result.stressIndex < 30
        ? AvatarMessages.stressLow
        : result.stressIndex < 60
            ? AvatarMessages.stressMid
            : AvatarMessages.stressHigh;
    final msg = msgs[result.timestamp.second % msgs.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [AppColors.primaryLight, AppColors.primaryDark],
              ),
            ),
            child: const Center(
                child: Text('🌿', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '잘 하셨어요! 🎉',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  msg,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStressCard() {
    final color = _stressColor(result.stressIndex);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.7), color.withOpacity(0.4)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          const Text(
            '스트레스 지수',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            result.stressIndex.toStringAsFixed(0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 72,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              result.stressLevel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String emoji,
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: TextStyle(
                      color: color.withOpacity(0.7), fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStressMeter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '스트레스 게이지',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: CustomPaint(
              painter: _StressMeterPainter(result.stressIndex),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('안정', style: TextStyle(color: AppColors.success, fontSize: 11)),
              Text('보통', style: TextStyle(color: AppColors.warning, fontSize: 11)),
              Text('높음', style: TextStyle(color: AppColors.error, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard() {
    String description;
    String recommendation;
    String emoji;

    if (result.stressIndex < 30) {
      description = '스트레스 수준이 낮아요. 현재 상태를 잘 유지하고 계세요! 👏';
      recommendation = '규칙적인 생활 습관을 유지하세요.';
      emoji = '😊';
    } else if (result.stressIndex < 60) {
      description = '스트레스가 보통 수준이에요. 일상적인 스트레스가 감지돼요.';
      recommendation = '충분한 휴식과 가벼운 운동을 권장해요.';
      emoji = '😌';
    } else if (result.stressIndex < 80) {
      description = '스트레스가 조금 높아요. 주의가 필요한 상태예요.';
      recommendation = '명상이나 호흡 운동을 시도해보세요.';
      emoji = '😤';
    } else {
      description = '스트레스가 매우 높아요. 지금 바로 쉬어가세요.';
      recommendation = '충분한 휴식을 취하시고, 필요시 전문가와 상담하세요.';
      emoji = '😰';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              const Text(
                '분석 결과',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.secondary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recommendation,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // 원인 기록하기 (강조)
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CauseRecordScreen()),
            ),
            icon: const Text('📋', style: TextStyle(fontSize: 18)),
            label: const Text(
              '오늘의 원인 기록하기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            // 기록 보기
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('기록 보기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.glassBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 완료
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  '완료',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _stressColor(double index) {
    if (index < 30) return AppColors.success;
    if (index < 60) return AppColors.warning;
    return AppColors.error;
  }

  String _hrInterpretation(double hr) {
    if (hr < 60) return '서맥';
    if (hr < 100) return '정상';
    return '빈맥';
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildBg() {
    return Stack(
      children: [
        Positioned(
          top: -80,
          left: -80,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.primaryLight.withOpacity(0.12),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _StressMeterPainter extends CustomPainter {
  final double stressLevel;
  _StressMeterPainter(this.stressLevel);

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = const LinearGradient(
      colors: [AppColors.success, AppColors.warning, AppColors.error],
      stops: [0.0, 0.5, 1.0],
    );
    final rect = Rect.fromLTWH(0, size.height / 2 - 6, size.width, 12);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)), paint);

    final indicatorX = size.width * (stressLevel / 100);
    canvas.drawCircle(
      Offset(indicatorX, size.height / 2),
      12,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(indicatorX, size.height / 2),
      12,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_StressMeterPainter old) => old.stressLevel != stressLevel;
}
