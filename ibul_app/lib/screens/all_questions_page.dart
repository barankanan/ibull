import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../services/product_question_service.dart';
import 'ask_product_question_page.dart';

class AllQuestionsPage extends StatefulWidget {
  final String productName;
  final String brand;
  final double rating;
  final int reviewCount;
  final List<String> images;
  final String? storeName;
  final String? sellerId;

  const AllQuestionsPage({
    super.key,
    required this.productName,
    required this.brand,
    required this.rating,
    required this.reviewCount,
    required this.images,
    this.storeName,
    this.sellerId,
  });

  @override
  State<AllQuestionsPage> createState() => _AllQuestionsPageState();
}

class _AllQuestionsPageState extends State<AllQuestionsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    final serviceQuestions = await ProductQuestionService.instance.getQuestions(
      productName: widget.productName,
      storeName: widget.storeName,
    );
    if (serviceQuestions.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _questions = serviceQuestions;
        _isLoading = false;
      });
      return;
    }

    final local = context.read<AppState>().getProductQuestionsFor(
      productName: widget.productName,
      storeName: widget.storeName,
    );
    if (!mounted) return;
    setState(() {
      _questions = local;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth >= 900;
    final filtered = _questions.where((question) {
      final term = _searchController.text.trim().toLowerCase();
      if (term.isEmpty) return true;
      return question['question']?.toString().toLowerCase().contains(term) ==
              true ||
          question['answer']?.toString().toLowerCase().contains(term) == true ||
          question['userName']?.toString().toLowerCase().contains(term) == true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: const Text(
          'Ürün Soru ve Cevapları',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWeb ? 1080 : 680),
          child: RefreshIndicator(
            onRefresh: _loadQuestions,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildProductHeader(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Sorularda ara',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _openAskQuestion,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Soru Sor'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  _buildEmptyState()
                else
                  ...filtered.map(_buildQuestionCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 74,
              height: 74,
              child: _buildImage(
                widget.images.isNotEmpty ? widget.images.first : '',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.brand,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.productName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_questions.length} soru • ${widget.reviewCount} değerlendirme',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(Icons.help_outline, size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'Henüz soru sorulmadı',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Bu ürünle ilgili ilk soruyu siz sorun. Satıcı yanıtladığında burada görünecek.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question) {
    final answer = question['answer']?.toString().trim() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  question['userName']?.toString() ?? 'Kullanıcı',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatDate(question['createdAt']?.toString()),
                style: const TextStyle(fontSize: 11, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            question['question']?.toString() ?? '',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: answer.isEmpty
                ? const Text(
                    'Satıcı yanıtı bekleniyor.',
                    style: TextStyle(fontSize: 13, color: Colors.black45),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Satıcı Yanıtı',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        answer,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAskQuestion() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AskProductQuestionPage(
          product: {
            'productName': widget.productName,
            'storeName': widget.storeName ?? '',
            'sellerId': widget.sellerId ?? '',
            'imageUrl': widget.images.isNotEmpty ? widget.images.first : '',
          },
        ),
      ),
    );
    if (result == true) {
      _loadQuestions();
    }
  }

  String _formatDate(String? raw) {
    final date = DateTime.tryParse(raw ?? '');
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildImage(String path) {
    if (path.isEmpty) return _placeholder();
    if (path.startsWith('http')) {
      return OptimizedImage(imageUrlOrPath: 
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFF3F4F6),
    child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
  );
}
