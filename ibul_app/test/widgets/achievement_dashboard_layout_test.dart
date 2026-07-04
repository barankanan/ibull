import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/achievements/models/seller_badge_models.dart';
import 'package:ibul_app/features/seller/achievements/services/seller_badge_progress_resolver.dart';
import 'package:ibul_app/features/seller/achievements/widgets/seller_achievements_dashboard_widgets.dart';
import 'package:ibul_app/features/seller/achievements/widgets/seller_badge_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final metrics = const SellerBadgeStoreMetrics(
    sellerId: 'seller-test',
    followerCount: 5,
    productCount: 2,
    profileComplete: true,
    hasLogo: true,
    hasDescription: true,
    hasCategory: true,
    hasContactInfo: true,
  );

  final allBadges = SellerBadgeProgressResolver.resolveAll(metrics);
  final earnedBadges = allBadges
      .where((b) => b.status == SellerBadgeStatus.earned)
      .toList(growable: false);
  final inProgressBadges = allBadges
      .where((b) => b.status == SellerBadgeStatus.inProgress)
      .toList(growable: false);
  final taskBadges = allBadges
      .where((b) => b.status != SellerBadgeStatus.earned)
      .toList(growable: false);

  final metricsItems = buildAchievementMetrics(
    earnedCount: earnedBadges.length,
    inProgressCount: inProgressBadges.length,
    featuredCount: 0,
    loadingFeatured: false,
    maxFeatured: 4,
  );

  group('achievement dashboard layout', () {
    testWidgets('header and four metric cards render', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SellerAchievementsDashboardHeader(
                    earnedCount: earnedBadges.length,
                    inProgressCount: inProgressBadges.length,
                  ),
                  const SizedBox(height: 12),
                  AchievementMetricGrid(metrics: metricsItems),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Başarılarım'), findsOneWidget);
      expect(find.text('Kazanılan Rozetler'), findsOneWidget);
      expect(find.text('Devam Eden Görevler'), findsOneWidget);
      expect(find.text('Vitrindeki Rozetler'), findsOneWidget);
      expect(find.text('Bölge Sıralaması'), findsOneWidget);
    });

    testWidgets('badge showcase and summary panel render', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  BadgeShowcaseCard(
                    earnedBadges: earnedBadges,
                    featuredBadgeIds: const [],
                    onToggleFeatured: (_) {},
                  ),
                  const SizedBox(height: 12),
                  AchievementProgressSummaryCard(
                    earnedCount: earnedBadges.length,
                    totalCount: allBadges.length,
                    inProgressCount: inProgressBadges.length,
                    featuredCount: 0,
                    maxFeatured: 4,
                    welcomeActive: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Rozet Vitrinim'), findsOneWidget);
      expect(find.text('Hızlı Özet'), findsOneWidget);
      expect(find.text('Rozet seç'), findsNWidgets(4));
    });

    testWidgets('compact task cards render in grid', (tester) async {
      final sample = taskBadges.isNotEmpty
          ? taskBadges.first
          : allBadges.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              child: SellerBadgeTaskCard(
                progress: sample,
                compact: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Detay'), findsOneWidget);
      expect(find.text(sample.definition.title), findsOneWidget);
    });

    testWidgets('earned badges grid renders tiles', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EarnedBadgesGrid(
              badges: earnedBadges,
              featuredBadgeIds: const [],
              onShowDetail: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Kazanılan Rozetler'), findsOneWidget);
      if (earnedBadges.isEmpty) {
        expect(find.text('Henüz kazanılmış rozet yok'), findsOneWidget);
      } else {
        expect(
          find.text(earnedBadges.first.definition.title),
          findsOneWidget,
        );
      }
    });

    testWidgets('category chip bar filters without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: SellerBadgeCategoryChipBar(
                selectedCategory: null,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tümü'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty state renders message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AchievementEmptyState(
              title: 'Henüz başarı bulunmuyor',
              message: 'Mağazanı kurdukça rozetler burada görünecek.',
            ),
          ),
        ),
      );

      expect(find.text('Henüz başarı bulunmuyor'), findsOneWidget);
      expect(
        find.text('Mağazanı kurdukça rozetler burada görünecek.'),
        findsOneWidget,
      );
    });

    testWidgets('narrow layout does not overflow dashboard shell', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SellerAchievementsDashboardHeader(
                      earnedCount: 1,
                      inProgressCount: 2,
                    ),
                    const SizedBox(height: 8),
                    AchievementMetricGrid(metrics: metricsItems),
                    const SizedBox(height: 8),
                    BadgeShowcaseCard(
                      earnedBadges: earnedBadges,
                      featuredBadgeIds: const [],
                      onToggleFeatured: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
