import 'package:flutter/material.dart';

import 'domain/visual_search_models.dart';
import 'navigation/visual_search_paths.dart';
import 'presentation/visual_search_capture_page.dart';
import 'presentation/visual_search_history_page.dart';
import 'presentation/visual_search_hub_page.dart';
import 'presentation/visual_search_result_pages.dart';

export 'domain/visual_search_models.dart' show VisualSearchJobType;
export 'presentation/visual_search_capture_page.dart';
export 'presentation/visual_search_hub_page.dart';

Widget? visualSearchPageForPath(String path) {
  if (path == VisualSearchPaths.root) return const VisualSearchHubPage();
  if (path == VisualSearchPaths.analyze) {
    return const VisualSearchCapturePage(jobType: VisualSearchJobType.combined);
  }
  if (path == VisualSearchPaths.match) {
    return const VisualSearchCapturePage(jobType: VisualSearchJobType.visualSearch);
  }
  if (path == VisualSearchPaths.history) return const VisualSearchHistoryPage();
  final historyId = VisualSearchPaths.idFrom(path, VisualSearchPaths.history);
  if (historyId != null) {
    return VisualSearchHistoryDetailPage(jobId: historyId);
  }
  final analysisId = VisualSearchPaths.idFrom(path, VisualSearchPaths.analyze);
  if (analysisId != null) {
    return VisualSearchHistoryDetailPage(jobId: analysisId);
  }
  final matchId = VisualSearchPaths.idFrom(path, VisualSearchPaths.match);
  if (matchId != null) {
    return VisualSearchHistoryDetailPage(jobId: matchId);
  }
  return null;
}
