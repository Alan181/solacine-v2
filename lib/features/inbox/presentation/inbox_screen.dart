import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dramereel_mobile/shared/widgets/app_cached_image.dart';
import '../../../app/i18n.dart';
import '../../auth/application/auth_controller.dart';
import '../application/inbox_unread_count_provider.dart';
import '../data/inbox_api.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final List<InboxItem> _items = <InboxItem>[];
  Object? _error;
  bool _loading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _mutating = false;
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
      final res = await ref.read(inboxApiProvider).list(page: 1);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(res.items);
        _page = res.currentPage;
        _lastPage = res.lastPage;
      });
      ref.invalidate(inboxUnreadCountProvider);
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
      final res = await ref.read(inboxApiProvider).list(page: next);
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

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final t = dt.toLocal();
    final yyyy = t.year.toString().padLeft(4, '0');
    final mm = t.month.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    final hh = t.hour.toString().padLeft(2, '0');
    final mi = t.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$mi';
  }

  Future<void> _openItem(InboxItem item) async {
    if (_mutating) return;

    var updated = item;

    if (item.isUnread && item.id.isNotEmpty) {
      setState(() => _mutating = true);
      try {
        await ref.read(inboxApiProvider).read(item.id);
        updated = InboxItem(
          id: item.id,
          title: item.title,
          body: item.body,
          imageUrl: item.imageUrl,
          actionUrl: item.actionUrl,
          readAt: DateTime.now(),
          createdAt: item.createdAt,
        );
        if (mounted) {
          setState(() {
            final idx = _items.indexWhere((e) => e.id == item.id);
            if (idx >= 0) _items[idx] = updated;
          });
        }
      } catch (_) {
        return;
      } finally {
        if (mounted) setState(() => _mutating = false);
      }
      ref.invalidate(inboxUnreadCountProvider);
    }

    if (!mounted) return;

    final t = AppI18n.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff0b0b0b),
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => _InboxDetailsSheet(
        title: updated.title,
        body: updated.body,
        timeLabel: _formatTime(updated.createdAt),
        imageUrl: updated.imageUrl,
        actionUrl: updated.actionUrl,
        openLabel: t.t('open_link'),
      ),
    );
  }

  Future<void> _deleteItem(InboxItem item) async {
    if (_mutating) return;
    if (item.id.isEmpty) return;
    setState(() => _mutating = true);
    try {
      await ref.read(inboxApiProvider).delete(item.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => e.id == item.id));
      ref.invalidate(inboxUnreadCountProvider);
    } catch (_) {
      return;
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _readAll() async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await ref.read(inboxApiProvider).readAll();
      if (!mounted) return;
      await _load(reset: true, showLoader: false);
    } catch (_) {
      return;
    } finally {
      if (mounted) setState(() => _mutating = false);
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
                      t.t('inbox'),
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
                    onPressed: _mutating ? null : _readAll,
                    icon: const Icon(Icons.done_all_rounded),
                    color: Colors.white.withValues(alpha: 0.78),
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
                                  t.t('no_inbox_messages'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ] else ...[
                              for (final item in _items) ...[
                                _InboxTile(
                                  item: item,
                                  timeLabel: _formatTime(item.createdAt),
                                  onTap: () => _openItem(item),
                                  onDelete: () => _deleteItem(item),
                                ),
                                const SizedBox(height: 10),
                              ],
                              if (_loadingMore)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
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

class _InboxTile extends StatelessWidget {
  const _InboxTile({
    required this.item,
    required this.timeLabel,
    required this.onTap,
    required this.onDelete,
  });

  final InboxItem item;
  final String timeLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bg = item.isUnread ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.05);
    final border = item.isUnread ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.10);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.title.trim().isNotEmpty)
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                        if (item.body.trim().isNotEmpty) ...[
                          if (item.title.trim().isNotEmpty) const SizedBox(height: 6),
                          Text(
                            item.body,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.28,
                            ),
                          ),
                        ],
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: Colors.white.withValues(alpha: 0.70),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            if (item.isUnread)
              Positioned(
                left: 12,
                top: 16,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xffef233c),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0xff050505), width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InboxDetailsSheet extends StatelessWidget {
  const _InboxDetailsSheet({
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.imageUrl,
    required this.actionUrl,
    required this.openLabel,
  });

  final String title;
  final String body;
  final String timeLabel;
  final String imageUrl;
  final String actionUrl;
  final String openLabel;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.82;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            top: 6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.trim().isNotEmpty)
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              if (title.trim().isNotEmpty && timeLabel.isNotEmpty) const SizedBox(height: 8),
              if (title.trim().isEmpty && timeLabel.isNotEmpty)
                Text(
                  timeLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (title.trim().isNotEmpty && timeLabel.isNotEmpty)
                Text(
                  timeLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 12),
              if (imageUrl.trim().isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: AppCachedImage(
                      imageUrl: imageUrl.trim(),
                      fit: BoxFit.cover,
                      errorWidget: (_) => Container(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
              if (actionUrl.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final uri = Uri.tryParse(actionUrl.trim());
                      if (uri == null) return;
                      try {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xfffbbf24),
                      foregroundColor: const Color(0xff111827),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    child: Text(
                      openLabel,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
