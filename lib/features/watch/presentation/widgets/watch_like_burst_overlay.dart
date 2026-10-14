import 'package:flutter/material.dart';

class WatchLikeBurstOverlay extends StatelessWidget {
  const WatchLikeBurstOverlay({
    super.key,
    required this.showLikeBurst,
    required this.isActive,
    required this.likeBurstPos,
    required this.likeBurstAnimation,
    required this.likeBurstScale,
    required this.likeBurstOpacity,
  });

  final bool showLikeBurst;
  final bool isActive;
  final Offset likeBurstPos;
  final Animation<double> likeBurstAnimation;
  final double Function(double t) likeBurstScale;
  final double Function(double t) likeBurstOpacity;

  @override
  Widget build(BuildContext context) {
    if (!showLikeBurst || !isActive) return const SizedBox.shrink();

    return Positioned(
      left: likeBurstPos.dx - 44,
      top: likeBurstPos.dy - 44,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: likeBurstAnimation,
          builder: (context, _) {
            final t = likeBurstAnimation.value;
            final s = likeBurstScale(t);
            final o = likeBurstOpacity(t);
            return Opacity(
              opacity: o,
              child: Transform.scale(
                scale: s,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 88,
                  color: const Color(0xffef233c).withValues(alpha: 0.92),
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
