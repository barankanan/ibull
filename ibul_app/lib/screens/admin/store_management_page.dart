import 'package:flutter/material.dart';

import '../../ads/presentation/pages/admin_ads_manager_page.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchAllStores();
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

  Future<void> _approveApplication(String applicationId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _adminService.updateSellerApplicationStatus(
        applicationId,
        'approved',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mağaza başvurusu onaylandı.')),
        );
        _fetchAllStores();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata oluştu: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectApplication(
    String applicationId, {
    String reason = 'Admin tarafından reddedildi',
  }) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _adminService.updateSellerApplicationStatus(
        applicationId,
        'rejected',
        rejectionReason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Başvuru reddedildi.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata oluştu: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _markApplicationMissingDocuments(
    String applicationId, {
    String note = 'Eksik belge nedeniyle ek evrak talep edildi',
  }) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _adminService.updateSellerApplicationStatus(
        applicationId,
        'missing_documents',
        rejectionReason: note,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eksik belge bildirimi kaydedildi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata oluştu: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showApplicationDetail(Map<String, dynamic> application) {
    showDialog(
      context: context,
      builder: (context) => StoreApplicationDetailDialog(
        application: application,
        onUpdateStatus: (id, status, {rejectionReason}) async {
          await _adminService.updateSellerApplicationStatus(
            id,
            status,
            rejectionReason: rejectionReason,
          );
          if (mounted) setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: _buildOverviewHero(
                      rejectedApplicationsCount: rejectedApplicationsCount,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: _buildTabStrip(),
                  ),
                ),
              ];
            },
            body: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
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
                  borderRadius: BorderRadius.circular(28),
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

  Widget _buildOverviewHero({required int rejectedApplicationsCount}) {
    final openStores = _allStores
        .where((store) => store['is_store_open'] == true)
        .length;
    final uniqueCategories = _allStores
        .map((store) => (store['category'] ?? '').toString().trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF134E4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroCopy(),
          const SizedBox(height: 16),
          _buildHeroMetrics(
            totalStores: _allStores.length,
            openStores: openStores,
            rejectedApplicationsCount: rejectedApplicationsCount,
            uniqueCategories: uniqueCategories,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCopy() {
    final syncLabel = _lastStoreRefreshAt == null
        ? 'Henüz senkron alınmadı'
        : 'Son senkron ${_formatTime(_lastStoreRefreshAt!)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(
            _activeTabTitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Mağaza operasyon merkezini daha net, daha hızlı ve daha kontrollü yönetin.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _activeTabDescription,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildHeroSignalPill(icon: Icons.sync_rounded, label: syncLabel),
            _buildHeroSignalPill(
              icon: Icons.search_rounded,
              label: _searchController.text.trim().isEmpty
                  ? 'Liste filtresi kapalı'
                  : '${_filteredStores.length} filtreli sonuç',
            ),
            _buildHeroSignalPill(
              icon: Icons.verified_user_outlined,
              label: 'Detay ve aksiyonlar tek panelde',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
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
              label: Text(_isLoadingStores ? 'Yenileniyor' : 'Mağazaları Yenile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
              icon: const Icon(Icons.ads_click_outlined, size: 18),
              label: const Text('Reklam Yonetimi'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildHeroMetricCard(
          title: 'Toplam Mağaza',
          value: '$totalStores',
          icon: Icons.storefront_rounded,
          accent: const Color(0xFF38BDF8),
        ),
        _buildHeroMetricCard(
          title: 'Açık Mağaza',
          value: '$openStores',
          icon: Icons.lock_open_rounded,
          accent: const Color(0xFF34D399),
        ),
        _buildHeroMetricCard(
          title: 'Reddedilen Başvuru',
          value: '$rejectedApplicationsCount',
          icon: Icons.close_rounded,
          accent: const Color(0xFFEF4444),
        ),
        _buildHeroMetricCard(
          title: 'Kategori',
          value: '$uniqueCategories',
          icon: Icons.category_rounded,
          accent: const Color(0xFFFBBF24),
        ),
      ],
    );
  }

  Widget _buildHeroMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      width: 128,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 17),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSignalPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: const Color(0xFF0F766E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140F766E),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF475569),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(icon: Icon(Icons.approval_outlined), text: 'Satıcı Başvuruları'),
          Tab(icon: Icon(Icons.storefront_outlined), text: 'Tüm Mağazalar'),
          Tab(
            icon: Icon(Icons.edit_location_alt_outlined),
            text: 'Konum Değişim',
          ),
          Tab(
            icon: Icon(Icons.delete_outline_rounded),
            text: 'Silme Talepleri',
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsTab() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: StreamBuilder<List<Map<String, dynamic>>>(
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
            final status = (app['status'] ?? 'pending')
                .toString()
                .toLowerCase();
            final userId = (app['user_id'] ?? '').toString();
            final alreadyStoreOwner =
                userId.isNotEmpty && storeSellerIds.contains(userId);
            return status == 'pending' && !alreadyStoreOwner;
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: _buildSectionHeader(
                  title: 'Bekleyen satıcı başvuruları',
                  subtitle:
                      'Başvuruları önceliklendirin, detayına inin ve aynı panelden onay ya da ret işlemi verin.',
                  action: OutlinedButton.icon(
                    onPressed: _isLoadingStores ? null : _fetchAllStores,
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('Mağazaları Eşle'),
                    style: _secondaryButtonStyle(),
                  ),
                ),
              ),
              Expanded(
                child: applications.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.verified_rounded,
                        title: 'Bekleyen başvuru yok',
                        subtitle:
                            'Yeni satıcı başvurusu geldiğinde burada kart olarak görünecek.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: applications.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) =>
                            _buildApplicationCard(applications[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final businessName = (application['business_name'] ?? 'İsimsiz mağaza')
        .toString();
    final category = (application['category'] ?? 'Kategori belirtilmemiş')
        .toString();
    final userId = (application['user_id'] ?? '').toString();
    final createdAt = _formatDateLabel(application['created_at']);

    return Container(
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
          final infoContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          businessName,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildMetaChip(
                              icon: Icons.sell_outlined,
                              label: category,
                            ),
                            if (userId.isNotEmpty)
                              _buildMetaChip(
                                icon: Icons.person_outline_rounded,
                                label: userId,
                              ),
                            _buildMetaChip(
                              icon: Icons.schedule_rounded,
                              label: createdAt,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildStatusChip(
                    label: 'Bekliyor',
                    background: const Color(0xFFFFF7ED),
                    foreground: const Color(0xFFEA580C),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Başvuru önce detay ekranında doğrulanır, ardından mağaza açılışı onaylanır ya da net gerekçe ile reddedilir.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _showApplicationDetail(application),
                style: _secondaryButtonStyle(),
                child: const Text('Detay Aç'),
              ),
              FilledButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () => _approveApplication(application['id'].toString()),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(_isProcessing ? 'İşleniyor' : 'Onayla'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
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
              OutlinedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () => _markApplicationMissingDocuments(
                        application['id'].toString(),
                      ),
                icon: const Icon(Icons.mail_outline_rounded, size: 18),
                label: const Text('Eksik Belge'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8B5CF6),
                  side: const BorderSide(color: Color(0xFFD8B4FE)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () => _rejectApplication(application['id'].toString()),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Reddet'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFECACA)),
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
              children: [infoContent, const SizedBox(height: 18), actions],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: infoContent),
              const SizedBox(width: 20),
              SizedBox(width: 340, child: actions),
            ],
          );
        },
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
                            image: NetworkImage(store['logo_url'].toString()),
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: _buildSectionHeader(
                  title: 'Mağaza silme akışı',
                  subtitle:
                      'Silme taleplerini gerekçeleriyle birlikte değerlendirin ve kalıcı aksiyonları kontrollü şekilde yönetin.',
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
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: requests.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) =>
                            _buildDeletionCard(requests[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeletionCard(Map<String, dynamic> request) {
    final status = (request['status'] ?? 'pending').toString();
    final isPending = status == 'pending';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Color(0xFFE11D48),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mağaza ID: $sellerId',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildMetaChip(
                          icon: Icons.schedule_outlined,
                          label: _formatDateLabel(request['created_at']),
                        ),
                        if ((request['business_name'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          _buildMetaChip(
                            icon: Icons.store_outlined,
                            label: request['business_name'].toString(),
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
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Talep Gerekçesi',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reason,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isPending) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _adminService.rejectStoreDeletion(
                    request['id'].toString(),
                    'Admin tarafından reddedildi',
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Reddet'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _adminService.approveStoreDeletion(
                    request['id'].toString(),
                    sellerId,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Silmeyi Onayla'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
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
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationChangeRequestsTab() {
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: _buildSectionHeader(
                  title: 'Konum güncelleme talepleri',
                  subtitle:
                      'Mevcut ve talep edilen koordinatları karşılaştırın, konum değişikliğini kontrollü olarak yayına alın.',
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
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: requests.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) =>
                            _buildLocationRequestCard(requests[index]),
                      ),
              ),
            ],
          );
        },
      ),
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

  Widget _buildLocationRequestCard(Map<String, dynamic> request) {
    final status = (request['status'] ?? 'pending').toString();
    final isPending = status == 'pending';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.location_searching_outlined,
                  color: Color(0xFF15803D),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (request['business_name'] ?? 'İsimsiz mağaza').toString(),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildMetaChip(
                          icon: Icons.badge_outlined,
                          label: (request['seller_id'] ?? '-').toString(),
                        ),
                        if (address.isNotEmpty)
                          _buildMetaChip(
                            icon: Icons.map_outlined,
                            label: address,
                          ),
                        _buildMetaChip(
                          icon: Icons.schedule_rounded,
                          label: _formatDateLabel(request['created_at']),
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
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildLocationInfoCard(
                  title: 'Mevcut Konum',
                  value: currentLat != null && currentLng != null
                      ? '${currentLat.toStringAsFixed(5)}, ${currentLng.toStringAsFixed(5)}'
                      : '-',
                  icon: Icons.my_location_rounded,
                  tint: const Color(0xFFE0F2FE),
                  iconColor: const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLocationInfoCard(
                  title: 'Talep Edilen Konum',
                  value: requestedLat != null && requestedLng != null
                      ? '${requestedLat.toStringAsFixed(5)}, ${requestedLng.toStringAsFixed(5)}'
                      : '-',
                  icon: Icons.place_outlined,
                  tint: const Color(0xFFDCFCE7),
                  iconColor: const Color(0xFF15803D),
                ),
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _rejectLocationChangeRequest(request),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Reddet'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Konumu Onayla'),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value.trim().isEmpty ? '-' : value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
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
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 16), action],
      ],
    );
  }

  Widget _buildStatusChip({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildMetaChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label.trim().isEmpty ? '-' : label,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

  ButtonStyle _secondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF0F172A),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      image: NetworkImage(widget.store['logo_url'].toString()),
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
                          image: NetworkImage(product['image_url'].toString()),
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
