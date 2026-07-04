import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 1:1 ürün görseli kırpıcı — cropperx tabanlı, sığdır/doldur/ortala destekli.
class ProductSquareCropper extends StatefulWidget {
  const ProductSquareCropper({
    super.key,
    required this.cropperKey,
    required this.image,
    this.zoomScale = 4,
    this.backgroundColor = const Color(0xFFF3F4F6),
    this.overlayColor = const Color(0x8A000000),
    this.onReady,
  });

  final GlobalKey cropperKey;
  final Image image;
  final double zoomScale;
  final Color backgroundColor;
  final Color overlayColor;
  final VoidCallback? onReady;

  static Future<Uint8List?> capture({
    required GlobalKey cropperKey,
    double pixelRatio = 3,
  }) async {
    final renderObject = cropperKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  @override
  State<ProductSquareCropper> createState() => ProductSquareCropperState();
}

class ProductSquareCropperState extends State<ProductSquareCropper> {
  final TransformationController _transformationController =
      TransformationController();
  final ImageConfiguration _imageConfiguration = const ImageConfiguration();

  bool _hasImageUpdated = true;
  bool _shouldSetInitialScale = false;
  bool _readyNotified = false;
  Size _lastParentSize = Size.zero;
  Size _lastChildSize = Size.zero;

  late final ImageStreamListener _imageStreamListener = ImageStreamListener(
    (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _shouldSetInitialScale = true);
      });
    },
  );

  @override
  void didUpdateWidget(covariant ProductSquareCropper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _hasImageUpdated = oldWidget.image.image != widget.image.image;
    if (_hasImageUpdated) {
      _shouldSetInitialScale = true;
      _readyNotified = false;
    }
  }

  void fitInside() => _applyScaleMode(_CropFitMode.contain);

  void fillCrop() => _applyScaleMode(_CropFitMode.cover);

  void centerImage() {
    if (_lastParentSize == Size.zero || _lastChildSize == Size.zero) {
      fillCrop();
      return;
    }
    final scale = _transformationController.value.getMaxScaleOnAxis();
    _applyMatrix(
      parentSize: _lastParentSize,
      childSize: _lastChildSize,
      scale: scale,
    );
  }

  void _applyScaleMode(_CropFitMode mode) {
    if (_lastParentSize == Size.zero || _lastChildSize == Size.zero) {
      _shouldSetInitialScale = true;
      return;
    }
    final scale = switch (mode) {
      _CropFitMode.cover => _coverRatio(_lastParentSize, _lastChildSize),
      _CropFitMode.contain => _containRatio(_lastParentSize, _lastChildSize),
    };
    _applyMatrix(
      parentSize: _lastParentSize,
      childSize: _lastChildSize,
      scale: scale,
    );
  }

  double _coverRatio(Size outside, Size inside) {
    return outside.width / outside.height > inside.width / inside.height
        ? outside.width / inside.width
        : outside.height / inside.height;
  }

  double _containRatio(Size outside, Size inside) {
    return outside.width / outside.height > inside.width / inside.height
        ? outside.height / inside.height
        : outside.width / inside.width;
  }

  void _applyMatrix({
    required Size parentSize,
    required Size childSize,
    required double scale,
  }) {
    final value = Matrix4.identity() * scale;
    value.translate(
      (parentSize.width / scale - childSize.width) / 2,
      (parentSize.height / scale - childSize.height) / 2,
      0,
    );
    _transformationController.value = value;
  }

  void _setInitialScale(BuildContext context, Size parentSize) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final renderBox = context.findRenderObject() as RenderBox?;
      final childSize = renderBox?.size ?? Size.zero;
      if (childSize == Size.zero) return;

      _lastParentSize = parentSize;
      _lastChildSize = childSize;
      _applyScaleMode(_CropFitMode.cover);
      _shouldSetInitialScale = false;
      if (!_readyNotified) {
        _readyNotified = true;
        widget.onReady?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ColoredBox(
        color: widget.backgroundColor,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              key: widget.cropperKey,
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (_, constraint) {
                    return InteractiveViewer(
                      clipBehavior: Clip.none,
                      transformationController: _transformationController,
                      constrained: false,
                      minScale: 0.1,
                      maxScale: widget.zoomScale,
                      child: Builder(
                        builder: (context) {
                          final imageStream = widget.image.image.resolve(
                            _imageConfiguration,
                          );
                          if (_hasImageUpdated && _shouldSetInitialScale) {
                            imageStream.removeListener(_imageStreamListener);
                            _setInitialScale(context, constraint.biggest);
                          }
                          if (_hasImageUpdated && !_shouldSetInitialScale) {
                            imageStream.addListener(_imageStreamListener);
                          }
                          return widget.image;
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned.fill(
              child: ClipPath(
                clipper: _SquareOverlayClipper(),
                child: ColoredBox(color: widget.overlayColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
}

enum _CropFitMode { cover, contain }

class _SquareOverlayClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final side = min(size.width, size.height);
    final opening = Path()
      ..addRect(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: side,
          height: side,
        ),
      );
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      opening,
    );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
