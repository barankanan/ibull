import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../screens/all_questions_page.dart';

class ProductQaCard extends StatelessWidget {
  const ProductQaCard({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;
    final brand = product.brand;
    final name = product.name;
    final questions = _generateQuestions(brand, name);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.question_answer_outlined, size: 18, color: Colors.black87),
              SizedBox(width: 6),
              Text(
                'Ürün Soru & Cevap',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${questions.length} soru soruldu',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 10),

          // Questions list
          ...questions.take(3).map((q) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.help_outline, size: 12, color: Colors.orange[700]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q['question']!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 11, color: Colors.green[600]),
                            const SizedBox(width: 3),
                            Text(
                              q['answeredBy']!,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 6),

          // "Soruları Gör" button
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllQuestionsPage(
                      productName: product.name,
                      brand: product.brand,
                      rating: product.rating,
                      reviewCount: product.reviewCount,
                      images: product.images,
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                'Soruları Gör',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _generateQuestions(String brand, String name) {
    final n = name.toLowerCase();

    if (n.contains('iphone') || (brand.contains('Apple') && n.contains('phone'))) {
      return [
        {
          'question': 'Bu telefon çift sim kart destekliyor mu?',
          'answeredBy': 'Satıcı tarafından yanıtlandı',
        },
        {
          'question': 'Kutuda şarj adaptörü geliyor mu?',
          'answeredBy': 'Satıcı tarafından yanıtlandı',
        },
        {
          'question': 'Türkiye garantili mi?',
          'answeredBy': 'Satıcı tarafından yanıtlandı',
        },
        {
          'question': 'Kılıf hediye var mı?',
          'answeredBy': 'Topluluk tarafından yanıtlandı',
        },
        {
          'question': 'eSIM desteği var mı?',
          'answeredBy': 'Satıcı tarafından yanıtlandı',
        },
      ];
    } else if (n.contains('galaxy') || brand.contains('Samsung')) {
      return [
        {
          'question': 'S Pen kutu içeriğinde geliyor mu?',
          'answeredBy': 'Satıcı tarafından yanıtlandı',
        },
        {
          'question': 'Hafıza kartı takılabiliyor mu?',
          'answeredBy': 'Satıcı tarafından yanıtlandı',
        },
        {
          'question': 'Samsung Türkiye garantili mi?',
          'answeredBy': 'Satıcı tarafından yanıtlandı',
        },
        {
          'question': 'Hızlı şarj destekliyor mu?',
          'answeredBy': 'Topluluk tarafından yanıtlandı',
        },
      ];
    } else if (n.contains('macbook') || n.contains('laptop')) {
      return [
        {
          'question': 'Windows kurulabilir mi?',
          'answeredBy': 'Topluluk tarafından yanıtlandı',
        },
        {
          'question': 'RAM yükseltilebilir mi?',
          'answeredBy': 'Satıcı tarafından yanıtlandı',
        },
        {
          'question': 'Harici monitör bağlanabilir mi?',
          'answeredBy': 'Satıcı tarafından yanıtlandı',
        },
      ];
    } else {
      return [
        {
          'question': 'Bu ürün orijinal mi?',
          'answeredBy': 'Satıcı tarafından yanıtlandı',
        },
        {
          'question': 'Faturası ile birlikte mi geliyor?',
          'answeredBy': 'Satıcı tarafından yanıtlandı',
        },
        {
          'question': 'İade süreci nasıl işliyor?',
          'answeredBy': 'Topluluk tarafından yanıtlandı',
        },
        {
          'question': 'Garanti süresi ne kadar?',
          'answeredBy': 'Satıcı tarafından yanıtlandı',
        },
      ];
    }
  }
}
