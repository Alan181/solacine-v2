import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../../app/i18n.dart';
import '../../data/wallet_api.dart';
import 'diagonal_stripes_painter.dart';

enum VipPlanBadgeType { hot, mostPopular, bestChoice, none }

class VipPlanCard extends StatefulWidget {
  const VipPlanCard({
    super.key,
    required this.pkg,
    required this.isSelected,
    required this.badgeType,
    required this.onTap,
  });

  final MembershipPackageDto pkg;
  final bool isSelected;
  final VipPlanBadgeType badgeType;
  final VoidCallback? onTap;

  @override
  State<VipPlanCard> createState() => _VipPlanCardState();
}

class _VipPlanCardState extends State<VipPlanCard> {
  Timer? _timer;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.pkg.promoSecondsRemaining;
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant VipPlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pkg.promoSecondsRemaining != widget.pkg.promoSecondsRemaining ||
        oldWidget.pkg.promoActive != widget.pkg.promoActive) {
      _secondsLeft = widget.pkg.promoSecondsRemaining;
      _startTimerIfNeeded();
    }
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (!widget.pkg.promoActive) return;
    if (_secondsLeft <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        setState(() => _secondsLeft = 0);
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtHms(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final ss = s % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
  }

  String _planLabel(AppI18n t, int days) {
    if (days == 7) return t.t('membership_plan_weekly');
    if (days == 30) return t.t('membership_plan_monthly');
    if (days == 90) return '90 Days';
    if (days == 365) return t.t('membership_plan_yearly');
    return t.t('days', params: {'days': days.toString()});
  }

  // Fungsi helper pemformatan harga yang sudah mendukung IDR (Rp di depan tanpa desimal)
  String _formatPrice(num amount, String? currency) {
    final cur = (currency == null || currency.isEmpty) ? 'IDR' : currency.toUpperCase();
    
    if (cur == 'IDR') {
      final formattedNumber = amount.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
      return 'Rp $formattedNumber';
    }

    final symbol = cur == 'USD'
        ? '\$'
        : (cur == 'EUR'
            ? '€'
            : (cur == 'GBP'
                ? '£'
                : ''));
    final formatted = amount.toDouble().toStringAsFixed(2);
    if (symbol.isNotEmpty) {
      return '$symbol$formatted';
    }
    return '$formatted $cur';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final pkg = widget.pkg;
    final isSelected = widget.isSelected;
    
    final currency = pkg.priceCurrency.isNotEmpty ? pkg.priceCurrency : 'IDR';
    final currentPrice = _formatPrice(pkg.currentPriceAmount, currency);
    final originalPrice = _formatPrice(pkg.originalPriceAmount, currency);
    
    final promoActive = pkg.promoActive && _secondsLeft > 0;
    final planLabel = _planLabel(t, pkg.durationDays);
    final titleText = t.t('membership_subscribe_to', params: {'plan': planLabel});

    Widget? badgeWidget;
    switch (widget.badgeType) {
      case VipPlanBadgeType.hot:
        badgeWidget = _buildBadge(
          text: t.t('badge_hot'),
          gradient: const LinearGradient(colors: [Color(0xffff7a00), Color(0xffff9900)]),
          textColor: Colors.white,
        );
        break;
      case VipPlanBadgeType.mostPopular:
        badgeWidget = _buildBadge(
          text: t.t('badge_most_popular'),
          gradient: const LinearGradient(colors: [Color(0xffff2d55), Color(0xffff5252)]),
          textColor: Colors.white,
        );
        break;
      case VipPlanBadgeType.bestChoice:
        badgeWidget = _buildBadge(
          text: '✦ ${t.t('badge_best_choice')}',
          gradient: const LinearGradient(colors: [Color(0xffffb800), Color(0xffffd000)]),
          textColor: const Color(0xff121212),
        );
        break;
      case VipPlanBadgeType.none:
        badgeWidget = null;
        break;
    }

    final hasTopTags = badgeWidget != null || promoActive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: const Color(0xffffb800).withValues(alpha: 0.15),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xff141419),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? const Color(0xffffb800)
                  : Colors.white.withValues(alpha: 0.10),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: const Color(0xffffb800).withValues(alpha: 0.28),
                  blurRadius: 26,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // Soft & transparent golden diagonal stripes
                Positioned.fill(
                  child: CustomPaint(
                    painter: DiagonalStripesPainter(
                      stripeColor: isSelected
                          ? const Color(0x0effb800)
                          : const Color(0x05f59e0b),
                      stripeWidth: 0.85,
                      spacing: 16.0,
                      slope: 0.45,
                    ),
                  ),
                ),

                // Warm radial glow on selected card
                if (isSelected)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.6, -0.6),
                          radius: 1.2,
                          colors: [
                            const Color(0xffffb800).withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                // Content
                Padding(
                  padding: EdgeInsets.fromLTRB(16, hasTopTags ? 38 : 18, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Title & Subtitle on left, Price & Period Pill on right
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  titleText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xfff5f5f7),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  t.t('membership_autorenew_note'),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.50),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (promoActive) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Original $originalPrice',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.45),
                                      fontSize: 11,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  currentPrice,
                                  style: const TextStyle(
                                    color: Color(0xffffc107),
                                    fontSize: 22, // Disesuaikan agar ukuran teks nominal IDR pas
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xffffb800).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xffffb800).withValues(alpha: 0.35),
                                    width: 0.9,
                                  ),
                                ),
                                child: Text(
                                  planLabel,
                                  style: const TextStyle(
                                    color: Color(0xffffc107),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      // Divider line
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                      const SizedBox(height: 12),

                      // Feature benefits row (Without offline download)
                      Row(
                        children: [
                          Expanded(
                            child: _buildFeatureItem(
                              icon: Icons.hd_outlined,
                              label: t.t('membership_feature_hd_1080'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFeatureItem(
                              icon: Icons.block_outlined,
                              label: t.t('membership_feature_no_ads'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFeatureItem(
                              icon: Icons.all_inclusive_rounded,
                              label: t.t('membership_feature_unlimited'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Top Tags Area: Badge + Promo Countdown Timer
                if (hasTopTags)
                  PositionedDirectional(
                    top: 10,
                    start: 14,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (badgeWidget != null) badgeWidget,
                        if (promoActive) ...[
                          if (badgeWidget != null) const SizedBox(width: 8),
                          _buildPromoTimerBadge(t),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String text,
    required Gradient gradient,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildPromoTimerBadge(AppI18n t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffef233c), Color(0xffff5252)],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffef233c).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            t.t('limited_time'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _fmtHms(_secondsLeft),
            style: const TextStyle(
              color: Color(0xffffd000),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: const Color(0xffffb800).withValues(alpha: 0.85),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
