import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/i18n.dart';

Future<void> openInAppWebView(
  BuildContext context, {
  required String title,
  required String url,
}) async {
  final t = AppI18n.of(context);
  final value = url.trim();
  if (value.isEmpty) return;
  final uri = Uri.tryParse(value);
  if (uri == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.t('unable_open_link'))),
    );
    return;
  }

  final loc = Uri(
    path: '/legal',
    queryParameters: {
      'title': title,
      'url': uri.toString(),
    },
  ).toString();

  if (!context.mounted) return;
  await context.push(loc);
}
