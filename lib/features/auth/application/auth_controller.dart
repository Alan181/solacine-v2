import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:solacine_mobile/features/bootstrap/application/bootstrap_controller.dart';
import 'package:solacine_mobile/shared/data/auth_token_provider.dart';
import 'package:solacine_mobile/shared/data/secure_storage_provider.dart';
import 'package:solacine_mobile/shared/data/shared_prefs_provider.dart';
import 'package:solacine_mobile/features/auth/data/auth_api.dart';
import 'package:solacine_mobile/features/auth/domain/auth_storage_keys.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    this.user,
  });

  final String token;
  final Map<String, dynamic>? user;
}

class AuthController extends AsyncNotifier<AuthSession?> {
  static Future<void>? _googleInitFuture;

  static Future<void> _ensureGoogleInitialized({required String? clientId}) {
    final normalized = (clientId ?? '').trim();
    _googleInitFuture ??= GoogleSignIn.instance.initialize(
      serverClientId: normalized.isEmpty ? null : normalized,
    );
    return _googleInitFuture!;
  }

  static bool get isAppleSupported {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  static String _messageFromDio(Object error) {
    if (error is! DioException) return '';
    final data = error.response?.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();
    return '';
  }

  @override
  Future<AuthSession?> build() async {
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: authTokenStorageKey);
    if (token == null || token.trim().isEmpty) return null;

    final rawUser = await storage.read(key: authUserStorageKey);
    Map<String, dynamic>? user;
    if (rawUser != null && rawUser.trim().isNotEmpty) {
      try {
        user = jsonDecode(rawUser) as Map<String, dynamic>;
      } catch (_) {
        user = null;
      }
    }

    try {
      final fresh = await ref.read(authApiProvider).me();
      if (fresh.isNotEmpty) {
        await storage.write(key: authUserStorageKey, value: jsonEncode(fresh));
        user = fresh;
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401 || code == 403) {
        await storage.delete(key: authTokenStorageKey);
        await storage.delete(key: authUserStorageKey);
        final prefs = await ref.read(sharedPrefsProvider.future);
        await prefs.setBool('skip_email_verification', false);
        return null;
      }
    } catch (_) {}

    return AuthSession(token: token, user: user);
  }

  Future<AuthSession> _persistSession({
    required String token,
    required Map<String, dynamic>? user,
  }) async {
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: authTokenStorageKey, value: token);
    await storage.write(key: authUserStorageKey, value: jsonEncode(user ?? const <String, dynamic>{}));
    ref.invalidate(authTokenProvider);
    return AuthSession(token: token, user: user);
  }

  Future<AuthResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final previous = state.valueOrNull;
    state = const AsyncLoading();
    try {
      final res = await ref.read(authApiProvider).loginWithEmail(
            email: email,
            password: password,
          );
      if (!res.ok) {
        throw Exception(res.message.isEmpty ? 'Login failed' : res.message);
      }

      if (res.requires2fa) {
        state = AsyncData(previous);
        return AuthResult(
          ok: true,
          message: res.message,
          requires2fa: true,
          challengeToken: res.challengeToken,
          user: res.user,
        );
      }

      final token = res.token;
      if (token == null || token.trim().isEmpty) {
        throw Exception('Server returned ok but no auth token');
      }
      final session = await _persistSession(token: token, user: res.user);
      state = AsyncData(session);
      return AuthResult(ok: true, message: '', token: session.token, user: session.user);
    } on DioException catch (e) {
      state = AsyncData(previous);
      final msg = _messageFromDio(e);
      return AuthResult(ok: false, message: msg.isNotEmpty ? msg : 'Login failed');
    } catch (_) {
      state = AsyncData(previous);
      return const AuthResult(ok: false, message: 'Login failed');
    }
  }

  Future<AuthResult> loginWithGoogle() async {
    final previous = state.valueOrNull;
    state = const AsyncLoading();
    try {
      final bootstrap = ref.read(appBootstrapProvider).valueOrNull;
      final clientId = bootstrap?.publicSettings['auth']?['google_client_id'] as String?;

      await _ensureGoogleInitialized(clientId: clientId);

      final googleAccount = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleAccount.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.trim().isEmpty) {
        throw Exception('Google ID token is missing');
      }

      final res = await ref.read(authApiProvider).loginWithGoogle(idToken: idToken);
      if (!res.ok) {
        throw Exception(res.message.isEmpty ? 'Google Login failed' : res.message);
      }

      if (res.requires2fa) {
        state = AsyncData(previous);
        return AuthResult(
          ok: true,
          message: res.message,
          requires2fa: true,
          challengeToken: res.challengeToken,
          user: res.user,
        );
      }

      final token = res.token;
      if (token == null || token.trim().isEmpty) {
        throw Exception('Server returned ok but no auth token');
      }
      final session = await _persistSession(token: token, user: res.user);
      state = AsyncData(session);
      return AuthResult(ok: true, message: '', token: session.token, user: session.user);
    } on DioException catch (e) {
      state = AsyncData(previous);
      final msg = _messageFromDio(e);
      return AuthResult(ok: false, message: msg.isNotEmpty ? msg : 'Google sign in failed');
    } catch (_) {
      state = AsyncData(previous);
      return const AuthResult(ok: false, message: 'Google sign in failed');
    }
  }

  Future<AuthResult> loginWithApple() async {
    if (!isAppleSupported) {
      return const AuthResult(ok: false, message: 'Apple sign in is not supported on this device');
    }

    final previous = state.valueOrNull;
    state = const AsyncLoading();
    try {
      final bootstrap = ref.read(appBootstrapProvider).valueOrNull;
      final clientId = bootstrap?.publicSettings['auth']?['apple_client_id'] as String?;
      final normalizedClientId = (clientId ?? '').trim();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: normalizedClientId.isEmpty
            ? null
            : WebAuthenticationOptions(
                clientId: normalizedClientId,
                redirectUri: Uri.parse('${Uri.base.scheme}://${Uri.base.host}/callbacks/sign_in_with_apple'),
              ),
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.trim().isEmpty) {
        throw Exception('Apple identity token is missing');
      }

      final email = credential.email;
      final givenName = credential.givenName;
      final familyName = credential.familyName;
      String? fullName;
      if ((givenName != null && givenName.trim().isNotEmpty) ||
          (familyName != null && familyName.trim().isNotEmpty)) {
        final parts = <String>[
          if (givenName != null) givenName.trim(),
          if (familyName != null) familyName.trim(),
        ];
        fullName = parts.join(' ');
      }

      final res = await ref.read(authApiProvider).loginWithApple(
            identityToken: idToken,
            email: email,
            givenName: givenName,
            familyName: familyName,
            fullName: fullName,
          );
      if (!res.ok) {
        throw Exception(res.message.isEmpty ? 'Apple Login failed' : res.message);
      }

      if (res.requires2fa) {
        state = AsyncData(previous);
        return AuthResult(
          ok: true,
          message: res.message,
          requires2fa: true,
          challengeToken: res.challengeToken,
          user: res.user,
        );
      }

      final token = res.token;
      if (token == null || token.trim().isEmpty) {
        throw Exception('Server returned ok but no auth token');
      }
      final session = await _persistSession(token: token, user: res.user);
      state = AsyncData(session);
      return AuthResult(ok: true, message: '', token: session.token, user: session.user);
    } on DioException catch (e) {
      state = AsyncData(previous);
      final msg = _messageFromDio(e);
      return AuthResult(ok: false, message: msg.isNotEmpty ? msg : 'Apple sign in failed');
    } on SignInWithAppleAuthorizationException catch (e) {
      state = AsyncData(previous);
      if (e.code == AuthorizationErrorCode.canceled ||
          e.code == AuthorizationErrorCode.unknown) {
        return const AuthResult(ok: false, message: '');
      }
      final m = e.message;
      return AuthResult(
        ok: false,
        message: m.isNotEmpty ? 'Apple sign in failed: $m' : 'Apple sign in failed',
      );
    } catch (_) {
      state = AsyncData(previous);
      return const AuthResult(ok: false, message: 'Apple sign in failed');
    }
  }

  Future<AuthResult> verifyTwoFactor({
    required String challengeToken,
    required String code,
  }) async {
    final previous = state.valueOrNull;
    state = const AsyncLoading();
    try {
      final res = await ref.read(authApiProvider).verifyTwoFactor(
            challengeToken: challengeToken,
            code: code,
          );
      final token = res.token;
      if (!res.ok || token == null || token.trim().isEmpty) {
        throw Exception(res.message.isEmpty ? 'Invalid code' : res.message);
      }

      final session = await _persistSession(token: token, user: res.user);
      state = AsyncData(session);
      return AuthResult(ok: true, message: '', token: session.token, user: session.user);
    } on DioException catch (e) {
      state = AsyncData(previous);
      final msg = _messageFromDio(e);
      return AuthResult(ok: false, message: msg.isNotEmpty ? msg : 'Request failed');
    } catch (_) {
      state = AsyncData(previous);
      return const AuthResult(ok: false, message: 'Request failed');
    }
  }

  Future<AuthResult> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final res = await ref.read(authApiProvider).registerWithEmail(
            name: name,
            email: email,
            password: password,
          );
      if (!res.ok) {
        throw Exception(res.message.isEmpty ? 'Registration failed' : res.message);
      }
      if (res.requires2fa) {
        return null;
      }

      final token = res.token;
      if (token == null || token.trim().isEmpty) {
        throw Exception('Server returned ok but no auth token');
      }
      final storage = ref.read(secureStorageProvider);
      await storage.write(key: authTokenStorageKey, value: token);
      await storage.write(key: authUserStorageKey, value: jsonEncode(res.user ?? {}));
      ref.invalidate(authTokenProvider);

      return AuthSession(token: token, user: res.user);
    });

    final current = state.valueOrNull;
    if (current == null) {
      return const AuthResult(ok: true, message: '', requires2fa: true);
    }

    return AuthResult(ok: true, message: '', token: current.token, user: current.user);
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: authTokenStorageKey);
    await storage.delete(key: authUserStorageKey);
    ref.invalidate(authTokenProvider);
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool('skip_email_verification', false);
    state = const AsyncData(null);
  }

  Future<String?> refreshToken() async {
    final current = state.valueOrNull;
    if (current == null) return null;

    try {
      final token = await ref.read(authApiProvider).refreshToken();
      final storage = ref.read(secureStorageProvider);
      await storage.write(key: authTokenStorageKey, value: token);
      ref.invalidate(authTokenProvider);
      state = AsyncData(AuthSession(token: token, user: current.user));
      return token;
    } catch (_) {
      await logout();
      return null;
    }
  }

  Future<void> setUser(Map<String, dynamic> user) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.user != null && mapEquals(current.user, user)) return;
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: authUserStorageKey, value: jsonEncode(user));
    state = AsyncData(AuthSession(token: current.token, user: user));
  }
}

final authSessionProvider = AsyncNotifierProvider<AuthController, AuthSession?>(
  AuthController.new,
);
