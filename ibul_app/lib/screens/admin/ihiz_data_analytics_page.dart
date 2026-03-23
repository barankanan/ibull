import 'package:flutter/material.dart';

import '../../services/admin_service.dart';

class IhizDataAnalyticsPage extends StatefulWidget {
  const IhizDataAnalyticsPage({super.key});

  @override
  State<IhizDataAnalyticsPage> createState() => _IhizDataAnalyticsPageState();
}

class _IhizDataAnalyticsPageState extends State<IhizDataAnalyticsPage> {
  final AdminService _adminService = AdminService();
  late Future<AdminIhizSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _adminService.getIhizOperationsSnapshot();
  }

  void _refresh() {
    setState(() {
      _snapshotFuture = _adminService.getIhizOperationsSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: FutureBuilder<AdminIhizSnapshot>(
            future: _snapshotFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _buildError(snapshot.error);
              }
              final data = snapshot.data;
              if (data == null) {
                return _buildError('IHIZ veri snapshot bos dondu.');
              }
              return _buildBody(data);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'IHIZ Veri Merkezi',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'IHIZ operasyon akisini, durum dagilimini ve takip kalitesini tek gorunumde inceleyin.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Yenile'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'IHIZ veri paneli acilamadi',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF991B1B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AdminIhizSnapshot data) {
    final timeline = _buildTimelineRows(data.recentShipments);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(data),
          const SizedBox(height: 14),
          _buildKpiRow(data),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1100;
              final status = _buildStatusDistributionCard(data);
              final hours = _buildHourlyFlowCard(timeline);
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: status),
                    const SizedBox(width: 12),
                    Expanded(child: hours),
                  ],
                );
              }
              return Column(
                children: [status, const SizedBox(height: 12), hours],
              );
            },
          ),
          const SizedBox(height: 14),
          _buildCourierSummaryCard(data.recentShipments),
          const SizedBox(height: 14),
          _buildRecentShipmentsCard(data.recentShipments),
        ],
      ),
    );
  }

  Widget _buildHero(AdminIhizSnapshot data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'IHIZ Veri Ozeti',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${data.windowLabel} icinde toplam ${_compact(data.totalIhizShipments)} IHIZ gonderisi izlendi.',
            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroPill('Aktif Dagitim', _compact(data.inTransitCount)),
              _buildHeroPill(
                'Takip Kapsamasi',
                _percent(data.trackingCoverage),
              ),
              _buildHeroPill('IHIZ Payi', _percent(data.ihizShareRatio)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Color(0xFFBFDBFE),
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(AdminIhizSnapshot data) {
    final kpis = [
      _IhizKpi(
        'Havuz Bekleyen',
        _compact(data.readyPoolCount),
        const Color(0xFF0EA5E9),
      ),
      _IhizKpi(
        'Yolda / Dagitim',
        _compact(data.inTransitCount),
        const Color(0xFF7C3AED),
      ),
      _IhizKpi(
        '24 Saat Teslim',
        _compact(data.delivered24hCount),
        const Color(0xFF059669),
      ),
      _IhizKpi('Sorunlu', _compact(data.problemCount), const Color(0xFFDC2626)),
      _IhizKpi(
        '48 Saat Ustunde',
        _compact(data.delayedOpenCount),
        const Color(0xFFB45309),
      ),
      _IhizKpi(
        'Sube Transferi',
        _compact(data.branchTransferCount),
        const Color(0xFF0F766E),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 1200
            ? (constraints.maxWidth - 20) / 3
            : constraints.maxWidth > 760
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kpis
              .map((item) {
                return SizedBox(width: width, child: _buildKpiCard(item));
              })
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildKpiCard(_IhizKpi item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 38,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: item.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDistributionCard(AdminIhizSnapshot data) {
    final total = data.totalIhizShipments <= 0 ? 1 : data.totalIhizShipments;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Durum Dagilimi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          if (data.statusBreakdown.isEmpty)
            const Text(
              'Durum dagilimi icin veri yok.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            )
          else
            ...data.statusBreakdown.map((slice) {
              final ratio = (slice.value / total).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            slice.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        Text(
                          '${slice.value}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: ratio,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF2563EB),
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

  Widget _buildHourlyFlowCard(List<_HourBin> timeline) {
    final maxValue = timeline.fold<int>(1, (p, e) => e.count > p ? e.count : p);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saatlik Akis (Son Kayitlar)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          if (timeline.isEmpty)
            const Text(
              'Saatlik akis icin veri yok.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            )
          else
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: timeline
                    .map((bin) {
                      final ratio = bin.count / maxValue;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${bin.count}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 100 * (ratio <= 0 ? 0.05 : ratio),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF60A5FA),
                                      Color(0xFF1D4ED8),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                bin.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCourierSummaryCard(List<AdminIhizShipment> items) {
    final grouped = <String, List<AdminIhizShipment>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.cargoCompany, () => []).add(item);
    }
    final rows =
        grouped.entries
            .map((entry) {
              final shipments = entry.value;
              final tracked = shipments.where((e) => e.hasTracking).length;
              final ratio = shipments.isEmpty
                  ? 0.0
                  : tracked / shipments.length;
              return _CourierSummaryRow(
                company: entry.key,
                count: shipments.length,
                trackingRatio: ratio,
              );
            })
            .toList(growable: false)
          ..sort((a, b) => b.count.compareTo(a.count));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kurye Sirket Dagilimi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text(
              'Kurye dagilimi icin veri yok.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            )
          else
            ...rows.take(5).map((row) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.company,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Text(
                      '${row.count} gonderi',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Takip: ${_percent(row.trackingRatio)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w700,
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

  Widget _buildRecentShipmentsCard(List<AdminIhizShipment> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Son IHIZ Gonderileri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text(
              'Gonderi kaydi bulunamadi.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            )
          else
            ...items.take(10).map((item) {
              final color = _statusColor(item.statusLabel);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 18, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.storeName} - ${item.productName}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.cargoCompany} | ${_formatDate(item.createdAt)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
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

  List<_HourBin> _buildTimelineRows(List<AdminIhizShipment> items) {
    final now = DateTime.now();
    final labels = ['-18s', '-15s', '-12s', '-9s', '-6s', '-3s', 'Simdi'];
    final bins = List<_HourBin>.generate(
      labels.length,
      (index) => _HourBin(label: labels[index], count: 0),
    );
    if (items.isEmpty) return bins;

    for (final item in items) {
      final created = item.createdAt?.toLocal();
      if (created == null) continue;
      final diffHours = now.difference(created).inHours;
      final bucket = diffHours ~/ 3;
      final reversed = (labels.length - 1) - bucket;
      if (reversed >= 0 && reversed < bins.length) {
        bins[reversed] = _HourBin(
          label: bins[reversed].label,
          count: bins[reversed].count + 1,
        );
      }
    }
    return bins;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Teslim edildi':
        return const Color(0xFF16A34A);
      case 'Dagitimda':
      case 'Yolda':
        return const Color(0xFF2563EB);
      case 'Hazirlandi':
      case 'Hazirlaniyor':
        return const Color(0xFFB45309);
      case 'Sorunlu / Iade':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }

  String _percent(double ratio) => '%${(ratio * 100).toStringAsFixed(1)}';

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }
}

class _IhizKpi {
  const _IhizKpi(this.title, this.value, this.color);

  final String title;
  final String value;
  final Color color;
}

class _HourBin {
  const _HourBin({required this.label, required this.count});

  final String label;
  final int count;
}

class _CourierSummaryRow {
  const _CourierSummaryRow({
    required this.company,
    required this.count,
    required this.trackingRatio,
  });

  final String company;
  final int count;
  final double trackingRatio;
}
