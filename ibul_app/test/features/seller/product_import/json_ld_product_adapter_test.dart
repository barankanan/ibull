import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/product_import/adapters/json_ld_product_adapter.dart';

void main() {
  group('JsonLdProductAdapter', () {
    const adapter = JsonLdProductAdapter();

    test('Standart Schema.org Product JSON-LD verisini ayrıştırmalı', () async {
      const html = '''
      <!DOCTYPE html>
      <html>
      <head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org/",
          "@type": "Product",
          "name": "Apple iPhone 15 128 GB Siyah",
          "image": [
            "https://example.com/iphone1.jpg",
            "https://example.com/iphone2.jpg"
          ],
          "description": "Son teknoloji A16 Bionic çipli akıllı telefon.",
          "sku": "IPHONE15-128-BLK",
          "gtin13": "194253000000",
          "brand": {
            "@type": "Brand",
            "name": "Apple"
          },
          "offers": {
            "@type": "Offer",
            "url": "https://example.com/product",
            "priceCurrency": "TRY",
            "price": "49999.90",
            "availability": "https://schema.org/InStock"
          },
          "additionalProperty": [
            {
              "@type": "PropertyValue",
              "name": "Dahili Hafıza",
              "value": "128 GB"
            },
            {
              "@type": "PropertyValue",
              "name": "Ekran Boyutu",
              "value": "6.1 inç"
            }
          ]
        }
        </script>
      </head>
      <body></body>
      </html>
      ''';

      final uri = Uri.parse('https://example.com/product');
      final products = await adapter.parse(uri: uri, html: html);

      expect(products, isNotEmpty);
      final p = products.first;

      expect(p.name, 'Apple iPhone 15 128 GB Siyah');
      expect(p.brand, 'Apple');
      expect(p.sku, 'IPHONE15-128-BLK');
      expect(p.barcode, '194253000000');
      expect(p.price, 49999.90);
      expect(p.currency, 'TRY');
      expect(p.imageUrls.length, 2);
      expect(p.imageUrls.first, 'https://example.com/iphone1.jpg');
      expect(p.specifications['Dahili Hafıza'], '128 GB');
      expect(p.specifications['Ekran Boyutu'], '6.1 inç');
    });

    test('AggregateOffers içindeki varyasyon listesini korumalı', () async {
      const html = '''
      <html>
      <head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org/",
          "@type": "Product",
          "name": "Pamuklu T-Shirt",
          "sku": "TSHIRT-01",
          "offers": {
            "@type": "AggregateOffer",
            "lowPrice": "299.90",
            "priceCurrency": "TRY",
            "offers": [
              {
                "@type": "Offer",
                "name": "Siyah / S",
                "sku": "TSHIRT-01-BLK-S",
                "price": "299.90",
                "availability": "https://schema.org/InStock"
              },
              {
                "@type": "Offer",
                "name": "Siyah / M",
                "sku": "TSHIRT-01-BLK-M",
                "price": "299.90",
                "availability": "https://schema.org/InStock"
              },
              {
                "@type": "Offer",
                "name": "Beyaz / L",
                "sku": "TSHIRT-01-WHT-L",
                "price": "349.90",
                "availability": "https://schema.org/InStock"
              }
            ]
          }
        }
        </script>
      </head>
      <body></body>
      </html>
      ''';

      final uri = Uri.parse('https://example.com/tshirt');
      final products = await adapter.parse(uri: uri, html: html);

      expect(products, isNotEmpty);
      final p = products.first;
      expect(p.realVariants.length, 3);
      expect(p.realVariants[0].combinationTitle, 'Siyah / S');
      expect(p.realVariants[0].sku, 'TSHIRT-01-BLK-S');
      expect(p.realVariants[2].combinationTitle, 'Beyaz / L');
      expect(p.realVariants[2].price, 349.90);
    });
  });
}
