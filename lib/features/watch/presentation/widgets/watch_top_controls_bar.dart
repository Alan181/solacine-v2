import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dramereel_mobile/app/i18n.dart';

class WatchTopControlsBar extends StatelessWidget {
  const WatchTopControlsBar({
    super.key,
    required this.topPad,
    required this.controlsVisible,
    required this.epNum,
    required this.totalEpisodes,
    required this.onToggleControls,
    required this.onSafePopOrHome,
    this.isUnlocked = true,
  });

  final double topPad;
  final bool controlsVisible;
  final int epNum;
  final int totalEpisodes;
  final VoidCallback onToggleControls;
  final VoidCallback onSafePopOrHome;
  final bool isUnlocked;

  @override
  Widget build(BuildContext context) {
    if (!isUnlocked) {
      return PositionedDirectional(
        top: topPad + 10,
        start: 12,
        child: InkWell(
          onTap: onSafePopOrHome,
          borderRadius: BorderRadius.circular(999),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.26), width: 0.9),
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final t = AppI18n.of(context);

    return PositionedDirectional(
      top: topPad + 10,
      start: 12,
      end: 12,
      child: AnimatedOpacity(
        opacity: controlsVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 180),
        child: IgnorePointer(
          ignoring: !controlsVisible,
          child: Row(
            children: [
              // Modern iOS Frosted Back Button (Leading)
              InkWell(
                onTap: onSafePopOrHome,
                borderRadius: BorderRadius.circular(999),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.26), width: 0.9),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Modern Center Episode Pill (iOS Style)
              Expanded(
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 0.9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6.5,
                              height: 6.5,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE50914),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '${t.t('Episode')} $epNum${totalEpisodes > 0 ? ' / $totalEpisodes' : ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.2,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Fullscreen / Mode Toggle Button (Trailing)
              InkWell(
                onTap: onToggleControls,
                borderRadius: BorderRadius.circular(999),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.26), width: 0.9),
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            controlsVisible ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                            key: ValueKey<bool>(controlsVisible),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
