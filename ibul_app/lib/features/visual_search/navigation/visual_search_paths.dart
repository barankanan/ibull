abstract final class VisualSearchPaths {
  static const root = '/visual-search';
  static const analyze = '/visual-search/analyze';
  static const match = '/visual-search/match';
  static const history = '/visual-search/history';

  static String historyDetail(String id) => '/visual-search/history/$id';

  static String analysisResult(String id) => '/visual-search/analyze/$id';

  static String matchResult(String id) => '/visual-search/match/$id';

  static bool matches(String path) =>
      path == root || path.startsWith('$root/');

  static String? idFrom(String path, String prefix) {
    if (!path.startsWith('$prefix/')) return null;
    final id = path.substring(prefix.length + 1);
    if (id.isEmpty || id.contains('/')) return null;
    return id;
  }
}
