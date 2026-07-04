import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/product_rich_description.dart'
    show ProductRichDescriptionBlock;
import 'package:ibul_app/models/seller_product.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_csv_parser.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_import_mapping.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_import_models.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_import_validator.dart';

void main() {
  const BulkProductCsvParser parser = BulkProductCsvParser();
  const BulkProductImportValidator validator = BulkProductImportValidator();

  group('CSV template', () {
    test('canonical kolonlar mevcut', () {
      expect(
        bulkProductImportCanonicalHeaders,
        containsAll(<String>[
          'product_name',
          'brand',
          'main_category',
          'sub_category',
          'attributes_json',
          'variants_json',
          'kargo_agirlik_kg',
          'en_cm',
          'boy_cm',
          'yukseklik_cm',
          'highlights_json',
          'key_features',
          'delivery_time',
          'estimated_delivery_days',
          'rich_description_json',
          'description_image_urls',
          'description_image_captions',
          'long_description',
        ]),
      );
    });

    test('UTF-8 BOM içerir', () {
      final bytes = buildBulkProductImportTemplateBytes();
      expect(bytes.length, greaterThan(3));
      expect(bytes[0], 0xEF);
      expect(bytes[1], 0xBB);
      expect(bytes[2], 0xBF);
    });

    test('örnek satırlar içerir', () {
      final csv = buildBulkProductImportTemplateCsv();
      expect(csv, contains('iPhone 15 Pro 256 GB'));
      expect(csv, contains('highlights_json'));
      expect(csv, contains('256 GB depolama'));
    });
  });

  group('CSV parser', () {
    test('noktalı virgül ayırıcıyı destekler', () {
      const String csv =
          'product_name;price;stock_quantity;brand;main_category;sub_category;status\n'
          'Test Ürün;100;5;Marka;Elektronik;Telefon;active';
      final document = parser.parseString(csv);
      expect(document.headers, contains('product_name'));
      expect(document.rows.first['product_name'], 'Test Ürün');
    });
  });

  group('CSV validator', () {
    test('geçerli elektronik satırı kabul eder', () {
      final String csv = buildBulkProductImportTemplateCsv();
      final document = parser.parseString(csv);
      final preview = validator.validate(
        fileName: 'test.csv',
        document: document,
        lockedMainCategory: 'Elektronik',
      );
      expect(preview.validRowCount, greaterThanOrEqualTo(3));
    });

    test('attributes_json içindeki çoklu özellikler eksiksiz parse edilir', () {
      const String csv =
          'product_name,brand,main_category,sub_category,price,stock_quantity,status,attributes_json\n'
          'Telefon X,Marka,Elektronik,Telefon,1000,3,pending_approval,'
          '"{""Renk"":""Siyah"",""RAM Kapasitesi"":""8 GB"",""Dahili Hafıza"":""256 GB"",""Ekran Boyutu"":""6.1 inç"",""Garanti Süresi"":""24 Ay""}"';
      final document = parser.parseString(csv);
      final preview = validator.validate(
        fileName: 'attrs.csv',
        document: document,
        lockedMainCategory: 'Elektronik',
      );
      final candidate = preview.rows.first.candidate!;
      expect(candidate.attributesMap.length, 5);
      expect(candidate.attributesMap['RAM Kapasitesi'], '8 GB');
    });

    test('description uzun metin korunur', () {
      final String longDescription =
          List<String>.filled(40, 'Detaylı açıklama cümlesi.').join(' ');
      final String csv =
          'product_name,brand,main_category,sub_category,price,stock_quantity,status,description\n'
          'Telefon X,Marka,Elektronik,Telefon,1000,3,pending_approval,"$longDescription"';
      final document = parser.parseString(csv);
      final preview = validator.validate(
        fileName: 'desc.csv',
        document: document,
        lockedMainCategory: 'Elektronik',
      );
      expect(preview.rows.first.candidate?.description, longDescription);
    });

    test('kargo alanları parse edilir', () {
      const String csv =
          'product_name,brand,main_category,sub_category,price,stock_quantity,status,'
          'cargo_weight_kg,cargo_width_cm,cargo_length_cm,cargo_height_cm,cargo_shipping_profile,free_shipping\n'
          'Telefon X,Marka,Elektronik,Telefon,1000,3,pending_approval,0.35,10,18,5,standart,evet';
      final document = parser.parseString(csv);
      final preview = validator.validate(
        fileName: 'cargo.csv',
        document: document,
        lockedMainCategory: 'Elektronik',
      );
      final candidate = preview.rows.first.candidate!;
      expect(candidate.cargoWeightKg, 0.35);
      expect(candidate.cargoWidthCm, 10);
      expect(candidate.cargoLengthCm, 18);
      expect(candidate.cargoHeightCm, 5);
      expect(candidate.cargoShippingProfile, 'standart');
      expect(candidate.freeShipping, isTrue);
    });

    test('virgüllü ondalık kargo ağırlığı parse edilir', () {
      const String csv =
          'product_name,brand,main_category,sub_category,price,stock_quantity,status,cargo_weight_kg\n'
          'Telefon X,Marka,Elektronik,Telefon,1000,3,pending_approval,"0,35"';
      final document = parser.parseString(csv);
      final preview = validator.validate(
        fileName: 'cargo-comma.csv',
        document: document,
        lockedMainCategory: 'Elektronik',
      );
      expect(preview.rows.first.candidate?.cargoWeightKg, 0.35);
    });

    test('highlights_json parse edilir', () {
      const String csv =
          'product_name,brand,main_category,sub_category,price,stock_quantity,status,highlights_json\n'
          'Telefon X,Marka,Elektronik,Telefon,1000,3,pending_approval,'
          '"[""128 GB depolama"",""6.1 inç OLED ekran"",""24 ay garanti""]"';
      final document = parser.parseString(csv);
      final preview = validator.validate(
        fileName: 'highlights.csv',
        document: document,
        lockedMainCategory: 'Elektronik',
      );
      expect(
        preview.rows.first.candidate?.highlightInfos,
        <String>[
          '128 GB depolama',
          '6.1 inç OLED ekran',
          '24 ay garanti',
        ],
      );
    });

    test('key_features pipe formatı parse edilir', () {
      const String csv =
          'product_name,brand,main_category,sub_category,price,stock_quantity,status,key_features\n'
          'Telefon X,Marka,Elektronik,Telefon,1000,3,pending_approval,'
          '128 GB depolama | 6.1 inç OLED ekran | 24 ay garanti';
      final document = parser.parseString(csv);
      final preview = validator.validate(
        fileName: 'key-features.csv',
        document: document,
        lockedMainCategory: 'Elektronik',
      );
      expect(preview.rows.first.candidate?.highlightInfos.length, 3);
    });

    test('free_shipping false/hayır/0 parse edilir', () {
      for (final String raw in <String>['false', 'hayır', '0']) {
        final String csv =
            'product_name,brand,main_category,sub_category,price,stock_quantity,status,free_shipping\n'
            'Telefon X,Marka,Elektronik,Telefon,1000,3,pending_approval,$raw';
        final document = parser.parseString(csv);
        final preview = validator.validate(
          fileName: 'free-shipping.csv',
          document: document,
          lockedMainCategory: 'Elektronik',
        );
        expect(preview.rows.first.candidate?.freeShipping, isFalse);
      }
    });

    test('geçersiz kargo alanı satır hatası verir', () {
      const String csv =
          'product_name,brand,main_category,sub_category,price,stock_quantity,status,cargo_weight_kg\n'
          'Telefon X,Marka,Elektronik,Telefon,1000,3,pending_approval,abc';
      final document = parser.parseString(csv);
      final preview = validator.validate(
        fileName: 'bad-cargo.csv',
        document: document,
        lockedMainCategory: 'Elektronik',
      );
      expect(
        preview.rows.first.errors,
        contains('cargo_weight_kg sayısal olmalı'),
      );
    });

    test('eski CSV şablonu highlights kolonları olmadan çalışır', () {
      const String csv =
          'product_name,brand,main_category,sub_category,price,stock_quantity,status\n'
          'Telefon X,Marka,Elektronik,Telefon,1000,3,pending_approval';
      final document = parser.parseString(csv);
      final preview = validator.validate(
        fileName: 'legacy.csv',
        document: document,
        lockedMainCategory: 'Elektronik',
      );
      expect(preview.rows.first.isValid, isTrue);
      expect(preview.rows.first.candidate?.highlightInfos, isEmpty);
    });

    test('long_description paragraf boşlukları korunur', () {
      const String csv =
          'product_name,brand,main_category,sub_category,price,stock_quantity,status,long_description\n'
          'Telefon X,Marka,Elektronik,Telefon,1000,3,pending_approval,'
          '"Birinci paragraf metni.\n\nİkinci paragraf metni."';
      final document = parser.parseString(csv);
      final preview = validator.validate(
        fileName: 'long-desc.csv',
        document: document,
        lockedMainCategory: 'Elektronik',
      );
      expect(
        preview.rows.first.candidate?.description,
        'Birinci paragraf metni.\n\nİkinci paragraf metni.',
      );
    });

    test('rich_description_json parse edilir', () {
      const String csv =
          'product_name,brand,main_category,sub_category,price,stock_quantity,status,rich_description_json\n'
          'Telefon X,Marka,Elektronik,Telefon,1000,3,pending_approval,'
          '"[{""type"":""paragraph"",""text"":""Ana paragraf""},{""type"":""image"",""url"":""https://example.com/a.jpg"",""caption"":""Detay""}]"';
      final document = parser.parseString(csv);
      final preview = validator.validate(
        fileName: 'rich-desc.csv',
        document: document,
        lockedMainCategory: 'Elektronik',
      );
      final blocks = preview.rows.first.candidate!.richDescriptionBlocks;
      expect(blocks.length, 2);
      expect(blocks.first.isParagraph, isTrue);
      expect(blocks.last.type, 'image');
    });

    test('description_image_urls pipe formatı parse edilir', () {
      final resolution = resolveBulkImportDescriptionFields(<String, String>{
        'long_description': 'Paragraf bir',
        'description_image_urls':
            'https://example.com/a.jpg | https://example.com/b.jpg',
        'description_image_captions': 'Bir | İki',
      });
      expect(
        resolution.richBlocks.where((ProductRichDescriptionBlock b) => b.isImage).length,
        2,
      );
    });

    test('long_description ve image_urls otomatik rich blok üretir', () {
      final resolution = resolveBulkImportDescriptionFields(<String, String>{
        'long_description': 'Paragraf bir\n\nParagraf iki',
        'description_image_urls': 'https://example.com/a.jpg',
        'description_image_captions': 'Görsel açıklaması',
      });
      expect(resolution.richBlocks, isNotEmpty);
      expect(
        resolution.richBlocks.any((ProductRichDescriptionBlock b) => b.isParagraph),
        isTrue,
      );
      expect(
        resolution.richBlocks.any((ProductRichDescriptionBlock b) => b.isImage),
        isTrue,
      );
    });

    test('eski CSV description alanı hâlâ çalışır', () {
      const String csv =
          'product_name,brand,main_category,sub_category,price,stock_quantity,status,description\n'
          'Telefon X,Marka,Elektronik,Telefon,1000,3,pending_approval,Klasik açıklama metni';
      final document = parser.parseString(csv);
      final preview = validator.validate(
        fileName: 'legacy-desc.csv',
        document: document,
        lockedMainCategory: 'Elektronik',
      );
      expect(preview.rows.first.candidate?.description, 'Klasik açıklama metni');
      expect(preview.rows.first.candidate?.richDescriptionBlocks, isEmpty);
    });

    test('bozuk rich_description_json satır hatası üretir', () {
      const String csv =
          'product_name,brand,main_category,sub_category,price,stock_quantity,status,rich_description_json\n'
          'Telefon X,Marka,Elektronik,Telefon,1000,3,pending_approval,{broken';
      final document = parser.parseString(csv);
      final preview = validator.validate(
        fileName: 'bad-rich.csv',
        document: document,
        lockedMainCategory: 'Elektronik',
      );
      expect(
        preview.rows.first.errors,
        contains('rich_description_json geçerli JSON olmalı'),
      );
    });
  });

  group('import payload mapping', () {
    test('kargo alanları specifications içinde düz anahtar olarak yazılır', () {
      const BulkProductImportCandidate candidate = BulkProductImportCandidate(
        productName: 'Telefon X',
        brand: 'Marka',
        mainCategory: 'Elektronik',
        subCategory: 'Telefon',
        price: 1000,
        stock: 3,
        cargoWeightKg: 0.35,
        cargoWidthCm: 10,
        cargoLengthCm: 18,
        cargoHeightCm: 5,
        cargoShippingProfile: 'standart',
        freeShipping: false,
      );

      final Map<String, dynamic> specs = decodeBulkImportSpecificationsMap(
        buildBulkImportSpecificationsJson(candidate, food: false),
      );

      expect(specs['weightKg'], 0.35);
      expect(specs['widthCm'], 10);
      expect(specs['lengthCm'], 18);
      expect(specs['heightCm'], 5);
      expect(readSpecificationCargoDouble(specs, 'weightKg'), 0.35);
    });

    test('attributes ve highlights ürün alanlarına yazılır', () {
      const BulkProductImportCandidate candidate = BulkProductImportCandidate(
        productName: 'Telefon X',
        brand: 'Marka',
        mainCategory: 'Elektronik',
        subCategory: 'Telefon',
        price: 1000,
        stock: 3,
        attributesMap: <String, String>{'RAM Kapasitesi': '8 GB'},
        highlightInfos: <String>['128 GB depolama'],
        description: 'Uzun açıklama metni korunmalı.',
      );

      final SellerProduct product = SellerProduct(
        id: '1',
        name: candidate.productName!,
        brand: candidate.brand!,
        mainCategory: 'Elektronik',
        subCategory: 'Telefon',
        price: candidate.price!,
        stock: candidate.stock!,
        sku: 'SKU-1',
        status: 'pending_approval',
        description: normalizeBulkImportDescription(candidate.description),
        specifications: buildBulkImportSpecificationsJson(candidate, food: false),
        attributes: buildBulkImportAttributeLines(candidate),
        additionalInfoItems: candidate.highlightInfos,
        additionalInfo: candidate.highlightInfos.join('\n'),
        createdAt: DateTime(2026),
      );

      expect(product.description, 'Uzun açıklama metni korunmalı.');
      expect(product.attributes, contains('RAM Kapasitesi: 8 GB'));
      expect(product.additionalInfoItems, <String>['128 GB depolama']);
      expect(product.additionalInfo, '128 GB depolama');
    });

    test('rich description specifications içine yazılır', () {
      const BulkProductImportCandidate candidate = BulkProductImportCandidate(
        productName: 'Telefon X',
        brand: 'Marka',
        mainCategory: 'Elektronik',
        subCategory: 'Telefon',
        price: 1000,
        stock: 3,
        description: 'Uzun açıklama',
        richDescriptionBlocks: <ProductRichDescriptionBlock>[
          ProductRichDescriptionBlock(
            type: 'paragraph',
            text: 'Paragraf metni',
          ),
          ProductRichDescriptionBlock(
            type: 'image',
            url: 'https://example.com/detail.jpg',
            caption: 'Detay',
          ),
        ],
      );

      final Map<String, dynamic> specs = decodeBulkImportSpecificationsMap(
        buildBulkImportSpecificationsJson(candidate, food: false),
      );

      expect(specs['rich_description_json'], isA<List<dynamic>>());
      expect((specs['rich_description_json'] as List).length, 2);
    });

    test('attributes_json rich description ile karışmaz', () {
      const BulkProductImportCandidate candidate = BulkProductImportCandidate(
        productName: 'Telefon X',
        brand: 'Marka',
        mainCategory: 'Elektronik',
        subCategory: 'Telefon',
        price: 1000,
        stock: 3,
        attributesMap: <String, String>{'RAM Kapasitesi': '8 GB'},
        richDescriptionBlocks: <ProductRichDescriptionBlock>[
          ProductRichDescriptionBlock(type: 'paragraph', text: 'Açıklama paragrafı'),
        ],
      );

      final Map<String, dynamic> specs = decodeBulkImportSpecificationsMap(
        buildBulkImportSpecificationsJson(candidate, food: false),
      );

      expect(specs['attributes'], isA<Map>());
      expect((specs['attributes'] as Map)['RAM Kapasitesi'], '8 GB');
      expect(specs.containsKey('rich_description_json'), isTrue);
      expect((specs['attributes'] as Map).containsKey('rich_description_json'), isFalse);
    });
  });

  group('CSV status', () {
    test('active onay bekleyen duruma çevrilir', () {
      expect(bulkProductImportPersistedStatus('active'), 'pending_approval');
    });
  });
}
