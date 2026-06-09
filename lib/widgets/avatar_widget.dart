import 'package:flutter/material.dart';
import '../utils/constants.dart';

class AvatarWidget extends StatefulWidget {
  final double size;
  final String message;
  final bool isAnimating;

  const AvatarWidget({
    super.key,
    this.size = 120,
    required this.message,
    this.isAnimating = false,
  });

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _breatheAnim;
  late Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _breatheAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _ringAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // 외부 링 (말할 때 펄스)
                if (widget.isAnimating)
                  Container(
                    width: widget.size + 28,
                    height: widget.size + 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryLight
                            .withOpacity(_ringAnim.value * 0.55),
                        width: 2.5,
                      ),
                    ),
                  ),
                // 아바타 원
                Transform.scale(
                  scale: _breatheAnim.value,
                  child: child!,
                ),
              ],
            );
          },
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.3),
                colors: [
                  AppColors.primaryLight,
                  AppColors.primaryDark,
                ],
              ),
              border: Border.all(
                color: AppColors.textSecondary.withOpacity(0.4),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryLight.withOpacity(0.25),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Text('🌿', style: TextStyle(fontSize: 44)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 말풍선
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Text(
            widget.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
