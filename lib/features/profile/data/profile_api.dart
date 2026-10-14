import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';

class ProfileApi {
  ProfileApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    String? username,
    String? phone,
  }) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/v1/profile',
      data: {
        'name': name,
        'email': email,
        'username': (username ?? '').trim().isEmpty ? null : username,
        'phone': (phone ?? '').trim().isEmpty ? null : phone,
      },
    );

    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }

    final data = map['data'] as Map<String, dynamic>?;
    final user = data?['user'] as Map<String, dynamic>?;
    return user ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateAvatar({
    required String filePath,
    required String fileName,
  }) async {
    final form = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/profile/avatar',
      data: form,
    );

    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }

    final data = map['data'] as Map<String, dynamic>?;
    final user = data?['user'] as Map<String, dynamic>?;
    return user ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> deleteAvatar() async {
    final res = await _dio.delete<Map<String, dynamic>>('/v1/profile/avatar');

    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }

    final data = map['data'] as Map<String, dynamic>?;
    final user = data?['user'] as Map<String, dynamic>?;
    return user ?? <String, dynamic>{};
  }
}

final profileApiProvider = Provider<ProfileApi>((ref) {
  return ProfileApi(ref.watch(dioProvider));
});
