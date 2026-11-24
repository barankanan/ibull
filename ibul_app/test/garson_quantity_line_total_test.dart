import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/mixed_service_order.dart';
import 'package:ibul_app/services/store/table_order_history_utils.dart';
import 'package:ibul_app/utils/garson_active_orders_fetch.dart';

/// Real device, 2026-11-24, Teras 8: 2 × KATI CACIK at 180. The server and the
/// local journal held 360; the table card on the center showed 180. `price`
/// is the UNIT price everywhere (server RPCs, kitchen ticket, journal); it
/// must never be divided by the quantity.
void main() {
  double cardTotal(List<Map<String, dynamic>> items) => items.fold<double>(
    0,
    (sum, item) => sum +
        MixedServiceOrder.itemLineTotal(MixedServiceOrder.normalizeOrderItem(item)),
  );

  test('cloud order line with quantity 2 keeps its full amount on the card', () {
    // What the board gets from `orders` + `order_items` (production row).
    final items = normalizeRestaurantOrderItems(<dynamic>[
      <String, dynamic>{
        'id': '11111111-1111-1111-1111-111111111111',
        'product_id': '1780481612042',
        'product_name': 'KATI CACIK',
        'quantity': 2,
        'unit_price': 180,
        'line_total': 360,
      },
    ]);
    final normalized = MixedServiceOrder.normalizeOrderItem(items.single);

    expect(normalized['quantity'], 2);
    expect(normalized['price'], 180);
    expect(normalized['unit_price_snapshot'], 180);
    expect(normalized['line_total'], 360);
    expect(cardTotal(items), 360);
  });

  test('center journal line (price and quantity only) is unit price times quantity', () {
    final items = <Map<String, dynamic>>[
      <String, dynamic>{'name': 'KATI CACIK', 'quantity': 2, 'price': 180.0},
    ];
    final normalized = MixedServiceOrder.normalizeOrderItem(items.single);

    expect(normalized['price'], 180);
    expect(normalized['line_total'], 360);
    expect(normalized['total_price'], 360);
    expect(cardTotal(items), 360);
  });

  test('old server row without a line total still multiplies', () {
    final items = normalizeRestaurantOrderItems(<dynamic>[
      <String, dynamic>{
        'product_name': 'Tavuk Tava',
        'quantity': 3,
        'unit_price': 300,
        'line_total': null,
      },
    ]);
    expect(cardTotal(items), 900);
  });

  test('a line that carries its own total still derives the unit from it', () {
    final normalized = MixedServiceOrder.normalizeOrderItem(<String, dynamic>{
      'name': 'Ayran',
      'quantity': 4,
      'total_price': 200,
    });
    expect(normalized['price'], 50);
    expect(normalized['line_total'], 200);
  });

  test('normalizing twice changes nothing', () {
    final once = MixedServiceOrder.normalizeOrderItem(<String, dynamic>{
      'name': 'KATI CACIK',
      'quantity': 2,
      'price': 180.0,
    });
    final twice = MixedServiceOrder.normalizeOrderItem(once);
    expect(twice['price'], 180);
    expect(twice['line_total'], 360);
    expect(MixedServiceOrder.itemLineTotal(twice), 360);
  });

  test('quantity 1 is unchanged', () {
    expect(
      cardTotal(<Map<String, dynamic>>[
        <String, dynamic>{'name': 'ORDÖVR TABAĞI', 'quantity': 1, 'price': 320.0},
      ]),
      320,
    );
  });

  // The same arithmetic the seller panel runs, one test per screen.
  // Table card / board: `_garsonOrdersTotal` = sum of itemLineTotal over normalized lines.
  // Bill window: `billTotal()` = the same sum over all open orders' lines; remaining = bill - paid.
  double orderTotal(List<Map<String, dynamic>> items) => items.fold<double>(
    0,
    (sum, item) => sum +
        MixedServiceOrder.itemLineTotal(MixedServiceOrder.normalizeOrderItem(item)),
  );

  group('every screen path', () {
    test('rows written before the totals fix (total_price 0, line_total null)', () {
      // What production holds for orders created before 2026-11-24.
      final items = normalizeRestaurantOrderItems(<dynamic>[
        <String, dynamic>{
          'product_name': 'KATI CACIK',
          'quantity': 2,
          'unit_price': 180,
          'total_price': 0,
          'line_total': null,
        },
      ]);
      expect(orderTotal(items), 360);
    });

    test('table card and board: two orders on one table add up', () {
      final first = normalizeRestaurantOrderItems(<dynamic>[
        <String, dynamic>{'product_name': 'KATI CACIK', 'quantity': 2, 'unit_price': 180, 'line_total': 360},
      ]);
      final second = <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Ayran', 'quantity': 3, 'price': 40.0},
      ];
      expect(orderTotal(first) + orderTotal(second), 480);
    });

    test('bill window and remaining balance', () {
      final lines = <Map<String, dynamic>>[
        ...normalizeRestaurantOrderItems(<dynamic>[
          <String, dynamic>{'product_name': 'KATI CACIK', 'quantity': 2, 'unit_price': 180, 'line_total': 360},
        ]),
        <String, dynamic>{'name': 'Ayran', 'quantity': 3, 'price': 40.0},
      ].map(MixedServiceOrder.normalizeOrderItem).toList();
      final bill = lines.fold<double>(0, (s, i) => s + MixedServiceOrder.itemLineTotal(i));
      const paid = 100.0;
      expect(bill, 480);
      expect(bill - paid, 380);
      expect(MixedServiceOrder.unverifiedOrdersMoney(<Map<String, dynamic>>[
        <String, dynamic>{'items': lines},
      ]), isNull);
    });

    test('finance product breakdown reads closed history lines', () {
      final row = <String, dynamic>{
        'grand_total': 360,
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'KATI CACIK', 'quantity': 2, 'price': 180, 'line_total': 360},
        ],
      };
      final item = MixedServiceOrder.normalizeOrderItem(
        (row['items'] as List).single as Map<String, dynamic>,
      );
      expect((item['quantity'] as num).toInt(), 2);
      expect(MixedServiceOrder.itemLineTotal(item), 360);
      expect(TableOrderHistoryUtils.revenue(row), 360);
      // A history row that never got a header total (6 older ones) derives it from its lines.
      expect(
        TableOrderHistoryUtils.revenue(<String, dynamic>{
          'grand_total': 0,
          'items': row['items'],
        }),
        360,
      );
    });

    test('mixed service: children carry the price (center journal shape)', () {
      final items = <Map<String, dynamic>>[
        <String, dynamic>{
          'item_type': 'mixed_service',
          'name': 'Karışık Servis',
          'quantity': 2,
          'child_items': <Map<String, dynamic>>[
            <String, dynamic>{'product_name': 'Beyti', 'quantity': 1, 'unit_price': 460, 'line_total': 460},
            <String, dynamic>{'product_name': 'Ciğer', 'quantity': 1, 'unit_price': 260, 'line_total': 260},
          ],
        },
      ];
      expect(orderTotal(items), 1440);
    });

    test('mixed service: flat cloud row, unit price 720 times 2', () {
      final items = normalizeRestaurantOrderItems(<dynamic>[
        <String, dynamic>{'product_name': 'Karışık Servis', 'quantity': 2, 'unit_price': 720, 'line_total': 1440},
      ]);
      expect(orderTotal(items), 1440);
    });

    test('size variant and weight (gram) lines keep unit price times quantity', () {
      final size = <String, dynamic>{
        'name': 'Pizza',
        'pricing_mode': 'size',
        'selected_size_name': 'Büyük',
        'quantity': 2,
        'price': 350.0,
      };
      final grams = <String, dynamic>{
        'name': 'Kuzu Pirzola',
        'pricing_mode': 'kilo',
        'selected_weight_grams': 250,
        'amount_label': '250 gr',
        'quantity': 3,
        'price': 187.5,
      };
      expect(orderTotal(<Map<String, dynamic>>[size]), 700);
      expect(orderTotal(<Map<String, dynamic>>[grams]), 562.5);
      final normalizedGrams = MixedServiceOrder.normalizeOrderItem(grams);
      expect(normalizedGrams['price'], 187.5);
    });

    test('free (ikram) lines stay zero and do not disturb the rest', () {
      final items = <Map<String, dynamic>>[
        <String, dynamic>{'name': 'İkram Çay', 'quantity': 2, 'price': 0},
        <String, dynamic>{'name': 'KATI CACIK', 'quantity': 2, 'price': 180.0},
      ];
      final normalizedFree = MixedServiceOrder.normalizeOrderItem(items.first);
      expect(MixedServiceOrder.itemLineTotal(normalizedFree), 0);
      expect(orderTotal(items), 360);
    });
  });
}
