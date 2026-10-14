import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';

class PublicSettingsApi {
  PublicSettingsApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getPublicSettings() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/settings');
    final json = res.data ?? const <String, dynamic>{};
    final ok = json['status'] == true;
    if (!ok) {
      throw Exception((json['message'] as String?) ?? 'Failed to load settings');
    }
    return (json['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  }
}

final publicSettingsApiProvider = Provider<PublicSettingsApi>((ref) {
  return PublicSettingsApi(ref.watch(dioProvider));
});

