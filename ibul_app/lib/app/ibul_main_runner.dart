import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/runtime_config.dart';
import '../core/ibul_app_mode.dart';
import '../core/ibul_boot_stage.dart';
import '../core/runtime_diagnostic_logger.dart';
import '../core/web_boot.dart';
import '../core/web_boot_step_profiler.dart';
import '../core/web_perf_logger.dart';
import 'app_navigator.dart';
import 'web_path_url_strategy_stub.dart'
    if (dart.library.html) 'web_path_url_strategy_web.dart';
import 'app_providers.dart';
import 'customer_app.dart';
import 'firebase_native_boot_stub.dart'
    if (dart.library.io) 'firebase_native_boot_io.dart' as firebase_boot;
import 'full_app.dart';
import 'ibul_app_boot.dart';
import 'ibul_boot_shell_app.dart';
import 'ibul_safe_boot_app.dart';

Future<void> runIbulMain(IbulAppMode mode) async {
  runZonedGuarded(
    () async {
      await _mainImpl(mode);
    },
    (error, stack) {
      WebBootLogger.log('zone_error', detail: error.toString());
      debugPrint('Unhandled zone error: $error');
      debugPrintStack(stackTrace: stack);
    },
  );
}

Future<void> _mainImpl(IbulAppMode mode) async {
  IbulAppModeRegistry.current = mode;
  WidgetsFlutterBinding.ensureInitialized();
  enableIbulPathUrlStrategy();
  WebPerfLogger.logAppStart();
  WebBootLogger.log('main', detail: 'entered mode=${mode.name}');
  RuntimeDiagnosticLogger.startup(
    '[Boot] entrypoint=${ibulEntrypointLabel(mode)}',
  );
  // Güvenli config diagnostiği (key loglanmaz; sadece varlık/host/uzunluk/kaynak).
  AppRuntimeConfig.logSupabaseConfigDiagnostics();
  WebBootStepProfiler.done('widgets_binding');

  if (AppRuntimeConfig.safeBootMode) {
    runIbulSafeBootApp();
    return;
  }

  WebBootLogger.log('safe_boot', detail: 'enabled=false');
  _configureBootErrorWidget(mode);

  final bootWatch = Stopwatch()..start();
  await runIbulAppBootstrap(
    bootWatch: bootWatch,
    initServicesBackground: initIbulServicesBackground,
    afterCoreInit: kIsWeb ? null : firebase_boot.initFirebaseNative,
    runAppWidget: () {
      WebBootStepProfiler.start('provider_tree');
      final providerCount = countMountedProviders(mode);
      RuntimeDiagnosticLogger.startup(
        '[Boot] customer shell runApp providers=$providerCount',
      );
      RuntimeDiagnosticLogger.startup('[AppMode] ${mode.name}');
      runApp(_buildReadyAppTree(mode));
      WebBootStepProfiler.done('provider_tree');
      RuntimeDiagnosticLogger.startup(
        'app boot ms=${bootWatch.elapsedMilliseconds}',
      );
      if (!kIsWeb) {
        unawaited(
          firebase_boot.initPushNotifications(navigatorKey: appNavigatorKey),
        );
      }
    },
  );
}

Widget _buildReadyAppTree(IbulAppMode mode) {
  WebBootStepProfiler.start('provider_tree');
  final stage = AppRuntimeConfig.bootStage;
  if (stage == IbulBootStage.providers) {
    final tree = MultiProvider(
      providers: buildProvidersForMode(mode),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: IbulBootDiagnosticProvidersPage(),
      ),
    );
    WebBootStepProfiler.done('provider_tree', detail: 'diagnostic');
    return tree;
  }

  final appWidget = mode == IbulAppMode.customer
      ? const CustomerApp()
      : const FullApp();

  final tree = MultiProvider(
    providers: buildProvidersForMode(mode),
    child: appWidget,
  );
  WebBootStepProfiler.done('provider_tree');
  return tree;
}

void _configureBootErrorWidget(IbulAppMode mode) {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Bir hata oluştu:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  };
}
