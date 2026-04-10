import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/mixed_service_order.dart';
import 'package:ibul_app/models/product_pricing.dart';
import 'package:ibul_app/models/seller_product.dart';
import 'package:ibul_app/widgets/restaurant_order/mixed_service_dialog.dart';

void main() {
  group('MixedServiceDialog', () {
    SellerProduct buildProduct() {
      return SellerProduct(
        id: 'p1',
        name: 'Tavuk Şiş',
        brand: 'Restoran',
        mainCategory: 'Yemek',
        subCategory: 'Izgara',
        price: 90,
        stock: 20,
        sku: 'P1',
        status: 'Aktif',
        createdAt: DateTime(2026),
      );
    }

    Future<void> openDialog(
      WidgetTester tester, {
      required List<SellerProduct> products,
      Map<String, dynamic>? initialItem,
      MixedServiceDialogMode mode = MixedServiceDialogMode.create,
      List<String>? availablePricingModes,
      void Function(Map<String, dynamic>?)? onResult,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    final future = showMixedServiceDialog(
                      context: context,
                      products: products,
                      initialItem: initialItem,
                      mode: mode,
                      availablePricingModes: availablePricingModes,
                    );
                    if (onResult != null) {
                      future.then(onResult);
                    }
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    FilledButton saveButton(WidgetTester tester) {
      return tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('mixed-service-save')),
      );
    }

    testWidgets(
      'starts empty in create mode and hydrates selections in edit mode',
      (tester) async {
        final product = buildProduct();
        final initialItem = MixedServiceOrder.normalizeOrderItem({
          'item_type': MixedServiceOrder.itemType,
          'item_name': 'Karışık Servis',
          'child_items': [
            {
              'product_id': product.id,
              'product_name': product.name,
              'quantity': 1,
              'unit_price': 90,
              'line_total': 90,
              'service_round': 1,
            },
          ],
        });

        await openDialog(
          tester,
          products: <SellerProduct>[product],
          mode: MixedServiceDialogMode.create,
        );

        expect(find.text('Karışık Servis Ekle'), findsOneWidget);
        expect(saveButton(tester).onPressed, isNull);

        await tester.tap(find.text('Vazgeç'));
        await tester.pumpAndSettle();

        await openDialog(
          tester,
          products: <SellerProduct>[product],
          initialItem: initialItem,
          mode: MixedServiceDialogMode.edit,
        );

        expect(find.text('Karışık Servisi Düzenle'), findsOneWidget);
        expect(saveButton(tester).onPressed, isNotNull);
      },
    );

    testWidgets('keeps separate draft selections for each table mode', (
      tester,
    ) async {
      final product = buildProduct();
      const saveKey = ValueKey<String>('mixed-service-save');
      final qtyPlusKey = ValueKey<String>('mixed-service-qty-plus-${'p1'}');
      const standardModeKey = ValueKey<String>('mixed-service-mode-0');
      const twoPlateModeKey = ValueKey<String>('mixed-service-mode-2');
      const threePlateModeKey = ValueKey<String>('mixed-service-mode-3');

      await openDialog(
        tester,
        products: <SellerProduct>[product],
        mode: MixedServiceDialogMode.create,
      );

      await tester.tap(find.byKey(qtyPlusKey));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byKey(saveKey)).onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(twoPlateModeKey));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byKey(saveKey)).onPressed,
        isNull,
      );

      await tester.tap(find.byKey(qtyPlusKey));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byKey(saveKey)).onPressed,
        isNotNull,
      );

      // All plate-modes share bucket=1 so items persist across plate-count
      // switches. Switching from mode-2 to mode-3 keeps the existing items.
      await tester.tap(find.byKey(threePlateModeKey));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byKey(saveKey)).onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(twoPlateModeKey));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byKey(saveKey)).onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(standardModeKey));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byKey(saveKey)).onPressed,
        isNotNull,
      );
    });

    testWidgets('stores the same product as separate rows across plates', (
      tester,
    ) async {
      final product = buildProduct();
      Map<String, dynamic>? savedItem;

      await openDialog(
        tester,
        products: <SellerProduct>[product],
        mode: MixedServiceDialogMode.create,
        onResult: (value) => savedItem = value,
      );

      // Add to plate 1 first (mode-1 → activeRound=1).
      await tester.tap(
        find.byKey(const ValueKey<String>('mixed-service-mode-1')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(ValueKey<String>('mixed-service-qty-plus-${product.id}')),
      );
      await tester.pump();

      // Switch to mode-2 (activeRound=2) and add to plate 2.
      // All plate-modes share the same bucket so the plate-1 item stays.
      await tester.tap(
        find.byKey(const ValueKey<String>('mixed-service-mode-2')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(ValueKey<String>('mixed-service-qty-plus-${product.id}')),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey<String>('mixed-service-save')),
      );
      await tester.pumpAndSettle();

      expect(savedItem, isNotNull);
      final childItems = MixedServiceOrder.normalizeChildItems(
        savedItem!['child_items'],
      );
      expect(childItems, hasLength(2));
      expect(
        childItems.map((item) => item['product_id']).toList(),
        orderedEquals(<String>[product.id, product.id]),
      );
      expect(
        childItems.map((item) => item['service_round']).toList(),
        orderedEquals(<int>[1, 2]),
      );
      expect(
        childItems
            .map((item) => item[MixedServiceOrder.childLocalRowIdKey])
            .toSet()
            .length,
        2,
      );
    });

    testWidgets(
      'template customization starts empty and saves only selected child items',
      (tester) async {
        final product = SellerProduct(
          id: 'portion-1',
          name: 'Tavuk Bonfile',
          brand: 'Restoran',
          mainCategory: 'Yemek',
          subCategory: 'Izgara',
          price: 120,
          portionPrice: 120,
          serviceControlType:
              ProductServiceControlType.portionStepper.storageValue,
          minPortion: 0.5,
          maxPortion: 2.0,
          portionStep: 0.5,
          stock: 20,
          sku: 'PORTION-1',
          status: 'Aktif',
          createdAt: DateTime(2026),
        );
        final template = SellerProduct(
          id: 'template-1',
          name: 'Hazir Menu',
          brand: 'Restoran',
          mainCategory: 'Yemek',
          subCategory: 'Karışık Menü',
          price: 0,
          stock: 999,
          sku: 'MIX-1',
          status: 'Aktif',
          createdAt: DateTime(2026),
          specifications: MixedServiceOrder.encodeTemplateSpecifications(
            pricingMode: MixedServiceOrder.autoSumPriceMode,
            fixedPrice: 0,
            manualPriceAllowed: false,
            templateItems: const <Map<String, dynamic>>[
              {
                'product_id': 'portion-1',
                'product_name': 'Tavuk Bonfile',
                'quantity': 1,
                'unit_price_snapshot': 120,
                'selected_portion_value': 1.0,
              },
            ],
          ),
        );
        Map<String, dynamic>? savedItem;

        await openDialog(
          tester,
          products: <SellerProduct>[product],
          initialItem: MixedServiceOrder.buildOrderItemFromTemplateProduct(
            template,
            availableProducts: <SellerProduct>[product],
            preselectTemplateItems: false,
          ),
          mode: MixedServiceDialogMode.edit,
          availablePricingModes: const <String>[
            MixedServiceOrder.autoSumPriceMode,
          ],
          onResult: (value) => savedItem = value,
        );

        expect(saveButton(tester).onPressed, isNull);

        await tester.tap(
          find.byKey(ValueKey<String>('mixed-service-customize-${product.id}')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(
            ValueKey<String>('mixed-service-option-plus-${product.id}'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            ValueKey<String>('mixed-service-option-plus-${product.id}'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(ValueKey<String>('mixed-service-note-${product.id}')),
          'Az sos',
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(ValueKey<String>('mixed-service-qty-plus-${product.id}')),
        );
        await tester.pumpAndSettle();

        expect(saveButton(tester).onPressed, isNotNull);

        await tester.tap(
          find.byKey(const ValueKey<String>('mixed-service-save')),
        );
        await tester.pumpAndSettle();

        expect(savedItem, isNotNull);
        final childItems = MixedServiceOrder.normalizeChildItems(
          savedItem!['child_items'],
        );
        expect(childItems, hasLength(1));
        expect(childItems.single['product_id'], product.id);
        expect(childItems.single['selected_portion_value'], 1.5);
        expect(childItems.single['note'], 'Az sos');
        expect(
          MixedServiceOrder.itemLineTotal(savedItem!),
          closeTo(180, 0.001),
        );
      },
    );
  });
}
