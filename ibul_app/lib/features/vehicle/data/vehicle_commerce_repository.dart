import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/vehicle_availability.dart';
import '../domain/vehicle_delivery_fee.dart';
import '../models/vehicle_commerce.dart';
import '../models/vehicle_enums.dart';
import 'vehicle_listing_repository.dart';

String _rentalError(String? code) {
  switch (code) {
    case 'not_available':
      return 'Seçilen tarihler dolu.';
    case 'duration_not_allowed':
      return 'Kiralama süresi satıcı limitlerinin dışında.';
    case 'documents_required':
      return 'Kimlik ve ehliyet belgelerini yükleyin.';
    case 'terms_required':
      return 'Kiralama koşullarını kabul edin.';
    case 'reason_required':
      return 'Neden zorunludur.';
    case 'payment_provider_required':
      return 'Ödeme altyapısı bağlı değil.';
    case 'contract_required':
    case 'contract_mismatch':
      return 'Araç kiralama sözleşmesini görüntüleyip kabul edin.';
    case 'invalid_national_id':
      return 'TC Kimlik No geçersiz.';
    case 'validation_failed':
      return 'Kiralayan bilgilerini tamamlayın.';
    case 'past_date':
      return 'Geçmiş tarih seçilemez.';
    case 'payment_window_expired':
      return 'Ödeme süresi doldu.';
    case 'invalid_state':
      return 'Bu rezervasyon durumunda işlem yapılamaz.';
    case 'out_of_zone':
      return VehicleDeliveryQuoteError.message('out_of_zone');
    case 'location_required':
    case 'missing_coordinates':
      return VehicleDeliveryQuoteError.message('location_required');
    case 'delivery_zone_missing':
    case 'home_delivery_disabled':
      return VehicleDeliveryQuoteError.message('home_delivery_disabled');
    case 'map_point_disabled':
      return VehicleDeliveryQuoteError.message('map_point_disabled');
    case 'airport_zone_missing':
      return VehicleDeliveryQuoteError.message('airport_zone_missing');
    case 'gallery_location_missing':
      return VehicleDeliveryQuoteError.message('gallery_location_missing');
    default:
      return 'Kiralama işlemi tamamlanamadı.';
  }
}

class VehicleReservationRepository {
  VehicleReservationRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> quoteDelivery({
    required String listingId,
    required VehicleDeliveryMode mode,
    double? lat,
    double? lng,
    bool airport = false,
  }) async {
    final raw = await _client.rpc(
      'quote_vehicle_delivery_fee',
      params: {
        'p_listing_id': listingId,
        'p_mode': mode.wire,
        'p_lat': lat,
        'p_lng': lng,
        'p_airport': airport,
      },
    );
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<List<VehicleDeliveryZoneQuote>> listDeliveryZones(String sellerId) async {
    final raw = await _client
        .from('vehicle_delivery_zones')
        .select('label, min_km, max_km, fee, is_airport')
        .eq('seller_id', sellerId);
    return (raw as List)
        .whereType<Map>()
        .map(
          (row) => VehicleDeliveryZoneQuote(
            label: row['label']?.toString() ?? 'Teslimat',
            minKm: (row['min_km'] as num?)?.toDouble() ?? 0,
            maxKm: (row['max_km'] as num?)?.toDouble() ?? 0,
            fee: (row['fee'] as num?)?.toDouble() ?? 0,
            isAirport: row['is_airport'] == true,
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> createReservation({
    required String listingId,
    required DateTime pickupAt,
    required DateTime returnAt,
    required VehicleDeliveryMode mode,
    String? address,
    double? lat,
    double? lng,
    bool airport = false,
    VehicleDeliveryMode? dropoffMode,
    String? dropoffAddress,
    double? dropoffLat,
    double? dropoffLng,
    String? customerName,
    String? customerPhone,
    DateTime? customerBirthDate,
    String? customerEmail,
    String? customerNote,
    String? customerNationalId,
  }) async {
    final raw = await _client.rpc(
      'create_vehicle_rental_reservation',
      params: {
        'p_listing_id': listingId,
        'p_pickup_at': pickupAt.toUtc().toIso8601String(),
        'p_return_at': returnAt.toUtc().toIso8601String(),
        'p_delivery_mode': mode.wire,
        'p_delivery_address': address,
        'p_lat': lat,
        'p_lng': lng,
        'p_airport': airport,
        'p_dropoff_mode': (dropoffMode ?? VehicleDeliveryMode.galleryPickup).wire,
        'p_dropoff_address': dropoffAddress,
        'p_dropoff_lat': dropoffLat,
        'p_dropoff_lng': dropoffLng,
        'p_customer_name': customerName,
        'p_customer_phone': customerPhone,
        'p_customer_birth_date': customerBirthDate
            ?.toIso8601String()
            .split('T')
            .first,
        'p_customer_email': customerEmail,
        'p_customer_note': customerNote,
        'p_customer_national_id': customerNationalId,
      },
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true) {
      throw VehicleRepositoryException(
        _rentalError(map['error']?.toString()),
        code: map['error']?.toString(),
      );
    }
    return map;
  }

  Future<VehicleReservation?> latestDraft({required String listingId}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('vehicle_reservations')
        .select('*, vehicle_listings(cover_url, specs, ai_payload)')
        .eq('listing_id', listingId)
        .eq('customer_id', uid)
        .eq('status', 'pending_docs')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return VehicleReservation.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Map<String, dynamic>> updateDraft({
    required String reservationId,
    required DateTime pickupAt,
    required DateTime returnAt,
    required VehicleDeliveryMode mode,
    String? address,
    double? lat,
    double? lng,
    bool airport = false,
    VehicleDeliveryMode? dropoffMode,
    String? dropoffAddress,
    String? customerName,
    String? customerPhone,
    DateTime? customerBirthDate,
    String? customerEmail,
    String? customerNote,
    String? customerNationalId,
  }) async {
    final raw = await _client.rpc(
      'update_vehicle_rental_draft',
      params: {
        'p_reservation_id': reservationId,
        'p_pickup_at': pickupAt.toUtc().toIso8601String(),
        'p_return_at': returnAt.toUtc().toIso8601String(),
        'p_delivery_mode': mode.wire,
        'p_delivery_address': address,
        'p_lat': lat,
        'p_lng': lng,
        'p_airport': airport,
        'p_dropoff_mode': (dropoffMode ?? VehicleDeliveryMode.galleryPickup).wire,
        'p_dropoff_address': dropoffAddress,
        'p_customer_name': customerName,
        'p_customer_phone': customerPhone,
        'p_customer_birth_date': customerBirthDate
            ?.toIso8601String()
            .split('T')
            .first,
        'p_customer_email': customerEmail,
        'p_customer_note': customerNote,
        'p_customer_national_id': customerNationalId,
      },
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true) {
      throw VehicleRepositoryException(
        _rentalError(map['error']?.toString()),
        code: map['error']?.toString(),
      );
    }
    return map;
  }

  Future<void> acceptTerms(String reservationId) async {
    final raw = await _client.rpc(
      'accept_vehicle_rental_terms',
      params: {'p_reservation_id': reservationId},
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true) {
      throw VehicleRepositoryException(
        'Koşullar kaydedilemedi',
        code: map['error']?.toString(),
      );
    }
  }

  Future<String> confirmPayment(String reservationId, {String? orderId}) async {
    if (orderId == null || orderId.trim().isEmpty) {
      throw VehicleRepositoryException(
        'Ödeme altyapısı bağlı değil. Tahsilat şimdilik alınmaz.',
        code: 'payment_provider_required',
      );
    }
    final raw = await _client.rpc(
      'confirm_vehicle_rental_payment',
      params: {'p_reservation_id': reservationId, 'p_order_id': orderId},
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true) {
      throw VehicleRepositoryException(
        _rentalError(map['error']?.toString()),
        code: map['error']?.toString(),
      );
    }
    return map['handover_code']?.toString() ?? '';
  }

  Future<Map<String, dynamic>> submitForReview(String reservationId) async {
    final raw = await _client.rpc(
      'submit_vehicle_rental_for_review',
      params: {'p_reservation_id': reservationId},
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true) {
      throw VehicleRepositoryException(
        _rentalError(map['error']?.toString()),
        code: map['error']?.toString(),
      );
    }
    return map;
  }

  Future<void> respond({
    required String reservationId,
    required String action,
    String? reason,
  }) async {
    final raw = await _client.rpc(
      'respond_vehicle_rental_reservation',
      params: {
        'p_reservation_id': reservationId,
        'p_action': action,
        'p_reason': reason,
      },
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true) {
      throw VehicleRepositoryException(
        _rentalError(map['error']?.toString()),
        code: map['error']?.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> cancel({
    required String reservationId,
    String? reason,
  }) async {
    final raw = await _client.rpc(
      'cancel_vehicle_rental_reservation',
      params: {'p_reservation_id': reservationId, 'p_reason': reason},
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true) {
      throw VehicleRepositoryException(
        _rentalError(map['error']?.toString()),
        code: map['error']?.toString(),
      );
    }
    return map;
  }

  Future<List<VehicleBusyInterval>> busyWindows(String listingId) async {
    final raw = await _client.rpc(
      'get_vehicle_unavailable_ranges',
      params: {'p_listing_id': listingId},
    );
    return [
      for (final row in _jsonRows(raw))
        VehicleBusyInterval(
          start: DateTime.parse(row['start_at'].toString()).toLocal(),
          end: DateTime.parse(row['end_at'].toString()).toLocal(),
          kind: VehicleBusyInterval.normalizeKind(row['kind']?.toString()),
        ),
    ];
  }

  static List<Map<String, dynamic>> _jsonRows(dynamic raw) {
    Object? value = raw;
    if (value is String && value.isNotEmpty) {
      value = jsonDecode(value);
    }
    if (value is! List) return const [];
    return [
      for (final row in value)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  Future<List<Map<String, dynamic>>> listBlocks(String listingId) async {
    final raw = await _client
        .from('vehicle_rental_blocks')
        .select()
        .eq('listing_id', listingId)
        .order('start_at');
    return (raw as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<void> upsertBlock({
    required String listingId,
    required String sellerId,
    required DateTime startAt,
    required DateTime endAt,
    required String kind,
    String? note,
  }) async {
    await _client.from('vehicle_rental_blocks').insert({
      'listing_id': listingId,
      'seller_id': sellerId,
      'start_at': startAt.toUtc().toIso8601String(),
      'end_at': endAt.toUtc().toIso8601String(),
      'kind': kind,
      'note': note,
    });
  }

  Future<void> deleteBlock(String blockId) async {
    await _client.from('vehicle_rental_blocks').delete().eq('id', blockId);
  }

  Future<List<Map<String, dynamic>>> listDocuments(String reservationId) async {
    final raw = await _client
        .from('vehicle_kyc_documents')
        .select('id, doc_type, status, created_at')
        .eq('reservation_id', reservationId)
        .order('created_at', ascending: false);
    final latest = <String, Map<String, dynamic>>{};
    for (final row in (raw as List).whereType<Map>()) {
      final map = Map<String, dynamic>.from(row);
      final type = map['doc_type']?.toString() ?? '';
      if (type.isEmpty || latest.containsKey(type)) continue;
      latest[type] = map;
    }
    return latest.values.toList(growable: false);
  }

  Future<String?> documentPreviewUrl(String documentId) async {
    final row = await _client
        .from('vehicle_kyc_documents')
        .select('object_path')
        .eq('id', documentId)
        .maybeSingle();
    final path = row?['object_path']?.toString();
    if (path == null || path.isEmpty) return null;
    return _client.storage.from('vehicle-documents').createSignedUrl(path, 120);
  }

  Future<void> handover({
    required String reservationId,
    required String code,
  }) async {
    final raw = await _client.rpc(
      'complete_vehicle_handover',
      params: {'p_reservation_id': reservationId, 'p_code': code},
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true) {
      throw VehicleRepositoryException(
        'Teslim tamamlanamadı',
        code: map['error']?.toString(),
      );
    }
  }

  Future<void> completeReturn({
    required String reservationId,
    int? odometerKm,
    String? fuelLevel,
    String? damageNote,
    List<String> photoUrls = const [],
    String? notes,
  }) async {
    final raw = await _client.rpc(
      'complete_vehicle_return',
      params: {
        'p_reservation_id': reservationId,
        'p_odometer_km': odometerKm,
        'p_fuel_level': fuelLevel,
        'p_damage_note': damageNote,
        'p_photo_urls': photoUrls,
        'p_notes': notes,
      },
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true) {
      throw VehicleRepositoryException(
        'İade tamamlanamadı',
        code: map['error']?.toString(),
      );
    }
  }

  Future<List<VehicleReservation>> listAllForAdmin() async {
    final raw = await _client
        .from('vehicle_reservations')
        .select()
        .order('created_at', ascending: false)
        .limit(200);
    return (raw as List)
        .whereType<Map>()
        .map(
          (row) => VehicleReservation.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<List<VehicleReservation>> listMine({required bool asSeller}) async {
    await expireUnpaid();
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final col = asSeller ? 'seller_id' : 'customer_id';
    Object raw;
    try {
      raw = await _client
          .from('vehicle_reservations')
          .select('*, vehicle_listings(cover_url, specs, ai_payload)')
          .eq(col, uid)
          .order('created_at', ascending: false);
    } catch (_) {
      raw = await _client
          .from('vehicle_reservations')
          .select()
          .eq(col, uid)
          .order('created_at', ascending: false);
    }
    return (raw as List)
        .whereType<Map>()
        .map(
          (row) => VehicleReservation.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<void> expireUnpaid() async {
    try {
      await _client.rpc('expire_unpaid_vehicle_rentals');
    } catch (_) {}
  }

  Future<VehicleReservation?> getMineById(String id) async {
    await expireUnpaid();
    Object? raw;
    try {
      raw = await _client
          .from('vehicle_reservations')
          .select('*, vehicle_listings(cover_url, specs, ai_payload)')
          .eq('id', id)
          .maybeSingle();
    } catch (_) {
      raw = await _client
          .from('vehicle_reservations')
          .select()
          .eq('id', id)
          .maybeSingle();
    }
    if (raw is! Map) return null;
    return VehicleReservation.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> uploadKyc({
    required String reservationId,
    required String customerId,
    required VehicleDocumentType type,
    required String objectPath,
  }) async {
    await _client.from('vehicle_kyc_documents').insert({
      'reservation_id': reservationId,
      'customer_id': customerId,
      'doc_type': type.wire,
      'status': 'submitted',
      'bucket': 'vehicle-documents',
      'object_path': objectPath,
    });
  }

  static const int kycMaxBytes = 8 * 1024 * 1024;

  Future<String> uploadKycBytes({
    required String reservationId,
    required String customerId,
    required VehicleDocumentType type,
    required List<int> bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      throw VehicleRepositoryException('Belge yüklenemedi', code: 'empty_file');
    }
    if (bytes.length > kycMaxBytes) {
      throw VehicleRepositoryException(
        'Belge 8 MB sınırını aşıyor.',
        code: 'file_too_large',
      );
    }
    final name = fileName.toLowerCase();
    final allowed = name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.pdf');
    if (!allowed) {
      throw VehicleRepositoryException(
        'Sadece JPG, PNG veya PDF yükleyebilirsiniz.',
        code: 'invalid_type',
      );
    }
    final ext = name.endsWith('.png')
        ? 'png'
        : name.endsWith('.pdf')
            ? 'pdf'
            : 'jpg';
    final contentType = ext == 'png'
        ? 'image/png'
        : ext == 'pdf'
            ? 'application/pdf'
            : 'image/jpeg';
    final objectPath =
        '$customerId/$reservationId/${type.wire}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    try {
      await _client.storage.from('vehicle-documents').uploadBinary(
            objectPath,
            bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false,
              cacheControl: 'private, max-age=0',
            ),
          );
    } catch (_) {
      throw VehicleRepositoryException(
        'Belge yüklenemedi',
        code: 'upload_failed',
      );
    }
    await uploadKyc(
      reservationId: reservationId,
      customerId: customerId,
      type: type,
      objectPath: objectPath,
    );
    return objectPath;
  }

  Future<void> deleteKyc({
    required String reservationId,
    required VehicleDocumentType type,
  }) async {
    final raw = await _client
        .from('vehicle_kyc_documents')
        .select('id, object_path')
        .eq('reservation_id', reservationId)
        .eq('doc_type', type.wire);
    for (final row in raw as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final path = map['object_path']?.toString();
      if (path != null && path.isNotEmpty) {
        try {
          await _client.storage.from('vehicle-documents').remove([path]);
        } catch (_) {}
      }
      await _client.from('vehicle_kyc_documents').delete().eq('id', map['id']);
    }
  }
}

class VehicleQuoteRepository {
  VehicleQuoteRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> submit({
    required String listingId,
    required String sellerId,
    required double amount,
    String? note,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw VehicleRepositoryException('Giriş gerekli', code: 'auth_required');
    }
    final inserted = await _client
        .from('vehicle_quotes')
        .insert({
          'listing_id': listingId,
          'seller_id': sellerId,
          'customer_id': uid,
          'amount': amount,
          'note': note,
        })
        .select('id')
        .single();
    await _client.from('vehicle_quote_events').insert({
      'quote_id': inserted['id'],
      'actor_id': uid,
      'action': 'submit',
      'amount': amount,
      'note': note,
    });
    await _client.from('vehicle_analytics_events').insert({
      'listing_id': listingId,
      'seller_id': sellerId,
      'event_type': 'quote',
      'actor_id': uid,
    });
  }

  Future<void> respond({
    required String quoteId,
    required String action,
    double? counterAmount,
    String? note,
  }) async {
    final raw = await _client.rpc(
      'respond_vehicle_quote',
      params: {
        'p_quote_id': quoteId,
        'p_action': action,
        'p_counter_amount': counterAmount,
        'p_note': note,
      },
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true) {
      throw VehicleRepositoryException(
        'Teklif yanıtlanamadı',
        code: map['error']?.toString(),
      );
    }
  }

  Future<List<VehicleQuote>> listForSeller() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final raw = await _client
        .from('vehicle_quotes')
        .select()
        .eq('seller_id', uid)
        .order('created_at', ascending: false);
    return (raw as List)
        .whereType<Map>()
        .map((row) => VehicleQuote.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }
}

class VehicleAppointmentRepository {
  VehicleAppointmentRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> create({
    required String listingId,
    required String sellerId,
    required VehicleAppointmentKind kind,
    required DateTime scheduledAt,
    String? address,
    double? lat,
    double? lng,
    String? note,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw VehicleRepositoryException('Giriş gerekli', code: 'auth_required');
    }
    await _client.from('vehicle_appointments').insert({
      'listing_id': listingId,
      'seller_id': sellerId,
      'customer_id': uid,
      'kind': kind.wire,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'address': address,
      'lat': lat,
      'lng': lng,
      'note': note,
    });
    await _client.from('vehicle_analytics_events').insert({
      'listing_id': listingId,
      'seller_id': sellerId,
      'event_type': 'appointment',
      'actor_id': uid,
    });
  }

  Future<void> respond({
    required String appointmentId,
    required String action,
  }) async {
    final raw = await _client.rpc(
      'respond_vehicle_appointment',
      params: {'p_appointment_id': appointmentId, 'p_action': action},
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true) {
      throw VehicleRepositoryException(
        'Randevu güncellenemedi',
        code: map['error']?.toString(),
      );
    }
  }

  Future<List<VehicleAppointment>> listForSeller() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final raw = await _client
        .from('vehicle_appointments')
        .select()
        .eq('seller_id', uid)
        .order('scheduled_at');
    return (raw as List)
        .whereType<Map>()
        .map(
          (row) => VehicleAppointment.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }
}
