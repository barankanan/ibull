import 'package:flutter/material.dart';

import '../features/visual_search/domain/visual_search_models.dart';
import '../features/visual_search/presentation/visual_search_capture_page.dart';

class VisualSearchSelectionPage extends StatelessWidget {
  const VisualSearchSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VisualSearchCapturePage(jobType: VisualSearchJobType.combined);
  }
}
