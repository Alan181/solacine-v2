import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import 'auth_token_provider.dart';
import 'secure_storage_provider.dart';
import '../../features/auth/domain/auth_storage_keys.dart';
import 'shared_prefs_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  Completer<String?>? refreshing;

  String normalizeLang(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s.isEmpty) return 'en';
    if (s.length >= 2) return s.substring(0, 2);
    return s;
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await ref.read(authTokenProvider.future);
        if (token != null && token.trim().isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        } else {
          options.headers.remove('Authorization');
        }

        final prefs = await ref.read(sharedPrefsProvider.future);
        final stored = prefs.getString('app_locale');
        final sys = PlatformDispatcher.instance.locale.languageCode;
        final code = (stored == null || stored == 'system') ? sys : stored;
        options.headers['Accept-Language'] = normalizeLang(code);
        handler.next(options);
      },
      onError: (err, handler) async {
        final status = err.response?.statusCode;
        final retried = err.requestOptions.extra['retried'] == true;
        if (status != 401 || retried) {
          handler.next(err);
          return;
        }

        final oldToken = await ref.read(authTokenProvider.future);
        if (oldToken == null || oldToken.trim().isEmpty) {
          handler.next(err);
          return;
        }

        Future<String?> refresh() async {
          if (refreshing != null) return refreshing!.future;
          refreshing = Completer<String?>();

          try {
            final raw = Dio(
              BaseOptions(
                baseUrl: apiBaseUrl,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 20),
                headers: const {
                  'Accept': 'application/json',
                },
              ),
            );

            final prefs = await ref.read(sharedPrefsProvider.future);
            final stored = prefs.getString('app_locale');
            final sys = PlatformDispatcher.instance.locale.languageCode;
            final code = (stored == null || stored == 'system') ? sys : stored;

            final res = await raw.post<Map<String, dynamic>>(
              '/v1/auth/refresh',
              options: Options(
                headers: {
                  'Authorization': 'Bearer $oldToken',
                  'Accept-Language': normalizeLang(code),
                },
              ),
            );

            final json = res.data ?? <String, dynamic>{};
            if (json['status'] != true) {
              throw Exception('Refresh failed');
            }
            final data = json['data'] as Map<String, dynamic>?;
            final token = data?['token'] as String?;
            if (token == null || token.trim().isEmpty) {
              throw Exception('Missing token');
            }

            final storage = ref.read(secureStorageProvider);
            await storage.write(key: authTokenStorageKey, value: token);
            refreshing!.complete(token);
            return token;
          } catch (_) {
            final storage = ref.read(secureStorageProvider);
            await storage.delete(key: authTokenStorageKey);
            await storage.delete(key: authUserStorageKey);
            refreshing!.complete(null);
            return null;
          } finally {
            refreshing = null;
          }
        }

        final newToken = await refresh();
        if (newToken == null) {
          handler.next(err);
          return;
        }

        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';
        opts.extra['retried'] = true;

        try {
          final response = await dio.fetch(opts);
          handler.resolve(response);
        } catch (e) {
          handler.next(e is DioException ? e : err);
        }
      },
    ),
  );

  return dio;
});
