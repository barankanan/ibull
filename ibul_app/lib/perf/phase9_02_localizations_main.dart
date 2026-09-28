import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';

/// Phase 9 layer: Material + the production locale delegates only.
void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale('tr'),
      supportedLocales: [Locale('tr')],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: Text('l10n'))),
    ),
  );
}
