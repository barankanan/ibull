import 'package:flutter/material.dart';

import '../core/home_data_diagnostics.dart';
import '../core/ibul_chrome.dart';
import 'home_screen_core.dart';

/// Stable deferred entry — web and mobile both use lean [HomeScreenCore].
Widget buildDeferredHomeScreen({
  int initialIndex = 0,
  String? initialCategory,
}) {
  return ResponsiveHomeScreen(
    initialIndex: initialIndex,
    initialCategory: initialCategory,
  );
}

class ResponsiveHomeScreen extends StatelessWidget {
  const ResponsiveHomeScreen({
    super.key,
    this.initialIndex = 0,
    this.initialCategory,
  });

  final int initialIndex;
  final String? initialCategory;

  static const double desktopBreakpoint = IbulChrome.web;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= desktopBreakpoint;

    HomeLayoutDiagnostics.log(
      platform: 'web',
      width: width,
      mode: isDesktop ? 'desktop_web' : 'mobile_web',
      widget: 'HomeScreenCore',
      mobileDesignActive: !isDesktop,
      legacyDemoSectionDisabled: true,
    );

    return HomeScreenCore(
      initialIndex: initialIndex,
      initialCategory: initialCategory,
    );
  }
}
