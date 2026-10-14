import 'package:flutter/material.dart';
import 'profile_user_header_card.dart';

class ProfileAppBarHeader extends StatelessWidget {
  const ProfileAppBarHeader({
    super.key,
    required this.displayName,
    required this.idLabel,
    required this.emailLabel,
    required this.avatarUrl,
    required this.authProvider,
    required this.isVip,
    required this.onEdit,
  });

  final String displayName;
  final String idLabel;
  final String emailLabel;
  final String avatarUrl;
  final String authProvider;
  final bool isVip;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.22,
            child: Image.asset(
              'assets/images/holder_offline_tip_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.low,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: ProfileUserHeaderCard(
            displayName: displayName,
            idLabel: idLabel,
            emailLabel: emailLabel,
            avatarUrl: avatarUrl,
            authProvider: authProvider,
            isVip: isVip,
            onEdit: onEdit,
          ),
        ),
      ],
    );
  }
}
