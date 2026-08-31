import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';
import 'ihiz_shell.dart';

/// Inner IHIZ screens keep header + footer chrome without marketplace UI.
class IhizSubpageScaffold extends StatelessWidget {
  const IhizSubpageScaffold({
    super.key,
    required this.header,
    required this.body,
    required this.footer,
  });

  final Widget header;
  final Widget body;
  final Widget footer;

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
