import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/product_import/adapters/open_graph_product_adapter.dart';
import 'package:ibul_app/features/seller/product_import/adapters/shopify_product_adapter.dart';
import 'package:ibul_app/features/seller/product_import/adapters/trendyol_product_adapter.dart';

void main() {
  group('ShopifyProductAdapter', () {
    const adapter = ShopifyProductAdapter();

    test('Shopify JSON script etiketinden varyasyonları ve seçenekleri eksiksiz çıkarmalı', () async {
      const html = '''
      <!DOCTYPE html>
      <html>
      <head>
        <script id="ProductJson-1" type="application/json">
        {
          "id": 8941235,
          "title": "Deri Ceket",
          "vendor": "Vakko",
          "body_html": "<p>Hakiki deri ceket.</p>",
          "images": ["https://cdn.shopify.com/s/files/1/jacket1.jpg"],
          "options": [
            {"name": "Renk", "position": 1, "values": ["Siyah", "Kahverengi"]},
            {"name": "Beden", "position": 2, "values": ["M", "L"]}
          ],
          "variants": [
            {
              "id": 101,
              "title": "Siyah / M",
              "option1": "Siyah",
              "option2": "M",
              "sku": "VAKKO-BLK-M",
              "price": "7500.00",
              "compare_at_price": "8500.00",
              "available": true,
              "inventory_quantity": 4
            },
            {
              "id": 102,
              "title": "Kahverengi / L",
              "option1": "Kahverengi",
              "option2": "L",
              "sku": "VAKKO-BRN-L",
              "price": "7500.00",
              "available": true,
              "inventory_quantity": 2
            }
          ]
        }
        </script>
      </head>
      <body></body>
      </html>
      ''';

      final uri = Uri.parse('https://example-shop.com/products/deri-ceket');
      final products = await adapter.parse(uri: uri, html: html);

      expect(products, isNotEmpty);
      final p = products.first;
      expect(p.name, 'Deri Ceket');
      expect(p.brand, 'Vakko');
      expect(p.price, 8500.00); // compare_at_price (base price)
      expect(p.discountPrice, 7500.00);
      expect(p.realVariants.length, 2);
      expect(p.realVariants[0].combinationTitle, 'Siyah / M');
      expect(p.realVariants[0].color, 'Siyah');
      expect(p.realVariants[0].size, 'M');
      expect(p.realVariants[0].sku, 'VAKKO-BLK-M');
      expect(p.realVariants[0].stock, 4);
    });

    test('Anker Shopify REST JSON (.js) verisini ve cent fiyatlarını kayıpsız dönüştürmeli', () async {
      const ankerJson = '''
      {
        "id": 7324867756194,
        "title": "Soundcore Life Q30 Bluetooth Kulaklık",
        "handle": "soundcore-life-q30-bluetooth-kulaklik",
        "description": "Gelişmiş Aktif Gürültü Önleme (ANC) teknolojisi ile donatılmış hibrit kulaklık.",
        "vendor": "Anker",
        "type": "Kulaklık",
        "price": 289900,
        "compare_at_price": 349900,
        "available": true,
        "images": [
          "//cdn.shopify.com/s/files/1/0579/6596/9570/products/A3028011_TD01.jpg",
          "//cdn.shopify.com/s/files/1/0579/6596/9570/products/A3028031_TD01.jpg"
        ],
        "options": [
          {
            "name": "Renk",
            "position": 1,
            "values": ["Siyah", "Mavi"]
          }
        ],
        "variants": [
          {
            "id": 41819383627938,
            "title": "Siyah",
            "option1": "Siyah",
            "sku": "A3028011",
            "barcode": "194644048884",
            "price": 289900,
            "compare_at_price": 349900,
            "available": true,
            "featured_image": {
              "src": "https://cdn.shopify.com/s/files/1/0579/6596/9570/products/A3028011_TD01.jpg"
            }
          },
          {
            "id": 41819383660706,
            "title": "Mavi",
            "option1": "Mavi",
            "sku": "A3028031",
            "barcode": "194644048891",
            "price": 289900,
            "compare_at_price": 349900,
            "available": true,
            "featured_image": {
              "src": "https://cdn.shopify.com/s/files/1/0579/6596/9570/products/A3028031_TD01.jpg"
            }
          }
        ]
      }
      ''';

      final uri = Uri.parse('https://anker-tr.com/products/soundcore-life-q30-bluetooth-kulaklik');
      expect(adapter.canHandle(uri), isTrue);

      final endpointUri = ShopifyProductAdapter.buildEndpointUri(uri);
      expect(endpointUri.toString(), 'https://anker-tr.com/products/soundcore-life-q30-bluetooth-kulaklik.js');

      final products = await adapter.parse(uri: uri, html: ankerJson);
      expect(products, isNotEmpty);

      final p = products.first;
      expect(p.name, 'Soundcore Life Q30 Bluetooth Kulaklık');
      expect(p.brand, 'Anker');
      expect(p.price, 3499.00); // 349900 cents -> 3499.00 TRY
      expect(p.discountPrice, 2899.00); // 289900 cents -> 2899.00 TRY
      expect(p.imageUrls, contains('https://cdn.shopify.com/s/files/1/0579/6596/9570/products/A3028011_TD01.jpg'));
      expect(p.realVariants.length, 2);

      // 1. Varyant (Siyah)
      final v1 = p.realVariants[0];
      expect(v1.combinationTitle, 'Siyah');
      expect(v1.color, 'Siyah');
      expect(v1.sku, 'A3028011');
      expect(v1.barcode, '194644048884');
      expect(v1.price, 3499.00);
      expect(v1.discountPrice, 2899.00);
      expect(v1.inStock, isTrue);
      expect(v1.stock, isNull); // Net sayısal stok yoksa null kalmalı (sahte stok yok)

      // 2. Varyant (Mavi)
      final v2 = p.realVariants[1];
      expect(v2.combinationTitle, 'Mavi');
      expect(v2.color, 'Mavi');
      expect(v2.sku, 'A3028031');
      expect(v2.barcode, '194644048891');
      expect(v2.price, 3499.00);
      expect(v2.discountPrice, 2899.00);
      expect(v2.inStock, isTrue);
    });
  });

  group('OpenGraphProductAdapter', () {
    const adapter = OpenGraphProductAdapter();

    test('OpenGraph ve twitter meta etiketlerini doğru yakalamalı', () async {
      const html = '''
      <html>
      <head>
        <meta property="og:title" content="Özel Tasarım Kolye" />
        <meta property="og:description" content="925 ayar gümüş el yapımı kolye." />
        <meta property="og:image" content="https://example.com/necklace.jpg" />
        <meta property="product:price:amount" content="850.00" />
        <meta property="product:price:currency" content="TRY" />
        <meta property="product:brand" content="Atölye Silver" />
        <meta property="product:retailer_item_id" content="SILVER-01" />
      </head>
      <body></body>
      </html>
      ''';

      final uri = Uri.parse('https://example.com/silver-necklace');
      final products = await adapter.parse(uri: uri, html: html);

      expect(products, isNotEmpty);
      final p = products.first;
      expect(p.name, 'Özel Tasarım Kolye');
      expect(p.brand, 'Atölye Silver');
      expect(p.price, 850.00);
      expect(p.sku, 'SILVER-01');
      expect(p.imageUrls, contains('https://example.com/necklace.jpg'));
    });
  });

  group('TrendyolProductAdapter', () {
    const adapter = TrendyolProductAdapter();

    test('canHandle trendyol.com domainini doğru tespit etmeli', () {
      expect(adapter.canHandle(Uri.parse('https://www.trendyol.com/brand/product-p-123')), isTrue);
      expect(adapter.canHandle(Uri.parse('https://hepsiburada.com/product')), isFalse);
    });

    test('Trendyol Cloudflare veya bot koruması ile karşılaştığında net yetkilendirme hatası vermeli', () async {
      const blockedHtml = '''
      <html>
        <head><title>Just a moment...</title></head>
        <body>
          <div id="challenge-platform">Please verify you are a human</div>
        </body>
      </html>
      ''';

      expect(
        () => adapter.parse(
          uri: Uri.parse('https://www.trendyol.com/brand/product-p-123'),
          html: blockedHtml,
        ),
        throwsA(predicate((e) => e.toString().contains('Erişim kısıtlaması nedeniyle bu mağaza için satıcı API anahtarı gereklidir'))),
      );
    });
  });
}
