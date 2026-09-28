import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../app/app_bootstrap.dart';
import '../core/app_ready.dart';
import '../core/config/runtime_config.dart';
import '../core/qr_initial_params.dart';
import '../core/review_state.dart';
import '../core/web_boot.dart';
import '../core/web_boot_loader.dart';
import '../core/web_boot_step_profiler.dart';
typedef IbulAppRunner = void Function();

/// Shared web-safe boot sequence with fatal error fallback UI.
Future<void> runIbulAppBootstrap({
  required Stopwatch bootWatch,
  required IbulAppRunner runAppWidget,
  required Future<void> Function(Stopwatch sw) initServicesBackground,
  Future<void> Function()? afterCoreInit,
  bool useQrFastPath = true,
}) async {
  WebBootLogger.log('start');
  WebBootStepProfiler.start('boot_total');
  debugPrint('[WebPerf] boot_start');

  QrInitialParams.captureFromUri();
  debugPrint(
    '[Boot] ${bootWatch.elapsedMilliseconds}ms — QR params captured. '
    'isQrPath=${QrInitialParams.isQrPath}',
  );

  configureAppDiagnostics(
    startupMessage: kIsWeb
        ? 'Starting IBUL App on Web'
        : 'Starting IBUL App on Native Platform',
    includeErrorStackTrace: true,
  );

  if (kIsWeb) {
    if (useQrFastPath && QrInitialParams.isQrPath) {
      debugPrint(
        '[Boot] ${bootWatch.elapsedMilliseconds}ms — QR web fast-path: runApp immediately',
      );
      unawaited(initServicesBackground(bootWatch));
      runAppWidget();
      WebBootLogger.log('app_ready', detail: 'qr_fast_path');
      WebBootStepProfiler.done('boot_total', detail: 'qr_fast_path');
      _scheduleWebBootLoaderDismiss();
      return;
    }

    try {
      WebBootStepProfiler.start('supabase_config_read');
      WebBootLogger.supabaseConfig(
        hasUrl: AppRuntimeConfig.rawSupabaseUrl.trim().isNotEmpty,
        hasAnonKey: AppRuntimeConfig.rawSupabaseAnonKey.trim().isNotEmpty,
      );
      WebBootStepProfiler.done('supabase_config_read');
      Intl.defaultLocale = 'tr_TR';

      runAppWidget();
      WebBootLogger.log('app_ready', detail: 'web_deferred_init');
      WebBootStepProfiler.done('first_frame_scheduled');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint(
          '[WebPerf] first_frame_ms=${bootWatch.elapsedMilliseconds}',
        );
      });
      // HTML shell stays until HomeScreenCore's first frame. The engine's
      // first frame is still WebHomeShell, which is not clickable.

      unawaited(
        _completeWebBootInit(
          bootWatch: bootWatch,
          afterCoreInit: afterCoreInit,
        ),
      );
      WebBootStepProfiler.done('boot_total', detail: 'web_deferred_init');
    } catch (error, stackTrace) {
      WebBootStepProfiler.error('boot_total', error);
      WebBootLogger.log('fatal_error', detail: error.toString());
      debugPrint('Fatal startup error: $error');
      debugPrintStack(stackTrace: stackTrace);
      runApp(buildWebBootFatalScreen(error, stackTrace: stackTrace));
      _scheduleWebBootLoaderDismiss();
    }
    return;
  }

  try {
    WebBootStepProfiler.start('supabase_config_read');
    WebBootLogger.supabaseConfig(
      hasUrl: AppRuntimeConfig.rawSupabaseUrl.trim().isNotEmpty,
      hasAnonKey: AppRuntimeConfig.rawSupabaseAnonKey.trim().isNotEmpty,
    );
    WebBootStepProfiler.done('supabase_config_read');

    WebBootStepProfiler.start('supabase_initialize');
    Intl.defaultLocale = 'tr_TR';
    await initializeDateFormatting('tr_TR');
    await initializeAppSupabase();
    WebBootStepProfiler.done('supabase_initialize');

    if (afterCoreInit != null) {
      WebBootStepProfiler.start('after_core_init');
      await afterCoreInit();
      WebBootStepProfiler.done('after_core_init');
    }

    ReviewState().initialize();
    if (!appServicesReadyCompleter.isCompleted) {
      appServicesReadyCompleter.complete();
    }

    runAppWidget();
    WebBootLogger.log('app_ready');
    WebBootStepProfiler.done('boot_total');
  } catch (error, stackTrace) {
    WebBootStepProfiler.error('boot_total', error);
    WebBootLogger.log('fatal_error', detail: error.toString());
    debugPrint('Fatal startup error: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(buildWebBootFatalScreen(error, stackTrace: stackTrace));
  }
}

void _scheduleWebBootLoaderDismiss() {
  if (!kIsWeb) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    dismissWebBootLoader();
  });
}

Future<void> _completeWebBootInit({
  required Stopwatch bootWatch,
  Future<void> Function()? afterCoreInit,
}) async {
  try {
    WebBootStepProfiler.start('supabase_initialize');
    final supabaseWatch = Stopwatch()..start();
    await Future.wait<void>([
      initializeDateFormatting('tr_TR'),
      initializeAppSupabase(),
    ]);
    debugPrint(
      '[WebPerf] supabase_init_ms=${supabaseWatch.elapsedMilliseconds}',
    );
    WebBootStepProfiler.done('supabase_initialize');

    if (afterCoreInit != null) {
      WebBootStepProfiler.start('after_core_init');
      await afterCoreInit();
      WebBootStepProfiler.done('after_core_init');
    }

    ReviewState().initialize();
    debugPrint('[Boot] ${bootWatch.elapsedMilliseconds}ms — web deferred init: done');
    if (!appServicesReadyCompleter.isCompleted) {
      appServicesReadyCompleter.complete();
    }
  } catch (error, stackTrace) {
    WebBootStepProfiler.error('supabase_initialize', error);
    WebBootLogger.log('auth_init_error', detail: error.toString());
    debugPrint('[Boot] ${bootWatch.elapsedMilliseconds}ms — web deferred init error: $error');
    debugPrintStack(stackTrace: stackTrace);
    if (!appServicesReadyCompleter.isCompleted) {
      appServicesReadyCompleter.completeError(error, stackTrace);
    }
  }
}

Future<void> initIbulServicesBackground(Stopwatch sw) async {
  try {
    debugPrint('[Boot] ${sw.elapsedMilliseconds}ms — background init: start');
    await Future.wait<void>([
      initializeDateFormatting('tr_TR'),
      initializeAppSupabase(),
    ]);
    ReviewState().initialize();
    debugPrint('[Boot] ${sw.elapsedMilliseconds}ms — background init: done');
    if (!appServicesReadyCompleter.isCompleted) {
      appServicesReadyCompleter.complete();
    }
  } catch (error, stackTrace) {
    WebBootLogger.log('auth_init_error', detail: error.toString());
    debugPrint('[Boot] ${sw.elapsedMilliseconds}ms — background init error: $error');
    debugPrintStack(stackTrace: stackTrace);
    if (!appServicesReadyCompleter.isCompleted) {
      appServicesReadyCompleter.completeError(error, stackTrace);
    }
  }
}
