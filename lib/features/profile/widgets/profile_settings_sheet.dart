import 'package:flutter/material.dart';
import 'profile_settings_tile.dart';

class ProfileSettingsSheet extends StatelessWidget {
  const ProfileSettingsSheet({
    super.key,
    required this.privacyUrl,
    required this.termsUrl,
    required this.onPrivacyTap,
    required this.onTermsTap,
    required this.onDeleteAccountTap,
    required this.privacyTitle,
    required this.termsTitle,
    required this.deleteAccountTitle,
  });

  final String privacyUrl;
  final String termsUrl;
  final String privacyTitle;
  final String termsTitle;
  final String deleteAccountTitle;
  final VoidCallback onPrivacyTap;
  final VoidCallback onTermsTap;
  final VoidCallback onDeleteAccountTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileSettingsTile(
              title: privacyTitle,
              icon: Icons.privacy_tip_outlined,
              visible: privacyUrl.isNotEmpty,
              onTap: () {
                Navigator.of(context).pop();
                onPrivacyTap();
              },
            ),
            ProfileSettingsTile(
              title: termsTitle,
              icon: Icons.description_outlined,
              visible: termsUrl.isNotEmpty,
              onTap: () {
                Navigator.of(context).pop();
                onTermsTap();
              },
            ),
            ProfileSettingsTile(
              title: deleteAccountTitle,
              icon: Icons.delete_outline,
              danger: true,
              onTap: () {
                Navigator.of(context).pop();
                onDeleteAccountTap();
              },
            ),
          ],
        ),
      ),
    );
  }
}
