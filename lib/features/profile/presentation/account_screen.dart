import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/i18n.dart';
import '../../auth/application/auth_controller.dart';
import '../data/profile_api.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _usernameController;
  late final TextEditingController _phoneController;

  bool _saving = false;
  bool _pickingAvatar = false;
  XFile? _pendingAvatar;
  bool _removeAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authSessionProvider).valueOrNull?.user ?? const <String, dynamic>{};
    _nameController = TextEditingController(text: (user['name'] as String?) ?? '');
    _emailController = TextEditingController(text: (user['email'] as String?) ?? '');
    _usernameController = TextEditingController(text: (user['username'] as String?) ?? '');
    _phoneController = TextEditingController(text: (user['phone'] as String?) ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _saving = true);
    try {
      var user = await ref.read(profileApiProvider).updateProfile(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            username: _usernameController.text.trim(),
            phone: _phoneController.text.trim(),
          );

      if (_removeAvatar) {
        user = await ref.read(profileApiProvider).deleteAvatar();
      } else if (_pendingAvatar != null) {
        final avatar = _pendingAvatar!;
        final file = File(avatar.path);
        user = await ref.read(profileApiProvider).updateAvatar(
              filePath: file.path,
              fileName: avatar.name,
            );
      }

      await ref.read(authSessionProvider.notifier).setUser(user);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppI18n.of(context).t('saved'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppI18n.of(context).t('request_failed'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeAvatar() async {
    if (_pickingAvatar) return;
    setState(() => _pickingAvatar = true);
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() {
        _pendingAvatar = image;
        _removeAvatar = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppI18n.of(context).t('request_failed'))),
      );
    } finally {
      if (mounted) setState(() => _pickingAvatar = false);
    }
  }

  void _deleteAvatar() {
    if (_saving || _pickingAvatar) return;
    setState(() {
      _pendingAvatar = null;
      _removeAvatar = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final user = ref.watch(authSessionProvider).valueOrNull?.user ?? const <String, dynamic>{};
    final avatarUrl = (user['avatar_url'] as String?) ?? '';
    final avatarIsDefault = avatarUrl.trim().isEmpty || avatarUrl.contains('ui-avatars.com/api/');
    final showRemove = !_saving && !_pickingAvatar && (!_removeAvatar) && (_pendingAvatar != null || !avatarIsDefault);
    final pendingAvatar = _pendingAvatar;
    final ImageProvider<Object>? avatarImage = pendingAvatar != null
        ? FileImage(File(pendingAvatar.path))
        : (!_removeAvatar && avatarUrl.trim().isNotEmpty && !avatarIsDefault
            ? NetworkImage(avatarUrl.trim())
            : const AssetImage('assets/images/avatar.jpg'));

    final twoFactorEnabled = user['two_factor_enabled'] == true;

    return Scaffold(
      backgroundColor: const Color(0xff050505),
      appBar: AppBar(
        backgroundColor: const Color(0xff050505),
        foregroundColor: Colors.white.withValues(alpha: 0.92),
        title: Text(t.t('account')),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/profile');
          },
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.92),
              textStyle: const TextStyle(fontWeight: FontWeight.w500),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(t.t('save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        children: [
          _SectionHeader(title: t.t('profile_title')),
          const SizedBox(height: 10),
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
                Align(
                  alignment: AlignmentDirectional.center,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.6),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: (_saving || _pickingAvatar) ? null : _changeAvatar,
                            customBorder: const CircleBorder(),
                            child: CircleAvatar(
                              radius: 34,
                              backgroundColor: Colors.white.withValues(alpha: 0.10),
                              foregroundImage: avatarImage,
                              child: avatarImage == null
                                  ? Text(
                                      (_nameController.text.trim().isNotEmpty ? _nameController.text.trim()[0] : 'U')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      if (showRemove)
                        PositionedDirectional(
                          end: -2,
                          bottom: -2,
                          child: _AvatarActionIcon(
                            icon: Icons.delete_outline,
                            onTap: _deleteAvatar,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _Field(
                        label: t.t('name'),
                        controller: _nameController,
                        keyboardType: TextInputType.name,
                        validator: (v) => (v == null || v.trim().isEmpty) ? t.t('field_required') : null,
                      ),
                      const SizedBox(height: 10),
                      _Field(
                        label: t.t('email'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || v.trim().isEmpty) ? t.t('field_required') : null,
                      ),
                      const SizedBox(height: 10),
                      _Field(
                        label: t.t('username'),
                        controller: _usernameController,
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 10),
                      _Field(
                        label: t.t('phone'),
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionHeader(title: t.t('security')),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                ListTile(
                  onTap: () => context.push('/account/password'),
                  leading: Icon(Icons.lock_outline_rounded, color: Colors.white.withValues(alpha: 0.82)),
                  title: Text(
                    t.t('update_password'),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  trailing: Icon(Icons.chevron_left_rounded, color: Colors.white.withValues(alpha: 0.35)),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                ListTile(
                  onTap: () => context.push('/account/2fa'),
                  leading: Icon(Icons.verified_user_outlined, color: Colors.white.withValues(alpha: 0.82)),
                  title: Text(
                    t.t('two_factor_authentication'),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      twoFactorEnabled ? t.t('enabled') : t.t('disabled'),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                    ),
                  ),
                  trailing: Icon(Icons.chevron_left_rounded, color: Colors.white.withValues(alpha: 0.35)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.78),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _AvatarActionIcon extends StatelessWidget {
  const _AvatarActionIcon({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xff0b0b0b),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.88)),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.92),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffef233c)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffef233c)),
        ),
      ),
    );
  }
}
