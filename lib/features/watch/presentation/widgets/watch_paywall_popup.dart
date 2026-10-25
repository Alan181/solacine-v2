import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:solacine_mobile/app/i18n.dart';

class WatchPaywallPopup extends StatelessWidget {
  const WatchPaywallPopup({
    super.key,
    this.episodeNumber,
    this.totalEpisodes,
    required this.showVipUpsell,
    required this.coinsBalance,
    required this.unlocking,
    required this.canUnlockByCoins,
    required this.canUnlockByAd,
    required this.allowAdsUnlock,
    required this.unlockCost,
    required this.adUnlocksToday,
    required this.dailyAdLimit,
    required this.autoUnlockEnabled,
    required this.coinUnit,
    required this.onRecharge,
    required this.onUnlockWithCoins,
    required this.onUnlockWithAd,
    required this.onSetAutoUnlock,
    required this.vipUpsellChild,
  });

  final int? episodeNumber;
  final int? totalEpisodes;
  final bool showVipUpsell;
  final int coinsBalance;
  final bool unlocking;
  final bool canUnlockByCoins;
  final bool canUnlockByAd;
  final bool allowAdsUnlock;
  final int unlockCost;
  final int adUnlocksToday;
  final int dailyAdLimit;
  final bool autoUnlockEnabled;
  final String coinUnit;
  final VoidCallback onRecharge;
  final VoidCallback onUnlockWithCoins;
  final VoidCallback onUnlockWithAd;
  final ValueChanged<bool> onSetAutoUnlock;
  final Widget vipUpsellChild;

  @override
  Widget build(BuildContext context) {
    if (showVipUpsell) return vipUpsellChild;
    final t = AppI18n.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xf2181822),
                      Color(0xf0111116),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 40,
                      spreadRadius: 2,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: const Color(0xffef233c).withValues(alpha: 0.12),
                      blurRadius: 28,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top header: Recharge button & coins balance pill
                    Row(
                      children: [
                        InkWell(
                          onTap: onRecharge,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: Color(0xffffb703),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  t.t('recharge'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xfff59e0b).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xfff59e0b).withValues(alpha: 0.28),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$coinsBalance',
                                style: const TextStyle(
                                  color: Color(0xffffd166),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Image.asset(
                                'assets/images/daily_checkin_top_ic.png',
                                width: 17,
                                height: 17,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.monetization_on_rounded,
                                  size: 16,
                                  color: Color(0xffffd166),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (episodeNumber != null && episodeNumber! > 0) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xffef233c).withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_rounded,
                                size: 12,
                                color: Color(0xffef233c),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              (totalEpisodes != null && totalEpisodes! > 0)
                                  ? '${t.t('Episode')} $episodeNumber / $totalEpisodes'
                                  : '${t.t('Episode')} $episodeNumber',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else
                      const SizedBox(height: 16),

                    // Primary Action: Unlock with coins
                    InkWell(
                      onTap: (unlocking)
                          ? null
                          : () {
                              if (canUnlockByCoins) {
                                onUnlockWithCoins();
                                return;
                              }
                              onRecharge();
                            },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: unlocking ? 0.70 : 1.0,
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFFD54F),
                                Color(0xFFFFB300),
                                Color(0xFFF59E0B),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xfff59e0b).withValues(alpha: 0.35),
                                blurRadius: 18,
                                spreadRadius: 0,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: unlocking
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Color(0xff1f1300),
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/images/push_pro_icon.png',
                                        width: 20,
                                        height: 20,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) => const Icon(
                                          Icons.lock_open_rounded,
                                          size: 20,
                                          color: Color(0xff1f1300),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        t.t(
                                          'unlock_with_coins',
                                          params: {
                                            'cost': unlockCost.toString(),
                                            'unit': coinUnit,
                                          },
                                        ),
                                        style: const TextStyle(
                                          color: Color(0xff1a1003),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),

                    // Secondary Action: Watch ad
                    if (allowAdsUnlock) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: (!canUnlockByAd || unlocking) ? null : onUnlockWithAd,
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: (!canUnlockByAd || unlocking) ? 0.50 : 1.0,
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFF43F5E),
                                  Color(0xFFEF233C),
                                  Color(0xFFBE123C),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xffef233c).withValues(alpha: 0.30),
                                  blurRadius: 16,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.play_circle_filled_rounded,
                                    color: Colors.white,
                                    size: 21,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    t.t('watch_ad_unlock'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.t('watch_ad_to_unlock'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Text(
                                '$adUnlocksToday / $dailyAdLimit',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!canUnlockByAd)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            t.t('daily_ad_limit_reached'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.60),
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.08),
                        height: 18,
                        thickness: 1,
                      ),
                    ),

                    // Auto unlock row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.t('auto_unlock'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.t('auto_unlock_note'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.52),
                                  fontWeight: FontWeight.w400,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: autoUnlockEnabled,
                          onChanged: onSetAutoUnlock,
                          activeThumbColor: Colors.white,
                          activeTrackColor: const Color(0xffef233c),
                          inactiveThumbColor: Colors.white.withValues(alpha: 0.80),
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
