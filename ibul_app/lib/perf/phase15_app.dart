import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app/app_providers.dart';
import '../core/app_motion.dart';
import '../core/constants.dart';
import 'phase14_router.dart';

void markPhase15(String name) => html.window.performance.mark(name);

/// Same providers, locale, and theme for every Phase 15 home variant.
void runPhase15Home(Widget Function() home) {
  runApp(
    MultiProvider(
      providers: buildCustomerProviders(),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        locale: const Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: _theme(),
        routerConfig: createPhase14Router(home: home),
      ),
    ),
  );
}

ThemeData _theme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
  ).copyWith(
    secondaryContainer: AppColors.softPurple,
    tertiaryContainer: AppColors.softPurple,
    surfaceTint: AppColors.popupLavenderStrong,
  );
  return ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.primary,
    colorScheme: colorScheme,
    pageTransitionsTheme: AppMotion.pageTransitionsTheme(),
    scaffoldBackgroundColor: AppColors.background,
    extensions: const <ThemeExtension<dynamic>>[IbulColorTokens()],
  );
}
