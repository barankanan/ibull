import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';

/// Pushes [footer] to the viewport bottom when [body] is short, and
/// still scrolls as one page when content is taller than the screen.
class IhizStickyFooterScroll extends StatelessWidget {
  const IhizStickyFooterScroll({
    super.key,
    required this.body,
    required this.footer,
    this.controller,
    this.scrollViewKey,
  });

  final Widget body;
  final Widget footer;
  final ScrollController? controller;
  final Key? scrollViewKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          key: scrollViewKey,
          controller: controller,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                body,
                footer,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// İHIZ site chrome: header + content + İHIZ footer.
class IhizShell extends StatelessWidget {
  const IhizShell({
    super.key,
    required this.header,
    required this.body,
    required this.footer,
    this.controller,
  });

  final Widget header;
  final Widget body;
  final Widget footer;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IhizBrand.surface,
      body: SafeArea(
        child: Column(
          children: [
            header,
            Expanded(
              child: IhizStickyFooterScroll(
                scrollViewKey: const ValueKey('ihiz-shell-scroll'),
                controller: controller,
                body: body,
                footer: footer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
