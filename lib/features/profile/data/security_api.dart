import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';

class TwoFactorSetup {
  const TwoFactorSetup({
    required this.secret,
    required this.otpauthUrl,
    required this.recoveryCodes,
  });

  final String secret;
  final String otpauthUrl;
  final List<String> recoveryCodes;

  factory TwoFactorSetup.fromJson(Map<String, dynamic> json) {
    final codesRaw = json['recovery_codes'];
    final codes = codesRaw is List ? codesRaw.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : <String>[];

    return TwoFactorSetup(
      secret: (json['secret'] as String?) ?? '',
      otpauthUrl: (json['otpauth_url'] as String?) ?? '',
      recoveryCodes: codes,
    );
  }
}

class SecurityApi {
  SecurityApi(this._dio);

  final Dio _dio;

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/password/update',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': confirmNewPassword,
      },
    );
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
  }

  Future<TwoFactorSetup> setupTwoFactor() async {
    final res = await _dio.post<Map<String, dynamic>>('/v1/auth/2fa/setup');
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return TwoFactorSetup.fromJson(data);
  }

  Future<void> confirmTwoFactor({required String code}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/2fa/confirm',
      data: {'code': code},
    );
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
  }

  Future<void> disableTwoFactor({required String currentPassword}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/2fa/disable',
      data: {'current_password': currentPassword},
    );
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception((map['message'] as String?) ?? 'Request failed');
    }
  }
}

final securityApiProvider = Provider<SecurityApi>((ref) {
  return SecurityApi(ref.watch(dioProvider));
});

