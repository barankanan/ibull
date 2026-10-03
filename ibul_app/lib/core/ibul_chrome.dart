import 'package:flutter/material.dart';

import 'constants.dart';
import '../responsive/breakpoints.dart';

/// Marketplace chrome contract (header / footer / home web vs mobile).
///
/// İHIZ uses [IhizBrand] (desktop 1024) and must not import this file.
abstract final class IbulChrome {
  static const double web = ScreenBreakpoints.marketplaceWeb;
  static const double maxContentWidth = ScreenBreakpoints.maxContentWidth;
  static const double footerCompact = 920;

  static const double webHorizontalPadding = 40;
  static const double webVerticalPadding = 16;
  static const double mobileHorizontalPadding = 12;
  static const double mobileVerticalPadding = 10;

  static const Color footerInk = Color(0xFF1A1A2E);

  /// Uzun sayfada içerik ile footer arasındaki nefes.
  static const double footerLongSpacingDesktop = 64;
  static const double footerLongSpacingCompact = 48;

  /// Kısa sayfada footer'dan önceki minimum boşluk.
  static const double footerShortClearanceDesktop = 200;
  static const double footerShortClearanceTablet = 140;
  static const double footerShortClearanceMobile = 80;

  /// Kısa sayfada belgenin viewport altına taşacağı minimum miktar.
  static const double footerShortOverflow = 72;

  static bool isWeb(double width) => width >= web;

  static bool isWebOf(BuildContext context) =>
      isWeb(MediaQuery.sizeOf(context).width);

  static bool isFooterCompact(double width) => width < footerCompact;

  static EdgeInsets headerPadding({required bool isWeb}) => EdgeInsets.symmetric(
        horizontal: isWeb ? webHorizontalPadding : mobileHorizontalPadding,
        vertical: isWeb ? webVerticalPadding : mobileVerticalPadding,
      );

  static List<BoxShadow> get headerShadow => [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static BoxDecoration get headerBarDecoration => BoxDecoration(
        color: AppColors.surface,
        boxShadow: headerShadow,
      );

  static const BoxDecoration categoryBarDecoration = BoxDecoration(
    color: AppColors.surface,
    border: Border(bottom: BorderSide(color: AppColors.border)),
  );

  static const BoxConstraints contentConstraints = BoxConstraints(
    maxWidth: maxContentWidth,
  );

  /// Desktop >= 1100, tablet, mobil. Tek kaynak: kısa sayfa footer boşluğu.
  static double footerShortClearanceForWidth(double width) {
    if (width >= web) return footerShortClearanceDesktop;
    if (width > ScreenBreakpoints.mobile) return footerShortClearanceTablet;
    return footerShortClearanceMobile;
  }

  static double footerLongSpacingForWidth(double width) {
    return width >= web ? footerLongSpacingDesktop : footerLongSpacingCompact;
  }

  /// İçerik viewport'a sığıyorsa kısa clearance, taşarsa uzun sayfa aralığı.
  /// Kısa sayfada footer'ın tamamı ilk ekrana sığmasın diye gerekirse boşluk büyür.
  static double footerGap({
    required double width,
    required double contentHeight,
    required double footerHeight,
    required double viewportHeight,
    double trailingPadding = 0,
  }) {
    if (!viewportHeight.isFinite || viewportHeight <= 0) {
      return footerLongSpacingForWidth(width);
    }
    if (contentHeight > viewportHeight) {
      return footerLongSpacingForWidth(width);
    }
    final short = footerShortClearanceForWidth(width);
    if (footerHeight <= 0) return short;
    final footerBlock = footerHeight + trailingPadding;
    final minExtent = viewportHeight + footerShortOverflow;
    final extent = contentHeight + short + footerBlock;
    if (extent >= minExtent) return short;
    final grown = minExtent - contentHeight - footerBlock;
    return grown > short ? grown : short;
  }
}
