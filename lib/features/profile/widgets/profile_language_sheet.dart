import 'package:flutter/material.dart';

class LanguageItem {
  final String code;
  final String name;

  const LanguageItem({required this.code, required this.name});
}

class ProfileLanguageSheet extends StatelessWidget {
  const ProfileLanguageSheet({
    super.key,
    required this.languages,
    required this.currentCode,
    required this.onLanguageSelected,
  });

  final List<LanguageItem> languages;
  final String currentCode;
  final void Function(String code) onLanguageSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        itemBuilder: (context, index) {
          final l = languages[index];
          final selected = l.code == currentCode;
          return ListTile(
            onTap: () {
              onLanguageSelected(l.code);
              Navigator.of(context).pop();
            },
            title: Text(
              l.name,
              style: TextStyle(
                color: Colors.white.withValues(alpha: selected ? 0.95 : 0.80),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: selected ? const Icon(Icons.check_rounded, color: Color(0xffef233c)) : null,
          );
        },
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
        itemCount: languages.length,
      ),
    );
  }
}
