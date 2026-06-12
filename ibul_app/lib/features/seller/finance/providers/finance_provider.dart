import 'package:flutter/foundation.dart';
import '../finance_quick_actions.dart';
import '../models/finance_models.dart';
import '../repositories/finance_repository.dart';

/// Finans modülünün merkezi state yöneticisi.
/// Sadece Overview (genel bakış) ve ortak kaynak listelerini tutar.
/// Her sekme kendi lokal state'ini yönetir.
class FinanceProvider extends ChangeNotifier {
  FinanceProvider({
    required this.sellerId,
    this.optimisticClosedHistory = const <Map<String, dynamic>>[],
  }) : repo = FinanceRepository(
         sellerId,
         optimisticHistoryRows: optimisticClosedHistory,
       );

  final String sellerId;
  final List<Map<String, dynamic>> optimisticClosedHistory;
  final FinanceRepository repo;

  // ─── Overview ───
  FinanceOverview _overview = FinanceOverview.empty;
  FinanceOverview get overview => _overview;

  List<MonthlyTrendPoint> _trend = [];
  List<MonthlyTrendPoint> get trend => _trend;

  List<DailySalesPoint> _salesSeries = const [];
  List<DailySalesPoint> get salesSeries => _salesSeries;

  bool _loadingOverview = false;
  bool get loadingOverview => _loadingOverview;

  String? _overviewError;
  String? get overviewError => _overviewError;

  // ─── Gerçek satış cirosu (order_items) ───
  double _todaySalesRevenue = 0;
  double get todaySalesRevenue => _todaySalesRevenue;

  double _monthSalesRevenue = 0;
  double get monthSalesRevenue => _monthSalesRevenue;

  // ─── Paylaşılan kaynaklar ───
  List<CashAccount> _cashAccounts = [];
  List<CashAccount> get cashAccounts => _cashAccounts;

  List<FinanceSupplier> _suppliers = [];
  List<FinanceSupplier> get suppliers => _suppliers;

  bool _resourcesLoaded = false;

  FinanceQuickActionEvent? _quickAction;
  FinanceQuickActionEvent? get quickAction => _quickAction;

  int _quickActionSequence = 0;

  // ─────────────────────────────────────────
  // Init
  // ─────────────────────────────────────────

  Future<void> init() async {
    if (_resourcesLoaded) return;
    await Future.wait([loadOverview(), loadSharedResources()]);
    _resourcesLoaded = true;
  }

  // ─────────────────────────────────────────
  // Overview
  // ─────────────────────────────────────────

  Future<void> loadOverview() async {
    _loadingOverview = true;
    _overviewError = null;
    notifyListeners();
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final todayStart = DateTime(now.year, now.month, now.day);
      final chartStart = todayStart.subtract(const Duration(days: 29));

      final results = await Future.wait([
        repo.getOverview(),
        repo.getMonthlyTrend(months: 6),
        repo.getSalesRevenue(from: todayStart, to: now),
        repo.getSalesRevenue(from: monthStart, to: now),
        repo.getMonthlySalesRevenue(months: 6),
        repo.getDailySalesSeries(from: chartStart, to: todayStart),
      ]);

      final baseOverview = results[0] as FinanceOverview;
      final baseTrend = results[1] as List<MonthlyTrendPoint>;
      _todaySalesRevenue = results[2] as double;
      _monthSalesRevenue = results[3] as double;
      final monthlySales = results[4] as Map<String, double>;
      _salesSeries = results[5] as List<DailySalesPoint>;

      // Gerçek satış cirosunu finans gelirine ekle → "Genel Bakış"taki ciro ile
      // finanstaki gelir artık tutarlı. Manuel gelir kayıtları + satış cirosu.
      _overview = baseOverview.copyWith(
        monthIncome: baseOverview.monthIncome + _monthSalesRevenue,
      );

      // Finansal Performans grafiği her zaman son 6 ayı göstermeli. Manuel gelir
      // kaydı yoksa baseTrend boş gelebiliyordu; bu yüzden 6 aylık iskeleti
      // burada üretip baseTrend (manuel gelir/gider) ve satış cirosunu üzerine
      // bindiriyoruz. Böylece satış varsa grafik mutlaka dolar.
      const labels = [
        'Oca',
        'Şub',
        'Mar',
        'Nis',
        'May',
        'Haz',
        'Tem',
        'Ağu',
        'Eyl',
        'Eki',
        'Kas',
        'Ara',
      ];
      final baseByKey = {
        for (final p in baseTrend)
          '${p.year}-${p.month.toString().padLeft(2, '0')}': p,
      };
      _trend = List.generate(6, (i) {
        final slot = DateTime(now.year, now.month - 5 + i, 1);
        final key = '${slot.year}-${slot.month.toString().padLeft(2, '0')}';
        final base = baseByKey[key];
        final sales = monthlySales[key] ?? 0;
        final income = (base?.income ?? 0) + sales;
        final expense = base?.expense ?? 0;
        return MonthlyTrendPoint(
          label: base?.label ?? labels[slot.month - 1],
          year: slot.year,
          month: slot.month,
          income: income,
          expense: expense,
          net: income - expense,
        );
      }, growable: false);
    } catch (e) {
      _overviewError = e.toString();
    } finally {
      _loadingOverview = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────
  // Shared Resources
  // ─────────────────────────────────────────

  Future<void> loadSharedResources() async {
    try {
      final results = await Future.wait([
        repo.getCashAccounts(),
        repo.getSuppliers(),
      ]);
      _cashAccounts = results[0] as List<CashAccount>;
      _suppliers = results[1] as List<FinanceSupplier>;
      notifyListeners();
    } catch (_) {
      // fail silently; each tab can retry
    }
  }

  Future<void> reloadCashAccounts() async {
    _cashAccounts = await repo.getCashAccounts();
    notifyListeners();
  }

  Future<void> reloadSuppliers() async {
    _suppliers = await repo.getSuppliers();
    notifyListeners();
  }

  void triggerQuickAction(
    String action, {
    Map<String, dynamic> payload = const {},
  }) {
    _quickAction = FinanceQuickActionEvent(
      id: ++_quickActionSequence,
      action: action,
      payload: payload,
    );
    notifyListeners();
  }

  bool consumeQuickAction(int eventId) {
    if (_quickAction == null || _quickAction!.id != eventId) return false;
    _quickAction = null;
    notifyListeners();
    return true;
  }

  void clearQuickAction() {
    if (_quickAction == null) return;
    _quickAction = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _quickAction = null;
    super.dispose();
  }

  // ─────────────────────────────────────────
  // Refresh all
  // ─────────────────────────────────────────

  Future<void> refresh() async {
    await Future.wait([loadOverview(), loadSharedResources()]);
  }
}
