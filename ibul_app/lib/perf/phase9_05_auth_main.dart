import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

/// Phase 9 layer: retain AuthService on top of Supabase. No Google sign-in UI.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: const String.fromEnvironment('IBUL_SUPABASE_URL'),
      anonKey: const String.fromEnvironment('IBUL_SUPABASE_ANON_KEY'),
    );
  } catch (_) {}
  final auth = AuthService();
  runApp(_Shell(label: 'auth ${auth.runtimeType}'));
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
