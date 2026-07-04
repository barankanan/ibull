import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/home_section_trace.dart';
import 'package:ibul_app/core/web_boot_trace.dart';
import 'package:ibul_app/core/web_perf_trace.dart';

void main() {
  group('Home boot watchdog', () {
    setUp(() {
      WebPerfTrace.resetForTests();
      WebBootTraceNotifier.active = null;
      currentWebBootAttemptId = null;
    });

    test('markComplete sets bootComplete and terminal stage', () {
      final trace = WebBootTraceNotifier(module: 'home_screen');
      expect(trace.bootAttemptId, isNotEmpty);
      expect(currentWebBootAttemptId, trace.bootAttemptId);

      trace.setStage(WebBootTraceStage.loadLibraryStarted);
      trace.setStage(WebBootTraceStage.loadLibraryCompleted);
      trace.setStage(WebBootTraceStage.deferredFactoryCompleted);
      trace.setStage(WebBootTraceStage.homeCoreWidgetCreated);
      trace.markComplete();

      expect(trace.isComplete, isTrue);
      expect(trace.snapshot.bootComplete, isTrue);
      expect(trace.snapshot.firstFrameRendered, isTrue);
      expect(trace.snapshot.moduleLoaded, isTrue);
      expect(trace.snapshot.factoryCompleted, isTrue);
      expect(trace.snapshot.stage, WebBootTraceStage.completed);
    });

    test('section timeout does not mark boot incomplete or set global error', () {
      final trace = WebBootTraceNotifier(module: 'home_screen');
      trace.markComplete();

      trace.noteSectionTimeout('sponsoredLists');
      trace.noteSectionTimeout('recentProducts');

      expect(trace.isComplete, isTrue);
      expect(trace.snapshot.bootComplete, isTrue);
      expect(trace.snapshot.globalErrorReason, isNull);
      expect(trace.snapshot.lastSectionTimeout, 'recentProducts');
      expect(trace.snapshot.stage, WebBootTraceStage.completed);
    });

    test('noteSectionTimeout before markComplete does not change boot stage', () {
      final trace = WebBootTraceNotifier(module: 'home_screen');
      trace.setStage(WebBootTraceStage.loadLibraryStarted);

      trace.noteSectionTimeout('sponsoredLists');

      expect(trace.isComplete, isFalse);
      expect(trace.snapshot.lastSectionTimeout, 'sponsoredLists');
      expect(trace.snapshot.stage, WebBootTraceStage.loadLibraryStarted);
      expect(trace.snapshot.globalErrorReason, isNull);
    });

    test('notifyHomeSectionLoadOutcome records timeout without boot failure', () {
      final trace = WebBootTraceNotifier(module: 'home_screen');
      trace.markComplete();

      notifyHomeSectionLoadOutcome(
        sectionName: 'recentProducts',
        source: 'timeout',
        state: 'empty',
        elapsedMs: 10007,
        error: 'timeout',
        timeoutMs: 10000,
      );

      expect(trace.snapshot.lastSectionTimeout, 'recentProducts');
      expect(trace.snapshot.bootComplete, isTrue);
      expect(trace.snapshot.globalErrorReason, isNull);
    });

    test('webBootTerminalSuccessStages includes home core first frame', () {
      expect(
        webBootTerminalSuccessStages,
        contains(WebBootTraceStage.homeCoreFirstFrameRendered),
      );
      expect(
        webBootTerminalSuccessStages,
        contains(WebBootTraceStage.bootComplete),
      );
    });
  });
}
