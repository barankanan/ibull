import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_import_models.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_csv_parser.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_import_validator.dart';

void main() {
  test('Debug CSV Headers', () {
    final template = buildBulkProductImportTemplateCsv(false);
    final headersString = template.split('\\n')[0];
    
    final row = [
      'Samsung Galaxy S24 Ultra 512GB', // product_name
      'Samsung', // brand
      'SM-S928B', // model_code
      'Elektronik', // main_category
      'Telefon', // sub_category
      'Yapay zeka özellikleri ile donatılmış harika bir telefon.', // description
      '75.000,50', // price 
      '15', // stock_quantity
      '5', // stock_alert_level
      'active', // status 
      'Siyah', // color
      '#000000', // color_hex
      'S24U-512-BLK', // sku
      '9876543210987', // barcode
      '74000', // sale_price
      '20', // tax_rate
      'TRY', // currency
      '24', // warranty_months
      'Güney Kore', // origin_country
      'new', // condition
      'true', // is_featured
      'https://example.com/s24.jpg', // main_image_url 
      'https://ibul.com/s24-2.jpg', // image_urls
      '', // video_url
      r'{"RAM":"12 GB","Ekran":"6.8 inç"}', // attributes_json
      r'[{"Hafıza":"512 GB","Renk":"Siyah","Fiyat":75000,"Stok":15}]', // variants_json
      '0.5', // kargo_agirlik_kg
      '12', // en_cm
      '20', // boy_cm
      '6', // yukseklik_cm
      'standart', // cargo_shipping_profile
      'true', // free_shipping
      r'["AI Kamera","Snapdragon 8 Gen 3"]', // highlights_json
      r'[{"Soru":"Kutu içeriği nedir?","Cevap":"Kablo ve iğne"}]', // faq_json
      '1-2 iş günü', // delivery_time
      '2', // estimated_delivery_days
    ];

    final String csvContent = '$headersString\\n${row.map((e) => '"${e.replaceAll('"', '""')}"').join(',')}';
    
    final parser = BulkProductCsvParser();
    final document = parser.parseBytes(utf8.encode(csvContent));
    
    final validator = BulkProductImportValidator();
    final preview = validator.validate(
      fileName: 'test.csv', 
      document: document,
      lockedMainCategory: 'Elektronik',
    );
    print('File Errors: ${preview.fileErrors}');
    if (preview.rows.isNotEmpty) {
      print('Row Errors: ${preview.rows.first.errors}');
    }
  });
}
