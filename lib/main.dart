import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/core/constants.dart';
import 'package:ibul_app/firebase_options.dart';
import 'package:ibul_app/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('Starting IBUL App. Platform: ${kIsWeb ? "web" : "native"}');

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
    ChangeNotifierProvider.value(
      value: AppState(),
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
