import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_compare_feedback.dart';
import 'package:ibul_app/features/vehicle/domain/vehicle_compare_store.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_enums.dart';
import 'package:ibul_app/features/vehicle/models/vehicle_listing.dart';
import 'package:ibul_app/features/vehicle/widgets/vehicle_card.dart';

VehicleListing _listing({
  String id = 'listing-1',
  String brand = 'Toyota',
  String model = 'Corolla',
  String title = 'Toyota Corolla',
  VehicleListingType type = VehicleListingType.sale,
  double? salePrice = 1200212,
}) {
  return VehicleListing(
    id: id,
    sellerId: 'seller-1',
    listingType: type,
    status: VehicleListingStatus.active,
    specs: VehicleSpecs(brand: brand, model: model, year: 2021),
    salePrice: salePrice,
    extras: {'title': title},
  );
}

void main() {
  tearDown(VehicleCompareStore.instance.clear);

  testWidgets('favorite and compare do not open vehicle detail', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 348,
            child: VehicleCard(
              listing: _listing(),
              width: 220,
              storefront: true,
              margin: EdgeInsets.zero,
              onTap: () => opened++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('vehicle-card-compare')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened, 0);
    expect(find.text('Araç Karşılaştırma'), findsOneWidget);
    expect(VehicleCompareStore.instance.contains('listing-1'), isFalse);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const ValueKey('vehicle-card-favorite')));
    await tester.pump();
    expect(opened, 0);
    expect(find.text('Giriş Yap'), findsWidgets);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold)),
    ).clearSnackBars();
    await tester.pump();

    await tester.tap(find.text('Toyota Corolla'));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('compare picker preselects current and searches vehicles only', (
    tester,
  ) async {
    final current = _listing();
    final other = _listing(
      id: 'listing-2',
      brand: 'Renault',
      model: 'Clio',
      title: 'Renault Clio',
      type: VehicleListingType.rental,
      salePrice: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => VehicleCompareFeedback.open(
                  context,
                  current,
                  similar: [other],
                ),
                child: const Text('Open compare'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open compare'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Araç Karşılaştırma'), findsOneWidget);
    expect(find.text('Toyota Corolla'), findsWidgets);
    expect(find.text('Araç Seç'), findsOneWidget);
    expect(find.text('Önerilen Araçlar'), findsOneWidget);
    expect(find.text('Renault Clio'), findsWidgets);
    expect(find.text('GoPro'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('vehicle-compare-pick-listing-2')),
    );
    await tester.pump();
    expect(find.text('Araç Seç'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Karşılaştır'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(VehicleCompareStore.instance.contains('listing-1'), isTrue);
    expect(VehicleCompareStore.instance.contains('listing-2'), isTrue);
    expect(find.text('Araç Karşılaştırma'), findsWidgets);
  });
}
