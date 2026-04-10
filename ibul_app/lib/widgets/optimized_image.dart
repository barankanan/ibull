import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/app_motion.dart';
import '../core/build_profile.dart';

enum OptimizedImagePriority { high, lazy }

class ResolvedImageCacheSize {
  const ResolvedImageCacheSize({
    required this.cacheWidth,
    required this.cacheHeight,
  });

  final int cacheWidth;
  final int cacheHeight;
}

/// Ağ ve asset görselleri için önbellek + boyut optimizasyonu.
/// - URL: CachedNetworkImage (diskte önbellek) + cacheWidth/cacheHeight (bellek/decode azaltır).
/// - Asset: Image.asset + cacheWidth/cacheHeight.
/// Görsel depolama ve uygulama hızı için liste/kartlarda bu widget kullanılmalı.
class OptimizedImage extends StatefulWidget {
  const OptimizedImage({
    super.key,
    required this.imageUrlOrPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
    this.cacheHeight,
    this.color,
    this.colorBlendMode,
    this.filterQuality = FilterQuality.low,
    this.gaplessPlayback = false,
    this.matchTextDirection = false,
    this.placeholder,
    this.errorBuilder,
    this.errorWidget,
    this.priority = OptimizedImagePriority.high,
    this.onFirstFrameReady,
  });

  final String imageUrlOrPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  /// Decode/cache için max genişlik (piksel). Liste kartları için 200–400 yeterli.
  final int? cacheWidth;

  /// Decode/cache için max yükseklik (piksel).
  final int? cacheHeight;
  final Color? color;
  final BlendMode? colorBlendMode;
  final FilterQuality filterQuality;
  final bool gaplessPlayback;
  final bool matchTextDirection;
  final Widget? placeholder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget? errorWidget;
  final OptimizedImagePriority priority;

  /// Called once when the first decoded frame has been committed to the
  /// Flutter layer. Use this to set a [ValueNotifier<bool>] that drives
  /// a [StaggeredReveal.imageReadySignal] so the slide animation begins
  /// only after the GPU texture upload is complete.
  final VoidCallback? onFirstFrameReady;

  static const int mobileMaxDecodeDimension = 800;
  static const int webMaxDecodeDimension = 1200;

  static int maxDecodeDimension() {
    return kIsWeb ? webMaxDecodeDimension : mobileMaxDecodeDimension;
  }

  static ResolvedImageCacheSize resolveCacheSize({
    required BuildContext context,
    BoxConstraints? constraints,
    double? width,
    double? height,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    final maxDimension = maxDecodeDimension();
    if (cacheWidth != null && cacheHeight != null) {
      return ResolvedImageCacheSize(
        cacheWidth: cacheWidth.clamp(1, maxDimension),
        cacheHeight: cacheHeight.clamp(1, maxDimension),
      );
    }

    final mediaSize = MediaQuery.maybeSizeOf(context);
    final devicePixelRatio =
        MediaQuery.maybeDevicePixelRatioOf(context) ??
        View.maybeOf(context)?.devicePixelRatio ??
        1.0;

    int resolveDimension({
      required double? explicitLogicalSize,
      required double? constrainedLogicalSize,
      required double fallbackLogicalSize,
      required int? explicitCacheSize,
    }) {
      if (explicitCacheSize != null) {
        return explicitCacheSize.clamp(1, maxDimension);
      }

      final logicalSize = _pickFinitePositive(
        explicitLogicalSize,
        constrainedLogicalSize,
        fallbackLogicalSize,
        1,
      );
      final physicalSize = (logicalSize * devicePixelRatio).round();
      return physicalSize.clamp(1, maxDimension);
    }

    final resolvedWidth = resolveDimension(
      explicitLogicalSize: width,
      constrainedLogicalSize: constraints?.maxWidth,
      fallbackLogicalSize: mediaSize?.width ?? 1,
      explicitCacheSize: cacheWidth,
    );
    final resolvedHeight = resolveDimension(
      explicitLogicalSize: height,
      constrainedLogicalSize: constraints?.maxHeight,
      fallbackLogicalSize: mediaSize?.height ?? mediaSize?.width ?? 1,
      explicitCacheSize: cacheHeight,
    );

    return ResolvedImageCacheSize(
      cacheWidth: resolvedWidth,
      cacheHeight: resolvedHeight,
    );
  }

  static ImageProvider<Object>? buildProvider({
    required String imageUrlOrPath,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    if (imageUrlOrPath.isEmpty) {
      return null;
    }

    if (imageUrlOrPath.startsWith('http')) {
      final baseProvider = CachedNetworkImageProvider(
        imageUrlOrPath,
        maxWidth: cacheWidth,
        maxHeight: cacheHeight,
      );
      return ResizeImage.resizeIfNeeded(
        cacheWidth,
        cacheHeight,
        baseProvider,
      );
    }

    return ResizeImage.resizeIfNeeded(
      cacheWidth,
      cacheHeight,
      AssetImage(imageUrlOrPath),
    );
  }

  static Future<void> prefetch({
    required BuildContext context,
    required String imageUrlOrPath,
    double? width,
    double? height,
    int? cacheWidth,
    int? cacheHeight,
  }) async {
    final provider = buildContextAwareProvider(
      context: context,
      imageUrlOrPath: imageUrlOrPath,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
    if (provider == null) {
      return;
    }

    try {
      await precacheImage(provider, context);
    } catch (_) {
      // Prefetch is opportunistic; visible image widgets still handle fallback.
    }
  }

  static ImageProvider<Object>? buildContextAwareProvider({
    required BuildContext context,
    required String imageUrlOrPath,
    BoxConstraints? constraints,
    double? width,
    double? height,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    final resolvedSize = resolveCacheSize(
      context: context,
      constraints: constraints,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
    return buildProvider(
      imageUrlOrPath: imageUrlOrPath,
      cacheWidth: resolvedSize.cacheWidth,
      cacheHeight: resolvedSize.cacheHeight,
    );
  }

  static double _pickFinitePositive(double? first, double? second, double third, double fallback) {
    for (final value in [first, second, third]) {
      if (value != null && value.isFinite && value > 0) {
        return value;
      }
    }
    return fallback;
  }

  @override
  State<OptimizedImage> createState() => _OptimizedImageState();
}

class _OptimizedImageState extends State<OptimizedImage> {
  bool _hasLoadedFrame = false;
  bool _hasError = false;

  // Tracks the last URL+dimensions combination that was eagerly precached so
  // we don't fire redundant precacheImage calls for the same provider.
  String? _lastPrecachedKey;

  /// Triggers decode for this image before layout resolves, provided explicit
  /// cache dimensions are given and priority is high. When the image is already
  /// in the Flutter ImageCache the subsequent Image widget load is synchronous
  /// (wasSynchronouslyLoaded == true), which eliminates the raster-thread spike.
  void _maybePrecacheEarly() {
    if (widget.priority != OptimizedImagePriority.high) return;
    if (widget.imageUrlOrPath.isEmpty) return;
    // Can only pre-resolve without layout when both dimensions are explicit.
    final w = widget.cacheWidth;
    final h = widget.cacheHeight;
    if (w == null || h == null) return;

    final key = '${widget.imageUrlOrPath}|$w|$h';
    if (_lastPrecachedKey == key) return;
    _lastPrecachedKey = key;

    final provider = OptimizedImage.buildProvider(
      imageUrlOrPath: widget.imageUrlOrPath,
      cacheWidth: w,
      cacheHeight: h,
    );
    if (provider == null) return;
    // Fire-and-forget: errors are non-fatal; the Image widget retries.
    precacheImage(provider, context).ignore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePrecacheEarly();
  }

  @override
  void didUpdateWidget(covariant OptimizedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrlOrPath != widget.imageUrlOrPath ||
        oldWidget.cacheWidth != widget.cacheWidth ||
        oldWidget.cacheHeight != widget.cacheHeight ||
        oldWidget.priority != widget.priority) {
      _hasLoadedFrame = false;
      _hasError = false;
      _maybePrecacheEarly();
    }
  }

  void _markFrameReady() {
    if (_hasLoadedFrame || !mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasLoadedFrame) {
        return;
      }
      setState(() {
        _hasLoadedFrame = true;
      });
      widget.onFirstFrameReady?.call();
    });
  }

  void _markError() {
    if (_hasError || !mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasError) {
        return;
      }
      setState(() {
        _hasError = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return BuildProfileCollector.measure('OptimizedImage', () {
      if (widget.imageUrlOrPath.isEmpty) {
        return _error();
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final provider = OptimizedImage.buildContextAwareProvider(
            context: context,
            imageUrlOrPath: widget.imageUrlOrPath,
            constraints: constraints,
            width: widget.width,
            height: widget.height,
            cacheWidth: widget.cacheWidth,
            cacheHeight: widget.cacheHeight,
          );

          if (provider == null) {
            return _error();
          }

          final image = Image(
            image: provider,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            alignment: widget.alignment,
            color: widget.color,
            colorBlendMode: widget.colorBlendMode,
            filterQuality: widget.filterQuality,
            gaplessPlayback: widget.gaplessPlayback,
            matchTextDirection: widget.matchTextDirection,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                _markFrameReady();
              }

              return AnimatedOpacity(
                opacity:
                    _hasLoadedFrame || wasSynchronouslyLoaded || frame != null
                    ? 1
                    : 0,
                duration: AppMotion.imageFadeInDuration,
                curve: AppMotion.fadeInCurve,
                child: child,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              _markError();
              return widget.errorBuilder?.call(context, error, stackTrace) ??
                  widget.errorWidget ??
                  _error();
            },
          );

          return RepaintBoundary(
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!_hasLoadedFrame && !_hasError)
                    widget.placeholder ?? _defaultPlaceholder(),
                  image,
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _error() {
    return Container(
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported,
        color: Colors.grey[400],
        size: (widget.cacheHeight ?? 48) / 2,
      ),
    );
  }

  Widget _defaultPlaceholder() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: const Color(0xFF94A3B8),
          size: (widget.cacheHeight ?? 56).clamp(24, 64).toDouble() / 2,
        ),
      ),
    );
  }
}
