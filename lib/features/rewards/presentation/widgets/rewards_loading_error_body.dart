import 'package:flutter/material.dart';
import 'package:dramereel_mobile/app/i18n.dart';

class RewardsLoadingErrorBody extends StatelessWidget {
  const RewardsLoadingErrorBody({
    super.key,
    required this.loading,
    required this.configLoaded,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final bool configLoaded;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (configLoaded == false && loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (error != null) {
      return SizedBox(
        height: 220,
        child: _ErrorState(onRetry: onRetry),
      );
    }

    return const SizedBox.shrink();
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.t('request_failed'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.90),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.90),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(t.t('retry')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
