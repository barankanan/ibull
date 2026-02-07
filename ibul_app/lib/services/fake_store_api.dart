import 'dart:convert';
import 'package:http/http.dart' as http;

class FakeStoreAPI {
  static const String baseUrl = 'https://fakestoreapi.com';

  /// Tüm ürünleri getir
  static Future<List<Map<String, dynamic>>> fetchProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print('API Hatası: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Ürünler yüklenirken hata: $e');
      return [];
    }
  }

  /// Kategorileri getir
  static Future<List<String>> fetchCategories() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products/categories'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<String>();
      } else {
        print('API Hatası: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Kategoriler yüklenirken hata: $e');
      return [];
    }
  }

  /// Belirli kategorideki ürünleri getir
  static Future<List<Map<String, dynamic>>> fetchProductsByCategory(String category) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/category/$category'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print('API Hatası: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Kategori ürünleri yüklenirken hata: $e');
      return [];
    }
  }

  /// API verilerini DBProduct formatına dönüştür
  static Map<String, dynamic> convertToDBProduct(Map<String, dynamic> apiProduct) {
    return {
      'id': apiProduct['id'],
      'name': apiProduct['title'] ?? 'Ürün',
      'brand': 'FakeStore',
      'store': 'FakeStore Market',
      'price': (apiProduct['price'] ?? 0).toString(),
      'oldPrice': ((apiProduct['price'] ?? 0) * 1.2).toStringAsFixed(2),
      'category': _translateCategory(apiProduct['category'] ?? ''),
      'subCategory': '',
      'rating': (apiProduct['rating']?['rate'] ?? 0.0).toDouble(),
      'reviewCount': (apiProduct['rating']?['count'] ?? 0).toInt(),
      'imageUrl': apiProduct['image'] ?? '',
      'imageUrls': apiProduct['image'] ?? '',
      'tags': _getCategoryTags(apiProduct['category'] ?? ''),
      'keywords': _getCategoryTags(apiProduct['category'] ?? ''),
      'description': apiProduct['description'] ?? '',
      'specifications': _generateSpecifications(apiProduct),
      'isPart': 0,
      'damagedParts': '',
      'variantGroupId': '',
      'variantOptions': _generateVariantOptions(apiProduct),
      'stock': 100,
      'isActive': 1,
    };
  }

  static String _translateCategory(String category) {
    final translations = {
      'electronics': 'Elektronik',
      'jewelery': 'Takı & Aksesuar',
      'men\'s clothing': 'Erkek Giyim',
      'women\'s clothing': 'Kadın Giyim',
    };
    return translations[category] ?? category;
  }

  static String _getCategoryTags(String category) {
    final tags = {
      'electronics': 'teknoloji|elektronik|yeni',
      'jewelery': 'takı|aksesuar|moda',
      'men\'s clothing': 'erkek|giyim|moda',
      'women\'s clothing': 'kadın|giyim|moda',
    };
    return tags[category] ?? 'ürün';
  }

  static String _generateSpecifications(Map<String, dynamic> product) {
    final category = product['category'] ?? '';
    final specs = <String>[];
    
    if (category.contains('clothing')) {
      specs.add('Malzeme: %100 Pamuk');
      specs.add('Yıkama: 30 derece');
      specs.add('Bedenler: S, M, L, XL');
    } else if (category == 'electronics') {
      specs.add('Garanti: 2 Yıl');
      specs.add('Üretici: ${product['title']?.split(' ')[0] ?? 'Generic'}');
      specs.add('Orijinal Ürün');
    } else if (category == 'jewelery') {
      specs.add('Malzeme: Gümüş/Altın kaplama');
      specs.add('Garantili');
    }
    
    return specs.join('|');
  }

  static String _generateVariantOptions(Map<String, dynamic> product) {
    final category = product['category'] ?? '';
    
    if (category.contains('clothing')) {
      return 'Beden:S,M,L,XL|Renk:Siyah,Beyaz,Lacivert';
    } else if (category == 'electronics') {
      return 'Renk:Siyah,Gümüş|Depolama:64GB,128GB,256GB';
    } else if (category == 'jewelery') {
      return 'Renk:Altın,Gümüş,Rose';
    }
    
    return '';
  }
}
