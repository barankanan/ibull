import '../domain/visual_search_analyzer.dart';
import '../domain/visual_search_models.dart';
import 'visual_search_supabase.dart';

/// Calls the `visual-search-analyze` edge function. Throws when the function
/// is not deployed so [FallbackVisualSearchAnalyzer] can use the mock.
class EdgeVisualSearchAnalyzer implements VisualSearchAnalyzer {
  const EdgeVisualSearchAnalyzer();

  @override
  Future<VisualSearchAnalysis> analyze({
    required VisualSearchJobType jobType,
    required String fileName,
    required List<int> imageBytes,
    List<VisualCatalogItem> catalog = const [],
  }) async {
    final client = VisualSearchSupabase.clientOrNull();
    if (client == null) throw const VisualSearchRemoteUnavailable();
    final response = await client.functions
        .invoke(
          'visual-search-analyze',
          body: {
            'job_type': jobType.wireName,
            'file_name': fileName,
            'catalog': [
              for (final item in catalog)
                {'id': item.id, 'name': item.name, 'brand': item.brand},
            ],
          },
        )
        .timeout(const Duration(seconds: 8));
    final data = response.data;
    if (data is! Map) {
      throw const VisualSearchException(
        VisualSearchErrorCode.analysisFailed,
        'Analiz servisi yanıt vermedi.',
      );
    }
    return VisualSearchAnalysis.fromJson(Map<String, dynamic>.from(data));
  }
}
