import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/i18n.dart';
import '../../../shared/data/shared_prefs_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_api.dart';
import '../data/wallet_api.dart';
import 'payment_success_dialog.dart';

class PaymentReturnScreen extends ConsumerStatefulWidget {
  const PaymentReturnScreen({
    super.key,
    required this.paymentOrderId,
    required this.provider,
    required this.status,
  });

  final String paymentOrderId;
  final String provider;
  final String status;

  @override
  ConsumerState<PaymentReturnScreen> createState() => _PaymentReturnScreenState();
}

class _PaymentReturnScreenState extends ConsumerState<PaymentReturnScreen> {
  bool _working = true;
  static const _kPendingGatewayOrderIdKey = 'pending_gateway_payment_order_id';

  @override
  void initState() {
    super.initState();
    Future.microtask(_process);
  }

  Future<void> _refreshUser() async {
    final fresh = await ref.read(authApiProvider).me();
    await ref.read(authSessionProvider.notifier).setUser(fresh);
  }

  Future<void> _process() async {
    final t = AppI18n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final orderId = widget.paymentOrderId.trim();
    final status = widget.status.trim().toLowerCase();
    if (orderId.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(t.t('payment_failed'))));
      if (mounted) context.go('/wallet');
      return;
    }

    if (status == 'cancel' || status == 'canceled' || status == 'failed') {
      messenger.showSnackBar(SnackBar(content: Text(t.t('payment_failed'))));
      if (mounted) context.go('/wallet');
      return;
    }

    // If order was already handled and cleared by the in-app webview flow, avoid redundant verification
    final prefs = await ref.read(sharedPrefsProvider.future);
    final pendingOrder = prefs.getString(_kPendingGatewayOrderIdKey)?.trim();
    if (pendingOrder == null || pendingOrder.isEmpty || pendingOrder != orderId) {
      if (mounted) context.go('/wallet');
      return;
    }

    String? finalStatus;
    bool isMembershipOrder = false;
    for (var i = 0; i < 10; i++) {
      try {
        final st = await ref.read(walletApiProvider).orderStatus(paymentOrderId: orderId);
        finalStatus = st.status.trim().toLowerCase();
        
        // Periksa apakah item berupa membership berdasarkan data order jika tersedia
        if (st.itemType != null && st.itemType!.toLowerCase().contains('membership')) {
          isMembershipOrder = true;
        }

        if (finalStatus == 'paid') break;
        if (finalStatus == 'failed' || finalStatus == 'canceled' || finalStatus == 'cancel') break;
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;

    if (finalStatus == 'paid') {
      try {
        await _refreshUser();
      } catch (_) {}
      if (!mounted) return;
      try {
        final prefs = await ref.read(sharedPrefsProvider.future);
        await prefs.remove(_kPendingGatewayOrderIdKey);
      } catch (_) {}
      if (!mounted) return;

      // Tampilkan dialog sukses dengan tipe yang sesuai, arahkan ke wallet setelah tombol OK ditekan
      await showPaymentSuccessDialog(
        context,
        type: isMembershipOrder ? PaymentSuccessType.membership : PaymentSuccessType.coins,
        onConfirm: () {
          if (mounted) context.go('/wallet');
        },
      );

      if (mounted) {
        context.go('/wallet');
      }
      return;
    } else if (finalStatus == 'failed' || finalStatus == 'canceled' || finalStatus == 'cancel') {
      messenger.showSnackBar(SnackBar(content: Text(t.t('payment_failed'))));
      try {
        final prefs = await ref.read(sharedPrefsProvider.future);
        await prefs.remove(_kPendingGatewayOrderIdKey);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _working = false);
    context.go('/wallet');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    return Scaffold(
      backgroundColor: const Color(0xff050505),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white.withValues(alpha: 0.90),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _working ? t.t('payment_status_pending') : '',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
