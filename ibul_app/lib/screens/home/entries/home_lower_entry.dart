import 'package:flutter/material.dart';

import '../../../widgets/web_footer.dart';
import '../sections/ibul_trust_bar_section.dart';

class HomeLowerBlock extends StatelessWidget {
  const HomeLowerBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IbulTrustBarSection(),
        WebFooter(),
      ],
    );
  }
}
