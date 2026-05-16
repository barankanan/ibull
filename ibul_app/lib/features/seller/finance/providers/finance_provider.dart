import 'package:flutter/foundation.dart';
import '../finance_quick_actions.dart';
import '../models/finance_models.dart';
import '../repositories/finance_repository.dart';

/// Finans modülünün merkezi state yöneticisi.
/// Sadece Overview (genel bakış) ve ortak kaynak listelerini tutar.
/// Her sekme kendi lokal state'ini yönetir.
class FinanceProvider extends ChangeNotifier {
  FinanceProvider({required this.sellerId})
      : repo = FinanceRepository(sellerId);

  final String sellerId;
  final FinanceRepository repo;

  // ─── Overview ───
  FinanceOverview _overview = FinanceOverview.empty;
  FinanceOverview get overview => _overview;

  List<MonthlyTrendPoint> _trend = [];
  List<MonthlyTrendPoint> get trend => _trend;

  bool _loadingOverview = false;
  bool get loadingOverview => _loadingOverview;

  String? _overviewError;
  String? get overviewError => _overviewError;

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
    await Future.wait([
      loadOverview(),
      loadSharedResources(),
    ]);
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
      final results = await Future.wait([
        repo.getOverview(),
        repo.getMonthlyTrend(months: 6),
      ]);
      _overview = results[0] as FinanceOverview;
      _trend = results[1] as List<MonthlyTrendPoint>;
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

  void triggerQuickAction(String action, {Map<String, dynamic> payload = const {}}) {
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
    await Future.wait([
      loadOverview(),
      loadSharedResources(),
    ]);
  }
}
