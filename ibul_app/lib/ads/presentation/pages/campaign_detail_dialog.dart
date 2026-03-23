import 'package:flutter/material.dart';

import '../../helpers/ad_metrics_helper.dart';
import '../../models/ad_campaign.dart';
import '../../models/ad_health_score.dart';
import '../../models/ad_insight.dart';
import '../../models/ad_metrics.dart';
import '../../models/campaign_review.dart';
import '../../services/ad_metrics_service.dart';
import '../../services/campaign_review_service.dart';
import '../../services/campaign_service.dart';
import '../../services/ad_revenue_service.dart';
import '../widgets/admin_approval_action_bar.dart';
import '../widgets/budget_progress_bar.dart';
import '../widgets/funnel_widget.dart';
import '../widgets/health_score_badge.dart';
import '../widgets/insight_card.dart';
import '../widgets/preview_card.dart';
import '../widgets/status_chip.dart';

class CampaignDetailDialog extends StatefulWidget {
  const CampaignDetailDialog({
    required this.campaign,
    this.isAdmin = false,
    this.onChanged,
    super.key,
  });

  final AdCampaign campaign;
  final bool isAdmin;
  final VoidCallback? onChanged;

  @override
  State<CampaignDetailDialog> createState() => _CampaignDetailDialogState();
}

class _CampaignDetailDialogState extends State<CampaignDetailDialog> {
  final AdMetricsService _metricsService = AdMetricsService();
  final AdRevenueService _revenueService = AdRevenueService();
  final CampaignReviewService _reviewService = CampaignReviewService();
  final CampaignService _campaignService = CampaignService();

  late Future<_CampaignDetailSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CampaignDetailSnapshot> _load() async {
    final metrics = await _metricsService.getDailyMetrics(
      campaignIds: [widget.campaign.id],
      from: DateTime.now().subtract(const Duration(days: 30)),
    );
    final health = await _metricsService.getHealthScore(
      campaignId: widget.campaign.id,
      isPendingReview: widget.campaign.status.name == 'pendingReview',
    );
    final insights = await _metricsService.getInsights(
      campaignId: widget.campaign.id,
    );
    final reviews = await _reviewService.getCampaignReviews(widget.campaign.id);
    final revenueOverview = await _revenueService.getRevenueOverview(
      sellerId: widget.isAdmin ? null : widget.campaign.sellerId,
    );
    final campaignRevenue =
        revenueOverview.campaignRevenue[widget.campaign.id] ?? 0;
    return _CampaignDetailSnapshot(
      metrics: metrics,
      aggregate: AdMetricsHelper.merge(metrics, campaignId: widget.campaign.id),
      health: health,
      insights: insights,
      reviews: reviews,
      campaignRevenue: campaignRevenue,
      revenueCurrency: revenueOverview.currency,
    );
  }

  Future<void> _approve() async {
    await _reviewService.approveCampaign(
      campaignId: widget.campaign.id,
      sellerId: widget.campaign.sellerId,
      reviewerId: 'admin-panel',
      note: 'Admin panel onayi',
    );
    widget.onChanged?.call();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _reject() async {
    await _reviewService.rejectCampaign(
      campaignId: widget.campaign.id,
      sellerId: widget.campaign.sellerId,
      reviewerId: 'admin-panel',
      reasons: const ['Kreatif veya hedefleme yeniden duzenlenmeli'],
      note: 'Manual admin rejection',
    );
    widget.onChanged?.call();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _stop() async {
    await _campaignService.stopCampaign(widget.campaign.id);
    widget.onChanged?.call();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _reviewAgain() async {
    await _reviewService.requestChanges(
      campaignId: widget.campaign.id,
      sellerId: widget.campaign.sellerId,
      reviewerId: 'admin-panel',
      reasons: const ['Yeniden inceleme talebi'],
      note: 'Tekrar incelemeye alindi',
    );
    widget.onChanged?.call();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  String _formatCampaignDate(bool isStart) {
    final missingKey = isStart ? '_missing_starts_at' : '_missing_ends_at';
    if (widget.campaign.metadata[missingKey] == true) {
      return 'Tarih yok';
    }
    final value = isStart ? widget.campaign.startsAt : widget.campaign.endsAt;
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 820),
        child: FutureBuilder<_CampaignDetailSnapshot>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(
                child: Text('Kampanya detaylari yuklenemedi.'),
              );
            }
            final data = snapshot.data;
            if (data == null) {
              return const Center(
                child: Text('Kampanya detaylari yuklenemedi.'),
              );
            }
            final aggregate = data.aggregate;
            final funnelSteps = [
              AdsFunnelStep(
                label: 'Impression',
                value: aggregate.impressions,
                color: const Color(0xFF1D4ED8),
              ),
              AdsFunnelStep(
                label: 'Click',
                value: aggregate.clicks,
                color: const Color(0xFF0EA5E9),
              ),
              AdsFunnelStep(
                label: 'Product view',
                value: aggregate.detailViews,
                color: const Color(0xFF8B5CF6),
              ),
              AdsFunnelStep(
                label: 'Add to cart',
                value: aggregate.addToCarts,
                color: const Color(0xFFF59E0B),
              ),
              AdsFunnelStep(
                label: 'Checkout',
                value: aggregate.conversions,
                color: const Color(0xFFFB7185),
              ),
              AdsFunnelStep(
                label: 'Order',
                value: aggregate.orders,
                color: const Color(0xFF16A34A),
              ),
            ];

            return Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              appBar: AppBar(
                title: Text(widget.campaign.name),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: HealthScoreBadge(score: data.health.score),
                    ),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip.fromStatus(widget.campaign.status.dbValue),
                        StatusChip(
                          label: widget.campaign.type.dbValue,
                          backgroundColor: const Color(0xFFE0F2FE),
                          foregroundColor: const Color(0xFF0369A1),
                          icon: Icons.ads_click_outlined,
                        ),
                        if (widget.isAdmin)
                          StatusChip(
                            label:
                                'Gelir ${data.campaignRevenue.toStringAsFixed(0)} ${data.revenueCurrency}',
                            backgroundColor: const Color(0xFFDCFCE7),
                            foregroundColor: const Color(0xFF166534),
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 980;
                        final overview = _buildOverviewCard(data, aggregate);
                        final preview = _buildPreviewCard();
                        if (!isWide) {
                          return Column(
                            children: [
                              overview,
                              const SizedBox(height: 16),
                              preview,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: overview),
                            const SizedBox(width: 16),
                            Expanded(flex: 4, child: preview),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 980;
                        final funnel = AdsFunnelWidget(
                          steps: funnelSteps,
                          title: 'Performans funnel',
                        );
                        final insights = _buildInsightCardList(data.insights);
                        if (!isWide) {
                          return Column(
                            children: [
                              funnel,
                              const SizedBox(height: 16),
                              insights,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: funnel),
                            const SizedBox(width: 16),
                            Expanded(flex: 5, child: insights),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    _buildMetricsAndHistory(data, aggregate),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOverviewCard(_CampaignDetailSnapshot data, AdMetrics aggregate) {
    final target = widget.campaign.target;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kampanya ozeti',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _detailRow('Hedef', widget.campaign.objective.dbValue),
          _detailRow('Reklam turu', widget.campaign.type.dbValue),
          _detailRow(
            'Butce',
            '${widget.campaign.dailyBudget.toStringAsFixed(0)} / ${widget.campaign.totalBudget.toStringAsFixed(0)} ${widget.campaign.currency}',
          ),
          const SizedBox(height: 10),
          BudgetProgressBar(
            spent: widget.campaign.spentAmount,
            total: widget.campaign.totalBudget,
            currency: widget.campaign.currency,
          ),
          const SizedBox(height: 12),
          _detailRow(
            'Kalan butce',
            widget.campaign.remainingBalance.toStringAsFixed(0),
          ),
          _detailRow('CTR', '%${(aggregate.ctr * 100).toStringAsFixed(2)}'),
          _detailRow('CPC', aggregate.cpc.toStringAsFixed(2)),
          _detailRow('CPM', aggregate.cpm.toStringAsFixed(2)),
          _detailRow('Conversion', aggregate.conversions.toString()),
          _detailRow(
            'Baslangic',
            _formatCampaignDate(true),
          ),
          _detailRow(
            'Bitis',
            _formatCampaignDate(false),
          ),
          _detailRow(
            'Hedef kitle',
            (target?.categories ?? const []).isEmpty
                ? '-'
                : (target?.categories ?? const []).join(', '),
          ),
          _detailRow(
            'Placement',
            (target?.placements ?? const [])
                .map((item) => item.dbValue)
                .join(', '),
          ),
          _detailRow(
            'Teklif / kupon',
            widget.campaign.metadata['coupon_code']?.toString().isNotEmpty ==
                    true
                ? '${widget.campaign.metadata['coupon_code']} • ${widget.campaign.metadata['offer_note'] ?? '-'}'
                : (widget.campaign.metadata['offer_note']?.toString() ?? '-'),
          ),
          _detailRow(
            'Yayin plani',
            widget.campaign.metadata['time_plan']?.toString() ?? '-',
          ),
          _detailRow(
            'A/B test',
            widget.campaign.abTestEnabled
                ? '${widget.campaign.abTestVariants.length} varyant'
                : 'Kapali',
          ),
          if (widget.isAdmin) ...[
            _detailRow('Satici', widget.campaign.sellerId),
            _detailRow('Magaza', widget.campaign.storeId ?? '-'),
            _detailRow(
              'Gelir',
              '${data.campaignRevenue.toStringAsFixed(0)} ${data.revenueCurrency}',
            ),
            _detailRow(
              'Frequency cap',
              '${widget.campaign.frequencyCapPerUser} / gun',
            ),
            _detailRow(
              'Geofence',
              target?.radiusMeters == null ? '-' : '${target?.radiusMeters} m',
            ),
          ],
          if (widget.isAdmin) ...[
            const SizedBox(height: 16),
            AdminApprovalActionBar(
              onApprove: _approve,
              onReject: _reject,
              onStop: _stop,
              onReviewAgain: _reviewAgain,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final asset = widget.campaign.assets.firstOrNull;
    return AdsPreviewCard(
      title: asset?.title?.isNotEmpty == true
          ? asset?.title ?? widget.campaign.name
          : widget.campaign.name,
      subtitle: asset?.subtitle?.isNotEmpty == true
          ? asset?.subtitle ?? (widget.campaign.description ?? '-')
          : (widget.campaign.description ?? 'Reklam kreatifi onizlemesi'),
      badge: widget.campaign.type.dbValue,
      imageUrl: asset?.mediaUrl,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deep link: ${asset?.deepLink ?? '-'}',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            'Entity: ${asset?.entityId ?? '-'}',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCardList(List<AdInsight> insights) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Oneriler',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          ...insights.take(4).map((insight) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InsightCard(
                title: insight.title,
                description: insight.description,
                severity: insight.severity,
                actionLabel: insight.actionLabel,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMetricsAndHistory(
    _CampaignDetailSnapshot data,
    AdMetrics aggregate,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performans ve gecmis',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricPill('Impression', aggregate.impressions.toString()),
              _metricPill('Click', aggregate.clicks.toString()),
              _metricPill('Product View', aggregate.detailViews.toString()),
              _metricPill('Order', aggregate.orders.toString()),
              _metricPill('ROAS', aggregate.roas.toStringAsFixed(2)),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Admin notlari / review gecmisi',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (data.reviews.isEmpty)
            const Text(
              'Kayitli review yok.',
              style: TextStyle(color: Color(0xFF64748B)),
            )
          else
            ...data.reviews.map((review) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: StatusChip.fromStatus(review.status.dbValue),
                title: Text(review.note ?? review.status.dbValue),
                subtitle: Text(review.reasons.join(', ')),
                trailing: Text(review.createdAt.toString().split('.').first),
              );
            }),
        ],
      ),
    );
  }

  Widget _metricPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    final displayValue = value.trim().isEmpty ? '-' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignDetailSnapshot {
  const _CampaignDetailSnapshot({
    required this.metrics,
    required this.aggregate,
    required this.health,
    required this.insights,
    required this.reviews,
    required this.campaignRevenue,
    required this.revenueCurrency,
  });

  final List<AdMetrics> metrics;
  final AdMetrics aggregate;
  final AdHealthScore health;
  final List<AdInsight> insights;
  final List<CampaignReview> reviews;
  final double campaignRevenue;
  final String revenueCurrency;
}
