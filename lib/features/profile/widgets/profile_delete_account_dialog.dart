import 'package:flutter/material.dart';

class ProfileDeleteAccountDialog extends StatelessWidget {
  const ProfileDeleteAccountDialog({
    super.key,
    required this.title,
    required this.content,
    required this.cancelText,
    required this.deleteText,
  });

  final String title;
  final String content;
  final String cancelText;
  final String deleteText;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xff0b0b0b),
      title: Text(
        title,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 16, fontWeight: FontWeight.w500),
      ),
      content: Text(
        content,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 13, fontWeight: FontWeight.w500),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: 0.78)),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: const Color(0xffef233c)),
          child: Text(deleteText),
        ),
      ],
    );
  }
}
