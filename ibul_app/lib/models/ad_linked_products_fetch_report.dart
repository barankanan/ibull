import '../models/db_product.dart';

/// Context for ad-linked product fetch (tightens RPC security + diagnostics).
class AdLinkedProductsFetchContext {
  const AdLinkedProductsFetchContext({
    this.campaignId,
    this.sellerId,
    this.adId,
    this.advertiserName,
    this.category,
    this.subcategory,
  });

  final String? campaignId;
  final String? sellerId;
  final String? adId;
  final String? advertiserName;
  final String? category;
  final String? subcategory;
}

/// Diagnostics for home_feature ad-linked product fetch.
class AdLinkedProductsFetchReport {
  const AdLinkedProductsFetchReport({
    required this.products,
    required this.requestedIdCount,
    required this.rawRpcCount,
    required this.rawSelectCount,
    required this.rawDbCount,
    required this.filteredCount,
    required this.query,
    this.error,
    this.rejections = const {},
    this.missingIds = const {},
    this.usedRpc = false,
    this.context,
  });

  final List<DBProduct> products;
  final int requestedIdCount;
  final int rawRpcCount;
  final int rawSelectCount;
  final int rawDbCount;
  final int filteredCount;
  final String query;
  final String? error;
  final Map<String, String> rejections;
  final Map<String, String> missingIds;
  final bool usedRpc;
  final AdLinkedProductsFetchContext? context;

  int get linkedProductIdCount => requestedIdCount;

  factory AdLinkedProductsFetchReport.empty() {
    return const AdLinkedProductsFetchReport(
      products: [],
      requestedIdCount: 0,
      rawRpcCount: 0,
      rawSelectCount: 0,
      rawDbCount: 0,
      filteredCount: 0,
      query: '(skipped — empty ids)',
    );
  }

  String? rejectionSummary({int maxEntries = 6}) {
    if (rejections.isEmpty && missingIds.isEmpty) return null;
    final parts = <String>[];
    for (final entry in rejections.entries.take(maxEntries)) {
      parts.add('${entry.key}:${entry.value}');
    }
    for (final entry in missingIds.entries.take(maxEntries - parts.length)) {
      parts.add('${entry.key}:${entry.value}');
    }
    return parts.join('; ');
  }
}
