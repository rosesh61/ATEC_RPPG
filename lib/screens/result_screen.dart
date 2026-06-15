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
            '스트레스 단계',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            child: CustomPaint(
              painter: _StressGradientPainter(result.stressIndex),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 6),
          // 구간 레이블 — 너비 비율을 구간 크기(30/30/20/20)에 맞춤
          Row(
            children: const [
              Expanded(flex: 30, child: Text('낮음',    textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF5AAD77), fontSize: 11, fontWeight: FontWeight.w600))),
              Expanded(flex: 30, child: Text('보통',    textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFA8C45A), fontSize: 11, fontWeight: FontWeight.w600))),
              Expanded(flex: 20, child: Text('높음',    textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFE8B84B), fontSize: 11, fontWeight: FontWeight.w600))),
              Expanded(flex: 20, child: Text('매우 높음', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFEF5350), fontSize: 11, fontWeight: FontWeight.w600))),
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

class _StressGradientPainter extends CustomPainter {
  final double stressIndex;
  const _StressGradientPainter(this.stressIndex);

  @override
  void paint(Canvas canvas, Size size) {
    const barH   = 16.0;
    const triH   = 14.0;
    const barTop = triH + 4.0;

    final barRect  = Rect.fromLTWH(0, barTop, size.width, barH);
    final barRRect = RRect.fromRectAndRadius(barRect, const Radius.circular(barH / 2));

    // 초록 → 연두 → 노랑 → 주황 → 빨강
    const gradient = LinearGradient(
      colors: [
        Color(0xFF43A047), // 녹색
        Color(0xFF8BC34A), // 연두
        Color(0xFFFFEB3B), // 노랑
        Color(0xFFFF9800), // 주황
        Color(0xFFF44336), // 빨강
      ],
      stops: [0.0, 0.30, 0.55, 0.75, 1.0],
    );

    canvas.drawRRect(barRRect, Paint()..shader = gradient.createShader(barRect));

    // 삼각형 인디케이터 ▼ — 끝점이 바 상단에 닿음
    final ix = (stressIndex / 100).clamp(0.04, 0.96) * size.width;
    final tri = Path()
      ..moveTo(ix, barTop)
      ..lineTo(ix - 8, barTop - triH)
      ..lineTo(ix + 8, barTop - triH)
      ..close();

    canvas.drawPath(tri, Paint()..color = Colors.white);
    canvas.drawPath(tri,
      Paint()
        ..color = Colors.grey.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_StressGradientPainter old) => old.stressIndex != stressIndex;
}
