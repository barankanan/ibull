import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/offline_overview.dart';
import 'package:ibul_app/features/seller/panel/helpers/offline_page_policy.dart';
import 'package:ibul_app/features/seller/panel/widgets/offline_page_widgets.dart';

OfflineOverviewData _data({bool tablesKnown = true}) => OfflineOverviewData(
  totalTables: tablesKnown ? 10 : 0,
  occupiedTables: 3,
  freeTables: tablesKnown ? 7 : 0,
  cloudOpenOrders: 2,
  localOrders: 4,
  localKitchenSent: 3,
  localPrintWaiting: 1,
  localPrintUnverified: 0,
  pendingSync: 3,
  syncFailed: 1,
  localProvisionalTotal: 320.5,
  cloudOpenBillTotal: 180,
  lastCloudSnapshotAt: DateTime(2026, 11, 22, 9, 30),
  tablesKnown: tablesKnown,
);

Future<void> _pump(WidgetTester tester, Widget child, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [Size(360, 740), Size(1280, 800)]) {
    testWidgets(
      'engelli sayfa ${size.width.toInt()}px: açıklama görünür, etkileşim yok',
      (tester) async {
        var tapped = false;
        await _pump(
          tester,
          Stack(
            children: [
              const OfflineBlockedModuleView(moduleLabel: 'Ürünlerim'),
              Positioned(
                left: 0,
                top: 0,
                child: GestureDetector(
                  onTap: () => tapped = true,
                  child: const SizedBox(width: 10, height: 10),
                ),
              ),
            ],
          ),
          size,
        );
        expect(find.text(offlineRequiresInternetMessage), findsOneWidget);
        expect(find.text('Ürünlerim'), findsOneWidget);
        expect(find.byType(IgnorePointer), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'çevrimdışı Genel Bakış ${size.width.toInt()}px: kaynaklar ayrı, taşma yok',
      (tester) async {
        await _pump(tester, OfflineOverviewView(data: _data()), size);
        expect(find.text('Toplam masa'), findsOneWidget);
        expect(
          find.text('Bulutla senkronize (son anlık görüntü)', skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text('Yerel olarak kaydedilmiş', skipOffstage: false), findsOneWidget);
        expect(find.text('Senkronizasyon bekleyen', skipOffstage: false), findsOneWidget);
        expect(find.text('Kesinleşmemiş tutarlar', skipOffstage: false), findsOneWidget);
        expect(find.text('₺320.50', skipOffstage: false), findsOneWidget);
        // Tahsilat rakamı yok, açık uyarı var:
        expect(
          find.text('Tahsil edilmiş gelir internet olmadan gösterilmez.', skipOffstage: false),
          findsOneWidget,
        );
        expect(find.textContaining('kazanıldı', skipOffstage: false), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('masa listesi hiç eşitlenmediyse boş masa sayısı uydurulmaz', (
    tester,
  ) async {
    await _pump(
      tester,
      OfflineOverviewView(data: _data(tablesKnown: false)),
      const Size(390, 844),
    );
    expect(find.text('Boş masa'), findsNothing);
    expect(find.textContaining('hiç eşitlenmedi'), findsWidgets);
  });

  testWidgets(
    'yükleyici: kimlik yoksa sonsuz spinner değil hata ve yeniden dene',
    (tester) async {
      await _pump(
        tester,
        const OfflineOverviewLoader(restaurantId: ''),
        const Size(390, 844),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Yeniden dene'), findsOneWidget);
    },
  );
}
