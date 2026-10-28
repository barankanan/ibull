import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/seller/add_product_page.dart';

void main() {
  group('ProductVariant Options & Multi-Option Model Tests', () {
    test('ProductVariant stores options Map and serializes toMap correctly', () {
      final variant = ProductVariant(
        color: 'Siyah',
        colorHex: '#000000',
        size: '2 Metre',
        optionType: 'Uzunluk',
        options: {
          'Uzunluk': '2 Metre',
          'Bağlantı Türü': 'Type-C',
          'Kapasite': '65W Hızlı Şarj',
        },
        sku: 'ANK-CBL-BLK-2M',
        stock: 50,
        priceDifference: 45.0,
      );

      final map = variant.toMap();

      expect(map['color'], 'Siyah');
      expect(map['colorHex'], '#000000');
      expect(map['color_hex'], '#000000');
      expect(map['size'], '2 Metre');
      expect(map['optionType'], 'Uzunluk');
      expect(map['option_type'], 'Uzunluk');
      expect(map['options'], isNotNull);
      expect(map['options']['Uzunluk'], '2 Metre');
      expect(map['options']['Bağlantı Türü'], 'Type-C');
      expect(map['options']['Kapasite'], '65W Hızlı Şarj');
      expect(map['sku'], 'ANK-CBL-BLK-2M');
      expect(map['stock'], 50);
      expect(map['priceDifference'], 45.0);
    });

    test('ProductVariant backward compatibility without options Map', () {
      final variant = ProductVariant(
        color: 'Beyaz',
        size: 'XL',
        optionType: 'Beden',
        sku: 'TSH-WHT-XL',
        stock: 20,
        priceDifference: 0.0,
      );

      final map = variant.toMap();

      expect(map['color'], 'Beyaz');
      expect(map['size'], 'XL');
      expect(map['optionType'], 'Beden');
      expect(map.containsKey('options'), isFalse);
    });

    test('ProductVariant deserialization simulation preserves options Map', () {
      final rawDbMap = {
        'color': 'Gece Mavisi',
        'color_hex': '#000080',
        'size': '42',
        'option_type': 'Numara',
        'options': {
          'Numara': '42',
          'Kalıp': 'Geniş Kalıp',
        },
        'sku': 'SHOE-NVY-42',
        'stock': 15,
        'priceDifference': 100.0,
      };

      Map<String, String>? parsedOptions;
      if (rawDbMap['options'] is Map) {
        parsedOptions = (rawDbMap['options'] as Map).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }

      final variant = ProductVariant(
        color: rawDbMap['color'] as String,
        colorHex: rawDbMap['color_hex'] as String?,
        size: rawDbMap['size'] as String,
        optionType: rawDbMap['option_type'] as String?,
        options: parsedOptions,
        sku: rawDbMap['sku'] as String,
        stock: rawDbMap['stock'] as int,
        priceDifference: (rawDbMap['priceDifference'] as num).toDouble(),
      );

      expect(variant.options, isNotNull);
      expect(variant.options!['Numara'], '42');
      expect(variant.options!['Kalıp'], 'Geniş Kalıp');
    });
  });
}
