# OPTIMIZATIONS.md
> Proje: ibul2026 — Flutter + Supabase + Local Print Bridge  
> Tarih: 2026-05-25  
> Durum: **Sadece analiz — hiçbir kod değiştirilmedi.**

---

# 1) Optimization Summary

## Genel Sağlık Durumu

Proje mimarisi temiz ve katmanlı; print-bridge zinciri, garson sipariş akışı ve Supabase katmanı birbirinden ayrılmış durumda. Garson sipariş state'i (`GarsonProductSelection`, `GarsonUnitSelection`, `GarsonProductModalState`) iyi modellendi. Ancak:

- `seller_panel_page.dart` 36 000+ satır tek dosya (beş `part` ile bölünmüş olsa da tek `State` sınıfı); rebuild yüzeyi devasa.
- Her `SellerProduct` getter zinciri `normalizeSizeOptions` + `resolveWeightGramSettings` gibi pahalı hesapları tekrar tekrar çalıştırıyor.
- Her sipariş satırı `Map<String,dynamic>` içinde aynı değeri snake_case + camelCase olarak çift tutuyor (~10–15 gereksiz alan).
- Supabase'de N+1 sorgusu ve eksik kolon seçimi bulguları mevcut.

## En Yüksek Etkili 3 İyileştirme

1. **`SellerProduct` computed getter'larını memoize et** — `normalizeSizeOptions`, `resolveWeightGramSettings`, `resolvedPricingMode` gibi getterlar modalın her build'inde ve her item map oluşturulurken tekrar çalışıyor. `late final` veya constructor parametresiyle pre-compute edilmesi tüm garson akışını hızlandırır.

2. **`buildOrderItem` Map boyutunu yarıya indir** — Her sipariş satırı 30+ alan içeriyor; ~12 tanesi birebir aynı değerin farklı key versiyonu (snake + camelCase). Print/Supabase katmanlarında birini tercih edip diğerini kaldırmak serialize/deserialize maliyetini düşürür.

3. **`getCategoriesWithSubs` N+1 sorgusunu join sorgusuna çevir** — Her ana kategori için ayrı bir `getSubCategories` DB çağrısı yapılıyor. Tek bir sorguya indirilmesi ağ round-trip sayısını N→1'e düşürür.

## Değişiklik Yapılmazsa En Büyük Riskler

- `seller_panel_page.dart` State sınıfı büyümeye devam ederse Flutter'ın `setState` propagasyonu daha geniş widget ağacını yeniden oluşturur; özellikle garson masa grid'i düşük RAM cihazlarda yavaşlar.
- `SellerProduct.fromMap` içindeki koşulsuz `debugPrint` production build'lerde bile çalışıyor; ürün listesi yüklendikçe log flood oluşur.
- `store_service_mappers.dart::productToSnakeCase` her çağrıda `created_at = DateTime.now()` yazıyor; UPDATE operasyonlarında `created_at` sütunu bozulabilir.

---

# 2) Findings Prioritized

---

## F-01 · `SellerProduct` Computed Getter Zinciri — Tekrarlı Pahalı Hesaplama

- **Category:** Performance / CPU
- **Severity:** High
- **Impact:** Her `buildOrderItem`, her garson modal açılışı ve her product card render'ında tetiklenir.
- **Evidence:**
  - `seller_product.dart` satır 182–245: `hasSizeOptions`, `normalizedSizeOptions`, `defaultSizeOption`, `resolvedPricingMode`, `supportsGarsonWeightSelection`, `resolvedMinWeightGrams`, `resolvedWeightStepGrams`, `resolvedDefaultWeightGrams`, `resolvedMaxWeightGrams` — hepsi getter.
  - `normalizedSizeOptions` getter → `ProductPriceCalculator.normalizeSizeOptions()` → `_sanitizeSizeOptionList()` → liste iterate + sort. Her erişimde yeniden çalışır.
  - `resolvedWeightGramSettings` getter dört farklı getter tarafından bağımsız çağrılıyor (`resolvedMinWeightGrams`, `resolvedWeightStepGrams`, `resolvedDefaultWeightGrams`, `resolvedMaxWeightGrams`). Dördü art arda erişildiğinde aynı hesaplama 4 kez yapılır.
  - `supportsGarsonWeightSelection` → `resolvedPricingType` → `resolvedPricingMode` → `resolvePricingMode()` → `normalizeSizeOptions()`. Tek erişim 3 getter + 1 liste sort zinciri tetikler.
  - `product_pricing.dart` satır 527–532: `_sanitizeSizeOptionList` → `.map().where().toList()..sort()`.
- **Why Inefficient:** `SellerProduct` immutable bir model; constructor sonrası değerleri hiç değişmez. Getter'lar `late final` veya constructor pre-compute ile tek seferlik hesaplanabilir.
- **Recommended Fix:** `SellerProduct` constructor'ına `late final` memoized alanlar ekle:
  ```dart
  late final List<ProductSizeOption> normalizedSizeOptions = ProductPriceCalculator.normalizeSizeOptions(sizeOptions);
  late final ResolvedWeightGramSettings resolvedWeightGramSettings = ProductPriceCalculator.resolveWeightGramSettings(...);
  late final ProductPricingMode resolvedPricingMode = ProductPriceCalculator.resolvePricingMode(...);
  ```
- **Tradeoffs / Risks:** `late final` Dart'ta constructor body'den önce atanamazsa factory veya `_init()` pattern gerekir. `fromMap` factory'sini bozmamak için dikkatli olunmalı.
- **Expected Impact Estimate:** likely %20–40 garson modal açılış süresi azalması; ölçülmeden kesin değer verilemez.
- **Removal Safety:** Güvenli — hesaplama sonucu değişmez, sadece cache edilir.
- **Reuse Scope:** `seller_product.dart`, `garson_product_selection.dart`, `product_pricing.dart`

---

## F-02 · `SellerProduct.fromMap` Koşulsuz `debugPrint`

- **Category:** Performance / Logging
- **Severity:** High
- **Impact:** Her ürün yüklenişinde (garson menü, seller panel ürün listesi, admin paneli) log basıyor. 50 ürünlük bir liste 50 satır büyük Map dump üretiyor.
- **Evidence:**
  - `seller_product.dart` satır 327: `debugPrint('DB Verisi (SellerProduct): $map');`
  - `kDebugMode` guard yok. Release build'de de çalışır.
- **Why Inefficient:** `debugPrint` release modda devre dışı bırakılmaz; büyük Map'in string interpolasyonu heap alloc + string formatting maliyeti taşır.
- **Recommended Fix:** `if (kDebugMode) debugPrint(...)` ile sarın veya satırı kaldırın.
- **Tradeoffs / Risks:** Sıfır risk. Log güvenlik/üretim ortamında istenmeyen veri sızdırabilir.
- **Expected Impact Estimate:** Release build'de belirgin I/O & string alloc tasarrufu.
- **Removal Safety:** Güvenli.
- **Reuse Scope:** `seller_product.dart`

---

## F-03 · `buildOrderItem` Map Alanı Duplikasyonu — Her Sipariş Satırında ~12 Gereksiz Alan

- **Category:** Memory / Serialization
- **Severity:** Medium-High
- **Impact:** Her sipariş satırı Map'i ~30+ alan taşıyor; ~12 tanesi aynı değerin farklı key kopyaları. Supabase JSON payload ve print bridge HTTP body büyüyor.
- **Evidence:**
  - `garson_product_selection.dart` satır 1062–1098:
    - `'gramaj'`, `'amount_label'`, `'amountLabel'` — üçü aynı değer.
    - `'selected_grams'`, `'selectedGrams'`, `'selected_weight_grams'`, `'selectedWeightGrams'` — dördü aynı değer.
    - `'notes'`, `'note'` — ikisi aynı.
    - `'selected_size_name'`, `'selectedSizeName'` — ikisi aynı.
    - `'selected_size_price'`, `'selectedSizePrice'` — ikisi aynı.
    - `'unit_price_snapshot'`, `'unitPriceSnapshot'` — ikisi aynı.
    - `'station_name'`, `'kitchen_station_name'` — ikisi aynı değere yazılıyor (satır 1089–1092).
    - `'service_control_type'`, `'serviceControlType'` — ikisi aynı.
    - `'selected_service_amount'`, `'selectedServiceAmount'` — ikisi aynı.
  - Aynı duplikasyon `enrichOrderItem` (satır 1362–1393) ve `_syncGramFields` (satır 1395–1402) tarafından da güncelleniyor.
- **Why Inefficient:** Her siparişte gereksiz 100–200 byte ek Map boyutu; downstream consumer'lar bu alanların her ikisini de okumak zorunda değil — ya snake_case ya da camelCase standardize edilebilir.
- **Recommended Fix (likely):** Önce tüm consumer'ların hangi key versiyonunu okuduğunu belirle; uzun vadede tek bir key seti kullan, diğerini `enrichOrderItem`'da eklemekten kaç.
- **Tradeoffs / Risks:** Zincirdeki consumer'lar (Python bridge, kitchen.py, receipt.py, Supabase insert) hangi key'leri beklediğini doğrulamak gerekir. Bozma riski yüksek olduğundan kesin önce audit, sonra değişiklik.
- **Expected Impact Estimate:** likely %30–50 order item Map boyutu azalması; ağ payload küçülür.
- **Removal Safety:** Ayrıntılı consumer audit yapılmadan **DO NOT TOUCH** kapsamında tutun.
- **Reuse Scope:** `garson_product_selection.dart`, `kitchen_hub_payload_stamp.dart`, `order_print_job_service.dart`, Python bridge

---

## F-04 · `getCategoriesWithSubs` N+1 Sorgu

- **Category:** Database / Network
- **Severity:** High
- **Impact:** Ana kategori sayısı kadar ayrı Supabase HTTP çağrısı yapılıyor. Her çağrı ~50–150ms.
- **Evidence:**
  - `supabase_service.dart` satır 1197–1211:
    ```dart
    for (var mainCat in mainCategories) {
      if (mainCat.id != null) {
        final subs = await getSubCategories(mainCat.id!); // <-- N+1
        result.add(...);
      }
    }
    ```
  - `getSubCategories` her çağrıda ayrı `.from('categories').select().eq('parent_id', parentId)` sorgusu yapar.
- **Why Inefficient:** N main category → N+1 round-trip. Tek bir `select().not('parent_id', 'is', null)` ile tüm sub-categories tek sorguda çekilip client-side gruplandırılabilir.
- **Recommended Fix:**
  ```dart
  // Tek sorgu ile tüm sublar
  final allSubs = await _supabase.from('categories').select().not('parent_id', 'is', null).eq('is_active', true);
  // Client-side group by parent_id
  ```
- **Tradeoffs / Risks:** Kategori sayısı küçükse (< 50) mevcut yük göz ardı edilebilir. Büyüdükçe kritik hale gelir.
- **Expected Impact Estimate:** N HTTP round-trip → 1. ~(N-1) × 50–150ms kazanç.
- **Removal Safety:** Güvenli — davranış değişmez, sadece sorgu yapısı değişir.
- **Reuse Scope:** `supabase_service.dart`

---

## F-05 · `getStoreProfile` / `getSellerProducts` — SELECT * Kullanımı

- **Category:** Database / Network
- **Severity:** Medium
- **Impact:** Gereksiz sütunlar (video, thumbnail, gallery_images, banners vs.) her zaman çekilir; payload büyür.
- **Evidence:**
  - `store_service.dart` satır 296: `.select()` — explicit kolon yok, SELECT *.
  - Satır 1421–1429: `getSellerProductsSnapshot` → `.select()` — explicit kolon yok.
  - Satır 1122–1128: `getProducts()` stream → `.stream(primaryKey: ['id'])` + `.eq(...)` — `stream` zaten SELECT * yapar.
  - `getProductsWithVideos` satır 395–407: `.select()` — SELECT *.
- **Why Inefficient:** Supabase PostgREST büyük JSONB kolonlarını (specifications, gallery_images, banners, video_size_bytes) da döndürür. Özellikle `seller_panel_page.dart` garson menüsü zaten `getMenuProductsBySellerId` (explicit kolon listeli) kullanıyor ama seller ürün listesi kullanmıyor.
- **Recommended Fix:** `getStoreProfile` için `store_service_mappers.dart::storeToCamelCase` içindeki alan listesini baz alarak explicit select yaz.
- **Tradeoffs / Risks:** Yeni bir DB kolonu eklendiğinde explicit select güncellenmeli.
- **Expected Impact Estimate:** likely %20–40 ağ payload küçülmesi (video/thumbnail alanları büyük).
- **Removal Safety:** Güvenli ancak yeni alanlar eklendiğinde select güncelleme disiplini gerekir.
- **Reuse Scope:** `store_service.dart`

---

## F-06 · `store_service_mappers.dart::productToSnakeCase` — `created_at` Her Zaman Üzerine Yazıyor

- **Category:** Bug Risk / Data Integrity
- **Severity:** High (data integrity)
- **Impact:** `addProduct`, `updateProduct`, `saveProductDraft` hepsi `productToSnakeCase` çağırıyor. Bu fonksiyon her zaman `created_at = DateTime.now()` yazar — UPDATE'lerde orijinal oluşturma tarihi kaybolur.
- **Evidence:**
  - `store_service_mappers.dart` satır 130: `'created_at': DateTime.now().toIso8601String()`
  - `store_service.dart` satır 641: `updateProduct` → `StoreServiceMappers.productToSnakeCase(product.toMap())`.
- **Why Inefficient:** `created_at` immutable olmalı; güncelleme sırasında DB'deki değer geçerli kalmalı.
- **Recommended Fix:** `productToSnakeCase`'den `created_at` alanını kaldır veya `null` bırak (Supabase UPDATE'de null alan gönderilmez). `addProduct` akışında sadece ilk insert'e `created_at` ekle.
- **Tradeoffs / Risks:** Mevcut ürünlerde zaten bozulmuş `created_at` değerleri olabilir. Migration sonrası doğrulama gerekir.
- **Expected Impact Estimate:** Data integrity fix — ölçümle ilgisi yok.
- **Removal Safety:** `store_service.dart`'ta `updateProduct` kodunu da kontrol et; bazı yerlerde `updated_at` ayrıca ekleniyor (doğru), `created_at` kaldırıldığında conflict yok.
- **Reuse Scope:** `store_service_mappers.dart`, `store_service.dart`

---

## F-07 · `getMenuProductsBySellerId` — 5 Kademeli try/catch Fallback Ağacı

- **Category:** Maintainability / Code Complexity
- **Severity:** Medium
- **Impact:** Bakım maliyeti yüksek; yeni bir kolon eklendiğinde 5 farklı fallback bloğuna eklenmesi gerekir. Hata tespiti zorlaşır.
- **Evidence:**
  - `store_service.dart` satır 1645–1741: iç içe 5 kademeli try/catch bloğu; `richMenuSelect`, `detailMenuSelect`, `noSpecificationsSelect`, `menuSelect` sırasıyla deneniyor.
  - Benzer pattern `getProductsBySellerId` (satır 1764–1803) ve `supabase_service.dart::getProductExtrasByNameBrand` (satır 418–474) içinde de tekrarlanıyor.
- **Why Inefficient:** Aynı "sütun yoksa kaldır, tekrar dene" mantığı 3 farklı yerde bağımsız implement edilmiş. `_runProductsSelectWithFallback` generic yardımcı zaten `supabase_service.dart`'ta var ama `store_service.dart`'ta kullanılmıyor.
- **Recommended Fix (likely):** `store_service.dart` içine `supabase_service.dart`'takine benzer generic fallback helper taşı; tüm getler bu helper üzerinden çalışsın.
- **Tradeoffs / Risks:** Refactor riski — bridge, routing ve sipariş no logic'e dokunmadan sadece DB select katmanı değişir.
- **Expected Impact Estimate:** Bakım maliyeti belirgin düşer; logic değişikliği yok.
- **Removal Safety:** Orta — fallback zincirlerin test coverage'ı kontrol edilmeli.
- **Reuse Scope:** `store_service.dart`, `supabase_service.dart`

---

## F-08 · `kitchen_hub_payload_stamp.dart` — Items Çift Geçiş (Double Processing)

- **Category:** Performance / CPU
- **Severity:** Medium
- **Impact:** Her print job'da her item iki kez station resolution logic'inden geçiyor.
- **Evidence:**
  - `kitchen_hub_payload_stamp.dart` satır 141–207: `for (final raw in rawItems)` loop — her item için `resolveHubItemProductionStation` çağırıyor ve `resolvedItems` listesine ekliyor.
  - Satır 209–217: Hemen ardından `enrichItemsWithProductionStations(items: resolvedItems, ...)` — bu fonksiyon da `kitchen_routing_service.dart` satır 876–970'te her item'ı yeniden map'leyerek station resolution logic'i tekrar çalıştırıyor.
  - İki pass arasında `resolvedItems` zaten `station_id`, `station_name`, `station_code` alanlarıyla doldurulmuş durumda; ikinci pass çoğunlukla aynı sonuca ulaşıyor.
- **Why Inefficient:** Station bilgisi ilk pass'ta item'a yazıldıktan sonra ikinci pass bunu tekrar çözmeye çalışıyor. İkinci pass'ın "already enriched" kontrolü yok.
- **Recommended Fix (likely):** İlk pass'ta station alanları dolu olan item'lar için `enrichItemsWithProductionStations` içinde erken `continue` ekle.
- **Tradeoffs / Risks:** Print routing testlerini koşmadan değişiklik yapma. `enrichItemsWithProductionStations` bazı edge case'lerde station'ı override edebilir; bu davranışın korunması gerekebilir.
- **Expected Impact Estimate:** likely her sipariş için print CPU time %20–30 azalma (ölçülmeli).
- **Removal Safety:** Riskli — bridge zincirini kırmadan dikkatli test gerektirir. **"Do Not Touch"** kapsamına yakın.
- **Reuse Scope:** `kitchen_hub_payload_stamp.dart`, `kitchen_routing_service.dart`

---

## F-09 · `server.py::_printer_health_payload` — İki Dalda Aynı `transport.health()` Çağrısı

- **Category:** Performance / Code Quality
- **Severity:** Low
- **Impact:** Sağlık kontrolü sırasında gereksiz tekrar.
- **Evidence:**
  - `server.py` satır 214–235:
    ```python
    if _ensure_windows_queue_selected():
        payload = dict(PrintBridgeHandler.transport.health())  # branch A
    else:
        payload = dict(PrintBridgeHandler.transport.health())  # branch B
    ```
    İki dal da aynı ifadeyi çalıştırıyor.
- **Why Inefficient:** Branch A'da `_ensure_windows_queue_selected()` çağrısı içindeki printer discovery (`discover_windows_printers()`) zaten transport'u yeniden yükleyebilir; sonrasında transport.health() doğru sonucu verir. Branch B de aynı şeyi yapar. Her iki dal aynı satır; if/else semantik değer taşımıyor.
- **Recommended Fix:** `if/else`'i kaldır, `_ensure_windows_queue_selected()` çağrısını yap, ardından tek bir `payload = dict(PrintBridgeHandler.transport.health())` yaz.
- **Tradeoffs / Risks:** Düşük risk; Windows'a özgü, test platformunda gözlemlenebilir.
- **Expected Impact Estimate:** Mikro optimizasyon; kod netliği kazanımı.
- **Removal Safety:** Güvenli.
- **Reuse Scope:** `local_print_bridge/server.py`

---

## F-10 · `server.py::_error_response` — Her Hata Yanıtında `probe_pillow(reload=True)`

- **Category:** Performance
- **Severity:** Medium
- **Impact:** Her HTTP hata yanıtında Pillow yeniden taranıyor; yüksek hata oranlı dönemlerde (yazıcı bağlantı sorunu vs.) köklü overhead.
- **Evidence:**
  - `server.py` satır 121–133: `_error_response` → `_runtime_diagnostics()` → `probe_pillow(reload=True)`.
  - `reload=True` Pillow'u her seferinde dinamik import ile yeniden probe ediyor.
- **Why Inefficient:** Pillow varlığı process boyunca değişmez. `reload=True` sadece `diagnostics` endpoint'inde mantıklı; hata yanıtlarında gereksiz.
- **Recommended Fix:** `_error_response` için `probe_pillow(reload=False)` veya başlangıçta cache edilmiş bir `_PILLOW_STATUS` sabiti kullan.
- **Tradeoffs / Risks:** Diagnostics endpoint'te reload=True korunmalı. Değişiklik yalnızca error path'ine özgü.
- **Expected Impact Estimate:** Yazıcı sorunlu ortamda HTTP latency azalır.
- **Removal Safety:** Güvenli.
- **Reuse Scope:** `local_print_bridge/server.py`

---

## F-11 · `_currentStoreBusinessName()` — Bildirim Her Çağrısında Ayrı DB Sorgusu

- **Category:** Database / Network
- **Severity:** Low-Medium
- **Impact:** Yeni ürün ekleme, indirim ve duyuru bildirimleri üç ayrı `_currentStoreBusinessName()` çağrısı yapar; her biri ayrı Supabase HTTP request.
- **Evidence:**
  - `store_service.dart` satır 1927–1941: `_currentStoreBusinessName()` — her seferinde `.from('stores').select('business_name').eq(...)` çağrısı.
  - Satır 1944–1957, 1959–1972, 1974–1982: Üç farklı notify fonksiyonu bağımsız çağırıyor.
- **Why Inefficient:** Mağaza adı oturum süresince değişmez (veya nadiren değişir). Session-level cache veya `getStoreProfile`'dan gelen cached değer kullanılabilir.
- **Recommended Fix:** `StoreService` içine `String? _cachedBusinessName` field ekle; `getStoreProfile` çağrısında doldurul. `_currentStoreBusinessName()` önce cache'i kontrol etsin.
- **Tradeoffs / Risks:** Profil güncellendiğinde cache invalidate edilmeli.
- **Expected Impact Estimate:** 2–3 DB round-trip → 0 (cache hit'te).
- **Removal Safety:** Güvenli.
- **Reuse Scope:** `store_service.dart`

---

## F-12 · `fetchPendingProducts` — 2 Ayrı Sorgu (Products + Stores) + Manuel `SellerProduct` Kopyalama

- **Category:** Database / Maintainability
- **Severity:** Medium
- **Impact:** Admin panel ürün listesi yüklenirken ürünler çekilip sonra mağaza adları için ikinci bir query yapılıyor; ardından matched product'lar için 20+ alan tek tek kopyalanarak yeni bir `SellerProduct` oluşturuluyor.
- **Evidence:**
  - `store_service.dart` satır 958–1028: Ürünler çekiliyor → `sellerIds` toplanıyor → stores çekiliyor → map oluşturuluyor → her ürün için manual `SellerProduct(...)` re-construction (satır 1003–1024, 20+ alan tek tek kopyalanıyor, birkaç alan eksik: pricingMode, basePrice, pricingType, pricePerKg, sizeOptions, serviceControlType, stationId vs. kopyalanmıyor).
  - Kopyalama incomplete: `stationId`, `stationName`, `stationCode`, `printerRoutingEnabled` vs. yeni nesneye geçmiyor.
- **Why Inefficient:** (1) Supabase foreign key join ile tek sorguda `stores(business_name)` çekilebilir. (2) `copyWith` metodu olmadığından tüm alanlar tek tek yazılıyor ve bazıları atlanıyor — bu silent data loss riski.
- **Recommended Fix:** Supabase join kullan: `from('products').select('*, stores(business_name)')...`. `SellerProduct` modeline `copyWith` ekle.
- **Tradeoffs / Risks:** RLS politikasının join'e izin verip vermediğini doğrula.
- **Expected Impact Estimate:** 2 HTTP round-trip → 1.
- **Removal Safety:** Orta — join'in RLS'de test edilmesi gerekir.
- **Reuse Scope:** `store_service.dart`, `seller_product.dart`

---

## F-13 · `getProducts` / `getSellerProducts` — İki Neredeyse Aynı Stream Metodu

- **Category:** Dead Code / Maintainability
- **Severity:** Low
- **Impact:** Bakım maliyeti.
- **Evidence:**
  - `store_service.dart` satır 1121–1128: `getProducts()` stream.
  - Satır 1409–1418: `getSellerProducts()` stream.
  - Her iki metod da `currentUserId`, `products` tablosu, aynı filtre ve mapping kullanıyor. `getProducts`'ta `!` (non-null assertion) var, `getSellerProducts`'ta null guard var.
- **Why Inefficient:** İki metod aynı işi yapıyor; ikisi de production'da kullanılıyorsa hangisi tercih edilmeli belirsiz. Dead code riski.
- **Recommended Fix:** `getProducts`'ın hangi call site'larda kullanıldığını kontrol et; `getSellerProducts` zaten güvenli null guard içeriyor. `getProducts`'ı deprecate et.
- **Tradeoffs / Risks:** Call site'lar değiştirilmeden biri kaldırılamaz.
- **Expected Impact Estimate:** Kod sağlığı iyileşir.
- **Removal Safety:** Önce usage audit gerekli.
- **Reuse Scope:** `store_service.dart`

---

## F-14 · `GarsonProductModalState._logInit` — Debug'da Fiyat Hesabı

- **Category:** Performance / Debug Overhead
- **Severity:** Low-Medium
- **Impact:** Her garson modal açılışında (debug build'de) tam fiyat hesabı çalışıyor sadece log için.
- **Evidence:**
  - `garson_product_selection.dart` satır 243–282: `_logInit` içinde `GarsonProductSelection.resolveUnitPrice(...)` çağrısı — tam fiyat calculation zinciri debug output için çalıştırılıyor.
  - Satır 256: `product.normalizedSizeOptions.map(...)` — debug string için ayrıca sizeOption iterate.
  - Bu metod `openNew` ve `fromDraftItem` factory'lerinden her çağrıda tetikleniyor.
- **Why Inefficient:** Zaten constructor sırasında hesaplanmış değerlerin tekrar hesaplanması; kDebugMode guard var ama debug geliştirme ortamında her modal açılışında cost var.
- **Recommended Fix:** `_logInit` içindeki `resolveUnitPrice` çağrısını kaldır; yerine constructor'da hesaplanan unit price'ı ilet veya log metnini sadeleştir.
- **Tradeoffs / Risks:** Debug log kalitesi biraz düşer.
- **Expected Impact Estimate:** Debug build'de modal açılış ~1–2ms iyileşme (ölçülmeli).
- **Removal Safety:** Güvenli.
- **Reuse Scope:** `garson_product_selection.dart`

---

## F-15 · Debug Log Fonksiyon Duplikasyonu

- **Category:** Maintainability / Dead Code Risk
- **Severity:** Low
- **Impact:** Bakım maliyeti ve tutarsız log format riski.
- **Evidence:**
  - `garson_product_selection.dart` satır 17–47: `garsonProductSelectLog`, `garsonOrderItemLog`, `sellerNavigationLog`, `garsonDraftLog` — dört fonksiyon, aynı pattern (kDebugMode guard, suffix build, debugPrint).
  - `kitchen_routing_service.dart` satır 7–23: `kitchenRoutingLog`, `kitchenPrintPayloadLog` — aynı pattern.
  - Her birinde `extra.entries.map((e) => '${e.key}=${e.value}').join(' ')` aynı suffix builder. Map→String interpolasyon her log çağrısında çalışır.
- **Why Inefficient:** Duplicate implementation; bir tanede değişiklik yapılırsa diğerleri unutulur. Suffix build, extra boş olsa bile `?.isEmpty` kontrolü sonrası `''` döndürüyor ama `extra == null` durumu kontrol edildikten sonra `extra.isEmpty` için ayrı dal var.
- **Recommended Fix:** Tek generic helper fonksiyon: `void _bridgeLog(String prefix, String stage, Map<String,Object?>? extra)`.
- **Tradeoffs / Risks:** Sıfır risk; sadece log format.
- **Expected Impact Estimate:** Kod sağlığı.
- **Removal Safety:** Güvenli.
- **Reuse Scope:** `garson_product_selection.dart`, `kitchen_routing_service.dart`

---

## F-16 · `sanitizeOrderItemFields` İçinde Çift Çağrı (likely)

- **Category:** Performance
- **Severity:** Low
- **Impact:** Her `buildOrderItem` çağrısında `sanitizeOrderItemFields` iki kez çalışıyor.
- **Evidence:**
  - `garson_product_selection.dart` satır 1100: `sanitizeOrderItemFields(item)` çağrısı → `enrichOrderItem(sanitized)`.
  - `enrichOrderItem` (satır 1362–1393) satır 1366: `sanitizeOrderItemFields(item)` yeniden çağrılıyor.
  - `sanitizeOrderItemFields` her çağrıda `Map<String, dynamic>.from(item)` ile kopya oluşturuyor.
- **Why Inefficient:** Aynı map iki kez sanitize edilip iki kez kopyalanıyor.
- **Recommended Fix (likely):** `buildOrderItem` içinde önce `enrichOrderItem`'ı çağır, `sanitizeOrderItemFields` sadece `enrichOrderItem` içinde yapılsın; `buildOrderItem`'dan ayrı `sanitizeOrderItemFields` çağrısı kaldırılabilir.
- **Tradeoffs / Risks:** `enrichOrderItem` davranışı bağımsız kullanımda değişmemeli.
- **Expected Impact Estimate:** Her item build'de ~2 map copy tasarrufu.
- **Removal Safety:** Orta — davranış testi gerekli.
- **Reuse Scope:** `garson_product_selection.dart`

---

## F-17 · `seller_panel_page.dart` — 36 000 Satır Tek State Sınıfı

- **Category:** Maintainability / Rebuild Surface
- **Severity:** High (maintainability), Medium (performance)
- **Impact:** `_SellerPanelPageState` içindeki tüm state alanları global olduğundan herhangi bir `setState` tüm subtree'yi potansiyel olarak etkiliyor. Garson akışı, ürün yönetimi, dashboard ve finans aynı state'i paylaşıyor.
- **Evidence:**
  - `seller_panel_page.dart` satır 270–300+: `_SellerPanelPageState` sınıfı başlıyor; satır 290'dan itibaren düzinelerce state field. `part` dosyaları state metodlarını paylaşıyor ama hepsi aynı `State` object.
  - İmport listesi (satır 1–103): 100+ import; tüm modüller tek dosyadan import ediliyor.
- **Why Inefficient:** Büyük State sınıfı, `setState` granülaritesini düşürür. Garson masa grid'i yenilenmesi, seller dashboard widget'larını da tetikleyebilir.
- **Recommended Fix:** `_SelectedModule` bazlı lazy loading veya her modül için ayrı `StatefulWidget`. Garson akışı özellikle ayrı `StatefulWidget` adayı.
- **Tradeoffs / Risks:** Büyük refactor — sipariş no logic, bridge dispatch, print feedback state bunların bazısı global state gerektiriyor olabilir. **Önce profil, sonra karar.**
- **Expected Impact Estimate:** likely yavaş açılan ekranlarda belirgin iyileşme; ölçülmeden kesin rakam verilmez.
- **Removal Safety:** Riskli. Önce `flutter analyze` + smoke test. Bu bulgu "Deeper Optimizations" kapsamında.
- **Reuse Scope:** `seller_panel_page.dart` ve tüm `part` dosyaları

---

## F-18 · `unitSelectionMergeKey` — Sadece Key İçin Tam `buildOrderItem` Çalıştırıyor

- **Category:** Performance
- **Severity:** Medium
- **Impact:** Çok ünite seçiminde (qty > 1) her ünite için tam bir `buildOrderItem` çağrısı yapılıyor sadece merge key oluşturmak için.
- **Evidence:**
  - `garson_product_selection.dart` satır 961–972: `unitSelectionMergeKey` → `buildOrderItemFromUnit` → `buildOrderItem` → `resolveUnitPrice` + `resolveAmountLabel` + `sanitizeOrderItemFields` + `enrichOrderItem`.
  - Bu `groupUnitSelectionsByMergeKey` (satır 975–999) içinde her ünite için çağrılıyor.
  - Qty=5 siparişte 5 × tam `buildOrderItem` sadece gruplama için.
- **Why Inefficient:** Merge key hesabı için fiyat ve label hesabı gerekmiyor. Key sadece: `productId`, `pricingMode`, `sizeName/grams/portionAmount`, `attributes`, `note`.
- **Recommended Fix:** `unitSelectionMergeKey` metodunu `buildOrderItem` kullanmadan doğrudan key string hesaplayan lite versiyona çevir.
- **Tradeoffs / Risks:** Key formatı `orderLineMergeKey` ile tutarlı kalmalı; aksi halde gruplama bozulur.
- **Expected Impact Estimate:** Çok ünite siparişlerde O(N) build → O(N) hafif key hesabı.
- **Removal Safety:** Orta — key format testi gerekli.
- **Reuse Scope:** `garson_product_selection.dart`

---

## F-19 · `_gramsFromItem` — Her Çağrıda 4 Key Dene

- **Category:** Micro-optimization / Code Quality
- **Severity:** Low
- **Impact:** Her item için 4 Map lookup; sık çağrıldığında minor overhead.
- **Evidence:**
  - `garson_product_selection.dart` satır 1005–1010: `_gramsFromItem` 4 farklı key'i sırayla deniyor.
  - Bu fonksiyon `buildOrderItem`, `orderLineMergeKey`, `enrichOrderItem`, `_variantLabelForItem` içinden çağrılıyor.
- **Why Inefficient:** Map duplikasyonu (F-03) çözülürse tek key yeterli olur. Şimdilik 4 key gereksinimi Map karmaşıklığının simptomudur.
- **Recommended Fix:** F-03 çözüldükten sonra `_gramsFromItem` otomatik sadeleşir.
- **Tradeoffs / Risks:** F-03'e bağımlı.
- **Expected Impact Estimate:** F-03 sonrası otomatik iyileşme.
- **Removal Safety:** F-03 tamamlandıktan sonra güvenli.
- **Reuse Scope:** `garson_product_selection.dart`

---

## F-20 · `supabase_service.dart` — 8 Farklı `_productSelectFields` String Sabit

- **Category:** Maintainability
- **Severity:** Low
- **Impact:** Yeni bir DB kolonu eklendiğinde 8 farklı yerde güncelleme gerekiyor; biri unutulursa tutarsızlık.
- **Evidence:**
  - `supabase_service.dart` satır 100–148: `_productSelectFields`, `_homeProductSelectFields`, `_homeProductSelectFieldsSansStore`, `_productSelectFieldsSansStore`, `_productSuggestionSelectFields`, `_productStorePreviewSelectFields`, `_categoryProductsSelectFields` — 7 static const string + store_service.dart'ta 4+ daha.
- **Why Inefficient:** Kolonlar arasındaki farklar küçük ama manuel yönetilen; bir kolonu eklemek/kaldırmak N yer güncelleme gerektirir.
- **Recommended Fix:** Kolon setlerini liste/set olarak tanımla; join ile string oluştur. Veya en azından bir "base set" + "ekstralar" composition pattern kullan.
- **Tradeoffs / Risks:** Refactor maliyeti düşük, fayda uzun vadede.
- **Expected Impact Estimate:** Bakım kolaylığı.
- **Removal Safety:** Güvenli.
- **Reuse Scope:** `supabase_service.dart`, `store_service.dart`

---

# 3) Quick Wins

Aşağıdaki değişiklikler hızlı, düşük riskli ve yüksek görünürlük:

| # | Bulgu | Dosya | Süre Est. |
|---|-------|-------|-----------|
| QW-1 | `SellerProduct.fromMap` içindeki koşulsuz `debugPrint` → `if (kDebugMode)` ekle | `seller_product.dart` satır 327 | 5 dk |
| QW-2 | `server.py::_printer_health_payload` if/else dallarındaki tekrar → tek dal | `server.py` ~satır 214 | 5 dk |
| QW-3 | `server.py::_error_response` → `probe_pillow(reload=False)` | `server.py` ~satır 114 | 5 dk |
| QW-4 | `getCategoriesWithSubs` N+1 → tek sorgu + client group | `supabase_service.dart` satır 1197 | 30 dk |
| QW-5 | `store_service_mappers.dart::productToSnakeCase` → `created_at` alanını kaldır | `store_service_mappers.dart` satır 130 | 10 dk + test |
| QW-6 | `_currentStoreBusinessName` → session-level cache ekle | `store_service.dart` satır 1927 | 15 dk |
| QW-7 | `getStoreProfile` → explicit kolon listesi (SELECT * → SELECT field1, field2...) | `store_service.dart` satır 296 | 15 dk |
| QW-8 | Debug log fonksiyonlarını generic helper'a birleştir | `garson_product_selection.dart`, `kitchen_routing_service.dart` | 20 dk |

---

# 4) Deeper Optimizations

Daha sonra yapılabilecek büyük refactorlar; öncesinde kapsamlı test ve profiling gerektirir:

## D-01 · `seller_panel_page.dart` State Modülarizasyonu
- Her `SellerModule` (dashboard, garson, ürünler, finans) için ayrı `StatefulWidget` veya `ChangeNotifier` izolasyonu.
- `InheritedWidget` / `Provider` tabanlı state seçici widget rebuilds.
- **Önce:** Flutter DevTools ile rebuild profili al.

## D-02 · `SellerProduct` Memoized Computed Properties
- Constructor'da `late final` ile tüm pahalı getter'lar hesaplanır.
- `fromMap` factory immutable nesne döndürdüğünden `late final` güvenli.

## D-03 · Order Item Map Tek Key Standardizasyonu
- Snake_case veya camelCase birini seç; bridge, Supabase ve Flutter layer tümü aynı convention'ı kullanacak şekilde güncelle.
- Bu değişiklik python bridge'de `kitchen.py` / `receipt.py` field access'lerini de etkiler — koordineli migration gerekir.
- **Önce:** Bridge + Flutter entegrasyon testi tam suite'i geçmeli.

## D-04 · `getMenuProductsBySellerId` Fallback Logic Birleştirilmesi
- Generic `_selectWithColumnFallback<T>` yardımcı yaratılır.
- `store_service.dart` ve `supabase_service.dart` bu helper'ı paylaşır.

## D-05 · `fetchPendingProducts` Supabase Join
- `from('products').select('*, stores(business_name)')` ile tek sorgu.
- `SellerProduct` modeline `copyWith` metodu eklenir.

## D-06 · Print Job Item Station Double Processing Kaldırma
- `stampHubKitchenPrintPayload` içindeki ilk loop'ta item'lar station alanlarıyla doldurulduktan sonra `enrichItemsWithProductionStations` çağrısında "already has station" kontrolü eklenir.
- **Önce:** Tüm routing test senaryoları koşulmalı (OCAK/FIRIN/KASAP routing, Genel fallback, masa alanı reddi).

## D-07 · `unitSelectionMergeKey` Lite Hesaplama
- `buildOrderItem` çağrısı yerine direkt key alanları birleştiren hafif fonksiyon.

---

# 5) Validation Plan

Her öneri için uygulama sonrası doğrulama adımları:

## flutter analyze
```bash
cd ibul_app && flutter analyze
```
- Tüm değişiklikler sonrası sıfır hata.

## flutter test
```bash
cd ibul_app && flutter test
```
- Mevcut testler geçmeli. Özellikle:
  - `test/product_pricing_test.dart` (varsa)
  - `test/garson_product_selection_test.dart` (varsa)
  - `test/kitchen_routing_test.dart` (varsa)

## Manuel Garson Sipariş Testi (F-01, F-02, F-03, F-16, F-18)
1. Garson ekranını aç → masa seç.
2. Gramajlı ürün seç (ör. 500g).
3. Boyutlu ürün seç (ör. Tek / Duble).
4. Porsiyon stepperli ürün seç.
5. Sipariş taslağına ekle, miktarı değiştir.
6. Siparişi gönder.
7. `flutter logs` çıktısında hata veya beklenmedik state yok.

## Adisyon Testi (F-03, D-03 için)
1. Masayı kapat → ödeme yöntemi seç → adisyon bas.
2. Fiyat, gramaj, boyut alanlarının fişte doğru görüntülendiğini doğrula.
3. Python bridge `receipt.py` alanlarının doğru map'lendiğini loglardan kontrol et.

## Mutfak Fişi Testi (F-08, D-06 için)
1. OCAK istasyonuna ait ürün sipariş et → mutfak fişinin başlığında "OCAK" çıktığını doğrula.
2. FIRIN istasyonuna ait ürün → "FIRIN".
3. İstasyonu olmayan ürün → "Genel".
4. Birden fazla istasyonlu sipariş → her istasyon için ayrı fiş basıldığını doğrula.

## Mac/Windows Print Testi (F-09, F-10 için)
1. Bridge çalıştır: `python -m local_print_bridge.server`.
2. `GET /health` → `{"ok": true}` beklenir.
3. Hata durumu simüle et (yazıcıyı çıkar) → `_error_response` dönmeli ama Pillow probe gereksiz yavaşlık yaratmamalı.
4. Windows'ta: `PRINT_BRIDGE_PRINTER_QUEUE` boşken health endpoint'ini çağır → `queue_pending: true` dönmeli.

## DB Güvenlik Testi (F-06 için)
- `productToSnakeCase`'den `created_at` kaldırıldıktan sonra:
  1. Yeni ürün ekle → `created_at` DB'de otomatik set edilmeli (default değer).
  2. Ürün güncelle → `created_at` değişmemeli.

## Supabase Sorgu Testi (F-04, F-05, F-07 için)
- Supabase dashboard'dan `getCategoriesWithSubs` çağrısından sonra query log'u kontrol et.
- N sorgu → 1 sorguya düştüğünü doğrula.

---

# 6) Do Not Touch List

Aşağıdaki dosya / akışlara hiçbir zaman izinsiz dokunulmaması önerilir:

| Alan | Dosya / Akış | Neden |
|------|-------------|-------|
| Bridge executable | `local_print_bridge/windows/`, installer script | PyInstaller bundle; rebuild gerektirir |
| Installer | `local_print_bridge/windows/` | Windows kurulum akışı |
| POS-58 encoding | `local_print_bridge/receipt.py` → `encode_text_report`, `render_turkish_encoding_*` | Türkçe karakter garanti modunu bozar |
| OCAK / FIRIN / KASAP routing | `kitchen_routing_service.dart`, `kitchen_hub_payload_stamp.dart` → station resolution zinciri | İstasyon başlığı yanlış eşlenirse mutfak fişleri yanlış yazıcıya gider |
| Sipariş no logic | `kitchen_order_number_fields.dart` (import'tan tespit edildi) | Fişte sipariş no sırası bozulur |
| Gramaj / boyut print label zinciri | `garson_product_selection.dart` → `resolvePrintItemLabel`, `resolvePrintItemAmountLabel`, `buildOrderItem` → `amount_label` / `gramaj` alanları | Fişte yanlış gramaj/boyut yazması müşteri şikayetine yol açar |
| Türkçe Garanti Modu | `server.py` → `_request_turkish_guarantee_mode`, `_request_turkish_print_mode_label` | Türkçe özel karakter garanti mekanizması |
| Supabase migration geçmişi | `ibul_app/supabase/migrations/` (47 dosya) | Rollback edilemeyen DB state değişikliği |
| ESC/POS raster encoder | `local_print_bridge/raster.py` | Bitmap/font rendering bozulur |
| Transport layer | `local_print_bridge/transport.py`, `usb_transport.py`, `windows_transport.py` | Yazıcı bağlantı zinciri |

---

# Appendix: Dead Code Tespiti

Aşağıdakiler likely dead code; kullanım yeri audit edilmeden silinmemeli:

| Bulgu | Dosya | Evidence |
|-------|-------|----------|
| `getProducts()` stream | `store_service.dart` satır 1121 | `getSellerProducts()` ile aynı iş; hangisi kullanılıyor? |
| `updateProductOld(...)` | `store_service.dart` satır 1472 | "Deprecated method, kept to satisfy linter" — aktif call site var mı? |
| `getProductVariantsByGroupId` | `supabase_service.dart` satır 1087 | İçi boş: `return []` — call site var mı? |
| `getVariantOptionKeys` | `supabase_service.dart` satır 1115 | `return {}` — aktif kullanım? |
| `getVariantValues` | `supabase_service.dart` satır 1119 | `return {}` — aktif kullanım? |
| `getProductByVariantOptions` | `supabase_service.dart` satır 1126 | `return null` — aktif kullanım? |
| `storagePricingModeFromItem` | `garson_product_selection.dart` satır 1001 | `strictPricingModeFromItem` çağrısından ibaret — neden iki ayrı isim? |
| `@Deprecated selectionSummaryLabel` | `garson_product_selection.dart` satır 446 | `@Deprecated` işareti; call site var mı? |

---

*Bu dosya sadece analiz çıktısıdır. Hiçbir kod değiştirilmemiştir.*
