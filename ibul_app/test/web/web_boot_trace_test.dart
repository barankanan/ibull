import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/web_boot_trace.dart';

void main() {
  group('WebBootTraceNotifier', () {
    test('markComplete sets bootComplete flags', () {
      final trace = WebBootTraceNotifier(module: 'home_screen');
      trace.setStage(WebBootTraceStage.loadLibraryStarted);
      trace.setStage(WebBootTraceStage.loadLibraryCompleted);
      trace.setStage(WebBootTraceStage.deferredFactoryStarted);
      trace.setStage(WebBootTraceStage.deferredFactoryCompleted);
      trace.setStage(WebBootTraceStage.homeCoreWidgetCreated);
      trace.markFirstBuildOnce();
      expect(trace.snapshot.stage, WebBootTraceStage.homeCoreFirstBuildStarted);

      trace.markComplete();
      expect(trace.isComplete, isTrue);
      expect(trace.snapshot.bootComplete, isTrue);
      expect(trace.snapshot.firstFrameRendered, isTrue);
      expect(trace.snapshot.stage, WebBootTraceStage.completed);
      expect(trace.bootAttemptId, isNotEmpty);
    });

    test('incrementRetry bumps retry count and clears error', () {
      final trace = WebBootTraceNotifier(module: 'home_screen');
      trace.setError('boom');
      trace.incrementRetry();
      expect(trace.snapshot.retryCount, 1);
      expect(trace.snapshot.lastError, isNull);
    });

    test('setError stores message on snapshot', () {
      final trace = WebBootTraceNotifier(module: 'home_screen');
      trace.setError('network failed');
      expect(trace.snapshot.lastError, 'network failed');
    });
  });
}
