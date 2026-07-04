import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/widgets/seller_lists_dashboard_widgets.dart';
import 'package:ibul_app/models/product_list_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleList = ProductList(
    id: 'list-1',
    name: 'Yaz Fırsatları',
    description: 'Sezon ürünleri',
    visibility: ProductListVisibility.public,
    productIds: const ['p1', 'p2'],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 3, 1),
  );

  final metrics = buildSellerListMetrics(
    totalLists: 1,
    addableProducts: 12,
    publicLists: 1,
    campaignReadyLists: 1,
  );

  group('seller lists layout', () {
    testWidgets('header and metric cards render', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SellerListsHeader(
                    totalLists: 1,
                    onCreateList: () {},
                  ),
                  const SizedBox(height: 12),
                  SellerListMetricGrid(metrics: metrics),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Listeler'), findsOneWidget);
      expect(find.text('Toplam Liste'), findsOneWidget);
      expect(find.text('Listeye Eklenebilir Ürün'), findsOneWidget);
      expect(find.text('Yeni Liste Oluştur'), findsOneWidget);
    });

    testWidgets('list card renders actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SellerListCard(
              list: sampleList,
              onAddProducts: () {},
              onEdit: () {},
              onDelete: () {},
              onBoost: () {},
              onRemoveProduct: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Yaz Fırsatları'), findsOneWidget);
      expect(find.text('Ürün ekle'), findsOneWidget);
      expect(find.text('Düzenle'), findsOneWidget);
      expect(find.text('Sil'), findsOneWidget);
    });

    test('list cover guidance mentions recommended size', () {
      expect(kSellerListCoverGuidanceText, contains('1200 × 450'));
      expect(kSellerListCoverGuidanceText, contains('8:3'));
    });

    test('list cover aspect ratio is 8:3', () {
      expect(kListCoverAspectRatio, closeTo(1200 / 450, 0.001));
    });

    testWidgets('empty state renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListsEmptyState(onCreateList: () {}),
          ),
        ),
      );

      expect(find.text('Henüz liste oluşturmadınız'), findsOneWidget);
      expect(find.text('İlk Listeyi Oluştur'), findsOneWidget);
    });

    testWidgets('narrow layout does not overflow header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: SellerListsHeader(
                totalLists: 2,
                onCreateList: () {},
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
