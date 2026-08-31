import 'package:flutter/material.dart';

import 'ihiz_courier_page.dart';

/// Account / leftover entry — the live İHIZ product is the landing, not the
/// old “yakında” card stack.
class IhizHomePage extends StatelessWidget {
  const IhizHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const IhizCourierPage();
  }
}
