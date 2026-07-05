import 'package:flutter/material.dart';

import '../core/home_data_diagnostics.dart';
import 'home_screen.dart' deferred as legacy_home;
import 'home_screen_core.dart';
import 'web_home_boot_shell.dart';

/// Stable deferred entry — desktop web uses lean core; mobile uses legacy [HomeScreen].
Widget buildDeferredHomeScreen({
  int initialIndex = 0,
  String? initialCategory,
}) {
  return ResponsiveHomeScreen(
    initialIndex: initialIndex,
    initialCategory: initialCategory,
  );
}

/// Routes home by viewport: desktop web → [HomeScreenCore], mobile → legacy [HomeScreen].
class ResponsiveHomeScreen extends StatefulWidget {
  const ResponsiveHomeScreen({
    super.key,
    this.initialIndex = 0,
    this.initialCategory,
  });

  final int initialIndex;
  final String? initialCategory;

  static const double desktopBreakpoint = 1100;

  @override
  State<ResponsiveHomeScreen> createState() => _ResponsiveHomeScreenState();
}

class _ResponsiveHomeScreenState extends State<ResponsiveHomeScreen> {
  Future<void>? _legacyLibraryFuture;

  bool _isDesktopWeb(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= ResponsiveHomeScreen.desktopBreakpoint;
  }

  Future<void> _ensureLegacyLibrary() {
    return _legacyLibraryFuture ??= legacy_home.loadLibrary();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = _isDesktopWeb(context);

    HomeLayoutDiagnostics.log(
      platform: 'web',
      width: width,
      mode: isDesktop ? 'desktop_web' : 'mobile_web',
      widget: isDesktop ? 'HomeScreenCore' : 'HomeScreen',
      mobileDesignActive: !isDesktop,
      legacyDemoSectionDisabled: true,
    );

    if (isDesktop) {
      return HomeScreenCore(
        initialIndex: widget.initialIndex,
        initialCategory: widget.initialCategory,
      );
    }

    return FutureBuilder<void>(
      future: _ensureLegacyLibrary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const WebHomeShell();
        }
        if (snapshot.hasError) {
          HomeLayoutDiagnostics.log(
            platform: 'web',
            width: width,
            mode: 'mobile_web_fallback',
            widget: 'HomeScreenCore',
            mobileDesignActive: false,
          );
          return HomeScreenCore(
            initialIndex: widget.initialIndex,
            initialCategory: widget.initialCategory,
          );
        }
        return legacy_home.HomeScreen(
          initialIndex: widget.initialIndex,
          initialCategory: widget.initialCategory,
        );
      },
    );
  }
}
