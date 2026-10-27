import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as media_kit_pkg;

class WatchSeekBar extends StatelessWidget {
  const WatchSeekBar({
    super.key,
    required this.player,
    required this.activeColor,
    required this.inactiveColor,
  });

  final media_kit_pkg.Player player;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    // Menggunakan StreamBuilder khusus untuk posisi agar lebih efisien & ringan
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? player.state.position;
        final duration = player.state.duration;

        final dur = duration.inMilliseconds;
        final pos = position.inMilliseconds;
        final progressValue = dur <= 0 ? 0.0 : (pos / dur).clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final activeW = w * progressValue;
            final thumbX = (activeW - 5).clamp(0.0, w - 10);

            void seek(Offset local) {
              if (dur <= 0) return;
              final next = (local.dx / w).clamp(0.0, 1.0);
              final targetDuration = Duration(milliseconds: (dur * next).round());
              player.seek(targetDuration);
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
