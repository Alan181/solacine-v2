import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';

class PushTokenApi {
  PushTokenApi(this._dio);

  final Dio _dio;

  Future<void> register({
    required String token,
    required String platform,
    String? deviceUid,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/device/push-token',
      data: {
        'fcm_token': token,
        'platform': platform,
        if (deviceUid != null && deviceUid.trim().isNotEmpty) 'device_uid': deviceUid.trim(),
      },
    );

    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
  }
}

final pushTokenApiProvider = Provider<PushTokenApi>((ref) {
  return PushTokenApi(ref.watch(dioProvider));
});
