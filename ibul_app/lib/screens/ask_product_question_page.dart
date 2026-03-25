import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../services/product_question_service.dart';

class AskProductQuestionPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const AskProductQuestionPage({super.key, required this.product});

  @override
  State<AskProductQuestionPage> createState() => _AskProductQuestionPageState();
}

class _AskProductQuestionPageState extends State<AskProductQuestionPage> {
  final TextEditingController _questionController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.product['productName']?.toString() ?? 'Ürün';
    final storeName = widget.product['storeName']?.toString() ?? 'Satıcı';
    final imageUrl = widget.product['imageUrl']?.toString() ?? '';
    final isDesktop = _isDesktopLayout(context);
    final contentMaxWidth = _contentMaxWidth(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: const Text(
          'Satıcıya Soru Sor',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 24 : 16,
              16,
              isDesktop ? 24 : 16,
              24,
            ),
            child: isDesktop
                ? _buildDesktopContent(productName, storeName, imageUrl)
                : _buildMobileContent(productName, storeName, imageUrl),
          ),
        ),
      ),
    );
  }

  bool _isDesktopLayout(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  double _contentMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1400) return 1220;
    if (width >= 1100) return 1080;
    return double.infinity;
  }

  Widget _buildDesktopContent(
    String productName,
    String storeName,
    String imageUrl,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: _buildProductCard(productName, storeName, imageUrl),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _buildQuestionFormCard(),
              const SizedBox(height: 16),
              _buildSubmitButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileContent(
    String productName,
    String storeName,
    String imageUrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductCard(productName, storeName, imageUrl),
        const SizedBox(height: 16),
        _buildQuestionFormCard(),
        const SizedBox(height: 18),
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildProductCard(
    String productName,
    String storeName,
    String imageUrl,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              child: _buildImage(imageUrl),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sorunuz ürün sayfasında yayınlanır ve satıcı yanıtlayabilir.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sorunuz',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _questionController,
            maxLines: 6,
            maxLength: 400,
            decoration: InputDecoration(
              hintText:
                  'Örn. Bu ürünün garanti süresi nedir? Hangi renk stokta var? Aynı gün teslim mümkün mü?',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Kişisel bilgi, telefon veya dış bağlantı paylaşmayın. Sorular ürün ve teslimat kapsamı için yayınlanır.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Soruyu Gönder',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Future<void> _submit() async {
    final appState = context.read<AppState>();
    final userId = appState.currentUser?['uid']?.toString();
    final userName =
        (appState.currentUser?['displayName'] ??
                appState.currentUser?['name'] ??
                'Kullanıcı')
            .toString();
    final question = _questionController.text.trim();

    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Soru sormak için giriş yapmanız gerekiyor.'),
        ),
      );
      return;
    }
    if (question.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sorunuz en az 6 karakter olmalı.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ProductQuestionService.instance.createQuestion(
        productName: widget.product['productName']?.toString() ?? 'Ürün',
        storeName: widget.product['storeName']?.toString() ?? 'Satıcı',
        sellerId: widget.product['sellerId']?.toString() ?? '',
        productImageUrl: widget.product['imageUrl']?.toString() ?? '',
        question: question,
        userId: userId,
        userName: userName,
      );
    } catch (_) {
      await appState.addProductQuestion(
        productName: widget.product['productName']?.toString() ?? 'Ürün',
        storeName: widget.product['storeName']?.toString() ?? 'Satıcı',
        sellerId: widget.product['sellerId']?.toString() ?? '',
        productImageUrl: widget.product['imageUrl']?.toString() ?? '',
        question: question,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sorunuz gönderildi. Satıcı yanıtladığında ürün sayfasında görünecek.',
        ),
      ),
    );
    Navigator.pop(context, true);
  }

  Widget _buildImage(String path) {
    if (path.isEmpty) {
      return Container(
        color: const Color(0xFFF3F4F6),
        child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
      );
    }
    if (path.startsWith('http')) {
      return OptimizedImage(imageUrlOrPath: 
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFF3F4F6),
    child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
  );
}
