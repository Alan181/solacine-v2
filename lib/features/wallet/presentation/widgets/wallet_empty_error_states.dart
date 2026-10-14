import 'package:flutter/material.dart';
import '../../../../../app/i18n.dart';

class WalletErrorState extends StatelessWidget {
  const WalletErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          Text(
            t.t('request_failed'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.90),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffef233c),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontWeight: FontWeight.w500),
              ),
              child: Text(t.t('retry')),
            ),
          ),
        ],
      ),
    );
  }
}

class WalletEmptyState extends StatelessWidget {
  const WalletEmptyState({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
      ),
    );
  }
}
