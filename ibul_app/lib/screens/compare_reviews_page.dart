import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import '../core/constants.dart';
import '../models/product_model.dart';

class CompareReviewsPage extends StatelessWidget {
  final List<Map<String, dynamic>> products;

  const CompareReviewsPage({super.key, required this.products});

  final List<Map<String, dynamic>> _reviews = const [
    {
      'productIndex': 0,
      'userName': 'Baran K**',
      'userAvatar': null,
      'comment': 'Kurulumu basit ıstması gayet yerinde bir ürün sorunsuz alıp kullanabilirsiniz',
    },
    {
      'productIndex': 1,
      'userName': 'Gülşen K**',
      'userAvatar': null,
      'comment': 'Ürünü alıp kullanık ama pek memnun kalmadık telide kırık geldi kargolam ada ciddi hatalar var',
    },
    {
      'productIndex': 0,
      'userName': 'Süleyman K**',
      'userAvatar': null,
      'comment': 'Ürün güzel ama ısısı yeterli , vidaları tam geldi , otomatik ısı sensörü sorunsuz çalışıyor',
    },
    {
      'productIndex': 1,
      'userName': 'Selma K**',
      'userAvatar': null,
      'comment': 'Kargolama yapılırken özenilmemiş ürün korunmadan konulduğu için kırık gelmiş',
    },
    {
      'productIndex': 0,
      'userName': 'Yusuf M**',
      'userAvatar': null,
      'comment': 'Ürün gayet iyi aynısından ikinci alışım ürünü severek kullanıyoruz',
    },
    {
      'productIndex': 1,
      'userName': 'Efe K**',
      'userAvatar': null,
      'comment': 'Güzel beğendim',
    },
    {
      'productIndex': 0,
      'userName': 'Onur G**',
      'userAvatar': null,
      'comment': 'Ürün bugün geldi denedim kokusuz çalıştı ısısı ufak bir adaya yeter ama aman aman bir ısı beklemeyip , gayet iyi ısıttırıp çalışıyor ürün tavsıyem yarında gelen kurulum kitapçığı çok açık ve yalın anlatımış kurulumu sorunsuz eksiksiz bir şekilde kurduk',
    },
    {
      'productIndex': 1,
      'userName': 'Onur K**',
      'userAvatar': null,
      'comment': 'Kargo firmasını değişmeli ürün hasarlı geldi iade ettim',
    },
    {
      'productIndex': 1,
      'userName': 'Sergen K**',
      'userAvatar': null,
      'comment': 'ürün hızlı geldi ama ürün sandığım gibi gelmedi beklentimi karşılamadı benden kaynaklı bir sorun olmakla ürün hasarlı geldi',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;

    if (isWeb) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            width: 900,
            height: 650,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildWebHeader(context),
                Expanded(child: _buildContent(context)),
              ],
            ),
          ),
        ),
      );
    }

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
      body: _buildContent(context),
    );
  }

  Widget _buildWebHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.compare_arrows, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ürün Yorumları',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              Text(
                'Kullanıcı deneyimlerini karşılaştır',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.grey),
            splashRadius: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final displayProducts = products.take(2).toList();
    
    return SingleChildScrollView(
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
                  Expanded(
                    child: Text(
                      'Seçtiğin ${displayProducts.isNotEmpty ? (displayProducts[0]['product'] as Product?)?.category ?? 'ürün' : 'ürün'}lerin Yorum karşılaştırması',
                      style: const TextStyle(
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
                children: displayProducts.map((productMap) {
                  final imagePath = productMap['image'];
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Text(
                            productMap['name'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Center(
                              child: imagePath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: imagePath.startsWith('http')
                                          ? OptimizedImage(imageUrlOrPath: imagePath, fit: BoxFit.cover)
                                          : Image.asset(imagePath, fit: BoxFit.cover),
                                    )
                                  : const Icon(Icons.image, size: 35, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Reviews Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column (Product 1)
                  Expanded(
                    child: Column(
                      children: _reviews
                          .where((review) => review['productIndex'] == 0)
                          .map((review) => _buildReviewCard(review))
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Center Divider
                  Container(
                    width: 2,
                    height: 1200,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  // Right Column (Product 2)
                  Expanded(
                    child: Column(
                      children: _reviews
                          .where((review) => review['productIndex'] == 1)
                          .map((review) => _buildReviewCard(review))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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
                radius: 16,
                backgroundColor: Colors.grey.shade300,
                child: const Icon(Icons.person, size: 18, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review['userName'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review['comment'],
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
