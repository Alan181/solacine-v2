import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dramereel_mobile/app/i18n.dart';

class WatchVipUpsellPopup extends StatelessWidget {
  const WatchVipUpsellPopup({
    super.key,
    required this.onGetVip,
  });

  final VoidCallback onGetVip;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                      color: const Color(0xfffbbf24).withValues(alpha: 0.12),
                      blurRadius: 30,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xfffbbf24).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xfffbbf24).withValues(alpha: 0.40),
                            ),
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: Color(0xfffbbf24),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.t('membership_model_active'),
                                style: const TextStyle(
                                  color: Color(0xfffbbf24),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                t.t('watch_all_episodes_no_ads_or_coins'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.68),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      t.t('this_platform_uses_membership_model_upgrade_vip_to_watch_all_episodes'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t.t('unlock_all_premium_content_with_a_vip_membership'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: onGetVip,
                      borderRadius: BorderRadius.circular(16),
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.workspace_premium_rounded,
                                color: Color(0xff1f1300),
                                size: 21,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                t.t('get_vip_membership'),
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
