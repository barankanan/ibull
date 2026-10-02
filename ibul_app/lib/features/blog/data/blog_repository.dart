import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/blog_models.dart';

class BlogException implements Exception {
  const BlogException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Single data access point for the blog (`20261002_blog_*.sql`).
class BlogRepository {
  BlogRepository({SupabaseClient? client}) : _clientOverride = client;

  static final BlogRepository instance = BlogRepository();

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  static const int pageSize = 12;

  // ---------------------------------------------------------------------------
  // Reader
  // ---------------------------------------------------------------------------
  Future<List<BlogCategory>> listCategories() async {
    final rows = await _run(() => _client.rpc('blog_list_categories'));
    return _rows(rows).map(BlogCategory.fromJson).toList();
  }

  Future<BlogPostPage> listPosts({
    String? search,
    String? categorySlug,
    bool? featured,
    String? excludeId,
    int limit = pageSize,
    int offset = 0,
  }) async {
    final rows = _rows(
      await _run(
        () => _client.rpc(
          'blog_list_posts',
          params: {
            'p_search': _blankToNull(search),
            'p_category': _blankToNull(categorySlug),
            'p_featured': featured,
            'p_exclude': excludeId,
            'p_limit': limit,
            'p_offset': offset,
          },
        ),
      ),
    );
    return BlogPostPage(
      items: rows.map(BlogPostSummary.fromJson).toList(),
      total: rows.isEmpty ? 0 : (rows.first['total_count'] as num).toInt(),
    );
  }

  Future<BlogPostLookup> getPost(String slug) async {
    final raw = await _run(
      () => _client.rpc('blog_get_post', params: {'p_slug': slug}),
    );
    if (raw is! Map) return const BlogPostLookup.missing();
    final json = Map<String, dynamic>.from(raw);
    final redirect = json['redirect_slug']?.toString();
    if (redirect != null && redirect.isNotEmpty) {
      return BlogPostLookup.redirect(redirect);
    }
    return BlogPostLookup.found(BlogPost.fromJson(json));
  }

  // ---------------------------------------------------------------------------
  // Management
  // ---------------------------------------------------------------------------
  Future<BlogAccess> myAccess() async {
    if (_client.auth.currentUser == null) return BlogAccess.none;
    return BlogAccess.fromJson(await _run(() => _client.rpc('blog_my_access')));
  }

  Future<BlogAdminPostPage> listManagedPosts({
    String? search,
    BlogPostStatus? status,
    int limit = 30,
    int offset = 0,
  }) async {
    final rows = _rows(
      await _run(
        () => _client.rpc(
          'blog_admin_list_posts',
          params: {
            'p_search': _blankToNull(search),
            'p_status': status?.apiName,
            'p_limit': limit,
            'p_offset': offset,
          },
        ),
      ),
    );
    return BlogAdminPostPage(
      items: rows.map(BlogAdminPostRow.fromJson).toList(),
      total: rows.isEmpty ? 0 : (rows.first['total_count'] as num).toInt(),
    );
  }

  Future<BlogPost> getEditablePost(String id) async => _post(
    await _run(
      () => _client.rpc('blog_get_editable_post', params: {'p_post_id': id}),
    ),
  );

  Future<BlogPost> savePost(String? id, Map<String, dynamic> payload) async =>
      _post(
        await _run(
          () => _client.rpc(
            'blog_save_post',
            params: {'p_post_id': id, 'p_payload': payload},
          ),
        ),
      );

  Future<BlogPost> submitForReview(String id) async => _post(
    await _run(
      () => _client.rpc('blog_submit_for_review', params: {'p_post_id': id}),
    ),
  );

  Future<BlogPost> publish(String id) async => _post(
    await _run(
      () => _client.rpc('blog_publish_post', params: {'p_post_id': id}),
    ),
  );

  Future<BlogPost> unpublish(String id) async => _post(
    await _run(
      () => _client.rpc('blog_unpublish_post', params: {'p_post_id': id}),
    ),
  );

  // Categories / tags (admin RLS on the tables).
  Future<List<BlogCategory>> listAllCategories() async {
    final rows = await _run(
      () => _client
          .from('blog_categories')
          .select('id,name,slug,description,sort_order,is_active')
          .order('sort_order')
          .order('name'),
    );
    return _rows(rows).map(BlogCategory.fromJson).toList();
  }

  Future<void> saveCategory({
    String? id,
    required String name,
    required String slug,
    String? description,
    required int sortOrder,
    required bool isActive,
  }) async {
    final data = {
      'name': name.trim(),
      'slug': slug,
      'description': _blankToNull(description),
      'sort_order': sortOrder,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _run(
      () => id == null
          ? _client.from('blog_categories').insert(data)
          : _client.from('blog_categories').update(data).eq('id', id),
    );
  }

  Future<List<BlogTag>> listTags() async {
    final rows = await _run(
      () => _client.from('blog_tags').select('id,name,slug').order('name'),
    );
    return _rows(rows).map(BlogTag.fromJson).toList();
  }

  Future<void> saveTag({String? id, required String name, required String slug}) async {
    final data = {'name': name.trim(), 'slug': slug};
    await _run(
      () => id == null
          ? _client.from('blog_tags').insert(data)
          : _client.from('blog_tags').update(data).eq('id', id),
    );
  }

  Future<void> deleteTag(String id) async {
    await _run(() => _client.from('blog_tags').delete().eq('id', id));
  }

  Future<List<BlogAuthor>> listAuthors() async {
    final rows = await _run(() => _client.rpc('blog_admin_list_authors'));
    return _rows(rows).map(BlogAuthor.fromJson).toList();
  }

  Future<void> saveAuthor({
    String? id,
    required String displayName,
    String? slug,
    String? bio,
    String? avatarUrl,
    String? userEmail,
    required bool isActive,
  }) async {
    await _run(
      () => _client.rpc(
        'blog_admin_upsert_author',
        params: {
          'p_id': id,
          'p_display_name': displayName,
          'p_slug': _blankToNull(slug),
          'p_bio': _blankToNull(bio),
          'p_avatar_url': _blankToNull(avatarUrl),
          'p_user_email': _blankToNull(userEmail),
          'p_is_active': isActive,
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static List<Map<String, dynamic>> _rows(Object? raw) => raw is List
      ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
      : const [];

  static BlogPost _post(Object? raw) {
    if (raw is! Map) throw const BlogException('Yazı bulunamadı.');
    return BlogPost.fromJson(Map<String, dynamic>.from(raw));
  }

  static Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PostgrestException catch (error) {
      throw BlogException(messageFor(error.message, code: error.code));
    }
  }

  static String messageFor(String raw, {String? code}) {
    const known = {
      'blog_not_authenticated': 'Bu işlem için giriş yapmalısınız.',
      'blog_forbidden': 'Bu işlem için yetkiniz yok.',
      'blog_not_found': 'Yazı bulunamadı.',
      'blog_title_required': 'Başlık zorunludur.',
      'blog_invalid_content':
          'İçerik güvenli değil veya desteklenmeyen bir blok içeriyor.',
      'blog_invalid_slug': 'URL adresi (slug) geçersiz veya ayrılmış.',
      'blog_slug_taken': 'Bu URL adresi başka bir yazıda kullanılıyor.',
      'blog_author_required': 'Yazar seçilmelidir.',
      'blog_invalid_category': 'Seçilen kategori bulunamadı.',
      'blog_no_revision': 'İncelemeye gönderilecek kaydedilmiş değişiklik yok.',
      'blog_user_not_found': 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.',
    };
    for (final entry in known.entries) {
      if (raw.contains(entry.key)) return entry.value;
    }
    if (code == '23505') return 'Bu ad veya adres zaten kullanılıyor.';
    if (code == '42501') return 'Bu işlem için yetkiniz yok.';
    if (code == 'PGRST202' || code == 'PGRST205' || code == '42P01') {
      return 'Blog altyapısı veritabanına henüz kurulmamış.';
    }
    return 'İşlem tamamlanamadı. Lütfen tekrar deneyin.';
  }
}

class BlogAdminPostPage {
  const BlogAdminPostPage({required this.items, required this.total});

  final List<BlogAdminPostRow> items;
  final int total;
}
