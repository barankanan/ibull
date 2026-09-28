/// Araç dikeyi durum ve tip sözlüğü. Geçersiz string'ler parse edilmez.
enum VehicleListingType { sale, rental, both }

enum VehicleListingStatus {
  draft,
  pendingReview,
  active,
  reserved,
  sold,
  rented,
  returnPending,
  maintenance,
  inactive,
}

enum VehicleOfferKind { sale, rental }

enum VehicleQuoteStatus { pending, accepted, rejected, countered }

enum VehicleAppointmentKind { gallery, customerLocation, meetingPoint }

enum VehicleAppointmentStatus {
  pending,
  confirmed,
  rejected,
  completed,
  cancelled,
}

enum VehicleReservationStatus {
  pendingPayment,
  pendingDocs,
  pendingSellerReview,
  confirmed,
  reserved,
  activeRental,
  returnPending,
  completed,
  cancelled,
  rejected,
  refundPending,
  sellerCancelled,
}

enum VehicleDeliveryMode { galleryPickup, mapPoint, homeDelivery }

enum VehicleDocumentType {
  identity,
  driverLicense,
  other,
  identityFront,
  identityBack,
  driverLicenseFront,
  driverLicenseBack,
}

enum VehicleDocumentStatus {
  uploaded,
  pendingReview,
  submitted,
  verified,
  approved,
  rejected,
}

enum VehicleMediaSlot {
  front,
  rear,
  right,
  left,
  interior,
  dashboard,
  engine,
  trunk,
  tire,
  damage,
  expertise,
  video,
  spin360,
  other,
}

enum VehicleVerificationSource { dealerEntered, documentVerified }

extension VehicleListingTypeX on VehicleListingType {
  String get wire {
    switch (this) {
      case VehicleListingType.sale:
        return 'sale';
      case VehicleListingType.rental:
        return 'rental';
      case VehicleListingType.both:
        return 'both';
    }
  }

  bool get allowsSale =>
      this == VehicleListingType.sale || this == VehicleListingType.both;

  bool get allowsRental =>
      this == VehicleListingType.rental || this == VehicleListingType.both;

  static VehicleListingType parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'sale':
      case 'satilik':
      case 'satılık':
        return VehicleListingType.sale;
      case 'rental':
      case 'kiralik':
      case 'kiralık':
        return VehicleListingType.rental;
      case 'both':
      case 'satilik_kiralik':
        return VehicleListingType.both;
      default:
        throw FormatException('Unknown vehicle listing type: $raw');
    }
  }
}

extension VehicleListingStatusX on VehicleListingStatus {
  String get wire {
    switch (this) {
      case VehicleListingStatus.draft:
        return 'draft';
      case VehicleListingStatus.pendingReview:
        return 'pending_review';
      case VehicleListingStatus.active:
        return 'active';
      case VehicleListingStatus.reserved:
        return 'reserved';
      case VehicleListingStatus.sold:
        return 'sold';
      case VehicleListingStatus.rented:
        return 'rented';
      case VehicleListingStatus.returnPending:
        return 'return_pending';
      case VehicleListingStatus.maintenance:
        return 'maintenance';
      case VehicleListingStatus.inactive:
        return 'inactive';
    }
  }

  bool get isPubliclyVisible =>
      this == VehicleListingStatus.active ||
      this == VehicleListingStatus.reserved ||
      this == VehicleListingStatus.rented;

  String get labelTr {
    switch (this) {
      case VehicleListingStatus.draft:
        return 'Taslak';
      case VehicleListingStatus.pendingReview:
        return 'Onay bekliyor';
      case VehicleListingStatus.active:
        return 'Yayında';
      case VehicleListingStatus.reserved:
        return 'Rezerve';
      case VehicleListingStatus.sold:
        return 'Satıldı';
      case VehicleListingStatus.rented:
        return 'Kirada';
      case VehicleListingStatus.returnPending:
        return 'İade bekliyor';
      case VehicleListingStatus.maintenance:
        return 'Bakımda';
      case VehicleListingStatus.inactive:
        return 'Duraklatıldı';
    }
  }

  static VehicleListingStatus parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'draft':
      case 'taslak':
        return VehicleListingStatus.draft;
      case 'pending_review':
      case 'inceleme':
        return VehicleListingStatus.pendingReview;
      case 'active':
      case 'aktif':
        return VehicleListingStatus.active;
      case 'reserved':
      case 'rezerve':
        return VehicleListingStatus.reserved;
      case 'sold':
      case 'satildi':
      case 'satıldı':
        return VehicleListingStatus.sold;
      case 'rented':
      case 'kirada':
        return VehicleListingStatus.rented;
      case 'return_pending':
        return VehicleListingStatus.returnPending;
      case 'maintenance':
      case 'bakimda':
      case 'bakımda':
        return VehicleListingStatus.maintenance;
      case 'inactive':
      case 'pasif':
        return VehicleListingStatus.inactive;
      default:
        throw FormatException('Unknown vehicle listing status: $raw');
    }
  }
}

extension VehicleReservationStatusX on VehicleReservationStatus {
  String get wire {
    switch (this) {
      case VehicleReservationStatus.pendingPayment:
        return 'pending_payment';
      case VehicleReservationStatus.pendingDocs:
        return 'pending_docs';
      case VehicleReservationStatus.pendingSellerReview:
        return 'pending_seller_review';
      case VehicleReservationStatus.confirmed:
        return 'confirmed';
      case VehicleReservationStatus.reserved:
        return 'reserved';
      case VehicleReservationStatus.activeRental:
        return 'active_rental';
      case VehicleReservationStatus.returnPending:
        return 'return_pending';
      case VehicleReservationStatus.completed:
        return 'completed';
      case VehicleReservationStatus.cancelled:
        return 'cancelled';
      case VehicleReservationStatus.rejected:
        return 'rejected';
      case VehicleReservationStatus.refundPending:
        return 'refund_pending';
      case VehicleReservationStatus.sellerCancelled:
        return 'seller_cancelled';
    }
  }

  bool get blocksCalendar =>
      this == VehicleReservationStatus.confirmed ||
      this == VehicleReservationStatus.reserved ||
      this == VehicleReservationStatus.activeRental ||
      this == VehicleReservationStatus.returnPending;

  String get labelTr => switch (this) {
    VehicleReservationStatus.pendingDocs => 'Belge bekleniyor',
    VehicleReservationStatus.pendingSellerReview => 'Satıcı incelemesi',
    VehicleReservationStatus.pendingPayment => 'Ödeme bekleniyor',
    VehicleReservationStatus.confirmed => 'Onaylandı',
    VehicleReservationStatus.reserved => 'Rezerve',
    VehicleReservationStatus.activeRental => 'Aktif kiralama',
    VehicleReservationStatus.returnPending => 'İade bekleniyor',
    VehicleReservationStatus.completed => 'Tamamlandı',
    VehicleReservationStatus.cancelled => 'İptal',
    VehicleReservationStatus.rejected => 'Reddedildi',
    VehicleReservationStatus.refundPending => 'İade bekleniyor',
    VehicleReservationStatus.sellerCancelled => 'Satıcı iptali',
  };

  static VehicleReservationStatus parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'pending_payment':
        return VehicleReservationStatus.pendingPayment;
      case 'pending_docs':
        return VehicleReservationStatus.pendingDocs;
      case 'pending_seller_review':
      case 'seller_review':
        return VehicleReservationStatus.pendingSellerReview;
      case 'confirmed':
        return VehicleReservationStatus.confirmed;
      case 'reserved':
        return VehicleReservationStatus.reserved;
      case 'active_rental':
        return VehicleReservationStatus.activeRental;
      case 'return_pending':
        return VehicleReservationStatus.returnPending;
      case 'completed':
        return VehicleReservationStatus.completed;
      case 'cancelled':
        return VehicleReservationStatus.cancelled;
      case 'rejected':
        return VehicleReservationStatus.rejected;
      case 'refund_pending':
        return VehicleReservationStatus.refundPending;
      case 'seller_cancelled':
        return VehicleReservationStatus.sellerCancelled;
      default:
        throw FormatException('Unknown reservation status: $raw');
    }
  }
}

extension VehicleDocumentTypeX on VehicleDocumentType {
  String get wire => switch (this) {
    VehicleDocumentType.identity => 'identity',
    VehicleDocumentType.driverLicense => 'driver_license',
    VehicleDocumentType.other => 'other',
    VehicleDocumentType.identityFront => 'identity_front',
    VehicleDocumentType.identityBack => 'identity_back',
    VehicleDocumentType.driverLicenseFront => 'driver_license_front',
    VehicleDocumentType.driverLicenseBack => 'driver_license_back',
  };

  String get labelTr => switch (this) {
    VehicleDocumentType.identity => 'Kimlik',
    VehicleDocumentType.driverLicense => 'Ehliyet',
    VehicleDocumentType.other => 'Diğer',
    VehicleDocumentType.identityFront => 'Kimlik ön yüz',
    VehicleDocumentType.identityBack => 'Kimlik arka yüz',
    VehicleDocumentType.driverLicenseFront => 'Ehliyet ön yüz',
    VehicleDocumentType.driverLicenseBack => 'Ehliyet arka yüz',
  };

  static VehicleDocumentType? tryParse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'identity':
        return VehicleDocumentType.identity;
      case 'driver_license':
        return VehicleDocumentType.driverLicense;
      case 'identity_front':
        return VehicleDocumentType.identityFront;
      case 'identity_back':
        return VehicleDocumentType.identityBack;
      case 'driver_license_front':
        return VehicleDocumentType.driverLicenseFront;
      case 'driver_license_back':
        return VehicleDocumentType.driverLicenseBack;
      case 'other':
        return VehicleDocumentType.other;
      default:
        return null;
    }
  }

  static String labelOf(String? raw) =>
      tryParse(raw)?.labelTr ?? 'Belge';
}

extension VehicleQuoteStatusX on VehicleQuoteStatus {
  String get wire {
    switch (this) {
      case VehicleQuoteStatus.pending:
        return 'pending';
      case VehicleQuoteStatus.accepted:
        return 'accepted';
      case VehicleQuoteStatus.rejected:
        return 'rejected';
      case VehicleQuoteStatus.countered:
        return 'countered';
    }
  }

  static VehicleQuoteStatus parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'pending':
        return VehicleQuoteStatus.pending;
      case 'accepted':
        return VehicleQuoteStatus.accepted;
      case 'rejected':
        return VehicleQuoteStatus.rejected;
      case 'countered':
        return VehicleQuoteStatus.countered;
      default:
        throw FormatException('Unknown quote status: $raw');
    }
  }
}

extension VehicleAppointmentStatusX on VehicleAppointmentStatus {
  String get wire {
    switch (this) {
      case VehicleAppointmentStatus.pending:
        return 'pending';
      case VehicleAppointmentStatus.confirmed:
        return 'confirmed';
      case VehicleAppointmentStatus.rejected:
        return 'rejected';
      case VehicleAppointmentStatus.completed:
        return 'completed';
      case VehicleAppointmentStatus.cancelled:
        return 'cancelled';
    }
  }

  static VehicleAppointmentStatus parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'pending':
        return VehicleAppointmentStatus.pending;
      case 'confirmed':
        return VehicleAppointmentStatus.confirmed;
      case 'rejected':
        return VehicleAppointmentStatus.rejected;
      case 'completed':
        return VehicleAppointmentStatus.completed;
      case 'cancelled':
        return VehicleAppointmentStatus.cancelled;
      default:
        throw FormatException('Unknown appointment status: $raw');
    }
  }
}

extension VehicleAppointmentKindX on VehicleAppointmentKind {
  String get wire {
    switch (this) {
      case VehicleAppointmentKind.gallery:
        return 'gallery';
      case VehicleAppointmentKind.customerLocation:
        return 'customer_location';
      case VehicleAppointmentKind.meetingPoint:
        return 'meeting_point';
    }
  }

  static VehicleAppointmentKind parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'gallery':
      case 'galeri':
        return VehicleAppointmentKind.gallery;
      case 'customer_location':
        return VehicleAppointmentKind.customerLocation;
      case 'meeting_point':
        return VehicleAppointmentKind.meetingPoint;
      default:
        throw FormatException('Unknown appointment kind: $raw');
    }
  }
}

extension VehicleDeliveryModeX on VehicleDeliveryMode {
  String get wire {
    switch (this) {
      case VehicleDeliveryMode.galleryPickup:
        return 'gallery_pickup';
      case VehicleDeliveryMode.mapPoint:
        return 'map_point';
      case VehicleDeliveryMode.homeDelivery:
        return 'home_delivery';
    }
  }

  static VehicleDeliveryMode parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'gallery_pickup':
        return VehicleDeliveryMode.galleryPickup;
      case 'map_point':
        return VehicleDeliveryMode.mapPoint;
      case 'home_delivery':
        return VehicleDeliveryMode.homeDelivery;
      default:
        throw FormatException('Unknown delivery mode: $raw');
    }
  }
}

extension VehicleMediaSlotX on VehicleMediaSlot {
  String get wire {
    switch (this) {
      case VehicleMediaSlot.front:
        return 'front';
      case VehicleMediaSlot.rear:
        return 'rear';
      case VehicleMediaSlot.right:
        return 'right';
      case VehicleMediaSlot.left:
        return 'left';
      case VehicleMediaSlot.interior:
        return 'interior';
      case VehicleMediaSlot.dashboard:
        return 'dashboard';
      case VehicleMediaSlot.engine:
        return 'engine';
      case VehicleMediaSlot.trunk:
        return 'trunk';
      case VehicleMediaSlot.tire:
        return 'tire';
      case VehicleMediaSlot.damage:
        return 'damage';
      case VehicleMediaSlot.expertise:
        return 'expertise';
      case VehicleMediaSlot.video:
        return 'video';
      case VehicleMediaSlot.spin360:
        return 'spin_360';
      case VehicleMediaSlot.other:
        return 'other';
    }
  }

  static VehicleMediaSlot parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'front':
        return VehicleMediaSlot.front;
      case 'rear':
        return VehicleMediaSlot.rear;
      case 'right':
        return VehicleMediaSlot.right;
      case 'left':
        return VehicleMediaSlot.left;
      case 'interior':
        return VehicleMediaSlot.interior;
      case 'dashboard':
        return VehicleMediaSlot.dashboard;
      case 'engine':
        return VehicleMediaSlot.engine;
      case 'trunk':
        return VehicleMediaSlot.trunk;
      case 'tire':
        return VehicleMediaSlot.tire;
      case 'damage':
        return VehicleMediaSlot.damage;
      case 'expertise':
        return VehicleMediaSlot.expertise;
      case 'video':
        return VehicleMediaSlot.video;
      case 'spin_360':
      case '360':
        return VehicleMediaSlot.spin360;
      default:
        return VehicleMediaSlot.other;
    }
  }
}
