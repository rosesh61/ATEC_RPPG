import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/avatar_widget.dart';
import 'member_check_screen.dart';

class StorytellingScreen extends StatefulWidget {
  const StorytellingScreen({super.key});

  @override
  State<StorytellingScreen> createState() => _StorytellingScreenState();
}

class _StorytellingScreenState extends State<StorytellingScreen> {
  int _currentPage = 0;

  final List<_StoryPage> _pages = const [
    _StoryPage(
      emoji: '📱',
      avatarMessage: '처음 오셨군요!\n천천히 안내해드릴게요 😊',
      title: '처음 사용해보시는 건가요?',
      description: '걱정 마세요!\n이 앱은 아주 간단하게\n건강을 확인할 수 있어요.',
    ),
    _StoryPage(
      emoji: '📷',
      avatarMessage: '카메라로 얼굴만\n보여주시면 돼요! 🌿',
      title: '카메라로 간단하게',
      description: '손을 대지 않아도 돼요.\n카메라 앞에 얼굴만 보여주면\n심박수를 잴 수 있어요.',
    ),
    _StoryPage(
      emoji: '💓',
      avatarMessage: '심박수, HRV, 스트레스\n한 번에 확인해요! 😊',
      title: '건강 정보를 한눈에',
      description: '심박수와 스트레스 정도를\n쉬운 그래프와\n이모티콘으로 알려드려요.',
    ),
    _StoryPage(
      emoji: '📋',
      avatarMessage: '오늘 힘든 일을\n기록해두면 도움이 돼요 🍃',
      title: '원인도 기록해요',
      description: '측정 후 오늘 있었던 일을\n기록하면 건강 변화를\n더 잘 파악할 수 있어요.',
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      setState(() => _currentPage++);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MemberCheckScreen()),
      );
    }
  }

  void _skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MemberCheckScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          _buildBg(),
          SafeArea(
            child: Column(
              children: [
                // 상단 스킵 버튼
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 페이지 인디케이터
                      Row(
                        children: List.generate(
                          _pages.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _currentPage ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _currentPage
                                  ? AppColors.secondary
                                  : AppColors.glassBorder,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _skip,
                        child: const Text(
                          '건너뛰기',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _buildPageContent(page),
                  ),
                ),

                // 하단 버튼
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: AppColors.primaryDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage < _pages.length - 1 ? '다음' : '시작하기',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  Widget _buildPageContent(_StoryPage page) {
    return Padding(
      key: ValueKey(_currentPage),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AvatarWidget(
            size: 120,
            message: page.avatarMessage,
            isAnimating: true,
          ),
          const SizedBox(height: 32),

          // 이모티콘
          Text(page.emoji, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 20),

          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBg() {
    return Stack(
      children: [
        Positioned(
          top: -80,
          left: -80,
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
        ),
        Positioned(
          bottom: -60,
          right: -60,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.secondary.withOpacity(0.09),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryPage {
  final String emoji;
  final String avatarMessage;
  final String title;
  final String description;

  const _StoryPage({
    required this.emoji,
    required this.avatarMessage,
    required this.title,
    required this.description,
  });
}
