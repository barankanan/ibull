import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/auth/user_identity.dart';
import '../../core/constants.dart';
import '../../screens/all_questions_page.dart';
import '../../screens/ask_product_question_page.dart';
import '../../services/product_question_service.dart';
import '../../viewmodels/product_detail_viewmodel.dart';

class ProductQaCard extends StatefulWidget {
  const ProductQaCard({super.key});

  @override
  State<ProductQaCard> createState() => _ProductQaCardState();
}

class _ProductQaCardState extends State<ProductQaCard> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadQuestions();
  }

  Future<List<Map<String, dynamic>>> _loadQuestions() async {
    final viewModel = context.read<ProductDetailViewModel>();
    final appState = context.read<AppState>();
    final product = viewModel.initialProduct;
    final serviceQuestions = await ProductQuestionService.instance.getQuestions(
      productName: product.name,
      storeName: product.store,
    );
    if (serviceQuestions.isNotEmpty) return serviceQuestions;
    return appState.getProductQuestionsFor(
      productName: product.name,
      storeName: product.store,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProductDetailViewModel>();
    final product = viewModel.initialProduct;
    final appState = context.watch<AppState>();
    final canAskQuestion =
        appState.isLoggedIn && !UserIdentity.isGuest(appState.currentUser);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final questions = snapshot.data ?? const <Map<String, dynamic>>[];
        final latest = questions.take(2).toList();
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.question_answer_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
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
                questions.isEmpty
                    ? 'Henüz soru sorulmadı'
                    : '${questions.length} soru listeleniyor',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (latest.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.help_outline,
                        size: 30,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Henüz soru sorulmadı',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              else
                ...latest.map(
                  (question) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question['question']?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          (question['answer']?.toString().trim().isEmpty ??
                                  true)
                              ? 'Satıcı yanıtı bekleniyor'
                              : 'Yanıt: ${question['answer']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: canAskQuestion
                      ? () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AskProductQuestionPage(
                                product: {
                                  'productName': product.name,
                                  'storeName': product.store ?? '',
                                  'sellerId': '',
                                  'imageUrl': product.images.isNotEmpty
                                      ? product.images.first
                                      : '',
                                },
                              ),
                            ),
                          );
                          if (result == true && mounted) {
                            setState(() {
                              _future = _loadQuestions();
                            });
                          }
                        }
                      : null,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    canAskQuestion ? 'Soru Sor' : 'Giriş Yaparak Soru Sor',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: OutlinedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AllQuestionsPage(
                          productName: product.name,
                          brand: product.brand,
                          rating: product.rating,
                          reviewCount: product.reviewCount,
                          images: product.images,
                          storeName: product.store,
                        ),
                      ),
                    );
                    if (mounted) {
                      setState(() {
                        _future = _loadQuestions();
                      });
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'Tüm Soruları Göster',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
