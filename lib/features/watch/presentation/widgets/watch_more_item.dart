import 'package:flutter/material.dart';

class WatchMoreItem extends StatelessWidget {
  const WatchMoreItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ),
            if (subtitle != null) ...[
              Text(
                subtitle!,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontWeight: FontWeight.w500, fontSize: 12),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
