import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

Import '../../../app/i18n.dart';
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
  Const PurchaseHistoryScreen({super.key});

  @override
  ConsumerState<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends ConsumerState<PurchaseHistoryScreen> {
  Final _scrollController = ScrollController();

  Object? _error;
  Bool _loading = true;

  Final List<PaymentOrderDto> _orders = [];
  WalletPagination? _ordersPagination;
  Bool _loadingMore = false;

  @override
  void initState() {
    Super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(_loadOrders);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Void _onScroll() {
    If (!_scrollController.hasClients) return;
    Final max = _scrollController.position.maxScrollExtent;
    Final pos = _scrollController.position.pixels;
    If (max - pos < 240) {
      _loadMore();
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    Try {
      Final page = await ref.read(walletApiProvider).paymentOrders(page: 1, perPage: 20);
      If (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(page.items);
        _ordersPagination = page.pagination;
      });
    } on DioException catch (e) {
      If (!mounted) return;
      setState(() => _error = e);
    } catch (e) {
      If (!mounted) return;
      setState(() => _error = e);
    } finally {
      If (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    If (_loadingMore) return;
    Final p = _ordersPagination;
    If (p == null || p.currentPage >= p.lastPage) return;

    setState(() => _loadingMore = true);
    Try {
      Final page = await ref.read(walletApiProvider).paymentOrders(page: p.currentPage + 1, perPage: p.perPage);
      If (!mounted) return;
      setState(() {
        _orders.addAll(page.items);
        _ordersPagination = page.pagination;
      });
    } catch (_) {
      // Ignore pagination errors
    } finally {
      If (mounted) setState(() => _loadingMore = false);
    }
  }

  Void _goBack() {
    If (context.canPop()) {
      Context.pop();
    } else {
      Context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    Final t = AppI18n.of(context);
    Final showError = _error != null && !_loading && _orders.isEmpty;

    Return PopScope(
      CanPop: context.canPop(),
      OnPopInvokedWithResult: (didPop, result) {
        If (didPop) return;
        _goBack();
      },
      Child: Scaffold(
        BackgroundColor: const Color(0xFF0C0D0E),
        AppBar: AppBar(
          BackgroundColor: const Color(0xFF0C0D0E),
          SurfaceTintColor: Colors.transparent,
          Elevation: 0,
          CenterTitle: true,
          Leading: IconButton(
            OnPressed: _goBack,
            Icon: Container(
              Width: 34,
              Height: 34,
              Decoration: BoxDecoration(
                Color: const Color(0xFF18191D),
                BorderRadius: BorderRadius.circular(8),
                Border: Border.all(color: const Color(0xFF26282E)),
              ),
              Child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFFE4E4E7)),
            ),
          ),
          Title: Text(
            T.t('purchase_history'),
            Style: const TextStyle(
              Color: Color(0xFFF4F4F5),
              FontSize: 16,
              FontWeight: FontWeight.w600,
              LetterSpacing: 0.2,
            ),
          ),
          Actions: [
            IconButton(
              OnPressed: _loadOrders,
              Tooltip: t.t('retry'),
              Icon: const Icon(
                Icons.refresh_rounded,
                Size: 19,
                Color: Color(0xFFA1A1AA),
              ),
            ),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 4)),
          ],
        ),
        Body: showError
            ? RefreshIndicator(
                OnRefresh: _loadOrders,
                Color: const Color(0xFFA1A1AA),
                BackgroundColor: const Color(0xFF18191D),
                Child: ListView(
                  Physics: const AlwaysScrollableScrollPhysics(),
                  Padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  Children: [
                    _ErrorState(onRetry: _loadOrders),
                  ],
                ),
              )
            : RefreshIndicator(
                OnRefresh: _loadOrders,
                Color: const Color(0xFFA1A1AA),
                BackgroundColor: const Color(0xFF18191D),
                Child: _loading && _orders.isEmpty
                    ? _buildSkeletonList()
                    : _orders.isEmpty
                        ? _buildEmptyState(t)
                        : _buildOrdersList(t),
              ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    Return ListView.builder(
      Physics: const AlwaysScrollableScrollPhysics(),
      Padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
      ItemCount: 8,
      ItemBuilder: (context, index) {
        Return Container(
          Margin: const EdgeInsets.only(bottom: 8),
          Padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          Decoration: BoxDecoration(
            Color: const Color(0xFF131418),
            BorderRadius: BorderRadius.circular(10),
            Border: Border.all(color: const Color(0xFF1E2026)),
          ),
          Child: Row(
            Children: [
              Container(
                Width: 32,
                Height: 32,
                Decoration: BoxDecoration(
                  Color: const Color(0xFF1C1E24),
                  BorderRadius: BorderRadius.circular(6),
                ),
              ),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 10)),
              Expanded(
                Child: Column(
                  CrossAxisAlignment: CrossAxisAlignment.start,
                  Children: [
                    Container(
                      Width: 110,
                      Height: 12,
                      Decoration: BoxDecoration(
                        Color: const Color(0xFF22242B),
                        BorderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 5)),
                    Container(
                      Width: 70,
                      Height: 9,
                      Decoration: BoxDecoration(
                        Color: const Color(0xFF1A1C22),
                        BorderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                Width: 50,
                Height: 14,
                Decoration: BoxDecoration(
                  Color: const Color(0xFF22242B),
                  BorderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AppI18n t) {
    Return ListView(
      Physics: const AlwaysScrollableScrollPhysics(),
      Padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
      Children: [
        Center(
          Child: Column(
            MainAxisAlignment: MainAxisAlignment.center,
            Children: [
              Container(
                Width: 64,
                Height: 64,
                Decoration: BoxDecoration(
                  Color: const Color(0xFF16171B),
                  Shape: BoxShape.circle,
                  Border: Border.all(color: const Color(0xFF26282E)),
                ),
                Child: const Center(
                  Child: Icon(
                    Icons.receipt_long_outlined,
                    Size: 28,
                    Color: Color(0xFF71717A),
                  ),
                ),
              ),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 16)),
              Text(
                T.t('no_transactions'),
                Style: const TextStyle(
                  Color: Color(0xFFE4E4E7),
                  FontSize: 15,
                  FontWeight: FontWeight.w600,
                ),
              ),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 6)),
              const Text(
                'All completed purchase records will be listed here.',
                TextAlign: TextAlign.center,
                Style: TextStyle(
                  Color: Color(0xFF71717A),
                  FontSize: 12,
                  Height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersList(AppI18n t) {
    Final list = <Widget>[];
    String? currentDay;

    For (var i = 0; i < _orders.length; i++) {
      Final order = _orders[i];
      Final dt = order.createdAt;
      Final day = dt == null ? '' : _formatDay(dt);

      If (currentDay != day) {
        CurrentDay = day;
        List.add(
          Padding(
            Padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            Child: Row(
              Children: [
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 11)),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 5)),
                Text(
                  Day.isEmpty ? '—' : day,
                  Style: const TextStyle(
                    Color: Color(0xFF8E8E93),
                    FontSize: 11,
                    FontWeight: FontWeight.w600,
                    LetterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      List.add(_CompactOrderCard(
        Item: order,
        OnTap: () => _showOrderDetailsSheet(context, order, t),
      ));
    }

    If (_loadingMore) {
      List.add(
        Const Padding(
          Padding: EdgeInsets.symmetric(vertical: 14),
          Child: Center(
            Child: SizedBox(
              Width: 18,
              Height: 18,
              Child: CircularProgressIndicator(color: Color(0xFF71717A), strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    Return ListView(
      Controller: _scrollController,
      Physics: const AlwaysScrollableScrollPhysics(),
      Padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      Children: list,
    );
  }

  Void _showOrderDetailsSheet(BuildContext context, PaymentOrderDto order, AppI18n t) {
    Final isVip = order.itemType == 'vip' || order.packageName.toLowerCase().contains('vip');
    Final dt = order.createdAt;
    Final dateFormatted = dt == null ? '—' : '${_formatDay(dt)} ${_formatTime(dt)}';
    Final isPaid = order.status.trim().toLowerCase() == 'paid' || order.paidAt != null;
    Final formattedPrice = _formatCurrency(order.amount, order.currency);

    ShowModalBottomSheet<void>(
      Context: context,
      BackgroundColor: Colors.transparent,
      IsScrollControlled: true,
      Builder: (ctx) {
        Return Container(
          Padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          Decoration: const BoxDecoration(
            Color: Color(0xFF141518),
            BorderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            Border: Border(
              Top: BorderSide(color: Color(0xFF26282E)),
            ),
          ),
          Child: SafeArea(
            Top: false,
            Child: Column(
              MainAxisSize: MainAxisSize.min,
              CrossAxisAlignment: CrossAxisAlignment.stretch,
              Children: [
                Center(
                  Child: Container(
                    Width: 32,
                    Height: 3.5,
                    Decoration: BoxDecoration(
                      Color: const Color(0xFF3F3F46),
                      BorderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 14)),
                Row(
                  Children: [
                    Container(
                      Width: 38,
                      Height: 38,
                      Decoration: BoxDecoration(
                        Color: const Color(0xFF1E2026),
                        BorderRadius: BorderRadius.circular(8),
                        Border: Border.all(color: const Color(0xFF2E3038)),
                      ),
                      Child: Center(
                        Child: Icon(
                          IsVip ? Icons.badge_outlined : Icons.receipt_outlined,
                          Color: const Color(0xFFD4D4D8),
                          Size: 20,
                        ),
                      ),
                    ),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 12)),
                    Expanded(
                      Child: Column(
                        CrossAxisAlignment: CrossAxisAlignment.start,
                        Children: [
                          Text(
                            Order.packageName.isEmpty ? t.t('purchase') : order.packageName,
                            Style: const TextStyle(
                              Color: Color(0xFFF4F4F5),
                              FontSize: 15,
                              FontWeight: FontWeight.w600,
                            ),
                          ),
                          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 2)),
                          Text(
                            _providerLabel(t, order.provider),
                            Style: const TextStyle(
                              Color: Color(0xFF71717A),
                              FontSize: 11,
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
                If (order.coins > 0)
                  _DetailRow(label: 'Coins Credited', value: '+${order.coins} Coins', highlightValue: true),
                _DetailRow(label: 'Date & Time', value: dateFormatted),
                _DetailRow(label: 'Payment Method', value: _providerLabel(t, order.provider)),
                _DetailRow(
                  Label: 'Total Paid',
                  Value: formattedPrice,
                  IsBoldPrice: true,
                ),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 16)),
                SizedBox(
                  Height: 42,
                  Child: FilledButton(
                    OnPressed: () => Navigator.pop(ctx),
                    Style: FilledButton.styleFrom(
                      BackgroundColor: const Color(0xFF22242B),
                      ForegroundColor: const Color(0xFFE4E4E7),
                      Shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    Child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
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
  Const _CompactOrderCard({required this.item, required this.onTap});

  Final PaymentOrderDto item;
  Final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Final t = AppI18n.of(context);
    Final isVip = item.itemType == 'vip' || item.packageName.toLowerCase().contains('vip');
    Final dt = item.createdAt;
    Final timeStr = dt == null ? '' : _formatTime(dt);
    Final statusNorm = item.status.trim().toLowerCase();
    Final isPaid = statusNorm == 'paid' || item.paidAt != null;
    Final formattedPrice = _formatCurrency(item.amount, item.currency);

    Final shortOrderId = item.paymentOrderId.isEmpty
        ? ''
        : (item.paymentOrderId.length > 10 ? item.paymentOrderId.substring(0, 10) : item.paymentOrderId);

    Return Container(
      Margin: const EdgeInsets.only(bottom: 6),
      Decoration: BoxDecoration(
        Color: const Color(0xFF131418),
        BorderRadius: BorderRadius.circular(10),
        Border: Border.all(color: const Color(0xFF1E2026)),
      ),
      Child: Material(
        Color: Colors.transparent,
        BorderRadius: BorderRadius.circular(10),
        Child: InkWell(
          OnTap: onTap,
          BorderRadius: BorderRadius.circular(10),
          Child: Padding(
            Padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            Child: Row(
              Children: [
                // Compact formal icon
                Container(
                  Width: 34,
                  Height: 34,
                  Decoration: BoxDecoration(
                    Color: const Color(0xFF1A1C22),
                    BorderRadius: BorderRadius.circular(8),
                    Border: Border.all(color: const Color(0xFF262830)),
                  ),
                  Child: Center(
                    Child: Icon(
                      IsVip ? Icons.badge_outlined : Icons.receipt_outlined,
                      Size: 16,
                      Color: const Color(0xFF9E9EA7),
                    ),
                  ),
                ),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 10)),
                // Title and provider
                Expanded(
                  Child: Column(
                    CrossAxisAlignment: CrossAxisAlignment.start,
                    MainAxisSize: MainAxisSize.min,
                    Children: [
                      Text(
                        Item.packageName.isEmpty ? t.t('purchase') : item.packageName,
                        MaxLines: 1,
                        Overflow: TextOverflow.ellipsis,
                        Style: const TextStyle(
                          Color: Color(0xFFE4E4E7),
                          FontSize: 13,
                          FontWeight: FontWeight.w600,
                        ),
                      ),
                      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 2)),
                      Row(
                        Children: [
                          Text(
                            _providerLabel(t, item.provider),
                            Style: const TextStyle(
                              Color: Color(0xFF71717A),
                              FontSize: 11,
                              FontWeight: FontWeight.w400,
                            ),
                          ),
                          If (shortOrderId.isNotEmpty) ...[
                            Const Text(
                              ' • ',
                              Style: TextStyle(color: Color(0xFF3F3F46), fontSize: 10),
                            ),
                            Text(
                              '#$shortOrderId',
                              Style: const TextStyle(
                                Color: Color(0xFF52525B),
                                FontSize: 10.5,
                                FontFamily: 'monospace',
                              ),
                            ),
                          ],
                          If (timeStr.isNotEmpty) ...[
                            Const Text(
                              ' • ',
                              Style: TextStyle(color: Color(0xFF3F3F46), fontSize: 10),
                            ),
                            Text(
                              TimeStr,
                              Style: const TextStyle(
                                Color: Color(0xFF52525B),
                                FontSize: 10.5,
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
                  CrossAxisAlignment: CrossAxisAlignment.end,
                  MainAxisSize: MainAxisSize.min,
                  Children: [
                    Text(
                      FormattedPrice,
                      Style: const TextStyle(
                        Color: Color(0xFFF4F4F5),
                        FontSize: 13,
                        FontWeight: FontWeight.w600,
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
  Const _StatusBadge({required this.status, required this.isPaid, this.isCompact = false});

  Final String status;
  Final bool isPaid;
  Final bool isCompact;

  @override
  Widget build(BuildContext context) {
    Final t = AppI18n.of(context);
    Final statusNorm = status.trim().toLowerCase();

    Color bg;
    Color border;
    Color text;
    String label;
    IconData icon;

    If (isPaid || statusNorm == 'paid') {
      Bg = const Color(0xFF13231B);
      Border = const Color(0xFF1D3B2D);
      Text = const Color(0xFF4ADE80);
      Label = t.t('payment_status_paid');
      Icon = Icons.check_circle_outline_rounded;
    } else if (statusNorm == 'pending' || statusNorm == 'processing') {
      Bg = const Color(0xFF261E14);
      Border = const Color(0xFF42321C);
      Text = const Color(0xFFFBBF24);
      Label = t.t('payment_status_pending');
      Icon = Icons.schedule_rounded;
    } else {
      Bg = const Color(0xFF241517);
      Border = const Color(0xFF402024);
      Text = const Color(0xFFF87171);
      Label = t.t('payment_status_failed');
      Icon = Icons.error_outline_rounded;
    }

    If (isCompact) {
      Return Container(
        Padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
        Decoration: BoxDecoration(
          Color: bg,
          BorderRadius: BorderRadius.circular(4),
          Border: Border.all(color: border, width: 0.8),
        ),
        Child: Row(
          MainAxisSize: MainAxisSize.min,
          Children: [
            Icon(icon, size: 9, color: text),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 3)),
            Text(
              Label,
              Style: TextStyle(color: text, fontSize: 9.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    Return Container(
      Padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      Decoration: BoxDecoration(
        Color: bg,
        BorderRadius: BorderRadius.circular(6),
        Border: Border.all(color: border),
      ),
      Child: Row(
        MainAxisSize: MainAxisSize.min,
        Children: [
          Icon(icon, size: 11, color: text),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 4)),
          Text(
            Label,
            Style: TextStyle(color: text, fontSize: 10.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  Const _DetailRow({
    Required this.label,
    Required this.value,
    This.canCopy = false,
    This.highlightValue = false,
    This.isBoldPrice = false,
  });

  Final String label;
  Final String value;
  Final bool canCopy;
  Final bool highlightValue;
  Final bool isBoldPrice;

  @override
  Widget build(BuildContext context) {
    Return Padding(
      Padding: const EdgeInsets.symmetric(vertical: 4.5),
      Child: Row(
        MainAxisAlignment: MainAxisAlignment.spaceBetween,
        Children: [
          Text(
            Label,
            Style: const TextStyle(
              Color: Color(0xFF71717A),
              FontSize: 12,
            ),
          ),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 12)),
          Flexible(
            Child: Row(
              MainAxisSize: MainAxisSize.min,
              Children: [
                Flexible(
                  Child: Text(
                    Value.isEmpty ? '—' : value,
                    Overflow: TextOverflow.ellipsis,
                    Style: TextStyle(
                      Color: highlightValue
                          ? const Color(0xFFE4E4E7)
                          : (isBoldPrice ? const Color(0xFFF4F4F5) : const Color(0xFFD4D4D8)),
                      FontSize: isBoldPrice ? 14 : 12,
                      FontWeight: (highlightValue || isBoldPrice) ? FontWeight.w600 : FontWeight.w400,
                      FontFamily: canCopy ? 'monospace' : null,
                    ),
                  ),
                ),
                If (canCopy && value.isNotEmpty) ...[
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 6)),
                  GestureDetector(
                    OnTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        Const SnackBar(
                          Content: Text('Order reference copied to clipboard'),
                          Duration: Duration(seconds: 2),
                          Behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    Child: Container(
                      Padding: const EdgeInsets.all(3),
                      Decoration: BoxDecoration(
                        Color: const Color(0xFF22242B),
                        BorderRadius: BorderRadius.circular(4),
                      ),
                      Child: const Icon(Icons.copy_rounded, size: 11, color: Color(0xFFA1A1AA)),
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
  Return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

String _formatTime(DateTime dt) {
  Return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String _providerLabel(AppI18n t, String provider) {
  Switch (provider.trim().toLowerCase()) {
    Case 'admin':
      Return t.t('admin');
    Case 'stripe':
      Return t.t('stripe');
    Case 'paypal':
      Return t.t('paypal');
    Case 'flutterwave':
      Return t.t('flutterwave');
    Case 'razorpay':
      Return t.t('razorpay');
    Case 'google_play':
      Return t.t('google_play');
    Case 'app_store':
    Case 'apple':
      Return t.t('apple_app_store');
    Default:
      Return provider.isEmpty ? 'Direct' : provider;
  }
}

class _ErrorState extends StatelessWidget {
  Const _ErrorState({required this.onRetry});

  Final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    Final t = AppI18n.of(context);
    Return Container(
      Padding: const EdgeInsets.all(18),
      Decoration: BoxDecoration(
        Color: const Color(0xFF141518),
        BorderRadius: BorderRadius.circular(12),
        Border: Border.all(color: const Color(0xFF26282E)),
      ),
      Child: Column(
        Children: [
          Const Icon(Icons.cloud_off_rounded, size: 30, color: Color(0xFF71717A)),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 10)),
          Text(
            T.t('request_failed'),
            Style: const TextStyle(color: Color(0xFFE4E4E7), fontSize: 13, fontWeight: FontWeight.w500),
          ),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 14)),
          SizedBox(
            Height: 38,
            Width: double.infinity,
            Child: FilledButton(
              OnPressed: () => onRetry(),
              Style: FilledButton.styleFrom(
                BackgroundColor: const Color(0xFF26282E),
                ForegroundColor: const Color(0xFFF4F4F5),
                Shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              Child: Text(t.t('retry'), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
