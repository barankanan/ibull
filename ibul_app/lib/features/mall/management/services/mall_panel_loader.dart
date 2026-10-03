import 'package:flutter/foundation.dart';

import '../models/mall_floor.dart';
import '../models/mall_ops.dart';
import '../models/mall_profile.dart';
import '../models/mall_setup_summary.dart';
import '../models/mall_store_link.dart';
import '../models/mall_unit.dart';
import 'mall_management_repository.dart';
import 'mall_operations_repository.dart';

/// Panel features loaded independently of the core `malls` + `mall_members`
/// rows. A failing feature query only blanks the sections that need it.
enum MallPanelFeature { floors, units, links, campaigns, summary }

/// Panel data from one load. Every section and the header read this object;
/// every mutation reloads it, so no section can show an older copy.
class MallPanelData {
  const MallPanelData({
    required this.mall,
    required this.access,
    required this.floors,
    required this.units,
    required this.links,
    required this.campaigns,
    required this.summary,
    this.errors = const {},
  });

  final MallProfile mall;
  final MallManagementAccess access;
  final List<MallFloor> floors;
  final List<MallUnit> units;
  final List<MallStoreLink> links;
  final List<MallCampaign> campaigns;
  final MallSetupSummary summary;
  final Map<MallPanelFeature, String> errors;

  int get activeCampaignCount =>
      campaigns.where((campaign) => campaign.displayStatus() == 'active').length;

  String? errorFor(Iterable<MallPanelFeature> features) {
    for (final feature in features) {
      final message = errors[feature];
      if (message != null) return message;
    }
    return null;
  }
}

sealed class MallPanelLoad {
  const MallPanelLoad();
}

class MallPanelLoaded extends MallPanelLoad {
  const MallPanelLoaded(this.data);
  final MallPanelData data;
}

class MallPanelDenied extends MallPanelLoad {
  const MallPanelDenied();
}

class MallPanelCoreFailed extends MallPanelLoad {
  const MallPanelCoreFailed();
}

Future<MallPanelLoad> loadMallPanel({
  required String mallId,
  required MallManagementRepository repository,
  required MallOperationsRepository operations,
}) async {
  final MallManagementAccess access;
  final MallProfile? mall;
  try {
    access = await repository.accessFor(mallId);
    mall = await repository.mall(mallId);
  } catch (error) {
    debugPrint('[MALL][LOAD_ERROR] feature=core mall=$mallId error=$error');
    return const MallPanelCoreFailed();
  }
  if (mall == null || !access.canEnter) return const MallPanelDenied();

  final errors = <MallPanelFeature, String>{};
  Future<T> part<T>(MallPanelFeature feature, Future<T> Function() load, T fallback) async {
    try {
      return await load();
    } catch (error) {
      debugPrint('[MALL][LOAD_ERROR] feature=${feature.name} mall=$mallId error=$error');
      errors[feature] = error is MallManagementException ? error.message : friendlyMallError(error);
      return fallback;
    }
  }

  final results = await Future.wait<Object?>([
    part(MallPanelFeature.floors, () => repository.floors(mallId), const <MallFloor>[]),
    part(MallPanelFeature.units, () => repository.units(mallId), const <MallUnit>[]),
    part(MallPanelFeature.links, () => operations.storeLinks(mallId), const <MallStoreLink>[]),
    part(MallPanelFeature.campaigns, () => operations.campaigns(mallId), const <MallCampaign>[]),
    part<MallSetupSummary?>(MallPanelFeature.summary, () => repository.setupSummary(mallId), null),
  ]);
  final floors = results[0]! as List<MallFloor>;
  final units = results[1]! as List<MallUnit>;
  final links = results[2]! as List<MallStoreLink>;
  final counts = <String, int>{};
  for (final unit in units) {
    counts[unit.floorId] = (counts[unit.floorId] ?? 0) + 1;
  }
  final summary = results[4] as MallSetupSummary? ??
      MallSetupSummary.fromRows(
        status: mall.status,
        isVerified: mall.isVerified,
        profileReady: mall.name.trim().isNotEmpty &&
            mall.city.trim().isNotEmpty &&
            mall.addressText.trim().isNotEmpty,
        mediaReady: mall.hasLogoAndCover,
        hoursReady: mall.hasOpeningHours,
        locationReady: mall.hasLocation,
        floorCount: floors.length,
        floorPlanCount: floors.where((floor) => floor.hasPlan).length,
        unitCount: units.length,
        vacantUnitCount: units.where((unit) => unit.isVacant).length,
        activeStoreCount: links.where((link) => link.isApproved).length,
        pendingRequestCount: links.where((link) => link.isPending).length,
      );
  return MallPanelLoaded(MallPanelData(
    mall: mall,
    access: access,
    floors: [for (final floor in sortMallFloors(floors)) floor.copyWith(unitCount: counts[floor.id] ?? 0)],
    units: units,
    links: links,
    campaigns: results[3]! as List<MallCampaign>,
    summary: summary,
    errors: errors,
  ));
}
