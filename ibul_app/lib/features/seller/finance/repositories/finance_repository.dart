import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../models/mixed_service_order.dart';
import '../../../../services/store/table_order_history_utils.dart';
import '../../../../utils/order_status_constants.dart';
import '../helpers/today_income_builder.dart';
import '../helpers/today_revenue_breakdown_builder.dart';
import '../models/finance_models.dart';

/// Tüm Finans modülü Supabase operasyonları.
/// Stateless — state yönetimi FinanceProvider'da yapılır.
class FinanceRepository {
  FinanceRepository(
    this._sellerId, {
    List<Map<String, dynamic>> optimisticHistoryRows =
        const <Map<String, dynamic>>[],
  }) : _optimisticHistoryRows = optimisticHistoryRows
           .map((row) => Map<String, dynamic>.from(row))
           .toList(growable: false);

  final String _sellerId;
  final List<Map<String, dynamic>> _optimisticHistoryRows;
  SupabaseClient get _db => Supabase.instance.client;
  bool? _tableOrderHistorySupportsArchivedAt;

  bool _isTableOrderHistoryArchivedAtMissingError(Object error) {
    if (error is! PostgrestException) return false;
    final details =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return error.code == '42703' ||
        details.contains('archived_at does not exist') ||
        details.contains('archived_at');
  }

  Future<List<Map<String, dynamic>>> _fetchTableOrderHistoryRows({
    required String selectWithArchivedAt,
    required String selectWithoutArchivedAt,
    DateTime? from,
    int limit = 800,
  }) async {
    Future<List<Map<String, dynamic>>> run(bool includeArchivedAt) async {
      var q = _db
          .from('table_order_history')
          .select(
            includeArchivedAt ? selectWithArchivedAt : selectWithoutArchivedAt,
          )
          .eq('seller_id', _sellerId);
      if (from != null) {
        final wideFrom = from
            .subtract(const Duration(days: 1))
            .toUtc()
            .toIso8601String();
        q = includeArchivedAt
            ? q.or('closed_at.gte.$wideFrom,archived_at.gte.$wideFrom')
            : q.gte('closed_at', wideFrom);
      }
      final data = await q.limit(limit);
      return List<Map<String, dynamic>>.from(data as List);
    }

    final preferArchivedAt = _tableOrderHistorySupportsArchivedAt != false;
    try {
      final rows = await run(preferArchivedAt);
      if (preferArchivedAt) {
        _tableOrderHistorySupportsArchivedAt = true;
      }
      return rows;
    } catch (error) {
      if (preferArchivedAt &&
          _isTableOrderHistoryArchivedAtMissingError(error)) {
        _tableOrderHistorySupportsArchivedAt = false;
        return run(false);
      }
      rethrow;
    }
  }

  List<Map<String, dynamic>> _optimisticHistoryRowsInRange({
    required DateTime from,
    required DateTime to,
  }) {
    return _optimisticHistoryRows
        .where((row) {
          return TableOrderHistoryUtils.isWithinRange(
            Map<dynamic, dynamic>.from(row),
            from,
            to,
          );
        })
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  /// DB'den gelen kapalı masa geçmişine henüz yazılmamış optimistic satırları
  /// ekler — dashboard `_mergeDashboardClosedHistoryWithOptimistic` ile aynı kural.
  List<Map<String, dynamic>> _mergeFetchedHistoryWithOptimistic(
    List<Map<String, dynamic>> fetchedRows, {
    required DateTime from,
    required DateTime to,
  }) {
    final merged = fetchedRows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: true);
    for (final row in _optimisticHistoryRowsInRange(from: from, to: to)) {
      final optimisticMap = Map<dynamic, dynamic>.from(row);
      final optimisticClosedAt = TableOrderHistoryUtils.closedAt(optimisticMap);
      final optimisticRevenue = TableOrderHistoryUtils.revenue(optimisticMap);
      final optimisticTable =
          int.tryParse(optimisticMap['table_number']?.toString() ?? '') ?? 0;
      final alreadyResolved = merged.any((existing) {
        final rowMap = Map<dynamic, dynamic>.from(existing);
        final rowClosedAt = TableOrderHistoryUtils.closedAt(rowMap);
        final rowRevenue = TableOrderHistoryUtils.revenue(rowMap);
        final rowTable =
            int.tryParse(rowMap['table_number']?.toString() ?? '') ?? 0;
        final sameTable = optimisticTable > 0 && rowTable == optimisticTable;
        final sameRevenue = (rowRevenue - optimisticRevenue).abs() <= 0.01;
        final nearCloseTime =
            optimisticClosedAt != null &&
            rowClosedAt != null &&
            optimisticClosedAt.difference(rowClosedAt).inMinutes.abs() <= 10;
        return sameTable && sameRevenue && nearCloseTime;
      });
      if (!alreadyResolved) {
        merged.insert(0, Map<String, dynamic>.from(row));
      }
    }
    return merged;
  }

  double _sumOptimisticHistoryRevenue({
    required DateTime from,
    required DateTime to,
  }) {
    return sumClosedTableIncome(
      historyRows: _optimisticHistoryRowsInRange(from: from, to: to),
      from: from,
      to: to,
    );
  }

  // ─────────────────────────────────────────
  // Overview
  // ─────────────────────────────────────────

  Future<FinanceOverview> getOverview() async {
    try {
      final result = await _db.rpc(
        'finance_get_overview',
        params: {'p_seller_id': _sellerId},
      );
      // `finance_get_overview` "RETURNS TABLE" olduğunda PostgREST tek satırlık
      // bir List döndürür; "RETURNS json" olduğunda Map döner. İkisini de
      // destekle ki tip-cast hatası grafiği sessizce boş bırakmasın.
      final json = _firstRowAsMap(result);
      if (json == null) return _buildOverviewFallback();
      return FinanceOverview.fromJson(json);
    } catch (error) {
      if (!_shouldUseOverviewFallback(error)) {
        // RPC dağıtılmış ama beklenmedik bir şekil/dönüş verdiyse (ör. tip-cast)
        // yine de modülü kırma — fallback hesaplamasına düş.
        return _buildOverviewFallback();
      }
      return _buildOverviewFallback();
    }
  }

  /// PostgREST RPC sonucunu güvenli biçimde `Map`e indirger.
  /// Map → kendisi; List → ilk eleman (Map ise); aksi halde null.
  Map<String, dynamic>? _firstRowAsMap(dynamic result) {
    if (result is Map) return Map<String, dynamic>.from(result);
    if (result is List && result.isNotEmpty) {
      final first = result.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  Future<List<MonthlyTrendPoint>> getMonthlyTrend({int months = 6}) async {
    try {
      final result = await _db.rpc(
        'finance_get_monthly_trend',
        params: {'p_seller_id': _sellerId, 'p_months': months},
      );
      if (result is! List) return _buildMonthlyTrendFallback(months: months);
      return result
          .whereType<Map>()
          .map((e) => MonthlyTrendPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (error) {
      if (!_shouldUseTrendFallback(error)) {
        return _buildMonthlyTrendFallback(months: months);
      }
      return _buildMonthlyTrendFallback(months: months);
    }
  }

  bool _shouldUseOverviewFallback(Object error) {
    if (error is! PostgrestException) return false;
    final message = '${error.message} ${error.details ?? ''}'.toLowerCase();
    return error.code == '42883' ||
        message.contains('finance_get_overview') ||
        message.contains('function') ||
        message.contains('schema cache');
  }

  bool _shouldUseTrendFallback(Object error) {
    if (error is! PostgrestException) return false;
    final message = '${error.message} ${error.details ?? ''}'.toLowerCase();
    return error.code == '42883' ||
        message.contains('finance_get_monthly_trend') ||
        message.contains('function') ||
        message.contains('schema cache');
  }

  bool _shouldUseFlowFallback(Object error, String functionName) {
    if (error is! PostgrestException) return false;
    final message = '${error.message} ${error.details ?? ''}'.toLowerCase();
    return error.code == '42883' ||
        message.contains(functionName.toLowerCase()) ||
        message.contains('function') ||
        message.contains('schema cache');
  }

  Future<FinanceOverview> _buildOverviewFallback() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final today = DateTime(now.year, now.month, now.day);
    final nextWeek = today.add(const Duration(days: 7));

    try {
      final results = await Future.wait([
        _db
            .from('finance_cash_accounts')
            .select('account_type, current_balance')
            .eq('seller_id', _sellerId)
            .eq('is_active', true),
        _db
            .from('finance_income_records')
            .select('net_amount, is_collected, income_date')
            .eq('seller_id', _sellerId),
        _db
            .from('finance_expenses')
            .select('amount, is_paid, due_date, expense_date')
            .eq('seller_id', _sellerId),
        _db
            .from('finance_debts')
            .select('original_amount, paid_amount, due_date, status')
            .eq('seller_id', _sellerId),
        _db
            .from('finance_salary_records')
            .select('net_salary, period_month, period_year')
            .eq('seller_id', _sellerId)
            .eq('period_month', now.month)
            .eq('period_year', now.year),
      ]);

      final cashAccounts = (results[0] as List).cast<Map<String, dynamic>>();
      final incomes = (results[1] as List).cast<Map<String, dynamic>>();
      final expenses = (results[2] as List).cast<Map<String, dynamic>>();
      final debts = (results[3] as List).cast<Map<String, dynamic>>();
      final salaries = (results[4] as List).cast<Map<String, dynamic>>();

      double totalCashBalance = 0;
      double totalBankBalance = 0;
      for (final row in cashAccounts) {
        final balance = _toDouble(row['current_balance']);
        final accountType = row['account_type'] as String? ?? 'cash';
        if (accountType == 'cash') {
          totalCashBalance += balance;
        } else {
          totalBankBalance += balance;
        }
      }

      double pendingCollections = 0;
      double monthIncome = 0;
      for (final row in incomes) {
        final income = _toDouble(row['net_amount']);
        final incomeDate = DateTime.tryParse(
          row['income_date'] as String? ?? '',
        );
        final isCollected = row['is_collected'] as bool? ?? false;
        if (!isCollected) pendingCollections += income;
        if (incomeDate != null &&
            !incomeDate.isBefore(monthStart) &&
            !incomeDate.isAfter(monthEnd)) {
          monthIncome += income;
        }
      }

      double pendingPayments = 0;
      double monthExpense = 0;
      int overduePayments = 0;
      int upcomingPayments = 0;
      for (final row in expenses) {
        final amount = _toDouble(row['amount']);
        final expenseDate = DateTime.tryParse(
          row['expense_date'] as String? ?? '',
        );
        final dueDate = DateTime.tryParse(row['due_date'] as String? ?? '');
        final isPaid = row['is_paid'] as bool? ?? false;

        if (expenseDate != null &&
            !expenseDate.isBefore(monthStart) &&
            !expenseDate.isAfter(monthEnd)) {
          monthExpense += amount;
        }
        if (!isPaid) {
          pendingPayments += amount;
          if (dueDate != null) {
            if (dueDate.isBefore(today)) overduePayments += 1;
            if (!dueDate.isBefore(today) && !dueDate.isAfter(nextWeek)) {
              upcomingPayments += 1;
            }
          }
        }
      }

      double totalDebt = 0;
      int overdueDebts = 0;
      for (final row in debts) {
        final originalAmount = _toDouble(row['original_amount']);
        final paidAmount = _toDouble(row['paid_amount']);
        final remaining = (originalAmount - paidAmount).clamp(
          0,
          double.infinity,
        );
        final dueDate = DateTime.tryParse(row['due_date'] as String? ?? '');
        final status = row['status'] as String? ?? 'active';

        if (status != 'paid' && status != 'cancelled') {
          totalDebt += remaining;
          if (dueDate != null && dueDate.isBefore(today) && remaining > 0) {
            overdueDebts += 1;
          }
          if (dueDate != null &&
              !dueDate.isBefore(today) &&
              !dueDate.isAfter(nextWeek) &&
              remaining > 0) {
            upcomingPayments += 1;
          }
        }
      }

      final monthSalaryLoad = salaries.fold<double>(
        0,
        (sum, row) => sum + _toDouble(row['net_salary']),
      );

      final salesMonthRevenue = await getSalesRevenue(
        from: monthStart,
        to: monthEnd,
      );

      return FinanceOverview(
        totalCashBalance: totalCashBalance,
        totalBankBalance: totalBankBalance,
        pendingCollections: pendingCollections,
        pendingPayments: pendingPayments,
        totalDebt: totalDebt,
        monthSalaryLoad: monthSalaryLoad,
        monthIncome: monthIncome + salesMonthRevenue,
        monthExpense: monthExpense,
        overduePayments: overduePayments,
        upcomingPayments: upcomingPayments,
        overdueDebts: overdueDebts,
      );
    } catch (_) {
      return FinanceOverview.empty;
    }
  }

  Future<List<MonthlyTrendPoint>> _buildMonthlyTrendFallback({
    required int months,
  }) async {
    final now = DateTime.now();
    final startMonth = DateTime(now.year, now.month - months + 1, 1);
    final endMonth = DateTime(now.year, now.month + 1, 0);
    final from = startMonth.toIso8601String().substring(0, 10);
    final to = endMonth.toIso8601String().substring(0, 10);

    try {
      final results = await Future.wait([
        _db
            .from('finance_income_records')
            .select('income_date, net_amount')
            .eq('seller_id', _sellerId)
            .gte('income_date', from)
            .lte('income_date', to),
        _db
            .from('finance_expenses')
            .select('expense_date, amount')
            .eq('seller_id', _sellerId)
            .gte('expense_date', from)
            .lte('expense_date', to),
        _db
            .from('finance_salary_records')
            .select('period_year, period_month, net_salary')
            .eq('seller_id', _sellerId)
            .gte('period_year', startMonth.year - 1),
      ]);

      final incomes = (results[0] as List).cast<Map<String, dynamic>>();
      final expenses = (results[1] as List).cast<Map<String, dynamic>>();
      final salaries = (results[2] as List).cast<Map<String, dynamic>>();

      final incomeMap = <String, double>{};
      final expenseMap = <String, double>{};

      for (final row in incomes) {
        final incomeDate = DateTime.tryParse(
          row['income_date'] as String? ?? '',
        );
        if (incomeDate == null) continue;
        final key =
            '${incomeDate.year}-${incomeDate.month.toString().padLeft(2, '0')}';
        incomeMap[key] = (incomeMap[key] ?? 0) + _toDouble(row['net_amount']);
      }
      for (final row in expenses) {
        final expenseDate = DateTime.tryParse(
          row['expense_date'] as String? ?? '',
        );
        if (expenseDate == null) continue;
        final key =
            '${expenseDate.year}-${expenseDate.month.toString().padLeft(2, '0')}';
        expenseMap[key] = (expenseMap[key] ?? 0) + _toDouble(row['amount']);
      }
      for (final row in salaries) {
        final year = (row['period_year'] as num?)?.toInt();
        final month = (row['period_month'] as num?)?.toInt();
        if (year == null || month == null) continue;
        final slotDate = DateTime(year, month, 1);
        if (slotDate.isBefore(startMonth) || slotDate.isAfter(endMonth)) {
          continue;
        }
        final key = '$year-${month.toString().padLeft(2, '0')}';
        expenseMap[key] = (expenseMap[key] ?? 0) + _toDouble(row['net_salary']);
      }

      final labels = [
        'Oca',
        'Sub',
        'Mar',
        'Nis',
        'May',
        'Haz',
        'Tem',
        'Agu',
        'Eyl',
        'Eki',
        'Kas',
        'Ara',
      ];
      return List.generate(months, (index) {
        final slot = DateTime(now.year, now.month - months + index + 1, 1);
        final key = '${slot.year}-${slot.month.toString().padLeft(2, '0')}';
        final income = incomeMap[key] ?? 0;
        final expense = expenseMap[key] ?? 0;
        return MonthlyTrendPoint(
          label: labels[slot.month - 1],
          year: slot.year,
          month: slot.month,
          income: income,
          expense: expense,
          net: income - expense,
        );
      });
    } catch (_) {
      return const [];
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  // ─────────────────────────────────────────
  // Gerçek satış cirosu (order_items)
  //
  // Finans modülü manuel "gelir kayıtları" üzerine kuruluydu; satıcının asıl
  // kazancı ise `order_items` tablosunda yaşıyor. Genel Bakış'taki ciro ile
  // tutarlı olması için satış cirosunu doğrudan buradan okuyup finans gelirine
  // ekliyoruz. order_items erişilemezse 0 döner — finans modülü asla kırılmaz.
  // ─────────────────────────────────────────

  Future<double> getSalesRevenue({DateTime? from, DateTime? to}) async {
    double sum = 0;

    // ── Online satışlar: order_items ──
    try {
      var q = _db
          .from('order_items')
          .select('total_price, status, created_at')
          .eq('seller_id', _sellerId);
      if (from != null) q = q.gte('created_at', from.toIso8601String());
      if (to != null) q = q.lte('created_at', to.toIso8601String());
      final data = await q;
      for (final row in (data as List)) {
        final status = ((row as Map)['status']?.toString() ?? '').toLowerCase();
        if (OrderStatusConstants.isCancelledStatus(status)) continue;
        sum += _toDouble(row['total_price']);
      }
    } catch (_) {
      /* online satış erişilemedi */
    }

    // ── Garson satışları: table_order_history (KAPATILMIŞ masalar) ──
    var historyRevenue = 0.0;
    try {
      final data = await _fetchTableOrderHistoryRows(
        selectWithArchivedAt:
            'id, original_order_id, session_key, table_number, grand_total, '
            'items, status, closed_at, archived_at, archived_orders, '
            'display_table_label, table_display_name, table_name, '
            'payment_method, payment_note',
        selectWithoutArchivedAt:
            'id, original_order_id, session_key, table_number, grand_total, '
            'items, status, closed_at, archived_orders, '
            'display_table_label, table_display_name, table_name, '
            'payment_method, payment_note',
        from: from,
      );
      final rangeFrom = from ?? DateTime(2000);
      final rangeTo = to ?? DateTime(2100, 12, 31);
      final mergedHistory = _mergeFetchedHistoryWithOptimistic(
        data,
        from: rangeFrom,
        to: rangeTo,
      );
      historyRevenue = sumClosedTableIncome(
        historyRows: mergedHistory,
        from: rangeFrom,
        to: rangeTo,
      );
      sum += historyRevenue;
    } catch (_) {
      /* kapalı masa geçmişi erişilemedi */
    }

    if (historyRevenue <= 0) {
      final optimisticFrom = from ?? DateTime(2000);
      final optimisticTo = to ?? DateTime(2100, 12, 31);
      sum += _sumOptimisticHistoryRevenue(
        from: optimisticFrom,
        to: optimisticTo,
      );
    }

    return sum;
  }

  /// Kapatılmış bir masa kaydının (table_order_history satırı) cirosu.
  /// Önce `grand_total` kolonu kullanılır; yoksa items satır toplamına düşülür.
  double _historyRowRevenue(Map row) =>
      TableOrderHistoryUtils.revenue(Map<dynamic, dynamic>.from(row));

  Future<List<TodayIncomeLine>> getTodayIncomeBreakdown() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    var historyRows = const <Map<String, dynamic>>[];
    var onlineRows = const <Map<String, dynamic>>[];
    var manualIncomeRows = const <Map<String, dynamic>>[];

    try {
      historyRows = await _fetchTableOrderHistoryRows(
        selectWithArchivedAt:
            'id, original_order_id, session_key, table_number, grand_total, '
            'items, status, closed_at, archived_at, archived_orders, '
            'display_table_label, table_display_name, table_name, '
            'payment_method, payment_note',
        selectWithoutArchivedAt:
            'id, original_order_id, session_key, table_number, grand_total, '
            'items, status, closed_at, archived_orders, '
            'display_table_label, table_display_name, table_name, '
            'payment_method, payment_note',
        from: from,
      );
    } catch (_) {
      /* garson geçmişi okunamadı */
    }
    historyRows = historyRows.isEmpty
        ? _optimisticHistoryRowsInRange(from: from, to: to)
        : _mergeFetchedHistoryWithOptimistic(
            historyRows,
            from: from,
            to: to,
          );

    try {
      onlineRows = List<Map<String, dynamic>>.from(
        await _db
            .from('order_items')
            .select('order_id, total_price, status, created_at, product_name')
            .eq('seller_id', _sellerId)
            .gte('created_at', from.toUtc().toIso8601String())
            .lte('created_at', to.toUtc().toIso8601String()),
      );
    } catch (_) {
      /* online satış okunamadı */
    }

    try {
      manualIncomeRows = List<Map<String, dynamic>>.from(
        await _db
            .from('finance_income_records')
            .select(
              'id, net_amount, source, description, income_type, income_date, '
              'is_collected',
            )
            .eq('seller_id', _sellerId)
            .gte('income_date', from.toIso8601String().split('T').first)
            .lte('income_date', to.toIso8601String().split('T').first),
      );
    } catch (_) {
      /* manuel gelir okunamadı */
    }

    return buildTodayIncomeLines(
      from: from,
      to: to,
      historyRows: historyRows,
      onlineRows: onlineRows,
      manualIncomeRows: manualIncomeRows,
    );
  }

  Future<TodayRevenueBreakdown> getTodayRevenueBreakdown() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    var historyRows = const <Map<String, dynamic>>[];
    var onlineRows = const <Map<String, dynamic>>[];
    var manualIncomeRows = const <Map<String, dynamic>>[];

    try {
      historyRows = await _fetchTableOrderHistoryRows(
        selectWithArchivedAt:
            'id, original_order_id, session_key, table_number, grand_total, '
            'items, status, closed_at, archived_at, archived_orders, '
            'display_table_label, table_display_name, table_name, table_area_name, '
            'payment_method, payment_note',
        selectWithoutArchivedAt:
            'id, original_order_id, session_key, table_number, grand_total, '
            'items, status, closed_at, archived_orders, '
            'display_table_label, table_display_name, table_name, table_area_name, '
            'payment_method, payment_note',
        from: from,
      );
    } catch (_) {
      /* garson geçmişi okunamadı */
    }
    historyRows = historyRows.isEmpty
        ? _optimisticHistoryRowsInRange(from: from, to: to)
        : _mergeFetchedHistoryWithOptimistic(
            historyRows,
            from: from,
            to: to,
          );

    try {
      onlineRows = List<Map<String, dynamic>>.from(
        await _db
            .from('order_items')
            .select('order_id, total_price, status, created_at, product_name')
            .eq('seller_id', _sellerId)
            .gte('created_at', from.toUtc().toIso8601String())
            .lte('created_at', to.toUtc().toIso8601String()),
      );
    } catch (_) {
      /* online satış okunamadı */
    }

    try {
      manualIncomeRows = List<Map<String, dynamic>>.from(
        await _db
            .from('finance_income_records')
            .select(
              'id, net_amount, source, description, income_type, income_date, '
              'is_collected',
            )
            .eq('seller_id', _sellerId)
            .gte('income_date', from.toIso8601String().split('T').first)
            .lte('income_date', to.toIso8601String().split('T').first),
      );
    } catch (_) {
      /* manuel gelir okunamadı */
    }

    var storeTableRows = const <Map<String, dynamic>>[];
    try {
      storeTableRows = List<Map<String, dynamic>>.from(
        await _db
            .from('store_tables')
            .select('id, table_number, area_name, area_id, display_label')
            .eq('seller_id', _sellerId)
            .eq('is_active', true),
      );
    } catch (_) {
      /* store_tables okunamadı — history alanı tek kaynak kalır */
    }

    return buildTodayRevenueBreakdown(
      from: from,
      to: to,
      historyRows: historyRows,
      onlineRows: onlineRows,
      manualIncomeRows: manualIncomeRows,
      storeTableRows: storeTableRows,
    );
  }

  /// Günlük gelir + gider serisi — finans performans grafiği için.
  Future<List<DailyFinanceTrendPoint>> getDailyFinanceTrend({
    required DateTime from,
    required DateTime to,
  }) async {
    final sales = await getDailySalesSeries(from: from, to: to);
    final expenseByDay = <DateTime, double>{};
    DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

    try {
      final data = await _db
          .from('finance_expenses')
          .select('expense_date, amount')
          .eq('seller_id', _sellerId)
          .gte('expense_date', from.toIso8601String().substring(0, 10))
          .lte('expense_date', to.toIso8601String().substring(0, 10));
      for (final raw in (data as List)) {
        final row = raw as Map;
        final expenseDate = DateTime.tryParse(
          row['expense_date']?.toString() ?? '',
        );
        if (expenseDate == null) continue;
        final key = dayKey(expenseDate);
        expenseByDay[key] = (expenseByDay[key] ?? 0) + _toDouble(row['amount']);
      }
    } catch (_) {
      /* gider okunamadı */
    }

    if (sales.isEmpty) {
      var cursor = dayKey(from);
      final lastDay = dayKey(to);
      final points = <DailyFinanceTrendPoint>[];
      while (!cursor.isAfter(lastDay)) {
        points.add(
          DailyFinanceTrendPoint(
            date: cursor,
            income: 0,
            expense: expenseByDay[cursor] ?? 0,
          ),
        );
        cursor = cursor.add(const Duration(days: 1));
      }
      return points;
    }

    return sales
        .map(
          (point) => DailyFinanceTrendPoint(
            date: point.date,
            income: point.revenue,
            expense: expenseByDay[dayKey(point.date)] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  /// Gerçek satışların (online `order_items` + garson `table_orders`) ürün
  /// bazında dökümü. "Neler satıldı, ne kadar ciro" → Gelirler sekmesinde
  /// gösterilir. Erişim hatası olursa boş döner (modül kırılmaz).
  Future<SalesBreakdown> getSalesBreakdown({
    DateTime? from,
    DateTime? to,
  }) async {
    final products = <String, SoldProduct>{};
    double onlineRevenue = 0;
    double garsonRevenue = 0;
    final onlineOrderIds = <String>{};
    int garsonOrderCount = 0;

    // ── Online satışlar: order_items ──
    try {
      var q = _db
          .from('order_items')
          .select(
            'order_id, product_name, quantity, total_price, unit_price, status, created_at',
          )
          .eq('seller_id', _sellerId);
      if (from != null) q = q.gte('created_at', from.toIso8601String());
      if (to != null) q = q.lte('created_at', to.toIso8601String());
      final data = await q;
      for (final raw in (data as List)) {
        final row = raw as Map;
        final status = (row['status']?.toString() ?? '').toLowerCase();
        if (OrderStatusConstants.isCancelledStatus(status)) continue;
        final qty = (row['quantity'] as num?)?.toInt() ?? 1;
        final line = row['total_price'] != null
            ? _toDouble(row['total_price'])
            : _toDouble(row['unit_price']) * qty;
        final name =
            (row['product_name']?.toString().trim().isNotEmpty ?? false)
            ? row['product_name'].toString().trim()
            : 'Ürün';
        onlineRevenue += line;
        final oid = row['order_id']?.toString();
        if (oid != null) onlineOrderIds.add(oid);
        final p = products.putIfAbsent(name, () => SoldProduct(name: name));
        p.quantity += qty;
        p.revenue += line;
        p.online = true;
      }
    } catch (_) {
      /* online satış erişilemedi */
    }

    // ── Garson satışları: table_order_history (KAPATILMIŞ masalar) ──
    try {
      final data = await _fetchTableOrderHistoryRows(
        selectWithArchivedAt:
            'grand_total, items, status, closed_at, archived_at, '
            'archived_orders, table_number',
        selectWithoutArchivedAt:
            'grand_total, items, status, closed_at, archived_orders, '
            'table_number',
        from: from,
      );
      final rangeFrom = from ?? DateTime(2000);
      final rangeTo = to ?? DateTime(2100, 12, 31);
      final merged = _mergeFetchedHistoryWithOptimistic(
        List<Map<String, dynamic>>.from(data),
        from: rangeFrom,
        to: rangeTo,
      );
      for (final raw in merged) {
        final row = Map<dynamic, dynamic>.from(raw);
        final status = (row['status']?.toString() ?? '').toLowerCase();
        if (OrderStatusConstants.isCancelledStatus(status)) continue;
        if (!TableOrderHistoryUtils.isWithinRange(row, rangeFrom, rangeTo)) {
          continue;
        }
        garsonOrderCount++;
        final sessionRevenue = _historyRowRevenue(row);
        garsonRevenue += sessionRevenue;
        for (final item in _parseJsonList(row['items'])) {
          final normalized = MixedServiceOrder.normalizeOrderItem(item);
          final qty = (normalized['quantity'] as num?)?.toInt() ?? 1;
          final line = MixedServiceOrder.itemLineTotal(normalized);
          final name = (normalized['item_name'] ?? normalized['name'])
              ?.toString()
              .trim();
          final label = (name != null && name.isNotEmpty) ? name : 'Ürün';
          final p = products.putIfAbsent(label, () => SoldProduct(name: label));
          p.quantity += qty;
          p.revenue += line;
          p.garson = true;
        }
        if (_parseJsonList(row['items']).isEmpty && sessionRevenue > 0) {
          final label = TableOrderHistoryUtils.tableLabel(row);
          final p = products.putIfAbsent(label, () => SoldProduct(name: label));
          p.quantity += 1;
          p.revenue += sessionRevenue;
          p.garson = true;
        }
      }
    } catch (_) {
      /* garson satış erişilemedi */
    }

    if (garsonRevenue <= 0 && garsonOrderCount == 0) {
      final optimisticRows = _optimisticHistoryRowsInRange(
        from: from ?? DateTime(2000),
        to: to ?? DateTime(2100, 12, 31),
      );
      for (final row in optimisticRows) {
        final typedRow = Map<dynamic, dynamic>.from(row);
        final sessionRevenue = _historyRowRevenue(typedRow);
        if (sessionRevenue <= 0) continue;
        garsonOrderCount++;
        garsonRevenue += sessionRevenue;
        for (final item in _parseJsonList(typedRow['items'])) {
          final normalized = MixedServiceOrder.normalizeOrderItem(item);
          final qty = (normalized['quantity'] as num?)?.toInt() ?? 1;
          final line = MixedServiceOrder.itemLineTotal(normalized);
          final name = (normalized['item_name'] ?? normalized['name'])
              ?.toString()
              .trim();
          final label = (name != null && name.isNotEmpty) ? name : 'Ürün';
          final p = products.putIfAbsent(label, () => SoldProduct(name: label));
          p.quantity += qty;
          p.revenue += line;
          p.garson = true;
        }
        if (_parseJsonList(typedRow['items']).isEmpty && sessionRevenue > 0) {
          final label = TableOrderHistoryUtils.tableLabel(typedRow);
          final p = products.putIfAbsent(label, () => SoldProduct(name: label));
          p.quantity += 1;
          p.revenue += sessionRevenue;
          p.garson = true;
        }
      }
    }

    final list = products.values.toList(growable: false)
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    return SalesBreakdown(
      onlineRevenue: onlineRevenue,
      garsonRevenue: garsonRevenue,
      onlineOrderCount: onlineOrderIds.length,
      garsonOrderCount: garsonOrderCount,
      products: list,
    );
  }

  /// Günlük satış serisi: "Gelir & Sipariş" grafiği için. Her gün için ciro
  /// (online `order_items` created_at + kapalı masa `table_order_history`
  /// closed_at) ve sipariş adedi döner. [from]..[to] arası tüm günler (ciro 0
  /// olsa bile) dahil edilir ki grafik düz/boş görünmesin.
  Future<List<DailySalesPoint>> getDailySalesSeries({
    required DateTime from,
    required DateTime to,
  }) async {
    DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
    final revenueByDay = <DateTime, double>{};
    final ordersByDay = <DateTime, int>{};
    final onlineOrderIdsByDay = <DateTime, Set<String>>{};

    final fromStart = dayKey(from);
    final toEnd = DateTime(to.year, to.month, to.day, 23, 59, 59);

    // ── Online: order_items (created_at) ──
    try {
      final data = await _db
          .from('order_items')
          .select('order_id, total_price, status, created_at')
          .eq('seller_id', _sellerId)
          .gte('created_at', fromStart.toIso8601String())
          .lte('created_at', toEnd.toIso8601String());
      for (final raw in (data as List)) {
        final row = raw as Map;
        final status = (row['status']?.toString() ?? '').toLowerCase();
        if (OrderStatusConstants.isCancelledStatus(status)) continue;
        final created = DateTime.tryParse(
          row['created_at']?.toString() ?? '',
        )?.toLocal();
        if (created == null) continue;
        final key = dayKey(created);
        revenueByDay[key] =
            (revenueByDay[key] ?? 0) + _toDouble(row['total_price']);
        final oid = row['order_id']?.toString();
        if (oid != null) {
          (onlineOrderIdsByDay[key] ??= <String>{}).add(oid);
        }
      }
    } catch (_) {
      /* online satış erişilemedi */
    }

    // ── Garson: table_order_history (closed_at veya archived_at) ──
    final loadedGarsonDayKeys = <DateTime>{};
    try {
      final data = await _fetchTableOrderHistoryRows(
        selectWithArchivedAt:
            'grand_total, items, status, closed_at, archived_at, archived_orders',
        selectWithoutArchivedAt:
            'grand_total, items, status, closed_at, archived_orders',
        from: fromStart,
      );
      for (final raw in data) {
        final row = Map<dynamic, dynamic>.from(raw as Map);
        final status = (row['status']?.toString() ?? '').toLowerCase();
        if (OrderStatusConstants.isCancelledStatus(status)) continue;
        final closed = TableOrderHistoryUtils.closedAt(row);
        if (closed == null) continue;
        if (closed.isBefore(fromStart) || closed.isAfter(toEnd)) continue;
        final key = dayKey(closed);
        revenueByDay[key] = (revenueByDay[key] ?? 0) + _historyRowRevenue(row);
        ordersByDay[key] = (ordersByDay[key] ?? 0) + 1;
        loadedGarsonDayKeys.add(key);
      }
    } catch (_) {
      /* kapalı masa geçmişi erişilemedi */
    }

    for (final row in _optimisticHistoryRowsInRange(
      from: fromStart,
      to: toEnd,
    )) {
      final typedRow = Map<dynamic, dynamic>.from(row);
      final closed = TableOrderHistoryUtils.closedAt(typedRow);
      if (closed == null) continue;
      final key = dayKey(closed);
      if (loadedGarsonDayKeys.contains(key)) continue;
      revenueByDay[key] =
          (revenueByDay[key] ?? 0) + _historyRowRevenue(typedRow);
      ordersByDay[key] = (ordersByDay[key] ?? 0) + 1;
    }

    // Tüm günleri (boş olsa bile) doldur.
    final points = <DailySalesPoint>[];
    var cursor = fromStart;
    final lastDay = dayKey(to);
    while (!cursor.isAfter(lastDay)) {
      final online = onlineOrderIdsByDay[cursor]?.length ?? 0;
      final garson = ordersByDay[cursor] ?? 0;
      points.add(
        DailySalesPoint(
          date: cursor,
          revenue: revenueByDay[cursor] ?? 0,
          orderCount: online + garson,
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    return points;
  }

  List<Map<String, dynamic>> _parseJsonList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false);
        }
      } catch (_) {
        /* geçersiz JSON */
      }
    }
    return const [];
  }

  /// 'yyyy-MM' anahtarlı aylık satış cirosu haritası (trend grafiği için).
  Future<Map<String, double>> getMonthlySalesRevenue({int months = 6}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - months + 1, 1);
    final map = <String, double>{};

    String? keyFor(dynamic createdRaw) {
      final created = DateTime.tryParse(
        createdRaw?.toString() ?? '',
      )?.toLocal();
      if (created == null) return null;
      return '${created.year}-${created.month.toString().padLeft(2, '0')}';
    }

    // ── Online satışlar: order_items ──
    try {
      final data = await _db
          .from('order_items')
          .select('total_price, status, created_at')
          .eq('seller_id', _sellerId)
          .gte('created_at', start.toIso8601String());
      for (final row in (data as List)) {
        final status = ((row as Map)['status']?.toString() ?? '').toLowerCase();
        if (OrderStatusConstants.isCancelledStatus(status)) continue;
        final key = keyFor(row['created_at']);
        if (key == null) continue;
        map[key] = (map[key] ?? 0) + _toDouble(row['total_price']);
      }
    } catch (_) {
      /* online satış erişilemedi */
    }

    // ── Garson satışları: table_order_history (KAPATILMIŞ masalar) ──
    final loadedMonthKeys = <String>{};
    try {
      final data = await _fetchTableOrderHistoryRows(
        selectWithArchivedAt:
            'grand_total, items, status, closed_at, archived_at, archived_orders',
        selectWithoutArchivedAt:
            'grand_total, items, status, closed_at, archived_orders',
        from: start,
      );
      for (final raw in data) {
        final row = Map<dynamic, dynamic>.from(raw as Map);
        final status = (row['status']?.toString() ?? '').toLowerCase();
        if (OrderStatusConstants.isCancelledStatus(status)) continue;
        final key = keyFor(row['closed_at'] ?? row['archived_at']);
        if (key == null) continue;
        map[key] = (map[key] ?? 0) + _historyRowRevenue(row);
        loadedMonthKeys.add(key);
      }
    } catch (_) {
      /* kapalı masa geçmişi erişilemedi */
    }

    for (final row in _optimisticHistoryRowsInRange(
      from: start,
      to: DateTime(now.year, now.month, now.day, 23, 59, 59),
    )) {
      final typedRow = Map<dynamic, dynamic>.from(row);
      final key = keyFor(typedRow['closed_at'] ?? typedRow['archived_at']);
      if (key == null || loadedMonthKeys.contains(key)) continue;
      map[key] = (map[key] ?? 0) + _historyRowRevenue(typedRow);
    }

    return map;
  }

  // ─────────────────────────────────────────
  // Suppliers
  // ─────────────────────────────────────────

  Future<List<FinanceSupplier>> getSuppliers({bool activeOnly = true}) async {
    var q = _db.from('finance_suppliers').select().eq('seller_id', _sellerId);
    if (activeOnly) q = q.eq('is_active', true);
    final data = await q.order('name');
    return (data as List)
        .map((e) => FinanceSupplier.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FinanceSupplier> createSupplier(FinanceSupplier s) async {
    final row = await _db
        .from('finance_suppliers')
        .insert(s.toInsertJson(_sellerId))
        .select()
        .single();
    return FinanceSupplier.fromJson(row);
  }

  Future<void> updateSupplier(String id, Map<String, dynamic> fields) async {
    await _db
        .from('finance_suppliers')
        .update(fields)
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  Future<void> deleteSupplier(String id) async {
    await _db
        .from('finance_suppliers')
        .update({'is_active': false})
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  // ─────────────────────────────────────────
  // Cash Accounts
  // ─────────────────────────────────────────

  Future<List<CashAccount>> getCashAccounts({bool activeOnly = true}) async {
    var q = _db
        .from('finance_cash_accounts')
        .select()
        .eq('seller_id', _sellerId);
    if (activeOnly) q = q.eq('is_active', true);
    final data = await q.order('created_at');
    return (data as List)
        .map((e) => CashAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CashAccount> createCashAccount(CashAccount a) async {
    final row = await _db
        .from('finance_cash_accounts')
        .insert(a.toInsertJson(_sellerId))
        .select()
        .single();
    return CashAccount.fromJson(row);
  }

  Future<void> updateCashAccount(String id, Map<String, dynamic> fields) async {
    await _db
        .from('finance_cash_accounts')
        .update(fields)
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  Future<void> deactivateCashAccount(String id) async {
    await _db
        .from('finance_cash_accounts')
        .update({'is_active': false})
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  // ─────────────────────────────────────────
  // Cash Movements
  // ─────────────────────────────────────────

  Future<List<CashMovement>> getCashMovements({
    String? accountId,
    DateTime? from,
    DateTime? to,
    int limit = 50,
  }) async {
    var q = _db
        .from('finance_cash_movements')
        .select('*, finance_cash_accounts(name)')
        .eq('seller_id', _sellerId);
    if (accountId != null) q = q.eq('account_id', accountId);
    if (from != null) {
      q = q.gte('movement_date', from.toIso8601String().substring(0, 10));
    }
    if (to != null) {
      q = q.lte('movement_date', to.toIso8601String().substring(0, 10));
    }
    final data = await q.order('movement_date', ascending: false).limit(limit);
    return (data as List)
        .map((e) => CashMovement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CashMovement> createCashMovement(CashMovement m) async {
    final row = await _db
        .from('finance_cash_movements')
        .insert(m.toInsertJson(_sellerId))
        .select('*, finance_cash_accounts(name)')
        .single();
    return CashMovement.fromJson(row);
  }

  Future<void> deleteCashMovement(String id) async {
    await _db
        .from('finance_cash_movements')
        .delete()
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  // ─────────────────────────────────────────
  // Income Records
  // ─────────────────────────────────────────

  Future<List<IncomeRecord>> getIncomeRecords({
    DateTime? from,
    DateTime? to,
    bool? collected,
    int limit = 100,
  }) async {
    var q = _db
        .from('finance_income_records')
        .select()
        .eq('seller_id', _sellerId);
    if (from != null) {
      q = q.gte('income_date', from.toIso8601String().substring(0, 10));
    }
    if (to != null) {
      q = q.lte('income_date', to.toIso8601String().substring(0, 10));
    }
    if (collected != null) q = q.eq('is_collected', collected);
    final data = await q.order('income_date', ascending: false).limit(limit);
    return (data as List)
        .map((e) => IncomeRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<IncomeRecord> createIncomeRecord(IncomeRecord r) async {
    final row = await _db
        .from('finance_income_records')
        .insert(r.toInsertJson(_sellerId))
        .select()
        .single();
    return IncomeRecord.fromJson(row);
  }

  Future<void> markIncomeCollected(String id, String? accountId) async {
    await _db
        .from('finance_income_records')
        .update({
          'is_collected': true,
          'collected_at': DateTime.now().toIso8601String(),
          ...?switch (accountId) {
            final value? => <String, dynamic>{'account_id': value},
            null => null,
          },
        })
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  Future<void> updateIncomeRecord(
    String id,
    Map<String, dynamic> fields,
  ) async {
    await _db
        .from('finance_income_records')
        .update(fields)
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  Future<void> deleteIncomeRecord(String id) async {
    await _db
        .from('finance_income_records')
        .delete()
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  // ─────────────────────────────────────────
  // Expenses
  // ─────────────────────────────────────────

  Future<List<Expense>> getExpenses({
    DateTime? from,
    DateTime? to,
    bool? paid,
    String? category,
    int limit = 100,
  }) async {
    var q = _db
        .from('finance_expenses')
        .select('*, finance_suppliers(name)')
        .eq('seller_id', _sellerId);
    if (from != null) {
      q = q.gte('expense_date', from.toIso8601String().substring(0, 10));
    }
    if (to != null) {
      q = q.lte('expense_date', to.toIso8601String().substring(0, 10));
    }
    if (paid != null) q = q.eq('is_paid', paid);
    if (category != null) q = q.eq('category', category);
    final data = await q.order('expense_date', ascending: false).limit(limit);
    return (data as List)
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Expense> createExpense(Expense e) async {
    final row = await _db
        .from('finance_expenses')
        .insert(e.toInsertJson(_sellerId))
        .select('*, finance_suppliers(name)')
        .single();
    return Expense.fromJson(row);
  }

  Future<void> markExpensePaid(String id, String? accountId) async {
    await _db
        .from('finance_expenses')
        .update({
          'is_paid': true,
          'paid_at': DateTime.now().toIso8601String(),
          ...?switch (accountId) {
            final value? => <String, dynamic>{'account_id': value},
            null => null,
          },
        })
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  Future<void> payExpense({
    required String expenseId,
    String? accountId,
    String? description,
    DateTime? paymentDate,
  }) async {
    final effectiveDate = paymentDate ?? DateTime.now();
    try {
      await _db.rpc(
        'finance_pay_expense',
        params: {
          'p_seller_id': _sellerId,
          'p_expense_id': expenseId,
          'p_account_id': accountId,
          'p_description': description,
          'p_payment_date': effectiveDate.toIso8601String().substring(0, 10),
          'p_create_cash_movement': accountId != null,
        },
      );
      return;
    } catch (error) {
      if (!_shouldUseFlowFallback(error, 'finance_pay_expense')) rethrow;
    }

    await markExpensePaid(expenseId, accountId);
    if (accountId != null) {
      final expenseRow = await _db
          .from('finance_expenses')
          .select('amount, category, description')
          .eq('id', expenseId)
          .eq('seller_id', _sellerId)
          .single();
      final amount = _toDouble(expenseRow['amount']);
      await createCashMovement(
        CashMovement(
          id: '',
          sellerId: _sellerId,
          accountId: accountId,
          movementType: CashMovementType.expense,
          amount: amount,
          direction: 'out',
          referenceId: expenseId,
          referenceType: 'expense_payment',
          description: description ?? expenseRow['description'] as String?,
          movementDate: effectiveDate,
          createdAt: effectiveDate,
        ),
      );
    }
  }

  Future<void> updateExpense(String id, Map<String, dynamic> fields) async {
    await _db
        .from('finance_expenses')
        .update(fields)
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  Future<void> deleteExpense(String id) async {
    await _db
        .from('finance_expenses')
        .delete()
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  // ─────────────────────────────────────────
  // Debts
  // ─────────────────────────────────────────

  Future<List<Debt>> getDebts({String? status}) async {
    var q = _db.from('finance_debts').select().eq('seller_id', _sellerId);
    if (status != null) q = q.eq('status', status);
    final data = await q.order('created_at', ascending: false);
    return (data as List)
        .map((e) => Debt.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Debt> createDebt(Debt d) async {
    final row = await _db
        .from('finance_debts')
        .insert(d.toInsertJson(_sellerId))
        .select()
        .single();
    return Debt.fromJson(row);
  }

  Future<void> updateDebt(String id, Map<String, dynamic> fields) async {
    await _db
        .from('finance_debts')
        .update(fields)
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  Future<void> deleteDebt(String id) async {
    await _db
        .from('finance_debts')
        .delete()
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  // ─────────────────────────────────────────
  // Debt Payments
  // ─────────────────────────────────────────

  Future<List<DebtPayment>> getDebtPayments(String debtId) async {
    final data = await _db
        .from('finance_debt_payments')
        .select()
        .eq('debt_id', debtId)
        .eq('seller_id', _sellerId)
        .order('payment_date', ascending: false);
    return (data as List)
        .map((e) => DebtPayment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DebtPayment> createDebtPayment(DebtPayment p) async {
    final row = await _db
        .from('finance_debt_payments')
        .insert(p.toInsertJson(_sellerId))
        .select()
        .single();
    return DebtPayment.fromJson(row);
  }

  Future<void> recordDebtPayment({
    required DebtPayment payment,
    bool createLinkedCashMovement = true,
  }) async {
    try {
      await _db.rpc(
        'finance_record_debt_payment',
        params: {
          'p_seller_id': _sellerId,
          'p_debt_id': payment.debtId,
          'p_amount': payment.amount,
          'p_account_id': payment.accountId,
          'p_description': payment.description,
          'p_payment_date': payment.paymentDate.toIso8601String().substring(
            0,
            10,
          ),
          'p_create_cash_movement':
              createLinkedCashMovement && payment.accountId != null,
        },
      );
      return;
    } catch (error) {
      if (!_shouldUseFlowFallback(error, 'finance_record_debt_payment')) {
        rethrow;
      }
    }

    await createDebtPayment(payment);
    if (createLinkedCashMovement && payment.accountId != null) {
      final debtRow = await _db
          .from('finance_debts')
          .select('debt_type, creditor_name, description')
          .eq('id', payment.debtId)
          .eq('seller_id', _sellerId)
          .single();
      final debtType = debtRow['debt_type'] as String? ?? 'other';
      await createCashMovement(
        CashMovement(
          id: '',
          sellerId: _sellerId,
          accountId: payment.accountId!,
          movementType: debtType == 'supplier'
              ? CashMovementType.supplierPayment
              : CashMovementType.expense,
          amount: payment.amount,
          direction: 'out',
          referenceId: payment.debtId,
          referenceType: 'debt_payment',
          description:
              payment.description ?? debtRow['creditor_name'] as String?,
          movementDate: payment.paymentDate,
          createdAt: payment.createdAt,
        ),
      );
    }
  }

  Future<void> deleteDebtPayment(String id) async {
    await _db
        .from('finance_debt_payments')
        .delete()
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  // ─────────────────────────────────────────
  // Employees
  // ─────────────────────────────────────────

  Future<List<FinanceEmployee>> getEmployees({bool activeOnly = true}) async {
    var q = _db.from('finance_employees').select().eq('seller_id', _sellerId);
    if (activeOnly) q = q.eq('is_active', true);
    final data = await q.order('full_name');
    return (data as List)
        .map((e) => FinanceEmployee.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FinanceEmployee> createEmployee(FinanceEmployee e) async {
    final row = await _db
        .from('finance_employees')
        .insert(e.toInsertJson(_sellerId))
        .select()
        .single();
    return FinanceEmployee.fromJson(row);
  }

  Future<void> updateEmployee(String id, Map<String, dynamic> fields) async {
    await _db
        .from('finance_employees')
        .update(fields)
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  Future<void> deactivateEmployee(String id) async {
    await _db
        .from('finance_employees')
        .update({'is_active': false})
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  // ─────────────────────────────────────────
  // Salary Records
  // ─────────────────────────────────────────

  Future<List<SalaryRecord>> getSalaryRecords({
    int? year,
    int? month,
    String? employeeId,
    String? status,
  }) async {
    var q = _db
        .from('finance_salary_records')
        .select('*, finance_employees(full_name)')
        .eq('seller_id', _sellerId);
    if (year != null) q = q.eq('period_year', year);
    if (month != null) q = q.eq('period_month', month);
    if (employeeId != null) q = q.eq('employee_id', employeeId);
    if (status != null) q = q.eq('status', status);
    final data = await q
        .order('period_year', ascending: false)
        .order('period_month', ascending: false);
    return (data as List)
        .map((e) => SalaryRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SalaryRecord> createSalaryRecord(SalaryRecord r) async {
    final row = await _db
        .from('finance_salary_records')
        .insert(r.toInsertJson(_sellerId))
        .select('*, finance_employees(full_name)')
        .single();
    return SalaryRecord.fromJson(row);
  }

  Future<void> updateSalaryRecord(
    String id,
    Map<String, dynamic> fields,
  ) async {
    await _db
        .from('finance_salary_records')
        .update(fields)
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  // ─────────────────────────────────────────
  // Salary Payments
  // ─────────────────────────────────────────

  Future<List<SalaryPayment>> getSalaryPayments(String salaryRecordId) async {
    final data = await _db
        .from('finance_salary_payments')
        .select()
        .eq('salary_record_id', salaryRecordId)
        .eq('seller_id', _sellerId)
        .order('payment_date', ascending: false);
    return (data as List)
        .map((e) => SalaryPayment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SalaryPayment> createSalaryPayment(SalaryPayment p) async {
    final row = await _db
        .from('finance_salary_payments')
        .insert({
          'seller_id': _sellerId,
          'salary_record_id': p.salaryRecordId,
          'amount': p.amount,
          'payment_date': p.paymentDate.toIso8601String().substring(0, 10),
          if (p.accountId != null) 'account_id': p.accountId,
          if (p.description != null) 'description': p.description,
        })
        .select()
        .single();
    return SalaryPayment.fromJson(row);
  }

  Future<void> transferBetweenAccounts({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    String? description,
    DateTime? movementDate,
  }) async {
    final effectiveDate = movementDate ?? DateTime.now();
    try {
      await _db.rpc(
        'finance_transfer_cash',
        params: {
          'p_seller_id': _sellerId,
          'p_from_account_id': fromAccountId,
          'p_to_account_id': toAccountId,
          'p_amount': amount,
          'p_description': description,
          'p_movement_date': effectiveDate.toIso8601String().substring(0, 10),
        },
      );
      return;
    } catch (error) {
      if (!_shouldUseFlowFallback(error, 'finance_transfer_cash')) rethrow;
    }

    final refId = DateTime.now().microsecondsSinceEpoch.toString();
    await createCashMovement(
      CashMovement(
        id: '',
        sellerId: _sellerId,
        accountId: fromAccountId,
        movementType: CashMovementType.transfer,
        amount: amount,
        direction: 'out',
        referenceId: refId,
        referenceType: 'account_transfer',
        description: description,
        movementDate: effectiveDate,
        createdAt: effectiveDate,
      ),
    );
    await createCashMovement(
      CashMovement(
        id: '',
        sellerId: _sellerId,
        accountId: toAccountId,
        movementType: CashMovementType.transfer,
        amount: amount,
        direction: 'in',
        referenceId: refId,
        referenceType: 'account_transfer',
        description: description,
        movementDate: effectiveDate,
        createdAt: effectiveDate,
      ),
    );
  }

  // ─────────────────────────────────────────
  // Reconciliation Notes
  // ─────────────────────────────────────────

  Future<List<ReconciliationNote>> getReconciliationNotes({
    String? status,
  }) async {
    var q = _db
        .from('finance_reconciliation_notes')
        .select()
        .eq('seller_id', _sellerId);
    if (status != null) q = q.eq('status', status);
    final data = await q.order('created_at', ascending: false);
    return (data as List)
        .map((e) => ReconciliationNote.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ReconciliationNote> createReconciliationNote(
    ReconciliationNote n,
  ) async {
    final row = await _db
        .from('finance_reconciliation_notes')
        .insert(n.toInsertJson(_sellerId))
        .select()
        .single();
    return ReconciliationNote.fromJson(row);
  }

  Future<void> updateReconciliationNote(
    String id,
    Map<String, dynamic> fields,
  ) async {
    await _db
        .from('finance_reconciliation_notes')
        .update(fields)
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  Future<void> deleteReconciliationNote(String id) async {
    await _db
        .from('finance_reconciliation_notes')
        .delete()
        .eq('id', id)
        .eq('seller_id', _sellerId);
  }

  // ─────────────────────────────────────────
  // Company Settings
  // ─────────────────────────────────────────

  Future<CompanySettings?> getCompanySettings() async {
    final data = await _db
        .from('finance_company_settings')
        .select()
        .eq('seller_id', _sellerId)
        .maybeSingle();
    if (data == null) return null;
    return CompanySettings.fromJson(data);
  }

  Future<void> upsertCompanySettings(CompanySettings s) async {
    await _db
        .from('finance_company_settings')
        .upsert(s.toUpsertJson(_sellerId), onConflict: 'seller_id');
  }

  // ─────────────────────────────────────────
  // Report helpers
  // ─────────────────────────────────────────

  /// Belirli bir ay için tüm kategorilerin gider toplamı
  Future<Map<String, double>> getExpenseSummaryByCategory({
    required int year,
    required int month,
  }) async {
    final from = DateTime(year, month, 1).toIso8601String().substring(0, 10);
    final to = DateTime(year, month + 1, 0).toIso8601String().substring(0, 10);
    final data = await _db
        .from('finance_expenses')
        .select('category, amount')
        .eq('seller_id', _sellerId)
        .gte('expense_date', from)
        .lte('expense_date', to)
        .eq('is_paid', true);

    final map = <String, double>{};
    for (final row in (data as List)) {
      final cat = row['category'] as String? ?? 'other';
      final amt = double.tryParse(row['amount'].toString()) ?? 0.0;
      map[cat] = (map[cat] ?? 0) + amt;
    }
    return map;
  }

  /// Yaklaşan / gecikmiş ödemeler (expenses + debts)
  Future<List<Map<String, dynamic>>> getPaymentScheduleItems({
    DateTime? from,
    DateTime? to,
  }) async {
    final now = DateTime.now();
    final startDate = (from ?? now.subtract(const Duration(days: 30)))
        .toIso8601String()
        .substring(0, 10);
    final endDate = (to ?? now.add(const Duration(days: 30)))
        .toIso8601String()
        .substring(0, 10);

    final expenses = await _db
        .from('finance_expenses')
        .select('id, description, amount, due_date, is_paid, category')
        .eq('seller_id', _sellerId)
        .eq('is_paid', false)
        .gte('due_date', startDate)
        .lte('due_date', endDate)
        .order('due_date');

    final debts = await _db
        .from('finance_debts')
        .select(
          'id, creditor_name, original_amount, paid_amount, due_date, status, debt_type',
        )
        .eq('seller_id', _sellerId)
        .not('status', 'in', '("paid","cancelled")')
        .not('due_date', 'is', null)
        .gte('due_date', startDate)
        .lte('due_date', endDate)
        .order('due_date');

    final items = <Map<String, dynamic>>[];

    for (final e in (expenses as List)) {
      final due = e['due_date'] as String?;
      if (due == null) continue;
      final dueDate = DateTime.parse(due);
      items.add({
        'id': e['id'],
        'type': 'expense',
        'title': ExpenseCategory.fromValue(
          e['category'] as String? ?? 'other',
        ).label,
        'description': e['description'] ?? '',
        'amount': double.tryParse(e['amount'].toString()) ?? 0,
        'due_date': dueDate,
        'is_overdue': dueDate.isBefore(now),
      });
    }

    for (final d in (debts as List)) {
      final due = d['due_date'] as String?;
      if (due == null) continue;
      final dueDate = DateTime.parse(due);
      final original = double.tryParse(d['original_amount'].toString()) ?? 0;
      final paid = double.tryParse(d['paid_amount'].toString()) ?? 0;
      items.add({
        'id': d['id'],
        'type': 'debt',
        'title': DebtType.fromValue(d['debt_type'] as String? ?? 'other').label,
        'description': d['creditor_name'] ?? '',
        'amount': original - paid,
        'due_date': dueDate,
        'is_overdue': dueDate.isBefore(now),
      });
    }

    items.sort(
      (a, b) =>
          (a['due_date'] as DateTime).compareTo(b['due_date'] as DateTime),
    );
    return items;
  }
}
