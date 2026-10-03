import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/ibul_chrome.dart';
import 'web_footer.dart';

/// Web sticky footer body slot yüksekliğini alt widget'lara iletir.
class WebStickyFooterBodyScope extends InheritedWidget {
  const WebStickyFooterBodyScope({
    super.key,
    required this.bodyMinHeight,
    required super.child,
  });

  final double bodyMinHeight;

  static WebStickyFooterBodyScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<WebStickyFooterBodyScope>();
  }

  @override
  bool updateShouldNotify(WebStickyFooterBodyScope oldWidget) {
    return oldWidget.bodyMinHeight != bodyMinHeight;
  }
}

/// Web sayfalarında footer'dan önce ortak nefes alanı bırakır.
///
/// Kısa içerikte footer viewport dibine yapışmaz; clearance kadar boşluk
/// sonrası gelir ve bir kısmı ilk ekranın altında kalabilir. Uzun içerikte
/// yalnız normal aralık kullanılır.
class WebStickyFooterScrollView extends StatefulWidget {
  const WebStickyFooterScrollView({
    super.key,
    required this.child,
    this.footerBottomPadding = 0,
    this.physics,
    this.showFooter = true,
  });

  final Widget child;
  final double footerBottomPadding;
  final ScrollPhysics? physics;
  final bool showFooter;

  @override
  State<WebStickyFooterScrollView> createState() =>
      _WebStickyFooterScrollViewState();
}

class _WebStickyFooterScrollViewState extends State<WebStickyFooterScrollView> {
  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _footerKey = GlobalKey();
  double _contentHeight = 0;
  double _footerHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final content = _contentKey.currentContext?.size?.height;
    final footer = widget.showFooter
        ? _footerKey.currentContext?.size?.height
        : 0.0;
    var changed = false;
    if (content != null && (content - _contentHeight).abs() > 1) {
      _contentHeight = content;
      changed = true;
    }
    if (footer != null && (footer - _footerHeight).abs() > 1) {
      _footerHeight = footer;
      changed = true;
    }
    if (changed) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxHeight;
        final gap = widget.showFooter
            ? IbulChrome.footerGap(
                width: constraints.maxWidth,
                contentHeight: _contentHeight,
                footerHeight: _footerHeight,
                viewportHeight: viewport,
                trailingPadding: widget.footerBottomPadding,
              )
            : 0.0;

        return SingleChildScrollView(
          physics: widget.physics,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              WebStickyFooterBodyScope(
                bodyMinHeight: _contentHeight,
                child: KeyedSubtree(
                  key: _contentKey,
                  child: widget.child,
                ),
              ),
              if (widget.showFooter) ...[
                SizedBox(height: gap),
                KeyedSubtree(
                  key: _footerKey,
                  child: const WebFooter(),
                ),
                if (widget.footerBottomPadding > 0)
                  SizedBox(height: widget.footerBottomPadding),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Header + ana içerik + clearance + [WebFooter].
///
/// Footer viewport dibine kilitlenmez. Kısa sayfada footer'dan önce ortak
/// boşluk vardır; uzun sayfada normal aralık yeterlidir.
class MarketplaceWebPageShell extends StatelessWidget {
  const MarketplaceWebPageShell({
    super.key,
    required this.header,
    required this.child,
    this.backgroundColor,
    this.showFooter = true,
  });

  final Widget header;
  final Widget child;
  final Color? backgroundColor;
  final bool showFooter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: WebStickyFooterScrollView(
              showFooter: showFooter,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// [CustomScrollView] sonu. [WebStickyFooterScrollView] ile aynı clearance.
class WebStickyFooterEndSliver extends StatefulWidget {
  const WebStickyFooterEndSliver({super.key});

  @override
  State<WebStickyFooterEndSliver> createState() =>
      _WebStickyFooterEndSliverState();
}

class _WebStickyFooterEndSliverState extends State<WebStickyFooterEndSliver> {
  final GlobalKey _footerKey = GlobalKey();
  double _footerHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final height = _footerKey.currentContext?.size?.height;
    if (height == null) return;
    if ((height - _footerHeight).abs() > 1) {
      setState(() => _footerHeight = height);
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final gap = IbulChrome.footerGap(
          width: constraints.crossAxisExtent,
          contentHeight: constraints.precedingScrollExtent,
          footerHeight: _footerHeight,
          viewportHeight: constraints.viewportMainAxisExtent,
        );
        return SliverToBoxAdapter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: gap),
              KeyedSubtree(
                key: _footerKey,
                child: const WebFooter(),
              ),
            ],
          ),
        );
      },
    );
  }
}
