import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Phase 9 layer: localization plus the Supabase library, without initialize.
void main() {
  final Object retained = Supabase.initialize;
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: Text('supabase-import $retained'))),
    ),
  );
}
