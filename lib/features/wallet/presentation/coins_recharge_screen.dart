import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../app/i18n.dart';
import '../../../shared/data/shared_prefs_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_api.dart';
import '../data/wallet_api.dart';
import 'payment_success_dialog.dart';
import 'payment_webview_screen.dart';
import 'widgets/payment_methods_sheet.dart';
import 'widgets/recharge_package_card.dart';
import 'widgets/wallet_empty_error_states.dart';
import 'widgets/wallet_shimmer_card.dart';

class CoinsRechargeScreen extends ConsumerStatefulWidget {
  const CoinsRechargeScreen({super.key});

  @override
  ConsumerState<CoinsRechargeScreen> createState() => _CoinsRechargeScreenState();
}

class _CoinsRechargeScreenState extends ConsumerState<CoinsRechargeScreen> with WidgetsBindingObserver {
  bool _loading = true;
  Object? _error;
  List<CoinPackageDto> _packages = const [];
  Map<String, bool> _providers = const {};

  bool _buying = false;
  String? _pendingOrderId;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final Set<String> _processingPurchaseTokens = <String>{};
  bool _googlePlayRestored = false;
  bool _appleStoreRestored = false;
  bool _pendingGatewayRestored = false;

  static const _kPendingGatewayOrderIdKey = 'pending_gateway_payment_order_id';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_loadAll);
    Future.microtask(_maybeInitGooglePlay);
    Future.microtask(_maybeInitAppleStore);
    Future.microtask(_restorePendingGatewayOrder);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _purchaseSub?.cancel();
    super.dispose();
  }

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingOrderId != null) {
      Future.microtask(() => _refreshStatusAndUser(_pendingOrderId!));
    }
  }

  Future<void> _restorePendingGatewayOrder() async {
    if (_pendingGatewayRestored) return;
    _pendingGatewayRestored = true;

    final prefs = await ref.read(sharedPrefsProvider.future);
    final saved = prefs.getString(_kPendingGatewayOrderIdKey)?.trim();
    if (saved == null || saved.isEmpty) return;

    _pendingOrderId = saved;
    await _refreshStatusAndUser(saved);
  }

  Future<void> _maybeInitGooglePlay({bool restore = false}) async {
    if (!_isAndroid) return;
    _purchaseSub ??= InAppPurchase.instance.purchaseStream.listen(_onPurchaseUpdates, onError: (_) {});

    if (restore && !_googlePlayRestored) {
      _googlePlayRestored = true;
      try {
        await InAppPurchase.instance.restorePurchases();
      } catch (_) {}
    }
  }

  Future<void> _maybeInitAppleStore({bool restore = false}) async {
    if (!_isIOS) return;
    _purchaseSub ??= InAppPurchase.instance.purchaseStream.listen(_onPurchaseUpdates, onError: (_) {});

    if (restore && !_appleStoreRestored) {
      _appleStoreRestored = true;
      try {
        await InAppPurchase.instance.restorePurchases();
      } catch (_) {}
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(walletApiProvider);
      final packages = await api.packages();
      final providers = await api.enabledProviders();

      if (!mounted) return;
      setState(() {
        _packages = packages;
        _providers = providers;
      });

      if (_providers['google_play'] == true) {
        await _maybeInitGooglePlay(restore: true);
      }
      if (_providers['app_store'] == true) {
        await _maybeInitAppleStore(restore: true);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buy(CoinPackageDto pkg) async {
    final t = AppI18n.of(context);
    if (_buying) return;

    if (_providers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
      return;
    }

    final googlePlayEnabled = _providers['google_play'] == true;
    final appleStoreEnabled = _providers['app_store'] == true;

    final selected = await PaymentMethodsSheet.show(
      context,
      enabledProviders: _providers,
      googlePlayEnabled: googlePlayEnabled,
      appleStoreEnabled: appleStoreEnabled,
      isAndroid: _isAndroid,
      isIOS: _isIOS,
    );

    if (!mounted || selected == null || selected.trim().isEmpty) return;

    if (selected == 'google_play') {
      await _buyGooglePlay(packageCode: pkg.code);
      return;
    }
    if (selected == 'app_store') {
      await _buyAppleStore(packageCode: pkg.code);
      return;
    }

    if (_isIOS) {
      if (appleStoreEnabled) {
        await _buyAppleStore(packageCode: pkg.code);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
      }
      return;
    }

    await _buyGateway(packageCode: pkg.code, provider: selected);
  }

  Future<void> _buyGateway({required String packageCode, required String provider}) async {
    final t = AppI18n.of(context);
    if (_buying) return;
    setState(() {
      _buying = true;
      _pendingOrderId = null;
    });

    try {
      final checkout = await ref.read(walletApiProvider).checkout(
            packageCode: packageCode,
            provider: provider,
            itemType: 'coins',
          );
      if (!mounted) return;
      if (checkout.paymentOrderId.isEmpty || checkout.redirectUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
        return;
      }

      _pendingOrderId = checkout.paymentOrderId;
      final prefs = await ref.read(sharedPrefsProvider.future);
      await prefs.setString(_kPendingGatewayOrderIdKey, _pendingOrderId!);
      if (!mounted) return;

      final uri = Uri.tryParse(checkout.redirectUrl!);
      if (uri == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('unable_open_link'))));
        return;
      }

      final success = await PaymentWebViewScreen.open(
        context,
        url: checkout.redirectUrl!,
        paymentOrderId: checkout.paymentOrderId,
        title: providerLabel(t, provider),
      );

      if (!mounted) return;

      if (success == true) {
        setState(() => _pendingOrderId = null);
        final prefs = await ref.read(sharedPrefsProvider.future);
        await prefs.remove(_kPendingGatewayOrderIdKey);
        await _refreshUser();
        if (!mounted) return;
        await showPaymentSuccessDialog(context, type: PaymentSuccessType.coins);
      } else {
        await _refreshStatusAndUser(checkout.paymentOrderId);
      }
    } on DioException catch (e) {
      final msg = _messageFromDio(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.isNotEmpty ? msg : t.t('request_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _buyGooglePlay({required String packageCode}) async {
    final t = AppI18n.of(context);
    if (_buying) return;
    setState(() {
      _buying = true;
      _pendingOrderId = null;
    });

    try {
      await _maybeInitGooglePlay();
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('google_play_unavailable'))));
        return;
      }

      final resp = await InAppPurchase.instance.queryProductDetails({packageCode});
      if (resp.productDetails.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('google_play_product_missing'))));
        return;
      }

      final param = PurchaseParam(productDetails: resp.productDetails.first);
      await InAppPurchase.instance.buyConsumable(purchaseParam: param, autoConsume: false);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _buyAppleStore({required String packageCode}) async {
    final t = AppI18n.of(context);
    if (_buying) return;
    setState(() {
      _buying = true;
      _pendingOrderId = null;
    });

    try {
      await _maybeInitAppleStore();
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apple App Store is unavailable')));
        return;
      }

      final resp = await InAppPurchase.instance.queryProductDetails({packageCode});
      if (resp.productDetails.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apple product missing in App Store Connect')));
        return;
      }

      final param = PurchaseParam(productDetails: resp.productDetails.first);
      try {
        await InAppPurchase.instance.buyConsumable(purchaseParam: param, autoConsume: false);
      } catch (_) {
        await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    if (!mounted) return;
    final t = AppI18n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    for (final p in purchases) {
      if (p.status == PurchaseStatus.pending) continue;
      if (p.status == PurchaseStatus.error) {
        messenger.showSnackBar(SnackBar(content: Text(t.t('payment_failed'))));
        continue;
      }

      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        final token = p.verificationData.serverVerificationData.trim();
        final productId = p.productID.trim();
        final transactionId = (p.purchaseID ?? '').trim();
        final sourceLower = p.verificationData.source.toString().toLowerCase();
        final sourceIsApple = sourceLower.contains('ios') ||
            sourceLower.contains('apple') ||
            sourceLower.contains('storekit') ||
            (defaultTargetPlatform == TargetPlatform.iOS);

        if (token.isEmpty || productId.isEmpty) continue;
        if (_processingPurchaseTokens.contains(token)) continue;
        _processingPurchaseTokens.add(token);

        try {
          if (sourceIsApple) {
            await ref.read(walletApiProvider).verifyAppleReceipt(
                  packageCode: productId,
                  productId: productId,
                  receiptData: token,
                  transactionId: transactionId.isEmpty ? null : transactionId,
                  itemType: 'coins',
                );
          } else {
            await ref.read(walletApiProvider).verifyGooglePlay(
                  packageCode: productId,
                  productId: productId,
                  purchaseToken: token,
                  itemType: 'coins',
                );
          }

          if (p.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(p);
          }

          if (!mounted) return;
          await _refreshUser();
          if (!mounted) return;
          await showPaymentSuccessDialog(context, type: PaymentSuccessType.coins);
        } catch (_) {
          if (!mounted) return;
          messenger.showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
        } finally {
          _processingPurchaseTokens.remove(token);
        }
      }
    }
  }

  Future<void> _refreshStatusAndUser(String orderId) async {
    try {
      final st = await ref.read(walletApiProvider).orderStatus(paymentOrderId: orderId);
      if (!mounted) return;
      if (st.status == 'paid') {
        await _refreshUser();
        if (!mounted) return;
        setState(() => _pendingOrderId = null);
        final prefs = await ref.read(sharedPrefsProvider.future);
        await prefs.remove(_kPendingGatewayOrderIdKey);
        if (!mounted) return;
        await showPaymentSuccessDialog(context, type: PaymentSuccessType.coins);
      } else if (st.status == 'failed' || st.status == 'canceled') {
        setState(() => _pendingOrderId = null);
        final prefs = await ref.read(sharedPrefsProvider.future);
        await prefs.remove(_kPendingGatewayOrderIdKey);
      }
    } catch (_) {}
  }

  Future<void> _refreshUser() async {
    final fresh = await ref.read(authApiProvider).me();
    await ref.read(authSessionProvider.notifier).setUser(fresh);
  }

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();
    return '';
  }

  String? _badgeForPackage(int index, int total) {
    if (total <= 2) return null;
    if (index == 3) return '+10%';
    if (index >= 4) return '+30%';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final session = ref.watch(authSessionProvider).valueOrNull;
    final coins = (session?.user?['coins_balance'] as num?)?.toInt() ??
        (session?.user?['coins'] as num?)?.toInt() ??
        0;

    void goBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
    }

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xff08070d),
        body: Stack(
          children: [
            // Top Ambient Violet / Purple Aurora Glow
            Positioned(
              top: -80,
              left: 0,
              right: 0,
              height: 340,
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.6),
                      radius: 0.9,
                      colors: [
                        Color(0x406d28d9),
                        Color(0x224c1d95),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Top App Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Row(
                      children: [
                        // Back Button
                        Material(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            onTap: goBack,
                            borderRadius: BorderRadius.circular(999),
                            child: const SizedBox(
                              width: 38,
                              height: 38,
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Screen Title
                        Text(
                          t.t('recharge'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        // History Button
                        Material(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            onTap: () => context.push('/purchase-history'),
                            borderRadius: BorderRadius.circular(999),
                            child: const SizedBox(
                              width: 38,
                              height: 38,
                              child: Icon(
                                Icons.history_rounded,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main Scrollable Area
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadAll,
                      color: const Color(0xffff2d79),
                      backgroundColor: const Color(0xff15141b),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          // Header Balance Card
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.t('gold_coins'),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '$coins',
                                      style: const TextStyle(
                                        color: Color(0xffffc107),
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.8,
                                        shadows: [
                                          Shadow(
                                            color: Color(0x66ffc107),
                                            blurRadius: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      t.t('coins'),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.65),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Packages Grid or States
                          if (_loading)
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: 6,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.88,
                              ),
                              itemBuilder: (context, index) => const CoinPackageShimmerCard(),
                            )
                          else if (_error != null)
                            WalletErrorState(onRetry: _loadAll)
                          else if (_packages.isEmpty)
                            WalletEmptyState(text: t.t('no_packages'))
                          else ...[
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _packages.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.88,
                              ),
                              itemBuilder: (context, index) {
                                final pkg = _packages[index];
                                final badge = _badgeForPackage(index, _packages.length);
                                return RechargePackageCard(
                                  pkg: pkg,
                                  badgeText: badge,
                                  onTap: _buying ? null : () => _buy(pkg),
                                );
                              },
                            ),
                            const SizedBox(height: 28),
                            // Tips Section (Only shown after packages load)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.t('recharge_tips'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  t.t('recharge_tips_desc'),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.50),
                                    fontSize: 13,
                                    height: 1.45,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Purchasing Loading Overlay
            if (_buying)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xff1a1924),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            color: Color(0xffff2d79),
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Processing purchase...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
    );
  }
}
