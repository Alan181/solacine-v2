import 'package:flutter/material.dart';
import '../../../app/i18n.dart';

class ProfileLogoutButton extends StatelessWidget {
  const ProfileLogoutButton({
    super.key,
    required this.onLogout,
  });

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onLogout,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(t.t('logout')),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.90),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
