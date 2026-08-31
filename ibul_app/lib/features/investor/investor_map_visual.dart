import 'package:flutter/material.dart';

import '../../core/constants.dart';
import 'investor_widgets.dart';

class InvestorTypeRibbon extends StatelessWidget {
  const InvestorTypeRibbon({super.key});

  static const types = [
    (Icons.store_outlined, 'Mağaza'),
    (Icons.checkroom_outlined, 'Butik'),
    (Icons.local_grocery_store_outlined, 'Market'),
    (Icons.directions_car_outlined, 'Oto kiralama'),
    (Icons.apartment_outlined, 'Emlak'),
    (Icons.restaurant_outlined, 'Restoran'),
    (Icons.handyman_outlined, 'Hizmet'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in types)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.softPurple,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: InvestorTokens.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(type.$1, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  type.$2,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: InvestorTokens.ink,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class InvestorStoreProductMap extends StatelessWidget {
  const InvestorStoreProductMap({super.key});

  @override
  Widget build(BuildContext context) {
    return InvestorCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 340,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(InvestorTokens.radius),
          child: Stack(
            children: [
              const Positioned.fill(child: _MapGrid()),
              const Positioned(
                left: 22,
                top: 28,
                child: _StorePin(label: 'Butik Lila', active: true),
              ),
              const Positioned(
                right: 36,
                top: 44,
                child: _StorePin(label: 'Market 7/24'),
              ),
              const Positioned(
                left: 48,
                bottom: 36,
                child: _StorePin(label: 'Oto Kiralama'),
              ),
              const Positioned(
                right: 28,
                bottom: 48,
                child: _StorePin(label: 'Emlak Ofisi'),
              ),
              const Positioned(
                left: 168,
                top: 86,
                child: _ProductPopup(),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Text(
                  'Örnek harita. Mağazaya dokununca ürünler popup’ta görünür.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: InvestorTokens.ink.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapGrid extends StatelessWidget {
  const _MapGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MapGridPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFF6F1FF);
    canvas.drawRect(Offset.zero & size, bg);
    final line = Paint()
      ..color = const Color(0xFFD9C8F5)
      ..strokeWidth = 1.2;
    for (var x = 0.0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final road = Paint()
      ..color = const Color(0xFFE4D6FA)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.42),
      Offset(size.width, size.height * 0.42),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.38, 0),
      Offset(size.width * 0.38, size.height),
      road,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StorePin extends StatelessWidget {
  const _StorePin({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.location_on,
          color: active ? AppColors.primary : const Color(0xFF9B7AD9),
          size: active ? 36 : 28,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? AppColors.primary : InvestorTokens.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: active ? AppColors.primary : InvestorTokens.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductPopup extends StatelessWidget {
  const _ProductPopup();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: SizedBox(
        width: 220,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Butik Lila',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: InvestorTokens.ink,
                ),
              ),
              const Text(
                '1,2 km · Açık',
                style: TextStyle(
                  color: Color(0xFF1B7F5A),
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 10),
              const _PopupProduct(name: 'Bluz', price: '890 ₺'),
              const SizedBox(height: 6),
              const _PopupProduct(name: 'Çanta', price: '1.250 ₺'),
              const SizedBox(height: 6),
              const _PopupProduct(name: 'Ceket', price: '2.100 ₺'),
              const SizedBox(height: 8),
              Text(
                'Örnek ürün listesi',
                style: TextStyle(
                  color: InvestorTokens.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopupProduct extends StatelessWidget {
  const _PopupProduct({required this.name, required this.price});

  final String name;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.softPurple,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.shopping_bag_outlined,
            size: 16,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: InvestorTokens.ink,
            ),
          ),
        ),
        Text(
          price,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
