import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/text_normalizer.dart';

class SearchTelemetryEvent {
  const SearchTelemetryEvent({
    required this.id,
    required this.query,
    required this.normalizedQuery,
    required this.source,
    required this.isRegistered,
    required this.createdAt,
    this.userId,
    this.viewerKey,
    this.deliveryAddress,
    this.city,
    this.district,
    this.resultCount,
  });

  final String id;
  final String query;
  final String normalizedQuery;
  final String source;
  final String? userId;
  final String? viewerKey;
  final bool isRegistered;
  final String? deliveryAddress;
  final String? city;
  final String? district;
  final int? resultCount;
  final DateTime createdAt;

  factory SearchTelemetryEvent.fromMap(Map<String, dynamic> map) {
    return SearchTelemetryEvent(
      id: map['id']?.toString() ?? '',
      query: map['query']?.toString() ?? '',
      normalizedQuery: map['normalized_query']?.toString() ?? '',
      source: map['source']?.toString() ?? 'search_results',
      userId: map['user_id']?.toString(),
      viewerKey: map['viewer_key']?.toString(),
      isRegistered: map['is_registered'] == true,
      deliveryAddress: map['delivery_address']?.toString(),
      city: map['city']?.toString(),
      district: map['district']?.toString(),
      resultCount: (map['result_count'] as num?)?.toInt(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class SearchTelemetryService {
  SearchTelemetryService._();
  static final SearchTelemetryService instance = SearchTelemetryService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'search_telemetry';
  static const String _guestViewerKeyPrefsKey =
      'search_telemetry.guest_viewer_key';

  Future<void> logSearch({
    required String query,
    required String source,
    required int resultCount,
    String? userId,
    required bool isRegistered,
    String? deliveryAddress,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;

    final region = _extractRegion(deliveryAddress);
    final viewerKey = await _resolveViewerKey(
      userId: userId,
      isRegistered: isRegistered,
    );

    try {
      await _supabase.from(_tableName).insert({
        'query': trimmed,
        'normalized_query': _normalize(trimmed),
        'source': source,
        'user_id': userId,
        'viewer_key': viewerKey,
        'is_registered': isRegistered,
        'delivery_address': deliveryAddress,
        'city': region.$1,
        'district': region.$2,
        'result_count': resultCount,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      debugPrint(
        'SearchTelemetryService.logSearch failed. '
        'Verify SUPABASE_SEARCH_TELEMETRY.sql grants/policies were applied. Error: $error',
      );
    }
  }

  Future<List<SearchTelemetryEvent>> getRecentSearches({int days = 30}) async {
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String();

    try {
      final rows = await _supabase
          .from(_tableName)
          .select()
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(1500);

      return List<Map<String, dynamic>>.from(
        rows as List,
      ).map(SearchTelemetryEvent.fromMap).toList();
    } catch (error) {
      if (error is PostgrestException &&
          (error.code == 'PGRST205' ||
              error.message.contains(_tableName) ||
              '${error.details ?? ''}'.contains(_tableName))) {
        throw Exception(
          "Arama analitigi Supabase'te hazir degil. 'search_telemetry' tablosunu olusturmaniz gerekiyor.",
        );
      }
      throw Exception('Arama analitigi okunamadi: $error');
    }
  }

  String _normalize(String value) {
    return TextNormalizer.normalize(value);
  }

  Future<String> _resolveViewerKey({
    required String? userId,
    required bool isRegistered,
  }) async {
    if (isRegistered && userId != null && userId.trim().isNotEmpty) {
      return 'user:${userId.trim()}';
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_guestViewerKeyPrefsKey);
    if (cached != null && cached.trim().isNotEmpty) {
      return cached.trim();
    }

    final random = Random.secure();
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final entropy = List.generate(
      3,
      (_) => random.nextInt(1 << 20).toRadixString(36),
    ).join();
    final generated = 'guest:$timestamp$entropy';
    await prefs.setString(_guestViewerKeyPrefsKey, generated);
    return generated;
  }

  (String?, String?) _extractRegion(String? deliveryAddress) {
    if (deliveryAddress == null || deliveryAddress.trim().isEmpty) {
      return (null, null);
    }

    final parts = deliveryAddress
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return (null, null);
    if (parts.length == 1) return (parts.first, null);
    return (parts.last, parts[parts.length - 2]);
  }
}
