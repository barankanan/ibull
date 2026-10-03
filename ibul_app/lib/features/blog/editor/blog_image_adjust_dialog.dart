import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/blog_image_frame.dart';
import '../widgets/blog_theme.dart';

/// One crop surface for block images and the cover. The source file is not
/// replaced; the result is reversible crop metadata on this post only.
Future<BlogImageFrame?> showBlogImageAdjustDialog({
  required BuildContext context,
  required String url,
  required BlogImageFrame initial,
}) {
  return showDialog<BlogImageFrame>(
    context: context,
    builder: (context) => _AdjustDialog(url: url, initial: initial),
  );
}

class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({required this.url, required this.initial});

  final String url;
  final BlogImageFrame initial;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  late BlogImageFrame _frame = widget.initial.isFull
      ? widget.initial.copyWith(x: 0.1, y: 0.1, w: 0.8, h: 0.8)
      : widget.initial;
  double? _imageAspect;
  String _ratio = 'free';
  bool _fill = true;

  @override
  void initState() {
    super.initState();
    _fill = widget.initial.fit != 'contain';
    final provider = NetworkImage(widget.url);
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      final aspect = info.image.width / info.image.height;
      if (mounted) setState(() => _imageAspect = aspect);
      stream.removeListener(listener);
    }, onError: (_, _) {});
    stream.addListener(listener);
  }

  void _setRatio(String ratio) {
    final imageAspect = _imageAspect ?? 1;
    final target = switch (ratio) {
      'original' => imageAspect,
      '1' => 1.0,
      '4/3' => 4 / 3,
      '16/9' => 16 / 9,
      _ => null,
    };
    setState(() {
      _ratio = ratio;
      _frame = target == null
          ? _frame
          : _frame.withRatio(target, imageAspect: imageAspect);
    });
  }

  BlogImageFrame _result({bool reset = false}) {
    if (reset) {
      return BlogImageFrame(originalUrl: widget.initial.originalUrl);
    }
    final imageAspect = _imageAspect ?? 1;
    final aspect = _frame.h <= 0 ? 1.0 : (_frame.w * imageAspect) / _frame.h;
    return _frame.copyWith(
      aspect: aspect,
      fit: _fill ? 'cover' : 'contain',
      originalUrl: widget.initial.originalUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Görseli düzenle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final entry in const [
                    ('free', 'Serbest'),
                    ('original', 'Orijinal'),
                    ('1', '1:1'),
                    ('4/3', '4:3'),
                    ('16/9', '16:9'),
                  ])
                    ChoiceChip(
                      label: Text(entry.$2),
                      selected: _ratio == entry.$1,
                      onSelected: (_) => _setRatio(entry.$1),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 360,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: _CropSurface(
                    url: widget.url,
                    imageAspect: _imageAspect,
                    frame: _frame,
                    onChanged: (frame) => setState(() => _frame = frame),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Tamamını göster')),
                  ButtonSegment(value: true, label: Text('Alanı doldur')),
                ],
                selected: {_fill},
                onSelectionChanged: (value) => setState(() => _fill = value.first),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, _result(reset: true)),
                    child: const Text('Orijinale dön'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('İptal'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: BlogTheme.accent),
                    onPressed: () => Navigator.pop(context, _result()),
                    child: const Text('Uygula'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CropSurface extends StatelessWidget {
  const _CropSurface({
    required this.url,
    required this.imageAspect,
    required this.frame,
    required this.onChanged,
  });

  final String url;
  final double? imageAspect;
  final BlogImageFrame frame;
  final ValueChanged<BlogImageFrame> onChanged;

  Rect _imageBox(Size box) {
    final aspect = imageAspect;
    if (aspect == null || aspect <= 0) return Offset.zero & box;
    final boxAspect = box.width / box.height;
    if (aspect > boxAspect) {
      final height = box.width / aspect;
      return Rect.fromLTWH(0, (box.height - height) / 2, box.width, height);
    }
    final width = box.height * aspect;
    return Rect.fromLTWH((box.width - width) / 2, 0, width, box.height);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        final image = _imageBox(box);
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(url, fit: BoxFit.contain),
            Positioned(
              left: image.left + frame.x * image.width,
              top: image.top + frame.y * image.height,
              width: math.max(24, frame.w * image.width),
              height: math.max(24, frame.h * image.height),
              child: GestureDetector(
                onPanUpdate: (details) {
                  onChanged(frame.copyWith(
                    x: (frame.x + details.delta.dx / image.width).clamp(0, 1 - frame.w).toDouble(),
                    y: (frame.y + details.delta.dy / image.height).clamp(0, 1 - frame.h).toDouble(),
                  ));
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    color: const Color(0x22000000),
                  ),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        onChanged(frame.copyWith(
                          w: (frame.w + details.delta.dx / image.width).clamp(0.05, 1 - frame.x).toDouble(),
                          h: (frame.h + details.delta.dy / image.height).clamp(0.05, 1 - frame.h).toDouble(),
                        ));
                      },
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: ColoredBox(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
