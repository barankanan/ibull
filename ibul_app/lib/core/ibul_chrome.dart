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
}
