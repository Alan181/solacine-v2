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
  const DrameReelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(appLocaleProvider).valueOrNull;
    final bootstrap = ref.watch(appBootstrapProvider).valueOrNull;

    final List<Locale> serverLocales = (bootstrap?.languages.isNotEmpty ?? false)
        ? bootstrap!.languages.map((e) => Locale(e.code)).toList()
        : [];

    const fallbackLocales = [Locale('id'), Locale('en'), Locale('ar')];
    final supportedLocales = <Locale>[
      ...serverLocales,
      for (final l in fallbackLocales)
        if (!serverLocales.any((s) => s.languageCode == l.languageCode)) l,
    ];

    // Memastikan effectiveLocale terdefinisi dengan benar (Default ke 'id')
    final Locale effectiveLocale;
    if (locale != null) {
      effectiveLocale = locale;
    } else {
      effectiveLocale = const Locale('id');
    }

    final isArabic = effectiveLocale.languageCode.toLowerCase().startsWith('ar');
    final font = isArabic ? 'Almarai' : null;
    final baseLight = buildLightTheme(fontFamily: font);
    final baseDark = buildDarkTheme(fontFamily: font);
    final lightTheme = baseLight;
    final darkTheme = baseDark;

    const overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    );
    SystemChrome.setSystemUIOverlayStyle(overlay);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return MaterialApp.router(
      title: 'Solacine',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return PushTokenRegistrar(
          child: AdsInitializer(
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlay,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      locale: effectiveLocale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppI18nDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
