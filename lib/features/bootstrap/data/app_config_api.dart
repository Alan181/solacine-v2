import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';

class AppConfigResult {
  const AppConfigResult({
    required this.platform,
    required this.data,
  });

  final String platform;
  final Map<String, dynamic> data;
}

class AppConfigApi {
  AppConfigApi(this._dio);

  final Dio _dio;

  Future<AppConfigResult> getAppConfig({
    required String apiKey,
    String? platform,
  }) async {
    final p = platform ?? _detectPlatform();
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/app-config',
      options: Options(
        headers: {
          'X-App-Platform': p,
          'X-App-Key': apiKey,
        },
      ),
      queryParameters: const {},
    );

    final json = res.data ?? const <String, dynamic>{};
    final ok = json['success'] == true;
    if (!ok) {
      throw Exception((json['message'] as String?) ?? 'Failed to load app config');
    }

    final data = (json['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final platformOut = (data['platform'] as String?) ?? p;
    return AppConfigResult(platform: platformOut, data: data);
  }

  String _detectPlatform() {
    if (kIsWeb) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }
}

final appConfigApiProvider = Provider<AppConfigApi>((ref) {
  return AppConfigApi(ref.watch(dioProvider));
});

