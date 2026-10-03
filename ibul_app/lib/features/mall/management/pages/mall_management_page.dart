import 'package:flutter/material.dart';

import '../../../../app/ibul_router.dart';
import '../../../../app/marketplace_paths.dart';
import '../../auth/mall_auth_gate.dart';
import '../mall_management_location.dart';
import '../models/mall_floor.dart';
import '../models/mall_profile.dart';
import '../models/mall_store_link.dart';
import '../models/mall_unit.dart';
import '../services/mall_management_repository.dart';
import '../services/mall_operations_repository.dart';
import '../services/mall_panel_loader.dart';
import '../widgets/mall_ads_view.dart';
import '../widgets/mall_campaigns_view.dart';
import '../widgets/mall_dashboard_view.dart';
import '../widgets/mall_indoor_map_view.dart';
import '../widgets/mall_panel_chrome.dart';
import '../widgets/mall_panel_kit.dart';
import '../widgets/mall_preview_dialog.dart';
import '../widgets/mall_profile_view.dart';
import '../widgets/mall_stats_view.dart';
import '../widgets/mall_store_application_dialog.dart';
import '../widgets/mall_store_link_dialog.dart';
import '../widgets/mall_stores_view.dart';
import '../widgets/mall_structure_views.dart';
import '../widgets/mall_team_view.dart';
import 'mall_selector_page.dart';

export '../services/mall_panel_loader.dart' show MallPanelData, MallPanelFeature;
export 'mall_selector_page.dart';

class MallManagementPage extends StatelessWidget {
  const MallManagementPage({super.key, required this.location, this.chooseMall = false});

  final MallManagementLocation location;

  /// `?sec=1`: show the list even when the user manages a single mall.
  final bool chooseMall;

  @override
  Widget build(BuildContext context) {
    return MallAuthGate(
      child: location.isSelector
          ? MallSelectorPage(autoOpenSingle: !chooseMall)
          : MallManagementShell(key: ValueKey(location.mallId), location: location),
    );
  }
}

class MallManagementShell extends StatefulWidget {
  const MallManagementShell({
    super.key,
    required this.location,
    this.repository,
    this.operations,
  });

  final MallManagementLocation location;
  final MallManagementRepository? repository;
  final MallOperationsRepository? operations;

  @override
  State<MallManagementShell> createState() => _MallManagementShellState();
}

class _MallManagementShellState extends State<MallManagementShell> {
  late final MallManagementRepository _repository = widget.repository ?? MallManagementRepository();
  late final MallOperationsRepository _operations = widget.operations ?? MallOperationsRepository();
  final _scaffold = GlobalKey<ScaffoldState>();
  var _loading = true;
  var _denied = false;
  var _revision = 0;
  String? _error;
  MallPanelData? _data;
  MallAccount? _account;
  List<MallMembership> _memberships = const [];

  String get _mallId => widget.location.mallId!;

  @override
  void initState() {
    super.initState();
    _load();
    _repository.currentAccount().then((account) {
      if (mounted) setState(() => _account = account);
    }).catchError((Object _) {});
    _repository.myMemberships().then((items) {
      if (mounted) setState(() => _memberships = items);
    }).catchError((Object _) {});
  }

  @override
  void didUpdateWidget(MallManagementShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final section = widget.location.section;
    if (section != oldWidget.location.section && section == 'ozet') _load();
  }

  /// Single refresh path: core rows plus every feature are reloaded together,
  /// but a failing feature only marks its own sections (see [MallPanelFeature]).
  Future<void> _load() async {
    final result = await loadMallPanel(mallId: _mallId, repository: _repository, operations: _operations);
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case MallPanelLoaded(:final data):
          _data = data;
          _denied = false;
          _error = null;
          _revision++;
        case MallPanelDenied():
          _denied = true;
        case MallPanelCoreFailed():
          _data = null;
      }
    });
  }

  void _open(String section) {
    _scaffold.currentState?.closeDrawer();
    final root = MarketplacePaths.mallManagementMall(_mallId);
    IbulRouter.go(context, section == 'ozet' ? root : '$root/$section');
  }

  Future<void> _act(Future<void> Function() action, {String? success}) async {
    try {
      await action();
      await _load();
      if (mounted && success != null) showMallSnack(context, success);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyMallError(error));
    }
  }

  late final _accountActions = MallAccountActions(onSignOut: _signOut);

  Future<void> _signOut() async {
    _scaffold.currentState?.closeDrawer();
    try {
      await _repository.signOut();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
      return;
    }
    if (mounted) IbulRouter.go(context, MarketplacePaths.mallHub);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final data = _data;
    final roleLabel = data?.access.role == null ? null : mallRoleLabel(data!.access.role!);
    final sidebar = MallSidebar(
      mall: data?.mall,
      section: widget.location.section,
      roleLabel: roleLabel,
      account: _account,
      actions: _accountActions,
      onSelect: _open,
    );
    final Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_denied) {
      body = const MallPage(children: [
        MallEmptyState(
          icon: Icons.lock_outline,
          title: 'Bu AVM için yönetim yetkiniz bulunmuyor.',
          message: 'Yetkiniz olduğunu düşünüyorsanız AVM yöneticinizden davet isteyin.',
        ),
      ]);
    } else if (data == null) {
      body = MallPage(children: [
        const MallInlineError('AVM bilgileri yüklenemedi.'),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            key: const ValueKey('mall-core-retry'),
            onPressed: _retry,
            child: const Text('Tekrar Dene'),
          ),
        ),
      ]);
    } else {
      final summary = data.summary;
      body = Column(
        children: [
          MallPanelHeader(
            mall: data.mall,
            statusLabel: summary.statusLabel,
            statusTone: summary.isActive
                ? MallTone.success
                : summary.isPendingReview
                    ? MallTone.primary
                    : MallTone.warning,
            account: _account,
            roleLabel: roleLabel,
            actions: _accountActions,
            memberships: _memberships,
            onSwitchMall: (mallId) => IbulRouter.go(context, MarketplacePaths.mallManagementMall(mallId)),
            onMenu: wide ? null : () => _scaffold.currentState?.openDrawer(),
            onPreview: () => showMallPreviewDialog(context, data: data.mall, floors: data.floors, links: data.links),
            onSettings: () => _open('bilgiler'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: MallInlineError(_error!, onClose: () => setState(() => _error = null)),
            ),
          Expanded(child: _section(data)),
        ],
      );
    }
    return Scaffold(
      key: _scaffold,
      backgroundColor: MallTokens.pageBackground,
      drawer: wide ? null : Drawer(width: 280, child: sidebar),
      body: wide ? Row(children: [sidebar, Expanded(child: body)]) : SafeArea(child: body),
    );
  }

  Future<void> _retry() async {
    setState(() => _loading = true);
    await _load();
  }

  static const _sectionFeatures = <String, (String, List<MallPanelFeature>)>{
    'katlar': ('Katlar yüklenemedi.', [MallPanelFeature.floors, MallPanelFeature.units]),
    'magazalar': ('Mağazalar yüklenemedi.', [MallPanelFeature.links, MallPanelFeature.floors, MallPanelFeature.units]),
    'harita': ('İç mekan haritası yüklenemedi.', [MallPanelFeature.floors, MallPanelFeature.units]),
    'kampanyalar': ('Kampanyalar yüklenemedi.', [MallPanelFeature.campaigns]),
  };

  Widget _section(MallPanelData data) {
    final needs = _sectionFeatures[widget.location.section];
    if (needs != null && data.errorFor(needs.$2) != null) {
      return MallPage(children: [
        MallInlineError(needs.$1, key: ValueKey('mall-section-error-${widget.location.section}')),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: _retry, child: const Text('Tekrar Dene')),
        ),
      ]);
    }
    return _sectionBody(data);
  }

  Widget _sectionBody(MallPanelData data) {
    final mall = data.mall;
    final access = data.access;
    switch (widget.location.section) {
      case 'bilgiler':
        return MallProfileView(mall: mall, canEdit: access.canEditProfile, repository: _repository, onSaved: _load);
      case 'katlar':
        final floorId = widget.location.floorId;
        if (floorId == null) {
          return MallFloorsView(
            floors: data.floors,
            units: data.units,
            links: data.links,
            canManage: access.canManageFloors,
            onAdd: () => _editFloor(),
            onOpen: (floor) => IbulRouter.go(context, MarketplacePaths.mallFloor(mall.id, floor.id)),
            onEdit: _editFloor,
            onDelete: (floor) => _act(
              () => _repository.deleteFloor(mallId: mall.id, floorId: floor.id),
              success: 'Kat silindi.',
            ),
          );
        }
        final floor = data.floors.where((item) => item.id == floorId).firstOrNull;
        if (floor == null) {
          return const MallPage(children: [
            MallEmptyState(icon: Icons.layers_outlined, title: 'Kat bulunamadı', message: 'Kat silinmiş olabilir.'),
          ]);
        }
        return MallFloorDetailView(
          floor: floor,
          units: data.units.where((unit) => unit.floorId == floorId).toList(),
          links: data.links,
          canManage: access.canManageUnits,
          onBack: () => _open('katlar'),
          onAddStore: (unitCode) => _addStore(floorId: floorId, unitCode: unitCode),
          onAdd: () => _editUnit(floorId: floorId, floors: data.floors),
          onEdit: (unit) => _editUnit(existing: unit, floors: data.floors),
          onDelete: (unit) => _act(
            () => _repository.deleteUnit(mallId: mall.id, unitId: unit.id),
            success: 'Mağaza alanı silindi.',
          ),
        );
      case 'magazalar':
        return MallStoresView(
          floors: data.floors,
          units: data.units,
          links: data.links,
          canManage: access.canManageStores,
          onAddStore: _addStore,
          onCancel: (link) => _act(
            () => _operations.cancelLink(link.id),
            success: link.isPending ? 'Talep geri çekildi.' : 'Bağlantı kaldırıldı.',
          ),
          onOpenFloors: () => _open('katlar'),
          onReview: _reviewApplication,
        );
      case 'harita':
        return MallIndoorMapView(
          mallId: mall.id,
          floors: data.floors,
          units: data.units,
          links: data.links,
          canManage: access.canManageFloors,
          repository: _repository,
          onChanged: _load,
        );
      case 'kampanyalar':
        return MallCampaignsView(
          mallId: mall.id,
          campaigns: data.campaigns,
          links: data.links,
          canManage: access.canManageCampaigns,
          operations: _operations,
          repository: _repository,
          onChanged: _load,
        );
      case 'reklam':
        return MallAdsView(mallId: mall.id, canManage: access.canManageAds, operations: _operations);
      case 'istatistikler':
        return MallStatsView(mallId: mall.id, operations: _operations);
      case 'yetkililer':
        return MallTeamView(mallId: mall.id, canManage: access.canManageTeam, operations: _operations);
      default:
        return MallDashboardView(
          mall: mall,
          summary: data.summary,
          activeCampaigns: data.activeCampaignCount,
          revision: _revision,
          canPublish: access.canPublish,
          loadActivity: () => _operations.activity(mall.id),
          onPublish: () => _act(() => _repository.requestPublication(mall.id),
              success: 'Yayın talebi gönderildi. İBUL ekibi onaylayınca AVM haritada görünür.'),
          onCancelPublish: () => _act(() => _repository.cancelPublication(mall.id), success: 'Yayın talebi geri çekildi.'),
          onOpen: _open,
        );
    }
  }

  Future<void> _addStore({String? floorId, String? unitCode}) async {
    final data = _data;
    if (data == null) return;
    final sent = await showMallStoreLinkDialog(
      context,
      mallId: _mallId,
      floors: data.floors,
      units: data.units,
      links: data.links,
      operations: _operations,
      floorId: floorId,
      unitCode: unitCode,
    );
    if (!sent) return;
    await _act(() async {}, success: 'Bağlantı talebi gönderildi. Mağaza onayı bekleniyor.');
  }

  Future<void> _reviewApplication(MallStoreLink link) async {
    final result = await showMallStoreApplicationDialog(context, link: link, operations: _operations);
    if (result != null) await _act(() async {}, success: result);
  }

  Future<void> _editFloor([MallFloor? floor]) async {
    final draft = await showMallFloorDialog(context, existing: floor);
    if (draft == null) return;
    await _act(
      () => _repository.saveFloor(mallId: _mallId, floorId: floor?.id, draft: draft),
      success: floor == null ? 'Kat eklendi.' : 'Kat güncellendi.',
    );
  }

  Future<void> _editUnit({String? floorId, MallUnit? existing, required List<MallFloor> floors}) async {
    final draft = await showMallUnitDialog(context, floors: floors, floorId: floorId, existing: existing);
    if (draft == null) return;
    await _act(
      () => _repository.saveUnit(mallId: _mallId, unitId: existing?.id, draft: draft),
      success: existing == null ? 'Mağaza alanı eklendi.' : 'Mağaza alanı güncellendi.',
    );
  }
}
