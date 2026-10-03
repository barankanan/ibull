/// Crop and placement for one image. Fractions are of the source image.
/// Missing crop means the whole image. [fit] null keeps the legacy 16:9 box.
class BlogImageFrame {
  const BlogImageFrame({
    this.x = 0,
    this.y = 0,
    this.w = 1,
    this.h = 1,
    this.aspect,
    this.fit,
    this.align = 'center',
    this.width = 'content',
    this.originalUrl = '',
  });

  final double x;
  final double y;
  final double w;
  final double h;

  /// Pixel aspect of the crop window, width / height. Null until measured.
  final double? aspect;
  final String? fit;
  final String align;
  final String width;
  final String originalUrl;

  bool get isFull =>
      x <= 0.001 && y <= 0.001 && w >= 0.999 && h >= 0.999;

  bool get isLegacy => isFull && fit == null && align == 'center' && width == 'content';

  BlogImageFrame copyWith({
    double? x,
    double? y,
    double? w,
    double? h,
    double? aspect,
    String? fit,
    String? align,
    String? width,
    String? originalUrl,
    bool clearAspect = false,
    bool clearFit = false,
  }) => BlogImageFrame(
    x: x ?? this.x,
    y: y ?? this.y,
    w: w ?? this.w,
    h: h ?? this.h,
    aspect: clearAspect ? null : aspect ?? this.aspect,
    fit: clearFit ? null : fit ?? this.fit,
    align: align ?? this.align,
    width: width ?? this.width,
    originalUrl: originalUrl ?? this.originalUrl,
  );

  static const full = BlogImageFrame();

  factory BlogImageFrame.fromJson(Map raw) {
    final crop = raw['crop'];
    final map = crop is Map ? crop : const {};
    double n(Object? value, double fallback) {
      final parsed = value is num ? value.toDouble() : double.tryParse('$value');
      if (parsed == null || parsed.isNaN) return fallback;
      return parsed.clamp(0, 1).toDouble();
    }

    final width = n(map['w'], 1);
    final height = n(map['h'], 1);
    return BlogImageFrame(
      x: n(map['x'], 0),
      y: n(map['y'], 0),
      w: width <= 0 ? 1 : width,
      h: height <= 0 ? 1 : height,
      aspect: map['aspect'] is num ? (map['aspect'] as num).toDouble() : null,
      fit: raw['fit'] == 'cover' || raw['fit'] == 'contain' ? raw['fit'] as String : null,
      align: const {'start', 'center', 'end'}.contains(raw['align'])
          ? raw['align'] as String
          : 'center',
      width: const {'content', 'medium', 'narrow'}.contains(raw['width'])
          ? raw['width'] as String
          : 'content',
      originalUrl: raw['original_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (!isFull) {
      json['crop'] = {
        'x': _round(x),
        'y': _round(y),
        'w': _round(w),
        'h': _round(h),
        if (aspect != null && aspect! > 0) 'aspect': _round(aspect!),
      };
    }
    if (fit != null) json['fit'] = fit;
    if (align != 'center') json['align'] = align;
    if (width != 'content') json['width'] = width;
    if (originalUrl.trim().isNotEmpty) json['original_url'] = originalUrl.trim();
    return json;
  }

  static double _round(double value) => (value * 10000).round() / 10000;

  /// Locks [w]/[h] to [ratio] (pixel width / height) inside the image.
  BlogImageFrame withRatio(double? ratio, {required double imageAspect}) {
    if (ratio == null) return this;
    final target = ratio <= 0 ? imageAspect : ratio;
    if (target <= 0) return this;
    var nextW = w;
    var nextH = nextW * imageAspect / target;
    if (nextH > 1) {
      nextH = 1;
      nextW = target / imageAspect;
    }
    if (nextW > 1) {
      nextW = 1;
      nextH = imageAspect / target;
    }
    return copyWith(
      x: x.clamp(0, 1 - nextW).toDouble(),
      y: y.clamp(0, 1 - nextH).toDouble(),
      w: nextW.clamp(0.05, 1).toDouble(),
      h: nextH.clamp(0.05, 1).toDouble(),
      aspect: (nextW * imageAspect) / nextH,
    );
  }
}
