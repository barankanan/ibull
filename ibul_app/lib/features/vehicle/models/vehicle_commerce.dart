import 'vehicle_enums.dart';

class VehicleSearchQuery {
  const VehicleSearchQuery({
    this.text,
    this.brand,
    this.model,
    this.version,
    this.yearMin,
    this.yearMax,
    this.priceMin,
    this.priceMax,
    this.kmMin,
    this.kmMax,
    this.fuel,
    this.transmission,
    this.bodyType,
    this.engineCcMin,
    this.engineCcMax,
    this.powerHpMin,
    this.powerHpMax,
    this.color,
    this.city,
    this.district,
    this.saleOnly = false,
    this.rentalOnly = false,
    this.verifiedOnly = false,
    this.tradeIn = false,
    this.financing = false,
    this.homeDelivery = false,
    this.nearLat,
    this.nearLng,
    this.nearRadiusKm,
    this.limit = 20,
    this.offset = 0,
  });

  final String? text;
  final String? brand;
  final String? model;
  final String? version;
  final int? yearMin;
  final int? yearMax;
  final double? priceMin;
  final double? priceMax;
  final int? kmMin;
  final int? kmMax;
  final String? fuel;
  final String? transmission;
  final String? bodyType;
  final int? engineCcMin;
  final int? engineCcMax;
  final int? powerHpMin;
  final int? powerHpMax;
  final String? color;
  final String? city;
  final String? district;
  final bool saleOnly;
  final bool rentalOnly;
  final bool verifiedOnly;
  final bool tradeIn;
  final bool financing;
  final bool homeDelivery;
  final double? nearLat;
  final double? nearLng;
  final double? nearRadiusKm;
  final int limit;
  final int offset;

  Map<String, dynamic> toRpcParams() => {
    'p_query': text,
    'p_brand': brand,
    'p_model': model,
    'p_version': version,
    'p_year_min': yearMin,
    'p_year_max': yearMax,
    'p_price_min': priceMin,
    'p_price_max': priceMax,
    'p_km_min': kmMin,
    'p_km_max': kmMax,
    'p_fuel': fuel,
    'p_transmission': transmission,
    'p_body_type': bodyType,
    'p_engine_cc_min': engineCcMin,
    'p_engine_cc_max': engineCcMax,
    'p_power_hp_min': powerHpMin,
    'p_power_hp_max': powerHpMax,
    'p_color': color,
    'p_city': city,
    'p_district': district,
    'p_sale_only': saleOnly,
    'p_rental_only': rentalOnly,
    'p_verified_only': verifiedOnly,
    'p_trade_in': tradeIn,
    'p_financing': financing,
    'p_home_delivery': homeDelivery,
    'p_limit': limit.clamp(1, 50),
    'p_offset': offset < 0 ? 0 : offset,
  };
}

class VehicleReservation {
  const VehicleReservation({
    required this.id,
    required this.listingId,
    required this.customerId,
    required this.sellerId,
    required this.status,
    required this.pickupAt,
    required this.returnAt,
    required this.deliveryMode,
    required this.rentalSubtotal,
    required this.deliveryFee,
    required this.deposit,
    required this.total,
    this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.dropoffMode,
    this.dropoffAddress,
    this.orderId,
    this.handoverCode,
    this.rentalCode,
    this.paymentStatus = 'unpaid',
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerNationalId,
    this.rejectReason,
    this.cancelReason,
    this.refundAmount,
    this.listingTitle,
    this.listingCoverUrl,
    this.customerNote,
    this.termsAcceptedAt,
    this.approvedAt,
    this.paymentDueAt,
    this.paidAt,
  });

  final String id;
  final String listingId;
  final String customerId;
  final String sellerId;
  final VehicleReservationStatus status;
  final DateTime pickupAt;
  final DateTime returnAt;
  final VehicleDeliveryMode deliveryMode;
  final double rentalSubtotal;
  final double deliveryFee;
  final double deposit;
  final double total;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final VehicleDeliveryMode? dropoffMode;
  final String? dropoffAddress;
  final String? orderId;
  final String? handoverCode;
  final String? rentalCode;
  final String paymentStatus;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerNationalId;
  final String? rejectReason;
  final String? cancelReason;
  final double? refundAmount;
  final String? listingTitle;
  final String? listingCoverUrl;
  final String? customerNote;
  final DateTime? termsAcceptedAt;
  final DateTime? approvedAt;
  final DateTime? paymentDueAt;
  final DateTime? paidAt;

  factory VehicleReservation.fromMap(Map<String, dynamic> map) {
    return VehicleReservation(
      id: (map['id'] ?? '').toString(),
      listingId: (map['listing_id'] ?? '').toString(),
      customerId: (map['customer_id'] ?? '').toString(),
      sellerId: (map['seller_id'] ?? '').toString(),
      status: VehicleReservationStatusX.parse(map['status']?.toString()),
      pickupAt: DateTime.parse(map['pickup_at'].toString()),
      returnAt: DateTime.parse(map['return_at'].toString()),
      deliveryMode: VehicleDeliveryModeX.parse(
        map['delivery_mode']?.toString() ?? 'gallery_pickup',
      ),
      rentalSubtotal: (map['rental_subtotal'] as num?)?.toDouble() ?? 0,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0,
      deposit: (map['deposit'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      deliveryAddress: map['delivery_address']?.toString(),
      deliveryLat: (map['delivery_lat'] as num?)?.toDouble(),
      deliveryLng: (map['delivery_lng'] as num?)?.toDouble(),
      dropoffMode: map['dropoff_mode'] == null
          ? null
          : VehicleDeliveryModeX.parse(map['dropoff_mode'].toString()),
      dropoffAddress: map['dropoff_address']?.toString(),
      orderId: map['order_id']?.toString(),
      handoverCode: map['handover_code']?.toString(),
      rentalCode: map['rental_code']?.toString(),
      paymentStatus: map['payment_status']?.toString() ?? 'unpaid',
      customerName: map['customer_name']?.toString(),
      customerPhone: map['customer_phone']?.toString(),
      customerEmail: map['customer_email']?.toString(),
      customerNationalId: map['customer_national_id']?.toString(),
      rejectReason: map['reject_reason']?.toString(),
      cancelReason: map['cancel_reason']?.toString(),
      refundAmount: (map['refund_amount'] as num?)?.toDouble(),
      listingTitle: _nestedListingTitle(map),
      listingCoverUrl: _nestedListingCover(map),
      customerNote: map['customer_note']?.toString(),
      termsAcceptedAt: DateTime.tryParse(map['terms_accepted_at']?.toString() ?? ''),
      approvedAt: DateTime.tryParse(map['approved_at']?.toString() ?? ''),
      paymentDueAt: DateTime.tryParse(map['payment_due_at']?.toString() ?? ''),
      paidAt: DateTime.tryParse(map['paid_at']?.toString() ?? ''),
    );
  }

  VehicleReservation copyWith({
    VehicleReservationStatus? status,
    String? paymentStatus,
    String? cancelReason,
    DateTime? approvedAt,
    DateTime? paymentDueAt,
    DateTime? paidAt,
  }) {
    return VehicleReservation(
      id: id,
      listingId: listingId,
      customerId: customerId,
      sellerId: sellerId,
      status: status ?? this.status,
      pickupAt: pickupAt,
      returnAt: returnAt,
      deliveryMode: deliveryMode,
      rentalSubtotal: rentalSubtotal,
      deliveryFee: deliveryFee,
      deposit: deposit,
      total: total,
      deliveryAddress: deliveryAddress,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      dropoffMode: dropoffMode,
      dropoffAddress: dropoffAddress,
      orderId: orderId,
      handoverCode: handoverCode,
      rentalCode: rentalCode,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerNationalId: customerNationalId,
      rejectReason: rejectReason,
      cancelReason: cancelReason ?? this.cancelReason,
      refundAmount: refundAmount,
      listingTitle: listingTitle,
      listingCoverUrl: listingCoverUrl,
      customerNote: customerNote,
      termsAcceptedAt: termsAcceptedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      paymentDueAt: paymentDueAt ?? this.paymentDueAt,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}

Map<String, dynamic>? _nestedListingMap(Map<String, dynamic> map) {
  final raw = map['vehicle_listings'];
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List && raw.isNotEmpty && raw.first is Map) {
    return Map<String, dynamic>.from(raw.first as Map);
  }
  return null;
}

String? _nestedListingCover(Map<String, dynamic> map) {
  return _nestedListingMap(map)?['cover_url']?.toString();
}

String? _nestedListingTitle(Map<String, dynamic> map) {
  final listing = _nestedListingMap(map);
  if (listing == null) return null;
  final extras = listing['ai_payload'] ?? listing['extras'];
  if (extras is Map) {
    final title = extras['title']?.toString().trim() ?? '';
    if (title.isNotEmpty) return title;
  }
  final specs = listing['specs'];
  if (specs is Map) {
    final brand = specs['brand']?.toString().trim() ?? '';
    final model = specs['model']?.toString().trim() ?? '';
    final title = '$brand $model'.trim();
    if (title.isNotEmpty) return title;
  }
  return null;
}

class VehicleQuote {
  const VehicleQuote({
    required this.id,
    required this.listingId,
    required this.customerId,
    required this.sellerId,
    required this.amount,
    required this.status,
    this.counterAmount,
    this.note,
    this.createdAt,
  });

  final String id;
  final String listingId;
  final String customerId;
  final String sellerId;
  final double amount;
  final VehicleQuoteStatus status;
  final double? counterAmount;
  final String? note;
  final DateTime? createdAt;

  factory VehicleQuote.fromMap(Map<String, dynamic> map) {
    return VehicleQuote(
      id: (map['id'] ?? '').toString(),
      listingId: (map['listing_id'] ?? '').toString(),
      customerId: (map['customer_id'] ?? '').toString(),
      sellerId: (map['seller_id'] ?? '').toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      status: VehicleQuoteStatusX.parse(map['status']?.toString()),
      counterAmount: (map['counter_amount'] as num?)?.toDouble(),
      note: map['note']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }
}

class VehicleAppointment {
  const VehicleAppointment({
    required this.id,
    required this.listingId,
    required this.customerId,
    required this.sellerId,
    required this.kind,
    required this.status,
    required this.scheduledAt,
    this.address,
    this.lat,
    this.lng,
    this.note,
  });

  final String id;
  final String listingId;
  final String customerId;
  final String sellerId;
  final VehicleAppointmentKind kind;
  final VehicleAppointmentStatus status;
  final DateTime scheduledAt;
  final String? address;
  final double? lat;
  final double? lng;
  final String? note;

  factory VehicleAppointment.fromMap(Map<String, dynamic> map) {
    return VehicleAppointment(
      id: (map['id'] ?? '').toString(),
      listingId: (map['listing_id'] ?? '').toString(),
      customerId: (map['customer_id'] ?? '').toString(),
      sellerId: (map['seller_id'] ?? '').toString(),
      kind: VehicleAppointmentKindX.parse(map['kind']?.toString()),
      status: VehicleAppointmentStatusX.parse(map['status']?.toString()),
      scheduledAt: DateTime.parse(map['scheduled_at'].toString()),
      address: map['address']?.toString(),
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      note: map['note']?.toString(),
    );
  }
}

class VehicleDashboardStats {
  const VehicleDashboardStats({
    required this.total,
    required this.active,
    required this.rental,
    required this.reserved,
    required this.sold,
    required this.maintenance,
    required this.unreadMessages,
    required this.newQuotes,
    required this.newReservations,
    required this.appointmentsToday,
    required this.handoversToday,
    required this.returnsToday,
    required this.views,
    required this.favorites,
    required this.quotes,
    required this.sales,
    required this.activeRentals,
    required this.upcomingReservations,
  });

  final int total;
  final int active;
  final int rental;
  final int reserved;
  final int sold;
  final int maintenance;
  final int unreadMessages;
  final int newQuotes;
  final int newReservations;
  final int appointmentsToday;
  final int handoversToday;
  final int returnsToday;
  final int views;
  final int favorites;
  final int quotes;
  final int sales;
  final int activeRentals;
  final int upcomingReservations;

  factory VehicleDashboardStats.fromMap(Map<String, dynamic> map) {
    int n(String key) => (map[key] as num?)?.toInt() ?? 0;
    return VehicleDashboardStats(
      total: n('total'),
      active: n('active'),
      rental: n('rental'),
      reserved: n('reserved'),
      sold: n('sold'),
      maintenance: n('maintenance'),
      unreadMessages: n('unread_messages'),
      newQuotes: n('new_quotes'),
      newReservations: n('new_reservations'),
      appointmentsToday: n('appointments_today'),
      handoversToday: n('handovers_today'),
      returnsToday: n('returns_today'),
      views: n('views'),
      favorites: n('favorites'),
      quotes: n('quotes'),
      sales: n('sales'),
      activeRentals: n('active_rentals'),
      upcomingReservations: n('upcoming_reservations'),
    );
  }

  static const empty = VehicleDashboardStats(
    total: 0,
    active: 0,
    rental: 0,
    reserved: 0,
    sold: 0,
    maintenance: 0,
    unreadMessages: 0,
    newQuotes: 0,
    newReservations: 0,
    appointmentsToday: 0,
    handoversToday: 0,
    returnsToday: 0,
    views: 0,
    favorites: 0,
    quotes: 0,
    sales: 0,
    activeRentals: 0,
    upcomingReservations: 0,
  );
}
