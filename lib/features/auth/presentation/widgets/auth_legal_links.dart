import 'package:flutter/material.dart';
import '../../../../app/i18n.dart';
import '../../../../shared/utils/in_app_web_view.dart';

class AuthLegalLinks extends StatelessWidget {
  const AuthLegalLinks({
    super.key,
    this.privacyUrl,
    this.termsUrl,
  });

  final String? privacyUrl;
  final String? termsUrl;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final privacy = (privacyUrl ?? '').trim();
    final terms = (termsUrl ?? '').trim();
    if (privacy.isEmpty && terms.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Text(
          t.t('legal_prefix'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.52),
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 0,
          children: [
            if (privacy.isNotEmpty)
              _LinkText(
                label: t.t('privacy_policy'),
                onTap: () => _openUrl(context, privacy),
              ),
            if (privacy.isNotEmpty && terms.isNotEmpty)
              Text(
                t.t('legal_and'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 12,
                ),
              ),
            if (terms.isNotEmpty)
              _LinkText(
                label: t.t('terms_of_use'),
                onTap: () => _openUrl(context, terms),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _openUrl(BuildContext context, String value) async {
    final t = AppI18n.of(context);
    final raw = value.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('unable_open_link'))),
      );
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('unable_open_link'))),
      );
      return;
    }

    // Legal pages (Privacy Policy / Terms of Use) are ALWAYS opened inside the
    // app via WebView to stay compliant with Play Store / App Store review
    // guidelines and to keep the user in-app.
    await openInAppWebView(
      context,
      title: _defaultTitleFor(context, raw) ?? '',
      url: raw,
    );
  }

  String? _defaultTitleFor(BuildContext context, String url) {
    final t = AppI18n.of(context);
    final low = url.toLowerCase();
    if (low.contains('privacy')) return t.t('privacy_policy');
    if (low.contains('terms')) return t.t('terms_of_use');
    return null;
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8B7BFF),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: Color(0xFF8B7BFF),
          ),
        ),
      ),
    );
  }
}
