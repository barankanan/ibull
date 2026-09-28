import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/vehicle_listing_validation.dart';
import '../domain/vehicle_state_machine.dart';
import '../models/vehicle_commerce.dart';
import '../models/vehicle_enums.dart';
import '../models/vehicle_listing.dart';
import 'vehicle_gallery_repository.dart';

export 'vehicle_gallery_repository.dart';

class VehicleRepositoryException implements Exception {
  VehicleRepositoryException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

class VehicleListingRepository {
  VehicleListingRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Listing + specs + media. No `stores(...)` embed — store badge is optional.
  static const listingSelect = '''
id, seller_id, listing_type, status, sale_price, negotiable, financing,
trade_in, home_delivery_sale, description, city, district, cover_url,
favorite_count, view_count, created_at, published_at, ai_payload,
vehicle_specs (*),
vehicle_rental_settings (*),
vehicle_media (id, slot, url, sort_order, is_cover, object_path)
''';

  static const homeListingSelect = '''
id, seller_id, listing_type, status, sale_price, city, district, cover_url,
vehicle_specs (brand, model, version, year, mileage_km, mileage_verified),
vehicle_galleries (id, name, avatar_url, slug)
''';

  Future<List<VehicleListing>> search(VehicleSearchQuery query) async {
    final raw = await _client.rpc(
      'search_vehicle_listings',
      params: query.toRpcParams(),
    );
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => VehicleListing.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<VehicleListing>> getHomeListings({int limit = 24}) async {
    final raw = await _client
        .from('vehicle_listings')
        .select(homeListingSelect)
        .eq('status', 'active')
        .order('published_at', ascending: false)
        .limit(limit);
    return (raw as List)
        .whereType<Map>()
        .map((row) => VehicleListing.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<VehicleListing>> getByIds(List<String> ids) async {
    final unique = ids.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (unique.isEmpty) return const [];
    final raw = await _client
        .from('vehicle_listings')
        .select(listingSelect)
        .inFilter('id', unique);
    return (raw as List)
        .whereType<Map>()
        .map((row) => VehicleListing.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<VehicleListing?> getById(
    String id, {
    bool includeGallery = true,
  }) async {
    final row = await _client
        .from('vehicle_listings')
        .select(listingSelect)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    var listing = VehicleListing.fromMap(Map<String, dynamic>.from(row));
    if (listing.specs.brand.trim().isEmpty) {
      final specRow = await _client
          .from('vehicle_specs')
          .select()
          .eq('listing_id', id)
          .maybeSingle();
      if (specRow != null) {
        listing = listing.copyWith(
          specs: VehicleSpecs.fromMap(Map<String, dynamic>.from(specRow)),
        );
      }
    }
    if (listing.media.isEmpty) {
      final mediaRaw = await _client
          .from('vehicle_media')
          .select('id, slot, url, sort_order, is_cover, object_path')
          .eq('listing_id', id)
          .order('sort_order');
      listing = listing.copyWith(
        media: VehicleMedia.sorted(
          (mediaRaw as List).whereType<Map>().map(
            (e) => VehicleMedia.fromMap(Map<String, dynamic>.from(e)),
          ),
        ),
      );
    }
    if (includeGallery &&
        listing.gallery == null &&
        listing.sellerId.isNotEmpty) {
      try {
        listing = listing.copyWith(
          gallery: await VehicleGalleryRepository(
            client: _client,
          ).getBySellerId(listing.sellerId),
        );
      } catch (error, stack) {
        debugPrint(
          '[vehicle] store enrichment skipped listingId=$id: $error\n$stack',
        );
      }
    }
    return listing;
  }

  Future<VehicleListing?> getForEdit(String id) => getById(id);

  Future<VehicleListing?> getForSellerPreview(String id) => getById(id);

  Future<VehicleListing?> getPublished(String id) async {
    final listing = await getById(id);
    if (listing == null || !listing.isLivePublished) return null;
    return listing;
  }

  Future<List<VehicleListing>> listBySeller(
    String sellerId, {
    String? status,
  }) async {
    var query = _client
        .from('vehicle_listings')
        .select(listingSelect)
        .eq('seller_id', sellerId);
    if (status != null) {
      query = query.eq('status', status);
    }
    final raw = await query.order('created_at', ascending: false);
    return (raw as List)
        .whereType<Map>()
        .map((row) => VehicleListing.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<VehicleListing>> listPublicBySeller(String sellerId) async {
    final rows = await listBySeller(sellerId);
    return rows.where((row) => row.isLivePublished).toList(growable: false);
  }

  Future<String> createDraft({
    required String sellerId,
    required VehicleListingType type,
    required VehicleSpecs specs,
    Map<String, dynamic>? extras,
  }) async {
    try {
      final inserted = await _client
          .from('vehicle_listings')
          .insert({
            'seller_id': sellerId,
            'listing_type': type.wire,
            'status': VehicleListingStatus.draft.wire,
            'city': null,
            'ai_payload': ?extras,
          })
          .select('id, status')
          .single();
      final id = inserted['id'].toString();
      debugPrint(
        '[VehicleListing][saveDraft] created listingId=$id '
        'sellerId=$sellerId status=${inserted['status']}',
      );
      try {
        await upsertSpecs(id, specs);
      } catch (error, stack) {
        debugPrint(
          '[VehicleListing][saveDraft] specs after create failed: $error\n$stack',
        );
      }
      try {
        await _client.from('vehicle_galleries').upsert({
          'seller_id': sellerId,
        }, onConflict: 'seller_id');
      } catch (error, stack) {
        debugPrint(
          '[VehicleListing][saveDraft] gallery upsert skipped: $error\n$stack',
        );
      }
      return id;
    } catch (error, stack) {
      debugPrint('[VehicleListing][saveDraft] create failed: $error\n$stack');
      throw VehicleRepositoryException(
        VehiclePublishErrorMapper.fromObject(error),
        code: _errorCode(error),
      );
    }
  }

  Future<void> updateListing(String id, Map<String, dynamic> patch) async {
    final updated = await _client
        .from('vehicle_listings')
        .update(patch)
        .eq('id', id)
        .select('id, status')
        .maybeSingle();
    if (updated == null) {
      debugPrint(
        '[VehicleListing][saveDraft] listingId=$id result=failed '
        'code=update_not_applied',
      );
      throw VehicleRepositoryException(
        'Taslak kaydedilemedi. Kayıt güncellenemedi.',
        code: 'update_not_applied',
      );
    }
  }

  Future<void> upsertSpecs(String listingId, VehicleSpecs specs) async {
    final saved = await _client
        .from('vehicle_specs')
        .upsert({
          ...specs.toMap(),
          'listing_id': listingId,
        }, onConflict: 'listing_id')
        .select('listing_id, brand, model, year')
        .maybeSingle();
    if (saved == null) {
      throw VehicleRepositoryException(
        'Araç bilgileri kaydedilemedi.',
        code: 'specs_required',
      );
    }
  }

  Future<void> upsertRental(
    String listingId,
    String sellerId,
    VehicleRentalSettings settings,
  ) async {
    await _client.from('vehicle_rental_settings').upsert({
      ...settings.toMap(),
      'listing_id': listingId,
      'seller_id': sellerId,
    }, onConflict: 'listing_id');
    if (settings.homeDelivery || settings.mapPointDelivery) {
      final existing = await _client
          .from('vehicle_delivery_zones')
          .select('id')
          .eq('seller_id', sellerId)
          .eq('is_airport', false)
          .limit(1);
      if ((existing as List).isEmpty) {
        await _client.from('vehicle_delivery_zones').insert({
          'seller_id': sellerId,
          'label': 'Adrese teslim',
          'min_km': 0,
          'max_km': 50,
          'fee': 0,
          'is_airport': false,
        });
      }
    }
  }

  Future<List<VehicleListing>> listForAdmin({String? status}) async {
    try {
      final raw = await _client.rpc(
        'admin_list_vehicle_listings',
        params: {'p_status': status},
      );
      if (raw is! List || raw.isEmpty) return const [];
      final ids = raw
          .whereType<Map>()
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      if (ids.isEmpty) return const [];
      final rows = await _client
          .from('vehicle_listings')
          .select(listingSelect)
          .inFilter('id', ids)
          .order('created_at', ascending: false);
      return (rows as List)
          .whereType<Map>()
          .map((row) => VehicleListing.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      debugPrint('[vehicle] admin list rpc fallback: $error');
    }
    var query = _client.from('vehicle_listings').select(listingSelect);
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }
    final raw = await query.order('created_at', ascending: false);
    return (raw as List)
        .whereType<Map>()
        .map((row) => VehicleListing.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<void> submitForReview(String listingId) async {
    final current = await getById(listingId, includeGallery: false);
    final fromStatus = current?.status.wire;
    debugPrint(
      '[VehicleListing][submitReview] listingId=$listingId '
      'sellerId=${current?.sellerId} from=$fromStatus to=pending_review',
    );
    if (current == null) {
      throw VehicleRepositoryException(
        VehiclePublishErrorMapper.fromCode('not_found'),
        code: 'not_found',
      );
    }
    if (current.status == VehicleListingStatus.pendingReview) {
      debugPrint('[VehicleListing][submitReview] result=already_pending');
      return;
    }
    if (current.status == VehicleListingStatus.active) {
      throw VehicleRepositoryException(
        VehiclePublishErrorMapper.fromCode('already_published'),
        code: 'already_published',
      );
    }
    try {
      final raw = await _client.rpc(
        'submit_vehicle_listing_for_review',
        params: {'p_listing_id': listingId},
      );
      _assertOk(raw);
      debugPrint('[VehicleListing][submitReview] result=success rpc');
    } on VehicleRepositoryException catch (error) {
      if (error.code == 'invalid_state' &&
          (current.status == VehicleListingStatus.draft ||
              current.status == VehicleListingStatus.inactive)) {
        await _submitDirect(listingId);
        return;
      }
      debugPrint(
        '[VehicleListing][submitReview] result=failed code=${error.code} '
        'message=${error.message}',
      );
      rethrow;
    } on PostgrestException catch (error, stack) {
      debugPrint(
        '[VehicleListing][submitReview] PostgrestException '
        'code=${error.code} message=${error.message}\n$stack',
      );
      if (_isMissingRpc(error, 'submit_vehicle_listing_for_review') ||
          _isMissingRpc(error, 'publish_vehicle_listing')) {
        await _submitDirect(listingId);
        return;
      }
      throw VehicleRepositoryException(
        VehiclePublishErrorMapper.fromObject(error),
        code: error.code ?? error.message,
      );
    } catch (error, stack) {
      debugPrint('[VehicleListing][submitReview] result=failed $error\n$stack');
      throw VehicleRepositoryException(
        VehiclePublishErrorMapper.fromObject(error),
        code: _errorCode(error),
      );
    }
  }

  Future<void> moderate({
    required String listingId,
    required bool approve,
    String? reason,
  }) async {
    try {
      final raw = await _client.rpc(
        'moderate_vehicle_listing',
        params: {
          'p_listing_id': listingId,
          'p_action': approve ? 'approve' : 'reject',
          'p_reason': reason,
        },
      );
      _assertOk(raw);
    } on VehicleRepositoryException {
      rethrow;
    } on PostgrestException catch (error, stack) {
      debugPrint('[vehicle] moderate rpc failed: $error\n$stack');
      throw VehicleRepositoryException(
        VehiclePublishErrorMapper.fromObject(error),
        code: error.code ?? error.message,
      );
    }
  }

  Future<void> publish(String listingId) async {
    await submitForReview(listingId);
  }

  Future<void> unpublish(String listingId) async {
    await _setStatus(listingId, VehicleListingStatus.inactive);
  }

  Future<void> markSold(String listingId) async {
    debugPrint('[vehicle] sold start listingId=$listingId target=sold');
    await _setStatus(listingId, VehicleListingStatus.sold);
    debugPrint('[vehicle] sold update result=ok listingId=$listingId');
  }

  Future<void> deleteListing(String listingId) async {
    await _client.from('vehicle_listings').delete().eq('id', listingId);
  }

  Future<void> _setStatus(String listingId, VehicleListingStatus to) async {
    final listing = await getById(listingId, includeGallery: false);
    debugPrint(
      '[vehicle] status listingId=$listingId current=${listing?.status.wire} '
      'target=${to.wire}',
    );
    if (listing == null) {
      throw VehicleRepositoryException(
        VehiclePublishErrorMapper.fromCode('not_found'),
        code: 'not_found',
      );
    }
    VehicleStateMachine.transitionListing(listing.status, to);
    await updateListing(listingId, {
      'status': to.wire,
      if (to == VehicleListingStatus.inactive) 'published_at': null,
    });
    debugPrint(
      '[vehicle] status update result=ok listingId=$listingId '
      'from=${listing.status.wire} to=${to.wire}',
    );
  }

  Future<void> _submitDirect(String listingId) async {
    debugPrint('[vehicle] submit rpc missing; using pending_review update');
    final listing = await getById(listingId, includeGallery: false);
    if (listing == null) {
      throw VehicleRepositoryException(
        VehiclePublishErrorMapper.fromCode('not_found'),
        code: 'not_found',
      );
    }
    if (listing.specs.brand.trim().isEmpty ||
        listing.specs.model.trim().isEmpty ||
        listing.specs.year <= 0) {
      throw VehicleRepositoryException(
        VehiclePublishErrorMapper.fromCode('specs_required'),
        code: 'specs_required',
      );
    }
    if (listing.listingType.allowsSale &&
        (listing.salePrice == null || listing.salePrice! <= 0)) {
      throw VehicleRepositoryException(
        VehiclePublishErrorMapper.fromCode('sale_price_required'),
        code: 'sale_price_required',
      );
    }
    if (listing.listingType.allowsRental && listing.rental == null) {
      throw VehicleRepositoryException(
        VehiclePublishErrorMapper.fromCode('rental_settings_required'),
        code: 'rental_settings_required',
      );
    }
    VehicleStateMachine.transitionListing(
      listing.status,
      VehicleListingStatus.pendingReview,
    );
    final extras = Map<String, dynamic>.from(listing.extras);
    extras['moderation'] = {
      'status': 'pending',
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
    };
    await updateListing(listingId, {
      'status': VehicleListingStatus.pendingReview.wire,
      'ai_payload': extras,
    });
    debugPrint(
      '[VehicleListing][submitReview] listingId=$listingId result=success direct',
    );
  }

  static bool _isMissingRpc(PostgrestException error, String name) {
    final blob = '${error.code} ${error.message} ${error.details}'
        .toLowerCase();
    return blob.contains('pgrst202') ||
        blob.contains('could not find the function') ||
        (blob.contains(name) && blob.contains('does not exist'));
  }

  static String? _errorCode(Object error) {
    if (error is PostgrestException) return error.code ?? error.message;
    if (error is VehicleRepositoryException) return error.code;
    return error.runtimeType.toString();
  }

  static void _assertOk(dynamic raw) {
    if (raw is Map && raw['ok'] == true) return;
    final code = raw is Map ? raw['error']?.toString() : 'unknown';
    debugPrint('[vehicle] rpc rejected code=$code raw=$raw');
    throw VehicleRepositoryException(
      VehiclePublishErrorMapper.fromCode(code),
      code: code,
    );
  }

  Future<void> recordView(VehicleListing listing) {
    return recordEvent(listing, 'listing_view');
  }

  Future<void> recordEvent(VehicleListing listing, String eventType) async {
    try {
      await _client.from('vehicle_analytics_events').insert({
        'listing_id': listing.id,
        'seller_id': listing.sellerId,
        'event_type': eventType,
        'actor_id': _client.auth.currentUser?.id,
      });
    } catch (error) {
      debugPrint('[vehicle] analytics event failed type=$eventType: $error');
    }
  }
}
