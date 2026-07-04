import '../utils/product_visibility_helper.dart';

/// Counts how many product rows survive each visibility filter step.
class ProductFilterAudit {
  const ProductFilterAudit({
    required this.rawCount,
    required this.afterActiveStatusCount,
    required this.afterApprovalStatusCount,
    required this.afterVisibilityFilterCount,
  });

  final int rawCount;
  final int afterActiveStatusCount;
  final int afterApprovalStatusCount;
  final int afterVisibilityFilterCount;

  bool get isEmptyAfterFilter => rawCount > 0 && afterVisibilityFilterCount == 0;

  bool get likelyApprovalFilterDrop =>
      rawCount > 0 &&
      afterActiveStatusCount > 0 &&
      afterApprovalStatusCount == 0;

  bool get likelyStatusFilterDrop =>
      rawCount > 0 && afterActiveStatusCount == 0;

  Map<String, dynamic> toJson() => {
        'rawCount': rawCount,
        'afterActiveStatusCount': afterActiveStatusCount,
        'afterApprovalStatusCount': afterApprovalStatusCount,
        'afterVisibilityFilterCount': afterVisibilityFilterCount,
      };

  static ProductFilterAudit fromRows(Iterable<Map<String, dynamic>> rows) {
    final raw = rows.map((row) => Map<String, dynamic>.from(row)).toList();
    var afterActive = 0;
    var afterApproval = 0;
    for (final row in raw) {
      final status = row['status']?.toString();
      if (!ProductVisibilityHelper.isPublicCatalogProductStatus(status)) {
        continue;
      }
      afterActive++;
      final approval = row['approval_status']?.toString();
      final adminApproval = row['admin_approval_status']?.toString();
      if (ProductVisibilityHelper.isApprovedApprovalStatus(approval) ||
          ProductVisibilityHelper.isApprovedApprovalStatus(adminApproval)) {
        afterApproval++;
      }
    }
    final filtered = ProductVisibilityHelper.filterPublicProductMaps(raw);
    return ProductFilterAudit(
      rawCount: raw.length,
      afterActiveStatusCount: afterActive,
      afterApprovalStatusCount: afterApproval,
      afterVisibilityFilterCount: filtered.length,
    );
  }
}
