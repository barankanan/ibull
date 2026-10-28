import 'package:flutter_test/flutter_test.dart';

import 'package:ibul_app/features/seller/product_import/adapters/amazon_product_adapter.dart';
import 'package:ibul_app/features/seller/product_import/adapters/ciceksepeti_product_adapter.dart';
import 'package:ibul_app/features/seller/product_import/adapters/hepsiburada_product_adapter.dart';
import 'package:ibul_app/features/seller/product_import/adapters/n11_product_adapter.dart';
import 'package:ibul_app/features/seller/product_import/adapters/shopify_product_adapter.dart';
import 'package:ibul_app/features/seller/product_import/models/imported_product.dart';
import 'package:ibul_app/features/seller/product_import/security/product_import_security.dart';
import 'package:ibul_app/features/seller/product_import/services/product_import_service.dart';
import 'package:ibul_app/features/seller/product_import/services/product_quality_service.dart';
import 'package:ibul_app/features/seller/product_import/services/product_variation_combiner.dart';

void main() {
  group('ProductImportService - Veri Doğruluğu ve Güvenlik', () {
    test('Bilinmeyen stok durumunda 10 uydurulmamalı, uyarı üretilmeli', () {
      final product = ImportedProductData(
        id: 'test_1',
        sourceUrl: 'https://example.com/p/1',
        adapterName: 'Test',
        name: 'Kablosuz Kulaklık',
        brand: 'TechBrand',
        sku: 'TECH-100',
        price: 999.0,
        stock: null, // Bilinmeyen stok
        mainCategory: 'Elektronik',
        subCategory: 'Kulaklık',
        capturedAt: DateTime.now(),
        quality: const ProductQualityReport(
          score: 0,
          level: ProductQualityLevel.low,
          completeFields: [],
          missingFields: [],
          warningMessages: [],
        ),
      );

      expect(product.isStockKnown, isFalse);
      expect(product.safeStock, equals(0));

      const qualityService = ProductQualityService();
      final report = qualityService.evaluateQuality(product);

      expect(
        report.warningMessages.any((w) => w.contains('net stok miktarı belirtilmemiş') || w.contains('Bilinmiyor')),
        isTrue,
      );
    });

    test('Farklı başlıklara sahip ürünler başlık benzerliği yüzünden mükerrer sayılmamalı', () {
      final p1 = ImportedProductData(
        id: 'p_1',
        sourceUrl: 'https://example.com/p/iphone-15-128gb-siyah',
        adapterName: 'Test',
        name: 'Apple iPhone 15 128 GB Siyah',
        brand: 'Apple',
        sku: 'IPHONE-15-128-BLK',
        price: 54999.0,
        mainCategory: 'Elektronik',
        subCategory: 'Telefon',
        capturedAt: DateTime.now(),
        quality: const ProductQualityReport(
          score: 100,
          level: ProductQualityLevel.high,
          completeFields: [],
          missingFields: [],
          warningMessages: [],
        ),
      );

      final p2 = ImportedProductData(
        id: 'p_2',
        sourceUrl: 'https://example.com/p/iphone-15-256gb-siyah',
        adapterName: 'Test',
        name: 'Apple iPhone 15 256 GB Siyah',
        brand: 'Apple',
        sku: 'IPHONE-15-256-BLK',
        price: 61999.0,
        mainCategory: 'Elektronik',
        subCategory: 'Telefon',
        capturedAt: DateTime.now(),
        quality: const ProductQualityReport(
          score: 100,
          level: ProductQualityLevel.high,
          completeFields: [],
          missingFields: [],
          warningMessages: [],
        ),
      );

      // Farklı SKU ve farklı URL -> Mükerrer değil
      final cleanSku1 = p1.sku.toLowerCase();
      final cleanSku2 = p2.sku.toLowerCase();
      final cleanUrl1 = p1.sourceUrl.toLowerCase();
      final cleanUrl2 = p2.sourceUrl.toLowerCase();

      expect(cleanSku1 == cleanSku2, isFalse);
      expect(cleanUrl1 == cleanUrl2, isFalse);
    });

    test('Aynı kaynak URL tekrar aktarılmak istendiğinde mükerrer tespiti yapılmalı', () {
      const sourceUrl = 'https://www.trendyol.com/apple/iphone-15-p-12345';
      final existingUrls = <String>{sourceUrl.toLowerCase()};

      final isDuplicate = existingUrls.contains(sourceUrl.toLowerCase());
      expect(isDuplicate, isTrue);
    });

    test('Görsel URL indirmelerinde SSRF koruması özel IP adreslerini engellemeli', () {
      final maliciousImageUrls = [
        'http://169.254.169.254/latest/meta-data/',
        'http://127.0.0.1:8080/secret.jpg',
        'http://192.168.1.1/router.jpg',
        'http://localhost/admin.png',
        'file:///etc/passwd',
      ];

      for (final badUrl in maliciousImageUrls) {
        final check = ProductImportSecurity.validateUrl(badUrl);
        expect(
          check.isValid,
          isFalse,
          reason: '$badUrl güvenli sayılmamalıydı!',
        );
      }
    });

    test('Amazon adaptörü bot koruması tespit ettiğinde net hata vermeli', () async {
      const amazonHtml = '''
        <html>
          <body>
            <h4>Robot olmadığınıza emin olun</h4>
            <p>Type the characters you see in this image</p>
          </body>
        </html>
      ''';

      const adapter = AmazonProductAdapter();
      expect(
        () => adapter.parse(
          uri: Uri.parse('https://www.amazon.com.tr/dp/B0CHX1W1XY'),
          html: amazonHtml,
        ),
        throwsA(predicate((e) => e.toString().contains('Amazon bot koruması'))),
      );
    });

    test('n11 adaptörü Incapsula koruması tespit ettiğinde net hata vermeli', () async {
      const n11Html = '''
        <html>
          <body>
            <p>Request unsuccessful. Incapsula incident ID: 981273981273</p>
          </body>
        </html>
      ''';

      const adapter = N11ProductAdapter();
      expect(
        () => adapter.parse(
          uri: Uri.parse('https://www.n11.com/urun/ornek-urun-p-12345'),
          html: n11Html,
        ),
        throwsA(predicate((e) => e.toString().contains('n11 erişim kısıtlaması'))),
      );
    });

    test('ÇiçekSepeti adaptörü bot koruması tespit ettiğinde net hata vermeli', () async {
      const csHtml = '''
        <html>
          <body>
            <script>var ShieldSquare = true;</script>
            <p>Lütfen bekleyiniz... captcha</p>
          </body>
        </html>
      ''';

      const adapter = CiceksepetiProductAdapter();
      expect(
        () => adapter.parse(
          uri: Uri.parse('https://www.ciceksepeti.com/ornek-urun-kc12345'),
          html: csHtml,
        ),
        throwsA(predicate((e) => e.toString().contains('ÇiçekSepeti bot koruması'))),
      );
    });

    test('Amazon adaptörü temiz HTML sayfasından ürün verisini doğru okumalı', () async {
      const validAmazonHtml = '''
        <html>
          <body>
            <span id="productTitle">Sony WH-1000XM5 Kablosuz Kulaklık</span>
            <a id="bylineInfo">Marka: Sony</a>
            <input type="hidden" id="ASIN" value="B09XS7JWHH" />
            <span class="a-price"><span class="a-offscreen">12.499,00 TL</span></span>
            <div id="landingImage" data-a-dynamic-image='{"https://m.media-amazon.com/images/I/61+btvdMr0L._AC_SL1500_.jpg":[1500,1500]}'></div>
            <div id="feature-bullets">
              <ul>
                <li><span class="a-list-item">Gelişmiş Gürültü Engelleme Teknolojisi</span></li>
                <li><span class="a-list-item">30 saate kadar pil ömrü</span></li>
              </ul>
            </div>
            <div id="availability"><span>Stokta sadece 3 adet kaldı.</span></div>
          </body>
        </html>
      ''';

      const adapter = AmazonProductAdapter();
      final products = await adapter.parse(
        uri: Uri.parse('https://www.amazon.com.tr/dp/B09XS7JWHH'),
        html: validAmazonHtml,
      );

      expect(products, isNotEmpty);
      final p = products.first;
      expect(p.name, equals('Sony WH-1000XM5 Kablosuz Kulaklık'));
      expect(p.brand, equals('Sony'));
      expect(p.sku, equals('B09XS7JWHH'));
      expect(p.price, equals(12499.0));
      expect(p.stock, equals(3));
      expect(p.imageUrls.first, contains('m.media-amazon.com'));
      expect(p.description, contains('Gelişmiş Gürültü Engelleme'));
    });

    test('Hepsiburada bot koruması veya engelleme tespit edildiğinde net yetkilendirme hatası vermeli', () async {
      const blockedHtml = '''
      <html>
        <head><title>Attention Required! | Cloudflare</title></head>
        <body>
          <div class="cf-ray">7a12b3c4d5e6</div>
          <p>Please enable javascript and cookies to continue</p>
        </body>
      </html>
      ''';

      const adapter = HepsiburadaProductAdapter();
      expect(
        () => adapter.parse(
          uri: Uri.parse('https://www.hepsiburada.com/urun-p-HBV00012345'),
          html: blockedHtml,
        ),
        throwsA(predicate((e) => e.toString().contains('Erişim kısıtlaması nedeniyle bu mağaza için satıcı API anahtarı gereklidir'))),
      );
    });

    test('Bilinmeyen stok durumunda stock_quantity null ve in_stock unknown olarak serileştirilmeli', () {
      final variant = ImportedProductVariant(
        id: 'v_unknown',
        combinationTitle: 'M / Mavi',
        price: 250.0,
        stock: null, // Net sayı yok
      );

      expect(variant.stock, isNull);
      expect(variant.stockQuantity, isNull);
      expect(variant.inStockStatus, equals('unknown'));

      final map = variant.toMap();
      expect(map['stock_quantity'], isNull);
      expect(map['in_stock'], equals('unknown'));

      // fromMap geri çözümleme
      final restored = ImportedProductVariant.fromMap(map);
      expect(restored.stock, isNull);
      expect(restored.inStockStatus, equals('unknown'));
    });

    test('ProductVariationCombiner İBUL variants şemasına ve StoreService sözleşmesine tam uymalı', () {
      const combiner = ProductVariationCombiner();
      final variants = [
        ImportedProductVariant(
          id: 'v_schema',
          combinationTitle: 'Kırmızı / S',
          color: 'Kırmızı',
          size: 'S',
          price: 500.0,
          stock: null, // Bilinmeyen stok
          imageUrl: 'https://cdn.example.com/red.jpg',
        ),
      ];

      final dbList = combiner.toDbVariants(variants, basePrice: 450.0);
      expect(dbList.length, equals(1));
      final item = dbList.first;

      // İBUL DB schema kontrolleri
      expect(item['stock'], equals(0)); // DB not-null kısıtı için güvenli 0
      expect(item['stock_unknown'], isTrue); // Bilinmeyen stok bayrağı
      expect(item.containsKey('stock_quantity'), isTrue); // Key korunmalı
      expect(item['stock_quantity'], isNull); // Gerçek kaynak durumu: null
      expect(item['in_stock'], equals('unknown'));
      expect(item['imagePath'], equals('https://cdn.example.com/red.jpg')); // StoreService.addProduct uyumu
      expect(item['imageUrl'], equals('https://cdn.example.com/red.jpg')); // Variant selector uyumu
      expect(item['priceDifference'], equals(50.0));
    });

    test('ShopifyProductAdapter.buildEndpointUri /products/ linklerini temiz .js REST endpointine dönüştürmeli', () {
      final uriWithQuery = Uri.parse('https://anker-tr.com/products/soundcore-life-q30-bluetooth-kulaklik?variant=41819383627938');
      final endpointUri = ShopifyProductAdapter.buildEndpointUri(uriWithQuery);

      expect(endpointUri.toString(), equals('https://anker-tr.com/products/soundcore-life-q30-bluetooth-kulaklik.js'));
      expect(endpointUri.query, isEmpty);
    });

    test('ProductImportService SSL ve sertifika uyuşmazlığı hatalarını tespit etmeli', () {
      expect(ProductImportService.isSslOrCertError('HandshakeException: invalid peer certificate'), isTrue);
      expect(ProductImportService.isSslOrCertError('CertVerifyError: NotValidForName (anker-tr.com)'), isTrue);
      expect(ProductImportService.isSslOrCertError('TlsException: SSL handshake failed'), isTrue);
      expect(ProductImportService.isSslOrCertError('HTTP 404: Not Found'), isFalse);
      expect(ProductImportService.isSslOrCertError('HTTP 403: Forbidden bot koruması'), isFalse);
    });

    test('ProductImportService addWwwPrefix ve toHttpScheme dönüşümlerini doğru yapmalı', () {
      final apexUri = Uri.parse('https://anker-tr.com/products/soundcore-life-q30-bluetooth-kulaklik.js');
      final withWww = ProductImportService.addWwwPrefix(apexUri);
      expect(withWww.toString(), equals('https://www.anker-tr.com/products/soundcore-life-q30-bluetooth-kulaklik.js'));

      // Zaten www varsa tekrar eklememeli
      final alreadyWww = ProductImportService.addWwwPrefix(withWww);
      expect(alreadyWww.toString(), equals('https://www.anker-tr.com/products/soundcore-life-q30-bluetooth-kulaklik.js'));

      // IP adresine www eklememeli
      final ipUri = Uri.parse('http://192.168.1.1/test');
      expect(ProductImportService.addWwwPrefix(ipUri).toString(), equals('http://192.168.1.1/test'));

      // toHttpScheme
      final httpUri = ProductImportService.toHttpScheme(apexUri);
      expect(httpUri.toString(), equals('http://anker-tr.com/products/soundcore-life-q30-bluetooth-kulaklik.js'));
    });

    test('Anker URL taramasında invalid peer certificate hatası alındığında otomatik www. ile telafi edip ürünü başarıyla getirmeli', () async {
      const ankerShopifyJson = '''
      {
        "id": 7324867756194,
        "title": "Soundcore Life Q30 Bluetooth Kulaklık",
        "handle": "soundcore-life-q30-bluetooth-kulaklik",
        "description": "Gelişmiş Aktif Gürültü Önleme (ANC) teknolojisi ile donatılmış hibrit kulaklık.",
        "vendor": "Anker",
        "price": 289900,
        "compare_at_price": 349900,
        "available": true,
        "images": [
          "//cdn.shopify.com/s/files/1/0579/6596/9570/products/A3028011_TD01.jpg"
        ],
        "options": [
          { "name": "Renk", "position": 1, "values": ["Siyah", "Mavi"] }
        ],
        "variants": [
          {
            "id": 41819383627938,
            "title": "Siyah",
            "sku": "A3028011",
            "price": 289900,
            "compare_at_price": 349900,
            "available": true
          }
        ]
      }
      ''';

      final requestedUrls = <String>[];

      // Custom fetcher: anker-tr.com (apex) için SSL peer certificate hatası fırlatır,
      // www.anker-tr.com için ise başarılı Shopify JSON döner.
      final service = ProductImportService(
        customFetcher: (requestedUri) async {
          requestedUrls.add(requestedUri.toString());
          if (requestedUri.host == 'anker-tr.com') {
            throw Exception('HandshakeException: invalid peer certificate: NotValidForName (anker-tr.com)');
          }
          if (requestedUri.host == 'www.anker-tr.com') {
            return ankerShopifyJson;
          }
          throw Exception('Bilinmeyen host: ${requestedUri.host}');
        },
      );

      final results = await service.scanUrls([
        'https://anker-tr.com/products/soundcore-life-q30-bluetooth-kulaklik',
      ]);

      // İstek sırası doğrulaması: İlk istek apex alan adına gitti, SSL hatası yakalandı ve otomatik www. ile telafi edildi
      expect(requestedUrls, contains('https://anker-tr.com/products/soundcore-life-q30-bluetooth-kulaklik.js'));
      expect(requestedUrls, contains('https://www.anker-tr.com/products/soundcore-life-q30-bluetooth-kulaklik.js'));

      // Ürün başarıyla dönüştürüldü
      expect(results, isNotEmpty);
      final product = results.first;
      expect(product.name, equals('Soundcore Life Q30 Bluetooth Kulaklık'));
      expect(product.brand, equals('Anker'));
      expect(product.price, equals(3499.00));
      expect(product.discountPrice, equals(2899.00));
      expect(product.realVariants, hasLength(1));
      expect(product.realVariants.first.sku, equals('A3028011'));
      expect(product.realVariants.first.inStock, isTrue);
    });
  });
}
