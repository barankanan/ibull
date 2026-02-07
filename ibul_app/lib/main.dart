import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';
import 'core/app_state.dart';
import 'core/constants.dart';
import 'screens/home_screen.dart';
import 'screens/product_image_test_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    // Only access dart:io if NOT on web
    // We avoid direct import of dart:io to prevent compilation errors on web
    // by using conditional imports if strictly necessary, but for simple prints
    // we can just omit or use a safe approach. 
    // For now, we simply remove the io.pid dependency or wrap it carefully.
    // However, since we cannot easily conditional import in one file without creating others,
    // we will remove the specific OS/PID print that requires dart:io.
    debugPrint('Starting IBUL App on Native Platform');
  } else {
    debugPrint('Starting IBUL App on Web');
  }

  // Global Flutter error handler (shows errors in terminal)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    debugPrint('Unhandled Flutter error: ${details.exception}');
  };

  // Informative debug message on start (hot restart will re-run this)
  assert(() {
    debugPrint(
      'App is running in DEBUG mode. Start with ./scripts/run.sh or flutter run -d <deviceId>, then press "r" (hot reload) or "R" (hot restart) in this terminal.'
    );
    return true;
  }());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AppState()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IBUL App',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr'),
        Locale('en'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        scaffoldBackgroundColor: AppColors.background,
      ),
      // Wrap HomeScreen so we can detect hot reload and show status
      home: const HomeWrapper(),
    );
  }
}

// Wrapper that logs hot reloads and prints heartbeat to terminal
class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  @override
  void reassemble() {
    super.reassemble();
    debugPrint('Hot reload / reassemble at ${DateTime.now().toIso8601String()}');
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}


