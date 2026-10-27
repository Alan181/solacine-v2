import 'package:flutter/material.dart';
import 'package:solacine_mobile/app/i18n.dart';

class WatchTitleInfoSection extends StatelessWidget {
  const WatchTitleInfoSection({
    super.key,
    required this.bottomPad,
    required this.genresLine,
    required this.seriesTitle,
    required this.contentRating,
    required this.synopsis,
    required this.reelsPreview,
    required this.ageRatingAsset,
    required this.onOpenSeriesInfo,
    required this.onWatchNow,
    required this.controlsVisible,
  });

  final double bottomPad;
  final String genresLine;
  final String seriesTitle;
  final String contentRating;
  final String synopsis;
  final bool reelsPreview;
  final String Function(String rating) ageRatingAsset;
  final VoidCallback onOpenSeriesInfo;
  final VoidCallback onWatchNow;
  final bool controlsVisible;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    if (reelsPreview) {
      return Positioned(
        right: 14,
        bottom: bottomPad + 18,
        child: SizedBox(
          width: 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpenSeriesInfo,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        seriesTitle,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              if (synopsis.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  synopsis.trim(),
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  debugPrint('[WatchTitleInfoSection] Tombol Tonton Sekarang diklik');
                  onWatchNow();
                },
                child: Container(
                  width: 250,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2E).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t.t('watch_now'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PositionedDirectional(
      start: 14,
      end: 72,
      bottom: bottomPad + 80,
      child: IgnorePointer(
        ignoring: !controlsVisible,
        child: AnimatedOpacity(
          opacity: controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (genresLine.isNotEmpty)
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  alignment: WrapAlignment.start,
                  children: genresLine
                      .split(RegExp(r'[•,]'))
                      .map((g) => g.trim())
                      .where((g) => g.isNotEmpty)
                      .take(3)
                      .map(
                        (g) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                          ),
                          child: Text(
                            '#$g',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 7),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpenSeriesInfo,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        seriesTitle,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16.5,
                          letterSpacing: -0.2,
                          shadows: [
                            Shadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 6, offset: const Offset(0, 1)),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white),
                    if (contentRating.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Image.asset(
                        ageRatingAsset(contentRating),
                        height: 18,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
              if (synopsis.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  synopsis.trim(),
                  textAlign: TextAlign.start,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFB0B0B0),
                    fontWeight: FontWeight.w400,
                    fontSize: 11.5,
                    height: 1.25,
                    shadows: [
                      Shadow(color: Colors.black.withValues(alpha: 0.50), blurRadius: 4, offset: const Offset(0, 1)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
