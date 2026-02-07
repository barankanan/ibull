import 'package:flutter/material.dart';

/// Test ekranı - İlk 12 ürünün görsellerini test eder
class ProductImageTestScreen extends StatelessWidget {
  const ProductImageTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // İlk 12 ürünün görselleri
    final List<Map<String, String>> products = [
      {
        'name': 'iPhone 15 Pro Max - Mavi 256GB',
        'image': 'assets/products/iphone15_mavi_256gb.png',
      },
      {
        'name': 'iPhone 15 Pro Max - Mavi 512GB',
        'image': 'assets/products/iphone15_mavi_512gb.png',
      },
      {
        'name': 'iPhone 15 Pro Max - Mavi Yan',
        'image': 'assets/products/iphone15_mavi_yan.webp',
      },
      {
        'name': 'MacBook Pro M3',
        'image': 'assets/products/macbook_pro_m3.jpeg',
      },
      {
        'name': 'Samsung S24 - Siyah 512GB',
        'image': 'assets/products/s24_siyah_512gb.png',
      },
      {
        'name': 'Samsung S24 - Siyah 256GB',
        'image': 'assets/products/s24_siyah_256gb.jpg',
      },
      {
        'name': 'Samsung S24 - Mor',
        'image': 'assets/products/s24_mor.jpeg',
      },
      {
        'name': 'Samsung S24 - Mor 2',
        'image': 'assets/products/s24_mor_2.webp',
      },
      {
        'name': 'Dyson V15 Detect',
        'image': 'assets/products/dyson_v15.jpeg',
      },
      {
        'name': 'Nike Air Max 90',
        'image': 'assets/products/nike_airmax90.jpeg',
      },
      {
        'name': 'Adidas Ultraboost 23',
        'image': 'assets/products/adidas_ultraboost.jpeg',
      },
      {
        'name': 'Sony WH-1000XM5',
        'image': 'assets/products/sony_xm5.jpg',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürün Görselleri Test'),
        backgroundColor: Colors.blue,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Görsel
                Container(
                  height: 250,
                  width: double.infinity,
                  color: Colors.grey[100],
                  child: Image.asset(
                    product['image']!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 64, color: Colors.red[300]),
                            const SizedBox(height: 8),
                            Text(
                              'Görsel yüklenemedi',
                              style: TextStyle(color: Colors.red[300]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product['image']!.split('/').last,
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Ürün adı
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product['image']!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
