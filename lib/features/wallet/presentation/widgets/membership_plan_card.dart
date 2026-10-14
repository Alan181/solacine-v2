import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../../app/i18n.dart';
import '../../data/wallet_api.dart';

enum MembershipBadge { hot, mostPopular, bestChoice }

class MembershipPlanCard extends StatefulWidget {
  const MembershipPlanCard({
    super.key,
    required this.pkg,
    required this.badge,
    required this.onTap,
  });

  final MembershipPackageDto pkg;
  final MembershipBadge badge;
  final VoidCallback? onTap;

  @override
  State<MembershipPlanCard> createState() => _MembershipPlanCardState();
}

class _MembershipPlanCardState extends State<MembershipPlanCard> {
  Timer? _timer;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.pkg.promoSecondsRemaining;
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MembershipPlanCard oldWidget) {
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
    if (days == 365) return t.t('membership_plan_yearly');
    return t.t('days', params: {'days': days.toString()});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final pkg = widget.pkg;
    final currentPrice = pkg.currentPriceAmount.toDouble().toStringAsFixed(2);
    final originalPrice = pkg.originalPriceAmount.toDouble().toStringAsFixed(2);
    final promoActive = pkg.promoActive && _secondsLeft > 0;
    final planLabel = _planLabel(t, pkg.durationDays);
    final titleText = t.t('membership_subscribe_to', params: {'plan': planLabel});
    final promoLine = t.t(
      'membership_promo_line',
      params: {
        'period': planLabel,
        'promo': currentPrice,
        'original': originalPrice,
      },
    );

    String badgeText;
    Color badgeBg;
    Color badgeFg;
    switch (widget.badge) {
      case MembershipBadge.hot:
        badgeText = t.t('badge_hot');
        badgeBg = const Color(0xfff97316);
        badgeFg = Colors.white;
        break;
      case MembershipBadge.mostPopular:
        badgeText = t.t('badge_most_popular');
        badgeBg = const Color(0xffef233c);
        badgeFg = Colors.white;
        break;
      case MembershipBadge.bestChoice:
        badgeText = t.t('badge_best_choice');
        badgeBg = const Color(0xfffbbf24);
        badgeFg = const Color(0xff0b0b0b);
        break;
    }

    final isBest = widget.badge == MembershipBadge.bestChoice;
    final borderColor = isBest
        ? const Color(0xfffbbf24).withValues(alpha: 0.60)
        : const Color(0xfffbbf24).withValues(alpha: 0.30);

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xff141116),
          border: Border.all(color: borderColor, width: isBest ? 1.6 : 1.0),
          boxShadow: [
            if (isBest)
              BoxShadow(
                color: const Color(0xfffbbf24).withValues(alpha: 0.18),
                blurRadius: 34,
                spreadRadius: -12,
                offset: const Offset(0, 20),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 26,
                spreadRadius: -14,
                offset: const Offset(0, 16),
              ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: RadialGradient(
                    center: const Alignment(-0.7, -0.9),
                    radius: 1.25,
                    colors: [
                      const Color(0xfffbbf24).withValues(alpha: isBest ? 0.22 : 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            if (promoActive)
              PositionedDirectional(
                top: -13,
                start: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xffef233c),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xffef233c).withValues(alpha: 0.25),
                        blurRadius: 18,
                        spreadRadius: -8,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.t('limited_time'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _fmtHms(_secondsLeft),
                        style: const TextStyle(
                          color: Color(0xfffbbf24),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            PositionedDirectional(
              top: promoActive ? 22 : -10,
              start: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: badgeBg.withValues(alpha: 0.22),
                      blurRadius: 18,
                      spreadRadius: -10,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeFg,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, promoActive ? 56 : 38, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            if (promoActive) ...[
                              const SizedBox(height: 4),
                              Text(
                                promoLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              t.t('membership_autorenew_note'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.50),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (promoActive)
                            Text(
                              '\$$originalPrice',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.lineThrough,
                                decorationThickness: 2,
                              ),
                            ),
                          Text(
                            '\$$currentPrice',
                            style: const TextStyle(
                              color: Color(0xfffbbf24),
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xfffbbf24).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xfffbbf24).withValues(alpha: 0.22),
                              ),
                            ),
                            child: Text(
                              planLabel,
                              style: const TextStyle(
                                color: Color(0xfffbbf24),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MembershipBenefitsRow(
                    leftIcon: 'assets/images/icon_subscribe_new_download.png',
                    leftText: t.t('membership_feature_download'),
                    rightIcon: 'assets/images/icon_subscribe_new_hd.png',
                    rightText: t.t('membership_feature_hd_1080'),
                  ),
                  const SizedBox(height: 8),
                  MembershipBenefitsRow(
                    leftIcon: 'assets/images/icon_subscribe_new_drama.png',
                    leftText: t.t('membership_feature_no_ads'),
                    rightIcon: 'assets/images/icon_subscribe_new_unlimited.png',
                    rightText: t.t('membership_feature_unlimited'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MembershipBenefitsRow extends StatelessWidget {
  const MembershipBenefitsRow({
    super.key,
    required this.leftIcon,
    required this.leftText,
    required this.rightIcon,
    required this.rightText,
  });

  final String leftIcon;
  final String leftText;
  final String rightIcon;
  final String rightText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: MembershipBenefit(icon: leftIcon, text: leftText)),
        const SizedBox(width: 8),
        Expanded(child: MembershipBenefit(icon: rightIcon, text: rightText)),
      ],
    );
  }
}

class MembershipBenefit extends StatelessWidget {
  const MembershipBenefit({
    super.key,
    required this.icon,
    required this.text,
  });

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Opacity(
          opacity: 0.90,
          child: Image.asset(
            icon,
            width: 16,
            height: 16,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.low,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
