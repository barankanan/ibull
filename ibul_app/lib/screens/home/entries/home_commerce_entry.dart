import 'package:flutter/material.dart';

import '../../../models/db_category.dart';
import '../../../models/db_product.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/text_normalizer.dart';
import '../deferred/deferred_home_full_rail_section.dart';

/// Commerce rails. Fetches only after this library is loaded.
class HomeCommerceBlock extends StatefulWidget {
  final String category;
  final String? subCategory;
  const HomeCommerceBlock({
    super.key,
    required this.category,
    this.subCategory,
  });

  @override
  State<HomeCommerceBlock> createState() => _HomeCommerceBlockState();
}

class _HomeCommerceBlockState extends State<HomeCommerceBlock> {
  List<_HomeCategorySection> _sections = const [];
  bool _loading = true;
  String? _error;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final int requestId = ++_requestGeneration;
    try {
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
          final categoryTreeFuture = SupabaseService.instance
            .getCategoriesWithSubsStrict()
          .timeout(const Duration(seconds: 8));
          final categoryLabelsFuture = SupabaseService.instance
            .getHomeProductCategoryLabels()
            .timeout(const Duration(seconds: 12));
          var categoryTree = const <CategoryWithSubcategories>[];
          try {
            categoryTree = await categoryTreeFuture;
          } catch (error) {
            debugPrint('[HomeCommerce] category tree query failed: $error');
          }
        var categoryLabels =
            const <({String mainCategory, String? subCategory})>[];
        try {
          categoryLabels = await categoryLabelsFuture;
        } catch (error) {
          debugPrint('[HomeCommerce] product category labels failed: $error');
        }
          final requests = _buildRequests(categoryTree, categoryLabels);
      if (requests.isEmpty) {
        throw StateError('No active home product categories were returned.');
      }
      final sections = await Future.wait(
        requests.map(_fetchSection),
      ).timeout(const Duration(seconds: 12));

      if (!mounted || _requestGeneration != requestId) return;
      setState(() {
        _sections = sections;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || _requestGeneration != requestId) return;
      setState(() {
        _loading = false;
        _error = 'Ürün kategorileri yüklenemedi';
      });
      debugPrint('[HomeCommerce] categories query failed: $error');
    }
  }

  List<_HomeCategorySection> _buildRequests(
    List<CategoryWithSubcategories> categoryTree,
    List<({String mainCategory, String? subCategory})> productLabels,
  ) {
    final requests = <_HomeCategorySection>[];
    final seenMainCategories = <String>{};
    final seenLeafGroups = <String>{};

    void addMainCategory(String name, String id) {
      final key = TextNormalizer.normalize(name);
      if (key.isEmpty || !seenMainCategories.add(key)) return;
      requests.add(
        _HomeCategorySection(
          id: id,
          title: _mainCategoryTitle(name),
          category: name,
        ),
      );
    }

    void addPhoneOrTabletLeaf(String mainCategory, String subCategory, String id) {
      final normalized = TextNormalizer.normalize(subCategory);
      final isPhone = normalized.contains('telefon');
      final isTablet = normalized.contains('tablet') ||
          normalized.contains('ipad');
      if (!isPhone && !isTablet) return;
      final family = isPhone ? 'phones' : 'tablets';
      if (!seenLeafGroups.add(family)) return;
      requests.add(
        _HomeCategorySection(
          id: id,
          title: isPhone ? 'Telefonlar' : 'Tabletler',
          category: mainCategory,
          subCategory: subCategory,
        ),
      );
    }

    for (final node in categoryTree) {
      final main = node.mainCategory;
      if (!main.isActive || main.id == null) continue;
      addMainCategory(main.name, 'category-${main.id}');

      for (final sub in node.subCategories) {
        if (!sub.isActive || sub.parentId != main.id || sub.id == null) {
          continue;
        }
        addPhoneOrTabletLeaf(main.name, sub.name, 'leaf-${sub.id}');
      }
    }

    for (final label in productLabels) {
      final main = label.mainCategory.trim();
      if (main.isEmpty) continue;
      addMainCategory(main, 'product-category-${requests.length}');
      final sub = label.subCategory;
      if (sub != null) {
        addPhoneOrTabletLeaf(main, sub, 'product-leaf-${requests.length}');
      }
    }

    return requests;
  }

  String _mainCategoryTitle(String rawName) {
    final name = TextNormalizer.normalize(rawName);
    if (name.contains('elektronik') ||
        name.contains('bilgisayar') ||
        name.contains('teknoloji')) {
      return 'Bilgisayar/Elektronik';
    }
    if (name.contains('ev') &&
        (name.contains('yasam') || name.contains('mobilya'))) {
      return 'Ev & Yaşam';
    }
    if (name.contains('moda') || name.contains('giyim')) return 'Moda';
    if (name.contains('yemek') || name.contains('restoran')) {
      return 'Restoran/Yemek';
    }
    if (name.contains('arac')) return 'Araç';
    if (name.contains('emlak')) return 'Emlak';
    if (name.contains('kozmetik')) return 'Kozmetik';
    if (name.contains('anne') || name.contains('bebek')) return 'Anne & Bebek';
    if (name.contains('kitap') || name.contains('kirtasiye')) {
      return 'Kitap & Kırtasiye';
    }
    if (name.contains('ayakkabi') || name.contains('canta')) {
      return 'Ayakkabı & Çanta';
    }
    if (name.contains('spor')) return 'Spor';
    return rawName;
  }

  Future<_HomeCategorySection> _fetchSection(
    _HomeCategorySection section,
  ) async {
    try {
      final page = await SupabaseService.instance
          .getCategoryProductsPaged(
            category: section.category,
            subCategory: section.subCategory,
            limit: 24,
          )
          .timeout(const Duration(seconds: 8));
      debugPrint(
        '[HomeCommerce] section=${section.id} title="${section.title}" '
        'state=${page.items.isEmpty ? 'empty' : 'content'} '
        'count=${page.items.length}',
      );
      return section.withResult(products: page.items);
    } catch (error) {
      debugPrint(
        '[HomeCommerce] section=${section.id} title="${section.title}" '
        'state=error error=$error',
      );
      return section.withResult(error: 'Bu kategori ürünleri yüklenemedi.');
    }
  }

  Future<void> _retrySection(_HomeCategorySection section) async {
    final index = _sections.indexWhere((item) => item.id == section.id);
    if (index < 0) return;
    final updated = await _fetchSection(section);
    if (!mounted) return;
    setState(() {
      _sections = [..._sections]..[index] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const DeferredHomeFullRailSection(
        title: 'Kategoriler',
        products: <DBProduct>[],
        isLoading: true,
        showViewAll: false,
      );
    }
    if (_error != null) {
      return DeferredHomeFullRailSection(
        title: 'Ürün kategorileri',
        products: const <DBProduct>[],
        errorMessage: _error,
        onRetry: _load,
        showViewAll: false,
      );
    }
    final visibleSections = _sections
        .where((section) => section.products.isNotEmpty || section.error != null)
        .toList(growable: false);
    if (visibleSections.isEmpty) {
      return DeferredHomeFullRailSection(
        title: 'Popüler Ürünler',
        products: const <DBProduct>[],
        onRetry: _load,
        showViewAll: false,
      );
    }
    return Column(
      children: [
        for (final section in visibleSections)
          DeferredHomeFullRailSection(
            key: ValueKey('home-category-rail-${section.id}'),
            title: section.title,
            products: section.products,
            maxItems: 12,
            grouped: false,
            errorMessage: section.error,
            onRetry: () => _retrySection(section),
          ),
      ],
    );
  }
}

class _HomeCategorySection {
  const _HomeCategorySection({
    required this.id,
    required this.title,
    required this.category,
    this.subCategory,
    this.products = const <DBProduct>[],
    this.error,
  });

  final String id;
  final String title;
  final String category;
  final String? subCategory;
  final List<DBProduct> products;
  final String? error;

  _HomeCategorySection withResult({
    List<DBProduct> products = const <DBProduct>[],
    String? error,
  }) => _HomeCategorySection(
    id: id,
    title: title,
    category: category,
    subCategory: subCategory,
    products: products,
    error: error,
  );
}
