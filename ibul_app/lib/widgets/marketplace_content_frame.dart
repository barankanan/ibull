import 'package:flutter/material.dart';

import '../core/ibul_chrome.dart';

/// Shared horizontal bounds for marketplace chrome and home sections.
class MarketplaceContentFrame extends StatelessWidget {
  const MarketplaceContentFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: IbulChrome.contentConstraints,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width >= 700 ? 24 : 16,
          ),
          child: child,
        ),
      ),
    );
  }
}
