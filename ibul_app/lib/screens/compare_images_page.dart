import 'package:flutter/material.dart';
import '../core/constants.dart';

class CompareImagesPage extends StatelessWidget {
  final List<Map<String, dynamic>> products;

  const CompareImagesPage({super.key, required this.products});

  final List<Map<String, dynamic>> _images = const [
    {
      'productIndex': 0,
      'userName': 'Baran K**',
      'userAvatar': null,
      'image': null,
      'comment': 'Kurulumu basit ıstması gayet yerinde bir ürün sorunsuz alıp..',
    },
    {
      'productIndex': 1,
      'userName': 'G*******',
      'userAvatar': null,
      'image': null,
      'comment': 'Ürünü alıp kullanık ama pek memnun kalmadık telide kırık..',
    },
    {
      'productIndex': 0,
      'userName': 'Süleyman K**',
      'userAvatar': null,
      'image': null,
      'comment': 'Ürün güzel ama ısısı yeterli , vidaları tam geldi , otomatik ısı..',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ürün Yorumları',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Seçtiğin ısıtıcı ürünlerin Görsel karşılaştırması',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Product Headers
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: products.take(2).map((product) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          const Text(
                            'UFO S / 2400',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Center(
                              child: Icon(Icons.image, size: 35, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Images Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column (Product 1)
                  Expanded(
                    child: Column(
                      children: _images
                          .where((image) => image['productIndex'] == 0)
                          .map((image) => _buildImageCard(image))
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Center Divider
                  Container(
                    width: 2,
                    height: 800,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  // Right Column (Product 2)
                  Expanded(
                    child: Column(
                      children: _images
                          .where((image) => image['productIndex'] == 1)
                          .map((image) => _buildImageCard(image))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(Map<String, dynamic> imageData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey.shade300,
                child: const Icon(Icons.person, size: 16, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  imageData['userName'],
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Image
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: imageData['image'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      imageData['image'],
                      fit: BoxFit.cover,
                    ),
                  )
                : const Center(
                    child: Icon(Icons.image, size: 35, color: Colors.grey),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            imageData['comment'],
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
              height: 1.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
