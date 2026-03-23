import 'dart:html' as html;

void setSeoMeta({
  required String title,
  String? description,
  List<String>? keywords,
  String? canonicalPath,
}) {
  final normalizedTitle = title.trim();
  if (normalizedTitle.isNotEmpty) {
    html.document.title = normalizedTitle;
  }

  final normalizedDescription = description?.trim();
  if (normalizedDescription != null && normalizedDescription.isNotEmpty) {
    _metaByName('description').content = normalizedDescription;
    _metaByProperty('og:description').content = normalizedDescription;
    _metaByName('twitter:description').content = normalizedDescription;
  }

  final activeTitle = html.document.title;
  _metaByProperty('og:title').content = activeTitle;
  _metaByName('twitter:title').content = activeTitle;

  final normalizedKeywords = (keywords ?? const <String>[])
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (normalizedKeywords.isNotEmpty) {
    _metaByName('keywords').content = normalizedKeywords.join(', ');
  }

  final canonical = canonicalPath?.trim();
  if (canonical != null && canonical.isNotEmpty) {
    final normalizedPath = canonical.startsWith('/')
        ? canonical
        : '/$canonical';
    final canonicalUrl = '${html.window.location.origin}$normalizedPath';
    _canonicalLink().href = canonicalUrl;
  }
}

html.MetaElement _metaByName(String name) {
  final existing = html.document.querySelector('meta[name="$name"]');
  if (existing is html.MetaElement) return existing;
  final created = html.MetaElement()..name = name;
  html.document.head?.append(created);
  return created;
}

html.MetaElement _metaByProperty(String property) {
  final existing = html.document.querySelector('meta[property="$property"]');
  if (existing is html.MetaElement) return existing;
  final created = html.MetaElement()..setAttribute('property', property);
  html.document.head?.append(created);
  return created;
}

html.LinkElement _canonicalLink() {
  final existing = html.document.querySelector('link[rel="canonical"]');
  if (existing is html.LinkElement) return existing;
  final created = html.LinkElement()..rel = 'canonical';
  html.document.head?.append(created);
  return created;
}
