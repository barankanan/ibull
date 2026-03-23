import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_list_model.dart';
import '../models/product_list_price_change.dart';
import '../models/product_model.dart';
import 'store_service.dart';
import 'supabase_service.dart';

class SellerProfilePublicListsFetchResult {
  const SellerProfilePublicListsFetchResult({
    required this.lists,
    required this.ownerScopedCount,
    required this.directScopedCount,
    required this.itemScopedCount,
    required this.ownerScopedIds,
    required this.directScopedIds,
    required this.itemScopedIds,
  });

  final List<ProductList> lists;
  final int ownerScopedCount;
  final int directScopedCount;
  final int itemScopedCount;
  final Set<String> ownerScopedIds;
  final Set<String> directScopedIds;
  final Set<String> itemScopedIds;
}

class ProductListService {
  ProductListService._();
  static final ProductListService instance = ProductListService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  final Random _random = Random();
  final StoreService _storeService = StoreService();

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<List<ProductList>> getOwnedLists() async {
    final userId = currentUserId;
    if (userId == null) return const [];

    final rows = await _supabase
        .from('product_lists')
        .select()
        .eq('owner_user_id', userId)
        .order('updated_at', ascending: false);

    return _hydrateLists(List<Map<String, dynamic>>.from(rows as List));
  }

  Future<List<ProductList>> getPublicLists({int limit = 40}) async {
    final rows = await _supabase
        .from('product_lists')
        .select()
        .eq('visibility', ProductListVisibility.public.dbValue)
        .order('follower_count', ascending: false)
        .order('updated_at', ascending: false)
        .limit(limit);

    return _hydrateLists(List<Map<String, dynamic>>.from(rows as List));
  }

  Future<List<ProductList>> getPublicListsForOwner(
    String ownerUserId, {
    int limit = 20,
  }) async {
    final normalizedOwnerId = ownerUserId.trim();
    if (normalizedOwnerId.isEmpty) return const [];

    final rows = await _supabase
        .from('product_lists')
        .select()
        .eq('owner_user_id', normalizedOwnerId)
        .eq('visibility', ProductListVisibility.public.dbValue)
        .order('updated_at', ascending: false)
        .limit(limit);

    return _hydrateLists(List<Map<String, dynamic>>.from(rows as List));
  }

  Future<List<ProductList>> getListsByIds(List<String> listIds) async {
    final normalizedIds = listIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedIds.isEmpty) return const [];

    final rows = await _supabase
        .from('product_lists')
        .select()
        .inFilter('id', normalizedIds);

    final hydrated = await _hydrateLists(
      List<Map<String, dynamic>>.from(rows as List),
    );
    final byId = {for (final list in hydrated) list.id: list};
    return normalizedIds
        .map((id) => byId[id])
        .whereType<ProductList>()
        .toList(growable: false);
  }

  Future<void> upsertList(ProductList list) async {
    final userId = currentUserId;
    if (userId == null) return;
    final resolvedStoreName = await _resolveStoreNameForList(list);
    final resolvedSellerId = _resolveSellerIdForList(list);

    final payload = <String, dynamic>{
      'id': list.id,
      'owner_user_id': userId,
      'seller_id': resolvedSellerId,
      'store_name': resolvedStoreName,
      'owner_display_name': list.ownerDisplayName,
      'owner_photo_url': list.ownerPhotoUrl,
      'name': list.name,
      'description': list.description,
      'cover_image_url': list.iconUrl,
      'category': list.category,
      'sub_category': list.subCategory,
      'visibility': list.visibility.dbValue,
      'share_code': list.shareCode,
      'product_count': list.productCount,
      'updated_at': list.updatedAt.toUtc().toIso8601String(),
    };

    try {
      await _supabase.from('product_lists').upsert(payload, onConflict: 'id');
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('seller_id') || message.contains('store_name')) {
        final legacyPayload = Map<String, dynamic>.from(payload)
          ..remove('seller_id')
          ..remove('store_name');
        await _supabase
            .from('product_lists')
            .upsert(legacyPayload, onConflict: 'id');
      } else {
        rethrow;
      }
    }
    await _supabase.from('product_list_items').delete().eq('list_id', list.id);

    if (list.products.isEmpty) return;

    final items = list.products
        .map((product) {
          return {
            'list_id': list.id,
            'product_key': productKey(product),
            'product_id': product.productId,
            'product_name': product.name,
            'brand': product.brand,
            'store_name': product.store,
            'seller_id': product.sellerId,
            'price_at_save': _parsePrice(product.price),
            'old_price_at_save': _parsePrice(product.oldPrice),
            'product_payload': product.toJson(),
          };
        })
        .toList(growable: false);

    await _supabase.from('product_list_items').insert(items);
  }

  Future<SellerProfilePublicListsFetchResult> getPublicListsForSellerProfile({
    required String sellerId,
    required String businessName,
    int limit = 60,
  }) async {
    final normalizedSellerId = sellerId.trim();
    final normalizedBusinessName = businessName.trim();

    final ownerScopedLists = normalizedSellerId.isEmpty
        ? const <ProductList>[]
        : await getPublicListsForOwner(normalizedSellerId, limit: limit);
    final ownerScopedIds = ownerScopedLists
        .map((list) => list.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final directScopedIds = await _fetchPublicListIdsByDirectStoreFields(
      sellerId: normalizedSellerId,
      businessName: normalizedBusinessName,
      limit: limit,
    );
    final itemScopedIds = await _fetchPublicListIdsByItems(
      sellerId: normalizedSellerId,
      businessName: normalizedBusinessName,
      limit: limit * 4,
    );

    final allCandidateIds = <String>{
      ...ownerScopedIds,
      ...directScopedIds,
      ...itemScopedIds,
    };

    final lists = allCandidateIds.isEmpty
        ? const <ProductList>[]
        : await _getPublicListsByIds(
            allCandidateIds.toList(growable: false),
            limit: limit,
          );

    return SellerProfilePublicListsFetchResult(
      lists: lists,
      ownerScopedCount: ownerScopedLists.length,
      directScopedCount: directScopedIds.length,
      itemScopedCount: itemScopedIds.length,
      ownerScopedIds: ownerScopedIds,
      directScopedIds: directScopedIds,
      itemScopedIds: itemScopedIds,
    );
  }

  Future<void> deleteList(String listId) async {
    await _supabase.from('product_lists').delete().eq('id', listId);
  }

  Future<void> followList(
    String listId, {
    bool notificationsEnabled = true,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _supabase.from('product_list_follows').upsert({
      'list_id': listId,
      'user_id': userId,
      'notifications_enabled': notificationsEnabled,
    }, onConflict: 'list_id,user_id');
  }

  Future<void> unfollowList(String listId) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _supabase
        .from('product_list_follows')
        .delete()
        .eq('list_id', listId)
        .eq('user_id', userId);
  }

  Future<void> updateFollowNotifications(
    String listId, {
    required bool enabled,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _supabase
        .from('product_list_follows')
        .update({'notifications_enabled': enabled})
        .eq('list_id', listId)
        .eq('user_id', userId);
  }

  Future<List<ProductListPriceChange>> getPriceChanges(ProductList list) async {
    final productIds = list.products
        .map((product) => product.productId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    final freshRows = await SupabaseService.instance.getProductsByIds(
      productIds,
    );
    final freshProducts = {
      for (final item in freshRows)
        item.id?.toString() ?? '': Product.fromDBProduct(item),
    };

    final results = <ProductListPriceChange>[];
    for (final product in list.products) {
      final current = freshProducts[product.productId?.trim() ?? ''] ?? product;
      final savedPrice = _parsePrice(product.price);
      final currentPrice = _parsePrice(current.price);
      if (savedPrice <= 0 || currentPrice <= 0) continue;
      if ((currentPrice - savedPrice).abs() < 0.009) continue;
      results.add(
        ProductListPriceChange(
          product: current,
          savedPrice: savedPrice,
          currentPrice: currentPrice,
        ),
      );
    }

    results.sort((a, b) => b.delta.abs().compareTo(a.delta.abs()));
    return results;
  }

  Future<void> notifyFollowersForNewProduct({
    required ProductList list,
    required Product product,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    final rows = await _supabase
        .from('product_list_follows')
        .select('user_id')
        .eq('list_id', list.id)
        .eq('notifications_enabled', true);

    final followerIds = List<Map<String, dynamic>>.from(rows as List)
        .map((row) => row['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty && id != userId)
        .toSet()
        .toList(growable: false);

    if (followerIds.isEmpty) return;

    final title = '${list.name} listesine yeni ürün eklendi';
    final body = '${product.brand} ${product.name} artık listede.';
    final now = DateTime.now().toUtc().toIso8601String();

    await _supabase
        .from('user_notifications')
        .insert(
          followerIds
              .map(
                (followerId) => {
                  'user_id': followerId,
                  'title': title,
                  'body': body,
                  'created_at': now,
                  'data': {
                    'type': 'product_list_updated',
                    'list_id': list.id,
                    'list_name': list.name,
                    'share_code': list.shareCode,
                    'product_id': product.productId,
                    'open_tab': 'notifications',
                  },
                },
              )
              .toList(growable: false),
        );
  }

  Future<List<ProductList>> _hydrateLists(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const [];

    final listIds = rows
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    final itemRowsRaw = await _supabase
        .from('product_list_items')
        .select()
        .inFilter('list_id', listIds)
        .order('created_at', ascending: true);
    final itemRows = List<Map<String, dynamic>>.from(itemRowsRaw as List);

    final userId = currentUserId;
    final follows = userId == null
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            (await _supabase
                    .from('product_list_follows')
                    .select('list_id, notifications_enabled')
                    .eq('user_id', userId)
                    .inFilter('list_id', listIds))
                as List,
          );

    final followsByListId = {
      for (final row in follows) row['list_id']?.toString() ?? '': row,
    };
    final itemsByListId = <String, List<Map<String, dynamic>>>{};
    for (final row in itemRows) {
      final listId = row['list_id']?.toString() ?? '';
      if (listId.isEmpty) continue;
      itemsByListId
          .putIfAbsent(listId, () => <Map<String, dynamic>>[])
          .add(row);
    }

    return rows
        .map((row) {
          final listId = row['id']?.toString() ?? '';
          final itemRowsForList = itemsByListId[listId] ?? const [];
          final products = itemRowsForList
              .map((item) {
                final payload = item['product_payload'];
                if (payload is Map) {
                  return Product.fromJson(Map<String, dynamic>.from(payload));
                }
                return null;
              })
              .whereType<Product>()
              .toList(growable: false);
          final followRow = followsByListId[listId];

          return ProductList(
            id: listId,
            name: row['name']?.toString() ?? 'Listem',
            description: row['description']?.toString(),
            iconUrl: row['cover_image_url']?.toString(),
            category: row['category']?.toString(),
            subCategory: row['sub_category']?.toString(),
            visibility: ProductListVisibilityX.fromValue(
              row['visibility']?.toString(),
            ),
            shareCode: row['share_code']?.toString() ?? buildShareCode(listId),
            sellerId: row['seller_id']?.toString(),
            storeName: row['store_name']?.toString(),
            ownerUserId: row['owner_user_id']?.toString(),
            ownerDisplayName: row['owner_display_name']?.toString(),
            ownerPhotoUrl: row['owner_photo_url']?.toString(),
            followerCount: (row['follower_count'] as num?)?.toInt() ?? 0,
            isFollowing: followRow != null,
            followNotificationsEnabled:
                followRow?['notifications_enabled'] != false,
            productIds: itemRowsForList
                .map((item) => item['product_key']?.toString() ?? '')
                .where((value) => value.isNotEmpty)
                .toList(growable: false),
            products: products,
            createdAt:
                DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.now(),
            updatedAt:
                DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
                DateTime.now(),
          );
        })
        .toList(growable: false);
  }

  String? _resolveSellerIdForList(ProductList list) {
    final explicitSellerId = list.sellerId?.trim();
    if (explicitSellerId != null && explicitSellerId.isNotEmpty) {
      return explicitSellerId;
    }
    for (final product in list.products) {
      final productSellerId = product.sellerId?.trim();
      if (productSellerId != null && productSellerId.isNotEmpty) {
        return productSellerId;
      }
    }
    final userId = currentUserId?.trim();
    if (userId != null && userId.isNotEmpty) {
      return userId;
    }
    return null;
  }

  Future<String?> _resolveStoreNameForList(ProductList list) async {
    final explicitStoreName = list.storeName?.trim();
    if (explicitStoreName != null && explicitStoreName.isNotEmpty) {
      return explicitStoreName;
    }
    for (final product in list.products) {
      final productStoreName = product.store?.trim();
      if (productStoreName != null && productStoreName.isNotEmpty) {
        return productStoreName;
      }
    }
    final storeProfile = await _storeService.getStoreProfile();
    final profileStoreName = storeProfile?['storeName']?.toString().trim();
    if (profileStoreName != null && profileStoreName.isNotEmpty) {
      return profileStoreName;
    }
    return null;
  }

  Future<Set<String>> _fetchPublicListIdsByDirectStoreFields({
    required String sellerId,
    required String businessName,
    required int limit,
  }) async {
    final ids = <String>{};
    Future<void> addRows(dynamic rowsRaw) async {
      for (final row in List<Map<String, dynamic>>.from(rowsRaw as List)) {
        final id = row['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          ids.add(id);
        }
      }
    }

    try {
      if (sellerId.isNotEmpty) {
        final rows = await _supabase
            .from('product_lists')
            .select('id')
            .eq('visibility', ProductListVisibility.public.dbValue)
            .eq('seller_id', sellerId)
            .limit(limit);
        await addRows(rows);
      }

      if (businessName.isNotEmpty) {
        final rows = await _supabase
            .from('product_lists')
            .select('id')
            .eq('visibility', ProductListVisibility.public.dbValue)
            .ilike('store_name', businessName)
            .limit(limit);
        await addRows(rows);
      }
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (!message.contains('seller_id') && !message.contains('store_name')) {
        rethrow;
      }
    }

    return ids;
  }

  Future<Set<String>> _fetchPublicListIdsByItems({
    required String sellerId,
    required String businessName,
    required int limit,
  }) async {
    final ids = <String>{};

    void addRows(dynamic rowsRaw) {
      for (final row in List<Map<String, dynamic>>.from(rowsRaw as List)) {
        final id = row['list_id']?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          ids.add(id);
        }
      }
    }

    if (sellerId.isNotEmpty) {
      final rows = await _supabase
          .from('product_list_items')
          .select('list_id')
          .eq('seller_id', sellerId)
          .limit(limit);
      addRows(rows);
    }

    if (businessName.isNotEmpty) {
      final rows = await _supabase
          .from('product_list_items')
          .select('list_id')
          .ilike('store_name', businessName)
          .limit(limit);
      addRows(rows);
    }

    return ids;
  }

  Future<List<ProductList>> _getPublicListsByIds(
    List<String> listIds, {
    required int limit,
  }) async {
    final normalizedIds = listIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return const <ProductList>[];
    }

    final rows = await _supabase
        .from('product_lists')
        .select()
        .eq('visibility', ProductListVisibility.public.dbValue)
        .inFilter('id', normalizedIds)
        .order('updated_at', ascending: false)
        .limit(limit);

    return _hydrateLists(List<Map<String, dynamic>>.from(rows as List));
  }

  String buildShareCode(String seed) {
    final prefix = seed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '')
        .trim();
    final suffix = List.generate(
      6,
      (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_random.nextInt(36)],
    ).join();
    if (prefix.isEmpty) return suffix;
    final normalized = prefix.length <= 18 ? prefix : prefix.substring(0, 18);
    return '$normalized$suffix';
  }

  String productKey(Product product) {
    final productId = product.productId?.trim() ?? '';
    if (productId.isNotEmpty) return 'id:$productId';
    final brand = product.brand.trim().toLowerCase();
    final name = product.name.trim().toLowerCase();
    final store = (product.store ?? '').trim().toLowerCase();
    return '$brand|$name|$store';
  }

  double _parsePrice(String? rawValue) {
    final source = rawValue?.trim() ?? '';
    if (source.isEmpty) return 0;

    var normalized = source
        .replaceAll('TL', '')
        .replaceAll('₺', '')
        .replaceAll(RegExp(r'[^0-9,.\-]'), '');

    if (normalized.contains(',') && normalized.contains('.')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else if (normalized.contains(',')) {
      normalized = normalized.replaceAll(',', '.');
    }

    return double.tryParse(normalized) ?? 0;
  }
}
