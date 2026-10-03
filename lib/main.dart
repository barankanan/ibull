import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ibul_app/app/app_bootstrap.dart';
import 'package:ibul_app/app/ibul_app_boot.dart';
import 'package:ibul_app/app/ibul_boot_controller.dart';
import 'package:ibul_app/app/ibul_boot_shell_app.dart';
import 'package:ibul_app/app/ibul_material_app.dart';
import 'package:ibul_app/app/shared_app_widgets.dart';
import 'package:ibul_app/app/web_path_url_strategy_stub.dart'
    if (dart.library.html) 'package:ibul_app/app/web_path_url_strategy_web.dart';
import 'package:ibul_app/app/ibul_safe_boot_app.dart';
import 'package:ibul_app/core/config/runtime_config.dart';
import 'package:ibul_app/core/ibul_boot_stage.dart';
import 'package:ibul_app/core/qr_initial_params.dart';
import 'package:ibul_app/core/route_observer.dart';
import 'package:ibul_app/core/web_boot.dart';
import 'package:ibul_app/core/web_boot_step_profiler.dart';

/// Root-level navigator key — gives push-notification service and any
/// background code a handle to the root navigator without importing the
/// ibul_app package’s standalone main.dart.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  enableIbulPathUrlStrategy();
  WebBootLogger.log('main', detail: 'entered');
  WebBootStepProfiler.done('widgets_binding');

  if (AppRuntimeConfig.safeBootMode) {
    runIbulSafeBootApp();
    return;
  }

  WebBootLogger.log('safe_boot', detail: 'enabled=false');

  if (kIsWeb) {
    _runWebProgressiveBoot();
    return;
  }

  final bootWatch = Stopwatch()..start();
  await runIbulAppBootstrap(
    bootWatch: bootWatch,
    initServicesBackground: initIbulServicesBackground,
    runAppWidget: () {
      WebBootStepProfiler.start('provider_tree');
      runApp(_buildReadyAppTree());
      WebBootStepProfiler.done('provider_tree');
    },
  );
}

void _runWebProgressiveBoot() {
  QrInitialParams.captureFromUri();
  configureAppDiagnostics(
    startupMessage: 'Starting IBUL App on Web (root entry)',
    includeErrorStackTrace: true,
  );

  final bootWatch = Stopwatch()..start();
  final controller = IbulBootController();

  WebBootStepProfiler.start('runApp_normal_shell');
  runApp(
    IbulProgressiveBootApp(
      controller: controller,
      bootStage: AppRuntimeConfig.bootStage,
      readyBuilder: (_) => _buildReadyAppTree(),
    ),
  );
  WebBootStepProfiler.done('runApp_normal_shell');

  unawaited(controller.initialize(bootWatch: bootWatch));
}

Widget _buildReadyAppTree() {
  WebBootStepProfiler.start('provider_tree');
  final stage = AppRuntimeConfig.bootStage;
  if (stage == IbulBootStage.providers) {
    final tree = MultiProvider(
      providers: buildAppProviders(),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: IbulBootDiagnosticProvidersPage(),
      ),
    );
    WebBootStepProfiler.done('provider_tree', detail: 'diagnostic');
    return tree;
  }

  final tree = MultiProvider(
    providers: buildAppProviders(),
    child: const MyApp(),
  );
  WebBootStepProfiler.done('provider_tree');
  return tree;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return IbulMaterialApp(
      navigatorKey: rootNavigatorKey,
      includeAuthRoutes: true,
      navigatorObservers: [routeObserver, SeoRouteObserver()],
    );
  }
}
