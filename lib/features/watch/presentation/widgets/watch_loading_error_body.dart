import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dramereel_mobile/app/i18n.dart';
import 'package:dramereel_mobile/shared/widgets/app_cached_image.dart';

class WatchLoadingErrorBody extends StatelessWidget {
  const WatchLoadingErrorBody({
    super.key,
    required this.isLoading,
    required this.error,
    required this.reelsPreview,
    required this.reelsBackdropUrl,
    required this.errorMessageFor,
    required this.onRetry,
    required this.onSafePopOrHome,
  });

  final bool isLoading;
  final Object? error;
  final bool reelsPreview;
  final String? reelsBackdropUrl;
  final ({String titleKey, String descKey}) Function(Object? error) errorMessageFor;
  final VoidCallback onRetry;
  final VoidCallback onSafePopOrHome;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final bg = (reelsBackdropUrl ?? '').trim();

    if (isLoading) {
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
              if (bg.isNotEmpty) ...[
                AppCachedImage(
                  imageUrl: bg,
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ] else
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xff121212),
                        Colors.black,
                      ],
                    ),
                  ),
                ),
              const Center(
                child: CupertinoActivityIndicator(radius: 14, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    final msg = errorMessageFor(error);
    if (reelsPreview && bg.isNotEmpty) {
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
              AppCachedImage(
                imageUrl: bg,
                fit: BoxFit.cover,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.90),
                    ],
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.t(msg.titleKey),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        t.t(msg.descKey),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                        textAlign: TextAlign.center,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: onRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffef233c),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        child: Text(t.t('retry')),
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
    return PopScope(
      canPop: GoRouter.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        onSafePopOrHome();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.t(msg.titleKey),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  t.t(msg.descKey),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffef233c),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  child: Text(t.t('retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
