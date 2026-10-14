import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap/application/bootstrap_controller.dart';
import '../application/locale_controller.dart';

class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appBootstrapProvider).valueOrNull;
    final languages = bootstrap?.languages ?? const [];
    if (languages.length < 2) return const SizedBox.shrink();

    final current = ref.watch(appLocaleProvider).valueOrNull?.languageCode ?? bootstrap?.localeCode ?? '';
    final currentLang = languages.where((e) => e.code == current).cast().firstOrNull;
    final label = (currentLang?.code ?? current).toUpperCase();

    return PopupMenuButton<String>(
      onSelected: (code) => ref.read(appLocaleProvider.notifier).setLocale(Locale(code)),
      itemBuilder: (context) {
        return [
          for (final l in languages)
            PopupMenuItem<String>(
              value: l.code,
              child: Text('${l.name} (${l.code.toUpperCase()})'),
            ),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label.isEmpty ? 'LANG' : label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

