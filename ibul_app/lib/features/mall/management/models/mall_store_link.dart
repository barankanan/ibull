/// A store branch an AVM can request to link. `branchCode` is public, not a secret.
class MallBranchCandidate {
  const MallBranchCandidate({
    required this.branchId,
    required this.branchCode,
    required this.branchName,
    required this.storeName,
    required this.isVerified,
    this.category,
    this.logoUrl,
    this.city,
    this.district,
    this.linkStatus,
  });

  final String branchId;
  final String branchCode;
  final String branchName;
  final String storeName;
  final String? category;
  final String? logoUrl;
  final String? city;
  final String? district;
  final bool isVerified;
  final String? linkStatus;

  bool get alreadyLinked => linkStatus == 'pending' || linkStatus == 'approved';

  String get locationLabel => [district, city]
      .whereType<String>()
      .where((part) => part.trim().isNotEmpty)
      .join(', ');

  factory MallBranchCandidate.fromMap(Map<String, dynamic> map) {
    return MallBranchCandidate(
      branchId: map['branch_id'].toString(),
      branchCode: map['branch_code']?.toString() ?? '',
      branchName: map['branch_name']?.toString() ?? '',
      storeName: map['store_name']?.toString() ?? '',
      category: _text(map['category']),
      logoUrl: _text(map['logo_url']),
      city: _text(map['city']),
      district: _text(map['district']),
      isVerified: map['is_verified'] == true,
      linkStatus: _text(map['link_status']),
    );
  }
}

/// A file attached to a store → AVM application. Lives in the private
/// `seller-documents` bucket; opened only through a short-lived signed URL.
class MallLinkDocument {
  const MallLinkDocument({required this.type, required this.path, required this.name, this.mime, this.size});

  static const required = ['lease_contract', 'allocation_letter'];
  static const types = ['lease_contract', 'allocation_letter', 'mall_approval', 'storefront_photo', 'other'];

  final String type;
  final String path;
  final String name;
  final String? mime;
  final int? size;

  static String labelFor(String type) => switch (type) {
        'lease_contract' => 'AVM kira sözleşmesi',
        'allocation_letter' => 'Yer tahsis / kullanım hakkı belgesi',
        'mall_approval' => 'AVM yerleşim / onay belgesi',
        'storefront_photo' => 'Mağaza cephe fotoğrafı',
        _ => 'Ek belge',
      };

  String get label => labelFor(type);

  static List<MallLinkDocument> listFrom(Object? raw) => [
        if (raw is List)
          for (final item in raw)
            if (item is Map)
              MallLinkDocument(
                type: item['type']?.toString() ?? 'other',
                path: item['path']?.toString() ?? '',
                name: item['name']?.toString() ?? 'belge',
                mime: _text(item['mime']),
                size: _intOrNull(item['size']),
              ),
      ];
}

class MallStoreLink {
  const MallStoreLink({
    required this.id,
    required this.status,
    required this.unitId,
    required this.unitCode,
    required this.floorName,
    required this.storeName,
    required this.branchCode,
    this.requestSource = 'mall',
    this.floorId,
    this.category,
    this.logoUrl,
    this.storeId,
    this.branchId,
    this.branchName,
    this.requestedAt,
    this.levelNumber,
    this.areaM2,
    this.note,
    this.reviewNote,
    this.city,
    this.district,
    this.documents = const [],
  });

  final String id;
  final String status;

  /// `mall`: AVM invited, the store approves. `store`: the store applied, the AVM approves.
  final String requestSource;
  final String? branchId;
  final String? branchName;
  final String? reviewNote;
  final List<MallLinkDocument> documents;
  final int? levelNumber;
  final double? areaM2;
  final String? note;
  final String? city;
  final String? district;
  final String unitId;
  final String unitCode;
  final String? floorId;
  final String floorName;
  final String storeName;
  final String branchCode;
  final String? category;
  final String? logoUrl;
  final String? storeId;
  final DateTime? requestedAt;

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get fromStore => requestSource == 'store';

  /// Incoming store application the AVM has to answer.
  bool get isIncoming => isPending && fromStore;

  /// Invitation sent by the AVM, waiting for the store.
  bool get isSentInvite => isPending && !fromStore;

  String get placeLabel => '$floorName • $unitCode';

  String get locationLabel => [district, city]
      .whereType<String>()
      .where((part) => part.trim().isNotEmpty)
      .join(', ');

  factory MallStoreLink.fromMap(Map<String, dynamic> map) {
    return MallStoreLink(
      id: map['id'].toString(),
      status: map['status']?.toString() ?? 'pending',
      requestSource: map['request_source']?.toString() ?? 'mall',
      branchName: _text(map['branch_name']),
      reviewNote: _text(map['review_note']),
      documents: MallLinkDocument.listFrom(map['documents']),
      unitId: map['mall_unit_id']?.toString() ?? '',
      unitCode: map['unit_code']?.toString() ?? '',
      floorId: _text(map['floor_id']),
      floorName: map['floor_name']?.toString() ?? '',
      storeName: map['store_name']?.toString() ?? '',
      branchCode: map['branch_code']?.toString() ?? '',
      category: _text(map['category']),
      logoUrl: _text(map['logo_url']),
      storeId: _text(map['store_id']),
      branchId: _text(map['branch_id']),
      requestedAt: DateTime.tryParse(map['requested_at']?.toString() ?? ''),
      levelNumber: _intOrNull(map['level_number']),
      areaM2: _doubleOrNull(map['area_m2']),
      note: _text(map['note']),
      city: _text(map['city']),
      district: _text(map['district']),
    );
  }
}

/// Seller side view of an AVM link: an AVM invitation or the store's own application.
class SellerMallRequest {
  const SellerMallRequest({
    required this.id,
    required this.status,
    required this.mallName,
    required this.floorName,
    required this.unitCode,
    this.mallId,
    this.requestSource = 'mall',
    this.city,
    this.district,
    this.logoUrl,
    this.requestedAt,
    this.levelNumber,
    this.areaM2,
    this.note,
    this.reviewNote,
    this.branchName,
    this.documents = const [],
  });

  final String id;
  final String status;
  final String requestSource;
  final String? reviewNote;
  final String? branchName;
  final List<MallLinkDocument> documents;
  final String? mallId;
  final String mallName;
  final int? levelNumber;
  final double? areaM2;
  final String? note;
  final String floorName;
  final String unitCode;
  final String? city;
  final String? district;
  final String? logoUrl;
  final DateTime? requestedAt;

  bool get isPending => status == 'pending';
  bool get isOwnApplication => requestSource == 'store';

  /// AVM invitation the seller has to answer.
  bool get awaitsMyAnswer => isPending && !isOwnApplication;

  String get placeLabel => '$floorName • $unitCode';

  String get locationLabel => [city, district]
      .whereType<String>()
      .where((part) => part.trim().isNotEmpty)
      .join(' / ');

  String get statusLabel => switch (status) {
        'approved' => 'Onaylandı',
        'rejected' => 'Reddedildi',
        _ => isOwnApplication ? 'Başvuru inceleniyor' : 'Yanıtınız bekleniyor',
      };

  factory SellerMallRequest.fromMap(Map<String, dynamic> map) {
    return SellerMallRequest(
      id: map['id'].toString(),
      status: map['status']?.toString() ?? 'pending',
      requestSource: map['request_source']?.toString() ?? 'mall',
      reviewNote: _text(map['review_note']),
      branchName: _text(map['branch_name']),
      documents: MallLinkDocument.listFrom(map['documents']),
      mallId: _text(map['mall_id']),
      mallName: map['mall_name']?.toString() ?? '',
      floorName: map['floor_name']?.toString() ?? '',
      unitCode: map['unit_code']?.toString() ?? '',
      city: _text(map['mall_city'] ?? map['city']),
      district: _text(map['mall_district'] ?? map['district']),
      logoUrl: _text(map['mall_logo_url'] ?? map['logo_url']),
      requestedAt: DateTime.tryParse(map['requested_at']?.toString() ?? ''),
      levelNumber: _intOrNull(map['level_number']),
      areaM2: _doubleOrNull(map['area_m2']),
      note: _text(map['note']),
    );
  }
}

int? _intOrNull(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

double? _doubleOrNull(Object? value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

String? _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
