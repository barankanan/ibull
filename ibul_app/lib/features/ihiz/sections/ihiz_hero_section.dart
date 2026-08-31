import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';

class IhizHeroSection extends StatelessWidget {
  const IhizHeroSection({
    super.key,
    required this.onLogin,
    required this.onCourierApply,
    required this.onBusinessJoin,
    required this.onHowItWorks,
  });

  final VoidCallback onLogin;
  final VoidCallback onCourierApply;
  final VoidCallback onBusinessJoin;
  final VoidCallback onHowItWorks;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final mobile = IhizBrand.isMobile(width);
        final desktop = IhizBrand.isDesktop(width);

        final copy = Column(
          crossAxisAlignment:
              mobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Text(
                'İHIZ · TESLİMAT PLATFORMU',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            SizedBox(height: mobile ? 18 : 22),
            Text(
              'Teslimatın yeni hızı: İhız.',
              textAlign: mobile ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: mobile ? 32 : (desktop ? 48 : 40),
                height: 1.08,
                letterSpacing: -0.8,
              ),
            ),
            SizedBox(height: mobile ? 14 : 18),
            Text(
              'Mağazalardan müşterilere hızlı, güvenli ve takip edilebilir teslimat. İhız, siparişini en yakın uygun kuryeyle buluşturur; sen satışına, biz teslimata odaklanırız.',
              textAlign: mobile ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontWeight: FontWeight.w600,
                fontSize: mobile ? 15 : 17,
                height: 1.55,
              ),
            ),
            SizedBox(height: mobile ? 22 : 28),
            if (mobile)
              Column(
                children: [
                  IhizSecondaryButton(
                    label: 'Giriş Yap',
                    icon: Icons.login_rounded,
                    onPressed: onLogin,
                    expanded: true,
                    onDark: true,
                  ),
                  const SizedBox(height: 12),
                  IhizPrimaryButton(
                    label: 'Kurye Ol',
                    icon: Icons.two_wheeler_rounded,
                    onPressed: onCourierApply,
                    expanded: true,
                  ),
                  const SizedBox(height: 12),
                  IhizSecondaryButton(
                    label: 'Nasıl Çalışır?',
                    icon: Icons.play_circle_outline_rounded,
                    onPressed: onHowItWorks,
                    expanded: true,
                    onDark: true,
                  ),
                  const SizedBox(height: 12),
                  IhizSecondaryButton(
                    label: 'İşletme Olarak Kullan',
                    icon: Icons.storefront_rounded,
                    onPressed: onBusinessJoin,
                    expanded: true,
                    onDark: true,
                  ),
                ],
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  IhizSecondaryButton(
                    label: 'Giriş Yap',
                    icon: Icons.login_rounded,
                    onPressed: onLogin,
                    onDark: true,
                  ),
                  IhizPrimaryButton(
                    label: 'Kurye Ol',
                    icon: Icons.two_wheeler_rounded,
                    onPressed: onCourierApply,
                  ),
                  IhizSecondaryButton(
                    label: 'Nasıl Çalışır?',
                    icon: Icons.play_circle_outline_rounded,
                    onPressed: onHowItWorks,
                    onDark: true,
                  ),
                  IhizSecondaryButton(
                    label: 'İşletme Olarak Kullan',
                    icon: Icons.storefront_rounded,
                    onPressed: onBusinessJoin,
                    onDark: true,
                  ),
                ],
              ),
          ],
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            mobile ? 18 : 36,
            mobile ? 22 : 36,
            mobile ? 18 : 36,
            mobile ? 20 : 32,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(mobile ? 24 : 32),
            gradient: IhizBrand.heroGradient,
            boxShadow: [
              BoxShadow(
                color: IhizBrand.navy.withValues(alpha: 0.28),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: mobile
              ? Column(
                  children: [
                    copy,
                    const SizedBox(height: 20),
                    const _HeroRouteVisual(compact: true),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 11, child: copy),
                    const SizedBox(width: 28),
                    const Expanded(flex: 10, child: _HeroRouteVisual(compact: false)),
                  ],
                ),
        );
      },
    );
  }
}

class _HeroRouteVisual extends StatelessWidget {
  const _HeroRouteVisual({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: compact ? 1.45 : 1.1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 20 : 26),
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _RouteMapPainter())),
            Positioned(
              left: 16,
              top: 16,
              child: _chip(Icons.storefront_outlined, 'Mağaza'),
            ),
            Positioned(
              right: 16,
              top: 16,
              child: _chip(Icons.inventory_2_outlined, 'Paket'),
            ),
            Positioned(
              left: compact ? 28 : 48,
              bottom: compact ? 72 : 88,
              child: _pin(Icons.store_mall_directory_rounded, const Color(0xFF5B9CFF)),
            ),
            Positioned(
              right: compact ? 36 : 56,
              bottom: compact ? 48 : 56,
              child: _pin(Icons.home_rounded, Colors.white),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: const Alignment(0.05, -0.05),
                child: _pin(Icons.two_wheeler_rounded, IhizBrand.blueBright),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.route_rounded, color: IhizBrand.blue, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Canlı rota · 12 dk tahmini teslimat',
                        style: TextStyle(
                          color: IhizBrand.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: IhizBrand.blue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: IhizBrand.ink,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pin(IconData icon, Color color) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: color == Colors.white ? IhizBrand.navy : Colors.white,
        size: 22,
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  const _RouteMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final route = Paint()
      ..color = const Color(0xFF7EB6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.42,
        size.width * 0.52,
        size.height * 0.48,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.56,
        size.width * 0.88,
        size.height * 0.68,
      );

    canvas.drawPath(path, road);
    canvas.drawPath(path, route);

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final x = size.width * i / 5;
      final y = size.height * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
