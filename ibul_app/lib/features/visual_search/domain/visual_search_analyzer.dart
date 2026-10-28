import 'visual_search_models.dart';

/// Analysis contract. Swap [MockVisualSearchAnalyzer] with a remote
/// implementation without changing the UI or repository.
abstract class VisualSearchAnalyzer {
  Future<VisualSearchAnalysis> analyze({
    required VisualSearchJobType jobType,
    required String fileName,
    required List<int> imageBytes,
    List<VisualCatalogItem> catalog = const [],
  });
}

class FallbackVisualSearchAnalyzer implements VisualSearchAnalyzer {
  const FallbackVisualSearchAnalyzer({
    required this.primary,
    required this.fallback,
  });

  final VisualSearchAnalyzer primary;
  final VisualSearchAnalyzer fallback;

  @override
  Future<VisualSearchAnalysis> analyze({
    required VisualSearchJobType jobType,
    required String fileName,
    required List<int> imageBytes,
    List<VisualCatalogItem> catalog = const [],
  }) async {
    try {
      return await primary.analyze(
        jobType: jobType,
        fileName: fileName,
        imageBytes: imageBytes,
        catalog: catalog,
      );
    } catch (_) {
      final result = await fallback.analyze(
        jobType: jobType,
        fileName: fileName,
        imageBytes: imageBytes,
        catalog: catalog,
      );
      return result.copyWith(usedMock: true);
    }
  }
}
