import 'package:supabase_flutter/supabase_flutter.dart';

class StoreCampaign {
  final String id;
  final String sellerId;
  final String type;
  final String name;
  final String? description;
  final String? couponCode;
  final bool autoGenerateCode;
  final bool singleUse;
  final String discountType;
  final double discountValue;
  final double minCartAmount;
  final double? maxDiscount;
  final bool freeShipping;
  final DateTime startDate;
  final DateTime endDate;
  final int? usageLimit;
  final int? perUserLimit;
  final int usageCount;
  final List<String> productIds;
  final String scope;
  final String status;

  StoreCampaign({
    required this.id,
    required this.sellerId,
    required this.type,
    required this.name,
    this.description,
    this.couponCode,
    this.autoGenerateCode = false,
    this.singleUse = false,
    required this.discountType,
    required this.discountValue,
    this.minCartAmount = 0,
    this.maxDiscount,
    this.freeShipping = false,
    required this.startDate,
    required this.endDate,
    this.usageLimit,
    this.perUserLimit,
    this.usageCount = 0,
    this.productIds = const [],
    this.scope = 'all',
    this.status = 'active',
  });

  factory StoreCampaign.fromMap(Map<String, dynamic> map) {
    List<String> ids = [];
    final raw = map['product_ids'];
    if (raw != null) {
      if (raw is List) ids = raw.map((e) => e.toString()).toList();
    }
    return StoreCampaign(
      id: map['id']?.toString() ?? '',
      sellerId: map['seller_id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'kupon',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      couponCode: map['coupon_code']?.toString(),
      autoGenerateCode: map['auto_generate_code'] == true,
      singleUse: map['single_use'] == true,
      discountType: map['discount_type']?.toString() ?? 'fixed',
      discountValue: (map['discount_value'] as num?)?.toDouble() ?? 0,
      minCartAmount: (map['min_cart_amount'] as num?)?.toDouble() ?? 0,
      maxDiscount: (map['max_discount'] as num?)?.toDouble(),
      freeShipping: map['free_shipping'] == true,
      startDate: map['start_date'] != null ? DateTime.parse(map['start_date'].toString()) : DateTime.now(),
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date'].toString()) : DateTime.now(),
      usageLimit: map['usage_limit'] as int?,
      perUserLimit: map['per_user_limit'] as int?,
      usageCount: map['usage_count'] as int? ?? 0,
      productIds: ids,
      scope: map['scope']?.toString() ?? 'all',
      status: map['status']?.toString() ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'seller_id': sellerId,
      'type': type,
      'name': name,
      'description': description,
      'coupon_code': couponCode,
      'auto_generate_code': autoGenerateCode,
      'single_use': singleUse,
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_cart_amount': minCartAmount,
      'max_discount': maxDiscount,
      'free_shipping': freeShipping,
      'start_date': startDate.toUtc().toIso8601String(),
      'end_date': endDate.toUtc().toIso8601String(),
      'usage_limit': usageLimit,
      'per_user_limit': perUserLimit,
      'product_ids': productIds,
      'scope': scope,
      'status': status,
    };
  }
}

class CampaignService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  static String _generateCouponCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = DateTime.now().millisecondsSinceEpoch % 100000;
    return '${chars[(r ~/ 10000) % chars.length]}${chars[(r ~/ 1000) % chars.length]}${chars[(r ~/ 100) % chars.length]}${chars[(r ~/ 10) % chars.length]}${chars[r % chars.length]}${(100 + (r % 100)).toString().substring(1)}';
  }

  Future<void> createCampaign(StoreCampaign campaign) async {
    if (_currentUserId == null) throw Exception('Giriş yapılmamış');
    final data = campaign.toMap();
    data['seller_id'] = _currentUserId;
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();
    var code = campaign.couponCode;
    if (campaign.autoGenerateCode && (code == null || code.isEmpty)) {
      code = _generateCouponCode();
      data['coupon_code'] = code;
    }
    await _supabase.from('store_campaigns').insert(data);
  }

  /// Satıcı profili için: sadece aktif ve süresi dolmamış kampanyalar.
  Future<List<StoreCampaign>> getStoreCampaignsBySellerId(String sellerId) async {
    try {
      final list = await _supabase
          .from('store_campaigns')
          .select()
          .eq('seller_id', sellerId)
          .eq('status', 'active')
          .gte('end_date', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false);
      return (list as List).map((e) => StoreCampaign.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('getStoreCampaignsBySellerId: $e');
      return [];
    }
  }

  /// Satıcı paneli için: tüm kampanyalar (aktif, durdurulmuş, süresi dolmuş).
  Future<List<StoreCampaign>> getStoreCampaignsForPanel(String sellerId) async {
    try {
      final list = await _supabase
          .from('store_campaigns')
          .select()
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);
      return (list as List).map((e) => StoreCampaign.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('getStoreCampaignsForPanel: $e');
      return [];
    }
  }

  Future<void> updateCampaign(StoreCampaign campaign) async {
    if (_currentUserId == null || campaign.id.isEmpty) throw Exception('Giriş yapılmamış veya kampanya id yok');
    final data = campaign.toMap();
    data.remove('seller_id');
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _supabase.from('store_campaigns').update(data).eq('id', campaign.id).eq('seller_id', _currentUserId!);
  }

  Future<void> stopCampaign(String campaignId) async {
    if (_currentUserId == null) throw Exception('Giriş yapılmamış');
    await _supabase.from('store_campaigns').update({
      'status': 'inactive',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', campaignId).eq('seller_id', _currentUserId!);
  }

  Future<void> deleteCampaign(String campaignId) async {
    if (_currentUserId == null) throw Exception('Giriş yapılmamış');
    await _supabase.from('store_campaigns').delete().eq('id', campaignId).eq('seller_id', _currentUserId!);
  }

  /// Mağaza adına göre kampanyaları getirir (stores tablosundan seller_id bulunur).
  Future<List<StoreCampaign>> getStoreCampaignsByBusinessName(String businessName) async {
    if (businessName.isEmpty) return [];
    try {
      final store = await _supabase
          .from('stores')
          .select('seller_id')
          .ilike('business_name', businessName)
          .limit(1)
          .maybeSingle();
      final sellerId = store?['seller_id']?.toString();
      if (sellerId == null) return [];
      return getStoreCampaignsBySellerId(sellerId);
    } catch (e) {
      print('getStoreCampaignsByBusinessName: $e');
      return [];
    }
  }
}
