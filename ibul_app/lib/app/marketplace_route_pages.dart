import 'package:flutter/material.dart';

import '../core/web_seo.dart';
import '../features/customer_support/screens/customer_support_page.dart';
import '../features/saved_payment_cards/screens/saved_payment_cards_page.dart';
import '../features/vehicle/screens/vehicle_customer_rentals_page.dart';
import '../models/product_model.dart';
import '../screens/account_page.dart';
import '../screens/addresses_page.dart';
import '../screens/ai_chat_page.dart';
import '../screens/business_detail_page.dart';
import '../screens/coupons_page.dart';
import '../screens/favorites_page.dart';
import '../screens/followed_stores_page.dart';
import '../screens/ibul_not_found_page.dart';
import '../screens/orders_page.dart';
import '../screens/product_detail_page.dart';
import '../screens/reviews_page.dart';
import '../screens/settings_page.dart';
import '../services/store_service.dart';
import '../services/supabase_service.dart';
import 'account_sections.dart';
import 'marketplace_paths.dart';

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
        setSeoMeta(
          title: '${product.name} | İBUL',
          description: product.shortDescription ?? product.name,
          canonicalPath: MarketplacePaths.product(
            widget.productId,
            slug: widget.slug ?? product.name,
          ),
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
        setSeoMeta(
          title: '$name | İBUL',
          description: '$name mağaza sayfası',
          canonicalPath: MarketplacePaths.store(
            widget.storeId,
            slug: widget.slug ?? name,
          ),
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
        return const FavoritesPage();
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
    }
  }
}

