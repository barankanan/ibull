import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import 'reviews_page.dart';

class ProductFeaturesPage extends StatefulWidget {
  final Product product;

  const ProductFeaturesPage({super.key, required this.product});

  @override
  State<ProductFeaturesPage> createState() => _ProductFeaturesPageState();
}

class _ProductFeaturesPageState extends State<ProductFeaturesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppState _appState = AppState();
  bool _isAddedToCart = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _isAddedToCart = _appState.cart.contains(widget.product);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
          'Tüm Özellikler',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _appState.isFavorite(widget.product) ? Icons.favorite : Icons.favorite_border,
              color: _appState.isFavorite(widget.product) ? AppColors.primary : Colors.black,
            ),
            onPressed: () {
              setState(() {
                _appState.toggleFavorite(widget.product);
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Ürün Özellikleri'),
            Tab(text: 'Ürün Açıklaması'),
            Tab(text: 'İade Koşulları'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Product Summary Card
          _buildProductSummary(),
          
          const Divider(height: 1),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFeaturesTab(),
                _buildDescriptionTab(),
                _buildReturnPolicyTab(),
              ],
            ),
          ),
          
          // Bottom Bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildProductSummary() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: widget.product.images.isNotEmpty
                ? Image.network(
                    widget.product.images.first,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.image, color: Colors.grey),
                  )
                : const Icon(Icons.image, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.brand,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.product.rating}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.product.reviewCount * 100} puan & ${widget.product.reviewCount} yorum >',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
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
  }

  Widget _buildFeaturesTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        const Text(
          'Genel Bilgiler',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        _buildBulletPoint('Bu ürün ${widget.product.brand} tarafından gönderilecektir.'),
        _buildBulletPoint('Kampanya fiyatından satılmak üzere 100 adetten fazla stok sunulmuştur.'),
        _buildBulletPoint('İncelemiş olduğunuz ürünün satış fiyatını satıcı belirlemektedir.'),
        _buildBulletPoint('Ürüne ait garanti belgesi ile tanıtma ve kullanım kılavuzları; kağıt ortamında paylaşılabileceği gibi elektronik ortamda erişim sağlayabileceğiniz, link ve karekod biçiminde de sunulabilecektir. Ürün teslimi sonrası ambalajın, paketin, kutunun dikkatle açılması tavsiye edilir.'),
        _buildBulletPoint(widget.product.name),
        _buildBulletPoint('6.1 inç Super Retina XDR ekranıyla yüksek kontrast oranı, parlaklık seviyesi ve genel görüntü kalitesi sunar.'),
        _buildBulletPoint('48 MP\'lik ve 12 MP ultra geniş kamerasıyla akıllı telefonlar içinde dikkat çeker.'),
        _buildBulletPoint('Yan tarafa monte edilmiş parmak izi okuyucu tasarımlı iPhone telefonları kolaylığı sunar.'),
        _buildBulletPoint('Büyük dosyaları ve uygulamaları saklama kapasitesiyle 128 GB telefonlar arasındadır.'),
        _buildBulletPoint('Zarif ve şık bir görünüm arayanlara siyah telefonlar ideal bir seçenektir.'),
        _buildBulletPoint('6.1 inç Apple iPhone 15, ergonomik kullanım sağlar.'),
      ],
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Icon(Icons.circle, size: 6, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        widget.product.getDisplayDescription(),
        style: TextStyle(color: Colors.grey[800], height: 1.5),
      ),
    );
  }

  Widget _buildReturnPolicyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        'İade Koşulları burada yer alacaktır.',
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Değerlendirmeler Button
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReviewsPage()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Değerlendirmeler',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Sepete Ekle Button
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    if (_isAddedToCart) {
                       _appState.removeFromCart(widget.product);
                       _isAddedToCart = false;
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Ürün sepetten çıkarıldı')),
                       );
                    } else {
                       _appState.addToCart(widget.product);
                       _isAddedToCart = true;
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Ürün sepete eklendi')),
                       );
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, // Always purple
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _isAddedToCart ? 'Sepete Eklendi' : 'Sepete Ekle',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
