import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../blog_paths.dart';
import 'blog_content.dart';
import 'blog_models.dart';

/// Mutable editor state. [toPayload] is the `blog_save_post` contract.
class BlogPostDraft {
  BlogPostDraft({
    this.id,
    this.title = '',
    this.subtitle = '',
    this.slug = '',
    this.excerpt = '',
    this.coverUrl = '',
    this.coverAlt = '',
    this.categoryId,
    List<String>? tagIds,
    this.authorId,
    this.isFeatured = false,
    this.publishedAt,
    this.seoTitle = '',
    this.metaDescription = '',
    BlogDocument? document,
    this.status = BlogPostStatus.draft,
    this.revisionStatus,
    this.liveSlug,
  }) : tagIds = tagIds ?? <String>[],
       document = document ?? BlogDocument();

  String? id;
  String title;
  String subtitle;
  String slug;
  String excerpt;
  String coverUrl;
  String coverAlt;
  String? categoryId;
  List<String> tagIds;
  String? authorId;
  bool isFeatured;
  DateTime? publishedAt;
  String seoTitle;
  String metaDescription;
  BlogDocument document;
  BlogPostStatus status;
  BlogPostStatus? revisionStatus;
  String? liveSlug;

  factory BlogPostDraft.fromPost(BlogPost post) => BlogPostDraft(
    id: post.id,
    title: post.title,
    subtitle: post.subtitle ?? '',
    slug: post.slug,
    excerpt: post.excerpt ?? '',
    coverUrl: post.coverUrl ?? '',
    coverAlt: post.coverAlt ?? '',
    categoryId: post.categoryId,
    tagIds: List.of(post.tagIds),
    authorId: post.authorId,
    isFeatured: post.isFeatured,
    publishedAt: post.publishedAt,
    seoTitle: post.seoTitle ?? '',
    metaDescription: post.metaDescription ?? '',
    document: BlogDocument.fromJson(post.document.toJson()),
    status: post.status ?? BlogPostStatus.draft,
    revisionStatus: post.revisionStatus,
    liveSlug: post.liveSlug,
  );

  String get effectiveSlug {
    final slugValue = BlogPaths.slugify(slug.trim().isEmpty ? title : slug);
    return slugValue.length > 120
        ? slugValue.substring(0, 120).replaceAll(RegExp(r'-+$'), '')
        : slugValue;
  }

  Map<String, dynamic> toPayload() => {
    'title': title.trim(),
    'subtitle': subtitle.trim(),
    'slug': effectiveSlug,
    'excerpt': excerpt.trim(),
    'cover_url': coverUrl.trim(),
    'cover_alt': coverAlt.trim(),
    'category_id': categoryId,
    'tag_ids': tagIds,
    'author_id': authorId,
    'is_featured': isFeatured,
    'published_at': publishedAt?.toUtc().toIso8601String(),
    'seo_title': seoTitle.trim(),
    'meta_description': metaDescription.trim(),
    'content': document.toJson(),
  };

  /// Stable fingerprint used for the unsaved-changes check.
  String get fingerprint => jsonEncode(toPayload());

  /// Draft save rejects only unsafe URLs. [publishing] also requires a title,
  /// a real slug, a byline and finished blocks. The signed-in user is not the byline.
  String? validate({bool publishing = false}) {
    final urlProblem = BlogUrlPolicy.problem(coverUrl);
    if (urlProblem != null) return urlProblem;
    if (!publishing) return document.validate();
    if (title.trim().isEmpty) return 'Yayınlamak için başlık girin.';
    if (effectiveSlug.isEmpty || effectiveSlug.startsWith('taslak-')) {
      return 'Yayınlamak için bir URL adresi (slug) girin.';
    }
    if (authorId == null || authorId!.trim().isEmpty) {
      return 'Yayınlamak için bir yazar seçin.';
    }
    if (coverUrl.trim().isNotEmpty && coverAlt.trim().isEmpty) {
      return 'Kapak görseli için alternatif metin girin.';
    }
    return document.validate(publishing: true);
  }

  /// In-memory article for the preview, rendered by the reader widget.
  BlogPost toPreviewPost({
    BlogCategory? category,
    BlogAuthor? author,
    List<BlogTag> tags = const [],
  }) => BlogPost(
    id: id ?? 'preview',
    slug: effectiveSlug,
    title: title.trim().isEmpty ? 'Başlıksız yazı' : title.trim(),
    document: document,
    subtitle: subtitle.trim().isEmpty ? null : subtitle.trim(),
    excerpt: excerpt.trim().isEmpty ? null : excerpt.trim(),
    coverUrl: coverUrl.trim().isEmpty ? null : coverUrl.trim(),
    coverAlt: coverAlt.trim().isEmpty ? null : coverAlt.trim(),
    readingMinutes: BlogDocument.readingMinutes(title, document.plainText),
    publishedAt: publishedAt ?? DateTime.now(),
    category: category,
    author: author,
    tags: tags,
  );

  Map<String, dynamic> _backupJson() => {
    ...toPayload(),
    'id': id,
    'saved_at': DateTime.now().toIso8601String(),
  };

  static BlogPostDraft _fromBackup(Map<String, dynamic> json) => BlogPostDraft(
    id: json['id']?.toString(),
    title: json['title']?.toString() ?? '',
    subtitle: json['subtitle']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    excerpt: json['excerpt']?.toString() ?? '',
    coverUrl: json['cover_url']?.toString() ?? '',
    coverAlt: json['cover_alt']?.toString() ?? '',
    categoryId: json['category_id']?.toString(),
    tagIds: (json['tag_ids'] as List?)?.map((e) => e.toString()).toList(),
    authorId: json['author_id']?.toString(),
    isFeatured: json['is_featured'] == true,
    publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
    seoTitle: json['seo_title']?.toString() ?? '',
    metaDescription: json['meta_description']?.toString() ?? '',
    document: BlogDocument.fromJson(json['content']),
  );

  // ---------------------------------------------------------------------------
  // Local backup: survives failed saves/uploads and closed tabs.
  // ---------------------------------------------------------------------------
  static String _backupKey(String? id) => 'blog_editor_backup_v1_${id ?? 'new'}';

  Future<void> writeBackup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backupKey(id), jsonEncode(_backupJson()));
  }

  static Future<void> clearBackup(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_backupKey(id));
  }

  static Future<({BlogPostDraft draft, DateTime savedAt})?> readBackup(
    String? id,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_backupKey(id));
    if (raw == null) return null;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final savedAt = DateTime.tryParse(json['saved_at']?.toString() ?? '');
      if (savedAt == null) return null;
      return (draft: _fromBackup(json), savedAt: savedAt);
    } catch (_) {
      return null;
    }
  }
}
