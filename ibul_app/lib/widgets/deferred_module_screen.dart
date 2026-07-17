import 'dart:async';

import 'package:flutter/material.dart';

import '../core/web_boot_error_store.dart';
import '../core/web_boot_trace.dart';
import '../core/web_perf_trace.dart';
import '../core/web_page_reload.dart';

/// Loads a deferred library with timeout, visible errors, retry, and boot tracing.
class DeferredModuleScreen extends StatefulWidget {
  const DeferredModuleScreen({
    super.key,
    required this.moduleName,
    required this.loadLibrary,
    required this.builder,
    this.loading,
    this.timeout = const Duration(seconds: 90),
    this.trace,
  });

  final String moduleName;
  final Future<void> Function() loadLibrary;
  final Widget Function() builder;
  final Widget? loading;
  final Duration timeout;
  final WebBootTraceNotifier? trace;

  @override
  State<DeferredModuleScreen> createState() => _DeferredModuleScreenState();
}

class _DeferredModuleScreenState extends State<DeferredModuleScreen> {
  int _attempt = 0;
  late Future<void> _loadFuture = _startLoad();
  bool _libraryLoaded = false;
  Object? _forcedError;
  Timer? _elapsedTicker;
  Timer? _watchdogTimer;

  @override
  void initState() {
    super.initState();
    if (widget.trace != null) {
      _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        widget.trace?.tickElapsed();
      });
    }
  }

  @override
  void dispose() {
    _elapsedTicker?.cancel();
    _watchdogTimer?.cancel();
    super.dispose();
  }

  Future<void> _startLoad() {
    final attempt = ++_attempt;
    _libraryLoaded = false;
    _forcedError = null;

    final loadWatch = Stopwatch()..start();
    widget.trace?.setStage(WebBootTraceStage.loadLibraryStarted);
    WebPerfTrace.instance.mark(WebPerfTraceStage.homeDeferredLoadStarted);
    _armWatchdog(attempt);

    return widget.loadLibrary().timeout(
      widget.timeout,
      onTimeout: () {
        widget.trace?.setStage(WebBootTraceStage.timeoutTriggered);
        widget.trace?.setError(
          '${widget.moduleName} ${widget.timeout.inSeconds} sn içinde yüklenemedi.',
        );
        throw TimeoutException(
          'Ana sayfa modülü yüklenemedi (${widget.timeout.inSeconds} sn).',
        );
      },
    ).then((_) async {
      if (attempt != _attempt) return;
      _watchdogTimer?.cancel();
      debugPrint(
        '[WebPerf] route_deferred_load route=${widget.moduleName}'
        ' ms=${loadWatch.elapsedMilliseconds}',
      );
      widget.trace?.setStage(WebBootTraceStage.loadLibraryCompleted);
      WebPerfTrace.instance.mark(WebPerfTraceStage.homeDeferredLoadCompleted);
      clearWebBootError();
      // Yield one frame so shell can paint, then mount home core.
      await Future<void>.delayed(Duration.zero);
      if (!mounted || attempt != _attempt) return;
      setState(() => _libraryLoaded = true);
    }).catchError((Object error, StackTrace stack) {
      if (attempt != _attempt) return;
      _watchdogTimer?.cancel();
      widget.trace?.setStage(WebBootTraceStage.errorCaught);
      widget.trace?.setError(error.toString());
      saveWebBootError(
        module: widget.moduleName,
        message: error.toString(),
        detail: stack.toString(),
      );
      if (mounted) {
        setState(() {
          _forcedError = error;
        });
      }
    });
  }

  void _armWatchdog(int attempt) {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(widget.timeout, () {
      if (!mounted || attempt != _attempt || _libraryLoaded) return;
      if (_forcedError != null) return;
      final timeoutError = TimeoutException(
        'Ana sayfa modülü yüklenemedi (${widget.timeout.inSeconds} sn).',
      );
      widget.trace?.setStage(WebBootTraceStage.timeoutTriggered);
      widget.trace?.setError(timeoutError.message ?? timeoutError.toString());
      saveWebBootError(
        module: widget.moduleName,
        message: timeoutError.toString(),
        detail: 'Dart watchdog after ${widget.timeout.inSeconds}s',
      );
      setState(() {
        _forcedError = timeoutError;
      });
    });
  }

  void _retry() {
    widget.trace?.incrementRetry();
    setState(() {
      _loadFuture = _startLoad();
    });
  }

  Widget _safeBuildChild() {
    try {
      return widget.builder();
    } catch (error, stack) {
      widget.trace?.setStage(WebBootTraceStage.deferredFactoryError);
      widget.trace?.setError(error.toString());
      saveWebBootError(
        module: widget.moduleName,
        message: error.toString(),
        detail: stack.toString(),
      );
      return DeferredModuleErrorView(
        moduleName: widget.moduleName,
        message: error.toString(),
        onRetry: _retry,
        onReload: reloadWebPage,
        trace: widget.trace?.snapshot,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_forcedError != null) {
      return DeferredModuleErrorView(
        moduleName: widget.moduleName,
        message: _forcedError.toString(),
        onRetry: _retry,
        onReload: reloadWebPage,
        trace: widget.trace?.snapshot,
      );
    }

    if (!_libraryLoaded) {
      return FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return DeferredModuleErrorView(
              moduleName: widget.moduleName,
              message: snapshot.error.toString(),
              onRetry: _retry,
              onReload: reloadWebPage,
              trace: widget.trace?.snapshot,
            );
          }
          return widget.loading ??
              DeferredModuleLoadingView(moduleName: widget.moduleName);
        },
      );
    }

    return SizedBox.expand(
      child: _TracedDeferredChild(
        trace: widget.trace,
        child: _safeBuildChild(),
      ),
    );
  }
}

class _TracedDeferredChild extends StatefulWidget {
  const _TracedDeferredChild({
    required this.trace,
    required this.child,
  });

  final WebBootTraceNotifier? trace;
  final Widget child;

  @override
  State<_TracedDeferredChild> createState() => _TracedDeferredChildState();
}

class _TracedDeferredChildState extends State<_TracedDeferredChild> {
  bool _firstFrameLogged = false;

  @override
  void initState() {
    super.initState();
    WebPerfTrace.instance.mark(WebPerfTraceStage.homeFirstBuildStarted);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _firstFrameLogged) return;
      _firstFrameLogged = true;
      WebPerfTrace.instance.mark(WebPerfTraceStage.homeFirstFrame);
      widget.trace?.markComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    widget.trace?.markFirstBuildOnce();
    return widget.child;
  }
}

class DeferredModuleLoadingView extends StatelessWidget {
  const DeferredModuleLoadingView({
    super.key,
    required this.moduleName,
    this.child,
  });

  final String moduleName;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return child ??
        Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  '$moduleName yükleniyor…',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        );
  }
}

class DeferredModuleErrorView extends StatelessWidget {
  const DeferredModuleErrorView({
    super.key,
    required this.moduleName,
    required this.message,
    required this.onRetry,
    required this.onReload,
    this.trace,
  });

  final String moduleName;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onReload;
  final WebBootTraceSnapshot? trace;

  @override
  Widget build(BuildContext context) {
    final isHome = moduleName.contains('home');
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFF7B2FBE), size: 56),
                const SizedBox(height: 20),
                Text(
                  isHome ? 'Ana sayfa modülü yüklenemedi' : 'Modül yüklenemedi',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Deferred module: $moduleName',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                if (trace != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'stage: ${trace!.stage} · ${trace!.elapsedSeconds}s · retry ${trace!.retryCount}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.45, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2FBE),
                  ),
                  child: const Text('Tekrar Dene'),
                ),
                const SizedBox(height: 10),
                TextButton(onPressed: onReload, child: const Text('Sayfayı Yenile')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
