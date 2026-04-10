import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/auth/user_identity.dart';
import '../../core/constants.dart';
import '../../models/product_model.dart';
import '../../screens/all_questions_page.dart';
import '../../screens/ask_product_question_page.dart';
import '../../services/product_question_service.dart';
import '../../viewmodels/product_detail_viewmodel.dart';

class ProductQaFullSection extends StatefulWidget {
  const ProductQaFullSection({super.key});

  @override
  State<ProductQaFullSection> createState() => _ProductQaFullSectionState();
}

class _ProductQaFullSectionState extends State<ProductQaFullSection> {
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
    final remote = await ProductQuestionService.instance.getQuestions(
      productName: product.name,
      storeName: product.store,
    );
    if (remote.isNotEmpty) return remote;
    return appState.getProductQuestionsFor(
      productName: product.name,
      storeName: product.store,
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = context.select<ProductDetailViewModel, Product>(
      (viewModel) => viewModel.initialProduct,
    );
    final canAsk = context.select<AppState, bool>(
      (appState) =>
          appState.isLoggedIn && !UserIdentity.isGuest(appState.currentUser),
    );

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final questions = snapshot.data ?? const <Map<String, dynamic>>[];
        final preview = questions.take(4).toList();
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
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
                    bottom: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
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
                      child: Icon(
                        Icons.question_answer_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Ürün Soru ve Cevapları',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      '${questions.length} soru',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Satıcıya ürün, stok, teslimat veya garanti ile ilgili soru sorabilirsiniz.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: canAsk
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
                          label: const Text('Soru Sor'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (preview.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.help_outline,
                              size: 46,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Henüz soru sorulmadı',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'İlk soruyu siz sorun, satıcı yanıtladığında cevap burada listelenir.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ...preview.map(
                        (question) => Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      question['userName']?.toString() ??
                                          'Kullanıcı',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatDate(
                                      question['createdAt']?.toString(),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                question['question']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  (question['answer']
                                              ?.toString()
                                              .trim()
                                              .isEmpty ??
                                          true)
                                      ? 'Satıcı yanıtı bekleniyor.'
                                      : question['answer'].toString(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        (question['answer']
                                                ?.toString()
                                                .trim()
                                                .isEmpty ??
                                            true)
                                        ? Colors.black45
                                        : Colors.black87,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Center(
                      child: SizedBox(
                        width: 320,
                        height: 44,
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
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.04,
                            ),
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
      },
    );
  }

  String _formatDate(String? raw) {
    final date = DateTime.tryParse(raw ?? '');
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
