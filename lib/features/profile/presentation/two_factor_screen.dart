import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/i18n.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_api.dart';
import '../data/security_api.dart';

class TwoFactorScreen extends ConsumerStatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  ConsumerState<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends ConsumerState<TwoFactorScreen> {
  TwoFactorSetup? _setup;
  bool _loading = false;
  bool _confirming = false;
  bool _disabling = false;

  final _code = TextEditingController();
  final _currentPassword = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _code.dispose();
    _currentPassword.dispose();
    super.dispose();
  }

  Future<void> _refreshMe() async {
    final me = await ref.read(authApiProvider).me();
    await ref.read(authSessionProvider.notifier).setUser(me);
  }

  Future<void> _setupTwoFactor() async {
    if (_loading) return;
    final t = AppI18n.of(context);
    setState(() => _loading = true);
    try {
      final setup = await ref.read(securityApiProvider).setupTwoFactor();
      if (!mounted) return;
      setState(() => _setup = setup);
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401 || code == 403) {
        await ref.read(authSessionProvider.notifier).logout();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmTwoFactor() async {
    if (_confirming) return;
    final t = AppI18n.of(context);
    final v = _code.text.trim();
    if (v.isEmpty) return;

    setState(() => _confirming = true);
    try {
      await ref.read(securityApiProvider).confirmTwoFactor(code: v);
      await _refreshMe();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('two_factor_enabled_ok'))));
      context.pop();
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401 || code == 403) {
        await ref.read(authSessionProvider.notifier).logout();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _disableTwoFactor() async {
    if (_disabling) return;
    final t = AppI18n.of(context);
    final pass = _currentPassword.text;
    if (pass.isEmpty) return;

    setState(() => _disabling = true);
    try {
      await ref.read(securityApiProvider).disableTwoFactor(currentPassword: pass);
      await _refreshMe();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('two_factor_disabled_ok'))));
      context.pop();
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401 || code == 403) {
        await ref.read(authSessionProvider.notifier).logout();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('request_failed'))));
    } finally {
      if (mounted) setState(() => _disabling = false);
    }
  }

  Future<void> _copy(String value, {required String okMessageKey}) async {
    final t = AppI18n.of(context);
    final v = value.trim();
    if (v.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: v));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t(okMessageKey))));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull?.user ?? const <String, dynamic>{};
    final enabled = user['two_factor_enabled'] == true;

    return Scaffold(
      backgroundColor: const Color(0xff050505),
      appBar: AppBar(
        backgroundColor: const Color(0xff050505),
        foregroundColor: Colors.white.withValues(alpha: 0.92),
        title: Text(t.t('two_factor_authentication')),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/account');
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? t.t('enabled') : t.t('disabled'),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                if (!enabled) ...[
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _setupTwoFactor,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffef233c),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(t.t('enable')),
                    ),
                  ),
                  if (_setup != null) ...[
                    ...() {
                      final setup = _setup!;
                      return <Widget>[
                        const SizedBox(height: 14),
                        Text(
                          t.t('two_factor_secret'),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  setup.secret,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _copy(setup.secret, okMessageKey: 'copied'),
                                icon: Icon(Icons.copy_rounded, color: Colors.white.withValues(alpha: 0.65), size: 18),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.t('recovery_codes'),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: setup.recoveryCodes
                                    .map(
                                      (c) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                                        ),
                                        child: Text(
                                          c,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.88),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                  onPressed: () => _copy(setup.recoveryCodes.join('\n'), okMessageKey: 'copied'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white.withValues(alpha: 0.85),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  child: Text(t.t('copy')),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ];
                    }(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        labelText: t.t('verification_code'),
                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13, fontWeight: FontWeight.w500),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _confirming ? null : _confirmTwoFactor,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        child: _confirming
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(t.t('verify')),
                      ),
                    ),
                  ],
                ] else ...[
                  TextFormField(
                    controller: _currentPassword,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: t.t('current_password'),
                      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13, fontWeight: FontWeight.w500),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.white.withValues(alpha: 0.60),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _disabling ? null : _disableTwoFactor,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffef233c),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      child: _disabling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(t.t('disable')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
