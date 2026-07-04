/// Bölüm yükleme fazları — erken hata gösterimini engellemek için grace period.
enum SectionLoadPhase {
  initial,
  loading,
  loaded,
  empty,
  error,
  refreshing,
}

class SectionLoadState {
  const SectionLoadState({
    this.phase = SectionLoadPhase.initial,
    this.startedAt,
    this.errorMessage,
    this.gracePeriod = const Duration(milliseconds: 1800),
  });

  final SectionLoadPhase phase;
  final DateTime? startedAt;
  final String? errorMessage;
  final Duration gracePeriod;

  bool get isLoading =>
      phase == SectionLoadPhase.initial ||
      phase == SectionLoadPhase.loading ||
      phase == SectionLoadPhase.refreshing;

  bool get isWithinGracePeriod {
    final started = startedAt;
    if (started == null) return true;
    return DateTime.now().difference(started) < gracePeriod;
  }

  bool get shouldShowError =>
      phase == SectionLoadPhase.error &&
      !isWithinGracePeriod &&
      (errorMessage?.trim().isNotEmpty ?? false);

  bool get shouldShowEmpty =>
      phase == SectionLoadPhase.empty && !isLoading;

  SectionLoadState copyWith({
    SectionLoadPhase? phase,
    DateTime? startedAt,
    String? errorMessage,
    Duration? gracePeriod,
  }) {
    return SectionLoadState(
      phase: phase ?? this.phase,
      startedAt: startedAt ?? this.startedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      gracePeriod: gracePeriod ?? this.gracePeriod,
    );
  }

  static SectionLoadState beginLoading({SectionLoadPhase phase = SectionLoadPhase.loading}) {
    return SectionLoadState(
      phase: phase,
      startedAt: DateTime.now(),
    );
  }

  String get logStateLabel {
    switch (phase) {
      case SectionLoadPhase.initial:
      case SectionLoadPhase.loading:
      case SectionLoadPhase.refreshing:
        return 'loading';
      case SectionLoadPhase.loaded:
        return 'hasData';
      case SectionLoadPhase.empty:
        return 'empty';
      case SectionLoadPhase.error:
        return 'error';
    }
  }
}

/// Popüler Ürünler rail skeleton yalnızca ürün yokken gösterilir.
bool shouldShowPopularProductsSkeleton({
  required bool isLoading,
  required int productCount,
}) {
  return isLoading && productCount == 0;
}

/// Sana Özel Ürünler rail skeleton yalnızca ürün yokken gösterilir.
bool shouldShowPersonalizedProductsSkeleton({
  required bool isLoading,
  required int productCount,
}) {
  return isLoading && productCount == 0;
}
