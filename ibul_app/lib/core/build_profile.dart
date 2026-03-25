class BuildProfileCollector {
  BuildProfileCollector._();

  static bool enabled = false;

  static final Map<String, _BuildProfileSummary> _summaries = {};

  static T measure<T>(String widgetName, T Function() builder) {
    if (!enabled) {
      return builder();
    }

    final stopwatch = Stopwatch()..start();
    final result = builder();
    stopwatch.stop();

    _summaries
        .putIfAbsent(widgetName, () => _BuildProfileSummary(widgetName))
        .add(stopwatch.elapsedMicroseconds / 1000.0);
    return result;
  }

  static void reset() {
    _summaries.clear();
  }

  static Map<String, dynamic> snapshot({double frameBudgetMs = 16.0}) {
    final summaries = _summaries.values.toList()
      ..sort((a, b) => b.totalBuildMs.compareTo(a.totalBuildMs));

    final overBudget =
        summaries
            .where((summary) => summary.maxBuildMs > frameBudgetMs)
            .toList()
          ..sort((a, b) => b.maxBuildMs.compareTo(a.maxBuildMs));

    return <String, dynamic>{
      'frame_budget_ms': frameBudgetMs,
      'widgets_over_budget': overBudget
          .map((summary) => summary.toJson())
          .toList(growable: false),
      'top_widgets_by_total_build_ms': summaries
          .take(10)
          .map((summary) => summary.toJson())
          .toList(growable: false),
    };
  }
}

class _BuildProfileSummary {
  _BuildProfileSummary(this.widgetName);

  final String widgetName;
  double maxBuildMs = 0;
  double totalBuildMs = 0;
  int buildCount = 0;

  void add(double buildMs) {
    buildCount++;
    totalBuildMs += buildMs;
    if (buildMs > maxBuildMs) {
      maxBuildMs = buildMs;
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'widget': widgetName,
      'max_build_ms': double.parse(maxBuildMs.toStringAsFixed(3)),
      'total_build_ms': double.parse(totalBuildMs.toStringAsFixed(3)),
      'build_count': buildCount,
    };
  }
}
