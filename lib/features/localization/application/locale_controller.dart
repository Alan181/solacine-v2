import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/i18n.dart';
import '../../../shared/data/shared_prefs_provider.dart';
import '../data/localization_api.dart';

class LocaleController extends AsyncNotifier<Locale?> {
  static const _key = 'app_locale';

  @override
  Future<Locale?> build() async {
    final prefs = await ref.watch(sharedPrefsProvider.future);
    final code = prefs.getString(_key);
    if (code == null || code == 'system') return null;
    final locale = Locale(code);

    final cached = await AppI18n.loadTranslationsCache(locale.languageCode, prefs);
    if (cached.isNotEmpty) {
      AppI18n.setTranslations(locale.languageCode, cached);
    }

    try {
      final payload = await ref.read(localizationApiProvider).getTranslations(locale.languageCode);
      AppI18n.setTranslations(payload.lang, payload.translations);
      await AppI18n.saveTranslationsCache(payload.lang, prefs);
    } catch (_) {}

    return locale;
  }

  Future<void> setLocale(Locale? locale) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    if (locale == null) {
      await prefs.setString(_key, 'system');
      state = const AsyncData(null);
      return;
    }

    await prefs.setString(_key, locale.languageCode);
    state = AsyncData(locale);

    final cached = await AppI18n.loadTranslationsCache(locale.languageCode, prefs);
    if (cached.isNotEmpty) {
      AppI18n.setTranslations(locale.languageCode, cached);
    }

    try {
      final payload = await ref.read(localizationApiProvider).getTranslations(locale.languageCode);
      AppI18n.setTranslations(payload.lang, payload.translations);
      await AppI18n.saveTranslationsCache(payload.lang, prefs);
    } catch (_) {}
  }
}

final appLocaleProvider = AsyncNotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);
