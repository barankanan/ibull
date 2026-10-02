import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/web_seo.dart';
import '../blog_paths.dart';
import '../data/blog_repository.dart';
import '../models/blog_models.dart';
import '../widgets/blog_post_card.dart';
import '../widgets/blog_scaffold.dart';
import '../widgets/blog_theme.dart';

class BlogHomePage extends StatefulWidget {
  const BlogHomePage({
    super.key,
    this.initialSearch,
    this.initialCategory,
    this.repository,
  });

  final String? initialSearch;
  final String? initialCategory;
  final BlogRepository? repository;

  /// Reads `?q=` / `?kategori=` from route arguments (go_router query map) or,
  /// on a cold web load, from the address bar.
  factory BlogHomePage.fromArguments(Object? arguments) {
    Map<String, String> query = const {};
    if (arguments is Map) {
      query = arguments.map((k, v) => MapEntry(k.toString(), v.toString()));
    } else if (kIsWeb && Uri.base.path == BlogPaths.root) {
      query = Uri.base.queryParameters;
    }
    return BlogHomePage(
      initialSearch: query[BlogPaths.searchParam],
      initialCategory: query[BlogPaths.categoryParam],
    );
  }

  @override
  State<BlogHomePage> createState() => _BlogHomePageState();
}

enum _LoadState { loading, ready, error }

class _BlogHomePageState extends State<BlogHomePage> {
  late final BlogRepository _repo = widget.repository ?? BlogRepository.instance;
  late final TextEditingController _search = TextEditingController(
    text: widget.initialSearch ?? '',
  );
  Timer? _debounce;
  int _requestId = 0;

  List<BlogCategory> _categories = const [];
  String? _category;
  BlogPostSummary? _featured;
  final List<BlogPostSummary> _posts = [];
  int _total = 0;
  _LoadState _state = _LoadState.loading;
  bool _loadingMore = false;
  String? _error;

  String get _query => _search.text.trim();
  bool get _filtered => _query.isNotEmpty || _category != null;

  @override
  void initState() {
    super.initState();
    _category = (widget.initialCategory?.isEmpty ?? true)
        ? null
        : widget.initialCategory;
    _repo.listCategories().then((value) {
      if (mounted) setState(() => _categories = value);
    }).catchError((_) {});
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _syncUrlAndMeta() {
    final path = BlogPaths.home(search: _query, categorySlug: _category);
    if (kIsWeb) {
      SystemNavigator.routeInformationUpdated(
        uri: Uri.parse(path),
        replace: true,
      );
    }
    final category = _categories.where((c) => c.slug == _category).firstOrNull;
    setSeoMeta(
      title: category == null ? 'İBUL Blog' : '${category.name} | İBUL Blog',
      description:
          category?.description ??
          'Alışveriş rehberleri, ürün karşılaştırmaları ve İBUL’dan haberler.',
      canonicalPath: BlogPaths.home(categorySlug: _category),
      noIndex: _query.isNotEmpty,
    );
  }

  Future<void> _reload() async {
    final id = ++_requestId;
    setState(() {
      _state = _LoadState.loading;
      _error = null;
    });
    _syncUrlAndMeta();
    try {
      BlogPostSummary? featured;
      if (!_filtered) {
        final hero = await _repo.listPosts(featured: true, limit: 1);
        featured = hero.items.firstOrNull;
      }
      final page = await _repo.listPosts(
        search: _query,
        categorySlug: _category,
        excludeId: featured?.id,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _featured = featured;
        _posts
          ..clear()
          ..addAll(page.items);
        _total = page.total;
        // No post flagged as featured: promote the latest one.
        if (_featured == null && !_filtered && _posts.isNotEmpty) {
          _featured = _posts.removeAt(0);
          _total -= 1;
        }
        _state = _LoadState.ready;
      });
    } catch (error) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _state = _LoadState.error;
        _error = error is BlogException
            ? error.message
            : 'Yazılar yüklenemedi. Bağlantınızı kontrol edin.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final id = _requestId;
    setState(() => _loadingMore = true);
    try {
      final promoted = _featured != null && !_filtered && !_featured!.isFeatured;
      final page = await _repo.listPosts(
        search: _query,
        categorySlug: _category,
        excludeId: _featured?.isFeatured == true ? _featured!.id : null,
        offset: _posts.length + (promoted ? 1 : 0),
      );
      if (!mounted || id != _requestId) return;
      setState(() => _posts.addAll(page.items));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daha fazla yazı yüklenemedi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  void _selectCategory(String? slug) {
    if (slug == _category) return;
    _category = slug;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final gutter = BlogTheme.gutter(context);
    Widget framed(Widget child) => Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: BlogTheme.pageWidth + gutter * 2),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );
    return BlogScaffold(
      slivers: [
        SliverToBoxAdapter(child: framed(_header())),
        SliverToBoxAdapter(child: framed(_categoryMenu())),
        ..._content(framed),
      ],
    );
  }

  Widget _header() {
    final wide = BlogTheme.isWide(context);
    return Padding(
      padding: EdgeInsets.only(top: wide ? 56 : 32, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'İBUL Blog',
            style: TextStyle(
              fontSize: wide ? 52 : 36,
              fontWeight: FontWeight.w900,
              color: BlogTheme.ink,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Akıllı alışveriş rehberleri, ürün karşılaştırmaları ve İBUL’dan haberler.',
            style: BlogTheme.subtitleStyle(context),
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              onSubmitted: (_) {
                _debounce?.cancel();
                _reload();
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Blogda ara',
                prefixIcon: const Icon(Icons.search, color: BlogTheme.muted),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Aramayı temizle',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _reload();
                        },
                      ),
                filled: true,
                fillColor: const Color(0xFFF7F6FA),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: BlogTheme.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryMenu() {
    Widget chip(String label, String? slug) {
      final selected = _category == slug;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => _selectCategory(slug),
          selectedColor: BlogTheme.accent,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: selected ? BlogTheme.accent : BlogTheme.line,
          ),
          labelStyle: TextStyle(
            color: selected ? Colors.white : BlogTheme.body,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(bottom: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BlogTheme.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip('Tümü', null),
            for (final category in _categories) chip(category.name, category.slug),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(Widget Function(Widget) framed) {
    if (_state == _LoadState.loading) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 96),
            child: Center(
              child: CircularProgressIndicator(color: BlogTheme.accent),
            ),
          ),
        ),
      ];
    }
    if (_state == _LoadState.error) {
      return [
        SliverToBoxAdapter(
          child: BlogStateMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Yazılar yüklenemedi',
            message: _error,
            actionLabel: 'Tekrar dene',
            onAction: _reload,
          ),
        ),
      ];
    }
    if (_posts.isEmpty && _featured == null) {
      return [
        SliverToBoxAdapter(
          child: BlogStateMessage(
            icon: Icons.search_off_outlined,
            title: _filtered ? 'Sonuç bulunamadı' : 'Henüz yazı yok',
            message: _filtered
                ? 'Farklı bir kelime deneyin veya filtreleri temizleyin.'
                : 'Yakında burada yeni yazılar olacak.',
            actionLabel: _filtered ? 'Filtreleri temizle' : null,
            onAction: _filtered
                ? () {
                    _search.clear();
                    _category = null;
                    _reload();
                  }
                : null,
          ),
        ),
      ];
    }
    return [
      if (_featured != null)
        SliverToBoxAdapter(
          child: framed(
            Padding(
              padding: const EdgeInsets.only(top: 36, bottom: 12),
              child: BlogFeaturedCard(post: _featured!),
            ),
          ),
        ),
      if (_filtered)
        SliverToBoxAdapter(
          child: framed(
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text('$_total yazı bulundu', style: BlogTheme.metaStyle),
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: framed(
          Padding(
            padding: const EdgeInsets.only(top: 36),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = BlogTheme.gridColumns(constraints.maxWidth);
                const gap = 32.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: 44,
                  children: [
                    for (final post in _posts)
                      SizedBox(width: width, child: BlogPostCard(post: post)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      if (_posts.length < _total)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: OutlinedButton(
                onPressed: _loadingMore ? null : _loadMore,
                style: OutlinedButton.styleFrom(
                  foregroundColor: BlogTheme.accent,
                  side: const BorderSide(color: BlogTheme.accent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                ),
                child: Text(_loadingMore ? 'Yükleniyor…' : 'Daha fazla yazı'),
              ),
            ),
          ),
        ),
    ];
  }
}
