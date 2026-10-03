import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../management/models/mall_store_link.dart';
import '../management/services/mall_management_repository.dart';
import 'seller_mall_models.dart';

/// Private bucket; paths are `<uid>/mall-links/<request id>/<file>`.
const mallLinkDocumentBucket = 'seller-documents';

/// Seller side of the AVM link: own branches and code, AVM invitations and
/// the store's own applications. Runs inside the seller panel, so it uses the
/// marketplace/seller session, not the AVM one.
class SellerMallLinkRepository {
  SellerMallLinkRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _db => _client ?? Supabase.instance.client;

  Future<String?> myBranchCode() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final row = await _db
          .from('store_branches')
          .select('branch_code')
          .eq('store_id', userId)
          .eq('is_primary', true)
          .maybeSingle();
      return row?['branch_code']?.toString();
    } catch (error) {
      debugPrint('[MALL][SELLER] branch code load failed: ${friendlyMallError(error)}');
      return null;
    }
  }

  Future<List<SellerBranchOption>> myBranches() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _guard(() => _db
        .from('store_branches')
        .select('id,name,branch_code,city,district,is_primary')
        .eq('store_id', userId)
        .eq('status', 'active')
        .order('is_primary', ascending: false));
    return [for (final row in rows) SellerBranchOption.fromMap(row)];
  }

  Future<List<SellerMallOption>> findMalls(String query) async {
    final trimmed = query.trim();
    try {
      final rows = await _db.rpc('public_find_malls', params: {'p_query': trimmed});
      if (rows is List && rows.isNotEmpty) {
        return [
          for (final row in rows)
            if (row is Map) SellerMallOption.fromMap(Map<String, dynamic>.from(row)),
        ];
      }
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202') {
        throw MallManagementException(friendlyMallError(error, context: 'public_find_malls'));
      }
    }
    final rows = await _guard(() => _db.rpc('seller_find_malls', params: {'p_query': trimmed}));
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map) SellerMallOption.fromMap(Map<String, dynamic>.from(row)),
    ];
  }

  /// Seller onboarding only. Never calls `seller_find_malls` (mall-manager RPC).
  /// City is not sent to `public_find_malls` — that RPC searches mall *name*.
  Future<List<SellerMallOption>> listMallsInArea({
    required String city,
    required String district,
  }) async {
    final cityName = city.trim();
    final districtName = district.trim();
    if (cityName.isEmpty || districtName.isEmpty) return const [];

    try {
      final rows = await _db
          .from('malls')
          .select('id,name,city,district,logo_url,is_verified,status')
          .eq('is_verified', true)
          .ilike('city', cityName)
          .ilike('district', districtName)
          .order('name')
          .limit(40);
      return _parseMallRows(rows).where(_isOnboardingMall).toList();
    } on PostgrestException catch (error) {
      debugPrint('[MALL][ONBOARD] area list failed code=${error.code}');
      return const [];
    }
  }

  /// Floors for the selected mall id. Uses public/seller client, not mall-manager session.
  Future<List<SellerMallFloorOption>> listFloorsForMall({
    required String mallId,
    required String mallName,
  }) async {
    try {
      final row = await _db.rpc('public_mall_detail', params: {'p_mall_id': mallId});
      if (row is Map) {
        final floors = _parseFloors(row['floors']);
        if (floors.isNotEmpty) return floors;
      }
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202') {
        debugPrint('[MALL][ONBOARD] public_mall_detail floors skipped code=${error.code}');
      }
    }

    final query = mallName.trim();
    if (query.length >= 2) {
      try {
        final rows = _asMaps(await _db.rpc('public_find_malls', params: {'p_query': query}));
        for (final row in rows) {
          if (row['id']?.toString() != mallId) continue;
          final floors = SellerMallOption.fromMap(row).floors;
          if (floors.isNotEmpty) return _sortFloors(floors);
        }
      } on PostgrestException catch (error) {
        if (error.code != 'PGRST202') {
          debugPrint('[MALL][ONBOARD] public_find_malls floors skipped code=${error.code}');
        }
      }
    }

    try {
      final rows = await _db
          .from('mall_floors')
          .select('id,name,level_number,sort_order')
          .eq('mall_id', mallId)
          .eq('is_active', true);
      return _parseFloors(rows);
    } on PostgrestException catch (error) {
      debugPrint('[MALL][ONBOARD] mall_floors select failed code=${error.code}');
      return const [];
    }
  }

  static bool _isOnboardingMall(SellerMallOption mall) =>
      mall.isVerified && const {'draft', 'pending_review', 'active'}.contains(mall.status);

  static List<SellerMallOption> _parseMallRows(dynamic rows) {
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map) SellerMallOption.fromMap(Map<String, dynamic>.from(row)),
    ];
  }

  static List<Map<String, dynamic>> _asMaps(dynamic value) {
    final decoded = value is String ? jsonDecode(value) : value;
    if (decoded is! List) return const [];
    return [
      for (final row in decoded)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  static List<SellerMallFloorOption> _parseFloors(dynamic rows) {
    if (rows is! List) return const [];
    return _sortFloors([
      for (final row in rows)
        if (row is Map)
          SellerMallFloorOption(
            id: row['id'].toString(),
            name: row['name']?.toString() ?? '',
            levelNumber: row['level_number'] is num ? (row['level_number'] as num).toInt() : null,
            sortOrder: row['sort_order'] is num ? (row['sort_order'] as num).toInt() : null,
          ),
    ]);
  }

  static List<SellerMallFloorOption> _sortFloors(List<SellerMallFloorOption> floors) =>
      [...floors]..sort(SellerMallFloorOption.compare);

  /// Uploads onboarding / application files. Does not open the mall request.
  Future<List<Map<String, Object?>>> uploadDocuments({
    required String requestId,
    required List<SellerMallFile> files,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw MallManagementException('Oturumunuz kapanmış. Tekrar giriş yapın.');
    final documents = <Map<String, Object?>>[];
    for (final (index, file) in files.indexed) {
      final path = '$userId/mall-links/$requestId/${file.type}-$index.${file.extension}';
      await _db.storage.from(mallLinkDocumentBucket).uploadBinary(
            path,
            file.bytes,
            fileOptions: FileOptions(contentType: file.mime, upsert: false),
          );
      documents.add({'type': file.type, 'path': path, 'name': file.name, 'mime': file.mime, 'size': file.bytes.length});
    }
    return documents;
  }

  Future<Map<String, dynamic>?> myLocation() async {
    try {
      final row = await _db.rpc('seller_store_location');
      return row is Map ? Map<String, dynamic>.from(row) : null;
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202') throw MallManagementException(friendlyMallError(error));
      return null;
    }
  }

  Future<void> submitStandaloneLocation({
    required String city,
    required String district,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    await _guard(() => _db.rpc('submit_store_location_change', params: {
          'p_city': city,
          'p_district': district,
          'p_address': address,
          'p_latitude': latitude,
          'p_longitude': longitude,
        }));
  }

  /// Uploads the files under a fresh request id, then opens the application.
  /// The server re-checks branch ownership, the floor and that every file exists.
  Future<String> apply(SellerMallApplicationDraft draft) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw MallManagementException('Oturumunuz kapanmış. Tekrar giriş yapın.');
    final requestId = draft.requestId;
    final uploaded = <String>[];
    try {
      final documents = <Map<String, Object?>>[];
      for (final (index, file) in draft.files.indexed) {
        final path = '$userId/mall-links/$requestId/${file.type}-$index.${file.extension}';
        await _db.storage.from(mallLinkDocumentBucket).uploadBinary(
              path,
              file.bytes,
              fileOptions: FileOptions(contentType: file.mime, upsert: false),
            );
        uploaded.add(path);
        documents.add({'type': file.type, 'path': path, 'name': file.name, 'mime': file.mime, 'size': file.bytes.length});
      }
      final row = await _db.rpc('apply_mall_store_link', params: {
        'p_request_id': requestId,
        'p_mall_id': draft.mallId,
        'p_branch_id': draft.branchId,
        'p_floor_id': draft.floorId,
        'p_unit_code': draft.unitCode.trim(),
        'p_area_m2': draft.areaM2,
        'p_note': draft.note?.trim().isEmpty ?? true ? null : draft.note!.trim(),
        'p_documents': documents,
      });
      debugPrint('[MALL][SELLER_APPLY] ok docs=${documents.length}');
      return row is Map ? row['mall_name']?.toString() ?? '' : '';
    } catch (error) {
      final pg = error is PostgrestException ? error : null;
      debugPrint('[MALL][SELLER_APPLY] code=${pg?.code} message=${pg?.message ?? error} '
          'details=${pg?.details} hint=${pg?.hint} mall_id=${draft.mallId} branch_id=${draft.branchId} '
          'floor_id=${draft.floorId} unit_code=${draft.unitCode.trim()}');
      if (uploaded.isNotEmpty) {
        try {
          await _db.storage.from(mallLinkDocumentBucket).remove(uploaded);
        } catch (_) {}
      }
      if (error is MallManagementException) rethrow;
      throw MallManagementException(friendlyMallError(error, context: 'apply_mall_store_link'));
    }
  }

  Future<List<SellerMallRequest>> requests() async {
    final rows = await _guard(() => _db.rpc('seller_mall_link_requests'));
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map) SellerMallRequest.fromMap(Map<String, dynamic>.from(row)),
    ];
  }

  /// AVM invitations: the store gives the final answer.
  Future<void> respond(String linkId, {required bool approve}) async {
    await _guard(() => _db.rpc('respond_mall_branch_link', params: {'p_link_id': linkId, 'p_approve': approve}));
    debugPrint('[MALL][SELLER] link ${approve ? 'approved' : 'rejected'}');
  }

  /// Withdraws a pending request or leaves an active link.
  Future<void> remove(String linkId) => _guard(() => _db.rpc('cancel_mall_branch_link', params: {'p_link_id': linkId}));

  Future<String> documentUrl(String path) =>
      _guard(() => _db.storage.from(mallLinkDocumentBucket).createSignedUrl(path, 300));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw MallManagementException(friendlyMallError(error));
    }
  }
}

/// One picked file, kept in memory until the application is sent.
class SellerMallFile {
  const SellerMallFile({required this.type, required this.name, required this.bytes, required this.mime});

  static const maxBytes = 10 * 1024 * 1024;

  final String type;
  final String name;
  final Uint8List bytes;
  final String mime;

  String get extension => switch (mime) {
        'application/pdf' => 'pdf',
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => 'jpg',
      };

  static String? mimeFor(String fileName) => switch (fileName.split('.').last.toLowerCase()) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };
}
