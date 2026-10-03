import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/mall_auth_session.dart';
import '../models/mall_floor.dart';
import '../models/mall_profile.dart';
import '../models/mall_setup_summary.dart';
import '../models/mall_unit.dart';

class MallManagementException implements Exception {
  MallManagementException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Logs the raw backend error under `[MALL][LOAD_ERROR]` and returns a Turkish
/// message without error codes. Server `raise exception` texts (P0001) are
/// shown as-is.
String friendlyMallError(Object error, {String? context}) {
  if (error is MallManagementException) return error.message;
  if (error is PostgrestException) {
    debugPrint(
      '[MALL][LOAD_ERROR] context=${context ?? '-'} code=${error.code} message=${error.message} '
      'details=${error.details} hint=${error.hint}',
    );
    return _postgrestMessage(error);
  }
  final text = error.toString();
  debugPrint('[MALL][LOAD_ERROR] context=${context ?? '-'} type=${error.runtimeType} message=$text');
  final floor = RegExp(r'Bu katta[\s\S]*?taşıyın\.').firstMatch(text);
  if (floor != null) return floor.group(0)!;
  if (text.contains('42501') || text.contains('yönetim yetkiniz')) {
    return 'Bu AVM için yönetim yetkiniz bulunmuyor.';
  }
  if (error is AuthException) return 'Oturumunuz sona erdi. Tekrar giriş yapın.';
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('ClientException')) {
    return 'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.';
  }
  if (error is StorageException) return 'Dosya yüklenemedi: ${error.message}';
  return 'İşlem tamamlanamadı. Lütfen tekrar deneyin.';
}

String _postgrestMessage(PostgrestException error) {
  final code = error.code ?? '';
  final message = error.message;
  switch (code) {
    case 'P0001':
      return message;
    case '42501':
      return message.isEmpty || message.contains('permission denied')
          ? 'Bu AVM için yönetim yetkiniz bulunmuyor.'
          : message;
    case 'PGRST202':
    case 'PGRST205':
    case '42P01':
    case '42883':
    case '42703':
      return 'Bu bölüm şu an kullanılamıyor. Lütfen daha sonra tekrar deneyin.';
    case '23505':
      return 'Bu kayıt zaten var. Aynı kat adı, kat seviyesi veya mağaza no kullanılıyor.';
    case '23503':
      return 'Bu kayda bağlı mağaza bağlantısı var. Önce bağlantıyı kaldırın.';
    case '23514':
      return 'Girilen değer kurallara uymuyor. Alanları kontrol edin.';
    case 'PGRST116':
      return 'Kayıt bulunamadı.';
  }
  if (message.contains('yetkiniz')) return message;
  return 'İşlem tamamlanamadı. Lütfen tekrar deneyin.';
}

class MallManagementCommands {
  const MallManagementCommands._();

  static Map<String, dynamic> updateProfile({
    required String mallId,
    required MallProfile draft,
  }) {
    return {
      'p_mall_id': mallId,
      'p_name': draft.name.trim(),
      'p_legal_name': draft.legalName,
      'p_city': draft.city.trim(),
      'p_district': draft.district.trim(),
      'p_address_text': draft.addressText.trim(),
      'p_phone': draft.phone,
      'p_website': draft.website,
      'p_opening_hours': draft.openingHours,
    };
  }

  static Map<String, dynamic> upsertFloor({
    required String mallId,
    String? floorId,
    required MallFloorDraft draft,
  }) {
    return {
      'p_mall_id': mallId,
      'p_floor_id': floorId,
      'p_name': draft.name.trim(),
      'p_level_number': draft.levelNumber,
      'p_sort_order': draft.sortOrder,
    };
  }

  static Map<String, dynamic> upsertUnit({
    required String mallId,
    String? unitId,
    required MallUnitDraft draft,
  }) {
    return {
      'p_mall_id': mallId,
      'p_unit_id': unitId,
      'p_floor_id': draft.floorId,
      'p_unit_code': draft.unitCode.trim(),
      'p_name': draft.name,
      'p_unit_type': draft.unitType,
      'p_occupancy': draft.occupancy,
      'p_area_m2': draft.areaM2,
      'p_sort_order': draft.sortOrder,
    };
  }

  /// `malls/{mallId}/{kind}/{file}` — matches the mall-media storage policy.
  static String mediaPath({
    required String mallId,
    required String kind,
    required String fileName,
    required int stamp,
  }) {
    final safe = fileName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    return 'malls/$mallId/$kind/${stamp}_$safe';
  }
}

class MallManagementRepository {
  MallManagementRepository({SupabaseClient? client, MallAuthSession? session})
      : _client = client,
        _session = session;

  final SupabaseClient? _client;
  final MallAuthSession? _session;
  static const mediaBucket = 'mall-media';

  MallAuthSession get _auth => _session ?? MallAuthSession.instance;

  SupabaseClient get _db => _client ?? _auth.client;

  String get _userId {
    final id = _db.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw MallManagementException('AVM yönetimi için giriş yapın.');
    }
    return id;
  }

  Future<List<MallMembership>> myMemberships() async {
    final userId = _userId;
    final rows = await _guard(() => _db
        .from('mall_members')
        .select(
          'role, status, mall_id, malls(id, name, legal_name, city, district, address_text, phone, website, opening_hours, logo_url, cover_url, status, is_verified)',
        )
        .eq('user_id', userId)
        .eq('status', 'active'));
    final items = (rows as List)
        .map((row) => MallMembership.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
    debugPrint('[MALL][MANAGEMENT] memberships uid=$userId count=${items.length}');
    return items;
  }

  Future<MallProfile?> mall(String mallId) async {
    final row = await _guard(() => _db.from('malls').select().eq('id', mallId).maybeSingle());
    if (row == null) return null;
    return MallProfile.fromMap(Map<String, dynamic>.from(row));
  }

  Future<MallManagementAccess> accessFor(String mallId) async {
    final userId = _userId;
    final row = await _guard(() => _db
        .from('mall_members')
        .select('role')
        .eq('mall_id', mallId)
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle());
    if (row != null) return MallManagementAccess(role: row['role']?.toString());
    final visible = await mall(mallId);
    return MallManagementAccess(adminViewer: visible != null);
  }

  Future<List<MallFloor>> floors(String mallId) async {
    final rows = await _guard(() => _db.from('mall_floors').select().eq('mall_id', mallId));
    return sortMallFloors(
      (rows as List).map((row) => MallFloor.fromMap(Map<String, dynamic>.from(row as Map))),
    );
  }

  Future<MallSetupSummary> setupSummary(String mallId) async {
    final row = await _guard(() => _db.rpc('mall_setup_summary', params: {'p_mall_id': mallId}));
    return MallSetupSummary.fromMap(row is Map ? Map<String, dynamic>.from(row) : const {});
  }

  Future<void> requestPublication(String mallId) async {
    await _guard(() => _db.rpc('request_mall_publication', params: {'p_mall_id': mallId}));
    debugPrint('[MALL][PUBLISH] requested');
  }

  Future<void> cancelPublication(String mallId) async {
    await _guard(() => _db.rpc('cancel_mall_publication', params: {'p_mall_id': mallId}));
  }

  Future<MallAccount> currentAccount() async {
    final user = _db.auth.currentUser;
    final email = user?.email ?? '';
    String? name;
    if (user != null) {
      try {
        final row = await _db.from('users').select('display_name').eq('id', user.id).maybeSingle();
        name = row?['display_name']?.toString();
      } catch (error) {
        debugPrint('[MALL][ACCOUNT] profile name unavailable: $error');
      }
    }
    final meta = user?.userMetadata?['full_name']?.toString();
    final display = [name, meta, email.split('@').first].firstWhere(
      (value) => value != null && value.trim().isNotEmpty,
      orElse: () => 'Hesabım',
    )!;
    return MallAccount(name: display.trim(), email: email);
  }

  /// Ends only the AVM session; the marketplace customer session is untouched.
  Future<void> signOut() async {
    await _auth.signOut();
    debugPrint('[MALL][ACCOUNT] signed out mallSession=${_auth.isSignedIn}');
  }

  Future<List<MallUnit>> units(String mallId) async {
    final rows = await _guard(() => _db
        .from('mall_units')
        .select()
        .eq('mall_id', mallId)
        .order('sort_order')
        .order('unit_code'));
    return (rows as List)
        .map((row) => MallUnit.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<MallProfile> updateProfile(MallProfile draft) async {
    final row = await _guard(() => _db.rpc(
          'update_mall_profile',
          params: MallManagementCommands.updateProfile(mallId: draft.id, draft: draft),
        ));
    return MallProfile.fromMap(Map<String, dynamic>.from(row as Map));
  }

  Future<void> saveFloor({
    required String mallId,
    String? floorId,
    required MallFloorDraft draft,
  }) async {
    final nameError = MallFloorValidation.nameError(draft.name);
    if (nameError != null) throw MallManagementException(nameError);
    await _guard(() => _db.rpc(
          'upsert_mall_floor',
          params: MallManagementCommands.upsertFloor(mallId: mallId, floorId: floorId, draft: draft),
        ));
    debugPrint('[MALL][MANAGEMENT] floor saved mode=${floorId == null ? 'create' : 'update'}');
  }

  Future<void> deleteFloor({required String mallId, required String floorId}) {
    return _guard(() => _db.rpc(
          'delete_mall_floor',
          params: {'p_mall_id': mallId, 'p_floor_id': floorId},
        ));
  }

  Future<void> saveUnit({
    required String mallId,
    String? unitId,
    required MallUnitDraft draft,
  }) async {
    final error = MallUnitValidation.codeError(draft.unitCode) ??
        MallUnitValidation.typeError(draft.unitType) ??
        MallUnitValidation.occupancyError(draft.occupancy);
    if (error != null) throw MallManagementException(error);
    await _guard(() => _db.rpc(
          'upsert_mall_unit',
          params: MallManagementCommands.upsertUnit(mallId: mallId, unitId: unitId, draft: draft),
        ));
  }

  Future<void> deleteUnit({required String mallId, required String unitId}) {
    return _guard(() => _db.rpc(
          'delete_mall_unit',
          params: {'p_mall_id': mallId, 'p_unit_id': unitId},
        ));
  }

  Future<String> uploadMedia({
    required String mallId,
    required String kind,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final path = MallManagementCommands.mediaPath(
      mallId: mallId,
      kind: kind,
      fileName: fileName,
      stamp: DateTime.now().millisecondsSinceEpoch,
    );
    await _guard(() => _db.storage.from(mediaBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentType(fileName), upsert: false),
        ));
    debugPrint('[MALL][MANAGEMENT] media uploaded kind=$kind bytes=${bytes.length}');
    return _db.storage.from(mediaBucket).getPublicUrl(path);
  }

  Future<void> setMallMedia({required String mallId, required String kind, String? url}) {
    return _guard(() => _db.rpc(
          'set_mall_media',
          params: {'p_mall_id': mallId, 'p_kind': kind, 'p_url': url},
        ));
  }

  Future<void> setFloorPlan({required String mallId, required String floorId, String? url}) {
    return _guard(() => _db.rpc(
          'set_mall_floor_plan',
          params: {'p_mall_id': mallId, 'p_floor_id': floorId, 'p_url': url},
        ));
  }

  Future<void> setUnitPosition({
    required String mallId,
    required String unitId,
    double? x,
    double? y,
  }) {
    return _guard(() => _db.rpc(
          'set_mall_unit_position',
          params: {'p_mall_id': mallId, 'p_unit_id': unitId, 'p_x': x, 'p_y': y},
        ));
  }

  String _contentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw MallManagementException(friendlyMallError(error));
    }
  }
}
