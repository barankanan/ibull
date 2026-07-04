import 'package:flutter/foundation.dart';

import '../../../core/app_state.dart';
import '../../../models/db_product.dart';
import '../../../models/product_model.dart';
import '../../../services/order_service.dart';
import '../../../services/store_service.dart';
import '../../../services/supabase_service.dart';
import '../helpers/order_history_status_helper.dart';
import '../models/order_history_models.dart';

class OrderHistoryService {
  OrderHistoryService._();
  static final OrderHistoryService instance = OrderHistoryService._();

  final _orderService = OrderService.instance;
  final _supabase = SupabaseService.instance;
  final _storeService = StoreService();

  Future<List<Map<String, dynamic>>> getMyPastOrders(String userId) {
    return _orderService.getUserOrders(userId);
  }

  List<Map<String, dynamic>> filterPastOrders({
    required List<Map<String, dynamic>> orders,
    required OrderHistoryFilter filter,
  }) {
    return orders.where((order) {
      final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
      if (createdAt == null) return false;
      if (filter.month != null && createdAt.month != filter.month) return false;
      if (filter.year != null && createdAt.year != filter.year) return false;

      final items =
          (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final resolved = OrderHistoryStatusHelper.resolveOrderStatus(
        (order['status']?.toString() ?? '').toLowerCase(),
        items,
      );
      return OrderHistoryStatusHelper.matchesStatusFilter(
        resolved,
        filter.status,
      );
    }).toList();
  }

  Map<String, dynamic>? findOrderById(
    List<Map<String, dynamic>> orders,
    String orderId,
  ) {
    for (final order in orders) {
      if ((order['id']?.toString() ?? '') == orderId) return order;
    }
    return null;
  }

  /// True when [product] has enough data to open [ProductDetailPage] safely.
  static bool isNavigableProduct(Product product) {
    final name = product.name.trim();
    if (name.isEmpty) return false;
    final id = product.productId?.trim() ?? '';
    return id.isNotEmpty;
  }

  Future<Product?> resolveProductForNavigation(Map<String, dynamic> item) async {
    try {
      final dbProduct = await _fetchDbProductForOrderItem(item);
      if (dbProduct == null) return null;
      final product = Product.fromDBProduct(dbProduct);
      if (!isNavigableProduct(product)) return null;
      return product;
    } catch (e, stackTrace) {
      debugPrint('resolveProductForNavigation failed: $e\n$stackTrace');
      return null;
    }
  }

  Future<DBProduct?> _fetchDbProductForOrderItem(
    Map<String, dynamic> item,
  ) async {
    final productId = item['product_id']?.toString().trim() ?? '';
    if (productId.isNotEmpty) {
      final byId = await _supabase.getProductsByIds([productId]);
      if (byId.isNotEmpty) return byId.first;
    }

    final productCode = item['product_code']?.toString().trim() ?? '';
    if (productCode.isNotEmpty && _looksLikeProductUuid(productCode)) {
      final byCode = await _supabase.getProductsByIds([productCode]);
      if (byCode.isNotEmpty) return byCode.first;
    }

    final productName = item['product_name']?.toString().trim() ?? '';
    if (productName.isNotEmpty) {
      return _supabase.getFirstProductByName(productName);
    }

    return null;
  }

  bool _looksLikeProductUuid(String value) {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidPattern.hasMatch(value);
  }

  String resolveProductIdFromItem(Map<String, dynamic> item) =>
      _resolveProductId(item);

  Future<List<ReorderLineCheck>> checkReorderAvailability(
    Map<String, dynamic> order,
  ) async {
    final items =
        (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    if (items.isEmpty) return const [];

    final productIds = <String>[];
    for (final item in items) {
      final productId = _resolveProductId(item);
      if (productId.isNotEmpty) productIds.add(productId);
    }

    final products = await _supabase.getProductsByIds(productIds);
    final productById = {
      for (final product in products)
        if ((product.id ?? '').isNotEmpty) product.id!: product,
    };

    final sellerCache = <String, bool>{};
    final checks = <ReorderLineCheck>[];

    for (final item in items) {
      checks.add(
        await _checkItem(
          item: item,
          productById: productById,
          sellerCache: sellerCache,
        ),
      );
    }
    return checks;
  }

  Future<ReorderResult> reorderOrder({
    required Map<String, dynamic> order,
    required AppState appState,
    List<String>? selectedItemIds,
  }) async {
    final checks = await checkReorderAvailability(order);
    final scoped = selectedItemIds == null
        ? checks
        : checks
            .where((c) => selectedItemIds.contains(c.orderItemId))
            .toList();

    final added = <ReorderLineCheck>[];
    final blocked = <ReorderLineCheck>[];
    final priceChanged = <ReorderLineCheck>[];

    for (final check in scoped) {
      if (check.canAddToCart && check.product != null) {
        final error = await appState.addToCart(check.product!);
        if (error != null) {
          blocked.add(check);
          continue;
        }
        if (check.outcome == ReorderItemOutcome.priceChanged) {
          priceChanged.add(check);
        }
        added.add(check);
      } else {
        blocked.add(check);
      }
    }

    return ReorderResult(
      added: added,
      blocked: blocked,
      priceChanged: priceChanged,
      allBlocked: added.isEmpty,
    );
  }

  Future<ReorderLineCheck> _checkItem({
    required Map<String, dynamic> item,
    required Map<String, DBProduct> productById,
    required Map<String, bool> sellerCache,
  }) async {
    final orderItemId = item['id']?.toString() ?? '';
    final productName = item['product_name']?.toString() ?? 'Ürün';
    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final previousUnitPrice = (item['unit_price'] as num?)?.toDouble();
    final productId = _resolveProductId(item);

    if (productId.isEmpty) {
      return ReorderLineCheck(
        orderItemId: orderItemId,
        productName: productName,
        quantity: quantity,
        outcome: ReorderItemOutcome.notListed,
        previousUnitPrice: previousUnitPrice,
      );
    }

    final dbProduct = productById[productId];
    if (dbProduct == null) {
      return ReorderLineCheck(
        orderItemId: orderItemId,
        productName: productName,
        quantity: quantity,
        outcome: ReorderItemOutcome.notListed,
        previousUnitPrice: previousUnitPrice,
      );
    }

    if (!dbProduct.isActive) {
      return ReorderLineCheck(
        orderItemId: orderItemId,
        productName: productName,
        quantity: quantity,
        outcome: ReorderItemOutcome.notListed,
        previousUnitPrice: previousUnitPrice,
      );
    }

    final stock = dbProduct.stock;
    if (stock != null && stock <= 0) {
      return ReorderLineCheck(
        orderItemId: orderItemId,
        productName: productName,
        quantity: quantity,
        outcome: ReorderItemOutcome.outOfStock,
        previousUnitPrice: previousUnitPrice,
      );
    }

    final sellerId = (item['seller_id']?.toString() ?? dbProduct.sellerId ?? '').trim();
    if (sellerId.isNotEmpty) {
      final storeActive = await _isSellerStoreActive(sellerId, sellerCache);
      if (!storeActive) {
        return ReorderLineCheck(
          orderItemId: orderItemId,
          productName: productName,
          quantity: quantity,
          outcome: ReorderItemOutcome.storeInactive,
          previousUnitPrice: previousUnitPrice,
        );
      }
    }

    final product = Product.fromDBProduct(dbProduct);
    final currentUnitPrice = _parsePrice(dbProduct.price);
    final priceChanged = previousUnitPrice != null &&
        currentUnitPrice != null &&
        (currentUnitPrice - previousUnitPrice).abs() > 0.01;

    return ReorderLineCheck(
      orderItemId: orderItemId,
      productName: productName,
      quantity: quantity,
      outcome: priceChanged
          ? ReorderItemOutcome.priceChanged
          : ReorderItemOutcome.added,
      product: product,
      previousUnitPrice: previousUnitPrice,
      currentUnitPrice: currentUnitPrice,
    );
  }

  Future<bool> _isSellerStoreActive(
    String sellerId,
    Map<String, bool> cache,
  ) async {
    if (cache.containsKey(sellerId)) return cache[sellerId]!;
    try {
      final info = await _storeService.getStorePublicInfoById(sellerId);
      final active = info != null && info.isNotEmpty;
      cache[sellerId] = active;
      return active;
    } catch (_) {
      cache[sellerId] = false;
      return false;
    }
  }

  String _resolveProductId(Map<String, dynamic> item) {
    final productId = item['product_id']?.toString().trim() ?? '';
    if (productId.isNotEmpty) return productId;
    final productCode = item['product_code']?.toString().trim() ?? '';
    return productCode;
  }

  double? _parsePrice(String raw) {
    final normalized = raw.replaceAll('TL', '').replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(normalized);
  }
}
