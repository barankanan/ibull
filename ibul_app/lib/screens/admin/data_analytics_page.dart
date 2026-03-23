import 'package:flutter/material.dart';

import 'package:ibul_app/services/admin_service.dart';

class DataAnalyticsPage extends StatefulWidget {
  const DataAnalyticsPage({super.key});

  @override
  State<DataAnalyticsPage> createState() => _DataAnalyticsPageState();
}

class _DataAnalyticsPageState extends State<DataAnalyticsPage> {
  final AdminService _adminService = AdminService();

  int _selectedTabIndex = 0;
  bool _isRunningGeneralCleanup = false;
  late Future<AdminUserAnalyticsSnapshot> _userFuture;
  late Future<AdminStoreAnalyticsSnapshot> _storeFuture;
  late Future<AdminCargoAnalyticsSnapshot> _cargoFuture;
  late Future<AdminSystemMetrics> _systemFuture;

  static const List<_AnalyticsTab> _tabs = [
    _AnalyticsTab(
      title: 'Kullanıcılar',
      subtitle: 'Gerçek kullanıcı aktivitesi ve sipariş davranışı',
      icon: Icons.people_alt_rounded,
      startColor: Color(0xFF0F766E),
      endColor: Color(0xFFF59E0B),
    ),
    _AnalyticsTab(
      title: 'Mağazalar',
      subtitle: 'Açık mağazalar, kategori dengesi ve satış ivmesi',
      icon: Icons.storefront_rounded,
      startColor: Color(0xFF1D4ED8),
      endColor: Color(0xFF38BDF8),
    ),
    _AnalyticsTab(
      title: 'Kargo',
      subtitle: 'Teslimat akışı, takip kapsaması ve gecikme riski',
      icon: Icons.local_shipping_rounded,
      startColor: Color(0xFF4F46E5),
      endColor: Color(0xFFFB7185),
    ),
    _AnalyticsTab(
      title: 'Sistem',
      subtitle: 'Veri yoğunluğu, operasyon sağlığı ve ölçek eşikleri',
      icon: Icons.dns_rounded,
      startColor: Color(0xFF111827),
      endColor: Color(0xFF10B981),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  void _reloadAll() {
    _userFuture = _adminService.getUserAnalyticsSnapshot();
    _storeFuture = _adminService.getStoreAnalyticsSnapshot();
    _cargoFuture = _adminService.getCargoAnalyticsSnapshot();
    _systemFuture = _adminService.getSystemMetrics();
  }

  void _refreshCurrentTab() {
    setState(() {
      switch (_selectedTabIndex) {
        case 0:
          _userFuture = _adminService.getUserAnalyticsSnapshot();
          break;
        case 1:
          _storeFuture = _adminService.getStoreAnalyticsSnapshot();
          break;
        case 2:
          _cargoFuture = _adminService.getCargoAnalyticsSnapshot();
          break;
        case 3:
          _systemFuture = _adminService.getSystemMetrics();
          break;
      }
    });
  }

  Future<void> _runGeneralCleanup() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Genel Temizleme'),
          content: const Text(
            'Sipariş, sipariş kalemi, sipariş geçmişi ve bildirim kayıtları temizlenecek.\n\nBu işlem geri alınamaz. Devam edilsin mi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
              ),
              child: const Text('Temizle'),
            ),
          ],
        );
      },
    );

    if (approved != true || !mounted) return;

    setState(() {
      _isRunningGeneralCleanup = true;
    });

    try {
      final result = await _adminService.runGeneralCleanup();
      if (!mounted) return;
      setState(() {
        _reloadAll();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Genel temizleme tamamlandı. '
            'Sipariş: ${result.deletedOrdersCount}, '
            'Kalem: ${result.deletedOrderItemsCount}, '
            'Geçmiş: ${result.deletedOrderItemHistoryCount}, '
            'Bildirim: ${result.deletedNotificationsCount}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Genel temizleme başarısız: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRunningGeneralCleanup = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tab = _tabs[_selectedTabIndex];
        return Column(
          children: [
            _buildHeader(tab),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildCurrentTab(constraints),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(_AnalyticsTab tab) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Veri Merkezi',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tab.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _refreshCurrentTab,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Yenile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF111827),
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(_tabs.length, (index) {
              final item = _tabs[index];
              final selected = index == _selectedTabIndex;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _selectedTabIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? LinearGradient(
                            colors: [item.startColor, item.endColor],
                          )
                        : null,
                    color: selected ? null : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 18,
                        color: selected ? Colors.white : item.startColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        item.title,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF111827),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab(BoxConstraints constraints) {
    switch (_selectedTabIndex) {
      case 0:
        return FutureBuilder<AdminUserAnalyticsSnapshot>(
          future: _userFuture,
          builder: (context, snapshot) {
            return _buildAsyncState(
              snapshot: snapshot,
              builder: (data) => _buildUserView(data, constraints.maxWidth),
            );
          },
        );
      case 1:
        return FutureBuilder<AdminStoreAnalyticsSnapshot>(
          future: _storeFuture,
          builder: (context, snapshot) {
            return _buildAsyncState(
              snapshot: snapshot,
              builder: (data) => _buildStoreView(data, constraints.maxWidth),
            );
          },
        );
      case 2:
        return FutureBuilder<AdminCargoAnalyticsSnapshot>(
          future: _cargoFuture,
          builder: (context, snapshot) {
            return _buildAsyncState(
              snapshot: snapshot,
              builder: (data) => _buildCargoView(data, constraints.maxWidth),
            );
          },
        );
      default:
        return FutureBuilder<AdminSystemMetrics>(
          future: _systemFuture,
          builder: (context, snapshot) {
            return _buildAsyncState(
              snapshot: snapshot,
              builder: (data) => _buildSystemView(data, constraints.maxWidth),
            );
          },
        );
    }
  }

  Widget _buildAsyncState<T>({
    required AsyncSnapshot<T> snapshot,
    required Widget Function(T data) builder,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return _buildLoadingCard();
    }
    if (snapshot.hasError) {
      return _buildErrorCard(snapshot.error);
    }
    final data = snapshot.data;
    if (data == null) {
      return _buildErrorCard('Veri okunamadı.');
    }
    return builder(data);
  }

  Widget _buildUserView(AdminUserAnalyticsSnapshot data, double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(
          title: 'Gerçek kullanıcı akışı',
          subtitle:
              'Kullanıcı, sipariş ve teslimat tercihleri doğrudan canlı tablolardan okunuyor.',
          icon: Icons.people_alt_rounded,
          startColor: _tabs[0].startColor,
          endColor: _tabs[0].endColor,
          badge: '${_compactNumber(data.totalUsers)} kayıtlı kullanıcı',
          bullets: [
            'Son 24 saatte aktif: ${_compactNumber(data.activeUsers24h)}',
            'Son 7 günde yeni kayıt: ${_compactNumber(data.newUsers7d)}',
            '30 gün tekrar satın alma: ${_percent(data.repeatBuyerRate)}',
          ],
        ),
        const SizedBox(height: 20),
        _buildMetricGrid(
          width: width,
          items: [
            _DashboardMetric(
              title: '30 gün aktif',
              value: _compactNumber(data.activeUsers30d),
              subtitle: 'Geri dönüp uygulamayı kullanan hesap',
              icon: Icons.bolt_rounded,
              color: const Color(0xFF0F766E),
            ),
            _DashboardMetric(
              title: '30 gün alıcı',
              value: _compactNumber(data.buyers30d),
              subtitle: 'Sipariş oluşturan benzersiz kullanıcı',
              icon: Icons.shopping_bag_rounded,
              color: const Color(0xFFF59E0B),
            ),
            _DashboardMetric(
              title: '30 gün sipariş',
              value: _compactNumber(data.orders30d),
              subtitle: 'Gerçek sipariş hacmi',
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFF1D4ED8),
            ),
            _DashboardMetric(
              title: 'Ortalama sepet',
              value: _currency(data.averageOrderValue),
              subtitle: '30 günlük ortalama sipariş tutarı',
              icon: Icons.payments_rounded,
              color: const Color(0xFFDC2626),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildUserGrowthCard(data.userGrowth),
        const SizedBox(height: 20),
        _buildSplitSection(
          width: width,
          left: _buildSliceCard(
            title: 'Şehir yoğunluğu',
            subtitle: 'Sipariş adreslerinden çıkan gerçek dağılım',
            icon: Icons.location_city_rounded,
            color: const Color(0xFF0F766E),
            slices: data.topCities,
          ),
          right: _buildSliceCard(
            title: 'Teslimat tercihi',
            subtitle: 'Checkout sırasında seçilen teslimat tipi',
            icon: Icons.delivery_dining_rounded,
            color: const Color(0xFFF59E0B),
            slices: data.deliveryTypes,
          ),
        ),
        const SizedBox(height: 20),
        _buildSplitSection(
          width: width,
          left: _buildSliceCard(
            title: 'Aktivite bandı',
            subtitle: 'Canlı kullanıcıların tazelik seviyesi',
            icon: Icons.timeline_rounded,
            color: const Color(0xFF1D4ED8),
            slices: data.activityBands,
          ),
          right: _buildRecentUsersCard(data.recentUsers),
        ),
      ],
    );
  }

  Widget _buildStoreView(AdminStoreAnalyticsSnapshot data, double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(
          title: 'Mağaza ağı sağlığı',
          subtitle:
              'Mağaza ve ürün tablosundaki canlı yoğunluk, açılış hızı ve satış akışı birlikte okunuyor.',
          icon: Icons.storefront_rounded,
          startColor: _tabs[1].startColor,
          endColor: _tabs[1].endColor,
          badge: '${_compactNumber(data.openStores)} açık mağaza',
          bullets: [
            'Son 30 günde açılan: ${_compactNumber(data.newStores30d)}',
            'Ürünsüz mağaza: ${_compactNumber(data.storesWithoutProducts)}',
            'Düşük stok riski: ${_compactNumber(data.lowStockStores)} mağaza',
          ],
        ),
        const SizedBox(height: 20),
        _buildMetricGrid(
          width: width,
          items: [
            _DashboardMetric(
              title: 'Toplam mağaza',
              value: _compactNumber(data.totalStores),
              subtitle: 'Stores tablosundaki toplam kayıt',
              icon: Icons.apartment_rounded,
              color: const Color(0xFF1D4ED8),
            ),
            _DashboardMetric(
              title: 'Toplam ürün',
              value: _compactNumber(data.totalProducts),
              subtitle: 'Platformda listelenen ürün adedi',
              icon: Icons.inventory_2_rounded,
              color: const Color(0xFF38BDF8),
            ),
            _DashboardMetric(
              title: 'Mağaza başı ürün',
              value: data.averageProductsPerStore.toStringAsFixed(1),
              subtitle: 'Toplam ürün / toplam mağaza',
              icon: Icons.grid_view_rounded,
              color: const Color(0xFFF59E0B),
            ),
            _DashboardMetric(
              title: 'Ortalama puan',
              value: data.averageRating == 0
                  ? '-'
                  : data.averageRating.toStringAsFixed(1),
              subtitle: 'Rating alanı dolu mağazaların ortalaması',
              icon: Icons.star_rounded,
              color: const Color(0xFF0F766E),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSplitSection(
          width: width,
          left: _buildSliceCard(
            title: 'Kategori dengesi',
            subtitle: 'Mağaza sayısına göre ilk kategoriler',
            icon: Icons.category_rounded,
            color: const Color(0xFF1D4ED8),
            slices: data.topCategories,
          ),
          right: _buildSliceCard(
            title: 'Şehir dağılımı',
            subtitle: 'Mağazaların yoğunlaştığı şehirler',
            icon: Icons.map_rounded,
            color: const Color(0xFF38BDF8),
            slices: data.topCities,
          ),
        ),
        const SizedBox(height: 20),
        _buildTopStoresCard(data.topStores),
      ],
    );
  }

  Widget _buildCargoView(AdminCargoAnalyticsSnapshot data, double width) {
    final deliveredRate = data.totalShipments == 0
        ? 0.0
        : data.deliveredShipments / data.totalShipments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(
          title: 'Kargo operasyon görünümü',
          subtitle:
              '${data.windowLabel} içindeki order item hareketlerinden canlı lojistik özeti çıkarılıyor.',
          icon: Icons.local_shipping_rounded,
          startColor: _tabs[2].startColor,
          endColor: _tabs[2].endColor,
          badge: '${_compactNumber(data.totalShipments)} sevkiyat',
          bullets: [
            'Teslim edilen oran: ${_percent(deliveredRate)}',
            'Takip kodu kapsaması: ${_percent(data.trackingCoverage)}',
            '48 saati geçen açık sevkiyat: ${_compactNumber(data.delayedShipments)}',
          ],
        ),
        const SizedBox(height: 20),
        _buildMetricGrid(
          width: width,
          items: [
            _DashboardMetric(
              title: 'Teslim edildi',
              value: _compactNumber(data.deliveredShipments),
              subtitle: 'Durumu kapanmış sevkiyat',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF16A34A),
            ),
            _DashboardMetric(
              title: 'Yolda',
              value: _compactNumber(data.inTransitShipments),
              subtitle: 'Transfer, şube veya dağıtım akışı',
              icon: Icons.route_rounded,
              color: const Color(0xFF2563EB),
            ),
            _DashboardMetric(
              title: 'Hazırlanıyor',
              value: _compactNumber(data.preparingShipments),
              subtitle: 'Satıcı çıkışı bekleyen paket',
              icon: Icons.inventory_rounded,
              color: const Color(0xFFF59E0B),
            ),
            _DashboardMetric(
              title: 'Sorunlu / iade',
              value: _compactNumber(data.problemShipments),
              subtitle: 'İptal veya iade sinyali veren sevkiyat',
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFDC2626),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSplitSection(
          width: width,
          left: _buildSliceCard(
            title: 'Kargo firması dağılımı',
            subtitle: 'Atanan kargo firmalarına göre hacim',
            icon: Icons.local_shipping_outlined,
            color: const Color(0xFF4F46E5),
            slices: data.companyBreakdown,
          ),
          right: _buildSliceCard(
            title: 'Durum dağılımı',
            subtitle: 'Shipment step ve sipariş durumundan türetilen özet',
            icon: Icons.stacked_bar_chart_rounded,
            color: const Color(0xFFFB7185),
            slices: data.statusBreakdown,
          ),
        ),
        const SizedBox(height: 20),
        _buildRecentShipmentsCard(data.recentShipments),
      ],
    );
  }

  Widget _buildSystemView(AdminSystemMetrics data, double width) {
    final projections = _buildCapacityProjections(data);
    final quota = data.supabaseQuota;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(
          title: 'Sistem kapasite resmi',
          subtitle:
              'Bu alan canlı sayımları gösterir; kullanıcı, görsel ve trafik eşikleri ise mevcut yoğunluğa göre tahmini projeksiyondur.',
          icon: Icons.dns_rounded,
          startColor: _tabs[3].startColor,
          endColor: _tabs[3].endColor,
          badge:
              'Veri kapsaması ${data.dataCoveragePercent.toStringAsFixed(0)}%',
          bullets: [
            'Sistem sağlığı: ${data.systemHealthPercent.toStringAsFixed(0)}%',
            'Bugünkü sipariş: ${_compactNumber(data.todayOrders)}',
            'Açık destek yükü: ${_compactNumber(data.openSupportTickets)}',
            'Supabase ${quota.planName.toUpperCase()} • DB ${_percent(quota.databaseUsagePercent)}',
          ],
        ),
        const SizedBox(height: 20),
        _buildMetricGrid(
          width: width,
          items: [
            _DashboardMetric(
              title: 'Kayıtlı kullanıcı',
              value:
                  '${_compactNumber(data.totalUsers)} / ${_compactNumber(quota.usersRecommendedLimit)}',
              subtitle: 'Kullanim / kullanici limiti',
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF7C3AED),
            ),
            _DashboardMetric(
              title: 'Mağaza',
              value:
                  '${_compactNumber(data.totalStores)} / ${_compactNumber(quota.storesRecommendedLimit)}',
              subtitle:
                  'Kullanim / magaza limiti • acik ${_compactNumber(data.openStores)}',
              icon: Icons.store_mall_directory_rounded,
              color: const Color(0xFF0EA5E9),
            ),
            _DashboardMetric(
              title: 'Aktif satıcı',
              value:
                  '${_compactNumber(data.totalSellers)} / ${_compactNumber(quota.sellersRecommendedLimit)}',
              subtitle: 'Kullanim / satici limiti',
              icon: Icons.storefront_rounded,
              color: const Color(0xFF4F46E5),
            ),
            _DashboardMetric(
              title: 'Onaylı iHIZ kurye',
              value:
                  '${_compactNumber(data.approvedIhizCouriers)} / ${_compactNumber(quota.couriersRecommendedLimit)}',
              subtitle: 'Kullanim / kurye limiti',
              icon: Icons.delivery_dining_rounded,
              color: const Color(0xFF16A34A),
            ),
            _DashboardMetric(
              title: 'Veritabanı doluluğu',
              value:
                  '${quota.databaseUsedMb.toStringAsFixed(1)} / ${quota.databaseLimitMb.toStringAsFixed(0)} MB',
              subtitle: 'Canlı ölçüm (pg_database_size)',
              icon: Icons.storage_rounded,
              color: const Color(0xFFF59E0B),
            ),
            _DashboardMetric(
              title: 'Storage doluluğu',
              value:
                  '${quota.storageUsedMb.toStringAsFixed(1)} / ${(quota.storageLimitMb / 1024).toStringAsFixed(1)} GB',
              subtitle: 'storage.objects metadata toplamı',
              icon: Icons.perm_media_rounded,
              color: const Color(0xFF10B981),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSupabaseLimitsCard(data),
        const SizedBox(height: 20),
        _buildSplitSection(
          width: width,
          left: _buildUsageCard(data),
          right: _buildSignalCard(data),
        ),
        const SizedBox(height: 20),
        _buildCapacityCard(projections),
        const SizedBox(height: 20),
        _buildSystemLogsCard(data.logs),
        const SizedBox(height: 20),
        _buildGeneralCleanupCard(),
      ],
    );
  }

  Widget _buildHeroCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color startColor,
    required Color endColor,
    required String badge,
    required List<String> bullets,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [startColor, endColor],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFE5E7EB),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: bullets
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid({
    required double width,
    required List<_DashboardMetric> items,
  }) {
    final cardWidth = width >= 1400
        ? (width - 48) / 4
        : width >= 820
        ? (width - 16) / 2
        : width;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: items
          .map(
            (item) => SizedBox(
              width: cardWidth,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, color: item.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.value,
                            style: const TextStyle(
                              fontSize: 22,
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSplitSection({
    required double width,
    required Widget left,
    required Widget right,
  }) {
    if (width < 1080) {
      return Column(children: [left, const SizedBox(height: 16), right]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }

  Widget _buildSliceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<AdminAnalyticsSlice> slices,
  }) {
    return _buildSurfaceCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      child: slices.isEmpty
          ? const Text(
              'Gösterilecek canlı dağılım verisi yok.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            )
          : Column(
              children: slices.map((slice) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              slice.label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          Text(
                            _compactNumber(slice.value),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _percent(slice.share),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: slice.share,
                          minHeight: 9,
                          backgroundColor: const Color(0xFFF1F5F9),
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildRecentUsersCard(List<AdminRecentUserActivity> users) {
    return _buildSurfaceCard(
      title: 'Yeni gelen kullanıcılar',
      subtitle:
          'Sisteme eklenen kullanıcıların isim, e-posta ve ilk hareketleri',
      icon: Icons.person_search_rounded,
      child: users.isEmpty
          ? const Text(
              'Kullanıcı listesi boş görünüyor.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            )
          : Column(
              children: users.map((user) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF0F766E),
                          child: Text(
                            user.name.isEmpty
                                ? '?'
                                : user.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Kayıt: ${_fullDate(user.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9CA3AF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildMiniChip(
                                    icon: Icons.shopping_bag_outlined,
                                    text: '${user.orderCount30d} sipariş / 30g',
                                  ),
                                  _buildMiniChip(
                                    icon: Icons.location_on_outlined,
                                    text: user.city,
                                  ),
                                  _buildMiniChip(
                                    icon: Icons.schedule_rounded,
                                    text:
                                        'Son hareket ${_relativeDate(user.lastSeenAt)}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildUserGrowthCard(List<AdminTimelinePoint> points) {
    final maxValue = points.fold<int>(
      1,
      (max, item) => [
        max,
        item.primaryValue,
        item.secondaryValue,
      ].reduce((a, b) => a > b ? a : b),
    );

    return _buildSurfaceCard(
      title: 'Kullanıcı grafiği',
      subtitle: 'Son 6 ay yeni kullanıcı ve aktif kullanıcı hareketi',
      icon: Icons.query_stats_rounded,
      child: points.isEmpty
          ? const Text(
              'Grafik verisi bulunamadı.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildStatusPill(
                      label: 'Yeni kullanıcı',
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusPill(
                      label: 'Aktif kullanıcı',
                      color: const Color(0xFF0F766E),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 240,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 34,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(4, (index) {
                            final factor = (3 - index) / 3;
                            final value = (maxValue * factor).round();
                            return Text(
                              '$value',
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: CustomPaint(
                                painter: _UserLineChartPainter(
                                  points: points,
                                  primaryColor: const Color(0xFF2563EB),
                                  secondaryColor: const Color(0xFF0F766E),
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: points
                                  .map(
                                    (point) => Expanded(
                                      child: Text(
                                        point.label,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: points.map((point) {
                    return Text(
                      '${point.label}: ${point.primaryValue} yeni / ${point.secondaryValue} aktif',
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }

  Widget _buildTopStoresCard(List<AdminStorePerformance> stores) {
    return _buildSurfaceCard(
      title: 'Öne çıkan mağazalar',
      subtitle: 'Son 30 günlük sipariş gelirine göre ilk mağazalar',
      icon: Icons.leaderboard_rounded,
      child: stores.isEmpty
          ? const Text(
              'Mağaza performans verisi yok.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            )
          : Column(
              children: stores.map((store) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: store.isOpen
                                ? const Color(0xFFE0F2FE)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            store.isOpen
                                ? Icons.storefront_rounded
                                : Icons.store_mall_directory_outlined,
                            color: store.isOpen
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                store.storeName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${store.city} • ${store.category}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildMiniChip(
                                    icon: Icons.payments_outlined,
                                    text: _currency(store.revenue30d),
                                  ),
                                  _buildMiniChip(
                                    icon: Icons.receipt_outlined,
                                    text: '${store.orderCount30d} sipariş',
                                  ),
                                  _buildMiniChip(
                                    icon: Icons.inventory_outlined,
                                    text: '${store.productCount} ürün',
                                  ),
                                  _buildMiniChip(
                                    icon: Icons.star_outline_rounded,
                                    text: store.rating == 0
                                        ? 'Puan yok'
                                        : store.rating.toStringAsFixed(1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildStatusPill(
                          label: store.isOpen ? 'Açık' : 'Kapalı',
                          color: store.isOpen
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF6B7280),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildRecentShipmentsCard(List<AdminCargoShipment> shipments) {
    return _buildSurfaceCard(
      title: 'Son sevkiyat hareketleri',
      subtitle: 'Order item kayıtlarındaki en güncel akış',
      icon: Icons.route_rounded,
      child: shipments.isEmpty
          ? const Text(
              'Sevkiyat hareketi bulunamadı.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            )
          : Column(
              children: shipments.map((shipment) {
                final color = _shipmentColor(shipment.stateLabel);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.local_shipping_outlined,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shipment.storeName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${shipment.cargoCompany} • ${_fullDate(shipment.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildStatusPill(
                                    label: shipment.stateLabel,
                                    color: color,
                                  ),
                                  _buildMiniChip(
                                    icon: Icons.pin_outlined,
                                    text: shipment.hasTracking
                                        ? shipment.trackingNumber
                                        : 'Takip no yok',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildUsageCard(AdminSystemMetrics data) {
    final quota = data.supabaseQuota;
    return _buildSurfaceCard(
      title: 'Operasyon basıncı',
      subtitle: 'Uygulama içi trafik ve iş yükü göstergeleri',
      icon: Icons.speed_rounded,
      child: Column(
        children: [
          _buildUsageRow(
            label: 'Bugünkü sipariş akışı',
            value: '${_compactNumber(data.todayOrders)} / gün',
            ratio: (data.todayOrders / 2000).clamp(0.0, 1.0),
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(height: 16),
          _buildUsageRow(
            label: 'Açık destek ve başvuru yükü',
            value:
                '${_compactNumber(data.openSupportTickets + data.pendingSellerApplications + data.pendingStoreDeletionRequests)} kayıt',
            ratio:
                ((data.openSupportTickets +
                            data.pendingSellerApplications +
                            data.pendingStoreDeletionRequests) /
                        500)
                    .clamp(0.0, 1.0)
                    .toDouble(),
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 16),
          _buildUsageRow(
            label: 'Realtime mesaj basıncı (tahmini)',
            value:
                '${_compactNumber(quota.realtimeMonthlyMessagesUsed)} / ${_compactNumber(quota.realtimeMonthlyMessagesLimit)}',
            ratio: quota.realtimeMessagesUsagePercent,
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 16),
          _buildUsageRow(
            label: 'Edge function çağrı basıncı (tahmini)',
            value:
                '${_compactNumber(quota.edgeMonthlyInvocationsUsed)} / ${_compactNumber(quota.edgeMonthlyInvocationsLimit)}',
            ratio: quota.edgeInvocationsUsagePercent,
            color: const Color(0xFF0EA5E9),
          ),
        ],
      ),
    );
  }

  Widget _buildSupabaseLimitsCard(AdminSystemMetrics data) {
    final quota = data.supabaseQuota;
    final fetchedAtText = _fullDate(quota.fetchedAt);
    return _buildSurfaceCard(
      title: 'Supabase kota ve doluluk',
      subtitle:
          'Canlı backend verisi. Egress/realtime/edge değerleri kullanım modeline göre tahmindir.',
      icon: Icons.cloud_done_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMiniChip(
                icon: Icons.workspace_premium_outlined,
                text: 'Plan: ${quota.planName.toUpperCase()}',
              ),
              _buildMiniChip(
                icon: Icons.schedule_rounded,
                text: 'Guncellendi: $fetchedAtText',
              ),
              _buildMiniChip(
                icon: Icons.network_check_rounded,
                text:
                    'Realtime esit baglanti limiti: ${quota.realtimeConcurrentConnectionsLimit}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildUsageRow(
            label: 'Veritabani',
            value:
                '${quota.databaseUsedMb.toStringAsFixed(1)} / ${quota.databaseLimitMb.toStringAsFixed(0)} MB',
            ratio: quota.databaseUsagePercent,
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 16),
          _buildUsageRow(
            label: 'Storage',
            value:
                '${quota.storageUsedMb.toStringAsFixed(1)} / ${(quota.storageLimitMb / 1024).toStringAsFixed(1)} GB',
            ratio: quota.storageUsagePercent,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 16),
          _buildUsageRow(
            label: 'Aylik aktif kullanici (MAU)',
            value:
                '${_compactNumber(quota.monthlyActiveUsersUsed)} / ${_compactNumber(quota.monthlyActiveUsersLimit)}',
            ratio: quota.mauUsagePercent,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(height: 16),
          _buildUsageRow(
            label:
                'Aylik egress ${quota.trafficIsEstimated ? "(tahmini)" : ""}',
            value:
                '${quota.monthlyEgressUsedGb.toStringAsFixed(2)} / ${quota.monthlyEgressLimitGb.toStringAsFixed(1)} GB',
            ratio: quota.egressUsagePercent,
            color: const Color(0xFFDC2626),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalCard(AdminSystemMetrics data) {
    return _buildSurfaceCard(
      title: 'Veri sinyalleri',
      subtitle: 'Admin panelinin beslendiği operasyon kaynakları',
      icon: Icons.monitor_heart_rounded,
      child: Column(
        children: [
          _buildSignalRow('Kullanıcı verisi', data.userSignalHealthy),
          _buildSignalRow('Sipariş verisi', data.orderSignalHealthy),
          _buildSignalRow('Mağaza verisi', data.storeSignalHealthy),
          _buildSignalRow('Destek verisi', data.supportSignalHealthy),
          _buildSignalRow('Bildirim verisi', data.notificationSignalHealthy),
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
                  'Açık operasyon özeti',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${data.openSupportTickets} açık destek kaydı, ${data.pendingSellerApplications} bekleyen satıcı başvurusu ve ${data.pendingStoreDeletionRequests} mağaza kapatma talebi var.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityCard(List<_CapacityProjection> projections) {
    return _buildSurfaceCard(
      title: 'Tahmini ölçek eşikleri',
      subtitle:
          'Bu bölüm Supabase FREE plan limitlerine göre hesaplanan erken uyarı eşiğidir.',
      icon: Icons.auto_graph_rounded,
      child: Column(
        children: projections.map((projection) {
          final riskRatio = projection.current / projection.riskThreshold;
          final color = riskRatio >= 0.9
              ? const Color(0xFFDC2626)
              : riskRatio >= 0.7
              ? const Color(0xFFF59E0B)
              : const Color(0xFF16A34A);
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
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
                      Expanded(
                        child: Text(
                          projection.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      _buildStatusPill(
                        label: 'Şimdi ${projection.currentLabel}',
                        color: color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${projection.safeLabel} civarı rahat alan, ${projection.riskLabel} civarı ise ölçekleme veya optimizasyon gerektiren bölge.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4B5563),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: riskRatio.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: const Color(0xFFE5E7EB),
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSystemLogsCard(List<AdminSystemLogEntry> logs) {
    return _buildSurfaceCard(
      title: 'Son sistem olayları',
      subtitle: 'Sipariş, destek ve başvuru akışından türetilen olay listesi',
      icon: Icons.history_rounded,
      child: logs.isEmpty
          ? const Text(
              'Henüz olay kaydı görünmüyor.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            )
          : Column(
              children: logs.map((log) {
                final color = _logColor(log.level);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.info_outline_rounded, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                log.subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildStatusPill(
                              label: _logLabel(log.level),
                              color: color,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _fullDate(log.occurredAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildGeneralCleanupCard() {
    return _buildSurfaceCard(
      title: 'Genel Temizleme',
      subtitle: 'Deneme verilerini hızlıca sıfırla',
      icon: Icons.cleaning_services_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFCD9BD)),
            ),
            child: const Text(
              'Bu işlem test siparişlerini ve siparişe bağlı geçmiş/bildirim kayıtlarını topluca siler. Geri alma yoktur.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: Color(0xFF9A3412),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isRunningGeneralCleanup ? null : _runGeneralCleanup,
              icon: _isRunningGeneralCleanup
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.delete_sweep_rounded),
              label: Text(
                _isRunningGeneralCleanup
                    ? 'Temizleniyor...'
                    : 'Genel Temizleme',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurfaceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF111827), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildUsageRow({
    required String label,
    required String value,
    required double ratio,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: const Color(0xFFE5E7EB),
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSignalRow(String title, bool healthy) {
    final color = healthy ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final label = healthy ? 'Online' : 'Sorun var';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }

  Widget _buildErrorCard(Object? error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Veri yüklenemedi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7F1D1D),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  List<_CapacityProjection> _buildCapacityProjections(AdminSystemMetrics data) {
    final quota = data.supabaseQuota;
    final dbSafe = (quota.databaseLimitMb * 0.7).toStringAsFixed(0);
    final dbRisk = (quota.databaseLimitMb * 0.9).toStringAsFixed(0);
    final storageSafe = (quota.storageLimitMb * 0.7 / 1024).toStringAsFixed(1);
    final storageRisk = (quota.storageLimitMb * 0.9 / 1024).toStringAsFixed(1);
    final mauSafe = (quota.monthlyActiveUsersLimit * 0.7).round();
    final mauRisk = (quota.monthlyActiveUsersLimit * 0.9).round();
    final egressSafe = (quota.monthlyEgressLimitGb * 0.7).toStringAsFixed(1);
    final egressRisk = (quota.monthlyEgressLimitGb * 0.9).toStringAsFixed(1);

    return [
      _CapacityProjection(
        title: 'MAU eşiği',
        current: quota.monthlyActiveUsersUsed.toDouble(),
        riskThreshold: quota.monthlyActiveUsersLimit.toDouble(),
        currentLabel: _compactNumber(quota.monthlyActiveUsersUsed),
        safeLabel: '${_compactNumber(mauSafe)} (%70)',
        riskLabel: '${_compactNumber(mauRisk)} (%90)',
      ),
      _CapacityProjection(
        title: 'Veritabani eşiği',
        current: quota.databaseUsedMb,
        riskThreshold: quota.databaseLimitMb,
        currentLabel: '${quota.databaseUsedMb.toStringAsFixed(1)} MB',
        safeLabel: '$dbSafe MB',
        riskLabel: '$dbRisk MB',
      ),
      _CapacityProjection(
        title: 'Storage eşiği',
        current: quota.storageUsedMb / 1024,
        riskThreshold: quota.storageLimitMb / 1024,
        currentLabel: '${(quota.storageUsedMb / 1024).toStringAsFixed(2)} GB',
        safeLabel: '$storageSafe GB',
        riskLabel: '$storageRisk GB',
      ),
      _CapacityProjection(
        title: 'Egress eşiği (tahmini)',
        current: quota.monthlyEgressUsedGb,
        riskThreshold: quota.monthlyEgressLimitGb,
        currentLabel: '${quota.monthlyEgressUsedGb.toStringAsFixed(2)} GB',
        safeLabel: '$egressSafe GB',
        riskLabel: '$egressRisk GB',
      ),
    ];
  }

  String _compactNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)} Mn';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)} B';
    }
    return '$value';
  }

  String _currency(double value) {
    if (value <= 0) return '₺0';
    if (value >= 1000000) {
      return '₺${(value / 1000000).toStringAsFixed(1)} Mn';
    }
    if (value >= 1000) {
      return '₺${(value / 1000).toStringAsFixed(1)} B';
    }
    return '₺${value.toStringAsFixed(0)}';
  }

  String _percent(double ratio) {
    return '%${(ratio * 100).toStringAsFixed(ratio * 100 >= 10 ? 0 : 1)}';
  }

  String _relativeDate(DateTime? value) {
    if (value == null) return 'Tarih yok';
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 1) return 'Az önce';
    if (difference.inHours < 1) return '${difference.inMinutes} dk önce';
    if (difference.inDays < 1) return '${difference.inHours} sa önce';
    return '${difference.inDays} gün önce';
  }

  String _fullDate(DateTime? value) {
    if (value == null) return 'Tarih yok';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  Color _shipmentColor(String stateLabel) {
    switch (stateLabel) {
      case 'Teslim edildi':
        return const Color(0xFF16A34A);
      case 'Yolda':
      case 'Dagitimda':
        return const Color(0xFF2563EB);
      case 'Hazirlaniyor':
      case 'Hazirlandi':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFDC2626);
    }
  }

  Color _logColor(String level) {
    switch (level) {
      case 'critical':
        return const Color(0xFFDC2626);
      case 'warning':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF2563EB);
    }
  }

  String _logLabel(String level) {
    switch (level) {
      case 'critical':
        return 'Kritik';
      case 'warning':
        return 'Uyarı';
      default:
        return 'Bilgi';
    }
  }
}

class _AnalyticsTab {
  const _AnalyticsTab({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.startColor,
    required this.endColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color startColor;
  final Color endColor;
}

class _DashboardMetric {
  const _DashboardMetric({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _CapacityProjection {
  const _CapacityProjection({
    required this.title,
    required this.current,
    required this.riskThreshold,
    required this.currentLabel,
    required this.safeLabel,
    required this.riskLabel,
  });

  final String title;
  final double current;
  final double riskThreshold;
  final String currentLabel;
  final String safeLabel;
  final String riskLabel;
}

class _UserLineChartPainter extends CustomPainter {
  const _UserLineChartPainter({
    required this.points,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final List<AdminTimelinePoint> points;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final dy = (size.height - 12) * (i / 3);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    final maxValue = points.fold<int>(
      1,
      (max, item) => [
        max,
        item.primaryValue,
        item.secondaryValue,
      ].reduce((a, b) => a > b ? a : b),
    );
    final primaryPath = Path();
    final secondaryPath = Path();
    final availableHeight = size.height - 18;
    final spacing = points.length == 1 ? 0.0 : size.width / (points.length - 1);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final dx = spacing * i;
      final primaryDy =
          availableHeight - (point.primaryValue / maxValue) * availableHeight;
      final secondaryDy =
          availableHeight - (point.secondaryValue / maxValue) * availableHeight;

      if (i == 0) {
        primaryPath.moveTo(dx, primaryDy);
        secondaryPath.moveTo(dx, secondaryDy);
      } else {
        primaryPath.lineTo(dx, primaryDy);
        secondaryPath.lineTo(dx, secondaryDy);
      }

      canvas.drawCircle(
        Offset(dx, primaryDy),
        3.5,
        Paint()..color = primaryColor,
      );
      canvas.drawCircle(
        Offset(dx, secondaryDy),
        3.5,
        Paint()..color = secondaryColor,
      );
    }

    canvas.drawPath(
      primaryPath,
      Paint()
        ..color = primaryColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      secondaryPath,
      Paint()
        ..color = secondaryColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _UserLineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
