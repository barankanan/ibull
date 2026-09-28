import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/coupon_campaign.dart';
import '../domain/coupon_enums.dart';
import '../domain/coupon_models.dart';

class CouponRepositoryException implements Exception {
  CouponRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CouponRepository {
  CouponRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _campaignSelect =
      'id, name, description, code, source_type, discount_type, discount_value, '
      'max_discount, min_order_amount, per_user_limit, total_usage_limit, '
      'used_count, new_users_only, is_public, payment_type, scope_type, '
      'seller_id, store_id, approval_status, lifecycle_status, rejection_reason, '
      'starts_at, ends_at, wheel_enabled, wheel_requested, ad_budget, '
      'ad_duration_days, view_count, claim_count, '
      'total_discount_granted, created_at, updated_at';

  String _publicMessage(Object error) {
    final raw = error.toString();
    const known = {
      'coupon code already exists': 'Bu kupon kodu zaten kullanılıyor.',
      'not authorized': 'Bu işlem için yetkiniz yok.',
      'not authenticated': 'Devam etmek için giriş yapın.',
      'probability total': 'Kazanma oranları toplamı %100 olmalıdır.',
      'wheel item must reference': 'Çarka yalnızca onaylı kuponlar eklenebilir.',
      'wheel items required': 'En az bir ödül ekleyin.',
      'wheel config not found':
          'Hediye çarkı ayarı bulunamadı. Sayfayı yenileyip tekrar deneyin.',
    };
    for (final entry in known.entries) {
      if (raw.contains(entry.key)) return entry.value;
    }
    debugPrint('CouponRepository error: $raw');
    if (raw.contains('PGRST') || raw.contains('Postgrest')) {
      return 'İşlem şu anda tamamlanamadı. Lütfen tekrar deneyin.';
    }
    final match = RegExp(r'error:\s*(.+)').firstMatch(raw);
    return match?.group(1)?.trim() ?? raw;
  }

  Future<List<CouponCampaign>> listForAdmin({
    String? search,
    CouponEffectiveStatus? status,
    CouponSourceType? source,
    CouponDiscountType? discountType,
  }) async {
    try {
      final rows = await _client
          .from('coupon_campaigns')
          .select(_campaignSelect)
          .order('created_at', ascending: false)
          .limit(400);
      final campaigns = (rows as List)
          .whereType<Map>()
          .map((row) => CouponCampaign.fromMap(Map<String, dynamic>.from(row)))
          .toList();
      await _attachScopes(campaigns);
      await _attachStoreNames(campaigns);
      return campaigns.where((campaign) {
        if (status != null && campaign.effectiveStatus != status) return false;
        if (source != null && campaign.sourceType != source) return false;
        if (discountType != null && campaign.discountType != discountType) {
          return false;
        }
        final q = (search ?? '').trim().toLowerCase();
        if (q.isEmpty) return true;
        return campaign.code.toLowerCase().contains(q) ||
            campaign.name.toLowerCase().contains(q) ||
            (campaign.storeName ?? '').toLowerCase().contains(q);
      }).toList();
    } catch (error) {
      throw CouponRepositoryException(_publicMessage(error));
    }
  }

  Future<CouponAdminSummary> adminSummary(List<CouponCampaign> campaigns) async {
    var active = 0;
    var pending = 0;
    var scheduled = 0;
    var expired = 0;
    var wheel = 0;
    for (final campaign in campaigns) {
      switch (campaign.effectiveStatus) {
        case CouponEffectiveStatus.active:
          active += 1;
        case CouponEffectiveStatus.pendingReview:
          pending += 1;
        case CouponEffectiveStatus.scheduled:
          scheduled += 1;
        case CouponEffectiveStatus.expired:
          expired += 1;
        default:
          break;
      }
      if (campaign.wheelEnabled) wheel += 1;
    }
    return CouponAdminSummary(
      active: active,
      pending: pending,
      scheduled: scheduled,
      expired: expired,
      wheel: wheel,
    );
  }

  Future<List<CouponCampaign>> listForSeller(String sellerId) async {
    try {
      final rows = await _client
          .from('coupon_campaigns')
          .select(_campaignSelect)
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);
      final campaigns = (rows as List)
          .whereType<Map>()
          .map((row) => CouponCampaign.fromMap(Map<String, dynamic>.from(row)))
          .toList();
      await _attachScopes(campaigns);
      return campaigns;
    } catch (error) {
      throw CouponRepositoryException(_publicMessage(error));
    }
  }

  Future<List<CouponCampaign>> listDiscoverable() async {
    try {
      final rows = await _client.rpc('list_discoverable_coupons');
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map((row) => CouponCampaign.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      throw CouponRepositoryException(_publicMessage(error));
    }
  }

  Future<List<UserCoupon>> listMine() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    try {
      final rows = await _client
          .from('user_coupons')
          .select('*, coupon_campaigns($_campaignSelect)')
          .eq('user_id', userId)
          .order('claimed_at', ascending: false);
      return (rows as List)
          .whereType<Map>()
          .map((row) => UserCoupon.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      throw CouponRepositoryException(_publicMessage(error));
    }
  }

  Future<CouponCampaign> upsert(CouponCampaign campaign) async {
    try {
      final raw = await _client.rpc(
        'coupon_upsert_campaign',
        params: {'p_payload': campaign.toUpsertPayload()},
      );
      final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final id = map['id']?.toString() ?? campaign.id;
      return campaign.id == id
          ? campaign
          : CouponCampaign.fromMap({
              ...campaign.toUpsertPayload(),
              'id': id,
              'code': map['code'] ?? campaign.code,
              'approval_status':
                  map['approval_status'] ?? campaign.approvalStatus.dbValue,
            });
    } catch (error) {
      throw CouponRepositoryException(_publicMessage(error));
    }
  }

  Future<void> moderate({
    required String campaignId,
    required String action,
    String? reason,
  }) async {
    try {
      await _client.rpc(
        'coupon_moderate_campaign',
        params: {
          'p_campaign_id': campaignId,
          'p_action': action,
          'p_reason': reason,
        },
      );
    } catch (error) {
      throw CouponRepositoryException(_publicMessage(error));
    }
  }

  Future<void> claim(String campaignId) async {
    try {
      final raw = await _client.rpc(
        'coupon_claim',
        params: {'p_campaign_id': campaignId},
      );
      if (raw is Map && raw['ok'] == false) {
        throw CouponRepositoryException(
          raw['error']?.toString() ?? 'Kupon alınamadı.',
        );
      }
    } catch (error) {
      if (error is CouponRepositoryException) rethrow;
      throw CouponRepositoryException(_publicMessage(error));
    }
  }

  Future<CouponQuote> quote({
    String? code,
    String? campaignId,
    required List<Map<String, dynamic>> items,
    String? paymentType,
  }) async {
    try {
      final raw = await _client.rpc(
        'coupon_quote',
        params: {
          'p_payload': {
            if (code != null) 'code': code,
            if (campaignId != null) 'campaign_id': campaignId,
            'items': items,
            if (paymentType != null) 'payment_type': paymentType,
          },
        },
      );
      return CouponQuote.fromMap(
        raw is Map ? Map<String, dynamic>.from(raw) : const {'ok': false},
      );
    } catch (error) {
      throw CouponRepositoryException(_publicMessage(error));
    }
  }

  Future<CouponQuote> applyToOrder({
    required String orderId,
    required List<Map<String, dynamic>> items,
    String? code,
    String? campaignId,
    String? idempotencyKey,
  }) async {
    try {
      final raw = await _client.rpc(
        'coupon_apply_to_order',
        params: {
          'p_payload': {
            'order_id': orderId,
            'items': items,
            if (code != null) 'code': code,
            if (campaignId != null) 'campaign_id': campaignId,
            'idempotency_key': idempotencyKey ?? orderId,
          },
        },
      );
      return CouponQuote.fromMap(
        raw is Map ? Map<String, dynamic>.from(raw) : const {'ok': false},
      );
    } catch (error) {
      throw CouponRepositoryException(_publicMessage(error));
    }
  }

  Future<List<DailyDealProduct>> listDailyDeals({int limit = 12}) async {
    try {
      final rows = await _client.rpc(
        'list_daily_deal_products',
        params: {'p_limit': limit},
      );
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map(
            (row) => DailyDealProduct.fromMap(Map<String, dynamic>.from(row)),
          )
          .where((item) => item.discountPrice > 0 && item.discountPrice < item.price)
          .toList(growable: false);
    } catch (error) {
      debugPrint('[CouponRepository] listDailyDeals error: $error');
      throw CouponRepositoryException('Günün fırsatları yüklenemedi: ${_publicMessage(error)}');
    }
  }

  Future<RewardWheelConfig?> loadWheelConfig() async {
    try {
      final rows = await _client
          .from('reward_wheel_configs')
          .select('*, reward_wheel_items(*)')
          .order('updated_at', ascending: false)
          .limit(1);
      final list = rows as List;
      if (list.isEmpty) return null;
      return RewardWheelConfig.fromMap(
        Map<String, dynamic>.from(list.first as Map),
      );
    } catch (error) {
      throw CouponRepositoryException(_publicMessage(error));
    }
  }

  Future<void> saveWheelConfig(RewardWheelConfig config) async {
    final activeBps = config.items
        .where((item) => item.isActive)
        .fold<int>(0, (sum, item) => sum + item.probabilityBps);
    if (activeBps != 10000) {
      throw CouponRepositoryException('Kazanma oranları toplamı %100 olmalıdır.');
    }
    try {
      await _client.rpc(
        'reward_wheel_save_config',
        params: {
          'p_payload': {
            'id': config.id,
            'is_active': config.isActive,
            'daily_free_spins': config.dailyFreeSpins,
            'per_user_daily_limit': config.perUserDailyLimit,
            'use_global_pool': config.useGlobalPool,
            'cooldown_hours': config.cooldownHours,
            'starts_at': config.startsAt?.toUtc().toIso8601String(),
            'ends_at': config.endsAt?.toUtc().toIso8601String(),
            'items': config.items.map((item) => item.toMap()).toList(),
          },
        },
      );
    } catch (error, stack) {
      debugPrint('CouponRepository.saveWheelConfig failed: $error\n$stack');
      throw CouponRepositoryException(_publicMessage(error));
    }
  }

  Future<RewardWheelConfig?> loadWheelForUser() async {
    try {
      final raw = await _client.rpc('get_reward_wheel_for_user');
      if (raw is! Map) return loadWheelConfig();
      final map = Map<String, dynamic>.from(raw);
      if (map['ok'] == false) {
        throw CouponRepositoryException(
          map['error']?.toString() ?? 'Hediye çarkı yüklenemedi.',
        );
      }
      return RewardWheelConfig.fromMap(map);
    } catch (error, stack) {
      debugPrint('CouponRepository.loadWheelForUser failed: $error\n$stack');
      try {
        return await loadWheelConfig();
      } catch (fallback, fallbackStack) {
        debugPrint(
          'CouponRepository.loadWheelForUser fallback failed: $fallback\n$fallbackStack',
        );
        throw CouponRepositoryException(_publicMessage(error));
      }
    }
  }

  Future<RewardWheelAdminStats> loadWheelAdminStats() async {
    try {
      final raw = await _client.rpc('reward_wheel_admin_stats');
      return RewardWheelAdminStats.fromMap(
        raw is Map ? Map<String, dynamic>.from(raw) : const {},
      );
    } catch (error, stack) {
      debugPrint('CouponRepository.loadWheelAdminStats failed: $error\n$stack');
      throw CouponRepositoryException(_publicMessage(error));
    }
  }

  Future<RewardWheelSpinResult> spinWheel(String idempotencyKey) async {
    try {
      final raw = await _client.rpc(
        'spin_reward_wheel',
        params: {'p_idempotency_key': idempotencyKey},
      );
      return RewardWheelSpinResult.fromMap(
        raw is Map ? Map<String, dynamic>.from(raw) : const {'ok': false},
      );
    } catch (error) {
      throw CouponRepositoryException(_publicMessage(error));
    }
  }

  Future<void> _attachScopes(List<CouponCampaign> campaigns) async {
    if (campaigns.isEmpty) return;
    final ids = campaigns.map((c) => c.id).toList();
    try {
      final catRows = await _client
          .from('coupon_campaign_categories')
          .select('campaign_id, category_id')
          .inFilter('campaign_id', ids);
      final prodRows = await _client
          .from('coupon_campaign_products')
          .select('campaign_id, product_id')
          .inFilter('campaign_id', ids);
      final storeRows = await _client
          .from('coupon_campaign_stores')
          .select('campaign_id, store_id')
          .inFilter('campaign_id', ids);
      final cats = <String, List<int>>{};
      for (final row in (catRows as List).whereType<Map>()) {
        final id = row['campaign_id']?.toString();
        final cat = int.tryParse('${row['category_id']}');
        if (id == null || cat == null) continue;
        cats.putIfAbsent(id, () => []).add(cat);
      }
      final products = <String, List<String>>{};
      for (final row in (prodRows as List).whereType<Map>()) {
        final id = row['campaign_id']?.toString();
        final pid = row['product_id']?.toString();
        if (id == null || pid == null) continue;
        products.putIfAbsent(id, () => []).add(pid);
      }
      final stores = <String, List<String>>{};
      for (final row in (storeRows as List).whereType<Map>()) {
        final id = row['campaign_id']?.toString();
        final sid = row['store_id']?.toString();
        if (id == null || sid == null) continue;
        stores.putIfAbsent(id, () => []).add(sid);
      }
      for (var i = 0; i < campaigns.length; i++) {
        final current = campaigns[i];
        campaigns[i] = CouponCampaign.fromMap({
          ...current.toUpsertPayload(),
          'used_count': current.usedCount,
          'wheel_enabled': current.wheelEnabled,
          'rejection_reason': current.rejectionReason,
          'store_name': current.storeName,
          'store_logo_url': current.storeLogoUrl,
          'wheel_requested': current.wheelRequested,
          'category_ids': cats[current.id] ?? current.categoryIds,
          'product_ids': products[current.id] ?? current.productIds,
          'store_ids': stores[current.id] ?? current.storeIds,
        });
      }
    } catch (error, stack) {
      debugPrint('CouponRepository._attachScopes failed: $error\n$stack');
    }
  }

  Future<void> _attachStoreNames(List<CouponCampaign> campaigns) async {
    final storeIds = campaigns
        .map((c) => c.storeId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (storeIds.isEmpty) return;
    try {
      final rows = await _client
          .from('stores')
          .select('seller_id, business_name, logo_url')
          .inFilter('seller_id', storeIds);
      final names = <String, String>{};
      final logos = <String, String>{};
      for (final row in (rows as List).whereType<Map>()) {
        final id = row['seller_id']?.toString();
        final name = row['business_name']?.toString();
        final logo = row['logo_url']?.toString();
        if (id != null && name != null) names[id] = name;
        if (id != null && logo != null && logo.isNotEmpty) logos[id] = logo;
      }
      for (var i = 0; i < campaigns.length; i++) {
        final current = campaigns[i];
        final name = names[current.storeId];
        final logo = logos[current.storeId];
        if (name == null && logo == null) continue;
        campaigns[i] = CouponCampaign.fromMap({
          ...current.toUpsertPayload(),
          'used_count': current.usedCount,
          'wheel_enabled': current.wheelEnabled,
          'wheel_requested': current.wheelRequested,
          'rejection_reason': current.rejectionReason,
          'store_name': name ?? current.storeName,
          'store_logo_url': logo ?? current.storeLogoUrl,
          'category_ids': current.categoryIds,
          'product_ids': current.productIds,
          'store_ids': current.storeIds,
        });
      }
    } catch (error, stack) {
      debugPrint('CouponRepository._attachStoreNames failed: $error\n$stack');
    }
  }
}
