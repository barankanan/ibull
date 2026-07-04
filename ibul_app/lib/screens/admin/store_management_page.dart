import 'package:flutter/material.dart';
import 'package:ibul_app/utils/order_status_constants.dart';


import '../../ads/presentation/pages/admin_ads_manager_page.dart';
import '../../features/admin/panel/helpers/admin_panel_density.dart';
import '../../services/admin_service.dart';
import 'store_application_detail_dialog.dart';

class StoreManagementPage extends StatefulWidget {
  const StoreManagementPage({super.key});

  @override
  State<StoreManagementPage> createState() => _StoreManagementPageState();
}

class _StoreManagementPageState extends State<StoreManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminService _adminService = AdminService();

  List<Map<String, dynamic>> _allStores = [];
  List<Map<String, dynamic>> _filteredStores = [];
  bool _isLoadingStores = false;
  bool _isProcessing = false;
  final TextEditingController _searchController = TextEditingController();
  DateTime? _lastStoreRefreshAt;
  List<Map<String, dynamic>> _applicationHistory = const [];
  bool _loadingApplicationHistory = false;
  String _applicationListMode = 'pending';
  String _historyActionFilter = 'all';
  String _historyDateFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchAllStores();
    _loadApplicationHistory();
  }

  Future<void> _loadApplicationHistory() async {
    setState(() => _loadingApplicationHistory = true);
    try {
      int? lastDays;
      if (_historyDateFilter == '7') lastDays = 7;
      if (_historyDateFilter == '30') lastDays = 30;
      final rows = await _adminService.fetchStoreApplicationHistory(
        actionFilter: _historyActionFilter == 'all' ? null : _historyActionFilter,
        lastDays: lastDays,
        limit: 200,
      );
      if (mounted) setState(() => _applicationHistory = rows);
    } finally {
      if (mounted) setState(() => _loadingApplicationHistory = false);
    }
  }

  List<Map<String, dynamic>> _priorHistoryForSeller(
    String sellerId,
    Map<String, dynamic> application,
  ) {
    if (sellerId.isEmpty) return const [];
    final appCreated = _readDate(application['created_at']);
    return _applicationHistory
        .where((entry) => (entry['seller_id'] ?? '').toString() == sellerId)
        .where((entry) {
          if (appCreated == null) return true;
          final actedAt = _readDate(entry['acted_at']);
          if (actedAt == null) return true;
          return actedAt.isBefore(appCreated);
        })
        .toList();
  }

  _ApplicationResubmitHints _resubmitHintsFor(
    String sellerId,
    Map<String, dynamic> application,
  ) {
    final prior = _priorHistoryForSeller(sellerId, application);
    final previouslyRejected = prior.any(
      (entry) => (entry['action'] ?? '').toString() == 'rejected',
    );
    final previouslyMissing = prior.any(
      (entry) =>
          (entry['action'] ?? '').toString() ==
          AdminService.storeHistoryChangesRequested,
    );
    return _ApplicationResubmitHints(
      previouslyRejected: previouslyRejected,
      previouslyMissingDocuments: previouslyMissing,
      isResubmission: previouslyRejected || previouslyMissing,
    );
  }

  String _historyActionLabel(String action) {
    switch (action) {
      case AdminService.storeHistoryApproved:
        return 'Onaylandı';
      case AdminService.storeHistoryRejected:
        return 'Reddedildi';
      case AdminService.storeHistoryChangesRequested:
        return 'Eksik Belge';
      case AdminService.storeHistoryResubmitted:
        return 'Tekrar Başvuru';
      default:
        return action;
    }
  }

  String _shortId(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 10) return trimmed;
    return '${trimmed.substring(0, 8)}…';
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchAllStores() async {
    setState(() => _isLoadingStores = true);
    try {
      final stores = await _adminService.getAllStores();
      if (mounted) {
        setState(() {
          _allStores = stores;
          _filteredStores = stores;
          _lastStoreRefreshAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Mağazalar alınamadı: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingStores = false);
    }
  }

  void _filterStores(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredStores = _allStores);
      return;
    }
    final lower = query.toLowerCase();
    setState(() {
      _filteredStores = _allStores.where((s) {
        final name = (s['business_name'] ?? '').toString().toLowerCase();
        final sellerId = (s['seller_id'] ?? '').toString().toLowerCase();
        return name.contains(lower) || sellerId.contains(lower);
      }).toList();
    });
  }

  void _showStoreDetail(Map<String, dynamic> store) {
    showDialog(
      context: context,
      builder: (context) => StoreDetailDialog(
        store: store,
        adminService: _adminService,
        onStoreUpdated: _fetchAllStores,
      ),
    );
  }

  void _showApplicationDetail(
    Map<String, dynamic> application, {
    Map<String, dynamic>? historyEntry,
    bool allowAdminActions = true,
    bool isSnapshotView = false,
  }) {
    final sellerId = (application['user_id'] ?? '').toString();
    final canAct =
        allowAdminActions && AdminService.canAdminActOnApplication(application);
    showDialog(
      context: context,
      builder: (context) => StoreApplicationDetailDialog(
        application: application,
        priorHistory: _priorHistoryForSeller(sellerId, application),
        allowAdminActions: canAct,
        historyEntry: historyEntry,
        isSnapshotView: isSnapshotView,
        onUpdateStatus: (id, status, {rejectionReason, adminNote}) async {
          await _adminService.updateSellerApplicationStatus(
            id,
            status,
            rejectionReason: rejectionReason,
            adminNote: adminNote,
          );
          await _loadApplicationHistory();
          if (mounted) {
            setState(() {});
            _fetchAllStores();
          }
        },
      ),
    );
  }

  Future<void> _openHistoryEntryDetail(
    Map<String, dynamic> entry,
    AdminPanelDensity density,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final resolution =
        await _adminService.resolveApplicationFromHistoryEntry(entry);

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (!mounted) return;

    if (resolution.application['id'] == null &&
        (resolution.application['business_name'] ?? '').toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başvuru detayı bulunamadı.')),
      );
      return;
    }

    _showApplicationDetail(
      resolution.application,
      historyEntry: entry,
      allowAdminActions: resolution.allowAdminActions,
      isSnapshotView: resolution.isSnapshot,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final density = AdminPanelDensity.fromWidth(constraints.maxWidth);
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _adminService.getSellerApplicationsStream(),
          builder: (context, snapshot) {
            final rejectedApplicationsCount = (snapshot.data ?? const [])
                .where(
                  (application) =>
                      (application['status'] ?? '').toString().toLowerCase() ==
                      'rejected',
                )
                .length;

            return Container(
              color: const Color(0xFFF4F7FB),
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          density.pagePadding,
                          density.pagePadding,
                          density.pagePadding,
                          density.sectionGap,
                        ),
                        child: _buildOverviewHero(
                          rejectedApplicationsCount: rejectedApplicationsCount,
                          density: density,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          density.pagePadding,
                          0,
                          density.pagePadding,
                          density.blockGap,
                        ),
                        child: _buildTabStrip(density),
                      ),
                    ),
                  ];
                },
                body: Padding(
                  padding: EdgeInsets.fromLTRB(
                    density.pagePadding,
                    0,
                    density.pagePadding,
                    density.pagePadding,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        density.isCompact ? 16 : 20,
                      ),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D0F172A),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        density.isCompact ? 16 : 20,
                      ),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildApplicationsTab(),
                          _buildAllStoresTab(),
                          _buildLocationChangeRequestsTab(),
                          _buildDeletionRequestsTab(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String get _activeTabTitle {
    switch (_tabController.index) {
      case 0:
        return 'Satıcı Başvuruları';
      case 1:
        return 'Tüm Mağazalar';
      case 2:
        return 'Konum Değişim Talepleri';
      case 3:
        return 'Silme Talepleri';
      default:
        return 'Mağaza Yönetimi';
    }
  }

  String get _activeTabDescription {
    switch (_tabController.index) {
      case 0:
        return 'Yeni mağaza başvurularını inceleyin, detaylarını açın ve tek akıştan karar verin.';
      case 1:
        return 'Kayıtlı tüm mağazaları arayın, durumlarını izleyin ve detay yönetim ekranına geçin.';
      case 2:
        return 'Konum güncelleme isteklerini mevcut koordinatlarla karşılaştırıp güvenli şekilde onaylayın.';
      case 3:
        return 'Silme taleplerinde gerekçeyi ve durumu tek bakışta görün, kapanış sürecini yönetin.';
      default:
        return 'Mağaza operasyonlarını tek merkezden yönetin.';
    }
  }

  Widget _buildOverviewHero({
    required int rejectedApplicationsCount,
    required AdminPanelDensity density,
  }) {
    final openStores = _allStores
        .where((store) => store['is_store_open'] == true)
        .length;
    final uniqueCategories = _allStores
        .map((store) => (store['category'] ?? '').toString().trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .length;

    return Container(
      padding: density.storeHeroPadding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF134E4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(density.heroBorderRadius),
        boxShadow: density.isCompact
            ? null
            : const [
                BoxShadow(
                  color: Color(0x1A0F172A),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
      ),
      child: density.heroSideBySide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildHeroCopy(density: density)),
                SizedBox(width: density.blockGap),
                Expanded(
                  child: _buildHeroMetrics(
                    totalStores: _allStores.length,
                    openStores: openStores,
                    rejectedApplicationsCount: rejectedApplicationsCount,
                    uniqueCategories: uniqueCategories,
                    density: density,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCopy(density: density),
                SizedBox(height: density.sectionGap),
                _buildHeroMetrics(
                  totalStores: _allStores.length,
                  openStores: openStores,
                  rejectedApplicationsCount: rejectedApplicationsCount,
                  uniqueCategories: uniqueCategories,
                  density: density,
                ),
              ],
            ),
    );
  }

  Widget _buildHeroCopy({required AdminPanelDensity density}) {
    final syncLabel = _lastStoreRefreshAt == null
        ? 'Henüz senkron alınmadı'
        : 'Son senkron ${_formatTime(_lastStoreRefreshAt!)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(
            _activeTabTitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(height: density.isCompact ? 6 : 8),
        Text(
          density.isCompact ? _activeTabTitle : 'Mağaza operasyon merkezi',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: density.storeHeroTitleFontSize,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        SizedBox(height: density.isCompact ? 3 : 4),
        Text(
          _activeTabDescription,
          maxLines: density.storeHeroSubtitleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: density.heroSubtitleFontSize,
            height: 1.35,
          ),
        ),
        SizedBox(height: density.isCompact ? 6 : 8),
        Wrap(
          spacing: density.gridSpacing,
          runSpacing: 6,
          children: [
            _buildHeroSignalPill(
              icon: Icons.sync_rounded,
              label: syncLabel,
              density: density,
            ),
            _buildHeroSignalPill(
              icon: Icons.search_rounded,
              label: _searchController.text.trim().isEmpty
                  ? 'Liste filtresi kapalı'
                  : '${_filteredStores.length} filtreli sonuç',
              density: density,
            ),
            _buildHeroSignalPill(
              icon: Icons.verified_user_outlined,
              label: 'Detay ve aksiyonlar tek panelde',
              density: density,
            ),
          ],
        ),
        SizedBox(height: density.isCompact ? 6 : 8),
        Wrap(
          spacing: density.gridSpacing,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: _isLoadingStores ? null : _fetchAllStores,
              icon: _isLoadingStores
                  ? SizedBox(
                      width: density.storeHeroActionIconSize,
                      height: density.storeHeroActionIconSize,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      size: density.storeHeroActionIconSize,
                    ),
              label: Text(
                _isLoadingStores ? 'Yenileniyor' : 'Yenile',
                style: TextStyle(fontSize: density.isCompact ? 11 : 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                padding: EdgeInsets.symmetric(
                  horizontal: density.storeHeroActionPaddingH,
                  vertical: density.storeHeroActionPaddingV,
                ),
                visualDensity: VisualDensity.compact,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const AdminAdsManagerPage(),
                  ),
                );
              },
              icon: Icon(
                Icons.ads_click_outlined,
                size: density.storeHeroActionIconSize,
              ),
              label: Text(
                'Reklam Yönetimi',
                style: TextStyle(fontSize: density.isCompact ? 11 : 12),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F172A),
                padding: EdgeInsets.symmetric(
                  horizontal: density.storeHeroActionPaddingH,
                  vertical: density.storeHeroActionPaddingV,
                ),
                visualDensity: VisualDensity.compact,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroMetrics({
    required int totalStores,
    required int openStores,
    required int rejectedApplicationsCount,
    required int uniqueCategories,
    required AdminPanelDensity density,
  }) {
    final cardWidth = density.storeHeroMetricWidth;
    return Wrap(
      spacing: density.gridSpacing,
      runSpacing: 6,
      children: [
        _buildHeroMetricCard(
          title: 'Toplam Mağaza',
          value: '$totalStores',
          icon: Icons.storefront_rounded,
          accent: const Color(0xFF38BDF8),
          width: cardWidth,
          density: density,
        ),
        _buildHeroMetricCard(
          title: 'Açık Mağaza',
          value: '$openStores',
          icon: Icons.lock_open_rounded,
          accent: const Color(0xFF34D399),
          width: cardWidth,
          density: density,
        ),
        _buildHeroMetricCard(
          title: 'Reddedilen',
          value: '$rejectedApplicationsCount',
          icon: Icons.close_rounded,
          accent: const Color(0xFFEF4444),
          width: cardWidth,
          density: density,
        ),
        _buildHeroMetricCard(
          title: 'Kategori',
          value: '$uniqueCategories',
          icon: Icons.category_rounded,
          accent: const Color(0xFFFBBF24),
          width: cardWidth,
          density: density,
        ),
      ],
    );
  }

  Widget _buildHeroMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
    required double width,
    required AdminPanelDensity density,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(
        horizontal: density.isCompact ? 8 : 10,
        vertical: density.storeHeroMetricPaddingV,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(density.isCompact ? 10 : 12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: density.storeHeroMetricIconBox,
            height: density.storeHeroMetricIconBox,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              icon,
              color: accent,
              size: density.isCompact ? 12 : 13,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: density.storeHeroMetricValueFontSize,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: density.isCompact ? 8.5 : 9,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSignalPill({
    required IconData icon,
    required String label,
    required AdminPanelDensity density,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: density.storeHeroSignalPillPaddingH,
        vertical: density.storeHeroSignalPillPaddingV,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: density.storeHeroSignalPillIconSize,
            color: Colors.white.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: density.storeHeroSignalPillFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabStrip(AdminPanelDensity density) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        Widget tabItem(int index, IconData icon, String label) {
          final selected = _tabController.index == index;
          final color = selected ? Colors.white : const Color(0xFF475569);
          return Tab(
            height: density.storeTabHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: density.storeTabPaddingH),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: density.storeTabIconSize, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: density.storeTabFontSize,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(density.storeTabStripPadding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(density.isCompact ? 16 : 18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              color: const Color(0xFF0F766E),
              borderRadius: BorderRadius.circular(density.isCompact ? 10 : 12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F766E),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF475569),
            tabAlignment: TabAlignment.start,
            tabs: [
              tabItem(0, Icons.approval_outlined, 'Satıcı Başvuruları'),
              tabItem(1, Icons.storefront_outlined, 'Tüm Mağazalar'),
              tabItem(2, Icons.edit_location_alt_outlined, 'Konum Değişim'),
              tabItem(3, Icons.delete_outline_rounded, 'Silme Talepleri'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApplicationsTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final density = AdminPanelDensity.fromWidth(constraints.maxWidth);
        return Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  density.storeSectionPadding,
                  density.storeSectionPadding,
                  density.storeSectionPadding,
                  density.storeCardGap,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      title: _applicationListMode == 'pending'
                          ? 'Bekleyen satıcı başvuruları'
                          : 'Başvuru geçmişi',
                      subtitle: _applicationListMode == 'pending'
                          ? 'Başvuruları detay ekranından inceleyin; onay, red ve eksik belge işlemleri yalnızca detayda yapılır.'
                          : 'Onay, red ve eksik belge kararlarının zaman çizelgesi.',
                      density: density,
                      action: OutlinedButton.icon(
                        onPressed: _isLoadingStores ? null : _fetchAllStores,
                        icon: Icon(
                          Icons.sync_rounded,
                          size: density.storeActionIconSize,
                        ),
                        label: const Text('Mağazaları Eşle'),
                        style: _secondaryButtonStyle(density),
                      ),
                    ),
                    SizedBox(height: density.storeCardGap),
                    _buildApplicationListModeToggle(density),
                    if (_applicationListMode == 'history') ...[
                      SizedBox(height: density.storeCardGap),
                      _buildApplicationHistoryFilters(density),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _applicationListMode == 'pending'
                    ? _buildPendingApplicationsList(density)
                    : _buildApplicationHistoryList(density),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApplicationListModeToggle(AdminPanelDensity density) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Bekleyenler'),
          selected: _applicationListMode == 'pending',
          onSelected: (_) => setState(() => _applicationListMode = 'pending'),
          visualDensity: VisualDensity.compact,
        ),
        ChoiceChip(
          label: const Text('Geçmiş'),
          selected: _applicationListMode == 'history',
          onSelected: (_) {
            setState(() => _applicationListMode = 'history');
            _loadApplicationHistory();
          },
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildApplicationHistoryFilters(AdminPanelDensity density) {
    const actionFilters = [
      ('all', 'Tümü'),
      (AdminService.storeHistoryApproved, 'Onaylananlar'),
      (AdminService.storeHistoryRejected, 'Reddedilenler'),
      (AdminService.storeHistoryChangesRequested, 'Eksik Belge'),
    ];
    const dateFilters = [
      ('all', 'Tüm zaman'),
      ('7', 'Son 7 gün'),
      ('30', 'Son 30 gün'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: actionFilters
              .map(
                (item) => FilterChip(
                  label: Text(
                    item.$2,
                    style: TextStyle(fontSize: density.isCompact ? 11 : 12),
                  ),
                  selected: _historyActionFilter == item.$1,
                  onSelected: (_) {
                    setState(() => _historyActionFilter = item.$1);
                    _loadApplicationHistory();
                  },
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(),
        ),
        SizedBox(height: density.isCompact ? 6 : 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: dateFilters
              .map(
                (item) => FilterChip(
                  label: Text(
                    item.$2,
                    style: TextStyle(fontSize: density.isCompact ? 11 : 12),
                  ),
                  selected: _historyDateFilter == item.$1,
                  onSelected: (_) {
                    setState(() => _historyDateFilter = item.$1);
                    _loadApplicationHistory();
                  },
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPendingApplicationsList(AdminPanelDensity density) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _adminService.getSellerApplicationsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('Başvurular alınamadı', snapshot.error);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final storeSellerIds = _allStores
            .map((store) => (store['seller_id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toSet();
        final applications = snapshot.data!.where((app) {
          final status = (app['status'] ?? 'pending').toString().toLowerCase();
          final userId = (app['user_id'] ?? '').toString();
          final alreadyStoreOwner =
              userId.isNotEmpty && storeSellerIds.contains(userId);
          return (status == AdminApprovalStatusConstants.pending ||
                  status == AdminService.sellerApplicationMissingDocuments) &&
              !alreadyStoreOwner;
        }).toList();

        if (applications.isEmpty) {
          return _buildEmptyState(
            icon: Icons.verified_rounded,
            title: 'Bekleyen başvuru yok',
            subtitle:
                'Yeni satıcı başvurusu geldiğinde burada kart olarak görünecek.',
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            density.storeSectionPadding,
            0,
            density.storeSectionPadding,
            density.storeSectionPadding,
          ),
          itemCount: applications.length,
          separatorBuilder: (_, _) =>
              SizedBox(height: density.storeListSeparator),
          itemBuilder: (context, index) => _buildApplicationCard(
            applications[index],
            density,
          ),
        );
      },
    );
  }

  Widget _buildApplicationHistoryList(AdminPanelDensity density) {
    if (_loadingApplicationHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_applicationHistory.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_rounded,
        title: 'Geçmiş kayıt yok',
        subtitle:
            'Onay, red veya eksik belge işlemleri burada zaman çizelgesi olarak görünecek.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        density.storeSectionPadding,
        0,
        density.storeSectionPadding,
        density.storeSectionPadding,
      ),
      itemCount: _applicationHistory.length,
      separatorBuilder: (_, _) => SizedBox(height: density.storeListSeparator),
      itemBuilder: (context, index) =>
          _buildApplicationHistoryCard(_applicationHistory[index], density),
    );
  }

  Widget _buildApplicationCard(
    Map<String, dynamic> application,
    AdminPanelDensity density,
  ) {
    final businessName = (application['business_name'] ?? 'İsimsiz mağaza')
        .toString();
    final category = (application['category'] ?? 'Kategori belirtilmemiş')
        .toString();
    final userId = (application['user_id'] ?? '').toString();
    final createdAt = _formatDateLabel(application['created_at']);
    final status = (application['status'] ?? AdminApprovalStatusConstants.pending)
        .toString()
        .toLowerCase();
    final isMissingDocuments =
        status == AdminService.sellerApplicationMissingDocuments;
    final hints = _resubmitHintsFor(userId, application);

    return Container(
      padding: EdgeInsets.all(density.storeCardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(density.storeCardBorderRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: density.storeCardIconBox,
            height: density.storeCardIconBox,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(density.isCompact ? 12 : 14),
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: const Color(0xFF1D4ED8),
              size: density.storeCardIconSize,
            ),
          ),
          SizedBox(width: density.isCompact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF0F172A),
                    fontSize: density.storeCardTitleFontSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: density.isCompact ? 4 : 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildMetaChip(
                      icon: Icons.sell_outlined,
                      label: category,
                      density: density,
                    ),
                    if (userId.isNotEmpty)
                      _buildMetaChip(
                        icon: Icons.person_outline_rounded,
                        label: _shortId(userId),
                        density: density,
                      ),
                    _buildMetaChip(
                      icon: Icons.schedule_rounded,
                      label: createdAt,
                      density: density,
                    ),
                    _buildStatusChip(
                      label: isMissingDocuments ? 'Eksik Belge' : 'Bekliyor',
                      background: isMissingDocuments
                          ? const Color(0xFFEEF2FF)
                          : const Color(0xFFFFF7ED),
                      foreground: isMissingDocuments
                          ? const Color(0xFF4338CA)
                          : const Color(0xFFEA580C),
                      density: density,
                    ),
                    if (hints.previouslyRejected)
                      _buildStatusChip(
                        label: 'Daha önce reddedildi',
                        background: const Color(0xFFFFF1F2),
                        foreground: const Color(0xFFE11D48),
                        density: density,
                      ),
                    if (hints.previouslyMissingDocuments)
                      _buildStatusChip(
                        label: 'Tekrar başvuru',
                        background: const Color(0xFFEEF2FF),
                        foreground: const Color(0xFF4338CA),
                        density: density,
                      ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: density.isCompact ? 8 : 10),
          OutlinedButton(
            onPressed: () => _showApplicationDetail(application),
            style: _secondaryButtonStyle(density),
            child: const Text('Detay Aç'),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationHistoryCard(
    Map<String, dynamic> entry,
    AdminPanelDensity density,
  ) {
    final action = (entry['action'] ?? '').toString();
    final storeName =
        (entry['store_name'] ?? 'İsimsiz mağaza').toString();
    final noteText = AdminService.formatStoreApplicationHistoryNote(entry);
    final applicationDate = _formatDateLabel(entry['application_created_at']);
    final actedDate = _formatDateLabel(entry['acted_at']);
    final statusLabel = _historyActionLabel(action);

    Color badgeBg = const Color(0xFFF8FAFC);
    Color badgeFg = const Color(0xFF475569);
    if (action == AdminService.storeHistoryApproved) {
      badgeBg = const Color(0xFFECFDF5);
      badgeFg = const Color(0xFF059669);
    } else if (action == AdminService.storeHistoryRejected) {
      badgeBg = const Color(0xFFFFF1F2);
      badgeFg = const Color(0xFFE11D48);
    } else if (action == AdminService.storeHistoryChangesRequested) {
      badgeBg = const Color(0xFFEEF2FF);
      badgeFg = const Color(0xFF4338CA);
    }

    final canOpenDetail =
        action == AdminService.storeHistoryRejected ||
        action == AdminService.storeHistoryChangesRequested;

    return Container(
      padding: EdgeInsets.all(density.storeCardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(density.storeCardBorderRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF0F172A),
                    fontSize: density.storeCardTitleFontSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: density.isCompact ? 4 : 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildMetaChip(
                      icon: Icons.event_note_outlined,
                      label: 'Başvuru: $applicationDate',
                      density: density,
                    ),
                    _buildMetaChip(
                      icon: Icons.history_rounded,
                      label: 'İşlem: $actedDate',
                      density: density,
                    ),
                    _buildStatusChip(
                      label: statusLabel,
                      background: badgeBg,
                      foreground: badgeFg,
                      density: density,
                    ),
                  ],
                ),
                SizedBox(height: density.isCompact ? 6 : 8),
                Text(
                  noteText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: density.isCompact ? 12 : 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (canOpenDetail) ...[
            SizedBox(width: density.isCompact ? 8 : 10),
            OutlinedButton(
              onPressed: () => _openHistoryEntryDetail(entry, density),
              style: _secondaryButtonStyle(density),
              child: const Text('Detay'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAllStoresTab() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              children: [
                _buildSectionHeader(
                  title: 'Mağaza envanteri',
                  subtitle:
                      'Arama, durum kontrolü ve detay yönetimi için tek bakışta okunabilen mağaza listesi.',
                  action: FilledButton.icon(
                    onPressed: _isLoadingStores ? null : _fetchAllStores,
                    icon: _isLoadingStores
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      _isLoadingStores ? 'Yükleniyor' : 'Listeyi Yenile',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterStores,
                    decoration: InputDecoration(
                      hintText: 'Mağaza adı veya satıcı ID ile ara...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF64748B),
                      ),
                      suffixIcon: _searchController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _filterStores('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingStores
                ? const Center(child: CircularProgressIndicator())
                : _filteredStores.isEmpty
                ? _buildEmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Mağaza bulunamadı',
                    subtitle:
                        'Arama kriterini temizleyin veya listeyi yeniden yenileyin.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: _filteredStores.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) =>
                        _buildStoreCard(_filteredStores[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store) {
    final isOpen = store['is_store_open'] == true;
    final rating = _asDouble(store['rating']);
    final sellerId = (store['seller_id'] ?? '').toString();
    final category = (store['category'] ?? 'Kategori yok').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _showStoreDetail(store),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 860;
            final leading = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(18),
                    image: store['logo_url'] != null
                        ? DecorationImage(
                            image: ResizeImage.resizeIfNeeded(
                              180,
                              180,
                              NetworkImage(store['logo_url'].toString()),
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: store['logo_url'] == null
                      ? const Icon(
                          Icons.storefront_rounded,
                          color: Color(0xFF64748B),
                          size: 28,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              (store['business_name'] ?? 'İsimsiz mağaza')
                                  .toString(),
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildStatusChip(
                            label: isOpen ? 'Açık' : 'Kapalı',
                            background: isOpen
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFFFF1F2),
                            foreground: isOpen
                                ? const Color(0xFF059669)
                                : const Color(0xFFE11D48),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (sellerId.isNotEmpty)
                            _buildMetaChip(
                              icon: Icons.badge_outlined,
                              label: sellerId,
                            ),
                          _buildMetaChip(
                            icon: Icons.category_outlined,
                            label: category,
                          ),
                          _buildMetaChip(
                            icon: Icons.star_outline_rounded,
                            label: rating.toStringAsFixed(1),
                          ),
                          _buildMetaChip(
                            icon: Icons.calendar_today_outlined,
                            label: _formatDateLabel(store['created_at']),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showStoreDetail(store),
                  icon: const Icon(Icons.analytics_outlined, size: 18),
                  label: const Text('Detay Paneli'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showStoreDetail(store),
                  icon: const Icon(Icons.arrow_outward_rounded, size: 18),
                  label: const Text('İncele'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE0F2F1),
                    foregroundColor: const Color(0xFF0F766E),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [leading, const SizedBox(height: 18), actions],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: leading),
                const SizedBox(width: 16),
                SizedBox(width: 220, child: actions),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDeletionRequestsTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final density = AdminPanelDensity.fromWidth(constraints.maxWidth);
        return Container(
          color: const Color(0xFFF8FAFC),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _adminService.getStoreDeletionRequestsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildErrorState(
                  'Silme talepleri alınamadı',
                  snapshot.error,
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final requests = snapshot.data!;
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      density.storeSectionPadding,
                      density.storeSectionPadding,
                      density.storeSectionPadding,
                      density.storeCardGap,
                    ),
                    child: _buildSectionHeader(
                      title: 'Mağaza silme akışı',
                      subtitle:
                          'Silme taleplerini gerekçeleriyle birlikte değerlendirin ve kalıcı aksiyonları kontrollü şekilde yönetin.',
                      density: density,
                    ),
                  ),
                  Expanded(
                    child: requests.isEmpty
                        ? _buildEmptyState(
                            icon: Icons.delete_outline_rounded,
                            title: 'Silme talebi yok',
                            subtitle:
                                'Satıcılardan gelen mağaza kapatma istekleri burada listelenecek.',
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              density.storeSectionPadding,
                              0,
                              density.storeSectionPadding,
                              density.storeSectionPadding,
                            ),
                            itemCount: requests.length,
                            separatorBuilder: (_, _) =>
                                SizedBox(height: density.storeListSeparator),
                            itemBuilder: (context, index) =>
                                _buildDeletionCard(requests[index], density),
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDeletionCard(
    Map<String, dynamic> request,
    AdminPanelDensity density,
  ) {
    final status = (request['status'] ?? 'pending').toString();
    final isPending = status == AdminApprovalStatusConstants.pending;
    final sellerId = (request['seller_id'] ?? '-').toString();
    final reason = (request['reason'] ?? 'Sebep belirtilmemiş').toString();

    final statusBackground = switch (status) {
      'approved' => const Color(0xFFECFDF5),
      'rejected' => const Color(0xFFFFF1F2),
      _ => const Color(0xFFFFF7ED),
    };
    final statusForeground = switch (status) {
      'approved' => const Color(0xFF059669),
      'rejected' => const Color(0xFFE11D48),
      _ => const Color(0xFFEA580C),
    };
    final statusLabel = switch (status) {
      'approved' => 'Onaylandı',
      'rejected' => 'Reddedildi',
      _ => 'Bekliyor',
    };

    return Container(
      padding: EdgeInsets.all(density.storeCardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(density.storeCardBorderRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: density.storeCardIconBox,
                height: density.storeCardIconBox,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(
                    density.isCompact ? 12 : 14,
                  ),
                ),
                child: Icon(
                  Icons.delete_sweep_outlined,
                  color: const Color(0xFFE11D48),
                  size: density.storeCardIconSize,
                ),
              ),
              SizedBox(width: density.isCompact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mağaza ID: $sellerId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF0F172A),
                        fontSize: density.storeCardTitleFontSize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: density.isCompact ? 4 : 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildMetaChip(
                          icon: Icons.schedule_outlined,
                          label: _formatDateLabel(request['created_at']),
                          density: density,
                        ),
                        if ((request['business_name'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          _buildMetaChip(
                            icon: Icons.store_outlined,
                            label: request['business_name'].toString(),
                            density: density,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildStatusChip(
                label: statusLabel,
                background: statusBackground,
                foreground: statusForeground,
                density: density,
              ),
            ],
          ),
          SizedBox(height: density.storeCardGap),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(density.storeLocationInfoPadding),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(density.storeActionRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Talep Gerekçesi',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: density.storeLocationInfoTitleFontSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: density.isCompact ? 4 : 6),
                Text(
                  reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF0F172A),
                    fontSize: density.storeLocationInfoValueFontSize,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isPending) ...[
            SizedBox(height: density.storeCardGap),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _adminService.rejectStoreDeletion(
                    request['id'].toString(),
                    'Admin tarafından reddedildi',
                  ),
                  icon: Icon(
                    Icons.close_rounded,
                    size: density.storeActionIconSize,
                  ),
                  label: const Text('Reddet'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    padding: EdgeInsets.symmetric(
                      horizontal: density.storeActionPaddingH,
                      vertical: density.storeActionPaddingV,
                    ),
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(density.storeActionRadius),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _adminService.approveStoreDeletion(
                    request['id'].toString(),
                    sellerId,
                  ),
                  icon: Icon(
                    Icons.check_rounded,
                    size: density.storeActionIconSize,
                  ),
                  label: const Text('Silmeyi Onayla'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: density.storeActionPaddingH,
                      vertical: density.storeActionPaddingV,
                    ),
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(density.storeActionRadius),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationChangeRequestsTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final density = AdminPanelDensity.fromWidth(constraints.maxWidth);
        return Container(
          color: const Color(0xFFF8FAFC),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _adminService.getStoreLocationChangeRequestsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildErrorState(
                  'Konum talepleri alınamadı',
                  snapshot.error,
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final requests = snapshot.data!;
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      density.storeSectionPadding,
                      density.storeSectionPadding,
                      density.storeSectionPadding,
                      density.storeCardGap,
                    ),
                    child: _buildSectionHeader(
                      title: 'Konum güncelleme talepleri',
                      subtitle:
                          'Mevcut ve talep edilen koordinatları karşılaştırın, konum değişikliğini kontrollü olarak yayına alın.',
                      density: density,
                    ),
                  ),
                  Expanded(
                    child: requests.isEmpty
                        ? _buildEmptyState(
                            icon: Icons.edit_location_alt_outlined,
                            title: 'Konum değişim talebi yok',
                            subtitle:
                                'Mağazalar yeni adres ya da koordinat gönderdiğinde burada görünecek.',
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              density.storeSectionPadding,
                              0,
                              density.storeSectionPadding,
                              density.storeSectionPadding,
                            ),
                            itemCount: requests.length,
                            separatorBuilder: (_, _) =>
                                SizedBox(height: density.storeListSeparator),
                            itemBuilder: (context, index) =>
                                _buildLocationRequestCard(
                              requests[index],
                              density,
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _approveLocationChangeRequest(
    Map<String, dynamic> request, {
    required double requestedLat,
    required double requestedLng,
  }) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _adminService.approveStoreLocationChange(
        request['id'].toString(),
        sellerId: request['seller_id'].toString(),
        requestedLat: requestedLat,
        requestedLng: requestedLng,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konum degisikligi onaylandi.')),
      );
      _fetchAllStores();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Konum onayi basarisiz: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectLocationChangeRequest(
    Map<String, dynamic> request,
  ) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _adminService.rejectStoreLocationChange(request['id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konum degisikligi reddedildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Konum reddi basarisiz: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildLocationRequestCard(
    Map<String, dynamic> request,
    AdminPanelDensity density,
  ) {
    final status = (request['status'] ?? 'pending').toString();
    final isPending = status == AdminApprovalStatusConstants.pending;
    final requestedLat = (request['requested_lat'] as num?)?.toDouble();
    final requestedLng = (request['requested_lng'] as num?)?.toDouble();
    final currentLat = (request['current_lat'] as num?)?.toDouble();
    final currentLng = (request['current_lng'] as num?)?.toDouble();
    final address = [
      (request['city'] ?? '').toString(),
      (request['district'] ?? '').toString(),
    ].where((part) => part.trim().isNotEmpty).join(' / ');

    final statusBackground = switch (status) {
      'approved' => const Color(0xFFECFDF5),
      'rejected' => const Color(0xFFFFF1F2),
      _ => const Color(0xFFFFF7ED),
    };
    final statusForeground = switch (status) {
      'approved' => const Color(0xFF059669),
      'rejected' => const Color(0xFFE11D48),
      _ => const Color(0xFFEA580C),
    };
    final statusLabel = switch (status) {
      'approved' => 'Onaylandı',
      'rejected' => 'Reddedildi',
      _ => 'Bekliyor',
    };

    return Container(
      padding: EdgeInsets.all(density.storeCardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(density.storeCardBorderRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: density.storeCardIconBox,
                height: density.storeCardIconBox,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(
                    density.isCompact ? 12 : 14,
                  ),
                ),
                child: Icon(
                  Icons.location_searching_outlined,
                  color: const Color(0xFF15803D),
                  size: density.storeCardIconSize,
                ),
              ),
              SizedBox(width: density.isCompact ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (request['business_name'] ?? 'İsimsiz mağaza').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF0F172A),
                        fontSize: density.storeCardTitleFontSize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: density.isCompact ? 4 : 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildMetaChip(
                          icon: Icons.badge_outlined,
                          label: (request['seller_id'] ?? '-').toString(),
                          density: density,
                        ),
                        if (address.isNotEmpty)
                          _buildMetaChip(
                            icon: Icons.map_outlined,
                            label: address,
                            density: density,
                          ),
                        _buildMetaChip(
                          icon: Icons.schedule_rounded,
                          label: _formatDateLabel(request['created_at']),
                          density: density,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildStatusChip(
                label: statusLabel,
                background: statusBackground,
                foreground: statusForeground,
                density: density,
              ),
            ],
          ),
          SizedBox(height: density.storeCardGap),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 520;
              final locationCards = [
                Expanded(
                  child: _buildLocationInfoCard(
                    title: 'Mevcut Konum',
                    value: currentLat != null && currentLng != null
                        ? '${currentLat.toStringAsFixed(5)}, ${currentLng.toStringAsFixed(5)}'
                        : '-',
                    icon: Icons.my_location_rounded,
                    tint: const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    density: density,
                  ),
                ),
                if (!stacked) SizedBox(width: density.isCompact ? 8 : 10),
                Expanded(
                  child: _buildLocationInfoCard(
                    title: 'Talep Edilen Konum',
                    value: requestedLat != null && requestedLng != null
                        ? '${requestedLat.toStringAsFixed(5)}, ${requestedLng.toStringAsFixed(5)}'
                        : '-',
                    icon: Icons.place_outlined,
                    tint: const Color(0xFFDCFCE7),
                    iconColor: const Color(0xFF15803D),
                    density: density,
                  ),
                ),
              ];

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLocationInfoCard(
                      title: 'Mevcut Konum',
                      value: currentLat != null && currentLng != null
                          ? '${currentLat.toStringAsFixed(5)}, ${currentLng.toStringAsFixed(5)}'
                          : '-',
                      icon: Icons.my_location_rounded,
                      tint: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
                      density: density,
                    ),
                    SizedBox(height: density.isCompact ? 6 : 8),
                    _buildLocationInfoCard(
                      title: 'Talep Edilen Konum',
                      value: requestedLat != null && requestedLng != null
                          ? '${requestedLat.toStringAsFixed(5)}, ${requestedLng.toStringAsFixed(5)}'
                          : '-',
                      icon: Icons.place_outlined,
                      tint: const Color(0xFFDCFCE7),
                      iconColor: const Color(0xFF15803D),
                      density: density,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: locationCards,
              );
            },
          ),
          if (isPending) ...[
            SizedBox(height: density.storeCardGap),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _rejectLocationChangeRequest(request),
                  icon: Icon(
                    Icons.close_rounded,
                    size: density.storeActionIconSize,
                  ),
                  label: const Text('Reddet'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    padding: EdgeInsets.symmetric(
                      horizontal: density.storeActionPaddingH,
                      vertical: density.storeActionPaddingV,
                    ),
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(density.storeActionRadius),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      _isProcessing ||
                          requestedLat == null ||
                          requestedLng == null
                      ? null
                      : () async {
                          await _approveLocationChangeRequest(
                            request,
                            requestedLat: requestedLat,
                            requestedLng: requestedLng,
                          );
                        },
                  icon: Icon(
                    Icons.check_rounded,
                    size: density.storeActionIconSize,
                  ),
                  label: const Text('Konumu Onayla'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: density.storeActionPaddingH,
                      vertical: density.storeActionPaddingV,
                    ),
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(density.storeActionRadius),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color tint,
    required Color iconColor,
    required AdminPanelDensity density,
  }) {
    return Container(
      padding: EdgeInsets.all(density.storeLocationInfoPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(density.storeActionRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: density.storeLocationInfoIconBox,
                height: density.storeLocationInfoIconBox,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: density.storeLocationInfoIconSize,
                  color: iconColor,
                ),
              ),
              SizedBox(width: density.isCompact ? 6 : 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: density.storeLocationInfoTitleFontSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: density.isCompact ? 4 : 6),
          Text(
            value.trim().isEmpty ? '-' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF0F172A),
              fontSize: density.storeLocationInfoValueFontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    AdminPanelDensity? density,
    Widget? action,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: const Color(0xFF0F172A),
                  fontSize: density?.storeSectionTitleFontSize ?? 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: density?.isCompact == true ? 4 : 6),
              Text(
                subtitle,
                maxLines: density != null ? 2 : null,
                overflow: density != null ? TextOverflow.ellipsis : null,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: density?.storeSectionSubtitleFontSize ?? 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (action != null) ...[
          SizedBox(width: density?.isCompact == true ? 10 : 16),
          action,
        ],
      ],
    );
  }

  Widget _buildStatusChip({
    required String label,
    required Color background,
    required Color foreground,
    AdminPanelDensity? density,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: density?.storeStatusChipPaddingH ?? 10,
        vertical: density?.storeStatusChipPaddingV ?? 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: density?.storeStatusChipFontSize ?? 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    AdminPanelDensity? density,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: density?.isCompact == true ? 180 : 240,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: density?.storeMetaChipPaddingH ?? 10,
          vertical: density?.storeMetaChipPaddingV ?? 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: density?.storeMetaChipIconSize ?? 15,
              color: const Color(0xFF64748B),
            ),
            SizedBox(width: density?.isCompact == true ? 4 : 6),
            Flexible(
              child: Text(
                label.trim().isEmpty ? '-' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF334155),
                  fontSize: density?.storeMetaChipFontSize ?? 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: const Color(0xFF475569), size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String title, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFE11D48),
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _secondaryButtonStyle([AdminPanelDensity? density]) {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF0F172A),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      padding: EdgeInsets.symmetric(
        horizontal: density?.storeActionPaddingH ?? 16,
        vertical: density?.storeActionPaddingV ?? 14,
      ),
      visualDensity: VisualDensity.compact,
      minimumSize: density != null ? Size.zero : null,
      tapTargetSize:
          density != null ? MaterialTapTargetSize.shrinkWrap : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          density?.storeActionRadius ?? 14,
        ),
      ),
    );
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final dynamic dynamicValue = value;
      final converted = dynamicValue.toDate();
      if (converted is DateTime) {
        return converted;
      }
    } catch (_) {}
    return DateTime.tryParse(value.toString());
  }

  String _formatDateLabel(dynamic value) {
    final date = _readDate(value);
    if (date == null) return 'Tarih yok';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _ApplicationResubmitHints {
  const _ApplicationResubmitHints({
    required this.previouslyRejected,
    required this.previouslyMissingDocuments,
    required this.isResubmission,
  });

  final bool previouslyRejected;
  final bool previouslyMissingDocuments;
  final bool isResubmission;
}

class StoreDetailDialog extends StatefulWidget {
  final Map<String, dynamic> store;
  final AdminService adminService;
  final VoidCallback onStoreUpdated;

  const StoreDetailDialog({
    super.key,
    required this.store,
    required this.adminService,
    required this.onStoreUpdated,
  });

  @override
  State<StoreDetailDialog> createState() => _StoreDetailDialogState();
}

class _StoreDetailDialogState extends State<StoreDetailDialog> {
  late TextEditingController _categoryController;
  late TextEditingController _nameController;
  bool _isLoadingProducts = false;
  bool _isLoadingInsights = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic> _insights = {};
  String _selectedTab = 'Genel Bilgiler';

  bool get _isStoreOpen => widget.store['is_store_open'] == true;

  @override
  void initState() {
    super.initState();
    _categoryController = TextEditingController(
      text: _asText(widget.store['category']),
    );
    _nameController = TextEditingController(
      text: _asText(widget.store['business_name']),
    );
    _loadInsights();
    _fetchProducts();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _asText(dynamic value, {String fallback = '-'}) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _insightText(String key, {String fallback = '-'}) {
    return _asText(_insights[key], fallback: fallback);
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    final raw = value.toString();
    if (raw.length >= 10) {
      return '${raw.substring(8, 10)}.${raw.substring(5, 7)}.${raw.substring(0, 4)}';
    }
    return raw;
  }

  Future<void> _fetchProducts() async {
    final sellerId = widget.store['seller_id'];
    if (sellerId == null) return;

    setState(() => _isLoadingProducts = true);
    try {
      final products = await widget.adminService.getStoreProducts(
        sellerId.toString(),
      );
      if (mounted) setState(() => _products = products);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ürünler alınamadı: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _loadInsights() async {
    final sellerId = widget.store['seller_id'];
    if (sellerId == null) return;

    setState(() => _isLoadingInsights = true);
    try {
      final data = await widget.adminService.getStoreInsights(
        sellerId.toString(),
      );
      if (!mounted) return;
      setState(() => _insights = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mağaza analiz verileri alınamadı: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingInsights = false);
    }
  }

  Future<void> _updateStore() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.adminService
          .updateStore(widget.store['seller_id'].toString(), {
            'business_name': _nameController.text.trim(),
            'category': _categoryController.text.trim(),
          });
      widget.store['business_name'] = _nameController.text.trim();
      widget.store['category'] = _categoryController.text.trim();
      if (mounted) {
        widget.onStoreUpdated();
        _loadInsights();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mağaza güncellendi')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _toggleStoreStatus() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final newValue = !_isStoreOpen;
    try {
      await widget.adminService.updateStore(
        widget.store['seller_id'].toString(),
        {'is_store_open': newValue},
      );
      if (mounted) {
        setState(() => widget.store['is_store_open'] = newValue);
        widget.onStoreUpdated();
        _loadInsights();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue ? 'Mağaza açıldı' : 'Mağaza kapatıldı'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteStore() async {
    try {
      await widget.adminService.deleteStore(
        _asText(widget.store['seller_id'], fallback: ''),
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onStoreUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mağaza ve ürünleri silindi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      await widget.adminService.deleteProduct(productId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ürün silindi')));
        _fetchProducts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 1000,
        height: 760,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Row(
                children: [
                  _buildSidebar(),
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF9FAFB),
                      child: _buildContent(),
                    ),
                  ),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              image: widget.store['logo_url'] != null
                  ? DecorationImage(
                      image: ResizeImage.resizeIfNeeded(
                        144,
                        144,
                        NetworkImage(widget.store['logo_url'].toString()),
                      ),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: widget.store['logo_url'] == null
                ? const Icon(Icons.store, color: Color(0xFF8B5CF6), size: 24)
                : null,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _asText(
                  widget.store['business_name'],
                  fallback: 'İsimsiz Mağaza',
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (_isStoreOpen ? Colors.green : Colors.red)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _isStoreOpen ? 'Mağaza Açık' : 'Mağaza Kapalı',
                      style: TextStyle(
                        color: _isStoreOpen ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Açılış Tarihi: ${_formatDate(widget.store['created_at'])}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 230,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          _buildSidebarItem(Icons.info_outline, 'Genel Bilgiler'),
          _buildSidebarItem(Icons.settings_outlined, 'Mağaza Ayarları'),
          _buildSidebarItem(Icons.inventory_2_outlined, 'Ürünler'),
          _buildSidebarItem(Icons.history, 'Geçmiş İşlemler'),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title) {
    final isSelected = _selectedTab == title;
    return InkWell(
      onTap: () => setState(() => _selectedTab = title),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? const Color(0xFF111827)
                  : Colors.grey.shade500,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF111827)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 'Genel Bilgiler':
        return _buildGeneralInfoTab();
      case 'Mağaza Ayarları':
        return _buildSettingsTab();
      case 'Ürünler':
        return _buildProductsTab();
      case 'Geçmiş İşlemler':
        return _buildHistoryTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildGeneralInfoTab() {
    final applicationScore =
        (_insights['application_score'] as num?)?.toDouble() ?? 0.0;
    final trustScore = (_insights['trust_score'] as num?)?.toInt() ?? 0;
    final riskLevel = _insightText('risk_level');
    final autoVerification = (_insights['auto_verification'] == true);
    final contactEmail = _insightText('email');
    final contactPhone = _insightText('phone');
    final contactAddress = _insightText('address');
    final productCount =
        (_insights['product_count'] as num?)?.toInt() ?? _products.length;

    final appScoreLabel = applicationScore.toStringAsFixed(1);
    final trustScoreLabel = '$trustScore/100';

    final riskColor = riskLevel == 'Düşük'
        ? Colors.green
        : riskLevel == 'Orta'
        ? Colors.orange
        : Colors.red;

    final autoLabel = autoVerification ? 'Başarılı' : 'Eksik';
    final autoColor = autoVerification ? Colors.teal : Colors.red;

    if (_isLoadingInsights && _insights.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Row(
          children: [
            _buildScoreCard(
              'Başvuru Skoru',
              appScoreLabel,
              Icons.analytics_outlined,
              Colors.blue,
            ),
            const SizedBox(width: 12),
            _buildScoreCard(
              'Risk Seviyesi',
              riskLevel,
              Icons.shield_outlined,
              riskColor,
            ),
            const SizedBox(width: 12),
            _buildScoreCard(
              'Oto. Doğrulama',
              autoLabel,
              Icons.verified_outlined,
              autoColor,
            ),
            const SizedBox(width: 12),
            _buildScoreCard(
              'Güven Puanı',
              trustScoreLabel,
              Icons.workspace_premium_outlined,
              const Color(0xFF8B5CF6),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Text(
          'Kurumsal Kimlik',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildInfoRow('Mağaza Adı', _asText(widget.store['business_name'])),
        _buildInfoRow('Satıcı ID', _asText(widget.store['seller_id'])),
        _buildInfoRow('Kategori', _asText(widget.store['category'])),
        _buildInfoRow('E-posta', contactEmail),
        _buildInfoRow('Telefon', contactPhone),
        _buildInfoRow('Adres', contactAddress),
        _buildInfoRow('Kayıt Tarihi', _formatDate(widget.store['created_at'])),
        const SizedBox(height: 24),
        const Text(
          'Otomatik Sistem Kontrolleri',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildCheckRow(
          'Logo Kontrolü',
          widget.store['logo_url'] != null ? 'Yüklü' : 'Eksik',
          widget.store['logo_url'] != null,
        ),
        _buildCheckRow(
          'Kategori Kontrolü',
          _asText(widget.store['category']) == '-' ? 'Eksik' : 'Tamam',
          _asText(widget.store['category']) != '-',
        ),
        _buildCheckRow(
          'İletişim Bilgisi',
          (contactEmail != '-' && contactPhone != '-') ? 'Tamam' : 'Eksik',
          (contactEmail != '-' && contactPhone != '-'),
        ),
        _buildCheckRow(
          'Ürün Aktivitesi',
          productCount == 0 ? 'Ürün yok' : '$productCount ürün',
          productCount > 0,
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const Text(
          'Mağaza Ayarları',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Mağaza Adı',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _categoryController,
          decoration: const InputDecoration(
            labelText: 'Kategori',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Mağazayı Sil?'),
                            content: const Text(
                              'Bu mağazayı ve tüm ürünlerini kalıcı olarak silmek istediğinize emin misiniz?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('İptal'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _deleteStore();
                                },
                                child: const Text(
                                  'Sil',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  'Mağazayı Sil',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade200),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _updateStore,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  _isSaving ? 'Kaydediliyor...' : 'Değişiklikleri Kaydet',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductsTab() {
    if (_isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_products.isEmpty) {
      return const Center(child: Text('Bu mağazanın ürünü yok.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _products.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final product = _products[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  image:
                      (product['image_url'] != null &&
                          product['image_url'].toString().isNotEmpty)
                      ? DecorationImage(
                          image: ResizeImage.resizeIfNeeded(
                            156,
                            156,
                            NetworkImage(product['image_url'].toString()),
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child:
                    (product['image_url'] == null ||
                        product['image_url'].toString().isEmpty)
                    ? const Icon(Icons.image_outlined, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _asText(product['name'], fallback: 'İsimsiz Ürün'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product['price'] ?? '-'} TL',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Ürün Silinsin mi?'),
                      content: Text(
                        '${_asText(product['name'])} ürününü silmek istediğinize emin misiniz?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('İptal'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _deleteProduct(product['id'].toString());
                          },
                          child: const Text(
                            'Sil',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const Text(
          'Geçmiş İşlemler',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildHistoryItem(
          'Mağaza oluşturuldu',
          _formatDate(widget.store['created_at']),
        ),
        _buildHistoryItem(
          'Son durum güncellemesi',
          _isStoreOpen ? 'Mağaza açık' : 'Mağaza kapalı',
        ),
        _buildHistoryItem('Toplam ürün', '${_products.length} ürün kayıtlı'),
      ],
    );
  }

  Widget _buildFooter() {
    final isSettings = _selectedTab == 'Mağaza Ayarları';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () {
              if (isSettings) {
                setState(() => _selectedTab = 'Genel Bilgiler');
              } else {
                Navigator.pop(context);
              }
            },
            icon: Icon(isSettings ? Icons.arrow_back : Icons.close, size: 16),
            label: Text(isSettings ? 'Genel Bilgilere Dön' : 'Kapat'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8B5CF6),
              side: const BorderSide(color: Color(0xFF8B5CF6)),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSaving
                ? null
                : () {
                    if (isSettings) {
                      _updateStore();
                    } else {
                      _toggleStoreStatus();
                    }
                  },
            icon: Icon(
              isSettings
                  ? Icons.save_outlined
                  : (_isStoreOpen
                        ? Icons.lock_outline
                        : Icons.lock_open_outlined),
              size: 16,
            ),
            label: Text(
              _isSaving
                  ? 'İşleniyor...'
                  : (isSettings
                        ? 'Değişiklikleri Kaydet'
                        : (_isStoreOpen ? 'Mağazayı Kapat' : 'Mağazayı Aç')),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(String label, String status, bool isSuccess) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.cancel,
            color: isSuccess ? Colors.green : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(
            status,
            style: TextStyle(
              color: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 18, color: Color(0xFF8B5CF6)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
