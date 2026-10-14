import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../app/i18n.dart';

enum PaymentSuccessType {
  membership,
  coins,
}

Future<void> showPaymentSuccessDialog(
  BuildContext context, {
  PaymentSuccessType type = PaymentSuccessType.membership,
  String? title,
  String? message,
  String? badgeText,
  String? buttonText,
  int? coins,
  VoidCallback? onConfirm,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.70),
    builder: (dialogContext) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: _PaymentSuccessDialog(
          type: type,
          title: title,
          message: message,
          badgeText: badgeText,
          buttonText: buttonText,
          coins: coins,
          onConfirm: onConfirm,
        ),
      );
    },
  );
}

class _PaymentSuccessDialog extends StatefulWidget {
  const _PaymentSuccessDialog({
    required this.type,
    this.title,
    this.message,
    this.badgeText,
    this.buttonText,
    this.coins,
    this.onConfirm,
  });

  final PaymentSuccessType type;
  final String? title;
  final String? message;
  final String? badgeText;
  final String? buttonText;
  final int? coins;
  final VoidCallback? onConfirm;

  @override
  State<_PaymentSuccessDialog> createState() => _PaymentSuccessDialogState();
}

class _PaymentSuccessDialogState extends State<_PaymentSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final screenW = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenW - 56).clamp(285.0, 315.0);
    // Aspect ratio of marketing_bg.webp is 860w x 1148h
    final cardHeight = cardWidth * (1148.0 / 860.0);

    final isMembership = widget.type == PaymentSuccessType.membership;

    // Title: distinct for membership vs coins
    final effectiveTitle = widget.title ??
        (isMembership
            ? t.t('subscription_successful')
            : t.t('recharge_successful'));

    // Badge: distinct for membership vs coins
    final effectiveBadge = widget.badgeText ??
        (isMembership
            ? 'VIP PRO'
            : (widget.coins != null && widget.coins! > 0
                ? '+${widget.coins} ${t.t('wallet_coins').toUpperCase()}'
                : t.t('wallet_coins').toUpperCase()));

    // Description text: distinct for membership vs coins
    final effectiveDesc = widget.message ??
        (isMembership
            ? t.t('vip_subscription_success_desc')
            : t.t('coins_recharge_success_desc'));

    // Button label: distinct for membership vs coins
    final effectiveBtn = widget.buttonText ??
        (isMembership ? t.t('watch_now') : t.t('ok'));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // 1. Background luxury celebration graphic
                  Image.asset(
                    'assets/images/marketing_bg.webp',
                    width: cardWidth,
                    height: cardHeight,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),

                  // 2. Center Orange Sunburst Area (Y: ~475/1148 to ~805/1148)
                  // Accurately positioned inside the orange box with ample margins
                  Positioned(
                    top: cardHeight * (475.0 / 1148.0),
                    left: cardWidth * 0.11,
                    right: cardWidth * 0.11,
                    height: cardHeight * (330.0 / 1148.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        // White circular icon badge (Checkmark for VIP, Coins for Recharge)
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xffb91c1c).withValues(alpha: 0.30),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: isMembership
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Color(0xffea580c),
                                  size: 25,
                                  weight: 800,
                                )
                              : Image.asset(
                                  'assets/images/daily_checkin_top_ic.png',
                                  width: 23,
                                  height: 23,
                                  fit: BoxFit.contain,
                                ),
                        ),
                        const SizedBox(height: 6),
                        // Main Success Title (Payment/Subscription/Recharge Successful)
                        Text(
                          effectiveTitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                            shadows: [
                              Shadow(
                                color: Color(0x66000000),
                                offset: Offset(0, 1.5),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Badge pill (VIP PRO or COINS)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xfffef08a).withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isMembership
                                    ? Icons.workspace_premium_rounded
                                    : Icons.toll_rounded,
                                color: const Color(0xfffef08a),
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                effectiveBadge,
                                style: const TextStyle(
                                  color: Color(0xfffef08a),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Lower Cream-White Card Area (Y: ~830/1148 to ~1095/1148)
                  // Adjusted with clean font sizes, comfortable spacing, and non-overlapping button
                  Positioned(
                    top: cardHeight * (830.0 / 1148.0),
                    left: cardWidth * 0.08,
                    right: cardWidth * 0.08,
                    height: cardHeight * (265.0 / 1148.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.t('congratulations'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xffea580c),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                effectiveDesc,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xff4b5563),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Action Button (Watch now / OK)
                        SizedBox(
                          height: 31,
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: FilledButton(
                              onPressed: () {
                                _dismiss();
                                widget.onConfirm?.call();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xff09090b),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                elevation: 2,
                                shadowColor: Colors.black.withValues(alpha: 0.35),
                              ),
                              child: Text(
                                effectiveBtn,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. Subtle Top-Right Close Button
                  Positioned(
                    top: cardHeight * 0.032,
                    right: cardWidth * 0.035,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _dismiss,
                      child: Container(
                        width: 29,
                        height: 29,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.1,
                          ),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.white,
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
    );
  }
}
