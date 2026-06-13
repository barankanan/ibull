import 'dart:math' as math;

import 'package:flutter/material.dart';

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

/// Web sayfalarında içerik kısa olsa bile footer'ı viewport altına sabitler.
///
/// İçerik uzadığında normal scroll davranışı korunur. Kısa/boş durumlarda body
/// alanı viewport yüksekliğini doldurur; içerik bu alan içinde dengeli konumlanır,
/// footer en altta kalır.
class WebStickyFooterScrollView extends StatefulWidget {
  const WebStickyFooterScrollView({
    super.key,
    required this.child,
    this.contentFooterGap = 32,
    this.footerBottomPadding = 0,
    this.physics,
    this.showFooter = true,
    this.contentAlignment = const Alignment(0, -0.1),
  });

  final Widget child;
  final double contentFooterGap;
  final double footerBottomPadding;
  final ScrollPhysics? physics;
  final bool showFooter;

  /// Kısa içerikte body içindeki dikey hizalama. Header'a saygılı, hafif yukarı
  /// bias için varsayılan `(0, -0.1)`.
  final Alignment contentAlignment;

  @override
  State<WebStickyFooterScrollView> createState() =>
      _WebStickyFooterScrollViewState();
}

class _WebStickyFooterScrollViewState extends State<WebStickyFooterScrollView> {
  /// Gap + footer tahmini; ilk frame'den sonra slot ölçümü ile güncellenir.
  static const double _initialFooterSlotHeight = 312;

  final GlobalKey _footerSlotKey = GlobalKey();
  double _footerSlotHeight = _initialFooterSlotHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureFooterSlot());
  }

  void _measureFooterSlot() {
    if (!mounted || !widget.showFooter) return;
    final context = _footerSlotKey.currentContext;
    if (context == null) return;
    final height = context.size?.height;
    if (height == null) return;
    if ((height - _footerSlotHeight).abs() > 1) {
      setState(() => _footerSlotHeight = height);
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureFooterSlot());
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final footerReserve =
            widget.showFooter ? _footerSlotHeight : 0.0;
        final bodyMinHeight = math.max(
          0.0,
          constraints.maxHeight - footerReserve,
        );

        return SingleChildScrollView(
          physics: widget.physics,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: bodyMinHeight),
                  child: WebStickyFooterBodyScope(
                    bodyMinHeight: bodyMinHeight,
                    child: Align(
                      alignment: widget.contentAlignment,
                      child: widget.child,
                    ),
                  ),
                ),
                if (widget.showFooter)
                  _FooterSlot(
                    slotKey: _footerSlotKey,
                    contentFooterGap: widget.contentFooterGap,
                    footerBottomPadding: widget.footerBottomPadding,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FooterSlot extends StatelessWidget {
  const _FooterSlot({
    required this.slotKey,
    required this.contentFooterGap,
    required this.footerBottomPadding,
  });

  final GlobalKey slotKey;
  final double contentFooterGap;
  final double footerBottomPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: slotKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: contentFooterGap),
        const WebFooter(),
        if (footerBottomPadding > 0) SizedBox(height: footerBottomPadding),
      ],
    );
  }
}
