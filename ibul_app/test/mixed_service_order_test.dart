import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/mixed_service_order.dart';
import 'package:ibul_app/models/product_pricing.dart';
import 'package:ibul_app/models/seller_product.dart';

void main() {
  group('MixedServiceOrder', () {
    test('normalizes mixed service payload and keeps child items', () {
      final item = MixedServiceOrder.normalizeOrderItem({
        'item_type': 'mixed_service',
        'item_name': 'Karışık Tabak',
        'price': 245.5,
        'pricing_mode': 'manual_price',
        'child_items': [
          {
            'product_id': 'p1',
            'product_name': 'Tavuk Şiş',
            'quantity': 2,
            'unit_price': 60,
          },
        ],
      });

      expect(MixedServiceOrder.isMixedService(item), isTrue);
      expect(item['name'], 'Karışık Tabak');
      expect(item['child_items'], hasLength(1));
      expect(item['pricing_mode'], MixedServiceOrder.manualPriceMode);
      expect(item['service_round_count'], 0);
      expect(MixedServiceOrder.itemLineTotal(item), 245.5);
    });

    test('falls back to child auto total when explicit total is missing', () {
      final item = MixedServiceOrder.normalizeOrderItem({
        'item_type': 'mixed_service',
        'item_name': 'Karışık Servis',
        'child_items': [
          {
            'product_id': 'p1',
            'product_name': 'Tavuk Şiş',
            'quantity': 1,
            'unit_price': 80,
            'line_total': 80,
            'service_round': 1,
          },
          {
            'product_id': 'p2',
            'product_name': 'Ciğer Şiş',
            'quantity': 2,
            'unit_price': 55,
            'line_total': 110,
            'service_round': 2,
          },
        ],
      });

      expect(MixedServiceOrder.itemLineTotal(item), 190);
      expect(
        MixedServiceOrder.childItemDisplayLines(item),
        containsAll(<String>[
          'Tabak 1',
          'Tavuk Şiş x1',
          'Tabak 2',
          'Ciğer Şiş x2',
        ]),
      );
    });

    test('multiplies mixed service total by quantity and keeps unit price', () {
      final item = MixedServiceOrder.normalizeOrderItem({
        'item_type': 'mixed_service',
        'item_name': '2 Adet Servis',
        'quantity': 2,
        'child_items': [
          {
            'product_id': 'p1',
            'product_name': 'Tavuk Şiş',
            'quantity': 1,
            'unit_price': 80,
            'line_total': 80,
          },
          {
            'product_id': 'p2',
            'product_name': 'Pilav',
            'quantity': 1,
            'unit_price': 20,
            'line_total': 20,
          },
        ],
      });

      expect(item['price'], 100);
      expect(item['line_total'], 200);
      expect(item['total_price'], 200);
      expect(MixedServiceOrder.itemLineTotal(item), 200);
    });

    test('builds kitchen note with child breakdown', () {
      final note = MixedServiceOrder.buildKitchenNote({
        'item_type': 'mixed_service',
        'notes': 'Yanında lavaş',
        'child_items': [
          {
            'product_id': 'p1',
            'product_name': 'Kuşbaşı Şiş',
            'quantity': 1,
            'unit_price': 95,
            'line_total': 95,
            'service_round': 3,
          },
        ],
      });

      expect(note, contains('Yanında lavaş'));
      expect(note, contains('Tabak 3'));
      expect(note, contains(' - Kuşbaşı Şiş x1'));
    });

    test('keeps standard mode child lines without plate headers', () {
      final item = MixedServiceOrder.normalizeOrderItem({
        'item_type': 'mixed_service',
        'item_name': 'Standart Karışık Servis',
        'service_round_count': 0,
        'child_items': [
          {
            'product_id': 'p1',
            'product_name': 'Adana',
            'quantity': 1,
            'unit_price': 120,
            'line_total': 120,
            'service_round': 1,
          },
        ],
      });

      expect(MixedServiceOrder.usesPlateGrouping(item), isFalse);
      expect(MixedServiceOrder.childItemDisplayLines(item), ['Adana x1']);
    });

    test('keeps single plate mode when explicitly selected', () {
      final item = MixedServiceOrder.normalizeOrderItem({
        'item_type': 'mixed_service',
        'item_name': 'Tek Tabak',
        'service_round_count': 1,
        'child_items': [
          {
            'product_id': 'p1',
            'product_name': 'Tavuk Şiş',
            'quantity': 1,
            'unit_price': 90,
            'line_total': 90,
            'service_round': 1,
          },
        ],
      });

      expect(MixedServiceOrder.usesPlateGrouping(item), isTrue);
      expect(MixedServiceOrder.childItemDisplayLines(item), [
        'Tabak 1',
        'Tavuk Şiş x1',
      ]);
    });

    test('resolves shared station and routing from selected products', () {
      final products = <SellerProduct>[
        SellerProduct(
          id: '1',
          name: 'Tavuk Şiş',
          brand: '',
          mainCategory: 'Yemek',
          subCategory: 'Izgara',
          price: 80,
          stock: 10,
          sku: 'SKU-1',
          status: 'Aktif',
          createdAt: DateTime(2026),
          stationId: 'station-a',
          printerRoutingEnabled: false,
        ),
        SellerProduct(
          id: '2',
          name: 'Ciğer Şiş',
          brand: '',
          mainCategory: 'Yemek',
          subCategory: 'Izgara',
          price: 75,
          stock: 8,
          sku: 'SKU-2',
          status: 'Aktif',
          createdAt: DateTime(2026),
          stationId: 'station-a',
          printerRoutingEnabled: true,
        ),
      ];

      expect(
        MixedServiceOrder.resolveStationIdForProducts(products),
        'station-a',
      );
      expect(MixedServiceOrder.resolvePrinterRoutingEnabled(products), isTrue);
    });

    test('encodes and reads template metadata from specifications', () {
      final product = SellerProduct(
        id: 'template-1',
        name: 'Karışık Izgara Menü',
        brand: 'Restoran',
        mainCategory: 'Yemek',
        subCategory: 'Karışık Menü',
        price: 210,
        stock: 999,
        sku: 'MIX-1',
        status: 'Aktif',
        createdAt: DateTime(2026),
        specifications: MixedServiceOrder.encodeTemplateSpecifications(
          pricingMode: MixedServiceOrder.manualAllowedPriceMode,
          fixedPrice: 210,
          manualPriceAllowed: true,
          templateItems: const <Map<String, dynamic>>[
            {
              'product_id': 'p1',
              'product_name': 'Tavuk Şiş',
              'quantity': 1,
              'unit_price_snapshot': 90,
              'service_round': 1,
            },
            {
              'product_id': 'p2',
              'product_name': 'Kuşbaşı Şiş',
              'quantity': 1,
              'unit_price_snapshot': 120,
              'service_round': 2,
            },
          ],
        ),
      );

      expect(MixedServiceOrder.isTemplateProduct(product), isTrue);
      expect(
        MixedServiceOrder.productTypeFromProduct(product),
        MixedServiceOrder.serviceTemplateProductType,
      );
      expect(MixedServiceOrder.templateTypeLabelFromProduct(product), 'Servis');
      expect(
        MixedServiceOrder.templatePricingLabel(product),
        'Manuel Fiyat Izinli',
      );
      expect(MixedServiceOrder.templatePreviewPriceFromProduct(product), 210);
      expect(
        MixedServiceOrder.childItemsFromTemplateProduct(product),
        hasLength(2),
      );
    });

    test(
      'preserves explicit menu template type in metadata and order items',
      () {
        final product = SellerProduct(
          id: 'template-menu-1',
          name: 'Sabit Menü',
          brand: 'Restoran',
          mainCategory: 'Yemek',
          subCategory: 'Menü',
          price: 180,
          stock: 999,
          sku: 'MENU-1',
          status: 'Aktif',
          createdAt: DateTime(2026),
          specifications: MixedServiceOrder.encodeTemplateSpecifications(
            productType: MixedServiceOrder.menuTemplateProductType,
            pricingMode: MixedServiceOrder.autoSumPriceMode,
            fixedPrice: 180,
            manualPriceAllowed: false,
            templateItems: const <Map<String, dynamic>>[
              {
                'product_id': 'p1',
                'product_name': 'Adana',
                'quantity': 1,
                'unit_price_snapshot': 95,
                'service_round': 1,
              },
            ],
          ),
        );

        final orderItem = MixedServiceOrder.buildOrderItemFromTemplateProduct(
          product,
        );

        expect(
          MixedServiceOrder.productTypeFromProduct(product),
          MixedServiceOrder.menuTemplateProductType,
        );
        expect(MixedServiceOrder.templateTypeLabelFromProduct(product), 'Menü');
        expect(
          orderItem['product_type'],
          MixedServiceOrder.menuTemplateProductType,
        );
        expect(
          orderItem['source_product_type'],
          MixedServiceOrder.menuTemplateProductType,
        );
      },
    );

    test('maps legacy mixed_service_template rows to service templates', () {
      final row = <String, dynamic>{
        'product_type': MixedServiceOrder.legacyTemplateProductType,
      };

      expect(MixedServiceOrder.isTemplateProductRow(row), isTrue);
      expect(
        MixedServiceOrder.normalizeTemplateProductType(
          MixedServiceOrder.legacyTemplateProductType,
        ),
        MixedServiceOrder.serviceTemplateProductType,
      );
    });

    test(
      'recomputes template preview and order total from current product prices',
      () {
        final template = SellerProduct(
          id: 'template-2',
          name: 'Guncel Fiyatli Menu',
          brand: 'Restoran',
          mainCategory: 'Yemek',
          subCategory: 'Karışık Menü',
          price: 150,
          stock: 999,
          sku: 'MIX-2',
          status: 'Aktif',
          createdAt: DateTime(2026),
          specifications: MixedServiceOrder.encodeTemplateSpecifications(
            pricingMode: MixedServiceOrder.manualAllowedPriceMode,
            fixedPrice: 150,
            manualPriceAllowed: true,
            templateItems: const <Map<String, dynamic>>[
              {
                'product_id': 'p1',
                'product_name': 'Tavuk Sis',
                'quantity': 1,
                'unit_price_snapshot': 60,
                'service_round': 1,
              },
              {
                'product_id': 'p2',
                'product_name': 'Kofte',
                'quantity': 2,
                'unit_price_snapshot': 45,
                'service_round': 2,
              },
            ],
          ),
        );

        final currentProducts = <SellerProduct>[
          SellerProduct(
            id: 'p1',
            name: 'Tavuk Sis',
            brand: 'Restoran',
            mainCategory: 'Yemek',
            subCategory: 'Izgara',
            price: 80,
            stock: 10,
            sku: 'P1',
            status: 'Aktif',
            createdAt: DateTime(2026),
          ),
          SellerProduct(
            id: 'p2',
            name: 'Kofte',
            brand: 'Restoran',
            mainCategory: 'Yemek',
            subCategory: 'Izgara',
            price: 55,
            stock: 10,
            sku: 'P2',
            status: 'Aktif',
            createdAt: DateTime(2026),
          ),
        ];

        expect(
          MixedServiceOrder.templatePreviewPriceFromProduct(
            template,
            availableProducts: currentProducts,
          ),
          190,
        );

        final orderItem = MixedServiceOrder.buildOrderItemFromTemplateProduct(
          template,
          availableProducts: currentProducts,
        );

        expect(
          orderItem['pricing_mode'],
          MixedServiceOrder.manualAllowedPriceMode,
        );
        expect(orderItem['total_price'], 190);
        expect(
          MixedServiceOrder.normalizeChildItems(
            orderItem['child_items'],
          ).map((item) => item['line_total']),
          orderedEquals(<double>[80, 110]),
        );
      },
    );

    test(
      'builds empty editable template draft and limits selectable products to template items',
      () {
        final template = SellerProduct(
          id: 'template-filtered',
          name: 'Filtreli Menu',
          brand: 'Restoran',
          mainCategory: 'Yemek',
          subCategory: 'Karışık Menü',
          price: 0,
          stock: 999,
          sku: 'MIX-FILTER',
          status: 'Aktif',
          createdAt: DateTime(2026),
          specifications: MixedServiceOrder.encodeTemplateSpecifications(
            pricingMode: MixedServiceOrder.autoSumPriceMode,
            fixedPrice: 0,
            manualPriceAllowed: false,
            templateItems: const <Map<String, dynamic>>[
              {
                'product_id': 'p2',
                'product_name': 'Kofte',
                'quantity': 1,
                'unit_price_snapshot': 55,
              },
              {
                'product_id': 'p1',
                'product_name': 'Corba',
                'quantity': 1,
                'unit_price_snapshot': 80,
              },
            ],
          ),
        );
        final availableProducts = <SellerProduct>[
          SellerProduct(
            id: 'p1',
            name: 'Corba',
            brand: 'Restoran',
            mainCategory: 'Yemek',
            subCategory: 'Corba',
            price: 80,
            stock: 20,
            sku: 'P1',
            status: 'Aktif',
            createdAt: DateTime(2026),
          ),
          SellerProduct(
            id: 'other',
            name: 'Ayran',
            brand: 'Restoran',
            mainCategory: 'İçecek',
            subCategory: 'Soğuk',
            price: 25,
            stock: 20,
            sku: 'OTHER',
            status: 'Aktif',
            createdAt: DateTime(2026),
          ),
          SellerProduct(
            id: 'p2',
            name: 'Kofte',
            brand: 'Restoran',
            mainCategory: 'Yemek',
            subCategory: 'Izgara',
            price: 55,
            stock: 20,
            sku: 'P2',
            status: 'Aktif',
            createdAt: DateTime(2026),
          ),
        ];

        final selectableProducts =
            MixedServiceOrder.selectableProductsForTemplate(
              template,
              availableProducts: availableProducts,
            );
        final orderItem = MixedServiceOrder.buildOrderItemFromTemplateProduct(
          template,
          availableProducts: availableProducts,
          preselectTemplateItems: false,
        );

        expect(
          selectableProducts.map((product) => product.id).toList(),
          orderedEquals(<String>['p2', 'p1']),
        );
        expect(
          MixedServiceOrder.normalizeChildItems(orderItem['child_items']),
          isEmpty,
        );
        expect(orderItem['pricing_mode'], MixedServiceOrder.autoSumPriceMode);
        expect(MixedServiceOrder.itemLineTotal(orderItem), 0);
      },
    );

    test('legacy fixed-price templates fall back to automatic total mode', () {
      final product = SellerProduct(
        id: 'template-legacy',
        name: 'Eski Menu',
        brand: 'Restoran',
        mainCategory: 'Yemek',
        subCategory: 'Karışık Menü',
        price: 200,
        stock: 999,
        sku: 'MIX-OLD',
        status: 'Aktif',
        createdAt: DateTime(2026),
        specifications: MixedServiceOrder.encodeTemplateSpecifications(
          pricingMode: MixedServiceOrder.fixedPriceMode,
          fixedPrice: 999,
          manualPriceAllowed: false,
          templateItems: const <Map<String, dynamic>>[
            {
              'product_id': 'p1',
              'product_name': 'Corba',
              'quantity': 1,
              'unit_price_snapshot': 70,
            },
          ],
        ),
      );

      final config = MixedServiceOrder.templateConfigFromProduct(product);

      expect(config?['pricing_mode'], MixedServiceOrder.autoSumPriceMode);
      expect(
        MixedServiceOrder.templatePricingLabel(product),
        'Otomatik Toplam',
      );
      expect(MixedServiceOrder.templatePreviewPriceFromProduct(product), 70);
    });

    test('keeps stepper amount labels and resolves selection pricing', () {
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
        stock: 50,
        sku: 'P-1',
        status: 'Aktif',
        createdAt: DateTime(2026),
      );

      expect(
        MixedServiceOrder.productUnitPriceForSelection(
          product,
          selectedServiceAmount: 1.5,
        ),
        180,
      );
      expect(
        MixedServiceOrder.productAmountLabelForSelection(
          product,
          selectedServiceAmount: 1.5,
        ),
        '1.5 Porsiyon',
      );

      final payload = MixedServiceOrder.buildChildItemPayload(
        product,
        quantity: 2,
        selectedServiceAmount: 1.5,
        serviceRound: 2,
      );

      expect(payload['selected_pricing_type'], 'portion');
      expect(payload['selected_portion_value'], 1.5);
      expect(payload['selected_option_label'], '1.5 Porsiyon');
      expect(payload['unit_price'], 180);
      expect(payload['line_total'], 360);

      final item = MixedServiceOrder.normalizeOrderItem({
        'item_type': 'mixed_service',
        'item_name': 'Karışık Servis',
        'child_items': [
          {
            'product_id': 'portion-1',
            'product_name': 'Tavuk Bonfile',
            'quantity': 1,
            'unit_price': 180,
            'line_total': 180,
            'service_round': 1,
            'service_control_type':
                ProductServiceControlType.portionStepper.storageValue,
            'selected_pricing_type': 'portion',
            'selected_portion_value': 1.5,
            'selected_service_amount': 1.5,
            'selected_option_label': '1.5 Porsiyon',
            'amount_label': '1.5 Porsiyon',
          },
        ],
      });

      expect(MixedServiceOrder.itemLineTotal(item), 180);
      expect(
        MixedServiceOrder.childItemDisplayLines(item),
        contains('Tavuk Bonfile • 1.5 Porsiyon'),
      );
      expect(
        MixedServiceOrder.buildKitchenNote(item),
        contains(' - Tavuk Bonfile • 1.5 Porsiyon'),
      );
    });

    test('calculates kilogram child item totals with selected weight', () {
      final product = SellerProduct(
        id: 'kg-1',
        name: 'Ciğer Şiş',
        brand: 'Restoran',
        mainCategory: 'Yemek',
        subCategory: 'Izgara',
        price: 1200,
        pricingType: 'weight',
        pricePerKg: 1200,
        serviceControlType:
            ProductServiceControlType.weightStepper.storageValue,
        minWeightGrams: 500,
        defaultWeightGrams: 500,
        weightStepGrams: 250,
        maxWeightGrams: 1500,
        stock: 20,
        sku: 'KG-1',
        status: 'Aktif',
        createdAt: DateTime(2026),
      );

      final payload = MixedServiceOrder.buildChildItemPayload(
        product,
        quantity: 1,
        selectedWeightGrams: 750,
      );

      expect(payload['selected_pricing_type'], 'kg');
      expect(payload['selected_weight_grams'], 750);
      expect(payload['selected_option_label'], '750 g');
      expect(payload['unit_price'], 900);
      expect(payload['line_total'], 900);
    });

    test(
      'prefers selected option label over legacy amount label in summaries',
      () {
        final item = MixedServiceOrder.normalizeOrderItem({
          'item_type': 'mixed_service',
          'item_name': 'Karışık Servis',
          'service_round_count': 2,
          'child_items': [
            {
              'product_id': 'p1',
              'product_name': 'Karışık Izgara',
              'quantity': 1,
              'unit_price': 450,
              'line_total': 450,
              'service_round': 1,
              'selected_pricing_type': 'kg',
              'selected_weight_grams': 500,
              'selected_option_label': '500 g',
              'amount_label': '1 Porsiyon',
            },
            {
              'product_id': 'p2',
              'product_name': 'Ciğer Şiş',
              'quantity': 1,
              'unit_price': 120,
              'line_total': 120,
              'service_round': 2,
              'service_control_type':
                  ProductServiceControlType.portionStepper.storageValue,
              'selected_pricing_type': 'portion',
              'selected_portion_value': 0.5,
              'selected_service_amount': 0.5,
              'selected_option_label': 'Yarım Porsiyon',
              'amount_label': '1 Porsiyon',
            },
          ],
        });

        expect(
          MixedServiceOrder.childItemDisplayLines(item),
          orderedEquals(<String>[
            'Tabak 1',
            'Karışık Izgara • 500 g',
            'Tabak 2',
            'Ciğer Şiş • Yarım Porsiyon',
          ]),
        );
      },
    );

    test('keeps duplicate product rows distinct with local row ids', () {
      final item = MixedServiceOrder.normalizeOrderItem({
        'item_type': 'mixed_service',
        'item_name': 'Karışık Servis',
        'service_round_count': 2,
        'child_items': [
          {
            'product_id': 'p1',
            'product_name': 'Tavuk Şiş',
            'quantity': 1,
            'unit_price': 90,
            'line_total': 90,
            'service_round': 1,
            'local_row_id': 'row-1',
          },
          {
            'product_id': 'p1',
            'product_name': 'Tavuk Şiş',
            'quantity': 1,
            'unit_price': 90,
            'line_total': 90,
            'service_round': 2,
            'local_row_id': 'row-2',
          },
        ],
      });

      final childItems = MixedServiceOrder.normalizeChildItems(
        item['child_items'],
      );
      expect(childItems, hasLength(2));
      expect(
        childItems
            .map((child) => child[MixedServiceOrder.childLocalRowIdKey])
            .toList(),
        orderedEquals(<String>['row-1', 'row-2']),
      );
      expect(
        MixedServiceOrder.childItemDisplayLines(item),
        orderedEquals(<String>[
          'Tabak 1',
          'Tavuk Şiş x1',
          'Tabak 2',
          'Tavuk Şiş x1',
        ]),
      );
    });

    test(
      'matches service template items by linked_product_id and filters out inactive or zero-stock rows',
      () {
        final template = SellerProduct(
          id: 'template-linked',
          name: 'Linked Service',
          brand: 'Restoran',
          mainCategory: 'Yemek',
          subCategory: 'Servis',
          price: 0,
          stock: 999,
          sku: 'LINKED-1',
          status: 'Aktif',
          createdAt: DateTime(2026),
          specifications: MixedServiceOrder.encodeTemplateSpecifications(
            pricingMode: MixedServiceOrder.autoSumPriceMode,
            fixedPrice: 0,
            manualPriceAllowed: false,
            templateItems: const <Map<String, dynamic>>[
              {
                'linked_product_id': 'p-active',
                'product_name': 'Adana',
                'quantity': 1,
              },
              {
                'linked_product_id': 'p-inactive',
                'product_name': 'Pilav',
                'quantity': 1,
              },
              {
                'linked_product_id': 'p-no-stock',
                'product_name': 'Ayran',
                'quantity': 1,
              },
            ],
          ),
        );

        final selectableProducts =
            MixedServiceOrder.selectableProductsForTemplate(
              template,
              availableProducts: <SellerProduct>[
                SellerProduct(
                  id: 'p-active',
                  name: 'Adana',
                  brand: 'Restoran',
                  mainCategory: 'Yemek',
                  subCategory: 'Izgara',
                  price: 120,
                  stock: 10,
                  sku: 'P-ACTIVE',
                  status: 'Aktif',
                  createdAt: DateTime(2026),
                ),
                SellerProduct(
                  id: 'p-inactive',
                  name: 'Pilav',
                  brand: 'Restoran',
                  mainCategory: 'Yemek',
                  subCategory: 'Yan Urun',
                  price: 30,
                  stock: 8,
                  sku: 'P-INACTIVE',
                  status: 'Taslak',
                  createdAt: DateTime(2026),
                ),
                SellerProduct(
                  id: 'p-no-stock',
                  name: 'Ayran',
                  brand: 'Restoran',
                  mainCategory: 'Icecek',
                  subCategory: 'Soguk',
                  price: 15,
                  stock: 0,
                  sku: 'P-NO-STOCK',
                  status: 'Aktif',
                  createdAt: DateTime(2026),
                ),
              ],
            );

        expect(
          selectableProducts.map((product) => product.id).toList(),
          orderedEquals(<String>['p-active']),
        );
      },
    );

    test(
      'falls back to normalized product name when service template ids are missing',
      () {
        final childItems = MixedServiceOrder.templateConfigToChildItems(
          const <Map<String, dynamic>>[
            {
              'product_name': '  karisik izgara  ',
              'quantity': 1,
              'unit_price_snapshot': 95,
            },
          ],
          availableProducts: <SellerProduct>[
            SellerProduct(
              id: 'p-name-match',
              name: 'Karisik Izgara',
              brand: 'Restoran',
              mainCategory: 'Yemek',
              subCategory: 'Izgara',
              price: 140,
              stock: 5,
              sku: 'P-NAME',
              status: 'Aktif',
              createdAt: DateTime(2026),
            ),
          ],
        );

        expect(childItems, hasLength(1));
        expect(childItems.first['product_id'], '');
        expect(childItems.first['product_name'], 'Karisik Izgara');
        expect(childItems.first['unit_price'], 140);
      },
    );
  });
}
