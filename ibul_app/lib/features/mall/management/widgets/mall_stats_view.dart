import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../models/mall_ops.dart';
import '../services/mall_operations_repository.dart';
import 'mall_panel_kit.dart';

const mallStatsEmptyMessage = 'Henüz yeterli veri yok.';

/// Only real `mall_analytics_events` counts. No sample or estimated values.
class MallStatsView extends StatefulWidget {
  const MallStatsView({super.key, required this.mallId, required this.operations});

  final String mallId;
  final MallOperationsRepository operations;

  @override
  State<MallStatsView> createState() => _MallStatsViewState();
}

class _MallStatsViewState extends State<MallStatsView> {
  var _days = 30;
  late Future<MallStats> _stats = widget.operations.stats(widget.mallId, days: _days);

  static const _icons = <String, IconData>{
    'mall_view': Icons.visibility_outlined,
    'map_open': Icons.map_outlined,
    'store_profile_click': Icons.storefront_outlined,
    'directions_click': Icons.directions_outlined,
    'campaign_view': Icons.local_offer_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MallStats>(
      future: _stats,
      builder: (context, snapshot) {
        final stats = snapshot.data;
        return MallPage(children: [
          MallPageTitle(
            title: 'İstatistikler',
            subtitle: 'Müşterilerin AVM sayfanız ve haritanızla etkileşimi.',
            actions: [
              MallSegmented(
                items: const {'7': '7 gün', '30': '30 gün', '90': '90 gün'},
                selected: '$_days',
                onChanged: (value) => setState(() {
                  _days = int.parse(value);
                  _stats = widget.operations.stats(widget.mallId, days: _days);
                }),
              ),
            ],
          ),
          if (snapshot.connectionState != ConnectionState.done)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (snapshot.hasError)
            MallLoadError('İstatistikler yüklenemedi.', onRetry: () => setState(() {
                  _stats = widget.operations.stats(widget.mallId, days: _days);
                }))
          else ...[
            MallGrid(minTileWidth: 220, children: [
              for (final entry in MallStats.events.entries)
                MallKpiCard(
                  label: entry.value,
                  value: '${stats!.totals[entry.key] ?? 0}',
                  icon: _icons[entry.key]!,
                ),
            ]),
            if (stats!.isEmpty)
              const MallEmptyState(
                icon: Icons.insights_outlined,
                title: mallStatsEmptyMessage,
                message: 'AVM yayına alındıktan sonra müşteri etkileşimleri burada gerçek verilerle görünür.',
              )
            else
              MallCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MallCardTitle('Günlük etkileşim', trailing: Text('Toplam ${stats.total}')),
                    MallDailyBars(points: stats.daily),
                  ],
                ),
              ),
          ],
        ]);
      },
    );
  }
}

class MallDailyBars extends StatelessWidget {
  const MallDailyBars({super.key, required this.points, this.height = 200});

  final List<({DateTime day, int count})> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(painter: _BarsPainter(points), child: const SizedBox.expand()),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.points);

  final List<({DateTime day, int count})> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maxCount = points.fold<int>(1, (max, point) => point.count > max ? point.count : max);
    final chartHeight = size.height - 22;
    final slot = size.width / points.length;
    final barWidth = (slot * 0.6).clamp(2.0, 28.0);
    final paint = Paint()..color = AppColors.primary;
    final grid = Paint()
      ..color = MallTokens.border
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, chartHeight), Offset(size.width, chartHeight), grid);
    final labelEvery = (points.length / 6).ceil().clamp(1, 1000);
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final barHeight = point.count / maxCount * (chartHeight - 8);
      final left = i * slot + (slot - barWidth) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, chartHeight - barHeight, barWidth, barHeight),
          const Radius.circular(4),
        ),
        paint,
      );
      if (i % labelEvery == 0) {
        final text = TextPainter(
          text: TextSpan(
            text: '${point.day.day}.${point.day.month}',
            style: const TextStyle(fontSize: 10, color: MallTokens.muted),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, Offset(i * slot + (slot - text.width) / 2, chartHeight + 6));
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) => oldDelegate.points != points;
}
