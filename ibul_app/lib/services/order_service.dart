import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/runtime_config.dart';
import 'supabase_service.dart';

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  static const double _deliveryBaseFee = 28;
  static const double _deliveryPerKmFee = 7;
  static const double _deliveryNightBonus = 12;
  static const double _deliveryRainBonus = 15;
  static const double _defaultDeliveryKm = 2.2;

  String get _debugSupabaseUrl {
    final raw = AppRuntimeConfig.rawSupabaseUrl.trim();
    return raw.isEmpty ? '(missing)' : raw;
  }

  String _debugRestRequestUrl(
    String table, {
    Map<String, String> query = const <String, String>{},
  }) {
    final encodedQuery = query.isEmpty
        ? ''
        : '?${Uri(queryParameters: query).query}';
    if (_debugSupabaseUrl == '(missing)') {
      return 'supabase://$table$encodedQuery';
    }
    return '$_debugSupabaseUrl/rest/v1/$table$encodedQuery';
  }

  void _debugSellerOrdersFetch(
    String branch, {
    required String sellerId,
    String? requestUrl,
    String? note,
    int? rowCount,
    int? durationMs,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final section = error == null ? 'Fetch' : 'Error';
    debugPrint(
      '[SellerPanel][$section] service=OrderService '
      'branch=$branch '
      'sellerId=${sellerId.isEmpty ? '-' : sellerId} '
      'requestUrl=${requestUrl ?? '-'} '
      'durationMs=${durationMs ?? '-'} '
      'rowCount=${rowCount ?? '-'} '
      'note=${note ?? '-'}'
      '${error != null ? ' error=$error' : ''}',
    );
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<Map<String, dynamic>> createOrderFromCheckout({
    required String userId,
    required List<Map<String, dynamic>> selectedProducts,
    required double totalAmount,
    required Map<String, dynamic> deliveryAddress,
    required Map<String, dynamic> paymentCard,
    required String deliveryType,
    String? deliverySlot,
  }) async {
    if (selectedProducts.isEmpty) {
      throw Exception('Sipariş verilecek ürün bulunamadı.');
    }

    final now = DateTime.now();
    final orderNumber =
        'IBUL-${now.millisecondsSinceEpoch.toString().substring(6)}';
    final List<Map<String, dynamic>> resolvedItems = [];
    final Set<String> categorySet = {};
    final Set<String> purchasedNames = {};
    final itemsNeedingAttention = selectedProducts
        .where((source) {
          final directProductId = source['productId']?.toString();
          final productObject = source['productObject'];
          String? objectProductId;
          try {
            objectProductId = (productObject as dynamic).productId?.toString();
          } catch (_) {}
          return (directProductId ?? objectProductId ?? '').trim().isEmpty;
        })
        .toList(growable: false);
    if (itemsNeedingAttention.isNotEmpty) {
      throw Exception(
        'Bazi sepet urunleri artik kullanilamiyor. Lutfen bu urunleri yeniden ekleyin.',
      );
    }

    final productIdsForMetadata = <String>{};
    final explicitSellerIds = <String>{};
    final explicitStoreNames = <String>{};
    for (final source in selectedProducts) {
      final productId = source['productId']?.toString().trim();
      if (productId != null && productId.isNotEmpty) {
        productIdsForMetadata.add(productId);
      }
      final sellerId = source['sellerId']?.toString().trim();
      if (sellerId != null && sellerId.isNotEmpty) {
        explicitSellerIds.add(sellerId);
      }
      final storeName = source['storeName']?.toString().trim();
      if (storeName != null && storeName.isNotEmpty) {
        explicitStoreNames.add(storeName);
      }
      final productObject = source['productObject'];
      try {
        final objectSellerId = (productObject as dynamic).sellerId
            ?.toString()
            .trim();
        if (objectSellerId != null && objectSellerId.isNotEmpty) {
          explicitSellerIds.add(objectSellerId);
        }
      } catch (_) {}
      try {
        final objectStoreName = (productObject as dynamic).store
            ?.toString()
            .trim();
        if (objectStoreName != null && objectStoreName.isNotEmpty) {
          explicitStoreNames.add(objectStoreName);
        }
      } catch (_) {}
      try {
        final objectProductId = (productObject as dynamic).productId
            ?.toString()
            .trim();
        if (objectProductId != null && objectProductId.isNotEmpty) {
          productIdsForMetadata.add(objectProductId);
        }
      } catch (_) {}
    }

    final productMetadataById = <String, Map<String, dynamic>>{};
    if (productIdsForMetadata.isNotEmpty) {
      try {
        final productRows = await _supabase
            .from('products')
            .select('id, seller_id, main_category')
            .inFilter('id', productIdsForMetadata.toList(growable: false));
        for (final row in List<Map<String, dynamic>>.from(
          productRows as List,
        )) {
          final id = row['id']?.toString();
          if (id == null || id.isEmpty) continue;
          productMetadataById[id] = row;
          final sellerId = row['seller_id']?.toString();
          if (sellerId != null && sellerId.isNotEmpty) {
            explicitSellerIds.add(sellerId);
          }
        }
      } catch (e) {
        debugPrint('OrderService bulk product metadata warn: $e');
      }
    }

    final storesBySellerId = <String, Map<String, dynamic>>{};
    final storesByName = <String, Map<String, dynamic>>{};
    final storeRows = await _fetchStoresInBulk(
      sellerIds: explicitSellerIds.toList(growable: false),
      storeNames: explicitStoreNames.toList(growable: false),
    );
    for (final row in storeRows) {
      final sellerId = row['seller_id']?.toString();
      final businessName = row['business_name']?.toString();
      if (sellerId != null && sellerId.isNotEmpty) {
        storesBySellerId[sellerId] = row;
      }
      if (businessName != null && businessName.trim().isNotEmpty) {
        storesByName[businessName.trim().toLowerCase()] = row;
      }
    }

    final sellerSubtotalMap = <String, double>{};

    for (int i = 0; i < selectedProducts.length; i++) {
      final source = selectedProducts[i];
      final productName = source['name']?.toString() ?? 'Ürün';
      final quantity = _toInt(source['quantity'], fallback: 1);
      final unitPrice = _toDoublePrice(source['price']);
      final totalPrice = (unitPrice * quantity).toDouble();
      final productCode =
          (source['sku'] ??
                  source['productId'] ??
                  source['id'] ??
                  source['productKey'] ??
                  'SKU-${i + 1}')
              .toString();
      final attributes = _collectAttributes(source);
      final imageUrl = source['image']?.toString();
      final productObject = source['productObject'];

      String? productId = source['productId']?.toString();
      String? sellerId = source['sellerId']?.toString();
      String? storeName = source['storeName']?.toString();
      String? categoryName = source['category']?.toString();

      try {
        productId ??= (productObject as dynamic).productId?.toString();
      } catch (_) {}
      try {
        sellerId ??= (productObject as dynamic).sellerId?.toString();
      } catch (_) {}
      try {
        storeName ??= (productObject as dynamic).store?.toString();
      } catch (_) {}
      try {
        categoryName ??= (productObject as dynamic).category?.toString();
      } catch (_) {}

      final metadata = productId == null
          ? null
          : productMetadataById[productId.trim()];
      sellerId ??= metadata?['seller_id']?.toString();
      categoryName ??= metadata?['main_category']?.toString();

      if ((storeName ?? '').trim().isNotEmpty) {
        final byName = storesByName[storeName!.trim().toLowerCase()];
        sellerId ??= byName?['seller_id']?.toString();
        storeName = byName?['business_name']?.toString() ?? storeName;
      }
      if ((sellerId ?? '').trim().isNotEmpty) {
        final bySellerId = storesBySellerId[sellerId!.trim()];
        storeName = bySellerId?['business_name']?.toString() ?? storeName;
      }

      final normalizedSellerId = sellerId?.trim() ?? '';
      if (normalizedSellerId.isNotEmpty) {
        sellerSubtotalMap[normalizedSellerId] =
            (sellerSubtotalMap[normalizedSellerId] ?? 0) + totalPrice;
      }

      final itemRow = <String, dynamic>{
        'seller_id': normalizedSellerId.isEmpty ? null : normalizedSellerId,
        'product_id': productId,
        'product_code': productCode,
        'product_name': productName,
        'store_name': storeName ?? _fallbackStoreName(source),
        'product_image_url': imageUrl,
        'attributes': attributes,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_price': totalPrice,
        'status': 'new',
        'shipment_step': 'confirmed',
        'cargo_company': 'ihız',
        'tracking_number': _buildTrackingNumber(orderNumber, i),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      resolvedItems.add(itemRow);
      purchasedNames.add(productName.toLowerCase());
      if ((categoryName ?? '').isNotEmpty) {
        categorySet.add(categoryName!);
      }
    }

    final deliveryPricing = _calculateDeliveryPricing(
      sourceType: 'ibul_internal',
      sellerSubtotalMap: sellerSubtotalMap,
      storesBySellerId: storesBySellerId,
      deliveryAddress: deliveryAddress,
      now: now,
    );

    final customerDeliveryFee =
        (deliveryPricing['customer_delivery_fee'] as double?) ?? 0.0;
    final sellerDeliveryFee =
        (deliveryPricing['seller_delivery_fee'] as double?) ?? 0.0;
    final totalDeliveryFee =
        (deliveryPricing['total_delivery_fee'] as double?) ?? 0.0;

    final baseOrderInsert = <String, dynamic>{
      'user_id': userId,
      'order_number': orderNumber,
      'status': 'confirmed',
      'payment_method': 'card',
      'payment_card_name': paymentCard['name']?.toString() ?? 'Kart',
      'payment_card_last4': _last4FromMaskedCard(
        paymentCard['number']?.toString(),
      ),
      'delivery_type': deliveryType,
      'delivery_slot': deliverySlot,
      'delivery_address': deliveryAddress,
      'subtotal_amount': totalAmount,
      'shipping_amount': customerDeliveryFee,
      'discount_amount': 0,
      'total_amount': totalAmount + customerDeliveryFee,
      'currency': 'TRY',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
    final extendedOrderInsert = <String, dynamic>{
      ...baseOrderInsert,
      'total_delivery_fee': totalDeliveryFee,
      'customer_delivery_fee': customerDeliveryFee,
      'seller_delivery_fee': sellerDeliveryFee,
      'wallet_reserve_status': 'none',
    };

    Map<String, dynamic> orderRow;
    String? orderId;
    final walletHolds = <Map<String, dynamic>>[];
    try {
      try {
        final inserted = await _supabase
            .from('orders')
            .insert(extendedOrderInsert)
            .select(
              'id, order_number, created_at, total_amount, status, shipping_amount, total_delivery_fee, customer_delivery_fee, seller_delivery_fee, wallet_reserve_status',
            )
            .single();
        orderRow = Map<String, dynamic>.from(inserted as Map);
      } catch (error) {
        if (!_isMissingDeliveryColumnsError(error)) rethrow;
        final inserted = await _supabase
            .from('orders')
            .insert(baseOrderInsert)
            .select(
              'id, order_number, created_at, total_amount, status, shipping_amount',
            )
            .single();
        orderRow = Map<String, dynamic>.from(inserted as Map);
      }
      orderId = orderRow['id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        throw Exception('Sipariş ID oluşturulamadı.');
      }

      final orderItems = resolvedItems
          .map((item) => <String, dynamic>{...item, 'order_id': orderId})
          .toList(growable: false);

      final insertedOrderItems = await _supabase
          .from('order_items')
          .insert(orderItems)
          .select();

      final storedItems = List<Map<String, dynamic>>.from(
        insertedOrderItems as List,
      );
      if (storedItems.isNotEmpty) {
        final historyRows = storedItems
            .map(
              (item) => <String, dynamic>{
                'order_item_id': item['id'],
                'status': 'confirmed',
                'title': 'Siparişiniz Alındı',
                'description':
                    'Sipariş kaydı oluşturuldu ve satıcının onayına gönderildi.',
                'tracking_number': item['tracking_number'],
                'cargo_company': item['cargo_company'],
              },
            )
            .toList();
        try {
          await _supabase.from('order_item_status_history').insert(historyRows);
        } catch (e) {
          debugPrint('OrderService initial history insert warn: $e');
        }
      }

      final sellerFeeBySellerId = Map<String, double>.from(
        deliveryPricing['seller_fee_by_seller'] as Map<String, double>,
      );
      for (final entry in sellerFeeBySellerId.entries) {
        final amount = entry.value;
        if (amount <= 0) continue;
        final reserveResponse = await _reserveSellerWalletForDelivery(
          sellerId: entry.key,
          amount: amount,
          referenceId: orderId,
          sourceType: 'ibul_internal',
          idempotencyKey: _buildWalletIdempotencyKey(
            prefix: 'reserve',
            referenceId: orderId,
            sellerId: entry.key,
          ),
          metadata: {
            'source': 'checkout',
            'delivery_type': deliveryType,
            'customer_id': userId,
            'order_number': orderNumber,
          },
        );
        walletHolds.add(reserveResponse);
      }
      if (walletHolds.isNotEmpty) {
        try {
          await _supabase
              .from('orders')
              .update({'wallet_reserve_status': 'reserved'})
              .eq('id', orderId);
          orderRow['wallet_reserve_status'] = 'reserved';
        } catch (_) {}
      }

      final helpfulProducts = await _getHelpfulProducts(
        categories: categorySet.toList(),
        excludeNamesLower: purchasedNames,
      );

      return {
        ...orderRow,
        'delivery_address': deliveryAddress,
        'payment_card': {
          'name': paymentCard['name']?.toString() ?? 'Kart',
          'number': paymentCard['number']?.toString() ?? '****',
        },
        'items': storedItems,
        'helpful_products': helpfulProducts,
        'delivery_pricing': deliveryPricing,
        'wallet_holds': walletHolds,
      };
    } catch (error) {
      await _releaseReservedWalletHolds(
        holds: walletHolds,
        reason: 'Checkout create order rollback',
      );
      if (orderId != null && orderId.isNotEmpty) {
        try {
          await _supabase.from('order_items').delete().eq('order_id', orderId);
          await _supabase.from('orders').delete().eq('id', orderId);
        } catch (_) {}
      }
      throw Exception(_mapWalletError(error));
    }
  }

  Future<Map<String, dynamic>> createSellerExternalCargoOrder({
    required String sellerId,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String city,
    required String district,
    double? customerLat,
    double? customerLng,
    String? productName,
    required int quantity,
    required double unitPrice,
    String? externalOrderReference,
    String? note,
    String? storeName,
    String deliveryType = 'ihiz_kurye_teslim',
    String cargoCompany = 'İHIZ',
  }) async {
    final normalizedSellerId = sellerId.trim();
    if (normalizedSellerId.isEmpty) {
      throw Exception('Satıcı kimliği bulunamadı.');
    }

    final normalizedCustomerName = customerName.trim();
    final normalizedCustomerPhone = customerPhone.trim();
    final normalizedCustomerAddress = customerAddress.trim();
    final normalizedProductName = (productName ?? '').trim().isEmpty
        ? 'Harici Sipariş Ürünü'
        : productName!.trim();
    if (normalizedCustomerName.isEmpty ||
        normalizedCustomerPhone.isEmpty ||
        normalizedCustomerAddress.isEmpty) {
      throw Exception('Müşteri alanları zorunludur.');
    }

    final safeQuantity = quantity <= 0 ? 1 : quantity;
    final safeUnitPrice = unitPrice < 0 ? 0 : unitPrice;
    final totalPrice = (safeQuantity * safeUnitPrice).toDouble();
    final now = DateTime.now();
    final millis = now.millisecondsSinceEpoch.toString();
    final shortSeed = millis.length > 8
        ? millis.substring(millis.length - 8)
        : millis;

    final normalizedExternalRef = (externalOrderReference ?? '')
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9-]'), '');
    final orderNumber = normalizedExternalRef.isEmpty
        ? 'IBUL-EXT-$shortSeed'
        : 'IBUL-EXT-$normalizedExternalRef-$shortSeed';
    final productCode = normalizedExternalRef.isEmpty
        ? 'EXT-$shortSeed'
        : 'EXT-$normalizedExternalRef';

    Map<String, dynamic>? resolvedStoreRow;
    var resolvedStoreName = (storeName ?? '').trim();
    if (resolvedStoreName.isEmpty) {
      try {
        final storeRow = await _supabase
            .from('stores')
            .select('business_name, store_lat, store_lng')
            .eq('seller_id', normalizedSellerId)
            .limit(1)
            .maybeSingle();
        if (storeRow != null) {
          resolvedStoreRow = Map<String, dynamic>.from(storeRow as Map);
        }
        resolvedStoreName = (storeRow?['business_name']?.toString() ?? '')
            .trim();
      } catch (e) {
        debugPrint('OrderService external order store lookup warn: $e');
      }
    }
    if (resolvedStoreName.isEmpty) {
      resolvedStoreName = 'Harici Sipariş';
    }

    final deliveryLat = customerLat;
    final deliveryLng = customerLng;

    final addressPayload = <String, dynamic>{
      'fullName': normalizedCustomerName,
      'name': normalizedCustomerName,
      'phone': normalizedCustomerPhone,
      'address': normalizedCustomerAddress,
      'detail': normalizedCustomerAddress,
      'city': city.trim(),
      'district': district.trim(),
      'lat': ?customerLat,
      'latitude': ?customerLat,
      'lng': ?customerLng,
      'longitude': ?customerLng,
      if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
    };

    final deliveryPricing = _calculateDeliveryPricing(
      sourceType: 'external_manual',
      sellerSubtotalMap: {normalizedSellerId: totalPrice},
      storesBySellerId: {
        normalizedSellerId: {
          'seller_id': normalizedSellerId,
          'business_name': resolvedStoreName,
          'store_lat': resolvedStoreRow?['store_lat'],
          'store_lng': resolvedStoreRow?['store_lng'],
        },
      },
      deliveryAddress: {
        ...addressPayload,
        if (deliveryLat != null && deliveryLat != 0) 'lat': deliveryLat,
        if (deliveryLat != null && deliveryLat != 0) 'latitude': deliveryLat,
        if (deliveryLng != null && deliveryLng != 0) 'lng': deliveryLng,
        if (deliveryLng != null && deliveryLng != 0) 'longitude': deliveryLng,
      },
      now: now,
    );
    final sellerDeliveryFee =
        (deliveryPricing['seller_delivery_fee'] as double?) ?? 0.0;
    final totalDeliveryFee =
        (deliveryPricing['total_delivery_fee'] as double?) ?? 0.0;

    Map<String, dynamic>? orderRow;
    String? orderId;
    Map<String, dynamic>? walletHold;
    try {
      final baseInsert = <String, dynamic>{
        'user_id': normalizedSellerId,
        'order_number': orderNumber,
        'status': 'confirmed',
        'payment_method': 'external',
        'payment_card_name': 'Harici kanal',
        'payment_card_last4': '0000',
        'delivery_type': deliveryType,
        'delivery_slot': 'Harici Sipariş',
        'delivery_address': addressPayload,
        'subtotal_amount': totalPrice,
        'shipping_amount': 0,
        'discount_amount': 0,
        'total_amount': totalPrice,
        'currency': 'TRY',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      final extendedInsert = <String, dynamic>{
        ...baseInsert,
        'total_delivery_fee': totalDeliveryFee,
        'customer_delivery_fee': 0,
        'seller_delivery_fee': sellerDeliveryFee,
        'wallet_reserve_status': 'none',
      };

      try {
        final inserted = await _supabase
            .from('orders')
            .insert(extendedInsert)
            .select(
              'id, order_number, created_at, total_amount, status, shipping_amount, total_delivery_fee, customer_delivery_fee, seller_delivery_fee, wallet_reserve_status',
            )
            .single();
        orderRow = Map<String, dynamic>.from(inserted as Map);
      } catch (error) {
        if (!_isMissingDeliveryColumnsError(error)) rethrow;
        final inserted = await _supabase
            .from('orders')
            .insert(baseInsert)
            .select(
              'id, order_number, created_at, total_amount, status, shipping_amount',
            )
            .single();
        orderRow = Map<String, dynamic>.from(inserted as Map);
      }

      orderId = orderRow['id'].toString();
      final trackingNumber = _buildTrackingNumber(orderNumber, 0);
      final insertedItems = await _supabase
          .from('order_items')
          .insert({
            'order_id': orderId,
            'seller_id': normalizedSellerId,
            'product_id': null,
            'product_code': productCode,
            'product_name': normalizedProductName,
            'store_name': resolvedStoreName,
            'product_image_url': null,
            'attributes': <String>[
              'Harici sipariş',
              if (normalizedExternalRef.isNotEmpty)
                'Harici referans: $normalizedExternalRef',
            ],
            'quantity': safeQuantity,
            'unit_price': safeUnitPrice,
            'total_price': totalPrice,
            'status': 'ready_to_ship',
            'shipment_step': 'ready_to_ship',
            'cargo_company': cargoCompany,
            'tracking_number': trackingNumber,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .select(
            'id, order_id, seller_id, product_name, product_code, quantity, total_price, unit_price, status, store_name, created_at, tracking_number, cargo_company, shipment_step, product_image_url',
          );

      final insertedItem = List<Map<String, dynamic>>.from(
        insertedItems as List,
      ).first;

      try {
        await _supabase.from('order_item_status_history').insert({
          'order_item_id': insertedItem['id'],
          'status': 'ready_to_ship',
          'title': 'Harici sipariş İHIZ akışına eklendi',
          'description':
              'Satıcı panelinden girilen harici sipariş kurye havuzuna hazırlandı.',
          'tracking_number': trackingNumber,
          'cargo_company': cargoCompany,
          'created_at': now.toIso8601String(),
        });
      } catch (e) {
        debugPrint('OrderService external order history warn: $e');
      }

      if (sellerDeliveryFee > 0) {
        walletHold = await _reserveSellerWalletForDelivery(
          sellerId: normalizedSellerId,
          amount: sellerDeliveryFee,
          referenceId: orderId,
          sourceType: 'external_manual',
          idempotencyKey: _buildWalletIdempotencyKey(
            prefix: 'reserve',
            referenceId: orderId,
            sellerId: normalizedSellerId,
          ),
          metadata: {
            'source': 'seller_external_order',
            'store_name': resolvedStoreName,
            'order_number': orderNumber,
          },
        );
        try {
          await _supabase
              .from('orders')
              .update({'wallet_reserve_status': 'reserved'})
              .eq('id', orderId);
          orderRow['wallet_reserve_status'] = 'reserved';
        } catch (_) {}
      }

      return {
        ...orderRow,
        'delivery_address': addressPayload,
        'items': [insertedItem],
        'delivery_pricing': deliveryPricing,
        'wallet_hold': ?walletHold,
      };
    } catch (error) {
      if (walletHold != null) {
        await _releaseReservedWalletHolds(
          holds: [walletHold],
          reason: 'External order create rollback',
        );
      }
      if (orderId != null && orderId.isNotEmpty) {
        try {
          await _supabase.from('order_items').delete().eq('order_id', orderId);
          await _supabase.from('orders').delete().eq('id', orderId);
        } catch (_) {}
      }
      throw Exception(_mapWalletError(error));
    }
  }

  Future<List<Map<String, dynamic>>> getUserOrders(String userId) async {
    final List<dynamic> orders = await _supabase
        .from('orders')
        .select(
          'id, order_number, status, total_amount, created_at, delivery_address',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    if (orders.isEmpty) return [];

    final orderIds = orders
        .map((e) => e['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    final orderIdSet = orderIds.toSet();
    final List<dynamic> items = await _supabase
        .from('order_items')
        .select(
          'id, order_id, product_name, store_name, product_image_url, quantity, total_price, unit_price, status, product_code, tracking_number, cargo_company, shipment_step, seller_id',
        )
        .inFilter('order_id', orderIds)
        .order('created_at', ascending: false);
    final latestReturnRequestsByItem = await _getLatestReturnRequestsByBuyer(
      userId: userId,
    );

    final Map<String, List<Map<String, dynamic>>> groupedItems = {};
    for (final raw in items) {
      final map = Map<String, dynamic>.from(raw as Map);
      final itemId = map['id']?.toString() ?? '';
      final returnRequest = latestReturnRequestsByItem[itemId];
      if (returnRequest != null) {
        map['status'] = _resolveOrderItemStatusByReturnRequest(
          currentStatus: map['status']?.toString(),
          returnRequestStatus: returnRequest['status']?.toString(),
        );
        map['return_request_id'] = returnRequest['id']?.toString();
      }
      final oid = map['order_id'].toString();
      groupedItems.putIfAbsent(oid, () => []).add(map);
    }

    for (final request in latestReturnRequestsByItem.values) {
      final orderId = request['order_id']?.toString() ?? '';
      final orderItemId = request['order_item_id']?.toString() ?? '';
      if (orderId.isEmpty ||
          orderItemId.isEmpty ||
          !orderIdSet.contains(orderId)) {
        continue;
      }
      final itemsForOrder = groupedItems.putIfAbsent(
        orderId,
        () => <Map<String, dynamic>>[],
      );
      final exists = itemsForOrder.any(
        (item) => (item['id']?.toString() ?? '') == orderItemId,
      );
      if (exists) continue;
      final syntheticStatus = _resolveOrderItemStatusByReturnRequest(
        currentStatus: null,
        returnRequestStatus: request['status']?.toString(),
      );
      itemsForOrder.add({
        'id': orderItemId,
        'order_id': orderId,
        'product_name': request['product_name']?.toString() ?? 'Ürün',
        'store_name': request['store_name']?.toString() ?? 'Mağaza',
        'product_image_url': request['product_image_url']?.toString(),
        'quantity': 1,
        'total_price': 0,
        'unit_price': 0,
        'status': syntheticStatus,
        'product_code': null,
        'tracking_number': null,
        'cargo_company': 'ihız',
        'shipment_step': _shipmentStepFromStatus(syntheticStatus),
        'seller_id': request['seller_id']?.toString(),
        'return_request_id': request['id']?.toString(),
      });
    }

    return orders.map((o) {
      final orderMap = Map<String, dynamic>.from(o as Map);
      final oid = orderMap['id'].toString();
      return {
        ...orderMap,
        'items': groupedItems[oid] ?? <Map<String, dynamic>>[],
      };
    }).toList();
  }

  Future<void> submitReturnRequest({
    required String userId,
    required String orderId,
    required String orderItemId,
    required String reason,
    required List<String> issueTags,
    required String detail,
    required String damageLevel,
    required String damageDescription,
    required List<String> evidenceImageDataUrls,
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedItemId = orderItemId.trim();
    final normalizedReason = reason.trim();
    final normalizedDetail = detail.trim();
    final normalizedDamageLevel = damageLevel.trim().isEmpty
        ? 'belirsiz'
        : damageLevel.trim();
    final normalizedDamageDescription = damageDescription.trim();
    if (normalizedOrderId.isEmpty || normalizedItemId.isEmpty) {
      throw Exception('İade talebi için sipariş bilgisi eksik.');
    }
    if (normalizedReason.isEmpty) {
      throw Exception('Lütfen iade nedenini seçin.');
    }

    final orderRow = await _supabase
        .from('orders')
        .select('id, user_id, order_number')
        .eq('id', normalizedOrderId)
        .eq('user_id', userId)
        .maybeSingle();
    if (orderRow == null) {
      throw Exception('Bu sipariş için iade talebi oluşturma yetkiniz yok.');
    }

    final itemRow = await _supabase
        .from('order_items')
        .select(
          'id, order_id, seller_id, status, product_name, store_name, product_image_url',
        )
        .eq('id', normalizedItemId)
        .eq('order_id', normalizedOrderId)
        .maybeSingle();
    if (itemRow == null) {
      throw Exception('İade talebi oluşturulacak ürün bulunamadı.');
    }

    final currentStatus = (itemRow['status'] ?? '').toString().toLowerCase();
    if (currentStatus != 'delivered' && !_isReturnFlowStatus(currentStatus)) {
      throw Exception(
        'Bu ürün için iade talebi yalnızca teslim edilen siparişlerde açılabilir.',
      );
    }
    if (_isReturnFlowStatus(currentStatus)) {
      throw Exception('Bu ürün için zaten aktif bir iade süreci bulunuyor.');
    }

    final nowIso = DateTime.now().toIso8601String();
    final sellerDecisionDueAt = DateTime.now()
        .add(const Duration(days: 3))
        .toIso8601String();
    final sellerId = itemRow['seller_id']?.toString().trim() ?? '';
    final productName = (itemRow['product_name'] ?? 'Ürün').toString();
    final storeName = (itemRow['store_name'] ?? 'Mağaza').toString();

    List<String> evidenceImageUrls = [];
    if (evidenceImageDataUrls.isNotEmpty) {
      evidenceImageUrls = await _uploadReturnEvidenceImages(
        userId: userId,
        orderItemId: normalizedItemId,
        images: evidenceImageDataUrls,
      );
    }

    final openReturnStatuses = <String>[
      'pending_seller_review',
      'awaiting_customer_pickup_slot',
      'pickup_scheduled',
      'reported_to_ibul',
    ];
    final existingOpenRow = await _supabase
        .from('order_item_return_requests')
        .select('id, status')
        .eq('order_item_id', normalizedItemId)
        .inFilter('status', openReturnStatuses)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    String requestStatusForOrderItem = 'pending_seller_review';
    String returnRequestId = '';
    var createdNewRequest = false;
    if (existingOpenRow != null) {
      final existingOpen = Map<String, dynamic>.from(existingOpenRow as Map);
      requestStatusForOrderItem = (existingOpen['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      returnRequestId = (existingOpen['id'] ?? '').toString();
      if (requestStatusForOrderItem == 'pending_seller_review') {
        await _supabase
            .from('order_item_return_requests')
            .update({
              'reason': normalizedReason,
              'issue_tags': issueTags,
              'detail': normalizedDetail,
              'damage_level': normalizedDamageLevel,
              'damage_description': normalizedDamageDescription,
              'evidence_image_urls': evidenceImageUrls,
              'seller_decision_due_at': sellerDecisionDueAt,
              'updated_at': nowIso,
            })
            .eq('id', returnRequestId)
            .eq('buyer_user_id', userId);
      } else {
        throw Exception('Bu ürün için zaten aktif bir iade süreci bulunuyor.');
      }
    } else {
      try {
        final insertedReturnRequest = await _supabase
            .from('order_item_return_requests')
            .insert({
              'order_id': normalizedOrderId,
              'order_item_id': normalizedItemId,
              'buyer_user_id': userId,
              'seller_id': sellerId.isEmpty ? null : sellerId,
              'store_name': storeName,
              'product_name': productName,
              'product_image_url': itemRow['product_image_url']?.toString(),
              'reason': normalizedReason,
              'issue_tags': issueTags,
              'detail': normalizedDetail,
              'damage_level': normalizedDamageLevel,
              'damage_description': normalizedDamageDescription,
              'evidence_image_urls': evidenceImageUrls,
              'status': 'pending_seller_review',
              'seller_decision': 'pending',
              'seller_decision_due_at': sellerDecisionDueAt,
              'courier_dispatch_status': 'not_scheduled',
              'created_at': nowIso,
              'updated_at': nowIso,
            })
            .select('id')
            .single();
        returnRequestId = insertedReturnRequest['id']?.toString() ?? '';
        createdNewRequest = true;
      } on PostgrestException catch (error) {
        final message = error.message.toLowerCase();
        if (error.code == '23505' || message.contains('duplicate key')) {
          throw Exception(
            'Bu ürün için zaten açık bir iade talebiniz var. İzleme ekranından süreci takip edebilirsiniz.',
          );
        }
        rethrow;
      }
    }

    final nextOrderItemStatus = _returnFlowStatusFromRequestStatus(
      requestStatusForOrderItem,
    );
    final updatedRows = await _supabase
        .from('order_items')
        .update({
          'status': nextOrderItemStatus,
          'shipment_step': _shipmentStepFromStatus(nextOrderItemStatus),
          'cargo_company': 'ihız',
          'updated_at': nowIso,
        })
        .eq('id', normalizedItemId)
        .eq('order_id', normalizedOrderId)
        .select('id');
    if ((updatedRows as List).isEmpty) {
      throw Exception('İade talebi kaydedilemedi.');
    }

    final issueText = issueTags.isEmpty ? 'Belirtilmedi' : issueTags.join(', ');
    final detailText = normalizedDetail.isEmpty
        ? 'Ek açıklama girilmedi.'
        : normalizedDetail;
    final damageText = normalizedDamageDescription.isEmpty
        ? 'Detay girilmedi.'
        : normalizedDamageDescription;
    final historyDescription =
        'İade No: ${returnRequestId.isEmpty ? '-' : returnRequestId}\n'
        'Neden: $normalizedReason\n'
        'Sorun etiketleri: $issueText\n'
        'Hasar seviyesi: $normalizedDamageLevel\n'
        'Hasar tespit notu: $damageText\n'
        'Müşteri notu: $detailText\n'
        'Kanıt görselleri: ${evidenceImageUrls.length} adet';

    try {
      await addOrderItemHistoryEntry(
        orderItemId: normalizedItemId,
        status: nextOrderItemStatus,
        title: createdNewRequest
            ? 'İade talebi oluşturuldu'
            : 'İade talebi güncellendi',
        description: historyDescription,
        cargoCompany: 'ihız',
      );
    } catch (e) {
      debugPrint('OrderService.submitReturnRequest history warn: $e');
    }

    await _syncParentOrderStatus(normalizedOrderId);

    if (createdNewRequest) {
      try {
        await _supabase.from('user_notifications').insert({
          'user_id': userId,
          'title': 'İade talebin alındı',
          'body':
              '$storeName mağazasından aldığın $productName ürünü için iade talebin iHız paneline iletildi.',
          'data': {
            'type': 'return_request',
            'order_id': normalizedOrderId,
            'order_item_id': normalizedItemId,
            'return_request_id': returnRequestId,
            'status': nextOrderItemStatus,
            'reason': normalizedReason,
            'issue_tags': issueTags,
            'damage_level': normalizedDamageLevel,
            'damage_description': damageText,
            'evidence_image_urls': evidenceImageUrls,
            'detail': detailText,
            'seller_decision_due_at': sellerDecisionDueAt,
            'open_tab': 'tracking',
          },
          'created_at': nowIso,
        });
      } catch (e) {
        debugPrint('OrderService.submitReturnRequest notification warn: $e');
      }

      if (sellerId.isNotEmpty) {
        try {
          await _supabase.from('user_notifications').insert({
            'user_id': sellerId,
            'title': 'Yeni iade talebi',
            'body':
                '$storeName için $productName ürününe iade talebi açıldı. En geç 3 iş günü içinde değerlendirin.',
            'data': {
              'type': 'seller_return_request',
              'order_id': normalizedOrderId,
              'order_item_id': normalizedItemId,
              'return_request_id': returnRequestId,
              'status': 'pending_seller_review',
              'reason': normalizedReason,
              'issue_tags': issueTags,
              'damage_level': normalizedDamageLevel,
              'damage_description': damageText,
              'evidence_image_urls': evidenceImageUrls,
              'detail': detailText,
              'seller_decision_due_at': sellerDecisionDueAt,
              'open_tab': 'orders',
            },
            'created_at': nowIso,
          });
        } catch (e) {
          debugPrint('OrderService.submitReturnRequest seller notify warn: $e');
        }
      }
    }
  }

  Future<Map<String, dynamic>?> getLatestReturnRequestForItem({
    required String orderItemId,
  }) async {
    final normalizedItemId = orderItemId.trim();
    if (normalizedItemId.isEmpty) return null;
    try {
      final row = await _supabase
          .from('order_item_return_requests')
          .select()
          .eq('order_item_id', normalizedItemId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return _normalizeReturnRequest(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      debugPrint('OrderService.getLatestReturnRequestForItem warn: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getReturnRequestById(
    String returnRequestId,
  ) async {
    final normalizedId = returnRequestId.trim();
    if (normalizedId.isEmpty) return null;
    try {
      final row = await _supabase
          .from('order_item_return_requests')
          .select()
          .eq('id', normalizedId)
          .maybeSingle();
      if (row == null) return null;
      return _normalizeReturnRequest(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      debugPrint('OrderService.getReturnRequestById warn: $e');
      return null;
    }
  }

  Future<void> sellerReviewReturnRequest({
    required String sellerId,
    required String returnRequestId,
    required String decision,
    String note = '',
  }) async {
    final normalizedSellerId = sellerId.trim();
    final normalizedReturnRequestId = returnRequestId.trim();
    final normalizedDecision = decision.trim().toLowerCase();
    final normalizedNote = note.trim();

    if (normalizedSellerId.isEmpty || normalizedReturnRequestId.isEmpty) {
      throw Exception('İade inceleme bilgisi eksik.');
    }
    if (normalizedDecision != 'approve' &&
        normalizedDecision != 'reject' &&
        normalizedDecision != 'report_to_ibul') {
      throw Exception('Geçersiz iade kararı.');
    }

    final requestRow = await _supabase
        .from('order_item_return_requests')
        .select()
        .eq('id', normalizedReturnRequestId)
        .maybeSingle();
    if (requestRow == null) {
      throw Exception('İade talebi bulunamadı.');
    }
    final request = _normalizeReturnRequest(
      Map<String, dynamic>.from(requestRow as Map),
    );

    final requestSellerId = request['seller_id']?.toString().trim() ?? '';
    if (requestSellerId.isEmpty || requestSellerId != normalizedSellerId) {
      throw Exception('Bu iade talebini değerlendirme yetkiniz yok.');
    }

    final currentStatus = request['status']?.toString().trim().toLowerCase();
    if (currentStatus == 'rejected_by_seller' ||
        currentStatus == 'closed_refunded' ||
        currentStatus == 'cancelled_by_ibul') {
      throw Exception('Kapatılmış iade talebi tekrar değerlendirilemez.');
    }

    final nowIso = DateTime.now().toIso8601String();
    final orderId = request['order_id']?.toString() ?? '';
    final orderItemId = request['order_item_id']?.toString() ?? '';
    final buyerUserId = request['buyer_user_id']?.toString() ?? '';
    final productName = request['product_name']?.toString() ?? 'Ürün';
    final storeName = request['store_name']?.toString() ?? 'Mağaza';
    String orderDeliveryType = '';
    if (orderId.isNotEmpty) {
      try {
        final orderRow = await _supabase
            .from('orders')
            .select('delivery_type')
            .eq('id', orderId)
            .maybeSingle();
        orderDeliveryType = orderRow?['delivery_type']?.toString() ?? '';
      } catch (_) {}
    }
    final resolutionText = normalizedNote.isEmpty
        ? 'Satıcı notu eklenmedi.'
        : normalizedNote;

    String nextRequestStatus;
    String sellerDecision;
    String nextOrderItemStatus;
    String historyTitle;
    String historyDescription;
    String buyerTitle;
    String buyerBody;

    if (normalizedDecision == 'approve') {
      nextRequestStatus = 'awaiting_customer_pickup_slot';
      sellerDecision = 'approved';
      nextOrderItemStatus = 'return_approved';
      historyTitle = 'İade talebi onaylandı';
      historyDescription =
          'Satıcı iade talebini onayladı. Müşteri, iHız kurye alımı için gün/saat aralığı seçecek.\n'
          'Satıcı notu: $resolutionText';
      buyerTitle = 'İade talebin onaylandı';
      buyerBody =
          '$storeName mağazası iade talebini onayladı. İadeniz kabul edildi, tarih seçerek iade ediniz.';
    } else if (normalizedDecision == 'reject') {
      if (normalizedNote.isEmpty) {
        throw Exception('İBUL incelemesine yönlendirme için açıklama zorunlu.');
      }
      nextRequestStatus = 'awaiting_ibul_review';
      sellerDecision = 'rejection_requested';
      nextOrderItemStatus = 'return_requested';
      historyTitle = 'Satıcı iade red talebini İBUL incelemesine gönderdi';
      historyDescription =
          'Satıcı iade talebini doğrudan reddetmedi; red talebini İBUL incelemesine gönderdi.\n'
          'Satıcı notu: $resolutionText';
      buyerTitle = 'İade talebin İBUL incelemesinde';
      buyerBody =
          '$storeName mağazası iade red talebini İBUL incelemesine gönderdi. Son kararı İBUL verecek.';
    } else {
      if (normalizedNote.isEmpty) {
        throw Exception('İBUL\'a bildirim için açıklama zorunlu.');
      }
      nextRequestStatus = 'awaiting_ibul_review';
      sellerDecision = 'rejection_requested';
      nextOrderItemStatus = 'return_requested';
      historyTitle = 'İade talebi İBUL incelemesine alındı';
      historyDescription =
          'Satıcı, iade talebini İBUL incelemesine yönlendirdi.\n'
          'Satıcı notu: $resolutionText';
      buyerTitle = 'İade talebin İBUL incelemesinde';
      buyerBody =
          '$storeName mağazası talebi İBUL incelemesine yönlendirdi. Kısa süre içinde ek bilgilendirme alacaksın.';
    }

    await _supabase
        .from('order_item_return_requests')
        .update({
          'status': nextRequestStatus,
          'seller_decision': sellerDecision,
          'seller_decision_note': resolutionText,
          'seller_decided_at': nowIso,
          'updated_at': nowIso,
          if (normalizedDecision == 'report_to_ibul' ||
              normalizedDecision == 'reject')
            'seller_will_receive_product': false,
        })
        .eq('id', normalizedReturnRequestId);

    await _supabase
        .from('order_items')
        .update({
          'status': nextOrderItemStatus,
          'shipment_step': _shipmentStepFromStatus(nextOrderItemStatus),
          'updated_at': nowIso,
        })
        .eq('id', orderItemId);

    await addOrderItemHistoryEntry(
      orderItemId: orderItemId,
      status: _shipmentStepFromStatus(nextOrderItemStatus),
      title: historyTitle,
      description: historyDescription,
      cargoCompany: 'ihız',
      extraData: {
        'return_request_id': normalizedReturnRequestId,
        'return_status': nextRequestStatus,
      },
    );
    await _syncParentOrderStatus(orderId);

    if (buyerUserId.isNotEmpty) {
      await _supabase.from('user_notifications').insert({
        'user_id': buyerUserId,
        'title': buyerTitle,
        'body': buyerBody,
        'data': {
          'type': 'return_reviewed',
          'order_id': orderId,
          'order_item_id': orderItemId,
          'return_request_id': normalizedReturnRequestId,
          'status': nextRequestStatus,
          'decision': sellerDecision,
          'note': resolutionText,
          'delivery_type': orderDeliveryType,
          'open_tab': 'tracking',
        },
        'created_at': nowIso,
      });
    }

    if (normalizedDecision == 'report_to_ibul' ||
        normalizedDecision == 'reject') {
      await _notifyAdminsForReturnCase(
        returnRequestId: normalizedReturnRequestId,
        orderId: orderId,
        orderItemId: orderItemId,
        storeName: storeName,
        productName: productName,
        note: resolutionText,
      );
    }
  }

  Future<void> scheduleReturnPickupWindow({
    required String userId,
    required String returnRequestId,
    required DateTime pickupWindowStart,
    required DateTime pickupWindowEnd,
    String note = '',
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedReturnRequestId = returnRequestId.trim();
    final normalizedNote = note.trim();
    if (normalizedUserId.isEmpty || normalizedReturnRequestId.isEmpty) {
      throw Exception('Kurye zamanlama bilgisi eksik.');
    }
    if (!pickupWindowEnd.isAfter(pickupWindowStart)) {
      throw Exception('Bitiş saati başlangıç saatinden sonra olmalı.');
    }
    if (pickupWindowStart.isBefore(DateTime.now())) {
      throw Exception('Kurye alım başlangıcı şu andan ileri bir zaman olmalı.');
    }

    final requestRow = await _supabase
        .from('order_item_return_requests')
        .select()
        .eq('id', normalizedReturnRequestId)
        .maybeSingle();
    if (requestRow == null) {
      throw Exception('İade kaydı bulunamadı.');
    }
    final request = _normalizeReturnRequest(
      Map<String, dynamic>.from(requestRow as Map),
    );
    final buyerUserId = request['buyer_user_id']?.toString() ?? '';
    if (buyerUserId != normalizedUserId) {
      throw Exception('Bu iade kaydı için zamanlama yetkiniz yok.');
    }
    final requestStatus = request['status']?.toString().toLowerCase() ?? '';
    if (requestStatus != 'awaiting_customer_pickup_slot' &&
        requestStatus != 'pickup_scheduled') {
      throw Exception(
        'Kurye zamanı seçimi için iade talebinin satıcı tarafından onaylanması gerekir.',
      );
    }

    final orderId = request['order_id']?.toString() ?? '';
    final orderItemId = request['order_item_id']?.toString() ?? '';
    final sellerId = request['seller_id']?.toString() ?? '';
    final storeName = request['store_name']?.toString() ?? 'Mağaza';
    final productName = request['product_name']?.toString() ?? 'Ürün';
    final nowIso = DateTime.now().toIso8601String();
    final pickupWindowStartUtcIso = pickupWindowStart.toUtc().toIso8601String();
    final pickupWindowEndUtcIso = pickupWindowEnd.toUtc().toIso8601String();

    final orderRow = await _supabase
        .from('orders')
        .select('id, delivery_address, delivery_type')
        .eq('id', orderId)
        .maybeSingle();
    final deliveryAddress = _asJsonMap(orderRow?['delivery_address']);
    final orderDeliveryType = orderRow?['delivery_type']?.toString() ?? '';
    if (!_isNearDistanceDeliveryType(orderDeliveryType)) {
      throw Exception(
        'Bu iade için kurye çağırma kullanılamaz. Ürünü şubeden satıcıya göndermeniz gerekiyor.',
      );
    }

    final existingTaskRowsRaw = await _supabase
        .from('ihiz_return_pickup_tasks')
        .select('id, status, assigned_courier_id, picked_up_at, delivered_at')
        .eq('return_request_id', normalizedReturnRequestId)
        .order('created_at', ascending: true);
    final existingTaskRows = List<Map<String, dynamic>>.from(
      existingTaskRowsRaw as List,
    );
    final hasCourierStartedTask = existingTaskRows.any((raw) {
      final row = Map<String, dynamic>.from(raw);
      final status = (row['status']?.toString() ?? '').trim().toLowerCase();
      final assignedCourierId = (row['assigned_courier_id']?.toString() ?? '')
          .trim();
      return status == 'assigned' ||
          status == 'picked_up' ||
          status == 'pickedup' ||
          status == 'in_transit' ||
          status == 'delivered' ||
          status == 'completed' ||
          assignedCourierId.isNotEmpty ||
          row['picked_up_at'] != null ||
          row['delivered_at'] != null;
    });
    if (hasCourierStartedTask) {
      throw Exception(
        'Kurye görevi başladıktan sonra iade zamanı güncellenemez.',
      );
    }
    if (existingTaskRows.length >= 2) {
      throw Exception('Kurye zamanını yalnızca 1 kez güncelleyebilirsin.');
    }
    if (existingTaskRows.isNotEmpty) {
      await _supabase
          .from('ihiz_return_pickup_tasks')
          .update({'status': 'rescheduled', 'updated_at': nowIso})
          .eq('return_request_id', normalizedReturnRequestId)
          .eq('status', 'queued');
    }

    await _supabase
        .from('order_item_return_requests')
        .update({
          'status': 'pickup_scheduled',
          'customer_pickup_slot_start': pickupWindowStartUtcIso,
          'customer_pickup_slot_end': pickupWindowEndUtcIso,
          'buyer_pickup_note': normalizedNote.isEmpty ? null : normalizedNote,
          'courier_dispatch_status': 'queued',
          'updated_at': nowIso,
        })
        .eq('id', normalizedReturnRequestId);

    if (orderItemId.isNotEmpty) {
      await _supabase
          .from('order_items')
          .update({
            'status': 'return_approved',
            'shipment_step': 'return_pickup_scheduled',
            'cargo_company': 'ihız',
            'updated_at': nowIso,
          })
          .eq('id', orderItemId);
    }

    await _supabase.from('ihiz_return_pickup_tasks').insert({
      'return_request_id': normalizedReturnRequestId,
      'order_id': orderId,
      'order_item_id': orderItemId,
      'buyer_user_id': normalizedUserId,
      'seller_id': sellerId.isEmpty ? null : sellerId,
      'pickup_window_start': pickupWindowStartUtcIso,
      'pickup_window_end': pickupWindowEndUtcIso,
      'pickup_address': deliveryAddress,
      'dropoff_store_name': storeName,
      'status': 'queued',
      'note': normalizedNote.isEmpty ? null : normalizedNote,
      'created_at': nowIso,
      'updated_at': nowIso,
    });

    await addOrderItemHistoryEntry(
      orderItemId: orderItemId,
      status: 'return_pickup_scheduled',
      title: 'İade kurye alım zamanı planlandı',
      description:
          'Müşteri iHız kurye alımı için ${_formatDateTimeText(pickupWindowStart)} - ${_formatDateTimeText(pickupWindowEnd)} aralığını seçti.',
      cargoCompany: 'ihız',
      extraData: {
        'return_request_id': normalizedReturnRequestId,
        'pickup_window_start': pickupWindowStartUtcIso,
        'pickup_window_end': pickupWindowEndUtcIso,
      },
    );

    if (sellerId.isNotEmpty) {
      await _supabase.from('user_notifications').insert({
        'user_id': sellerId,
        'title': 'İade kurye zamanı seçildi',
        'body':
            '$productName ürünü için iade alım zamanı planlandı. iHız kurye havuzuna görev aktarıldı.',
        'data': {
          'type': 'return_pickup_scheduled',
          'order_id': orderId,
          'order_item_id': orderItemId,
          'return_request_id': normalizedReturnRequestId,
          'pickup_window_start': pickupWindowStartUtcIso,
          'pickup_window_end': pickupWindowEndUtcIso,
          'open_tab': 'orders',
        },
        'created_at': nowIso,
      });
    }

    await _supabase.from('user_notifications').insert({
      'user_id': normalizedUserId,
      'title': 'İade kurye alımı planlandı',
      'body':
          '$storeName mağazası için iade alım zamanın sisteme işlendi. iHız kurye seçtiğin aralıkta adrese gelecek.',
      'data': {
        'type': 'return_pickup_scheduled',
        'order_id': orderId,
        'order_item_id': orderItemId,
        'return_request_id': normalizedReturnRequestId,
        'pickup_window_start': pickupWindowStartUtcIso,
        'pickup_window_end': pickupWindowEndUtcIso,
        'open_tab': 'tracking',
      },
      'created_at': nowIso,
    });

    await _queueCourierPickupDueNotifications(
      returnRequestId: normalizedReturnRequestId,
      orderId: orderId,
      orderItemId: orderItemId,
      storeName: storeName,
      productName: productName,
      pickupWindowStart: pickupWindowStart,
      pickupWindowEnd: pickupWindowEnd,
      createdByUserId: normalizedUserId,
      sellerId: sellerId,
      pickupAddress: deliveryAddress,
      note: normalizedNote,
    );
  }

  Future<void> resolveReportedReturnByIbul({
    required String returnRequestId,
    required bool approveSellerRejection,
    required String resolutionNote,
  }) async {
    final normalizedId = returnRequestId.trim();
    final normalizedNote = resolutionNote.trim();
    if (normalizedId.isEmpty) {
      throw Exception('İade dosyası bulunamadı.');
    }
    if (normalizedNote.isEmpty) {
      throw Exception('İBUL çözüm notu zorunludur.');
    }

    final requestRow = await _supabase
        .from('order_item_return_requests')
        .select()
        .eq('id', normalizedId)
        .maybeSingle();
    if (requestRow == null) {
      throw Exception('İade dosyası bulunamadı.');
    }
    final request = _normalizeReturnRequest(
      Map<String, dynamic>.from(requestRow as Map),
    );

    final nowIso = DateTime.now().toIso8601String();
    final orderItemId = request['order_item_id']?.toString() ?? '';
    final orderId = request['order_id']?.toString() ?? '';
    final buyerUserId = request['buyer_user_id']?.toString() ?? '';
    final sellerUserId = request['seller_id']?.toString() ?? '';
    final productName = request['product_name']?.toString() ?? 'Ürün';
    final storeName = request['store_name']?.toString() ?? 'Mağaza';
    String orderDeliveryType = '';
    if (orderId.isNotEmpty) {
      try {
        final orderRow = await _supabase
            .from('orders')
            .select('delivery_type')
            .eq('id', orderId)
            .maybeSingle();
        orderDeliveryType = orderRow?['delivery_type']?.toString() ?? '';
      } catch (_) {}
    }
    final currentStatus = request['status']?.toString().toLowerCase() ?? '';
    if (currentStatus != 'awaiting_ibul_review' &&
        currentStatus != 'reported_to_ibul') {
      throw Exception('Bu iade dosyası İBUL karar aşamasında değil.');
    }

    String nextRequestStatus;
    String nextOrderStatus;
    String historyTitle;
    String buyerTitle;
    String buyerBody;
    String sellerTitle;
    String sellerBody;
    if (approveSellerRejection) {
      nextRequestStatus = 'cancelled_by_ibul';
      nextOrderStatus = 'delivered';
      historyTitle = 'İBUL iade dosyasını kapattı';
      buyerTitle = 'İadeniz reddedildi';
      buyerBody =
          '$storeName mağazası için iadeniz İBUL tarafından reddedildi. Gerekçe: $normalizedNote';
      sellerTitle = 'İade red talebiniz onaylandı';
      sellerBody =
          '$productName için açtığınız iade red talebi İBUL tarafından onaylandı.';
    } else {
      nextRequestStatus = 'awaiting_customer_pickup_slot';
      nextOrderStatus = 'return_approved';
      historyTitle = 'İBUL iade talebini satıcı onayı olmadan kabul etti';
      buyerTitle = 'İadeniz kabul edildi';
      buyerBody =
          '$storeName mağazası için iadeniz İBUL tarafından kabul edildi. Tarih seçerek iade ediniz.';
      sellerTitle = 'İade red talebiniz reddedildi';
      sellerBody =
          '$productName için iade red talebiniz İBUL tarafından reddedildi. İade süreci kullanıcı lehine onaylandı.';
    }

    await _supabase
        .from('order_item_return_requests')
        .update({
          'status': nextRequestStatus,
          'ibul_case_status': 'resolved',
          'ibul_resolution_note': normalizedNote,
          'ibul_resolved_at': nowIso,
          'updated_at': nowIso,
          if (approveSellerRejection) 'closed_at': nowIso,
        })
        .eq('id', normalizedId);

    await _supabase
        .from('order_items')
        .update({
          'status': nextOrderStatus,
          'shipment_step': _shipmentStepFromStatus(nextOrderStatus),
          'updated_at': nowIso,
        })
        .eq('id', orderItemId);
    await _syncParentOrderStatus(orderId);

    await addOrderItemHistoryEntry(
      orderItemId: orderItemId,
      status: _shipmentStepFromStatus(nextOrderStatus),
      title: historyTitle,
      description: normalizedNote,
      cargoCompany: 'ihız',
      extraData: {
        'return_request_id': normalizedId,
        'ibul_resolution': approveSellerRejection ? 'closed' : 'reopened',
      },
    );

    if (buyerUserId.isNotEmpty) {
      await _supabase.from('user_notifications').insert({
        'user_id': buyerUserId,
        'title': buyerTitle,
        'body': buyerBody,
        'data': {
          'type': 'ibul_return_resolution',
          'order_id': orderId,
          'order_item_id': orderItemId,
          'return_request_id': normalizedId,
          'status': nextRequestStatus,
          'resolution_note': normalizedNote,
          'delivery_type': orderDeliveryType,
          'open_tab': 'tracking',
        },
        'created_at': nowIso,
      });
    }
    if (sellerUserId.isNotEmpty) {
      await _supabase.from('user_notifications').insert({
        'user_id': sellerUserId,
        'title': sellerTitle,
        'body': sellerBody,
        'data': {
          'type': 'ibul_return_resolution',
          'order_id': orderId,
          'order_item_id': orderItemId,
          'return_request_id': normalizedId,
          'status': nextRequestStatus,
          'resolution_note': normalizedNote,
          'open_tab': 'orders',
        },
        'created_at': nowIso,
      });
    }
  }

  Future<List<Map<String, dynamic>>> getSellerOrders(String sellerId) async {
    String? sellerBusinessName;
    final totalWatch = Stopwatch()..start();
    final directRequestUrl = _debugRestRequestUrl(
      'order_items',
      query: <String, String>{
        'select':
            'id,order_id,seller_id,product_name,product_code,quantity,total_price,unit_price,status,store_name,created_at,tracking_number,cargo_company,shipment_step,product_image_url',
        'seller_id': 'eq.$sellerId',
        'order': 'created_at.desc',
      },
    );
    final directWatch = Stopwatch()..start();
    _debugSellerOrdersFetch(
      'order_items_direct:start',
      sellerId: sellerId,
      requestUrl: directRequestUrl,
    );
    final List<Map<String, dynamic>> itemRows = List<Map<String, dynamic>>.from(
      await _supabase
          .from('order_items')
          .select(
            'id, order_id, seller_id, product_name, product_code, quantity, total_price, unit_price, status, store_name, created_at, tracking_number, cargo_company, shipment_step, product_image_url',
          )
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false),
    );
    _debugSellerOrdersFetch(
      'order_items_direct:success',
      sellerId: sellerId,
      requestUrl: directRequestUrl,
      durationMs: directWatch.elapsedMilliseconds,
      rowCount: itemRows.length,
    );
    final seenIds = itemRows
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toSet();

    try {
      final storeRequestUrl = _debugRestRequestUrl(
        'stores',
        query: <String, String>{
          'select': 'business_name',
          'seller_id': 'eq.$sellerId',
          'limit': '1',
        },
      );
      final storeWatch = Stopwatch()..start();
      _debugSellerOrdersFetch(
        'store_lookup:start',
        sellerId: sellerId,
        requestUrl: storeRequestUrl,
      );
      final storeRow = await _supabase
          .from('stores')
          .select('business_name')
          .eq('seller_id', sellerId)
          .limit(1)
          .maybeSingle();
      _debugSellerOrdersFetch(
        'store_lookup:success',
        sellerId: sellerId,
        requestUrl: storeRequestUrl,
        durationMs: storeWatch.elapsedMilliseconds,
        rowCount: storeRow == null ? 0 : 1,
      );
      final businessName = storeRow?['business_name']?.toString().trim();
      sellerBusinessName = businessName;
      if (businessName != null && businessName.isNotEmpty) {
        final storeFallbackRequestUrl = _debugRestRequestUrl(
          'order_items',
          query: <String, String>{
            'select':
                'id,order_id,seller_id,product_name,product_code,quantity,total_price,unit_price,status,store_name,created_at,tracking_number,cargo_company,shipment_step,product_image_url',
            'store_name': 'ilike.$businessName',
            'order': 'created_at.desc',
          },
        );
        final storeFallbackWatch = Stopwatch()..start();
        _debugSellerOrdersFetch(
          'order_items_store_name_fallback:start',
          sellerId: sellerId,
          requestUrl: storeFallbackRequestUrl,
          note: 'businessName=$businessName',
        );
        final fallbackRows = List<Map<String, dynamic>>.from(
          await _supabase
              .from('order_items')
              .select(
                'id, order_id, seller_id, product_name, product_code, quantity, total_price, unit_price, status, store_name, created_at, tracking_number, cargo_company, shipment_step, product_image_url',
              )
              .ilike('store_name', businessName)
              .order('created_at', ascending: false),
        );
        _debugSellerOrdersFetch(
          'order_items_store_name_fallback:success',
          sellerId: sellerId,
          requestUrl: storeFallbackRequestUrl,
          durationMs: storeFallbackWatch.elapsedMilliseconds,
          rowCount: fallbackRows.length,
          note: 'businessName=$businessName',
        );
        for (final row in fallbackRows) {
          final rowId = row['id']?.toString();
          if (rowId == null || seenIds.contains(rowId)) continue;
          itemRows.add(row);
          seenIds.add(rowId);
        }

        final sellerProductsRequestUrl = _debugRestRequestUrl(
          'products',
          query: <String, String>{
            'select': 'id,name',
            'seller_id': 'eq.$sellerId',
          },
        );
        final sellerProductsWatch = Stopwatch()..start();
        _debugSellerOrdersFetch(
          'seller_products_lookup:start',
          sellerId: sellerId,
          requestUrl: sellerProductsRequestUrl,
        );
        final sellerProducts = List<Map<String, dynamic>>.from(
          await _supabase
              .from('products')
              .select('id, name')
              .eq('seller_id', sellerId),
        );
        _debugSellerOrdersFetch(
          'seller_products_lookup:success',
          sellerId: sellerId,
          requestUrl: sellerProductsRequestUrl,
          durationMs: sellerProductsWatch.elapsedMilliseconds,
          rowCount: sellerProducts.length,
        );
        final sellerProductIds = sellerProducts
            .map((row) => row['id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        final sellerProductNames = sellerProducts
            .map((row) => row['name']?.toString().trim())
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList();

        if (sellerProductIds.isNotEmpty) {
          final productIdRequestUrl = _debugRestRequestUrl(
            'order_items',
            query: <String, String>{
              'select':
                  'id,order_id,seller_id,product_id,product_name,product_code,quantity,total_price,unit_price,status,store_name,created_at,tracking_number,cargo_company,shipment_step,product_image_url',
              'product_id': 'in.(${sellerProductIds.length} ids)',
              'order': 'created_at.desc',
            },
          );
          final productIdWatch = Stopwatch()..start();
          _debugSellerOrdersFetch(
            'order_items_product_id_fallback:start',
            sellerId: sellerId,
            requestUrl: productIdRequestUrl,
            note: 'productIds=${sellerProductIds.length}',
          );
          final productIdRows = List<Map<String, dynamic>>.from(
            await _supabase
                .from('order_items')
                .select(
                  'id, order_id, seller_id, product_id, product_name, product_code, quantity, total_price, unit_price, status, store_name, created_at, tracking_number, cargo_company, shipment_step, product_image_url',
                )
                .inFilter('product_id', sellerProductIds)
                .order('created_at', ascending: false),
          );
          _debugSellerOrdersFetch(
            'order_items_product_id_fallback:success',
            sellerId: sellerId,
            requestUrl: productIdRequestUrl,
            durationMs: productIdWatch.elapsedMilliseconds,
            rowCount: productIdRows.length,
            note: 'productIds=${sellerProductIds.length}',
          );
          for (final row in productIdRows) {
            final rowId = row['id']?.toString();
            if (rowId == null || seenIds.contains(rowId)) continue;
            itemRows.add(row);
            seenIds.add(rowId);
          }
        }

        if (sellerProductNames.isNotEmpty) {
          final storeNameFilterValue = businessName.replaceAll(',', r'\,');
          final productNameRequestUrl = _debugRestRequestUrl(
            'order_items',
            query: <String, String>{
              'select':
                  'id,order_id,seller_id,product_id,product_name,product_code,quantity,total_price,unit_price,status,store_name,created_at,tracking_number,cargo_company,shipment_step,product_image_url',
              'product_name': 'in.(${sellerProductNames.length} names)',
              'or':
                  'seller_id.eq.$sellerId,store_name.ilike.$storeNameFilterValue',
              'order': 'created_at.desc',
            },
          );
          final productNameWatch = Stopwatch()..start();
          _debugSellerOrdersFetch(
            'order_items_product_name_fallback:start',
            sellerId: sellerId,
            requestUrl: productNameRequestUrl,
            note:
                'productNames=${sellerProductNames.length} '
                'serverFilteredBy=seller_id|store_name',
          );
          final productNameRows = List<Map<String, dynamic>>.from(
            await _supabase
                .from('order_items')
                .select(
                  'id, order_id, seller_id, product_id, product_name, product_code, quantity, total_price, unit_price, status, store_name, created_at, tracking_number, cargo_company, shipment_step, product_image_url',
                )
                .inFilter('product_name', sellerProductNames)
                .or(
                  'seller_id.eq.$sellerId,store_name.ilike.$storeNameFilterValue',
                )
                .order('created_at', ascending: false),
          );
          _debugSellerOrdersFetch(
            'order_items_product_name_fallback:success',
            sellerId: sellerId,
            requestUrl: productNameRequestUrl,
            durationMs: productNameWatch.elapsedMilliseconds,
            rowCount: productNameRows.length,
            note:
                'productNames=${sellerProductNames.length} '
                'serverFilteredBy=seller_id|store_name',
          );
          for (final row in productNameRows) {
            final rowId = row['id']?.toString();
            if (rowId == null || seenIds.contains(rowId)) continue;
            final rowStoreName = row['store_name']?.toString().trim() ?? '';
            final rowSellerId = row['seller_id']?.toString().trim() ?? '';
            final hasSellerIdMatch = rowSellerId == sellerId;
            final hasStoreNameMatch =
                rowStoreName.toLowerCase() == businessName.toLowerCase();
            final hasAnyIdentity =
                rowSellerId.isNotEmpty || rowStoreName.isNotEmpty;
            if (!hasAnyIdentity) continue;
            if (rowSellerId.isNotEmpty && !hasSellerIdMatch) continue;
            if (rowStoreName.isNotEmpty && !hasStoreNameMatch) continue;
            if (!hasSellerIdMatch && !hasStoreNameMatch) continue;
            itemRows.add(row);
            seenIds.add(rowId);
          }
        }
      }
    } catch (e) {
      _debugSellerOrdersFetch(
        'legacy_fallback:warn',
        sellerId: sellerId,
        note: 'durationMs=${totalWatch.elapsedMilliseconds}',
        error: e,
      );
    }

    final returnRequestsWatch = Stopwatch()..start();
    _debugSellerOrdersFetch(
      'return_requests_lookup:start',
      sellerId: sellerId,
      requestUrl: 'OrderService._getLatestReturnRequestsBySeller',
      note: 'businessName=${sellerBusinessName ?? '-'}',
    );
    final latestReturnRequestsByItem = await _getLatestReturnRequestsBySeller(
      sellerId: sellerId,
      businessName: sellerBusinessName,
    );
    _debugSellerOrdersFetch(
      'return_requests_lookup:success',
      sellerId: sellerId,
      requestUrl: 'OrderService._getLatestReturnRequestsBySeller',
      durationMs: returnRequestsWatch.elapsedMilliseconds,
      rowCount: latestReturnRequestsByItem.length,
      note: 'businessName=${sellerBusinessName ?? '-'}',
    );
    for (final row in itemRows) {
      final itemId = row['id']?.toString() ?? '';
      final returnRequest = latestReturnRequestsByItem[itemId];
      if (returnRequest == null) continue;
      row['status'] = _resolveOrderItemStatusByReturnRequest(
        currentStatus: row['status']?.toString(),
        returnRequestStatus: returnRequest['status']?.toString(),
      );
      row['return_request_id'] = returnRequest['id']?.toString();
    }
    for (final request in latestReturnRequestsByItem.values) {
      final orderItemId = request['order_item_id']?.toString() ?? '';
      final orderId = request['order_id']?.toString() ?? '';
      if (orderItemId.isEmpty ||
          orderId.isEmpty ||
          seenIds.contains(orderItemId)) {
        continue;
      }
      final syntheticStatus = _resolveOrderItemStatusByReturnRequest(
        currentStatus: null,
        returnRequestStatus: request['status']?.toString(),
      );
      itemRows.add({
        'id': orderItemId,
        'order_id': orderId,
        'seller_id': request['seller_id']?.toString(),
        'product_name': request['product_name']?.toString() ?? 'Ürün',
        'product_code': null,
        'quantity': 1,
        'total_price': 0,
        'unit_price': 0,
        'status': syntheticStatus,
        'store_name': request['store_name']?.toString() ?? sellerBusinessName,
        'created_at': request['created_at']?.toString(),
        'tracking_number': null,
        'cargo_company': 'ihız',
        'shipment_step': _shipmentStepFromStatus(syntheticStatus),
        'product_image_url': request['product_image_url']?.toString(),
        'return_request_id': request['id']?.toString(),
      });
      seenIds.add(orderItemId);
    }

    if (itemRows.isEmpty) return [];

    final orderIds = itemRows
        .map((e) => e['order_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    List<dynamic> orders = const <dynamic>[];
    try {
      final ordersLookupRequestUrl = _debugRestRequestUrl(
        'orders',
        query: <String, String>{
          'select':
              'id,order_number,user_id,status,total_amount,created_at,delivery_address,delivery_type,delivery_slot',
          'id': 'in.(${orderIds.length} ids)',
        },
      );
      final ordersLookupWatch = Stopwatch()..start();
      _debugSellerOrdersFetch(
        'orders_lookup:start',
        sellerId: sellerId,
        requestUrl: ordersLookupRequestUrl,
        note: 'orderIds=${orderIds.length}',
      );
      orders = await _supabase
          .from('orders')
          .select(
            'id, order_number, user_id, status, total_amount, created_at, delivery_address, delivery_type, delivery_slot',
          )
          .inFilter('id', orderIds);
      _debugSellerOrdersFetch(
        'orders_lookup:success',
        sellerId: sellerId,
        requestUrl: ordersLookupRequestUrl,
        durationMs: ordersLookupWatch.elapsedMilliseconds,
        rowCount: orders.length,
        note: 'orderIds=${orderIds.length}',
      );
    } catch (error) {
      _debugSellerOrdersFetch(
        'orders_lookup:warn',
        sellerId: sellerId,
        requestUrl: 'orders_lookup',
        durationMs: totalWatch.elapsedMilliseconds,
        error: error,
      );
      if (_isPolicyRecursionError(error)) {
        debugPrint(
          'OrderService seller orders fallback: orders policies hit recursion (42P17). Returning item-based rows.',
        );
      }
      orders = const <dynamic>[];
    }

    final customerIds = orders
        .map((e) => e['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final Map<String, Map<String, dynamic>> orderById = {};
    for (final raw in orders) {
      final map = Map<String, dynamic>.from(raw as Map);
      orderById[map['id'].toString()] = map;
    }

    final Map<String, Map<String, dynamic>> userById = {};
    if (customerIds.isNotEmpty) {
      try {
        final usersLookupRequestUrl = _debugRestRequestUrl(
          'users',
          query: <String, String>{
            'select': 'id,display_name,email,phone',
            'id': 'in.(${customerIds.length} ids)',
          },
        );
        final usersLookupWatch = Stopwatch()..start();
        _debugSellerOrdersFetch(
          'users_lookup:start',
          sellerId: sellerId,
          requestUrl: usersLookupRequestUrl,
          note: 'customerIds=${customerIds.length}',
        );
        final users = await _supabase
            .from('users')
            .select('id, display_name, email, phone')
            .inFilter('id', customerIds);
        _debugSellerOrdersFetch(
          'users_lookup:success',
          sellerId: sellerId,
          requestUrl: usersLookupRequestUrl,
          durationMs: usersLookupWatch.elapsedMilliseconds,
          rowCount: (users as List<dynamic>).length,
          note: 'customerIds=${customerIds.length}',
        );
        for (final raw in (users as List<dynamic>)) {
          final map = Map<String, dynamic>.from(raw as Map);
          userById[map['id'].toString()] = map;
        }
      } catch (e) {
        _debugSellerOrdersFetch(
          'users_lookup:warn',
          sellerId: sellerId,
          requestUrl: 'users_lookup',
          durationMs: totalWatch.elapsedMilliseconds,
          error: e,
        );
      }
    }

    final List<Map<String, dynamic>> result = [];
    for (final raw in itemRows) {
      final item = Map<String, dynamic>.from(raw as Map);
      final order = orderById[item['order_id'].toString()];
      if (order == null) {
        debugPrint(
          'OrderService seller orders skip orphan item: order_id=${item['order_id']}',
        );
        final fallbackOrderId = item['order_id']?.toString() ?? '';
        final fallbackNumber = fallbackOrderId.isEmpty
            ? '-'
            : 'IBUL-${fallbackOrderId.replaceAll('-', '').substring(0, 6).toUpperCase()}';
        result.add({
          ...item,
          'order_number': fallbackNumber,
          'order_total_amount': item['total_price'] ?? item['unit_price'] ?? 0,
          'order_status': item['status'] ?? 'new',
          'customer_id': null,
          'customer_name': 'Musteri bilgisi sinirli',
          'customer_email': null,
          'customer_phone': null,
          'order_created_at': item['created_at'],
          'delivery_address': const <String, dynamic>{},
          'delivery_type': null,
          'delivery_slot': null,
          'is_priority': false,
        });
        continue;
      }
      final deliveryAddress = _asJsonMap(order['delivery_address']);
      final customerId = order['user_id']?.toString();
      final customer = customerId != null ? userById[customerId] : null;
      final addressName = [
        deliveryAddress['name']?.toString(),
        deliveryAddress['surname']?.toString(),
      ].where((e) => (e ?? '').trim().isNotEmpty).join(' ').trim();
      result.add({
        ...item,
        'order_number': order['order_number'] ?? '-',
        'order_total_amount': order['total_amount'] ?? 0,
        'order_status': order['status'] ?? 'confirmed',
        'customer_id': customerId,
        'customer_name':
            deliveryAddress['fullName']?.toString() ??
            (addressName.isNotEmpty ? addressName : null) ??
            deliveryAddress['title']?.toString() ??
            customer?['display_name'],
        'customer_email': customer?['email'],
        'customer_phone':
            deliveryAddress['phone']?.toString() ??
            deliveryAddress['phoneNumber']?.toString() ??
            deliveryAddress['gsm']?.toString() ??
            customer?['phone'],
        'order_created_at': order['created_at'],
        'delivery_address': order['delivery_address'],
        'delivery_type': order['delivery_type'],
        'delivery_slot': order['delivery_slot'],
        'is_priority':
            (order['delivery_type']?.toString().toLowerCase().contains(
                  'near',
                ) ??
                false) ||
            (order['delivery_type']?.toString().toLowerCase().contains(
                  'yakin',
                ) ??
                false),
      });
    }
    _debugSellerOrdersFetch(
      'getSellerOrders:success',
      sellerId: sellerId,
      requestUrl: 'OrderService.getSellerOrders',
      durationMs: totalWatch.elapsedMilliseconds,
      rowCount: result.length,
      note: 'rawItems=${itemRows.length}',
    );
    return result;
  }

  Future<Map<String, Map<String, dynamic>>> _getLatestReturnRequestsByBuyer({
    required String userId,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return const {};
    try {
      final rows = await _supabase
          .from('order_item_return_requests')
          .select(
            'id, order_id, order_item_id, buyer_user_id, seller_id, store_name, product_name, product_image_url, status, created_at',
          )
          .eq('buyer_user_id', normalizedUserId)
          .order('created_at', ascending: false);
      return _mapLatestReturnRequestsByOrderItem(rows);
    } catch (e) {
      debugPrint('OrderService buyer return request fallback warn: $e');
      return const {};
    }
  }

  Future<Map<String, Map<String, dynamic>>> _getLatestReturnRequestsBySeller({
    required String sellerId,
    String? businessName,
  }) async {
    final normalizedSellerId = sellerId.trim();
    if (normalizedSellerId.isEmpty) return const {};
    final merged = <String, Map<String, dynamic>>{};
    try {
      final directRows = await _supabase
          .from('order_item_return_requests')
          .select(
            'id, order_id, order_item_id, buyer_user_id, seller_id, store_name, product_name, product_image_url, status, created_at',
          )
          .eq('seller_id', normalizedSellerId)
          .order('created_at', ascending: false);
      merged.addAll(_mapLatestReturnRequestsByOrderItem(directRows));
    } catch (e) {
      debugPrint('OrderService seller return request direct warn: $e');
    }

    final normalizedBusinessName = businessName?.trim() ?? '';
    if (normalizedBusinessName.isNotEmpty) {
      try {
        final fallbackRows = await _supabase
            .from('order_item_return_requests')
            .select(
              'id, order_id, order_item_id, buyer_user_id, seller_id, store_name, product_name, product_image_url, status, created_at',
            )
            .ilike('store_name', normalizedBusinessName)
            .order('created_at', ascending: false);
        final mapped = _mapLatestReturnRequestsByOrderItem(fallbackRows);
        for (final entry in mapped.entries) {
          merged.putIfAbsent(entry.key, () => entry.value);
        }
      } catch (e) {
        debugPrint('OrderService seller return request fallback warn: $e');
      }
    }
    return merged;
  }

  Map<String, Map<String, dynamic>> _mapLatestReturnRequestsByOrderItem(
    dynamic rows,
  ) {
    final mapped = <String, Map<String, dynamic>>{};
    for (final raw in (rows as List<dynamic>)) {
      final row = _normalizeReturnRequest(
        Map<String, dynamic>.from(raw as Map),
      );
      final itemId = row['order_item_id']?.toString().trim() ?? '';
      if (itemId.isEmpty || mapped.containsKey(itemId)) continue;
      mapped[itemId] = row;
    }
    return mapped;
  }

  String _resolveOrderItemStatusByReturnRequest({
    required String? currentStatus,
    required String? returnRequestStatus,
  }) {
    final normalizedCurrent = (currentStatus ?? '').trim().toLowerCase();
    final derived = _returnFlowStatusFromRequestStatus(returnRequestStatus);
    if (_isReturnFlowStatus(normalizedCurrent)) return normalizedCurrent;
    if (_isReturnFlowStatus(derived)) return derived;
    if (normalizedCurrent.isNotEmpty) return normalizedCurrent;
    return derived;
  }

  String _returnFlowStatusFromRequestStatus(String? requestStatus) {
    switch ((requestStatus ?? '').trim().toLowerCase()) {
      case 'pending_seller_review':
      case 'awaiting_ibul_review':
        return 'return_requested';
      case 'awaiting_customer_pickup_slot':
      case 'pickup_scheduled':
        return 'return_approved';
      case 'seller_rejected':
      case 'closed_by_ibul':
        return 'delivered';
      default:
        return 'return_requested';
    }
  }

  Map<String, dynamic> _asJsonMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _normalizeReturnRequest(Map<String, dynamic> raw) {
    return {
      ...raw,
      'issue_tags': _toStringList(raw['issue_tags']),
      'evidence_image_urls': _toStringList(raw['evidence_image_urls']),
    };
  }

  List<String> _toStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const <String>[];
  }

  Future<List<String>> _uploadReturnEvidenceImages({
    required String userId,
    required String orderItemId,
    required List<String> images,
  }) async {
    final uploaded = <String>[];
    for (var index = 0; index < images.length; index++) {
      final dataUrl = images[index].trim();
      if (!dataUrl.startsWith('data:image/')) continue;
      final mime = _extractMimeType(dataUrl);
      final ext = _extensionFromMime(mime);
      final bytes = _decodeDataUrl(dataUrl);
      final path =
          '$userId/$orderItemId/${DateTime.now().microsecondsSinceEpoch}_$index.$ext';
      await _supabase.storage
          .from('return-evidence')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime, upsert: false),
          );
      uploaded.add(
        _supabase.storage.from('return-evidence').getPublicUrl(path),
      );
    }
    return uploaded;
  }

  Uint8List _decodeDataUrl(String dataUrl) {
    final uriData = UriData.parse(dataUrl);
    return uriData.contentAsBytes();
  }

  String _extractMimeType(String dataUrl) {
    final header = dataUrl.split(',').first;
    final normalized = header.toLowerCase();
    if (!normalized.startsWith('data:')) return 'image/jpeg';
    final noPrefix = normalized.substring(5);
    final semicolonIndex = noPrefix.indexOf(';');
    if (semicolonIndex <= 0) return 'image/jpeg';
    return noPrefix.substring(0, semicolonIndex);
  }

  String _extensionFromMime(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/heic':
        return 'heic';
      case 'image/jpg':
      case 'image/jpeg':
      default:
        return 'jpg';
    }
  }

  String _formatDateTimeText(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _notifyAdminsForReturnCase({
    required String returnRequestId,
    required String orderId,
    required String orderItemId,
    required String storeName,
    required String productName,
    required String note,
  }) async {
    try {
      final admins = await _supabase.from('users').select('id').inFilter(
        'role',
        const ['admin', 'super_admin'],
      );
      final adminIds = List<Map<String, dynamic>>.from(
        admins as List,
      ).map((row) => row['id']?.toString() ?? '').where((id) => id.isNotEmpty);
      final nowIso = DateTime.now().toIso8601String();
      for (final adminId in adminIds) {
        await _supabase.from('user_notifications').insert({
          'user_id': adminId,
          'title': 'İBUL iade inceleme talebi',
          'body':
              '$storeName mağazası, $productName ürünü için iade dosyasını İBUL incelemesine yönlendirdi.',
          'data': {
            'type': 'ibul_return_case',
            'return_request_id': returnRequestId,
            'order_id': orderId,
            'order_item_id': orderItemId,
            'seller_note': note,
            'open_tab': 'orders_returns',
          },
          'created_at': nowIso,
        });
      }
    } catch (e) {
      debugPrint('OrderService._notifyAdminsForReturnCase warn: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getHelpfulProducts({
    required List<String> categories,
    required Set<String> excludeNamesLower,
  }) async {
    try {
      PostgrestFilterBuilder<dynamic> query = _supabase
          .from('products')
          .select('name, brand, price, image_url, main_category')
          .inFilter('status', SupabaseService.publicCatalogProductStatuses);

      if (categories.isNotEmpty) {
        query = query.inFilter('main_category', categories);
      }

      final List<dynamic> rows = await query.limit(12);
      final List<Map<String, dynamic>> filtered = [];
      for (final raw in rows) {
        final p = Map<String, dynamic>.from(raw as Map);
        final lower = (p['name']?.toString() ?? '').toLowerCase();
        if (excludeNamesLower.contains(lower)) continue;
        filtered.add({
          'name': p['name']?.toString() ?? '',
          'brand': p['brand']?.toString() ?? '',
          'price': p['price'],
          'image_url': p['image_url']?.toString(),
        });
      }
      return filtered.take(6).toList();
    } catch (e) {
      debugPrint('OrderService helpful products warn: $e');
      return [];
    }
  }

  Future<void> updateSellerOrderStatus({
    required String itemId,
    required String orderId,
    required String sellerId,
    required String customerId,
    required String status,
    String? trackingNumber,
    String cargoCompany = 'ihız',
    String? storeName,
    String? storeLogoUrl,
    String? productName,
    String? productCode,
    String? productImageUrl,
    String? deliveryMode,
    String? deliveryType,
    String? title,
    String? description,
    bool forceUpdate = false,
  }) async {
    final shipmentStep = _shipmentStepFromStatus(status);
    final now = DateTime.now().toUtc().toIso8601String();
    final currentItem = await _supabase
        .from('order_items')
        .select(
          'id, seller_id, status, shipment_step, tracking_number, cargo_company, product_code',
        )
        .eq('id', itemId)
        .maybeSingle();

    if (currentItem == null) {
      throw Exception('Sipariş kaydı bulunamadı.');
    }

    final itemSellerId = currentItem['seller_id']?.toString() ?? '';
    final hasSellerAccess = await _hasSellerAccess(
      actingSellerId: sellerId,
      itemSellerId: itemSellerId,
    );
    if (!hasSellerAccess) {
      throw Exception(
        'Sipariş güncellenemedi: satıcı yetkisi veya sipariş kaydı eşleşmedi.',
      );
    }

    final currentStatus = (currentItem['status']?.toString() ?? '').trim();
    final currentShipmentStep = (currentItem['shipment_step']?.toString() ?? '')
        .trim();
    final currentTracking = (currentItem['tracking_number']?.toString() ?? '')
        .trim();
    final currentCargo = (currentItem['cargo_company']?.toString() ?? '')
        .trim();
    final nextTracking = (trackingNumber ?? '').trim();
    final nextCargo = cargoCompany.trim();

    final alreadySameState =
        currentStatus.toLowerCase() == status.toLowerCase() &&
        currentShipmentStep.toLowerCase() == shipmentStep.toLowerCase() &&
        currentTracking == nextTracking &&
        currentCargo == nextCargo;
    if (alreadySameState && !forceUpdate) {
      return;
    }

    await _supabase
        .from('order_items')
        .update({
          'status': status,
          'shipment_step': shipmentStep,
          'tracking_number': trackingNumber,
          'cargo_company': cargoCompany,
          'updated_at': now,
        })
        .eq('id', itemId)
        .eq('seller_id', itemSellerId);

    final normalizedDeliveryType = (deliveryType ?? '').trim();
    if (normalizedDeliveryType.isNotEmpty) {
      try {
        final updatedOrders = await _supabase
            .from('orders')
            .update({
              'delivery_type': normalizedDeliveryType,
              'updated_at': now,
            })
            .eq('id', orderId)
            .select('id');
        final rows = List<Map<String, dynamic>>.from(updatedOrders as List);
        if (rows.isEmpty) {
          throw Exception('Sipariş teslimat tipi güncellenemedi (yetki yok).');
        }
      } catch (e) {
        debugPrint('OrderService delivery_type update warn: $e');
        final isIhizDelivery = normalizedDeliveryType.toLowerCase().contains(
          'ihiz',
        );
        if (isIhizDelivery) {
          throw Exception(
            'İHIZ havuzuna gönderim tamamlanamadı. Sipariş teslimat tipi güncellenemedi.',
          );
        }
      }
    }

    final historyTitle = title ?? _statusTitle(shipmentStep);
    final historyDescription =
        description ??
        _statusDescription(shipmentStep, cargoCompany: cargoCompany);
    final hasSameHistory = await _hasExistingHistoryEntry(
      orderItemId: itemId,
      status: shipmentStep,
      title: historyTitle,
      description: historyDescription,
      trackingNumber: trackingNumber,
      cargoCompany: cargoCompany,
    );
    if (!hasSameHistory) {
      await addOrderItemHistoryEntry(
        orderItemId: itemId,
        status: shipmentStep,
        title: historyTitle,
        description: historyDescription,
        trackingNumber: trackingNumber,
        cargoCompany: cargoCompany,
      );
    }

    await _syncParentOrderStatus(orderId);

    try {
      if (!_shouldSendCustomerTrackingNotification(shipmentStep)) {
        return;
      }
      final normalizedProductCode = (productCode ?? '').trim();
      final fallbackProductCode =
          (currentItem['product_code']?.toString() ?? '').trim();
      final resolvedProductCode = normalizedProductCode.isNotEmpty
          ? normalizedProductCode
          : fallbackProductCode;
      final resolvedTrackingNumber = nextTracking.isNotEmpty
          ? nextTracking
          : (currentTracking.isEmpty ? null : currentTracking);
      final resolvedProductName =
          productName == null || productName.trim().isEmpty
          ? 'ürün'
          : productName.trim();
      final resolvedStoreName = storeName == null || storeName.trim().isEmpty
          ? 'Mağaza'
          : storeName.trim();
      final deliveryLabel = _deliveryModeLabel(
        deliveryMode: deliveryMode,
        cargoCompany: cargoCompany,
      );
      final notificationTitle = _notificationTitle(
        shipmentStep,
        storeName: resolvedStoreName,
      );
      final notificationBody = _notificationBody(
        shipmentStep,
        storeName: resolvedStoreName,
        productName: resolvedProductName,
        trackingNumber: resolvedTrackingNumber,
        productCode: resolvedProductCode,
        cargoCompany: cargoCompany,
        deliveryLabel: deliveryLabel,
        deliveryMode: deliveryMode,
      );
      final notificationType = shipmentStep == 'returned'
          ? 'return_refund_completed'
          : 'order_tracking';
      final hasSameNotification = await _hasExistingNotification(
        userId: customerId,
        orderItemId: itemId,
        status: shipmentStep,
        title: notificationTitle,
        body: notificationBody,
        trackingNumber: resolvedTrackingNumber,
      );
      if (!hasSameNotification) {
        await _supabase.from('user_notifications').insert({
          'user_id': customerId,
          'title': notificationTitle,
          'body': notificationBody,
          'data': {
            'type': notificationType,
            'order_id': orderId,
            'order_item_id': itemId,
            'status': shipmentStep,
            'store_name': resolvedStoreName,
            'store_logo_url': storeLogoUrl,
            'product_name': resolvedProductName,
            'product_code': resolvedProductCode.isEmpty
                ? null
                : resolvedProductCode,
            'product_image_url': productImageUrl,
            'tracking_number': resolvedTrackingNumber,
            'cargo_company': cargoCompany,
            'delivery_mode': deliveryMode,
            'delivery_type': normalizedDeliveryType.isEmpty
                ? null
                : normalizedDeliveryType,
            'open_tab': 'tracking',
          },
          'created_at': now,
        });
      }
    } catch (e) {
      debugPrint('OrderService user_notifications warn: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getOrderItemTracking(
    String orderItemId,
  ) async {
    try {
      final rows = await _supabase
          .from('order_item_status_history')
          .select()
          .eq('order_item_id', orderItemId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      debugPrint('OrderService.getOrderItemTracking warn: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getUserTrackingSnapshotByItemId({
    required String userId,
    required String orderItemId,
  }) async {
    try {
      final itemRow = await _supabase
          .from('order_items')
          .select(
            'id, order_id, seller_id, product_id, product_name, product_code, store_name, product_image_url, quantity, unit_price, total_price, status, shipment_step, tracking_number, cargo_company, created_at',
          )
          .eq('id', orderItemId)
          .maybeSingle();
      if (itemRow == null) return null;

      final item = Map<String, dynamic>.from(itemRow as Map);
      final orderRow = await _supabase
          .from('orders')
          .select(
            'id, user_id, order_number, delivery_address, created_at, delivery_type, delivery_slot',
          )
          .eq('id', item['order_id'])
          .maybeSingle();
      if (orderRow == null) return null;

      final order = Map<String, dynamic>.from(orderRow as Map);
      if ((order['user_id']?.toString() ?? '') != userId) {
        return null;
      }
      return _enrichTrackingSnapshot(item: item, order: order);
    } catch (e) {
      debugPrint('OrderService.getUserTrackingSnapshotByItemId warn: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> findUserTrackingByCode({
    required String userId,
    required String code,
  }) async {
    final normalizedCode = _normalizeLookupCode(code);
    if (normalizedCode.isEmpty) return null;

    try {
      final orderRows = await _supabase
          .from('orders')
          .select(
            'id, user_id, order_number, delivery_address, created_at, delivery_type, delivery_slot',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(150);
      final orders = List<Map<String, dynamic>>.from(orderRows as List);
      if (orders.isEmpty) return null;

      final orderIds = orders.map((e) => e['id'].toString()).toList();
      final orderById = <String, Map<String, dynamic>>{
        for (final order in orders) order['id'].toString(): order,
      };

      final itemRows = await _supabase
          .from('order_items')
          .select(
            'id, order_id, seller_id, product_id, product_name, product_code, store_name, product_image_url, quantity, unit_price, total_price, status, shipment_step, tracking_number, cargo_company, created_at',
          )
          .inFilter('order_id', orderIds)
          .order('created_at', ascending: false);

      for (final raw in (itemRows as List<dynamic>)) {
        final item = Map<String, dynamic>.from(raw as Map);
        final order = orderById[item['order_id'].toString()];
        if (order == null) continue;
        if (_trackingCodeMatches(item, order, normalizedCode)) {
          return _enrichTrackingSnapshot(item: item, order: order);
        }
      }
      return null;
    } catch (e) {
      debugPrint('OrderService.findUserTrackingByCode warn: $e');
      return null;
    }
  }

  Future<void> addOrderItemHistoryEntry({
    required String orderItemId,
    required String status,
    required String title,
    required String description,
    String? trackingNumber,
    String? cargoCompany,
    Map<String, dynamic>? extraData,
  }) async {
    await _supabase.from('order_item_status_history').insert({
      'order_item_id': orderItemId,
      'status': status,
      'title': title,
      'description': description,
      'tracking_number': trackingNumber,
      'cargo_company': cargoCompany,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return [];

    try {
      final rows = await _supabase
          .from('user_notifications')
          .select()
          .eq('user_id', normalizedUserId)
          .order('created_at', ascending: false);
      final notifications = List<Map<String, dynamic>>.from(rows as List);
      final fallbackRows = await _buildFallbackNotificationsFromOrderItems(
        userId: normalizedUserId,
        existingRows: notifications,
      );
      final merged = <Map<String, dynamic>>[
        ...notifications,
        ...fallbackRows,
      ].where(_isNotificationVisibleNow).toList(growable: false);
      final deduped = _dedupeNotifications(merged);
      deduped.sort((a, b) {
        final bTime = _notificationCreatedAtUtc(b['created_at']);
        final aTime = _notificationCreatedAtUtc(a['created_at']);
        return bTime.compareTo(aTime);
      });
      return deduped;
    } catch (e) {
      debugPrint('OrderService.getUserNotifications warn: $e');
      final fallbackRows = await _buildFallbackNotificationsFromOrderItems(
        userId: normalizedUserId,
      );
      fallbackRows.sort((a, b) {
        final bTime = _notificationCreatedAtUtc(b['created_at']);
        final aTime = _notificationCreatedAtUtc(a['created_at']);
        return bTime.compareTo(aTime);
      });
      return _dedupeNotifications(
        fallbackRows.where(_isNotificationVisibleNow).toList(),
      );
    }
  }

  Future<void> _queueCourierPickupDueNotifications({
    required String returnRequestId,
    required String orderId,
    required String orderItemId,
    required String storeName,
    required String productName,
    required DateTime pickupWindowStart,
    required DateTime pickupWindowEnd,
    required String createdByUserId,
    required String sellerId,
    required Map<String, dynamic> pickupAddress,
    required String note,
  }) async {
    try {
      final courierIds = <String>{};
      bool asBool(dynamic value) {
        if (value is bool) return value;
        if (value is num) return value != 0;
        final normalized = value?.toString().trim().toLowerCase() ?? '';
        return normalized == 'true' || normalized == '1' || normalized == 'yes';
      }

      try {
        final rows = await _supabase
            .from('users')
            .select('id, role, is_ihiz_approved')
            .inFilter('role', const ['courier', 'ihiz_courier']);
        for (final raw in (rows as List<dynamic>)) {
          final map = Map<String, dynamic>.from(raw as Map);
          final id = map['id']?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            courierIds.add(id);
          }
        }
      } catch (e) {
        debugPrint('OrderService courier role lookup warn: $e');
      }

      try {
        final rows = await _supabase
            .from('users')
            .select('id, is_ihiz_approved')
            .eq('is_ihiz_approved', true);
        for (final raw in (rows as List<dynamic>)) {
          final map = Map<String, dynamic>.from(raw as Map);
          if (!asBool(map['is_ihiz_approved'])) continue;
          final id = map['id']?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            courierIds.add(id);
          }
        }
      } catch (e) {
        debugPrint('OrderService courier approval lookup warn: $e');
      }

      try {
        final rows = await _supabase
            .from('ihiz_courier_applications')
            .select('user_id, status, application_status');
        for (final raw in (rows as List<dynamic>)) {
          final map = Map<String, dynamic>.from(raw as Map);
          final applicationStatus =
              (map['status'] ?? map['application_status'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
          if (applicationStatus != 'approved' &&
              applicationStatus != 'onaylandi') {
            continue;
          }
          final id = map['user_id']?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            courierIds.add(id);
          }
        }
      } catch (e) {
        debugPrint('OrderService ihiz courier lookup warn: $e');
      }

      if (courierIds.isEmpty) return;

      final visibleAtIso = DateTime.now().toUtc().toIso8601String();
      final pickupWindowStartUtcIso = pickupWindowStart
          .toUtc()
          .toIso8601String();
      final pickupWindowEndUtcIso = pickupWindowEnd.toUtc().toIso8601String();
      final startText = _formatDateTimeText(pickupWindowStart);
      final endText = _formatDateTimeText(pickupWindowEnd);
      for (final courierId in courierIds) {
        await _supabase.from('user_notifications').insert({
          'user_id': courierId,
          'title': 'İHIZ iade alım bildirimi',
          'body':
              '$storeName mağazası için iade alım görevi planlandı. Alım aralığı: $startText - $endText.',
          'data': {
            'type': 'ihiz_return_pickup_due',
            'status': 'ihiz_return_pickup_due',
            'order_id': orderId,
            'order_item_id': orderItemId,
            'return_request_id': returnRequestId,
            'store_name': storeName,
            'product_name': productName,
            'buyer_user_id': createdByUserId,
            'seller_id': sellerId.isEmpty ? null : sellerId,
            'pickup_address': pickupAddress,
            'pickup_window_start': pickupWindowStartUtcIso,
            'pickup_window_end': pickupWindowEndUtcIso,
            'buyer_pickup_note': note.isEmpty ? null : note,
            'created_by_user_id': createdByUserId,
            'open_tab': 'pool',
          },
          'created_at': visibleAtIso,
        });
      }
    } catch (e) {
      debugPrint('OrderService courier due notification queue warn: $e');
    }
  }

  Future<Map<String, dynamic>> _enrichTrackingSnapshot({
    required Map<String, dynamic> item,
    required Map<String, dynamic> order,
  }) async {
    final result = <String, dynamic>{
      ...item,
      'order_number': order['order_number'],
      'delivery_address': order['delivery_address'],
      'order_created_at': order['created_at'],
      'delivery_type': order['delivery_type'],
      'delivery_slot': order['delivery_slot'],
    };

    final sellerId = item['seller_id']?.toString();
    final productId = item['product_id']?.toString();
    final productName = item['product_name']?.toString() ?? '';

    try {
      Map<String, dynamic>? productRow;
      if (productId != null && productId.isNotEmpty) {
        final row = await _supabase
            .from('products')
            .select()
            .eq('id', productId)
            .maybeSingle();
        if (row != null) {
          productRow = Map<String, dynamic>.from(row as Map);
        }
      }
      if (productRow == null && productName.trim().isNotEmpty) {
        PostgrestFilterBuilder<dynamic> query = _supabase
            .from('products')
            .select()
            .eq('name', productName.trim());
        if (sellerId != null && sellerId.isNotEmpty) {
          query = query.eq('seller_id', sellerId);
        }
        final row = await query.limit(1).maybeSingle();
        if (row != null) {
          productRow = Map<String, dynamic>.from(row as Map);
        }
      }
      if (productRow != null) {
        result['product_id'] ??= productRow['id']?.toString();
        result['product_name'] =
            result['product_name']?.toString().trim().isNotEmpty == true
            ? result['product_name']
            : productRow['name'];
        result['product_image_url'] =
            result['product_image_url']?.toString().trim().isNotEmpty == true
            ? result['product_image_url']
            : productRow['image_url']?.toString();
        result['product_video_url'] =
            productRow['video_url']?.toString() ??
            productRow['videoUrl']?.toString();
      }
    } catch (e) {
      debugPrint('OrderService tracking product enrich warn: $e');
    }

    try {
      if (sellerId != null && sellerId.isNotEmpty) {
        final row = await _supabase
            .from('stores')
            .select()
            .eq('seller_id', sellerId)
            .maybeSingle();
        if (row != null) {
          final store = Map<String, dynamic>.from(row as Map);
          result['store_name'] =
              result['store_name']?.toString().trim().isNotEmpty == true
              ? result['store_name']
              : store['business_name']?.toString();
          result['store_logo_url'] =
              result['store_logo_url']?.toString().trim().isNotEmpty == true
              ? result['store_logo_url']
              : store['logo_url']?.toString();
          result['store_address'] = _joinTextParts([
            store['address']?.toString(),
            store['district']?.toString(),
            store['city']?.toString(),
          ]);
          result['store_lat'] = _firstDouble([
            store['store_lat'],
            store['latitude'],
            store['lat'],
          ]);
          result['store_lng'] = _firstDouble([
            store['store_lng'],
            store['longitude'],
            store['lng'],
          ]);
        }
      }
    } catch (e) {
      debugPrint('OrderService tracking store enrich warn: $e');
    }

    final deliveryAddress = _asJsonMap(order['delivery_address']);
    result['delivery_address_text'] = _joinTextParts([
      deliveryAddress['address']?.toString(),
      deliveryAddress['district']?.toString(),
      deliveryAddress['city']?.toString(),
    ]);
    result['recipient_name'] = _joinTextParts([
      deliveryAddress['name']?.toString(),
      deliveryAddress['surname']?.toString(),
    ]);
    result['lookup_code'] = _preferredTrackingLookupCode(result);
    return result;
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      await _supabase
          .from('user_notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('OrderService.markNotificationRead warn: $e');
    }
  }

  Future<void> _syncParentOrderStatus(String orderId) async {
    final rows = await _supabase
        .from('order_items')
        .select('status')
        .eq('order_id', orderId);
    final statuses = List<Map<String, dynamic>>.from(
      rows as List,
    ).map((e) => (e['status'] ?? '').toString().toLowerCase()).toList();
    if (statuses.isEmpty) return;

    String orderStatus = 'confirmed';
    if (statuses.every((s) => s == 'delivered')) {
      orderStatus = 'delivered';
    } else if (statuses.every(
      (s) => s == 'returned' || s == 'return_received' || s == 'refunded',
    )) {
      orderStatus = 'returned';
    } else if (statuses.any(_isReturnFlowStatus)) {
      orderStatus = 'return_requested';
    } else if (statuses.any(
      (s) =>
          s == 'shipped' ||
          s == 'transfer' ||
          s == 'branch' ||
          s == 'out_for_delivery',
    )) {
      orderStatus = 'shipped';
    } else if (statuses.any((s) => s == 'preparing' || s == 'ready_to_ship')) {
      orderStatus = 'preparing';
    } else if (statuses.any((s) => s == 'confirmed')) {
      orderStatus = 'confirmed';
    } else if (statuses.any((s) => s == 'cancelled')) {
      orderStatus = 'cancelled';
    }

    await _supabase
        .from('orders')
        .update({
          'status': orderStatus,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
  }

  String _shipmentStepFromStatus(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'new':
        return 'confirmed';
      case 'preparing':
        return 'preparing';
      case 'ready_to_ship':
        return 'ready_to_ship';
      case 'shipped':
        return 'shipped';
      case 'transfer':
        return 'transfer';
      case 'branch':
        return 'branch';
      case 'out_for_delivery':
        return 'out_for_delivery';
      case 'delivered':
        return 'delivered';
      case 'cancelled':
        return 'cancelled';
      case 'return_requested':
        return 'return_requested';
      case 'return_approved':
        return 'return_approved';
      case 'return_shipped_back':
        return 'return_shipped_back';
      case 'return_received':
        return 'return_received';
      case 'refunded':
      case 'returned':
        return 'returned';
      default:
        return 'confirmed';
    }
  }

  String _statusTitle(String step) {
    switch (step) {
      case 'confirmed':
        return 'Sipariş kabul edildi';
      case 'preparing':
        return 'Sipariş hazırlanıyor';
      case 'ready_to_ship':
        return 'Sevkiyat operasyonu başlatıldı';
      case 'shipped':
        return 'Sipariş kargoya verildi';
      case 'transfer':
        return 'Kargo transfer aşamasında';
      case 'branch':
        return 'Kargo şubeye ulaştı';
      case 'out_for_delivery':
        return 'Sipariş dağıtıma çıktı';
      case 'delivered':
        return 'Sipariş teslim edildi';
      case 'cancelled':
        return 'Sipariş iptal edildi';
      case 'return_requested':
        return 'İade talebi alındı';
      case 'return_approved':
        return 'İade talebi onaylandı';
      case 'return_shipped_back':
        return 'İade kargosu yolda';
      case 'return_received':
        return 'İade ürünü teslim alındı';
      case 'returned':
      case 'refunded':
        return 'İade tamamlandı';
      default:
        return 'Sipariş güncellendi';
    }
  }

  String _statusDescription(String step, {required String cargoCompany}) {
    switch (step) {
      case 'confirmed':
        return 'Satıcı siparişinizi kabul etti.';
      case 'preparing':
        return 'Satıcı siparişinizi paketleme hazırlığına aldı.';
      case 'ready_to_ship':
        return 'Siparişiniz sevkiyat operasyonuna alındı.';
      case 'shipped':
        return 'Paket $cargoCompany kargo firmasına teslim edildi.';
      case 'transfer':
        return 'Paket transfer merkezinde ilerliyor.';
      case 'branch':
        return 'Paket teslimat şubesine ulaştı.';
      case 'out_for_delivery':
        return 'Kurye paketinizi dağıtıma çıkardı.';
      case 'delivered':
        return 'Sipariş başarıyla teslim edildi.';
      case 'cancelled':
        return 'Sipariş iptal edildi.';
      case 'return_requested':
        return 'Müşteri iade talebi oluşturdu. İHız iade operasyonuna aktarıldı.';
      case 'return_approved':
        return 'İade talebi onaylandı. Ürünün geri gönderimi bekleniyor.';
      case 'return_shipped_back':
        return 'İade ürünü taşıma sürecine alındı.';
      case 'return_received':
        return 'İade ürünü mağaza tarafından teslim alındı.';
      case 'returned':
      case 'refunded':
        return 'İade süreci tamamlandı.';
      default:
        return 'Sipariş durumu güncellendi.';
    }
  }

  bool _isReturnFlowStatus(String status) {
    switch (status.toLowerCase()) {
      case 'return_requested':
      case 'return_approved':
      case 'return_shipped_back':
      case 'return_received':
      case 'returned':
      case 'refunded':
        return true;
      default:
        return false;
    }
  }

  bool _isNearDistanceDeliveryType(String rawType) {
    final normalized = rawType.toLowerCase().trim();
    if (normalized.isEmpty) return false;
    return normalized.contains('near') ||
        normalized.contains('yakin') ||
        normalized.contains('yakın') ||
        normalized.contains('local') ||
        normalized.contains('ihiz') ||
        normalized.contains('kurye');
  }

  String _notificationTitle(String step, {required String storeName}) {
    switch (step) {
      case 'preparing':
      case 'ready_to_ship':
        return storeName;
      case 'shipped':
      case 'transfer':
      case 'branch':
      case 'out_for_delivery':
      case 'delivered':
        return storeName;
      case 'returned':
      case 'refunded':
        return 'İaden Onaylandı';
      default:
        return 'Sipariş güncellendi';
    }
  }

  String _notificationBody(
    String step, {
    required String storeName,
    required String productName,
    required String? trackingNumber,
    String? productCode,
    required String cargoCompany,
    required String deliveryLabel,
    required String? deliveryMode,
  }) {
    final normalizedProductName = productName.trim().isEmpty
        ? 'ürününüz'
        : productName.trim();
    switch (step) {
      case 'preparing':
        return "$storeName mağazamızdan aldığınız ($normalizedProductName) siparişiniz hazırlanıyor.";
      case 'ready_to_ship':
        final mode = (deliveryMode ?? '').toLowerCase();
        if (mode == 'courier') {
          return "$storeName mağazamızdan aldığınız ($normalizedProductName) ürünü için İHız kurye çağrısı açıldı. Kurye paketi teslim aldığında takip numarası paylaşılacaktır.";
        }
        if (mode == 'branch_ihiz_pool') {
          return "$storeName mağazamızdan aldığınız ($normalizedProductName) ürünü için Kargo Teslim çağrısı açıldı. İHız kurye paketi satıcı adresinden alıp şubeye bırakacaktır.";
        }
        if (mode == 'branch_self_dropoff') {
          final tracking = (trackingNumber ?? '').trim().isEmpty
              ? '-'
              : trackingNumber!.trim();
          return "$storeName mağazamızdan aldığınız ($normalizedProductName) ürünü şube gönderimine alındı. Takip numarası: $tracking.";
        }
        if (mode == 'branch_company_pickup') {
          return "$storeName mağazamızdan aldığınız ($normalizedProductName) ürünü için anlaşmalı kargo firması adres alımı bekleniyor.";
        }
        return "$storeName mağazamızdan aldığınız ($normalizedProductName) ürünü sevkiyat operasyonuna alındı.";
      case 'shipped':
        final tracking = (trackingNumber ?? '').trim().isEmpty
            ? '-'
            : trackingNumber!.trim();
        final shortCode = tracking == '-'
            ? '----'
            : tracking.substring(
                (tracking.length - 4).clamp(0, tracking.length),
              );
        final mode = (deliveryMode ?? '').toLowerCase();
        final isIhiz =
            mode.contains('courier') ||
            mode.contains('ihiz') ||
            deliveryLabel.toLowerCase().contains('ihiz');
        if (isIhiz) {
          return "$storeName mağazamızdan aldığınız $normalizedProductName ürünü İHız kuryemiz tarafından teslim alınmıştır, $shortCode ile takip edebilirsiniz, $tracking ile ürünün detaylı bilgilerini görebilirsiniz.";
        }
        return "$storeName mağazamızdan aldığınız ($normalizedProductName) ürünü $deliveryLabel teslim edilmiştir. $tracking ile takip edebilirsiniz.";
      case 'transfer':
      case 'branch':
      case 'out_for_delivery':
        return "$storeName mağazamızdan aldığınız ($normalizedProductName) siparişinizin teslimat süreci güncellendi.";
      case 'delivered':
        return "$storeName mağazamızdan aldığınız $normalizedProductName ürünü, İHız tarafından teslim edilmiştir.";
      case 'returned':
      case 'refunded':
        final code = (productCode ?? '').trim().isNotEmpty
            ? (productCode ?? '').trim()
            : ((trackingNumber ?? '').trim().isNotEmpty
                  ? (trackingNumber ?? '').trim()
                  : '-');
        return "Ürün izleme Kodu: $code. $normalizedProductName ürünün için iade talebin onaylandı. Ürün satıcıya ulaştı. Ücret iadeni başlattık, 5 iş günü içerisinde hesabına yansıyacak. Bankandan kontrol edebilirsin.";
      default:
        return _statusTitle(step);
    }
  }

  bool _shouldSendCustomerTrackingNotification(String shipmentStep) {
    final normalized = shipmentStep.trim().toLowerCase();
    return normalized == 'shipped' ||
        normalized == 'out_for_delivery' ||
        normalized == 'delivered' ||
        normalized == 'returned' ||
        normalized == 'refunded' ||
        normalized == 'cancelled';
  }

  String _deliveryModeLabel({
    required String? deliveryMode,
    required String cargoCompany,
  }) {
    switch ((deliveryMode ?? '').toLowerCase()) {
      case 'courier':
        return 'iHız';
      case 'branch_ihiz_pool':
        return 'iHız Kargo Teslim';
      case 'branch_self_dropoff':
        return '$cargoCompany şube teslim';
      case 'branch_company_pickup':
        return '$cargoCompany adresten alım';
      case 'branch':
        return cargoCompany;
      default:
        return cargoCompany;
    }
  }

  Map<String, dynamic> _calculateDeliveryPricing({
    required String sourceType,
    required Map<String, double> sellerSubtotalMap,
    required Map<String, Map<String, dynamic>> storesBySellerId,
    required Map<String, dynamic> deliveryAddress,
    required DateTime now,
  }) {
    final normalizedSource = sourceType.trim().toLowerCase();
    final isExternal = normalizedSource.startsWith('external');
    final isNight = _isNightWindow(now);
    final isRain =
        deliveryAddress['is_raining'] == true ||
        deliveryAddress['weather_rain'] == true;

    final sellerFeeBySeller = <String, double>{};
    final customerFeeBySeller = <String, double>{};
    final distanceBySeller = <String, double>{};

    var totalDeliveryFee = 0.0;
    var totalCustomerFee = 0.0;
    var totalSellerFee = 0.0;

    for (final entry in sellerSubtotalMap.entries) {
      final sellerId = entry.key.trim();
      if (sellerId.isEmpty) continue;

      final store = storesBySellerId[sellerId];
      final distanceKm = _resolveDistanceKmForSeller(
        store: store,
        deliveryAddress: deliveryAddress,
      );
      final distanceComponent = distanceKm * _deliveryPerKmFee;
      final nightComponent = isNight ? _deliveryNightBonus : 0.0;
      final rainComponent = isRain ? _deliveryRainBonus : 0.0;
      final sellerTotalFee = _round2(
        _deliveryBaseFee + distanceComponent + nightComponent + rainComponent,
      );
      final customerShare = isExternal
          ? 0.0
          : _round2(
              _customerDeliveryShareByDistance(
                distanceKm,
              ).clamp(0, sellerTotalFee).toDouble(),
            );
      final sellerShare = _round2(
        (sellerTotalFee - customerShare).clamp(0, 1e9),
      );

      distanceBySeller[sellerId] = _round2(distanceKm);
      customerFeeBySeller[sellerId] = customerShare;
      sellerFeeBySeller[sellerId] = sellerShare;

      totalDeliveryFee += sellerTotalFee;
      totalCustomerFee += customerShare;
      totalSellerFee += sellerShare;
    }

    return {
      'source_type': sourceType,
      'is_night_bonus': isNight,
      'is_rain_bonus': isRain,
      'total_delivery_fee': _round2(totalDeliveryFee),
      'customer_delivery_fee': _round2(totalCustomerFee),
      'seller_delivery_fee': _round2(totalSellerFee),
      'seller_fee_by_seller': sellerFeeBySeller,
      'customer_fee_by_seller': customerFeeBySeller,
      'distance_km_by_seller': distanceBySeller,
      'pricing_components': {
        'base_fee': _deliveryBaseFee,
        'per_km_fee': _deliveryPerKmFee,
        'night_bonus': isNight ? _deliveryNightBonus : 0,
        'rain_bonus': isRain ? _deliveryRainBonus : 0,
      },
    };
  }

  double _customerDeliveryShareByDistance(double distanceKm) {
    if (distanceKm <= 3) return 35;
    if (distanceKm <= 6) return 45;
    return 55;
  }

  double _resolveDistanceKmForSeller({
    required Map<String, dynamic>? store,
    required Map<String, dynamic> deliveryAddress,
  }) {
    final storeLat = _firstDouble([
      store?['store_lat'],
      store?['latitude'],
      store?['lat'],
    ]);
    final storeLng = _firstDouble([
      store?['store_lng'],
      store?['longitude'],
      store?['lng'],
    ]);
    final deliveryLat = _firstDouble([
      deliveryAddress['lat'],
      deliveryAddress['latitude'],
    ]);
    final deliveryLng = _firstDouble([
      deliveryAddress['lng'],
      deliveryAddress['longitude'],
    ]);

    if (storeLat == null ||
        storeLng == null ||
        deliveryLat == null ||
        deliveryLng == null) {
      return _defaultDeliveryKm;
    }
    final km = _haversineKm(storeLat, storeLng, deliveryLat, deliveryLng);
    if (!km.isFinite || km <= 0) return _defaultDeliveryKm;
    if (km < 0.3) return 0.3;
    if (km > 50) return 50;
    return km;
  }

  bool _isNightWindow(DateTime now) {
    final hour = now.hour;
    return hour >= 22 || hour < 6;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _degToRad(double value) => value * (3.141592653589793 / 180.0);

  double _round2(double value) => (value * 100).round() / 100.0;

  Future<Map<String, dynamic>> _reserveSellerWalletForDelivery({
    required String sellerId,
    required double amount,
    required String referenceId,
    required String sourceType,
    required String idempotencyKey,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _supabase.rpc(
      'wallet_reserve_seller_delivery',
      params: {
        'p_seller_id': sellerId,
        'p_amount': _round2(amount),
        'p_reference_id': referenceId,
        'p_source_type': sourceType,
        'p_idempotency_key': idempotencyKey,
        'p_metadata': metadata ?? <String, dynamic>{},
      },
    );

    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      final ok = map['ok'];
      if (ok == false) {
        throw Exception(map['error']?.toString() ?? 'Wallet reserve basarisiz');
      }
      return map;
    }
    if (response is String && response.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(response);
        if (decoded is Map) {
          final map = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          final ok = map['ok'];
          if (ok == false) {
            throw Exception(
              map['error']?.toString() ?? 'Wallet reserve basarisiz',
            );
          }
          return map;
        }
      } catch (_) {}
    }
    throw Exception('Wallet reserve RPC beklenen cevap formatinda donmedi.');
  }

  Future<void> _releaseReservedWalletHolds({
    required List<Map<String, dynamic>> holds,
    required String reason,
  }) async {
    for (final hold in holds.reversed) {
      final holdId =
          hold['hold_id']?.toString() ?? hold['id']?.toString() ?? '';
      if (holdId.isEmpty) continue;
      try {
        await _supabase.rpc(
          'wallet_release_seller_delivery',
          params: {
            'p_hold_id': holdId,
            'p_idempotency_key': _buildWalletIdempotencyKey(
              prefix: 'release',
              referenceId: holdId,
              sellerId: hold['seller_id']?.toString() ?? 'seller',
            ),
            'p_reason': reason,
          },
        );
      } catch (e) {
        debugPrint('OrderService wallet release rollback warn: $e');
      }
    }
  }

  String _buildWalletIdempotencyKey({
    required String prefix,
    required String referenceId,
    required String sellerId,
  }) {
    final safeReference = referenceId
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
        .toLowerCase();
    final safeSeller = sellerId
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
        .toLowerCase();
    return '$prefix-$safeReference-$safeSeller-${DateTime.now().microsecondsSinceEpoch}';
  }

  bool _isMissingDeliveryColumnsError(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('42703') &&
        (raw.contains('total_delivery_fee') ||
            raw.contains('customer_delivery_fee') ||
            raw.contains('seller_delivery_fee') ||
            raw.contains('wallet_reserve_status'));
  }

  bool _isPolicyRecursionError(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('42p17') ||
        raw.contains('infinite recursion detected in policy');
  }

  String _mapWalletError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('insufficient_wallet_balance') ||
        lower.contains('yetersiz bakiye') ||
        lower.contains('insufficient balance')) {
      return 'Yetersiz cüzdan bakiyesi. Lütfen bakiye yükleyin.';
    }
    if (_isPolicyRecursionError(error)) {
      return 'Sipariş şu anda oluşturulamıyor: veritabanı erişim kuralı çakışması (42P17). '
          'Supabase tarafında orders/order_items RLS fix migration çalıştırılmalı.';
    }
    if (lower.contains('wallet_reserve_seller_delivery') &&
        lower.contains('does not exist')) {
      return 'Wallet altyapisi hazir degil. SUPABASE_SELLER_WALLET_DELIVERY.sql scriptini calistirin.';
    }
    return raw.replaceFirst('Exception: ', '');
  }

  String _buildTrackingNumber(String orderNumber, int index) {
    final seed = orderNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final suffix = (index + 1).toString().padLeft(2, '0');
    return '7330${seed.padRight(10, '4').substring(0, 10)}$suffix';
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _toDoublePrice(dynamic value) {
    if (value is num) return value.toDouble();
    final raw = value?.toString() ?? '0';
    String clean = raw
        .replaceAll('₺', '')
        .replaceAll('TL', '')
        .replaceAll(' ', '')
        .trim();
    if (clean.contains(',') && clean.contains('.')) {
      if (clean.lastIndexOf(',') > clean.lastIndexOf('.')) {
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        clean = clean.replaceAll(',', '');
      }
    } else if (clean.contains(',')) {
      clean = clean.replaceAll(',', '.');
    }
    return double.tryParse(clean) ?? 0;
  }

  String _last4FromMaskedCard(String? masked) {
    if (masked == null || masked.isEmpty) return '0000';
    final digits = masked.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 4) return digits;
    return digits.substring(digits.length - 4);
  }

  List<String> _collectAttributes(Map<String, dynamic> source) {
    final attrs = <String>[];
    for (final key in const ['color', 'storage', 'watt', 'feature']) {
      final value = source[key]?.toString();
      if (value != null && value.trim().isNotEmpty) {
        attrs.add(value.trim());
      }
    }
    final services = source['services'];
    if (services is List) {
      attrs.addAll(
        services.map((e) => e.toString()).where((e) => e.trim().isNotEmpty),
      );
    }
    return attrs.toSet().toList();
  }

  String _fallbackStoreName(Map<String, dynamic> source) {
    final productObject = source['productObject'];
    try {
      final fromProduct = (productObject as dynamic).store?.toString();
      if (fromProduct != null && fromProduct.trim().isNotEmpty) {
        return fromProduct;
      }
    } catch (_) {}
    final fromMap =
        source['storeName']?.toString() ??
        source['brand']?.toString() ??
        source['store']?.toString();
    return (fromMap == null || fromMap.trim().isEmpty)
        ? 'Bilinmeyen Mağaza'
        : fromMap.trim();
  }

  Future<bool> _hasSellerAccess({
    required String actingSellerId,
    required String itemSellerId,
  }) async {
    if (actingSellerId.isEmpty || itemSellerId.isEmpty) return false;
    if (actingSellerId == itemSellerId) return true;

    final currentUser = _supabase.auth.currentUser;
    final email = currentUser?.email?.trim();
    final phone = currentUser?.phone?.trim();
    final filters = <String>[];
    if (email != null && email.isNotEmpty) {
      filters.add('email.eq.$email');
    }
    if (phone != null && phone.isNotEmpty) {
      filters.add('phone.eq.$phone');
    }
    if (filters.isEmpty) return false;

    try {
      final subAdmin = await _supabase
          .from('store_sub_admins')
          .select('id')
          .eq('store_id', itemSellerId)
          .or(filters.join(','))
          .limit(1)
          .maybeSingle();
      return subAdmin != null;
    } catch (e) {
      debugPrint('OrderService seller access warn: $e');
      return false;
    }
  }

  Future<bool> _hasExistingHistoryEntry({
    required String orderItemId,
    required String status,
    required String title,
    required String description,
    String? trackingNumber,
    String? cargoCompany,
  }) async {
    try {
      final rows = await _supabase
          .from('order_item_status_history')
          .select('id, tracking_number, cargo_company')
          .eq('order_item_id', orderItemId)
          .eq('status', status)
          .eq('title', title)
          .eq('description', description)
          .order('created_at', ascending: false)
          .limit(5);
      final normalizedTracking = (trackingNumber ?? '').trim();
      final normalizedCargo = (cargoCompany ?? '').trim();
      for (final raw in (rows as List<dynamic>)) {
        final map = Map<String, dynamic>.from(raw as Map);
        final rowTracking = (map['tracking_number']?.toString() ?? '').trim();
        final rowCargo = (map['cargo_company']?.toString() ?? '').trim();
        if (rowTracking == normalizedTracking && rowCargo == normalizedCargo) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('OrderService history dedupe warn: $e');
    }
    return false;
  }

  Future<bool> _hasExistingNotification({
    required String userId,
    required String orderItemId,
    required String status,
    required String title,
    required String body,
    String? trackingNumber,
  }) async {
    try {
      final rows = await _supabase
          .from('user_notifications')
          .select('id, data')
          .eq('user_id', userId)
          .eq('title', title)
          .eq('body', body)
          .order('created_at', ascending: false)
          .limit(20);
      final normalizedTracking = (trackingNumber ?? '').trim();
      for (final raw in (rows as List<dynamic>)) {
        final map = Map<String, dynamic>.from(raw as Map);
        final data = _asJsonMap(map['data']);
        final rowItemId = data['order_item_id']?.toString() ?? '';
        final rowStatus = data['status']?.toString() ?? '';
        final rowTracking = (data['tracking_number']?.toString() ?? '').trim();
        if (rowItemId == orderItemId &&
            rowStatus == status &&
            rowTracking == normalizedTracking) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('OrderService notification dedupe warn: $e');
    }
    return false;
  }

  List<Map<String, dynamic>> _dedupeNotifications(
    List<Map<String, dynamic>> rows,
  ) {
    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];
    for (final row in rows) {
      final data = _asJsonMap(row['data']);
      final key = [
        row['user_id']?.toString() ?? '',
        data['order_item_id']?.toString() ?? '',
        data['status']?.toString() ?? '',
        data['tracking_number']?.toString() ?? '',
        row['title']?.toString() ?? '',
        row['body']?.toString() ?? '',
      ].join('|');
      if (seen.add(key)) {
        unique.add(row);
      }
    }
    return unique;
  }

  Future<List<Map<String, dynamic>>> _buildFallbackNotificationsFromOrderItems({
    required String userId,
    List<Map<String, dynamic>> existingRows = const [],
  }) async {
    try {
      final orderRows = await _supabase
          .from('orders')
          .select('id, order_number, delivery_type')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(250);
      final orders = List<Map<String, dynamic>>.from(orderRows as List);
      if (orders.isEmpty) return const [];

      final orderIds = orders
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      if (orderIds.isEmpty) return const [];

      final orderById = <String, Map<String, dynamic>>{
        for (final row in orders) row['id']?.toString() ?? '': row,
      };
      final itemRows = await _supabase
          .from('order_items')
          .select(
            'id, order_id, product_name, store_name, product_image_url, status, shipment_step, tracking_number, cargo_company, created_at, updated_at',
          )
          .inFilter('order_id', orderIds)
          .order('updated_at', ascending: false);
      final items = List<Map<String, dynamic>>.from(itemRows as List);
      if (items.isEmpty) return const [];

      final existingStatusKeys = <String>{};
      for (final row in existingRows) {
        final data = _asJsonMap(row['data']);
        final itemId = data['order_item_id']?.toString() ?? '';
        final status = data['status']?.toString() ?? '';
        if (itemId.isEmpty || status.isEmpty) continue;
        existingStatusKeys.add('$itemId|$status');
      }

      final fallback = <Map<String, dynamic>>[];
      for (final item in items) {
        final itemId = item['id']?.toString() ?? '';
        final orderId = item['order_id']?.toString() ?? '';
        if (itemId.isEmpty || orderId.isEmpty) continue;
        final normalizedStatus = _shipmentStepFromStatus(
          item['shipment_step']?.toString() ??
              item['status']?.toString() ??
              'confirmed',
        );
        if (!_shouldSendCustomerTrackingNotification(normalizedStatus)) {
          continue;
        }

        final dedupeKey = '$itemId|$normalizedStatus';
        if (existingStatusKeys.contains(dedupeKey)) continue;
        existingStatusKeys.add(dedupeKey);

        final order = orderById[orderId];
        final resolvedStoreName =
            item['store_name']?.toString().trim().isNotEmpty == true
            ? item['store_name'].toString().trim()
            : 'Mağaza';
        final resolvedProductName =
            item['product_name']?.toString().trim().isNotEmpty == true
            ? item['product_name'].toString().trim()
            : 'ürün';
        final trackingNumber = item['tracking_number']?.toString().trim();
        final cargoCompany =
            item['cargo_company']?.toString().trim().isNotEmpty == true
            ? item['cargo_company'].toString().trim()
            : 'İHız';
        final deliveryType = order?['delivery_type']?.toString().trim() ?? '';
        final body = _notificationBody(
          normalizedStatus,
          storeName: resolvedStoreName,
          productName: resolvedProductName,
          trackingNumber: trackingNumber == null || trackingNumber.isEmpty
              ? null
              : trackingNumber,
          cargoCompany: cargoCompany,
          deliveryLabel: _deliveryModeLabel(
            deliveryMode: null,
            cargoCompany: cargoCompany,
          ),
          deliveryMode: null,
        );
        final createdAt =
            item['updated_at']?.toString() ??
            item['created_at']?.toString() ??
            DateTime.now().toUtc().toIso8601String();

        fallback.add({
          'id': 'fallback-$itemId-$normalizedStatus',
          'user_id': userId,
          'title': _notificationTitle(
            normalizedStatus,
            storeName: resolvedStoreName,
          ),
          'body': body,
          'is_read': false,
          'created_at': createdAt,
          'data': {
            'type': 'order_tracking',
            'order_id': orderId,
            'order_item_id': itemId,
            'status': normalizedStatus,
            'store_name': resolvedStoreName,
            'product_name': resolvedProductName,
            'product_image_url': item['product_image_url']?.toString(),
            'tracking_number': trackingNumber,
            'cargo_company': cargoCompany,
            'delivery_type': deliveryType.isEmpty ? null : deliveryType,
            'open_tab': 'tracking',
            'synthetic': true,
          },
        });
      }
      return fallback;
    } catch (e) {
      debugPrint('OrderService fallback notifications warn: $e');
      return const [];
    }
  }

  bool _isNotificationVisibleNow(Map<String, dynamic> row) {
    final createdAt = _notificationCreatedAtUtc(row['created_at']);
    final data = _asJsonMap(row['data']);
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    if (type == 'ihiz_return_pickup_due') {
      final nowUtc = DateTime.now().toUtc();
      return !createdAt.isAfter(nowUtc);
    }
    // Tracking bildirimlerinde timezone kayması yüzünden "gelecek tarih"
    // gelirse kullanıcıdan saklamıyoruz.
    return true;
  }

  DateTime _notificationCreatedAtUtc(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    if (parsed == null) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return parsed.toUtc();
  }

  bool _trackingCodeMatches(
    Map<String, dynamic> item,
    Map<String, dynamic> order,
    String normalizedCode,
  ) {
    final candidates = <String>[
      item['product_code']?.toString() ?? '',
      item['tracking_number']?.toString() ?? '',
      order['order_number']?.toString() ?? '',
      item['id']?.toString() ?? '',
    ];

    for (final candidate in candidates) {
      final normalizedCandidate = _normalizeLookupCode(candidate);
      if (normalizedCandidate.isEmpty) continue;
      if (normalizedCandidate == normalizedCode ||
          normalizedCandidate.endsWith(normalizedCode) ||
          normalizedCandidate.contains(normalizedCode) ||
          normalizedCode.contains(normalizedCandidate)) {
        return true;
      }
    }
    return false;
  }

  String _normalizeLookupCode(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase().trim();
  }

  String _preferredTrackingLookupCode(Map<String, dynamic> data) {
    final productCode = data['product_code']?.toString().trim() ?? '';
    if (productCode.isNotEmpty) return productCode;
    final trackingNumber = data['tracking_number']?.toString().trim() ?? '';
    if (trackingNumber.isNotEmpty) return trackingNumber;
    final orderNumber = data['order_number']?.toString().trim() ?? '';
    return orderNumber;
  }

  String _joinTextParts(List<String?> values) {
    return values
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(', ');
  }

  double? _firstDouble(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchStoresInBulk({
    required List<String> sellerIds,
    required List<String> storeNames,
  }) async {
    final rows = <Map<String, dynamic>>[];
    if (sellerIds.isNotEmpty) {
      try {
        final bySeller = await _supabase
            .from('stores')
            .select('seller_id, business_name, store_lat, store_lng')
            .inFilter('seller_id', sellerIds);
        rows.addAll(List<Map<String, dynamic>>.from(bySeller as List));
      } catch (e) {
        debugPrint('OrderService bulk store by seller warn: $e');
      }
    }
    final remainingStoreNames = storeNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (remainingStoreNames.isNotEmpty) {
      try {
        final orClause = remainingStoreNames
            .map((name) => 'business_name.ilike.${name.replaceAll(',', r'\,')}')
            .join(',');
        final byName = await _supabase
            .from('stores')
            .select('seller_id, business_name, store_lat, store_lng')
            .or(orClause);
        rows.addAll(List<Map<String, dynamic>>.from(byName as List));
      } catch (e) {
        debugPrint('OrderService bulk store by name warn: $e');
      }
    }
    final deduped = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final key =
          row['seller_id']?.toString() ??
          row['business_name']?.toString() ??
          '';
      if (key.isEmpty) continue;
      deduped[key] = row;
    }
    return deduped.values.toList(growable: false);
  }
}
