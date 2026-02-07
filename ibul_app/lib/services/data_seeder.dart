import 'dart:convert';
import '../services/database_helper.dart';
import '../models/db_product.dart';
import '../models/db_banner.dart';

/// Ürün ve banner ekleme scripti
/// Bu dosyayı kullanarak kolay bir şekilde veritabanına veri ekleyebilirsiniz
class DataSeeder {
  final DatabaseHelper _db = DatabaseHelper.instance;
  
  /// Örnek ürünleri ekle
  Future<void> seedProducts() async {
    final products = [
      DBProduct(
        name: 'iPhone 15 Pro Max',
        brand: 'Apple',
        store: 'Teknosa',
        price: '64.999 TL',
        oldPrice: '74.999 TL',
        rating: 4.9,
        reviewCount: 1234,
        imageUrl: 'assets/images/products/iphone15.jpg',
        imageUrls: json.encode([
          'assets/images/products/iphone15.jpg',
          'assets/images/products/iphone15_2.jpg',
        ]),
        category: 'Elektronik',
        subCategory: 'Telefon',
        tags: json.encode(['Ücretsiz Kargo', '%13 indirim', 'Yeni']),
        description: 'Titanium kasa, A17 Pro çip, 256GB',
        specifications: json.encode({
          'İşlemci': 'A17 Pro',
          'RAM': '8GB',
          'Depolama': '256GB',
          'Ekran': '6.7 inç Super Retina XDR',
          'Kamera': '48MP + 12MP + 12MP',
          'Pil': '4422 mAh',
        }),
        stock: 45,
        variantGroupId: 'IPHONE15-TEKNOSA',
        variantOptions: 'Renk:Mavi|Depolama:256GB',
      ),
      DBProduct(
        name: 'iPhone 15 Pro Max Beyaz',
        brand: 'Apple',
        store: 'Teknosa',
        price: '64.999 TL',
        oldPrice: '74.999 TL',
        rating: 4.9,
        reviewCount: 1234,
        imageUrl: 'assets/products/iphone15promax beyaz.webp',
        imageUrls: json.encode([
          'assets/products/iphone15promax beyaz.webp',
          'assets/products/iphone15promax1Tb.jpeg',
        ]),
        category: 'Elektronik',
        subCategory: 'Telefon',
        tags: json.encode(['Ücretsiz Kargo', 'Yeni']),
        description: 'Titanium kasa, A17 Pro çip, 256GB',
        specifications: json.encode({
          'İşlemci': 'A17 Pro',
          'RAM': '8GB',
          'Depolama': '256GB',
          'Ekran': '6.7 inç Super Retina XDR',
          'Kamera': '48MP + 12MP + 12MP',
          'Pil': '4422 mAh',
        }),
        stock: 20,
        variantGroupId: 'IPHONE15-TEKNOSA',
        variantOptions: 'Renk:Beyaz|Depolama:256GB',
      ),
      DBProduct(
        name: 'MacBook Pro M3',
        brand: 'Apple',
        price: '52.999 TL',
        oldPrice: null,
        rating: 4.8,
        reviewCount: 892,
        imageUrl: 'assets/images/products/macbook.jpg',
        imageUrls: json.encode(['assets/images/products/macbook.jpg']),
        category: 'Bilgisayar',
        tags: json.encode(['Ücretsiz Kargo', 'Hızlı Kargo']),
        description: '14 inç, M3 çip, 16GB RAM, 512GB SSD',
        specifications: json.encode({
          'İşlemci': 'Apple M3 (8-core CPU)',
          'RAM': '16GB Unified Memory',
          'Depolama': '512GB SSD',
          'Ekran': '14.2 inç Liquid Retina XDR',
          'GPU': '10-core',
          'Pil': '70Wh - 17 saat',
        }),
        stock: 12,
      ),
      // Daha fazla ürün eklenebilir...
    ];
    
    await _db.insertProducts(products);
    print('✅ ${products.length} ürün eklendi!');
  }
  
  /// Örnek bannerları ekle
  Future<void> seedBanners() async {
    final banners = [
      DBBanner(
        imageUrl: 'assets/images/banners/winter_sale.jpg',
        link: null,
        orderIndex: 1,
        type: 'main',
        title: 'Kış İndirimleri',
        description: 'Tüm ürünlerde %50\'ye varan indirim',
      ),
      DBBanner(
        imageUrl: 'assets/images/banners/free_shipping.jpg',
        link: null,
        orderIndex: 2,
        type: 'main',
        title: 'Ücretsiz Kargo',
        description: '500 TL üzeri tüm siparişlerde',
      ),
      // Daha fazla banner eklenebilir...
    ];
    
    await _db.insertBanners(banners);
    print('✅ ${banners.length} banner eklendi!');
  }
  
  /// Tüm örnek verileri ekle
  Future<void> seedAll() async {
    print('🌱 Veritabanı seed işlemi başlatılıyor...');
    await seedProducts();
    await seedBanners();
    print('✨ Seed işlemi tamamlandı!');
  }
  
  /// Veritabanını temizle
  Future<void> clearAll() async {
    await _db.clearAllData();
    print('🗑️ Tüm veriler temizlendi!');
  }
  
  /// Veritabanını sıfırla ve yeniden seed et
  Future<void> resetAndSeed() async {
    await clearAll();
    await seedAll();
  }
}

/// Kullanım örneği:
/// 
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   
///   final seeder = DataSeeder();
///   await seeder.seedAll(); // Tüm verileri ekle
///   
///   runApp(MyApp());
/// }
