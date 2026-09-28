import 'package:flutter/material.dart';

/// Marketplace color roles. Hex values match the live UI — aliases only.
class AppColors {
  static const Color primary = Color(0xFF7A2FF4);
  static const Color background = Color(0xFFF9FAFB);
  static const Color textDark = Color(0xFF333333);
  static const Color textGrey = Color(0xFF757575);
  static const Color softPurple = Color(0xFFE9DBFF);
  static const Color popupLavender = Color(0xFFE5D4FF);
  static const Color popupLavenderStrong = Color(0xFFC9A8FF);
  static const Color orangeLight = Color(
    0xFFFFCC80,
  ); // approximate for orange.shade100
  static const Color orangeDark = Color(0xFFF57C00); // approximate

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = background;
  static const Color onSurface = textDark;
  static const Color onSurfaceMuted = textGrey;
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF222222);
  static const Color border = Color(0xFFEEEEEE);
  static const Color borderStrong = Color(0xFFE0E0E0);
  static const Color iconMuted = Color(0xFFBDBDBD);
  static const Color iconFaint = Color(0xFFE0E0E0);
  static const Color danger = Color(0xFFD32F2F);
  static const Color dangerSoft = Color(0xFFFFCDD2);
  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFBBF7D0);
  static const Color warning = orangeDark;
  static const Color warningSoft = orangeLight;
  static const Color accentContainer = softPurple;
  static const Color overlay = Color(0xA6000000);
  static const Color scrim = Color(0x80000000);
}

/// Radii already used across marketplace chrome — named, not restyled.
class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppAssets {
  static const String ibulLogo = 'assets/icons/ibul_logo_header.png';
}

/// Opt-in token access via Theme.of(context).extension. Does not retint ColorScheme.
@immutable
class IbulColorTokens extends ThemeExtension<IbulColorTokens> {
  const IbulColorTokens();

  static IbulColorTokens of(BuildContext context) {
    return Theme.of(context).extension<IbulColorTokens>() ??
        const IbulColorTokens();
  }

  Color get primary => AppColors.primary;
  Color get surface => AppColors.surface;
  Color get onSurface => AppColors.onSurface;
  Color get onSurfaceMuted => AppColors.onSurfaceMuted;
  Color get border => AppColors.border;
  Color get danger => AppColors.danger;
  Color get success => AppColors.success;

  @override
  IbulColorTokens copyWith() => this;

  @override
  IbulColorTokens lerp(ThemeExtension<IbulColorTokens>? other, double t) {
    return this;
  }
}
