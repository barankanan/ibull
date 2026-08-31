import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/ihiz/delivery/ihiz_public_tracking.dart';
import '../features/ihiz/delivery/ihiz_route_paths.dart';

class IhizPublicTrackingService {
  IhizPublicTrackingService({
    SupabaseClient? client,
    Future<IhizPublicTracking> Function(String code)? fetchOverride,
  }) : _client = client,
       _fetchOverride = fetchOverride;

  static final IhizPublicTrackingService instance =
      IhizPublicTrackingService();

  final SupabaseClient? _client;
  final Future<IhizPublicTracking> Function(String code)? _fetchOverride;

  SupabaseClient get _resolvedClient =>
      _client ?? Supabase.instance.client;

  Future<IhizPublicTracking> fetch(String rawCode) async {
    final code = IhizRoutePaths.normalizeTrackingCode(rawCode);
    if (!IhizRoutePaths.isValidTrackingCode(code)) {
      return IhizPublicTracking.notFound();
    }
    final override = _fetchOverride;
    if (override != null) {
      return override(code);
    }
    try {
      final response = await _resolvedClient.rpc(
        'get_ihiz_public_tracking',
        params: {'p_tracking_code': code},
      );
      if (response is Map) {
        final json = Map<String, dynamic>.from(response);
        if (IhizPublicTracking.jsonExposesForbiddenKeys(json)) {
          debugPrint('IHIZ public tracking PII leak blocked');
          return IhizPublicTracking.notFound();
        }
        return IhizPublicTracking.fromJson(json);
      }
      return IhizPublicTracking.notFound();
    } on PostgrestException catch (error) {
      debugPrint('IHIZ public tracking RPC warn: ${error.message}');
      return IhizPublicTracking.notFound();
    } catch (error) {
      debugPrint('IHIZ public tracking warn: $error');
      return IhizPublicTracking.notFound();
    }
  }

  RealtimeChannel? subscribe(String code, void Function() onChange) {
    if (_fetchOverride != null && _client == null) return null;
    final normalized = IhizRoutePaths.normalizeTrackingCode(code);
    return _resolvedClient
        .channel('ihiz-track-$normalized')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ihiz_delivery_tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tracking_code',
            value: normalized,
          ),
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ihiz_delivery_events',
          callback: (_) => onChange(),
        );
  }

  Future<void> detach(RealtimeChannel? channel) async {
    if (channel == null) return;
    try {
      await _resolvedClient.removeChannel(channel);
    } catch (error) {
      debugPrint('IHIZ tracking detach warn: $error');
    }
  }
}
