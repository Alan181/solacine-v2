import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/i18n.dart';
import '../../auth/application/auth_controller.dart';
import '../data/support_ticket_api.dart';

class SupportTicketsScreen extends ConsumerStatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  ConsumerState<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends ConsumerState<SupportTicketsScreen> {
  final List<SupportTicketSummary> _items = <SupportTicketSummary>[];
  Object? _error;
  bool _loading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _creating = false;
  int _page = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(reset: true, showLoader: true));
  }

  Future<void> _load({required bool reset, required bool showLoader}) async {
    if (reset) {
      _page = 1;
      _lastPage = 1;
    }

    final shouldShowLoader = showLoader || (_items.isEmpty && reset);
    setState(() {
      _error = null;
      _loading = shouldShowLoader;
      _refreshing = !shouldShowLoader;
    });

    try {
      final res = await ref.read(supportTicketApiProvider).list(page: 1);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(res.items);
        _page = res.currentPage;
        _lastPage = res.lastPage;
      });
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401 || code == 403) {
        await ref.read(authSessionProvider.notifier).logout();
        return;
      }
      if (!mounted) return;
      setState(() => _error = e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    if (_page >= _lastPage) return;

    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final res = await ref.read(supportTicketApiProvider).list(page: next);
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _page = res.currentPage;
        _lastPage = res.lastPage;
      });
    } catch (_) {
      return;
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _open(SupportTicketSummary item) async {
    final res = await context.push<SupportTicketDetails>(
      '/support/${item.id}',
      extra: item.subject,
    );
    if (!mounted) return;
    if (res == null) return;
    await _load(reset: true, showLoader: false);
  }

  Future<void> _createTicket() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final created = await showModalBottomSheet<_CreateTicketResult?>(
        context: context,
        backgroundColor: const Color(0xff0b0b0b),
        showDragHandle: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (context) => const _CreateTicketSheet(),
      );

      if (!mounted) return;
      if (created == null) return;

      final id = await ref.read(supportTicketApiProvider).create(
            subject: created.subject,
            message: created.message,
          );
      if (id <= 0) return;
      if (!mounted) return;
      await _load(reset: true, showLoader: false);
      if (!mounted) return;
      await context.push('/support/$id', extra: created.subject);
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401 || code == 403) {
        await ref.read(authSessionProvider.notifier).logout();
        return;
      }
      return;
    } catch (_) {
      return;
    } finally {
      if (mounted) setState(() => _creating = false);
    }
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

    return Scaffold(
      backgroundColor: const Color(0xff050505),
      floatingActionButton: FloatingActionButton(
        onPressed: _creating ? null : _createTicket,
        backgroundColor: const Color(0xfffbbf24),
        foregroundColor: const Color(0xff111827),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: goBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: Colors.white.withValues(alpha: 0.90),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.t('support_tickets'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _creating ? null : _createTicket,
                    icon: const Icon(Icons.add_rounded),
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
            if (_refreshing)
              const SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  color: Colors.white,
                  backgroundColor: Colors.transparent,
                ),
              ),
            Expanded(
              child: (_loading && _items.isEmpty)
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : RefreshIndicator(
                      onRefresh: () => _load(reset: true, showLoader: false),
                      color: Colors.white,
                      backgroundColor: const Color(0xff0b0b0b),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 120) {
                            _loadMore();
                          }
                          return false;
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                          children: [
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                                ),
                                child: Text(
                                  t.t('request_failed'),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.70),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_items.isEmpty && _error == null) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Text(
                                  t.t('no_support_tickets'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ] else ...[
                              ..._items.map((it) {
                                final closed = it.isClosed;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
                                    onTap: () => _open(it),
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  it.subject,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.92),
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: closed
                                                      ? Colors.white.withValues(alpha: 0.06)
                                                      : const Color(0xff10b981).withValues(alpha: 0.14),
                                                  borderRadius: BorderRadius.circular(999),
                                                  border: Border.all(
                                                    color: closed
                                                        ? Colors.white.withValues(alpha: 0.10)
                                                        : const Color(0xff10b981).withValues(alpha: 0.25),
                                                  ),
                                                ),
                                                child: Text(
                                                  closed ? t.t('ticket_closed') : t.t('open'),
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: closed ? 0.70 : 0.90),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (it.lastMessage.trim().isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              it.lastMessage,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.70),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              if (_loadingMore)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white.withValues(alpha: 0.80),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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

class _CreateTicketResult {
  const _CreateTicketResult({required this.subject, required this.message});

  final String subject;
  final String message;
}

class _CreateTicketSheet extends StatefulWidget {
  const _CreateTicketSheet();

  @override
  State<_CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends State<_CreateTicketSheet> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.t('new_ticket'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subjectCtrl,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14, fontWeight: FontWeight.w500),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              labelText: t.t('subject'),
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.60)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _messageCtrl,
            minLines: 3,
            maxLines: 6,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14, fontWeight: FontWeight.w500),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              labelText: t.t('message'),
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.60)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _submitting
                  ? null
                  : () {
                      final subject = _subjectCtrl.text.trim();
                      final message = _messageCtrl.text.trim();
                      if (subject.isEmpty || message.isEmpty) return;
                      setState(() => _submitting = true);
                      Navigator.of(context).pop(_CreateTicketResult(subject: subject, message: message));
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xfffbbf24),
                foregroundColor: const Color(0xff111827),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              child: Text(t.t('send')),
            ),
          ),
        ],
      ),
    );
  }
}
