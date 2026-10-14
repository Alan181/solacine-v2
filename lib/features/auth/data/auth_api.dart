import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';

class AuthResult {
  const AuthResult({
    required this.ok,
    required this.message,
    this.token,
    this.user,
    this.requires2fa = false,
    this.challengeToken,
  });

  final bool ok;
  final String message;
  final String? token;
  final Map<String, dynamic>? user;
  final bool requires2fa;
  final String? challengeToken;
}

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/login',
      data: {'email': email, 'password': password},
    );

    return _parseAuthResponse(res.data);
  }

  Future<AuthResult> loginWithGoogle({required String idToken}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/google',
      data: {'id_token': idToken},
    );

    return _parseAuthResponse(res.data);
  }

  Future<AuthResult> loginWithApple({
    required String identityToken,
    String? email,
    String? givenName,
    String? familyName,
    String? fullName,
  }) async {
    final payload = <String, dynamic>{
      'identity_token': identityToken,
    };
    if (email != null && email.trim().isNotEmpty) payload['email'] = email.trim();
    if (givenName != null && givenName.trim().isNotEmpty) payload['given_name'] = givenName.trim();
    if (familyName != null && familyName.trim().isNotEmpty) payload['family_name'] = familyName.trim();
    if (fullName != null && fullName.trim().isNotEmpty) payload['full_name'] = fullName.trim();

    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/apple',
      data: payload,
    );

    return _parseAuthResponse(res.data);
  }

  Future<AuthResult> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/register',
      data: {'name': name, 'email': email, 'password': password},
    );

    return _parseAuthResponse(res.data);
  }

  Future<String> refreshToken() async {
    final res = await _dio.post<Map<String, dynamic>>('/v1/auth/refresh');
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception('Refresh failed');
    }
    final data = map['data'] as Map<String, dynamic>?;
    final token = data?['token'] as String?;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Missing token');
    }
    return token;
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/auth/me');
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception('Unauthorized');
    }
    final data = map['data'] as Map<String, dynamic>?;
    final user = data?['user'] as Map<String, dynamic>?;
    return user ?? <String, dynamic>{};
  }

  Future<void> deleteAccount() async {
    final res = await _dio.delete<Map<String, dynamic>>('/v1/auth/account');
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception('Request failed');
    }
  }

  Future<void> resendEmailOtp() async {
    final res = await _dio.post<Map<String, dynamic>>('/v1/auth/email-otp/resend');
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception('Request failed');
    }
  }

  Future<void> verifyEmailOtp({required String code}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/email-otp/verify',
      data: {'code': code},
    );
    final map = res.data ?? <String, dynamic>{};
    if (map['status'] != true) {
      throw Exception('Invalid code');
    }
  }

  Future<AuthResult> verifyTwoFactor({
    required String challengeToken,
    required String code,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/2fa/verify',
      data: {
        'challenge_token': challengeToken,
        'code': code,
      },
    );
    return _parseAuthResponse(res.data);
  }

  AuthResult _parseAuthResponse(Map<String, dynamic>? json) {
    final map = json ?? <String, dynamic>{};
    final message = (map['message'] as String?) ?? '';
    final data = map['data'] as Map<String, dynamic>?;

    final requires2fa = (data?['requires_2fa'] == true);
    if (requires2fa) {
      return AuthResult(
        ok: true,
        message: message,
        requires2fa: true,
        challengeToken: data?['challenge_token'] as String?,
        user: data?['user'] as Map<String, dynamic>?,
      );
    }

    final token = data?['token'] as String?;
    final user = data?['user'] as Map<String, dynamic>?;
    final ok = token != null && token.isNotEmpty;

    return AuthResult(
      ok: ok,
      message: message,
      token: token,
      user: user,
    );
  }
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});
