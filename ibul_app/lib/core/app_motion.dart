import 'package:flutter/material.dart';

enum AppRouteTransitionStyle { standard, hero }

class AppMotion {
  static const Duration fastInteractionDuration = Duration(milliseconds: 140);
  static const Duration fastInteractionReverseDuration = Duration(
    milliseconds: 110,
  );
  static const Duration normalTransitionDuration = Duration(milliseconds: 220);
  static const Duration normalTransitionReverseDuration = Duration(
    milliseconds: 180,
  );
  static const Duration modalTransitionDuration = Duration(milliseconds: 240);
  static const Duration modalTransitionReverseDuration = Duration(
    milliseconds: 180,
  );
  static const Duration imageFadeInDuration = Duration(milliseconds: 140);
  static const Duration imageFadeOutDuration = Duration(milliseconds: 70);
  // Reveal-specific: slightly shorter than normal to reduce first-raster load.
  static const Duration revealTransitionDuration = Duration(milliseconds: 190);

  static const Curve tapFeedbackCurve = Curves.easeOutCubic;
  static const Curve tapFeedbackReverseCurve = Curves.easeInCubic;
  static const Curve pageTransitionCurve = Curves.easeOutCubic;
  static const Curve pageTransitionReverseCurve = Curves.easeInCubic;
  static const Curve fadeInCurve = Curves.easeOutCubic;
  static const Curve revealCurve = Curves.easeOutCubic;
  static const Curve revealReverseCurve = Curves.easeInCubic;

  static const Duration routeDuration = normalTransitionDuration;
  static const Duration routeReverseDuration = normalTransitionReverseDuration;
  static const Duration surfaceDuration = normalTransitionDuration;
  static const Duration surfaceReverseDuration =
      normalTransitionReverseDuration;
  static const Curve emphasizedCurve = pageTransitionCurve;
  static const Curve emphasizedReverseCurve = pageTransitionReverseCurve;
  static const Curve standardCurve = revealCurve;

  static const AnimationStyle dialogAnimationStyle = AnimationStyle(
    duration: modalTransitionDuration,
    reverseDuration: modalTransitionReverseDuration,
    curve: revealCurve,
    reverseCurve: revealReverseCurve,
  );

  static const AnimationStyle sheetAnimationStyle = AnimationStyle(
    duration: modalTransitionDuration,
    reverseDuration: modalTransitionReverseDuration,
    curve: revealCurve,
    reverseCurve: revealReverseCurve,
  );

  static PageTransitionsTheme pageTransitionsTheme() {
    const builder = _AppPageTransitionsBuilder();
    return const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: builder,
        TargetPlatform.iOS: builder,
        TargetPlatform.macOS: builder,
        TargetPlatform.windows: builder,
        TargetPlatform.linux: builder,
      },
    );
  }

  static Widget buildFadeSlideTransition(
    Animation<double> animation,
    Widget child, {
    Offset begin = const Offset(0, 0.018),
  }) {
    final fadeAnimation = CurvedAnimation(
      parent: animation,
      curve: fadeInCurve,
      reverseCurve: pageTransitionReverseCurve,
    );
    final slideAnimation = CurvedAnimation(
      parent: animation,
      curve: pageTransitionCurve,
      reverseCurve: pageTransitionReverseCurve,
    );
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: begin,
          end: Offset.zero,
        ).animate(slideAnimation),
        child: child,
      ),
    );
  }

  static Widget buildFadeScaleTransition(
    Animation<double> animation,
    Widget child, {
    double beginScale = 0.985,
  }) {
    final fadeAnimation = CurvedAnimation(
      parent: animation,
      curve: fadeInCurve,
      reverseCurve: pageTransitionReverseCurve,
    );
    final scaleAnimation = CurvedAnimation(
      parent: animation,
      curve: pageTransitionCurve,
      reverseCurve: pageTransitionReverseCurve,
    );
    return FadeTransition(
      opacity: fadeAnimation,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: beginScale,
          end: 1,
        ).animate(scaleAnimation),
        child: child,
      ),
    );
  }
}

Route<T> buildAppPageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool fullscreenDialog = false,
  AppRouteTransitionStyle transitionStyle = AppRouteTransitionStyle.standard,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      switch (transitionStyle) {
        case AppRouteTransitionStyle.standard:
          return AppMotion.buildFadeSlideTransition(animation, child);
        case AppRouteTransitionStyle.hero:
          return AppMotion.buildFadeScaleTransition(animation, child);
      }
    },
    transitionDuration: AppMotion.routeDuration,
    reverseTransitionDuration: AppMotion.routeReverseDuration,
  );
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useRootNavigator = true,
  bool useSafeArea = true,
  RouteSettings? routeSettings,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    useSafeArea: useSafeArea,
    routeSettings: routeSettings,
    animationStyle: AppMotion.dialogAnimationStyle,
    builder: builder,
  );
}

Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  ShapeBorder? shape,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  bool useSafeArea = false,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: backgroundColor,
    shape: shape,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    useSafeArea: useSafeArea,
    clipBehavior: clipBehavior,
    constraints: constraints,
    barrierColor: barrierColor,
    sheetAnimationStyle: AppMotion.sheetAnimationStyle,
    builder: builder,
  );
}

class AppAnimatedIndexedStack extends StatelessWidget {
  const AppAnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    final safeIndex = index.clamp(0, children.length - 1);
    // IndexedStack only paints the active child. A Stack + AnimatedOpacity
    // kept every tab in the paint tree, which caused visible overlap on web
    // (e.g. account guest card under another tab's footer layer).
    return IndexedStack(
      index: safeIndex,
      sizing: StackFit.expand,
      children: List<Widget>.generate(children.length, (childIndex) {
        final isActive = childIndex == safeIndex;
        return RepaintBoundary(
          child: KeyedSubtree(
            key: ValueKey<int>(childIndex),
            child: TickerMode(
              enabled: isActive,
              child: children[childIndex],
            ),
          ),
        );
      }),
    );
  }
}

class _AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const _AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.settings.name == null && route.fullscreenDialog) {
      return AppMotion.buildFadeSlideTransition(
        animation,
        child,
        begin: const Offset(0, 0.026),
      );
    }

    return AppMotion.buildFadeSlideTransition(animation, child);
  }
}
