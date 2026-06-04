import 'package:flutter/material.dart';

import '../../../../models/seller_product.dart';
import '../models/seller_panel_types.dart';

enum SellerPanelNavigationSource {
  userTap,
  routeParentRestore,
  init,
  asyncBlocked,
}

class SellerPanelNavigationController extends ChangeNotifier {
  SellerPanelNavigationController._({
    required this.ownerKey,
    SellerModule initialModule = SellerModule.dashboard,
  }) : _activeModule = initialModule;

  static final Map<String, SellerPanelNavigationController>
  _sellerPanelNavControllersBySellerId =
      <String, SellerPanelNavigationController>{};

  static SellerPanelNavigationController forSeller(
    String sellerId, {
    SellerModule initialModule = SellerModule.dashboard,
  }) {
    final ownerKey = _normalizeOwnerKey(sellerId);
    return _sellerPanelNavControllersBySellerId.putIfAbsent(
      ownerKey,
      () => SellerPanelNavigationController._(
        ownerKey: ownerKey,
        initialModule: initialModule,
      ),
    );
  }

  static void clearCachedControllersForTests() {
    _sellerPanelNavControllersBySellerId.clear();
  }

  static String _normalizeOwnerKey(String sellerId) {
    final normalized = sellerId.trim();
    if (normalized.isNotEmpty) return normalized;
    return '__seller_panel_unknown__';
  }

  final String ownerKey;

  SellerModule _activeModule;
  bool _hasUserSelected = false;

  SellerModule get activeModule => _activeModule;
  bool get hasUserSelected => _hasUserSelected;

  bool seedIfPristine(SellerModule module, {required String source}) {
    if (_hasUserSelected) {
      debugPrint(
        '[NAV_CONTROLLER_NOOP] '
        'owner=$ownerKey source=$source module=${_activeModule.name} '
        'reason=seed_ignored_user_selection_exists',
      );
      return false;
    }
    return _set(
      module,
      source: source,
      userInitiated: false,
      parentRestore: true,
    );
  }

  bool selectByUser(SellerModule module, {required String source}) {
    return _set(module, source: source, userInitiated: true);
  }

  bool restoreParent(SellerModule module, {required String source}) {
    return _set(
      module,
      source: source,
      userInitiated: false,
      parentRestore: true,
    );
  }

  bool tryAsyncSet(SellerModule module, {required String source}) {
    if (_hasUserSelected) {
      debugPrint(
        '[NAV_CONTROLLER_BLOCKED] '
        'owner=$ownerKey source=$source from=${_activeModule.name} '
        'to=${module.name} reason=user_selected_lock',
      );
      return false;
    }
    if (_activeModule == SellerModule.garson &&
        module == SellerModule.dashboard) {
      debugPrint(
        '[NAV_CONTROLLER_BLOCKED] '
        'owner=$ownerKey source=$source from=garson '
        'to=dashboard reason=garson_active',
      );
      return false;
    }
    return _set(module, source: source, userInitiated: false);
  }

  bool _set(
    SellerModule module, {
    required String source,
    required bool userInitiated,
    bool parentRestore = false,
  }) {
    final previous = _activeModule;
    final nextHasUserSelected = _hasUserSelected || userInitiated;
    final moduleChanged = previous != module;
    final lockChanged = nextHasUserSelected != _hasUserSelected;

    if (!moduleChanged && !lockChanged) {
      debugPrint(
        '[NAV_CONTROLLER_NOOP] '
        'owner=$ownerKey source=$source module=${module.name} '
        'userInitiated=$userInitiated parentRestore=$parentRestore',
      );
      return false;
    }

    _activeModule = module;
    _hasUserSelected = nextHasUserSelected;
    debugPrint(
      '[NAV_CONTROLLER_WRITE] '
      'owner=$ownerKey source=$source from=${previous.name} '
      'to=${module.name} userInitiated=$userInitiated '
      'parentRestore=$parentRestore hasUserSelected=$_hasUserSelected',
    );
    notifyListeners();
    return moduleChanged;
  }
}

String sellerPanelLifecycleRouteNameForLog(String? cachedRouteName) {
  final normalized = cachedRouteName?.trim() ?? '';
  if (normalized.isEmpty) return '-';
  return normalized;
}

String buildSellerPanelLifecycleLogLine({
  required String phase,
  required String instanceId,
  required String widgetKey,
  required String oldWidgetKey,
  required String newWidgetKey,
  required String initialModule,
  required String oldInitialModule,
  required String newInitialModule,
  required String selectedModule,
  required String controllerModule,
  required bool hasUserSelected,
  required String routeName,
  required String ownerKey,
}) {
  final buffer = StringBuffer()
    ..write('[SELLER_PANEL_LIFECYCLE][$phase] ')
    ..write('instance=$instanceId ')
    ..write('widgetKey=$widgetKey ')
    ..write('oldWidgetKey=$oldWidgetKey ')
    ..write('newWidgetKey=$newWidgetKey ')
    ..write('initialModule=$initialModule ')
    ..write('oldInitialModule=$oldInitialModule ')
    ..write('newInitialModule=$newInitialModule ')
    ..write('selectedModule=$selectedModule ')
    ..write('controllerModule=$controllerModule ')
    ..write('hasUserSelected=$hasUserSelected ')
    ..write('route=$routeName ')
    ..write('owner=$ownerKey');
  return buffer.toString();
}

/// Result of a centralised seller-panel navigation decision.
///
/// `apply`   → caller MUST call setState and update [SellerModule].
/// `blocked` → another (async/background) source tried to override a module
///             the user explicitly chose; the write was rejected.
/// `noop`    → the requested next module is the same as the current one.
enum SellerNavigationWriteAction { apply, blocked, noop }

/// Pure decision returned by [evaluateSellerNavigationWrite].
class SellerNavigationWriteDecision {
  const SellerNavigationWriteDecision({
    required this.action,
    required this.nextHasUserSelectedModule,
  });

  final SellerNavigationWriteAction action;

  /// New value the caller should assign to the "user-has-selected" lock flag.
  final bool nextHasUserSelectedModule;
}

/// Single source of truth for *whether* a [SellerModule] write should be
/// applied. All seller-panel navigation writes (sidebar tap, route pop,
/// async profile load, dashboard refresh, etc.) MUST funnel through a
/// helper that consults this function so navigation can never be
/// hijacked by background work.
///
/// Rules:
///  * Same module → [SellerNavigationWriteAction.noop].
///  * User tap   ([userInitiated] = true) → always [apply] and lock further
///    async overrides via [nextHasUserSelectedModule] = true.
///  * Parent route restore (e.g. closing a garson table flow) → [apply]
///    regardless of the lock; the user implicitly returned to the parent
///    module.
///  * Otherwise (async/background) → [apply] only when no explicit user
///    selection has happened yet, otherwise [blocked].
/// Pure version of the *garson hard-block* applied inside
/// `_setActiveSellerModule` (stage A). Returns `true` when an attempted
/// dashboard write MUST be rejected because the user is currently doing
/// waiter work — they're on garson, a garson table route is open, or they
/// have explicitly chosen a module.
///
/// `parentRestore` always allows the write so a child route popping back
/// can never strand the panel away from its parent module.
bool shouldHardBlockGarsonDashboardWrite({
  required SellerModule current,
  required SellerModule next,
  required bool hasUserSelectedModule,
  required bool isGarsonTableRouteOpen,
  required bool userInitiated,
  required bool parentRestore,
}) {
  if (next != SellerModule.dashboard) return false;
  if (userInitiated || parentRestore) return false;
  return current == SellerModule.garson ||
      isGarsonTableRouteOpen ||
      hasUserSelectedModule;
}

/// Decision strings emitted by [resolveSellerPanelRenderTarget] and matched
/// by the `[RENDER_DECISION]` log line. Kept as plain
/// strings (not an enum) so the call site can produce a single uniform
/// string for all modules.
class SellerPanelRenderTargets {
  const SellerPanelRenderTargets._();
  static const String dashboard = 'dashboard';
  static const String garson = 'garson';
  static const String garsonPlaceholder = 'garson_placeholder';
  static const String system = 'system';
  static const String systemPlaceholder = 'system_placeholder';
}

/// Pure helper that decides what the seller-panel content area should
/// render for a given `(selectedModule, storeCategory, isWaiterEntry)`
/// tuple. The widget's `_buildContent` uses a richer switch but the most
/// bug-prone branches (garson / system fallbacks) are extracted here so
/// the rule is testable: the dashboard widget MUST NEVER be substituted
/// when garson is selected.
String resolveSellerPanelRenderTarget({
  required SellerModule selectedModule,
  required String? storeCategory,
  required bool isWaiterEntry,
}) {
  switch (selectedModule) {
    case SellerModule.garson:
      if (isWaiterEntry || isSellerFoodStoreCategory(storeCategory)) {
        return SellerPanelRenderTargets.garson;
      }
      return SellerPanelRenderTargets.garsonPlaceholder;
    case SellerModule.system:
      if (isSellerFoodStoreCategory(storeCategory)) {
        return SellerPanelRenderTargets.system;
      }
      return SellerPanelRenderTargets.systemPlaceholder;
    case SellerModule.dashboard:
      return SellerPanelRenderTargets.dashboard;
    case SellerModule.products:
    case SellerModule.collections:
    case SellerModule.orders:
    case SellerModule.store:
    case SellerModule.team:
    case SellerModule.campaigns:
    case SellerModule.finance:
    case SellerModule.reviews:
    case SellerModule.support:
      return selectedModule.name;
  }
}

/// Builds a stable signature of the products list so [_applySellerProducts]
/// can drop redundant publishes. The realtime products stream can time out
/// every 9–10 s, triggering a fallback snapshot fetch followed by an
/// immediate re-subscribe (which then re-emits the same data). Without this
/// guard the resulting `setState` + `_productsVersion++` +
/// `_invalidateDashboardSnapshot()` chain re-runs on every retry tick —
/// even when zero products actually changed — which is one of the visible
/// causes of the "Genel Bakış sayıları sürekli gidip geliyor" symptom.
///
/// The signature only captures fields the dashboard summaries actually
/// branch on. Cosmetic edits to a product's description/image do NOT
/// invalidate the cache key.
String sellerProductsListSignature(List<SellerProduct> products) {
  if (products.isEmpty) return 'empty';
  final entries =
      products
          .map(
            (p) => [
              p.id,
              p.status,
              p.price.toStringAsFixed(4),
              p.stock,
              p.discountPrice?.toStringAsFixed(4) ?? '-',
            ].join('|'),
          )
          .toList()
        ..sort();
  return '${entries.length}#${entries.join(';')}';
}

/// Result of a [resolveTableOrdersStreamLifecycle] decision. Identifies
/// whether a build call should re-use the cached `table_orders` stream
/// (because the seller key has not changed) or kick off a fresh
/// subscription. The actual stream object lives on the widget state; this
/// helper only exposes the decision so it can be unit-tested without
/// mounting the panel.
enum TableOrdersStreamLifecycleAction { reuse, start }

class TableOrdersStreamLifecycleDecision {
  const TableOrdersStreamLifecycleDecision({
    required this.action,
    required this.nextSellerKey,
  });

  final TableOrdersStreamLifecycleAction action;

  /// The seller-id key the caller should remember for the cache. When the
  /// action is [TableOrdersStreamLifecycleAction.reuse] this is identical
  /// to the existing cached key; when it is
  /// [TableOrdersStreamLifecycleAction.start] this is the new key the
  /// caller should store next to the freshly-subscribed stream.
  final String nextSellerKey;
}

/// Decides whether a build-phase request for the garson
/// `table_orders` stream should re-use the previously cached subscription
/// or start a new one. The rule is simple but explicitly written down so
/// regressions show up as test failures rather than as "every rebuild
/// re-subscribes" runtime smells:
///
///  * If we have no cached key yet → start.
///  * If the requested seller key is empty → start (the empty key is
///    handled by the service-level guard which returns an empty stream
///    without subscribing).
///  * If the cached key matches the requested key → reuse.
///  * Otherwise (seller switched) → start, replacing the cache.
///
/// Build-phase callers MUST funnel through this decision; opening a new
/// realtime subscription from inside `build` is the bug class the user
/// reported as "screen_stream_request her build'de tekrar tekrar
/// basılıyor".
TableOrdersStreamLifecycleDecision resolveTableOrdersStreamLifecycle({
  required String requestedSellerId,
  required String? cachedSellerId,
}) {
  final normalized = requestedSellerId.trim();
  final cachedNormalized = cachedSellerId?.trim();
  if (cachedSellerId == null) {
    return TableOrdersStreamLifecycleDecision(
      action: TableOrdersStreamLifecycleAction.start,
      nextSellerKey: normalized,
    );
  }
  if (cachedNormalized == normalized) {
    return TableOrdersStreamLifecycleDecision(
      action: TableOrdersStreamLifecycleAction.reuse,
      nextSellerKey: cachedNormalized!,
    );
  }
  return TableOrdersStreamLifecycleDecision(
    action: TableOrdersStreamLifecycleAction.start,
    nextSellerKey: normalized,
  );
}

/// Pure decision used by the products realtime listener / snapshot
/// fallback to decide whether to publish a fresh products list. Returns
/// `true` only when the next signature differs from the previous one OR
/// the row count differs (covers add/remove cases the signature already
/// covers but kept as a defensive cross-check).
///
/// The reason this is its own helper: the actual `_applySellerProducts`
/// call needs to call `setState` on a real widget, which makes it hard to
/// unit-test. By extracting the decision, regressions in the loop_guard
/// are caught without mounting the panel.
bool shouldPublishProductsUpdate({
  required String? previousSignature,
  required int previousCount,
  required String nextSignature,
  required int nextCount,
}) {
  if (previousSignature == null) return true;
  if (previousSignature != nextSignature) return true;
  if (previousCount != nextCount) return true;
  return false;
}

/// Should an async/background dashboard refresh be allowed to run?
///
/// The rule is intentionally strict: the refresh only runs when the user
/// is actually viewing the dashboard module. Loading dashboard data while
/// the user is on garson is wasted work AND bumps version counters which
/// invalidate the dashboard snapshot cache — the visual cause of the
/// "Genel Bakış sayıları sürekli gidip geliyor" symptom.
///
/// `userInitiated` does NOT bypass this rule because every user-initiated
/// refresh fires from a widget that is itself only rendered on the
/// dashboard (pull-to-refresh, Yenile button). If someone wires up a
/// user-initiated refresh from another module, they should switch to the
/// dashboard first.
bool shouldRunDashboardRefresh({required SellerModule selectedModule}) =>
    selectedModule == SellerModule.dashboard;

/// Background Garson updates are allowed to change the visible UI only in
/// two cases:
///  * Garson is not currently visible.
///  * The visible refresh is an explicit manual refresh already in progress.
///
/// Otherwise we freeze the grid and surface only a lightweight
/// "pending changes" indicator so realtime/products fallback traffic cannot
/// make the waiter screen jump while the user is working.
bool shouldBlockGarsonBackgroundPublish({
  required SellerModule selectedModule,
  required bool manualRefreshInProgress,
  required bool hasPublishedData,
  required String source,
}) {
  if (selectedModule != SellerModule.garson) return false;
  if (manualRefreshInProgress) return false;
  if (!hasPublishedData) return false;
  if (source == 'garson_manual_refresh_button' ||
      source == 'garson_order_submit' ||
      source == 'garson_table_route_popped' ||
      source == 'garson_local_table_action') {
    return false;
  }
  return source != 'garson_manual_refresh_button';
}

bool shouldSkipManualGarsonRefresh({required bool refreshInProgress}) =>
    refreshInProgress;

bool shouldAllowGarsonManualRefresh({
  required String source,
  required bool allowInitialAutoSeed,
}) {
  if (source == 'garson_manual_refresh_button') return true;
  return allowInitialAutoSeed;
}

bool shouldRunGarsonInitialVisibleSeed({
  required bool isGarsonVisible,
  required bool initialVisibleSeedDone,
  required bool initialLoading,
}) {
  if (!isGarsonVisible) return false;
  if (initialVisibleSeedDone) return false;
  if (initialLoading) return false;
  return true;
}

bool shouldRunGarsonInitialBootstrapLoad({
  required bool hasStoreTables,
  required bool hasProducts,
  required bool hasPublishedOrders,
}) {
  return !hasStoreTables || !hasProducts || !hasPublishedOrders;
}

bool shouldShowGarsonInitialLoading({
  required bool initialLoading,
  required bool initialVisibleSeedDone,
  required int visibleOrderCount,
  required int storeTableCount,
}) {
  if (!initialLoading) return false;
  if (initialVisibleSeedDone) return false;
  return visibleOrderCount == 0 && storeTableCount == 0;
}

String tableOrdersListSignature(List<Map<String, dynamic>> orders) {
  if (orders.isEmpty) return 'empty';
  final entries = orders.map((order) {
    final id = (order['id'] ?? '').toString();
    final tableNo = (order['table_number'] ?? '').toString();
    final status = (order['status'] ?? '').toString();
    final updatedAt = (order['updated_at'] ?? order['created_at'] ?? '')
        .toString();
    final items = order['items'];
    final itemCount = items is List ? items.length : 0;
    return '$id|$tableNo|$status|$updatedAt|i$itemCount';
  }).toList()..sort();
  return '${entries.length}#${entries.join(';')}';
}

String garsonStoreTablesSignature(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return 'empty';
  final entries = rows.map((row) {
    final id = (row['id'] ?? '').toString();
    final tableNo = (row['table_number'] ?? '').toString();
    final areaId = (row['area_id'] ?? '').toString();
    final areaName = (row['area_name'] ?? '').toString();
    final updatedAt = (row['updated_at'] ?? row['created_at'] ?? '').toString();
    return '$id|$tableNo|$areaId|$areaName|$updatedAt';
  }).toList()..sort();
  return '${entries.length}#${entries.join(';')}';
}

SellerNavigationWriteDecision evaluateSellerNavigationWrite({
  required SellerModule current,
  required SellerModule next,
  required bool hasUserSelectedModule,
  required bool userInitiated,
  required bool parentRestore,
}) {
  // Any user tap is observable intent and promotes the lock even when the
  // module does not actually change. Otherwise an async write running just
  // after a same-module tap could still hijack navigation.
  final nextHasUserSelectedModule = hasUserSelectedModule || userInitiated;
  if (current == next) {
    return SellerNavigationWriteDecision(
      action: SellerNavigationWriteAction.noop,
      nextHasUserSelectedModule: nextHasUserSelectedModule,
    );
  }
  if (!userInitiated && !parentRestore && hasUserSelectedModule) {
    return SellerNavigationWriteDecision(
      action: SellerNavigationWriteAction.blocked,
      // Blocking must preserve the lock — the user already chose a module.
      nextHasUserSelectedModule: hasUserSelectedModule,
    );
  }
  return SellerNavigationWriteDecision(
    action: SellerNavigationWriteAction.apply,
    nextHasUserSelectedModule: nextHasUserSelectedModule,
  );
}

/// Builds a stable signature of the dashboard's table_orders snapshot so the
/// loader can compare two successive responses cheaply. When the signature
/// matches the previous one we skip [setState]/version-bump entirely, which
/// is the only way to avoid the "[DashboardRefresh] loop" the user reported
/// (numbers oscillating because the loader kept publishing a "new" list that
/// in fact contained the same data).
///
/// The signature includes every field the dashboard summarises:
///  * `id` / `table_id` / `table_name` — identity + grouping
///  * `status`                          — open/closed/cancelled drives metrics
///  * `total_price` / `total_amount`    — revenue counters
///  * `updated_at` / `created_at`       — recency
///  * item count                        — basket changes within an open order
///
/// Renaming a printer or updating a non-summary column does NOT invalidate
/// the dashboard view.
String tableOrdersDashboardSignature(List<Map<String, dynamic>> orders) {
  if (orders.isEmpty) return 'empty';
  final entries = orders.map((order) {
    final id = (order['id'] ?? '').toString();
    final tableId = (order['table_id'] ?? '').toString();
    final tableName = (order['table_name'] ?? '').toString();
    final status = (order['status'] ?? '').toString();
    final updatedAt = (order['updated_at'] ?? order['created_at'] ?? '')
        .toString();
    final total =
        (order['total_price'] ??
                order['total_amount'] ??
                order['amount'] ??
                order['total'] ??
                '')
            .toString();
    final items = order['items'];
    final itemCount = items is List ? items.length : 0;
    return '$id|$tableId|$tableName|$status|$updatedAt|$total|i$itemCount';
  }).toList()..sort();
  return '${entries.length}#${entries.join(';')}';
}

/// Returns true when the store category indicates a food/restaurant business.
/// This is the single source of truth for the food-business check.
/// Dashboard behaviour (metrics, cards, charts) branches on this flag.
bool isSellerFoodStoreCategory(String? category) {
  final normalized = (category ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return false;
  const keywords = <String>[
    'yemek',
    'restoran',
    'restaurant',
    'food',
    'kafe',
    'cafe',
    'kafeterya',
    'lokanta',
    'kebap',
    'kebab',
    'döner',
    'doner',
    'pide',
    'lahmacun',
    'pastane',
    'pastahane',
    'fast food',
    'fastfood',
    'yiyecek',
    'içecek',
    'mutfak',
    'büfe',
    'bufe',
    'pizza',
    'burger',
    'sushi',
    'steakhouse',
    'et lokantası',
    'balık',
    'balik',
    'tatlı',
    'tatli',
    'kahve',
    'coffee',
    'çay',
    'cay',
  ];
  return keywords.any((kw) => normalized.contains(kw));
}

List<SellerModule> visibleSellerModules(
  String? storeCategory, {
  bool garsonOnly = false,
}) {
  if (garsonOnly) {
    return <SellerModule>[SellerModule.garson];
  }
  return <SellerModule>[
    SellerModule.dashboard,
    SellerModule.products,
    SellerModule.collections,
    SellerModule.orders,
    if (isSellerFoodStoreCategory(storeCategory)) SellerModule.garson,
    if (isSellerFoodStoreCategory(storeCategory)) SellerModule.system,
    SellerModule.store,
    SellerModule.team,
    SellerModule.campaigns,
    SellerModule.finance,
    SellerModule.reviews,
    SellerModule.support,
  ];
}

String sellerModuleLabel(SellerModule module) {
  switch (module) {
    case SellerModule.dashboard:
      return 'Genel Bakış';
    case SellerModule.products:
      return 'Ürünlerim';
    case SellerModule.collections:
      return 'Listeler';
    case SellerModule.orders:
      return 'Siparişler';
    case SellerModule.garson:
      return 'Garson';
    case SellerModule.system:
      return 'Sistem';
    case SellerModule.store:
      return 'Mağaza Profili';
    case SellerModule.team:
      return 'Alt Yöneticiler';
    case SellerModule.campaigns:
      return 'Reklam';
    case SellerModule.finance:
      return 'Finans';
    case SellerModule.reviews:
      return 'Yorumlar, Değerlendirmeler, Şikayetler';
    case SellerModule.support:
      return 'Destek';
  }
}

/// Async profile reloads preserve the current module; only waiter entry
/// hard-pins the panel to garson.
SellerModule resolveSellerModuleAfterProfileReload({
  required SellerModule currentModule,
  required String? storeCategory,
  required bool garsonOnly,
}) {
  if (garsonOnly) return SellerModule.garson;
  return currentModule;
}

IconData sellerModuleIcon(SellerModule module) {
  switch (module) {
    case SellerModule.dashboard:
      return Icons.dashboard_outlined;
    case SellerModule.products:
      return Icons.inventory_2_outlined;
    case SellerModule.collections:
      return Icons.collections_bookmark_outlined;
    case SellerModule.orders:
      return Icons.shopping_bag_outlined;
    case SellerModule.garson:
      return Icons.table_restaurant_outlined;
    case SellerModule.system:
      return Icons.settings_suggest_outlined;
    case SellerModule.store:
      return Icons.store_outlined;
    case SellerModule.team:
      return Icons.people_outline;
    case SellerModule.campaigns:
      return Icons.ads_click_outlined;
    case SellerModule.finance:
      return Icons.account_balance_wallet_outlined;
    case SellerModule.reviews:
      return Icons.rate_review_outlined;
    case SellerModule.support:
      return Icons.support_agent_outlined;
  }
}
