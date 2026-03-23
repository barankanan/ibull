import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/admin_service.dart';

class AdminAdsPage extends StatefulWidget {
  const AdminAdsPage({super.key});

  @override
  State<AdminAdsPage> createState() => _AdminAdsPageState();
}

class _AdminAdsPageState extends State<AdminAdsPage> {
  final AdminService _adminService = AdminService();

  late Future<_AdsSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  Future<_AdsSnapshot> _loadSnapshot() async {
    final results = await Future.wait<dynamic>([
      _adminService.getUserAnalyticsSnapshot(),
      _adminService.getStoreAnalyticsSnapshot(),
      _adminService.getSystemMetrics(),
      _adminService.getUserGrowthTimeline(months: 12),
      _adminService.getStoreParticipationTimeline(months: 12),
    ]);

    final user = results[0] as AdminUserAnalyticsSnapshot;
    final store = results[1] as AdminStoreAnalyticsSnapshot;
    final system = results[2] as AdminSystemMetrics;
    final userGrowth = results[3] as List<AdminTimelinePoint>;
    final storeGrowth = results[4] as List<AdminTimelinePoint>;

    final estimatedSpend =
        (user.activeUsers30d * 2.4) +
        (user.newUsers7d * 18) +
        (store.openStores * 35);
    final conversionCount = user.buyers30d == 0 ? 1 : user.buyers30d;
    final estimatedRevenue = user.averageOrderValue * user.orders30d;
    final estimatedRoas = estimatedSpend <= 0
        ? 0.0
        : (estimatedRevenue / estimatedSpend).toDouble();
    final estimatedCtr = system.totalUsers == 0
        ? 0.0
        : (user.activeUsers30d / system.totalUsers).clamp(0.0, 1.0).toDouble();
    final estimatedCpa = conversionCount == 0
        ? 0.0
        : (estimatedSpend / conversionCount).toDouble();
    final performanceSeries = _buildPerformanceSeries(userGrowth, storeGrowth);
    final totalImpressions = performanceSeries.fold<int>(
      0,
      (sum, item) => sum + item.impressions,
    );
    final totalClicks = performanceSeries.fold<int>(
      0,
      (sum, item) => sum + item.clicks,
    );
    final totalLeads = performanceSeries.fold<int>(
      0,
      (sum, item) => sum + item.leads,
    );
    final totalSpend = performanceSeries.fold<double>(
      0,
      (sum, item) => sum + item.spend,
    );
    final blendedCtr = totalImpressions == 0
        ? 0.0
        : totalClicks / totalImpressions;
    final blendedCpm = totalImpressions == 0
        ? 0.0
        : (totalSpend / totalImpressions) * 1000;
    final blendedCpc = totalClicks == 0 ? 0.0 : totalSpend / totalClicks;
    final blendedCpl = totalLeads == 0 ? 0.0 : totalSpend / totalLeads;
    return _AdsSnapshot(
      user: user,
      store: store,
      system: system,
      userGrowth: userGrowth,
      storeGrowth: storeGrowth,
      estimatedSpend: estimatedSpend,
      estimatedRevenue: estimatedRevenue,
      estimatedRoas: estimatedRoas,
      estimatedCtr: estimatedCtr,
      estimatedCpa: estimatedCpa,
      performanceSeries: performanceSeries,
      totalImpressions: totalImpressions,
      totalClicks: totalClicks,
      totalLeads: totalLeads,
      totalSpend: totalSpend,
      blendedCtr: blendedCtr,
      blendedCpm: blendedCpm,
      blendedCpc: blendedCpc,
      blendedCpl: blendedCpl,
      refreshedAt: DateTime.now(),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
    await _snapshotFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AdsSnapshot>(
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
                        Icons.ads_click_outlined,
                        size: 56,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Reklam merkezi yüklenemedi',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
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
          return const Center(child: Text('Reklam verisi bulunamadı.'));
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1260;
            final isMedium = constraints.maxWidth >= 940;
            final campaignCards = _buildCampaignCards(data);
            final segments = _buildAudienceSegments(data);
            final cohorts = _buildAudienceCohorts(data.user.recentUsers);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildHeroSection(data, isWide: isWide),
                  const SizedBox(height: 20),
                  _buildKpiStrip(data, width: constraints.maxWidth),
                  const SizedBox(height: 20),
                  _buildPerformanceOverview(data, width: constraints.maxWidth),
                  const SizedBox(height: 20),
                  _buildAdMetricsBoard(data, width: constraints.maxWidth),
                  const SizedBox(height: 20),
                  _buildCampaignSection(campaignCards, isMedium: isMedium),
                  const SizedBox(height: 20),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            children: [
                              _buildGrowthCanvas(data),
                              const SizedBox(height: 20),
                              _buildAudienceSegmentsCard(segments),
                              const SizedBox(height: 20),
                              _buildCityTargetingCard(data),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              _buildFunnelCard(data),
                              const SizedBox(height: 20),
                              _buildAudienceCohortCard(cohorts),
                              const SizedBox(height: 20),
                              _buildCreativeInsightsCard(data),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildGrowthCanvas(data),
                    const SizedBox(height: 20),
                    _buildFunnelCard(data),
                    const SizedBox(height: 20),
                    _buildAudienceSegmentsCard(segments),
                    const SizedBox(height: 20),
                    _buildAudienceCohortCard(cohorts),
                    const SizedBox(height: 20),
                    _buildCityTargetingCard(data),
                    const SizedBox(height: 20),
                    _buildCreativeInsightsCard(data),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeroSection(_AdsSnapshot data, {required bool isWide}) {
    final roasLabel = data.estimatedRoas >= 4
        ? 'agresif ölçeklenebilir'
        : data.estimatedRoas >= 2
        ? 'kontrollü büyüme'
        : 'yeniden optimizasyon';

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1D4ED8), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildHeroCopy(data, roasLabel)),
                const SizedBox(width: 20),
                SizedBox(width: 340, child: _buildHeroStatPanel(data)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCopy(data, roasLabel),
                const SizedBox(height: 20),
                _buildHeroStatPanel(data),
              ],
            ),
    );
  }

  Widget _buildHeroCopy(_AdsSnapshot data, String roasLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.campaign_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'Performance Ads Center',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Kullanıcı akışını reklam zekasına dönüştüren kontrol alanı.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Bu ekran doğrudan uygulama içi kullanıcı, sipariş ve mağaza sinyallerini okur. '
          'Hedef kitle sınıflandırma, yaratıcı yön, funnel takibi ve reklam ölçekleme '
          'için Google Ads ve Meta Ads hissinde bir karar yüzeyi sunar.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _heroPill('ROAS modu', roasLabel),
            _heroPill('Aktif hedef kitle', _compact(data.user.activeUsers30d)),
            _heroPill(
              'Yeni kullanıcı ivmesi',
              '${data.user.newUsers7d} / 7 gün',
            ),
            _heroPill('Son yenileme', _dateTime(data.refreshedAt)),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroStatPanel(_AdsSnapshot data) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Medya performans özeti',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          _heroStatRow('Tahmini bütçe', _money(data.estimatedSpend)),
          const SizedBox(height: 10),
          _heroStatRow('Tahmini gelir', _money(data.estimatedRevenue)),
          const SizedBox(height: 10),
          _heroStatRow('CTR benzeri skor', _percent(data.estimatedCtr)),
          const SizedBox(height: 10),
          _heroStatRow('CPA simülasyonu', _money(data.estimatedCpa)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (data.estimatedRoas / 5).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              color: const Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'ROAS ${data.estimatedRoas.toStringAsFixed(1)}x',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiStrip(_AdsSnapshot data, {required double width}) {
    final items = [
      _AdsKpi(
        title: 'Tahmini medya bütçesi',
        value: _money(data.estimatedSpend),
        subtitle:
            'Aktif kullanıcı, yeni kayıt ve mağaza yoğunluğundan türetildi',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF2563EB),
      ),
      _AdsKpi(
        title: 'Tahmini ROAS',
        value: '${data.estimatedRoas.toStringAsFixed(1)}x',
        subtitle: 'Sipariş geliri / projekte edilmiş reklam maliyeti',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF16A34A),
      ),
      _AdsKpi(
        title: 'Dönüşüm havuzu',
        value: _compact(data.user.buyers30d),
        subtitle: 'Son 30 gün sipariş veren benzersiz kullanıcı',
        icon: Icons.ads_click_rounded,
        color: const Color(0xFFF59E0B),
      ),
      _AdsKpi(
        title: 'Yeniden hedefleme havuzu',
        value: _compact(
          (data.user.totalUsers - data.user.activeUsers30d).clamp(0, 1 << 31),
        ),
        subtitle: 'Kayıtlı ama son 30 günde aktif olmayan kullanıcı',
        icon: Icons.refresh_rounded,
        color: const Color(0xFF7C3AED),
      ),
    ];

    final cardWidth = width >= 1440
        ? (width - 48) / 4
        : width >= 900
        ? (width - 16) / 2
        : width;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: items.map((item) {
        return SizedBox(
          width: cardWidth,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.value,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
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
        );
      }).toList(),
    );
  }

  Widget _buildCampaignSection(
    List<_CampaignCardData> items, {
    required bool isMedium,
  }) {
    final children = items
        .map((item) => _buildCampaignCard(item))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Reklam Setleri',
          'Google Search, Meta Prospecting ve Retargeting benzeri yapıların uygulama içi karşılığı.',
        ),
        const SizedBox(height: 16),
        if (isMedium)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: 16),
              Expanded(child: children[1]),
              const SizedBox(width: 16),
              Expanded(child: children[2]),
            ],
          )
        else
          Column(
            children: [
              children[0],
              const SizedBox(height: 16),
              children[1],
              const SizedBox(height: 16),
              children[2],
            ],
          ),
      ],
    );
  }

  Widget _buildAdMetricsBoard(_AdsSnapshot data, {required double width}) {
    final metrics = [
      _AdsMetricCardData(
        title: 'Harcama Tutarı',
        value: _money(data.totalSpend),
        subtitle: '12 aylık türetilmiş medya harcaması',
        color: const Color(0xFF2563EB),
        points: data.performanceSeries.map((item) => item.spend).toList(),
      ),
      _AdsMetricCardData(
        title: 'Gösterim',
        value: _compact(data.totalImpressions),
        subtitle: 'Reklam görüntülenme sayısı',
        color: const Color(0xFF0F766E),
        points: data.performanceSeries
            .map((item) => item.impressions.toDouble())
            .toList(),
      ),
      _AdsMetricCardData(
        title: 'CPM',
        value: _money(data.blendedCpm),
        subtitle: '1000 gösterim başına maliyet',
        color: const Color(0xFFF59E0B),
        points: data.performanceSeries.map((item) => item.cpm).toList(),
      ),
      _AdsMetricCardData(
        title: 'Tıklama',
        value: _compact(data.totalClicks),
        subtitle: 'Toplam reklam tıklanma sayısı',
        color: const Color(0xFF7C3AED),
        points: data.performanceSeries
            .map((item) => item.clicks.toDouble())
            .toList(),
      ),
      _AdsMetricCardData(
        title: 'CTR',
        value: _percent(data.blendedCtr),
        subtitle: 'Gösterimi görenlerin tıklama oranı',
        color: const Color(0xFF06B6D4),
        points: data.performanceSeries.map((item) => item.ctr).toList(),
      ),
      _AdsMetricCardData(
        title: 'CPC',
        value: _money(data.blendedCpc),
        subtitle: 'Tıklama başına maliyet',
        color: const Color(0xFFDC2626),
        points: data.performanceSeries.map((item) => item.cpc).toList(),
      ),
      _AdsMetricCardData(
        title: 'Leads',
        value: _compact(data.totalLeads),
        subtitle: 'Kullanıcı verisi alma hacmi',
        color: const Color(0xFF16A34A),
        points: data.performanceSeries
            .map((item) => item.leads.toDouble())
            .toList(),
      ),
      _AdsMetricCardData(
        title: 'Cost Per Lead',
        value: _money(data.blendedCpl),
        subtitle: 'Lead başına maliyet',
        color: const Color(0xFFEA580C),
        points: data.performanceSeries.map((item) => item.costPerLead).toList(),
      ),
    ];

    final cardWidth = width >= 1500
        ? (width - 48) / 4
        : width >= 1000
        ? (width - 16) / 2
        : width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Reklam KPI Grafikleri',
          'Bu metrikler uygulama içi kullanıcı, mağaza ve sipariş davranışından türetilmiş performans modeliyle hesaplanır.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: metrics.map((metric) {
            return SizedBox(
              width: cardWidth,
              child: _buildMetricTrendCard(metric, data.performanceSeries),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPerformanceOverview(_AdsSnapshot data, {required double width}) {
    final labels = data.performanceSeries
        .map((item) => item.label)
        .toList(growable: false);
    final acquisitionSeries = [
      _AdsTrendSeries(
        label: 'Gosterim',
        color: const Color(0xFF0F766E),
        values: data.performanceSeries
            .map((item) => item.impressions.toDouble())
            .toList(growable: false),
      ),
      _AdsTrendSeries(
        label: 'Tiklama',
        color: const Color(0xFF7C3AED),
        values: data.performanceSeries
            .map((item) => item.clicks.toDouble())
            .toList(growable: false),
      ),
      _AdsTrendSeries(
        label: 'Lead',
        color: const Color(0xFF16A34A),
        values: data.performanceSeries
            .map((item) => item.leads.toDouble())
            .toList(growable: false),
      ),
    ];
    final efficiencySeries = [
      _AdsTrendSeries(
        label: 'Harcama',
        color: const Color(0xFF2563EB),
        values: data.performanceSeries
            .map((item) => item.spend)
            .toList(growable: false),
      ),
      _AdsTrendSeries(
        label: 'CPM',
        color: const Color(0xFFF59E0B),
        values: data.performanceSeries
            .map((item) => item.cpm)
            .toList(growable: false),
      ),
      _AdsTrendSeries(
        label: 'CPC',
        color: const Color(0xFFDC2626),
        values: data.performanceSeries
            .map((item) => item.cpc)
            .toList(growable: false),
      ),
      _AdsTrendSeries(
        label: 'CTR',
        color: const Color(0xFF06B6D4),
        values: data.performanceSeries
            .map((item) => item.ctr * 100)
            .toList(growable: false),
      ),
      _AdsTrendSeries(
        label: 'CPL',
        color: const Color(0xFFEA580C),
        values: data.performanceSeries
            .map((item) => item.costPerLead)
            .toList(growable: false),
      ),
    ];
    final isWide = width >= 1160;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Zaman Serisi Reklam Grafikleri',
          'Harcama, gosterim, tiklama, CTR, CPC ve lead verisini uygulama ici sinyallerden turetilmis reklam modeliyle birlikte izle.',
        ),
        const SizedBox(height: 16),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildPerformanceChartCard(
                  title: 'Edinim Akisi',
                  subtitle:
                      'Gosterim, tiklama ve lead hacmini ayni zaman serisinde oku.',
                  labels: labels,
                  series: acquisitionSeries,
                  summary: [
                    _miniMetric(
                      'Toplam gosterim',
                      _compact(data.totalImpressions),
                    ),
                    _miniMetric('Toplam tiklama', _compact(data.totalClicks)),
                    _miniMetric('Toplam lead', _compact(data.totalLeads)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPerformanceChartCard(
                  title: 'Maliyet ve Verimlilik',
                  subtitle:
                      'Harcama egilimi ile CPM, CPC, CTR ve lead maliyetini birlikte izle.',
                  labels: labels,
                  series: efficiencySeries,
                  summary: [
                    _miniMetric('Toplam harcama', _money(data.totalSpend)),
                    _miniMetric('Blended CPM', _money(data.blendedCpm)),
                    _miniMetric('Blended CPC', _money(data.blendedCpc)),
                    _miniMetric('Blended CTR', _percent(data.blendedCtr)),
                    _miniMetric('Lead maliyeti', _money(data.blendedCpl)),
                  ],
                ),
              ),
            ],
          )
        else ...[
          _buildPerformanceChartCard(
            title: 'Edinim Akisi',
            subtitle:
                'Gosterim, tiklama ve lead hacmini ayni zaman serisinde oku.',
            labels: labels,
            series: acquisitionSeries,
            summary: [
              _miniMetric('Toplam gosterim', _compact(data.totalImpressions)),
              _miniMetric('Toplam tiklama', _compact(data.totalClicks)),
              _miniMetric('Toplam lead', _compact(data.totalLeads)),
            ],
          ),
          const SizedBox(height: 16),
          _buildPerformanceChartCard(
            title: 'Maliyet ve Verimlilik',
            subtitle:
                'Harcama egilimi ile CPM, CPC, CTR ve lead maliyetini birlikte izle.',
            labels: labels,
            series: efficiencySeries,
            summary: [
              _miniMetric('Toplam harcama', _money(data.totalSpend)),
              _miniMetric('Blended CPM', _money(data.blendedCpm)),
              _miniMetric('Blended CPC', _money(data.blendedCpc)),
              _miniMetric('Blended CTR', _percent(data.blendedCtr)),
              _miniMetric('Lead maliyeti', _money(data.blendedCpl)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPerformanceChartCard({
    required String title,
    required String subtitle,
    required List<String> labels,
    required List<_AdsTrendSeries> series,
    required List<Widget> summary,
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
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
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: series
                .map((item) => _legendChip(item.label, item.color))
                .toList(growable: false),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 250,
            child: CustomPaint(
              painter: _AdsMultiSeriesPainter(series: series),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: labels
                .map((label) {
                  return Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: summary),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              'Kaynak: kullanici kazanimi, aktiflik, siparis ve magaza arz verisinden turetilmis reklam performans modeli.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTrendCard(
    _AdsMetricCardData metric,
    List<_AdsPerformancePoint> performanceSeries,
  ) {
    final labels = performanceSeries.map((item) => item.label).toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9CA3AF),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: CustomPaint(
              painter: _AdsSparklinePainter(
                values: metric.points,
                color: metric.color,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: labels.map((label) {
              return Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignCard(_CampaignCardData item) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(item.status, item.color),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _miniMetric('Hedef kitle', item.audienceLabel),
              _miniMetric('Bütçe', _money(item.budget)),
              _miniMetric('ROAS', '${item.roas.toStringAsFixed(1)}x'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            item.note,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4B5563),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthCanvas(_AdsSnapshot data) {
    return _surfaceCard(
      title: 'Kitle ve Talep Büyümesi',
      subtitle:
          'Aynı tuvalde kullanıcı kazanımı ile mağaza arzının nasıl büyüdüğünü gör.',
      icon: Icons.insights_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _legendChip('Yeni kullanıcı', const Color(0xFF2563EB)),
              _legendChip('Aktif kullanıcı', const Color(0xFF0F766E)),
              _legendChip('Katılan mağaza', const Color(0xFFF97316)),
              _legendChip('Açık mağaza', const Color(0xFF7C3AED)),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 280,
            child: CustomPaint(
              painter: _AdsGrowthPainter(
                userPoints: data.userGrowth,
                storePoints: data.storeGrowth,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: data.userGrowth.take(12).map((point) {
              return Expanded(
                child: Text(
                  point.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceSegmentsCard(List<_AudienceSegment> segments) {
    return _surfaceCard(
      title: 'Hedef Kitle Segmentleri',
      subtitle:
          'Reklam çıkılabilecek kullanıcı kümeleri ve önerilen medya yönü.',
      icon: Icons.groups_2_rounded,
      child: Column(
        children: segments.map((segment) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: segment.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(segment.icon, color: segment.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          segment.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          segment.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _miniMetric('Hacim', _compact(segment.size)),
                            _miniMetric('Kanal', segment.channel),
                            _miniMetric('Aksiyon', segment.actionLabel),
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

  Widget _buildFunnelCard(_AdsSnapshot data) {
    final awareness = (data.system.totalUsers * 1.4).round().clamp(0, 1 << 31);
    final engaged = data.user.activeUsers30d;
    final prospects = data.user.buyers30d;
    final repeat = (data.user.repeatBuyerRate * data.user.buyers30d).round();
    final stages = [
      ('Erişim', awareness, const Color(0xFF2563EB)),
      ('Etkileşim', engaged, const Color(0xFF0F766E)),
      ('Dönüşüm', prospects, const Color(0xFFF97316)),
      ('Tekrar satın alma', repeat, const Color(0xFF7C3AED)),
    ];
    final maxValue = stages.fold<int>(
      1,
      (max, item) => item.$2 > max ? item.$2 : max,
    );

    return _surfaceCard(
      title: 'Reklam Funnel',
      subtitle: 'Uygulama içi veriyle kampanya hunisini ve dar boğazları gör.',
      icon: Icons.filter_alt_rounded,
      child: Column(
        children: stages.map((stage) {
          final ratio = maxValue == 0 ? 0.0 : stage.$2 / maxValue;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stage.$1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Text(
                      _compact(stage.$2),
                      style: TextStyle(
                        color: stage.$3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 11,
                    backgroundColor: const Color(0xFFE5E7EB),
                    color: stage.$3,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAudienceCohortCard(List<_AudienceCohort> cohorts) {
    return _surfaceCard(
      title: 'Kullanıcı Sınıflandırma',
      subtitle: 'Yeni gelen kullanıcıları reklam uygunluğuna göre sınıflandır.',
      icon: Icons.person_search_rounded,
      child: cohorts.isEmpty
          ? const Text(
              'Sınıflandırılacak kullanıcı görünmüyor.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            )
          : Column(
              children: cohorts.map((cohort) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: cohort.color.withValues(alpha: 0.14),
                          child: Text(
                            _initials(cohort.name),
                            style: TextStyle(
                              color: cohort.color,
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
                                cohort.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cohort.email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _miniMetric('Segment', cohort.segment),
                                  _miniMetric('Şehir', cohort.city),
                                  _miniMetric(
                                    'Sipariş',
                                    '${cohort.orderCount30d} / 30 gün',
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

  Widget _buildCityTargetingCard(_AdsSnapshot data) {
    return _surfaceCard(
      title: 'Şehir Bazlı Hedefleme',
      subtitle:
          'Yüksek niyetli şehirleri medya bütçesi ve teslimat tercihiyle eşleştir.',
      icon: Icons.location_city_rounded,
      child: Column(
        children: data.user.topCities.map((city) {
          final deliverySlice = data.user.deliveryTypes.isEmpty
              ? null
              : data.user.deliveryTypes.first;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        city.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Text(
                      _compact(city.value),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _percent(city.share),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: city.share,
                    minHeight: 9,
                    backgroundColor: const Color(0xFFE5E7EB),
                    color: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    deliverySlice == null
                        ? 'Şehir skoru'
                        : 'Önerilen kanal: ${deliverySlice.label}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCreativeInsightsCard(_AdsSnapshot data) {
    final bullets = [
      'Yeni kullanıcı ivmesi ${data.user.newUsers7d} kayıt ile sıcak bir üst huni gösteriyor.',
      'Tekrar satın alma oranı ${_percent(data.user.repeatBuyerRate)}; remarketing dili performans odaklı olmalı.',
      '${data.store.openStores} açık mağaza, reklam sonrası talebi karşılayabilecek arz bulunduğunu gösteriyor.',
      '${data.system.openSupportTickets} açık destek kaydı var; agresif kampanya öncesi operasyon kalitesi izlenmeli.',
    ];

    return _surfaceCard(
      title: 'Kreatif ve Medya Notları',
      subtitle:
          'Uygulama verisinin reklam mesajına çevrildiği hızlı yönlendirmeler.',
      icon: Icons.auto_awesome_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: bullets.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  List<_CampaignCardData> _buildCampaignCards(_AdsSnapshot data) {
    final repeatBuyers = (data.user.repeatBuyerRate * data.user.buyers30d)
        .round();
    return [
      _CampaignCardData(
        title: 'Search Intent',
        subtitle: 'Yüksek satın alma niyetine yakın kullanıcıları topla',
        audienceLabel: '${_compact(data.user.buyers30d)} kullanıcı',
        budget: data.estimatedSpend * 0.34,
        roas: data.estimatedRoas + 0.4,
        note:
            'Sipariş veren kullanıcılar ve güçlü şehir yoğunluğu üzerinden performans odaklı arama kampanyası senaryosu.',
        icon: Icons.travel_explore_rounded,
        color: const Color(0xFF2563EB),
        status: 'Ölçeklenebilir',
      ),
      _CampaignCardData(
        title: 'Meta Prospecting',
        subtitle: 'Yeni kullanıcı ve aktif ama satın almayan kitleyi ısıt',
        audienceLabel:
            '${_compact((data.user.activeUsers30d - data.user.buyers30d).clamp(0, 1 << 31))} kullanıcı',
        budget: data.estimatedSpend * 0.41,
        roas: data.estimatedRoas,
        note:
            'Yeni kayıtlar, aktif kullanıcılar ve teslimat tercihleri üzerinden ilgi odaklı geniş hedefleme taslağı.',
        icon: Icons.groups_rounded,
        color: const Color(0xFF7C3AED),
        status: 'Aktif',
      ),
      _CampaignCardData(
        title: 'Retargeting Burst',
        subtitle: 'Tekrar satın alma ve geri kazanım havuzu',
        audienceLabel: '${_compact(repeatBuyers)} kullanıcı',
        budget: data.estimatedSpend * 0.25,
        roas: data.estimatedRoas + 0.8,
        note:
            'Repeat buyer oranı ve son 30 günde pasif kalan kayıtlı kullanıcılar üzerinden yeniden hedefleme önerisi.',
        icon: Icons.replay_circle_filled_rounded,
        color: const Color(0xFFF97316),
        status: 'Verimli',
      ),
    ];
  }

  List<_AudienceSegment> _buildAudienceSegments(_AdsSnapshot data) {
    final repeatBuyers = (data.user.repeatBuyerRate * data.user.buyers30d)
        .round();
    final warmAudience = (data.user.activeUsers30d - data.user.buyers30d).clamp(
      0,
      1 << 31,
    );
    final coldAudience = (data.user.totalUsers - data.user.activeUsers30d)
        .clamp(0, 1 << 31);
    return [
      _AudienceSegment(
        title: 'Yeni kayıtlar',
        subtitle: 'Son 7 gün uygulamaya ilk kez giren kullanıcılar',
        size: data.user.newUsers7d,
        channel: 'Meta / App Install',
        actionLabel: 'Onboarding kreatifi',
        icon: Icons.person_add_alt_1_rounded,
        color: const Color(0xFF2563EB),
      ),
      _AudienceSegment(
        title: 'Sıcak ama dönüşmemiş',
        subtitle: 'Aktif fakat henüz sipariş oluşturmamış kitle',
        size: warmAudience,
        channel: 'Search + Social',
        actionLabel: 'Teklif ve güven mesajı',
        icon: Icons.whatshot_rounded,
        color: const Color(0xFFF97316),
      ),
      _AudienceSegment(
        title: 'Repeat buyer',
        subtitle: 'Tekrar sipariş potansiyeli yüksek sadık kullanıcılar',
        size: repeatBuyers,
        channel: 'CRM / Retargeting',
        actionLabel: 'Sepet ve bundle',
        icon: Icons.loyalty_rounded,
        color: const Color(0xFF16A34A),
      ),
      _AudienceSegment(
        title: 'Reaktivasyon havuzu',
        subtitle: 'Kayıtlı ama son 30 günde aktif görünmeyen kullanıcılar',
        size: coldAudience,
        channel: 'Meta Retargeting',
        actionLabel: 'Geri çağırma mesajı',
        icon: Icons.restart_alt_rounded,
        color: const Color(0xFF7C3AED),
      ),
    ];
  }

  List<_AudienceCohort> _buildAudienceCohorts(
    List<AdminRecentUserActivity> users,
  ) {
    return users
        .map((user) {
          final isNew =
              user.createdAt != null &&
              DateTime.now().difference(user.createdAt!).inDays <= 7;
          final isBuyer = user.orderCount30d > 0;
          final segment = isBuyer
              ? 'Dönüşmüş kullanıcı'
              : isNew
              ? 'Yeni prospect'
              : 'Isınan kitle';
          final color = isBuyer
              ? const Color(0xFF16A34A)
              : isNew
              ? const Color(0xFF2563EB)
              : const Color(0xFFF97316);
          return _AudienceCohort(
            name: user.name,
            email: user.email,
            city: user.city,
            orderCount30d: user.orderCount30d,
            segment: segment,
            color: color,
          );
        })
        .toList(growable: false);
  }

  Widget _surfaceCard({
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

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _heroPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStatRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _legendChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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

  Widget _miniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
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

  int _clampInt(int value, {int min = 0, int max = 1 << 31}) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  List<_AdsPerformancePoint> _buildPerformanceSeries(
    List<AdminTimelinePoint> userGrowth,
    List<AdminTimelinePoint> storeGrowth,
  ) {
    final pointCount = math.min(userGrowth.length, storeGrowth.length);
    if (pointCount == 0) return const [];

    return List.generate(pointCount, (index) {
      final userPoint = userGrowth[index];
      final storePoint = storeGrowth[index];

      final impressions = _clampInt(
        (userPoint.secondaryValue * 92) +
            (userPoint.primaryValue * 160) +
            (storePoint.secondaryValue * 1180) +
            (storePoint.primaryValue * 760),
        min: 1200,
      );
      final ctr =
          (0.014 +
                  (userPoint.primaryValue * 0.0012) +
                  (storePoint.primaryValue * 0.0015) +
                  (userPoint.secondaryValue * 0.00008))
              .clamp(0.012, 0.068)
              .toDouble();
      final clicks = _clampInt((impressions * ctr).round(), min: 1);
      final cpc =
          (2.2 +
                  (storePoint.primaryValue * 0.18) +
                  (userPoint.primaryValue < 6 ? 0.7 : 0.0) +
                  (userPoint.secondaryValue < 90 ? 0.35 : 0.0))
              .clamp(1.4, 8.6)
              .toDouble();
      final spend = clicks * cpc;
      final leadRate =
          (0.16 +
                  (userPoint.primaryValue * 0.003) +
                  (storePoint.secondaryValue * 0.0008))
              .clamp(0.12, 0.36)
              .toDouble();
      final leads = _clampInt(
        math.max(userPoint.primaryValue, (clicks * leadRate).round()),
        min: 1,
      );
      final cpm = impressions == 0 ? 0.0 : (spend / impressions) * 1000;
      final costPerLead = leads == 0 ? 0.0 : spend / leads;

      return _AdsPerformancePoint(
        label: userPoint.label,
        spend: spend,
        impressions: impressions,
        clicks: clicks,
        ctr: ctr,
        cpm: cpm,
        cpc: cpc,
        leads: leads,
        costPerLead: costPerLead,
      );
    });
  }

  String _compact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)} Mn';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)} B';
    }
    return '$value';
  }

  String _money(double value) {
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

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return 'RK';
    return parts.map((item) => item.substring(0, 1).toUpperCase()).join();
  }
}

class _AdsSnapshot {
  const _AdsSnapshot({
    required this.user,
    required this.store,
    required this.system,
    required this.userGrowth,
    required this.storeGrowth,
    required this.estimatedSpend,
    required this.estimatedRevenue,
    required this.estimatedRoas,
    required this.estimatedCtr,
    required this.estimatedCpa,
    required this.performanceSeries,
    required this.totalImpressions,
    required this.totalClicks,
    required this.totalLeads,
    required this.totalSpend,
    required this.blendedCtr,
    required this.blendedCpm,
    required this.blendedCpc,
    required this.blendedCpl,
    required this.refreshedAt,
  });

  final AdminUserAnalyticsSnapshot user;
  final AdminStoreAnalyticsSnapshot store;
  final AdminSystemMetrics system;
  final List<AdminTimelinePoint> userGrowth;
  final List<AdminTimelinePoint> storeGrowth;
  final double estimatedSpend;
  final double estimatedRevenue;
  final double estimatedRoas;
  final double estimatedCtr;
  final double estimatedCpa;
  final List<_AdsPerformancePoint> performanceSeries;
  final int totalImpressions;
  final int totalClicks;
  final int totalLeads;
  final double totalSpend;
  final double blendedCtr;
  final double blendedCpm;
  final double blendedCpc;
  final double blendedCpl;
  final DateTime refreshedAt;
}

class _AdsKpi {
  const _AdsKpi({
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

class _CampaignCardData {
  const _CampaignCardData({
    required this.title,
    required this.subtitle,
    required this.audienceLabel,
    required this.budget,
    required this.roas,
    required this.note,
    required this.icon,
    required this.color,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String audienceLabel;
  final double budget;
  final double roas;
  final String note;
  final IconData icon;
  final Color color;
  final String status;
}

class _AdsMetricCardData {
  const _AdsMetricCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.points,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final List<double> points;
}

class _AdsPerformancePoint {
  const _AdsPerformancePoint({
    required this.label,
    required this.spend,
    required this.impressions,
    required this.clicks,
    required this.ctr,
    required this.cpm,
    required this.cpc,
    required this.leads,
    required this.costPerLead,
  });

  final String label;
  final double spend;
  final int impressions;
  final int clicks;
  final double ctr;
  final double cpm;
  final double cpc;
  final int leads;
  final double costPerLead;
}

class _AdsTrendSeries {
  const _AdsTrendSeries({
    required this.label,
    required this.color,
    required this.values,
  });

  final String label;
  final Color color;
  final List<double> values;
}

class _AudienceSegment {
  const _AudienceSegment({
    required this.title,
    required this.subtitle,
    required this.size,
    required this.channel,
    required this.actionLabel,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final int size;
  final String channel;
  final String actionLabel;
  final IconData icon;
  final Color color;
}

class _AudienceCohort {
  const _AudienceCohort({
    required this.name,
    required this.email,
    required this.city,
    required this.orderCount30d,
    required this.segment,
    required this.color,
  });

  final String name;
  final String email;
  final String city;
  final int orderCount30d;
  final String segment;
  final Color color;
}

class _AdsGrowthPainter extends CustomPainter {
  const _AdsGrowthPainter({
    required this.userPoints,
    required this.storePoints,
  });

  final List<AdminTimelinePoint> userPoints;
  final List<AdminTimelinePoint> storePoints;

  @override
  void paint(Canvas canvas, Size size) {
    final pointCount = userPoints.length < storePoints.length
        ? userPoints.length
        : storePoints.length;
    if (pointCount == 0) return;

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final dy = (size.height - 18) * (i / 3);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    final maxValue = [
      ...userPoints.take(pointCount).map((item) => item.primaryValue),
      ...userPoints.take(pointCount).map((item) => item.secondaryValue),
      ...storePoints.take(pointCount).map((item) => item.primaryValue),
      ...storePoints.take(pointCount).map((item) => item.secondaryValue),
    ].fold<int>(1, (max, value) => value > max ? value : max);

    final userNewPath = Path();
    final userActivePath = Path();
    final storeNewPath = Path();
    final storeOpenPath = Path();
    final availableHeight = size.height - 20;
    final spacing = pointCount == 1 ? 0.0 : size.width / (pointCount - 1);

    for (var i = 0; i < pointCount; i++) {
      final dx = spacing * i;
      final userNewDy =
          availableHeight -
          (userPoints[i].primaryValue / maxValue) * availableHeight;
      final userActiveDy =
          availableHeight -
          (userPoints[i].secondaryValue / maxValue) * availableHeight;
      final storeNewDy =
          availableHeight -
          (storePoints[i].primaryValue / maxValue) * availableHeight;
      final storeOpenDy =
          availableHeight -
          (storePoints[i].secondaryValue / maxValue) * availableHeight;

      void moveOrLine(Path path, double dy) {
        if (i == 0) {
          path.moveTo(dx, dy);
        } else {
          path.lineTo(dx, dy);
        }
      }

      moveOrLine(userNewPath, userNewDy);
      moveOrLine(userActivePath, userActiveDy);
      moveOrLine(storeNewPath, storeNewDy);
      moveOrLine(storeOpenPath, storeOpenDy);
    }

    void drawPath(Path path, Color color) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
    }

    drawPath(userNewPath, const Color(0xFF2563EB));
    drawPath(userActivePath, const Color(0xFF0F766E));
    drawPath(storeNewPath, const Color(0xFFF97316));
    drawPath(storeOpenPath, const Color(0xFF7C3AED));
  }

  @override
  bool shouldRepaint(covariant _AdsGrowthPainter oldDelegate) {
    return oldDelegate.userPoints != userPoints ||
        oldDelegate.storePoints != storePoints;
  }
}

class _AdsSparklinePainter extends CustomPainter {
  const _AdsSparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxValue = values.fold<double>(0, (max, value) {
      return value > max ? value : max;
    });
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final spacing = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < values.length; i++) {
      final dx = spacing * i;
      final dy = size.height - ((values[i] / safeMax) * (size.height - 10)) - 5;
      if (i == 0) {
        path.moveTo(dx, dy);
        fillPath.moveTo(dx, size.height);
        fillPath.lineTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
        fillPath.lineTo(dx, dy);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    for (var i = 0; i < values.length; i++) {
      final dx = spacing * i;
      final dy = size.height - ((values[i] / safeMax) * (size.height - 10)) - 5;
      canvas.drawCircle(Offset(dx, dy), 2.8, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _AdsSparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class _AdsMultiSeriesPainter extends CustomPainter {
  const _AdsMultiSeriesPainter({required this.series});

  final List<_AdsTrendSeries> series;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    final pointCount = series.first.values.length;
    if (pointCount == 0) return;

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final dy = (size.height - 16) * (i / 4);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    double maxValue = 1;
    for (final item in series) {
      for (final value in item.values) {
        if (value > maxValue) {
          maxValue = value;
        }
      }
    }

    final availableHeight = size.height - 18;
    final spacing = pointCount == 1 ? 0.0 : size.width / (pointCount - 1);

    for (final item in series) {
      final path = Path();
      for (var i = 0; i < pointCount; i++) {
        final dx = spacing * i;
        final dy =
            availableHeight - ((item.values[i] / maxValue) * availableHeight);
        if (i == 0) {
          path.moveTo(dx, dy);
        } else {
          path.lineTo(dx, dy);
        }
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = item.color
          ..strokeWidth = 2.6
          ..style = PaintingStyle.stroke,
      );

      for (var i = 0; i < pointCount; i++) {
        final dx = spacing * i;
        final dy =
            availableHeight - ((item.values[i] / maxValue) * availableHeight);
        canvas.drawCircle(Offset(dx, dy), 3, Paint()..color = item.color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AdsMultiSeriesPainter oldDelegate) {
    return oldDelegate.series != series;
  }
}
