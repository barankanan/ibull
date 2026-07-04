import 'package:flutter/foundation.dart';

/// Debug-only uygulama performans logları.
class AppPerfLogger {
  AppPerfLogger._();

  static void logHomeBoot({
    required int startMs,
    int? firstFrameMs,
    int? routeReadyMs,
    bool cachedSnapshotUsed = false,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[HomePerf][boot] '
      'startMs=$startMs '
      'firstFrameMs=${firstFrameMs ?? '-'} '
      'routeReadyMs=${routeReadyMs ?? '-'} '
      'cachedSnapshotUsed=$cachedSnapshotUsed',
    );
  }

  static void logHomeFetch({
    int? categoriesMs,
    int? heroAdsMs,
    int? sponsoredListsMs,
    int? storeStoriesMs,
    int? productSectionsMs,
    int? totalMs,
    bool parallel = false,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[HomePerf][fetch] '
      'categoriesMs=${categoriesMs ?? '-'} '
      'heroAdsMs=${heroAdsMs ?? '-'} '
      'sponsoredListsMs=${sponsoredListsMs ?? '-'} '
      'storeStoriesMs=${storeStoriesMs ?? '-'} '
      'productSectionsMs=${productSectionsMs ?? '-'} '
      'totalMs=${totalMs ?? '-'} '
      'parallel=$parallel',
    );
  }

  static void logHomeImages({
    int? heroPrecacheMs,
    int? visibleProductImagesPrecacheMs,
    int failedImageCount = 0,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[HomePerf][images] '
      'heroPrecacheMs=${heroPrecacheMs ?? '-'} '
      'visibleProductImagesPrecacheMs=${visibleProductImagesPrecacheMs ?? '-'} '
      'failedImageCount=$failedImageCount',
    );
  }

  static void logHomeSection({
    required String sectionName,
    required String source,
    String state = 'loading',
    int itemCount = 0,
    int? ms,
    String? error,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[HomePerf][section] '
      'sectionName=$sectionName '
      'state=$state '
      'source=$source '
      'itemCount=$itemCount '
      'ms=${ms ?? '-'} '
      'error=${error ?? '-'}',
    );
  }

  static void logHomePopular({
    required String stage,
    required String source,
    String state = 'loading',
    int cachedItemCount = 0,
    int networkItemCount = 0,
    int? cacheMs,
    int? networkMs,
    int? firstPaintMs,
    int? imagePrecacheMs,
    int? totalMs,
    String? error,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[HomePerf][popular] '
      'stage=$stage '
      'source=$source '
      'state=$state '
      'cachedItemCount=$cachedItemCount '
      'networkItemCount=$networkItemCount '
      'cacheMs=${cacheMs ?? '-'} '
      'networkMs=${networkMs ?? '-'} '
      'firstPaintMs=${firstPaintMs ?? '-'} '
      'imagePrecacheMs=${imagePrecacheMs ?? '-'} '
      'totalMs=${totalMs ?? '-'} '
      'error=${error ?? '-'}',
    );
  }

  static void logHomePersonalized({
    required String source,
    String state = 'loading',
    int itemCount = 0,
    int? cacheMs,
    int? networkMs,
    int? firstPaintMs,
    int? totalMs,
    String? error,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[HomePerf][personalized] '
      'source=$source '
      'state=$state '
      'itemCount=$itemCount '
      'cacheMs=${cacheMs ?? '-'} '
      'networkMs=${networkMs ?? '-'} '
      'firstPaintMs=${firstPaintMs ?? '-'} '
      'totalMs=${totalMs ?? '-'} '
      'error=${error ?? '-'}',
    );
  }
}
