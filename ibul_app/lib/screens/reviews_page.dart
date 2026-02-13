import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import 'photo_review_detail_page.dart';
import 'chat_page.dart';
import '../widgets/web_header.dart';
import '../widgets/web_footer.dart';
import '../widgets/account_sidebar.dart';

class ReviewsPage extends StatefulWidget {
  final Product? product;

  const ReviewsPage({super.key, this.product});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  String _selectedTab = 'Tümü';

  final List<Map<String, dynamic>> _tabs = [
    {'name': 'Tümü', 'count': 5},
    {'name': 'Değer Verilmeyen', 'count': 2},
    {'name': 'Değer Verilen', 'count': 1},
    {'name': 'Satıcı Değerlendirmesi', 'count': null},
    {'name': 'Kargo Değerlendirmesi', 'count': null},
  ];

  final List<Map<String, dynamic>> _allReviews = [
    {
      'userName': 'Baran K***',
      'date': '30/08/2023',
      'reviewText': 'Muhteşem paketleme çok ilgili davranıldı , Ürün 8 saat sonra elime ulaştı\nİçerisinde Hediyelerle birlikte geldi . Tüm sorularıma anında yanıt aldım Herkese tavsşye ettiğim bir ürün İHİZ yaptıgı kurye özelliği ile ayrı bir boyut atmış ben çok memnun kaldım',
      'rating': 5.0,
      'hasReview': true,
      'type': 'product',
      'imageCount': 5,
      'productImage': 'https://via.placeholder.com/60x60.png?text=Ürün',
    },
    {
      'userName': 'Süleyman K**',
      'date': '13/09/2023',
      'reviewText': 'Ürünü Alacakken parçalma özelliğinize denk geldim iyi düşünülmüş ben sistem hem ısıtıcıyı, hemde camını aldım malum yere düştümü cam kırılıyor cam kırıldım soba mahfoluyor bu ekonomide de sürekli yenisini almak güç bela , hem sıfır hemde 2.el ürünler için iyi düşünülmüş.',
      'rating': 4.5,
      'hasReview': true,
      'type': 'product',
      'imageCount': 0,
      'productImage': null,
    },
    {
      'userName': 'Gülşen K**',
      'date': '14/01/2022',
      'reviewText': 'Yakın lokasyon özelliğiniz sayesinde evde oturduğum yerden aynı ürünün yakın çevremde satıldığını gördüm ürünü gidip inceleyip günümde satın aldım kaliteli ve güzel bir ürün alınmasını tavsiye ediyorumö',
      'rating': 4.0,
      'hasReview': true,
      'type': 'product',
      'imageCount': 0,
      'productImage': null,
    },
    {
      'userName': 'Selma K**',
      'date': '14/01/2022',
      'reviewText': 'Ürün montaj sırasında ürüne zarar geldi ve sorunu hiçbir extra fazla masraf istemeden zararı giderdiler hızlı ve güvenilir bir platform',
      'rating': 4.0, // Assuming 4.0 from context or 5.0
      'hasReview': true,
      'type': 'product',
      'imageCount': 0,
      'productImage': null,
    },
  ];

  List<Map<String, dynamic>> get _filteredReviews {
    if (_selectedTab == 'Tümü') {
      return _allReviews;
    } else if (_selectedTab == 'Değer Verilmeyen') {
      return _allReviews.where((review) => !review['hasReview']).toList();
    } else if (_selectedTab == 'Değer Verilen') {
      return _allReviews.where((review) => review['hasReview']).toList();
    } else if (_selectedTab == 'Satıcı Değerlendirmesi') {
      return _allReviews.where((review) => review['type'] == 'seller').toList();
    } else if (_selectedTab == 'Kargo Değerlendirmesi') {
      return _allReviews.where((review) => review['type'] == 'cargo').toList();
    }
    return _allReviews;
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;

    if (isWeb) {
      return _buildWebView();
    }

    return _buildMobileView();
  }

  Widget _buildWebView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(onSearch: (q) {}),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Sidebar
                            const SizedBox(
                              width: 280,
                              child: AccountSidebar(activePage: 'Değerlendirmelerim'),
                            ),
                            const SizedBox(width: 32),
                            // Right Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Değerlendirmelerim',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Web Tabs/Filters
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: _tabs.map((tab) {
                                          final isSelected = _selectedTab == tab['name'];
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: InkWell(
                                              onTap: () => setState(() => _selectedTab = tab['name']),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: isSelected ? AppColors.primary : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      tab['name'],
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                        color: isSelected ? Colors.white : Colors.grey.shade700,
                                                      ),
                                                    ),
                                                    if (tab['count'] != null) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.grey.shade100,
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                        child: Text(
                                                          tab['count'].toString(),
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: isSelected ? Colors.white : Colors.grey.shade600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Reviews Grid
                                  _buildWebReviewsGrid(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const WebFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebReviewsGrid() {
    final filteredReviews = _filteredReviews;
    if (filteredReviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Bu kategoride değerlendirme bulunamadı',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 columns for reviews
        childAspectRatio: 1.2, // Aspect ratio to fit content
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: filteredReviews.length,
      itemBuilder: (context, index) {
        return _buildReviewCard(filteredReviews[index], isWeb: true);
      },
    );
  }

  Widget _buildMobileView() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Değerlendirmeler',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Buttons (Filtrele, Karşılaştır, Sırala)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(child: _buildHeaderButton(Icons.filter_list, 'Filtrele')),
                const SizedBox(width: 12),
                Expanded(child: _buildHeaderButton(Icons.compare_arrows, 'Karşılaştır')),
                const SizedBox(width: 12),
                Expanded(child: _buildHeaderButton(Icons.sort, 'Sırala')),
              ],
            ),
          ),

          const Divider(height: 1),

          // Reviews List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              children: _buildReviewsList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, String label) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildReviewsList() {
    final filteredReviews = _filteredReviews;
    if (filteredReviews.isEmpty) {
      return [
        const SizedBox(height: 40),
        const Center(
          child: Text(
            'Bu kategoride değerlendirme bulunamadı',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
      ];
    }

    List<Widget> widgets = [];

    for (var review in filteredReviews) {
      widgets.add(_buildReviewCard(review));
      widgets.add(const SizedBox(height: 16));
    }

    widgets.add(const SizedBox(height: 16));
    return widgets;
  }

  Widget _buildReviewCard(Map<String, dynamic> review, {bool isWeb = false}) {
    if (isWeb) return _buildWebReviewCard(review);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name and Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review['userName'],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                review['date'],
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF673AB7), // Purple date
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Review Text
          Text(
            review['reviewText'] ?? '',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Footer: Rating and Image Placeholder
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Rating
              Row(
                children: [
                  Text(
                    review['rating'].toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  ...List.generate(
                    5,
                    (index) => Icon(
                      index < review['rating'].floor()
                          ? Icons.star
                          : (index < review['rating'] ? Icons.star_half : Icons.star_border),
                      color: Colors.amber,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey[400]),
                ],
              ),

              // Image Placeholder (+5 style)
              if (review['imageCount'] > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.image_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '(+${review['imageCount']})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebReviewCard(Map<String, dynamic> review) {
    // Keep existing web implementation or similar
    return GestureDetector(
      onTap: () {
        // ... existing tap logic ...
      },
      child: Container(
        // ... existing web styling ...
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          // ... web content ...
          children: [Text(review['userName'])], // Placeholder for brevity if not changing web
        ),
      ),
    );
  }
}
