import '../models/product_model.dart';

/// Abstract repository interface for Product data operations.
/// This allows switching between different data sources (SQLite, Firebase, REST API)
/// without changing the UI or business logic.
abstract class ProductRepository {
  Future<List<Product>> getAllProducts();
  
  Future<Product?> getProductById(String id);
  
  Future<List<Product>> getProductsByCategory(String category);
  
  Future<List<Product>> searchProducts(String query);
  
  // Example of future Auth integration
  // Future<void> toggleFavorite(String userId, String productId);
}

// Example implementation for SQLite (wrapping existing DatabaseHelper)
// class SqliteProductRepository implements ProductRepository { ... }

// Example implementation for Firebase (future)
// class FirebaseProductRepository implements ProductRepository { ... }
