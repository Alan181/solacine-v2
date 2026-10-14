import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dramereel_mobile/app/i18n.dart';
import 'package:dramereel_mobile/shared/validators.dart';
import 'package:dramereel_mobile/features/auth/application/auth_controller.dart';
import 'package:dramereel_mobile/features/auth/application/email_verification_skip_controller.dart';
import 'package:dramereel_mobile/features/bootstrap/application/bootstrap_controller.dart';
import 'package:dramereel_mobile/features/auth/data/auth_api.dart';
import 'widgets/apple_auth_button.dart';
import 'widgets/auth_legal_links.dart';
import 'widgets/auth_shell.dart';
import 'widgets/google_auth_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppI18n.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      final res = await ref.read(authSessionProvider.notifier).registerWithEmail(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          );

      if (!mounted) return;
      if (!res.ok) {
        // Duplicate email / weak password / validation from backend / banned country / etc.
        // Backend already sent a human-readable error message in res.message.
        final msg = res.message.trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.isEmpty ? t.t('register_failed') : msg)),
        );
        return;
      }
      await _handleAuthResult(res);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('register_failed'))),
      );
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    final t = AppI18n.of(context);
    try {
      final res = await ref.read(authSessionProvider.notifier).loginWithGoogle();
      if (!mounted) return;
      if (res.ok) {
        await _handleAuthResult(res);
      } else if (res.message.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('register_failed'))),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _loginWithApple() async {
    setState(() => _isAppleLoading = true);
    final t = AppI18n.of(context);
    try {
      final res = await ref.read(authSessionProvider.notifier).loginWithApple();
      if (!mounted) return;
      if (res.ok) {
        await _handleAuthResult(res);
      } else if (res.message.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('register_failed'))),
      );
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  Future<void> _handleAuthResult(AuthResult res) async {
    final t = AppI18n.of(context);
    if (res.requires2fa) {
      final token = (res.challengeToken ?? '').trim();
      if (token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.t('two_factor_required'))),
        );
        return;
      }
      if (!mounted) return;
      final uri = Uri(
        path: '/two-factor',
        queryParameters: {
          'challenge_token': token,
          'email': _email.text.trim(),
        },
      );
      context.push(uri.toString());
      return;
    }
    final session = ref.read(authSessionProvider).valueOrNull;
    final verified = session?.user?['email_verified'] == true;
    if (!mounted) return;
    await ref.read(skipEmailVerificationProvider.notifier).setSkipped(false);
    if (!mounted) return;
    if (verified) {
      context.go('/home');
    } else {
      context.go('/verify-email');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final auth = ref.watch(authSessionProvider);
    final loading = auth.isLoading;
    final bootstrap = ref.watch(appBootstrapProvider).valueOrNull;
    final googleEnabled = bootstrap?.publicSettings['auth']?['google_login_enabled'] == true;
    final appleEnabled = AuthController.isAppleSupported &&
        bootstrap?.publicSettings['auth']?['apple_login_enabled'] == true;
    final appConfig = bootstrap?.appConfig.data ?? const <String, dynamic>{};
    final appGeneral = (appConfig['general'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final legal = (bootstrap?.publicSettings['legal'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final privacyUrl =
        ((appGeneral['privacy_policy_link'] as String?) ?? (legal['privacy_policy'] as String?) ?? '').trim();
    final termsUrl =
        ((appGeneral['terms_of_service_link'] as String?) ?? (legal['terms_of_service'] as String?) ?? '').trim();

    return AuthShell(
      title: t.t('register_title'),
      subtitle: '',
      logoAssetPath: 'assets/images/icon.png',
      initialChildSize: 0.84,
      minChildSize: 0.84,
      maxChildSize: 0.96,
      child: Card(
        color: Colors.white.withValues(alpha: 0.06),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: t.t('name'),
                    labelStyle: const TextStyle(color: Color(0xFFCBD5E1)),
                    prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFFCBD5E1), size: 20),
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.6),
                    ),
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return t.t('field_required');
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: t.t('email'),
                    labelStyle: const TextStyle(color: Color(0xFFCBD5E1)),
                    prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFFCBD5E1), size: 20),
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.6),
                    ),
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return t.t('field_required');
                    if (!isLikelyEmail(v)) return t.t('invalid_email');
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: t.t('password'),
                    labelStyle: const TextStyle(color: Color(0xFFCBD5E1)),
                    prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFFCBD5E1), size: 20),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        color: const Color(0xFFCBD5E1),
                        size: 20,
                      ),
                    ),
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.6),
                    ),
                  ),
                  validator: (value) {
                    final v = value ?? '';
                    if (v.isEmpty) return t.t('field_required');
                    if (v.length < 6) return t.t('password_min', params: {'min': '6'});
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPassword,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: t.t('confirm_password'),
                    labelStyle: const TextStyle(color: Color(0xFFCBD5E1)),
                    prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFFCBD5E1), size: 20),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        color: const Color(0xFFCBD5E1),
                        size: 20,
                      ),
                    ),
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.6),
                    ),
                  ),
                  validator: (value) {
                    final v = value ?? '';
                    if (v.isEmpty) return t.t('field_required');
                    if (v != _password.text) return t.t('password_mismatch');
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(t.t('create_account')),
                ),
                const SizedBox(height: 12),
                if (googleEnabled) ...[
                  GoogleAuthButton(
                    onPressed: _loginWithGoogle,
                    label: t.t('sign_in_google'),
                    loading: _isGoogleLoading,
                  ),
                  const SizedBox(height: 12),
                ],
                if (appleEnabled) ...[
                  AppleAuthButton(
                    onPressed: _loginWithApple,
                    label: t.t('sign_in_apple') == 'sign_in_apple'
                        ? 'Continue with Apple'
                        : t.t('sign_in_apple'),
                    loading: _isAppleLoading,
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 10),
                TextButton(
                  onPressed: loading
                      ? null
                      : () {
                          if (context.canPop()) {
                            context.pop();
                            return;
                          }
                          context.go('/login');
                        },
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFE2E8F0)),
                  child: Text(t.t('have_account')),
                ),
                const SizedBox(height: 8),
                AuthLegalLinks(
                  privacyUrl: privacyUrl,
                  termsUrl: termsUrl,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
