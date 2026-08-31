import 'package:flutter/material.dart';

/// İHIZ landing marka token’ları — mavi / lacivert kurumsal dil.
class IhizBrand {
  const IhizBrand._();

  static const Color navy = Color(0xFF0E2A47);
  static const Color navyDeep = Color(0xFF0A2036);
  static const Color navySoft = Color(0xFF10345F);
  static const Color blue = Color(0xFF1F64D6);
  static const Color blueBright = Color(0xFF2E73FF);
  static const Color blueOcean = Color(0xFF1A5A9B);
  static const Color ink = Color(0xFF102941);
  static const Color inkSoft = Color(0xFF51677F);
  static const Color surface = Color(0xFFF5F8FC);
  static const Color surfaceAlt = Color(0xFFEEF3FA);
  static const Color line = Color(0xFFDCE8F8);
  static const Color mint = Color(0xFF09A66D); // yalnızca durum göstergesi

  /// Section container — ortalanmış içerik genişliği.
  static const double contentMaxWidth = 1220;

  /// Viewport / available-width breakpoints.
  /// Independent of marketplace IbulChrome.web (1100).
  /// LayoutBuilder `constraints.maxWidth` is post-padding; use [useWideGrid]
  /// for multi-column sections.
  static const double desktopMin = 1024;
  static const double tabletMin = 720;

  static bool isDesktop(double width) => width >= desktopMin;
  static bool isTablet(double width) => width >= tabletMin && width < desktopMin;
  static bool isMobile(double width) => width < tabletMin;

  /// 3 kolon feature/grid (içerik alanı ≥ 900).
  static bool useWideGrid(double maxWidth) => maxWidth >= 900;

  /// 2 kolon grid (içerik alanı ≥ 560).
  static bool useMediumGrid(double maxWidth) => maxWidth >= 560;

  static double sectionGap(double maxWidth) =>
      isMobile(maxWidth) ? 36 : (isTablet(maxWidth) ? 56 : 72);

  static double pageGutter(double maxWidth) =>
      isMobile(maxWidth) ? 16 : (isTablet(maxWidth) ? 24 : 32);

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0B2340), Color(0xFF13457C), Color(0xFF1E63B4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient footerGradient = LinearGradient(
    colors: [Color(0xFF0C2440), Color(0xFF0E2E54)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient softBlueGradient = LinearGradient(
    colors: [Color(0xFFF7FAFF), Color(0xFFEEF5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: navy.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];
}

class IhizLogoLockup extends StatelessWidget {
  const IhizLogoLockup({
    super.key,
    this.size = 28,
    this.color = IhizBrand.ink,
    this.onDark = false,
  });

  final double size;
  final Color color;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final tile = size * 1.18;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: tile,
          height: tile,
          decoration: BoxDecoration(
            color: onDark ? Colors.white : IhizBrand.blue,
            borderRadius: BorderRadius.circular(size * 0.38),
            boxShadow: [
              BoxShadow(
                color: IhizBrand.navy.withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.local_shipping_rounded,
            color: onDark ? IhizBrand.blue : Colors.white,
            size: size * 0.68,
          ),
        ),
        SizedBox(width: size * 0.28),
        Text(
          'İHIZ',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: size,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}
