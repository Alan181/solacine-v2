import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/i18n.dart';
import '../../../shared/constants.dart';
import '../../../shared/data/shared_prefs_provider.dart';
import '../data/app_config_api.dart';
import '../data/public_settings_api.dart';
import '../../localization/data/localization_api.dart';

class AppBootstrapData {
  const AppBootstrapData({
    required this.appConfig,
    required this.publicSettings,
    required this.languages,
    required this.localeCode,
  });

  final AppConfigResult appConfig;
  final Map<String, dynamic> publicSettings;
  final List<LanguageDto> languages;
  final String localeCode;
}

final appBootstrapProvider = FutureProvider<AppBootstrapData>((ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  const localePrefsKey = 'app_locale';
  final stored = (prefs.getString(localePrefsKey) ?? '').trim();
  final storedLang = stored == '' || stored == 'system' ? '' : stored;

  String chosenLang = storedLang.isNotEmpty ? storedLang : 'ar';
  final cachedBoot = await AppI18n.loadTranslationsCache(chosenLang, prefs);
  if (cachedBoot.isNotEmpty) AppI18n.setTranslations(chosenLang, cachedBoot);

  final publicSettings = await ref.watch(publicSettingsApiProvider).getPublicSettings();

  final platform = _detectPlatform();
  final key = platform == 'ios' ? iosAppConfigKey : androidAppConfigKey;
  if (key.trim().isEmpty) {
    throw Exception('Missing app config key for $platform');
  }

  final appConfig = await ref.watch(appConfigApiProvider).getAppConfig(apiKey: key, platform: platform);

  final languagesPayload = await ref.watch(localizationApiProvider).getLanguages();
  final defaultLang = languagesPayload.defaultCode.trim().isNotEmpty ? languagesPayload.defaultCode : 'en';

  if (storedLang.isEmpty) {
    chosenLang = defaultLang;
    await prefs.setString(localePrefsKey, chosenLang);
  }

  final cached = await AppI18n.loadTranslationsCache(chosenLang, prefs);
  if (cached.isNotEmpty) {
    AppI18n.setTranslations(chosenLang, cached);
  }

  String finalLang = chosenLang;
  try {
    final tPayload = await ref.watch(localizationApiProvider).getTranslations(chosenLang);
    AppI18n.setTranslations(tPayload.lang, tPayload.translations);
    await AppI18n.saveTranslationsCache(tPayload.lang, prefs);
    finalLang = tPayload.lang;
  } catch (_) {}

  return AppBootstrapData(
    appConfig: appConfig,
    publicSettings: publicSettings,
    languages: languagesPayload.languages,
    localeCode: finalLang,
  );
});

String _detectPlatform() {
  if (kIsWeb) return 'android';
  if (Platform.isIOS) return 'ios';
  return 'android';
}
