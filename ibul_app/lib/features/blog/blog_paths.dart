/// Public blog URLs. Reserved first segments must match `blog_normalize_payload`.
abstract final class BlogPaths {
  static const root = '/blog';
  static const studio = '/blog/yazar';
  static const previewRoot = '/blog/onizleme';
  static const searchParam = 'q';
  static const categoryParam = 'kategori';

  static String post(String slug) => '$root/${Uri.encodeComponent(slug)}';

  static String preview(String postId) =>
      '$previewRoot/${Uri.encodeComponent(postId)}';

  static String home({String? search, String? categorySlug}) {
    final query = <String, String>{
      if (search != null && search.trim().isNotEmpty)
        searchParam: search.trim(),
      if (categorySlug != null && categorySlug.isNotEmpty)
        categoryParam: categorySlug,
    };
    return Uri(path: root, queryParameters: query.isEmpty ? null : query)
        .toString();
  }

  /// Mirrors SQL `blog_slugify`: Turkish letters are folded before lowercasing.
  static String slugify(String raw) {
    const from = 'İIĞÜŞÖÇığüşöçÂÎÛâîû';
    const to = 'iigusocigusocaiuaiu';
    final folded = StringBuffer();
    for (final char in raw.split('')) {
      final index = from.indexOf(char);
      folded.write(index >= 0 ? to[index] : char);
    }
    return folded
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  static bool isBlogPath(String path) =>
      path == root || path.startsWith('$root/');

  /// `/blog/<slug>` → slug; null for root, studio, preview and deeper paths.
  static String? slugFrom(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length != 2 || segments.first != 'blog') return null;
    final slug = Uri.decodeComponent(segments[1]);
    if (slug == 'yazar' || slug == 'onizleme') return null;
    return slug;
  }

  static String? previewIdFrom(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length != 3 ||
        segments[0] != 'blog' ||
        segments[1] != 'onizleme') {
      return null;
    }
    return Uri.decodeComponent(segments[2]);
  }
}
