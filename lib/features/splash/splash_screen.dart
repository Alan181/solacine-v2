import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../app/i18n.dart';
import '../bootstrap/application/bootstrap_controller.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppI18n.of(context);
    final bootstrap = ref.watch(appBootstrapProvider);
    final errorText = bootstrap.hasError ? _formatError(bootstrap.error, t) : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/icon.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 18),
              if (bootstrap.hasError) ...[
                const Icon(Icons.error_outline_rounded, color: Color(0xFFFCA5A5), size: 28),
                const SizedBox(height: 10),
                SizedBox(
                  height: 120,
                  child: SingleChildScrollView(
                    child: Text(
                      errorText ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => ref.invalidate(appBootstrapProvider),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(t.t('retry')),
                ),
              ] else ...[
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatError(Object? error, AppI18n t) {
  if (error is DioException) {
    final inner = error.error;
    final type = error.type;

    if (inner is SocketException ||
        type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.sendTimeout) {
      final title = t.t('no_connection');
      final body  = t.t('no_connection_desc');
      return '$title\n\n$body';
    }

    final status = error.response?.statusCode ?? 0;
    if (status >= 500) {
      final title = t.t('server_unreachable');
      final body  = t.t('server_unreachable_desc');
      return '$title\n\n$body';
    }

    final title = t.t('request_failed');
    final body  = t.t('request_failed_desc');
    return '$title\n\n$body';
  }

  final title = t.t('startup_failed');
  final body  = t.t('startup_failed_desc');
  return '$title\n\n$body';
}
