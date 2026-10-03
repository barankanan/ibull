import 'package:flutter/material.dart';

import '../models/blog_image_frame.dart';
import 'blog_theme.dart';

/// Same crop math for the editor preview and the reader.
/// A legacy frame (no crop, no explicit fit) stays in the old 16:9 box.
class BlogFramedImage extends StatelessWidget {
  const BlogFramedImage({
    super.key,
    required this.url,
    this.frame = const BlogImageFrame(),
    this.semanticLabel,
  });

  final String url;
  final BlogImageFrame frame;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final image = BlogImage(url: url, semanticLabel: semanticLabel, fit: BoxFit.fill);
    if (frame.isLegacy) {
      return AspectRatio(
        aspectRatio: BlogTheme.coverAspect,
        child: BlogImage(url: url, semanticLabel: semanticLabel, fit: BoxFit.contain),
      );
    }
    final align = switch (frame.align) {
      'start' => Alignment.centerLeft,
      'end' => Alignment.centerRight,
      _ => Alignment.center,
    };
    final factor = switch (frame.width) {
      'narrow' => 0.5,
      'medium' => 0.75,
      _ => 1.0,
    };
    final framed = frame.isFull || frame.fit == 'contain'
        ? BlogImage(url: url, semanticLabel: semanticLabel, fit: BoxFit.contain)
        : _Cropped(frame: frame, image: image);
    return Align(
      alignment: align,
      child: FractionallySizedBox(widthFactor: factor, child: framed),
    );
  }
}

class _Cropped extends StatelessWidget {
  const _Cropped({required this.frame, required this.image});

  final BlogImageFrame frame;
  final Widget image;

  @override
  Widget build(BuildContext context) {
    final aspect = frame.aspect ?? (frame.w / frame.h);
    return AspectRatio(
      aspectRatio: aspect <= 0 ? 1 : aspect,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth / frame.w;
            final height = constraints.maxHeight / frame.h;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: -frame.x * width,
                  top: -frame.y * height,
                  width: width,
                  height: height,
                  child: image,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
