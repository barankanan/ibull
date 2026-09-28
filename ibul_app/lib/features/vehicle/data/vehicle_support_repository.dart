import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/vehicle_image_upload.dart';
import '../models/vehicle_commerce.dart';
import '../models/vehicle_enums.dart';
import '../models/vehicle_listing.dart';
import 'vehicle_listing_repository.dart';

class VehicleChatRepository {
  VehicleChatRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> openConversation({
    required String listingId,
    required String sellerId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw VehicleRepositoryException('Giriş gerekli', code: 'auth_required');
    }
    final existing = await _client
        .from('vehicle_conversations')
        .select('id')
        .eq('listing_id', listingId)
        .eq('customer_id', uid)
        .maybeSingle();
    if (existing != null) return existing['id'].toString();
    final inserted = await _client
        .from('vehicle_conversations')
        .insert({
          'listing_id': listingId,
          'seller_id': sellerId,
          'customer_id': uid,
        })
        .select('id')
        .single();
    await _client.from('vehicle_analytics_events').insert({
      'listing_id': listingId,
      'seller_id': sellerId,
      'event_type': 'chat',
      'actor_id': uid,
    });
    return inserted['id'].toString();
  }

  Future<List<Map<String, dynamic>>> messages(String conversationId) async {
    final raw = await _client
        .from('vehicle_messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at');
    return (raw as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  Future<void> send({
    required String conversationId,
    required String body,
    String? mediaUrl,
    String? actionType,
    Map<String, dynamic>? actionPayload,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw VehicleRepositoryException('Giriş gerekli', code: 'auth_required');
    }
    await _client.from('vehicle_messages').insert({
      'conversation_id': conversationId,
      'sender_id': uid,
      'body': body,
      'media_url': mediaUrl,
      'action_type': actionType,
      'action_payload': actionPayload,
    });
    await _client
        .from('vehicle_conversations')
        .update({
          'last_message': body,
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', conversationId);
  }

  Future<List<Map<String, dynamic>>> inbox({required bool asSeller}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final col = asSeller ? 'seller_id' : 'customer_id';
    final raw = await _client
        .from('vehicle_conversations')
        .select()
        .eq(col, uid)
        .order('last_message_at', ascending: false);
    return (raw as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }
}

class VehicleFavoriteRepository {
  VehicleFavoriteRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<bool> isFavorite(String listingId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final ids = await listingIds();
    return ids.contains(listingId);
  }

  Future<bool> toggle(VehicleListing listing) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw VehicleRepositoryException('Giriş gerekli', code: 'auth_required');
    }
    final existing = await isFavorite(listing.id);
    if (existing) {
      await _client
          .from('vehicle_favorites')
          .delete()
          .eq('user_id', uid)
          .eq('listing_id', listing.id);
      _remember(listing.id, false);
      return false;
    }
    await _client.from('vehicle_favorites').insert({
      'user_id': uid,
      'listing_id': listing.id,
    });
    await _client.from('vehicle_analytics_events').insert({
      'listing_id': listing.id,
      'seller_id': listing.sellerId,
      'event_type': 'favorite',
      'actor_id': uid,
    });
    _remember(listing.id, true);
    return true;
  }

  Future<bool> ensureFavorite(VehicleListing listing) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw VehicleRepositoryException('Giriş gerekli', code: 'auth_required');
    }
    if (await isFavorite(listing.id)) {
      _remember(listing.id, true);
      return true;
    }
    try {
      return await toggle(listing);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        _remember(listing.id, true);
        return true;
      }
      rethrow;
    }
  }

  Future<Set<String>>? _idsInFlight;
  final Set<String> _idsMem = {};
  bool _idsLoaded = false;

  void invalidateIds() {
    _idsInFlight = null;
    _idsLoaded = false;
    _idsMem.clear();
  }

  void _remember(String listingId, bool favorite) {
    if (favorite) {
      _idsMem.add(listingId);
    } else {
      _idsMem.remove(listingId);
    }
    _idsLoaded = true;
  }

  Future<Set<String>> listingIds({bool refresh = false}) async {
    if (refresh) invalidateIds();
    if (_idsLoaded && !refresh) return Set<String>.from(_idsMem);
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const {};
    _idsInFlight ??= _fetchIds(uid).whenComplete(() => _idsInFlight = null);
    return _idsInFlight!;
  }

  Future<Set<String>> _fetchIds(String uid) async {
    final raw = await _client
        .from('vehicle_favorites')
        .select('listing_id')
        .eq('user_id', uid);
    _idsMem
      ..clear()
      ..addAll(
        (raw as List)
            .whereType<Map>()
            .map((row) => row['listing_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty),
      );
    _idsLoaded = true;
    return Set<String>.from(_idsMem);
  }

  Future<List<VehicleListing>> listListings() async {
    final ids = await listingIds(refresh: true);
    if (ids.isEmpty) return const [];
    return VehicleListingRepository(client: _client).getByIds(ids.toList());
  }
}

class VehicleOperationsRepository {
  VehicleOperationsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> addMaintenance({
    required String listingId,
    required String sellerId,
    required String kind,
    required String title,
    String? notes,
    DateTime? occurredOn,
    int? odometerKm,
  }) async {
    await _client.from('vehicle_maintenance_records').insert({
      'listing_id': listingId,
      'seller_id': sellerId,
      'kind': kind,
      'title': title,
      'notes': notes,
      'occurred_on': occurredOn?.toIso8601String().split('T').first,
      'odometer_km': odometerKm,
    });
  }

  Future<List<Map<String, dynamic>>> listMaintenance(String listingId) async {
    final raw = await _client
        .from('vehicle_maintenance_records')
        .select()
        .eq('listing_id', listingId)
        .order('created_at', ascending: false);
    return (raw as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  Future<void> replaceDamageRecords({
    required String listingId,
    required String sellerId,
    required Map<String, String> parts,
  }) async {
    await _client
        .from('vehicle_damage_records')
        .delete()
        .eq('listing_id', listingId);
    final rows = <Map<String, dynamic>>[];
    for (final entry in parts.entries) {
      if (entry.value == 'original') continue;
      rows.add({
        'listing_id': listingId,
        'seller_id': sellerId,
        'part_name': entry.key,
        'severity': entry.value,
      });
    }
    if (rows.isEmpty) return;
    await _client.from('vehicle_damage_records').insert(rows);
  }

  Future<VehicleDashboardStats> dashboard() async {
    final raw = await _client.rpc('vehicle_seller_dashboard');
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true) return VehicleDashboardStats.empty;
    return VehicleDashboardStats.fromMap(map);
  }

  Future<void> upsertDeliveryZone({
    required String sellerId,
    required String label,
    required double minKm,
    required double maxKm,
    required double fee,
    bool airport = false,
  }) async {
    await _client.from('vehicle_delivery_zones').insert({
      'seller_id': sellerId,
      'label': label,
      'min_km': minKm,
      'max_km': maxKm,
      'fee': fee,
      'is_airport': airport,
    });
  }
}

class VehicleMediaRepository {
  VehicleMediaRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const bucket = VehicleImageUpload.bucket;

  Future<({String path, String publicUrl, int sizeBytes})> uploadBytes({
    required Uint8List bytes,
    required String objectPath,
    required String contentType,
    required String sellerId,
    required String listingId,
    String? fileName,
  }) async {
    final uid = _client.auth.currentUser?.id;
    debugPrint(
      '[vehicle] UPLOAD START '
      'userId=$uid sellerId=$sellerId storeId=n/a(seller_id) '
      'vehicleId=$listingId bucket=$bucket path=$objectPath '
      'fileName=$fileName mimeType=$contentType fileSize=${bytes.length}',
    );
    if (uid == null || uid.isEmpty) {
      throw VehicleRepositoryException(
        'Satıcı oturumu gerekli',
        code: 'auth_required',
      );
    }
    if (uid != sellerId) {
      debugPrint(
        '[vehicle] UPLOAD RESULT failure code=seller_mismatch '
        'authUid=$uid sellerId=$sellerId',
      );
      throw VehicleRepositoryException(
        'Fotoğraf yalnızca kendi galerinize yüklenebilir.',
        code: 'forbidden',
      );
    }
    if (bytes.isEmpty) {
      throw VehicleRepositoryException(
        'Dosya boş görünüyor.',
        code: 'empty_file',
      );
    }
    if (bytes.length > VehicleImageUpload.maxBytes) {
      throw VehicleRepositoryException(
        'Fotoğraf çok büyük.',
        code: 'file_too_large',
      );
    }
    try {
      await _client.storage
          .from(bucket)
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
              cacheControl: 'public, max-age=31536000',
            ),
          );
      final publicUrl = _client.storage.from(bucket).getPublicUrl(objectPath);
      debugPrint(
        '[vehicle] UPLOAD RESULT success '
        'bucket=$bucket path=$objectPath size=${bytes.length} '
        'urlHost=${Uri.tryParse(publicUrl)?.host}',
      );
      return (path: objectPath, publicUrl: publicUrl, sizeBytes: bytes.length);
    } on StorageException catch (error, stack) {
      debugPrint(
        '[vehicle] UPLOAD RESULT failure '
        'status=${error.statusCode} code=${error.error} '
        'message=${error.message}\n$stack',
      );
      throw VehicleRepositoryException(
        _storageUserMessage(error),
        code: error.statusCode ?? error.error,
      );
    } catch (error, stack) {
      debugPrint('[vehicle] UPLOAD RESULT failure error=$error\n$stack');
      throw VehicleRepositoryException(
        'Fotoğraf yüklenemedi. $error',
        code: 'upload_failed',
      );
    }
  }

  String _storageUserMessage(StorageException error) {
    final blob = '${error.statusCode} ${error.error} ${error.message}'
        .toLowerCase();
    if (blob.contains('not found') || blob.contains('404')) {
      return 'Depolama alanı (vehicle-media) bulunamadı.';
    }
    if (blob.contains('403') ||
        blob.contains('unauthorized') ||
        blob.contains('row-level security') ||
        blob.contains('policy')) {
      return 'Fotoğraf yükleme izni reddedildi.';
    }
    if (blob.contains('413') || blob.contains('too large')) {
      return 'Fotoğraf boyutu depolama sınırını aşıyor.';
    }
    return 'Fotoğraf yüklenemedi.';
  }

  Future<String> attach({
    required String listingId,
    required String sellerId,
    required VehicleMediaSlot slot,
    required String objectPath,
    required String url,
    bool isCover = false,
    int sortOrder = 0,
  }) async {
    try {
      final attached = await _client
          .from('vehicle_media')
          .insert({
            'listing_id': listingId,
            'seller_id': sellerId,
            'slot': slot.wire,
            'bucket': bucket,
            'object_path': objectPath,
            'url': url,
            'is_cover': isCover,
            'sort_order': sortOrder,
          })
          .select('id')
          .single();
      if (isCover) {
        await _client
            .from('vehicle_listings')
            .update({'cover_url': url})
            .eq('id', listingId);
      }
      debugPrint(
        '[vehicle] IMAGE DB RESULT success mediaId=${attached['id']} '
        'listingId=$listingId',
      );
      return attached['id'].toString();
    } catch (error, stack) {
      debugPrint(
        '[vehicle] IMAGE DB RESULT failure listingId=$listingId '
        'error=$error\n$stack',
      );
      rethrow;
    }
  }

  Future<List<VehicleMedia>> listByListing(String listingId) async {
    final raw = await _client
        .from('vehicle_media')
        .select('id, slot, url, sort_order, is_cover, object_path')
        .eq('listing_id', listingId)
        .order('sort_order');
    return (raw as List)
        .whereType<Map>()
        .map((row) => VehicleMedia.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<void> detach({required String mediaId, String? objectPath}) async {
    await _client.from('vehicle_media').delete().eq('id', mediaId);
    if (objectPath == null || objectPath.trim().isEmpty) return;
    try {
      await _client.storage.from(bucket).remove([objectPath]);
    } catch (error) {
      debugPrint('[vehicle] storage delete skipped: $error');
    }
  }

  Future<void> setCover({
    required String listingId,
    required String mediaId,
    required String url,
  }) async {
    await _client
        .from('vehicle_media')
        .update({'is_cover': false})
        .eq('listing_id', listingId);
    await _client
        .from('vehicle_media')
        .update({'is_cover': true})
        .eq('id', mediaId);
    await _client
        .from('vehicle_listings')
        .update({'cover_url': url})
        .eq('id', listingId);
  }

  Future<void> updateSortOrder({
    required String mediaId,
    required int sortOrder,
  }) async {
    await _client
        .from('vehicle_media')
        .update({'sort_order': sortOrder})
        .eq('id', mediaId);
  }
}
