import 'dart:convert';

import 'package:ibul_app/features/blog/data/blog_repository.dart';
import 'package:ibul_app/features/blog/models/blog_content.dart';
import 'package:ibul_app/features/blog/models/blog_models.dart';

/// In-memory stand-in for the blog RPCs (status rules mirror the SQL).
class FakeBlogRepository extends BlogRepository {
  static const category = BlogCategory(id: 'c1', name: 'Teknoloji', slug: 'teknoloji');
  static const author = BlogAuthor(id: 'a1', displayName: 'Yazar Bir', slug: 'yazar-bir');

  final Map<String, Map<String, dynamic>> rows = {};
  int _seq = 0;
  bool failNextSave = false;
  bool failLists = false;

  @override
  Future<List<BlogCategory>> listCategories() async => [category];

  @override
  Future<List<BlogCategory>> listAllCategories() async => [category];

  @override
  Future<List<BlogTag>> listTags() async => const [];

  @override
  Future<List<BlogAuthor>> listAuthors() async => [author];

  @override
  Future<BlogPost> getEditablePost(String id) async {
    final row = rows[id];
    if (row == null) throw const BlogException('Yazı bulunamadı.');
    return BlogPost.fromJson(row);
  }

  @override
  Future<BlogPost> savePost(String? id, Map<String, dynamic> payload) async {
    if (failNextSave) {
      failNextSave = false;
      throw const BlogException('Bağlantı hatası.');
    }
    final data = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    final key = id ?? 'p${++_seq}';
    final previous = rows[key];
    rows[key] = {
      ...data,
      'id': key,
      'author_id': data['author_id'] ?? author.id,
      'status': previous?['status'] ?? 'draft',
      'published_at': previous?['published_at'] ?? data['published_at'],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    return getEditablePost(key);
  }

  @override
  Future<BlogPost> submitForReview(String id) async {
    rows[id]!['status'] = 'in_review';
    return getEditablePost(id);
  }

  @override
  Future<BlogPost> publish(String id) async {
    rows[id]!
      ..['status'] = 'published'
      ..['published_at'] ??= DateTime.now().toUtc().toIso8601String();
    return getEditablePost(id);
  }

  @override
  Future<BlogPost> unpublish(String id) async {
    rows[id]!['status'] = 'draft';
    return getEditablePost(id);
  }

  Iterable<Map<String, dynamic>> get _published =>
      rows.values.where((r) => r['status'] == 'published');

  Map<String, dynamic> _public(Map<String, dynamic> row) => {
    ...row,
    'category': row['category_id'] == category.id
        ? {'id': category.id, 'name': category.name, 'slug': category.slug}
        : null,
    'author': {'id': author.id, 'display_name': author.displayName, 'slug': author.slug},
    'category_name': row['category_id'] == category.id ? category.name : null,
    'category_slug': row['category_id'] == category.id ? category.slug : null,
  };

  @override
  Future<BlogPostPage> listPosts({
    String? search,
    String? categorySlug,
    bool? featured,
    String? excludeId,
    int limit = BlogRepository.pageSize,
    int offset = 0,
  }) async {
    if (failLists) throw const BlogException('Sunucuya ulaşılamadı.');
    final term = search?.trim().toLowerCase() ?? '';
    final matches = _published.where((r) {
      final text = [
        r['title'],
        r['excerpt'],
        BlogDocument.fromJson(r['content']).plainText,
      ].join(' ').toLowerCase();
      return (term.isEmpty || text.contains(term)) &&
          (categorySlug == null || (categorySlug == category.slug && r['category_id'] == category.id)) &&
          (featured != true || r['is_featured'] == true) &&
          r['id'] != excludeId;
    }).toList();
    return BlogPostPage(
      items: matches.skip(offset).take(limit).map((r) => BlogPostSummary.fromJson(_public(r))).toList(),
      total: matches.length,
    );
  }

  @override
  Future<BlogPostLookup> getPost(String slug) async {
    final row = _published.where((r) => r['slug'] == slug).firstOrNull;
    return row == null
        ? const BlogPostLookup.missing()
        : BlogPostLookup.found(BlogPost.fromJson(_public(row)));
  }
}
