import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../screens/all_questions_page.dart';
import '../../core/constants.dart';

class ProductQaFullSection extends StatefulWidget {
  const ProductQaFullSection({super.key});

  @override
  State<ProductQaFullSection> createState() => _ProductQaFullSectionState();
}

class _ProductQaFullSectionState extends State<ProductQaFullSection> {
  String _selectedCategory = 'tümü';

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;
    final name = product.name.toString().toLowerCase();
    final categories = _getCategories(name);
    final questions = _getQuestions(name);
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.primary.withValues(alpha: 0.02),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border(
                bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.12)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.question_answer_outlined, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Ürün Soru ve Cevapları',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

          // Category filter tags (horizontal scroll)
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = _selectedCategory == cat.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${cat.label} (${cat.count})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: isSelected ? Colors.white : Colors.grey[500],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Question cards (horizontal scroll)
          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: questions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final q = questions[index];
                      final cardWidth = screenWidth > 900
                          ? ((screenWidth - 160) / 3).clamp(280.0, 380.0)
                          : 300.0;
                      return SizedBox(
                        width: cardWidth,
                        child: _buildQuestionCard(q),
                      );
                    },
                  ),
                ),
                // Scroll indicator arrow
                if (questions.length > 3)
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.chevron_right, size: 20, color: Colors.black54),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // "TÜM SORULARI GÖSTER" button
          Center(
            child: SizedBox(
              width: 320,
              height: 44,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AllQuestionsPage(
                        productName: product.name,
                        brand: product.brand ?? '',
                        rating: product.rating,
                        reviewCount: product.reviewCount,
                        images: product.images,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'TÜM SORULARI GÖSTER',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========= QUESTION CARD =========
  Widget _buildQuestionCard(_QuestionData q) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question text
          Text(
            q.question,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // User + Date
          Text(
            '${q.userName} - ${q.date}',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          // Answer box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seller info row
                Row(
                  children: [
                    // Seller logo placeholder
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          q.sellerShort,
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${q.sellerName} satıcısının cevabı',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '1 dakika içinde cevaplandı.',
                            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Answer text
                Text(
                  q.answer,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========= DATA =========
  List<_QaCategory> _getCategories(String name) {
    if (name.contains('iphone')) {
      return [
        _QaCategory('tümü', 'tümü', 242),
        _QaCategory('garanti', 'Garanti Kapsamı', 28),
        _QaCategory('sifir', 'Sıfır Ürün/Kapalı Kutu Mu?', 28),
        _QaCategory('icerik', 'Ürün İçeriği', 27),
        _QaCategory('uyumluluk', 'Uyumluluk', 16),
        _QaCategory('fonksiyon', 'Fonksiyon/Özellik', 15),
        _QaCategory('sarj', 'Şarj Özellikleri', 13),
        _QaCategory('renk', 'Renk Seçenekleri', 10),
      ];
    } else if (name.contains('galaxy')) {
      return [
        _QaCategory('tümü', 'tümü', 186),
        _QaCategory('garanti', 'Garanti Kapsamı', 22),
        _QaCategory('ekran', 'Ekran Özellikleri', 20),
        _QaCategory('kamera', 'Kamera', 18),
        _QaCategory('sifir', 'Sıfır Ürün Mü?', 15),
        _QaCategory('hafiza', 'Hafıza/Depolama', 14),
        _QaCategory('pil', 'Pil/Şarj', 12),
      ];
    } else if (name.contains('macbook') || name.contains('laptop')) {
      return [
        _QaCategory('tümü', 'tümü', 98),
        _QaCategory('garanti', 'Garanti', 15),
        _QaCategory('performans', 'Performans', 14),
        _QaCategory('ekran', 'Ekran', 12),
        _QaCategory('pil', 'Pil Ömrü', 10),
        _QaCategory('baglanti', 'Bağlantı Portları', 8),
      ];
    } else {
      return [
        _QaCategory('tümü', 'tümü', 65),
        _QaCategory('garanti', 'Garanti', 12),
        _QaCategory('kalite', 'Kalite', 10),
        _QaCategory('kargo', 'Kargo/Teslimat', 8),
        _QaCategory('iade', 'İade/Değişim', 6),
      ];
    }
  }

  List<_QuestionData> _getQuestions(String name) {
    if (name.contains('iphone')) {
      return [
        _QuestionData(
          question: 'ürün yenilenmiş iPhone mi yoksa direk 0 mı',
          userName: '**** ****',
          date: '18 Ekim 2025',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, ürün sıfır kapalı kutu olarak gönderilmektedir. İlginiz için teşekkür ederiz.',
        ),
        _QuestionData(
          question: 'Yenilenmiş cihaz mı bu sıfır mı',
          userName: '**** ****',
          date: '9 Aralık 2025',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, ürün sıfır kapalı kutu olarak gönderilmektedir. İlginiz için teşekkür ederiz.',
        ),
        _QuestionData(
          question: 'Eski telefon alım hizmeti var mı takas yapılıyor mu',
          userName: '**** ****',
          date: '28 Ekim 2025',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, ilgili seçeneği ürün başlığını seçerek görüntüleyebilirsiniz.',
        ),
        _QuestionData(
          question: 'Türkiye garantili mi bu ürün',
          userName: '**** ****',
          date: '5 Kasım 2025',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, ürünümüz Apple Türkiye garantili olarak gönderilmektedir.',
        ),
        _QuestionData(
          question: 'Şarj aleti ve kulaklık kutu içerisinde geliyor mu',
          userName: '**** ****',
          date: '12 Aralık 2025',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, kutu içeriğinde USB-C to Lightning kablo ve kullanım kılavuzu bulunmaktadır.',
        ),
      ];
    } else if (name.contains('galaxy')) {
      return [
        _QuestionData(
          question: 'Samsung Türkiye garantili mi',
          userName: '**** ****',
          date: '15 Ekim 2025',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, ürünümüz Samsung Türkiye garantilidir.',
        ),
        _QuestionData(
          question: 'Kutu içeriğinde neler var',
          userName: '**** ****',
          date: '20 Kasım 2025',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, kutu içeriğinde telefon, USB-C kablo ve kullanım kılavuzu bulunmaktadır.',
        ),
        _QuestionData(
          question: 'Ekran koruyucu takılı mı geliyor',
          userName: '**** ****',
          date: '2 Aralık 2025',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, fabrika çıkışlı koruyucu film üzerinde bulunmaktadır. İyi günlerde kullanın.',
        ),
      ];
    } else {
      return [
        _QuestionData(
          question: 'Bu ürün orijinal mi',
          userName: '**** ****',
          date: '10 Ocak 2026',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, ürünümüz %100 orijinal ve garantilidir. İlginiz için teşekkür ederiz.',
        ),
        _QuestionData(
          question: 'Kargo ne kadar sürede gelir',
          userName: '**** ****',
          date: '15 Ocak 2026',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, siparişiniz 1-3 iş günü içerisinde teslim edilmektedir.',
        ),
        _QuestionData(
          question: 'İade koşulları nelerdir',
          userName: '**** ****',
          date: '20 Ocak 2026',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, ürünü teslim aldıktan sonra 15 gün içinde ücretsiz iade edebilirsiniz.',
        ),
      ];
    }
  }
}

class _QaCategory {
  final String id;
  final String label;
  final int count;
  _QaCategory(this.id, this.label, this.count);
}

class _QuestionData {
  final String question;
  final String userName;
  final String date;
  final String sellerName;
  final String sellerShort;
  final String answer;

  _QuestionData({
    required this.question,
    required this.userName,
    required this.date,
    required this.sellerName,
    required this.sellerShort,
    required this.answer,
  });
}
