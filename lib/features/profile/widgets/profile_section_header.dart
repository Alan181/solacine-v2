import 'package:flutter/material.dart';

class ProfileSectionHeader extends StatelessWidget {
  const ProfileSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Icon(Icons.chevron_left_rounded, color: Colors.white.withValues(alpha: 0.35)),
      ],
    );
  }
}
