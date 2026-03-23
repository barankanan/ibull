import 'package:flutter/material.dart';

import '../../enums/ad_enums.dart';
import '../../helpers/ad_metrics_helper.dart';
import '../../models/ad_campaign.dart';
import '../../models/ad_metrics.dart';
import '../../models/ad_revenue_overview.dart';
import '../../models/ads_dashboard_snapshot.dart';
import '../../services/ad_metrics_service.dart';
import '../../services/campaign_review_service.dart';
import '../../services/campaign_service.dart';
import '../../services/ads_service.dart';
import 'campaign_detail_dialog.dart';
import '../widgets/campaign_action_menu.dart';
import '../widgets/admin_ad_credit_codes_panel.dart';
import '../widgets/revenue_card.dart';
import '../widgets/status_chip.dart';
import '../widgets/summary_stat_card.dart';

const List<DropdownMenuItem<String>> _kStatusItems = [
  DropdownMenuItem(value: 'Tum', child: Text('Tum')),
  DropdownMenuItem(value: 'active', child: Text('active')),
  DropdownMenuItem(value: 'approved', child: Text('approved')),
  DropdownMenuItem(value: 'pending_review', child: Text('pending_review')),
  DropdownMenuItem(value: 'paused', child: Text('paused')),
  DropdownMenuItem(value: 'rejected', child: Text('rejected')),
];

const List<DropdownMenuItem<String>> _kReviewItems = [
  DropdownMenuItem(value: 'Tum', child: Text('Tum')),
  DropdownMenuItem(value: 'pending', child: Text('pending')),
  DropdownMenuItem(value: 'approved', child: Text('approved')),
  DropdownMenuItem(value: 'rejected', child: Text('rejected')),
  DropdownMenuItem(
    value: 'changes_requested',
    child: Text('changes_requested'),
  ),
];

class AdminAdsManagerContent extends StatefulWidget {
  const AdminAdsManagerContent({this.embedded = false, super.key});

  final bool embedded;

  @override
  State<AdminAdsManagerContent> createState() => _AdminAdsManagerContentState();
}

class _AdminAdsManagerContentState extends State<AdminAdsManagerContent> {
  final AdsService _adsService = AdsService();
  final CampaignReviewService _reviewService = CampaignReviewService();
  final CampaignService _campaignService = CampaignService();
  final AdMetricsService _metricsService = AdMetricsService();

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _processingCampaignIds = <String>{};
  String _statusFilter = 'Tum';
  String _reviewFilter = 'Tum';
  bool _showCreditManagement = false;
  bool _isOpeningCreditManagement = false;
  bool _creditScreenRenderLogged = false;

  late Future<_AdminAdsViewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_AdminAdsViewData> _load() async {
    final stopwatch = Stopwatch()..start();
    debugPrint('LOAD START');
    try {
      debugPrint('before getAdminDashboard');
      final snapshot = await _adsService.getAdminDashboard().timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('AdminAdsManagerContent dashboard timeout');
          return _buildEmptySnapshot();
        },
      );
      debugPrint('after getAdminDashboard');
      debugPrint(
        'AdminAdsManagerContent campaigns loaded count=${snapshot.campaigns.length}',
      );
      debugPrint(
        'AdminAdsManagerContent reviews loaded count=${snapshot.reviews.length}',
      );

      final campaignIds = snapshot.campaigns
          .map((item) => item.id)
          .toList(growable: false);

      List<AdMetrics> metrics = const <AdMetrics>[];
      if (campaignIds.isEmpty) {
        debugPrint(
          'AdminAdsManagerContent metrics skipped because campaigns are empty',
        );
      } else {
        debugPrint('before getDailyMetrics');
        try {
          metrics = await _metricsService
              .getDailyMetrics(
                campaignIds: campaignIds,
                from: DateTime.now().subtract(const Duration(days: 30)),
              )
              .timeout(
                const Duration(seconds: 2),
                onTimeout: () {
                  debugPrint('AdminAdsManagerContent metrics timeout');
                  return <AdMetrics>[];
                },
              );
        } catch (error, stackTrace) {
          debugPrint('AdminAdsManagerContent metrics load failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          metrics = const <AdMetrics>[];
        }
        debugPrint('after getDailyMetrics');
      }
      debugPrint(
        'AdminAdsManagerContent metrics loaded count=${metrics.length}',
      );

      debugPrint('before buildViewData');
      final viewData = _buildViewData(snapshot, metrics);
      debugPrint('after buildViewData');
      debugPrint('RETURNING VIEW DATA');
      return viewData;
    } catch (error, stackTrace) {
      debugPrint('AdminAdsManagerContent load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw StateError('Reklam merkezi yuklenemedi: $error');
    } finally {
      stopwatch.stop();
      debugPrint('LOAD END ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _openAdCreditPage() async {
    debugPrint('[AdCredit][Admin] tap fired');
    debugPrint('[AdCredit][Admin] onPressed called');
    if (!mounted || _showCreditManagement || _isOpeningCreditManagement) {
      return;
    }
    setState(() {
      _isOpeningCreditManagement = true;
      _showCreditManagement = true;
      _creditScreenRenderLogged = false;
    });
    debugPrint('[AdCredit][Admin] open credit panel called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isOpeningCreditManagement = false;
      });
    });
  }

  void _closeAdCreditPage() {
    if (!mounted) return;
    setState(() {
      _showCreditManagement = false;
      _isOpeningCreditManagement = false;
      _creditScreenRenderLogged = false;
    });
  }

  _AdminAdsViewData _buildViewData(
    AdsDashboardSnapshot snapshot,
    List<AdMetrics> metrics,
  ) {
    debugPrint('start buildViewData');
    final metricsByCampaign = <String, AdMetrics>{};
    debugPrint('before metricsByCampaign loop');
    for (final campaign in snapshot.campaigns) {
      metricsByCampaign[campaign.id] = AdMetricsHelper.merge(
        metrics.where((item) => item.campaignId == campaign.id),
        campaignId: campaign.id,
      );
    }
    debugPrint('after metricsByCampaign loop');
    debugPrint('before row mapping');
    final campaignIds = snapshot.campaigns
        .map((campaign) => campaign.id)
        .toList(growable: false);
    debugPrint('after row mapping count=${campaignIds.length}');

    String topSeller = '-';
    double topSellerSpend = -1;
    snapshot.revenueOverview.sellerSpend.forEach((sellerId, amount) {
      if (amount > topSellerSpend) {
        topSellerSpend = amount;
        topSeller = sellerId;
      }
    });

    String topType = '-';
    double topTypeRevenue = -1;
    final typeRevenue = <String, double>{};
    for (final campaign in snapshot.campaigns) {
      final revenue =
          snapshot.revenueOverview.campaignRevenue[campaign.id] ?? 0;
      typeRevenue[campaign.type.dbValue] =
          (typeRevenue[campaign.type.dbValue] ?? 0) + revenue;
    }
    typeRevenue.forEach((type, revenue) {
      if (revenue > topTypeRevenue) {
        topTypeRevenue = revenue;
        topType = type;
      }
    });

    final viewData = _AdminAdsViewData(
      snapshot: snapshot,
      metricsByCampaign: metricsByCampaign,
      topSeller: topSeller,
      topRevenueType: topType,
    );
    debugPrint('end buildViewData');
    return viewData;
  }

  String _resolvedFilterValue(
    String value,
    List<DropdownMenuItem<String>> items,
  ) {
    final availableValues = items
        .map((item) => item.value)
        .whereType<String>()
        .toSet();
    return availableValues.contains(value) ? value : 'Tum';
  }

  String _fallbackText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? '-' : trimmed;
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Tarih yok';
    }
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  String _formatCampaignDate(AdCampaign campaign, {required bool isStart}) {
    final missingKey = isStart ? '_missing_starts_at' : '_missing_ends_at';
    if (campaign.metadata[missingKey] == true) {
      return 'Tarih yok';
    }
    return _formatDate(isStart ? campaign.startsAt : campaign.endsAt);
  }

  Widget _buildScrollableState({required Widget child}) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.all(widget.embedded ? 0 : 20),
      children: [child],
    );
  }

  Widget _buildBranchCard({
    required IconData icon,
    required String title,
    required String message,
    String actionLabel = 'Tekrar dene',
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return _buildScrollableState(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 16),
            Text(
              'Reklam merkezi yukleniyor...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Kampanyalar ve gelir ozeti hazirlaniyor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafeSection({
    required String label,
    required Widget Function() builder,
  }) {
    try {
      debugPrint('$label BUILD START');
      final widget = builder();
      debugPrint('$label BUILD END');
      return widget;
    } catch (error, stackTrace) {
      debugPrint('$label BUILD FAILED: $error');
      debugPrintStack(stackTrace: stackTrace);
      return _buildSectionFallback(label);
    }
  }

  Widget _buildSectionFallback(String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$label bolumu gecici olarak gosterilemiyor.',
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showCreditManagement) {
      if (!_creditScreenRenderLogged) {
        _creditScreenRenderLogged = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          debugPrint('[AdCredit][Admin] credit screen rendered');
        });
      }
      return _buildCreditManagementScreen();
    }
    return FutureBuilder<_AdminAdsViewData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.active) {
          return _buildLoadingState();
        }
        if (snapshot.hasError) {
          return _buildScrollableState(
            child: _buildBranchCard(
              icon: Icons.error_outline_rounded,
              title: 'Reklam merkezi yuklenemedi',
              message:
                  'Panel verileri alinirken bir sorun olustu.\n${snapshot.error}',
            ),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return _buildScrollableState(
            child: _buildBranchCard(
              icon: Icons.inbox_outlined,
              title: 'Reklam verisi bulunamadi',
              message:
                  'Panel acildi ancak gosterilecek veri donmedi. Biraz sonra tekrar deneyin.',
            ),
          );
        }
        debugPrint('SUCCESS UI ENTERED');
        final filtered = _filteredCampaigns(data.snapshot);
        final revenue = data.snapshot.revenueOverview;
        final pendingCount = _pendingReviewCount(data.snapshot);
        return ListView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.all(widget.embedded ? 0 : 20),
          children: [
            _buildSafeSection(
              label: 'HERO',
              builder: () => _buildHero(pendingCount),
            ),
            const SizedBox(height: 18),
            _buildSafeSection(
              label: 'REVENUE',
              builder: () => _buildRevenueOverview(revenue),
            ),
            const SizedBox(height: 12),
            _buildSafeSection(
              label: 'OPERATIONS',
              builder: () =>
                  _buildOperationsOverview(data, revenue, pendingCount),
            ),
            const SizedBox(height: 18),
            _buildSafeSection(label: 'FILTER', builder: _buildFilterBar),
            const SizedBox(height: 18),
            _buildSafeSection(
              label: 'TABLE',
              builder: () => _buildTable(data, filtered),
            ),
          ],
        );
      },
    );
  }

  AdsDashboardSnapshot _buildEmptySnapshot() {
    return AdsDashboardSnapshot(
      role: AdRole.admin,
      campaigns: const <AdCampaign>[],
      aggregateMetrics: AdMetrics(campaignId: 'all', date: DateTime.now()),
      insights: const [],
      healthScores: const [],
      revenueOverview: AdRevenueOverview(
        totalRevenue: 0,
        todayRevenue: 0,
        weekRevenue: 0,
        monthRevenue: 0,
        pendingPayments: 0,
        approvedPayments: 0,
        refundedPayments: 0,
        walletTopUps: 0,
        currency: 'TRY',
        generatedAt: DateTime.now(),
      ),
      reviews: const [],
      walletTransactions: const [],
      topPlacementResults: const [],
      generatedAt: DateTime.now(),
    );
  }

  Widget _buildHero(int pendingCount) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reklam Yonetimi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kampanya onaylarini, gelir takibini ve seller performansini tek merkezden yonetin.',
                  style: TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _heroPill(
                      icon: Icons.rule_folder_outlined,
                      label: '$pendingCount onay bekliyor',
                    ),
                    _heroPill(
                      icon: Icons.view_column_outlined,
                      label: 'Kompakt tablo gorunumu',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildHeroActionBar(),
        ],
      ),
    );
  }

  Widget _buildHeroActionBar() {
    debugPrint('[AdCredit][Admin] build action bar started');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAdCreditButton(),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Yenile'),
        ),
      ],
    );
  }

  Widget _buildAdCreditButton() {
    debugPrint(
      '[AdCredit][Admin] ad credit button built enabled=${!_isOpeningCreditManagement}',
    );
    return OutlinedButton.icon(
      onPressed: _isOpeningCreditManagement ? null : _openAdCreditPage,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0x33FFFFFF)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      icon: _isOpeningCreditManagement
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.qr_code_2_rounded),
      label: Text(_isOpeningCreditManagement ? 'Aciliyor' : 'Reklam kredisi'),
    );
  }

  Widget _heroPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditManagementScreen() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(widget.embedded ? 0 : 20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x040F172A),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _closeAdCreditPage,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Reklama don'),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reklam kredisi',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Olusturulan kredi kodlarini burada gorur, yeni batch uretir ve kullanim gecmisini izlersiniz.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const AdminAdCreditCodesPanel(),
      ],
    );
  }

  Widget _buildRevenueOverview(AdRevenueOverview revenue) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 248,
          child: RevenueCard(
            title: 'Toplam reklam geliri',
            amountLabel:
                '${revenue.totalRevenue.toStringAsFixed(0)} ${revenue.currency}',
            subtitle: 'Tum kampanya gelirleri',
            accent: const Color(0xFF16A34A),
          ),
        ),
        SizedBox(
          width: 248,
          child: RevenueCard(
            title: 'Bugun',
            amountLabel:
                '${revenue.todayRevenue.toStringAsFixed(0)} ${revenue.currency}',
            subtitle: 'Gunluk reklam geliri',
            accent: const Color(0xFF0EA5E9),
          ),
        ),
        SizedBox(
          width: 248,
          child: RevenueCard(
            title: 'Bu hafta',
            amountLabel:
                '${revenue.weekRevenue.toStringAsFixed(0)} ${revenue.currency}',
            subtitle: 'Haftalik reklam geliri',
            accent: const Color(0xFF2563EB),
          ),
        ),
        SizedBox(
          width: 248,
          child: RevenueCard(
            title: 'Bu ay',
            amountLabel:
                '${revenue.monthRevenue.toStringAsFixed(0)} ${revenue.currency}',
            subtitle: 'Aylik reklam geliri',
            accent: const Color(0xFF7C3AED),
          ),
        ),
      ],
    );
  }

  Widget _buildOperationsOverview(
    _AdminAdsViewData data,
    AdRevenueOverview revenue,
    int pendingCount,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 248,
          child: SummaryStatCard(
            title: 'Bekleyen reklam odemeleri',
            value:
                '${revenue.pendingPayments.toStringAsFixed(0)} ${revenue.currency}',
            subtitle: 'Odeme bekleyen hareketler',
            icon: Icons.pending_actions_outlined,
            accent: const Color(0xFFF59E0B),
          ),
        ),
        SizedBox(
          width: 248,
          child: SummaryStatCard(
            title: 'Onay bekleyen kampanya',
            value: pendingCount.toString(),
            subtitle: 'Inceleme kuyrugu',
            icon: Icons.rule_folder_outlined,
            accent: const Color(0xFFEA580C),
          ),
        ),
        SizedBox(
          width: 248,
          child: SummaryStatCard(
            title: 'En cok harcayan satici',
            value: data.topSeller,
            subtitle: 'Seller bazli spend',
            icon: Icons.person_outline_rounded,
            accent: const Color(0xFF0F766E),
          ),
        ),
        SizedBox(
          width: 248,
          child: SummaryStatCard(
            title: 'En cok gelir getiren tur',
            value: data.topRevenueType,
            subtitle: 'Tur bazli gelir',
            icon: Icons.auto_graph_rounded,
            accent: const Color(0xFF9333EA),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Kampanya, satici veya magaza ara',
              ),
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _resolvedFilterValue(_statusFilter, _kStatusItems),
              decoration: const InputDecoration(labelText: 'Reklam durumu'),
              items: _kStatusItems,
              onChanged: (value) =>
                  setState(() => _statusFilter = value ?? 'Tum'),
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _resolvedFilterValue(_reviewFilter, _kReviewItems),
              decoration: const InputDecoration(labelText: 'Onay durumu'),
              items: _kReviewItems,
              onChanged: (value) =>
                  setState(() => _reviewFilter = value ?? 'Tum'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(_AdminAdsViewData data, List<AdCampaign> campaigns) {
    debugPrint('TABLE BUILD START');
    final rows = campaigns
        .map((campaign) {
          final review = data.snapshot.reviews
              .where((item) => item.campaignId == campaign.id)
              .firstOrNull;
          return _AdminCampaignRow(
            campaign: campaign,
            metrics:
                data.metricsByCampaign[campaign.id] ??
                AdMetrics(campaignId: campaign.id, date: DateTime.now()),
            revenue:
                data.snapshot.revenueOverview.campaignRevenue[campaign.id] ?? 0,
            reviewLabel: _reviewLabelForCampaign(
              campaign,
              review?.status.dbValue,
            ),
          );
        })
        .toList(growable: false);
    final table = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kampanya tablosu',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${rows.length} kampanya goruntuleniyor. Onay bekleyen kampanyalar icin hizli aksiyonlar sag tarafta acik tutulur.',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_pendingReviewCount(data.snapshot)} bekleyen',
                  style: const TextStyle(
                    color: Color(0xFFEA580C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            _buildAdminEmptyState()
          else
            _buildSimpleCampaignTable(rows),
        ],
      ),
    );
    debugPrint('TABLE BUILD END');
    return table;
  }

  Widget _buildAdminEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.campaign_outlined, size: 42, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text(
            'Kampanya bulunamadi',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Filtreleri degistirerek veya aramayi temizleyerek tekrar deneyin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleCampaignTable(List<_AdminCampaignRow> rows) {
    const campaignWidth = 250.0;
    const typeWidth = 170.0;
    const audienceWidth = 190.0;
    const budgetWidth = 90.0;
    const spentWidth = 90.0;
    const revenueWidth = 90.0;
    const statusWidth = 132.0;
    const reviewWidth = 132.0;
    const dateWidth = 132.0;
    const actionsWidth = 250.0;
    const totalWidth =
        campaignWidth +
        typeWidth +
        audienceWidth +
        budgetWidth +
        spentWidth +
        revenueWidth +
        statusWidth +
        reviewWidth +
        dateWidth +
        actionsWidth;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : totalWidth;
        final tableWidth = minWidth > totalWidth ? minWidth : totalWidth;
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: tableWidth),
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  children: [
                    Container(
                      height: 52,
                      color: const Color(0xFFF8FAFC),
                      child: Row(
                        children: [
                          _tableHeaderCell('Kampanya', campaignWidth),
                          _tableHeaderCell('Tur / Hedef', typeWidth),
                          _tableHeaderCell('Hedefleme', audienceWidth),
                          _tableHeaderCell(
                            'Butce',
                            budgetWidth,
                            alignEnd: true,
                          ),
                          _tableHeaderCell('Harc.', spentWidth, alignEnd: true),
                          _tableHeaderCell(
                            'Gelir',
                            revenueWidth,
                            alignEnd: true,
                          ),
                          _tableHeaderCell('Reklam', statusWidth),
                          _tableHeaderCell('Onay', reviewWidth),
                          _tableHeaderCell('Tarih', dateWidth),
                          _tableHeaderCell('Aksiyonlar', actionsWidth),
                        ],
                      ),
                    ),
                    ...rows.map(_buildSimpleCampaignRow),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tableHeaderCell(String label, double width, {bool alignEnd = false}) {
    return Container(
      width: width,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSimpleCampaignRow(_AdminCampaignRow row) {
    const campaignWidth = 250.0;
    const typeWidth = 170.0;
    const audienceWidth = 190.0;
    const budgetWidth = 90.0;
    const spentWidth = 90.0;
    const revenueWidth = 90.0;
    const statusWidth = 132.0;
    const reviewWidth = 132.0;
    const dateWidth = 132.0;
    const actionsWidth = 250.0;

    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tableBodyCell(campaignWidth, _buildCampaignIdentityCell(row)),
            _tableBodyCell(typeWidth, _buildTypeObjectiveCell(row)),
            _tableBodyCell(
              audienceWidth,
              Text(
                (row.campaign.target?.categories ?? const []).isEmpty
                    ? '-'
                    : (row.campaign.target?.categories ?? const []).join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _tableBodyCell(
              budgetWidth,
              Text(row.campaign.totalBudget.toStringAsFixed(0)),
              alignEnd: true,
            ),
            _tableBodyCell(
              spentWidth,
              Text(row.campaign.spentAmount.toStringAsFixed(0)),
              alignEnd: true,
            ),
            _tableBodyCell(
              revenueWidth,
              Text(row.revenue.toStringAsFixed(0)),
              alignEnd: true,
            ),
            _tableBodyCell(
              statusWidth,
              StatusChip.fromStatus(row.campaign.status.dbValue),
            ),
            _tableBodyCell(reviewWidth, StatusChip.fromStatus(row.reviewLabel)),
            _tableBodyCell(
              dateWidth,
              Text(
                '${_formatCampaignDate(row.campaign, isStart: true)}\n${_formatCampaignDate(row.campaign, isStart: false)}',
              ),
            ),
            _tableBodyCell(actionsWidth, _buildAdminActions(row)),
          ],
        ),
      ),
    );
  }

  Widget _tableBodyCell(double width, Widget child, {bool alignEnd = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 13,
          height: 1.4,
        ),
        child: child,
      ),
    );
  }

  Widget _buildCampaignIdentityCell(_AdminCampaignRow row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _fallbackText(row.campaign.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Satici: ${_prettyName(_fallbackText(row.campaign.sellerId))}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        Text(
          'Magaza: ${_prettyName(_fallbackText(row.campaign.storeId))}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTypeObjectiveCell(_AdminCampaignRow row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _humanizeToken(row.campaign.type.dbValue),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _humanizeToken(row.campaign.objective.dbValue),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAdminActions(_AdminCampaignRow row) {
    final isProcessing = _processingCampaignIds.contains(row.campaign.id);
    if (isProcessing) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final isPending = _isPendingAdminApproval(row);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (isPending)
          FilledButton.tonalIcon(
            onPressed: () => _approve(row.campaign),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Onayla'),
          ),
        if (isPending)
          OutlinedButton.icon(
            onPressed: () => _reject(row.campaign),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Reddet'),
          ),
        if (!isPending)
          OutlinedButton.icon(
            onPressed: () => _openDetail(row.campaign),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Text('Detay'),
          ),
        CampaignActionMenu(
          isAdmin: true,
          onDetail: () => _openDetail(row.campaign),
          onApprove: () => _approve(row.campaign),
          onReject: () => _reject(row.campaign),
          onStop: () => _stop(row.campaign),
          onReviewAgain: () => _reviewAgain(row.campaign),
          onOpenSeller: () => _openSeller(row.campaign),
          onHistory: () => _showHistory(row.campaign),
        ),
      ],
    );
  }

  bool _isPendingAdminApproval(_AdminCampaignRow row) {
    return row.campaign.status == CampaignStatus.pendingReview ||
        row.reviewLabel == 'pending';
  }

  List<AdCampaign> _filteredCampaigns(AdsDashboardSnapshot snapshot) {
    final query = _searchController.text.trim().toLowerCase();
    return snapshot.campaigns
        .where((campaign) {
          final matchesQuery =
              query.isEmpty ||
              campaign.name.toLowerCase().contains(query) ||
              campaign.sellerId.toLowerCase().contains(query) ||
              (campaign.storeId ?? '').toLowerCase().contains(query);
          final matchesStatus =
              _statusFilter == 'Tum' ||
              campaign.status.dbValue == _statusFilter;
          final matchesReview =
              _reviewFilter == 'Tum' ||
              snapshot.reviews.any(
                (review) =>
                    review.campaignId == campaign.id &&
                    review.status.dbValue == _reviewFilter,
              );
          return matchesQuery && matchesStatus && matchesReview;
        })
        .toList(growable: false);
  }

  String _prettyName(String raw) {
    if (raw == '-') return raw;
    final sanitized = raw.trim();
    if (sanitized.isEmpty) return '-';
    final parts = sanitized
        .split('-')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.length < 2) return sanitized;
    return '${parts.first[0].toUpperCase()}${parts.first.substring(1)} ${parts.last}';
  }

  int _pendingReviewCount(AdsDashboardSnapshot snapshot) {
    return snapshot.campaigns
        .where((campaign) => campaign.status == CampaignStatus.pendingReview)
        .length;
  }

  String _reviewLabelForCampaign(AdCampaign campaign, String? rawReviewStatus) {
    final resolvedStatus = rawReviewStatus?.trim();
    if ((resolvedStatus ?? '').isNotEmpty) {
      return resolvedStatus ?? 'pending';
    }
    if (campaign.status == CampaignStatus.pendingReview) {
      return 'pending';
    }
    if (campaign.status == CampaignStatus.rejected) {
      return 'rejected';
    }
    if (campaign.status == CampaignStatus.draft) {
      return 'changes_requested';
    }
    return 'approved';
  }

  String _humanizeToken(String value) {
    if (value.trim().isEmpty) return '-';
    return value
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  Future<void> _openDetail(AdCampaign campaign) async {
    await showDialog<void>(
      context: context,
      builder: (context) => CampaignDetailDialog(
        campaign: campaign,
        isAdmin: true,
        onChanged: _refresh,
      ),
    );
  }

  Future<void> _approve(AdCampaign campaign) async {
    await _runAdminAction(
      campaign.id,
      successMessage: '${campaign.name} onaylandi.',
      action: () => _reviewService.approveCampaign(
        campaignId: campaign.id,
        sellerId: campaign.sellerId,
        reviewerId: 'admin-panel',
      ),
    );
  }

  Future<void> _reject(AdCampaign campaign) async {
    await _runAdminAction(
      campaign.id,
      successMessage: '${campaign.name} reddedildi.',
      action: () => _reviewService.rejectCampaign(
        campaignId: campaign.id,
        sellerId: campaign.sellerId,
        reviewerId: 'admin-panel',
        reasons: const ['Admin tarafinda reddedildi'],
      ),
    );
  }

  Future<void> _stop(AdCampaign campaign) async {
    await _runAdminAction(
      campaign.id,
      successMessage: '${campaign.name} durduruldu.',
      action: () => _campaignService.stopCampaign(campaign.id),
    );
  }

  Future<void> _reviewAgain(AdCampaign campaign) async {
    await _runAdminAction(
      campaign.id,
      successMessage: '${campaign.name} tekrar incelemeye alindi.',
      action: () => _reviewService.requestChanges(
        campaignId: campaign.id,
        sellerId: campaign.sellerId,
        reviewerId: 'admin-panel',
        reasons: const ['Tekrar incelemeye alindi'],
      ),
    );
  }

  Future<void> _runAdminAction(
    String campaignId, {
    required Future<dynamic> Function() action,
    required String successMessage,
  }) async {
    if (_processingCampaignIds.contains(campaignId)) {
      return;
    }
    setState(() => _processingCampaignIds.add(campaignId));
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Islem tamamlanamadi: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processingCampaignIds.remove(campaignId));
      }
    }
  }

  void _openSeller(AdCampaign campaign) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Satici: ${campaign.sellerId} • Magaza: ${campaign.storeId ?? '-'}',
        ),
      ),
    );
  }

  void _showHistory(AdCampaign campaign) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${campaign.name} gecmis kayitlari panelde listeleniyor.',
        ),
      ),
    );
  }
}

class _AdminAdsViewData {
  const _AdminAdsViewData({
    required this.snapshot,
    required this.metricsByCampaign,
    required this.topSeller,
    required this.topRevenueType,
  });

  final AdsDashboardSnapshot snapshot;
  final Map<String, AdMetrics> metricsByCampaign;
  final String topSeller;
  final String topRevenueType;
}

class _AdminCampaignRow {
  const _AdminCampaignRow({
    required this.campaign,
    required this.metrics,
    required this.revenue,
    required this.reviewLabel,
  });

  final AdCampaign campaign;
  final AdMetrics metrics;
  final double revenue;
  final String reviewLabel;
}
