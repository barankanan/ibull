import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../widgets/web_header.dart';
import 'home_screen.dart';
import 'search_results_page.dart';

class AllQuestionsPage extends StatefulWidget {
  final String productName;
  final String brand;
  final double rating;
  final int reviewCount;
  final List<String> images;

  const AllQuestionsPage({
    super.key,
    required this.productName,
    required this.brand,
    required this.rating,
    required this.reviewCount,
    required this.images,
  });

  @override
  State<AllQuestionsPage> createState() => _AllQuestionsPageState();
}

class _AllQuestionsPageState extends State<AllQuestionsPage> {
  String _selectedCategory = 'tümü';
  String _sortBy = 'Önerilen Sıralama';

  late List<_QaCategory> _categories;
  late List<_QuestionData> _allQuestions;
  late Map<int, int> _starDistribution;
  late List<_FeatureRating> _featureRatings;

  @override
  void initState() {
    super.initState();
    _categories = _getCategories();
    _allQuestions = _getQuestions();
    _starDistribution = _getStarDistribution(widget.reviewCount);
    _featureRatings = _getFeatureRatings();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          WebHeader(
            onSearch: (query) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchResultsPage(query: query, results: const []),
                ),
              );
            },
            onCategorySelected: (category) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
          Expanded(
            child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
          ),
        ],
      ),
    );
  }

  // ========= WIDE LAYOUT =========
  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT: Rating summary (sticky)
          SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: _buildLeftPanel(),
            ),
          ),
          const SizedBox(width: 24),
          // RIGHT: Questions list (scrollable)
          Expanded(
            child: SingleChildScrollView(
              child: _buildRightPanel(),
            ),
          ),
        ],
      ),
    );
  }

  // ========= NARROW LAYOUT =========
  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildLeftPanel(),
          const SizedBox(height: 16),
          _buildRightPanel(),
        ],
      ),
    );
  }

  // ========= LEFT PANEL =========
  Widget _buildLeftPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Product image + Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 100,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: widget.images.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          widget.images.first,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.phone_iphone, size: 32, color: Colors.grey[400]),
                        ),
                      )
                    : Icon(Icons.phone_iphone, size: 32, color: Colors.grey[400]),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.rating.toStringAsFixed(1).replaceAll('.', ','),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      return Icon(
                        i < widget.rating.round() ? Icons.star : Icons.star_border,
                        size: 18,
                        color: AppColors.primary,
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Star bars
          _buildStarBars(),
          const SizedBox(height: 12),
          // Soru Sor button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.help_outline, size: 16),
              label: const Text(
                'Soru Sor',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Öne çıkan özellikler
          _buildFeatureRatingsBox(),
        ],
      ),
    );
  }

  // ========= RIGHT PANEL =========
  Widget _buildRightPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Ürün Soru ve Cevapları',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Search + Sort row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Icon(Icons.search, size: 20, color: Colors.grey[400]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Sorularda Ara',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Sort dropdown
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    icon: Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey[600]),
                    style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    elevation: 3,
                    items: const [
                      DropdownMenuItem(value: 'Önerilen Sıralama', child: Text('Önerilen Sıralama')),
                      DropdownMenuItem(value: 'En Yeni', child: Text('En Yeni')),
                      DropdownMenuItem(value: 'En Eski', child: Text('En Eski')),
                      DropdownMenuItem(value: 'En Beğenilen', child: Text('En Beğenilen')),
                    ],
                    onChanged: (v) => setState(() => _sortBy = v!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Category filter tags
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 20),

          // Question cards
          ..._allQuestions.map((q) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildQuestionCard(q),
          )),
        ],
      ),
    );
  }

  // ========= QUESTION CARD =========
  Widget _buildQuestionCard(_QuestionData q) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question text
          Text(
            q.question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          // User + Date
          Text(
            '${q.userName} - ${q.date}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          // Answer box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seller info
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          q.sellerShort,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${q.sellerName} satıcısının cevabı',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '1 dakika içinde cevaplandı.',
                            style: TextStyle(fontSize: 11, color: Colors.green[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Answer text
                Text(
                  q.answer,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                // Helpful row
                Row(
                  children: [
                    Text(
                      'Bu cevabı faydalı buldunuz mu?',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.thumb_up_outlined, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text('(${q.helpfulCount})', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(width: 8),
                    Icon(Icons.thumb_down_outlined, size: 14, color: Colors.grey[400]),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========= STAR BARS =========
  Widget _buildStarBars() {
    final maxCount = _starDistribution.values.fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
      children: List.generate(5, (i) {
        final starNum = 5 - i;
        final count = _starDistribution[starNum] ?? 0;
        final ratio = maxCount > 0 ? count / maxCount : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Icon(Icons.star, size: 14, color: AppColors.primary),
              const SizedBox(width: 2),
              SizedBox(
                width: 12,
                child: Text('$starNum', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(height: 8, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(height: 8, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4))),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 30, child: Text('$count', style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.end)),
            ],
          ),
        );
      }),
    );
  }

  // ========= FEATURE RATINGS BOX =========
  Widget _buildFeatureRatingsBox() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Öne çıkan özellikler', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _featureRatings.map((f) {
              return Expanded(
                child: Column(
                  children: [
                    Icon(f.icon, size: 28, color: Colors.grey[700]),
                    const SizedBox(height: 6),
                    Text(f.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: AppColors.primary),
                        const SizedBox(width: 2),
                        Text(f.rating.toStringAsFixed(1).replaceAll('.', ','), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('(${_formatCount(f.count)})', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ========= HELPERS =========
  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(0)}K';
    return '$count';
  }

  Map<int, int> _getStarDistribution(int totalReviews) {
    final base = totalReviews > 0 ? totalReviews : 1200;
    return {
      5: (base * 0.72).round(),
      4: (base * 0.12).round(),
      3: (base * 0.06).round(),
      2: (base * 0.03).round(),
      1: (base * 0.07).round(),
    };
  }

  List<_FeatureRating> _getFeatureRatings() {
    final name = widget.productName.toLowerCase();
    final brand = widget.brand.toLowerCase();
    if (name.contains('iphone') || (brand.contains('apple') && name.contains('phone'))) {
      return [
        _FeatureRating(Icons.battery_full, 'Batarya', 4.6, 24768),
        _FeatureRating(Icons.phone_iphone, 'Ekran', 4.8, 24465),
        _FeatureRating(Icons.camera_alt_outlined, 'Kamera', 4.8, 24383),
        _FeatureRating(Icons.memory, 'İşlemci', 4.8, 24329),
      ];
    } else if (name.contains('galaxy') || brand.contains('samsung')) {
      return [
        _FeatureRating(Icons.battery_full, 'Batarya', 4.7, 18200),
        _FeatureRating(Icons.phone_iphone, 'Ekran', 4.9, 17800),
        _FeatureRating(Icons.camera_alt_outlined, 'Kamera', 4.8, 17500),
        _FeatureRating(Icons.memory, 'İşlemci', 4.7, 17300),
      ];
    } else {
      return [
        _FeatureRating(Icons.star, 'Kalite', 4.5, 3200),
        _FeatureRating(Icons.local_shipping, 'Kargo', 4.6, 3100),
        _FeatureRating(Icons.inventory_2, 'Ambalaj', 4.7, 2900),
        _FeatureRating(Icons.thumb_up, 'Değer', 4.4, 2800),
      ];
    }
  }

  List<_QaCategory> _getCategories() {
    final name = widget.productName.toLowerCase();
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

  List<_QuestionData> _getQuestions() {
    final name = widget.productName.toLowerCase();
    if (name.contains('iphone')) {
      return [
        _QuestionData(
          question: 'ürün yenilenmiş iPhone mi yoksa direk 0 mı',
          userName: '**** ****',
          date: '18 Ekim 2025',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, ürün sıfır kapalı kutu olarak gönderilmektedir. İlginiz için teşekkür ederiz.',
          helpfulCount: 45,
        ),
        _QuestionData(
          question: 'Yenilenmiş cihaz mı bu sıfır mı',
          userName: '**** ****',
          date: '9 Aralık 2025',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, ürün sıfır kapalı kutu olarak gönderilmektedir. İlginiz için teşekkür ederiz.',
          helpfulCount: 32,
        ),
        _QuestionData(
          question: 'Eski telefon alım hizmeti var mı takas yapılıyor mu',
          userName: '**** ****',
          date: '28 Ekim 2025',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, ilgili seçeneği ürün başlığını seçerek görüntüleyebilirsiniz.',
          helpfulCount: 18,
        ),
        _QuestionData(
          question: 'Türkiye garantili mi bu ürün',
          userName: '**** ****',
          date: '5 Kasım 2025',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, ürünümüz Apple Türkiye garantili olarak gönderilmektedir.',
          helpfulCount: 67,
        ),
        _QuestionData(
          question: 'Şarj aleti ve kulaklık kutu içerisinde geliyor mu',
          userName: '**** ****',
          date: '12 Aralık 2025',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, kutu içeriğinde USB-C to Lightning kablo ve kullanım kılavuzu bulunmaktadır.',
          helpfulCount: 28,
        ),
        _QuestionData(
          question: 'Face ID özelliği çalışıyor mu',
          userName: '**** ****',
          date: '20 Ocak 2026',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, evet Face ID özelliği sorunsuz çalışmaktadır.',
          helpfulCount: 14,
        ),
        _QuestionData(
          question: 'eSIM desteği var mı bu modelde',
          userName: '**** ****',
          date: '3 Şubat 2026',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, iPhone 13 modeli eSIM desteğine sahiptir. Nano SIM + eSIM olarak kullanabilirsiniz.',
          helpfulCount: 22,
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
          helpfulCount: 38,
        ),
        _QuestionData(
          question: 'Kutu içeriğinde neler var',
          userName: '**** ****',
          date: '20 Kasım 2025',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, kutu içeriğinde telefon, USB-C kablo ve kullanım kılavuzu bulunmaktadır.',
          helpfulCount: 25,
        ),
        _QuestionData(
          question: 'Ekran koruyucu takılı mı geliyor',
          userName: '**** ****',
          date: '2 Aralık 2025',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, fabrika çıkışlı koruyucu film üzerinde bulunmaktadır.',
          helpfulCount: 15,
        ),
        _QuestionData(
          question: 'Çift SIM kart destekliyor mu',
          userName: '**** ****',
          date: '10 Ocak 2026',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, evet çift SIM kart desteği bulunmaktadır.',
          helpfulCount: 20,
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
          answer: 'Merhaba, ürünümüz %100 orijinal ve garantilidir.',
          helpfulCount: 12,
        ),
        _QuestionData(
          question: 'Kargo ne kadar sürede gelir',
          userName: '**** ****',
          date: '15 Ocak 2026',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, siparişiniz 1-3 iş günü içerisinde teslim edilmektedir.',
          helpfulCount: 8,
        ),
        _QuestionData(
          question: 'İade koşulları nelerdir',
          userName: '**** ****',
          date: '20 Ocak 2026',
          sellerName: 'iBul',
          sellerShort: 'iBul',
          answer: 'Merhaba, ürünü teslim aldıktan sonra 15 gün içinde ücretsiz iade edebilirsiniz.',
          helpfulCount: 6,
        ),
      ];
    }
  }
}

class _FeatureRating {
  final IconData icon;
  final String label;
  final double rating;
  final int count;
  _FeatureRating(this.icon, this.label, this.rating, this.count);
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
  final int helpfulCount;

  _QuestionData({
    required this.question,
    required this.userName,
    required this.date,
    required this.sellerName,
    required this.sellerShort,
    required this.answer,
    this.helpfulCount = 0,
  });
}
