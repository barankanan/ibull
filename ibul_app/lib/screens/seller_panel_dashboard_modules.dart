part of 'seller_panel_page.dart';

extension _SellerPanelDashboardModules on _SellerPanelPageState {
  Widget _buildMobileDashboardModuleImpl() {
    final metrics = _dashboardMetrics;
    final statusCounts = _dashboardStatusCounts();
    final topProducts = _dashboardTopProducts();
    final pendingTasks = _dashboardPendingTasks(metrics, statusCounts);
    final isFoodBusiness = _isFoodStoreCategory(_storeCategory);
    final totalOrderCount = _combinedDashboardOrders.length;
    final deliveredCount = statusCounts['delivered'] ?? 0;
    final completionRate = totalOrderCount == 0
        ? 0.0
        : (deliveredCount / totalOrderCount) * 100;
    return RefreshIndicator(
      onRefresh: () => _refreshDashboardData(
        source: 'mobile_dashboard_pull_to_refresh',
        userInitiated: true,
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 8),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          _buildMobileDashboardHero(metrics),
          const SizedBox(height: 14),
          _buildMobileSectionTitle(
            'Canlı KPI Kartları',
            icon: Icons.dashboard_rounded,
          ),
          const SizedBox(height: 8),
          _buildMobileDashboardTopCards(metrics),
          const SizedBox(height: 12),
          _buildMobileSectionTitle('Gelir Ve Sipariş', icon: Icons.show_chart),
          const SizedBox(height: 8),
          _buildMobileDashboardChartCard(metrics),
          const SizedBox(height: 12),
          _buildMobileSectionTitle(
            'Son Siparişler',
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 8),
          _buildMobileDashboardRecentOrdersCard(metrics),
          const SizedBox(height: 12),
          _buildMobileSectionTitle(
            'En Çok Satanlar',
            icon: Icons.whatshot_rounded,
          ),
          const SizedBox(height: 8),
          _buildMobileDashboardTopProductsCard(topProducts),
          const SizedBox(height: 12),
          _buildMobileSectionTitle(
            'Performans',
            icon: Icons.auto_graph_rounded,
          ),
          const SizedBox(height: 8),
          _buildMobileDashboardPerformanceCard(
            metrics: metrics,
            statusCounts: statusCounts,
            totalOrderCount: totalOrderCount,
            completionRate: completionRate,
          ),
          const SizedBox(height: 12),
          _mobileSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMobileSectionTitle(
                  isFoodBusiness ? 'Masa & Sipariş Durumu' : 'Sipariş Durumu',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: isFoodBusiness
                      ? [
                          _mobileBadge(
                            'Açık Masa',
                            '${statusCounts['open_tables'] ?? 0}',
                          ),
                          _mobileBadge(
                            'Mutfakta',
                            '${statusCounts['sent_to_kitchen'] ?? 0}',
                          ),
                          _mobileBadge(
                            'Bugün Kapanan',
                            '${statusCounts['closed_today'] ?? 0}',
                          ),
                          _mobileBadge(
                            'İptal',
                            '${statusCounts['restaurant_cancelled'] ?? 0}',
                          ),
                          _mobileBadge(
                            'Online Yeni',
                            '${statusCounts['new'] ?? 0}',
                          ),
                        ]
                      : [
                          _mobileBadge('Yeni', '${statusCounts['new'] ?? 0}'),
                          _mobileBadge(
                            'Hazırlanıyor',
                            '${statusCounts['preparing'] ?? 0}',
                          ),
                          _mobileBadge(
                            'Kargoya Hazır',
                            '${statusCounts['ready_to_ship'] ?? 0}',
                          ),
                          _mobileBadge(
                            'Kargoda',
                            '${statusCounts['shipped'] ?? 0}',
                          ),
                          _mobileBadge(
                            'Tamamlandı',
                            '${statusCounts['delivered'] ?? 0}',
                          ),
                          _mobileBadge(
                            'İade',
                            '${statusCounts['returns'] ?? 0}',
                          ),
                        ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _mobileSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMobileSectionTitle('Bekleyen İşler'),
                const SizedBox(height: 8),
                ...pendingTasks.map((task) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: task['onTap'] as VoidCallback?,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: task['background'] as Color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              task['icon'] as IconData,
                              color: task['accent'] as Color,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                task['title']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              task['actionLabel']?.toString() ?? 'Aç',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: task['accent'] as Color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildDashboardImpl() {
    final dashboardSnapshot = _dashboardSnapshot;
    final metrics = dashboardSnapshot.metrics;
    final statusCounts = dashboardSnapshot.statusCounts;
    final weeklyStats = dashboardSnapshot.weeklyStats;
    final monthlyStats = dashboardSnapshot.monthlyStats;
    final totalOrderCount = dashboardSnapshot.totalOrderCount;
    final completionRate = dashboardSnapshot.completionRate;
    final topProducts = dashboardSnapshot.topProducts;
    final cargoSummary = dashboardSnapshot.cargoSummary;
    final pendingTasks = dashboardSnapshot.pendingTasks;
    final averageOrderChange = dashboardSnapshot.averageOrderChange;
    final today = DateTime.now();
    final isFoodBusiness = _isFoodStoreCategory(_storeCategory);

    // ── Operation cards: restaurant vs e-commerce ─────────────────────────
    final List<Map<String, dynamic>> operationCards;
    if (isFoodBusiness) {
      operationCards = [
        {
          'icon': Icons.trending_up_rounded,
          'iconColor': const Color(0xFF2563EB),
          'iconBackground': const Color(0xFFE8F0FF),
          'title': 'Bugünkü Ciro',
          'value': _formatDashboardCurrency(metrics.todayRevenue),
          'subtitle': '${statusCounts['today_table_orders'] ?? 0} garson sip.',
          'trend': _formatChangeLabel(metrics.todayRevenueChangePercent),
          'trendColor': metrics.todayRevenueChangePercent >= 0
              ? const Color(0xFF16A34A)
              : const Color(0xFFEF4444),
        },
        {
          'icon': Icons.table_restaurant_outlined,
          'iconColor': const Color(0xFF16A34A),
          'iconBackground': const Color(0xFFDCFCE7),
          'title': 'Açık Masa',
          'value': '${statusCounts['open_tables'] ?? 0}',
          'subtitle': 'Aktif servis',
          'trend': '+${statusCounts['today_table_orders'] ?? 0} bugün',
          'trendColor': const Color(0xFF16A34A),
        },
        {
          'icon': Icons.receipt_long_outlined,
          'iconColor': const Color(0xFFF59E0B),
          'iconBackground': const Color(0xFFFFF4DB),
          'title': 'Garson Siparişi',
          'value': '${statusCounts['today_table_orders'] ?? 0}',
          'subtitle': 'Bugün',
          'trend': '+${statusCounts['today_table_orders'] ?? 0}',
          'trendColor': const Color(0xFF16A34A),
        },
        {
          'icon': Icons.soup_kitchen_outlined,
          'iconColor': const Color(0xFF7C3AED),
          'iconBackground': const Color(0xFFF1E8FF),
          'title': 'Mutfağa İletilen',
          'value': '${statusCounts['sent_to_kitchen'] ?? 0}',
          'subtitle': 'Hazırlanıyor',
          'trend': '+${statusCounts['sent_to_kitchen'] ?? 0}',
          'trendColor': const Color(0xFF16A34A),
        },
        {
          'icon': Icons.check_circle_outline_rounded,
          'iconColor': const Color(0xFF10B981),
          'iconBackground': const Color(0xFFDCFCE7),
          'title': 'Bugün Kapanan',
          'value': '${statusCounts['closed_today'] ?? 0}',
          'subtitle': 'Tamamlandı',
          'trend': '+${statusCounts['closed_today'] ?? 0}',
          'trendColor': const Color(0xFF16A34A),
        },
        {
          'icon': Icons.replay_circle_filled_outlined,
          'iconColor': const Color(0xFFEF4444),
          'iconBackground': const Color(0xFFFFE5E5),
          'title': 'İptal / İade',
          'value': '${statusCounts['restaurant_cancelled'] ?? 0}',
          'subtitle': 'İnceleniyor',
          'trend': '-${statusCounts['restaurant_cancelled'] ?? 0}',
          'trendColor': const Color(0xFFEF4444),
        },
      ];
    } else {
      operationCards = [
        {
          'icon': Icons.notifications_active_outlined,
          'iconColor': const Color(0xFF2563EB),
          'iconBackground': const Color(0xFFE8F0FF),
          'title': 'Yeni Sipariş',
          'value': '${statusCounts['new'] ?? 0}',
          'subtitle': 'Aksiyon gerekli',
          'trend':
              '+${_dashboardTodayStatusCount(const ['new', 'confirmed'])}',
          'trendColor': const Color(0xFF16A34A),
        },
        {
          'icon': Icons.schedule_outlined,
          'iconColor': const Color(0xFFF59E0B),
          'iconBackground': const Color(0xFFFFF4DB),
          'title': 'Hazırlanıyor',
          'value': '${statusCounts['preparing'] ?? 0}',
          'subtitle': 'Devam ediyor',
          'trend':
              '+${_dashboardTodayStatusCount(const ['preparing', 'ready_to_ship'])}',
          'trendColor': const Color(0xFF16A34A),
        },
        {
          'icon': Icons.inventory_2_outlined,
          'iconColor': const Color(0xFF22C55E),
          'iconBackground': const Color(0xFFDCFCE7),
          'title': 'Kargoya Hazır',
          'value': '${statusCounts['ready_to_ship'] ?? 0}',
          'subtitle': 'Gönderilmeli',
          'trend': '${metrics.lowStockProducts} risk',
          'trendColor': const Color(0xFF16A34A),
        },
        {
          'icon': Icons.local_shipping_outlined,
          'iconColor': const Color(0xFF7C3AED),
          'iconBackground': const Color(0xFFF1E8FF),
          'title': 'Kargoda',
          'value': '${statusCounts['shipped'] ?? 0}',
          'subtitle': 'Takipte',
          'trend':
              '+${_dashboardTodayStatusCount(const ['shipped', 'transfer', 'branch', 'out_for_delivery'])}',
          'trendColor': const Color(0xFF16A34A),
        },
        {
          'icon': Icons.verified_outlined,
          'iconColor': const Color(0xFF10B981),
          'iconBackground': const Color(0xFFDCFCE7),
          'title': 'Bugün Teslim',
          'value': '${_dashboardTodayStatusCount(const ['delivered'])}',
          'subtitle': 'Tamamlandı',
          'trend':
              '+${math.max(0, _dashboardTodayStatusCount(const ['delivered']) - 1)}',
          'trendColor': const Color(0xFF16A34A),
        },
        {
          'icon': Icons.replay_circle_filled_outlined,
          'iconColor': const Color(0xFFEF4444),
          'iconBackground': const Color(0xFFFFE5E5),
          'title': 'İade / İptal',
          'value': '${statusCounts['returns'] ?? 0}',
          'subtitle': 'İnceleniyor',
          'trend': '-${statusCounts['returns'] ?? 0}',
          'trendColor': const Color(0xFFEF4444),
        },
      ];
    }
    final revenueCards = [
      {
        'icon': Icons.trending_up_rounded,
        'iconColor': const Color(0xFF4F46E5),
        'iconBackground': const Color(0xFFE8EBFF),
        'title': 'Bugünkü Gelir',
        'value': _formatDashboardCurrency(metrics.todayRevenue),
        'subtitle': '${_dashboardTodayOrderCount()} sipariş',
        'trend': _formatChangeLabel(metrics.todayRevenueChangePercent),
        'trendColor': metrics.todayRevenueChangePercent >= 0
            ? const Color(0xFF16A34A)
            : const Color(0xFFEF4444),
      },
      {
        'icon': Icons.bar_chart_rounded,
        'iconColor': const Color(0xFF6366F1),
        'iconBackground': const Color(0xFFE9EAFE),
        'title': 'Bu Haftaki Gelir',
        'value': _formatDashboardCurrency(weeklyStats.$1),
        'subtitle': '${weeklyStats.$2} sipariş',
        'trend': _formatChangeLabel(weeklyStats.$3),
        'trendColor': weeklyStats.$3 >= 0
            ? const Color(0xFF16A34A)
            : const Color(0xFFEF4444),
      },
      {
        'icon': Icons.workspace_premium_outlined,
        'iconColor': const Color(0xFF4F46E5),
        'iconBackground': const Color(0xFFEDE9FE),
        'title': 'Bu Ayki Gelir',
        'value': _formatDashboardCurrency(metrics.monthRevenue),
        'subtitle': '${monthlyStats.$2} sipariş',
        'trend': _formatChangeLabel(metrics.monthRevenueChangePercent),
        'trendColor': metrics.monthRevenueChangePercent >= 0
            ? const Color(0xFF16A34A)
            : const Color(0xFFEF4444),
      },
      {
        'icon': Icons.receipt_long_outlined,
        'iconColor': const Color(0xFF4F46E5),
        'iconBackground': const Color(0xFFE8EBFF),
        'title': 'Ort. Sipariş',
        'value': _formatDashboardCurrency(metrics.averageOrderValue),
        'subtitle': 'Sepet değeri',
        'trend': _formatChangeLabel(averageOrderChange),
        'trendColor': averageOrderChange >= 0
            ? const Color(0xFF16A34A)
            : const Color(0xFFEF4444),
      },
    ];

    return SingleChildScrollView(
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
                    Text(
                      _formatDashboardLongDate(today),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Genel Bakış',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _refreshDashboardData(
                  source: 'desktop_dashboard_yenile_button',
                  userInitiated: true,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Yenile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade200),
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildDashboardSectionLabel('OPERASYON DURUMU'),
          const SizedBox(height: 10),
          _buildDashboardGrid(
            operationCards
                .map((card) => _buildOverviewStatusCard(card))
                .toList(growable: false),
            minItemWidth: 190,
          ),
          const SizedBox(height: 18),
          _buildDashboardSectionLabel('GELİR ÖZETİ'),
          const SizedBox(height: 10),
          _buildDashboardGrid(
            revenueCards
                .map((card) => _buildOverviewRevenueCard(card))
                .toList(growable: false),
            minItemWidth: 250,
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildOverviewCardShell(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Gelir & Sipariş Grafiği',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDashboardRangeCaption(
                                      metrics.rangeStart,
                                      metrics.rangeEnd,
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _buildDashboardRangeChip(
                                  label: '7 Gün',
                                  selected:
                                      _dashboardRangePreset ==
                                      SellerDashboardRangePreset.last7Days,
                                  onTap: () => _setDashboardRangePreset(
                                    SellerDashboardRangePreset.last7Days,
                                  ),
                                ),
                                _buildDashboardRangeChip(
                                  label: '30 Gün',
                                  selected:
                                      _dashboardRangePreset ==
                                      SellerDashboardRangePreset.last30Days,
                                  onTap: () => _setDashboardRangePreset(
                                    SellerDashboardRangePreset.last30Days,
                                  ),
                                ),
                                _buildDashboardRangeChip(
                                  label: '3 Ay',
                                  selected: _isDashboardRollingRangeSelected(
                                    90,
                                  ),
                                  onTap: () => _setDashboardRollingRange(90),
                                ),
                                _buildDashboardRangeChip(
                                  label: '6 Ay',
                                  selected: _isDashboardRollingRangeSelected(
                                    180,
                                  ),
                                  onTap: () => _setDashboardRollingRange(180),
                                ),
                                _buildDashboardRangeChip(
                                  label: 'Tarih',
                                  icon: Icons.calendar_month_outlined,
                                  selected:
                                      _dashboardRangePreset ==
                                          SellerDashboardRangePreset.custom &&
                                      !_isDashboardRollingRangeSelected(90) &&
                                      !_isDashboardRollingRangeSelected(180),
                                  onTap: _showDashboardRangeDialog,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Row(
                          children: [
                            _buildOverviewMetricInline(
                              'Toplam Gelir',
                              _formatDashboardCurrency(metrics.selectedRevenue),
                              const Color(0xFF4F46E5),
                            ),
                            _buildOverviewInlineDivider(),
                            _buildOverviewMetricInline(
                              'Toplam Sipariş',
                              _formatDashboardNumber(
                                metrics.selectedOrderCount,
                              ),
                              const Color(0xFF0F9D8A),
                            ),
                            _buildOverviewInlineDivider(),
                            _buildOverviewMetricInline(
                              'Dönem Ort.',
                              _formatDashboardCurrency(
                                metrics.averageOrderValue,
                              ),
                              const Color(0xFF334155),
                            ),
                            const Spacer(),
                            _buildLegendPill(
                              label: 'Gelir',
                              color: const Color(0xFF7C3AED),
                            ),
                            const SizedBox(width: 8),
                            _buildLegendPill(
                              label: 'Sipariş',
                              color: const Color(0xFF14B8A6),
                              outlined: true,
                            ),
                          ],
                        ),
                      ),
                      Container(height: 1, color: const Color(0xFFE5E7EB)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        child: _buildEnhancedSalesChart(metrics),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildOverviewDistributionCard(
                  statusCounts: statusCounts,
                  totalOrderCount: totalOrderCount,
                  completionRate: completionRate,
                  isFoodBusiness: isFoodBusiness,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildOverviewRecentOrdersCard(metrics)),
              const SizedBox(width: 14),
              Expanded(child: _buildOverviewPendingTasksCard(pendingTasks)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildOverviewTopProductsCard(topProducts),
              ),
              const SizedBox(width: 14),
              if (!isFoodBusiness)
                Expanded(
                  child: _buildOverviewCargoSummaryCard(cargoSummary),
                )
              else
                Expanded(
                  child: _buildFoodAveragesCard(
                    statusCounts: statusCounts,
                    metrics: metrics,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDashboardSectionLabel('PERFORMANS METRİKLERİ'),
          const SizedBox(height: 10),
          _buildDashboardGrid([
            if (!isFoodBusiness)
              _buildOverviewPerformanceCard(
                icon: Icons.alarm_on_rounded,
                iconColor: const Color(0xFF6366F1),
                iconBackground: const Color(0xFFEDE9FE),
                title: 'Zamanında Gönderim',
                value:
                    '${_dashboardShippingPerformance(statusCounts).toStringAsFixed(0)}%',
                valueSuffix: '',
                progress: _dashboardShippingPerformance(statusCounts) / 100,
                progressColor: const Color(0xFF6366F1),
              )
            else
              _buildOverviewPerformanceCard(
                icon: Icons.table_restaurant_outlined,
                iconColor: const Color(0xFF6366F1),
                iconBackground: const Color(0xFFEDE9FE),
                title: 'Masa Doluluk',
                value:
                    '${statusCounts['open_tables'] ?? 0}',
                valueSuffix: ' masa',
                progress: ((statusCounts['open_tables'] ?? 0) /
                        math.max(1, (statusCounts['open_tables'] ?? 0) +
                            (statusCounts['closed_today'] ?? 0)))
                    .clamp(0.0, 1.0),
                progressColor: const Color(0xFF6366F1),
              ),
            _buildOverviewPerformanceCard(
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFF10B981),
              iconBackground: const Color(0xFFDCFCE7),
              title: isFoodBusiness ? 'Masa Tamamlama' : 'Sipariş Tamamlama',
              value: '${completionRate.toStringAsFixed(0)}%',
              valueSuffix: '',
              progress: completionRate / 100,
              progressColor: const Color(0xFF10B981),
            ),
            _buildOverviewPerformanceCard(
              icon: Icons.star_border_rounded,
              iconColor: const Color(0xFFEAB308),
              iconBackground: const Color(0xFFFEF3C7),
              title: 'Müşteri Puanı',
              value: metrics.storeRating <= 0
                  ? '0.0'
                  : metrics.storeRating.toStringAsFixed(1),
              valueSuffix: '/5',
              progress:
                  (metrics.storeRating <= 0 ? 0 : metrics.storeRating) / 5,
              progressColor: const Color(0xFFEAB308),
            ),
            _buildOverviewPerformanceCard(
              icon: Icons.replay_circle_filled_outlined,
              iconColor: const Color(0xFFEF4444),
              iconBackground: const Color(0xFFFFE5E5),
              title: 'İade Oranı',
              value:
                  '${_dashboardReturnRate(statusCounts, totalOrderCount).toStringAsFixed(1)}%',
              valueSuffix: '',
              progress:
                  _dashboardReturnRate(statusCounts, totalOrderCount) / 100,
              progressColor: const Color(0xFFEF4444),
            ),
          ], minItemWidth: 240),
        ],
      ),
    );
  }

  /// Summary card shown on the right side of the bottom row for food businesses,
  /// replacing the e-commerce cargo summary card.
  Widget _buildFoodAveragesCard({
    required Map<String, int> statusCounts,
    required SellerDashboardMetrics metrics,
  }) {
    final todayTableOrders = statusCounts['today_table_orders'] ?? 0;
    final openTables = statusCounts['open_tables'] ?? 0;
    final closedToday = statusCounts['closed_today'] ?? 0;
    final sentToKitchen = statusCounts['sent_to_kitchen'] ?? 0;
    final restaurantCancelled = statusCounts['restaurant_cancelled'] ?? 0;

    final avgOrderValue = metrics.averageOrderValue;

    final rows = <Map<String, dynamic>>[
      {
        'icon': Icons.receipt_long_outlined,
        'label': 'Bugün Sipariş',
        'value': '$todayTableOrders',
        'color': const Color(0xFF2563EB),
      },
      {
        'icon': Icons.table_restaurant_outlined,
        'label': 'Açık Masa',
        'value': '$openTables',
        'color': const Color(0xFF16A34A),
      },
      {
        'icon': Icons.soup_kitchen_outlined,
        'label': 'Mutfağa İletilen',
        'value': '$sentToKitchen',
        'color': const Color(0xFFF59E0B),
      },
      {
        'icon': Icons.check_circle_outline_rounded,
        'label': 'Bugün Kapanan',
        'value': '$closedToday',
        'color': const Color(0xFF10B981),
      },
      {
        'icon': Icons.cancel_outlined,
        'label': 'İptal',
        'value': '$restaurantCancelled',
        'color': const Color(0xFFEF4444),
      },
      {
        'icon': Icons.payments_outlined,
        'label': 'Ort. Sipariş',
        'value': _formatDashboardCurrency(avgOrderValue),
        'color': const Color(0xFF7C3AED),
      },
    ];

    return SellerDashboardCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Restoran Özeti',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 14),
          ...rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    row['icon'] as IconData,
                    size: 16,
                    color: row['color'] as Color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row['label'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Text(
                    row['value'] as String,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
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
}
