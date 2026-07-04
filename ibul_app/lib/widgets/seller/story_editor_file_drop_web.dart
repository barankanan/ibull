import 'dart:async';
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

typedef StoryEditorDroppedFile = ({Uint8List bytes, String name});

/// Web: sürükleme sırasında dosya bırakmayı yakalar; normalde tıklamaları engellemez.
class StoryEditorFileDropLayer extends StatefulWidget {
  const StoryEditorFileDropLayer({
    super.key,
    required this.child,
    required this.onFileDropped,
    this.enabled = true,
  });

  final Widget child;
  final ValueChanged<StoryEditorDroppedFile> onFileDropped;
  final bool enabled;

  @override
  State<StoryEditorFileDropLayer> createState() =>
      _StoryEditorFileDropLayerState();
}

class _StoryEditorFileDropLayerState extends State<StoryEditorFileDropLayer> {
  static int _counter = 0;
  late final String _viewType = 'story-editor-drop-${_counter++}';
  bool _dragActive = false;
  StreamSubscription<html.Event>? _windowDragEnterSub;
  StreamSubscription<html.Event>? _windowDragLeaveSub;
  StreamSubscription<html.Event>? _windowDropSub;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final html.DivElement element = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..style.backgroundColor = 'transparent'
        ..style.pointerEvents = 'none';

      element.onDragOver.listen((html.Event event) {
        event.preventDefault();
      });

      element.onDrop.listen((html.Event event) async {
        event.preventDefault();
        if (!widget.enabled) return;
        final html.DataTransfer? transfer =
            (event as dynamic).dataTransfer as html.DataTransfer?;
        final List<html.File>? files = transfer?.files;
        if (files == null || files.isEmpty) return;

        final html.File file = files.first;
        final html.FileReader reader = html.FileReader();
        final Completer<Uint8List> completer = Completer<Uint8List>();
        reader.onLoadEnd.first.then((_) {
          final Object? result = reader.result;
          if (result is ByteBuffer) {
            completer.complete(Uint8List.view(result));
          } else if (result is Uint8List) {
            completer.complete(result);
          } else {
            completer.completeError(StateError('empty'));
          }
        });
        reader.readAsArrayBuffer(file);
        try {
          final Uint8List bytes = await completer.future;
          if (bytes.isEmpty) return;
          widget.onFileDropped((
            bytes: bytes,
            name: file.name.trim().isNotEmpty ? file.name : 'image.jpg',
          ));
        } catch (_) {}
        if (mounted) setState(() => _dragActive = false);
      });

      return element;
    });

    _windowDragEnterSub = html.window.onDragEnter.listen((_) {
      if (!widget.enabled) return;
      if (mounted) setState(() => _dragActive = true);
    });
    _windowDragLeaveSub = html.window.onDragLeave.listen((_) {
      if (mounted) setState(() => _dragActive = false);
    });
    _windowDropSub = html.window.onDrop.listen((_) {
      if (mounted) setState(() => _dragActive = false);
    });
  }

  @override
  void dispose() {
    _windowDragEnterSub?.cancel();
    _windowDragLeaveSub?.cancel();
    _windowDropSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (widget.enabled && _dragActive)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: HtmlElementView(viewType: _viewType),
            ),
          ),
      ],
    );
  }
}
