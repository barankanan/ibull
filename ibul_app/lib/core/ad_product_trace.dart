import 'package:flutter/foundation.dart';

import 'ad_product_trace_stub.dart'
    if (dart.library.html) 'ad_product_trace_web.dart' as impl;

/// Ad product resolution stages (home_feature category cards).
abstract final class AdProductTraceStage {
  static const adBannerFetchStarted = 'ad_banner_fetch_started';
  static const adBannerFetchSuccess = 'ad_banner_fetch_success';
  static const adProductFetchStarted = 'ad_product_fetch_started';
  static const adProductFetchSuccess = 'ad_product_fetch_success';
  static const adProductFetchEmpty = 'ad_product_fetch_empty';
  static const adProductFilterStarted = 'ad_product_filter_started';
  static const adProductFilterEmpty = 'ad_product_filter_empty';
  static const adProductRenderStarted = 'ad_product_render_started';
  static const adProductRenderCompleted = 'ad_product_render_completed';
  static const adProductFetchError = 'ad_product_fetch_error';
  static const adBannerOnlyNoProductRow = 'ad_banner_only_no_product_row';
}

class AdProductTraceSnapshot {
  const AdProductTraceSnapshot({
    required this.stage,
    this.placement,
    this.category,
    this.subcategory,
    this.adId,
    this.campaignId,
    this.advertiserName,
    this.sellerId,
    this.productIds,
    this.linkedProductIdCount,
    this.isBannerOnly,
    this.bannerCount,
    this.rawRpcCount,
    this.rawSelectCount,
    this.rawProductCount,
    this.filteredProductCount,
    this.renderedProductCount,
    this.rejectionReasons,
    this.query,
    this.error,
    this.filterDetail,
    this.timestamp,
  });

  final String stage;
  final String? placement;
  final String? category;
  final String? subcategory;
  final String? adId;
  final String? campaignId;
  final String? advertiserName;
  final String? sellerId;
  final List<String>? productIds;
  final int? linkedProductIdCount;
  final bool? isBannerOnly;
  final int? bannerCount;
  final int? rawRpcCount;
  final int? rawSelectCount;
  final int? rawProductCount;
  final int? filteredProductCount;
  final int? renderedProductCount;
  final String? rejectionReasons;
  final String? query;
  final String? error;
  final String? filterDetail;
  final String? timestamp;

  Map<String, dynamic> toJson() => {
        'stage': stage,
        if (placement != null) 'placement': placement,
        if (category != null) 'category': category,
        if (subcategory != null) 'subcategory': subcategory,
        if (adId != null) 'adId': adId,
        if (campaignId != null) 'campaignId': campaignId,
        if (advertiserName != null) 'advertiserName': advertiserName,
        if (sellerId != null) 'sellerId': sellerId,
        if (productIds != null) 'productIds': productIds,
        if (linkedProductIdCount != null)
          'linkedProductIdCount': linkedProductIdCount,
        if (isBannerOnly != null) 'isBannerOnly': isBannerOnly,
        if (bannerCount != null) 'bannerCount': bannerCount,
        if (rawRpcCount != null) 'rawRpcCount': rawRpcCount,
        if (rawSelectCount != null) 'rawSelectCount': rawSelectCount,
        if (rawProductCount != null) 'rawProductCount': rawProductCount,
        if (filteredProductCount != null)
          'filteredProductCount': filteredProductCount,
        if (renderedProductCount != null)
          'renderedProductCount': renderedProductCount,
        if (rejectionReasons != null) 'rejectionReasons': rejectionReasons,
        if (query != null) 'query': query,
        if (error != null) 'error': error,
        if (filterDetail != null) 'filterDetail': filterDetail,
        if (timestamp != null) 'timestamp': timestamp,
      };
}

void persistAdProductTrace(AdProductTraceSnapshot snapshot) {
  impl.persistAdProductTrace(snapshot);
}

String? readAdProductTraceJson() => impl.readAdProductTraceJson();

void clearAdProductTrace() => impl.clearAdProductTrace();

void traceAdProduct({
  required String stage,
  String? placement,
  String? category,
  String? subcategory,
  String? adId,
  String? campaignId,
  String? advertiserName,
  String? sellerId,
  List<String>? productIds,
  int? linkedProductIdCount,
  bool? isBannerOnly,
  int? bannerCount,
  int? rawRpcCount,
  int? rawSelectCount,
  int? rawProductCount,
  int? filteredProductCount,
  int? renderedProductCount,
  String? rejectionReasons,
  String? query,
  String? error,
  String? filterDetail,
}) {
  final snapshot = AdProductTraceSnapshot(
    stage: stage,
    placement: placement,
    category: category,
    subcategory: subcategory,
    adId: adId,
    campaignId: campaignId,
    advertiserName: advertiserName,
    sellerId: sellerId,
    productIds: productIds,
    linkedProductIdCount: linkedProductIdCount ?? productIds?.length,
    isBannerOnly: isBannerOnly,
    bannerCount: bannerCount,
    rawRpcCount: rawRpcCount,
    rawSelectCount: rawSelectCount,
    rawProductCount: rawProductCount,
    filteredProductCount: filteredProductCount,
    renderedProductCount: renderedProductCount,
    rejectionReasons: rejectionReasons ?? filterDetail,
    query: query,
    error: error,
    filterDetail: filterDetail,
    timestamp: DateTime.now().toIso8601String(),
  );
  if (kDebugMode) {
    debugPrint(
      '[AdProductTrace][$stage] campaign=$campaignId store=$advertiserName '
      'bannerOnly=$isBannerOnly ids=${productIds?.length ?? 0} '
      'rawRpc=$rawRpcCount rawSelect=$rawSelectCount raw=$rawProductCount '
      'filtered=$filteredProductCount render=$renderedProductCount '
      'error=$error detail=${rejectionReasons ?? filterDetail}',
    );
  }
  persistAdProductTrace(snapshot);
}
