### 1) Optimization Summary

- Current optimization health: mixed. The codebase already has some good direction, including paged Supabase search in `SupabaseService.searchProductsPaged`, cache usage in `ReviewRepository`, and store-info caching in `StoreService`. The main problems are broader data-access patterns that still fetch partial catalogs and filter client-side, plus a few critical flows that remain very chatty.
- Top 3 highest-impact improvements:
  1. Remove `getAllProducts()`-driven client-side scans from UI flows that assume they have the full catalog, even though the helper is capped at 500 rows.
  2. Collapse checkout into a backend transaction/RPC instead of multiple sequential writes and per-seller reserve calls from the client.
  3. Rework map proximity matching so it does not fetch per-store product pages and scan favorites sequentially on movement.
- Biggest risk if no changes are made: catalog growth will silently break discovery correctness before it only hurts latency. Several screens treat `getAllProducts()` as authoritative, but [`ibul_app/lib/services/supabase_service.dart`](ibul_app/lib/services/supabase_service.dart) hard-caps it to 500 rows.

### 2) Findings (Prioritized)

- **[Reuse Opportunity] Hard-capped `getAllProducts()` drives client-side catalog scans across multiple screens**
- **Category** DB
- **Severity** Critical
- **Impact** Latency, memory, bandwidth, correctness, scalability
- **Evidence** `SupabaseService.getAllProducts()` returns `getProductsPage(limit: 500)` in `ibul_app/lib/services/supabase_service.dart:66-68`. That helper is used as a complete catalog source in `ibul_app/lib/services/database_helper.dart:35-36`, `ibul_app/lib/screens/categories_page.dart:84-88`, `ibul_app/lib/screens/market_list_page.dart:72-76`, `ibul_app/lib/widgets/search_overlay.dart:152-155`, `ibul_app/lib/widgets/product_detail/product_category_cards.dart:39-41`, `ibul_app/lib/viewmodels/product_detail_viewmodel.dart:316-357`, `ibul_app/lib/viewmodels/product_detail_viewmodel.dart:914-925`, and `ibul_app/lib/screens/followed_stores_page.dart:433-436`.
- **Why it’s inefficient** The UI repeatedly pulls the first 500 active products, then filters them in Dart for categories, store pages, suggestions, similar items, and followed-store previews. This wastes network and CPU, increases heap pressure, and makes results incomplete once the active catalog exceeds 500 rows.
- **Recommended fix** Deprecate `getAllProducts()` for runtime UI flows. Replace each caller with targeted APIs such as `getProductsBySellerIdPaged`, `getProductsByCategory`, `searchProductsPaged`, and a dedicated lightweight suggestions endpoint. Keep `getAllProducts()` only for explicitly bounded admin/export use cases. Add an assertion or rename it to `getFirstProductPageForLegacyUse()` so new code stops treating it as full-catalog access.
- **Tradeoffs / Risks** Some current screens depend on local client-side fuzzy filtering or mixed-source fallback behavior. Moving to narrower APIs may change ordering or matching until acceptance-tested.
- **Expected impact estimate** High. Request payload and client filtering cost should drop materially, and correctness improves once catalog size passes 500 rows.
- **Removal Safety** Needs Verification
- **Reuse Scope** service-wide

- **Checkout is still a multi-round-trip client saga instead of a single transactional backend operation**
- **Category** DB
- **Severity** High
- **Impact** Checkout latency, timeout risk, partial-failure risk, DB load
- **Evidence** `createOrderFromCheckout` in `ibul_app/lib/services/order_service.dart:17-390` already batches some metadata well, but the critical path still does: order insert, order-items insert, history insert, per-seller wallet reserve calls in a loop at `329-349`, follow-up order update at `351-358`, and rollback deletes at `379-387`.
- **Why it’s inefficient** The happy path performs several sequential network/database operations from the client on the most latency-sensitive flow in the app. Any transient failure after the first insert expands both latency and recovery complexity. The per-seller reserve loop scales linearly with seller count in the cart.
- **Recommended fix** Move checkout into a single RPC or Edge Function that validates cart state, inserts `orders` and `order_items`, creates status history, reserves wallet amounts in bulk, and returns one response. Keep the client-side metadata pre-resolution only if it is necessary for optimistic UI; otherwise let the backend own canonical resolution.
- **Tradeoffs / Risks** This centralizes more business logic on the backend and requires careful migration of current fallback behavior for legacy schemas.
- **Expected impact estimate** Medium to High. Fewer round trips on checkout and much lower risk of partial writes or user-visible failure after payment intent.
- **Removal Safety** Needs Verification
- **Reuse Scope** service-wide

- **Map proximity matching does per-store product fetches and sequential favorite scans on movement**
- **Category** Network
- **Severity** High
- **Impact** Battery, network load, notification latency, backend read load
- **Evidence** `MapPage` keeps a page-lifetime `_storeProductsCache` in `ibul_app/lib/screens/map_page.dart:72`. During proximity checks, `_checkAndSendProximityNotifications()` loops stores sequentially at `332-449`, calls `_findInterestMatchForStore()` at `272-315`, which loads store products through `_getStoreProducts()` at `1060-1068`. Web also polls location every 3 seconds in `889-913`.
- **Why it’s inefficient** On first proximity scans, each nearby store can trigger its own product-page request, then the code scans up to 25 favorites per store. This compounds quickly with dense store maps. The cache is also unbounded for the page lifetime, so longer sessions retain every store-product list touched.
- **Recommended fix** Push proximity matching server-side or at least precompute it client-side in bulk:
  - fetch only nearby seller IDs first
  - query matching products for the nearby seller set in one request
  - pre-normalize favorite/search terms once per session
  - cap `_storeProductsCache` with TTL/LRU
  - widen web polling if product requirements allow
- **Tradeoffs / Risks** Server-side matching needs clear product-interest semantics. More aggressive throttling can delay notifications slightly.
- **Expected impact estimate** Medium to High for users who keep the map open or move across dense store areas.
- **Removal Safety** Needs Verification
- **Reuse Scope** local file

- **[Over-Abstracted Code] `AppState` causes broad rebuild fan-out and persists whole review/question blobs**
- **Category** Frontend
- **Severity** Medium
- **Impact** Render cost, startup cost, local I/O, maintainability
- **Evidence** `AppState` has 42 `notifyListeners()` calls in `ibul_app/lib/core/app_state.dart` and there are 68 `AppState` consumers/watchers across screens/widgets. It also eagerly loads persisted review/question blobs in `ibul_app/lib/core/app_state.dart:21-23`, `352-405`, and `450-455`, then rewrites full JSON payloads after mutations in `1304`, `1336`, `1361`, and `1377`.
- **Why it’s inefficient** A monolithic `ChangeNotifier` means search history, cart, reviews, addresses, and followed stores can all fan out rebuilds through the same shared object. Persisting whole review/question arrays to `SharedPreferences` creates write amplification and higher local serialization cost than the UI actually needs.
- **Recommended fix** Split `AppState` into bounded providers/repositories by domain: auth/profile, cart, social/follows, review cache, and local question drafts. Keep reviews in `ReviewRepository` or another TTL cache instead of globally persisted JSON blobs. Use narrower selectors so simple state updates do not invalidate unrelated subtrees.
- **Tradeoffs / Risks** Refactoring provider boundaries will touch many widgets and requires discipline around dependency injection.
- **Expected impact estimate** Medium. The biggest gains are lower rebuild fan-out and less local storage churn rather than a single dramatic hotspot reduction.
- **Removal Safety** Needs Verification
- **Reuse Scope** service-wide

- **Widget-level `FutureBuilder` patterns create duplicate store/product lookups**
- **Category** Frontend
- **Severity** Medium
- **Impact** UI latency, redundant requests, repeated decode work
- **Evidence** `ProductStoreInfo` launches two separate logo lookups for the same `storeName` in `ibul_app/lib/widgets/product_detail/product_store_info.dart:92-103` and `292-303`. `FollowedStoresPage` creates a `FutureBuilder` per followed store at `ibul_app/lib/screens/followed_stores_page.dart:433-436`, but `DatabaseHelper.getProductsByStore()` at `ibul_app/lib/services/database_helper.dart:66-75` loads all products and filters client-side for each store card.
- **Why it’s inefficient** The product-detail widget repeats the same async logo request in two branches, and the followed-store screen turns each card into an N+1 catalog fetch/filter pass. This grows linearly with store count and causes avoidable spinner-heavy UI.
- **Recommended fix** Memoize store-summary futures by `sellerId/storeName` at a repository/provider layer and prefetch product thumbnails in the parent list. Replace `DatabaseHelper.getProductsByStore()` with a bounded seller/store query, then pass the resolved preview list into the card widget.
- **Tradeoffs / Risks** Parent-level prefetch means the list owns more loading/error state.
- **Expected impact estimate** Medium on followed-store screens; Low to Medium on product detail depending on rebuild frequency.
- **Removal Safety** Likely Safe
- **Reuse Scope** module

- **[Dead Code] Legacy Firestore data layer and unused bulk-review APIs add drift and maintenance overhead**
- **Category** Build
- **Severity** Low
- **Impact** Maintainability, bug surface, optimization velocity
- **Evidence** `FirestoreHelper` in `ibul_app/lib/services/firestore_helper.dart` has no call sites in `ibul_app/lib`. `ReviewService.getAllProductReviews()` and `getAllSellerReviews()` are defined in `ibul_app/lib/services/review_service.dart:10-37` but have no usages either. Comments in `DatabaseHelper` still describe client-side fallback behavior that newer Supabase code should not encourage.
- **Why it’s inefficient** Unused data paths make it harder to reason about the real runtime path, invite accidental regressions, and slow future optimization work because reviewers have to verify whether old abstractions still matter.
- **Recommended fix** Remove or quarantine unused Firestore-only code and dead bulk-review methods behind a `legacy/` folder or delete them after a quick grep-based verification. Tighten `DatabaseHelper` so its public surface matches supported runtime behavior only.
- **Tradeoffs / Risks** If any external branch or planned migration still depends on these files, deletion needs coordination.
- **Expected impact estimate** Low runtime impact, Medium maintainability gain.
- **Removal Safety** Likely Safe
- **Reuse Scope** module

- **[Reuse Opportunity] Product mapping and normalization logic is duplicated across screens and view models**
- **Category** Algorithm
- **Severity** Low
- **Impact** Maintainability, consistency, minor CPU waste
- **Evidence** Repeated `DBProduct -> Product` conversion with repeated JSON decode appears in `ibul_app/lib/screens/business_detail_page.dart:74-124`, `ibul_app/lib/screens/categories_page.dart:95-120`, `ibul_app/lib/screens/market_list_page.dart:83-120`, `ibul_app/lib/screens/home_screen.dart:3062+`, and `ibul_app/lib/viewmodels/product_detail_viewmodel.dart:932-974`. Turkish text normalization is also duplicated in multiple UI files, while a shared `TextNormalizer` already exists.
- **Why it’s inefficient** Duplication makes performance fixes harder to roll out and keeps repeated image/tag decode logic in hot UI code paths instead of one shared mapper.
- **Recommended fix** Centralize product mapping on a shared adapter and expose pre-normalized model fields where needed. That reduces code drift and makes future caching or lazy decode strategies much easier.
- **Tradeoffs / Risks** Small behavior differences may surface if current call sites rely on slightly different fallback rules.
- **Expected impact estimate** Low direct runtime gain, Medium long-term optimization gain.
- **Removal Safety** Safe
- **Reuse Scope** service-wide

### 3) Quick Wins (Do First)

- Replace all runtime UI uses of `getAllProducts()` with targeted paged queries, starting with `CategoriesPage`, `MarketListPage`, `SearchOverlay`, `ProductCategoryCards`, `ProductDetailViewModel`, and `FollowedStoresPage`.
- Replace `DatabaseHelper.getProductsByStore()` with a real seller/store query instead of `getAllProducts().where(...)`.
- Memoize store logo/public-info futures so `ProductStoreInfo` and similar widgets do not recreate identical lookups on rebuild.
- Bound `_storeProductsCache` in `MapPage` and stop fetching store products sequentially for every nearby store.
- Move checkout writes behind one backend RPC before adding more client-side checkout features.

### 4) Deeper Optimizations (Do Next)

- Introduce a dedicated product-discovery/query layer that exposes category, store, similar-product, and suggestion endpoints without relying on broad catalog fetches.
- Push proximity interest matching into Supabase RPC/Edge Functions so the server evaluates nearby sellers against normalized user interests in one call.
- Split `AppState` into narrower providers and move review/question persistence into dedicated repositories with bounded caches.
- Retire legacy Firestore abstractions and shrink the data layer to one supported backend path.

### 5) Validation Plan

- Benchmarks:
  - Measure `CategoriesPage`, `MarketListPage`, and `SearchOverlay` cold-load time before/after removing `getAllProducts()` paths.
  - Measure checkout tap-to-success latency for 1-seller and 3-seller carts before/after backend transaction work.
  - Measure map proximity scan time with 10, 50, and 200 stores in range.
- Profiling strategy:
  - Use Flutter DevTools CPU/memory on `MapPage`, `FollowedStoresPage`, and product-detail flows.
  - Log Supabase request count and payload size per screen open.
  - Record rebuild counts for widgets watching `AppState`.
- Metrics to compare before/after:
  - Supabase requests per screen open
  - total bytes transferred per categories/search/followed-stores load
  - time-to-first-render and worst-frame time
  - retained heap after opening map and product detail repeatedly
  - checkout round-trip count and failure rate
- Test cases to ensure correctness is preserved:
  - catalog result correctness with more than 500 active products
  - followed-store preview correctness for stores with 0, 1, and 100+ products
  - map notifications still fire once per intended threshold after batching/throttling
  - mixed-seller checkout still reserves correct wallet amounts and rolls back safely on failure

### 6) Optimized Code / Patch (when possible)

No application source files were changed. These are targeted pseudo-patches for the highest-ROI changes.

```dart
// 1. Replace legacy full-catalog store lookup.
Future<List<DBProduct>> getProductsByStorePreview(
  String storeName, {
  int limit = 5,
}) async {
  final page = await SupabaseService.instance.getProductsByStoreNamePaged(
    storeName: storeName,
    limit: limit,
  );
  return page.items;
}
```

Changed: removes `getAllProducts()` + client-side `where(...)` from store previews and keeps the query bounded by `limit`.

```dart
// 2. Parent-owned memoization for store logos / previews.
final Map<String, Future<String?>> _logoFutureByStore = {};

Future<String?> _logoFor(String storeName) {
  final key = TextNormalizer.normalize(storeName);
  return _logoFutureByStore.putIfAbsent(
    key,
    () => StoreService().getStoreLogoUrlByBusinessName(storeName),
  );
}
```

Changed: avoids recreating identical futures from multiple `FutureBuilder`s during rebuilds.

```dart
// 3. Checkout RPC shape instead of client-side saga.
final response = await _supabase.rpc('checkout_create_order', params: {
  'p_user_id': userId,
  'p_delivery_address': deliveryAddress,
  'p_payment_card': paymentCard,
  'p_delivery_type': deliveryType,
  'p_delivery_slot': deliverySlot,
  'p_items': selectedProducts,
});
```

Changed: pushes order creation, item insert, status-history insert, wallet reserve, and rollback into one backend transaction boundary.

### 7) 2026-03-10 Uygulanan Optimizasyonlar (Canli Takip)

Bu bolum, bu oturumda gercekten uygulanmis ve dogrulanmis degisiklikleri kaydeder.

#### 7.1 Ana sayfa ilk acilis loading/empty-state duzeltmesi

- Amaç: Ilk acilista empty-state metinlerinin erken gorunmesini engellemek.
- Uygulama:
  - `home_screen.dart` icine `_isLoadingHomeSections` eklendi.
  - Banner, kupon, populer/hizli/firsat urun bloklarinda kosul sirasi `loading -> empty -> content` olacak sekilde duzenlendi.
  - Ilk acilista skeleton/placeholder gosterimi eklendi.
- Dosya:
  - `/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app/lib/screens/home_screen.dart`
- Dogrulama:
  - `dart analyze lib/screens/home_screen.dart` calistirildi.
  - Yeni error yok; dosyada var olan eski warning/info girdileri devam ediyor.

#### 7.2 Urun karti gorsel decode/render optimizasyonu

- Amaç: Liste kartlarinda gereksiz buyuk decode maliyetini azaltmak.
- Uygulama:
  - `ProductCard` icinde sabit `cacheWidth/cacheHeight` (400/200) kaldirildi.
  - `LayoutBuilder + devicePixelRatio` ile kartin gercek render olcusune gore dinamik decode boyutu hesaplandi.
  - Mevcut davranis (UI/hero/fit) korunarak sadece decode hedefi optimize edildi.
- Dosya:
  - `/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app/lib/widgets/product_card.dart`
- Dogrulama:
  - `dart analyze lib/widgets/product_card.dart lib/screens/home_screen.dart` calistirildi.
  - Yeni error yok; `home_screen.dart` icindeki onceki warning/info girdileri ayni.

#### 7.3 Web asset yukunde tek yuksek etkili/low-risk temizlik

- Amaç: Baslangic web asset paketini davranis bozmadan kucultmek.
- Uygulama:
  - `pubspec.yaml` icinden `assets/haircare/` cikartildi.
  - Kod taramasinda bu klasorun aktif runtime akista zorunlu olmadigi, referanslarin kullanilmayan demo alanda kaldigi dogrulandi.
- Dosya:
  - `/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app/pubspec.yaml`
- Etki:
  - `assets/haircare` kaynak boyutu: yaklasik `5.43 MB`.
  - Build dagiliminda `haircare` dosyalari artik paket dagilim listesinde yok.
- Dogrulama:
  - `flutter build web --release` basarili.

#### 7.4 main.dart.js eager import yukunu azaltma (deferred loading)

- Amaç: Nadir kullanilan panel ekranlarini ilk bundle disina almak.
- Uygulama:
  - Su importlar deferred yapildi:
    - `screens/seller/admin_panel_page.dart`
    - `screens/seller_panel_page.dart`
    - `screens/become_seller_page.dart`
  - `/admin`, `/seller`, `/become-seller` route'lari `DeferredScreen` ile lazy yuklenecek hale getirildi.
  - Route adlari ve fonksiyonel akis korunarak sadece yukleme zamani degistirildi.
- Dosya:
  - `/Users/barankananogullari/Desktop/ibul2026 kopyası 9/ibul_app/lib/main.dart`
- Olcum:
  - `main.dart.js`: `7,570,917` bayt -> `6,849,418` bayt
  - Azalma: `721,499` bayt (yaklasik `%9.5`)
  - Yeni split parcasi: `main.dart.js_2.part.js` ~ `734,586` bayt
- Dogrulama:
  - `dart analyze lib/main.dart` -> `No issues found!`
  - `flutter build web --release` basarili.
  - Build cikisinda `deferredLibraryParts:{admin_panel:[0],seller_panel:[1],become_seller:[2]}` teyit edildi.

#### 7.5 Sonraki odak (kisa not)

- Ayni yaklasimla, giriste nadir kullanilan diger ekranlar icin ek deferred import adimlari planlanabilir.
- Ancak her adim tek tek olculup uygulanmali (low-risk strategy korunmali).
