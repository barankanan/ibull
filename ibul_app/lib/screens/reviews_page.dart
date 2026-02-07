import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import 'photo_review_detail_page.dart';
import 'chat_page.dart';

class ReviewsPage extends StatefulWidget {
  final Product? product;

  const ReviewsPage({super.key, this.product});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  final String _selectedTab = 'Tümü';

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
      'rating': 3.0,
      'hasReview': true,
      'type': 'product',
      'imageCount': 1,
      'productImage': 'https://via.placeholder.com/60x60.png?text=Ürün',
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
          // Filter Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.filter_list, size: 18),
                    label: const Text('Filtrele', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.compare_arrows, size: 18),
                    label: const Text('Karşılaştır', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.sort, size: 18),
                    label: const Text('Sırala', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
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

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return GestureDetector(
      onTap: () {
        if (review['productImage'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PhotoReviewDetailPage(
                review: review,
                product: widget.product,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Username and Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review['userName'],
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                review['date'],
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Review Text
          if (review['reviewText'] != null) ...[
            Text(
              review['reviewText'],
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Rating and Actions
          Row(
            children: [
              // Rating Stars
              Text(
                review['rating'].toString(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 6),
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
              const SizedBox(width: 12),

              // Chat Icon
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatPage(
                        seller: {
                          'id': review['userName'],
                          'name': review['userName'],
                          'logo': review['userName'].toString().substring(0, 1),
                        },
                        product: {
                          'name': widget.product?.name ?? 'Ürün',
                          'image': review['productImage'],
                          'rating': review['rating'].toString(),
                        },
                        isSellerChat: false,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),

              const Spacer(),

              // Product Image Thumbnail
              if (review['productImage'] != null) ...[
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(
                      review['productImage'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.image,
                        color: Colors.grey.shade400,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                if (review['imageCount'] > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(+${review['imageCount']})',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    ),
    );
  }
}
