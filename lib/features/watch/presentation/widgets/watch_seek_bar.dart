import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class WatchSeekBar extends StatelessWidget {
  const WatchSeekBar({
    super.key,
    required this.controller,
    required this.activeColor,
    required this.inactiveColor,
  });

  final VideoPlayerController controller;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final v = controller.value;
        final dur = v.duration.inMilliseconds;
        final pos = v.position.inMilliseconds;
        final value = dur <= 0 ? 0.0 : (pos / dur).clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final activeW = w * value;
            final thumbX = (activeW - 5).clamp(0.0, w - 10);

            void seek(Offset local) {
              if (dur <= 0) return;
              final next = (local.dx / w).clamp(0.0, 1.0);
              controller.seekTo(Duration(milliseconds: (dur * next).round()));
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => seek(d.localPosition),
              onHorizontalDragStart: (d) => seek(d.localPosition),
              onHorizontalDragUpdate: (d) => seek(d.localPosition),
              child: SizedBox(
                height: 22,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Inactive Track
                    Container(
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: inactiveColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    // Active Track
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: activeW,
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: activeColor.withValues(alpha: 0.40),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Scrubber Thumb
                    Positioned(
                      left: thumbX,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: activeColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.50),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
