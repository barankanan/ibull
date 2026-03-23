import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/ads_table_names.dart';
import '../models/ad_credit_code.dart';

class AdCreditCodeService {
  AdCreditCodeService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final math.Random _random = math.Random.secure();

  String normalizeCode(String value) => value.trim().toUpperCase();

  Future<List<AdCreditCode>> generateCodes({
    required double amount,
    required int count,
    int usageLimit = 1,
    bool isActive = true,
    DateTime? expiresAt,
    String? note,
    String? targetSellerId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Amount must be positive.');
    }
    if (count <= 0) {
      throw ArgumentError.value(count, 'count', 'Count must be positive.');
    }
    if (usageLimit <= 0) {
      throw ArgumentError.value(
        usageLimit,
        'usageLimit',
        'Usage limit must be positive.',
      );
    }

    final now = DateTime.now();
    final batchId = 'batch-${now.microsecondsSinceEpoch}';
    final createdBy = _client.auth.currentUser?.id;
    debugPrint(
      '[AdCredit] admin batch create started amount=$amount count=$count usageLimit=$usageLimit seller=${targetSellerId?.trim()}',
    );
    final payload = List.generate(count, (index) {
      final code = _buildCode(seedIndex: index);
      return <String, dynamic>{
        'batch_id': batchId,
        'code': code,
        'amount': amount,
        'credit_amount': amount,
        'usage_limit': usageLimit,
        'used_count': 0,
        'is_active': isActive,
        'status': isActive ? 'active' : 'disabled',
        'created_by': createdBy,
        'seller_id': targetSellerId?.trim().isEmpty == true
            ? null
            : targetSellerId?.trim(),
        'target_seller_id': targetSellerId?.trim().isEmpty == true
            ? null
            : targetSellerId?.trim(),
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'metadata': <String, dynamic>{
          'generated_from': 'admin_ads_manager',
          'generated_at': now.toUtc().toIso8601String(),
          'usage_limit': usageLimit,
          ...metadata,
        },
      };
    });

    final response = await _client
        .from(AdsTableNames.adCreditCodes)
        .insert(payload)
        .select();
    final parsed = _parseCodes(response);
    debugPrint(
      '[AdCredit] admin batch create completed batchId=$batchId created=${parsed.length}',
    );
    return parsed;
  }

  Future<List<AdCreditCode>> getRecentCodes({int limit = 24}) async {
    debugPrint('[AdCredit] loading codes started limit=$limit');
    final response = await _client
        .from(AdsTableNames.adCreditCodes)
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    final parsed = _parseCodes(response);
    debugPrint('[AdCredit] loading codes completed count=${parsed.length}');
    return parsed;
  }

  Future<List<AdCreditRedemption>> getRecentRedemptions({
    int limit = 24,
  }) async {
    debugPrint('[AdCredit] loading redemptions started limit=$limit');
    final response = await _client
        .from(AdsTableNames.adCreditRedemptions)
        .select()
        .order('redeemed_at', ascending: false)
        .limit(limit);
    final parsed = _parseMaps(
      response,
      label: AdsTableNames.adCreditRedemptions,
    ).map(AdCreditRedemption.fromJson).toList(growable: false);
    debugPrint(
      '[AdCredit] loading redemptions completed count=${parsed.length}',
    );
    return parsed;
  }

  Future<AdCreditCodePreview?> previewCode(String code) async {
    final normalized = normalizeCode(code);
    if (normalized.isEmpty) {
      return null;
    }
    debugPrint('[AdCredit] preview request started code=$normalized');
    final response = await _client.rpc(
      'preview_ad_credit_code',
      params: <String, dynamic>{'p_code': normalized},
    );
    final rows = _parseMaps(response, label: 'preview_ad_credit_code');
    if (rows.isEmpty) {
      debugPrint('[AdCredit] preview request completed code=$normalized empty');
      return null;
    }
    final preview = AdCreditCodePreview.fromJson(rows.first);
    debugPrint(
      '[AdCredit] preview request completed code=$normalized canRedeem=${preview.canRedeem} reason=${preview.reason}',
    );
    return preview;
  }

  Future<AdCreditCodeRedemptionResult> redeemCode(String code) async {
    final normalized = normalizeCode(code);
    if (normalized.isEmpty) {
      throw ArgumentError('Credit code is required.');
    }
    debugPrint('[AdCredit] redeem request started code=$normalized');
    final response = await _client.rpc(
      'redeem_ad_credit_code',
      params: <String, dynamic>{'p_code': normalized},
    );
    final rows = _parseMaps(response, label: 'redeem_ad_credit_code');
    if (rows.isEmpty) {
      debugPrint('[AdCredit] redeem request failed code=$normalized empty');
      throw StateError('Credit code redemption returned no rows.');
    }
    final result = AdCreditCodeRedemptionResult.fromJson(rows.first);
    debugPrint(
      '[AdCredit] redeem request success code=$normalized amount=${result.amount} seller=${result.sellerId}',
    );
    return result;
  }

  List<AdCreditCode> _parseCodes(dynamic response) {
    return _parseMaps(
      response,
      label: AdsTableNames.adCreditCodes,
    ).map(AdCreditCode.fromJson).toList(growable: false);
  }

  List<Map<String, dynamic>> _parseMaps(
    dynamic response, {
    required String label,
  }) {
    if (response is! List) {
      debugPrint(
        'AdCreditCodeService $label response was not a list: $response',
      );
      return const <Map<String, dynamic>>[];
    }
    return response
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  String _buildCode({required int seedIndex}) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final timestamp = DateTime.now().microsecondsSinceEpoch
        .toRadixString(36)
        .toUpperCase();
    final suffix = List.generate(6, (_) {
      final index = _random.nextInt(alphabet.length);
      return alphabet[index];
    }).join();
    final safeStamp = timestamp.length > 6
        ? timestamp.substring(timestamp.length - 6)
        : timestamp.padLeft(6, '0');
    return 'IBUL-$safeStamp-$seedIndex$suffix';
  }
}
