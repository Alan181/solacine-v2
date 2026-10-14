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
import 'widgets/vip_plan_card.dart';
import 'widgets/wallet_empty_error_states.dart';
import 'widgets/wallet_shimmer_card.dart';

class VipMembershipScreen extends ConsumerStatefulWidget {
  const VipMembershipScreen({super.key});

  @override
  ConsumerState<VipMembershipScreen> createState() => _VipMembershipScreenState();
}

class _VipMembershipScreenState extends ConsumerState<VipMembershipScreen> with WidgetsBindingObserver {
  bool _loading = true;
  Object? _error;
  List<MembershipPackageDto> _membershipPackages = const [];
  Map<String, bool> _providers = const {};
  String? _selectedCode;

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
      final membershipPackages = await api.membershipPackages();
      final providers = await api.enabledProviders();

      if (!mounted) return;
      final sorted = membershipPackages.toList()
        ..sort((a, b) => a.durationDays.compareTo(b.durationDays));

      setState(() {
        _membershipPackages = sorted;
        _providers = providers;
        if (_selectedCode == null && sorted.isNotEmpty) {
          // Select the best choice (last / highest or popular)
          _selectedCode = sorted.length > 2 ? sorted.last.code : sorted.first.code;
        }
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

  Future<void> _buyMembership(MembershipPackageDto pkg) async {
    final t = AppI18n.of(context);
    setState(() => _selectedCode = pkg.code);
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
            itemType: 'membership',
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
        await showPaymentSuccessDialog(context, type: PaymentSuccessType.membership);
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
                  itemType: 'membership',
                );
          } else {
            await ref.read(walletApiProvider).verifyGooglePlay(
                  packageCode: productId,
                  productId: productId,
                  purchaseToken: token,
                  itemType: 'membership',
                );
          }

          if (p.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(p);
          }

          if (!mounted) return;
          await _refreshUser();
          if (!mounted) return;
          await showPaymentSuccessDialog(context, type: PaymentSuccessType.membership);
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
        await showPaymentSuccessDialog(context, type: PaymentSuccessType.membership);
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

  VipPlanBadgeType _badgeForIndex(int index, int total) {
    if (total == 1) return VipPlanBadgeType.hot;
    if (index == 0) return VipPlanBadgeType.hot;
    if (index == total - 1) return VipPlanBadgeType.bestChoice;
    return VipPlanBadgeType.mostPopular;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);

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
            // Top Ambient Golden / Warm Glow
            Positioned(
              top: -60,
              left: 0,
              right: 0,
              height: 300,
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.6),
                      radius: 0.9,
                      colors: [
                        Color(0x30d97706),
                        Color(0x1578350f),
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
                  // App Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Row(
                      children: [
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
                        Expanded(
                          child: Text(
                            t.t('vip_membership_benefits'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
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
                      color: const Color(0xffffb800),
                      backgroundColor: const Color(0xff15141b),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                        children: [
                          // Top VIP Membership Benefits Card
                          _buildBenefitsHeaderCard(t),

                          const SizedBox(height: 22),

                          // Section Title: "Choose your plan"
                          Text(
                            t.t('choose_your_plan'),
                            style: const TextStyle(
                              color: Color(0xfff0f0f5),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          const SizedBox(height: 14),

                          if (_loading)
                            Column(
                              children: const [
                                VipPlanShimmerCard(),
                                SizedBox(height: 18),
                                VipPlanShimmerCard(),
                                SizedBox(height: 18),
                                VipPlanShimmerCard(),
                              ],
                            )
                          else if (_error != null)
                            WalletErrorState(onRetry: _loadAll)
                          else if (_membershipPackages.isEmpty)
                            WalletEmptyState(text: t.t('no_packages'))
                          else
                            Column(
                              children: [
                                for (var i = 0; i < _membershipPackages.length; i++) ...[
                                  VipPlanCard(
                                    pkg: _membershipPackages[i],
                                    isSelected: _selectedCode == _membershipPackages[i].code,
                                    badgeType: _badgeForIndex(i, _membershipPackages.length),
                                    onTap: _buying ? null : () => _buyMembership(_membershipPackages[i]),
                                  ),
                                  if (i != _membershipPackages.length - 1)
                                    const SizedBox(height: 18),
                                ],
                              ],
                            ),
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
                            color: Color(0xffffb800),
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

  Widget _buildBenefitsHeaderCard(AppI18n t) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                'assets/images/bg_product_sub_customer2.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),

            // Content on top of background
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.t('vip_membership_benefits'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildBenefitRow(t.t('vip_benefit_full_access')),
                  const SizedBox(height: 10),
                  _buildBenefitRow(t.t('vip_benefit_no_ads')),
                  const SizedBox(height: 10),
                  _buildBenefitRow(t.t('vip_benefit_ultra_hd')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(String text) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xffffb800), Color(0xffff9900)],
            ),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xff121212),
            size: 14,
            weight: 900,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
