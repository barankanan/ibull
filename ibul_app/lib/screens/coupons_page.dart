import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../services/coupon_service.dart';
import '../widgets/web_header.dart';
import '../widgets/web_footer.dart';
import '../widgets/account_sidebar.dart';

class CouponsPage extends StatefulWidget {
  const CouponsPage({super.key});

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock Data for Coupons
  final List<Map<String, dynamic>> _activeCoupons = [
    {
      'id': 'c1',
      'code': 'YAZ20',
      'title': 'Yaz Fırsatı',
      'description': '20 TL İndirim',
      'detail': '100 TL ve üzeri alışverişlerde geçerlidir.',
      'discountAmount': 20.0,
      'isPercentage': false,
      'minPrice': 100.0,
      'expiryDate': '30 Haziran 2026',
      'color': Colors.orange.shade50,
      'iconColor': Colors.orange,
    },
    {
      'id': 'c2',
      'code': 'TEKNO10',
      'title': 'Teknoloji İndirimi',
      'description': '%10 İndirim',
      'detail': 'Teknoloji kategorisindeki 500 TL ve üzeri ürünlerde.',
      'discountAmount': 10.0,
      'isPercentage': true,
      'minPrice': 500.0,
      'expiryDate': '15 Temmuz 2026',
      'color': Colors.blue.shade50,
      'iconColor': Colors.blue,
    },
    {
      'id': 'c3',
      'code': 'HOSGELDIN',
      'title': 'Hoş Geldin Hediyesi',
      'description': '50 TL İndirim',
      'detail': 'İlk siparişine özel 250 TL ve üzeri alışverişlerde.',
      'discountAmount': 50.0,
      'isPercentage': false,
      'minPrice': 250.0,
      'expiryDate': '31 Aralık 2026',
      'color': Colors.purple.shade50,
      'iconColor': Colors.purple,
    },
  ];

  final List<Map<String, dynamic>> _expiredCoupons = [
    {
      'id': 'c4',
      'code': 'BAHAR24',
      'title': 'Bahar İndirimi',
      'description': '30 TL İndirim',
      'detail': 'Süresi doldu.',
      'discountAmount': 30.0,
      'isPercentage': false,
      'minPrice': 150.0,
      'expiryDate': '1 Mayıs 2026',
      'color': Colors.grey.shade100,
      'iconColor': Colors.grey,
      'status': 'Süresi Doldu',
    },
    {
      'id': 'c5',
      'code': 'ILK100',
      'title': 'İlk Alışveriş',
      'description': '100 TL İndirim',
      'detail': 'Kullanıldı.',
      'discountAmount': 100.0,
      'isPercentage': false,
      'minPrice': 1000.0,
      'expiryDate': '10 Ocak 2026',
      'color': Colors.grey.shade100,
      'iconColor': Colors.grey,
      'status': 'Kullanıldı',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Listen to coupon service updates
    CouponService().addListener(_updateCoupons);
  }

  @override
  void dispose() {
    CouponService().removeListener(_updateCoupons);
    _tabController.dispose();
    super.dispose();
  }

  void _updateCoupons() {
    if (mounted) setState(() {});
  }
  
  // Combine static and won coupons
  List<Map<String, dynamic>> get _allActiveCoupons {
    // Convert won coupons to map format to match existing UI logic
    final wonMapped = CouponService().wonCoupons.map((c) => {
      'id': c.id,
      'code': c.code,
      'title': c.title,
      'description': c.description,
      'detail': 'Şans Çarkı ödülü.',
      'discountAmount': c.discountAmount,
      'isPercentage': c.isPercentage,
      'minPrice': c.minPrice,
      'expiryDate': c.expiryDate,
      'color': c.color,
      'iconColor': c.iconColor,
    }).toList();
    
    return [...wonMapped, ..._activeCoupons];
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
                              child: AccountSidebar(activePage: 'Kuponlarım'),
                            ),
                            const SizedBox(width: 32),
                            // Right Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Kuponlarım',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Web Tabs
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                          ),
                                          child: TabBar(
                                            controller: _tabController,
                                            labelColor: AppColors.primary,
                                            unselectedLabelColor: Colors.grey,
                                            indicatorColor: AppColors.primary,
                                            indicatorWeight: 3,
                                            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                                            tabs: const [
                                              Tab(text: 'Aktif Kuponlar'),
                                              Tab(text: 'Pasif Kuponlar'),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          height: 500, // Fixed height for tab view content or use minHeight
                                          child: TabBarView(
                                            controller: _tabController,
                                            children: [
                                              _buildWebCouponGrid(_allActiveCoupons, isActive: true),
                                              _buildWebCouponGrid(_expiredCoupons, isActive: false),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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

  Widget _buildWebCouponGrid(List<Map<String, dynamic>> coupons, {required bool isActive}) {
    if (coupons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              isActive ? 'Aktif kuponunuz bulunmuyor' : 'Geçmiş kuponunuz bulunmuyor',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5, // Wider aspect ratio for web cards
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: coupons.length,
      itemBuilder: (context, index) {
        final coupon = coupons[index];
        return _buildCouponCard(coupon, isActive: isActive, isWeb: true);
      },
    );
  }

  Widget _buildMobileView() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Kuponlarım',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Aktif Kuponlar'),
            Tab(text: 'Pasif Kuponlar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCouponList(_allActiveCoupons, isActive: true),
          _buildCouponList(_expiredCoupons, isActive: false),
        ],
      ),
    );
  }

  Widget _buildCouponList(List<Map<String, dynamic>> coupons, {required bool isActive}) {
    if (coupons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              isActive ? 'Aktif kuponunuz bulunmuyor' : 'Geçmiş kuponunuz bulunmuyor',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: coupons.length,
      itemBuilder: (context, index) {
        final coupon = coupons[index];
        return _buildCouponCard(coupon, isActive: isActive);
      },
    );
  }

  Widget _buildCouponCard(Map<String, dynamic> coupon, {required bool isActive, bool isWeb = false}) {
    return Container(
      margin: isWeb ? null : const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isWeb ? Border.all(color: Colors.grey.shade200) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            // Detay popup veya kullanım
          },
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Sol taraf - İkon ve Tutar
                Container(
                  width: isWeb ? 110 : 90,
                  decoration: BoxDecoration(
                    color: coupon['color'],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_offer, color: coupon['iconColor'], size: isWeb ? 32 : 28),
                      const SizedBox(height: 4),
                      Text(
                        coupon['isPercentage'] ? '%${coupon['discountAmount'].toInt()}' : '₺${coupon['discountAmount'].toInt()}',
                        style: TextStyle(
                          color: coupon['iconColor'],
                          fontWeight: FontWeight.bold,
                          fontSize: isWeb ? 22 : 18,
                        ),
                      ),
                      Text(
                        'İndirim',
                        style: TextStyle(
                          color: coupon['iconColor'],
                          fontSize: isWeb ? 13 : 11,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Kesik Çizgi Efekti
                CustomPaint(
                  size: const Size(1, double.infinity),
                  painter: DashedLinePainter(color: Colors.grey[300]!),
                ),

                // Sağ Taraf - Detaylar
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(isWeb ? 20 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                coupon['title'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isWeb ? 16 : 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  coupon['status'] ?? 'Pasif',
                                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: isWeb ? 8 : 2),
                        Text(
                          coupon['detail'],
                          style: TextStyle(color: Colors.grey[600], fontSize: isWeb ? 13 : 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isWeb ? 12 : 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Son: ${coupon['expiryDate']}',
                              style: TextStyle(color: Colors.grey[400], fontSize: 10),
                            ),
                            if (isActive)
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: coupon['code']));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${coupon['code']} kopyalandı!'),
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        coupon['code'],
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: isWeb ? 13 : 11,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.copy, size: isWeb ? 14 : 11, color: AppColors.primary),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final Color color;

  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const double dashHeight = 5;
    const double dashSpace = 3;
    double startY = 0;

    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
