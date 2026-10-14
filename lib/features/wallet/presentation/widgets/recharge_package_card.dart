import 'package:flutter/material.dart';
import '../../../../../app/i18n.dart';
import '../../data/wallet_api.dart';
import 'diagonal_stripes_painter.dart';
import 'shiny_gold_coin.dart';

class RechargePackageCard extends StatelessWidget {
  const RechargePackageCard({
    super.key,
    required this.pkg,
    required this.onTap,
    this.badgeText,
  });

  final CoinPackageDto pkg;
  final VoidCallback? onTap;
  final String? badgeText;

  String _formatPrice(CoinPackageDto item) {
    final currency = item.priceCurrency.toUpperCase();
    final symbol = currency == 'USD'
        ? '\$'
        : (currency == 'EUR'
            ? '€'
            : (currency == 'GBP'
                ? '£'
                : ''));
    final amount = item.priceAmount;
    // If it's a whole number or decimal
    final isWhole = (amount % 1) == 0;
    final formatted = isWhole ? amount.toInt().toString() : amount.toStringAsFixed(2);
    if (symbol.isNotEmpty) {
      return '$symbol$formatted';
    }
    return '$formatted $currency';
  }

  @override
  Widget build(BuildContext context) {
    final priceLabel = _formatPrice(pkg);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: const Color(0xffff2d79).withValues(alpha: 0.2),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xff15141b),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // Subtle golden diagonal stripes (soft and transparent)
                Positioned.fill(
                  child: CustomPaint(
                    painter: const DiagonalStripesPainter(
                      stripeColor: Color(0x07f59e0b),
                      stripeWidth: 0.85,
                      spacing: 16.0,
                      slope: 0.45,
                    ),
                  ),
                ),

                // Ambient golden bottom corner sheen
                Positioned(
                  bottom: -20,
                  right: -20,
                  width: 90,
                  height: 90,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xfff59e0b).withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Card content
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Spacer(),
                      // Shiny gold coin
                      const ShinyGoldCoin(size: 42),
                      const SizedBox(height: 8),

                      // Coin Amount + Coins Label
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${pkg.coins}',
                              style: const TextStyle(
                                color: Color(0xfffff8e1),
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                height: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            AppI18n.of(context).t('coins'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Bottom pink-orange gradient button
                      Container(
                        height: 38,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xffff2d79),
                              Color(0xffff6b4a),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xffff2d79).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          priceLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Top-Left Badge (e.g. +10%, +30%)
                if (badgeText != null && badgeText!.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xffff2d79),
                            Color(0xffff7a00),
                          ],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(18),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: Text(
                        badgeText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
