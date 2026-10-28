import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';

class IhizHeroSection extends StatelessWidget {
  const IhizHeroSection({
    super.key,
    required this.onTrack,
  });

  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final mobile = IhizBrand.isMobile(width);
        final titleSize = mobile ? 32.0 : (width >= 1100 ? 48.0 : 40.0);

        final copy = Column(
          crossAxisAlignment:
              mobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: IhizBrand.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'İHIZ · TESLİMAT PLATFORMU',
                style: TextStyle(
                  color: IhizBrand.blue,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            SizedBox(height: mobile ? 14 : 18),
            Text(
              'Teslimatın yeni hızı:',
              textAlign: mobile ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                color: IhizBrand.ink,
                fontWeight: FontWeight.w900,
                fontSize: titleSize,
                height: 1.05,
                letterSpacing: -0.8,
              ),
            ),
            Text(
              'İHIZ.',
              textAlign: mobile ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                color: IhizBrand.ink,
                fontWeight: FontWeight.w900,
                fontSize: titleSize,
                height: 1.05,
                letterSpacing: -0.8,
              ),
            ),
            SizedBox(height: mobile ? 12 : 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                'Mağazalardan müşterilere hızlı, güvenli ve takip edilebilir teslimat. İHIZ, siparişini en yakın uygun kuryeyle buluşturur; sen satışına, biz teslimata odaklanırız.',
                textAlign: mobile ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  color: IhizBrand.inkSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: mobile ? 14.5 : 16,
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(height: mobile ? 18 : 24),
            IhizPrimaryButton(
              label: 'Teslimatını Takip Et',
              icon: Icons.route_rounded,
              onPressed: onTrack,
              expanded: mobile,
            ),
          ],
        );

        final map = const _HeroRouteVisual();

        if (mobile) {
          return Column(
            children: [
              copy,
              const SizedBox(height: 18),
              SizedBox(height: 210, child: map),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 11, child: copy),
            const SizedBox(width: 28),
            Expanded(flex: 10, child: SizedBox(height: 340, child: map)),
          ],
        );
      },
    );
  }
}

class _HeroRouteVisual extends StatelessWidget {
  const _HeroRouteVisual();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: IhizBrand.line),
        boxShadow: IhizBrand.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _RouteMapPainter())),
            const Positioned(
              left: 14,
              top: 14,
              child: _MapChip(
                icon: Icons.storefront_outlined,
                title: 'Mağaza',
                caption: 'Paket hazır',
              ),
            ),
            const Positioned(
              right: 14,
              bottom: 14,
              child: _MapChip(
                icon: Icons.home_outlined,
                title: 'Müşteri',
                caption: 'Teslimat noktası',
              ),
            ),
            const Align(
              alignment: Alignment(0.05, -0.08),
              child: _RouteBubble(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({
    required this.icon,
    required this.title,
    required this.caption,
  });

  final IconData icon;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IhizBrand.line),
        boxShadow: [
          BoxShadow(
            color: IhizBrand.navy.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: IhizBrand.blue),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: IhizBrand.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              Text(
                caption,
                style: const TextStyle(
                  color: IhizBrand.inkSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteBubble extends StatelessWidget {
  const _RouteBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: IhizBrand.blue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Yolda',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  const _RouteMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF4F8FC),
    );

    final park = Paint()..color = const Color(0xFFD7EEDC);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.06, size.height * 0.55, size.width * 0.28, size.height * 0.28),
        const Radius.circular(18),
      ),
      park,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.62, size.height * 0.12, size.width * 0.26, size.height * 0.22),
        const Radius.circular(18),
      ),
      park,
    );

    final road = Paint()
      ..color = const Color(0xFFE3EAF3)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.22,
        size.width * 0.48,
        size.height * 0.46,
      )
      ..quadraticBezierTo(
        size.width * 0.56,
        size.height * 0.72,
        size.width * 0.82,
        size.height * 0.68,
      );
    canvas.drawPath(path, road);

    final route = Paint()
      ..color = IhizBrand.blue
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, route);

    _dot(canvas, Offset(size.width * 0.18, size.height * 0.28), IhizBrand.blue);
    _dot(canvas, Offset(size.width * 0.82, size.height * 0.68), const Color(0xFFE85D4C));
  }

  void _dot(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, 8, Paint()..color = Colors.white);
    canvas.drawCircle(center, 5.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
