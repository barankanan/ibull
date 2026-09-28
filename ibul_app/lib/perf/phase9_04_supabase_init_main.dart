import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Phase 9 layer: call Supabase.initialize with the local benchmark defines.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  html.window.performance.mark('phase9_supabase_init_start');
  try {
    await Supabase.initialize(
      url: const String.fromEnvironment('IBUL_SUPABASE_URL'),
      anonKey: const String.fromEnvironment('IBUL_SUPABASE_ANON_KEY'),
    );
  } catch (_) {}
  html.window.performance.mark('phase9_supabase_init_end');
  runApp(const _Shell(label: 'supabase-init'));
}

class _Shell extends StatelessWidget {
  const _Shell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: Text(label))),
    );
  }
}
