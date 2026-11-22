import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/store/store_mapping_helpers.dart';

void main() {
  Map<String, dynamic> row(Map<String, dynamic> extra) => <String, dynamic>{
    'id': 'prd_1',
    'name': 'Cay',
    'price': 25,
    'created_at': '2026-01-01T00:00:00Z',
    ...extra,
  };

  test('the product row keeps its kitchen station', () {
    final product = mapSnakeCaseToProduct(row(<String, dynamic>{
      'station_id': 'st-1',
      'stations': <String, dynamic>{'name': 'Ocak', 'code': 'OCAK'},
    }));
    expect(product.stationId, 'st-1');
    expect(product.stationName, 'Ocak');
    expect(product.stationCode, 'OCAK');
  });

  test('a product without a station stays without one', () {
    final product = mapSnakeCaseToProduct(row(const <String, dynamic>{}));
    expect(product.stationId, isNull);
    expect(product.printerRoutingEnabled, isTrue);
  });
}
