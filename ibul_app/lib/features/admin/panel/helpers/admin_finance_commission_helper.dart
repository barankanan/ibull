import '../../../../services/admin_service.dart';

/// Kategori bazlı komisyon, kargo komisyonu ve vergi tahminleri.
class AdminFinanceCommissionConfig {
  const AdminFinanceCommissionConfig({
    this.defaultPercent = 15,
    this.categoryRules = const [],
    this.cargoMode = AdminFinanceCargoCommissionMode.percent,
    this.cargoPercent = 10,
    this.cargoFixed = 0,
    this.kdvPercent = 20,
    this.stopajPercent = 0,
    this.corporateTaxPercent = 25,
  });

  final double defaultPercent;
  final List<AdminFinanceCategoryCommissionRule> categoryRules;
  final AdminFinanceCargoCommissionMode cargoMode;
  final double cargoPercent;
  final double cargoFixed;
  final double kdvPercent;
  final double stopajPercent;
  final double corporateTaxPercent;

  factory AdminFinanceCommissionConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const AdminFinanceCommissionConfig();
    }
    final rulesRaw = json['category_rules'];
    final rules = <AdminFinanceCategoryCommissionRule>[];
    if (rulesRaw is List) {
      for (final entry in rulesRaw) {
        if (entry is Map) {
          rules.add(AdminFinanceCategoryCommissionRule.fromJson(
            Map<String, dynamic>.from(entry),
          ));
        }
      }
    }
    final cargoModeRaw = (json['cargo_mode'] ?? 'percent').toString();
    return AdminFinanceCommissionConfig(
      defaultPercent: _readDouble(json['default_percent'], 15),
      categoryRules: rules,
      cargoMode: cargoModeRaw == 'fixed'
          ? AdminFinanceCargoCommissionMode.fixed
          : AdminFinanceCargoCommissionMode.percent,
      cargoPercent: _readDouble(json['cargo_percent'], 10),
      cargoFixed: _readDouble(json['cargo_fixed'], 0),
      kdvPercent: _readDouble(json['kdv_percent'], 20),
      stopajPercent: _readDouble(json['stopaj_percent'], 0),
      corporateTaxPercent: _readDouble(json['corporate_tax_percent'], 25),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'default_percent': defaultPercent,
      'category_rules': categoryRules.map((r) => r.toJson()).toList(),
      'cargo_mode': cargoMode == AdminFinanceCargoCommissionMode.fixed
          ? 'fixed'
          : 'percent',
      'cargo_percent': cargoPercent,
      'cargo_fixed': cargoFixed,
      'kdv_percent': kdvPercent,
      'stopaj_percent': stopajPercent,
      'corporate_tax_percent': corporateTaxPercent,
    };
  }

  AdminFinanceCommissionConfig copyWith({
    double? defaultPercent,
    List<AdminFinanceCategoryCommissionRule>? categoryRules,
    AdminFinanceCargoCommissionMode? cargoMode,
    double? cargoPercent,
    double? cargoFixed,
    double? kdvPercent,
    double? stopajPercent,
    double? corporateTaxPercent,
  }) {
    return AdminFinanceCommissionConfig(
      defaultPercent: defaultPercent ?? this.defaultPercent,
      categoryRules: categoryRules ?? this.categoryRules,
      cargoMode: cargoMode ?? this.cargoMode,
      cargoPercent: cargoPercent ?? this.cargoPercent,
      cargoFixed: cargoFixed ?? this.cargoFixed,
      kdvPercent: kdvPercent ?? this.kdvPercent,
      stopajPercent: stopajPercent ?? this.stopajPercent,
      corporateTaxPercent: corporateTaxPercent ?? this.corporateTaxPercent,
    );
  }

  static double _readDouble(Object? value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

enum AdminFinanceCargoCommissionMode { percent, fixed }

class AdminFinanceCategoryCommissionRule {
  const AdminFinanceCategoryCommissionRule({
    required this.categoryName,
    this.categoryId,
    this.percent = 15,
    this.fixedAmount,
    this.isActive = true,
  });

  final String categoryName;
  final int? categoryId;
  final double percent;
  final double? fixedAmount;
  final bool isActive;

  factory AdminFinanceCategoryCommissionRule.fromJson(Map<String, dynamic> json) {
    final fixed = json['fixed_amount'];
    return AdminFinanceCategoryCommissionRule(
      categoryName: (json['category_name'] ?? '').toString(),
      categoryId: (json['category_id'] as num?)?.toInt(),
      percent: AdminFinanceCommissionConfig._readDouble(json['percent'], 15),
      fixedAmount: fixed == null ? null : (fixed as num).toDouble(),
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (categoryId != null) 'category_id': categoryId,
      'category_name': categoryName,
      'percent': percent,
      if (fixedAmount != null) 'fixed_amount': fixedAmount,
      'is_active': isActive,
    };
  }

  AdminFinanceCategoryCommissionRule copyWith({
    String? categoryName,
    int? categoryId,
    double? percent,
    double? fixedAmount,
    bool? isActive,
  }) {
    return AdminFinanceCategoryCommissionRule(
      categoryName: categoryName ?? this.categoryName,
      categoryId: categoryId ?? this.categoryId,
      percent: percent ?? this.percent,
      fixedAmount: fixedAmount ?? this.fixedAmount,
      isActive: isActive ?? this.isActive,
    );
  }
}

class AdminFinanceCommissionHelper {
  const AdminFinanceCommissionHelper._();

  static double commissionForItem({
    required AdminFinanceOrderItem item,
    required AdminFinanceCommissionConfig config,
  }) {
    final rule = _matchRule(item.categoryName, config.categoryRules);
    if (rule != null) {
      if (rule.fixedAmount != null && rule.fixedAmount! > 0) {
        return rule.fixedAmount!;
      }
      return item.totalPrice * (rule.percent / 100);
    }
    return item.totalPrice * (config.defaultPercent / 100);
  }

  static double cargoCommissionForOrder({
    required AdminFinanceOrder order,
    required AdminFinanceCommissionConfig config,
    required bool Function(String status) isDelivered,
    required bool Function(String deliveryType) isCourierDelivery,
  }) {
    if (!isDelivered(order.status) && !isCourierDelivery(order.deliveryType)) {
      return 0;
    }
    final base = order.shippingAmount > 0
        ? order.shippingAmount
        : (order.customerDeliveryFee > 0
            ? order.customerDeliveryFee
            : order.totalDeliveryFee);
    if (base <= 0) {
      if (config.cargoMode == AdminFinanceCargoCommissionMode.fixed) {
        return config.cargoFixed;
      }
      return 0;
    }
    if (config.cargoMode == AdminFinanceCargoCommissionMode.fixed) {
      return config.cargoFixed;
    }
    return base * (config.cargoPercent / 100);
  }

  static AdminFinanceTaxEstimate estimateTaxes({
    required double taxableRevenue,
    required double recordedTaxExpenses,
    required AdminFinanceCommissionConfig config,
  }) {
    final kdv = taxableRevenue * (config.kdvPercent / 100);
    final stopaj = taxableRevenue * (config.stopajPercent / 100);
    final corporate = taxableRevenue > 0
        ? taxableRevenue * (config.corporateTaxPercent / 100)
        : 0.0;
    final estimatedTotal = kdv + stopaj + corporate;
    return AdminFinanceTaxEstimate(
      kdvEstimate: kdv,
      stopajEstimate: stopaj,
      corporateTaxEstimate: corporate,
      recordedTaxExpenses: recordedTaxExpenses,
      totalGovernmentBurden: estimatedTotal + recordedTaxExpenses,
    );
  }

  static AdminFinanceCategoryCommissionRule? _matchRule(
    String? categoryName,
    List<AdminFinanceCategoryCommissionRule> rules,
  ) {
    if (categoryName == null || categoryName.trim().isEmpty) return null;
    final normalized = categoryName.trim().toLowerCase();
    for (final rule in rules) {
      if (!rule.isActive) continue;
      if (rule.categoryName.trim().toLowerCase() == normalized) {
        return rule;
      }
    }
    return null;
  }
}

class AdminFinanceTaxEstimate {
  const AdminFinanceTaxEstimate({
    required this.kdvEstimate,
    required this.stopajEstimate,
    required this.corporateTaxEstimate,
    required this.recordedTaxExpenses,
    required this.totalGovernmentBurden,
  });

  final double kdvEstimate;
  final double stopajEstimate;
  final double corporateTaxEstimate;
  final double recordedTaxExpenses;
  final double totalGovernmentBurden;
}
