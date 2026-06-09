import 'package:flutter/material.dart';
import '../services/user_session.dart';
import '../utils/constants.dart';
import '../widgets/avatar_widget.dart';
import 'measurement_screen.dart';

class DurationSelectScreen extends StatefulWidget {
  const DurationSelectScreen({super.key});

  @override
  State<DurationSelectScreen> createState() => _DurationSelectScreenState();
}

class _DurationSelectScreenState extends State<DurationSelectScreen> {
  int _selectedSeconds = 45;

  static const _options = [
    _DurationOption(
        label: '45초', seconds: 45, description: '빠른 측정', emoji: '⚡'),
    _DurationOption(
        label: '1분', seconds: 60, description: '기본 측정', emoji: '⏱️'),
    _DurationOption(
        label: '3분', seconds: 180, description: '정밀 측정', emoji: '🎯'),
    _DurationOption(
        label: '5분', seconds: 300, description: '심층 측정', emoji: '🏆'),
  ];

  @override
  Widget build(BuildContext context) {
    final user = UserSession.instance.currentUser;
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          _buildBg(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 앱바
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 아바타
                        Center(
                          child: AvatarWidget(
                            size: 100,
                            message: '측정 시간이 길수록\n더 정확한 결과를 드려요! 🌿',
                            isAnimating: true,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // 타이틀
                        if (user != null)
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                height: 1.4,
                              ),
                              children: [
                                TextSpan(text: '${user.name}님,\n'),
                                const TextSpan(
                                  text: '측정 시간을 선택해주세요',
                                  style: TextStyle(fontSize: 20),
                                ),
                              ],
                            ),
                          )
                        else
                          const Text(
                            '측정 시간을\n선택해주세요',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.4,
                            ),
                          ),
                        const SizedBox(height: 28),

                        // 시간 선택 카드
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.05,
                          children: _options
                              .map((opt) => _buildOptionCard(opt))
                              .toList(),
                        ),
                        const SizedBox(height: 20),

                        // 선택 안내
                        _buildSelectedInfo(),
                        const SizedBox(height: 24),

                        // 시작 버튼
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _startMeasurement,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: AppColors.primaryDark,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_arrow_rounded, size: 28),
                                const SizedBox(width: 8),
                                Text(
                                  '${_selectedLabel()} 측정 시작',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
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

  Widget _buildOptionCard(_DurationOption opt) {
    final isSelected = _selectedSeconds == opt.seconds;
    return GestureDetector(
      onTap: () => setState(() => _selectedSeconds = opt.seconds),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary.withOpacity(0.15)
              : AppColors.glassWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.secondary
                : AppColors.glassBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(opt.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              opt.label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.secondary
                    : AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              opt.description,
              style: TextStyle(
                color: isSelected
                    ? AppColors.secondary.withOpacity(0.8)
                    : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedInfo() {
    final opt = _options.firstWhere((o) => o.seconds == _selectedSeconds);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _infoText(opt.seconds),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startMeasurement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MeasurementScreen(durationSeconds: _selectedSeconds),
      ),
    );
  }

  String _selectedLabel() =>
      _options.firstWhere((o) => o.seconds == _selectedSeconds).label;

  String _infoText(int seconds) {
    switch (seconds) {
      case 45:
        return '최소 측정 시간이에요. 기본적인 심박수와 스트레스 지수를 확인할 수 있어요.';
      case 60:
        return '일반적인 측정 시간이에요. 심박수와 HRV를 안정적으로 측정해요.';
      case 180:
        return '충분한 데이터로 HRV를 정밀하게 분석해요. 더 정확한 스트레스 지수를 확인할 수 있어요.';
      case 300:
        return '가장 정밀한 측정이에요. 안정된 자세로 5분간 측정하면 최고의 정확도를 얻을 수 있어요.';
      default:
        return '';
    }
  }

  Widget _buildBg() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 400,
            height: 400,
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

class _DurationOption {
  final String label;
  final int seconds;
  final String description;
  final String emoji;

  const _DurationOption({
    required this.label,
    required this.seconds,
    required this.description,
    required this.emoji,
  });
}
