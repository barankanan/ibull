/// Production-grade image CDN pipeline for the ibul app.
///
/// Architecture:
///   - Raw (original) images are stored once in Cloudflare R2 (or Supabase storage).
///   - Every UI surface requests a *variant* URL instead of the raw URL.
///   - When [AppImageCdn.cdnBaseUrl] is configured, variant URLs are rewritten
///     through Cloudflare's `cdn-cgi/image` transform endpoint so the network
///     delivers exactly the size/quality needed and **never** the original file.
///   - When [AppImageCdn.cdnBaseUrl] is empty (default), the raw URL is returned
///     as-is (passthrough). This is the safe production default.
///
/// Passthrough vs. resize fallback:
///   - Passthrough is always safe and works with any storage backend.
///   - Proper Firebase-side resizing should be implemented via pre-generated
///     image variants (e.g. the Firebase Extensions "Resize Images" extension)
///     or by writing your own Cloud Function that produces fixed-size copies.
///   - The `=w<px>` suffix on Firebase download URLs is an **undocumented**
///     Google backend behaviour. It is NOT part of the Firebase public API,
///     has no SLA, and can be removed without notice. Do NOT rely on it in
///     production. An opt-in experimental flag ([AppImageCdn.enableExperimentalFirebaseResize])
///     is provided for local testing only.
///
/// Usage:
///   // In main() or app startup:
///   AppImageCdn.cdnBaseUrl = 'https://img.yourdomain.com';
///
///   // In widgets:
///   final url = product.imageFor(AppImageVariant.card);
library;

import 'package:flutter/foundation.dart' show kIsWeb;

// ---------------------------------------------------------------------------
// 1. Variant enum — one entry per UI surface
// ---------------------------------------------------------------------------

/// The four canonical image sizes used across the app.
///
/// | Variant | Typical surface                     | W × H    | Quality |
/// |---------|-------------------------------------|----------|---------|
/// | thumb   | Thumbnail strips, mini logos        | 160×160  | 70      |
/// | card    | Product cards (home/search/category)| 420×420  | 75      |
/// | detail  | Product detail main image           | 960×960  | 82      |
/// | hero    | Home banner / hero banners          | 1400×800 | 78      |
enum AppImageVariant { thumb, card, detail, hero }

// ---------------------------------------------------------------------------
// 2. Spec per variant
// ---------------------------------------------------------------------------

class _ImageSpec {
  final int width;
  final int height;
  final int quality;

  const _ImageSpec({
    required this.width,
    required this.height,
    required this.quality,
  });
}

const _specs = <AppImageVariant, _ImageSpec>{
  AppImageVariant.thumb: _ImageSpec(width: 160, height: 160, quality: 70),
  AppImageVariant.card: _ImageSpec(width: 420, height: 420, quality: 75),
  AppImageVariant.detail: _ImageSpec(width: 960, height: 960, quality: 82),
  AppImageVariant.hero: _ImageSpec(width: 1400, height: 800, quality: 78),
};

// ---------------------------------------------------------------------------
// 3. Central CDN configuration & URL builder
// ---------------------------------------------------------------------------

/// Central configuration for the image CDN.
///
/// Set [cdnBaseUrl] once during app startup to enable Cloudflare transform URLs.
/// Leave it empty to use raw URLs (safe default — no Cloudflare required).
///
/// Example Cloudflare setup:
///   - R2 bucket bound to a Worker or behind a custom domain
///   - Zone with "Image Resizing" / "Transform URL" enabled
///   - [cdnBaseUrl] = 'https://img.yourdomain.com'
///
/// The resulting URL format is:
///   `https://img.yourdomain.com/cdn-cgi/image/width=420,height=420,quality=75,format=auto/{sourceUrl}`
class AppImageCdn {
  AppImageCdn._();

  /// Base URL of the Cloudflare zone that serves your images.
  ///
  /// Leave empty to disable CDN transforms (passthrough mode).
  /// Must NOT end with a trailing slash.
  ///
  /// Example: `'https://img.yourdomain.com'`
  static String cdnBaseUrl = '';

  /// **EXPERIMENTAL — disabled by default. Do NOT enable in production.**
  ///
  /// When `true` and [cdnBaseUrl] is empty, [buildUrl] will attempt to append
  /// a `=w<px>` suffix to Firebase Storage download URLs in the hope that
  /// Google's backend honours it and returns a smaller image.
  ///
  /// ⚠️  This relies on **undocumented** Firebase behaviour with no public API
  /// guarantee or SLA. Google can remove this at any time and the app will
  /// silently receive broken image URLs.
  ///
  /// The correct way to serve resized images from Firebase Storage is to use
  /// pre-generated variants produced by the "Resize Images" Firebase Extension
  /// (https://extensions.dev/extensions/firebase/storage-resize-images) or a
  /// custom Cloud Function that writes fixed-size copies on upload.
  ///
  /// Set to `true` only for local performance experiments.
  static bool enableExperimentalFirebaseResize = false;

  /// Appends `=w{width}` to a Firebase Storage download URL.
  ///
  /// ⚠️  Undocumented behaviour — for experimental use only.
  /// Strips any pre-existing `=w\d+` suffix to avoid double-appending.
  static String _experimentalFirebaseResizeUrl(
    String sourceUrl,
    AppImageVariant variant,
  ) {
    if (!sourceUrl.contains('firebasestorage.googleapis.com')) {
      return sourceUrl;
    }

    final spec = _specs[variant]!;
    final width =
        (!kIsWeb && variant == AppImageVariant.hero) ? 1200 : spec.width;

    // Strip any existing =w… suffix before appending the new one.
    final stripped = sourceUrl.replaceAll(RegExp(r'=w\d+$'), '');
    return '$stripped=w$width';
  }

  /// Builds a CDN-transformed URL for [sourceUrl] at the given [variant].
  ///
  /// Behaviour by configuration:
  ///
  /// | [cdnBaseUrl] | [enableExperimentalFirebaseResize] | Result                          |
  /// |---|---|---|
  /// | set          | any                               | Cloudflare cdn-cgi/image URL    |
  /// | empty        | `false` (default / safe)          | Original URL unchanged          |
  /// | empty        | `true`  (experimental)            | Firebase `=w<px>` suffix if URL matches |
  ///
  /// Passthrough (empty [cdnBaseUrl], flag off) is the **safe production default**.
  /// It works with any storage backend and never produces broken URLs.
  static String buildUrl(String sourceUrl, AppImageVariant variant) {
    if (sourceUrl.isEmpty || !sourceUrl.startsWith('http')) {
      return sourceUrl;
    }

    final base = cdnBaseUrl.trim();
    if (base.isEmpty) {
      // No CDN configured — passthrough is the safe default.
      // Experimental Firebase resize can be opted-in for local testing only;
      // see [enableExperimentalFirebaseResize] for caveats.
      if (enableExperimentalFirebaseResize) {
        return _experimentalFirebaseResizeUrl(sourceUrl, variant);
      }
      return sourceUrl;
    }

    final spec = _specs[variant]!;

    // On web, hero images may exceed the standard decode cap so we allow the
    // full spec; on mobile we clamp hero width to 1200 px to match the
    // OptimizedImage.webMaxDecodeDimension boundary.
    final width =
        (!kIsWeb && variant == AppImageVariant.hero) ? 1200 : spec.width;
    final height =
        (!kIsWeb && variant == AppImageVariant.hero) ? 680 : spec.height;

    return '$base/cdn-cgi/image/'
        'width=$width,height=$height,quality=${spec.quality},format=auto/'
        '$sourceUrl';
  }

  /// Returns the decode cache size (in physical pixels) that [OptimizedImage]
  /// should use when displaying a [variant]. This keeps `ResizeImage` and the
  /// CDN transform in agreement so Flutter never over-decodes the received JPEG.
  static ({int width, int height}) cacheSize(AppImageVariant variant) {
    final spec = _specs[variant]!;
    return (width: spec.width, height: spec.height);
  }
}

// ---------------------------------------------------------------------------
// 4. Convenience extension on the primary image list (raw URL list)
// ---------------------------------------------------------------------------

/// Extension that lets any widget call `product.imageFor(AppImageVariant.card)`
/// without knowing about raw URL resolution or CDN logic.
extension ProductImageX on List<String> {
  /// Returns the CDN-transformed URL for the first image in this list.
  ///
  /// If the list is empty or the first URL is blank, returns `''`.
  String cdnUrl(AppImageVariant variant, {String? fallback}) {
    final raw =
        isNotEmpty ? first.trim() : (fallback?.trim() ?? '');
    if (raw.isEmpty) return '';
    return AppImageCdn.buildUrl(raw, variant);
  }
}
