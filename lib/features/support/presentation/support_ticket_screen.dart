import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/i18n.dart';
import '../../auth/application/auth_controller.dart';
import '../data/support_ticket_api.dart';

class SupportTicketScreen extends ConsumerStatefulWidget {
  const SupportTicketScreen({super.key, required this.id, required this.subject});

  final int id;
  final String subject;

  @override
  ConsumerState<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends ConsumerState<SupportTicketScreen> {
  SupportTicketDetails? _ticket;
  bool _loading = true;
  bool _sending = false;
  bool _closing = false;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final t = dt.toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _buildUserAvatar() {
    final session = ref.read(authSessionProvider).valueOrNull;
    final avatarUrl = (session?.user?['avatar_url'] as String?) ?? '';

    final isDefaultOrEmpty = avatarUrl.trim().isEmpty || avatarUrl.contains('ui-avatars.com/api/');

    if (!isDefaultOrEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        backgroundImage: NetworkImage(avatarUrl.trim()),
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      backgroundImage: const AssetImage('assets/images/avatar.jpg'),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final res = await ref.read(supportTicketApiProvider).get(widget.id);
      if (!mounted) return;
      setState(() => _ticket = res);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401 || code == 403) {
        await ref.read(authSessionProvider.notifier).logout();
        return;
      }
      return;
    } catch (e) {
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_ticket?.isClosed == true) return;

    setState(() => _sending = true);
    try {
      await ref.read(supportTicketApiProvider).reply(id: widget.id, message: text);
      _controller.clear();
      await _load();
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
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _close() async {
    if (_closing) return;
    if (_ticket?.isClosed == true) return;

    setState(() => _closing = true);
    try {
      await ref.read(supportTicketApiProvider).close(widget.id);
      await _load();
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
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    ref.watch(authSessionProvider);

    void goBack() {
      if (context.canPop()) {
        context.pop(_ticket);
      } else {
        context.go('/support');
      }
    }

    final ticket = _ticket;
    final isClosed = ticket?.isClosed == true;

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
                      widget.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: (isClosed || _closing) ? null : _close,
                    icon: const Icon(Icons.lock_rounded),
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : (ticket == null)
                      ? Center(
                          child: Text(
                            t.t('request_failed'),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontWeight: FontWeight.w500),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: Colors.white,
                          backgroundColor: const Color(0xff0b0b0b),
                          child: ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: ticket.messages.length + (isClosed ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (isClosed && index == ticket.messages.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Center(
                                    child: Text(
                                      t.t('ticket_closed'),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.55),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final m = ticket.messages[index];
                              final isSupport = m.isSupport;

                              final bubbleBg = isSupport
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xff2563eb).withValues(alpha: 0.22);
                              final bubbleBorder = isSupport
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : const Color(0xff2563eb).withValues(alpha: 0.32);

                              final ts = _formatTime(m.createdAt);
                              final bubble = Container(
                                constraints: const BoxConstraints(maxWidth: 520),
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                decoration: BoxDecoration(
                                  color: bubbleBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: bubbleBorder),
                                ),
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(bottom: ts.isNotEmpty ? 18 : 0),
                                      child: Text(
                                        m.body,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.88),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                    if (ts.isNotEmpty)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Text(
                                          ts,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.52),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );

                              if (isSupport) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    textDirection: TextDirection.ltr,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                                        backgroundImage: const AssetImage('assets/images/mine_feedback_icon.webp'),
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(child: bubble),
                                      const SizedBox(width: 40),
                                    ],
                                  ),
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  textDirection: TextDirection.ltr,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const SizedBox(width: 40),
                                    Flexible(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: bubble,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _buildUserAvatar(),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xff0b0b0b),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !isClosed,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14, fontWeight: FontWeight.w500),
                      cursorColor: Colors.white,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: t.t('message'),
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: IconButton(
                      onPressed: (isClosed || _sending) ? null : _send,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xfffbbf24),
                        foregroundColor: const Color(0xff111827),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
