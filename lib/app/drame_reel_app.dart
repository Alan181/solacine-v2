import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'i18n.dart';
import 'router.dart';
import 'theme.dart';
import '../features/bootstrap/application/bootstrap_controller.dart';
import '../features/localization/application/locale_controller.dart';
import '../features/notifications/application/push_token_registrar.dart';
import '../features/ads/application/ads_initializer.dart';

class DrameReelApp extends ConsumerWidget {
  Const DrameReelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Final router = ref.watch(appRouterProvider);
    Final locale = ref.watch(appLocaleProvider).valueOrNull;
    Final bootstrap = ref.watch(appBootstrapProvider).valueOrNull;

    Final List<Locale> serverLocales = (bootstrap?.languages.isNotEmpty ?? false)
        ? bootstrap!.languages.map((e) => Locale(e.code)).toList()
        : [];

    Const fallbackLocales = [Locale('id'), Locale('en'), Locale('ar')];
    Final supportedLocales = <Locale>[
      ...serverLocales,
      For (final l in fallbackLocales)
        If (!serverLocales.any((s) => s.languageCode == l.languageCode)) l,
    ];

    // 👉 MODIFIKASI DI SINI:
    // Urutan prioritas: 
    // 1. Pilihan manual pengguna (locale dari provider/shared_preferences)
    // 2. Jika belum pernah diatur, paksa JADI Bahasa Indonesia ('id') sebagai default mutlak.
    Final Locale effectiveLocale;
    If (locale != null) {
      EffectiveLocale = locale;
    } else {
      // Selalu set default ke 'id' (Bahasa Indonesia)
      EffectiveLocale = const Locale('id');
    }

    Final isArabic = effectiveLocale.languageCode.toLowerCase().startsWith('ar');
    Final font = isArabic ? 'Almarai' : null;
    Final baseLight = buildLightTheme(fontFamily: font);
    Final baseDark = buildDarkTheme(fontFamily: font);
    Final lightTheme = baseLight;
    Final darkTheme = baseDark;

    Const overlay = SystemUiOverlayStyle(
      StatusBarColor: Colors.transparent,
      StatusBarIconBrightness: Brightness.light,
      StatusBarBrightness: Brightness.dark,
      SystemNavigationBarColor: Colors.black,
      SystemNavigationBarDividerColor: Colors.transparent,
      SystemNavigationBarIconBrightness: Brightness.light,
      SystemNavigationBarContrastEnforced: false,
    );
    SystemChrome.setSystemUIOverlayStyle(overlay);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    Return MaterialApp.router(
      Title: 'Solacine',
      DebugShowCheckedModeBanner: false,
      Theme: lightTheme,
      DarkTheme: darkTheme,
      ThemeMode: ThemeMode.system,
      Builder: (context, child) {
        Return PushTokenRegistrar(
          Child: AdsInitializer(
            Child: AnnotatedRegion<SystemUiOverlayStyle>(
              Value: overlay,
              Child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      Locale: effectiveLocale,
      SupportedLocales: supportedLocales,
      LocalizationsDelegates: const [
        AppI18nDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      RouterConfig: router,
    );
  }
}
