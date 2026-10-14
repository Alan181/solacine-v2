import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dramereel_mobile/app/i18n.dart';

class WatchSwipeGuideOverlay extends StatelessWidget {
  const WatchSwipeGuideOverlay({
    super.key,
    required this.showSwipeGuide,
    required this.bottomPad,
    required this.guideShakeAnimation,
    required this.onDismiss,
  });

  final bool showSwipeGuide;
  final double bottomPad;
  final Animation<double> guideShakeAnimation;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (!showSwipeGuide) return const SizedBox.shrink();
    final t = AppI18n.of(context);

    return Positioned.fill(
      child: GestureDetector(
        onTap: onDismiss,
        behavior: HitTestBehavior.opaque,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPad + 92),
            child: AnimatedBuilder(
              animation: guideShakeAnimation,
              builder: (context, child) {
                final s = math.sin(guideShakeAnimation.value * math.pi * 2);
                return Transform.translate(offset: Offset(0, s * 10), child: child);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/player_guide.webp',
                    width: 220,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.t('swipe_up'),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
