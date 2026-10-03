import 'dart:convert';

import 'blog_content.dart';

DateTime? _date(Object? raw) =>
    raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();

String? _text(Object? raw) {
  final value = raw?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

enum BlogPostStatus {
  draft('Taslak'),
  inReview('İnceleme bekliyor'),
  published('Yayında');

  const BlogPostStatus(this.label);

  final String label;

  String get apiName => switch (this) {
    BlogPostStatus.draft => 'draft',
    BlogPostStatus.inReview => 'in_review',
    BlogPostStatus.published => 'published',
  };

  static BlogPostStatus? fromApi(Object? raw) {
    for (final value in values) {
      if (value.apiName == raw?.toString()) return value;
    }
    return null;
  }
}

class BlogCategory {
  const BlogCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final int sortOrder;
  final bool isActive;

  factory BlogCategory.fromJson(Map<String, dynamic> json) => BlogCategory(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    description: _text(json['description']),
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    isActive: json['is_active'] != false,
  );
}

class BlogTag {
  const BlogTag({required this.id, required this.name, required this.slug});

  final String id;
  final String name;
  final String slug;

  factory BlogTag.fromJson(Map<String, dynamic> json) => BlogTag(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
  );
}

class BlogAuthor {
  const BlogAuthor({
    required this.id,
    required this.displayName,
    required this.slug,
    this.bio,
    this.avatarUrl,
    this.isActive = true,
    this.userEmail,
    this.postCount = 0,
  });

  final String id;
  final String displayName;
  final String slug;
  final String? bio;
  final String? avatarUrl;
  final bool isActive;
  final String? userEmail;
  final int postCount;

  factory BlogAuthor.fromJson(Map<String, dynamic> json) => BlogAuthor(
    id: json['id'].toString(),
    displayName: json['display_name']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    bio: _text(json['bio']),
    avatarUrl: _text(json['avatar_url']),
    isActive: json['is_active'] != false,
    userEmail: _text(json['user_email']),
    postCount: (json['post_count'] as num?)?.toInt() ?? 0,
  );
}

/// Card row returned by `blog_list_posts`.
class BlogPostSummary {
  const BlogPostSummary({
    required this.id,
    required this.slug,
    required this.title,
    this.subtitle,
    this.excerpt,
    this.coverUrl,
    this.coverAlt,
    this.categoryName,
    this.categorySlug,
    this.authorName,
    this.isFeatured = false,
    this.readingMinutes = 1,
    this.publishedAt,
    this.updatedAt,
  });

  final String id;
  final String slug;
  final String title;
  final String? subtitle;
  final String? excerpt;
  final String? coverUrl;
  final String? coverAlt;
  final String? categoryName;
  final String? categorySlug;
  final String? authorName;
  final bool isFeatured;
  final int readingMinutes;
  final DateTime? publishedAt;
  final DateTime? updatedAt;

  factory BlogPostSummary.fromJson(Map<String, dynamic> json) =>
      BlogPostSummary(
        id: json['id'].toString(),
        slug: json['slug']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        subtitle: _text(json['subtitle']),
        excerpt: _text(json['excerpt']),
        coverUrl: _text(json['cover_url']),
        coverAlt: _text(json['cover_alt']),
        categoryName: _text(json['category_name']),
        categorySlug: _text(json['category_slug']),
        authorName: _text(json['author_name']),
        isFeatured: json['is_featured'] == true,
        readingMinutes: (json['reading_minutes'] as num?)?.toInt() ?? 1,
        publishedAt: _date(json['published_at']),
        updatedAt: _date(json['updated_at']),
      );
}

class BlogPostPage {
  const BlogPostPage({required this.items, required this.total});

  final List<BlogPostSummary> items;
  final int total;
}

/// Full article (`blog_get_post`) or the editable view (`blog_get_editable_post`).
class BlogPost {
  BlogPost({
    required this.id,
    required this.slug,
    required this.title,
    required this.document,
    this.subtitle,
    this.excerpt,
    this.coverUrl,
    this.coverAlt,
    this.isFeatured = false,
    this.seoTitle,
    this.metaDescription,
    this.readingMinutes = 1,
    this.publishedAt,
    this.updatedAt,
    this.category,
    this.author,
    this.tags = const [],
    this.status,
    this.revisionStatus,
    this.categoryId,
    this.authorId,
    this.tagIds = const [],
    this.liveSlug,
  });

  final String id;
  final String slug;
  final String title;
  final BlogDocument document;
  final String? subtitle;
  final String? excerpt;
  final String? coverUrl;
  final String? coverAlt;
  final bool isFeatured;
  final String? seoTitle;
  final String? metaDescription;
  final int readingMinutes;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final BlogCategory? category;
  final BlogAuthor? author;
  final List<BlogTag> tags;

  // Editable-only fields.
  final BlogPostStatus? status;
  final BlogPostStatus? revisionStatus;
  final String? categoryId;
  final String? authorId;
  final List<String> tagIds;
  final String? liveSlug;

  bool get hasRevision => revisionStatus != null;

  factory BlogPost.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    final author = json['author'];
    final tags = json['tags'];
    final tagIds = json['tag_ids'];
    return BlogPost(
      id: json['id'].toString(),
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      document: BlogDocument.fromJson(json['content']),
      subtitle: _text(json['subtitle']),
      excerpt: _text(json['excerpt']),
      coverUrl: _text(json['cover_url']),
      coverAlt: _text(json['cover_alt']),
      isFeatured: json['is_featured'] == true,
      seoTitle: _text(json['seo_title']),
      metaDescription: _text(json['meta_description']),
      readingMinutes: (json['reading_minutes'] as num?)?.toInt() ?? 1,
      publishedAt: _date(json['published_at']),
      updatedAt: _date(json['updated_at']),
      category: category is Map
          ? BlogCategory.fromJson(Map<String, dynamic>.from(category))
          : null,
      author: author is Map
          ? BlogAuthor.fromJson(Map<String, dynamic>.from(author))
          : null,
      tags: tags is List
          ? tags
                .whereType<Map>()
                .map((t) => BlogTag.fromJson(Map<String, dynamic>.from(t)))
                .toList()
          : const [],
      status: BlogPostStatus.fromApi(json['status']),
      revisionStatus: BlogPostStatus.fromApi(json['revision_status']),
      categoryId: _text(json['category_id']),
      authorId: _text(json['author_id']),
      tagIds: tagIds is List
          ? tagIds.map((e) => e.toString()).toList()
          : const [],
      liveSlug: _text(json['live_slug']),
    );
  }
}

/// Result of resolving a public slug.
class BlogPostLookup {
  const BlogPostLookup.found(BlogPost this.post) : redirectSlug = null;
  const BlogPostLookup.redirect(String this.redirectSlug) : post = null;
  const BlogPostLookup.missing() : post = null, redirectSlug = null;

  final BlogPost? post;
  final String? redirectSlug;
}

class BlogAccess {
  const BlogAccess({required this.isAdmin, this.authorId, this.authorName});

  static const none = BlogAccess(isAdmin: false);

  final bool isAdmin;
  final String? authorId;
  final String? authorName;

  bool get canWrite => isAdmin || authorId != null;

  factory BlogAccess.fromJson(Object? raw) {
    if (raw is String && raw.trim().startsWith('{')) {
      raw = jsonDecode(raw);
    }
    if (raw is! Map) {
      throw const FormatException('blog_my_access');
    }
    return BlogAccess(
      isAdmin: raw['is_admin'] == true || raw['is_admin'] == 'true',
      authorId: _text(raw['author_id']),
      authorName: _text(raw['author_name']),
    );
  }
}

/// Row returned by `blog_admin_list_posts`.
class BlogAdminPostRow {
  const BlogAdminPostRow({
    required this.id,
    required this.slug,
    required this.title,
    required this.status,
    this.revisionStatus,
    this.authorName,
    this.categoryName,
    this.publishedAt,
    this.updatedAt,
  });

  final String id;
  final String slug;
  final String title;
  final BlogPostStatus status;
  final BlogPostStatus? revisionStatus;
  final String? authorName;
  final String? categoryName;
  final DateTime? publishedAt;
  final DateTime? updatedAt;

  factory BlogAdminPostRow.fromJson(Map<String, dynamic> json) =>
      BlogAdminPostRow(
        id: json['id'].toString(),
        slug: json['slug']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        status:
            BlogPostStatus.fromApi(json['status']) ?? BlogPostStatus.draft,
        revisionStatus: BlogPostStatus.fromApi(json['revision_status']),
        authorName: _text(json['author_name']),
        categoryName: _text(json['category_name']),
        publishedAt: _date(json['published_at']),
        updatedAt: _date(json['updated_at']),
      );
}
