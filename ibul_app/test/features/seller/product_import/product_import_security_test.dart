import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/product_import/security/product_import_security.dart';

void main() {
  group('ProductImportSecurity - SSRF Validation', () {
    test('Geçerli genel HTTPS ve HTTP URL\'lerini kabul etmeli', () {
      final res1 = ProductImportSecurity.validateUrl('https://www.trendyol.com/brand/product-p-12345');
      expect(res1.isValid, isTrue);
      expect(res1.error, isNull);
      expect(res1.uri?.host, 'www.trendyol.com');

      final res2 = ProductImportSecurity.validateUrl('http://my-shop.com/products/item-1');
      expect(res2.isValid, isTrue);
    });

    test('HTTP/HTTPS dışındaki protokolleri reddetmeli', () {
      final resFtp = ProductImportSecurity.validateUrl('ftp://example.com/file');
      expect(resFtp.isValid, isFalse);
      expect(resFtp.error, contains('HTTP'));

      final resFile = ProductImportSecurity.validateUrl('file:///etc/passwd');
      expect(resFile.isValid, isFalse);

      final resJs = ProductImportSecurity.validateUrl('javascript:alert(1)');
      expect(resJs.isValid, isFalse);
    });

    test('Kimlik bilgisi içeren URL\'leri (credentials) reddetmeli', () {
      final res = ProductImportSecurity.validateUrl('https://admin:secret@example.com/product');
      expect(res.isValid, isFalse);
      expect(res.error, contains('kimlik bilgisi'));
    });

    test('Localhost ve yerel ağ isimlerini (SSRF) engellemeli', () {
      expect(ProductImportSecurity.validateUrl('http://localhost:3000/product').isValid, isFalse);
      expect(ProductImportSecurity.validateUrl('http://127.0.0.1:8080/').isValid, isFalse);
      expect(ProductImportSecurity.validateUrl('http://database.local/').isValid, isFalse);
      expect(ProductImportSecurity.validateUrl('http://api.internal/').isValid, isFalse);
    });

    test('Özel IP bloklarını ve Bulut Metadata adreslerini (169.254.169.254) engellemeli', () {
      // AWS / GCP / Azure metadata endpoint
      final resMeta = ProductImportSecurity.validateUrl('http://169.254.169.254/latest/meta-data/');
      expect(resMeta.isValid, isFalse);
      expect(resMeta.error, contains('SSRF'));

      // RFC 1918 Private Ranges
      expect(ProductImportSecurity.validateUrl('http://10.0.0.1/product').isValid, isFalse);
      expect(ProductImportSecurity.validateUrl('http://192.168.1.1/product').isValid, isFalse);
      expect(ProductImportSecurity.validateUrl('http://172.16.0.1/product').isValid, isFalse);
      expect(ProductImportSecurity.validateUrl('http://172.25.1.1/product').isValid, isFalse);
      expect(ProductImportSecurity.validateUrl('http://172.31.255.255/product').isValid, isFalse);

      // Loopback
      expect(ProductImportSecurity.validateUrl('http://127.0.0.1/').isValid, isFalse);
      expect(ProductImportSecurity.validateUrl('http://127.1.2.3/').isValid, isFalse);
    });
  });

  group('ProductImportSecurity - Sanitization & Price Parsing', () {
    test('Zararlı HTML kodlarını ve scriptleri temizlemeli', () {
      const dirty = '<script>alert("hack")</script><h1>Harika Telefon</h1><p>Açıklama &quot;test&quot; &amp; detay</p>';
      final clean = ProductImportSecurity.sanitizeText(dirty);
      expect(clean, contains('Harika Telefon'));
      expect(clean, contains('Açıklama "test" & detay'));
      expect(clean, isNot(contains('<script>')));
      expect(clean, isNot(contains('alert')));
    });

    test('Türkçe ve uluslararası fiyat biçimlerini doğru ayrıştırmalı', () {
      expect(ProductImportSecurity.parsePrice('1.499,90 TL'), 1499.90);
      expect(ProductImportSecurity.parsePrice('₺ 250,50'), 250.50);
      expect(ProductImportSecurity.parsePrice('1,499.90'), 1499.90);
      expect(ProductImportSecurity.parsePrice('1250'), 1250.0);
      expect(ProductImportSecurity.parsePrice(499.99), 499.99);
      expect(ProductImportSecurity.parsePrice('geçersiz'), isNull);
    });

    test('Para birimlerini normalize etmeli', () {
      expect(ProductImportSecurity.parseCurrency('TL'), 'TRY');
      expect(ProductImportSecurity.parseCurrency('₺'), 'TRY');
      expect(ProductImportSecurity.parseCurrency('USD'), 'USD');
      expect(ProductImportSecurity.parseCurrency('\$'), 'USD');
      expect(ProductImportSecurity.parseCurrency('EUR'), 'EUR');
      expect(ProductImportSecurity.parseCurrency('€'), 'EUR');
    });
  });
}
