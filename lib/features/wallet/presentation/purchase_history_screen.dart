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

class _PurchaseHistoryScreenState extends ConsumerState<PurchaseHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Diubah menjadi 4 tab (ditambah Pendapatan)
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF71717A),
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            isScrollable: true,
            tabs: const [
              Tab(text: 'Pembelian'),
              Tab(text: 'Pendapatan'),
              Tab(text: 'Penukaran'),
              Tab(text: 'Penarikan'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            _OrdersTabWidget(),
            _EarningsTabWidget(),
            _ConversionsTabWidget(),
            _WithdrawalsTabWidget(),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TAB 1: PEMBELIAN (PURCHASE ORDERS)
// ==========================================
class _OrdersTabWidget extends ConsumerStatefulWidget {
  const _OrdersTabWidget();

  @override
  ConsumerState<_OrdersTabWidget> createState() => _OrdersTabWidgetState();
}

class _OrdersTabWidgetState extends ConsumerState<_OrdersTabWidget> {
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
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final showError = _error != null && !_loading && _orders.isEmpty;

    if (showError) {
      return RefreshIndicator(
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
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: const Color(0xFFA1A1AA),
      backgroundColor: const Color(0xFF18191D),
      child: _loading && _orders.isEmpty
          ? _buildSkeletonList()
          : _orders.isEmpty
              ? _buildEmptyState(t)
              : _buildOrdersList(t),
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
              const SizedBox(width: 10),
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
                    const SizedBox(height: 5),
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
              const SizedBox(height: 16),
              Text(
                t.t('no_transactions'),
                style: const TextStyle(
                  color: Color(0xFFE4E4E7),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
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
                const SizedBox(height: 14),
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
                    const SizedBox(width: 12),
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
                          const SizedBox(height: 2),
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
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF22242B), height: 1),
                const SizedBox(height: 12),
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
                const SizedBox(height: 16),
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

// ==========================================
// TAB 2: PENDAPATAN KOIN (EARNINGS)
// ==========================================
class _EarningsTabWidget extends ConsumerStatefulWidget {
  const _EarningsTabWidget();

  @override
  ConsumerState<_EarningsTabWidget> createState() => _EarningsTabWidgetState();
}

class _EarningsTabWidgetState extends ConsumerState<_EarningsTabWidget> {
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  WalletPagination? _pagination;
  final List<CoinEarningsDto> _items = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(_loadData);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent - _scrollController.position.pixels < 240) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(walletApiProvider).coinEarnings(page: 1);
      if (!mounted) return;
      setState(() {
        _items.clear();
        _items.addAll(res.items);
        _pagination = res.pagination;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final p = _pagination;
    if (p == null || p.currentPage >= p.lastPage) return;

    setState(() => _loadingMore = true);
    try {
      final res = await ref.read(walletApiProvider).coinEarnings(page: p.currentPage + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _pagination = res.pagination;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  IconData _getEarningIcon(String sourceType) {
    final t = sourceType.toLowerCase();
    if (t.contains('check')) return Icons.event_available_rounded;
    if (t.contains('minute') || t.contains('watch')) return Icons.play_circle_outline_rounded;
    if (t.contains('task')) return Icons.task_alt_rounded;
    if (t.contains('drama')) return Icons.movie_outlined;
    return Icons.monetization_on_outlined;
  }

  String _formatSourceLabel(String sourceType) {
    final t = sourceType.toLowerCase();
    if (t.contains('checkin') || t.contains('check_in')) return 'Daily Check-in';
    if (t.contains('minute') || t.contains('watch')) return 'Reward Tonton 1 Menit';
    if (t.contains('task')) return 'Task Reward';
    if (t.contains('drama')) return 'Reward Drama';
    return sourceType.isEmpty ? 'Pendapatan Koin' : sourceType;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF71717A), strokeWidth: 2));
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFFA1A1AA),
        backgroundColor: const Color(0xFF18191D),
        child: ListView(
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
                    child: const Center(child: Icon(Icons.savings_outlined, size: 28, color: Color(0xFF71717A))),
                  ),
                  const SizedBox(height: 16),
                  const Text('Belum ada riwayat pendapatan', style: TextStyle(color: Color(0xFFE4E4E7), fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('Pendapatan dari check-in, task, drama, dan tonton 1 menit akan tampil di sini.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF71717A), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFA1A1AA),
      backgroundColor: const Color(0xFF18191D),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final dt = item.createdAt;
          final dateStr = dt == null ? '' : '${_formatDay(dt)} ${_formatTime(dt)}';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF131418),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E2026)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1C22),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF262830)),
                  ),
                  child: Center(child: Icon(_getEarningIcon(item.sourceType), size: 16, color: const Color(0xFF9E9EA7))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatSourceLabel(item.sourceType), style: const TextStyle(color: Color(0xFFE4E4E7), fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(dateStr, style: const TextStyle(color: Color(0xFF71717A), fontSize: 11)),
                    ],
                  ),
                ),
                Text(
                  '+${item.coins} Koin',
                  style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// TAB 3: RIWAYAT KONVERSI KOIN
// ==========================================
class _ConversionsTabWidget extends ConsumerStatefulWidget {
  const _ConversionsTabWidget();

  @override
  ConsumerState<_ConversionsTabWidget> createState() => _ConversionsTabWidgetState();
}

class _ConversionsTabWidgetState extends ConsumerState<_ConversionsTabWidget> {
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  WalletPagination? _pagination;
  final List<CoinConversionDto> _items = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(_loadData);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent - _scrollController.position.pixels < 240) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(walletApiProvider).coinConversions(page: 1);
      if (!mounted) return;
      setState(() {
        _items.clear();
        _items.addAll(res.items);
        _pagination = res.pagination;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final p = _pagination;
    if (p == null || p.currentPage >= p.lastPage) return;

    setState(() => _loadingMore = true);
    try {
      final res = await ref.read(walletApiProvider).coinConversions(page: p.currentPage + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _pagination = res.pagination;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF71717A), strokeWidth: 2));
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFFA1A1AA),
        backgroundColor: const Color(0xFF18191D),
        child: ListView(
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
                    child: const Center(child: Icon(Icons.currency_exchange_rounded, size: 28, color: Color(0xFF71717A))),
                  ),
                  const SizedBox(height: 16),
                  const Text('Belum ada riwayat konversi koin', style: TextStyle(color: Color(0xFFE4E4E7), fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('Riwayat penukaran koin Anda akan muncul di sini.', style: TextStyle(color: Color(0xFF71717A), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFA1A1AA),
      backgroundColor: const Color(0xFF18191D),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final dt = item.createdAt;
          final dateStr = dt == null ? '' : '${_formatDay(dt)} ${_formatTime(dt)}';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF131418),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E2026)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1C22),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF262830)),
                  ),
                  child: const Center(child: Icon(Icons.repeat_rounded, size: 16, color: Color(0xFF9E9EA7))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tukar ${item.coinsConverted} Koin', style: const TextStyle(color: Color(0xFFE4E4E7), fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(dateStr, style: const TextStyle(color: Color(0xFF71717A), fontSize: 11)),
                    ],
                  ),
                ),
                Text(
                  '+Rp ${item.cashReceived.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                  style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// TAB 4: RIWAYAT PENARIKAN (WITHDRAW)
// ==========================================
class _WithdrawalsTabWidget extends ConsumerStatefulWidget {
  const _WithdrawalsTabWidget();

  @override
  ConsumerState<_WithdrawalsTabWidget> createState() => _WithdrawalsTabWidgetState();
}

class _WithdrawalsTabWidgetState extends ConsumerState<_WithdrawalsTabWidget> {
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  WalletPagination? _pagination;
  final List<WithdrawRequestDto> _items = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(_loadData);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent - _scrollController.position.pixels < 240) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(walletApiProvider).withdrawRequestsHistory(page: 1);
      if (!mounted) return;
      setState(() {
        _items.clear();
        _items.addAll(res.items);
        _pagination = res.pagination;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final p = _pagination;
    if (p == null || p.currentPage >= p.lastPage) return;

    setState(() => _loadingMore = true);
    try {
      final res = await ref.read(walletApiProvider).withdrawRequestsHistory(page: p.currentPage + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _pagination = res.pagination;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF71717A), strokeWidth: 2));
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFFA1A1AA),
        backgroundColor: const Color(0xFF18191D),
        child: ListView(
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
                    child: const Center(child: Icon(Icons.account_balance_wallet_outlined, size: 28, color: Color(0xFF71717A))),
                  ),
                  const SizedBox(height: 16),
                  const Text('Belum ada riwayat penarikan', style: TextStyle(color: Color(0xFFE4E4E7), fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('Permintaan tarik saldo DANA/GoPay Anda akan tampil di sini.', style: TextStyle(color: Color(0xFF71717A), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFA1A1AA),
      backgroundColor: const Color(0xFF18191D),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final dt = item.createdAt;
          final dateStr = dt == null ? '' : '${_formatDay(dt)} ${_formatTime(dt)}';
          final statusNorm = item.status.trim().toLowerCase();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF131418),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E2026)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1C22),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF262830)),
                  ),
                  child: const Center(child: Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF9E9EA7))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tarik ke ${item.walletType}', style: const TextStyle(color: Color(0xFFE4E4E7), fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(item.walletNumber, style: const TextStyle(color: Color(0xFF71717A), fontSize: 11, fontFamily: 'monospace')),
                          const Text(' • ', style: TextStyle(color: Color(0xFF3F3F46), fontSize: 10)),
                          Text(dateStr, style: const TextStyle(color: Color(0xFF71717A), fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '-Rp ${item.amountIdr.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                      style: const TextStyle(color: Color(0xFFF87171), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: statusNorm == 'paid' || statusNorm == 'success' ? const Color(0xFF13231B) : const Color(0xFF261E14),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: statusNorm == 'paid' || statusNorm == 'success' ? const Color(0xFF1D3B2D) : const Color(0xFF42321C),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        statusNorm.toUpperCase(),
                        style: TextStyle(
                          color: statusNorm == 'paid' || statusNorm == 'success' ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// WIDGET PENDUKUNG & HELPER LAINNYA
// ==========================================
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
                const SizedBox(width: 10),
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
                      const SizedBox(height: 2),
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
                            const Text(' • ', style: TextStyle(color: Color(0xFF3F3F46), fontSize: 10)),
                            Text('#$shortOrderId', style: const TextStyle(color: Color(0xFF52525B), fontSize: 10.5, fontFamily: 'monospace')),
                          ],
                          if (timeStr.isNotEmpty) ...[
                            const Text(' • ', style: TextStyle(color: Color(0xFF3F3F46), fontSize: 10)),
                            Text(timeStr, style: const TextStyle(color: Color(0xFF52525B), fontSize: 10.5)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                    const SizedBox(height: 3),
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
            const SizedBox(width: 3),
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
          const SizedBox(width: 4),
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
          const SizedBox(width: 12),
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
                  const SizedBox(width: 6),
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
      return 'Midtrans';
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
          const SizedBox(height: 10),
          Text(
            t.t('request_failed'),
            style: const TextStyle(color: Color(0xFFE4E4E7), fontSize: 13, fontWeight: FontWeight.w500),
          ),
      const SizedBox(height: 14),
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
