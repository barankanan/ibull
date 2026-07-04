import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../enums/ad_enums.dart';

/// Fire-and-forget ana sayfa reklam event tracking.
/// Hata olursa UI kırılmaz.
class HomeFeatureEventService {
  HomeFeatureEventService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  void track({
    required String campaignId,
    required HomeFeatureEventType eventType,
    String? productId,
    String? storeId,
  }) {
    unawaited(_trackAsync(
      campaignId: campaignId,
      eventType: eventType,
      productId: productId,
      storeId: storeId,
    ));
  }

  Future<void> _trackAsync({
    required String campaignId,
    required HomeFeatureEventType eventType,
    String? productId,
    String? storeId,
  }) async {
    try {
      await _client.rpc(
        'increment_home_feature_metric',
        params: {
          'p_campaign_id': campaignId,
          'p_metric_key': eventType.metricKey,
        },
      );
      // TODO(phase2): user_product_events tablosuna detaylı event yaz
      debugPrint(
        'HomeFeatureEvent: ${eventType.dbValue} campaign=$campaignId '
        'product=$productId store=$storeId',
      );
    } catch (e) {
      debugPrint('HomeFeatureEventService.track failed: $e');
    }
  }
}
