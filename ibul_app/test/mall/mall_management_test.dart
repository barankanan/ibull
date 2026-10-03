import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/mall/management/mall_management_location.dart';
import 'package:ibul_app/features/mall/management/models/mall_floor.dart';
import 'package:ibul_app/features/mall/management/models/mall_ops.dart';
import 'package:ibul_app/features/mall/management/models/mall_profile.dart';
import 'package:ibul_app/features/mall/management/models/mall_setup_summary.dart';
import 'package:ibul_app/features/mall/management/models/mall_store_link.dart';
import 'package:ibul_app/features/mall/management/models/mall_unit.dart';
import 'package:ibul_app/features/mall/management/services/mall_management_repository.dart';
import 'package:ibul_app/features/mall/management/services/mall_operations_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

void main() {
  test('floor and unit maps read plan and normalized map position', () {
    final floor = MallFloor.fromMap({
      'id': 'f1',
      'mall_id': 'm1',
      'name': 'Zemin Kat',
      'level_number': -1,
      'sort_order': 1,
      'plan_url': 'https://x/mall-media/malls/m1/floor-plans/p.png',
    });
    final unit = MallUnit.fromMap({
      'id': 'u1',
      'mall_id': 'm1',
      'floor_id': 'f1',
      'unit_code': '102',
      'unit_type': 'store',
      'occupancy': 'reserved',
      'sort_order': 2,
      'map_x': '0.25',
      'map_y': 0.5,
    });
    expect(floor.shortLabel, 'B1');
    expect(floor.hasPlan, isTrue);
    expect(unit.isPlaced, isTrue);
    expect(unit.mapX, 0.25);
    expect(MallUnitOccupancy.label(unit.occupancy), 'Rezerve');
  });

  test('profile update payload cannot write status or verification', () {
    final payload = MallManagementCommands.updateProfile(
      mallId: 'm1',
      draft: const MallProfile(
        id: 'm1',
        name: 'Prime',
        city: 'Hatay',
        district: 'İskenderun',
        addressText: 'Sahil',
        status: 'active',
        isVerified: false,
        openingHours: '10:00-22:00',
      ),
    );
    expect(payload.keys, isNot(contains('p_status')));
    expect(payload.keys, isNot(contains('p_is_verified')));
    expect(payload['p_opening_hours'], '10:00-22:00');
  });

  test('unit drafts cannot claim occupied', () {
    final payload = MallManagementCommands.upsertUnit(
      mallId: 'm1',
      draft: const MallUnitDraft(floorId: 'f1', unitCode: '101', unitType: 'restaurant'),
    );
    expect(payload['p_occupancy'], 'vacant');
    expect(MallUnitValidation.occupancyError('occupied'), isNotNull);
    expect(MallUnitOccupancy.editable, ['vacant', 'reserved', 'temporarily_closed']);
    expect(MallUnitType.values, ['store', 'restaurant', 'cafe', 'kiosk', 'cinema', 'service', 'other']);
  });

  test('role capabilities mirror server role lists', () {
    const manager = MallManagementAccess(role: 'mall_manager');
    const stores = MallManagementAccess(role: 'mall_store_manager');
    const content = MallManagementAccess(role: 'mall_content_editor');
    const ads = MallManagementAccess(role: 'mall_ad_manager');
    expect([manager.canManageFloors, manager.canManageAds, manager.canManageTeam], [true, true, true]);
    expect([stores.canManageFloors, stores.canManageStores, stores.canManageCampaigns], [true, true, false]);
    expect([content.canEditProfile, content.canManageCampaigns, content.canManageUnits], [true, true, false]);
    expect([ads.canManageAds, ads.canEditProfile, ads.canManageTeam], [true, false, false]);
    expect(const MallManagementAccess(adminViewer: true).canManageUnits, isFalse);
    expect(mallRoleLabel('mall_store_manager'), 'Mağaza Operasyonları');
    expect(mallRoleLabel('mall_ad_manager'), 'Reklam Yöneticisi');
  });

  test('setup summary maps the server row and gates publishing', () {
    final draft = MallSetupSummary.fromMap({
      'status': 'draft',
      'is_verified': true,
      'floor_count': 3,
      'unit_count': '2',
      'hours_ready': true,
      'missing': ['store'],
      'publication': {'status': 'rejected', 'admin_note': 'Kapak eksik'},
    });
    expect([draft.floorCount, draft.unitCount, draft.hoursReady], [3, 2, true]);
    expect(draft.canRequestPublish, isFalse);
    expect(draft.publication!.isRejected, isTrue);
    expect(draft.mapVisibilityText('Primall new'), contains('"Kurulumda"'));
    expect(MallSetupSummary.missingLabel('store'), 'En az 1 onaylı mağaza');
    final ready = MallSetupSummary.fromMap({'status': 'draft', 'is_verified': true, 'missing': <String>[]});
    expect(ready.canRequestPublish, isTrue);
    final active = MallSetupSummary.fromMap({'status': 'active'});
    expect([active.statusLabel, active.canRequestPublish], ['Yayında', false]);
    expect(active.mapVisibilityText('Primall new'), contains('AVM pini olarak görünüyor'));
  });

  test('floors sort bottom to top and levels get standard names', () {
    MallFloor floor(String id, int? level, [int sort = 0]) =>
        MallFloor(id: id, mallId: 'm1', name: id, sortOrder: sort, levelNumber: level);
    final sorted = sortMallFloors([floor('1', 1), floor('none', null), floor('B2', -2), floor('Z', 0), floor('B1', -1)]);
    expect(sorted.map((f) => f.id), ['B2', 'B1', 'Z', '1', 'none']);
    expect([for (final l in [-2, -1, 0, 1, 2]) MallFloorLevels.defaultName(l)], ['B2', 'B1', 'Zemin Kat', '1. Kat', '2. Kat']);
    expect(floor('z', 0).shortLabel, 'Z');
    final codes = ['105A', '12', '102', 'Z-1', '9']..sort(compareMallUnitCodes);
    expect(codes, ['9', '12', '102', '105A', 'Z-1']);
  });

  test('store code normalization and format', () {
    expect(MallOperationsRepository.normalizeCode(' ibl 7k4p9x '), 'IBL-7K4P9X');
    expect(MallOperationsRepository.normalizeCode('ibl-7k4p9x'), 'IBL-7K4P9X');
    expect(MallOperationsRepository.normalizeCode('IBL7LXD6N'), 'IBL-7LXD6N');
    expect(MallOperationsRepository.normalizeCode(' ibl-7lxd6n'), 'IBL-7LXD6N');
    expect(MallOperationsRepository.codePattern.hasMatch('IBL-7K4P9X'), isTrue);
    expect(MallOperationsRepository.codePattern.hasMatch('7264153b-f493-4508'), isFalse);
  });

  test('campaign display status follows dates', () {
    final campaign = MallCampaign.fromMap({
      'id': 'c1',
      'title': 'Hafta sonu',
      'starts_at': '2026-10-01T00:00:00Z',
      'ends_at': '2026-10-10T00:00:00Z',
      'status': 'published',
      'target_type': 'stores',
      'target_branch_ids': ['b1', 'b2'],
    });
    expect(campaign.displayStatus(DateTime.utc(2026, 9, 1)), 'scheduled');
    expect(campaign.displayStatus(DateTime.utc(2026, 10, 5)), 'active');
    expect(campaign.displayStatus(DateTime.utc(2026, 11, 1)), 'ended');
    expect(campaign.targetLabel, 'Seçili mağazalar (2)');
    expect(MallCampaign.fromMap({...{'id': 'c2', 'title': 't'}, 'status': 'draft'}).displayStatus(), 'draft');
  });

  test('ad groups and link/request maps', () {
    expect(MallAd.fromMap({'id': 'a', 'status': 'pending_review'}).group, 'review');
    expect(MallAd.fromMap({'id': 'a', 'status': 'active'}).group, 'active');
    expect(MallAd.fromMap({'id': 'a', 'status': 'completed'}).group, 'done');
    final link = MallStoreLink.fromMap({
      'id': 'l1',
      'status': 'approved',
      'mall_unit_id': 'u1',
      'unit_code': '102',
      'floor_id': 'f1',
      'floor_name': '1. Kat',
      'store_name': 'destina',
      'branch_code': 'IBL-ABCDEF',
      'branch_id': 'b1',
    });
    expect(link.placeLabel, '1. Kat • 102');
    expect(link.branchId, 'b1');
    final request = SellerMallRequest.fromMap({'id': 'l1', 'status': 'pending', 'mall_name': 'Primall new'});
    expect(request.statusLabel, 'Yanıtınız bekleniyor');
  });

  test('management routes cover every section', () {
    for (final section in MallManagementLocation.sections.where((s) => s != 'ozet')) {
      final location = MallManagementLocation.parse('/avm/yonetim/mall-1/$section');
      expect(location?.section, section, reason: section);
      expect(location?.path, '/avm/yonetim/mall-1/$section');
    }
    final floor = MallManagementLocation.parse('/avm/yonetim/mall-1/katlar/floor-9');
    expect(floor?.floorId, 'floor-9');
    expect(floor?.path, '/avm/yonetim/mall-1/katlar/floor-9');
    expect(MallManagementLocation.parse('/avm/yonetim/mall-1/yoneticiler')?.section, 'yetkililer');
    expect(MallManagementLocation.parse('/avm/yonetim/mall-1')?.section, 'ozet');
    expect(MallManagementLocation.parse('/avm/yonetim')?.isSelector, isTrue);
    expect(MallManagementLocation.parse('/avm/yonetim/mall-1/bilinmeyen'), isNull);
  });

  test('backend errors map to specific messages', () {
    expect(friendlyMallError(Exception('PostgrestException 42501')), 'Bu AVM için yönetim yetkiniz bulunmuyor.');
    expect(
      friendlyMallError(Exception('Bu katta 12 mağaza birimi bulunuyor. Önce birimleri kaldırın veya başka kata taşıyın.')),
      contains('12 mağaza birimi'),
    );
    for (final code in ['PGRST202', '42703', '42883', 'XX000']) {
      final message = friendlyMallError(PostgrestException(message: 'column l.note does not exist', code: code));
      expect(message, isNot(contains(code)), reason: code);
      expect(message, isNot(contains('kod:')), reason: code);
    }
    expect(
      friendlyMallError(const PostgrestException(message: 'Kendi rolünüzü veya durumunuzu değiştiremezsiniz.', code: '42501')),
      'Kendi rolünüzü veya durumunuzu değiştiremezsiniz.',
    );
    expect(
      friendlyMallError(const PostgrestException(message: 'permission denied for table malls', code: '42501')),
      'Bu AVM için yönetim yetkiniz bulunmuyor.',
    );
    expect(friendlyMallError(const PostgrestException(message: 'x', code: '23505')), contains('zaten var'));
    expect(friendlyMallError(Exception('random')), isNot(contains('AVM listeniz')));
  });
}
