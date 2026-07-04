import 'package:flutter/material.dart';

import '../../ads/services/ad_revenue_service.dart';
import '../../features/admin/panel/helpers/admin_panel_density.dart';
import '../../features/admin/panel/widgets/overview_platform_health_sheet.dart';
import '../../services/admin_service.dart';
import '../../utils/order_status_constants.dart';

class GeneralOverviewPage extends StatefulWidget {
  const GeneralOverviewPage({super.key});

  @override
  State<GeneralOverviewPage> createState() => _GeneralOverviewPageState();
}

class _GeneralOverviewPageState extends State<GeneralOverviewPage> {
  final AdminService _adminService = AdminService();

  late Future<_OverviewSnapshot> _snapshotFuture;
  _GrowthPeriod _userGrowthPeriod = _GrowthPeriod.halfYear;
  _GrowthPeriod _storeGrowthPeriod = _GrowthPeriod.halfYear;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  Future<_OverviewSnapshot> _loadSnapshot() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final results = await Future.wait<dynamic>([
      _adminService.getSystemMetrics(),
      _adminService.getUserAnalyticsSnapshot(),
      _adminService.getStoreAnalyticsSnapshot(),
      _adminService.getCargoAnalyticsSnapshot(),
      _adminService.getUserGrowthTimeline(months: _userGrowthPeriod.months),
      _adminService.getStoreParticipationTimeline(
        months: _storeGrowthPeriod.months,
      ),
      _loadAdRevenueTotals(),
      _loadCargoRevenue30d(thirtyDaysAgo),
    ]);

    final adRevenue = results[6] as _RevenueTotals;

    return _OverviewSnapshot(
      system: results[0] as AdminSystemMetrics,
      user: results[1] as AdminUserAnalyticsSnapshot,
      store: results[2] as AdminStoreAnalyticsSnapshot,
      cargo: results[3] as AdminCargoAnalyticsSnapshot,
      userGrowth: results[4] as List<AdminTimelinePoint>,
      storeParticipation: results[5] as List<AdminTimelinePoint>,
      adRevenueTotal: adRevenue.total,
      adRevenueMonth: adRevenue.month,
      cargoRevenue30d: results[7] as double,
      refreshedAt: DateTime.now(),
    );
  }

  Future<_RevenueTotals> _loadAdRevenueTotals() async {
    try {
      final overview = await AdRevenueService().getRevenueOverview();
      return _RevenueTotals(
        total: overview.totalRevenue,
        month: overview.monthRevenue,
      );
    } catch (_) {
      return const _RevenueTotals(total: 0, month: 0);
    }
  }

  Future<double> _loadCargoRevenue30d(DateTime from) async {
    try {
      final orders = await _adminService.getFinanceOrders(from: from);
      return orders
          .where(_countsAsCargoRevenue)
          .fold<double>(0, (sum, order) => sum + order.shippingAmount);
    } catch (_) {
      return 0;
    }
  }

  bool _countsAsCargoRevenue(AdminFinanceOrder order) {
    if (order.shippingAmount <= 0) return false;
    final status = order.status.trim().toLowerCase();
    final isDelivered =
        OrderStatusConstants.isEcommerceTerminal(status) ||
        status == 'teslim edildi';
    final deliveryType = order.deliveryType.trim().toLowerCase();
    final isCourierDelivery =
        deliveryType.contains('courier') || deliveryType.contains('kurye');
    return isDelivered || isCourierDelivery;
  }

  Future<void> _refresh() async {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
    await _snapshotFuture;
  }

  void _updateUserGrowthPeriod(_GrowthPeriod period) {
    if (period == _userGrowthPeriod) return;
    setState(() {
      _userGrowthPeriod = period;
      _snapshotFuture = _loadSnapshot();
    });
  }

  void _updateStoreGrowthPeriod(_GrowthPeriod period) {
    if (period == _storeGrowthPeriod) return;
    setState(() {
      _storeGrowthPeriod = period;
      _snapshotFuture = _loadSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OverviewSnapshot>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.monitor_heart_outlined,
                        size: 56,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Genel bakış yüklenemedi',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const Center(child: Text('Genel bakış verisi bulunamadı.'));
        }

        final attentionItems = _buildAttentionItems(data);
        final activityFeed = _buildActivityFeed(data);

        return LayoutBuilder(
          builder: (context, constraints) {
            final density = AdminPanelDensity.fromWidth(constraints.maxWidth);
            final isWide = density.isWide;
            final isMedium = density.contentWidth >= 900;

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: EdgeInsets.all(density.pagePadding),
                children: [
                  _buildHeroSection(data, density: density),
                  SizedBox(height: density.sectionGap),
                  _buildKpiGrid(data, density: density),
                  SizedBox(height: density.sectionGap),
                  _buildPendingApprovalsStrip(data, density: density),
                  SizedBox(height: density.sectionGap),
                  _buildCriticalAlertsStrip(data, density: density),
                  SizedBox(height: density.sectionGap),
                  _buildGrowthChartsSection(data, density: density),
                  SizedBox(height: density.sectionGap),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            children: [
                              _buildSignalGrid(
                                data,
                                density: density,
                              ),
                              const SizedBox(height: 14),
                              _buildTopStoresCard(data),
                              const SizedBox(height: 14),
                              _buildDistributionSection(
                                data,
                                isMedium: isMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              _buildAttentionCard(attentionItems),
                              const SizedBox(height: 14),
                              _buildNewUsersCard(data, density: density),
                              const SizedBox(height: 14),
                              _buildActivityCard(activityFeed, density: density),
                              const SizedBox(height: 14),
                              _buildCoverageCard(data),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildSignalGrid(data, density: density),
                    const SizedBox(height: 14),
                    _buildAttentionCard(attentionItems),
                    const SizedBox(height: 14),
                    _buildNewUsersCard(data, density: density),
                    const SizedBox(height: 14),
                    _buildActivityCard(activityFeed, density: density),
                    const SizedBox(height: 14),
                    _buildCoverageCard(data),
                    const SizedBox(height: 14),
                    _buildTopStoresCard(data),
                    const SizedBox(height: 14),
                    _buildDistributionSection(data, isMedium: isMedium),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeroSection(_OverviewSnapshot data, {required AdminPanelDensity density}) {
    final healthTone = _healthTone(data.system.systemHealthPercent);
    final gmv30d = data.user.averageOrderValue * data.user.orders30d;
    final headline = _headlineText(data);
    final gauge = _buildHeroGauge(
      data: data,
      percent: data.system.systemHealthPercent,
      coveragePercent: data.system.dataCoveragePercent,
      label: healthTone.label,
      color: healthTone.color,
      density: density,
    );

    return Container(
      padding: density.heroPadding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF0F766E), Color(0xFFF97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(density.heroBorderRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _buildHeroCopy(data, headline, gmv30d, density: density),
          ),
          SizedBox(width: density.isCompact ? 8 : 12),
          SizedBox(
            width: density.isCompact ? 132 : 168,
            child: gauge,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCopy(
    _OverviewSnapshot data,
    String headline,
    double gmv30d, {
    required AdminPanelDensity density,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _alpha(Colors.white, 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_graph_rounded, color: Colors.white, size: 14),
              SizedBox(width: 6),
              Text(
                'İBul yönetim paneli',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          headline,
          maxLines: density.heroSubtitleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: density.heroTitleFontSize,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        SizedBox(height: density.isCompact ? 4 : 6),
        Wrap(
          spacing: density.gridSpacing,
          runSpacing: density.gridSpacing,
          children: [
            _heroPill('Son yenileme', _formatDateTime(data.refreshedAt), density: density),
            _heroPill('30 gün GMV', _formatCurrency(gmv30d), density: density),
            _heroPill(
              'Açık mağaza',
              '%${_formatPercentValue(_safeRatio(data.store.openStores, data.store.totalStores) * 100)}',
              density: density,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroGauge({
    required _OverviewSnapshot data,
    required double percent,
    required double coveragePercent,
    required String label,
    required Color color,
    required AdminPanelDensity density,
  }) {
    final ratio = (percent / 100).clamp(0.0, 1.0);
    final size = density.gaugeSize;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => OverviewPlatformHealthSheet.show(
          context,
          system: data.system,
          user: data.user,
          store: data.store,
          cargo: data.cargo,
        ),
        borderRadius: BorderRadius.circular(density.heroBorderRadius),
        child: Container(
          padding: EdgeInsets.all(density.isCompact ? 8 : 10),
          decoration: BoxDecoration(
            color: _alpha(Colors.white, 0.1),
            borderRadius: BorderRadius.circular(density.heroBorderRadius),
            border: Border.all(color: _alpha(Colors.white, 0.12)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: size,
                      height: size,
                      child: CircularProgressIndicator(
                        value: ratio,
                        strokeWidth: density.gaugeStroke,
                        backgroundColor: _alpha(Colors.white, 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    Text(
                      '${percent.round()}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: density.gaugeValueFontSize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Platform sağlığı',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _alpha(Colors.white, 0.82),
                              fontWeight: FontWeight.w700,
                              fontSize: density.isCompact ? 10 : 11,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.info_outline_rounded,
                          size: density.isCompact ? 12 : 14,
                          color: _alpha(Colors.white, 0.6),
                        ),
                      ],
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _alpha(Colors.white, 0.76),
                        fontSize: density.isCompact ? 9 : 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kapsama %${_formatPercentValue(coveragePercent)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _alpha(Colors.white, 0.7),
                        fontSize: density.isCompact ? 9 : 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiGrid(_OverviewSnapshot data, {required AdminPanelDensity density}) {
    final gmv30d = data.user.averageOrderValue * data.user.orders30d;
    final items = [
      _OverviewMetric(
        title: 'Toplam kullanıcı',
        value: _formatCompact(data.user.totalUsers),
        subtitle: '${data.user.newUsers7d} yeni kullanıcı / 7 gün',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF0F766E),
      ),
      _OverviewMetric(
        title: 'Toplam sipariş',
        value: _formatCompact(data.system.totalOrders),
        subtitle: '${data.system.todayOrders} sipariş bugün',
        icon: Icons.shopping_cart_checkout_rounded,
        color: const Color(0xFF2563EB),
      ),
      _OverviewMetric(
        title: '30 gün GMV',
        value: _formatCurrency(gmv30d),
        subtitle: 'Ort. sepet ${_formatCurrency(data.user.averageOrderValue)}',
        icon: Icons.payments_rounded,
        color: const Color(0xFFF97316),
      ),
      _OverviewMetric(
        title: 'Açık mağaza',
        value: '${data.store.openStores}/${data.store.totalStores}',
        subtitle: '${data.store.newStores30d} yeni mağaza / 30 gün',
        icon: Icons.storefront_rounded,
        color: const Color(0xFF7C3AED),
      ),
      _OverviewMetric(
        title: 'Destek backlog',
        value: _formatCompact(data.system.openSupportTickets),
        subtitle:
            '${data.system.pendingSellerApplications} satıcı başvurusu bekliyor',
        icon: Icons.support_agent_rounded,
        color: const Color(0xFFDC2626),
      ),
      _OverviewMetric(
        title: 'Kargo gecikmesi',
        value: _formatCompact(data.cargo.delayedShipments),
        subtitle:
            '${_formatPercentValue(data.cargo.trackingCoverage * 100)}% takip kapsaması',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF0F172A),
      ),
      _OverviewMetric(
        title: 'Reklam gelirleri',
        value: _formatCurrency(data.adRevenueTotal),
        subtitle: 'Bu ay ${_formatCurrency(data.adRevenueMonth)}',
        icon: Icons.campaign_rounded,
        color: const Color(0xFF16A34A),
      ),
      _OverviewMetric(
        title: 'Kargo gelirleri',
        value: _formatCurrency(data.cargoRevenue30d),
        subtitle: 'Son 30 gün teslimat tahsilatı',
        icon: Icons.local_shipping_outlined,
        color: const Color(0xFF0284C7),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final localDensity =
            AdminPanelDensity.fromWidth(constraints.maxWidth);
        final columns = localDensity.kpiColumns;
        final spacing = localDensity.gridSpacing;
        final itemWidth =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: _buildMetricCard(item, density: localDensity),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildMetricCard(_OverviewMetric item, {required AdminPanelDensity density}) {
    return Container(
      padding: EdgeInsets.all(density.kpiCardPadding),
      constraints: BoxConstraints(
        minHeight: density.kpiMinHeight,
        maxHeight: density.kpiMaxHeight,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(density.kpiIconPadding),
            decoration: BoxDecoration(
              color: _alpha(item.color, 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: item.color, size: density.kpiIconSize),
          ),
          SizedBox(width: density.isCompact ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF6B7280),
                    fontSize: density.kpiTitleFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: density.kpiValueFontSize,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF4B5563),
                    fontSize: density.kpiSubtitleFontSize,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalGrid(_OverviewSnapshot data, {required AdminPanelDensity density}) {
    final signals = [
      _SignalCardData(
        title: '30 gün aktif kullanıcı kapsaması',
        value:
            '%${_formatPercentValue(_safeRatio(data.user.activeUsers30d, data.user.totalUsers) * 100)}',
        subtitle:
            '${data.user.activeUsers30d} aktif kullanıcı, ${data.user.totalUsers} toplam taban',
        progress: _safeRatio(data.user.activeUsers30d, data.user.totalUsers),
        color: const Color(0xFF0F766E),
      ),
      _SignalCardData(
        title: 'Tekrar alışveriş oranı',
        value: '%${_formatPercentValue(data.user.repeatBuyerRate * 100)}',
        subtitle:
            '${data.user.buyers30d} alıcı içinde tekrar gelen kullanıcı oranı',
        progress: data.user.repeatBuyerRate.clamp(0.0, 1.0),
        color: const Color(0xFF2563EB),
      ),
      _SignalCardData(
        title: 'Açık mağaza oranı',
        value:
            '%${_formatPercentValue(_safeRatio(data.store.openStores, data.store.totalStores) * 100)}',
        subtitle:
            '${data.store.lowStockStores} mağazada düşük stok sinyali var',
        progress: _safeRatio(data.store.openStores, data.store.totalStores),
        color: const Color(0xFFF97316),
      ),
      _SignalCardData(
        title: 'Kargo takip kapsaması',
        value: '%${_formatPercentValue(data.cargo.trackingCoverage * 100)}',
        subtitle: '${data.cargo.delayedShipments} gönderi 48 saati aştı',
        progress: data.cargo.trackingCoverage.clamp(0.0, 1.0),
        color: const Color(0xFF7C3AED),
      ),
      _SignalCardData(
        title: 'Veri kapsaması',
        value: '%${_formatPercentValue(data.system.dataCoveragePercent)}',
        subtitle:
            '${_formatCompact(data.system.notificationsToday)} bildirim bugün işlendi',
        progress: (data.system.dataCoveragePercent / 100).clamp(0.0, 1.0),
        color: const Color(0xFF0F172A),
      ),
      _SignalCardData(
        title: 'Stok sağlığı',
        value: '%${_formatPercentValue(_stockHealthRatio(data.system) * 100)}',
        subtitle:
            '${data.system.outOfStockProducts} tükenen, ${data.system.lowStockProducts} düşük stok ürün',
        progress: _stockHealthRatio(data.system),
        color: const Color(0xFFDC2626),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Operasyon Nabzı',
          'Büyüme, kalite ve akış sağlığını tek satırda izle.',
        ),
        SizedBox(height: density.blockGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final localDensity =
                AdminPanelDensity.fromWidth(constraints.maxWidth);
            final columns = localDensity.signalGridColumns;
            final spacing = localDensity.gridSpacing;
            final itemWidth =
                (constraints.maxWidth - (columns - 1) * spacing) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: signals
                  .map(
                    (item) => SizedBox(
                      width: itemWidth,
                      child: _buildSignalCard(item, density: localDensity),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPendingApprovalsStrip(
    _OverviewSnapshot data, {
    required AdminPanelDensity density,
  }) {
    final chips = [
      _PendingSummaryChip(
        label: 'Satıcı başvurusu',
        count: data.system.pendingSellerApplications,
        icon: Icons.approval_rounded,
        color: const Color(0xFF2563EB),
      ),
      _PendingSummaryChip(
        label: 'Destek talebi',
        count: data.system.openSupportTickets,
        icon: Icons.support_agent_rounded,
        color: const Color(0xFFDC2626),
      ),
      _PendingSummaryChip(
        label: 'Geciken kargo',
        count: data.cargo.delayedShipments,
        icon: Icons.local_shipping_outlined,
        color: const Color(0xFF7C3AED),
      ),
      _PendingSummaryChip(
        label: 'Tükenen ürün',
        count: data.system.outOfStockProducts,
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFFF97316),
      ),
    ];

    return _surfaceCard(
      padding: density.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Onay Bekleyenler Özeti',
            'İlk bakışta müdahale gerektiren kuyruk ve backlog sayıları.',
          ),
          SizedBox(height: density.blockGap),
          Wrap(
            spacing: density.gridSpacing,
            runSpacing: density.gridSpacing,
            children: chips
                .map((chip) => _buildPendingChip(chip, density: density))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingChip(
    _PendingSummaryChip chip, {
    required AdminPanelDensity density,
  }) {
    final hasItems = chip.count > 0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: density.isCompact ? 10 : 12,
        vertical: density.isCompact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: _alpha(chip.color, hasItems ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _alpha(chip.color, hasItems ? 0.22 : 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, size: 16, color: chip.color),
          const SizedBox(width: 8),
          Text(
            chip.label,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            hasItems ? '${chip.count}' : '—',
            style: TextStyle(
              color: chip.color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalAlertsStrip(
    _OverviewSnapshot data, {
    required AdminPanelDensity density,
  }) {
    final alerts = data.system.logs
        .where((log) => log.level == 'critical' || log.level == 'warning')
        .take(5)
        .toList(growable: false);

    return _surfaceCard(
      padding: density.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Kritik Uyarılar',
            'Son operasyon loglarından kritik ve uyarı seviyesindeki kayıtlar.',
          ),
          SizedBox(height: density.blockGap),
          if (alerts.isEmpty)
            const Text(
              'Şu an kritik uyarı kaydı yok.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            )
          else
            SizedBox(
              height: density.isCompact ? 120 : 140,
              child: ListView.separated(
                itemCount: alerts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final log = alerts[index];
                  final color = log.level == 'critical'
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFF97316);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Color(0xFF111827),
                              ),
                            ),
                            Text(
                              log.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatRelativeDate(log.occurredAt),
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrowthChartsSection(
    _OverviewSnapshot data, {
    required AdminPanelDensity density,
  }) {
    final userSeries = data.userGrowth;
    final storeSeries = data.storeParticipation;
    final userChart = _buildTrendChartCard(
      title: 'Kullanıcı Artışı',
      subtitle:
          '${_growthPeriodDescription(_userGrowthPeriod)} yeni kullanıcı ve aktif kullanıcı hareketi',
      headlineValue:
          '+${userSeries.fold<int>(0, (sum, item) => sum + item.primaryValue)}',
      headlineNote: 'yeni kullanıcı / ${_userGrowthPeriod.labelLower}',
      primaryLabel: 'Yeni kullanıcı',
      secondaryLabel: 'Aktif kullanıcı',
      primaryColor: const Color(0xFF2563EB),
      secondaryColor: const Color(0xFF0F766E),
      series: userSeries,
      density: density,
      selectedPeriod: _userGrowthPeriod,
      onPeriodSelected: _updateUserGrowthPeriod,
    );
    final storeChart = _buildTrendChartCard(
      title: 'Mağaza Katılımı',
      subtitle:
          '${_growthPeriodDescription(_storeGrowthPeriod)} sisteme katılan ve açık kalan mağazaların dağılımı',
      headlineValue:
          '+${storeSeries.fold<int>(0, (sum, item) => sum + item.primaryValue)}',
      headlineNote: 'katılan mağaza / ${_storeGrowthPeriod.labelLower}',
      primaryLabel: 'Katılan mağaza',
      secondaryLabel: 'Açık mağaza',
      primaryColor: const Color(0xFFF97316),
      secondaryColor: const Color(0xFF7C3AED),
      series: storeSeries,
      density: density,
      selectedPeriod: _storeGrowthPeriod,
      onPeriodSelected: _updateStoreGrowthPeriod,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Büyüme Grafikleri',
          'Kullanıcı kazanımı ile mağaza katılımını aynı ekranda gör.',
        ),
        SizedBox(height: density.blockGap),
        if (density.isWide || density.isMedium)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: userChart),
              SizedBox(width: density.gridSpacing),
              Expanded(child: storeChart),
            ],
          )
        else
          Column(
            children: [
              userChart,
              SizedBox(height: density.gridSpacing),
              storeChart,
            ],
          ),
      ],
    );
  }

  Widget _buildChartPeriodSelector({
    required _GrowthPeriod selected,
    required ValueChanged<_GrowthPeriod> onSelected,
    required AdminPanelDensity density,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _GrowthPeriod.chartOptions.map((period) {
          final isSelected = period == selected;
          return Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelected(period),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: density.isCompact ? 6 : 8,
                    vertical: density.isCompact ? 4 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Text(
                    period.label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF4B5563),
                      fontSize: density.isCompact ? 10 : 11,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrendChartCard({
    required String title,
    required String subtitle,
    required String headlineValue,
    required String headlineNote,
    required String primaryLabel,
    required String secondaryLabel,
    required Color primaryColor,
    required Color secondaryColor,
    required List<AdminTimelinePoint> series,
    required AdminPanelDensity density,
    required _GrowthPeriod selectedPeriod,
    required ValueChanged<_GrowthPeriod> onPeriodSelected,
  }) {
    final maxValue = series.fold<int>(
      1,
      (max, item) => [
        max,
        item.primaryValue,
        item.secondaryValue,
      ].reduce((a, b) => a > b ? a : b),
    );

    return _surfaceCard(
      padding: density.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _sectionHeader(title, subtitle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: _buildChartPeriodSelector(
                  selected: selectedPeriod,
                  onSelected: onPeriodSelected,
                  density: density,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                headlineValue,
                style: TextStyle(
                  color: const Color(0xFF111827),
                  fontSize: density.isCompact ? 18 : 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                headlineNote,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          SizedBox(height: density.blockGap),
          Row(
            children: [
              _legendChip(primaryLabel, primaryColor),
              const SizedBox(width: 8),
              _legendChip(secondaryLabel, secondaryColor),
            ],
          ),
          SizedBox(height: density.blockGap),
          SizedBox(
            height: density.isCompact ? 160 : 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
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
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          painter: _DualLineChartPainter(
                            series: series,
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor,
                            gridColor: const Color(0xFFE5E7EB),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: series
                            .map(
                              (point) => Expanded(
                                child: Text(
                                  point.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 10,
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
        ],
      ),
    );
  }

  Widget _legendChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _alpha(color, 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalCard(_SignalCardData item, {required AdminPanelDensity density}) {
    return Container(
      padding: EdgeInsets.all(density.signalCardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF111827),
              fontWeight: FontWeight.w700,
              fontSize: density.isCompact ? 10 : 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: density.isCompact ? 18 : 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 9,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: item.progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: _alpha(item.color, 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(item.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionCard(List<_AttentionItem> items) {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Dikkat Gerektiren Alanlar',
            'İlk müdahale edilmesi gereken operasyonel başlıklar.',
          ),
          const SizedBox(height: 16),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _alpha(item.color, 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _alpha(item.color, 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _alpha(item.color, 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, color: item.color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              color: Color(0xFF4B5563),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.value,
                      style: TextStyle(
                        color: item.color,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    List<_ActivityItem> items, {
    required AdminPanelDensity density,
  }) {
    final visibleItems = items.take(30).toList(growable: false);
    return _surfaceCard(
      padding: density.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionHeader(
                  'Son Hareket Akışı',
                  'Kullanıcı, sipariş, destek ve kargo gelişmelerini tek listede gör.',
                ),
              ),
              Text(
                '${visibleItems.length} kayıt',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: density.blockGap),
          if (visibleItems.isEmpty)
            const Text(
              'Henüz hareket kaydı yok.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            )
          else
            SizedBox(
              height: density.scrollPanelMaxHeight,
              child: ListView.separated(
                itemCount: visibleItems.length,
                separatorBuilder: (context, index) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final item = visibleItems[index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _alpha(item.color, 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, color: item.color, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Color(0xFF111827),
                              ),
                            ),
                            Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatRelativeDate(item.occurredAt),
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNewUsersCard(
    _OverviewSnapshot data, {
    required AdminPanelDensity density,
  }) {
    final recentUsers = [...data.user.recentUsers]
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    return _surfaceCard(
      padding: density.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _sectionHeader(
                  'Yeni Gelen Kullanıcılar',
                  'Sisteme yeni katılan kullanıcıların ismini ve ilk hareketlerini izle.',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${data.user.newUsers7d} yeni / 7 gün',
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: density.blockGap),
          if (recentUsers.isEmpty)
            const Text(
              'Yeni kullanıcı verisi bulunamadı.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            )
          else
            SizedBox(
              height: density.scrollPanelMaxHeight,
              child: ListView.separated(
                itemCount: recentUsers.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = recentUsers[index];
                  final createdAt = user.createdAt;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFDBEAFE),
                          child: Text(
                            _initialsFor(user.name),
                            style: const TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                user.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              createdAt != null
                                  ? _formatRelativeDate(createdAt)
                                  : 'Tarih yok',
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${user.orderCount30d} sipariş',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoverageCard(_OverviewSnapshot data) {
    final signals = [
      _CoverageSignal(
        label: 'Kullanıcı sinyali',
        isHealthy: data.system.userSignalHealthy,
      ),
      _CoverageSignal(
        label: 'Sipariş sinyali',
        isHealthy: data.system.orderSignalHealthy,
      ),
      _CoverageSignal(
        label: 'Mağaza sinyali',
        isHealthy: data.system.storeSignalHealthy,
      ),
      _CoverageSignal(
        label: 'Destek sinyali',
        isHealthy: data.system.supportSignalHealthy,
      ),
      _CoverageSignal(
        label: 'Bildirim sinyali',
        isHealthy: data.system.notificationSignalHealthy,
      ),
    ];

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'İzleme Kapsaması',
            'Hangi operasyon akışları görünür durumda, hangileri yakından izlenmeli.',
          ),
          const SizedBox(height: 16),
          ...signals.map((signal) {
            final color = signal.isHealthy
                ? const Color(0xFF16A34A)
                : const Color(0xFFDC2626);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      signal.label,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    signal.isHealthy ? 'Aktif' : 'Kontrol et',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (data.system.dataCoveragePercent / 100).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Veri kapsaması ${_formatPercentValue(data.system.dataCoveragePercent)}%. '
            'Bu oran düştüğünde paneldeki sayılar temsil gücünü kaybeder.',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStoresCard(_OverviewSnapshot data) {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Mağaza Liderleri',
            'Son 30 günde hacim üreten mağazaları ve operasyon kalitesini birlikte gör.',
          ),
          const SizedBox(height: 16),
          ...data.store.topStores.asMap().entries.map((entry) {
            final index = entry.key;
            final store = entry.value;
            final medalColor = [
              const Color(0xFFF59E0B),
              const Color(0xFF94A3B8),
              const Color(0xFFB45309),
            ][index < 3 ? index : 2];
            return Container(
              margin: EdgeInsets.only(
                bottom: index == data.store.topStores.length - 1 ? 0 : 14,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _alpha(medalColor, 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: medalColor,
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
                          store.storeName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${store.city} • ${store.category}',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(store.revenue30d),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${store.orderCount30d} sipariş • ${store.productCount} ürün',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        store.isOpen ? 'Açık' : 'Kapalı',
                        style: TextStyle(
                          color: store.isOpen
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDistributionSection(
    _OverviewSnapshot data, {
    required bool isMedium,
  }) {
    final cards = [
      _buildSliceCard(
        'Müşteri Şehirleri',
        'Son 30 gün sipariş yoğunluğu',
        data.user.topCities,
        emptyLabel: 'Şehir verisi yok',
      ),
      _buildSliceCard(
        'Teslimat Tipleri',
        'Kullanıcıların tercih ettiği teslimat akışı',
        data.user.deliveryTypes,
        emptyLabel: 'Teslimat tipi verisi yok',
      ),
      _buildSliceCard(
        'Mağaza Kategorileri',
        'Aktif mağaza evreninin kategori dağılımı',
        data.store.topCategories,
        emptyLabel: 'Kategori verisi yok',
      ),
    ];

    if (isMedium) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 16),
          Expanded(child: cards[1]),
          const SizedBox(width: 16),
          Expanded(child: cards[2]),
        ],
      );
    }

    return Column(
      children: [
        cards[0],
        const SizedBox(height: 16),
        cards[1],
        const SizedBox(height: 16),
        cards[2],
      ],
    );
  }

  Widget _buildSliceCard(
    String title,
    String subtitle,
    List<AdminAnalyticsSlice> slices, {
    required String emptyLabel,
  }) {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(title, subtitle),
          const SizedBox(height: 16),
          if (slices.isEmpty)
            Text(emptyLabel, style: const TextStyle(color: Color(0xFF6B7280)))
          else
            ...slices.map((slice) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            slice.label,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${slice.value}',
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: slice.share.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF0F766E),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _surfaceCard({required Widget child, double padding = 14}) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  List<_AttentionItem> _buildAttentionItems(_OverviewSnapshot data) {
    return [
      _AttentionItem(
        title: 'Açık destek talepleri',
        subtitle: 'Müşteri deneyimini en hızlı etkileyen açık backlog.',
        value: '${data.system.openSupportTickets}',
        icon: Icons.support_agent_rounded,
        color: data.system.openSupportTickets >= 15
            ? const Color(0xFFDC2626)
            : const Color(0xFFF97316),
      ),
      _AttentionItem(
        title: 'Bekleyen satıcı başvuruları',
        subtitle: 'Büyüme hattındaki onboarding gecikmesini gösterir.',
        value: '${data.system.pendingSellerApplications}',
        icon: Icons.approval_rounded,
        color: data.system.pendingSellerApplications >= 10
            ? const Color(0xFFDC2626)
            : const Color(0xFF2563EB),
      ),
      _AttentionItem(
        title: 'Geciken gönderiler',
        subtitle: '48 saati aşan kargo akışı operasyon riskidir.',
        value: '${data.cargo.delayedShipments}',
        icon: Icons.local_shipping_outlined,
        color: data.cargo.delayedShipments >= 10
            ? const Color(0xFFDC2626)
            : const Color(0xFF7C3AED),
      ),
      _AttentionItem(
        title: 'Düşük stok mağazaları',
        subtitle: 'Ürün sürekliliği ve satış kaybı riski taşıyan mağazalar.',
        value: '${data.store.lowStockStores}',
        icon: Icons.inventory_2_outlined,
        color: data.store.lowStockStores >= 12
            ? const Color(0xFFDC2626)
            : const Color(0xFF0F766E),
      ),
      _AttentionItem(
        title: 'Ürünsüz mağazalar',
        subtitle: 'Açık olsa bile katalog üretmeyen mağazalar ivmeyi düşürür.',
        value: '${data.store.storesWithoutProducts}',
        icon: Icons.store_mall_directory_outlined,
        color: const Color(0xFF0F172A),
      ),
    ];
  }

  List<_ActivityItem> _buildActivityFeed(_OverviewSnapshot data) {
    final items = <_ActivityItem>[
      ...data.system.logs.map((log) {
        final color = switch (log.level) {
          'critical' => const Color(0xFFDC2626),
          'warning' => const Color(0xFFF97316),
          _ => const Color(0xFF2563EB),
        };
        return _ActivityItem(
          title: log.title,
          subtitle: log.subtitle,
          occurredAt: log.occurredAt,
          icon: log.subtitle.contains('Destek')
              ? Icons.support_agent_rounded
              : log.subtitle.contains('basvurusu')
              ? Icons.approval_rounded
              : Icons.receipt_long_rounded,
          color: color,
        );
      }),
      ...data.user.recentUsers.take(4).map((user) {
        final activityTime =
            user.lastSeenAt ?? user.createdAt ?? data.refreshedAt;
        return _ActivityItem(
          title: '${user.name} görünür oldu',
          subtitle:
              '${user.orderCount30d} sipariş / 30 gün • ${user.city} • ${user.email}',
          occurredAt: activityTime,
          icon: Icons.person_rounded,
          color: const Color(0xFF0F766E),
        );
      }),
      ...data.cargo.recentShipments.take(4).map((shipment) {
        return _ActivityItem(
          title: '${shipment.storeName} • ${shipment.stateLabel}',
          subtitle:
              '${shipment.cargoCompany} • ${shipment.hasTracking ? "takip numarası var" : "takip numarası yok"}',
          occurredAt: shipment.createdAt ?? data.refreshedAt,
          icon: Icons.local_shipping_rounded,
          color: shipment.hasTracking
              ? const Color(0xFF7C3AED)
              : const Color(0xFFDC2626),
        );
      }),
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return items.take(30).toList(growable: false);
  }

  String _headlineText(_OverviewSnapshot data) {
    final health = data.system.systemHealthPercent;
    if (health >= 85) {
      return 'Platform akışı dengede, büyüme ve operasyon aynı ritimde ilerliyor.';
    }
    if (health >= 70) {
      return 'Genel tablo güçlü, ancak birkaç operasyon başlığı yakın takip istiyor.';
    }
    return 'Operasyon yoğunluğu artmış durumda; destek, stok ve teslimat akışı sıkı izlenmeli.';
  }

  _HealthTone _healthTone(double healthPercent) {
    if (healthPercent >= 85) {
      return const _HealthTone('Stabil', Color(0xFF22C55E));
    }
    if (healthPercent >= 70) {
      return const _HealthTone('İzlemede', Color(0xFFF59E0B));
    }
    return const _HealthTone('Müdahale gerekli', Color(0xFFEF4444));
  }

  double _safeRatio(int value, int total) {
    if (total <= 0) return 0;
    return (value / total).clamp(0.0, 1.0);
  }

  double _stockHealthRatio(AdminSystemMetrics system) {
    if (system.totalProducts <= 0) return 1;
    final penalty = system.outOfStockProducts + (system.lowStockProducts * 0.5);
    return (1 - (penalty / system.totalProducts)).clamp(0.0, 1.0);
  }

  Widget _heroPill(
    String label,
    String value, {
    required AdminPanelDensity density,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: density.isCompact ? 8 : 10,
        vertical: density.isCompact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: _alpha(Colors.white, 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _alpha(Colors.white, 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _alpha(Colors.white, 0.66),
              fontSize: density.isCompact ? 9 : 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: density.isCompact ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    final rounded = value.round();
    final isNegative = rounded < 0;
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final reverseIndex = digits.length - i;
      buffer.write(digits[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    return '${isNegative ? '-₺' : '₺'}$buffer';
  }

  String _formatCompact(int value) {
    final absolute = value.abs();
    final sign = value < 0 ? '-' : '';
    if (absolute >= 1000000) {
      return '$sign${(absolute / 1000000).toStringAsFixed(1)} Mn';
    }
    if (absolute >= 1000) {
      return '$sign${(absolute / 1000).toStringAsFixed(1)} Bin';
    }
    return '$value';
  }

  String _formatPercentValue(double value) =>
      value.toStringAsFixed(value >= 10 ? 0 : 1);

  Color _alpha(Color color, double alpha) => color.withValues(alpha: alpha);

  String _formatDateTime(DateTime value) {
    const months = <String>[
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    final day = value.day.toString().padLeft(2, '0');
    final month = months[value.month - 1];
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }

  String _growthPeriodDescription(_GrowthPeriod period) {
    switch (period) {
      case _GrowthPeriod.days7:
        return 'Son 7 günde (aylık özet)';
      case _GrowthPeriod.days30:
        return 'Son 30 günde (aylık özet)';
      case _GrowthPeriod.quarter:
        return 'Son 3 ayda';
      case _GrowthPeriod.halfYear:
        return 'Son 6 ayda';
      case _GrowthPeriod.year:
        return 'Son 12 ayda';
    }
  }

  String _initialsFor(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return 'YK';
    return parts.map((item) => item.substring(0, 1).toUpperCase()).join();
  }

  String _formatRelativeDate(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) return 'şimdi';
    if (difference.inHours < 1) return '${difference.inMinutes} dk önce';
    if (difference.inDays < 1) return '${difference.inHours} sa önce';
    if (difference.inDays < 7) return '${difference.inDays} gün önce';
    return _formatDateTime(value);
  }
}

class _OverviewSnapshot {
  const _OverviewSnapshot({
    required this.system,
    required this.user,
    required this.store,
    required this.cargo,
    required this.userGrowth,
    required this.storeParticipation,
    required this.adRevenueTotal,
    required this.adRevenueMonth,
    required this.cargoRevenue30d,
    required this.refreshedAt,
  });

  final AdminSystemMetrics system;
  final AdminUserAnalyticsSnapshot user;
  final AdminStoreAnalyticsSnapshot store;
  final AdminCargoAnalyticsSnapshot cargo;
  final List<AdminTimelinePoint> userGrowth;
  final List<AdminTimelinePoint> storeParticipation;
  final double adRevenueTotal;
  final double adRevenueMonth;
  final double cargoRevenue30d;
  final DateTime refreshedAt;
}

class _RevenueTotals {
  const _RevenueTotals({required this.total, required this.month});

  final double total;
  final double month;
}

class _OverviewMetric {
  const _OverviewMetric({
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

class _SignalCardData {
  const _SignalCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.progress,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final double progress;
  final Color color;
}

class _AttentionItem {
  const _AttentionItem({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color color;
}

class _ActivityItem {
  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.occurredAt,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final DateTime occurredAt;
  final IconData icon;
  final Color color;
}

class _CoverageSignal {
  const _CoverageSignal({required this.label, required this.isHealthy});

  final String label;
  final bool isHealthy;
}

class _HealthTone {
  const _HealthTone(this.label, this.color);

  final String label;
  final Color color;
}

enum _GrowthPeriod {
  days7(1, '7 Gün', '7 gün'),
  days30(1, '30 Gün', '30 gün'),
  quarter(3, '3 Ay', '3 ay'),
  halfYear(6, '6 Ay', '6 ay'),
  year(12, '12 Ay', '12 ay');

  const _GrowthPeriod(this.months, this.label, this.labelLower);

  static const List<_GrowthPeriod> chartOptions = [
    days7,
    days30,
    quarter,
    halfYear,
    year,
  ];

  final int months;
  final String label;
  final String labelLower;
}

class _PendingSummaryChip {
  const _PendingSummaryChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;
}

class _DualLineChartPainter extends CustomPainter {
  const _DualLineChartPainter({
    required this.series,
    required this.primaryColor,
    required this.secondaryColor,
    required this.gridColor,
  });

  final List<AdminTimelinePoint> series;
  final Color primaryColor;
  final Color secondaryColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) {
      return;
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final dy = (size.height - 12) * (i / 3);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    final maxValue = series.fold<int>(
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
    final spacing = series.length == 1 ? 0.0 : size.width / (series.length - 1);

    for (var i = 0; i < series.length; i++) {
      final item = series[i];
      final dx = spacing * i;
      final primaryDy =
          availableHeight - (item.primaryValue / maxValue) * availableHeight;
      final secondaryDy =
          availableHeight - (item.secondaryValue / maxValue) * availableHeight;

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

    final primaryPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final secondaryPaint = Paint()
      ..color = secondaryColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawPath(primaryPath, primaryPaint);
    canvas.drawPath(secondaryPath, secondaryPaint);
  }

  @override
  bool shouldRepaint(covariant _DualLineChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.gridColor != gridColor;
  }
}
