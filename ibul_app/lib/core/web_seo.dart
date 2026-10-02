import 'web_seo_stub.dart' if (dart.library.html) 'web_seo_web.dart' as impl;

/// Page-level head tags. Share image, `og:type`, robots and JSON-LD are reset
/// to site defaults when omitted so they never leak to the next page.
void setSeoMeta({
  required String title,
  String? description,
  List<String>? keywords,
  String? canonicalPath,
  String? imageUrl,
  String? ogType,
  bool noIndex = false,
  String? jsonLd,
}) {
  impl.setSeoMeta(
    title: title,
    description: description,
    keywords: keywords,
    canonicalPath: canonicalPath,
    imageUrl: imageUrl,
    ogType: ogType,
    noIndex: noIndex,
    jsonLd: jsonLd,
  );
}
