import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../services/coupon_service.dart';

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

  Widget _buildCouponCard(Map<String, dynamic> coupon, {required bool isActive}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), // Boşluk azaltıldı (16 -> 12)
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                  width: 90, // Genişlik azaltıldı (100 -> 90)
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
                      Icon(Icons.local_offer, color: coupon['iconColor'], size: 28), // İkon küçültüldü (32 -> 28)
                      const SizedBox(height: 4), // Boşluk azaltıldı
                      Text(
                        coupon['isPercentage'] ? '%${coupon['discountAmount'].toInt()}' : '₺${coupon['discountAmount'].toInt()}',
                        style: TextStyle(
                          color: coupon['iconColor'],
                          fontWeight: FontWeight.bold,
                          fontSize: 18, // Font küçültüldü (20 -> 18)
                        ),
                      ),
                      Text(
                        'İndirim',
                        style: TextStyle(
                          color: coupon['iconColor'],
                          fontSize: 11, // Font küçültüldü (12 -> 11)
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
                    padding: const EdgeInsets.all(12), // Padding azaltıldı (16 -> 12)
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15, // Font küçültüldü (16 -> 15)
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Padding azaltıldı
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  coupon['status'] ?? 'Pasif',
                                  style: TextStyle(fontSize: 9, color: Colors.grey[600]), // Font küçültüldü
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2), // Boşluk azaltıldı (4 -> 2)
                        Text(
                          coupon['detail'],
                          style: TextStyle(color: Colors.grey[600], fontSize: 11), // Font küçültüldü (12 -> 11)
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6), // Boşluk azaltıldı (8 -> 6)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Son: ${coupon['expiryDate']}',
                              style: TextStyle(color: Colors.grey[400], fontSize: 10), // Font küçültüldü (11 -> 10)
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Padding azaltıldı
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        coupon['code'],
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11, // Font küçültüldü (12 -> 11)
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.copy, size: 11, color: AppColors.primary), // İkon küçültüldü
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
