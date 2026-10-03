import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'home_section_error.dart';

/// Bölüm görünür olana ya da kullanıcı ona [prefetchViewports] viewport kadar
/// yaklaşana dek [placeholderHeight] kadar boşluk gösterir; ilk build'de
/// hiçbir şey yüklemez.
class HomeViewportSection extends StatefulWidget {
  const HomeViewportSection({
    super.key,
    required this.placeholderHeight,
    required this.loadLibrary,
    required this.builder,
    this.errorMessage = 'Bu bölüm şu an yüklenemedi.',
    this.prefetchViewports = 1.25,
    this.debugName = 'Section',
  });

  final double placeholderHeight;
  final Future<void> Function() loadLibrary;
  final Widget Function() builder;
  final String errorMessage;
  final String debugName;

  /// Prefetch penceresi scrollable'ın GERÇEK viewport yüksekliğinin katı olarak
  /// ifade edilir; mobil/tablet/desktop için ayrı sabit gerekmeden ölçeklenir.
  final double prefetchViewports;

  @override
  State<HomeViewportSection> createState() => _HomeViewportSectionState();
}

class _HomeViewportSectionState extends State<HomeViewportSection> {
  ScrollPosition? _position;
  bool _userScrolled = false;
  bool _codeTriggered = false;
  bool _dataTriggered = false;
  bool _codeReady = false;
  bool _ready = false;
  bool _failed = false;
  Widget? _child;
  DateTime? _prefetchStart;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _scheduleEvaluate();
    // Fallback: ensure all sections trigger within 3 seconds even if
    // the scroll-proximity logic fails to reach them (e.g., user doesn't
    // scroll and the section is outside the no-scroll threshold).
    _fallbackTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _dataTriggered) return;
      debugPrint('[Phase17] ${widget.debugName} fallback_trigger (3s)');
      _triggerCodeAndData();
    });
  }

  @override
  void didUpdateWidget(covariant HomeViewportSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the mounted section's state, but pass current category/filter props.
    if (_ready) _child = widget.builder();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindScroll();
    _scheduleEvaluate();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _detachScroll();
    super.dispose();
  }

  void _scheduleEvaluate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bindScroll();
      _evaluate();
    });
  }

  void _bindScroll() {
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null || identical(position, _position)) return;
    _position?.removeListener(_onScroll);
    _position = position;
    position.addListener(_onScroll);
  }

  void _detachScroll() {
    _position?.removeListener(_onScroll);
    _position = null;
  }

  void _onScroll() {
    _evaluate();
  }

  void _evaluate() {
    if (_dataTriggered || !mounted) return;
    final position = _position;
    if (position == null ||
        !position.hasPixels ||
        !position.hasViewportDimension) {
      return;
    }
    if (position.pixels > 0) _userScrolled = true;

    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;

    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final revealOffset = viewport.getOffsetToReveal(box, 0).offset;
    final viewportExtent = position.viewportDimension;
    // > 0 ise bölüm hâlâ fold'un altında ve bu kadar piksel uzakta.
    final distanceAhead = revealOffset - (position.pixels + viewportExtent);

    if (distanceAhead <= 0) {
      _triggerCodeAndData();
      return;
    }

    // Code prefetch occurs earlier (1.5 viewports)
    if (!_codeTriggered && distanceAhead <= viewportExtent * 1.5) {
      _triggerCode();
    }

    // P1 section threshold without scroll
    if (!_userScrolled) {
      if (distanceAhead <= viewportExtent * 0.25) {
        _triggerCodeAndData();
      }
      return;
    }

    // Data prefetch occurs later (widget.prefetchViewports, usually 0.75-1.0)
    if (distanceAhead <= viewportExtent * widget.prefetchViewports) {
      _triggerCodeAndData();
    }
  }

  void _triggerCode() {
    if (_codeTriggered) return;
    _codeTriggered = true;
    _prefetchStart = DateTime.now();
    debugPrint('[Phase17] ${widget.debugName} code_prefetch_trigger');
    widget
        .loadLibrary()
        .then((_) {
          if (!mounted) return;
          _codeReady = true;
          final ms = DateTime.now().difference(_prefetchStart!).inMilliseconds;
          debugPrint(
            '[Phase17] ${widget.debugName} loadLibrary_complete in ${ms}ms',
          );
          if (_dataTriggered && !_ready) {
            _mountData();
          }
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('[HomeViewportSection] loadLibrary failed: $error');
          if (!mounted) return;
          setState(() {
            _codeTriggered = false;
            _dataTriggered = false;
            _failed = true;
          });
          _bindScroll();
        });
  }

  void _triggerCodeAndData() {
    if (!_codeTriggered) _triggerCode();
    if (_dataTriggered) return;
    _dataTriggered = true;

    // Trigger sonrası listener'a ihtiyaç yok
    _detachScroll();

    debugPrint('[Phase17] ${widget.debugName} data_prefetch_trigger');
    if (_codeReady) {
      _mountData();
    }
  }

  void _mountData() {
    setState(() {
      _child = widget.builder();
      _ready = true;
      _failed = false;
    });
  }

  void _retry() {
    setState(() => _failed = false);
    _codeTriggered = false;
    _dataTriggered = false;
    _triggerCodeAndData();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready && _child != null) return _child!;
    if (_failed) {
      return SizedBox(
        height: widget.placeholderHeight,
        child: HomeSectionError(message: widget.errorMessage, onRetry: _retry),
      );
    }
    return SizedBox(height: widget.placeholderHeight);
  }
}
