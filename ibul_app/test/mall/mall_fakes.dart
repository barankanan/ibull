import 'package:ibul_app/features/mall/management/models/mall_floor.dart';
import 'package:ibul_app/features/mall/management/models/mall_ops.dart';
import 'package:ibul_app/features/mall/management/models/mall_profile.dart';
import 'package:ibul_app/features/mall/management/models/mall_setup_summary.dart';
import 'package:ibul_app/features/mall/management/models/mall_store_link.dart';
import 'package:ibul_app/features/mall/management/models/mall_unit.dart';
import 'package:ibul_app/features/mall/management/services/mall_management_repository.dart';
import 'package:ibul_app/features/mall/management/services/mall_operations_repository.dart';
import 'package:ibul_app/features/mall/seller/seller_mall_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const testMall = MallProfile(
  id: 'm1',
  name: 'Primall new',
  city: 'Hatay',
  district: 'İskenderun',
  addressText: 'Numune Mahallesi',
  status: 'draft',
  isVerified: true,
);

/// In-memory stand-in for the RPC layer. Mirrors server rules the UI relies
/// on: link requests become pending and reserve the unit; the setup summary is
/// computed from the same rows like `mall_setup_summary`.
class FakeMallStore {
  final floors = <MallFloor>[];
  final units = <MallUnit>[];
  final links = <MallStoreLink>[];
  final campaigns = <MallCampaign>[];
  var status = 'draft';
  var hoursReady = true;
  var summaryCalls = 0;
  var _seq = 0;

  /// Queries that fail like the real remote did: `core`, `floors`, `links`, `summary`.
  final failing = <String>{};

  void failIf(String query) {
    if (failing.contains(query)) {
      throw MallManagementException(
        friendlyMallError(const PostgrestException(message: 'column l.note does not exist', code: '42703')),
      );
    }
  }

  String nextId(String prefix) => 'new-$prefix${++_seq}';

  MallStoreLink copyLink(MallStoreLink link, {required String status, String? unitId, String? reviewNote}) => MallStoreLink(
        id: link.id,
        status: status,
        requestSource: link.requestSource,
        unitId: unitId ?? link.unitId,
        unitCode: link.unitCode,
        floorId: link.floorId,
        floorName: link.floorName,
        storeName: link.storeName,
        branchCode: link.branchCode,
        branchId: link.branchId,
        branchName: link.branchName,
        storeId: link.storeId ?? 'seller-1',
        category: link.category,
        areaM2: link.areaM2,
        note: link.note,
        reviewNote: reviewNote ?? link.reviewNote,
        documents: link.documents,
      );

  MallSetupSummary summary() {
    summaryCalls++;
    final active = links.where((link) => link.isApproved).length;
    final open = {for (final link in links) if (link.isApproved || link.isPending) link.unitId};
    return MallSetupSummary(
      status: status,
      isVerified: true,
      floorCount: floors.length,
      unitCount: units.length,
      vacantUnitCount: units.where((unit) => unit.occupancy != 'occupied' && !open.contains(unit.id)).length,
      activeStoreCount: active,
      pendingRequestCount: links.where((link) => link.isPending).length,
      floorPlanCount: floors.where((floor) => floor.hasPlan).length,
      profileReady: true,
      mediaReady: true,
      hoursReady: hoursReady,
      missing: [
        if (!hoursReady) 'hours',
        if (floors.isEmpty) 'floor',
        if (active == 0) 'store',
      ],
    );
  }
}

class FakeMallRepository extends MallManagementRepository {
  FakeMallRepository(this.store, {this.role = 'mall_manager', this.memberships = const []});

  final FakeMallStore store;
  final String role;
  final List<MallMembership> memberships;
  var signedOut = false;

  @override
  Future<List<MallMembership>> myMemberships() async => memberships;

  @override
  Future<MallSetupSummary> setupSummary(String mallId) async {
    store.failIf('summary');
    return store.summary();
  }

  @override
  Future<void> requestPublication(String mallId) async {
    if (!store.summary().canRequestPublish) throw MallManagementException('Yayın için eksikler var.');
    store.status = 'pending_review';
  }

  @override
  Future<void> cancelPublication(String mallId) async => store.status = 'draft';

  @override
  Future<MallAccount> currentAccount() async => const MallAccount(name: 'Baran Kananoğulları', email: 'baran@x.com');

  @override
  Future<void> signOut() async => signedOut = true;

  @override
  Future<MallProfile?> mall(String mallId) async {
    store.failIf('core');
    return testMall;
  }

  @override
  Future<MallManagementAccess> accessFor(String mallId) async => MallManagementAccess(role: role);

  @override
  Future<List<MallFloor>> floors(String mallId) async {
    store.failIf('floors');
    return List.of(store.floors);
  }

  @override
  Future<List<MallUnit>> units(String mallId) async => List.of(store.units);

  @override
  Future<void> saveFloor({required String mallId, String? floorId, required MallFloorDraft draft}) async {
    store.floors.add(MallFloor(
      id: floorId ?? store.nextId('f'),
      mallId: mallId,
      name: draft.name,
      levelNumber: draft.levelNumber,
      sortOrder: draft.sortOrder,
    ));
  }

  @override
  Future<void> saveUnit({required String mallId, String? unitId, required MallUnitDraft draft}) async {
    store.units.add(MallUnit(
      id: unitId ?? store.nextId('u'),
      mallId: mallId,
      floorId: draft.floorId,
      unitCode: draft.unitCode,
      unitType: draft.unitType,
      occupancy: draft.occupancy,
      sortOrder: draft.sortOrder,
    ));
  }
}

class FakeMallOperations extends MallOperationsRepository {
  FakeMallOperations(this.store, {this.candidates = const [], this.fixedStats = const MallStats(totals: {}, daily: [])});

  final FakeMallStore store;
  final List<MallBranchCandidate> candidates;
  final MallStats fixedStats;
  String? lastQuery;

  @override
  Future<List<MallBranchCandidate>> findBranches(String mallId, String query) async {
    lastQuery = query;
    final q = query.toLowerCase();
    return candidates
        .where((item) => item.branchCode == query || item.storeName.toLowerCase().contains(q))
        .toList();
  }

  /// Same rules as `request_mall_store_link`: reuse the floor's area with that
  /// number or create it, refuse a number used on another floor or a taken one.
  @override
  Future<void> requestStoreLink({
    required String mallId,
    required String branchId,
    required String floorId,
    required String unitCode,
    double? areaM2,
    String? note,
  }) async {
    final code = unitCode.trim();
    final floor = store.floors.firstWhere((item) => item.id == floorId);
    final branch = candidates.firstWhere((item) => item.branchId == branchId);
    var unit = store.units.where((item) => item.unitCode.toLowerCase() == code.toLowerCase()).firstOrNull;
    if (unit != null && unit.floorId != floorId) {
      throw MallManagementException('Mağaza $code başka bir katta kayıtlı.');
    }
    if (unit != null &&
        store.links.any((link) => link.unitId == unit!.id && (link.isPending || link.isApproved))) {
      throw MallManagementException('Mağaza $code dolu.');
    }
    final reserved = MallUnit(
      id: unit?.id ?? store.nextId('u'),
      mallId: mallId,
      floorId: floorId,
      unitCode: unit?.unitCode ?? code,
      unitType: unit?.unitType ?? 'store',
      occupancy: 'reserved',
      areaM2: areaM2 ?? unit?.areaM2,
      sortOrder: unit?.sortOrder ?? 0,
    );
    if (unit == null) {
      store.units.add(reserved);
    } else {
      store.units[store.units.indexOf(unit)] = reserved;
    }
    unit = reserved;
    store.links.add(MallStoreLink(
      id: store.nextId('l'),
      status: 'pending',
      unitId: unit.id,
      unitCode: unit.unitCode,
      floorId: floor.id,
      floorName: floor.name,
      storeName: branch.storeName,
      branchCode: branch.branchCode,
      branchId: branchId,
      areaM2: areaM2,
      note: note,
    ));
  }

  @override
  Future<void> cancelLink(String linkId) async => store.links.removeWhere((link) => link.id == linkId);

  /// What the store owner's approval does on the server.
  void approve(String linkId) {
    final index = store.links.indexWhere((link) => link.id == linkId);
    final link = store.links[index];
    store.links[index] = MallStoreLink(
      id: link.id,
      status: 'approved',
      unitId: link.unitId,
      unitCode: link.unitCode,
      floorId: link.floorId,
      floorName: link.floorName,
      storeName: link.storeName,
      branchCode: link.branchCode,
      branchId: link.branchId,
      storeId: 'seller-1',
    );
    final unit = store.units.firstWhere((item) => item.id == link.unitId);
    store.units[store.units.indexOf(unit)] = MallUnit(
      id: unit.id,
      mallId: unit.mallId,
      floorId: unit.floorId,
      unitCode: unit.unitCode,
      unitType: unit.unitType,
      occupancy: 'occupied',
      sortOrder: unit.sortOrder,
    );
  }

  /// What `respond_mall_branch_link` does for a store application: the AVM
  /// approves, the store number is created (or reused) and becomes occupied.
  @override
  Future<void> respondToApplication(String linkId, {required bool approve, String? note}) async {
    final index = store.links.indexWhere((link) => link.id == linkId);
    final link = store.links[index];
    if (!link.isIncoming) throw MallManagementException('Bu talebi yanıtlama yetkiniz yok.');
    var unitId = link.unitId;
    if (approve) {
      final existing = store.units.where((unit) => unit.unitCode == link.unitCode).firstOrNull;
      final unit = MallUnit(
        id: existing?.id ?? store.nextId('u'),
        mallId: 'm1',
        floorId: link.floorId!,
        unitCode: link.unitCode,
        unitType: 'store',
        occupancy: 'occupied',
        areaM2: existing?.areaM2 ?? link.areaM2,
        sortOrder: existing?.sortOrder ?? 0,
      );
      existing == null ? store.units.add(unit) : store.units[store.units.indexOf(existing)] = unit;
      unitId = unit.id;
    }
    store.links[index] = store.copyLink(link, status: approve ? 'approved' : 'rejected', unitId: unitId, reviewNote: note);
  }

  final infoRequests = <String, String>{};

  @override
  Future<void> requestInfo(String linkId, String message) async => infoRequests[linkId] = message;

  @override
  Future<String> documentUrl(String path) async => 'https://signed.example/$path?token=short';

  @override
  Future<List<MallStoreLink>> storeLinks(String mallId) async {
    store.failIf('links');
    return List.of(store.links);
  }

  @override
  Future<List<MallCampaign>> campaigns(String mallId) async => List.of(store.campaigns);

  @override
  Future<List<MallAd>> ads(String mallId) async => const [];

  @override
  Future<MallStats> stats(String mallId, {int days = 30}) async => fixedStats;

  @override
  Future<({List<MallMember> members, List<MallInvitation> invitations})> team(String mallId) async => (
        members: const [
          MallMember(userId: 'me', role: 'mall_manager', status: 'active', displayName: 'Baran', isSelf: true),
          MallMember(userId: 'u2', role: 'mall_ad_manager', status: 'active', displayName: 'Ece', email: 'ece@x.com'),
        ],
        invitations: const [MallInvitation(email: 'yeni@x.com', role: 'mall_content_editor')],
      );

  @override
  Future<List<MallActivity>> activity(String mallId) async => const [];
}

/// Seller panel over the same in-memory store as the AVM panel, so a test can
/// apply as Teknosa and approve as Primall new.
class FakeSellerPortal extends SellerMallLinkRepository {
  FakeSellerPortal(this.store);

  final FakeMallStore store;
  SellerMallApplicationDraft? lastDraft;

  @override
  Future<String?> myBranchCode() async => 'IBL-7LXD6N';

  @override
  Future<List<SellerBranchOption>> myBranches() async =>
      const [SellerBranchOption(id: 'b-teknosa', name: 'Teknosa', code: 'IBL-7LXD6N', district: 'İskenderun')];

  @override
  Future<List<SellerMallOption>> findMalls(String query) async => [
        if ('primall new'.contains(query.trim().toLowerCase())) _primall,
      ];

  @override
  Future<List<SellerMallOption>> listMallsInArea({
    required String city,
    required String district,
  }) async =>
      [
        if (city.toLowerCase().contains('hatay') && district.toLowerCase().contains('skenderun')) _primall,
      ];

  @override
  Future<List<SellerMallFloorOption>> listFloorsForMall({
    required String mallId,
    required String mallName,
  }) async =>
      mallId == 'm1' ? _primall.floors : const [];

  SellerMallOption get _primall => SellerMallOption(
        id: 'm1',
        name: 'Primall new',
        city: 'Hatay',
        district: 'İskenderun',
        isVerified: true,
        status: store.status,
        floors: [
          for (final floor in store.floors)
            SellerMallFloorOption(id: floor.id, name: floor.name, levelNumber: floor.levelNumber),
        ],
      );

  @override
  Future<String> apply(SellerMallApplicationDraft draft) async {
    if (!draft.hasRequiredDocument) throw MallManagementException('Kira sözleşmesi veya yer tahsis belgesi zorunlu.');
    lastDraft = draft;
    final floor = store.floors.firstWhere((item) => item.id == draft.floorId);
    final existing = store.units.where((unit) => unit.unitCode == draft.unitCode.trim()).firstOrNull;
    store.links.add(MallStoreLink(
      id: draft.requestId,
      status: 'pending',
      requestSource: 'store',
      unitId: existing?.id ?? '',
      unitCode: draft.unitCode.trim(),
      floorId: floor.id,
      floorName: floor.name,
      storeName: 'Teknosa',
      branchCode: 'IBL-7LXD6N',
      branchId: draft.branchId,
      branchName: 'Teknosa',
      category: 'Elektronik',
      storeId: 'seller-1',
      areaM2: draft.areaM2,
      note: draft.note,
      documents: [
        for (final file in draft.files)
          MallLinkDocument(type: file.type, path: 'seller-1/mall-links/${draft.requestId}/${file.name}', name: file.name, mime: file.mime),
      ],
    ));
    return 'Primall new';
  }

  @override
  Future<List<SellerMallRequest>> requests() async => [
        for (final link in store.links)
          SellerMallRequest(
            id: link.id,
            status: link.status,
            requestSource: link.requestSource,
            mallName: 'Primall new',
            city: 'Hatay',
            district: 'İskenderun',
            floorName: link.floorName,
            unitCode: link.unitCode,
            areaM2: link.areaM2,
            reviewNote: link.reviewNote,
            documents: link.documents,
          ),
      ];
}

class FakeSellerLinks extends SellerMallLinkRepository {
  FakeSellerLinks(this.items);

  List<SellerMallRequest> items;
  final responses = <String, bool>{};

  @override
  Future<String?> myBranchCode() async => 'IBL-7K4P9X';

  @override
  Future<List<SellerMallRequest>> requests() async => List.of(items);

  @override
  Future<void> respond(String linkId, {required bool approve}) async {
    responses[linkId] = approve;
    items = [
      for (final item in items)
        item.id == linkId
            ? SellerMallRequest(
                id: item.id,
                status: approve ? 'approved' : 'rejected',
                mallName: item.mallName,
                floorName: item.floorName,
                unitCode: item.unitCode,
              )
            : item,
    ];
  }
}
