import 'package:flutter/material.dart';
import 'breakpoints.dart';

/// Responsive Layout Widget
/// 
/// Farklı screen boyutlarına göre farklı layoutlar gösterir.
/// 
/// Örnek:
/// ```dart
/// ResponsiveLayout(
///   mobile: MobileHomePage(),
///   tablet: TabletHomePage(),
///   desktop: DesktopHomePage(),
/// )
/// ```

class ResponsiveLayout extends StatefulWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  State<ResponsiveLayout> createState() => _ResponsiveLayoutState();
}

class _ResponsiveLayoutState extends State<ResponsiveLayout> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width <= ScreenBreakpoints.mobile) {
      return widget.mobile;
    } else if (width <= ScreenBreakpoints.tablet) {
      return widget.tablet ?? widget.mobile;
    } else {
      return widget.desktop;
    }
  }
}

/// Responsive Builder - Dinamik olarak widget oluşturmak için
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize screenSize) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final screenSize = width.screenSize;

    return builder(context, screenSize);
  }
}

/// Responsive Grid Widget - Otomatik column sayısı ayarlayan grid
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final double runSpacing;

  const ResponsiveGridView({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.spacing = 16.0,
    this.runSpacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final screenSize = width.screenSize;

    int crossAxisCount;
    switch (screenSize) {
      case ScreenSize.mobile:
        crossAxisCount = ScreenBreakpoints.mobileColumns;
        break;
      case ScreenSize.tablet:
        crossAxisCount = ScreenBreakpoints.tabletColumns;
        break;
      case ScreenSize.desktop:
      case ScreenSize.ultraWide:
        crossAxisCount = ScreenBreakpoints.desktopColumns;
        break;
    }

    return Padding(
      padding: padding,
      child: GridView.count(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: runSpacing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}

/// Responsive Padding Helper
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? mobilePadding;
  final EdgeInsetsGeometry? tabletPadding;
  final EdgeInsetsGeometry? desktopPadding;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.mobilePadding,
    this.tabletPadding,
    this.desktopPadding,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final screenSize = width.screenSize;

    EdgeInsetsGeometry padding = mobilePadding ??
        const EdgeInsets.symmetric(
          horizontal: ScreenBreakpoints.mobileHorizontalPadding,
          vertical: ScreenBreakpoints.mobileVerticalPadding,
        );

    switch (screenSize) {
      case ScreenSize.mobile:
        padding = mobilePadding ??
            const EdgeInsets.symmetric(
              horizontal: ScreenBreakpoints.mobileHorizontalPadding,
              vertical: ScreenBreakpoints.mobileVerticalPadding,
            );
        break;
      case ScreenSize.tablet:
        padding = tabletPadding ??
            const EdgeInsets.symmetric(
              horizontal: ScreenBreakpoints.tabletHorizontalPadding,
              vertical: ScreenBreakpoints.tabletVerticalPadding,
            );
        break;
      case ScreenSize.desktop:
      case ScreenSize.ultraWide:
        padding = desktopPadding ??
            const EdgeInsets.symmetric(
              horizontal: ScreenBreakpoints.desktopHorizontalPadding,
              vertical: ScreenBreakpoints.desktopVerticalPadding,
            );
        break;
    }

    return Padding(
      padding: padding,
      child: child,
    );
  }
}

/// Conditional Widget gösterme
class ShowOnScreenSize extends StatelessWidget {
  final Widget? mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? child; // Tüm screen size'larda göster

  const ShowOnScreenSize({
    super.key,
    this.mobile,
    this.tablet,
    this.desktop,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final screenSize = width.screenSize;

    switch (screenSize) {
      case ScreenSize.mobile:
        return mobile ?? child ?? const SizedBox.shrink();
      case ScreenSize.tablet:
        return tablet ?? child ?? const SizedBox.shrink();
      case ScreenSize.desktop:
      case ScreenSize.ultraWide:
        return desktop ?? child ?? const SizedBox.shrink();
    }
  }
}
