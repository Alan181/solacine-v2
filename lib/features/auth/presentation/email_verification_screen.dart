import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:solacine_mobile/app/i18n.dart';
import 'package:solacine_mobile/features/bootstrap/application/bootstrap_controller.dart';
import 'package:solacine_mobile/features/auth/application/auth_controller.dart';
import 'package:solacine_mobile/features/auth/application/email_verification_skip_controller.dart';
import 'package:solacine_mobile/features/auth/data/auth_api.dart';
import 'widgets/auth_shell.dart';
import 'widgets/otp_code_field.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  Timer? _timer;
  int _cooldown = 0;
  bool _submitting = false;
  bool _sending = false;
  String _otp = '';

  @override
  void initState() {
    super.initState();
    _startCooldown(0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
        return;
      }
      setState(() => _cooldown -= 1);
    });
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(authApiProvider).resendEmailOtp();
      if (!mounted) return;
      _startCooldown(30);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppI18n.of(context).t('request_failed'))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    if (_submitting) return;
    final code = _otp.trim();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppI18n.of(context).t('invalid_code'))));
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authApiProvider).verifyEmailOtp(code: code);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppI18n.of(context).t('invalid_code'))));
      setState(() => _submitting = false);
      return;
    }

    try {
      final fresh = await ref.read(authApiProvider).me();
      if (fresh.isNotEmpty) {
        await ref.read(authSessionProvider.notifier).setUser(fresh);
      }
    } catch (_) {}

    if (!mounted) return;
    await ref.read(skipEmailVerificationProvider.notifier).setSkipped(false);
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _skip() async {
    final bootstrap = ref.read(appBootstrapProvider).valueOrNull;
    final allowSkip = (bootstrap?.publicSettings['auth'] is Map)
        ? ((bootstrap?.publicSettings['auth'] as Map)['allow_email_verification_skip'] == true)
        : true;
    if (!allowSkip) return;
    await ref.read(skipEmailVerificationProvider.notifier).setSkipped(true);
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final session = ref.watch(authSessionProvider).valueOrNull;
    final email = (session?.user?['email'] as String?) ?? '';
    final bootstrap = ref.watch(appBootstrapProvider).valueOrNull;
    final allowSkip = (bootstrap?.publicSettings['auth'] is Map)
        ? ((bootstrap?.publicSettings['auth'] as Map)['allow_email_verification_skip'] == true)
        : true;

    return AuthShell(
      title: t.t('verify_email_title'),
      subtitle: email.isEmpty ? t.t('app_name') : email,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.t('verification_code'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              OtpCodeField(
                length: 6,
                onChanged: (v) => _otp = v,
                onCompleted: (_) => _verify(),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _submitting ? null : _verify,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(t.t('verify')),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _cooldown > 0 || _sending ? null : _resend,
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFE2E8F0)),
                child: Text(_cooldown > 0 ? '${t.t('resend')} (${_cooldown}s)' : t.t('resend')),
              ),
              const SizedBox(height: 6),
              if (allowSkip)
                TextButton(
                  onPressed: _skip,
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFE2E8F0)),
                  child: Text(t.t('skip_for_now')),
                ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0x1AFFFFFF)),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () async {
                  await ref.read(authSessionProvider.notifier).logout();
                  if (!context.mounted) return;
                  context.go('/login');
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: Text(t.t('logout')),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.55),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
