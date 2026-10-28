import 'package:flutter/material.dart';

import '../core/public_seo.dart';
import '../core/web_boot_loader.dart';
import '../core/web_seo.dart';
import '../features/customer_support/screens/customer_support_page.dart';
import '../features/saved_payment_cards/screens/saved_payment_cards_page.dart';
import '../features/vehicle/screens/vehicle_customer_rentals_page.dart';
import '../models/product_model.dart';
import '../screens/account_page.dart';
import '../screens/addresses_page.dart';
import '../screens/ai_chat_page.dart';
import '../screens/business_detail_page.dart';
import '../screens/category_products_page.dart';
import '../screens/coupons_page.dart';
import '../screens/favorites_page.dart';
import '../screens/followed_stores_page.dart';
import '../screens/ibul_not_found_page.dart';
import '../screens/orders_page.dart';
import '../screens/product_detail_page.dart';
import '../screens/reviews_page.dart';
import '../screens/account/account_security_page.dart';
import '../screens/account/notification_settings_page.dart';
import '../screens/settings_page.dart';
import '../services/store_service.dart';
import '../services/supabase_service.dart';
import '../widgets/common/product_card_skeleton.dart';
import 'account_sections.dart';
import 'marketplace_paths.dart';

class CategoryRoutePage extends StatefulWidget {
  const CategoryRoutePage({
    super.key,
    required this.mainCategoryId,
    required this.subCategoryId,
  });

  final String mainCategoryId;
  final String subCategoryId;

  @override
  State<CategoryRoutePage> createState() => _CategoryRoutePageState();
}

class _CategoryRoutePageState extends State<CategoryRoutePage> {
  late Future<Widget> _future = _resolve();

  @override
  void initState() {
    super.initState();
    // Direct / refreshed /kategori URLs never mount the home page, which is the
    // only normal-boot path that removes the full-screen HTML boot loader.
    WidgetsBinding.instance.addPostFrameCallback((_) => dismissWebBootLoader());
  }

  Future<Widget> _resolve() async {
    final decodedMain = Uri.decodeComponent(widget.mainCategoryId);
    final decodedSub = Uri.decodeComponent(widget.subCategoryId);
    final mainId = int.tryParse(decodedMain);
    final subId = int.tryParse(decodedSub);
    
    // We can match by integer ID or string Name
    final isMainMatch = (node) => 
        (mainId != null && node.mainCategory.id == mainId) || 
        (node.mainCategory.name == decodedMain);
        
    final isSubMatch = (sub, resolvedMainId) => 
        (subId != null && sub.id == subId) || 
        (sub.name == decodedSub && sub.parentId == resolvedMainId);

    final categories = await SupabaseService.instance
      .getCategoriesWithSubsStrict();
      
    for (final node in categories) {
      if (!isMainMatch(node) || !node.mainCategory.isActive) {
        continue;
      }
      
      if (widget.subCategoryId.isEmpty || widget.subCategoryId == '-') {
        final products = await SupabaseService.instance.getCategoryProductsPaged(
          category: node.mainCategory.name,
          limit: 24,
        );
        setSeoMeta(
          title: categorySeoTitle(node.mainCategory.name),
          description: clipMetaDescription(
            '${node.mainCategory.name} kategorisindeki ürünler.',
          ),
          canonicalPath: MarketplacePaths.category(
            widget.mainCategoryId,
            widget.subCategoryId.isEmpty ? '-' : widget.subCategoryId,
            slug: node.mainCategory.name,
          ),
          jsonLd: breadcrumbJsonLd([
            (name: 'İBUL', path: '/'),
            (name: node.mainCategory.name, path: MarketplacePaths.categoryRoot),
          ]),
        );
        return CategoryProductsPage(
          category: node.mainCategory.name,
          subCategory: '', // Main category only
          products: products.items
              .map(Product.fromDBProduct)
              .toList(growable: false),
          initialNextCursor: products.nextCursor,
        );
      }

      for (final sub in node.subCategories) {
        if (!isSubMatch(sub, node.mainCategory.id) || !sub.isActive) {
          continue;
        }
        final products = await SupabaseService.instance.getCategoryProductsPaged(
          category: node.mainCategory.name,
          subCategory: sub.name,
          limit: 24,
        );
        final categoryPath = MarketplacePaths.category(
          widget.mainCategoryId,
          widget.subCategoryId,
          slug: sub.name,
        );
        setSeoMeta(
          title: categorySeoTitle(sub.name),
          description: clipMetaDescription(
            '${sub.name} ürünleri, ${node.mainCategory.name} kategorisinde.',
          ),
          canonicalPath: categoryPath,
          jsonLd: breadcrumbJsonLd([
            (name: 'İBUL', path: '/'),
            (name: node.mainCategory.name, path: MarketplacePaths.categoryRoot),
            (name: sub.name, path: categoryPath),
          ]),
        );
        return CategoryProductsPage(
          category: node.mainCategory.name,
          subCategory: sub.name,
          products: products.items
              .map(Product.fromDBProduct)
              .toList(growable: false),
          initialNextCursor: products.nextCursor,
        );
      }
    }
    return IbulNotFoundPage(path: MarketplacePaths.categoryRoot);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _future,
      builder: (context, snapshot) {
        Widget content;
        if (snapshot.hasError) {
          content = Scaffold(
            key: const ValueKey('category-route-error'),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Kategori ürünleri yüklenemedi.'),
                  TextButton(
                    onPressed: () => setState(() => _future = _resolve()),
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            ),
          );
        } else if (!snapshot.hasData) {
          content = const Scaffold(
            key: ValueKey('category-route-loading'),
            body: SafeArea(
              child: ProductCardSkeletonGrid(itemCount: 8),
            ),
          );
        } else {
          content = KeyedSubtree(
            key: const ValueKey('category-route-data'),
            child: snapshot.data!,
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: content,
        );
      },
    );
  }
}

class ProductRoutePage extends StatefulWidget {
  const ProductRoutePage({
    super.key,
    required this.productId,
    this.initial,
    this.slug,
  });

  final String productId;
  final Product? initial;
  final String? slug;

  @override
  State<ProductRoutePage> createState() => _ProductRoutePageState();
}

class _ProductRoutePageState extends State<ProductRoutePage> {
  late final Future<Product?> _future = _resolve();

  Future<Product?> _resolve() async {
    final initial = widget.initial;
    if (initial != null &&
        (initial.productId == null ||
            initial.productId == widget.productId)) {
      return initial;
    }
    final row = await SupabaseService.instance.getProductByIdString(
      widget.productId,
    );
    if (row == null) return null;
    return Product.fromDBProduct(row);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Product?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final product = snapshot.data;
        if (product == null) {
          return IbulNotFoundPage(
            path: MarketplacePaths.product(widget.productId),
          );
        }
        final canonicalPath = MarketplacePaths.product(
          widget.productId,
          slug: widget.slug ?? product.name,
        );
        final images = productHttpImages(product);
        setSeoMeta(
          title: productSeoTitle(product.name),
          description: clipMetaDescription(
            product.shortDescription ?? product.description,
            fallback: product.name,
          ),
          canonicalPath: canonicalPath,
          imageUrl: images.isEmpty ? null : images.first,
          ogType: 'product',
          jsonLd: productJsonLd(product, canonicalPath: canonicalPath),
        );
        return ProductDetailPage(product: product);
      },
    );
  }
}

class StoreRoutePage extends StatefulWidget {
  const StoreRoutePage({
    super.key,
    required this.storeId,
    this.initial,
    this.slug,
  });

  final String storeId;
  final Map<String, dynamic>? initial;
  final String? slug;

  @override
  State<StoreRoutePage> createState() => _StoreRoutePageState();
}

class _StoreRoutePageState extends State<StoreRoutePage> {
  late final Future<Map<String, dynamic>?> _future = _resolve();

  Future<Map<String, dynamic>?> _resolve() async {
    final initial = widget.initial;
    if (initial != null && initial.isNotEmpty) return initial;
    final info = await StoreService().getStorePublicInfoById(widget.storeId);
    if (info == null) {
      return {
        'id': widget.storeId,
        'seller_id': widget.storeId,
        'name': widget.slug ?? 'Mağaza',
      };
    }
    return {
      'id': widget.storeId,
      'seller_id': widget.storeId,
      'name': info['businessName'] ?? widget.slug ?? 'Mağaza',
      'logo': info['logoUrl'],
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final business = snapshot.data;
        if (business == null) {
          return IbulNotFoundPage(
            path: MarketplacePaths.store(widget.storeId),
          );
        }
        final name = business['name']?.toString() ?? 'Mağaza';
        final canonicalPath = MarketplacePaths.store(
          widget.storeId,
          slug: widget.slug ?? name,
        );
        setSeoMeta(
          title: storeSeoTitle(name),
          description: clipMetaDescription('$name mağazasının ürünleri ve bilgileri.'),
          canonicalPath: canonicalPath,
          imageUrl: business['logo']?.toString(),
          jsonLd: breadcrumbJsonLd([
            (name: 'İBUL', path: '/'),
            (name: name, path: canonicalPath),
          ]),
        );
        return BusinessDetailPage(business: business);
      },
    );
  }
}

class AccountSectionRoutePage extends StatelessWidget {
  const AccountSectionRoutePage({super.key, required this.section});

  final AccountSection section;

  @override
  Widget build(BuildContext context) {
    setSeoMeta(
      title: AccountSections.documentTitleOf(section),
      description: 'İBUL hesap, sipariş ve kiralama yönetimi.',
      canonicalPath: AccountSections.pathOf(section),
      noIndex: true,
    );
    return _pageFor(section);
  }

  static Widget _pageFor(AccountSection section) {
    switch (section) {
      case AccountSection.overview:
        return const AccountPage();
      case AccountSection.ai:
        return const AIChatPage(showAccountSidebar: true);
      case AccountSection.orders:
        return const OrdersPage();
      case AccountSection.rentals:
        return const VehicleCustomerRentalsPage();
      case AccountSection.favorites:
        return const FavoritesPage(showAccountSidebar: false);
      case AccountSection.coupons:
        return const CouponsPage();
      case AccountSection.following:
        return const FollowedStoresPage();
      case AccountSection.addresses:
        return const AddressesPage();
      case AccountSection.cards:
        return const SavedPaymentCardsPage();
      case AccountSection.reviews:
        return const ReviewsPage();
      case AccountSection.support:
        return const CustomerSupportPage();
      case AccountSection.settings:
        return const SettingsPage();
      case AccountSection.notifications:
        return const NotificationSettingsPage();
      case AccountSection.security:
        return const AccountSecurityPage();
    }
  }
}

