import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/db_product.dart';
import 'database_helper.dart';

/// CSV dosyasından ürünleri veritabanına aktaran servis
class CSVImporter {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// CSV dosyasını okur ve ürünleri veritabanına ekler
  Future<int> importProductsFromCSV() async {
    try {
      // CSV dosyasını oku
      final csvString = await rootBundle.loadString('assets/urun_sablonu.csv');
      
      // Satırlara ayır
      final lines = const LineSplitter().convert(csvString);
      
      if (lines.isEmpty) {
        return 0;
      }

      // İlk satır başlıklar, atla
      final products = <DBProduct>[];
      
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        try {
          final product = _parseCSVLine(line);
          if (product != null) {
            products.add(product);
          }
        } catch (e) {
          print('Satır parse hatası ($i): $e');
        }
      }

      // Toplu ekleme
      if (products.isNotEmpty) {
        await _dbHelper.insertProducts(products);
      }

      return products.length;
    } catch (e) {
      print('CSV import hatası: $e');
      return 0;
    }
  }

  /// CSV satırını DBProduct nesnesine dönüştürür
  DBProduct? _parseCSVLine(String line) {
    final fields = _parseCSVFields(line);
    
    if (fields.length < 19) {
      return null;
    }

    try {
      // Görsel isimlerini düzenle
      String? imageUrl = fields[18].trim().isNotEmpty ? _normalizeImagePath(fields[18].trim()) : null;
      
      // Birden fazla görseli birleştir (varsa)
      List<String> imageUrls = [];
      if (fields.length > 19 && fields[19].trim().isNotEmpty) {
        final normalized = _normalizeImagePath(fields[19].trim());
        if (normalized != null && normalized.isNotEmpty) {
          imageUrls.add(normalized);
        }
      }
      if (fields.length > 20 && fields[20].trim().isNotEmpty) {
        final normalized = _normalizeImagePath(fields[20].trim());
        if (normalized != null && normalized.isNotEmpty) {
          imageUrls.add(normalized);
        }
      }

      return DBProduct(
        name: fields[0],
        brand: fields[1],
        store: fields[2].isEmpty ? null : fields[2],
        price: fields[3],
        oldPrice: fields[4].isEmpty ? null : fields[4],
        rating: double.tryParse(fields[8]) ?? 0.0,
        reviewCount: int.tryParse(fields[9]) ?? 0,
        imageUrl: imageUrl ?? '',
        imageUrls: imageUrls.isEmpty ? null : imageUrls.join(','),
        category: fields[5],
        subCategory: fields[6].isEmpty ? null : fields[6],
        tags: fields[12],
        keywords: fields[13].isEmpty ? null : fields[13],
        description: fields[10].isEmpty ? null : fields[10],
        specifications: fields[11].isEmpty ? null : fields[11],
        isPart: fields[14] == '1',
        damagedParts: fields[15].isEmpty ? null : fields[15],
        variantGroupId: fields[16].isEmpty ? null : fields[16],
        variantOptions: fields[17].isEmpty ? null : fields[17],
        stock: int.tryParse(fields[7]) ?? 0,
        isActive: true,
      );
    } catch (e) {
      print('Ürün parse hatası: $e');
      return null;
    }
  }

  /// Görsel yolunu normalize eder
  String? _normalizeImagePath(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return null;
    }

    String normalized = imagePath.trim();
    
    // Dosya ismindeki özel karakterleri düzenle (AVIF dönüşümünden ÖNCE)
    final imageMap = {
      'İphone15.Titanyum Mavi|Depolama-256GB.webp': 'iphone15_mavi_yan.webp',
      'iphone 15 mavi 512gb.avif': 'iphone15_mavi_256gb.png',
      'iphone-15-pro-max-mavi.avif': 'iphone15_mavi_512gb.png',
      'iphone15_mavi_yan.webp': 'iphone15_mavi_yan.webp',
      'iphone15_mavi_512gb.png': 'iphone15_mavi_512gb.png',
      '15-pro-mavi.jpg': 'iphone15_mavi_512gb.png',
      'iphone15promax beyaz.webp': 'iphone15_mavi_yan.webp',
      'iphone15promax1Tb.jpeg': 'iphone15_mavi_yan.webp',
      's24.avif': 's24_siyah_512gb.png',
      's242.jpg': 's24_siyah_256gb.jpg',
      's24_siyah_256gb.jpg': 's24_siyah_256gb.jpg',
      's24_siyah_512gb.jpg': 's24_siyah_512gb.png',
      's24mor.jpeg': 's24_mor.jpeg',
      's24mor2.webp': 's24_mor_2.webp',
      'macbookPro.jpeg': 'macbook_pro_m3.jpeg',
      'macbook_pro_m3.jpeg': 'macbook_pro_m3.jpeg',
      'macbook_1.jpg': 'macbook_pro_m3.jpeg',
      'Dyson V15 Detect.jpeg': 'dyson_v15.jpeg',
      'dyson_v15.jpeg': 'dyson_v15.jpeg',
      'dyson_1.jpg': 'dyson_v15.jpeg',
      'Nike Air Max 90.jpeg': 'nike_airmax90.jpeg',
      'nike_airmax90.jpeg': 'nike_airmax90.jpeg',
      'nike_airmax_1.jpg': 'nike_airmax90.jpeg',
      'Adidas Ultraboost 23.jpeg': 'adidas_ultraboost.jpeg',
      'adidas_ultraboost.jpeg': 'adidas_ultraboost.jpeg',
      'adidas_ultra_1.jpg': 'adidas_ultraboost.jpeg',
      'Sony WH-1000XM5.jpg': 'sony_xm5.jpg',
      'sony_xm5.jpg': 'sony_xm5.jpg',
      'sony_xm5_1.jpg': 'sony_xm5.jpg',
      'LG OLED C3 55 inç.jpeg': 'lg_oled.jpeg',
      'lg_oled.jpeg': 'lg_oled.jpeg',
      'lg_oled_1.jpg': 'lg_oled.jpeg',
      'iPhone 13 Hasarlı.webp': 'iphone13_hasarli.webp',
      'iphone13_hasarli.webp': 'iphone13_hasarli.webp',
      'iphone13_damaged.jpg': 'iphone13_hasarli.webp',
      'Canon EOS R6 Mark II.jpeg': 'canon_r6.jpeg',
      'canon_r6.jpeg': 'canon_r6.jpeg',
      'canon_r6_1.jpg': 'canon_r6.jpeg',
      'Zara Kadın Blazer Ceket.jpg': 'zara_blazer.jpg',
      'zara_blazer.jpg': 'zara_blazer.jpg',
      'zara_blazer_1.jpg': 'zara_blazer.jpg',
      '15proyan.png': 'iphone15_mavi_yan.webp',
      'iphone 15 siyah 512.webp': 'iphone15_mavi_256gb.png',
    };
    
    // Önce tam eşleşme ara
    if (imageMap.containsKey(normalized)) {
      normalized = imageMap[normalized]!;
      print('🖼️  Image mapping: "$imagePath" → "$normalized"');
    } else {
      print('⚠️  No mapping found for: "$imagePath" (normalized: "$normalized")');
    }
    
    // assets/products/ öneki ekle
    if (!normalized.startsWith('assets/')) {
      normalized = 'assets/products/$normalized';
    }
    
    print('✅ Final image path: "$normalized"');
    return normalized;
  }

  /// CSV alanlarını parse eder (tırnak içi virgülleri dikkate alır)
  List<String> _parseCSVFields(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        fields.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    // Son alanı ekle
    fields.add(buffer.toString().trim());

    return fields;
  }

  /// Veritabanını temizler
  Future<void> clearDatabase() async {
    await _dbHelper.clearAllData();
    print('Veritabanı temizlendi');
  }
}
