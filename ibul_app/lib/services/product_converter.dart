import 'dart:convert';
import '../models/product_model.dart';
import '../models/db_product.dart';

/// DBProduct ve Product model'leri arasında dönüşüm yapan yardımcı sınıf
class ProductConverter {
  
  /// DBProduct'ı Product'a çevir (UI için)
  static Product toProduct(DBProduct dbProduct) {
    List<String> images = [];
    
    // imageUrls varsa parse et, yoksa sadece imageUrl kullan
    if (dbProduct.imageUrls != null && dbProduct.imageUrls!.isNotEmpty) {
      try {
        images = List<String>.from(json.decode(dbProduct.imageUrls!));
      } catch (e) {
        images = [dbProduct.imageUrl];
      }
    } else {
      images = [dbProduct.imageUrl];
    }
    
    // Tags'i parse et
    List<String> tags = [];
    try {
      tags = List<String>.from(json.decode(dbProduct.tags));
    } catch (e) {
      tags = [];
    }
    
    return Product(
      name: dbProduct.name,
      brand: dbProduct.brand,
      price: dbProduct.price,
      rating: dbProduct.rating,
      reviewCount: dbProduct.reviewCount,
      images: images,
      tags: tags,
    );
  }
  
  /// Product'ı DBProduct'a çevir (Database'e kaydetmek için)
  static DBProduct toDBProduct(
    Product product, {
    int? id,
    String? oldPrice,
    String category = 'Genel',
    String? description,
    Map<String, String>? specifications,
    int stock = 0,
  }) {
    return DBProduct(
      id: id,
      name: product.name,
      brand: product.brand,
      price: product.price,
      oldPrice: oldPrice,
      rating: product.rating,
      reviewCount: product.reviewCount,
      imageUrl: product.images.isNotEmpty ? product.images.first : '',
      imageUrls: json.encode(product.images),
      category: category,
      tags: json.encode(product.tags),
      description: description,
      specifications: specifications != null ? json.encode(specifications) : null,
      stock: stock,
      isActive: true,
    );
  }
  
  /// List<DBProduct>'ı List<Product>'a çevir
  static List<Product> toProductList(List<DBProduct> dbProducts) {
    return dbProducts.map((dbProduct) => toProduct(dbProduct)).toList();
  }
  
  /// List<Product>'ı List<DBProduct>'a çevir
  static List<DBProduct> toDBProductList(List<Product> products) {
    return products.map((product) => toDBProduct(product)).toList();
  }
}
