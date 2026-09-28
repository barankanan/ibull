import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../core/app_ready.dart';
import '../core/review_state.dart';
import '../core/web_boot.dart';
import '../core/web_boot_step_profiler.dart';
import 'app_bootstrap.dart';

enum IbulBootStatus {
  loading,
  ready,
  error,
}

/// Async bootstrap after the visible boot shell is on screen.
class IbulBootController extends ChangeNotifier {
  IbulBootStatus status = IbulBootStatus.loading;
  String? errorMessage;
  String currentStep = 'starting';

  Future<void> initialize({
    required Stopwatch bootWatch,
    Future<void> Function()? afterCoreInit,
  }) async {
    try {
      _setStep('core_init');
      WebBootStepProfiler.start('core_init');
      Intl.defaultLocale = 'tr_TR';
      await Future.wait<void>([
        initializeDateFormatting('tr_TR').timeout(const Duration(seconds: 8)),
        initializeAppSupabase().timeout(const Duration(seconds: 12)),
      ]);
      WebBootStepProfiler.done('core_init');

      if (afterCoreInit != null) {
        _setStep('after_core_init');
        WebBootStepProfiler.start('after_core_init');
        await afterCoreInit().timeout(const Duration(seconds: 12));
        WebBootStepProfiler.done('after_core_init');
      }

      _setStep('review_state_init');
      ReviewState().initialize();

      if (!appServicesReadyCompleter.isCompleted) {
        appServicesReadyCompleter.complete();
      }

      status = IbulBootStatus.ready;
      currentStep = 'app_ready';
      WebBootStepProfiler.done('app_ready');
      WebBootLogger.log('app_ready');
      notifyListeners();
    } catch (error, stackTrace) {
      status = IbulBootStatus.error;
      errorMessage = error.toString();
      WebBootStepProfiler.error('app_ready', error);
      WebBootLogger.log('fatal_error', detail: error.toString());
      if (kDebugMode) {
        debugPrint('IbulBootController initialize failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!appServicesReadyCompleter.isCompleted) {
        appServicesReadyCompleter.completeError(error, stackTrace);
      }
      notifyListeners();
    }
  }

  void _setStep(String step) {
    currentStep = step;
    notifyListeners();
  }
}
