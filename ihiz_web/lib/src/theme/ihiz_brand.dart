import 'package:flutter/material.dart';

/// Shared İHIZ brand tokens for the marketing/landing surface.
///
/// Only landing / footer / admin-login UI uses these. The courier operation
/// screens keep their own styling untouched.
class IhizBrand {
  const IhizBrand._();

  // Core blues / navy — the existing İHIZ brand language.
  static const Color navy = Color(0xFF0E2A47);
  static const Color navyDeep = Color(0xFF0A2036);
  static const Color navySoft = Color(0xFF10345F);
  static const Color blue = Color(0xFF1F64D6);
  static const Color blueBright = Color(0xFF2E73FF);
  static const Color blueOcean = Color(0xFF1A5A9B);
  static const Color ink = Color(0xFF102941);
  static const Color inkSoft = Color(0xFF51677F);
  static const Color surface = Color(0xFFF2F7FB);
  static const Color line = Color(0xFFDCE8F8);
  static const Color mint = Color(0xFF09A66D);

  /// Max content width for the marketing sections.
  static const double contentMaxWidth = 1280;

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0C2745), Color(0xFF13457C), Color(0xFF1E63B4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient footerGradient = LinearGradient(
    colors: [Color(0xFF0C2440), Color(0xFF0E2E54)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient adminGradient = LinearGradient(
    colors: [Color(0xFFEAF2FE), Color(0xFFDCEAFB), Color(0xFFF4F8FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Breakpoint below which the marketing surface switches to the mobile
  /// (single-column / hamburger) layout.
  static bool isMobile(double width) => width < 920;
  static bool isCompact(double width) => width < 640;
}

/// The İHIZ logo lockup (white rounded tile + wordmark). Falls back to a truck
/// icon when the optional logo asset is missing.
class IhizLogoLockup extends StatelessWidget {
  const IhizLogoLockup({
    super.key,
    this.size = 34,
    this.color = Colors.white,
    this.onDark = true,
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
          padding: EdgeInsets.all(size * 0.18),
          decoration: BoxDecoration(
            color: onDark ? Colors.white : IhizBrand.blue,
            borderRadius: BorderRadius.circular(size * 0.42),
            boxShadow: [
              BoxShadow(
                color: IhizBrand.navy.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          // No standalone logo asset ships with the app, so render the brand
          // mark directly. Avoids a missing-asset load (which the SPA rewrite
          // otherwise answers with index.html, spamming decode exceptions).
          child: Icon(
            Icons.local_shipping_rounded,
            color: onDark ? IhizBrand.blue : Colors.white,
            size: size * 0.72,
          ),
        ),
        SizedBox(width: size * 0.32),
        Text(
          'İHIZ',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: size,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}
