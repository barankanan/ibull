import 'package:flutter/material.dart';

import '../../models/ads_dashboard_snapshot.dart';

class AdsDashboardShell extends StatelessWidget {
  const AdsDashboardShell({
    required this.snapshot,
    required this.title,
    required this.subtitle,
    this.showWallet = false,
    this.showReviews = false,
    super.key,
  });

  final AdsDashboardSnapshot snapshot;
  final String title;
  final String subtitle;
  final bool showWallet;
  final bool showReviews;

  @override
  Widget build(BuildContext context) {
    final revenue = snapshot.revenueOverview;
    final balance = snapshot.walletTransactions.isEmpty
        ? 0.0
        : snapshot.walletTransactions.first.balanceAfter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final cardWidth = isWide ? (constraints.maxWidth - 48) / 4 : 280.0;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.84),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(
                  width: cardWidth,
                  title: 'Toplam reklam geliri',
                  value:
                      '${revenue.totalRevenue.toStringAsFixed(0)} ${revenue.currency}',
                  subtitle: 'Tum kampanyalar',
                ),
                _StatCard(
                  width: cardWidth,
                  title: 'Bugun',
                  value:
                      '${revenue.todayRevenue.toStringAsFixed(0)} ${revenue.currency}',
                  subtitle: 'Gunluk reklam geliri',
                ),
                _StatCard(
                  width: cardWidth,
                  title: 'Bu ay',
                  value:
                      '${revenue.monthRevenue.toStringAsFixed(0)} ${revenue.currency}',
                  subtitle: 'Aylik reklam geliri',
                ),
                _StatCard(
                  width: cardWidth,
                  title: 'Bekleyen odemeler',
                  value:
                      '${revenue.pendingPayments.toStringAsFixed(0)} ${revenue.currency}',
                  subtitle: 'Review veya odeme bekleyenler',
                ),
                if (showWallet)
                  _StatCard(
                    width: cardWidth,
                    title: 'Reklam bakiyesi',
                    value: '${balance.toStringAsFixed(0)} ${revenue.currency}',
                    subtitle: 'Seller wallet',
                  ),
                _StatCard(
                  width: cardWidth,
                  title: 'Aktif kampanya',
                  value: snapshot.campaigns.length.toString(),
                  subtitle: 'Dashboard kapsamindaki kampanyalar',
                ),
                _StatCard(
                  width: cardWidth,
                  title: 'Impression',
                  value: snapshot.aggregateMetrics.impressions.toString(),
                  subtitle: 'Son 30 gun',
                ),
                _StatCard(
                  width: cardWidth,
                  title: 'Siparis / donusum',
                  value:
                      '${snapshot.aggregateMetrics.orders} / ${snapshot.aggregateMetrics.conversions}',
                  subtitle: 'Son 30 gun',
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _SectionCard(
                      title: 'Kampanyalar',
                      child: Column(
                        children: snapshot.campaigns
                            .map(
                              (campaign) => _CampaignTile(
                                name: campaign.name,
                                status: campaign.status.dbValue,
                                budget: campaign.totalBudget,
                                spent: campaign.spentAmount,
                                currency: campaign.currency,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _SectionCard(
                      title: 'Ic goruler',
                      child: Column(
                        children: snapshot.insights
                            .take(6)
                            .map((insight) {
                              return _InsightTile(
                                title: insight.title,
                                description: insight.actionLabel,
                                severity: insight.severity,
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              _SectionCard(
                title: 'Kampanyalar',
                child: Column(
                  children: snapshot.campaigns
                      .map(
                        (campaign) => _CampaignTile(
                          name: campaign.name,
                          status: campaign.status.dbValue,
                          budget: campaign.totalBudget,
                          spent: campaign.spentAmount,
                          currency: campaign.currency,
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Ic goruler',
                child: Column(
                  children: snapshot.insights
                      .take(6)
                      .map((insight) {
                        return _InsightTile(
                          title: insight.title,
                          description: insight.actionLabel,
                          severity: insight.severity,
                        );
                      })
                      .toList(growable: false),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _SectionCard(
              title: showReviews ? 'Review kuyurugu' : 'Top placements',
              child: Column(
                children: showReviews
                    ? snapshot.reviews
                          .take(8)
                          .map((review) {
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.rule_folder_outlined),
                              title: Text(review.campaignId),
                              subtitle: Text(
                                review.note ?? review.status.dbValue,
                              ),
                              trailing: Text(review.status.dbValue),
                            );
                          })
                          .toList(growable: false)
                    : snapshot.topPlacementResults
                          .take(8)
                          .map((item) {
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.ads_click_outlined),
                              title: Text(
                                item.metadata['campaign_name']?.toString() ??
                                    item.campaignId,
                              ),
                              subtitle: Text(item.reason),
                              trailing: Text(item.score.toStringAsFixed(2)),
                            );
                          })
                          .toList(growable: false),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final double width;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _CampaignTile extends StatelessWidget {
  const _CampaignTile({
    required this.name,
    required this.status,
    required this.budget,
    required this.spent,
    required this.currency,
  });

  final String name;
  final String status;
  final double budget;
  final double spent;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final progress = budget <= 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(status),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 6),
          Text(
            '${spent.toStringAsFixed(0)} / ${budget.toStringAsFixed(0)} $currency',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.title,
    required this.description,
    required this.severity,
  });

  final String title;
  final String description;
  final String severity;

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      'critical' => const Color(0xFFDC2626),
      'watch' => const Color(0xFFF59E0B),
      _ => const Color(0xFF16A34A),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.insights_outlined, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
