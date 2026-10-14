import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../app/i18n.dart';
import '../data/wallet_api.dart';

class PaymentWebViewScreen extends ConsumerStatefulWidget {
  const PaymentWebViewScreen({
    super.key,
    required this.url,
    required this.paymentOrderId,
    required this.title,
  });

  final String url;
  final String paymentOrderId;
  final String title;

  static Future<bool?> open(
    BuildContext context, {
    required String url,
    required String paymentOrderId,
    required String title,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentWebViewScreen(
          url: url,
          paymentOrderId: paymentOrderId,
          title: title,
        ),
      ),
    );
  }

  @override
  ConsumerState<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends ConsumerState<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  double _progress = 0.0;
  bool _hasError = false;
  bool _verifying = false;
  bool _completed = false;

  static const _iosSystemGreen = Color(0xff34C759);

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  void _initWebViewController() {
    final uri = Uri.tryParse(widget.url.trim());
    if (uri == null) {
      _hasError = true;
      _loading = false;
      _controller = WebViewController();
      return;
    }

    _controller = WebViewController()
      ..setUserAgent('DrameReelApp/WebView')
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xff1C1C1E))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _progress = progress / 100.0;
                if (progress >= 100) _loading = false;
              });
            }
          },
          onPageStarted: (url) {
            if (mounted) setState(() => _loading = true);
            _checkInterceptUrl(url);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _loading = false);
            _checkInterceptUrl(url);
          },
          onUrlChange: (UrlChange change) {
            final url = change.url;
            if (url != null) _checkInterceptUrl(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            final lower = request.url.toLowerCase();
            final uri = Uri.tryParse(request.url);
            final scheme = uri?.scheme.toLowerCase() ?? '';
            final isCustomScheme = scheme.isNotEmpty && scheme != 'http' && scheme != 'https' && scheme != 'about';

            if (isCustomScheme ||
                lower.contains('/payment-return') ||
                lower.contains('/payments/orders/')) {
              _checkInterceptUrl(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            // Ignore subframe resource errors (e.g. tracking pixels or fonts)
            if (error.isForMainFrame == true) {
              if (mounted) setState(() => _hasError = true);
            }
          },
        ),
      )
      ..loadRequest(uri);
  }

  void _checkInterceptUrl(String url) {
    if (_verifying || _completed) return;
    final lower = url.toLowerCase();
    final uri = Uri.tryParse(url);
    final scheme = uri?.scheme.toLowerCase() ?? '';
    final isCustomScheme = scheme.isNotEmpty && scheme != 'http' && scheme != 'https' && scheme != 'about';

    final isReturnUrl = isCustomScheme ||
        lower.contains('/payment-return') ||
        lower.contains('status=success') ||
        lower.contains('status=paid') ||
        lower.contains('status=cancel') ||
        lower.contains('status=failed');

    if (isReturnUrl) {
      try {
        _controller.loadRequest(Uri.parse('about:blank'));
      } catch (_) {}
      _handleCompletion(url);
    }
  }

  Future<void> _handleCompletion(String url) async {
    if (_verifying || _completed) return;
    setState(() => _verifying = true);

    final lower = url.toLowerCase();
    final isExplicitCancel = lower.contains('status=cancel') ||
        lower.contains('status=failed') ||
        lower.contains('status=canceled');

    if (isExplicitCancel) {
      _finish(false);
      return;
    }

    // Verify order status directly with backend
    final orderId = widget.paymentOrderId.trim();
    if (orderId.isEmpty) {
      _finish(true);
      return;
    }

    String? status;
    for (var i = 0; i < 6; i++) {
      try {
        final st = await ref.read(walletApiProvider).orderStatus(paymentOrderId: orderId);
        status = st.status.trim().toLowerCase();
        if (status == 'paid') {
          _finish(true);
          return;
        }
        if (status == 'failed' || status == 'canceled' || status == 'cancel') {
          _finish(false);
          return;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    // If still in processing or indeterminate, return true if redirected from success
    if (status == 'paid' || lower.contains('status=success')) {
      _finish(true);
    } else {
      _finish(false);
    }
  }

  void _finish(bool success) {
    if (_completed) return;
    _completed = true;
    if (mounted) {
      Navigator.of(context).pop(success);
    }
  }

  Future<bool> _onWillPop() async {
    if (_verifying) return false;
    // Check order status once before closing
    final orderId = widget.paymentOrderId.trim();
    if (orderId.isNotEmpty) {
      try {
        final st = await ref.read(walletApiProvider).orderStatus(paymentOrderId: orderId);
        if (st.status.trim().toLowerCase() == 'paid') {
          _finish(true);
          return false;
        }
      } catch (_) {}
    }
    _finish(false);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xff1C1C1E),
        appBar: AppBar(
          backgroundColor: const Color(0xff1C1C1E),
          elevation: 0,
          leading: IconButton(
            icon: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
            ),
            onPressed: () => _onWillPop(),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/images/shield-check.svg',
                width: 17,
                height: 17,
                colorFilter: const ColorFilter.mode(
                  _iosSystemGreen,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title.isNotEmpty ? widget.title : (isArabic ? 'الدفع الآمن' : t.t('secure_checkout')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      isArabic ? 'دفع رسمي ومشفر 256-bit' : '256-bit SSL encrypted',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _loading = true;
                });
                _controller.reload();
              },
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: _loading && !_hasError
                ? LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    color: _iosSystemGreen,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    minHeight: 2,
                  )
                : Container(
                    height: 0.6,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
          ),
        ),
        body: Stack(
          children: [
            // WebView
            if (!_hasError)
              WebViewWidget(controller: _controller),

            // Error Screen
            if (_hasError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.wifi_off_rounded,
                          size: 30,
                          color: Colors.white.withValues(alpha: 0.50),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.t('no_connection'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.t('no_connection_desc'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                            _loading = true;
                          });
                          _controller.reload();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(t.t('retry')),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xffef233c),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Verification Overlay
            if (_verifying)
              Container(
                color: Colors.black.withValues(alpha: 0.85),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _iosSystemGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _iosSystemGreen.withValues(alpha: 0.30),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          color: _iosSystemGreen,
                          strokeWidth: 2.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isArabic ? 'جاري التحقق من عملية الدفع...' : 'Verifying payment status...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isArabic ? 'يرجى الانتظار لحظات' : 'Please wait a moment',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 12.5,
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
