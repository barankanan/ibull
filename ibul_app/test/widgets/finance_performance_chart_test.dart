import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ibul_app/features/seller/finance/helpers/finance_chart_helpers.dart';
import 'package:ibul_app/features/seller/finance/models/finance_models.dart';
import 'package:ibul_app/features/seller/finance/widgets/dashboard/chart/finance_range_selector.dart';
import 'package:ibul_app/features/seller/finance/widgets/dashboard/chart/finance_performance_line_chart.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  group('finance chart helpers', () {
    test('formatFinanceAxisLabel kısa TL formatı', () {
      expect(formatFinanceAxisLabel(0), '₺0');
      expect(formatFinanceAxisLabel(5400), '₺5K');
      expect(formatFinanceAxisLabel(25000000), '₺25.0M');
      expect(formatFinanceAxisLabel(140000000000), '₺140.0B');
    });

    test('buildFinancePerformanceChartPoints gelir/gider/maaş/likidite üretir', () {
      final daily = [
        DailyFinanceTrendPoint(
          date: DateTime(2026, 6, 28),
          income: 1000,
          expense: 200,
        ),
        DailyFinanceTrendPoint(
          date: DateTime(2026, 6, 29),
          income: 1500,
          expense: 300,
        ),
      ];
      final points = buildFinancePerformanceChartPoints(
        dailyPoints: daily,
        range: FinancePerformanceRange.days7,
        monthSalaryLoad: 30000,
      );
      expect(points, hasLength(2));
      expect(points.first.income, 1000);
      expect(points.first.expense, 200);
      expect(points.first.salaryLoadDaily, 15000);
      expect(points.first.liquidityCumulative, 800);
      expect(points.last.liquidityCumulative, 2000);
    });

    test('toggleFinanceChartSeries en az bir seri aktif kalır', () {
      var enabled = {FinanceChartSeriesId.income};
      final next = toggleFinanceChartSeries(
        enabled: enabled,
        id: FinanceChartSeriesId.income,
      );
      expect(next, enabled);
    });

    test('filterFinanceChartSeries pasif serileri çıkarır', () {
      final all = defaultFinanceChartSeries();
      final filtered = filterFinanceChartSeries(
        all: all,
        enabled: {FinanceChartSeriesId.income, FinanceChartSeriesId.expense},
      );
      expect(filtered, hasLength(2));
      expect(filtered.map((s) => s.id), contains(FinanceChartSeriesId.income));
      expect(filtered.map((s) => s.id), isNot(contains(FinanceChartSeriesId.liquidity)));
    });

    test('financeChartHasVisibleData boş listeyi reddeder', () {
      expect(financeChartHasVisibleData(const []), isFalse);
      expect(
        financeChartHasVisibleData(
          buildFinancePerformanceChartPoints(
            dailyPoints: [
              DailyFinanceTrendPoint(
                date: DateTime(2026, 6, 1),
                income: 0,
                expense: 0,
              ),
            ],
            range: FinancePerformanceRange.days7,
            monthSalaryLoad: 0,
          ),
        ),
        isFalse,
      );
    });

    test('resolveFinancePerformanceRange 7 gün aralığı', () {
      final now = DateTime(2026, 6, 30, 15);
      final bounds = resolveFinancePerformanceRange(
        range: FinancePerformanceRange.days7,
        now: now,
      );
      expect(bounds.from, DateTime(2026, 6, 24));
      expect(bounds.to.day, 30);
    });
  });

  group('finance performance chart widgets', () {
    testWidgets('legend dört seriyi gösterir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinanceSeriesLegend(
              series: defaultFinanceChartSeries(),
              enabled: FinanceChartSeriesId.values.toSet(),
              onToggle: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Gelir'), findsOneWidget);
      expect(find.text('Gider'), findsOneWidget);
      expect(find.text('Maaş Yükü'), findsOneWidget);
      expect(find.text('Likidite'), findsOneWidget);
    });

    testWidgets('range selector tüm dönem seçeneklerini gösterir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinanceRangeSelector(
              selected: FinancePerformanceRange.days30,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('7 Gün'), findsOneWidget);
      expect(find.text('30 Gün'), findsOneWidget);
      expect(find.text('3 Ay'), findsOneWidget);
      expect(find.text('6 Ay'), findsOneWidget);
      expect(find.text('1 Yıl'), findsOneWidget);
      expect(find.text('Özel Tarih'), findsOneWidget);
    });

    testWidgets('empty chart data placeholder yüksekliği korur', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinancePerformanceLineChart(
              points: const [],
              series: defaultFinanceChartSeries(),
              formatCurrency: (v) => '₺$v',
              height: 200,
            ),
          ),
        ),
      );
      final box = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(FinancePerformanceLineChart),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(box.height, 200);
    });
  });
}
