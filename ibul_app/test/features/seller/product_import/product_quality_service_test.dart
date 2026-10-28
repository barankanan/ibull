import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/product_import/models/imported_product.dart';
import 'package:ibul_app/features/seller/product_import/services/product_quality_service.dart';

void main() {
  group('ProductQualityService', () {
    const service = ProductQualityService();

    test('Eksiksiz ürün için yüksek kalite skoru (100) vermeli', () {
      final product = ImportedProductData(
        id: 'test_1',
        sourceUrl: 'https://example.com/item',
        adapterName: 'Test',
        name: 'Kablosuz Oyuncu Kulaklığı',
        brand: 'HyperX',
        sku: 'HYPER-001',
        barcode: '868000000001',
        price: 2499.90,
        currency: 'TRY',
        stock: 15,
        mainCategory: 'Elektronik',
        subCategory: 'Kulaklık',
        description: '7.1 Surround ses deneyimi.',
        imageUrls: const ['https://example.com/headset.jpg'],
        specifications: const {'Bağlantı': 'Bluetooth'},
        capturedAt: DateTime.now(),
        quality: const ProductQualityReport(
          score: 0,
          level: ProductQualityLevel.low,
          completeFields: [],
          missingFields: [],
          warningMessages: [],
        ),
      );

      final report = service.evaluateQuality(product);

      expect(report.score, 100);
      expect(report.level, ProductQualityLevel.high);
      expect(report.missingFields, isEmpty);
      expect(report.isReadyForImport, isTrue);
    });

    test('Zorunlu alanlar eksik olduğunda düşük kalite ve uyarı vermeli', () {
      final incompleteProduct = ImportedProductData(
        id: 'test_2',
        sourceUrl: 'https://example.com/item',
        adapterName: 'Test',
        name: '', // Ad eksik
        brand: '',
        sku: '',
        price: 0.0, // Fiyat eksik
        currency: 'USD', // Farklı para birimi
        stock: 0, // Stok yok
        mainCategory: 'BilinmeyenKategori',
        subCategory: '',
        imageUrls: const [], // Görsel yok
        capturedAt: DateTime.now(),
        quality: const ProductQualityReport(
          score: 0,
          level: ProductQualityLevel.low,
          completeFields: [],
          missingFields: [],
          warningMessages: [],
        ),
      );

      final report = service.evaluateQuality(incompleteProduct);

      expect(report.score, lessThan(50));
      expect(report.level, ProductQualityLevel.low);
      expect(report.missingFields, contains('Ürün Adı'));
      expect(report.missingFields, contains('Fiyat'));
      expect(report.missingFields, contains('Görseller'));
      expect(report.warningMessages, anyElement(contains('USD')));
      expect(report.warningMessages, anyElement(contains('stokta yok')));
      expect(report.isReadyForImport, isFalse);
    });

    test('Harici kategorileri İBUL 10 ana kategorisine doğru haritalamalı', () {
      expect(service.mapToMainCategory('Kadın Elbise & Modelleri'), 'Giyim & Aksesuar');
      expect(service.mapToMainCategory('Akıllı Cep Telefonları'), 'Elektronik');
      expect(service.mapToMainCategory('Mutfak & Banyo Aksesuarları'), 'Ev & Yaşam');
      expect(service.mapToMainCategory('Cilt Bakım Kremleri & Makyaj'), 'Kozmetik & Kişisel Bakım');
      expect(service.mapToMainCategory('Spor Ayakkabı & Fitness Ekipmanları'), 'Giyim & Aksesuar'); // Ayakkabı önceliği
      expect(service.mapToMainCategory('Fitness Ağırlık & Kamp Malzemeleri'), 'Spor & Outdoor');
      expect(service.mapToMainCategory('Bebek Oyuncakları & Beşik'), 'Anne & Bebek & Oyuncak');
      expect(service.mapToMainCategory('Edebiyat Roman Kitapları'), 'Kitap & Hobi');
      expect(service.mapToMainCategory('Kedi Köpek Maması & Petshop'), 'Süpermarket & Petshop');
      expect(service.mapToMainCategory('İkinci El Otomobil Yedek Parça'), '2.el Ürünler');
    });
  });
}
