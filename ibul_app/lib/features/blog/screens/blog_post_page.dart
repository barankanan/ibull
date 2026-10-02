import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/marketplace_paths.dart';
import '../../../core/web_seo.dart';
import '../blog_paths.dart';
import '../data/blog_repository.dart';
import '../models/blog_models.dart';
import '../widgets/blog_article_view.dart';
import '../widgets/blog_inline_text.dart';
import '../widgets/blog_post_card.dart';
import '../widgets/blog_scaffold.dart';
import '../widgets/blog_theme.dart';

/// Article JSON-LD. Kept in sync with `scripts/prerender_blog.py`.
String blogArticleJsonLd(BlogPost post) {
  final url = MarketplacePaths.shareUrl(BlogPaths.post(post.slug));
  return jsonEncode({
    '@context': 'https://schema.org',
    '@type': 'BlogPosting',
    'headline': post.seoTitle ?? post.title,
    if ((post.metaDescription ?? post.excerpt) != null)
      'description': post.metaDescription ?? post.excerpt,
    if (post.coverUrl != null) 'image': [post.coverUrl],
    if (post.publishedAt != null)
      'datePublished': post.publishedAt!.toUtc().toIso8601String(),
    if (post.updatedAt != null)
      'dateModified': post.updatedAt!.toUtc().toIso8601String(),
    if (post.author != null)
      'author': {'@type': 'Person', 'name': post.author!.displayName},
    'publisher': {'@type': 'Organization', 'name': 'İBUL'},
    'mainEntityOfPage': url,
  });
}

class BlogPostPage extends StatefulWidget {
  const BlogPostPage({super.key, required this.slug, this.repository});

  final String slug;
  final BlogRepository? repository;

  @override
  State<BlogPostPage> createState() => _BlogPostPageState();
}

class _BlogPostPageState extends State<BlogPostPage> {
  late final BlogRepository _repo = widget.repository ?? BlogRepository.instance;
  late Future<BlogPost?> _future = _load();
  List<BlogPostSummary> _related = const [];

  @override
  void didUpdateWidget(covariant BlogPostPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) {
      _related = const [];
      _future = _load();
    }
  }

  Future<BlogPost?> _load() async {
    final BlogPostLookup lookup;
    try {
      lookup = await _repo.getPost(widget.slug);
    } catch (_) {
      setSeoMeta(
        title: 'İBUL Blog',
        canonicalPath: BlogPaths.post(widget.slug),
        noIndex: true,
      );
      rethrow;
    }
    final redirect = lookup.redirectSlug;
    if (redirect != null && mounted) {
      final target = BlogPaths.post(redirect);
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.replace(target);
      } else {
        Navigator.of(context).pushReplacementNamed(target);
      }
      return null;
    }
    final post = lookup.post;
    if (post == null) {
      setSeoMeta(
        title: 'Yazı bulunamadı | İBUL Blog',
        description: 'Aradığınız blog yazısı bulunamadı veya yayından kaldırıldı.',
        canonicalPath: BlogPaths.post(widget.slug),
        noIndex: true,
      );
      return null;
    }
    setSeoMeta(
      title: '${post.seoTitle ?? post.title} | İBUL Blog',
      description: post.metaDescription ?? post.excerpt ?? post.subtitle,
      canonicalPath: BlogPaths.post(post.slug),
      imageUrl: post.coverUrl,
      ogType: 'article',
      jsonLd: blogArticleJsonLd(post),
    );
    _loadRelated(post);
    return post;
  }

  Future<void> _loadRelated(BlogPost post) async {
    try {
      var page = await _repo.listPosts(
        categorySlug: post.category?.slug,
        excludeId: post.id,
        limit: 3,
      );
      if (page.items.isEmpty && post.category != null) {
        page = await _repo.listPosts(excludeId: post.id, limit: 3);
      }
      if (mounted) setState(() => _related = page.items);
    } catch (_) {
      // Related posts are optional.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BlogPost?>(
      future: _future,
      builder: (context, snapshot) {
        final Widget body;
        if (snapshot.connectionState != ConnectionState.done) {
          body = const Padding(
            padding: EdgeInsets.symmetric(vertical: 120),
            child: Center(
              child: CircularProgressIndicator(color: BlogTheme.accent),
            ),
          );
        } else if (snapshot.hasError) {
          body = BlogStateMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Yazı yüklenemedi',
            message: snapshot.error is BlogException
                ? (snapshot.error as BlogException).message
                : 'Bağlantınızı kontrol edip tekrar deneyin.',
            actionLabel: 'Tekrar dene',
            onAction: () => setState(() => _future = _load()),
          );
        } else if (snapshot.data == null) {
          body = BlogStateMessage(
            icon: Icons.article_outlined,
            title: 'Yazı bulunamadı',
            message: 'Bu yazı kaldırılmış veya adresi değişmiş olabilir.',
            actionLabel: 'Bloga dön',
            onAction: () => openBlogLink(context, BlogPaths.root),
          );
        } else {
          body = _Loaded(post: snapshot.data!, related: _related);
        }
        return BlogScaffold(slivers: [SliverToBoxAdapter(child: body)]);
      },
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.post, required this.related});

  final BlogPost post;
  final List<BlogPostSummary> related;

  @override
  Widget build(BuildContext context) {
    final gutter = BlogTheme.gutter(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BlogArticleView(post: post),
        const SizedBox(height: 56),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: BlogTheme.pageWidth + gutter * 2,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: BlogTheme.line),
                  const SizedBox(height: 32),
                  if (related.isNotEmpty) ...[
                    const Text(
                      'İlgili yazılar',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: BlogTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = BlogTheme.gridColumns(
                          constraints.maxWidth,
                        );
                        const gap = 32.0;
                        final width =
                            (constraints.maxWidth - gap * (columns - 1)) /
                            columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: 40,
                          children: [
                            for (final item in related)
                              SizedBox(
                                width: width,
                                child: BlogPostCard(post: item),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => openBlogLink(context, BlogPaths.root),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Tüm blog yazıları'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BlogTheme.accent,
                      side: const BorderSide(color: BlogTheme.accent),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
