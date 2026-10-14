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
import 'widgets/membership_plan_card.dart';
import 'widgets/payment_methods_sheet.dart';
import 'widgets/wallet_coins_pill.dart';
import 'widgets/wallet_empty_error_states.dart';
import 'widgets/wallet_package_card.dart';
import 'widgets/wallet_section_title.dart';
import 'widgets/wallet_type_tabs.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key, this.initialItemType = 'coins'});

  final String initialItemType;

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> with WidgetsBindingObserver {
  bool _loading = true;
  Object? _error;

  List<CoinPackageDto> _packages = const [];
  List<MembershipPackageDto> _membershipPackages = const [];
  Map<String, bool> _providers = const {};
  late String _selectedItemType;

  bool _buying = false;
  String? _pendingOrderId;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final Set<String> _processingPurchaseTokens = <String>{};
  bool _googlePlayRestored = false;
  bool _appleStoreRestored = false;
  bool _pendingGatewayRestored = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedItemType = widget.initialItemType == 'membership' ? 'membership' : 'coins';
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
  static const _kPendingGatewayOrderIdKey = 'pending_gateway_payment_order_id';

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_pendingOrderId != null) {
        Future.microtask(() => _refreshStatusAndUser(_pendingOrderId!));
      }
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
      final membershipPackages = await api.membershipPackages();
      final providers = await api.enabledProviders();

      if (!mounted) return;
      setState(() {
        _packages = packages;
        _membershipPackages = membershipPackages;
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
    await _buyItem(itemType: 'coins', packageCode: pkg.code);
  }

  Future<void> _buyMembership(MembershipPackageDto pkg) async {
    await _buyItem(itemType: 'membership', packageCode: pkg.code);
  }

  Future<void> _buyItem({required String itemType, required String packageCode}) async {
    final t = AppI18n.of(context);

    if (_buying) return;
    if (_providers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
      return;
    }

    final enabledGateway = <String>[];
    for (final p in const ['stripe', 'paypal', 'flutterwave', 'razorpay']) {
      if (_providers[p] == true) enabledGateway.add(p);
    }

    final googlePlayEnabled = _providers['google_play'] == true;
    final appleStoreEnabled  = _providers['app_store']  == true;
    final isAndroid = _isAndroid;
    final isIOS = _isIOS;

    final selected = await PaymentMethodsSheet.show(
      context,
      enabledProviders: _providers,
      googlePlayEnabled: googlePlayEnabled,
      appleStoreEnabled: appleStoreEnabled,
      isAndroid: isAndroid,
      isIOS: isIOS,
    );

    if (!mounted) return;
    if (selected == null || selected.trim().isEmpty) return;

    if (selected == 'google_play') {
      await _buyGooglePlay(packageCode: packageCode, itemType: itemType);
      return;
    }
    if (selected == 'app_store') {
      await _buyAppleStore(packageCode: packageCode, itemType: itemType);
      return;
    }

    if (_isIOS) {
      if (appleStoreEnabled) {
        await _buyAppleStore(packageCode: packageCode, itemType: itemType);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
      }
      return;
    }

    await _buyGateway(packageCode: packageCode, provider: selected, itemType: itemType);
  }

  Future<void> _buyGateway({required String packageCode, required String provider, required String itemType}) async {
    final t = AppI18n.of(context);
    if (_buying) return;
    setState(() {
      _buying = true;
      _pendingOrderId = null;
    });

    try {
      final checkout = await ref.read(walletApiProvider).checkout(packageCode: packageCode, provider: provider, itemType: itemType);
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
        await _refreshUserAndLists();
        if (!mounted) return;
        await showPaymentSuccessDialog(
          context,
          type: itemType == 'coins' ? PaymentSuccessType.coins : PaymentSuccessType.membership,
        );
      } else {
        await _refreshStatusAndUser(checkout.paymentOrderId);
      }
    } on DioException catch (e) {
      final msg = _messageFromDio(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.isNotEmpty ? msg : t.t('request_failed'))));
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _buyGooglePlay({required String packageCode, required String itemType}) async {
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

      final productId = packageCode;
      final resp = await InAppPurchase.instance.queryProductDetails({productId});
      if (resp.productDetails.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('google_play_product_missing'))));
        return;
      }

      final pd = resp.productDetails.first;
      final param = PurchaseParam(productDetails: pd);
      await InAppPurchase.instance.buyConsumable(purchaseParam: param, autoConsume: false);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _buyAppleStore({required String packageCode, required String itemType}) async {
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Apple App Store is unavailable')));
        return;
      }

      final productId = packageCode;
      final resp = await InAppPurchase.instance.queryProductDetails({productId});
      if (resp.productDetails.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Apple product missing in App Store Connect')));
        return;
      }

      final pd = resp.productDetails.first;
      final param = PurchaseParam(productDetails: pd);
      try {
        await InAppPurchase.instance.buyConsumable(purchaseParam: param, autoConsume: false);
      } catch (_) {
        try {
          await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
        } catch (e) {
          rethrow;
        }
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
      if (p.status == PurchaseStatus.pending) {
        continue;
      }

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
                  itemType: _membershipPackages.any((e) => e.code == productId) ? 'membership' : 'coins',
                );
          } else {
            await ref.read(walletApiProvider).verifyGooglePlay(
                  packageCode: productId,
                  productId: productId,
                  purchaseToken: token,
                  itemType: _membershipPackages.any((e) => e.code == productId) ? 'membership' : 'coins',
                );
          }

          if (p.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(p);
          }

          if (!mounted) return;
          await _refreshUserAndLists();
          if (!mounted) return;
          await showPaymentSuccessDialog(context);
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
        await _refreshUserAndLists();
        if (!mounted) return;
        setState(() => _pendingOrderId = null);
        final prefs = await ref.read(sharedPrefsProvider.future);
        await prefs.remove(_kPendingGatewayOrderIdKey);
        if (!mounted) return;
        await showPaymentSuccessDialog(context);
      } else if (st.status == 'failed' || st.status == 'canceled') {
        setState(() => _pendingOrderId = null);
        final prefs = await ref.read(sharedPrefsProvider.future);
        await prefs.remove(_kPendingGatewayOrderIdKey);
      }
    } catch (_) {}
  }

  Future<void> _refreshUserAndLists() async {
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

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final session = ref.watch(authSessionProvider).valueOrNull;
    final coins = (session?.user?['coins_balance'] as num?)?.toInt() ?? (session?.user?['coins'] as num?)?.toInt() ?? 0;

    void goBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
    }

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xff050505),
        body: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Opacity(
                opacity: 0.18,
                child: Image.asset(
                  'assets/images/icon_subscribe_iaa_bg.png',
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 12, 6),
                    child: SizedBox(
                      height: 44,
                      child: Stack(
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: IconButton(
                              onPressed: goBack,
                              icon: const Icon(Icons.arrow_back_ios_new_rounded),
                              color: Colors.white.withValues(alpha: 0.90),
                            ),
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 70),
                              child: Text(
                                t.t('wallet'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: WalletCoinsPill(coins: coins),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadAll,
                      color: Colors.white,
                      backgroundColor: const Color(0xff0b0b0b),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        children: [
                          if (_loading)
                            const SizedBox(
                              height: 220,
                              child: Center(child: CircularProgressIndicator(color: Colors.white)),
                            )
                          else if (_error != null)
                            WalletErrorState(onRetry: _loadAll)
                          else ...[
                            WalletTypeTabs(
                              selected: _selectedItemType,
                              onSelect: (v) => setState(() => _selectedItemType = v),
                            ),
                            const SizedBox(height: 14),
                            if (_selectedItemType == 'membership') ...[
                              WalletSectionTitle(title: t.t('membership_packages')),
                              const SizedBox(height: 18),
                              if (_membershipPackages.isEmpty)
                                WalletEmptyState(text: t.t('no_packages'))
                              else
                                Builder(
                                  builder: (context) {
                                    final sorted = _membershipPackages.toList()
                                      ..sort((a, b) => a.durationDays.compareTo(b.durationDays));
                                    return Column(
                                      children: [
                                        for (var i = 0; i < sorted.length; i++) ...[
                                          MembershipPlanCard(
                                            pkg: sorted[i],
                                            badge: i == 0
                                                ? MembershipBadge.hot
                                                : (i == sorted.length - 1
                                                    ? MembershipBadge.bestChoice
                                                    : MembershipBadge.mostPopular),
                                            onTap: _buying ? null : () => _buyMembership(sorted[i]),
                                          ),
                                          if (i != sorted.length - 1) const SizedBox(height: 20),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                            ] else ...[
                              WalletSectionTitle(title: t.t('recharge')),
                              const SizedBox(height: 12),
                              if (_packages.isEmpty)
                                WalletEmptyState(text: t.t('no_packages'))
                              else
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _packages.length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.92,
                                  ),
                                  itemBuilder: (context, index) {
                                    final pkg = _packages[index];
                                    return WalletPackageCard(
                                      pkg: pkg,
                                      onTap: _buying ? null : () => _buy(pkg),
                                    );
                                  },
                                ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_buying)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: false,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.50),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
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

