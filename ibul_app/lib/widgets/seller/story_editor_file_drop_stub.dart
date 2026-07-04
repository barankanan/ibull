import 'dart:typed_data';

import 'package:flutter/widgets.dart';

typedef StoryEditorDroppedFile = ({Uint8List bytes, String name});

/// Mobil/masaüstü: sürükle-bırak katmanı yok, child doğrudan gösterilir.
class StoryEditorFileDropLayer extends StatelessWidget {
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
  Widget build(BuildContext context) => child;
}
