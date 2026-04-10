// Models for the restaurant operations upgrade.
// See migration: 20260407_restaurant_ops_upgrade.sql

/// Payment methods accepted at the table.
enum TablePaymentMethod {
  cash,
  card,
  online,
  mixed,
  complimentary,
  other;

  String get label {
    switch (this) {
      case TablePaymentMethod.cash:
        return 'Nakit';
      case TablePaymentMethod.card:
        return 'Kart';
      case TablePaymentMethod.online:
        return 'Online / QR';
      case TablePaymentMethod.mixed:
        return 'Karma';
      case TablePaymentMethod.complimentary:
        return 'İkram';
      case TablePaymentMethod.other:
        return 'Diğer';
    }
  }

  String get value {
    switch (this) {
      case TablePaymentMethod.cash:
        return 'cash';
      case TablePaymentMethod.card:
        return 'card';
      case TablePaymentMethod.online:
        return 'online';
      case TablePaymentMethod.mixed:
        return 'mixed';
      case TablePaymentMethod.complimentary:
        return 'complimentary';
      case TablePaymentMethod.other:
        return 'other';
    }
  }

  static TablePaymentMethod fromValue(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'cash':
        return TablePaymentMethod.cash;
      case 'card':
        return TablePaymentMethod.card;
      case 'online':
        return TablePaymentMethod.online;
      case 'mixed':
        return TablePaymentMethod.mixed;
      case 'complimentary':
        return TablePaymentMethod.complimentary;
      default:
        return TablePaymentMethod.other;
    }
  }
}

/// A single payment event recorded against a table session.
class TablePayment {
  const TablePayment({
    required this.id,
    required this.sellerId,
    required this.tableNumber,
    required this.sessionKey,
    required this.amount,
    required this.method,
    required this.isClosing,
    required this.createdAt,
    this.paidBy,
    this.waiterId,
    this.waiterName,
    this.note,
  });

  final String id;
  final String sellerId;
  final int tableNumber;
  final String sessionKey;
  final double amount;
  final TablePaymentMethod method;
  final bool isClosing;
  final DateTime createdAt;
  final String? paidBy;
  final String? waiterId;
  final String? waiterName;
  final String? note;

  factory TablePayment.fromMap(Map<String, dynamic> map) {
    return TablePayment(
      id: map['id']?.toString() ?? '',
      sellerId: map['seller_id']?.toString() ?? '',
      tableNumber: _parseInt(map['table_number']),
      sessionKey: map['session_key']?.toString() ?? '',
      amount: _parseDouble(map['amount']),
      method: TablePaymentMethod.fromValue(map['method']?.toString()),
      isClosing: map['is_closing'] == true,
      createdAt: _parseDate(map['created_at']),
      paidBy: map['paid_by']?.toString(),
      waiterId: map['waiter_id']?.toString(),
      waiterName: map['waiter_name']?.toString(),
      note: map['note']?.toString(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'seller_id': sellerId,
      'table_number': tableNumber,
      'session_key': sessionKey,
      'amount': amount,
      'method': method.value,
      'is_closing': isClosing,
      if (paidBy != null && paidBy!.isNotEmpty) 'paid_by': paidBy,
      if (waiterId != null && waiterId!.isNotEmpty) 'waiter_id': waiterId,
      if (waiterName != null && waiterName!.isNotEmpty) 'waiter_name': waiterName,
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _parseDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  static DateTime _parseDate(dynamic v) {
    return DateTime.tryParse(v?.toString() ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}

/// Payment session: aggregates [TablePayment] records for a single table.
class TablePaymentSession {
  const TablePaymentSession({
    required this.sessionKey,
    required this.tableNumber,
    required this.payments,
    required this.grandTotal,
  });

  final String sessionKey;
  final int tableNumber;
  final List<TablePayment> payments;
  final double grandTotal;

  double get paidTotal =>
      payments.fold(0.0, (sum, p) => sum + p.amount);

  double get remainingTotal {
    final r = grandTotal - paidTotal;
    return r < 0 ? 0 : r;
  }

  bool get isFullyPaid => remainingTotal <= 0;

  /// Returns a human-readable summary for the operations sheet.
  String get summaryLabel {
    if (payments.isEmpty) return 'Ödeme yapılmadı';
    final count = payments.length;
    final paid = paidTotal;
    return '$count ödeme — ${_formatMoney(paid)}';
  }

  static String _formatMoney(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} ₺';
}

/// Transfer type for table transfer operations.
enum TableTransferType {
  full,
  partial,
  customerBased;

  String get label {
    switch (this) {
      case TableTransferType.full:
        return 'Tüm Sipariş';
      case TableTransferType.partial:
        return 'Seçili Ürünler';
      case TableTransferType.customerBased:
        return 'Müşteri Bazlı';
    }
  }

  String get value {
    switch (this) {
      case TableTransferType.full:
        return 'full';
      case TableTransferType.partial:
        return 'partial';
      case TableTransferType.customerBased:
        return 'customer';
    }
  }
}

/// Archived (historical) table order — read from table_order_history.
class TableOrderHistoryRecord {
  const TableOrderHistoryRecord({
    required this.id,
    required this.originalOrderId,
    required this.sellerId,
    required this.tableNumber,
    required this.items,
    required this.status,
    required this.revision,
    required this.grandTotal,
    required this.closedAt,
    required this.createdAt,
    this.paymentMethod,
    this.paymentNote,
    this.waiterName,
    this.waiterId,
    this.sessionKey,
    this.openedAt,
    this.lastEditSummary,
    this.lastEditNote,
  });

  final String id;
  final String originalOrderId;
  final String sellerId;
  final int tableNumber;
  final List<Map<String, dynamic>> items;
  final String status;
  final int revision;
  final double grandTotal;
  final DateTime closedAt;
  final DateTime createdAt;
  final String? paymentMethod;
  final String? paymentNote;
  final String? waiterName;
  final String? waiterId;
  final String? sessionKey;
  final DateTime? openedAt;
  final Map<String, dynamic>? lastEditSummary;
  final String? lastEditNote;

  Duration get sessionDuration {
    final start = openedAt ?? createdAt;
    return closedAt.difference(start);
  }

  factory TableOrderHistoryRecord.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    final items = rawItems is List
        ? rawItems.cast<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];

    return TableOrderHistoryRecord(
      id: map['id']?.toString() ?? '',
      originalOrderId: map['original_order_id']?.toString() ?? '',
      sellerId: map['seller_id']?.toString() ?? '',
      tableNumber: _parseIntS(map['table_number']),
      items: items,
      status: map['status']?.toString() ?? 'closed',
      revision: _parseIntS(map['revision'], fallback: 1),
      grandTotal: _parseDoubleS(map['grand_total']),
      closedAt:
          DateTime.tryParse(map['closed_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      paymentMethod: map['payment_method']?.toString(),
      paymentNote: map['payment_note']?.toString(),
      waiterName: map['waiter_name']?.toString(),
      waiterId: map['waiter_id']?.toString(),
      sessionKey: map['session_key']?.toString(),
      openedAt:
          DateTime.tryParse(map['opened_at']?.toString() ?? '')?.toLocal(),
      lastEditSummary: map['last_edit_summary'] is Map
          ? Map<String, dynamic>.from(map['last_edit_summary'] as Map)
          : null,
      lastEditNote: map['last_edit_note']?.toString(),
    );
  }

  static int _parseIntS(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  static double _parseDoubleS(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }
}

/// Waiter performance snapshot from the DB view / RPC.
class WaiterPerformanceRecord {
  const WaiterPerformanceRecord({
    required this.waiterId,
    required this.waiterName,
    required this.orderCount,
    required this.totalRevenue,
    required this.avgTicket,
    this.topProduct,
  });

  final String waiterId;
  final String waiterName;
  final int orderCount;
  final double totalRevenue;
  final double avgTicket;
  final String? topProduct;

  factory WaiterPerformanceRecord.fromMap(Map<String, dynamic> map) {
    return WaiterPerformanceRecord(
      waiterId: map['waiter_id']?.toString() ?? '',
      waiterName: map['waiter_name']?.toString() ?? 'Bilinmeyen',
      orderCount: _pi(map['order_count']),
      totalRevenue: _pd(map['total_revenue']),
      avgTicket: _pd(map['avg_ticket']),
      topProduct: map['top_product']?.toString(),
    );
  }

  static int _pi(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _pd(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }
}

/// A local undo-able action (stored in memory, expires after [ttl]).
class GarsonUndoAction {
  GarsonUndoAction({
    required this.tableNumber,
    required this.label,
    required this.undo,
    this.ttl = const Duration(seconds: 30),
  }) : expiresAt = DateTime.now().add(ttl);

  final int tableNumber;
  final String label;
  final Future<void> Function() undo;
  final Duration ttl;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remaining {
    final r = expiresAt.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared order-preview view model
// ─────────────────────────────────────────────────────────────────────────────

/// Unified view model used by:
///   • Gelen Siparişler compact card (list summary)
///   • OrderPreviewSheet — Adisyon / Mutfak Fişi / Sipariş Detayı tabs
///   • TableHistoryScreen — reprint quick action
///
/// Constructed from a live `table_orders` row **or** a
/// [TableOrderHistoryRecord] so the same UI works for both.
class OrderPreviewRecord {
  const OrderPreviewRecord({
    required this.orderId,
    required this.tableNumber,
    required this.items,
    required this.status,
    required this.revision,
    required this.grandTotal,
    required this.createdAt,
    this.updatedAt,
    this.closedAt,
    this.openedAt,
    this.waiterName,
    this.waiterId,
    this.closedByName,
    this.paymentMethod,
    this.paymentNote,
    this.lastEditNote,
    this.lastEditSummary,
    this.storeName,
    this.storeBranch,
    this.storePhone,
    // Print-job metadata (available when built from PrintJobModel)
    this.printHistory = const [],
    this.printerTarget,
  });

  final String orderId;
  final int tableNumber;

  /// Flat item list — each map must have: name, quantity, price.
  final List<Map<String, dynamic>> items;

  final String status;
  final int revision;
  final double grandTotal;
  final DateTime createdAt;
  /// Last significant update (for live orders). Same as [closedAt] for history.
  final DateTime? updatedAt;
  /// Timestamp when the table session was closed (history records only).
  final DateTime? closedAt;
  /// Timestamp when the table session was opened (history records only).
  final DateTime? openedAt;

  final String? waiterName;
  final String? waiterId;
  /// Who closed the table session. Populated from history records.
  final String? closedByName;
  final String? paymentMethod;
  final String? paymentNote;
  final String? lastEditNote;
  final Map<String, dynamic>? lastEditSummary;

  // Optional store metadata for adisyon preview
  final String? storeName;
  final String? storeBranch;
  final String? storePhone;

  // Operational metadata
  final List<PrintHistoryEntry> printHistory;
  final String? printerTarget;

  /// Duration of the table session (only meaningful when [closedAt] and
  /// [openedAt] are both available, i.e. from history records).
  Duration? get sessionDuration {
    final end = closedAt;
    if (end == null) return null;
    final start = openedAt ?? createdAt;
    final d = end.difference(start);
    return d.isNegative ? null : d;
  }

  // ── Convenience getters ────────────────────────────────────────────────────

  int get itemCount => items.fold(0, (s, i) => s + _qty(i));

  /// First 2 product names, then "+N daha" suffix.
  String get shortSummary {
    if (items.isEmpty) return 'Ürün yok';
    final names = items
        .take(2)
        .map((i) => '${_qty(i)}× ${i['name'] ?? '?'}')
        .join(', ');
    final rest = items.length - 2;
    return rest > 0 ? '$names +$rest daha' : names;
  }

  /// Items flagged as added in the last revision (from lastEditSummary).
  List<Map<String, dynamic>> get addedItems {
    final list = lastEditSummary?['added'];
    return list is List
        ? list.cast<Map<String, dynamic>>()
        : const [];
  }

  /// Items flagged as removed in the last revision (from lastEditSummary).
  List<Map<String, dynamic>> get removedItems {
    final list = lastEditSummary?['removed'];
    return list is List
        ? list.cast<Map<String, dynamic>>()
        : const [];
  }

  static int _qty(Map<String, dynamic> item) =>
      (item['quantity'] as num?)?.toInt() ?? 1;

  // ── Constructors ───────────────────────────────────────────────────────────

  /// Build from a live `table_orders` row.
  factory OrderPreviewRecord.fromTableOrder(Map<String, dynamic> row) {
    final rawItems = row['items'];
    final items = rawItems is List
        ? rawItems.cast<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];
    final grand = items.fold<double>(
      0,
      (s, i) => s + (_qty(i) * ((i['price'] as num?)?.toDouble() ?? 0.0)),
    );
    final rawSummary = row['last_edit_summary'];
    return OrderPreviewRecord(
      orderId: row['id']?.toString() ?? '',
      tableNumber: _pi(row['table_number']),
      items: items,
      status: row['status']?.toString() ?? 'new',
      revision: _pi(row['revision'] ?? 1),
      grandTotal: (row['grand_total'] as num?)?.toDouble() ?? grand,
      createdAt: _pd(row['created_at']),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
      waiterName: row['waiter_name']?.toString(),
      waiterId: row['waiter_id']?.toString(),
      paymentMethod: row['payment_method']?.toString(),
      lastEditNote: row['last_edit_note']?.toString(),
      lastEditSummary: rawSummary is Map<String, dynamic>
          ? rawSummary
          : null,
    );
  }

  /// Build from a [TableOrderHistoryRecord].
  factory OrderPreviewRecord.fromHistory(TableOrderHistoryRecord h) {
    return OrderPreviewRecord(
      orderId: h.originalOrderId,
      tableNumber: h.tableNumber,
      items: h.items,
      status: h.status,
      revision: h.revision,
      grandTotal: h.grandTotal,
      createdAt: h.createdAt,
      updatedAt: h.closedAt,
      closedAt: h.closedAt,
      openedAt: h.openedAt,
      waiterName: h.waiterName,
      waiterId: h.waiterId,
      closedByName: h.waiterName,   // table_order_history: waiter_name = closer
      paymentMethod: h.paymentMethod,
      paymentNote: h.paymentNote,
      lastEditNote: h.lastEditNote,
      lastEditSummary: h.lastEditSummary,
    );
  }

  static int _pi(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static DateTime _pd(dynamic v) =>
      DateTime.tryParse(v?.toString() ?? '')?.toLocal() ?? DateTime.now();
}

/// A single entry in the print history for an order.
class PrintHistoryEntry {
  const PrintHistoryEntry({
    required this.jobType,
    required this.status,
    required this.createdAt,
    this.printerName,
    this.stationName,
    this.retryCount = 0,
    this.lastError,
  });

  final String jobType;
  final String status;
  final DateTime createdAt;
  final String? printerName;
  final String? stationName;
  final int retryCount;
  final String? lastError;

  factory PrintHistoryEntry.fromPrintJob(
      Map<String, dynamic> job) {
    final payload = job['payload'];
    final p = payload is Map<String, dynamic> ? payload : <String, dynamic>{};
    return PrintHistoryEntry(
      jobType: job['job_type']?.toString() ?? '-',
      status: job['status']?.toString() ?? '-',
      createdAt: DateTime.tryParse(
              job['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      printerName: p['printer_name']?.toString(),
      stationName: p['station_name']?.toString(),
      retryCount: (job['retry_count'] as num?)?.toInt() ?? 0,
      lastError: job['last_error']?.toString(),
    );
  }
}
