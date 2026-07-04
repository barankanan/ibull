import 'package:flutter/foundation.dart';

import 'web_perf_logger.dart';

/// Debug-only ana sayfa yükleme metrikleri.
class HomeLoadAudit {
  HomeLoadAudit._();

  static int criticalQueryCount = 0;
  static int deferredQueryCount = 0;
  static int sponsoredContentQueryCount = 0;
  static int storeLogoQueryCount = 0;
  static int uniqueStoreIdCount = 0;
  static int approxImageRequestCount = 0;
  static bool usesAdminCampaignQuery = false;

  static void reset() {
    criticalQueryCount = 0;
    deferredQueryCount = 0;
    sponsoredContentQueryCount = 0;
    storeLogoQueryCount = 0;
    uniqueStoreIdCount = 0;
    approxImageRequestCount = 0;
    usesAdminCampaignQuery = false;
  }

  static void recordCritical([int count = 1]) {
    criticalQueryCount += count;
    WebPerfLogger.recordSupabaseInitialRequest(count);
  }

  static void recordDeferred([int count = 1]) {
    deferredQueryCount += count;
  }

  static void recordSponsoredContent([int count = 1]) {
    if (!kDebugMode) return;
    sponsoredContentQueryCount += count;
  }

  static void recordStoreLogoBatch({
    required int uniqueStoreIds,
    int queryCount = 1,
  }) {
    if (!kDebugMode) return;
    storeLogoQueryCount += queryCount;
    uniqueStoreIdCount += uniqueStoreIds;
  }

  static void recordApproxImages(int count) {
    if (!kDebugMode) return;
    approxImageRequestCount += count;
  }

  static void markAdminCampaignQueryUsed() {
    if (!kDebugMode) return;
    usesAdminCampaignQuery = true;
  }

  static void logSummary() {
    if (!kDebugMode) return;
    debugPrint(
      'HOME_LOAD_AUDIT '
      'critical=$criticalQueryCount '
      'deferred=$deferredQueryCount '
      'sponsored=$sponsoredContentQueryCount '
      'store_logo_queries=$storeLogoQueryCount '
      'unique_store_ids=$uniqueStoreIdCount '
      'approx_images=$approxImageRequestCount '
      'uses_admin_campaign_query=${usesAdminCampaignQuery ? 'yes' : 'no'}',
    );
  }
}
