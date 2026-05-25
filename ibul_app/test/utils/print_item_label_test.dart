import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/kitchen_routing_service.dart';
import 'package:ibul_app/utils/garson_product_selection.dart';

void main() {
  group('resolvePrintItemLabel', () {
    test('weight item keeps display_label', () {
      final item = <String, dynamic>{
        'name': 'Ciğer Servis',
        'display_label': 'Ciğer Servis 300 g',
        'amount_label': '300 g',
        'pricing_mode': 'kilo',
        'selected_grams': 300,
      };
      expect(
        GarsonProductSelection.resolvePrintItemLabel(item),
        'Ciğer Servis 300 g',
      );
    });

    test('name missing gram but display_label has gram', () {
      final item = <String, dynamic>{
        'name': 'Ciğer Servis',
        'display_label': 'Ciğer Servis 1 kg',
        'amount_label': '1 kg',
        'pricing_mode': 'kilo',
        'selected_weight_grams': 1000,
      };
      expect(
        GarsonProductSelection.resolvePrintItemLabel(item),
        'Ciğer Servis 1 kg',
      );
    });

    test('amount_label exists but display_label missing appends amount', () {
      final item = <String, dynamic>{
        'name': 'Kemiksiz Tavuk Servis',
        'amount_label': '500 g',
        'pricing_mode': 'kilo',
        'selected_grams': 500,
      };
      expect(
        GarsonProductSelection.resolvePrintItemLabel(item),
        'Kemiksiz Tavuk Servis 500 g',
      );
    });

    test('size item keeps selected_size_name', () {
      final item = <String, dynamic>{
        'name': 'Kemiksiz Tavuk Servis',
        'selected_size_name': 'Tek',
        'pricing_mode': 'size',
      };
      expect(
        GarsonProductSelection.resolvePrintItemLabel(item),
        'Kemiksiz Tavuk Servis Tek',
      );
    });

    test('portion item stays plain name', () {
      final item = <String, dynamic>{
        'name': 'Ciğer Servis',
        'pricing_mode': 'portion',
      };
      expect(
        GarsonProductSelection.resolvePrintItemLabel(item),
        'Ciğer Servis',
      );
    });
  });

  group('kitchen routing payload', () {
    test('gramajlı name with product_name base resolves print label', () {
      final item = <String, dynamic>{
        'name': 'Ciğer Servis 300 g',
        'product_name': 'Ciğer Servis',
        'amount_label': '300 g',
        'pricing_mode': 'kilo',
      };
      expect(
        GarsonProductSelection.resolvePrintItemLabel(item),
        'Ciğer Servis 300 g',
      );
    });

    test('kitchen payload weight item keeps display_label on name', () {
      final routing = const KitchenRoutingService().normalizeItems(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Ciğer Servis',
            'display_label': 'Ciğer Servis 300 g',
            'amount_label': '300 g',
            'pricing_mode': 'kilo',
            'selected_grams': 300,
            'quantity': 1,
            'price': 10,
          },
        ],
      );
      expect(routing, hasLength(1));
      final map = routing.single.toPayloadMap();
      expect(map['name'], 'Ciğer Servis 300 g');
      expect(map['display_label'], 'Ciğer Servis 300 g');
      expect(map['amount_label'], '300 g');
      expect(map['product_name'], 'Ciğer Servis');
    });
  });
}
