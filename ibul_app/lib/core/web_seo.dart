import 'web_seo_stub.dart' if (dart.library.html) 'web_seo_web.dart' as impl;

void setSeoMeta({
  required String title,
  String? description,
  List<String>? keywords,
  String? canonicalPath,
}) {
  impl.setSeoMeta(
    title: title,
    description: description,
    keywords: keywords,
    canonicalPath: canonicalPath,
  );
}
