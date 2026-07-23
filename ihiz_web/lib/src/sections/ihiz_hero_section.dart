import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';

/// Premium İHIZ landing hero.
///
/// Fixes the previous overflow: the old hero used [BoxFit.cover] on a
/// background image plus a hand-tuned empty gap to position the buttons, so the
/// scooter cropped/overflowed on different aspect ratios. Here the brand
/// gradient owns the layout height (content-driven, never clipped) and the
/// photo lives inside a fixed 16:9 rounded showcase with a gradient overlay, so
/// it can never push content off-screen on mobile.
class IhizHeroSection extends StatelessWidget {
  const IhizHeroSection({
    super.key,
    required this.onLogin,
    required this.onApply,
  });

  final VoidCallback onLogin;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = IhizBrand.isCompact(width);
        final headlineSize = (width * (compact ? 0.085 : 0.05)).clamp(
          30.0,
          58.0,
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 34,
            compact ? 22 : 36,
            compact ? 20 : 34,
            compact ? 16 : 26,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: IhizBrand.heroGradient,
            boxShadow: [
              BoxShadow(
                color: IhizBrand.navy.withValues(alpha: 0.30),
                blurRadius: 40,
                offset: const Offset(0, 22),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const IhizLogoLockup(size: 40),
              SizedBox(height: compact ? 10 : 14),
              Container(
                width: 168,
                height: 2.2,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              SizedBox(height: compact ? 10 : 14),
              Text(
                'İstediğin HIZ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                  fontSize: (headlineSize * 0.42).clamp(16.0, 24.0),
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: compact ? 8 : 12),
              Text(
                '1 Saatte Kapında,\nGününde Teslimat',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: headlineSize,
                  height: 1.04,
                  letterSpacing: -0.2,
                  shadows: const [
                    Shadow(
                      color: Color(0x55223A66),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
              SizedBox(height: compact ? 18 : 26),
              _HeroButtons(
                compact: compact,
                onLogin: onLogin,
                onApply: onApply,
              ),
              SizedBox(height: compact ? 20 : 30),
              _HeroShowcase(compact: compact),
            ],
          ),
        );
      },
    );
  }
}

class _HeroButtons extends StatelessWidget {
  const _HeroButtons({
    required this.compact,
    required this.onLogin,
    required this.onApply,
  });

  final bool compact;
  final VoidCallback onLogin;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final login = ElevatedButton(
      onPressed: onLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: IhizBrand.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        elevation: 8,
        shadowColor: const Color(0x6612449D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
      ),
      child: const Text('Giriş Yap'),
    );
    final register = OutlinedButton(
      onPressed: onApply,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        minimumSize: const Size.fromHeight(56),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.92), width: 1.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
      ),
      child: const Text('Kayıt Ol'),
    );

    if (compact) {
      return Column(
        children: [
          login,
          const SizedBox(height: 16),
          register,
        ],
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Row(
        children: [
          Expanded(child: login),
          const SizedBox(width: 18),
          Expanded(child: register),
        ],
      ),
    );
  }
}

class _HeroShowcase extends StatelessWidget {
  const _HeroShowcase({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 22 : 28),
        child: AspectRatio(
          aspectRatio: compact ? 4 / 3 : 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/hero/hero_bg.png',
                fit: BoxFit.cover,
                alignment: const Alignment(0, 0.06),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      IhizBrand.navy.withValues(alpha: 0.05),
                      IhizBrand.navy.withValues(alpha: 0.30),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(compact ? 22 : 28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.4,
                    ),
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
