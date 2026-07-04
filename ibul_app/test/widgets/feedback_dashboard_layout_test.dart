import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/widgets/seller_feedback_dashboard_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final emptyTrend = List<Map<String, dynamic>>.generate(
    7,
    (index) => <String, dynamic>{
      'reviews': 0,
      'questions': 0,
      'complaints': 0,
      'label': 'G${index + 1}',
    },
  );

  final metrics = buildFeedbackMetricsFromStats(<String, dynamic>{
    'averageRating': 0.0,
    'reviewCount': 0,
    'feedbackCount': 0,
    'thisWeekCount': 0,
    'pendingQuestions': 0,
    'complaintCount': 0,
    'fiveStarRatio': 0,
  });

  group('feedback dashboard layout', () {
    testWidgets('header and metric cards render', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const SellerFeedbackDashboardHeader(activeRecordCount: 0),
                  const SizedBox(height: 12),
                  FeedbackMetricGrid(metrics: metrics),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Müşteri Etkileşim Merkezi'), findsOneWidget);
      expect(find.text('Ortalama Puan'), findsOneWidget);
      expect(find.text('Toplam Geri Bildirim'), findsOneWidget);
      expect(find.text('Yanıt Bekleyen Soru'), findsOneWidget);
      expect(find.text('Şikayet Riski'), findsOneWidget);
    });

    testWidgets('chart shows empty state when no trend data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedbackTrendChartCard(
              trend: emptyTrend,
              shortDayLabel: (weekday) => '$weekday',
            ),
          ),
        ),
      );

      expect(find.text('Bu dönemde geri bildirim yok.'), findsOneWidget);
    });

    testWidgets('rating card shows empty state when no reviews', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RatingDistributionCard(
              starDistribution: <int, int>{},
              totalReviews: 0,
            ),
          ),
        ),
      );

      expect(
        find.text('Henüz puanlı değerlendirme yok.'),
        findsOneWidget,
      );
    });

    testWidgets('filter bar renders search and tabs', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: FeedbackFilterBar(
                searchController: controller,
                onSearchChanged: (_) {},
                selectedTab: 'Tum',
                onTabSelected: (_) {},
                selectedRatingFilter: 'Tum',
                onRatingFilterChanged: (_) {},
                allCount: 0,
                reviewCount: 0,
                questionCount: 0,
                complaintCount: 0,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Kullanıcı, ürün, yorum veya soru ara'), findsOneWidget);
      expect(find.text('Tümü (0)'), findsOneWidget);
      expect(find.text('Değerlendirmeler (0)'), findsOneWidget);
      expect(find.text('Sorular (0)'), findsOneWidget);
      expect(find.text('Şikayetler (0)'), findsOneWidget);
    });

    testWidgets('narrow layout does not overflow dashboard shell', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SellerFeedbackDashboardLayout(
                metrics: metrics,
                trend: emptyTrend,
                starDistribution: const <int, int>{},
                totalReviews: 0,
                averageRating: 0,
                reviewCount: 0,
                questionCount: 0,
                complaintCount: 0,
                pendingQuestions: 0,
                activeRecordCount: 0,
                searchController: controller,
                onSearchChanged: (_) {},
                selectedTab: 'Tum',
                onTabSelected: (_) {},
                selectedRatingFilter: 'Tum',
                onRatingFilterChanged: (_) {},
                allCount: 0,
                shortDayLabel: (weekday) => '$weekday',
                listSection: const FeedbackListEmptyState(),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Müşteri Etkileşim Merkezi'), findsOneWidget);
    });
  });
}
