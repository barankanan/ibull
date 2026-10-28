import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/app/app_route_table.dart';
import 'package:ibul_app/features/visual_search/application/visual_search_controller.dart';
import 'package:ibul_app/features/visual_search/application/visual_search_service.dart';
import 'package:ibul_app/features/visual_search/data/mock_visual_search_analyzer.dart';
import 'package:ibul_app/features/visual_search/data/visual_search_repository.dart';
import 'package:ibul_app/features/visual_search/domain/visual_search_models.dart';
import 'package:ibul_app/features/visual_search/navigation/visual_search_paths.dart';
import 'package:ibul_app/features/visual_search/presentation/visual_search_history_page.dart';
import 'package:ibul_app/features/visual_search/presentation/visual_search_hub_page.dart';
import 'package:ibul_app/features/visual_search/presentation/visual_search_result_pages.dart';
import 'package:ibul_app/features/visual_search/visual_search_route.dart';
import 'package:ibul_app/widgets/deferred_module_screen.dart';

void main() {
  VisualSearchController controller() {
    return VisualSearchController(
      service: VisualSearchService(
        repository: MemoryVisualSearchRepository(),
        analyzer: const MockVisualSearchAnalyzer(),
      ),
    );
  }

  test('visual search paths stay stable', () {
    expect(VisualSearchPaths.root, '/visual-search');
    expect(VisualSearchPaths.analyze, '/visual-search/analyze');
    expect(VisualSearchPaths.match, '/visual-search/match');
    expect(VisualSearchPaths.history, '/visual-search/history');
    expect(VisualSearchPaths.historyDetail('abc'), '/visual-search/history/abc');
    expect(VisualSearchPaths.analysisResult('abc'), '/visual-search/analyze/abc');
    expect(VisualSearchPaths.matchResult('abc'), '/visual-search/match/abc');
  });

  test('route table resolves the visual search shell', () {
    final page = pageForAppRoute(
      '/visual-search',
      settings: const RouteSettings(name: '/visual-search'),
      includeAuthRoutes: true,
    );
    final detail = pageForAppRoute(
      '/visual-search/history/job-1',
      settings: const RouteSettings(name: '/visual-search/history/job-1'),
      includeAuthRoutes: true,
    );

    expect(page, isA<DeferredModuleScreen>());
    expect(detail, isA<DeferredModuleScreen>());
  });

  test('page builder maps each visual search screen', () {
    expect(visualSearchPageForPath('/visual-search'), isA<VisualSearchHubPage>());
    expect(
      visualSearchPageForPath('/visual-search/analyze'),
      isA<VisualSearchCapturePage>(),
    );
    expect(
      visualSearchPageForPath('/visual-search/match'),
      isA<VisualSearchCapturePage>(),
    );
    expect(
      visualSearchPageForPath('/visual-search/history'),
      isA<VisualSearchHistoryPage>(),
    );
    expect(
      visualSearchPageForPath('/visual-search/history/1'),
      isA<VisualSearchHistoryDetailPage>(),
    );
    expect(
      visualSearchPageForPath('/visual-search/analyze/1'),
      isA<VisualSearchHistoryDetailPage>(),
    );
    expect(
      visualSearchPageForPath('/visual-search/match/1'),
      isA<VisualSearchHistoryDetailPage>(),
    );
    expect(visualSearchPageForPath('/urun/1'), isNull);
  });

  testWidgets('hub shows upload actions and the three modules', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(home: VisualSearchHubPage(controller: controller())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kamera ile Keşfet'), findsOneWidget);
    expect(find.text('Görsel Zeka'), findsOneWidget);
    expect(find.text('Ürünü Arat'), findsOneWidget);
    expect(find.text('Geçmiş'), findsWidgets);
    expect(find.text('Kamera Aç'), findsOneWidget);
    expect(find.text('Galeriden Seç'), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsOneWidget);
    expect(find.text('Nasıl çalışır?'), findsNothing);
    expect(find.text('Son aramalar'), findsNothing);
    expect(find.text('Görsel ekle'), findsNothing);
  });

  testWidgets('wide hub hides the mobile tab bar', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(home: VisualSearchHubPage(controller: controller())),
    );
    await tester.pump();

    expect(find.text('Kamera Aç'), findsOneWidget);
    expect(find.text('Görsel Zeka'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  testWidgets('history empty state offers a new capture', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: VisualSearchHistoryPage(controller: controller())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Henüz kayıt yok'), findsOneWidget);
    expect(find.text('Görsel arama'), findsOneWidget);
    expect(find.text('Hasar analizi'), findsOneWidget);
  });

  testWidgets('analysis result shows damage, missing part and confidence', (
    tester,
  ) async {
    final job = VisualSearchJob(
      id: 'job-1',
      fileName: 'kupa.jpg',
      jobType: VisualSearchJobType.combined,
      status: VisualSearchJobStatus.completed,
      createdAt: DateTime.utc(2026, 10, 4, 8),
      updatedAt: DateTime.utc(2026, 10, 4, 8),
      analysis: VisualSearchAnalysis(
        summary: 'Seramik kupada çatlak var.',
        confidence: 0.88,
        damages: [
          DamageDetection(
            id: 'd1',
            label: 'Gövde çatlağı',
            confidence: 0.91,
            bbox: const BoundingBox(x: 0.2, y: 0.2, width: 0.3, height: 0.3),
            description: 'Ön yüzey çatlak.',
          ),
        ],
        missingParts: [
          MissingPartDetection(
            id: 'm1',
            partName: 'Kulp parçası',
            confidence: 0.8,
            bbox: const BoundingBox(x: 0.6, y: 0.3, width: 0.15, height: 0.15),
            details: 'Kulp yok.',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnalysisResultPage(job: job, controller: controller()),
      ),
    );

    expect(find.text('Analiz Sonucu'), findsOneWidget);
    expect(find.text('Seramik kupada çatlak var.'), findsOneWidget);
    expect(find.text('Gövde çatlağı'), findsWidgets);
    expect(find.text('Kulp parçası'), findsWidgets);
    expect(find.text('Güven skoru %88'), findsOneWidget);
    expect(find.text('İşaretleme'), findsOneWidget);
  });

  testWidgets('product match result lists price, store and detail action', (
    tester,
  ) async {
    final job = VisualSearchJob(
      id: 'job-2',
      fileName: 'ayakkabi.jpg',
      jobType: VisualSearchJobType.visualSearch,
      status: VisualSearchJobStatus.completed,
      createdAt: DateTime.utc(2026, 10, 4, 8),
      updatedAt: DateTime.utc(2026, 10, 4, 8),
      analysis: const VisualSearchAnalysis(
        summary: 'Koşu ayakkabısı eşleşti.',
        confidence: 0.83,
        matches: [
          ProductMatch(
            id: 'p1',
            productId: 'vs-demo-kosu',
            name: 'Koşu Ayakkabısı',
            brand: 'Sprint',
            store: 'Spor Park',
            price: '1.899 TL',
            category: 'Ayakkabı',
            similarityScore: 0.72,
            matchType: ProductMatchType.exact,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProductMatchResultPage(job: job, controller: controller()),
      ),
    );

    expect(find.text('Ürün Eşleşme Sonucu'), findsOneWidget);
    expect(find.text('Koşu Ayakkabısı'), findsOneWidget);
    expect(find.text('1.899 TL'), findsOneWidget);
    expect(find.textContaining('Spor Park'), findsOneWidget);
    expect(find.text('Ürüne git'), findsOneWidget);
  });
}
