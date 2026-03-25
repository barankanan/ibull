import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_state.dart';
import '../core/constants.dart';

class OrderReviewPage extends StatefulWidget {
  const OrderReviewPage({super.key, required this.item, this.initialTab = 1});

  final Map<String, dynamic> item;
  final int initialTab;

  @override
  State<OrderReviewPage> createState() => _OrderReviewPageState();
}

class _OrderReviewPageState extends State<OrderReviewPage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _productCommentController =
      TextEditingController();
  final TextEditingController _sellerCommentController =
      TextEditingController();

  late int _activeTab;
  int _productRating = 0;
  int _sellerRating = 0;
  bool _isSaving = false;
  final List<String> _productImages = [];
  final List<String> _sellerImages = [];

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab.clamp(0, 1);
  }

  @override
  void dispose() {
    _productCommentController.dispose();
    _sellerCommentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDesktop = _isDesktopLayout(context);
    final contentMaxWidth = _contentMaxWidth(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5FA),
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
        title: const Text(
          'Ürün ve Siparişi Değerlendir',
          style: TextStyle(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 24 : 16,
              12,
              isDesktop ? 24 : 16,
              24,
            ),
            child: _buildPageContent(item, isDesktop: isDesktop),
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

  Widget _buildPageContent(
    Map<String, dynamic> item, {
    required bool isDesktop,
  }) {
    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabs(isDesktop: false),
          const SizedBox(height: 14),
          _buildSummaryCard(item),
          const SizedBox(height: 14),
          if (_activeTab == 0)
            _buildSellerReviewForm()
          else
            _buildProductReviewForm(),
          const SizedBox(height: 14),
          _buildSubmitButton(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabs(isDesktop: true),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: _buildSummaryCard(item)),
            const SizedBox(width: 16),
            Expanded(
              flex: 6,
              child: _activeTab == 0
                  ? _buildSellerReviewForm()
                  : _buildProductReviewForm(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(flex: 4, child: SizedBox.shrink()),
            const SizedBox(width: 16),
            Expanded(flex: 6, child: _buildSubmitButton()),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _submitReview,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: Text(
          _isSaving ? 'Kaydediliyor...' : 'Değerlendir',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildTabs({required bool isDesktop}) {
    final tabs = Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E8F0)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabButton('Satıcıyı Değerlendir', 0)),
          Expanded(child: _buildTabButton('Ürünü Değerlendir', 1)),
        ],
      ),
    );

    if (!isDesktop) return tabs;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: tabs,
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isActive = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> item) {
    final imageUrl = item['product_image_url']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF7F5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 82,
              height: 82,
              child: _ReviewImage(url: imageUrl),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product_name']?.toString() ?? 'Ürün',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Satıcı: ${item['store_name'] ?? 'Bilinmeyen Mağaza'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metaPill(
                      'Ürün Kodu',
                      item['product_code']?.toString() ?? '-',
                    ),
                    _metaPill(
                      'Fiyat',
                      _money(item['total_price'] ?? item['unit_price']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaPill(String label, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black45),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductReviewForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Ürünü puanlayın'),
          const SizedBox(height: 10),
          _buildStars(_productRating, (value) {
            setState(() => _productRating = value);
          }),
          const SizedBox(height: 20),
          _sectionTitle('Ürün yorumu'),
          const SizedBox(height: 10),
          _buildCommentBox(
            controller: _productCommentController,
            hint:
                'Ürünle ilgili deneyiminizi yazın. Kargo, kalite, paketleme ve kullanım detayları burada görünsün.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('Ürün fotoğrafları'),
          const SizedBox(height: 10),
          _buildImagePickerRow(_productImages),
          const SizedBox(height: 8),
          const Text(
            'Maksimum 3 fotoğraf ekleyebilirsiniz. Fotoğraflar ürün değerlendirmelerinde gösterilir.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerReviewForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF6F1FF), Color(0xFFFFFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8E0FF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Satıcı deneyimi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.item['store_name'] ?? 'Satıcı'} için iletişim, hız, paketleme ve destek kalitesini puanlayın.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              _buildStars(_sellerRating, (value) {
                setState(() => _sellerRating = value);
              }),
              const SizedBox(height: 20),
              _buildCommentBox(
                controller: _sellerCommentController,
                hint:
                    'Satıcı iletişimi nasıldı? Sipariş sürecinde memnun kaldığınız veya eksik bulduğunuz noktaları yazın.',
              ),
              const SizedBox(height: 20),
              _sectionTitle('İsteğe bağlı görseller'),
              const SizedBox(height: 10),
              _buildImagePickerRow(_sellerImages),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildStars(int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            return InkWell(
              onTap: () => onChanged(starValue),
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  starValue <= value
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 38,
                  color: starValue <= value
                      ? AppColors.primary
                      : const Color(0xFFD3D4DE),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          value == 0 ? 'Puan seçin' : '$value/5 • ${_ratingLabel(value)}',
          style: TextStyle(
            color: value == 0 ? Colors.black45 : AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildCommentBox({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E7EF)),
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        maxLines: 6,
        maxLength: 500,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          counterText: '',
        ),
      ),
    );
  }

  Widget _buildImagePickerRow(List<String> images) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 20) / 3;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(3, (index) {
            final hasImage = index < images.length;
            return SizedBox(
              width: itemWidth,
              child: InkWell(
                onTap: hasImage ? null : () => _pickImageForActiveTab(),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 124,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE7E7EF)),
                  ),
                  child: hasImage
                      ? Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: _ReviewImage(url: images[index]),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    images.removeAt(index);
                                  });
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 16),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: AppColors.primary,
                              size: 28,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Fotoğraf\nEkle',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Future<void> _pickImageForActiveTab() async {
    final targetList = _activeTab == 0 ? _sellerImages : _productImages;
    if (targetList.length >= 3) return;
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    final mime = image.mimeType ?? 'image/jpeg';
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    setState(() {
      targetList.add(dataUrl);
    });
  }

  Future<void> _submitReview() async {
    final appState = AppState();
    final item = widget.item;
    final isSellerTab = _activeTab == 0;
    final rating = isSellerTab ? _sellerRating : _productRating;
    final comment = isSellerTab
        ? _sellerCommentController.text.trim()
        : _productCommentController.text.trim();

    if (rating <= 0) {
      _showSnack('Puan seçmeniz gerekiyor.');
      return;
    }
    if (comment.isEmpty) {
      _showSnack('Yorum metni boş bırakılamaz.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (isSellerTab) {
        await appState.addSellerReview(
          storeName: item['store_name']?.toString() ?? 'Satıcı',
          sellerId: item['seller_id']?.toString() ?? '',
          rating: rating.toDouble(),
          comment: comment,
          imageUrls: List<String>.from(_sellerImages),
        );
      } else {
        await appState.addProductReview(
          productName: item['product_name']?.toString() ?? 'Ürün',
          storeName: item['store_name']?.toString() ?? 'Satıcı',
          sellerId: item['seller_id']?.toString() ?? '',
          productImageUrl: item['product_image_url']?.toString() ?? '',
          productCode: item['product_code']?.toString() ?? '',
          rating: rating.toDouble(),
          comment: comment,
          imageUrls: List<String>.from(_productImages),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Değerlendirme kaydedilemedi: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Zayıf';
      case 2:
        return 'Geliştirilmeli';
      case 3:
        return 'Orta';
      case 4:
        return 'İyi';
      case 5:
        return 'Mükemmel';
      default:
        return '';
    }
  }

  String _money(dynamic value) {
    if (value == null) return '-';
    if (value is num) {
      return '${value.toStringAsFixed(2)} TL';
    }
    return value.toString();
  }
}

class _ReviewImage extends StatelessWidget {
  const _ReviewImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: const Color(0xFFF0F0F4),
        child: const Icon(Icons.image_outlined, color: Colors.grey),
      );
    }
    if (url.startsWith('data:image/')) {
      final bytes = base64Decode(url.split(',').last);
      return Image.memory(bytes, fit: BoxFit.cover);
    }
    if (url.startsWith('http')) {
      return OptimizedImage(imageUrlOrPath: 
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFFF0F0F4),
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      );
    }
    return Image.asset(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: const Color(0xFFF0F0F4),
        child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
      ),
    );
  }
}
