import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app/i18n.dart';

class ProfileMembershipVipCard extends StatelessWidget {
  const ProfileMembershipVipCard({
    super.key,
    required this.appName,
    required this.isVip,
    required this.expiresDateLabel,
    required this.daysLeft,
    required this.onActivate,
  });

  final String appName;
  final bool isVip;
  final String expiresDateLabel;
  final int daysLeft;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final title = t.t('membership_title', params: {'app': appName});
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Image.asset(
            'assets/images/membership_kcoin_bg_light.png',
            height: 108,
            width: double.infinity,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (isVip) ...[
                              Image.asset(
                                'assets/images/vip_config_icon.webp',
                                width: 18,
                                height: 18,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.low,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                isVip ? t.t('vip_active') : title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xff1f2937),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (isVip)
                        Image.asset(
                          'assets/images/pay_left_start_over.webp',
                          height: 30,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.low,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        )
                      else
                        _AnimatedActivateButton(
                          onTap: onActivate,
                          label: t.t('activate'),
                        ),
                    ],
                  ),
                  const Spacer(),
                  if (isVip)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.t('vip_expires_on', params: {'date': expiresDateLabel}),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xff374151),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.t('vip_days_left', params: {'days': daysLeft.toString()}),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xff92400e),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _AnimatedActivateButton(
                              onTap: onActivate,
                              label: t.t('extend'),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _MembershipBenefit(
                                iconAsset: 'assets/images/icon_subscribe_new_unlimited.png',
                                label: t.t('membership_feature_unlimited'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MembershipBenefit(
                                iconAsset: 'assets/images/icon_subscribe_new_hd.png',
                                label: t.t('membership_feature_hd_1080'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _MembershipBenefit(
                                iconAsset: 'assets/images/icon_subscribe_new_drama.png',
                                label: t.t('membership_feature_no_ads'),
                              ),
                            ),
                            //   the feature is ready to be shown in the membership card.
                            // const SizedBox(width: 10),
                            // Expanded(
                            //   child: _MembershipBenefit(
                            //     iconAsset: 'assets/images/icon_subscribe_new_download.png',
                            //     label: t.t('membership_feature_download'),
                            //   ),
                            // ),
                            const Expanded(child: SizedBox.shrink()),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipBenefit extends StatelessWidget {
  const _MembershipBenefit({
    required this.iconAsset,
    required this.label,
  });

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          iconAsset,
          width: 14,
          height: 14,
          filterQuality: FilterQuality.low,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xff374151),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedActivateButton extends StatefulWidget {
  const _AnimatedActivateButton({
    required this.onTap,
    required this.label,
  });

  final VoidCallback onTap;
  final String label;

  @override
  State<_AnimatedActivateButton> createState() => _AnimatedActivateButtonState();
}

class _AnimatedActivateButtonState extends State<_AnimatedActivateButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final progress = _ctrl.value;
        final glowOpacity = 0.28 + 0.16 * math.sin(progress * 2 * math.pi);

        return Container(
          height: 30, // Reduced height
          constraints: const BoxConstraints(minWidth: 88), // Wider button
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xffffb800),
                Color(0xffff8800),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffffb800).withValues(alpha: glowOpacity),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(999),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Animated light shine sweep beam
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(-90.0 + progress * 240.0, 0),
                        child: Transform.rotate(
                          angle: 0.35,
                          child: Container(
                            width: 28,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.50),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Button text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          color: Color(0xff121212),
                          fontSize: 13,
                          fontWeight: FontWeight.bold, // Bold text
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

