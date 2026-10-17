import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../app/i18n.dart';
import 'wallet_payment_method_tile.dart';

String providerLabel(AppI18n t, String provider) {
  switch (provider) {
    case 'stripe':
      return t.t('stripe');
    case 'paypal':
      return t.t('paypal');
    case 'flutterwave':
      return t.t('flutterwave');
    case 'razorpay':
      return t.t('razorpay');
    case 'xendit':
      return 'Xendit';
    default:
      return provider;
  }
}

class PaymentMethodsSheet extends StatelessWidget {
  const PaymentMethodsSheet({
    super.key,
    required this.enabledProviders,
    required this.enabledGateway,
    required this.isAndroid,
    required this.isIOS,
    required this.googlePlayEnabled,
    required this.appleStoreEnabled,
  });

  final Map<String, bool> enabledProviders;
  final List<String> enabledGateway;
  final bool isAndroid;
  final bool isIOS;
  final bool googlePlayEnabled;
  final bool appleStoreEnabled;

  static const _iosSystemGreen = Color(0xff34C759);

  static Future<String?> show(
    BuildContext context, {
    required Map<String, bool> enabledProviders,
    required bool googlePlayEnabled,
    required bool appleStoreEnabled,
    required bool isAndroid,
    required bool isIOS,
  }) {
    final webGateway = <String>[];
    // Menambahkan 'xendit' ke dalam daftar web gateway yang didukung
    for (final p in const ['stripe', 'paypal', 'flutterwave', 'razorpay', 'xendit']) {
      if (enabledProviders[p] == true) webGateway.add(p);
    }

    final hasGooglePlay = isAndroid && googlePlayEnabled;
    final hasAppleStore = isIOS && appleStoreEnabled;

    final availableOptions = <String>[];
    if (hasGooglePlay) availableOptions.add('google_play');
    if (hasAppleStore) availableOptions.add('app_store');
    availableOptions.addAll(webGateway);

    // If only one payment method is available, proceed immediately without opening sheet
    if (availableOptions.length == 1) {
      return Future.value(availableOptions.first);
    }

    return showModalBottomSheet<String>(
      context: context,
      // Official iOS dark mode sheet surface
      backgroundColor: const Color(0xff1C1C1E),
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return PaymentMethodsSheet(
          enabledProviders: enabledProviders,
          enabledGateway: webGateway,
          isAndroid: isAndroid,
          isIOS: isIOS,
          googlePlayEnabled: googlePlayEnabled,
          appleStoreEnabled: appleStoreEnabled,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // ── Calculate how many options are actually available ───────────────────
    final hasGooglePlay = isAndroid && googlePlayEnabled;
    final hasAppleStore = isIOS && appleStoreEnabled;
    final hasWebGateways = enabledGateway.isNotEmpty;
    final availableCount = (hasGooglePlay ? 1 : 0) +
        (hasAppleStore ? 1 : 0) +
        enabledGateway.length;
    // ────────────────────────────────────────────────────────────────────────

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // iOS Standard Grabber / Handle bar
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Official Header Bar with iOS touches
            Row(
              children: [
                // Shield Check Badge Container (Apple System Green)
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _iosSystemGreen.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: _iosSystemGreen.withValues(alpha: 0.30),
                      width: 0.8,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/images/shield-check.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                      _iosSystemGreen,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'الدفع الآمن' : t.t('secure_checkout'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic
                            ? 'اختر وسيلة الدفع الرسمية لإتمام المعاملة'
                            : t.t('choose_payment_method'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // iOS Circular Close Button
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close_rounded,
                      size: 17,
                      color: Colors.white.withValues(alpha: 0.80),
                    ),
                  ),
                ),
              ],
            ),

            // iOS Hairline Divider
            Divider(
              height: 22,
              thickness: 0.6,
              color: Colors.white.withValues(alpha: 0.08),
            ),

            // ── EMPTY STATE: No payment methods at all ──────────────────────
            if (availableCount == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                          width: 0.6,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.credit_card_off_rounded,
                        size: 34,
                        color: Colors.white.withValues(alpha: 0.50),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t.t('no_payment_methods'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.t('no_payment_methods_desc'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xffef233c),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        child: Text(t.t('close')),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // iOS Trust Callout Banner with shield-check.svg
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                decoration: BoxDecoration(
                  color: const Color(0xff24252C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _iosSystemGreen.withValues(alpha: 0.22),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/images/shield-check.svg',
                      width: 15,
                      height: 15,
                      colorFilter: const ColorFilter.mode(
                        _iosSystemGreen,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isArabic
                            ? 'معاملة مشفرة 256-bit SSL ومؤمنة بالكامل'
                            : '256-bit SSL encrypted • Guaranteed secure checkout',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Scrollable container for payment tiles to avoid overflow on smaller screens
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Google Play (Android only) ────────────────────────
                      if (hasGooglePlay)
                        WalletPaymentMethodTile(
                          title: 'Google Play',
                          subtitle: isArabic
                              ? 'الدفع الرسمي عبر متجر جوجل'
                              : 'Official Google Play billing',
                          badgeText: isArabic ? 'معتمد' : 'Official',
                          iconAsset: 'assets/images/payments/google_play.png',
                          onTap: () => Navigator.of(context).pop('google_play'),
                        ),

                      // ── Apple App Store (iOS only) ────────────────────────
                      if (hasAppleStore)
                        WalletPaymentMethodTile(
                          title: 'Apple App Store',
                          subtitle: isArabic
                              ? 'الدفع الرسمي عبر متجر آبل'
                              : 'Official Apple in-app purchase',
                          badgeText: isArabic ? 'معتمد' : 'Official',
                          iconBgColor: Colors.black,
                          iconWidget: const Icon(
                            Icons.apple_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                          onTap: () => Navigator.of(context).pop('app_store'),
                        ),

                      // ── Web Gateways: Stripe / Paypal / Flutterwave / Razorpay / Xendit
                      if (hasWebGateways)
                        ...enabledGateway.map((p) {
                          final icon = switch (p) {
                            'stripe' => 'assets/images/payments/stripe.png',
                            'paypal' => 'assets/images/payments/paypal.png',
                            'flutterwave' => 'assets/images/payments/flutterwave.png',
                            'razorpay' => 'assets/images/payments/razorpay.png',
                            'xendit' => 'assets/images/daily_checkin_top_ic.png', // Menggunakan aset yang sudah ada
                            _ => null,
                          };
                          final subtitle = switch (p) {
                            'stripe' => isArabic
                                ? 'البطاقات البنكية (Visa, MasterCard)'
                                : 'Credit & Debit Cards (Visa, MasterCard)',
                            'paypal' => isArabic
                                ? 'الحساب المالي وبطاقات باي بال'
                                : 'PayPal balance & cards',
                            'razorpay' => isArabic
                                ? 'البطاقات البنكية وUPI'
                                : 'UPI, Cards & NetBanking',
                            'flutterwave' => isArabic
                                ? 'البطاقات والتحويل البنكي'
                                : 'Cards & local payments',
                            'xendit' => isArabic
                                ? 'QRIS، الحسابات الافتراضية والمحافظ الإلكترونية'
                                : 'QRIS, Virtual Accounts & E-Wallets',
                            _ => isArabic ? 'دفع آمن ومعتمد' : t.t('secure_payment'),
                          };
                          return WalletPaymentMethodTile(
                            title: providerLabel(t, p),
                            subtitle: subtitle,
                            iconAsset: icon,
                            badgeText: (p == 'stripe' || p == 'paypal' || p == 'xendit')
                                ? (isArabic ? 'آمن' : 'Secure')
                                : null,
                            onTap: () => Navigator.of(context).pop(p),
                          );
                        }),
                    ],
                  ),
                ),
              ),

              // iOS Footer note with lock icon
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isArabic
                          ? 'بوابة دفع معتمدة ومحمية 100%'
                          : '100% Certified & protected payment gateway',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
