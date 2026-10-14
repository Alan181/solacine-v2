import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/i18n.dart';
import '../application/auth_controller.dart';
import '../application/email_verification_skip_controller.dart';
import 'widgets/otp_code_field.dart';

class TwoFactorVerifyScreen extends ConsumerStatefulWidget {
  const TwoFactorVerifyScreen({
    super.key,
    required this.challengeToken,
    this.email,
  });

  final String challengeToken;
  final String? email;

  @override
  ConsumerState<TwoFactorVerifyScreen> createState() => _TwoFactorVerifyScreenState();
}

class _TwoFactorVerifyScreenState extends ConsumerState<TwoFactorVerifyScreen> {
  bool _submitting = false;
  String _code = '';

  Future<void> _submit() async {
    if (_submitting) return;
    final t = AppI18n.of(context);
    final code = _code.trim();
    if (code.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final res = await ref.read(authSessionProvider.notifier).verifyTwoFactor(
            challengeToken: widget.challengeToken,
            code: code,
          );
      if (!mounted) return;
      if (!res.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message.isNotEmpty ? res.message : t.t('request_failed'))),
        );
        return;
      }

      final session = ref.read(authSessionProvider).valueOrNull;
      final verified = session?.user?['email_verified'] == true;
      await ref.read(skipEmailVerificationProvider.notifier).setSkipped(false);
      if (!mounted) return;
      if (verified) {
        context.go('/home');
      } else {
        context.go('/verify-email');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('request_failed'))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final email = (widget.email ?? '').trim();
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xff050505),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: media.size.height * .55,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/auth_hero.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x22000000),
                        Color(0x77000000),
                        Color(0xFF050505),
                      ],
                      stops: [
                        0,
                        .45,
                        .72,
                        1,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          PositionedDirectional(
            top: media.padding.top + 10,
            start: 12,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                color: Colors.white.withValues(alpha: 0.92),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                    return;
                  }
                  context.go('/login');
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, media.size.height * 0.18, 16, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          t.t('two_factor_required'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            email,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        OtpCodeField(
                          length: 6,
                          onChanged: (v) => setState(() => _code = v),
                          onCompleted: (v) async {
                            setState(() => _code = v);
                            await _submit();
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _submitting || _code.trim().length < 6 ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xffef233c),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
                              disabledForegroundColor: Colors.white.withValues(alpha: 0.70),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(t.t('verify')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
