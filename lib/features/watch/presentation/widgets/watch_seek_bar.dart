import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as media_kit_pkg;

class WatchSeekBar extends StatelessWidget {
  const WatchSeekBar({
    super.key,
    required this.player,
    required this.activeColor,
    required this.inactiveColor,
  });

  final media_kit_pkg.Player player; // Diubah dari BetterPlayerController ke media_kit Player
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<media_kit_pkg.PlayerState>(
      stream: player.stream,
      builder: (context, snapshot) {
        final state = snapshot.data ?? player.state;
        final position = state.position;
        final duration = state.duration;

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
