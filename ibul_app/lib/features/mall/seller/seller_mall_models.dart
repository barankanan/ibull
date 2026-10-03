import 'dart:math';

import '../management/models/mall_store_link.dart';
import '../management/models/mall_unit.dart';
import 'seller_mall_link_repository.dart';

/// Location type chosen while opening a store. `mall` does not publish a pin.
enum SellerOnboardingLocationKind { standalone, mall }

/// A physical branch of the signed-in seller (`store_branches`).
class SellerBranchOption {
  const SellerBranchOption({required this.id, required this.name, required this.code, this.city, this.district});

  final String id;
  final String name;
  final String code;
  final String? city;
  final String? district;

  String get label => [name, ?district].join(' • ');

  factory SellerBranchOption.fromMap(Map<String, dynamic> map) => SellerBranchOption(
        id: map['id'].toString(),
        name: map['name']?.toString() ?? '',
        code: map['branch_code']?.toString() ?? '',
        city: map['city']?.toString(),
        district: map['district']?.toString(),
      );
}

class SellerMallFloorOption {
  const SellerMallFloorOption({required this.id, required this.name, this.levelNumber, this.sortOrder});

  final String id;
  final String name;
  final int? levelNumber;
  final int? sortOrder;

  static int compare(SellerMallFloorOption a, SellerMallFloorOption b) {
    final left = a.levelNumber ?? a.sortOrder ?? 1 << 20;
    final right = b.levelNumber ?? b.sortOrder ?? 1 << 20;
    if (left != right) return left.compareTo(right);
    return a.name.compareTo(b.name);
  }
}

/// AVM search result for a store application. The id stays internal.
class SellerMallOption {
  const SellerMallOption({
    required this.id,
    required this.name,
    required this.isVerified,
    required this.status,
    required this.floors,
    this.city,
    this.district,
    this.logoUrl,
  });

  final String id;
  final String name;
  final bool isVerified;
  final String status;
  final List<SellerMallFloorOption> floors;
  final String? city;
  final String? district;
  final String? logoUrl;

  String get locationLabel => [?city, ?district].join(' / ');

  SellerMallOption withFloors(List<SellerMallFloorOption> floors) => SellerMallOption(
        id: id,
        name: name,
        isVerified: isVerified,
        status: status,
        floors: floors,
        city: city,
        district: district,
        logoUrl: logoUrl,
      );

  factory SellerMallOption.fromMap(Map<String, dynamic> map) {
    final floors = map['floors'] ?? map['mall_floors'];
    return SellerMallOption(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? '',
      isVerified: map['is_verified'] == true,
      status: map['status']?.toString() ?? 'draft',
      city: map['city']?.toString(),
      district: map['district']?.toString(),
      logoUrl: map['logo_url']?.toString(),
      floors: [
        if (floors is List)
          for (final floor in floors)
            if (floor is Map)
              SellerMallFloorOption(
                id: floor['id'].toString(),
                name: floor['name']?.toString() ?? '',
                levelNumber: floor['level_number'] is num ? (floor['level_number'] as num).toInt() : null,
                sortOrder: floor['sort_order'] is num ? (floor['sort_order'] as num).toInt() : null,
              ),
      ],
    );
  }
}

class SellerMallApplicationDraft {
  SellerMallApplicationDraft({
    required this.mallId,
    required this.branchId,
    required this.floorId,
    required this.unitCode,
    required this.files,
    this.areaM2,
    this.note,
    String? requestId,
  }) : requestId = requestId ?? newRequestId();

  final String requestId;
  final String mallId;
  final String branchId;
  final String floorId;
  final String unitCode;
  final double? areaM2;
  final String? note;
  final List<SellerMallFile> files;

  bool get hasRequiredDocument => files.any((file) => const ['lease_contract', 'allocation_letter'].contains(file.type));

  /// Random v4 UUID; also the storage folder of the application files.
  static String newRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class SellerOnboardingMallDraft {
  const SellerOnboardingMallDraft({
    required this.requestId,
    required this.mall,
    required this.unitCode,
    required this.files,
    this.floorId,
    this.areaM2,
    this.note,
  });

  final String requestId;
  final SellerMallOption mall;
  final String? floorId;
  final String unitCode;
  final double? areaM2;
  final String? note;
  final List<SellerMallFile> files;

  String get selectedMallId => mall.id;
  String get selectedMallName => mall.name;

  bool get isReadyToSubmit =>
      floorId != null &&
      MallUnitValidation.codeError(unitCode) == null &&
      files.any((file) => MallLinkDocument.required.contains(file.type));

  String get floorName =>
      mall.floors.where((floor) => floor.id == floorId).firstOrNull?.name ?? '';

  Map<String, Object?> toPlacementJson(List<Map<String, Object?>> documents) => {
        'request_id': requestId,
        'mall_id': mall.id,
        'mall_name': mall.name,
        'floor_id': ?floorId,
        'unit_code': unitCode,
        if (areaM2 != null) 'area_m2': areaM2,
        if (note != null) 'note': note,
        'documents': documents,
      };
}
