import 'package:flutter/material.dart';
import '../../../../../app/i18n.dart';

class WalletCoinsPill extends StatelessWidget {
  const WalletCoinsPill({super.key, required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/push_pro_icon.png',
            width: 18,
            height: 18,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.low,
          ),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            t.t('wallet_coins'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
