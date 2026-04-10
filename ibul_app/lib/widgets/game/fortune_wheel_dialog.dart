import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/coupon_service.dart';

class FortuneWheelDialog extends StatefulWidget {
  final VoidCallback? onSpinComplete;

  const FortuneWheelDialog({super.key, this.onSpinComplete});

  @override
  State<FortuneWheelDialog> createState() => _FortuneWheelDialogState();
}

class _FortuneWheelDialogState extends State<FortuneWheelDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentAngle = 0;
  bool _isSpinning = false;
  
  // Canlı Renk Paleti (Casino Tarzı)
  final List<Map<String, dynamic>> _items = [
    {'label': '%50\nİNDİRİM', 'color': const Color(0xFFFFD700), 'type': 'discount', 'val': 50.0, 'isPerc': true, 'textColor': Colors.black}, // Altın
    {'label': 'iPhone 15', 'color': const Color(0xFF000000), 'type': 'grand_prize', 'val': 0.0, 'textColor': Colors.white}, // Siyah (Premium)
    {'label': '100 TL\nKUPON', 'color': const Color(0xFFFF0000), 'type': 'discount', 'val': 100.0, 'isPerc': false, 'textColor': Colors.white}, // Kırmızı
    {'label': 'KARGO\nBEDAVA', 'color': const Color(0xFF1E90FF), 'type': 'free_shipping', 'val': 0.0, 'textColor': Colors.white}, // Canlı Mavi
    {'label': '%25\nİNDİRİM', 'color': const Color(0xFF32CD32), 'type': 'discount', 'val': 25.0, 'isPerc': true, 'textColor': Colors.white}, // Lime Yeşili
    {'label': 'SÜRPRİZ\nHEDİYE', 'color': const Color(0xFFFF69B4), 'type': 'surprise', 'val': 75.0, 'textColor': Colors.white}, // Hot Pink
    {'label': '50 TL\nKUPON', 'color': const Color(0xFFFF8C00), 'type': 'discount', 'val': 50.0, 'isPerc': false, 'textColor': Colors.white}, // Koyu Turuncu
    {'label': '%10\nİNDİRİM', 'color': const Color(0xFF9370DB), 'type': 'discount', 'val': 10.0, 'isPerc': true, 'textColor': Colors.white}, // Mor
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), // Biraz daha uzun dönüş süresi
    );
    
    _animation = CurvedAnimation(parent: _controller, curve: Curves.decelerate);
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isSpinning = false);
        _handlePrize();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spinWheel() {
    if (_isSpinning) return;

    setState(() => _isSpinning = true);
    
    final random = Random();
    // Daha fazla tur (10-15 arası)
    final spinCount = 10 + random.nextInt(5); 
    final randomAngle = random.nextDouble() * 2 * pi;
    final targetAngle = _currentAngle + (spinCount * 2 * pi) + randomAngle;

    _animation = Tween<double>(
      begin: _currentAngle,
      end: targetAngle,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)); // Daha yumuşak duruş

    _controller.forward(from: 0).then((_) {
      _currentAngle = targetAngle;
    });
  }

  void _handlePrize() {
    double normalizedAngle = _currentAngle % (2 * pi);
    double segmentAngle = 2 * pi / _items.length;
    double arrowAngle = 3 * pi / 2; // 270 derece (tepe)
    
    double effectiveAngle = (arrowAngle - normalizedAngle) % (2 * pi);
    if (effectiveAngle < 0) effectiveAngle += 2 * pi;
    
    int winnerIndex = (effectiveAngle / segmentAngle).floor();
    if (winnerIndex >= _items.length) winnerIndex = 0;
    
    final wonItem = _items[winnerIndex];
    
    if (wonItem['type'] != 'none') {
      _saveCoupon(wonItem);
      _showResultDialog(wonItem, true);
    } else {
      _showResultDialog(wonItem, false);
    }

    widget.onSpinComplete?.call();
  }

  void _saveCoupon(Map<String, dynamic> item) {
    final randomCode = 'SANSLI${Random().nextInt(900) + 100}';
    final coupon = CouponModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Çark Hediyesi: ${item['label']}',
      description: item['type'] == 'free_shipping' ? 'Kargo Bedava' : '${item['label']} Fırsatı',
      code: randomCode,
      discountAmount: (item['val'] as num).toDouble(),
      isPercentage: item['isPerc'] ?? false,
      minPrice: 0,
      expiryDate: '24 Saat Geçerli',
      color: (item['color'] as Color).withValues(alpha: 0.1),
      iconColor: item['color'],
    );
    
    CouponService().addCoupon(coupon);
  }

  void _showResultDialog(Map<String, dynamic> item, bool isWin) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: (item['color'] as Color).withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Işıltı efekti için stack
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (item['color'] as Color).withValues(alpha: 0.2),
                    ),
                  ),
                  Icon(
                    isWin ? Icons.stars : Icons.sentiment_dissatisfied,
                    size: 80,
                    color: item['color'],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                isWin ? 'TEBRİKLER!' : 'ÜZGÜNÜZ',
                style: const TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isWin ? '${item['label']} kazandınız!' : 'Bu seferlik şanssızdın.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (isWin)
                Text(
                  'Kupon hesabına tanımlandı.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Dialog kapat
                  Navigator.pop(context); // Çark ekranını kapat
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: item['color'],
                  foregroundColor: item['textColor'] ?? Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  elevation: 8,
                ),
                child: const Text('HARİKA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ekran boyutunu al
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Çark boyutunu ekran genişliğine göre ayarla (maksimum 320, minimum 280)
    final wheelSize = (screenWidth * 0.85).clamp(280.0, 340.0);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(0),
      child: SizedBox(
        width: wheelSize + 20, 
        height: wheelSize + 80, // Çark + buton alanı
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Dış Işık Halkası
            Container(
              width: wheelSize,
              height: wheelSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF222222),
                border: Border.all(color: const Color(0xFFFFD700), width: 8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            
            // Çark Gövdesi
            SizedBox(
              width: wheelSize - 30,
              height: wheelSize - 30,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _animation.value,
                    child: CustomPaint(
                      painter: WheelPainter(items: _items),
                    ),
                  );
                },
              ),
            ),
            
            // Ampuller
            ...List.generate(12, (index) {
              final angle = (2 * pi / 12) * index;
              final radius = wheelSize / 2 - 8; // Çerçeveye göre ayarla
              return Positioned(
                // Stack'in ortasına göre hesaplama yapıyoruz
                // Stack width/2 = (wheelSize+20)/2
                left: (wheelSize + 20) / 2 + radius * cos(angle) - 6 - 10, // -10 offset düzeltmesi
                top: (wheelSize + 80) / 2 + radius * sin(angle) - 6 - 40, // -40 dikey offset
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.white, blurRadius: 5)],
                  ),
                ),
              );
            }),

            // Gösterge
            Positioned(
              top: 0,
              child: Container(
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
                  ]
                ),
                child: Image.asset(
                  'assets/icons/pointer.png',
                  width: 50,
                  height: 60,
                  errorBuilder: (c, o, s) => const Icon(
                    Icons.location_on, 
                    size: 60, 
                    color: Color(0xFFE74C3C),
                  ),
                ),
              ),
            ),
            
            // Orta Göbek ve Çevir Butonu
            GestureDetector(
              onTap: _spinWheel,
              child: Container(
                width: wheelSize * 0.25, // Orantılı boyut
                height: wheelSize * 0.25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Colors.white, Color(0xFFE0E0E0)],
                  ),
                  border: Border.all(color: const Color(0xFFFFD700), width: 4),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Center(
                  child: _isSpinning 
                    ? const CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text('ÇEVİR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                          Icon(Icons.touch_app, size: 16),
                        ],
                      ),
                ),
              ),
            ),
            
            // Kapatma Butonu
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
                  ),
                  child: const Icon(Icons.close, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> items;

  WheelPainter({required this.items});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Metin ressamı
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Çizime -pi/2 (saat 12) yönünden değil, 0'dan başlıyoruz. Dönüşü transform hallediyor.
    double startAngle = 0;
    final sweepAngle = 2 * pi / items.length;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      paint.color = item['color'];
      
      // 1. Dilimi çiz
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      
      // 2. Kenar çizgileri
      final borderPaint = Paint()
        ..color = const Color(0xFFFFD700).withValues(alpha: 0.5) 
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawArc(rect, startAngle, sweepAngle, true, borderPaint);

      // 3. Metin Çizimi - Sadece SORU İŞARETİ
      canvas.save();
      
      // Metni dilimin ortasına hizalamak için döndür
      final angle = startAngle + sweepAngle / 2;
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      
      // Metin stili (Büyük Soru İşareti)
      textPainter.text = TextSpan(
        text: '?',
        style: TextStyle(
          color: item['textColor'] ?? Colors.white,
          fontSize: 32, // Büyük font
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(1, 1),
              blurRadius: 2,
            ),
          ],
        ),
      );
      textPainter.layout();
      
      // Metni yerleştir (yarıçapın %70'i kadar dışarıda)
      canvas.translate(radius * 0.70, -textPainter.height / 2);
      
      // Metni 90 derece döndür
      textPainter.paint(canvas, Offset.zero);
      
      canvas.restore();
      
      startAngle += sweepAngle;
    }
    
    // Merkezdeki vida delikleri (Süs)
    final circlePaint = Paint()..color = Colors.white.withValues(alpha: 0.3);
    canvas.drawCircle(center, radius * 0.15, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
