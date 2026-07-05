import 'runtime_diagnostic_logger.dart';

/// Release-safe navigator route tracing.
abstract final class RouteTraceLogger {
  static void push({required String route}) {
    RuntimeDiagnosticLogger.startup('[RouteTrace] push route=$route');
  }

  static void unknownRoute({required String route}) {
    RuntimeDiagnosticLogger.startup('[RouteTrace] unknown_route route=$route');
  }

  static void blockedRoute({required String route, required String reason}) {
    RuntimeDiagnosticLogger.startup(
      '[RouteTrace] blocked_route route=$route reason=$reason',
    );
  }
}
