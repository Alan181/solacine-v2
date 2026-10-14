import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/i18n.dart';

class LegalWebViewScreen extends StatefulWidget {
  const LegalWebViewScreen({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<LegalWebViewScreen> createState() => _LegalWebViewScreenState();
}

class _LegalWebViewScreenState extends State<LegalWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();

    final uri = Uri.tryParse(widget.url.trim());
    if (uri == null) {
      _failed = true;
      _loading = false;
      _controller = WebViewController();
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xff050505))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _failed = true);
          },
        ),
      )
      ..loadRequest(uri);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final title = widget.title.trim().isNotEmpty ? widget.title.trim() : t.t('app_name');

    return Scaffold(
      backgroundColor: const Color(0xff050505),
      appBar: AppBar(
        backgroundColor: const Color(0xff050505),
        foregroundColor: Colors.white.withValues(alpha: 0.92),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/profile');
          },
        ),
      ),
      body: Stack(
        children: [
          if (!_failed) WebViewWidget(controller: _controller),
          if (_failed)
            Center(
              child: Text(
                t.t('request_failed'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          if (_loading && !_failed)
            const Center(
              child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6)),
            ),
        ],
      ),
    );
  }
}

