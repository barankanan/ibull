import '../../../models/product_model.dart';

enum OrderHistoryStatusFilter {
  all('Tümü'),
  delivered('Teslim Edilenler'),
  preparing('Hazırlanıyor'),
  inTransit('Yolda'),
  pending('Bekleyenler'),
  cancelled('İptal Edilenler'),
  returned('İade Edilenler');

  const OrderHistoryStatusFilter(this.label);
  final String label;
}

enum ReorderItemOutcome {
  added,
  outOfStock,
  notListed,
  storeInactive,
  priceChanged,
}

class OrderHistoryFilter {
  const OrderHistoryFilter({
    this.month,
    this.year,
    this.status = OrderHistoryStatusFilter.all,
  });

  final int? month;
  final int? year;
  final OrderHistoryStatusFilter status;

  bool get hasActiveFilters =>
      month != null || year != null || status != OrderHistoryStatusFilter.all;

  OrderHistoryFilter clear() => const OrderHistoryFilter();

  OrderHistoryFilter copyWith({
    int? month,
    bool clearMonth = false,
    int? year,
    bool clearYear = false,
    OrderHistoryStatusFilter? status,
  }) {
    return OrderHistoryFilter(
      month: clearMonth ? null : (month ?? this.month),
      year: clearYear ? null : (year ?? this.year),
      status: status ?? this.status,
    );
  }
}

class ReorderLineCheck {
  const ReorderLineCheck({
    required this.orderItemId,
    required this.productName,
    required this.quantity,
    required this.outcome,
    this.product,
    this.previousUnitPrice,
    this.currentUnitPrice,
  });

  final String orderItemId;
  final String productName;
  final int quantity;
  final ReorderItemOutcome outcome;
  final Product? product;
  final double? previousUnitPrice;
  final double? currentUnitPrice;

  bool get canAddToCart =>
      outcome == ReorderItemOutcome.added ||
      outcome == ReorderItemOutcome.priceChanged;
}

class ReorderResult {
  const ReorderResult({
    required this.added,
    required this.blocked,
    required this.priceChanged,
    required this.allBlocked,
  });

  final List<ReorderLineCheck> added;
  final List<ReorderLineCheck> blocked;
  final List<ReorderLineCheck> priceChanged;
  final bool allBlocked;

  bool get hasAdded => added.isNotEmpty;
}
