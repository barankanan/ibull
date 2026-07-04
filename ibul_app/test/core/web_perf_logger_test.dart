import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/web_perf_logger.dart';

void main() {
  tearDown(WebPerfLogger.resetForTests);

  group('WebPerfLogger', () {
    test('logs app start and first frame', () {
      WebPerfLogger.resetForTests();
      expect(() => WebPerfLogger.logAppStart(), returnsNormally);
      expect(() => WebPerfLogger.logFirstFrame(), returnsNormally);
      expect(() => WebPerfLogger.logHomeShellRendered(), returnsNormally);
    });

    test('tracks supabase and image counters', () {
      WebPerfLogger.resetForTests();
      WebPerfLogger.recordSupabaseInitialRequest(2);
      WebPerfLogger.recordImageWidgetsScheduled(4);
      WebPerfLogger.logCriticalProductsLoaded(count: 8, ms: 120);
      expect(() => WebPerfLogger.logDeferredSectionsStarted(), returnsNormally);
      expect(() => WebPerfLogger.logDeferredSectionsCompleted(), returnsNormally);
    });
  });
}
