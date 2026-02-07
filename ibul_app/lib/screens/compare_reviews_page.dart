import 'package:flutter/material.dart';
import '../core/constants.dart';

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
                      'Seçtiğin ısıtıcı ürünlerin Yorum karşılaştırması',
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
