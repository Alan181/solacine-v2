import 'package:flutter/material.dart';
import '../../../../../app/i18n.dart';
import '../../data/wallet_api.dart';

class WalletPackageCard extends StatelessWidget {
  const WalletPackageCard({
    super.key,
    required this.pkg,
    required this.onTap,
  });

  final CoinPackageDto pkg;
  final VoidCallback? onTap;

  // Fungsi helper format harga dinamis (IDR vs mata uang lain)
  String _formatPrice(num amount, String? currency) {
    final curr = (currency == null || currency.isEmpty) ? 'IDR' : currency.toUpperCase();
    
    if (curr == 'IDR') {
      final formattedNumber = amount.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
      return 'Rp $formattedNumber';
    }

    final symbol = curr == 'USD'
        ? '\$'
        : (curr == 'EUR'
            ? '€'
            : (curr == 'GBP'
                ? '£'
                : ''));
    final formatted = amount.toDouble().toStringAsFixed(2);
    if (symbol.isNotEmpty) {
      return '$symbol$formatted';
    }
    return '$formatted $curr';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    
    final currency = pkg.priceCurrency.isNotEmpty ? pkg.priceCurrency : 'IDR';
    final price = _formatPrice(pkg.priceAmount, currency);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xfffbbf24).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xfffbbf24).withValues(alpha: 0.22)),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/images/push_pro_icon.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.low,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Text(
                    currency,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              pkg.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '${pkg.coins}',
                      style: const TextStyle(
                        color: Color(0xfffbbf24),
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    t.t('wallet_coins'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.75), size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
