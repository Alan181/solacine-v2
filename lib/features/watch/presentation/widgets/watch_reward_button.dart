import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:solacine_mobile/app/i18n.dart';

class WatchRewardButton extends StatelessWidget {
  const WatchRewardButton({
    super.key,
    required this.topPad,
    required this.rewardShakeAnimation,
    required this.progressAnimation, // <-- Ditambahkan: parameter animasi lingkaran progress
    required this.rewardDismissed,
    required this.onTapReward,
    required this.onDismiss,
  });

  final double topPad;
  final Animation<double> rewardShakeAnimation;
  final Animation<double> progressAnimation; // <-- Ditambahkan
  final bool rewardDismissed;
  final VoidCallback onTapReward;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (rewardDismissed) return const SizedBox.shrink();
    final t = AppI18n.of(context);

    return Positioned(
      top: topPad + 86,
      left: 28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                onTap: onTapReward,
                borderRadius: BorderRadius.circular(999),
                child: AnimatedBuilder(
                  // Menggabungkan animasi shake dan progress lingkaran
                  animation: Listenable.merge([rewardShakeAnimation, progressAnimation]),
                  builder: (context, child) {
                    final s = math.sin(rewardShakeAnimation.value * math.pi * 2);
                    return Transform.translate(
                      offset: Offset(s * 2.0, 0),
                      child: Transform.rotate(
                        angle: s * 0.06,
                        child: CustomPaint(
                          painter: RewardProgressPainter(
                            progress: progressAnimation.value,
                            progressColor: Colors.amberAccent,
                            trackColor: Colors.white.withValues(alpha: 0.15),
                            strokeWidth: 3.0,
                          ),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/app_gl_red_ic.png',
                        width: 26,
                        height: 26,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const SizedBox(width: 26, height: 26),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t.t('reward'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.90), fontWeight: FontWeight.w500, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// Painter untuk menggambar lingkaran progress durasi 1 menit
class RewardProgressPainter extends CustomPainter {
  RewardProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color progressColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas sizeCanvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) + (strokeWidth / 2) + 1;

    final trackPaint = Paint()
      .setColor(trackColor)
      .setStyle(PaintingStyle.stroke)
      .setStrokeWidth(strokeWidth)
      .setStrokeCap(StrokeCap.round);

    sizeCanvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      .setColor(progressColor)
      .setStyle(PaintingStyle.stroke)
      .setStrokeWidth(strokeWidth)
      .setStrokeCap(StrokeCap.round);

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    sizeCanvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant RewardProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}
