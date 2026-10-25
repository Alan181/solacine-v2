import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solacine_mobile/app/i18n.dart';
import 'package:solacine_mobile/shared/widgets/app_cached_image.dart';

class WatchNoEpisodesBody extends StatelessWidget {
  const WatchNoEpisodesBody({
    super.key,
    required this.bg,
    required this.topPad,
    required this.onSafePopOrHome,
  });

  final String bg;
  final double topPad;
  final VoidCallback onSafePopOrHome;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);

    return PopScope(
      canPop: GoRouter.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        onSafePopOrHome();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (bg.isNotEmpty)
              AppCachedImage(
                imageUrl: bg,
                fit: BoxFit.cover,
                errorWidget: (_) => Container(color: const Color(0xff0b0b0b)),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xff0b0b0b),
                      Colors.black,
                    ],
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
            PositionedDirectional(
              top: topPad + 10,
              start: 12,
              end: 12,
              child: Row(
                children: [
                  const Spacer(),
                  InkWell(
                    onTap: onSafePopOrHome,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.t('no_episodes'),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontWeight: FontWeight.w500, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.t('no_episodes_desc'),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontWeight: FontWeight.w500, fontSize: 12),
                      textAlign: TextAlign.center,
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
}
