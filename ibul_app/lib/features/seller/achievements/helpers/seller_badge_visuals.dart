import 'package:flutter/material.dart';

import '../data/seller_badge_definitions.dart';
import '../models/seller_badge_models.dart';

/// Data-driven premium rozet görsel token'ları.
class SellerBadgeVisualSpec {
  const SellerBadgeVisualSpec({
    required this.icon,
    required this.iconColor,
    required this.baseColor,
    required this.accentColor,
    required this.backgroundGradient,
    required this.rimGradient,
    required this.sparkleColor,
    required this.depthShadowColor,
    required this.glowEnabled,
    required this.specialEffectLevel,
    this.accentGlyph,
    this.badgeShapeVariant = 0,
  });

  final IconData icon;
  final Color iconColor;
  final Color baseColor;
  final Color accentColor;
  final List<Color> backgroundGradient;
  final List<Color> rimGradient;
  final Color sparkleColor;
  final Color depthShadowColor;
  final bool glowEnabled;
  final IconData? accentGlyph;

  /// 0 = düz, 1 = soft, 2 = premium, 3 = crystal
  final int specialEffectLevel;

  /// 0 = classic disc, 1 = beveled medallion
  final int badgeShapeVariant;
}

class _CategoryPalette {
  const _CategoryPalette({
    required this.primary,
    required this.secondary,
    required this.sparkle,
  });

  final Color primary;
  final Color secondary;
  final Color sparkle;
}

SellerBadgeVisualSpec sellerBadgeVisualSpec(SellerBadgeProgress progress) {
  final definition = progress.definition;
  final levelStyle = SellerBadgeLevelStyle.forLevel(definition.level);
  final category = _categoryPalette(definition.category, definition.badgeId);
  final icon = _resolveBadgeIcon(definition);

  final baseEffect = switch (definition.level) {
    SellerBadgeLevel.bronze => 0,
    SellerBadgeLevel.silver => 1,
    SellerBadgeLevel.gold => 2,
    SellerBadgeLevel.diamond => 3,
    SellerBadgeLevel.verified => 3,
  };
  final specialEffect = definition.premiumGlow ||
          definition.level == SellerBadgeLevel.verified
      ? (baseEffect + 1).clamp(0, 3)
      : baseEffect;

  final categoryWeight = definition.badgeId == 'verified_store' ? 0.72 : 0.58;
  final iconColor =
      Color.lerp(category.primary, levelStyle.color, categoryWeight)!;
  final accent = Color.lerp(category.secondary, levelStyle.accent, 0.28)!;

  final backgroundGradient = [
    Color.lerp(levelStyle.background, category.primary, 0.22)!,
    Color.lerp(levelStyle.background, Colors.white, 0.28)!,
    Color.lerp(category.secondary, levelStyle.color, 0.18)!
        .withValues(alpha: 0.24),
  ];

  final rimGradient = [
    Color.lerp(category.primary, levelStyle.color, 0.18)!,
    Color.lerp(category.secondary, levelStyle.accent, 0.32)!,
    Color.lerp(Colors.white, category.sparkle, 0.45)!,
  ];

  return SellerBadgeVisualSpec(
    icon: icon,
    iconColor: iconColor,
    baseColor: levelStyle.color,
    accentColor: accent,
    backgroundGradient: backgroundGradient,
    rimGradient: rimGradient,
    sparkleColor: category.sparkle,
    depthShadowColor:
        Color.lerp(levelStyle.color, category.primary, 0.38)!,
    glowEnabled: progress.allowsPremiumGlow,
    specialEffectLevel: specialEffect,
    accentGlyph: _accentGlyphFor(definition),
    badgeShapeVariant: specialEffect >= 2 ? 1 : 0,
  );
}

_CategoryPalette _categoryPalette(
  SellerBadgeCategory category,
  String badgeId,
) {
  if (badgeId == 'verified_store') {
    return const _CategoryPalette(
      primary: Color(0xFF1D4ED8),
      secondary: Color(0xFF38BDF8),
      sparkle: Color(0xFFE0F2FE),
    );
  }

  switch (category) {
    case SellerBadgeCategory.onboarding:
      return const _CategoryPalette(
        primary: Color(0xFFEA580C),
        secondary: Color(0xFFF59E0B),
        sparkle: Color(0xFFFDE68A),
      );
    case SellerBadgeCategory.followers:
      return const _CategoryPalette(
        primary: Color(0xFF1D4ED8),
        secondary: Color(0xFF06B6D4),
        sparkle: Color(0xFF7DD3FC),
      );
    case SellerBadgeCategory.orders:
      return const _CategoryPalette(
        primary: Color(0xFF6D28D9),
        secondary: Color(0xFF4338CA),
        sparkle: Color(0xFFC4B5FD),
      );
    case SellerBadgeCategory.shippingSpeed:
      return const _CategoryPalette(
        primary: Color(0xFFD97706),
        secondary: Color(0xFFFBBF24),
        sparkle: Color(0xFFFEF08A),
      );
    case SellerBadgeCategory.packagingQuality:
      return const _CategoryPalette(
        primary: Color(0xFFE11D48),
        secondary: Color(0xFFFB7185),
        sparkle: Color(0xFFFDA4AF),
      );
    case SellerBadgeCategory.messageResponse:
      return const _CategoryPalette(
        primary: Color(0xFF059669),
        secondary: Color(0xFF14B8A6),
        sparkle: Color(0xFF6EE7B7),
      );
    case SellerBadgeCategory.reviews:
      return const _CategoryPalette(
        primary: Color(0xFFA21CAF),
        secondary: Color(0xFFEC4899),
        sparkle: Color(0xFFF9A8D4),
      );
    case SellerBadgeCategory.region:
      return const _CategoryPalette(
        primary: Color(0xFF047857),
        secondary: Color(0xFFD97706),
        sparkle: Color(0xFF86EFAC),
      );
    case SellerBadgeCategory.verification:
      return const _CategoryPalette(
        primary: Color(0xFF1E40AF),
        secondary: Color(0xFF38BDF8),
        sparkle: Color(0xFFDBEAFE),
      );
  }
}

IconData? _accentGlyphFor(SellerBadgeDefinition definition) {
  if (definition.badgeId == 'verified_store') return Icons.verified_rounded;
  if (definition.badgeId == 'region_joined') return Icons.auto_awesome;
  if (definition.premiumGlow || definition.level == SellerBadgeLevel.diamond) {
    return Icons.auto_awesome;
  }
  if (definition.level == SellerBadgeLevel.gold ||
      definition.level == SellerBadgeLevel.verified) {
    return Icons.star_rounded;
  }
  return null;
}

IconData _resolveBadgeIcon(SellerBadgeDefinition definition) {
  if (definition.badgeId == 'new_seller') return Icons.spa_rounded;
  if (definition.badgeId == 'region_joined') return Icons.location_on_rounded;
  if (definition.badgeId == 'verified_store') {
    return Icons.workspace_premium_rounded;
  }
  return definition.icon;
}

String sellerBadgeInfoTooltipMessage(SellerBadgeProgress progress) {
  final level = SellerBadgeLevelStyle.forLevel(progress.definition.level).label;
  return '${progress.definition.title}\n'
      '${progress.definition.description}\n'
      'Seviye: $level';
}

/// Kategori paletleri birbirinden ayrışıyor mu — test yardımcısı.
bool sellerBadgeCategoryPalettesAreDistinct() {
  final palettes = SellerBadgeCategory.values
      .map((category) => _categoryPalette(category, ''))
      .map((p) => p.primary.toARGB32())
      .toSet();
  return palettes.length == SellerBadgeCategory.values.length;
}

/// Onaylanmış mağaza rozeti mavi verified paletinde mi.
bool sellerVerifiedBadgeUsesBluePalette() {
  final definition = sellerBadgeDefinitionById('verified_store');
  if (definition == null) return false;
  final palette = _categoryPalette(
    definition.category,
    definition.badgeId,
  );
  return palette.primary.toARGB32() == const Color(0xFF1D4ED8).toARGB32();
}
