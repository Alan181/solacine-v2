import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/i18n.dart';
import '../data/wallet_api.dart';

// Fungsi helper pemformatan harga dinamis (IDR vs mata uang lain)
String _formatCurrency(num amount, String? currency) {
  final curr = (currency == null || currency.isEmpty) ? 'IDR' : currency.toUpperCase();
  
  if (curr == 'IDR') {
    final formattedNumber = amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $formattedNumber';
  }

  final symbol = curr == 'USD'
      ? '\$'
      : (curr == 'EUR'
          ? '€'
          : (curr == 'GBP'
              ? '£'
              : ''));
  final formatted = amount.toDouble().toStringAsFixed(2);
  if (symbol.isNotEmpty) {
    return '$symbol$formatted';
  }
  return '$formatted $curr';
}

class PurchaseHistoryScreen extends ConsumerStatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  ConsumerState<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends ConsumerState<PurchaseHistoryScreen> {
  final _scrollController = ScrollController();

  Object? _error;
  bool _loading = true;

  final List<PaymentOrderDto> _orders = [];
  WalletPagination? _ordersPagination;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(_loadOrders);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final pos = _scrollController.position.pixels;
    if (max - pos < 240) {
      _loadMore();
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await ref.read(walletApiProvider).paymentOrders(page: 1, perPage: 20);
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(page.items);
        _ordersPagination = page.pagination;
      });
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

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final p = _ordersPagination;
    if (p == null || p.currentPage >= p.lastPage) return;

    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(walletApiProvider).paymentOrders(page: p.currentPage + 1, perPage: p.perPage);
      if (!mounted) return;
      setState(() {
        _orders.addAll(page.items);
        _ordersPagination = page.pagination;
      });
    } catch (_) {
      // Ignore pagination errors
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final showError = _error != null && !_loading && _orders.isEmpty;

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0C0D0E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0C0D0E),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: _goBack,
            icon: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF18191D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF26282E)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFFE4E4E7)),
            ),
          ),
          title: Text(
            t.t('purchase_history'),
            style: const TextStyle(
              color: Color(0xFFF4F4F5),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _loadOrders,
              tooltip: t.t('retry'),
              icon: const Icon(
                Icons.refresh_rounded,
                size: 19,
                color: Color(0xFFA1A1AA),
              ),
            ),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 4)),
          ],
        ),
        body: showError
            ? RefreshIndicator(
                onRefresh: _loadOrders,
                color: const Color(0xFFA1A1AA),
                backgroundColor: const Color(0xFF18191D),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  children: [
                    _ErrorState(onRetry: _loadOrders),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadOrders,
                color: const Color(0xFFA1A1AA),
                backgroundColor: const Color(0xFF18191D),
                child: _loading && _orders.isEmpty
                    ? _buildSkeletonList()
                    : _orders.isEmpty
                        ? _buildEmptyState(t)
                        : _buildOrdersList(t),
              ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF131418),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1E2026)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1E24),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 110,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22242B),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 5)),
                    Container(
                      width: 70,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1C22),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 50,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF22242B),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AppI18n t) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF16171B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF26282E)),
                ),
                child: const Center(
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 28,
                    color: Color(0xFF71717A),
                  ),
                ),
              ),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 16)),
              Text(
                t.t('no_transactions'),
                style: const TextStyle(
                  color: Color(0xFFE4E4E7),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 6)),
              const Text(
                'All completed purchase records will be listed here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersList(AppI18n t) {
    final list = <Widget>[];
    String? currentDay;

    for (var i = 0; i < _orders.length; i++) {
      final order = _orders[i];
      final dt = order.createdAt;
      final day = dt == null ? '' : _formatDay(dt);

      if (currentDay != day) {
        currentDay = day;
        list.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Row(
              children: [
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 11)),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 5)),
                Text(
                  day.isEmpty ? '—' : day,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      list.add(_CompactOrderCard(
        item: order,
        onTap: () => _showOrderDetailsSheet(context, order, t),
      ));
    }

    if (_loadingMore) {
      list.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: Color(0xFF71717A), strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      children: list,
    );
  }

  void _showOrderDetailsSheet(BuildContext context, PaymentOrderDto order, AppI18n t) {
    final isVip = order.itemType == 'vip' || order.packageName.toLowerCase().contains('vip');
    final dt = order.createdAt;
    final dateFormatted = dt == null ? '—' : '${_formatDay(dt)} ${_formatTime(dt)}';
    final isPaid = order.status.trim().toLowerCase() == 'paid' || order.paidAt != null;
    final formattedPrice = _formatCurrency(order.amount, order.currency);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF141518),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: Color(0xFF26282E)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3F3F46),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 14)),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2026),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2E3038)),
                      ),
                      child: Center(
                        child: Icon(
                          isVip ? Icons.badge_outlined : Icons.receipt_outlined,
                          color: const Color(0xFFD4D4D8),
                          size: 20,
                        ),
                      ),
                    ),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.packageName.isEmpty ? t.t('purchase') : order.packageName,
                            style: const TextStyle(
                              color: Color(0xFFF4F4F5),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 2)),
                          Text(
                            _providerLabel(t, order.provider),
                            style: const TextStyle(
                              color: Color(0xFF71717A),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(status: order.status, isPaid: isPaid),
                  ],
                ),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 16)),
                const Divider(color: Color(0xFF22242B), height: 1),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 12)),
                _DetailRow(label: 'Order Reference', value: order.paymentOrderId, canCopy: true),
                _DetailRow(label: 'Item Type', value: isVip ? 'VIP Membership' : 'Coin Package'),
                if (order.coins > 0)
                  _DetailRow(label: 'Coins Credited', value: '+${order.coins} Coins', highlightValue: true),
                _DetailRow(label: 'Date & Time', value: dateFormatted),
                _DetailRow(label: 'Payment Method', value: _providerLabel(t, order.provider)),
                _DetailRow(
                  label: 'Total Paid',
                  value: formattedPrice,
                  isBoldPrice: true,
                ),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 16)),
                SizedBox(
                  height: 42,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22242B),
                      foregroundColor: const Color(0xFFE4E4E7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CompactOrderCard extends StatelessWidget {
  const _CompactOrderCard({required this.item, required this.onTap});

  final PaymentOrderDto item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final isVip = item.itemType == 'vip' || item.packageName.toLowerCase().contains('vip');
    final dt = item.createdAt;
    final timeStr = dt == null ? '' : _formatTime(dt);
    final statusNorm = item.status.trim().toLowerCase();
    final isPaid = statusNorm == 'paid' || item.paidAt != null;
    final formattedPrice = _formatCurrency(item.amount, item.currency);

    final shortOrderId = item.paymentOrderId.isEmpty
        ? ''
        : (item.paymentOrderId.length > 10 ? item.paymentOrderId.substring(0, 10) : item.paymentOrderId);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF131418),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E2026)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              children: [
                // Compact formal icon
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1C22),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF262830)),
                  ),
                  child: Center(
                    child: Icon(
                      isVip ? Icons.badge_outlined : Icons.receipt_outlined,
                      size: 16,
                      color: const Color(0xFF9E9EA7),
                    ),
                  ),
                ),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 10)),
                // Title and provider
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.packageName.isEmpty ? t.t('purchase') : item.packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE4E4E7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 2)),
                      Row(
                        children: [
                          Text(
                            _providerLabel(t, item.provider),
                            style: const TextStyle(
                              color: Color(0xFF71717A),
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if (shortOrderId.isNotEmpty) ...[
                            const Text(
                              ' • ',
                              style: TextStyle(color: Color(0xFF3F3F46), fontSize: 10),
                            ),
                            Text(
                              '#$shortOrderId',
                              style: const TextStyle(
                                color: Color(0xFF52525B),
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                          if (timeStr.isNotEmpty) ...[
                            const Text(
                              ' • ',
                              style: TextStyle(color: Color(0xFF3F3F46), fontSize: 10),
                            ),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                color: Color(0xFF52525B),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 8)),
                // Amount and status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formattedPrice,
                      style: const TextStyle(
                        color: Color(0xFFF4F4F5),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 3)),
                    _StatusBadge(status: item.status, isPaid: isPaid, isCompact: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.isPaid, this.isCompact = false});

  final String status;
  final bool isPaid;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final statusNorm = status.trim().toLowerCase();

    Color bg;
    Color border;
    Color text;
    String label;
    IconData icon;

    if (isPaid || statusNorm == 'paid') {
      bg = const Color(0xFF13231B);
      border = const Color(0xFF1D3B2D);
      text = const Color(0xFF4ADE80);
      label = t.t('payment_status_paid');
      icon = Icons.check_circle_outline_rounded;
    } else if (statusNorm == 'pending' || statusNorm == 'processing') {
      bg = const Color(0xFF261E14);
      border = const Color(0xFF42321C);
      text = const Color(0xFFFBBF24);
      label = t.t('payment_status_pending');
      icon = Icons.schedule_rounded;
    } else {
      bg = const Color(0xFF241517);
      border = const Color(0xFF402024);
      text = const Color(0xFFF87171);
      label = t.t('payment_status_failed');
      icon = Icons.error_outline_rounded;
    }

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: border, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 9, color: text),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 3)),
            Text(
              label,
              style: TextStyle(color: text, fontSize: 9.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: text),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 4)),
          Text(
            label,
            style: TextStyle(color: text, fontSize: 10.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.canCopy = false,
    this.highlightValue = false,
    this.isBoldPrice = false,
  });

  final String label;
  final String value;
  final bool canCopy;
  final bool highlightValue;
  final bool isBoldPrice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF71717A),
              fontSize: 12,
            ),
          ),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 12)),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value.isEmpty ? '—' : value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: highlightValue
                          ? const Color(0xFFE4E4E7)
                          : (isBoldPrice ? const Color(0xFFF4F4F5) : const Color(0xFFD4D4D8)),
                      fontSize: isBoldPrice ? 14 : 12,
                      fontWeight: (highlightValue || isBoldPrice) ? FontWeight.w600 : FontWeight.w400,
                      fontFamily: canCopy ? 'monospace' : null,
                    ),
                  ),
                ),
                if (canCopy && value.isNotEmpty) ...[
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 6)),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Order reference copied to clipboard'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22242B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.copy_rounded, size: 11, color: Color(0xFFA1A1AA)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDay(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

String _formatTime(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String _providerLabel(AppI18n t, String provider) {
  switch (provider.trim().toLowerCase()) {
    case 'admin':
      return t.t('admin');
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
    case 'duitku':
      return 'Duitku';
    case 'midtrans':
      return 'Midtrans'; // Ditambahkan agar Midtrans muncul dengan rapi
    case 'google_play':
      return t.t('google_play');
    case 'app_store':
    case 'apple':
      return t.t('apple_app_store');
    default:
      return provider.isEmpty ? 'Direct' : provider;
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141518),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF26282E)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 30, color: Color(0xFF71717A)),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 10)),
          Text(
            t.t('request_failed'),
            style: const TextStyle(color: Color(0xFFE4E4E7), fontSize: 13, fontWeight: FontWeight.w500),
          ),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 14)),
          SizedBox(
            height: 38,
            width: double.infinity,
            child: FilledButton(
              onPressed: () => onRetry(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF26282E),
                foregroundColor: const Color(0xFFF4F4F5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(t.t('retry'), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
