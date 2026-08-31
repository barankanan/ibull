import 'package:ibul_app/utils/order_status_constants.dart';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/mobile_category_catalog.dart';
import '../models/admin_permissions.dart';
import '../models/db_category.dart';
import 'admin/admin_access_service.dart';
import 'admin/admin_mapping_helpers.dart';
import 'admin/admin_metrics_service.dart';
import 'auth_service.dart';

class AdminSystemLogEntry {
  const AdminSystemLogEntry({
    required this.title,
    required this.subtitle,
    required this.level,
    required this.occurredAt,
  });

  final String title;
  final String subtitle;
  final String level;
  final DateTime occurredAt;
}

class AdminSupabaseQuotaSnapshot {
  const AdminSupabaseQuotaSnapshot({
    required this.planName,
    required this.fetchedAt,
    required this.databaseUsedMb,
    required this.databaseLimitMb,
    required this.storageUsedMb,
    required this.storageLimitMb,
    required this.monthlyActiveUsersUsed,
    required this.monthlyActiveUsersLimit,
    required this.monthlyEgressUsedGb,
    required this.monthlyEgressLimitGb,
    required this.realtimeMonthlyMessagesUsed,
    required this.realtimeMonthlyMessagesLimit,
    required this.realtimeConcurrentConnectionsLimit,
    required this.edgeMonthlyInvocationsUsed,
    required this.edgeMonthlyInvocationsLimit,
    required this.trafficIsEstimated,
    required this.usersRecommendedLimit,
    required this.storesRecommendedLimit,
    required this.sellersRecommendedLimit,
    required this.couriersRecommendedLimit,
  });

  final String planName;
  final DateTime? fetchedAt;
  final double databaseUsedMb;
  final double databaseLimitMb;
  final double storageUsedMb;
  final double storageLimitMb;
  final int monthlyActiveUsersUsed;
  final int monthlyActiveUsersLimit;
  final double monthlyEgressUsedGb;
  final double monthlyEgressLimitGb;
  final int realtimeMonthlyMessagesUsed;
  final int realtimeMonthlyMessagesLimit;
  final int realtimeConcurrentConnectionsLimit;
  final int edgeMonthlyInvocationsUsed;
  final int edgeMonthlyInvocationsLimit;
  final bool trafficIsEstimated;
  final int usersRecommendedLimit;
  final int storesRecommendedLimit;
  final int sellersRecommendedLimit;
  final int couriersRecommendedLimit;

  double get databaseUsagePercent => databaseLimitMb <= 0
      ? 0
      : (databaseUsedMb / databaseLimitMb).clamp(0.0, 1.0).toDouble();
  double get storageUsagePercent => storageLimitMb <= 0
      ? 0
      : (storageUsedMb / storageLimitMb).clamp(0.0, 1.0).toDouble();
  double get mauUsagePercent => monthlyActiveUsersLimit <= 0
      ? 0
      : (monthlyActiveUsersUsed / monthlyActiveUsersLimit)
            .clamp(0.0, 1.0)
            .toDouble();
  double get egressUsagePercent => monthlyEgressLimitGb <= 0
      ? 0
      : (monthlyEgressUsedGb / monthlyEgressLimitGb).clamp(0.0, 1.0).toDouble();
  double get realtimeMessagesUsagePercent => realtimeMonthlyMessagesLimit <= 0
      ? 0
      : (realtimeMonthlyMessagesUsed / realtimeMonthlyMessagesLimit)
            .clamp(0.0, 1.0)
            .toDouble();
  double get edgeInvocationsUsagePercent => edgeMonthlyInvocationsLimit <= 0
      ? 0
      : (edgeMonthlyInvocationsUsed / edgeMonthlyInvocationsLimit)
            .clamp(0.0, 1.0)
            .toDouble();
}

class AdminSystemMetrics {
  const AdminSystemMetrics({
    required this.totalUsers,
    required this.totalSellers,
    required this.approvedIhizCouriers,
    required this.activeUsers24h,
    required this.activeUsers30d,
    required this.totalStores,
    required this.openStores,
    required this.totalProducts,
    required this.lowStockProducts,
    required this.outOfStockProducts,
    required this.totalOrders,
    required this.todayOrders,
    required this.pendingSellerApplications,
    required this.pendingStoreDeletionRequests,
    required this.openSupportTickets,
    required this.notificationsToday,
    required this.estimatedDatabaseMb,
    required this.estimatedDatabaseUsagePercent,
    required this.estimatedStorageMb,
    required this.estimatedStorageUsagePercent,
    required this.systemHealthPercent,
    required this.dataCoveragePercent,
    required this.userSignalHealthy,
    required this.orderSignalHealthy,
    required this.storeSignalHealthy,
    required this.supportSignalHealthy,
    required this.notificationSignalHealthy,
    required this.logs,
    required this.supabaseQuota,
  });

  final int totalUsers;
  final int totalSellers;
  final int approvedIhizCouriers;
  final int activeUsers24h;
  final int activeUsers30d;
  final int totalStores;
  final int openStores;
  final int totalProducts;
  final int lowStockProducts;
  final int outOfStockProducts;
  final int totalOrders;
  final int todayOrders;
  final int pendingSellerApplications;
  final int pendingStoreDeletionRequests;
  final int openSupportTickets;
  final int notificationsToday;
  final double estimatedDatabaseMb;
  final double estimatedDatabaseUsagePercent;
  final double estimatedStorageMb;
  final double estimatedStorageUsagePercent;
  final double systemHealthPercent;
  final double dataCoveragePercent;
  final bool userSignalHealthy;
  final bool orderSignalHealthy;
  final bool storeSignalHealthy;
  final bool supportSignalHealthy;
  final bool notificationSignalHealthy;
  final List<AdminSystemLogEntry> logs;
  final AdminSupabaseQuotaSnapshot supabaseQuota;
}

class AdminSecurityRequirement {
  const AdminSecurityRequirement({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.owner,
    required this.evidenceLabel,
    required this.actionLabel,
    required this.completionPercent,
  });

  final String id;
  final String title;
  final String description;
  final String status;
  final String owner;
  final String evidenceLabel;
  final String actionLabel;
  final int completionPercent;
}

class AdminSecurityIncident {
  const AdminSecurityIncident({
    required this.title,
    required this.subtitle,
    required this.severity,
    required this.source,
    required this.occurredAt,
  });

  final String title;
  final String subtitle;
  final String severity;
  final String source;
  final DateTime occurredAt;
}

class AdminAuthLoginEvent {
  const AdminAuthLoginEvent({
    required this.id,
    required this.email,
    required this.provider,
    required this.authArea,
    required this.status,
    required this.attemptedAt,
    this.userId,
    this.errorCode,
    this.errorMessage,
    this.platform,
    this.deviceLabel,
    this.userAgent,
    this.metadata = const {},
  });

  final String id;
  final String? userId;
  final String? email;
  final String provider;
  final String authArea;
  final String status;
  final String? errorCode;
  final String? errorMessage;
  final String? platform;
  final String? deviceLabel;
  final String? userAgent;
  final DateTime attemptedAt;
  final Map<String, dynamic> metadata;

  factory AdminAuthLoginEvent.fromMap(Map<String, dynamic> map) {
    final metadata = map['metadata'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(map['metadata'] as Map)
        : const <String, dynamic>{};

    return AdminAuthLoginEvent(
      id: (map['id'] ?? '').toString(),
      userId: map['user_id']?.toString(),
      email: map['email']?.toString(),
      provider: (map['provider'] ?? 'password').toString(),
      authArea: (map['auth_area'] ?? 'unknown').toString(),
      status: (map['status'] ?? 'failed').toString(),
      errorCode: map['error_code']?.toString(),
      errorMessage: map['error_message']?.toString(),
      platform: map['platform']?.toString(),
      deviceLabel: map['device_label']?.toString(),
      userAgent: map['user_agent']?.toString(),
      attemptedAt:
          DateTime.tryParse((map['attempted_at'] ?? '').toString()) ??
          DateTime.now(),
      metadata: metadata,
    );
  }
}

class AdminSecurityAdminPosture {
  const AdminSecurityAdminPosture({
    required this.userId,
    required this.name,
    required this.email,
    required this.roleKey,
    required this.roleLabel,
    required this.modules,
    required this.lastUpdated,
    required this.hasSecurityLogsAccess,
    required this.hasPermissionSystemAccess,
    required this.isOverexposed,
  });

  final String userId;
  final String name;
  final String email;
  final String roleKey;
  final String roleLabel;
  final List<String> modules;
  final DateTime? lastUpdated;
  final bool hasSecurityLogsAccess;
  final bool hasPermissionSystemAccess;
  final bool isOverexposed;

  int get moduleCount => modules.length;
}

class AdminSecuritySnapshot {
  const AdminSecuritySnapshot({
    required this.activeAdminCount,
    required this.securityOwnerCount,
    required this.permissionManagerCount,
    required this.overexposedAdminCount,
    required this.criticalIncidentCount7d,
    required this.readinessPercent,
    required this.visibilityPercent,
    required this.postureLabel,
    required this.postureNote,
    required this.schemaMessage,
    required this.requirements,
    required this.incidents,
    required this.adminPosture,
  });

  final int activeAdminCount;
  final int securityOwnerCount;
  final int permissionManagerCount;
  final int overexposedAdminCount;
  final int criticalIncidentCount7d;
  final double readinessPercent;
  final double visibilityPercent;
  final String postureLabel;
  final String postureNote;
  final String schemaMessage;
  final List<AdminSecurityRequirement> requirements;
  final List<AdminSecurityIncident> incidents;
  final List<AdminSecurityAdminPosture> adminPosture;
}

class AdminAnalyticsSlice {
  const AdminAnalyticsSlice({
    required this.label,
    required this.value,
    required this.share,
    this.note,
  });

  final String label;
  final int value;
  final double share;
  final String? note;
}

class AdminTimelinePoint {
  const AdminTimelinePoint({
    required this.label,
    required this.primaryValue,
    this.secondaryValue = 0,
  });

  final String label;
  final int primaryValue;
  final int secondaryValue;
}

class AdminRecentUserActivity {
  const AdminRecentUserActivity({
    required this.name,
    required this.email,
    required this.createdAt,
    required this.lastSeenAt,
    required this.orderCount30d,
    required this.city,
  });

  final String name;
  final String email;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final int orderCount30d;
  final String city;
}

class AdminUserAnalyticsSnapshot {
  const AdminUserAnalyticsSnapshot({
    required this.totalUsers,
    required this.activeUsers24h,
    required this.activeUsers30d,
    required this.newUsers7d,
    required this.buyers30d,
    required this.orders30d,
    required this.repeatBuyerRate,
    required this.averageOrderValue,
    required this.topCities,
    required this.deliveryTypes,
    required this.activityBands,
    required this.recentUsers,
    required this.userGrowth,
  });

  final int totalUsers;
  final int activeUsers24h;
  final int activeUsers30d;
  final int newUsers7d;
  final int buyers30d;
  final int orders30d;
  final double repeatBuyerRate;
  final double averageOrderValue;
  final List<AdminAnalyticsSlice> topCities;
  final List<AdminAnalyticsSlice> deliveryTypes;
  final List<AdminAnalyticsSlice> activityBands;
  final List<AdminRecentUserActivity> recentUsers;
  final List<AdminTimelinePoint> userGrowth;
}

class AdminStorePerformance {
  const AdminStorePerformance({
    required this.storeName,
    required this.city,
    required this.category,
    required this.isOpen,
    required this.rating,
    required this.productCount,
    required this.orderCount30d,
    required this.revenue30d,
  });

  final String storeName;
  final String city;
  final String category;
  final bool isOpen;
  final double rating;
  final int productCount;
  final int orderCount30d;
  final double revenue30d;
}

class AdminStoreAnalyticsSnapshot {
  const AdminStoreAnalyticsSnapshot({
    required this.totalStores,
    required this.openStores,
    required this.newStores30d,
    required this.totalProducts,
    required this.averageProductsPerStore,
    required this.averageRating,
    required this.lowStockStores,
    required this.storesWithoutProducts,
    required this.topCategories,
    required this.topCities,
    required this.topStores,
  });

  final int totalStores;
  final int openStores;
  final int newStores30d;
  final int totalProducts;
  final double averageProductsPerStore;
  final double averageRating;
  final int lowStockStores;
  final int storesWithoutProducts;
  final List<AdminAnalyticsSlice> topCategories;
  final List<AdminAnalyticsSlice> topCities;
  final List<AdminStorePerformance> topStores;
}

class AdminCargoShipment {
  const AdminCargoShipment({
    required this.storeName,
    required this.cargoCompany,
    required this.stateLabel,
    required this.createdAt,
    required this.hasTracking,
    required this.trackingNumber,
  });

  final String storeName;
  final String cargoCompany;
  final String stateLabel;
  final DateTime? createdAt;
  final bool hasTracking;
  final String trackingNumber;
}

class AdminCargoAnalyticsSnapshot {
  const AdminCargoAnalyticsSnapshot({
    required this.windowLabel,
    required this.totalShipments,
    required this.deliveredShipments,
    required this.inTransitShipments,
    required this.preparingShipments,
    required this.problemShipments,
    required this.delayedShipments,
    required this.trackingCoverage,
    required this.companyBreakdown,
    required this.statusBreakdown,
    required this.recentShipments,
  });

  final String windowLabel;
  final int totalShipments;
  final int deliveredShipments;
  final int inTransitShipments;
  final int preparingShipments;
  final int problemShipments;
  final int delayedShipments;
  final double trackingCoverage;
  final List<AdminAnalyticsSlice> companyBreakdown;
  final List<AdminAnalyticsSlice> statusBreakdown;
  final List<AdminCargoShipment> recentShipments;
}

class AdminIhizShipment {
  const AdminIhizShipment({
    required this.id,
    required this.storeName,
    required this.productName,
    required this.cargoCompany,
    required this.statusLabel,
    required this.shipmentStep,
    required this.createdAt,
    required this.hasTracking,
    required this.trackingNumber,
  });

  final String id;
  final String storeName;
  final String productName;
  final String cargoCompany;
  final String statusLabel;
  final String shipmentStep;
  final DateTime? createdAt;
  final bool hasTracking;
  final String trackingNumber;
}

class AdminIhizSnapshot {
  const AdminIhizSnapshot({
    required this.windowLabel,
    required this.totalIhizShipments,
    required this.readyPoolCount,
    required this.inTransitCount,
    required this.delivered24hCount,
    required this.problemCount,
    required this.delayedOpenCount,
    required this.branchTransferCount,
    required this.trackingCoverage,
    required this.ihizShareRatio,
    required this.statusBreakdown,
    required this.recentShipments,
  });

  final String windowLabel;
  final int totalIhizShipments;
  final int readyPoolCount;
  final int inTransitCount;
  final int delivered24hCount;
  final int problemCount;
  final int delayedOpenCount;
  final int branchTransferCount;
  final double trackingCoverage;
  final double ihizShareRatio;
  final List<AdminAnalyticsSlice> statusBreakdown;
  final List<AdminIhizShipment> recentShipments;
}

class AdminInvestmentEntry {
  const AdminInvestmentEntry({
    required this.id,
    required this.source,
    required this.amount,
    required this.investmentDate,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String source;
  final double amount;
  final DateTime investmentDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  factory AdminInvestmentEntry.fromMap(Map<String, dynamic> map) {
    return AdminInvestmentEntry(
      id: (map['id'] ?? '').toString(),
      source: (map['source'] ?? '').toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      investmentDate:
          DateTime.tryParse((map['investment_date'] ?? '').toString()) ??
          DateTime.now(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()),
      createdBy: map['created_by']?.toString(),
    );
  }
}

class AdminInvestmentAllocation {
  const AdminInvestmentAllocation({
    required this.id,
    required this.category,
    required this.amount,
    required this.spentAt,
    this.note = '',
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String category;
  final double amount;
  final DateTime spentAt;
  final String note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  factory AdminInvestmentAllocation.fromMap(Map<String, dynamic> map) {
    return AdminInvestmentAllocation(
      id: (map['id'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      spentAt:
          DateTime.tryParse((map['spent_at'] ?? '').toString()) ??
          DateTime.now(),
      note: (map['note'] ?? '').toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()),
      createdBy: map['created_by']?.toString(),
    );
  }
}

class AdminExpense {
  const AdminExpense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.expenseDate,
    required this.type,
    this.recurrence,
    required this.status,
    this.paymentMethod,
    this.vendor,
    this.invoiceUrl,
    this.note,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime expenseDate;
  final String type;
  final String? recurrence;
  final String status;
  final String? paymentMethod;
  final String? vendor;
  final String? invoiceUrl;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  factory AdminExpense.fromMap(Map<String, dynamic> map) {
    final rawDate = (map['expense_date'] ?? '').toString();
    final parsedDate = DateTime.tryParse(rawDate) ??
        DateTime.tryParse('${rawDate}T00:00:00') ??
        DateTime.now();
    return AdminExpense(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      category: (map['category'] ?? 'other').toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      expenseDate: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      type: (map['type'] ?? 'one_time').toString(),
      recurrence: map['recurrence']?.toString(),
      status: (map['status'] ?? 'paid').toString(),
      paymentMethod: map['payment_method']?.toString(),
      vendor: map['vendor']?.toString(),
      invoiceUrl: map['invoice_url']?.toString(),
      note: map['note']?.toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()),
      createdBy: map['created_by']?.toString(),
    );
  }

  static String formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toInsertMap() {
    return {
      'title': title,
      'category': category,
      'amount': amount,
      'expense_date': formatDate(expenseDate),
      'type': type,
      'recurrence': type == 'recurring' ? recurrence : null,
      'status': status,
      'payment_method': paymentMethod,
      'vendor': vendor,
      'invoice_url': invoiceUrl,
      'note': note,
    };
  }
}

class AdminRevenue {
  const AdminRevenue({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.revenueDate,
    required this.type,
    this.recurrence,
    required this.status,
    this.source,
    this.paymentMethod,
    this.referenceNo,
    this.note,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime revenueDate;
  final String type;
  final String? recurrence;
  final String status;
  final String? source;
  final String? paymentMethod;
  final String? referenceNo;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  factory AdminRevenue.fromMap(Map<String, dynamic> map) {
    final rawDate = (map['revenue_date'] ?? '').toString();
    final parsedDate = DateTime.tryParse(rawDate) ??
        DateTime.tryParse('${rawDate}T00:00:00') ??
        DateTime.now();
    return AdminRevenue(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      category: (map['category'] ?? 'other').toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      revenueDate: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      type: (map['type'] ?? 'one_time').toString(),
      recurrence: map['recurrence']?.toString(),
      status: (map['status'] ?? 'received').toString(),
      source: map['source']?.toString(),
      paymentMethod: map['payment_method']?.toString(),
      referenceNo: map['reference_no']?.toString(),
      note: map['note']?.toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()),
      createdBy: map['created_by']?.toString(),
    );
  }

  static String formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class SellerPayout {
  const SellerPayout({
    required this.id,
    required this.sellerId,
    this.storeId,
    this.storeName,
    required this.periodStart,
    required this.periodEnd,
    required this.grossAmount,
    required this.commissionAmount,
    required this.refundAmount,
    required this.deductionsAmount,
    required this.netPayoutAmount,
    required this.orderCount,
    required this.itemCount,
    required this.status,
    this.paymentMethod,
    this.paymentReference,
    this.paidAt,
    this.approvedAt,
    this.approvedBy,
    this.paidBy,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String sellerId;
  final String? storeId;
  final String? storeName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double grossAmount;
  final double commissionAmount;
  final double refundAmount;
  final double deductionsAmount;
  final double netPayoutAmount;
  final int orderCount;
  final int itemCount;
  final String status;
  final String? paymentMethod;
  final String? paymentReference;
  final DateTime? paidAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? paidBy;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SellerPayout.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(String raw) {
      final parsed = DateTime.tryParse(raw) ??
          DateTime.tryParse('${raw}T00:00:00') ??
          DateTime.now();
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    return SellerPayout(
      id: (map['id'] ?? '').toString(),
      sellerId: (map['seller_id'] ?? '').toString(),
      storeId: map['store_id']?.toString(),
      storeName: map['store_name']?.toString(),
      periodStart: parseDate((map['period_start'] ?? '').toString()),
      periodEnd: parseDate((map['period_end'] ?? '').toString()),
      grossAmount: (map['gross_amount'] as num?)?.toDouble() ?? 0,
      commissionAmount: (map['commission_amount'] as num?)?.toDouble() ?? 0,
      refundAmount: (map['refund_amount'] as num?)?.toDouble() ?? 0,
      deductionsAmount: (map['deductions_amount'] as num?)?.toDouble() ?? 0,
      netPayoutAmount: (map['net_payout_amount'] as num?)?.toDouble() ?? 0,
      orderCount: (map['order_count'] as num?)?.toInt() ?? 0,
      itemCount: (map['item_count'] as num?)?.toInt() ?? 0,
      status: (map['status'] ?? 'pending').toString(),
      paymentMethod: map['payment_method']?.toString(),
      paymentReference: map['payment_reference']?.toString(),
      paidAt: DateTime.tryParse((map['paid_at'] ?? '').toString()),
      approvedAt: DateTime.tryParse((map['approved_at'] ?? '').toString()),
      approvedBy: map['approved_by']?.toString(),
      paidBy: map['paid_by']?.toString(),
      note: map['note']?.toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()),
    );
  }
}

class AdminFinanceStoreEntry {
  const AdminFinanceStoreEntry({
    required this.sellerId,
    required this.storeName,
    this.isStoreOpen = true,
  });

  final String sellerId;
  final String storeName;
  final bool isStoreOpen;

  factory AdminFinanceStoreEntry.fromMap(Map<String, dynamic> map) {
    final name = (map['business_name'] ?? map['store_name'] ?? 'Mağaza')
        .toString()
        .trim();
    return AdminFinanceStoreEntry(
      sellerId: (map['seller_id'] ?? '').toString(),
      storeName: name.isEmpty ? 'Mağaza' : name,
      isStoreOpen: map['is_store_open'] == true,
    );
  }
}

class AdminFinanceOrderItem {
  const AdminFinanceOrderItem({
    required this.orderId,
    required this.sellerId,
    required this.storeName,
    required this.status,
    required this.totalPrice,
    required this.createdAt,
    this.updatedAt,
    this.categoryName,
  });

  final String orderId;
  final String sellerId;
  final String storeName;
  final String status;
  final double totalPrice;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? categoryName;

  factory AdminFinanceOrderItem.fromMap(Map<String, dynamic> map) {
    final categoryRaw = map['category_name'];
    return AdminFinanceOrderItem(
      orderId: (map['order_id'] ?? '').toString(),
      sellerId: (map['seller_id'] ?? '').toString(),
      storeName: (map['store_name'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0,
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()),
      categoryName: categoryRaw == null || categoryRaw.toString().trim().isEmpty
          ? null
          : categoryRaw.toString().trim(),
    );
  }
}

class AdminFinanceOrder {
  const AdminFinanceOrder({
    required this.id,
    required this.status,
    required this.totalAmount,
    required this.shippingAmount,
    required this.deliveryType,
    required this.createdAt,
    this.customerDeliveryFee = 0,
    this.sellerDeliveryFee = 0,
    this.totalDeliveryFee = 0,
  });

  final String id;
  final String status;
  final double totalAmount;
  final double shippingAmount;
  final String deliveryType;
  final DateTime createdAt;
  final double customerDeliveryFee;
  final double sellerDeliveryFee;
  final double totalDeliveryFee;

  factory AdminFinanceOrder.fromMap(Map<String, dynamic> map) {
    return AdminFinanceOrder(
      id: (map['id'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      shippingAmount: (map['shipping_amount'] as num?)?.toDouble() ?? 0,
      deliveryType: (map['delivery_type'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      customerDeliveryFee:
          (map['customer_delivery_fee'] as num?)?.toDouble() ?? 0,
      sellerDeliveryFee: (map['seller_delivery_fee'] as num?)?.toDouble() ?? 0,
      totalDeliveryFee: (map['total_delivery_fee'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdminGeneralCleanupResult {
  const AdminGeneralCleanupResult({
    required this.deletedOrderItemHistoryCount,
    required this.deletedOrderItemsCount,
    required this.deletedOrdersCount,
    required this.deletedNotificationsCount,
    this.usedRpc = false,
  });

  final int deletedOrderItemHistoryCount;
  final int deletedOrderItemsCount;
  final int deletedOrdersCount;
  final int deletedNotificationsCount;
  final bool usedRpc;

  int get totalDeleted =>
      deletedOrderItemHistoryCount +
      deletedOrderItemsCount +
      deletedOrdersCount +
      deletedNotificationsCount;
}

class AdminService {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<AdminRoleCatalogEntry> get _fallbackRoleCatalog =>
      defaultAdminRoleCatalog;
  static const String _investmentEntriesTable = 'admin_investment_entries';
  static const String _investmentAllocationsTable =
      'admin_investment_allocations';
  static const String _adminExpensesTable = 'admin_expenses';
  static const String _adminRevenuesTable = 'admin_revenues';
  static const String _sellerPayoutsTable = 'seller_payouts';
  static const String _cleanupSentinelUuid =
      '00000000-0000-0000-0000-000000000000';

  Future<int> _safeCount(
    Future<int> Function() action, {
    void Function()? onSuccess,
  }) async {
    try {
      final value = await action();
      onSuccess?.call();
      return value;
    } catch (e) {
      debugPrint('AdminService: count query failed: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>?> _safeSingle(
    Future<Map<String, dynamic>?> Function() action, {
    void Function()? onSuccess,
  }) async {
    try {
      final value = await action();
      onSuccess?.call();
      return value;
    } catch (e) {
      debugPrint('AdminService: single query failed: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _safeList(
    Future<List<Map<String, dynamic>>> Function() action, {
    void Function()? onSuccess,
  }) async {
    try {
      final value = await action();
      onSuccess?.call();
      return value;
    } catch (e) {
      debugPrint('AdminService: list query failed: $e');
      return const [];
    }
  }

  AdminRoleCatalogEntry? _fallbackRoleByKey(String roleKey) {
    for (final entry in _fallbackRoleCatalog) {
      if (entry.roleKey == roleKey) return entry;
    }
    return null;
  }

  List<String> _normalizedModules(Iterable<String> values) {
    return normalizeAdminModules(values);
  }

  List<String> _withDefaultIhizAccess(
    String roleKey,
    Iterable<String> modules,
  ) {
    return withDefaultIhizAccess(roleKey, modules);
  }

  Exception _friendlyFinanceSchemaException() {
    return Exception(
      "Finans tabloları Supabase'te hazır değil. İlgili SQL migration dosyasını uygulamanız gerekiyor.",
    );
  }

  Object _mapFinanceSchemaError(Object error) {
    final details = error is PostgrestException ? '${error.details ?? ''}' : '';
    final message = error is PostgrestException ? error.message : '$error';
    if (error is PostgrestException &&
        (error.code == '42501' || message.toLowerCase().contains('permission denied'))) {
      return Exception(
        'Finans kaydı kaydedilemedi. Yetki, RLS veya migration ayarlarını kontrol edin.',
      );
    }
    if (error is PostgrestException && error.code == '23505') {
      return Exception('Bu satıcı ve dönem için hakediş kaydı zaten mevcut.');
    }
    if (error is PostgrestException &&
        (error.code == 'PGRST205' ||
            message.contains(_investmentEntriesTable) ||
            message.contains(_investmentAllocationsTable) ||
            message.contains(_adminExpensesTable) ||
            message.contains(_adminRevenuesTable) ||
            message.contains(_sellerPayoutsTable) ||
            details.contains(_investmentEntriesTable) ||
            details.contains(_investmentAllocationsTable) ||
            details.contains(_adminExpensesTable) ||
            details.contains(_adminRevenuesTable) ||
            details.contains(_sellerPayoutsTable))) {
      return _friendlyFinanceSchemaException();
    }
    return error;
  }

  bool _canSellerPayoutTransition(String from, String to) {
    if (from == to) return true;
    const allowed = {
      'pending': {'approved', 'disputed', 'cancelled'},
      'approved': {'paid', 'disputed', 'cancelled'},
      'disputed': {'approved', 'cancelled'},
    };
    return allowed[from]?.contains(to) ?? false;
  }

  String _sellerPayoutTransitionError(String from, String to) {
    if (from == 'paid') return 'Ödenmiş hakediş durumu değiştirilemez.';
    if (from == 'cancelled') return 'İptal edilmiş hakediş yenilenemez.';
    return 'Geçersiz durum geçişi: $from → $to';
  }

  void _validateAdminExpenseInput({
    required String title,
    required String category,
    required double amount,
    required String type,
    required String status,
    String? recurrence,
  }) {
    if (title.trim().isEmpty) {
      throw Exception('Gider başlığı boş olamaz.');
    }
    if (category.trim().isEmpty) {
      throw Exception('Gider kategorisi seçilmelidir.');
    }
    if (amount <= 0 || amount.isNaN || amount.isInfinite) {
      throw Exception('Gider tutarı 0\'dan büyük olmalıdır.');
    }
    const validTypes = {'one_time', 'recurring'};
    const validStatuses = {'paid', 'pending', 'cancelled'};
    if (!validTypes.contains(type)) {
      throw Exception('Geçersiz gider türü.');
    }
    if (!validStatuses.contains(status)) {
      throw Exception('Geçersiz gider durumu.');
    }
    if (type == 'recurring' && (recurrence == null || recurrence.trim().isEmpty)) {
      throw Exception('Tekrarlayan gider için periyot seçilmelidir.');
    }
  }

  Future<void> _logFinanceInsertFailure({
    required String table,
    required Map<String, dynamic> payload,
    required Object error,
  }) async {
    debugPrint('[FinanceInsert] table=$table');
    debugPrint('[FinanceInsert] payload_keys=${payload.keys.toList()}');
    debugPrint(
      '[FinanceInsert] status=${payload['status']} '
      'type=${payload['type']} category=${payload['category']}',
    );
    if (error is PostgrestException) {
      debugPrint(
        '[FinanceInsert] code=${error.code} message=${error.message} '
        'details=${error.details}',
      );
    } else {
      debugPrint('[FinanceInsert] error=$error');
    }
    try {
      final debug = await _supabase.rpc('debug_admin_finance_access');
      debugPrint('[FinanceInsert] debug_admin_finance_access=$debug');
    } catch (rpcError) {
      debugPrint('[FinanceInsert] debug_admin_finance_access unavailable: $rpcError');
    }
  }

  void _validateSellerPayoutAmounts({
    required double grossAmount,
    required double commissionAmount,
    required double refundAmount,
    required double deductionsAmount,
    required double netPayoutAmount,
  }) {
    for (final value in [
      grossAmount,
      commissionAmount,
      refundAmount,
      deductionsAmount,
      netPayoutAmount,
    ]) {
      if (value.isNaN || value.isInfinite || value < 0) {
        throw Exception('Hakediş tutarları geçersiz.');
      }
    }
  }

  Future<SellerPayout?> _findSellerPayoutForPeriod({
    required String sellerId,
    String? storeId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    try {
      dynamic query = _supabase
          .from(_sellerPayoutsTable)
          .select()
          .eq('seller_id', sellerId)
          .eq('period_start', AdminExpense.formatDate(periodStart))
          .eq('period_end', AdminExpense.formatDate(periodEnd))
          .neq('status', 'cancelled');
      final normalizedStoreId = storeId?.trim();
      if (normalizedStoreId != null && normalizedStoreId.isNotEmpty) {
        query = query.eq('store_id', normalizedStoreId);
      } else {
        query = query.filter('store_id', 'is', null);
      }
      final response = await query.maybeSingle();
      if (response == null) return null;
      return SellerPayout.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<SellerPayout?> _fetchSellerPayoutById(String payoutId) async {
    try {
      final response = await _supabase
          .from(_sellerPayoutsTable)
          .select()
          .eq('id', payoutId)
          .maybeSingle();
      if (response == null) return null;
      return SellerPayout.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  String? _missingSellerApplicationColumn(Object error) {
    if (error is! PostgrestException || error.code != 'PGRST204') {
      return null;
    }

    final details = '${error.details ?? ''}';
    final message = error.message;
    final combined = '$message $details';
    final exactMatch = RegExp(
      r"'([^']+)' column of 'seller_applications'",
    ).firstMatch(combined);
    if (exactMatch != null) {
      return exactMatch.group(1);
    }

    for (final key in const [
      'approved_at',
      'rejected_at',
      'rejection_reason',
    ]) {
      if (combined.contains(key)) {
        return key;
      }
    }
    return null;
  }

  Future<void> _updateSellerApplicationRecord(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final fallbackUpdates = Map<String, dynamic>.from(updates);
    while (true) {
      try {
        await _supabase
            .from('seller_applications')
            .update(fallbackUpdates)
            .eq('id', id);
        return;
      } on PostgrestException catch (error) {
        final missingColumn = _missingSellerApplicationColumn(error);
        if (missingColumn == null ||
            !fallbackUpdates.containsKey(missingColumn)) {
          rethrow;
        }
        fallbackUpdates.remove(missingColumn);
      }
    }
  }

  Future<AdminSystemMetrics> getSystemMetrics() async {
    final now = DateTime.now().toUtc();
    final last24Hours = now
        .subtract(const Duration(hours: 24))
        .toIso8601String();
    final last30Days = now.subtract(const Duration(days: 30)).toIso8601String();
    final startOfToday = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).toIso8601String();

    var totalChecks = 0;
    var successfulChecks = 0;
    void markCheckSuccess() => successfulChecks++;

    Future<int> trackedCount(Future<int> Function() action) async {
      totalChecks++;
      return _safeCount(action, onSuccess: markCheckSuccess);
    }

    Future<Map<String, dynamic>?> trackedSingle(
      Future<Map<String, dynamic>?> Function() action,
    ) async {
      totalChecks++;
      return _safeSingle(action, onSuccess: markCheckSuccess);
    }

    Future<List<Map<String, dynamic>>> trackedList(
      Future<List<Map<String, dynamic>>> Function() action,
    ) async {
      totalChecks++;
      return _safeList(action, onSuccess: markCheckSuccess);
    }

    final results = await Future.wait<dynamic>([
      trackedCount(() => _supabase.from('users').count(CountOption.exact)),
      trackedCount(
        () => _supabase
            .from('users')
            .count(CountOption.exact)
            .eq('role', 'seller'),
      ),
      trackedCount(
        () => _supabase
            .from('ihiz_courier_applications')
            .count(CountOption.exact)
            .eq('status', 'approved'),
      ),
      trackedCount(
        () => _supabase
            .from('users')
            .count(CountOption.exact)
            .gte('updated_at', last24Hours),
      ),
      trackedCount(
        () => _supabase
            .from('users')
            .count(CountOption.exact)
            .gte('updated_at', last30Days),
      ),
      trackedCount(() => _supabase.from('stores').count(CountOption.exact)),
      trackedCount(
        () => _supabase
            .from('stores')
            .count(CountOption.exact)
            .eq('is_store_open', true),
      ),
      trackedCount(() => _supabase.from('products').count(CountOption.exact)),
      trackedCount(
        () =>
            _supabase.from('products').count(CountOption.exact).eq('stock', 0),
      ),
      trackedCount(
        () => _supabase
            .from('products')
            .count(CountOption.exact)
            .gt('stock', 0)
            .lt('stock', 10),
      ),
      trackedCount(() => _supabase.from('orders').count(CountOption.exact)),
      trackedCount(
        () => _supabase
            .from('orders')
            .count(CountOption.exact)
            .gte('created_at', startOfToday),
      ),
      trackedCount(
        () => _supabase
            .from('seller_applications')
            .count(CountOption.exact)
            .eq('status', 'pending'),
      ),
      trackedCount(
        () => _supabase
            .from('store_deletion_requests')
            .count(CountOption.exact)
            .eq('status', 'pending'),
      ),
      trackedCount(
        () => _supabase
            .from('support_tickets')
            .count(CountOption.exact)
            .inFilter('status', ['open', 'in_progress']),
      ),
      trackedCount(
        () => _supabase
            .from('user_notifications')
            .count(CountOption.exact)
            .gte('created_at', startOfToday),
      ),
      trackedList(
        () async => List<Map<String, dynamic>>.from(
          await _supabase
              .from('orders')
              .select('order_number,status,created_at')
              .order('created_at', ascending: false)
              .limit(3),
        ),
      ),
      trackedList(
        () async => List<Map<String, dynamic>>.from(
          await _supabase
              .from('support_tickets')
              .select('subject,status,priority,created_at')
              .order('created_at', ascending: false)
              .limit(3),
        ),
      ),
      trackedList(
        () async => List<Map<String, dynamic>>.from(
          await _supabase
              .from('seller_applications')
              .select('business_name,status,created_at')
              .order('created_at', ascending: false)
              .limit(3),
        ),
      ),
      trackedSingle(
        () async => await _supabase
            .from('users')
            .select('updated_at')
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle(),
      ),
      trackedSingle(
        () async => await _supabase
            .from('orders')
            .select('created_at')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle(),
      ),
    ]);

    final totalUsers = results[0] as int;
    final totalSellers = results[1] as int;
    final approvedIhizCouriers = results[2] as int;
    final activeUsers24h = results[3] as int;
    final activeUsers30d = results[4] as int;
    final totalStores = results[5] as int;
    final openStores = results[6] as int;
    final totalProducts = results[7] as int;
    final outOfStockProducts = results[8] as int;
    final lowStockProducts = results[9] as int;
    final totalOrders = results[10] as int;
    final todayOrders = results[11] as int;
    final pendingSellerApplications = results[12] as int;
    final pendingStoreDeletionRequests = results[13] as int;
    final openSupportTickets = results[14] as int;
    final notificationsToday = results[15] as int;
    final recentOrders = results[16] as List<Map<String, dynamic>>;
    final recentSupportTickets = results[17] as List<Map<String, dynamic>>;
    final recentSellerApplications = results[18] as List<Map<String, dynamic>>;
    final latestUserRow = results[19] as Map<String, dynamic>?;
    final latestOrderRow = results[20] as Map<String, dynamic>?;

    final estimatedDatabaseKb =
        (totalUsers * 2.2) +
        (totalStores * 4.5) +
        (totalProducts * 5.8) +
        (totalOrders * 3.6) +
        (openSupportTickets * 2.4) +
        (pendingSellerApplications * 2.8) +
        (pendingStoreDeletionRequests * 1.4) +
        (notificationsToday * 0.8);
    final estimatedDatabaseMb = estimatedDatabaseKb / 1024;
    final estimatedDatabaseUsagePercent = clampAdminRatio(
      estimatedDatabaseMb / 500,
    );

    final estimatedStorageMb =
        (totalProducts * 0.45) +
        (totalStores * 1.1) +
        (pendingSellerApplications * 0.2);
    final estimatedStorageUsagePercent = clampAdminRatio(
      estimatedStorageMb / 1024,
    );
    final fallbackEgressGb = (activeUsers30d * 0.045)
        .clamp(0, 1000000)
        .toDouble();
    final fallbackRealtimeMonthlyMessages =
        (((todayOrders * 8) + (notificationsToday * 3)) * 30).clamp(0, 1 << 31);
    final fallbackEdgeMonthlyInvocations =
        (((todayOrders * 4) + (notificationsToday * 2)) * 30).clamp(0, 1 << 31);
    final supabaseQuota =
        await _getSupabaseQuotaSnapshot(
          fallbackDatabaseMb: estimatedDatabaseMb,
          fallbackStorageMb: estimatedStorageMb,
          fallbackMau: activeUsers30d,
          fallbackEgressGb: fallbackEgressGb,
          fallbackRealtimeMessagesMonthly: fallbackRealtimeMonthlyMessages,
          fallbackEdgeInvocationsMonthly: fallbackEdgeMonthlyInvocations,
        ) ??
        AdminSupabaseQuotaSnapshot(
          planName: 'free',
          fetchedAt: now,
          databaseUsedMb: estimatedDatabaseMb,
          databaseLimitMb: 500,
          storageUsedMb: estimatedStorageMb,
          storageLimitMb: 1024,
          monthlyActiveUsersUsed: activeUsers30d,
          monthlyActiveUsersLimit: 50000,
          monthlyEgressUsedGb: fallbackEgressGb,
          monthlyEgressLimitGb: 5,
          realtimeMonthlyMessagesUsed: fallbackRealtimeMonthlyMessages,
          realtimeMonthlyMessagesLimit: 2000000,
          realtimeConcurrentConnectionsLimit: 200,
          edgeMonthlyInvocationsUsed: fallbackEdgeMonthlyInvocations,
          edgeMonthlyInvocationsLimit: 500000,
          trafficIsEstimated: true,
          usersRecommendedLimit: 5000,
          storesRecommendedLimit: 1200,
          sellersRecommendedLimit: 1200,
          couriersRecommendedLimit: 500,
        );

    final queryCoverage = totalChecks == 0
        ? 0.0
        : successfulChecks / totalChecks;
    final storeSignal = totalStores == 0 ? 1.0 : openStores / totalStores;
    final activitySignal = totalUsers == 0
        ? 1.0
        : clampAdminRatio(activeUsers30d / totalUsers);
    final supportSignal = totalOrders == 0
        ? 1.0
        : clampAdminRatio(1 - (openSupportTickets / totalOrders));
    final stockSignal = totalProducts == 0
        ? 1.0
        : clampAdminRatio(
            1 -
                (((outOfStockProducts * 1.0) + (lowStockProducts * 0.5)) /
                    totalProducts),
          );

    final systemHealthPercent =
        ((queryCoverage * 0.4) +
            (storeSignal * 0.2) +
            (activitySignal * 0.15) +
            (supportSignal * 0.1) +
            (stockSignal * 0.15)) *
        100;

    final logs = <AdminSystemLogEntry>[
      ...recentOrders.map((row) {
        final orderNumber = (row['order_number'] ?? '-').toString();
        final status = (row['status'] ?? 'unknown').toString();
        return AdminSystemLogEntry(
          title: 'Siparis #$orderNumber',
          subtitle: 'Durum: $status',
          level: status.toLowerCase() == 'cancelled' ? 'warning' : 'info',
          occurredAt:
              DateTime.tryParse((row['created_at'] ?? '').toString()) ?? now,
        );
      }),
      ...recentSupportTickets.map((row) {
        final subject = (row['subject'] ?? 'Destek talebi').toString();
        final priority = (row['priority'] ?? 'medium').toString();
        final status = (row['status'] ?? 'open').toString();
        return AdminSystemLogEntry(
          title: subject,
          subtitle: 'Destek kaydi • $status • $priority',
          level: priority == 'high' ? 'critical' : 'warning',
          occurredAt:
              DateTime.tryParse((row['created_at'] ?? '').toString()) ?? now,
        );
      }),
      ...recentSellerApplications.map((row) {
        final businessName = (row['business_name'] ?? 'Satici basvurusu')
            .toString();
        final status = (row['status'] ?? 'pending').toString();
        return AdminSystemLogEntry(
          title: businessName,
          subtitle: 'Satici basvurusu • $status',
          level: status == AdminApprovalStatusConstants.pending ? 'warning' : 'info',
          occurredAt:
              DateTime.tryParse((row['created_at'] ?? '').toString()) ?? now,
        );
      }),
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    final userSignalHealthy =
        latestUserRow != null || totalUsers == 0 || activeUsers30d >= 0;
    final orderSignalHealthy =
        latestOrderRow != null || totalOrders == 0 || todayOrders >= 0;
    final storeSignalHealthy = successfulChecks > 0 && totalStores >= 0;
    final supportSignalHealthy = openSupportTickets >= 0;
    final notificationSignalHealthy = notificationsToday >= 0;

    return AdminSystemMetrics(
      totalUsers: totalUsers,
      totalSellers: totalSellers,
      approvedIhizCouriers: approvedIhizCouriers,
      activeUsers24h: activeUsers24h,
      activeUsers30d: activeUsers30d,
      totalStores: totalStores,
      openStores: openStores,
      totalProducts: totalProducts,
      lowStockProducts: lowStockProducts,
      outOfStockProducts: outOfStockProducts,
      totalOrders: totalOrders,
      todayOrders: todayOrders,
      pendingSellerApplications: pendingSellerApplications,
      pendingStoreDeletionRequests: pendingStoreDeletionRequests,
      openSupportTickets: openSupportTickets,
      notificationsToday: notificationsToday,
      estimatedDatabaseMb: estimatedDatabaseMb,
      estimatedDatabaseUsagePercent: estimatedDatabaseUsagePercent,
      estimatedStorageMb: estimatedStorageMb,
      estimatedStorageUsagePercent: estimatedStorageUsagePercent,
      systemHealthPercent: systemHealthPercent,
      dataCoveragePercent: queryCoverage * 100,
      userSignalHealthy: userSignalHealthy,
      orderSignalHealthy: orderSignalHealthy,
      storeSignalHealthy: storeSignalHealthy,
      supportSignalHealthy: supportSignalHealthy,
      notificationSignalHealthy: notificationSignalHealthy,
      logs: logs.take(5).toList(growable: false),
      supabaseQuota: supabaseQuota,
    );
  }

  Future<AdminSupabaseQuotaSnapshot?> _getSupabaseQuotaSnapshot({
    required double fallbackDatabaseMb,
    required double fallbackStorageMb,
    required int fallbackMau,
    required double fallbackEgressGb,
    required int fallbackRealtimeMessagesMonthly,
    required int fallbackEdgeInvocationsMonthly,
  }) async {
    try {
      final response = await _supabase.rpc('admin_get_supabase_usage_snapshot');
      final payload = _asAdminMap(response);
      if (payload.isEmpty) return null;

      return AdminSupabaseQuotaSnapshot(
        planName: adminNonEmptyText(payload['plan_name'], fallback: 'free'),
        fetchedAt: _parseAdminDateTime(payload['fetched_at']),
        databaseUsedMb: adminAsDouble(payload['database_used_mb']) <= 0
            ? fallbackDatabaseMb
            : adminAsDouble(payload['database_used_mb']),
        databaseLimitMb: adminAsDouble(payload['database_limit_mb']) <= 0
            ? 500
            : adminAsDouble(payload['database_limit_mb']),
        storageUsedMb: adminAsDouble(payload['storage_used_mb']) <= 0
            ? fallbackStorageMb
            : adminAsDouble(payload['storage_used_mb']),
        storageLimitMb: adminAsDouble(payload['storage_limit_mb']) <= 0
            ? 1024
            : adminAsDouble(payload['storage_limit_mb']),
        monthlyActiveUsersUsed: adminAsInt(payload['mau_used_30d']) <= 0
            ? fallbackMau
            : adminAsInt(payload['mau_used_30d']),
        monthlyActiveUsersLimit: adminAsInt(payload['mau_limit']) <= 0
            ? 50000
            : adminAsInt(payload['mau_limit']),
        monthlyEgressUsedGb:
            adminAsDouble(payload['egress_used_gb_estimate']) <= 0
            ? fallbackEgressGb
            : adminAsDouble(payload['egress_used_gb_estimate']),
        monthlyEgressLimitGb: adminAsDouble(payload['egress_limit_gb']) <= 0
            ? 5
            : adminAsDouble(payload['egress_limit_gb']),
        realtimeMonthlyMessagesUsed:
            adminAsInt(payload['realtime_messages_used_month_estimate']) <= 0
            ? fallbackRealtimeMessagesMonthly
            : adminAsInt(payload['realtime_messages_used_month_estimate']),
        realtimeMonthlyMessagesLimit:
            adminAsInt(payload['realtime_messages_limit_month']) <= 0
            ? 2000000
            : adminAsInt(payload['realtime_messages_limit_month']),
        realtimeConcurrentConnectionsLimit:
            adminAsInt(payload['realtime_concurrent_limit']) <= 0
            ? 200
            : adminAsInt(payload['realtime_concurrent_limit']),
        edgeMonthlyInvocationsUsed:
            adminAsInt(payload['edge_invocations_used_month_estimate']) <= 0
            ? fallbackEdgeInvocationsMonthly
            : adminAsInt(payload['edge_invocations_used_month_estimate']),
        edgeMonthlyInvocationsLimit:
            adminAsInt(payload['edge_invocations_limit_month']) <= 0
            ? 500000
            : adminAsInt(payload['edge_invocations_limit_month']),
        trafficIsEstimated:
            payload['traffic_is_estimated'] == true ||
            payload['egress_used_gb_estimate'] == null,
        usersRecommendedLimit:
            adminAsInt(payload['users_recommended_limit']) <= 0
            ? 5000
            : adminAsInt(payload['users_recommended_limit']),
        storesRecommendedLimit:
            adminAsInt(payload['stores_recommended_limit']) <= 0
            ? 1200
            : adminAsInt(payload['stores_recommended_limit']),
        sellersRecommendedLimit:
            adminAsInt(payload['sellers_recommended_limit']) <= 0
            ? 1200
            : adminAsInt(payload['sellers_recommended_limit']),
        couriersRecommendedLimit:
            adminAsInt(payload['couriers_recommended_limit']) <= 0
            ? 500
            : adminAsInt(payload['couriers_recommended_limit']),
      );
    } catch (error) {
      debugPrint('AdminService: quota rpc failed: $error');
      return AdminSupabaseQuotaSnapshot(
        planName: 'free',
        fetchedAt: DateTime.now(),
        databaseUsedMb: fallbackDatabaseMb,
        databaseLimitMb: 500,
        storageUsedMb: fallbackStorageMb,
        storageLimitMb: 1024,
        monthlyActiveUsersUsed: fallbackMau,
        monthlyActiveUsersLimit: 50000,
        monthlyEgressUsedGb: fallbackEgressGb,
        monthlyEgressLimitGb: 5,
        realtimeMonthlyMessagesUsed: fallbackRealtimeMessagesMonthly,
        realtimeMonthlyMessagesLimit: 2000000,
        realtimeConcurrentConnectionsLimit: 200,
        edgeMonthlyInvocationsUsed: fallbackEdgeInvocationsMonthly,
        edgeMonthlyInvocationsLimit: 500000,
        trafficIsEstimated: true,
        usersRecommendedLimit: 5000,
        storesRecommendedLimit: 1200,
        sellersRecommendedLimit: 1200,
        couriersRecommendedLimit: 500,
      );
    }
  }

  Future<AdminUserAnalyticsSnapshot> getUserAnalyticsSnapshot() async {
    final now = DateTime.now().toUtc();
    final last24Hours = now
        .subtract(const Duration(hours: 24))
        .toIso8601String();
    final last7Days = now.subtract(const Duration(days: 7)).toIso8601String();
    final last30Days = now.subtract(const Duration(days: 30)).toIso8601String();

    final results = await Future.wait<dynamic>([
      _safeCount(() => _supabase.from('users').count(CountOption.exact)),
      _safeCount(
        () => _supabase
            .from('users')
            .count(CountOption.exact)
            .gte('updated_at', last24Hours),
      ),
      _safeCount(
        () => _supabase
            .from('users')
            .count(CountOption.exact)
            .gte('updated_at', last30Days),
      ),
      _safeCount(
        () => _supabase
            .from('users')
            .count(CountOption.exact)
            .gte('created_at', last7Days),
      ),
      _safeList(
        () async => List<Map<String, dynamic>>.from(
          await _supabase
              .from('orders')
              .select(
                'user_id,total_amount,created_at,delivery_type,delivery_address',
              )
              .gte('created_at', last30Days)
              .order('created_at', ascending: false)
              .limit(4000),
        ),
      ),
      _safeList(
        () async => List<Map<String, dynamic>>.from(
          await _supabase
              .from('users')
              .select('id,email,display_name,created_at,updated_at')
              .order('updated_at', ascending: false)
              .limit(8),
        ),
      ),
      getUserGrowthTimeline(months: 6),
    ]);

    final totalUsers = results[0] as int;
    final activeUsers24h = results[1] as int;
    final activeUsers30d = results[2] as int;
    final newUsers7d = results[3] as int;
    final orders30dRows = results[4] as List<Map<String, dynamic>>;
    final recentUsersRows = results[5] as List<Map<String, dynamic>>;
    final userGrowth = results[6] as List<AdminTimelinePoint>;

    final cityCounts = <String, int>{};
    final deliveryTypeCounts = <String, int>{};
    final orderCountByUser = <String, int>{};
    final mostRecentCityByUser = <String, String>{};
    var totalAmount = 0.0;

    for (final row in orders30dRows) {
      final userId = (row['user_id'] ?? '').toString().trim();
      final deliveryType = _humanizeDeliveryType(row['delivery_type']);
      final city = extractAdminCityFromAddress(row['delivery_address']);

      deliveryTypeCounts[deliveryType] =
          (deliveryTypeCounts[deliveryType] ?? 0) + 1;
      cityCounts[city] = (cityCounts[city] ?? 0) + 1;
      totalAmount += (row['total_amount'] as num?)?.toDouble() ?? 0;

      if (userId.isEmpty) continue;
      orderCountByUser[userId] = (orderCountByUser[userId] ?? 0) + 1;
      mostRecentCityByUser.putIfAbsent(userId, () => city);
    }

    final buyers30d = orderCountByUser.length;
    final repeatBuyerCount = orderCountByUser.values
        .where((count) => count > 1)
        .length;
    final orders30d = orders30dRows.length;

    final recentUsers = recentUsersRows
        .map((row) {
          final userId = (row['id'] ?? '').toString().trim();
          final email = (row['email'] ?? '').toString().trim();
          final displayName = (row['display_name'] ?? '').toString().trim();
          return AdminRecentUserActivity(
            name: displayName.isNotEmpty
                ? displayName
                : adminNameFromEmail(email),
            email: email,
            createdAt: _parseAdminDateTime(row['created_at']),
            lastSeenAt: _parseAdminDateTime(row['updated_at']),
            orderCount30d: orderCountByUser[userId] ?? 0,
            city: mostRecentCityByUser[userId] ?? 'Henuz siparis yok',
          );
        })
        .toList(growable: false);

    return AdminUserAnalyticsSnapshot(
      totalUsers: totalUsers,
      activeUsers24h: activeUsers24h,
      activeUsers30d: activeUsers30d,
      newUsers7d: newUsers7d,
      buyers30d: buyers30d,
      orders30d: orders30d,
      repeatBuyerRate: buyers30d == 0 ? 0 : repeatBuyerCount / buyers30d,
      averageOrderValue: orders30d == 0 ? 0 : totalAmount / orders30d,
      topCities: _buildSlices(cityCounts, limit: 5),
      deliveryTypes: _buildSlices(deliveryTypeCounts, limit: 4),
      activityBands: _buildSlices({
        'Son 24 saat aktif': activeUsers24h,
        'Son 30 gun aktif': activeUsers30d,
        'Geri kazanilabilir': totalUsers > activeUsers30d
            ? totalUsers - activeUsers30d
            : 0,
      }, limit: 3),
      recentUsers: recentUsers,
      userGrowth: userGrowth,
    );
  }

  Future<AdminStoreAnalyticsSnapshot> getStoreAnalyticsSnapshot() async {
    final now = DateTime.now().toUtc();
    final last30Days = now.subtract(const Duration(days: 30)).toIso8601String();

    final results = await Future.wait<dynamic>([
      _safeCount(() => _supabase.from('stores').count(CountOption.exact)),
      _safeCount(
        () => _supabase
            .from('stores')
            .count(CountOption.exact)
            .eq('is_store_open', true),
      ),
      _safeCount(
        () => _supabase
            .from('stores')
            .count(CountOption.exact)
            .gte('created_at', last30Days),
      ),
      _safeCount(() => _supabase.from('products').count(CountOption.exact)),
      _safeList(
        () async => List<Map<String, dynamic>>.from(
          await _supabase
              .from('stores')
              .select(
                'seller_id,business_name,category,city,is_store_open,rating,created_at',
              )
              .order('created_at', ascending: false)
              .limit(2000),
        ),
      ),
      _safeList(
        () async => List<Map<String, dynamic>>.from(
          await _supabase
              .from('products')
              .select('seller_id,stock,status')
              .limit(6000),
        ),
      ),
      _safeList(
        () async => List<Map<String, dynamic>>.from(
          await _supabase
              .from('order_items')
              .select('seller_id,store_name,total_price,created_at')
              .gte('created_at', last30Days)
              .order('created_at', ascending: false)
              .limit(5000),
        ),
      ),
    ]);

    final totalStores = results[0] as int;
    final openStores = results[1] as int;
    final newStores30d = results[2] as int;
    final totalProducts = results[3] as int;
    final storeRows = results[4] as List<Map<String, dynamic>>;
    final productRows = results[5] as List<Map<String, dynamic>>;
    final orderRows = results[6] as List<Map<String, dynamic>>;

    final categoryCounts = <String, int>{};
    final cityCounts = <String, int>{};
    final productCountBySeller = <String, int>{};
    final lowStockSellers = <String>{};
    final revenueBySeller = <String, double>{};
    final orderCountBySeller = <String, int>{};
    var ratingSum = 0.0;
    var ratingCount = 0;

    for (final row in storeRows) {
      final category = adminNonEmptyText(
        row['category'],
        fallback: 'Kategori yok',
      );
      final city = adminNonEmptyText(row['city'], fallback: 'Sehir yok');
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      cityCounts[city] = (cityCounts[city] ?? 0) + 1;

      final rating = adminAsDouble(row['rating']);
      if (rating > 0) {
        ratingSum += rating;
        ratingCount++;
      }
    }

    for (final row in productRows) {
      final sellerId = (row['seller_id'] ?? '').toString().trim();
      if (sellerId.isEmpty) continue;
      productCountBySeller[sellerId] =
          (productCountBySeller[sellerId] ?? 0) + 1;
      final stock = (row['stock'] as num?)?.toInt() ?? 0;
      if (stock < 10) {
        lowStockSellers.add(sellerId);
      }
    }

    for (final row in orderRows) {
      final sellerId = (row['seller_id'] ?? '').toString().trim();
      if (sellerId.isEmpty) continue;
      revenueBySeller[sellerId] =
          (revenueBySeller[sellerId] ?? 0) +
          ((row['total_price'] as num?)?.toDouble() ?? 0);
      orderCountBySeller[sellerId] = (orderCountBySeller[sellerId] ?? 0) + 1;
    }

    final topStores =
        storeRows.map((row) {
          final sellerId = (row['seller_id'] ?? '').toString().trim();
          return AdminStorePerformance(
            storeName: adminNonEmptyText(
              row['business_name'],
              fallback: 'Isimsiz magaza',
            ),
            city: adminNonEmptyText(row['city'], fallback: 'Sehir yok'),
            category: adminNonEmptyText(
              row['category'],
              fallback: 'Kategori yok',
            ),
            isOpen: row['is_store_open'] == true,
            rating: adminAsDouble(row['rating']),
            productCount: productCountBySeller[sellerId] ?? 0,
            orderCount30d: orderCountBySeller[sellerId] ?? 0,
            revenue30d: revenueBySeller[sellerId] ?? 0,
          );
        }).toList()..sort((a, b) {
          final revenueCompare = b.revenue30d.compareTo(a.revenue30d);
          if (revenueCompare != 0) return revenueCompare;
          return b.orderCount30d.compareTo(a.orderCount30d);
        });

    final storesWithoutProducts = storeRows.where((row) {
      final sellerId = (row['seller_id'] ?? '').toString().trim();
      return (productCountBySeller[sellerId] ?? 0) == 0;
    }).length;

    return AdminStoreAnalyticsSnapshot(
      totalStores: totalStores,
      openStores: openStores,
      newStores30d: newStores30d,
      totalProducts: totalProducts,
      averageProductsPerStore: totalStores == 0
          ? 0
          : totalProducts / totalStores,
      averageRating: ratingCount == 0 ? 0 : ratingSum / ratingCount,
      lowStockStores: lowStockSellers.length,
      storesWithoutProducts: storesWithoutProducts,
      topCategories: _buildSlices(categoryCounts, limit: 5),
      topCities: _buildSlices(cityCounts, limit: 5),
      topStores: topStores.take(5).toList(growable: false),
    );
  }

  Future<AdminCargoAnalyticsSnapshot> getCargoAnalyticsSnapshot() async {
    final now = DateTime.now().toUtc();
    final last60Days = now.subtract(const Duration(days: 60)).toIso8601String();
    final rows = await _safeList(
      () async => List<Map<String, dynamic>>.from(
        await _supabase
            .from('order_items')
            .select(
              'store_name,cargo_company,status,shipment_step,tracking_number,created_at',
            )
            .gte('created_at', last60Days)
            .order('created_at', ascending: false)
            .limit(5000),
      ),
    );

    final companyCounts = <String, int>{};
    final statusCounts = <String, int>{};
    final recentShipments = <AdminCargoShipment>[];
    var deliveredShipments = 0;
    var inTransitShipments = 0;
    var preparingShipments = 0;
    var problemShipments = 0;
    var delayedShipments = 0;
    var trackedShipments = 0;

    for (final row in rows) {
      final createdAt = _parseAdminDateTime(row['created_at']);
      final company = adminNonEmptyText(
        row['cargo_company'],
        fallback: 'Atanmamis',
      );
      final stateLabel = _shipmentStateLabel(
        row['shipment_step'],
        row['status'],
      );
      final trackingNumber = (row['tracking_number'] ?? '').toString().trim();
      final hasTracking = trackingNumber.isNotEmpty;
      if (hasTracking) trackedShipments++;

      companyCounts[company] = (companyCounts[company] ?? 0) + 1;
      statusCounts[stateLabel] = (statusCounts[stateLabel] ?? 0) + 1;

      if (stateLabel == 'Teslim edildi') {
        deliveredShipments++;
      } else if (stateLabel == 'Yolda' || stateLabel == 'Dagitimda') {
        inTransitShipments++;
      } else if (stateLabel == 'Hazirlaniyor' || stateLabel == 'Hazirlandi') {
        preparingShipments++;
      } else if (stateLabel == 'Sorunlu / Iade') {
        problemShipments++;
      }

      if (createdAt != null &&
          stateLabel != 'Teslim edildi' &&
          now.difference(createdAt).inHours >= 48) {
        delayedShipments++;
      }

      if (recentShipments.length < 6) {
        recentShipments.add(
          AdminCargoShipment(
            storeName: adminNonEmptyText(
              row['store_name'],
              fallback: 'Magaza bilgisi yok',
            ),
            cargoCompany: company,
            stateLabel: stateLabel,
            createdAt: createdAt,
            hasTracking: hasTracking,
            trackingNumber: trackingNumber,
          ),
        );
      }
    }

    return AdminCargoAnalyticsSnapshot(
      windowLabel: 'Son 60 gun',
      totalShipments: rows.length,
      deliveredShipments: deliveredShipments,
      inTransitShipments: inTransitShipments,
      preparingShipments: preparingShipments,
      problemShipments: problemShipments,
      delayedShipments: delayedShipments,
      trackingCoverage: rows.isEmpty ? 0 : trackedShipments / rows.length,
      companyBreakdown: _buildSlices(companyCounts, limit: 5),
      statusBreakdown: _buildSlices(statusCounts, limit: 5),
      recentShipments: recentShipments,
    );
  }

  Future<AdminIhizSnapshot> getIhizOperationsSnapshot() async {
    final now = DateTime.now().toUtc();
    final last45Days = now.subtract(const Duration(days: 45)).toIso8601String();
    final rows = await _safeList(
      () async => List<Map<String, dynamic>>.from(
        await _supabase
            .from('order_items')
            .select(
              'id,store_name,product_name,status,shipment_step,cargo_company,tracking_number,created_at,updated_at',
            )
            .gte('created_at', last45Days)
            .order('created_at', ascending: false)
            .limit(8000),
      ),
    );

    final ihizRows = rows.where(_isIhizOrderItem).toList(growable: false);
    final statusCounts = <String, int>{};
    final recent = <AdminIhizShipment>[];

    var readyPoolCount = 0;
    var inTransitCount = 0;
    var delivered24hCount = 0;
    var problemCount = 0;
    var delayedOpenCount = 0;
    var branchTransferCount = 0;
    var trackedCount = 0;

    for (final row in ihizRows) {
      final stateLabel = _shipmentStateLabel(
        row['shipment_step'],
        row['status'],
      );
      final shipmentStep = (row['shipment_step'] ?? '').toString().trim();
      final createdAt = _parseAdminDateTime(row['created_at']);
      final updatedAt = _parseAdminDateTime(row['updated_at']);
      final activityAt = updatedAt ?? createdAt;
      final trackingNumber = (row['tracking_number'] ?? '').toString().trim();
      final hasTracking = trackingNumber.isNotEmpty;

      if (hasTracking) trackedCount++;
      statusCounts[stateLabel] = (statusCounts[stateLabel] ?? 0) + 1;

      final normalizedStep = shipmentStep.toLowerCase();
      if (stateLabel == 'Hazirlandi') {
        readyPoolCount++;
      }
      if (stateLabel == 'Dagitimda' || stateLabel == 'Yolda') {
        inTransitCount++;
      }
      if (normalizedStep == 'branch') {
        branchTransferCount++;
      }
      if (stateLabel == 'Sorunlu / Iade') {
        problemCount++;
      }
      if (stateLabel == 'Teslim edildi' &&
          activityAt != null &&
          now.difference(activityAt).inHours <= 24) {
        delivered24hCount++;
      }
      final isOpenFlow =
          stateLabel != 'Teslim edildi' && stateLabel != 'Sorunlu / Iade';
      if (isOpenFlow &&
          createdAt != null &&
          now.difference(createdAt).inHours >= 48) {
        delayedOpenCount++;
      }

      if (recent.length < 14) {
        recent.add(
          AdminIhizShipment(
            id: (row['id'] ?? '').toString(),
            storeName: adminNonEmptyText(row['store_name'], fallback: 'Magaza'),
            productName: adminNonEmptyText(
              row['product_name'],
              fallback: 'Urun',
            ),
            cargoCompany: adminNonEmptyText(
              row['cargo_company'],
              fallback: 'Ihiz',
            ),
            statusLabel: stateLabel,
            shipmentStep: shipmentStep,
            createdAt: createdAt,
            hasTracking: hasTracking,
            trackingNumber: trackingNumber,
          ),
        );
      }
    }

    return AdminIhizSnapshot(
      windowLabel: 'Son 45 gun',
      totalIhizShipments: ihizRows.length,
      readyPoolCount: readyPoolCount,
      inTransitCount: inTransitCount,
      delivered24hCount: delivered24hCount,
      problemCount: problemCount,
      delayedOpenCount: delayedOpenCount,
      branchTransferCount: branchTransferCount,
      trackingCoverage: ihizRows.isEmpty ? 0 : trackedCount / ihizRows.length,
      ihizShareRatio: rows.isEmpty ? 0 : ihizRows.length / rows.length,
      statusBreakdown: _buildSlices(statusCounts, limit: 6),
      recentShipments: recent,
    );
  }

  Future<List<AdminTimelinePoint>> getUserGrowthTimeline({
    int months = 6,
  }) async {
    final monthStarts = _adminMonthStarts(months);
    final start = monthStarts.first.toIso8601String();
    final rows = await _safeList(
      () async => List<Map<String, dynamic>>.from(
        await _supabase
            .from('users')
            .select('created_at,updated_at')
            .gte('updated_at', start)
            .order('updated_at', ascending: false)
            .limit(8000),
      ),
    );

    final createdCounts = <String, int>{};
    final activeCounts = <String, int>{};

    for (final row in rows) {
      final createdAt = _parseAdminDateTime(row['created_at']);
      if (createdAt != null && !createdAt.isBefore(monthStarts.first)) {
        final key = _adminMonthKey(createdAt);
        createdCounts[key] = (createdCounts[key] ?? 0) + 1;
      }

      final updatedAt = _parseAdminDateTime(row['updated_at']);
      if (updatedAt != null && !updatedAt.isBefore(monthStarts.first)) {
        final key = _adminMonthKey(updatedAt);
        activeCounts[key] = (activeCounts[key] ?? 0) + 1;
      }
    }

    return monthStarts
        .map((monthStart) {
          final key = _adminMonthKey(monthStart);
          return AdminTimelinePoint(
            label: _adminMonthLabel(monthStart),
            primaryValue: createdCounts[key] ?? 0,
            secondaryValue: activeCounts[key] ?? 0,
          );
        })
        .toList(growable: false);
  }

  Future<List<AdminTimelinePoint>> getStoreParticipationTimeline({
    int months = 6,
  }) async {
    final monthStarts = _adminMonthStarts(months);
    final start = monthStarts.first.toIso8601String();
    final rows = await _safeList(
      () async => List<Map<String, dynamic>>.from(
        await _supabase
            .from('stores')
            .select('created_at,is_store_open')
            .gte('created_at', start)
            .order('created_at', ascending: false)
            .limit(5000),
      ),
    );

    final joinedCounts = <String, int>{};
    final openCounts = <String, int>{};

    for (final row in rows) {
      final createdAt = _parseAdminDateTime(row['created_at']);
      if (createdAt == null || createdAt.isBefore(monthStarts.first)) {
        continue;
      }
      final key = _adminMonthKey(createdAt);
      joinedCounts[key] = (joinedCounts[key] ?? 0) + 1;
      if (row['is_store_open'] == true) {
        openCounts[key] = (openCounts[key] ?? 0) + 1;
      }
    }

    return monthStarts
        .map((monthStart) {
          final key = _adminMonthKey(monthStart);
          return AdminTimelinePoint(
            label: _adminMonthLabel(monthStart),
            primaryValue: joinedCounts[key] ?? 0,
            secondaryValue: openCounts[key] ?? 0,
          );
        })
        .toList(growable: false);
  }

  List<AdminAnalyticsSlice> _buildSlices(
    Map<String, int> source, {
    required int limit,
  }) {
    return buildAdminAnalyticsBuckets(source, limit: limit)
        .map(
          (entry) => AdminAnalyticsSlice(
            label: entry.label,
            value: entry.value,
            share: entry.share,
          ),
        )
        .toList(growable: false);
  }

  Map<String, dynamic> _asAdminMap(dynamic value) {
    return asAdminMap(value);
  }

  DateTime? _parseAdminDateTime(dynamic raw) {
    return parseAdminDateTime(raw);
  }

  List<DateTime> _adminMonthStarts(int months) {
    return adminMonthStarts(months);
  }

  String _adminMonthKey(DateTime date) => adminMonthKey(date);

  String _adminMonthLabel(DateTime date) => adminMonthLabel(date);

  String _humanizeDeliveryType(dynamic raw) {
    return humanizeAdminDeliveryType(raw, adminTitleCase);
  }

  String _shipmentStateLabel(dynamic shipmentStep, dynamic status) {
    return shipmentStateLabel(shipmentStep, status);
  }

  bool _isIhizOrderItem(Map<String, dynamic> row) {
    return isIhizOrderItem(row);
  }

  Future<List<Map<String, dynamic>>> searchUsersByEmail(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];

    final response = await _supabase
        .from('users')
        .select('id,email,display_name,role,updated_at')
        .ilike('email', '%$normalized%')
        .order('updated_at', ascending: false)
        .limit(12);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<AdminInvestmentEntry>> getInvestmentEntries() async {
    try {
      final response = await _supabase
          .from(_investmentEntriesTable)
          .select()
          .order('investment_date', ascending: true)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(
        response,
      ).map(AdminInvestmentEntry.fromMap).toList();
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<List<AdminInvestmentAllocation>> getInvestmentAllocations() async {
    try {
      final response = await _supabase
          .from(_investmentAllocationsTable)
          .select()
          .order('spent_at', ascending: true)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(
        response,
      ).map(AdminInvestmentAllocation.fromMap).toList();
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<AdminInvestmentEntry> createInvestmentEntry({
    required String source,
    required double amount,
    required DateTime investmentDate,
  }) async {
    final actorId = _supabase.auth.currentUser?.id;
    try {
      final response = await _supabase
          .from(_investmentEntriesTable)
          .insert({
            'source': source.trim(),
            'amount': amount,
            'investment_date': investmentDate.toIso8601String(),
            'created_by': actorId,
          })
          .select()
          .single();
      return AdminInvestmentEntry.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<AdminInvestmentEntry> upsertInvestmentEntry({
    String? id,
    required String source,
    required double amount,
    required DateTime investmentDate,
  }) async {
    final actorId = _supabase.auth.currentUser?.id;
    final payload = <String, dynamic>{
      if (id != null && id.isNotEmpty) 'id': id,
      'source': source.trim(),
      'amount': amount,
      'investment_date': investmentDate.toIso8601String(),
      'created_by': actorId,
    };
    try {
      final response = await _supabase
          .from(_investmentEntriesTable)
          .upsert(payload)
          .select()
          .single();
      return AdminInvestmentEntry.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<AdminInvestmentAllocation> upsertInvestmentAllocation({
    String? id,
    required String category,
    required double amount,
    required DateTime spentAt,
    String note = '',
  }) async {
    final actorId = _supabase.auth.currentUser?.id;
    final payload = <String, dynamic>{
      if (id != null && id.isNotEmpty) 'id': id,
      'category': category.trim(),
      'amount': amount,
      'spent_at': spentAt.toIso8601String(),
      'note': note.trim(),
      'created_by': actorId,
    };
    try {
      final response = await _supabase
          .from(_investmentAllocationsTable)
          .upsert(payload)
          .select()
          .single();
      return AdminInvestmentAllocation.fromMap(
        Map<String, dynamic>.from(response),
      );
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<void> deleteInvestmentAllocation(String allocationId) async {
    try {
      await _supabase
          .from(_investmentAllocationsTable)
          .delete()
          .eq('id', allocationId);
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<void> deleteInvestmentEntry(String entryId) async {
    try {
      await _supabase.from(_investmentEntriesTable).delete().eq('id', entryId);
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<List<AdminExpense>> fetchAdminExpenses({
    DateTime? from,
    DateTime? toExclusive,
  }) async {
    try {
      dynamic query = _supabase.from(_adminExpensesTable).select();
      if (from != null) {
        query = query.gte(
          'expense_date',
          AdminExpense.formatDate(from),
        );
      }
      if (toExclusive != null) {
        query = query.lt(
          'expense_date',
          AdminExpense.formatDate(toExclusive),
        );
      }
      final response = await query.order('expense_date', ascending: false);
      return List<Map<String, dynamic>>.from(response)
          .map(AdminExpense.fromMap)
          .toList();
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<void> logFinanceExpenseAccessDebug() async {
    final uid = _supabase.auth.currentUser?.id;
    debugPrint('[FinanceExpense] auth.uid=$uid');
    if (uid == null) return;
    try {
      final userRow = await _supabase
          .from('users')
          .select('role')
          .eq('id', uid)
          .maybeSingle();
      debugPrint('[FinanceExpense] users.role=${userRow?['role']}');
      final perms = await _supabase
          .from('admin_user_permissions')
          .select('role_key,allowed_modules,denied_modules,is_active')
          .eq('user_id', uid)
          .maybeSingle();
      debugPrint('[FinanceExpense] admin_user_permissions=$perms');
      try {
        final debug = await _supabase.rpc('debug_admin_finance_access');
        debugPrint('[FinanceExpense] debug_admin_finance_access=$debug');
      } catch (rpcError) {
        debugPrint('[FinanceExpense] debug_admin_finance_access unavailable: $rpcError');
      }
    } catch (error) {
      debugPrint('[FinanceExpense] access probe failed: $error');
    }
  }

  Future<String> _financeInsertErrorMessage({
    required Object error,
    required String rpcName,
  }) async {
    if (error is PostgrestException) {
      if (error.code == 'PGRST202' ||
          error.message.toLowerCase().contains('could not find') ||
          error.message.contains(rpcName)) {
        return "Supabase'de $rpcName fonksiyonu yok. "
            'ibul_app/SUPABASE_FINANCE_INSERT_HOTFIX.sql dosyasını SQL Editor\'da çalıştırın.';
      }
      if (error.code == '42501' ||
          error.message.toLowerCase().contains('permission denied')) {
        try {
          final debug = await _supabase.rpc('debug_admin_finance_access');
          final debugMap = Map<String, dynamic>.from(debug as Map);
          final userRole = (debugMap['user_role'] ?? '').toString();
          final permissionRole =
              (debugMap['permission_role_key'] ?? '').toString();
          final effectiveRole = (debugMap['effective_role'] ?? '').toString();
          if (userRole == 'postgres' ||
              userRole == 'user' ||
              userRole == 'seller') {
            return 'Finans kaydı kaydedilemedi: users.role="$userRole" geçersiz. '
                'SUPABASE_FINANCE_INSERT_HOTFIX.sql dosyasını tekrar çalıştırın '
                '(admin_user_permissions rolünü otomatik düzeltir). '
                'İzin rolü: ${permissionRole.isEmpty ? "yok" : permissionRole}. '
                'Debug: $debug';
          }
          return 'Finans kaydı kaydedilemedi: yetki reddedildi. '
              'Etkin rol: ${effectiveRole.isEmpty ? userRole : effectiveRole}. '
              'Debug: $debug';
        } catch (_) {
          return 'Finans kaydı kaydedilemedi: yetki reddedildi (RLS). '
              'SUPABASE_FINANCE_INSERT_HOTFIX.sql dosyasını uygulayın.';
        }
      }
      if (error.code == 'PGRST205' ||
          error.message.contains(_adminExpensesTable) ||
          error.message.contains(_adminRevenuesTable)) {
        return _friendlyFinanceSchemaException().toString().replaceFirst('Exception: ', '');
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  bool _isFinanceRpcOrPermissionError(Object error) {
    if (error is! PostgrestException) return false;
    return error.code == '42501' ||
        error.code == 'PGRST202' ||
        error.message.toLowerCase().contains('permission denied') ||
        error.message.toLowerCase().contains('could not find');
  }

  Future<AdminExpense> createAdminExpense({
    required String title,
    required String category,
    required double amount,
    required DateTime expenseDate,
    required String type,
    String? recurrence,
    required String status,
    String? paymentMethod,
    String? vendor,
    String? invoiceUrl,
    String? note,
  }) async {
    _validateAdminExpenseInput(
      title: title,
      category: category,
      amount: amount,
      type: type,
      status: status,
      recurrence: recurrence,
    );
    final actorId = _supabase.auth.currentUser?.id;
    final payload = <String, dynamic>{
      'title': title.trim(),
      'category': category.trim(),
      'amount': amount,
      'expense_date': AdminExpense.formatDate(expenseDate),
      'type': type,
      'recurrence': type == 'recurring' ? recurrence : null,
      'status': status,
      'payment_method': paymentMethod?.trim(),
      'vendor': vendor?.trim(),
      'invoice_url': invoiceUrl?.trim(),
      'note': note?.trim(),
      'created_by': ?actorId,
    };
    try {
      final rpcResponse = await _supabase.rpc(
        'admin_insert_expense',
        params: {
          'p_title': payload['title'],
          'p_category': payload['category'],
          'p_amount': payload['amount'],
          'p_expense_date': payload['expense_date'],
          'p_type': payload['type'],
          'p_recurrence': payload['recurrence'],
          'p_status': payload['status'],
          'p_payment_method': payload['payment_method'],
          'p_vendor': payload['vendor'],
          'p_invoice_url': payload['invoice_url'],
          'p_note': payload['note'],
        },
      );
      return AdminExpense.fromMap(Map<String, dynamic>.from(rpcResponse as Map));
    } catch (rpcError) {
      debugPrint('[FinanceExpense] RPC failed: $rpcError');
      if (_isFinanceRpcOrPermissionError(rpcError)) {
        await _logFinanceInsertFailure(
          table: _adminExpensesTable,
          payload: payload,
          error: rpcError,
        );
        throw Exception(
          await _financeInsertErrorMessage(
            error: rpcError,
            rpcName: 'admin_insert_expense',
          ),
        );
      }
      try {
        final response = await _supabase
            .from(_adminExpensesTable)
            .insert(payload)
            .select()
            .single();
        return AdminExpense.fromMap(Map<String, dynamic>.from(response));
      } catch (error) {
        await _logFinanceInsertFailure(
          table: _adminExpensesTable,
          payload: payload,
          error: error,
        );
        throw Exception(
          await _financeInsertErrorMessage(
            error: error,
            rpcName: 'admin_insert_expense',
          ),
        );
      }
    }
  }

  Future<AdminExpense> updateAdminExpense({
    required String id,
    required String title,
    required String category,
    required double amount,
    required DateTime expenseDate,
    required String type,
    String? recurrence,
    required String status,
    String? paymentMethod,
    String? vendor,
    String? invoiceUrl,
    String? note,
  }) async {
    _validateAdminExpenseInput(
      title: title,
      category: category,
      amount: amount,
      type: type,
      status: status,
      recurrence: recurrence,
    );
    try {
      final response = await _supabase
          .from(_adminExpensesTable)
          .update({
            'title': title.trim(),
            'category': category.trim(),
            'amount': amount,
            'expense_date': AdminExpense.formatDate(expenseDate),
            'type': type,
            'recurrence': type == 'recurring' ? recurrence : null,
            'status': status,
            'payment_method': paymentMethod?.trim(),
            'vendor': vendor?.trim(),
            'invoice_url': invoiceUrl?.trim(),
            'note': note?.trim(),
          })
          .eq('id', id)
          .select()
          .single();
      return AdminExpense.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<void> cancelAdminExpense(String expenseId) async {
    try {
      await _supabase
          .from(_adminExpensesTable)
          .update({'status': 'cancelled'})
          .eq('id', expenseId);
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<void> deleteAdminExpense(String expenseId) async {
    try {
      await _supabase.from(_adminExpensesTable).delete().eq('id', expenseId);
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  void _validateAdminRevenueInput({
    required String title,
    required String category,
    required double amount,
    required String type,
    required String status,
    String? recurrence,
  }) {
    if (title.trim().isEmpty) {
      throw Exception('Gelir adı zorunludur.');
    }
    if (category.trim().isEmpty) {
      throw Exception('Kategori zorunludur.');
    }
    if (amount <= 0 || amount.isNaN || amount.isInfinite) {
      throw Exception('Tutar 0\'dan büyük olmalıdır.');
    }
    const validTypes = {'one_time', 'recurring'};
    const validStatuses = {'received', 'pending', 'cancelled'};
    if (!validTypes.contains(type)) {
      throw Exception('Geçersiz gelir türü.');
    }
    if (!validStatuses.contains(status)) {
      throw Exception('Geçersiz gelir durumu.');
    }
    if (type == 'recurring' && (recurrence == null || recurrence.isEmpty)) {
      throw Exception('Tekrarlayan gelir için periyot seçin.');
    }
  }

  Future<List<AdminRevenue>> fetchAdminRevenues({
    DateTime? from,
    DateTime? toExclusive,
  }) async {
    try {
      dynamic query = _supabase.from(_adminRevenuesTable).select();
      if (from != null) {
        query = query.gte('revenue_date', AdminRevenue.formatDate(from));
      }
      if (toExclusive != null) {
        query = query.lt('revenue_date', AdminRevenue.formatDate(toExclusive));
      }
      final response = await query.order('revenue_date', ascending: false);
      return List<Map<String, dynamic>>.from(response)
          .map(AdminRevenue.fromMap)
          .toList();
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<AdminRevenue> createAdminRevenue({
    required String title,
    required String category,
    required double amount,
    required DateTime revenueDate,
    required String type,
    String? recurrence,
    required String status,
    String? source,
    String? paymentMethod,
    String? referenceNo,
    String? note,
  }) async {
    _validateAdminRevenueInput(
      title: title,
      category: category,
      amount: amount,
      type: type,
      status: status,
      recurrence: recurrence,
    );
    final actorId = _supabase.auth.currentUser?.id;
    final payload = <String, dynamic>{
      'title': title.trim(),
      'category': category.trim(),
      'amount': amount,
      'revenue_date': AdminRevenue.formatDate(revenueDate),
      'type': type,
      'recurrence': type == 'recurring' ? recurrence : null,
      'status': status,
      'source': source?.trim(),
      'payment_method': paymentMethod?.trim(),
      'reference_no': referenceNo?.trim(),
      'note': note?.trim(),
      'created_by': ?actorId,
    };
    try {
      final rpcResponse = await _supabase.rpc(
        'admin_insert_revenue',
        params: {
          'p_title': payload['title'],
          'p_category': payload['category'],
          'p_amount': payload['amount'],
          'p_revenue_date': payload['revenue_date'],
          'p_type': payload['type'],
          'p_recurrence': payload['recurrence'],
          'p_status': payload['status'],
          'p_source': payload['source'],
          'p_payment_method': payload['payment_method'],
          'p_reference_no': payload['reference_no'],
          'p_note': payload['note'],
        },
      );
      return AdminRevenue.fromMap(Map<String, dynamic>.from(rpcResponse as Map));
    } catch (rpcError) {
      debugPrint('[FinanceRevenue] RPC failed: $rpcError');
      if (_isFinanceRpcOrPermissionError(rpcError)) {
        await _logFinanceInsertFailure(
          table: _adminRevenuesTable,
          payload: payload,
          error: rpcError,
        );
        throw Exception(
          await _financeInsertErrorMessage(
            error: rpcError,
            rpcName: 'admin_insert_revenue',
          ),
        );
      }
      try {
        final response = await _supabase
            .from(_adminRevenuesTable)
            .insert(payload)
            .select()
            .single();
        return AdminRevenue.fromMap(Map<String, dynamic>.from(response));
      } catch (error) {
        await _logFinanceInsertFailure(
          table: _adminRevenuesTable,
          payload: payload,
          error: error,
        );
        throw Exception(
          await _financeInsertErrorMessage(
            error: error,
            rpcName: 'admin_insert_revenue',
          ),
        );
      }
    }
  }

  Future<AdminRevenue> updateAdminRevenue({
    required String id,
    required String title,
    required String category,
    required double amount,
    required DateTime revenueDate,
    required String type,
    String? recurrence,
    required String status,
    String? source,
    String? paymentMethod,
    String? referenceNo,
    String? note,
  }) async {
    _validateAdminRevenueInput(
      title: title,
      category: category,
      amount: amount,
      type: type,
      status: status,
      recurrence: recurrence,
    );
    try {
      final response = await _supabase
          .from(_adminRevenuesTable)
          .update({
            'title': title.trim(),
            'category': category.trim(),
            'amount': amount,
            'revenue_date': AdminRevenue.formatDate(revenueDate),
            'type': type,
            'recurrence': type == 'recurring' ? recurrence : null,
            'status': status,
            'source': source?.trim(),
            'payment_method': paymentMethod?.trim(),
            'reference_no': referenceNo?.trim(),
            'note': note?.trim(),
          })
          .eq('id', id)
          .select()
          .single();
      return AdminRevenue.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<AdminRevenue> cancelAdminRevenue(String id) async {
    try {
      final response = await _supabase
          .from(_adminRevenuesTable)
          .update({'status': 'cancelled'})
          .eq('id', id)
          .select()
          .single();
      return AdminRevenue.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<void> deleteAdminRevenue(String id) async {
    try {
      await _supabase.from(_adminRevenuesTable).delete().eq('id', id);
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<List<SellerPayout>> fetchSellerPayouts({
    DateTime? from,
    DateTime? toExclusive,
    String? status,
  }) async {
    try {
      dynamic query = _supabase.from(_sellerPayoutsTable).select();
      if (from != null) {
        query = query.gte('period_end', AdminExpense.formatDate(from));
      }
      if (toExclusive != null) {
        query = query.lte(
          'period_start',
          AdminExpense.formatDate(
            toExclusive.subtract(const Duration(days: 1)),
          ),
        );
      }
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      final response = await query.order('period_start', ascending: false);
      return List<Map<String, dynamic>>.from(response)
          .map(SellerPayout.fromMap)
          .toList();
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<SellerPayout> createOrRefreshSellerPayout({
    required String sellerId,
    String? storeId,
    required String storeName,
    required DateTime periodStart,
    required DateTime periodEnd,
    required double grossAmount,
    required double commissionAmount,
    required double refundAmount,
    required double deductionsAmount,
    required double netPayoutAmount,
    required int orderCount,
    required int itemCount,
    required String status,
    String? note,
    String? existingId,
  }) async {
    _validateSellerPayoutAmounts(
      grossAmount: grossAmount,
      commissionAmount: commissionAmount,
      refundAmount: refundAmount,
      deductionsAmount: deductionsAmount,
      netPayoutAmount: netPayoutAmount,
    );

    final actorId = _supabase.auth.currentUser?.id;
    final normalizedStoreId =
        storeId != null && storeId.trim().isNotEmpty ? storeId.trim() : null;

    SellerPayout? existing;
    if (existingId != null && existingId.isNotEmpty) {
      existing = await _fetchSellerPayoutById(existingId);
    }
    existing ??= await _findSellerPayoutForPeriod(
      sellerId: sellerId,
      storeId: normalizedStoreId,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );

    final amountPayload = <String, dynamic>{
      'seller_id': sellerId,
      'store_id': normalizedStoreId,
      'store_name': storeName.trim(),
      'period_start': AdminExpense.formatDate(periodStart),
      'period_end': AdminExpense.formatDate(periodEnd),
      'gross_amount': grossAmount,
      'commission_amount': commissionAmount,
      'refund_amount': refundAmount,
      'deductions_amount': deductionsAmount,
      'net_payout_amount': netPayoutAmount,
      'order_count': orderCount,
      'item_count': itemCount,
      if (note != null) 'note': note.trim(),
    };

    try {
      if (existing != null) {
        if (existing.status == 'cancelled') {
          throw Exception(_sellerPayoutTransitionError('cancelled', status));
        }
        if (existing.status == 'paid') {
          final response = await _supabase
              .from(_sellerPayoutsTable)
              .update(amountPayload)
              .eq('id', existing.id)
              .select()
              .single();
          return SellerPayout.fromMap(Map<String, dynamic>.from(response));
        }
        if (!_canSellerPayoutTransition(existing.status, status)) {
          throw Exception(
            _sellerPayoutTransitionError(existing.status, status),
          );
        }
        final payload = Map<String, dynamic>.from(amountPayload)
          ..['status'] = status;
        if (status == 'approved') {
          payload['approved_at'] = DateTime.now().toUtc().toIso8601String();
          if (actorId != null) payload['approved_by'] = actorId;
        }
        final response = await _supabase
            .from(_sellerPayoutsTable)
            .update(payload)
            .eq('id', existing.id)
            .select()
            .single();
        return SellerPayout.fromMap(Map<String, dynamic>.from(response));
      }

      final initialStatus = status;
      if (initialStatus != 'pending' &&
          !_canSellerPayoutTransition('pending', initialStatus)) {
        throw Exception(_sellerPayoutTransitionError('pending', initialStatus));
      }
      final payload = Map<String, dynamic>.from(amountPayload)
        ..['status'] = initialStatus;
      if (initialStatus == 'approved') {
        payload['approved_at'] = DateTime.now().toUtc().toIso8601String();
        if (actorId != null) payload['approved_by'] = actorId;
      }
      final response = await _supabase
          .from(_sellerPayoutsTable)
          .insert(payload)
          .select()
          .single();
      return SellerPayout.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      if (error is PostgrestException && error.code == '23505') {
        final duplicate = await _findSellerPayoutForPeriod(
          sellerId: sellerId,
          storeId: normalizedStoreId,
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
        if (duplicate != null) {
          return createOrRefreshSellerPayout(
            sellerId: sellerId,
            storeId: normalizedStoreId,
            storeName: storeName,
            periodStart: periodStart,
            periodEnd: periodEnd,
            grossAmount: grossAmount,
            commissionAmount: commissionAmount,
            refundAmount: refundAmount,
            deductionsAmount: deductionsAmount,
            netPayoutAmount: netPayoutAmount,
            orderCount: orderCount,
            itemCount: itemCount,
            status: status,
            note: note,
            existingId: duplicate.id,
          );
        }
      }
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<SellerPayout> updateSellerPayoutStatus({
    required String payoutId,
    required String status,
    String? note,
  }) async {
    final existing = await _fetchSellerPayoutById(payoutId);
    if (existing == null) {
      throw Exception('Hakediş kaydı bulunamadı.');
    }
    if (!_canSellerPayoutTransition(existing.status, status)) {
      throw Exception(_sellerPayoutTransitionError(existing.status, status));
    }
    final actorId = _supabase.auth.currentUser?.id;
    final updates = <String, dynamic>{
      'status': status,
      if (note != null) 'note': note.trim(),
    };
    if (status == 'approved') {
      updates['approved_at'] = DateTime.now().toUtc().toIso8601String();
      if (actorId != null) updates['approved_by'] = actorId;
    }
    try {
      final response = await _supabase
          .from(_sellerPayoutsTable)
          .update(updates)
          .eq('id', payoutId)
          .select()
          .single();
      return SellerPayout.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<SellerPayout> markSellerPayoutPaid({
    required String payoutId,
    required String paymentMethod,
    String? paymentReference,
    required DateTime paidAt,
    String? note,
  }) async {
    final existing = await _fetchSellerPayoutById(payoutId);
    if (existing == null) {
      throw Exception('Hakediş kaydı bulunamadı.');
    }
    if (existing.status == 'paid') {
      return existing;
    }
    if (!_canSellerPayoutTransition(existing.status, 'paid')) {
      throw Exception(_sellerPayoutTransitionError(existing.status, 'paid'));
    }
    final actorId = _supabase.auth.currentUser?.id;
    try {
      final response = await _supabase
          .from(_sellerPayoutsTable)
          .update({
            'status': 'paid',
            'payment_method': paymentMethod.trim(),
            'payment_reference': paymentReference?.trim(),
            'paid_at': paidAt.toUtc().toIso8601String(),
            'paid_by': actorId,
            if (note != null) 'note': note.trim(),
          })
          .eq('id', payoutId)
          .select()
          .single();
      return SellerPayout.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw _mapFinanceSchemaError(error);
    }
  }

  Future<List<AdminFinanceOrderItem>> getFinanceOrderItems({
    DateTime? from,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_finance_order_items_snapshot',
        params: {
          'p_from': from?.toIso8601String(),
        },
      );
      return List<Map<String, dynamic>>.from(response)
          .map(AdminFinanceOrderItem.fromMap)
          .toList();
    } catch (error) {
      try {
        dynamic query = _supabase
            .from('order_items')
            .select(
              'order_id,seller_id,store_name,status,total_price,created_at,updated_at',
            );
        if (from != null) {
          query = query.gte('created_at', from.toIso8601String());
        }
        final response = await query.order('created_at', ascending: true);
        return List<Map<String, dynamic>>.from(
          response,
        ).map(AdminFinanceOrderItem.fromMap).toList();
      } catch (fallbackError) {
        throw Exception(
          'Finans siparis kalemleri alinamadi: $fallbackError',
        );
      }
    }
  }

  Future<Map<String, dynamic>> fetchFinanceCommissionConfigRaw() async {
    try {
      final response = await _supabase
          .from('admin_finance_settings')
          .select('setting_value')
          .eq('setting_key', 'commission_config')
          .maybeSingle();
      if (response == null) return {};
      final value = response['setting_value'];
      if (value is Map) return Map<String, dynamic>.from(value);
      return {};
    } catch (error) {
      debugPrint('[FinanceCommission] config load failed: $error');
      return {};
    }
  }

  Future<Map<String, dynamic>> saveFinanceCommissionConfig(
    Map<String, dynamic> config,
  ) async {
    try {
      final response = await _supabase.rpc(
        'admin_save_finance_commission_config',
        params: {'p_config': config},
      );
      if (response is Map) return Map<String, dynamic>.from(response);
      return config;
    } catch (error) {
      try {
        await _supabase.from('admin_finance_settings').upsert({
          'setting_key': 'commission_config',
          'setting_value': config,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        return config;
      } catch (fallbackError) {
        throw Exception('Komisyon ayarlari kaydedilemedi: $fallbackError');
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchFinanceCategoryOptions() async {
    try {
      final response = await _supabase
          .from('categories')
          .select('id,name,parent_id,is_active')
          .eq('is_active', true)
          .order('order_index', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      debugPrint('[FinanceCommission] categories load failed: $error');
      return const [];
    }
  }

  Future<List<AdminFinanceOrder>> getFinanceOrders({DateTime? from}) async {
    try {
      dynamic query = _supabase
          .from('orders')
          .select(
            'id,status,total_amount,shipping_amount,delivery_type,created_at,'
            'customer_delivery_fee,seller_delivery_fee,total_delivery_fee',
          );
      if (from != null) {
        query = query.gte('created_at', from.toIso8601String());
      }
      final response = await query.order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(
        response,
      ).map(AdminFinanceOrder.fromMap).toList();
    } catch (error) {
      throw Exception('Finans siparisleri alinamadi: $error');
    }
  }

  Future<int> getOpenStoreCount() async {
    try {
      return await _supabase
          .from('stores')
          .count(CountOption.exact)
          .eq('is_store_open', true);
    } catch (error) {
      throw Exception('Acik magaza sayisi alinamadi: $error');
    }
  }

  Future<List<AdminFinanceStoreEntry>> getFinanceStoreDirectory() async {
    try {
      final response = await _supabase
          .from('stores')
          .select('seller_id,business_name,is_store_open')
          .order('business_name', ascending: true);
      return List<Map<String, dynamic>>.from(response)
          .map(AdminFinanceStoreEntry.fromMap)
          .where((store) => store.sellerId.trim().isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      debugPrint('[FinanceStores] directory load failed: $error');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> getFinanceAdCampaignRows({
    DateTime? from,
  }) async {
    try {
      dynamic query = _supabase.from('campaigns').select(
            'id,seller_id,name,type,objective,status,billing_model,'
            'daily_budget,total_budget,spent_amount,remaining_balance,'
            'starts_at,ends_at,metadata,created_at,approved_at',
          );
      if (from != null) {
        query = query.gte('created_at', from.toIso8601String());
      }
      final response = await query.order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      throw Exception('Finans reklam kampanyalari alinamadi: $error');
    }
  }

  Future<List<Map<String, dynamic>>> getFinanceAdMetricsRows({
    DateTime? from,
  }) async {
    try {
      dynamic query = _supabase.from('ad_metrics_daily').select();
      if (from != null) {
        query = query.gte(
          'metric_date',
          from.toIso8601String().split('T').first,
        );
      }
      final response = await query.order('metric_date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      throw Exception('Finans reklam metrikleri alinamadi: $error');
    }
  }

  Future<List<Map<String, dynamic>>> getFinanceAdRevenueLogRows({
    DateTime? from,
  }) async {
    try {
      dynamic query = _supabase.from('ad_revenue_logs').select();
      if (from != null) {
        query = query.gte('recorded_at', from.toIso8601String());
      }
      final response = await query.order('recorded_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      throw Exception('Finans reklam gelir kayitlari alinamadi: $error');
    }
  }

  Future<List<Map<String, dynamic>>> getFinanceAdWalletTransactionRows({
    DateTime? from,
  }) async {
    try {
      dynamic query = _supabase.from('ad_wallet_transactions').select();
      if (from != null) {
        query = query.gte('created_at', from.toIso8601String());
      }
      final response = await query.order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      throw Exception('Finans reklam cuzdan hareketleri alinamadi: $error');
    }
  }

  Future<List<AdminRoleCatalogEntry>> getRoleCatalog() async {
    try {
      final response = await _supabase
          .from('admin_role_catalog')
          .select()
          .order('sort_order')
          .order('title');
      final items = List<Map<String, dynamic>>.from(response)
          .map(AdminRoleCatalogEntry.fromMap)
          .where((entry) => entry.roleKey.isNotEmpty)
          .map(
            (entry) => entry.copyWith(
              modules: _withDefaultIhizAccess(entry.roleKey, entry.modules),
            ),
          )
          .toList();
      if (items.isEmpty) return _fallbackRoleCatalog;
      return items;
    } catch (_) {
      return _fallbackRoleCatalog;
    }
  }

  Future<AdminRoleCatalogEntry?> getRoleCatalogEntry(String roleKey) async {
    try {
      final response = await _supabase
          .from('admin_role_catalog')
          .select()
          .eq('role_key', roleKey)
          .maybeSingle();
      if (response == null) return _fallbackRoleByKey(roleKey);
      final entry = AdminRoleCatalogEntry.fromMap(response);
      return entry.copyWith(
        modules: _withDefaultIhizAccess(entry.roleKey, entry.modules),
      );
    } catch (_) {
      return _fallbackRoleByKey(roleKey);
    }
  }

  Future<void> upsertRoleCatalogEntry(AdminRoleCatalogEntry entry) async {
    final actorId = _supabase.auth.currentUser?.id;
    final now = DateTime.now().toIso8601String();
    final payload = entry.copyWith(updatedAt: DateTime.now()).toMap()
      ..remove('created_at')
      ..['updated_at'] = now
      ..['updated_by'] = actorId
      ..putIfAbsent('created_by', () => actorId);

    try {
      final previous = await getRoleCatalogEntry(entry.roleKey);
      await _supabase
          .from('admin_role_catalog')
          .upsert(payload, onConflict: 'role_key');
      await _supabase
          .from('admin_user_permissions')
          .update({'allowed_modules': entry.modules, 'updated_at': now})
          .eq('role_key', entry.roleKey)
          .eq('is_active', true);

      await _insertRoleHistory(
        eventType: previous == null ? 'catalog_created' : 'catalog_updated',
        previousRoleKey: previous?.roleKey,
        newRoleKey: entry.roleKey,
        previousModules: previous?.modules ?? const [],
        newModules: entry.modules,
        note: 'Rol katalogu guncellendi: ${entry.title}',
      );
    } catch (e) {
      throw Exception(
        'Rol katalogu kaydedilemedi. SQL migration uygulanmamis olabilir. Detay: $e',
      );
    }
  }

  Future<void> setRoleCatalogStatus({
    required String roleKey,
    required bool isActive,
  }) async {
    final existing = await getRoleCatalogEntry(roleKey);
    if (existing == null) return;
    await upsertRoleCatalogEntry(existing.copyWith(isActive: isActive));
  }

  Future<List<AdminUserPermissionAssignment>> getAdminUsers({
    String search = '',
    String? roleKey,
  }) async {
    final normalizedSearch = search.trim().toLowerCase();
    try {
      final response = await _supabase
          .from('admin_user_permissions')
          .select(
            'user_id,role_key,allowed_modules,denied_modules,is_active,note,assigned_at,updated_at,users!admin_user_permissions_user_id_fkey(id,email,display_name,role,updated_at)',
          )
          .eq('is_active', true)
          .order('updated_at', ascending: false);

      var items = List<Map<String, dynamic>>.from(response)
          .map(AdminUserPermissionAssignment.fromMap)
          .map(
            (item) => AdminUserPermissionAssignment(
              userId: item.userId,
              roleKey: item.roleKey,
              allowedModules: _withDefaultIhizAccess(
                item.roleKey,
                item.allowedModules,
              ),
              deniedModules: item.deniedModules,
              isActive: item.isActive,
              userEmail: item.userEmail,
              userDisplayName: item.userDisplayName,
              note: item.note,
              assignedAt: item.assignedAt,
              updatedAt: item.updatedAt,
            ),
          )
          .toList();

      if (roleKey != null && roleKey.isNotEmpty) {
        items = items.where((item) => item.roleKey == roleKey).toList();
      }
      if (normalizedSearch.isNotEmpty) {
        items = items.where((item) {
          final email = (item.userEmail ?? '').toLowerCase();
          final name = (item.userDisplayName ?? '').toLowerCase();
          return email.contains(normalizedSearch) ||
              name.contains(normalizedSearch);
        }).toList();
      }
      return items;
    } catch (_) {
      final response = await _supabase
          .from('users')
          .select('id,email,display_name,role,updated_at')
          .or('role.eq.admin,role.eq.super_admin,role.like.admin_%')
          .order('updated_at', ascending: false);
      final users = List<Map<String, dynamic>>.from(response);
      return users
          .where((user) {
            final role = (user['role'] ?? '').toString();
            final email = (user['email'] ?? '').toString().toLowerCase();
            final name = (user['display_name'] ?? '').toString().toLowerCase();
            final roleMatches =
                roleKey == null || roleKey.isEmpty || role == roleKey;
            final searchMatches =
                normalizedSearch.isEmpty ||
                email.contains(normalizedSearch) ||
                name.contains(normalizedSearch);
            return AuthService.isAdminRole(role) &&
                roleMatches &&
                searchMatches;
          })
          .map(
            (user) => AdminUserPermissionAssignment(
              userId: user['id'].toString(),
              roleKey: (user['role'] ?? '').toString(),
              allowedModules: _withDefaultIhizAccess(
                (user['role'] ?? '').toString(),
                _fallbackRoleByKey((user['role'] ?? '').toString())?.modules ??
                    const [],
              ),
              deniedModules: const [],
              isActive: true,
              userEmail: user['email']?.toString(),
              userDisplayName: user['display_name']?.toString(),
              updatedAt: DateTime.tryParse(
                (user['updated_at'] ?? '').toString(),
              ),
            ),
          )
          .toList();
    }
  }

  Future<AdminAccessBundle> getCurrentAdminAccessBundle() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      return const AdminAccessBundle(
        roleKey: 'user',
        roleTitle: 'Kullanici',
        allowedModules: [],
        deniedModules: [],
      );
    }

    final userRow = await _supabase
        .from('users')
        .select('role')
        .eq('id', currentUser.id)
        .maybeSingle();
    final roleKey = (userRow?['role'] ?? '').toString();
    if (!AuthService.isAdminRole(roleKey)) {
      return AdminAccessBundle(
        roleKey: roleKey,
        roleTitle: AuthService.adminRoleLabel(roleKey),
        allowedModules: const [],
        deniedModules: const [],
      );
    }

    final catalogEntry = await getRoleCatalogEntry(roleKey);
    var allowedModules = _withDefaultIhizAccess(
      roleKey,
      catalogEntry?.modules ??
          _fallbackRoleByKey(roleKey)?.modules ??
          <String>[AdminModules.dashboard],
    );
    var deniedModules = <String>[];

    try {
      final assignment = await _supabase
          .from('admin_user_permissions')
          .select('allowed_modules,denied_modules,is_active')
          .eq('user_id', currentUser.id)
          .eq('is_active', true)
          .maybeSingle();
      if (assignment != null) {
        final allowedOverride = _withDefaultIhizAccess(
          roleKey,
          (assignment['allowed_modules'] as List? ?? const []).map(
            (item) => item.toString(),
          ),
        );
        deniedModules = _normalizedModules(
          (assignment['denied_modules'] as List? ?? const []).map(
            (item) => item.toString(),
          ),
        );
        if (allowedOverride.isNotEmpty) {
          allowedModules = allowedOverride;
        }
      }
    } catch (_) {}

    if (roleKey == 'super_admin') {
      allowedModules = AdminModules.all;
      deniedModules = const [];
    }

    allowedModules = allowedModules
        .where((module) => !deniedModules.contains(module))
        .toList();

    return AdminAccessBundle(
      roleKey: roleKey,
      roleTitle: catalogEntry?.title ?? AuthService.adminRoleLabel(roleKey),
      allowedModules: _withDefaultIhizAccess(roleKey, allowedModules),
      deniedModules: deniedModules,
      roleCatalogEntry: catalogEntry,
    );
  }

  Future<void> assignAdminRole({
    required String userId,
    required String roleKey,
    String? note,
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    final currentUserRow = await _supabase
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    final previousRole = currentUserRow?['role']?.toString();
    final previousCatalog = previousRole == null || previousRole.isEmpty
        ? null
        : await getRoleCatalogEntry(previousRole);
    final roleEntry = await getRoleCatalogEntry(roleKey);
    if (roleEntry == null) {
      throw Exception('Secilen rol katalogda bulunamadi: $roleKey');
    }

    final now = DateTime.now().toIso8601String();
    await _supabase
        .from('users')
        .update({'role': roleKey, 'updated_at': now})
        .eq('id', userId);

    try {
      await _supabase.from('admin_user_permissions').upsert({
        'user_id': userId,
        'role_key': roleEntry.roleKey,
        'allowed_modules': roleEntry.modules,
        'denied_modules': <String>[],
        'is_active': true,
        'note': note,
        'assigned_by': currentUserId,
        'assigned_at': now,
        'updated_at': now,
      }, onConflict: 'user_id');
    } catch (e) {
      throw Exception(
        'Admin atamasi icin izin tablolari hazir degil. SQL migration uygulanmamis olabilir. Detay: $e',
      );
    }

    await _insertRoleHistory(
      userId: userId,
      eventType: previousRole == null || previousRole.isEmpty
          ? 'granted'
          : 'updated',
      previousRoleKey: previousRole,
      newRoleKey: roleEntry.roleKey,
      previousModules: previousCatalog?.modules ?? const [],
      newModules: roleEntry.modules,
      note: note,
    );
  }

  Future<void> revokeAdminRole({
    required String userId,
    String fallbackRole = 'user',
    String? note,
  }) async {
    final currentUserRow = await _supabase
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    final previousRole = currentUserRow?['role']?.toString();
    final previousCatalog = previousRole == null || previousRole.isEmpty
        ? null
        : await getRoleCatalogEntry(previousRole);

    final now = DateTime.now().toIso8601String();
    await _supabase
        .from('users')
        .update({'role': fallbackRole, 'updated_at': now})
        .eq('id', userId);

    try {
      await _supabase
          .from('admin_user_permissions')
          .update({'is_active': false, 'updated_at': now, 'note': note})
          .eq('user_id', userId);
    } catch (_) {}

    await _insertRoleHistory(
      userId: userId,
      eventType: 'revoked',
      previousRoleKey: previousRole,
      newRoleKey: fallbackRole,
      previousModules: previousCatalog?.modules ?? const [],
      newModules: const [],
      note: note,
    );
  }

  Future<List<AdminRoleHistoryEntry>> getRoleHistory({
    String search = '',
    String? roleKey,
    int limit = 50,
  }) async {
    final normalizedSearch = search.trim().toLowerCase();
    try {
      final response = await _supabase
          .from('admin_role_history')
          .select(
            'id,user_id,actor_id,event_type,previous_role_key,new_role_key,previous_modules,new_modules,note,created_at,users!admin_role_history_user_id_fkey(email,display_name),actor:users!admin_role_history_actor_id_fkey(email,display_name)',
          )
          .order('created_at', ascending: false)
          .limit(limit);

      var items = List<Map<String, dynamic>>.from(
        response,
      ).map(AdminRoleHistoryEntry.fromMap).toList();

      if (roleKey != null && roleKey.isNotEmpty) {
        items = items.where((item) {
          return item.newRoleKey == roleKey || item.previousRoleKey == roleKey;
        }).toList();
      }
      if (normalizedSearch.isNotEmpty) {
        items = items.where((item) {
          final userName = (item.userDisplayName ?? '').toLowerCase();
          final userEmail = (item.userEmail ?? '').toLowerCase();
          final note = (item.note ?? '').toLowerCase();
          final newRole = (item.newRoleKey ?? '').toLowerCase();
          final oldRole = (item.previousRoleKey ?? '').toLowerCase();
          return userName.contains(normalizedSearch) ||
              userEmail.contains(normalizedSearch) ||
              note.contains(normalizedSearch) ||
              newRole.contains(normalizedSearch) ||
              oldRole.contains(normalizedSearch);
        }).toList();
      }
      return items;
    } catch (_) {
      return const [];
    }
  }

  Future<List<AdminAuthLoginEvent>> getAuthLoginEvents({int limit = 50}) async {
    try {
      final response = await _supabase
          .from('admin_auth_login_events')
          .select(
            'id,user_id,email,provider,auth_area,status,error_code,error_message,platform,device_label,user_agent,metadata,attempted_at',
          )
          .order('attempted_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(
        response,
      ).map(AdminAuthLoginEvent.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<AdminSecuritySnapshot> getSecuritySnapshot() async {
    final results = await Future.wait<dynamic>([
      getAdminUsers(),
      getRoleHistory(limit: 80),
      getSystemMetrics(),
      getRoleCatalog(),
      getAuthLoginEvents(limit: 60),
    ]);

    final adminUsers = results[0] as List<AdminUserPermissionAssignment>;
    final roleHistory = results[1] as List<AdminRoleHistoryEntry>;
    final systemMetrics = results[2] as AdminSystemMetrics;
    final roleCatalog = results[3] as List<AdminRoleCatalogEntry>;
    final authLoginEvents = results[4] as List<AdminAuthLoginEvent>;
    final now = DateTime.now().toUtc();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final roleCatalogByKey = {
      for (final entry in roleCatalog) entry.roleKey: entry,
    };

    final adminPosture =
        adminUsers.map((admin) {
          final resolvedModules = _normalizedModules(
            admin.allowedModules.isNotEmpty
                ? admin.allowedModules
                : (roleCatalogByKey[admin.roleKey]?.modules ??
                      _fallbackRoleByKey(admin.roleKey)?.modules ??
                      const <String>[]),
          );
          final hasSecurityLogsAccess = resolvedModules.contains(
            AdminModules.securityLogs,
          );
          final hasPermissionSystemAccess = resolvedModules.contains(
            AdminModules.permissionSystem,
          );
          final resolvedName =
              (admin.userDisplayName?.trim().isNotEmpty ?? false)
              ? admin.userDisplayName!.trim()
              : ((admin.userEmail?.split('@').first ?? 'Admin').trim());

          return AdminSecurityAdminPosture(
            userId: admin.userId,
            name: resolvedName,
            email: admin.userEmail ?? '-',
            roleKey: admin.roleKey,
            roleLabel:
                roleCatalogByKey[admin.roleKey]?.title ??
                AuthService.adminRoleLabel(admin.roleKey),
            modules: resolvedModules,
            lastUpdated: admin.updatedAt ?? admin.assignedAt,
            hasSecurityLogsAccess: hasSecurityLogsAccess,
            hasPermissionSystemAccess: hasPermissionSystemAccess,
            isOverexposed:
                resolvedModules.length >= 5 ||
                (hasSecurityLogsAccess && hasPermissionSystemAccess),
          );
        }).toList()..sort((a, b) {
          if (a.isOverexposed != b.isOverexposed) {
            return a.isOverexposed ? -1 : 1;
          }
          final left = a.lastUpdated ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.lastUpdated ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });

    final incidents = <AdminSecurityIncident>[
      ...authLoginEvents.map((event) {
        final attemptedIdentity = (event.email?.trim().isNotEmpty ?? false)
            ? event.email!.trim()
            : 'Bilinmeyen hesap';
        final detailParts = <String>[
          attemptedIdentity,
          'Alan: ${event.authArea}',
          'Sağlayıcı: ${event.provider}',
          if ((event.platform ?? '').isNotEmpty) 'Platform: ${event.platform}',
          if ((event.errorCode ?? '').isNotEmpty) 'Kod: ${event.errorCode}',
          if ((event.errorMessage ?? '').isNotEmpty) event.errorMessage!,
        ];

        return AdminSecurityIncident(
          title: _securityIncidentTitleFromAuthEvent(event),
          subtitle: detailParts.join(' • '),
          severity: _securityIncidentSeverityFromAuthEvent(event),
          source: 'Auth Giriş Denemesi',
          occurredAt: event.attemptedAt,
        );
      }),
      ...roleHistory.map((entry) {
        final subject = (entry.userDisplayName?.trim().isNotEmpty ?? false)
            ? entry.userDisplayName!.trim()
            : (entry.userEmail ?? 'Bilinmeyen hesap');
        final actor = (entry.actorDisplayName?.trim().isNotEmpty ?? false)
            ? entry.actorDisplayName!.trim()
            : (entry.actorEmail ?? 'Sistem');
        final note = (entry.note ?? '').trim();
        final roleContext = [
          if ((entry.previousRoleKey ?? '').isNotEmpty) entry.previousRoleKey,
          if ((entry.newRoleKey ?? '').isNotEmpty) entry.newRoleKey,
        ].join(' → ');

        return AdminSecurityIncident(
          title: _securityIncidentTitleFromHistory(entry.eventType),
          subtitle: [
            subject,
            actor,
            if (roleContext.isNotEmpty) roleContext,
            if (note.isNotEmpty) note,
          ].join(' • '),
          severity: _securityIncidentSeverityFromHistory(entry.eventType),
          source: 'Yetki Geçmişi',
          occurredAt: entry.createdAt,
        );
      }),
      ...systemMetrics.logs.map((log) {
        return AdminSecurityIncident(
          title: log.title,
          subtitle: log.subtitle,
          severity: _normalizeSecuritySeverity(log.level),
          source: 'Sistem Sinyali',
          occurredAt: log.occurredAt,
        );
      }),
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    final securityOwnerCount = adminPosture
        .where((admin) => admin.hasSecurityLogsAccess)
        .length;
    final permissionManagerCount = adminPosture
        .where((admin) => admin.hasPermissionSystemAccess)
        .length;
    final overexposedAdminCount = adminPosture
        .where((admin) => admin.isOverexposed)
        .length;
    final criticalIncidentCount7d = incidents
        .where(
          (incident) =>
              incident.severity == 'critical' &&
              incident.occurredAt.toUtc().isAfter(sevenDaysAgo),
        )
        .length;
    final failedAuthEvents7d = authLoginEvents
        .where(
          (event) =>
              event.status == 'failed' &&
              event.attemptedAt.toUtc().isAfter(sevenDaysAgo),
        )
        .length;
    final successfulAuthEvents7d = authLoginEvents
        .where(
          (event) =>
              event.status == 'success' &&
              event.attemptedAt.toUtc().isAfter(sevenDaysAgo),
        )
        .length;

    final requirements = <AdminSecurityRequirement>[
      AdminSecurityRequirement(
        id: 'audit_trail',
        title: 'Denetim izi',
        description:
            'Rol değişiklikleri ve kritik operasyonlar geriye dönük okunabilir bir akışta tutulmalı.',
        status: roleHistory.isNotEmpty ? 'healthy' : 'critical',
        owner: 'Güvenlik Operasyonu',
        evidenceLabel: roleHistory.isNotEmpty
            ? '${roleHistory.length} rol olayı mevcut'
            : 'Rol geçmişi kaydı yok',
        actionLabel: roleHistory.isNotEmpty
            ? 'Kayıt akışı okunabiliyor'
            : 'Migration ve kayıt politikası gerekli',
        completionPercent: roleHistory.isNotEmpty ? 100 : 30,
      ),
      AdminSecurityRequirement(
        id: 'separation_of_duties',
        title: 'Yetki ayrıştırması',
        description:
            'İzin yönetimi ile güvenlik log erişimi tek kişide yoğunlaşmamalı; en az iki sorumlu rol bulunmalı.',
        status:
            securityOwnerCount > 0 &&
                permissionManagerCount > 0 &&
                overexposedAdminCount == 0
            ? 'healthy'
            : (securityOwnerCount > 0 || permissionManagerCount > 0)
            ? 'warning'
            : 'critical',
        owner: 'Admin Yetki Kurulu',
        evidenceLabel:
            '$securityOwnerCount güvenlik sorumlusu • $permissionManagerCount yetki yöneticisi',
        actionLabel: overexposedAdminCount == 0
            ? 'Görev ayrımı korunuyor'
            : '$overexposedAdminCount hesapta fazla ayrıcalık var',
        completionPercent:
            overexposedAdminCount == 0 &&
                securityOwnerCount > 0 &&
                permissionManagerCount > 0
            ? 100
            : (securityOwnerCount > 0 || permissionManagerCount > 0)
            ? 68
            : 25,
      ),
      AdminSecurityRequirement(
        id: 'auth_event_visibility',
        title: 'Kimlik doğrulama görünürlüğü',
        description:
            'Başarısız giriş, oturum yenileme ve MFA olayları ayrı bir kaynakta izlenmeli.',
        status: authLoginEvents.isEmpty
            ? 'critical'
            : failedAuthEvents7d > 0
            ? 'warning'
            : 'healthy',
        owner: 'Kimlik & Erişim',
        evidenceLabel: authLoginEvents.isEmpty
            ? 'Henüz auth giriş denemesi kaydı oluşmadı'
            : '$successfulAuthEvents7d başarılı • $failedAuthEvents7d başarısız giriş / 7 gün',
        actionLabel: authLoginEvents.isEmpty
            ? 'Yeni migration sonrası giriş akışlarından kayıt akmasını doğrulayın'
            : failedAuthEvents7d > 0
            ? 'Başarısız girişlerin kaynaklarını inceleyin ve MFA görünürlüğünü ekleyin'
            : 'Temel giriş akışı görünür; MFA ve oturum yenileme olaylarını da ekleyin',
        completionPercent: authLoginEvents.isEmpty
            ? 15
            : failedAuthEvents7d > 0
            ? 72
            : 88,
      ),
      AdminSecurityRequirement(
        id: 'privileged_review',
        title: 'Yüksek ayrıcalık incelemesi',
        description:
            'Çok modüllü veya çift kritik erişimli hesaplar haftalık gözden geçirilmeli.',
        status: overexposedAdminCount == 0 ? 'healthy' : 'warning',
        owner: 'İç Denetim',
        evidenceLabel: overexposedAdminCount == 0
            ? 'Riskli erişim kombinasyonu yok'
            : '$overexposedAdminCount hesap manuel inceleme bekliyor',
        actionLabel: overexposedAdminCount == 0
            ? 'Periyodik kontrol yeterli'
            : 'Modül kapsamlarını daraltın ve sahiplikleri bölün',
        completionPercent: overexposedAdminCount == 0 ? 100 : 58,
      ),
    ];

    final readinessPercent = requirements.isEmpty
        ? 0.0
        : requirements.fold<int>(
                0,
                (total, item) => total + item.completionPercent,
              ) /
              requirements.length;
    final visibilityPercent =
        ((systemMetrics.dataCoveragePercent * 0.45) +
                ((roleHistory.isNotEmpty ? 100 : 0) * 0.35) +
                ((authLoginEvents.isNotEmpty ? 100 : 0) * 0.20))
            .clamp(0, 100)
            .toDouble();

    final postureLabel =
        criticalIncidentCount7d > 0 || overexposedAdminCount > 0
        ? 'Dikkat gerekli'
        : readinessPercent >= 85
        ? 'Stabil'
        : 'İzlemede';
    final postureNote = criticalIncidentCount7d > 0
        ? 'Son 7 günde kritik olay görüldü; olay müdahalesi ve yetki gözden geçirmesi önerilir.'
        : overexposedAdminCount > 0
        ? 'Bazı hesaplarda kritik modüller tek elde toplanıyor.'
        : authLoginEvents.isEmpty
        ? 'Auth kayıt şeması hazır; ilk giriş denemeleri oluştukça görünürlük artacak.'
        : 'Mevcut sinyaller dengeli; sıradaki adım MFA ve oturum yenileme olaylarını aynı akışa almak.';

    return AdminSecuritySnapshot(
      activeAdminCount: adminPosture.length,
      securityOwnerCount: securityOwnerCount,
      permissionManagerCount: permissionManagerCount,
      overexposedAdminCount: overexposedAdminCount,
      criticalIncidentCount7d: criticalIncidentCount7d,
      readinessPercent: readinessPercent,
      visibilityPercent: visibilityPercent,
      postureLabel: postureLabel,
      postureNote: postureNote,
      schemaMessage: authLoginEvents.isEmpty
          ? 'Auth giriş denemesi şeması eklendi. Kayıtlar, login akışları bu migration ile güncellendiğinde burada görünür olacaktır.'
          : 'Bu ekran rol geçmişi, sistem sinyalleri ve gerçek auth giriş denemesi kayıtlarını birlikte gösteriyor.',
      requirements: requirements,
      incidents: incidents.take(12).toList(growable: false),
      adminPosture: adminPosture,
    );
  }

  String _securityIncidentTitleFromHistory(String eventType) {
    switch (eventType) {
      case 'granted':
        return 'Yeni admin yetkisi verildi';
      case 'updated':
        return 'Admin rol kapsamı güncellendi';
      case 'revoked':
        return 'Admin yetkisi geri alındı';
      case 'catalog_created':
        return 'Yeni rol şablonu oluşturuldu';
      case 'catalog_updated':
        return 'Rol şablonu değiştirildi';
      default:
        return 'Admin güvenlik olayı';
    }
  }

  String _securityIncidentSeverityFromHistory(String eventType) {
    switch (eventType) {
      case 'revoked':
        return 'critical';
      case 'updated':
      case 'catalog_updated':
        return 'warning';
      default:
        return 'info';
    }
  }

  String _securityIncidentTitleFromAuthEvent(AdminAuthLoginEvent event) {
    switch (event.status) {
      case 'success':
        return 'Başarılı giriş denemesi';
      case 'cancelled':
        return 'İptal edilen giriş denemesi';
      default:
        return 'Başarısız giriş denemesi';
    }
  }

  String _securityIncidentSeverityFromAuthEvent(AdminAuthLoginEvent event) {
    if (event.status == 'failed') {
      if ((event.errorCode ?? '') == 'too_many_requests') {
        return 'critical';
      }
      return 'warning';
    }
    if (event.status == 'cancelled') {
      return 'info';
    }
    return 'info';
  }

  String _normalizeSecuritySeverity(String level) {
    switch (level.toLowerCase()) {
      case 'critical':
      case 'error':
        return 'critical';
      case 'warning':
        return 'warning';
      default:
        return 'info';
    }
  }

  Future<void> _insertRoleHistory({
    String? userId,
    required String eventType,
    String? previousRoleKey,
    String? newRoleKey,
    List<String> previousModules = const [],
    List<String> newModules = const [],
    String? note,
  }) async {
    try {
      await _supabase.from('admin_role_history').insert({
        'user_id': userId,
        'actor_id': _supabase.auth.currentUser?.id,
        'event_type': eventType,
        'previous_role_key': previousRoleKey,
        'new_role_key': newRoleKey,
        'previous_modules': previousModules,
        'new_modules': newModules,
        'note': note,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // --- IHIZ Courier Applications ---

  Stream<List<Map<String, dynamic>>> getIhizCourierApplicationsStream({
    String? status,
  }) {
    if (status == null || status.trim().isEmpty) {
      return _supabase
          .from('ihiz_courier_applications')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false);
    }
    return _supabase
        .from('ihiz_courier_applications')
        .stream(primaryKey: ['id'])
        .eq('status', status.trim())
        .order('created_at', ascending: false);
  }

  Future<void> updateIhizCourierApplicationStatus(
    String id,
    String status, {
    String? rejectionReason,
  }) async {
    final normalizedStatus = status.trim();
    if (normalizedStatus != AdminApprovalStatusConstants.approved &&
        normalizedStatus != AdminApprovalStatusConstants.rejected &&
        normalizedStatus != AdminApprovalStatusConstants.pending) {
      throw Exception('Gecersiz IHIZ basvuru durumu: $status');
    }

    final row = await _supabase
        .from('ihiz_courier_applications')
        .select('user_id')
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw Exception('IHIZ basvurusu bulunamadi.');
    }

    final nowIso = DateTime.now().toIso8601String();
    final updates = <String, dynamic>{
      'status': normalizedStatus,
      'updated_at': nowIso,
    };
    if (normalizedStatus == AdminApprovalStatusConstants.approved) {
      updates['approved_at'] = nowIso;
      updates['rejection_reason'] = null;
    } else if (normalizedStatus == AdminApprovalStatusConstants.rejected) {
      updates['approved_at'] = null;
      updates['rejection_reason'] = rejectionReason?.trim();
    } else {
      updates['approved_at'] = null;
      updates['rejection_reason'] = null;
    }

    await _supabase
        .from('ihiz_courier_applications')
        .update(updates)
        .eq('id', id);

    final userId = row['user_id']?.toString();
    if (userId != null && userId.isNotEmpty) {
      try {
        // Best-effort sync: users RLS insert policy yoksa başvuru onayı yine de başarısız olmamalı.
        await _supabase
            .from('users')
            .update({
              'is_ihiz_approved': normalizedStatus == AdminApprovalStatusConstants.approved,
              'updated_at': nowIso,
            })
            .eq('id', userId);
      } catch (error) {
        debugPrint('IHIZ users approval flag update skipped: $error');
      }
    }
  }

  // --- Seller Applications ---

  static const String sellerApplicationMissingDocuments = 'missing_documents';

  static const String storeHistoryApproved = 'approved';
  static const String storeHistoryRejected = 'rejected';
  static const String storeHistoryChangesRequested = 'changes_requested';
  static const String storeHistoryResubmitted = 'resubmitted';

  Stream<List<Map<String, dynamic>>> getSellerApplicationsStream() {
    return _supabase
        .from('seller_applications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  static bool canAdminActOnApplication(Map<String, dynamic> application) {
    final status = (application['status'] ?? '').toString().toLowerCase();
    return status == AdminApprovalStatusConstants.pending ||
        status == sellerApplicationMissingDocuments;
  }

  Future<Map<String, dynamic>?> fetchSellerApplicationById(String id) async {
    if (id.trim().isEmpty) return null;
    try {
      final raw = await _supabase
          .from('seller_applications')
          .select()
          .eq('id', id.trim())
          .maybeSingle();
      if (raw == null) return null;
      return Map<String, dynamic>.from(raw);
    } on PostgrestException catch (error) {
      debugPrint('Seller application fetch skipped: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchLatestActionableApplicationForSeller(
    String sellerId,
  ) async {
    if (sellerId.trim().isEmpty) return null;
    try {
      final raw = await _supabase
          .from('seller_applications')
          .select()
          .eq('user_id', sellerId.trim())
          .inFilter('status', [
            AdminApprovalStatusConstants.pending,
            sellerApplicationMissingDocuments,
          ])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (raw == null) return null;
      return Map<String, dynamic>.from(raw);
    } on PostgrestException catch (error) {
      debugPrint('Actionable seller application fetch skipped: $error');
      return null;
    }
  }

  Future<SellerApplicationHistoryResolution> resolveApplicationFromHistoryEntry(
    Map<String, dynamic> entry,
  ) async {
    final applicationId = (entry['application_id'] ?? '').toString();
    final sellerId = (entry['seller_id'] ?? entry['store_id'] ?? '').toString();

    if (applicationId.isNotEmpty) {
      final byId = await fetchSellerApplicationById(applicationId);
      if (byId != null && canAdminActOnApplication(byId)) {
        return SellerApplicationHistoryResolution(
          application: byId,
          allowAdminActions: true,
        );
      }
    }

    if (sellerId.isNotEmpty) {
      final latest = await fetchLatestActionableApplicationForSeller(sellerId);
      if (latest != null) {
        return SellerApplicationHistoryResolution(
          application: latest,
          allowAdminActions: true,
          linkedFromHistory: true,
        );
      }
    }

    final metadata = entry['metadata'];
    if (metadata is Map) {
      final snapshot = metadata['snapshot'];
      if (snapshot is Map) {
        return SellerApplicationHistoryResolution(
          application: Map<String, dynamic>.from(snapshot),
          allowAdminActions: false,
          isSnapshot: true,
        );
      }
    }

    return SellerApplicationHistoryResolution(
      application: {
        'id': applicationId.isEmpty ? null : applicationId,
        'user_id': sellerId.isEmpty ? null : sellerId,
        'business_name': entry['store_name'],
        'created_at': entry['application_created_at'],
        'status': entry['new_status'],
      },
      allowAdminActions: false,
      isSnapshot: true,
    );
  }

  Map<String, dynamic> _applicationHistorySnapshot(
    Map<String, dynamic> application,
  ) {
    return {
      'id': application['id'],
      'user_id': application['user_id'],
      'business_name': application['business_name'],
      'category': application['category'],
      'email': application['email'] ?? application['user_email'],
      'phone': application['phone'],
      'contact_name': application['contact_name'] ?? application['full_name'],
      'full_name': application['full_name'] ?? application['contact_name'],
      'address': application['address'],
      'city': application['city'],
      'district': application['district'],
      'tax_number': application['tax_number'],
      'documents': application['documents'],
      'logo_url': application['logo_url'],
      'created_at': application['created_at'],
      'status': application['status'],
    };
  }

  Future<List<Map<String, dynamic>>> fetchStoreApplicationHistory({
    String? actionFilter,
    int? lastDays,
    int limit = 150,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('store_application_history').select();

      if (actionFilter != null &&
          actionFilter.isNotEmpty &&
          actionFilter != 'all') {
        query = query.eq('action', actionFilter);
      }
      if (lastDays != null && lastDays > 0) {
        final since = DateTime.now()
            .toUtc()
            .subtract(Duration(days: lastDays))
            .toIso8601String();
        query = query.gte('acted_at', since);
      }

      final raw = await query
          .order('acted_at', ascending: false)
          .range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(raw as List);
    } on PostgrestException catch (error) {
      debugPrint('Store application history fetch skipped: $error');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchSellerApplicationHistoryForSeller(
    String sellerId,
  ) async {
    if (sellerId.trim().isEmpty) return const [];
    try {
      final raw = await _supabase
          .from('store_application_history')
          .select()
          .eq('seller_id', sellerId.trim())
          .order('acted_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(raw as List);
    } on PostgrestException catch (error) {
      debugPrint('Seller application history fetch skipped: $error');
      return const [];
    }
  }

  static String resolveStoreApplicationHistoryNoteBody(
    Map<String, dynamic> entry,
  ) {
    final reason = (entry['reason'] ?? '').toString().trim();
    final adminNote = (entry['admin_note'] ?? '').toString().trim();
    if (reason.isNotEmpty) return reason;
    if (adminNote.isNotEmpty) return adminNote;
    return '';
  }

  static String formatStoreApplicationHistoryNote(Map<String, dynamic> entry) {
    final action = (entry['action'] ?? '').toString();
    final body = resolveStoreApplicationHistoryNoteBody(entry);
    switch (action) {
      case storeHistoryRejected:
        return body.isEmpty ? 'Red nedeni girilmemiş.' : 'Red nedeni: $body';
      case storeHistoryChangesRequested:
        return body.isEmpty
            ? 'Eksik belge nedeni girilmemiş.'
            : 'Eksik belge nedeni: $body';
      case storeHistoryApproved:
        return body.isEmpty ? 'Başvuru onaylandı.' : 'Onay notu: $body';
      default:
        return body.isEmpty ? '-' : body;
    }
  }

  Future<void> _recordStoreApplicationHistory({
    required Map<String, dynamic> application,
    required String action,
    String? reason,
    String? adminNote,
    String? previousStatus,
    String? newStatus,
  }) async {
    try {
      final actorId = _supabase.auth.currentUser?.id;
      final trimmedReason = reason?.trim();
      final trimmedAdminNote = adminNote?.trim();
      await _supabase.from('store_application_history').insert({
        'store_id': application['user_id'],
        'seller_id': application['user_id'],
        'application_id': application['id'],
        'store_name': application['business_name'],
        'action': action,
        'reason': (trimmedReason == null || trimmedReason.isEmpty)
            ? null
            : trimmedReason,
        'admin_note': (trimmedAdminNote == null || trimmedAdminNote.isEmpty)
            ? null
            : trimmedAdminNote,
        'previous_status': previousStatus,
        'new_status': newStatus,
        'acted_by': actorId,
        'acted_at': DateTime.now().toUtc().toIso8601String(),
        'application_created_at': application['created_at'],
        'metadata': {
          'snapshot': _applicationHistorySnapshot(application),
        },
      });
    } on PostgrestException catch (error) {
      debugPrint('Store application history insert skipped: $error');
    }
  }

  String _historyActionForStatus(String status) {
    switch (status) {
      case AdminApprovalStatusConstants.approved:
        return storeHistoryApproved;
      case AdminApprovalStatusConstants.rejected:
        return storeHistoryRejected;
      case sellerApplicationMissingDocuments:
        return storeHistoryChangesRequested;
      default:
        return storeHistoryChangesRequested;
    }
  }

  String? _historyReasonForStatus(
    String status, {
    String? rejectionReason,
  }) {
    final trimmed = rejectionReason?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (status == AdminApprovalStatusConstants.rejected ||
        status == sellerApplicationMissingDocuments) {
      return trimmed;
    }
    return null;
  }

  Future<void> deleteDemoStores() async {
    // List of demo store names to delete
    const demoNames = [
      'Teknosa',
      'LC Waikiki',
      'Destina Restorant',
      'Arçelik',
      'Queen İletişim',
      'Flo',
      'Koton',
      'Toyzz Shop',
      'Arsuz Parfüm Evi',
      'Eve',
      'A101',
      'ŞOK',
      'İŞLER Kitapevi',
      'FP PRO Tamir',
    ];

    debugPrint('AdminService: Deleting demo stores: $demoNames');

    try {
      // 1. Get IDs of stores with these names
      final stores = await _supabase
          .from('stores')
          .select('seller_id')
          .filter('business_name', 'in', demoNames);

      if (stores.isEmpty) {
        debugPrint('AdminService: No demo stores found to delete.');
        return;
      }

      final ids = stores.map((s) => s['seller_id']).toList();
      debugPrint('AdminService: Found ${ids.length} demo stores. IDs: $ids');

      // 2. Delete products for these stores
      await _supabase.from('products').delete().filter('seller_id', 'in', ids);

      // 3. Delete stores
      await _supabase.from('stores').delete().filter('seller_id', 'in', ids);

      debugPrint('AdminService: Demo stores deleted successfully.');
    } catch (e) {
      debugPrint('AdminService: Error deleting demo stores: $e');
      rethrow;
    }
  }

  Future<AdminGeneralCleanupResult> runGeneralCleanup() async {
    final rpcResult = await _tryRunGeneralCleanupRpc();
    if (rpcResult != null) {
      return rpcResult;
    }
    return _runGeneralCleanupFallback();
  }

  Future<AdminGeneralCleanupResult?> _tryRunGeneralCleanupRpc() async {
    try {
      final raw = await _supabase.rpc('admin_general_cleanup');
      if (raw is! Map) return null;
      final payload = Map<String, dynamic>.from(raw);
      return AdminGeneralCleanupResult(
        deletedOrderItemHistoryCount: adminAsInt(
          payload['deleted_order_item_status_history'],
        ),
        deletedOrderItemsCount: adminAsInt(payload['deleted_order_items']),
        deletedOrdersCount: adminAsInt(payload['deleted_orders']),
        deletedNotificationsCount: adminAsInt(payload['deleted_notifications']),
        usedRpc: true,
      );
    } on PostgrestException catch (error) {
      final code = (error.code ?? '').toLowerCase();
      final message = error.message.toLowerCase();
      final missingFunction =
          code == '42883' ||
          code == 'pgrst202' ||
          message.contains('admin_general_cleanup');
      final whereClauseRequired =
          code == '21000' || message.contains('delete requires a where clause');
      if (missingFunction || whereClauseRequired) {
        debugPrint('AdminService.generalCleanup rpc unavailable, fallback.');
        return null;
      }
      rethrow;
    }
  }

  Future<AdminGeneralCleanupResult> _runGeneralCleanupFallback() async {
    try {
      final deletedHistory = await _deleteAllById('order_item_status_history');
      final deletedItems = await _deleteAllById('order_items');
      final deletedOrders = await _deleteAllById('orders');
      final deletedNotifications = await _deleteAllById('user_notifications');
      return AdminGeneralCleanupResult(
        deletedOrderItemHistoryCount: deletedHistory,
        deletedOrderItemsCount: deletedItems,
        deletedOrdersCount: deletedOrders,
        deletedNotificationsCount: deletedNotifications,
      );
    } on PostgrestException catch (error) {
      final normalized = error.toString().toLowerCase();
      if (normalized.contains('delete requires a where clause')) {
        throw Exception(
          'Temizleme için WHERE zorunluluğu aktif. SQL Editor’den SUPABASE_ADMIN_GENERAL_CLEANUP_RPC.sql dosyasını çalıştırın.',
        );
      }
      if (normalized.contains('row-level security') ||
          normalized.contains('permission') ||
          normalized.contains('policy')) {
        throw Exception(
          'Yetki hatası: RLS policy temizleme izni vermiyor. Gerekirse admin_general_cleanup RPC fonksiyonu tanımlayın.',
        );
      }
      rethrow;
    }
  }

  Future<int> _deleteAllById(String tableName) async {
    final rows = await _supabase
        .from(tableName)
        .select('id')
        .neq('id', _cleanupSentinelUuid);
    final ids = List<Map<String, dynamic>>.from(rows as List)
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) return 0;

    var deleted = 0;
    const chunkSize = 200;
    for (var start = 0; start < ids.length; start += chunkSize) {
      final end = (start + chunkSize > ids.length)
          ? ids.length
          : start + chunkSize;
      final chunk = ids.sublist(start, end);
      final response = await _supabase
          .from(tableName)
          .delete()
          .inFilter('id', chunk)
          .select('id');
      // Sadece adet okunuyor — List.from chunk başına (200'e kadar) satırı
      // gereksiz kopyalıyordu. Değer birebir aynı.
      deleted += (response as List).length;
    }
    return deleted;
  }

  Future<void> updateSellerApplicationStatus(
    String id,
    String status, {
    String? rejectionReason,
    String? adminNote,
  }) async {
    final applicationRaw = await _supabase
        .from('seller_applications')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (applicationRaw == null) {
      throw Exception('Başvuru bulunamadı');
    }
    final application = Map<String, dynamic>.from(applicationRaw);
    final previousStatus =
        (application['status'] ?? AdminApprovalStatusConstants.pending)
            .toString();

    await _recordStoreApplicationHistory(
      application: application,
      action: _historyActionForStatus(status),
      reason: _historyReasonForStatus(status, rejectionReason: rejectionReason),
      adminNote: status == AdminApprovalStatusConstants.approved
          ? adminNote
          : null,
      previousStatus: previousStatus,
      newStatus: status,
    );

    final updates = {'status': status};
    if (rejectionReason != null && rejectionReason.trim().isNotEmpty) {
      updates['rejection_reason'] = rejectionReason.trim();
    }
    if (status == AdminApprovalStatusConstants.approved) {
      updates['approved_at'] = DateTime.now().toIso8601String();

      // Onaylandığında, satıcı için 'stores' tablosunda otomatik bir kayıt oluşturmalıyız
      // Önce başvuru detaylarını çekelim
      final applicationDetails = application;

      // Eğer store zaten varsa tekrar oluşturma (seller_id kontrolü)
      final existingStore = await _supabase
          .from('stores')
          .select()
          .eq('seller_id', application['user_id'])
          .maybeSingle();

      if (existingStore == null) {
        // Yeni mağaza kaydı oluştur
        await _supabase.from('stores').insert({
          'seller_id': applicationDetails['user_id'],
          'business_name': applicationDetails['business_name'],
          'category': applicationDetails['category'],
          'email': applicationDetails['email'] ?? applicationDetails['user_email'],
          'phone': applicationDetails['phone'],
          'address': applicationDetails['address'],
          'city': applicationDetails['city'],
          'district': applicationDetails['district'],
          'postal_code': applicationDetails['postal_code'],
          'tax_number': applicationDetails['tax_number'],
          'contact_name': applicationDetails['contact_name'],
          'logo_url': applicationDetails['logo_url'],
          'store_lat': applicationDetails['store_lat'],
          'store_lng': applicationDetails['store_lng'],
          'is_store_open': true,
          'accept_new_orders': true,
          'is_verified': true,
          'rating': 0.0,
          'created_at': DateTime.now().toIso8601String(),
          // Diğer alanlar varsayılan veya boş olabilir
        });
      } else {
        // Mağaza zaten varsa eksik alanları başvurudan tamamla
        await _supabase
            .from('stores')
            .update({
              'business_name': applicationDetails['business_name'],
              'category': applicationDetails['category'],
              'email':
                  applicationDetails['email'] ?? applicationDetails['user_email'],
              'phone': applicationDetails['phone'],
              'address': applicationDetails['address'],
              'city': applicationDetails['city'],
              'district': applicationDetails['district'],
              'postal_code': applicationDetails['postal_code'],
              'tax_number': applicationDetails['tax_number'],
              'contact_name': applicationDetails['contact_name'],
              'logo_url': applicationDetails['logo_url'],
              'store_lat': applicationDetails['store_lat'],
              'store_lng': applicationDetails['store_lng'],
              'accept_new_orders': true,
              'is_verified': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('seller_id', applicationDetails['user_id']);
      }

      // Satıcı girişinin çalışması için users tablosunda rol/onay durumunu güncelle
      await _supabase.from('users').upsert({
        'id': applicationDetails['user_id'],
        'email': applicationDetails['email'] ?? applicationDetails['user_email'],
        'display_name':
            applicationDetails['contact_name'] ??
            applicationDetails['business_name'],
        'phone': applicationDetails['phone'],
        'address': applicationDetails['address'],
        'role': 'seller',
        'is_seller_approved': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
    } else if (status == AdminApprovalStatusConstants.rejected) {
      final app = application;
      if (app['user_id'] != null) {
        await _supabase
            .from('users')
            .update({
              'is_seller_approved': false,
              'role': 'user',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', app['user_id']);

        await _supabase.from('stores').delete().eq('seller_id', app['user_id']);
      }

      await _supabase.from('seller_applications').delete().eq('id', id);
      return;
    }

    await _updateSellerApplicationRecord(id, updates);
  }

  // --- Store Deletion Requests ---

  Stream<List<Map<String, dynamic>>> getStoreDeletionRequestsStream() {
    return _supabase
        .from('store_deletion_requests')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> getStoreLocationChangeRequestsStream() {
    return _supabase
        .from('store_location_change_requests')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Future<void> approveStoreDeletion(String requestId, String sellerId) async {
    // 1. Update request status
    await _supabase
        .from('store_deletion_requests')
        .update({
          'status': AdminApprovalStatusConstants.approved,
          'approved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);

    // 2. Update store status (close store)
    // Assuming we want to mark it as deleted or closed
    await _supabase
        .from('stores')
        .update({
          'is_store_open': false,
          'is_active': false, // If this column exists, or rely on is_store_open
          // 'deleted_at': DateTime.now().toIso8601String(), // If soft delete supported
        })
        .eq('seller_id', sellerId);

    // Note: Ideally this should be a transaction (RPC)
  }

  Future<void> rejectStoreDeletion(String requestId, String adminNote) async {
    await _supabase
        .from('store_deletion_requests')
        .update({
          'status': AdminApprovalStatusConstants.rejected,
          'rejected_at': DateTime.now().toIso8601String(),
          'admin_note': adminNote,
        })
        .eq('id', requestId);
  }

  Future<void> approveStoreLocationChange(
    String requestId, {
    required String sellerId,
    required double requestedLat,
    required double requestedLng,
  }) async {
    Map<String, dynamic>? updatedStore;
    try {
      updatedStore = await _supabase
          .from('stores')
          .update({
            'store_lat': requestedLat,
            'store_lng': requestedLng,
            // Legacy kolonlar bazi ortamlarda olabilir.
            'latitude': requestedLat,
            'longitude': requestedLng,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('seller_id', sellerId)
          .select('seller_id')
          .maybeSingle();
    } on PostgrestException catch (e) {
      final message = (e.message).toLowerCase();
      final missingLegacyColumn =
          message.contains("could not find the 'latitude' column") ||
          message.contains("could not find the 'longitude' column");
      if (!missingLegacyColumn) rethrow;

      // DB'de legacy kolonlar yoksa sadece aktif kolonlarla tekrar dene.
      updatedStore = await _supabase
          .from('stores')
          .update({
            'store_lat': requestedLat,
            'store_lng': requestedLng,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('seller_id', sellerId)
          .select('seller_id')
          .maybeSingle();
    }

    if (updatedStore == null) {
      throw Exception(
        'Magaza konumu guncellenemedi. Admin hesabi stores tablosunda update yetkisine sahip olmayabilir (RLS policy).',
      );
    }

    await _supabase
        .from('store_location_change_requests')
        .update({
          'status': AdminApprovalStatusConstants.approved,
          'approved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId)
        .eq('status', 'pending');
  }

  Future<void> rejectStoreLocationChange(
    String requestId, {
    String adminNote = 'Admin tarafından reddedildi',
  }) async {
    await _supabase
        .from('store_location_change_requests')
        .update({
          'status': AdminApprovalStatusConstants.rejected,
          'rejected_at': DateTime.now().toIso8601String(),
          'admin_note': adminNote,
        })
        .eq('id', requestId);
  }

  Future<Map<String, dynamic>?> getHairCareLayout() async {
    try {
      final res = await _supabase
          .from('system_layouts')
          .select()
          .eq('key', 'hair_care')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return res;
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertHairCareLayout({
    required String title,
    required String storeName,
    required String brandName,
    String? adImageUrl,
    List<String>? productIds,
    int? slot,
  }) async {
    await _supabase.from('system_layouts').upsert({
      'key': 'hair_care',
      'title': title,
      'store_name': storeName,
      'brand_name': brandName,
      'ad_image_url': adImageUrl,
      'product_ids': productIds,
      'slot': slot,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getHairCareLayouts() async {
    try {
      final res = await _supabase
          .from('system_layouts')
          .select()
          .eq('key', 'hair_care')
          .order('id');
      debugPrint(
        'AdminService: Fetched ${res.length} layouts. First item keys: ${res.isNotEmpty ? res.first.keys : "none"}',
      );
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('AdminService: Error fetching layouts: $e');
      return [];
    }
  }

  Future<void> saveHairCareLayouts(List<Map<String, dynamic>> layouts) async {
    if (layouts.isEmpty) return;

    final now = DateTime.now().toIso8601String();

    for (var layout in layouts) {
      debugPrint(
        'AdminService: Saving layout with ad_image_url: ${layout['ad_image_url']}',
      );
      final data = {
        'key': 'hair_care',
        'title': layout['title'],
        'store_name': layout['store_name'],
        'brand_name': layout['brand_name'],
        'ad_image_url': layout['ad_image_url'],
        'product_ids': layout['product_ids'],
        'slot': layout['slot'],
        'target_category': layout['target_category'], // New field
        'updated_at': now,
      };

      if (layout['id'] != null) {
        // Update existing record
        data['id'] = layout['id'];
        await _supabase.from('system_layouts').upsert(data);
      } else {
        // Insert new record
        await _supabase.from('system_layouts').insert(data);
      }
    }
  }

  Future<void> deleteSystemLayout(dynamic id) async {
    try {
      debugPrint('AdminService: Deleting system_layout with id: $id');
      final response = await _supabase
          .from('system_layouts')
          .delete()
          .eq('id', id)
          .select(); // Request return of deleted rows

      debugPrint('AdminService: Deleted rows: $response');

      if (response.isEmpty) {
        debugPrint(
          'AdminService: WARNING - No rows were deleted. Check RLS policies or if ID exists.',
        );
        throw Exception(
          'Veritabanından silinemedi. Lütfen Supabase RLS (Yetki) ayarlarını kontrol edin.',
        );
      }
    } catch (e) {
      debugPrint('AdminService: Error deleting layout: $e');
      rethrow;
    }
  }

  // --- Store Management ---

  Future<List<Map<String, dynamic>>> getAllStores() async {
    final response = await _supabase
        .from('stores')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateStore(
    String sellerId,
    Map<String, dynamic> updates,
  ) async {
    await _supabase.from('stores').update(updates).eq('seller_id', sellerId);
  }

  Future<Map<String, dynamic>> getStoreInsights(String sellerId) async {
    final storeRaw = await _supabase
        .from('stores')
        .select()
        .eq('seller_id', sellerId)
        .limit(1)
        .maybeSingle();
    final store = storeRaw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(storeRaw);

    final applicationRaw = await _supabase
        .from('seller_applications')
        .select()
        .eq('user_id', sellerId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final application = applicationRaw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(applicationRaw);

    final productsRaw = await _supabase
        .from('products')
        .select('id,price')
        .eq('seller_id', sellerId);
    final products = List<Map<String, dynamic>>.from(productsRaw);

    final rating = (store['rating'] as num?)?.toDouble() ?? 0.0;
    final productCount = products.length;
    final hasLogo = (store['logo_url'] ?? '').toString().trim().isNotEmpty;
    final isOpen = store['is_store_open'] == true;

    final email = pickFirstAdminText(store, application, const [
      'email',
      'user_email',
      'contact_email',
    ]);
    final phone = pickFirstAdminText(store, application, const [
      'phone',
      'phone_number',
      'contact_phone',
    ]);
    final address = pickFirstAdminText(store, application, const [
      'address',
      'business_address',
      'full_address',
    ]);

    final filledIdentityFields = [
      (store['business_name'] ?? '').toString().trim(),
      (store['category'] ?? '').toString().trim(),
      email,
      phone,
      address,
      hasLogo ? '1' : '',
    ].where((e) => e.isNotEmpty).length;

    final completionRatio = filledIdentityFields / 6.0;

    final applicationScore =
        ((completionRatio * 5.0) + (rating.clamp(0, 5) * 0.2))
            .clamp(0, 5)
            .toDouble();

    final trustScore =
        (((rating.clamp(0, 5) / 5.0) * 45) +
                (completionRatio * 35) +
                ((productCount >= 20 ? 1 : productCount / 20.0) * 15) +
                (isOpen ? 5 : 0))
            .round()
            .clamp(0, 100);

    final riskLevel = trustScore >= 75
        ? 'Düşük'
        : trustScore >= 45
        ? 'Orta'
        : 'Yüksek';

    final autoVerification =
        (email.isNotEmpty && phone.isNotEmpty && hasLogo && isOpen);

    return {
      'store': store,
      'application': application,
      'email': email,
      'phone': phone,
      'address': address,
      'product_count': productCount,
      'application_score': applicationScore,
      'trust_score': trustScore,
      'risk_level': riskLevel,
      'auto_verification': autoVerification,
    };
  }

  Future<List<Map<String, dynamic>>> getStoreProducts(String sellerId) async {
    final response = await _supabase
        .from('products')
        .select()
        .eq(
          'seller_id',
          sellerId,
        ) // Assuming seller_id links products to stores
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> deleteProduct(String productId) async {
    debugPrint('AdminService: Deleting product with id: $productId');
    try {
      final response = await _supabase
          .from('products')
          .delete()
          .eq('id', productId)
          .select();
      debugPrint('AdminService: Deleted product response: $response');

      if (response.isEmpty) {
        throw Exception(
          'Ürün silinemedi. Supabase RLS (Delete) yetkisi eksik olabilir.',
        );
      }
    } catch (e) {
      debugPrint('AdminService: Error deleting product: $e');
      rethrow;
    }
  }

  Future<void> deleteStore(String sellerId) async {
    debugPrint('AdminService: Deleting store with seller_id: $sellerId');
    try {
      // 1. Delete all products of this store
      final prodResponse = await _supabase
          .from('products')
          .delete()
          .eq('seller_id', sellerId)
          .select();
      debugPrint('AdminService: Deleted products response: $prodResponse');

      // 2. Delete store
      final response = await _supabase
          .from('stores')
          .delete()
          .eq('seller_id', sellerId)
          .select();

      debugPrint('AdminService: Deleted store response: $response');

      if (response.isEmpty) {
        throw Exception(
          'Mağaza silinemedi. Supabase RLS (Delete) yetkisi eksik olabilir.',
        );
      }
    } catch (e) {
      debugPrint('AdminService: Error deleting store: $e');
      rethrow;
    }
  }

  // --- Campaign Images ---

  /*
  SQL Structure:
  create table public.campaign_images (
    id bigint generated by default as identity primary key,
    image_path text not null,
    mobile_image_path text,
    title text,
    alt_text text,
    link_url text,
    sort_order int default 0,
    is_active boolean default true,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
  );
  */

  Future<List<Map<String, dynamic>>> getCampaignImages() async {
    return await _supabase
        .from('campaign_images')
        .select()
        .order('sort_order', ascending: true);
  }

  /// Ana sayfa hero banner için dar kolon seçimi.
  Future<List<Map<String, dynamic>>> getHomeCampaignImages() async {
    return List<Map<String, dynamic>>.from(
      await _supabase
          .from('campaign_images')
          .select(
            'id, image_path, mobile_image_path, is_active, sort_order',
          )
          .eq('is_active', true)
          .order('sort_order', ascending: true),
    );
  }

  Future<void> saveCampaignImage(Map<String, dynamic> image) async {
    final now = DateTime.now().toIso8601String();

    // Create a new map to avoid modifying the original one
    final data = Map<String, dynamic>.from(image);
    data['updated_at'] = now;

    if (data['id'] == null) {
      data.remove(
        'id',
      ); // Ensure 'id' is removed if null so Postgres generates it
      data['created_at'] = now;
      await _supabase.from('campaign_images').insert(data);
    } else {
      await _supabase.from('campaign_images').update(data).eq('id', data['id']);
    }
  }

  Future<void> deleteCampaignImage(int id) async {
    await _supabase.from('campaign_images').delete().eq('id', id);
  }

  Future<void> updateCampaignImagesOrder(
    List<Map<String, dynamic>> images,
  ) async {
    for (int i = 0; i < images.length; i++) {
      await _supabase
          .from('campaign_images')
          .update({'sort_order': i})
          .eq('id', images[i]['id']);
    }
  }

  // --- App Categories ---

  Future<List<Map<String, dynamic>>> getAppCategories() async {
    return await _supabase
        .from('app_categories')
        .select()
        .order('id', ascending: true);
  }

  /// Ana sayfa feature menüsü için dar kolon seçimi.
  Future<List<Map<String, dynamic>>> getHomeAppCategories() async {
    return List<Map<String, dynamic>>.from(
      await _supabase
          .from('app_categories')
          .select('id, category_key, display_name, image_url, is_active')
          .eq('is_active', true)
          .order('id', ascending: true),
    );
  }

  Future<List<CategoryWithSubcategories>> getManagedCategoriesWithSubs() async {
    final mainResponse = await _supabase
        .from('categories')
        .select()
        .filter('parent_id', 'is', null)
        .order('order_index', ascending: true);

    final mainCategories = (mainResponse as List<dynamic>)
        .map(
          (item) =>
              adminDbCategoryFromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);

    final result = <CategoryWithSubcategories>[];
    for (final mainCategory in mainCategories) {
      final mainId = mainCategory.id;
      if (mainId == null) {
        result.add(
          CategoryWithSubcategories(
            mainCategory: mainCategory,
            subCategories: const [],
          ),
        );
        continue;
      }

      final subResponse = await _supabase
          .from('categories')
          .select()
          .eq('parent_id', mainId)
          .order('order_index', ascending: true);
      final subCategories = (subResponse as List<dynamic>)
          .map(
            (item) =>
                adminDbCategoryFromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);

      result.add(
        CategoryWithSubcategories(
          mainCategory: mainCategory,
          subCategories: subCategories,
        ),
      );
    }

    return result;
  }

  Future<DBCategory> saveManagedCategory(DBCategory category) async {
    final payload = adminDbCategoryToMap(category);

    if (category.id == null) {
      final response = await _supabase
          .from('categories')
          .insert(payload)
          .select()
          .single();
      return adminDbCategoryFromMap(Map<String, dynamic>.from(response));
    }

    final response = await _supabase
        .from('categories')
        .update(payload)
        .eq('id', category.id!)
        .select()
        .single();
    return adminDbCategoryFromMap(Map<String, dynamic>.from(response));
  }

  Future<void> deleteManagedCategory({
    required DBCategory category,
    bool deleteChildren = false,
  }) async {
    final deletedPayload = adminDbCategoryToMap(
      category.copyWith(
        isActive: false,
        iconName: deletedManagedCategoryIconName,
      ),
    );

    if (category.id == null) {
      await _supabase.from('categories').insert(deletedPayload);
    } else {
      await _supabase
          .from('categories')
          .update(deletedPayload)
          .eq('id', category.id!);
    }

    if (deleteChildren && category.id != null) {
      await _supabase
          .from('categories')
          .update({
            'is_active': false,
            'icon_name': deletedManagedCategoryIconName,
          })
          .eq('parent_id', category.id!);
    }
  }

  Future<void> saveAppCategory(Map<String, dynamic> category) async {
    final data = Map<String, dynamic>.from(category);
    if (data['id'] == null) {
      data.remove('id');
    }

    await _supabase
        .from('app_categories')
        .upsert(data, onConflict: 'category_key');
  }

  Future<String> uploadCategoryImage(
    Uint8List imageBytes,
    String fileName, {
    required String categoryKey,
  }) async {
    try {
      final path = '$categoryKey/$fileName';
      await _supabase.storage
          .from('categories')
          .uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return _supabase.storage.from('categories').getPublicUrl(path);
    } catch (e) {
      debugPrint('AdminService: Error uploading category image: $e');
      if (e.toString().contains('Bucket not found')) {
        throw Exception(
          'Storage bucket "categories" bulunamadı. Lütfen Supabase panelinden oluşturun.',
        );
      }
      if (e.toString().contains('Unauthorized') ||
          e.toString().contains('statusCode: 403') ||
          e.toString().contains('row-level security policy')) {
        throw Exception(
          'Storage izni yok (RLS/Policy). "categories" bucket için upload yetkisi tanımlayın.',
        );
      }
      rethrow;
    }
  }

  // Upload Campaign Image
  Future<String> uploadCampaignImage(
    Uint8List imageBytes,
    String fileName,
  ) async {
    try {
      final path = 'campaigns/$fileName';

      // Try uploading to 'campaign_images' bucket first
      try {
        await _supabase.storage
            .from('campaign_images')
            .uploadBinary(
              path,
              imageBytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        return _supabase.storage.from('campaign_images').getPublicUrl(path);
      } catch (e) {
        // Fallback: If bucket not found, try 'banners' bucket which likely exists
        if (e.toString().contains('Bucket not found') ||
            e.toString().contains('not found')) {
          debugPrint(
            'Bucket "campaign_images" not found, trying "banners"...',
          );
          await _supabase.storage
              .from('banners')
              .uploadBinary(
                path,
                imageBytes,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  upsert: true,
                ),
              );
          return _supabase.storage.from('banners').getPublicUrl(path);
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('AdminService: Error uploading campaign image: $e');
      if (e.toString().contains('Bucket not found')) {
        throw Exception(
          'Storage bucket "campaign_images" veya "banners" bulunamadı. Lütfen Supabase panelinden oluşturun.',
        );
      }
      rethrow;
    }
  }
}

class SellerApplicationHistoryResolution {
  const SellerApplicationHistoryResolution({
    required this.application,
    required this.allowAdminActions,
    this.isSnapshot = false,
    this.linkedFromHistory = false,
  });

  final Map<String, dynamic> application;
  final bool allowAdminActions;
  final bool isSnapshot;
  final bool linkedFromHistory;
}
