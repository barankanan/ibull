# İBUL Otonom İlerleme Raporu

## Çalıştırma #1 — 2026-11-16 (21:23 UTC)
- Son denetlenen uygulama: Yok (ortam doğrulaması)
- Durum: BLOCKED (kısmen) — kod değişikliği yapılmadı
- Bulgular:
  - Git: ~80 commit edilmemiş değişiklik var (seller yazıcı/garson/LAN/staff login dosyaları, testler, pubspec). Korundu, dokunulmadı.
  - Son 30 dk içinde `ibul_app/test/screens/failures/*.png` (golden test hata çıktıları) yazılmış → kullanıcı veya başka bir oturum şu an Flutter test çalıştırıyor olabilir. Eşzamanlı düzenleme riski nedeniyle kaynak düzenlenmedi.
  - Ortam: Bulut sandbox VM'inde `flutter`/`dart` yok, `pytest` yok → Flutter analyze/test bu ortamda çalıştırılamıyor (BLOCKED). Disk: 20 GB boş (%96 dolu, dikkat).
  - Önceki rapor yoktu; bu dosya oluşturuldu.
- Çalıştırılan testler: Yok.
- Gerçek ortam/fiziksel doğrulama: Yapılmadı.
## Sonraki en değerli görev
1. Commit edilmemiş seller yazıcı/garson değişikliklerinin (kitchen_print_dedup, desktop_print_hub, staff_login_policy) kullanıcı tarafından gözden geçirilip commit edilmesi gerekir; ardından bunların üzerinde regresyon denetimi.
2. Golden test hataları (`test/screens/failures`) kök neden analizi (sipariş sekmesi / ürünler sekmesi görsel fark).
3. Flutter erişimi olan ortamda `flutter analyze` + hedefli test.

## Çalıştırma #2 — 2026-11-16 (21:30 UTC)
- Durum: BLOCKED — kod değişikliği yapılmadı (Run #1 ile aynı nedenler).
- Git: 81 commit edilmemiş değişiklik (korundu). Son 30 dk içinde yine `ibul_app/test/screens/failures/*.png` yazıldı → başka oturum/kullanıcı aktif test çalıştırıyor; eşzamanlı düzenleme yapılmadı.
- Ortam: `flutter`/`dart` PATH'te yok (hem bulut hem cihaz VM'i); yalnızca python3/node var → analyze/test çalıştırılamıyor. Disk 20 GB boş (%96).
- Test: yok. Gerçek ortam doğrulaması: yok.
## Sonraki en değerli görev
Flutter erişimi olan ortamda (veya cihaz VM'ine flutter kurulumu ile) golden test hatalarının kök neden analizi + commit edilmemiş seller yazıcı/garson değişikliklerinin regresyon denetimi.

## Çalıştırma #3 — 2026-11-17 (01:13 +03) — yerel Mac, Flutter erişimi VAR
- Son denetlenen uygulama: İBUL Satıcı — yazıcı kuyruğu / Yazıcı Merkezi
- Ortam: flutter mevcut, disk 13 GB boş, RAM sıkışık (swap yoğun), aktif test/build süreci yok (yalnızca dart language-server). 89 commit edilmemiş dosya korundu.
- `flutter analyze` (lib/services, utils, garson modeli, LAN widget'ları): hata yok, 14 uyarı/info (kullanılmayan `_calculateDeliveryPricing`/`_buildTrackingNumber` order_service.dart — ödeme alanına yakın olduğu için dokunulmadı; lan_cert_material gereksiz cast'ler; order_print_job_service.dart:5579 gereksiz null karşılaştırması).
- Bulunan hata (P2): `printer_center_operations_test` "queue counts" testi başarısız. Kök neden: `PrintJobModel.operatorQueueBucket` `quarantined` durumunu tanımıyordu (varsayılan → uncertain, Karantina sayacı 0) ve "belirsiz" notu taşıyan `completed` iş "sent" sayılıyordu (yanıltıcı "gönderildi").
- Düzeltme: `ibul_app/lib/models/print_job_model.dart` — `quarantined` → quarantine; `completed` + lastError "belirsiz" → uncertain.
- Testler: printer_center_operations + printer_center_hardening PASS; kitchen_fast_dispatch, desktop_print_orchestrator, garson_critical_operations, garson_integration_hardening PASS (258). analyze print_job_model.dart temiz.
- Durum: Kod tamamlandı / Test geçti. Entegre edilmedi (commit yok). Gerçek yazıcı/ortam doğrulaması YOK.
- Kalan başarısız (mevcut, bu değişiklikten bağımsız, kök neden doğrulanmadı): 
  - windows_pos58_unified_dispatch_test (3 test), windows_pos58_encoding_profile_test, ethernet_role_mapping_test (queued kitchen payload tcp metadata), printer_system_setup_wizard_widget_test (copy diagnostics). Windows POS-58 testlerinde bridge isteği test HttpClient'ında 400 dönüyor; test altyapısı mı yoksa uncommitted değişiklik mi araştırılmalı.
## Sonraki en değerli görev
1. Yukarıdaki 6 kalan başarısız printer_setup testinin kök neden analizi (önce ethernet_role_mapping_test — kuyruğa alınmış mutfak payload'ında tcp metadata kaybı olası gerçek hata).
2. Golden test hataları (`test/screens/failures`).
3. Commit edilmemiş değişikliklerin kullanıcı tarafından commit edilmesi.

## Çalıştırma #4 — 2026-11-17 — yerel Mac, Flutter var
- Son denetlenen uygulama/modül: İBUL Satıcı — yazıcı kurulum sihirbazı testleri (`test/printer_setup`).
- Ortam: aktif test/build yok (yalnızca dart language-server), disk 12 GB boş, 95 commit edilmemiş dosya korundu.
- Durum tespiti: Run #3'te listelenen 6 başarısız testten yalnızca 1'i kalmıştı (ethernet_role_mapping, windows_pos58_* ve ethernet dialog testleri şu an PASS; bu çalıştırmada başarısızlık yeniden üretilemedi, kök neden/çözüm kaynağı doğrulanmadı — büyük olasılıkla Run #3 sonrası değişiklikler).
- Bulunan hata (P3, test altyapısı): `Bridge operator tools can copy diagnostics without terminal` başarısız.
  - Kök neden: Testte `SystemChannels.platform` için Clipboard mock'u yoktu; `Clipboard.setData` hiç tamamlanmıyor, SnackBar hiç gösterilmiyordu (uygulama kodu doğru; izleme ile doğrulandı).
  - Düzeltme: yalnızca test — `printer_system_setup_wizard_widget_test.dart` içinde Clipboard method-channel mock'u + panoya yazılan içerikte `recent_print_logs` doğrulaması. Uygulama kodu değişmedi.
- Test: `flutter test test/printer_setup` → 257 PASS / 0 FAIL.
- Seviye: Kod tamamlandı / Test geçti. Entegre edilmedi (commit yok). Gerçek ortam doğrulaması YOK.
- Not: `order_service.dart` kullanılmayan fiyat/takip fonksiyonları (ödeme alanına yakın) hâlâ dokunulmadı.
## Sonraki en değerli görev
1. Golden test hataları (`test/screens/failures`) kök neden analizi.
2. `order_print_job_service.dart:5579` gereksiz null karşılaştırması + lan_cert_material cast uyarıları (düşük riskli analyzer temizliği).
3. Commit edilmemiş değişikliklerin kullanıcı tarafından gözden geçirilip commit edilmesi.

## Çalıştırma #5 — 2026-11-17 (23:06 +03) — yerel Mac, Flutter var
- Son denetlenen uygulama/modül: İBUL E-Ticaret (müşteri) — ürün arama / kategori filtresi / favori listeleri.
- Ortam: disk 11 GB boş (eşik sınırında), swap ~10.8/12 GB dolu. Eşzamanlı çalışma VAR: `xcodebuild` (SellerOfflinetest, izole DerivedData) sürüyordu; son 20 dk'da `seller_panel_page.dart`, `offline_panel_identity*.dart` ve 50 dk önce `ihiz_web/lib/main.dart` başka oturumca değiştirilmiş. Bu yüzden satıcı/çevrimdışı/yazıcı/İHIZ dosyalarına DOKUNULMADI; ağır build başlatılmadı. ~119 commit edilmemiş dosya korundu.
- Not: `ihiz_web` içinde bu raporda kaydı olmayan commit edilmemiş iş var (`ihiz_delivery_action_gate.dart`, `ihiz_location_poll_policy.dart` + main.dart entegrasyonu, testleri). Başka oturuma ait; denetlenmedi.
- Bulunan hata (P2, kullanıcıya görünür): Türkçe karakterli aramalar sonuçsuz kalıyordu.
  - Kök neden: Arama `String.toLowerCase()` ile yapılıyordu. Dart'ta "I" → "i" (ı değil), "İ" → "i̇" (i + birleştirici nokta). Sonuç: "ısıtıcı" sorgusu "ISITICI"yı, "iskender" sorgusu "İskender"i, "İPHONE" sorgusu "iPhone"u bulamıyordu. Test ile yeniden üretildi (önce FAIL).
  - Düzeltme: mevcut `TextNormalizer.normalize` (yeni altyapı yok) kullanıldı. Yan etki (istenen): aksan duyarsız eşleşme ("sut" → "Süt").
- Değişen dosyalar:
  - `ibul_app/lib/features/products/helpers/product_filter_engine.dart` (applyFilters arama eşleşmesi)
  - `ibul_app/lib/screens/category_products_page.dart` (Yemek kategorisi yerel araması)
  - `ibul_app/lib/screens/favorites_page.dart` (liste adı araması)
  - `ibul_app/test/features/products/product_filter_engine_test.dart` (+1 regresyon testi)
- Testler: `flutter test test/features/products` → 27 PASS / 0 FAIL. `dart analyze` (3 dosya + features/products) temiz.
- Seviye: Kod tamamlandı / Test geçti (yalnızca filtre motoru birim testi; iki ekran düzenlemesi için widget testi yok, yalnızca analyze). Entegre edilmedi (commit yok). Gerçek cihaz/web doğrulaması YOK.
- Mevcut (bu değişiklikten BAĞIMSIZ, A/B ile doğrulandı — değişikliklerim geri alınmışken de aynı 11 hata) başarısız testler; kök neden analiz edilmedi:
  - `test/core/home_speed_slice_test.dart` — "home does not prefetch every deferred section at startup" (kaynakta `_scheduleIdleCodePrefetch` bulunuyor).
  - `test/theme/app_theme_tokens_test.dart` — "product MaterialApps lock locale to Turkish only" (`kIbulLocale` beklentisi).
  - `test/widgets/responsive_product_grid_test.dart` — mobil/tablet/desktop render testleri `ProviderNotFoundError` (8 istisna) ile düşüyor.
- Ödeme sistemi: dokunulmadı; değişen kod ödeme yoluna girmiyor.
## Sonraki en değerli görev
1. `responsive_product_grid_test` ProviderNotFoundError kök nedeni (gerçek uygulama hatası mı, test kurulumunda eksik Provider mı) + `home_speed_slice` prefetch beklentisi (açılış performansı regresyonu olabilir).
2. Aynı `toLowerCase()` arama kalıbının diğer müşteri ekranlarında taranması (`map_page`/`map_store_filter_helpers` "İ" eksik, `product_search_page`, satıcı ürün araması) — satıcı dosyaları başka oturum bitince.
3. Golden test hataları (`test/screens/failures`); `restaurant-ops-web` için `node_modules` yok → build/typecheck doğrulanamıyor (BLOCKED, kurulum kullanıcı kararı).
4. Commit edilmemiş değişikliklerin kullanıcı tarafından gözden geçirilip commit edilmesi.

## Çalıştırma #6 — 2026-11-18 — yerel Mac, Flutter var
- Son denetlenen uygulama/modül: İBUL E-Ticaret (müşteri) — harita mağaza araması, mağaza sayfası ürün/araç araması, Favoriler › Öneriler grid'i, Run #5'ten kalan 3 başarısız test.
- Ortam: disk 12 GB boş, swap ~9.4/10 GB dolu; aktif build/test süreci yok, son 60 dk'da başka oturum dosya değiştirmemiş. 127 commit edilmemiş dosya korundu. Ağır build başlatılmadı. `claude-flow` MCP bağlanamadı (kullanılmadı).
- Bulunan hata 1 (P2, kullanıcıya görünür): "İ" ile başlayan mağaza/ürün/araç adları küçük harfli aramada bulunamıyordu ("istanbul" → "İstanbul Kebap" yok).
  - Kök neden: Dart `"İ".toLowerCase()` → "i̇" (i + birleştirici nokta). Harita `_normalize` bunu ele almıyordu; mağaza sayfası ürün araması ve `StorefrontCatalog.matchesVehicle` düz `toLowerCase()` kullanıyordu. İki yeni testle önce FAIL olarak yeniden üretildi.
  - Düzeltme: üç yerde mevcut `TextNormalizer.normalize` (yeni altyapı yok).
- Bulunan hata 2 (P2, responsive): Favoriler › Öneriler sekmesi (<800px yolu) sabit 2 kolon kullanıyordu; 600–799px'te (küçük tablet) dev kart, Beğeniler sekmesiyle tutarsız. Düzeltme: Beğeniler ile aynı `ProductGridSizing` helper'ı. Yan etki: <360px'te 1 yerine 2 kolon (Beğeniler ile aynı kart/extent; gerçek cihazda bakılmadı).
- Bulunan hata 3 (P3, geliştirici aracı): `lib/dev/performance_profile_main.dart` `CompareState` provider'ı sağlamıyordu → `ProductCard` render edince ProviderNotFoundError. Provider eklendi (çalıştırılarak doğrulanmadı, yalnızca analyze).
- Run #5'ten kalan testler:
  - `responsive_product_grid_test` (8 hata): kök neden test kurulumunda eksik `CompareState` provider'ı (gerçek uygulamada tüm giriş noktaları `buildCustomerProviders` ile sağlıyor — uygulama hatası DEĞİL). Test düzeltildi; ardından ortaya çıkan 9. hata yukarıdaki Öneriler grid'i gerçek hatasıydı.
  - `app_theme_tokens_test` locale: test eskimiş — locale kilidi `IbulMaterialApp` kabuğuna taşınmış, davranış korunuyor. Test kabuğu + `customer_app`/`full_app`'in kabuğu kullandığını doğrulayacak şekilde güncellendi (kontrol gevşetilmedi).
  - `home_speed_slice_test` "home does not prefetch every deferred section": DOKUNULMADI. `_scheduleIdleCodePrefetch` commit 556697a'da bilinçli eklenmiş (alt bölümlerin boş placeholder kalması düzeltmesi); test ise prefetch'i yasaklıyor. Açılış performansı ↔ boş bölüm çelişkisi; ölçüm (web build) yapılamadan kaldırmak riskli → kullanıcı kararı / ölçüm gerekli.
- Değişen dosyalar:
  - `ibul_app/lib/core/map_store_filter_helpers.dart`
  - `ibul_app/lib/features/seller/storefront/storefront_catalog.dart`
  - `ibul_app/lib/screens/business_detail_page.dart` (`_filteredProducts` getter)
  - `ibul_app/lib/screens/favorites_page.dart` (`_buildRecommendationBody`)
  - `ibul_app/lib/dev/performance_profile_main.dart`
  - Testler: `test/core/map_store_filter_helpers_test.dart` (+1), `test/features/seller/storefront/storefront_copy_test.dart` (+1), `test/widgets/responsive_product_grid_test.dart`, `test/theme/app_theme_tokens_test.dart`
- Testler: map_store_filter_helpers + storefront + responsive_product_grid + app_theme_tokens + features/products + favorites_filters + favorite_browse_card → PASS. `dart analyze` (değişen dosyalar) temiz. Tam `flutter test` çalıştırılmadı (RAM/swap).
- Seviye: Kod tamamlandı / Test geçti (mağaza sayfası araması ve Öneriler grid'i için widget testi yok — yalnızca kaynak/birim testi + analyze). Entegre edilmedi (commit yok). Gerçek cihaz/web doğrulaması YOK.
- Ödeme sistemi: dokunulmadı. `business_detail_page.dart` içindeki sepet/tutar koduna girilmedi; yalnızca arama getter'ı değişti.
- Kanıtlanan ama düzeltilmeyen sorunlar:
  - `test/widgets/product_card_layout_test.dart` 6 hata (bu çalıştırmadan BAĞIMSIZ — `product_card.dart` ve `home/mobile/*` değiştirilmedi): 412/430px mobilde `ProductCard` RenderFlex alttan 8–28px taşıyor; "tümünü gör" kartında action altı boşluk beklentisi ve fiyat sıralama testi düşüyor. Muhtemel gerçek UI taşması.
  - `map_store_filter_helpers.dart`: "Şu an açık" filtresi sahte — `if (filterOpenNow && i % 5 == 0) continue;` (indekse göre her 5. mağazayı gizliyor, çalışma saatine bakmıyor). Yanıltıcı filtre; gerçek çalışma saati verisi gerektirir → tasarım kararı.
  - `spare_parts_page.dart:649-655` aynı `toLowerCase()` kalıbı (cihaz modeli/kategori eşleşmesi) — henüz ele alınmadı.
## Sonraki en değerli görev
1. `product_card_layout_test` 412/430px ProductCard taşması kök nedeni (müşteri ana akışında görünür olabilir).
2. Dengeli ilerleme: son iki çalıştırma müşteri uygulamasındaydı → İHIZ (`ihiz_web` commit edilmemiş `ihiz_delivery_action_gate` / `ihiz_location_poll_policy` regresyon denetimi + testleri) veya satıcı paneli araması (`toLowerCase` kalıbı).
3. Harita "Şu an açık" sahte filtresi için teknik öneri; `home_speed_slice` prefetch çelişkisi için ölçüm.
4. Golden test hataları (`test/screens/failures`); `restaurant-ops-web` `node_modules` yok (BLOCKED).
5. Commit edilmemiş değişikliklerin kullanıcı tarafından gözden geçirilip commit edilmesi.

## Çalıştırma #7 — 2026-11-18 — yerel Mac, Flutter var
- Son denetlenen uygulama/modül: İHIZ (`ihiz_web`) — kurye teslimat durum geçişleri (teslim alma / teslim etme / iptal) + başka oturumun commit edilmemiş `ihiz_delivery_action_gate` / `ihiz_location_poll_policy` entegrasyonunun regresyon denetimi.
- Ortam: disk 12 GB boş; aktif build/test süreci yok; son 90 dk'da yalnızca Run #6 dosyaları değişmiş (ihiz_web en son 17 Kas 22:16). 135 commit edilmemiş dosya korundu. Ağır build yok. `claude-flow` MCP bağlanamadı (kullanılmadı).
- Denetim sonucu (başka oturumun işi): aksiyon kilidi ve konum sorgu politikası mantıken doğru, testleri PASS. Ancak kilit bir yan etki doğurmuş (aşağıdaki hata).
- Bulunan hata (P1, durum bütünlüğü): "Paketi teslim al" sunucuya yazılamadığında (RLS reddi / satır yok / ağ) arayüz iyimser olarak kurduğu aktif teslimatı geri almıyordu → kurye sunucuda hiç başlamamış "hayalet" teslimata kilitleniyor, diğer görevler "Aktif teslimat var" diye kapanıyordu. Yeni eklenen `_hasActiveDelivery` koruması yeniden denemeyi de engellediği için tek çıkış "iptal" idi; iptal ise sunucuda sipariş kalemini `cancelled` yapıyor (hiç teslim alınmamış müşteri siparişi iptal olabilir).
  - Kök neden: `_markOrderAsPickedUp` sonucu döndürmüyor, `_pickupPackage` başarısızlıkta yalnızca SnackBar gösteriyordu.
  - Düzeltme: `_markOrderAsPickedUp` artık `IhizPickupSyncOutcome` döndürüyor. Birincil yazım (order_items) kesin uygulanmadıysa (`notApplied`: güncellenen satır yok, 5xx olmayan PostgREST reddi veya ağ hatası sonrası doğrulama okumasında durum değişmemiş) mevcut `_resetDeliveryFlow()` ile yerel durum geri alınıyor ve görev havuza dönüyor. Yazım uygulanmış ama yan adım (geçmiş/bildirim) düşmüşse teslimat korunuyor (eski davranış). Doğrulanamayan ağ hatasında (`unverified`) teslimat bilinçli olarak korunuyor (geri almak paketi sunucuda sahipsiz "yolda" bırakabilir) ve kurye uyarılıyor.
- Değişen dosyalar:
  - `ihiz_web/lib/main.dart` (`_pickupPackage`, `_markOrderAsPickedUp`)
  - `ihiz_web/lib/src/util/ihiz_pickup_sync_outcome.dart` (yeni, saf karar fonksiyonu)
  - `ihiz_web/test/util/ihiz_pickup_sync_outcome_test.dart` (yeni, 6 test)
- Testler: `flutter test` (ihiz_web) → util testleri 14 PASS (6 yeni + 8 mevcut). `dart analyze lib/main.dart` + util + test/util temiz.
  - Mevcut ve BAĞIMSIZ hata: `ihiz_web/test/widget_test.dart` VM'de derlenmiyor (`ihiz_web_location.dart` koşulsuz `dart:html` kullanıyor; dosya 14 Kas'tan beri değişmedi). `--platform chrome` ile çalıştırılmadı (RAM).
- Seviye: Kod tamamlandı / Test geçti (yalnızca karar fonksiyonu birim testi; `_pickupPackage` geri alma yolu için widget/entegrasyon testi YOK — 15.9k satırlık State içinde, Supabase mock altyapısı yok). Entegre edilmedi (commit yok). Gerçek kurye/cihaz/sunucu doğrulaması YOK; canlı teslimat verisine dokunulmadı.
- Ödeme sistemi: dokunulmadı (aşağıdaki cüzdan bulgusu yalnızca rapor).
- Kanıtlanan ama düzeltilmeyen sorunlar (kod okumasıyla; çalıştırılarak yeniden üretilmedi):
  - ÖDEME (yalnızca rapor): teslim almada `wallet_capture_seller_delivery_by_reference` RPC'sine `p_idempotency_key: 'capture-<orderItemId>-<microsecondsSinceEpoch>'` gönderiliyor → anahtar her çağrıda farklı, idempotency sağlamıyor. Sunucu `p_reference_id` ile tekilleştirmiyorsa tekrarlanan teslim alma çift tahsilat üretebilir. RPC gövdesi incelenmedi.
  - P1 (teknik öneri gerekir): teslim alma/teslim/iptal güncellemeleri yalnızca `.eq('id', orderItemId)` ile yapılıyor; durum ön koşulu ve kurye sahipliği yok. İki kurye aynı `ready_to_ship` kalemini aynı anda teslim alabilir; herhangi bir kurye başka kuryenin kalemini `delivered`/`cancelled` yapabilir (RLS ne kadar izin veriyorsa). Çözüm sunucu tarafı atomik "claim" RPC'si veya `.eq('status', 'ready_to_ship')` koşullu güncelleme + atanan kurye sütunu → veri sözleşmesi değişikliği, otomatik uygulanmadı.
  - P2: kurye iptali müşteri sipariş kalemini doğrudan `cancelled` yapıyor (yeniden havuza `ready_to_ship` döndürmüyor) — ürün kararı.
  - P3: `Sipariş havuzu güncellenemedi: $error` ham hata metnini kuryeye gösteriyor (bilgi sızıntısı); İHIZ metinlerinde ASCII/Türkçe karışık ("dogrulandi", "yazilamadi").
  - `ihiz_web/lib/main.dart` 15.9k satır (500 satır kuralının çok üstünde) — büyük refactor, önerilmez/otomatik yapılmadı.
## Sonraki en değerli görev
1. Dengeli ilerleme → İBUL Satıcı: satıcı paneli aramalarında `toLowerCase()` Türkçe kalıbı (ürünlerim / masa geçmişi) veya `product_card_layout_test` 412/430px ProductCard taşması (müşteri).
2. İHIZ: kurye "claim" yarışı için teknik öneri dokümanı (kullanıcı onayıyla); `ihiz_web_location.dart` için koşullu import ile `widget_test.dart`'ı VM'de derlenebilir yapmak (düşük risk).
3. Harita "Şu an açık" sahte filtresi teknik önerisi; `home_speed_slice` prefetch ölçümü; golden test hataları; `restaurant-ops-web` `node_modules` yok (BLOCKED).
4. Commit edilmemiş değişikliklerin kullanıcı tarafından gözden geçirilip commit edilmesi.

## Çalıştırma #8 — 2026-11-18 (03:14 +03) — yerel Mac, Flutter var
- Son denetlenen uygulama/modül: İBUL Satıcı — panel aramaları (Ürünlerim, Siparişler, Geri Bildirim, Garson ürün seçimi, Personel listesi, Kampanya ürün seçimi) + personel filtre açılır kutusu.
- Ortam: disk 12 GB boş; aktif build/test süreci yok; son 90 dk'da yalnızca Run #7 dosyaları değişmiş. 136 commit edilmemiş dosya korundu. Ağır build yok. `claude-flow` MCP bağlanamadı (kullanılmadı). Başka oturuma ait `fake_printer.py` süreci çalışıyordu — dokunulmadı.
- Bulunan hata 1 (P2, kullanıcıya görünür): Türkçe klavyeyle yazılan "ı" içeren aramalar büyük "I" ile yazılmış adları bulamıyordu ("ızgara" → "Izgara"/"IZGARA" yok, "ışık" → "Işık" yok). Garson ürün aramasında menüde doğrudan hissedilir.
  - Kök neden: düz `toLowerCase()`; Dart "I" → "i" yapar ("ı" değil). Widget testiyle A/B doğrulandı (düzeltme geri alınınca FAIL, uygulanınca PASS).
  - Düzeltme: 7 arama noktasında mevcut `TextNormalizer.normalize` (yeni altyapı yok). Yan etki (istenen): aksan duyarsız eşleşme ("cagla" → "Çağla").
  - KAYIT DÜZELTMESİ (Run #5/#6): o raporlarda "Dart `İ.toLowerCase()` → i + birleştirici nokta" yazıldı. Bu çalıştırmada ölçüldü: Dart VM'de (mobil/masaüstü/test) "İ" → düz "i" olur; birleştirici nokta JS çalışma zamanının (Flutter Web) davranışıdır ve bu çalıştırmada web'de doğrulanmadı. VM'de kesin olan hata "I/ı" eşleşmesidir. Yapılan düzeltmeler her iki durumu da kapsıyor; geri alınacak bir şey yok.
- Bulunan hata 2 (P2, UI taşması): Personel listesi "Görev"/"Şube" filtre açılır kutusu (180px) `isExpanded` olmadan en uzun seçeneğe göre genişliyordu; uzun görev/şube adında (sahibin girdiği serbest metin) RenderFlex taşması. Testte 5.2px taşma olarak yakalandı (test fontu daha geniş; gerçek fontta kısa adlarda görünmeyebilir). Düzeltme: `isExpanded: true` + seçenek metninde ellipsis.
- Değişen dosyalar:
  - `ibul_app/lib/screens/seller_panel_page.dart` (yalnızca arama eşleşmesi: `_productsMatchingSearch`, `_getFilteredSellerOrders`, `_filterFeedbackItems`, garson `_buildProductsTab`; + import)
  - `ibul_app/lib/features/seller/staff/staff_team_panel.dart` (`_visible`, `_filter`)
  - `ibul_app/lib/screens/seller/campaign_form_dialog.dart` (ürün arama)
  - `ibul_app/test/features/staff_team_panel_search_test.dart` (yeni, 2 test)
- Testler: yeni test 2 PASS. `dart analyze` (3 dosya + test): yeni sorun yok (seller_panel_page'de mevcut 4 uyarı/info, aşağıda). `flutter test test/features/seller` + staff/garson seçili testler: 370 PASS / 10 FAIL — 10 hatanın hiçbiri arama koduna dokunmuyor (aşağıda; bu 10 hata için ayrı A/B yapılmadı, hata nedenleri okunarak ayrıldı).
- Seviye: Kod tamamlandı / Test geçti (yalnızca personel paneli widget testi; `seller_panel_page` içindeki 4 arama ve kampanya dialogu için test YOK — özel State metodları, yalnızca analyze). Entegre edilmedi (commit yok). Gerçek cihaz/masaüstü doğrulaması YOK.
- Ödeme sistemi: dokunulmadı; sipariş araması yalnızca listeleme filtresi, tutar/ödeme koduna girilmedi.
- Kanıtlanan ama düzeltilmeyen sorunlar:
  - P1 GÜVENLİK (test ile kanıtlı, `test/security/staff_permission_matrix_test.dart` "no-permission non-waiter staff must not receive garson fallback" FAIL): `seller_panel_module_helpers.dart` `modulesForStaff` — hiç yetkisi olmayan ve garson olmayan personele `if (filtered.isEmpty) return [SellerModule.garson]` ile Garson modülü açılıyor (mağaza restoran olmasa bile). İstemci menü seviyesi; sunucu RLS/RPC ayrıca incelenmedi. Otomatik DÜZELTİLMEDİ: satır kaldırılırsa "boş menü" durumu oluşuyor ve çağıranlar (`allowed.isNotEmpty` koşulları) bu durumda reddedilen modülden yönlendirme yapmıyor → çalıştırılarak doğrulanamayan yeni durum; ayrıca test başka oturumun devam eden işine ait. Öneri: satırı kaldır + boş menü için açık "yetkiniz yok" ekranı + testleri birlikte.
  - `seller_panel_navigation_grep_test`: `seller_panel_page.dart:1860` doğrudan `_selectedModule = SellerModule.garson;` (başka oturumun `_seedOfflineTestGarsonBoard` eklemesi). Aynı bölgede `@override` yanlış metoda kaymış (analyzer: 1826 `override_on_non_overriding_member`, 1857 `initState` `@override` eksik) — işlevsel etkisi yok, başka oturumun bölgesi olduğu için dokunulmadı.
  - `seller_panel_owner_id_resolution_grep_test`: kaynakta `_storeService.resolveStoreOwnerIdForCurrentUser()` beklentisi karşılanmıyor (kök neden incelenmedi).
  - `seller_logout_helper_test` 7 hata: test kendi `MaterialApp`'inde `home` + `routes['/']` birlikte veriyor (assert) — test kurulum hatası gibi; incelenmedi.
  - Run #6/#7'den devreden: `product_card_layout_test` taşması, harita "Şu an açık" sahte filtresi, İHIZ claim yarışı ve cüzdan idempotency anahtarı (yalnızca rapor), `spare_parts_page` `toLowerCase` kalıbı.
## Sonraki en değerli görev
1. P1: personel "garson fallback" — kullanıcı onayı/başka oturumla eşgüdüm sonrası boş menü ekranıyla birlikte düzeltme.
2. Dengeli ilerleme → İBUL E-Ticaret: `product_card_layout_test` 412/430px ProductCard taşması; ardından İHIZ `ihiz_web_location.dart` koşullu import.
3. `seller_logout_helper_test` ve `seller_panel_owner_id_resolution_grep_test` kök nedeni.
4. Commit edilmemiş değişikliklerin kullanıcı tarafından gözden geçirilip commit edilmesi.

## Çalıştırma #9 — 2026-11-18 (04:14 +03) — yerel Mac, Flutter var
- Son denetlenen uygulama/modül: İBUL E-Ticaret (müşteri) — mobil ana sayfa ürün rail'i + "Tümünü gör" grid'i (`ProductCard(homeRail: true)`).
- Ortam: disk 13 GB boş, swap ~9.1/10 GB dolu; aktif build yok; son 90 dk'da yalnızca Run #8 dosyaları değişmiş. 139 commit edilmemiş dosya korundu. Ağır build yok. `claude-flow` MCP bağlanamadı (kullanılmadı). Run #8'den kalmış görünen bir `flutter_tester` süreci (03:18 başlangıçlı) ve başka oturumun `fake_printer.py` süreci çalışıyordu — dokunulmadı.
- Bulunan hata (P2, kullanıcıya görünür UI taşması — Run #6'dan devreden `product_card_layout_test` 6 hatası):
  - Belirti: mobil ana sayfa rail'inde (sabit 312px) ürün kartı, kart genişliği arttıkça alttan taşıyordu. Yeni testle gerçek `MobileProductRail` üzerinde 390/393/430px'te taşma, 360px'te yükseklik sapması yeniden üretildi (düzeltmesiz 4/4 FAIL). "Tümünü gör" grid'inde 390px'te 8px, 430px'te 28px taşma (sepete ekle butonunun altı hücre dışında kalıyor/kırpılıyor); 360px'te ise kart hücreden 7px kısa.
  - Kök neden: `_buildNormalImageSection` görseli her zaman `AspectRatio(1.0)` ile sarıyordu; bu, home-rail için verilen sabit `homeRailImageHeight` (156) değerini kart genişliğiyle eziyordu. Rail yüksekliği ve grid `mainAxisExtent` (`homeRailCardHeight`) ise 156'ya göre hesaplanıyor → geniş telefonda kart hücreden uzun.
  - Düzeltme: `homeRail` + `imageHeight` verildiğinde görsel `SizedBox(height: imageHeight)` ile sarılıyor; diğer tüm yollar (web/masaüstü/tight/compact/fill) aynen `AspectRatio(1.0)`.
  - Görsel etki (bilinçli): geniş telefonlarda home-rail görseli kare yerine 156px yüksekliğinde yatay dikdörtgen (ör. 430px'te ~186×156). Ürünlerde `BoxFit.contain`, yemekte `cover`. Gerçek cihazda bakılmadı.
- Değişen dosyalar:
  - `ibul_app/lib/widgets/product_card.dart` (`_buildNormalImageSection` dönüşü)
  - `ibul_app/test/widgets/product_card_layout_test.dart` (+4 test: gerçek `MobileProductRail` 360/390/393/430)
- Testler: `product_card_layout_test` 22 PASS / 0 FAIL (önce 12 PASS / 6 FAIL). A/B: düzeltme devre dışıyken 10 FAIL (6 eski + 4 yeni), geri açınca 22 PASS. `dart analyze` (2 dosya) temiz. ProductCard/ana sayfa ile ilgili 11 test dosyası: 98 PASS / 2 FAIL — ikisi de bu değişiklikten bağımsız kaynak-grep testi:
  - `home_speed_slice_test` prefetch (Run #6'da açıklandı, kullanıcı kararı bekliyor).
  - `home_ui_no_demo_test` "non-empty body sections": `home_screen_core.dart` içinde `IbulOpportunityShortcutsSection` metni bekleniyor, yok (kök neden incelenmedi; bu dosyaya dokunulmadı).
  - Tam `flutter test` çalıştırılmadı (RAM/swap).
- Seviye: Kod tamamlandı / Test geçti (widget testi, A/B'li). Entegre edilmedi (commit yok). Gerçek cihaz doğrulaması YOK.
- Ödeme sistemi: dokunulmadı (yalnızca kart görsel sarmalayıcısı).
- Kanıtlanan ama düzeltilmeyen (devreden): P1 personel "garson fallback" (Run #8), İHIZ claim yarışı + cüzdan idempotency anahtarı (yalnızca rapor, Run #7), harita "Şu an açık" sahte filtresi, `spare_parts_page` `toLowerCase`, `seller_logout_helper_test`, `seller_panel_owner_id_resolution_grep_test`, `seller_panel_page.dart` yanlış yere kaymış `@override`.
## Sonraki en değerli görev
1. P1: personel "garson fallback" — kullanıcı onayı sonrası boş menü ekranıyla birlikte düzeltme.
2. Dengeli ilerleme → İHIZ: `ihiz_web_location.dart` koşullu import (`widget_test.dart` VM'de derlensin) + ham hata metni/ASCII Türkçe metin temizliği.
3. İBUL Satıcı: `seller_logout_helper_test` ve `seller_panel_owner_id_resolution_grep_test` kök nedeni. Müşteri: `home_ui_no_demo_test` `IbulOpportunityShortcutsSection` beklentisi, `spare_parts_page` araması.
4. Commit edilmemiş değişikliklerin kullanıcı tarafından gözden geçirilip commit edilmesi.

## Çalıştırma #10 — 2026-11-18 — yerel Mac, Flutter var
- Son denetlenen uygulama/modül: İHIZ (`ihiz_web`) — kuryeye gösterilen hata mesajları (teslim alma / teslim etme / iptal / destek / canlı sohbet), konum durum metinleri, `IhizWebLocation` test derlenebilirliği.
- Ortam: disk 13 GB boş; aktif build yok; son 90 dk'da yalnızca Run #9 dosyaları değişmiş. 141 commit edilmemiş dosya korundu. Ağır build yok. `claude-flow` MCP bağlanamadı (kullanılmadı). Eski `flutter_tester` (03:18) ve başka oturumun `fake_printer.py` süreci çalışıyordu — dokunulmadı.
- Bulunan hata 1 (P2, bilgi sızıntısı + kullanılabilirlik — Run #7'den devreden P3 notu, kapsamı büyütüldü): kuryeye ham sunucu hatası gösteriliyordu.
  - Kanıt (kod): `_deliverySyncFailureHint` kuryeye "Kurye hesabının order_items UPDATE yetkisi yok. RLS courier policy eksik." ve `Teknik hata: <ham PostgREST metni, 180 karakter>` (tablo/kısıt adı, satır içeriği) gösteriyordu; 3 SnackBar doğrudan `$error` basıyordu (teslim alma yan adımı, destek bildirimi, canlı sohbet).
  - Düzeltme: yeni saf fonksiyon `ihizCourierSyncFailureHint` — yetki / bağlantı / eksik sipariş bilgisi / beklenmeyen hata olarak sınıflar; kuryeye yalnızca anlaşılır Türkçe metin + varsa kısa SQLSTATE kodu ("Hata kodu: 42501") gösterir. Ham ayrıntı `debugPrint` loglarında kalıyor (destek/sohbet/teslim alma yan adımı için log satırı eklendi). Sınıflama eski mantığın üst kümesi (ek: `jwt`, `failed to fetch`, `xmlhttprequest`, `connection`).
  - Davranış notu: geliştirme sırasında RLS teşhisi artık SnackBar'dan değil konsol logundan + hata kodundan yapılır.
- Bulunan hata 2 (P3, Türkçe metin tutarlılığı): kuryeye görünen ASCII yazılmış metinler düzeltildi ("Kod dogrulandi ancak teslim durumu yazilamadi", "Lutfen 4 haneli kod girin", "Canli magazaya ait konum bulunamadi", "... bolgesine teslim edilecek", konum izin/hata durumlarının tamamı: "Tarayici konum izni reddedildi", "Konum alinamadi" vb.). Bu metinlerle karşılaştırma yapan kod yok (grep ile doğrulandı).
- Bulunan hata 3 (P3, test altyapısı — Run #7'den devreden): `ihiz_web_location.dart` koşulsuz `dart:html` kullandığı için `main.dart`'ı içe aktaran hiçbir test VM'de derlenmiyordu.
  - Düzeltme: koşullu export. `ihiz_web_location.dart` (cephe) → web'de `ihiz_web_location_web.dart` (eski içerik, değişmedi), VM'de `ihiz_web_location_stub.dart`. Koşul `dart.library.js_interop` (wasm'da sessizce stub'a düşmesin diye `dart.library.html` kullanılmadı).
  - Doğrulama: `dart compile js` ile küçük bir deneme girişinde web sürümünün seçildiği (çıktıda `pushState`) ve VM'de stub'ın seçildiği doğrulandı. Tam `flutter build web` çalıştırılmadı (RAM/disk).
  - `test/widget_test.dart` artık DERLENİYOR ama hâlâ FAIL: (a) test Supabase'i başlatmıyor (`Supabase.instance` assert), (b) beklenen metinler ("İhız", "İhız ile mağazadan al, müşteriye hızla teslim et.") kaynakta yok — test eskimiş. Düzeltilmedi (Supabase test kurulumu gerekir).
- Değişen dosyalar:
  - `ihiz_web/lib/main.dart` (import; `_deliverySyncFailureHint` gövdesi; 3 SnackBar; 2 dahili hata işareti; kullanıcı metinleri)
  - `ihiz_web/lib/src/util/ihiz_courier_error_text.dart` (yeni)
  - `ihiz_web/lib/src/util/ihiz_web_location.dart` (cephe), `ihiz_web_location_web.dart` (eski dosyanın taşınmış hali — git'te eski yol "değişmiş", yeni yol izlenmiyor), `ihiz_web_location_stub.dart` (yeni)
  - `ihiz_web/test/util/ihiz_courier_error_text_test.dart` (yeni, 6 test)
- Testler: `flutter test test/util` (ihiz_web) → 20 PASS / 0 FAIL (6 yeni + 14 mevcut). `dart analyze lib/main.dart lib/src/util test` temiz. `test/widget_test.dart` FAIL (yukarıda, mevcut/bağımsız neden).
- Seviye: Kod tamamlandı / Test geçti (yalnızca sınıflama fonksiyonu birim testi; SnackBar çağrı noktaları ve metin değişiklikleri için widget testi YOK — yalnızca analyze). Entegre edilmedi (commit yok). Gerçek tarayıcı/kurye doğrulaması YOK; canlı veriye dokunulmadı.
- Ödeme sistemi: dokunulmadı. `Kazanç talebi gönderilemedi: $error` (main.dart, ödeme talebi akışı) aynı ham hata sızıntısını taşıyor — ödeme alanı olduğu için yalnızca rapor.
- Kanıtlanan ama düzeltilmeyen:
  - Admin ekranlarında ham hata + ASCII metin (`Versiyon kaydi okunamadi ... Hata: $error`, `Kayit basarisiz: $error`, `Ayarlar kaydedilemedi: $error`) — yalnızca yönetici görür, teşhis değeri var; dokunulmadı.
  - Devreden: P1 personel "garson fallback" (Run #8), İHIZ claim yarışı + cüzdan idempotency anahtarı (yalnızca rapor, Run #7), harita "Şu an açık" sahte filtresi, `spare_parts_page` `toLowerCase`, `seller_logout_helper_test`, `seller_panel_owner_id_resolution_grep_test`, `home_ui_no_demo_test`, `home_speed_slice` prefetch kararı.
## Sonraki en değerli görev
1. P1: personel "garson fallback" — kullanıcı onayı sonrası boş menü ekranıyla birlikte düzeltme.
2. Dengeli ilerleme → İBUL Satıcı: `seller_logout_helper_test` (7 hata) ve `seller_panel_owner_id_resolution_grep_test` kök nedeni.
3. İHIZ: `widget_test.dart` için Supabase test kurulumu + güncel metin beklentileri; kurye "claim" yarışı teknik önerisi.
4. Müşteri: `home_ui_no_demo_test` `IbulOpportunityShortcutsSection` beklentisi, `spare_parts_page` araması.
5. Commit edilmemiş değişikliklerin kullanıcı tarafından gözden geçirilip commit edilmesi.

## Çalıştırma #11 — 2026-11-18 (06:14 +03) — yerel Mac, Flutter var
- Son denetlenen uygulama/modül: İBUL Satıcı — satıcı paneli test kümesi (çıkış akışı, sahip kimliği çözümü, modül gezinme koruması); ek olarak müşteri `spare_parts_page` araması.
- Ortam: disk 12 GB boş; aktif build yok; son 120 dk'da yalnızca Run #9/#10 dosyaları değişmiş (başka oturum etkinliği yok). 145 commit edilmemiş dosya korundu. Ağır build yok. `claude-flow` MCP bağlanamadı (kullanılmadı). Eski `flutter_tester` ve başka oturumun `fake_printer.py` süreci çalışıyordu — dokunulmadı.
- Run #8'den devreden 3 başarısız satıcı testi — kök nedenler (üçünde de uygulama davranışı doğru):
  1. `seller_logout_helper_test` (7 hata, P3 test altyapısı): `HomeNavigation.routeName` go_router geçişinde `'/'` olmuş; test `MaterialApp`'e hem `home:` hem `routes['/']` veriyordu → Flutter assert. Çıkış kodu (`SellerLogoutGuard`) doğru. Düzeltme yalnızca test: panel başlangıç ekranı `onGenerateInitialRoutes` ile veriliyor, `'/'` ana sayfa rotası olarak kalıyor. Beklentiler değişmedi/gevşetilmedi. Not: dosyaya `dart format` uygulandı → diff büyük görünüyor (145+/125−), mantık değişikliği yalnızca 7 `MaterialApp` kurulumunda.
  2. `seller_panel_owner_id_resolution_grep_test` (1 hata, P3): kaynak-grep testi tek satır `_storeService.resolveStoreOwnerIdForCurrentUser()` arıyordu; biçimlendirici çağrıyı iki satıra bölmüş. Çağrı yerinde (`_ensureSellerDataOwnerIdResolved`). Test boşluktan bağımsız RegExp'e çevrildi.
  3. `seller_panel_navigation_grep_test` (1 hata, P3 kod hijyeni): `initState` içinde `IBUL_OFFLINE_TEST` yolunda doğrudan `_selectedModule = SellerModule.garson;` yazımı vardı; ayrıca `@override` `initState` yerine `_seedOfflineTestGarsonBoard` üstüne kaymıştı. Düzeltme: `_applySelectedModuleState(SellerModule.garson)` (aynı davranış, merkezi yazım) + `@override` doğru metoda taşındı. Yalnızca geliştirici bayrağı yolunu etkiler; analyzer'daki 2 tanı (override_on_non_overriding_member, eksik @override) kapandı.
- Bulunan hata (P3, müşteri — Run #6'dan devreden): `spare_parts_page.dart` cihaz modeli/kategori eşleşmesi düz `toLowerCase()` kullanıyordu (Türkçe I/ı; web'de İ). Mevcut `TextNormalizer.normalize` ile değiştirildi. Bu değişiklik için test YOK (özel State metodu) — yalnızca analyze.
- Değişen dosyalar:
  - `ibul_app/lib/screens/seller_panel_page.dart` (`initState` başı + `_seedOfflineTestGarsonBoard` annotasyonu)
  - `ibul_app/lib/screens/spare_parts_page.dart` (yedek parça filtresi + import)
  - `ibul_app/test/features/seller/panel/seller_logout_helper_test.dart`
  - `ibul_app/test/features/seller/panel/seller_panel_owner_id_resolution_grep_test.dart`
- Testler: `flutter test test/features/seller/panel` → 196 PASS / 0 FAIL (önce 9 FAIL). `test/features/seller` + `test/security` + `staff_gate_permissions`: tek kalan hata aşağıdaki garson fallback testi. `dart analyze seller_panel_page.dart`: 2 mevcut uyarı/info (15029 kullanılmayan parametre, 12420 süslü parantez), yeni sorun yok; `spare_parts_page.dart` temiz. Tam `flutter test` çalıştırılmadı (RAM).
- Seviye: Kod tamamlandı / Test geçti (satıcı paneli testleri). `spare_parts_page`: Kod tamamlandı, test yok. Entegre edilmedi (commit yok). Gerçek cihaz doğrulaması YOK.
- Ödeme sistemi: dokunulmadı.
- P1 "garson fallback" için yeni kanıt (hâlâ DÜZELTİLMEDİ — karar çelişkisi):
  - Commit edilmiş `test/services/staff_menu_gate_test.dart` "sub-admin with no permissions still has the floor fallback" bu davranışı BİLİNÇLİ olarak bekliyor; commit edilmemiş `test/security/staff_permission_matrix_test.dart` ise tersini (boş liste) istiyor. İki test aynı anda geçemez → ürün/güvenlik kararı kullanıcıda.
  - Kesin kusur (karardan bağımsız): fallback, katalogda Garson modülü olmasa bile (restoran olmayan mağaza) `[SellerModule.garson]` döndürüyor. En dar öneri: fallback'i yalnızca katalogda garson varsa uygula; tam çözüm: fallback'i kaldır + boş menü için "Yetkiniz yok" ekranı + iki testi birlikte güncelle.
- Kanıtlanan ama düzeltilmeyen (devreden): İHIZ claim yarışı + cüzdan idempotency anahtarı (yalnızca rapor, Run #7), harita "Şu an açık" sahte filtresi, `home_ui_no_demo_test`, `home_speed_slice` prefetch kararı, İHIZ `widget_test.dart` Supabase kurulumu.
## Sonraki en değerli görev
1. P1: personel "garson fallback" — kullanıcı kararı (yukarıdaki iki seçenek).
2. Dengeli ilerleme → İHIZ: `widget_test.dart` Supabase test kurulumu + güncel metinler; kurye "claim" yarışı teknik önerisi.
3. Müşteri: `home_ui_no_demo_test` `IbulOpportunityShortcutsSection` kök nedeni; harita "Şu an açık" filtresi önerisi.
4. Satıcı: `local_print_bridge` pytest regresyonu (uzun süredir çalıştırılmadı); golden test hataları (`test/screens/failures`).
5. Commit edilmemiş değişikliklerin kullanıcı tarafından gözden geçirilip commit edilmesi.

## Çalıştırma #12 — 2026-11-18 (07:14 +03) — yerel Mac, Flutter var
- Son denetlenen uygulama/modül: İHIZ (`ihiz_web`) — kurye "Paketi teslim al" (claim) yarışı (Run #7'den devreden P1).
- Ortam: disk 12 GB boş; aktif build yok; son 150 dk'da yalnızca Run #10/#11 dosyaları değişmiş (başka oturum etkinliği yok). 148 commit edilmemiş dosya korundu. Ağır build yok. `claude-flow` MCP bağlanamadı (kullanılmadı). Eski `flutter_tester` ve başka oturumun `fake_printer.py` süreci çalışıyordu — dokunulmadı.
- Bulunan hata (P1, mükerrer teslimat — kod okumasıyla kanıtlı; iki kuryeyle çalıştırılarak yeniden üretilmedi): normal (iade olmayan) teslim alma güncellemesi yalnızca `.eq('id', orderItemId)` ile yapılıyordu. İki kurye aynı `ready_to_ship` paketi aynı anda aldığında ikisinin de yazımı başarılı oluyor, ikisi de aktif teslimata geçiyor, müşteriye iki "kurye teslim aldı" bildirimi + iki geçmiş kaydı gidiyordu; ayrıca havuz listesi eskiyken satıcının/müşterinin durumunu değiştirdiği (ör. iptal) siparişin üzerine `out_for_delivery` yazılabiliyordu.
  - Kök neden: güncellemede durum ön koşulu yok.
  - Düzeltme (şema/veri sözleşmesi değişikliği YOK, yalnızca istemci sorgusu): güncellemeye `.eq('status', 'ready_to_ship')` eklendi → Postgres satır kilidi sayesinde yalnızca ilk kurye kazanır, ikincinin güncellemesi 0 satır döner. 0 satırda güncel durum okunur: durum değişmişse kuryeye "Bu paket artık teslim alınamıyor. Bu paket başka bir kurye tarafından alınmış veya sipariş durumu değişmiş olabilir. Görev listesi yenilendi." gösterilir (eskiden yanlış "yetkiniz yok" ipucu çıkardı); durum hâlâ `ready_to_ship` ise/okunamıyorsa eski yetki-reddi yolu aynen çalışır. Her iki durumda Run #7'nin geri alma mekanizması (`notApplied` → `_resetDeliveryFlow` + havuz yenileme) devreye girer.
  - Güvenlik analizi: teslim alınabilir normal görevler yalnızca `status IN ('ready_to_ship')` havuz sorgusundan gelir; geri yüklenen aktif teslimatta aşama hiç `idle` olmadığından `_pickupPackage` yeniden yazım yapmaz → ön koşul meşru bir teslim almayı engellemez. Yanıt kaybolan ama uygulanmış yazım ağ-hatası yolundan doğrulama okumasıyla `committed` sayılmaya devam eder.
  - Kapsam dışı bırakılan (bilinçli): iade teslim alma yolu. İade görevleri bildirim kaynaklı sinyalle `return_shipped_back` durumundayken de listelenebiliyor; ön koşul eklemek yerel durumunu kaybetmiş kuryenin iadeye devam etmesini engelleyebilir → dokunulmadı.
  - Kalan risk: ön koşul yalnızca istemcide; RLS izin veriyorsa değiştirilmiş istemci hâlâ koşulsuz yazabilir. Teslim etme / iptal güncellemelerinde kurye sahipliği kontrolü hâlâ yok (atanan kurye sütunu gerekir → veri sözleşmesi, kullanıcı kararı).
- Değişen dosyalar:
  - `ihiz_web/lib/main.dart` (`_markOrderAsPickedUp` normal yol + `_pickupPackage` SnackBar metni)
  - `ihiz_web/lib/src/util/ihiz_pickup_sync_outcome.dart` (`ihizPickupReadyStatus`, `isPickupLostToStatusChange`)
  - `ihiz_web/lib/src/util/ihiz_courier_error_text.dart` (`ihizPickupNoLongerAvailableSyncError` + metin)
  - `ihiz_web/test/util/ihiz_pickup_sync_outcome_test.dart` (+2), `ihiz_web/test/util/ihiz_courier_error_text_test.dart` (+1)
- Testler: `flutter test test/util` (ihiz_web) → 23 PASS / 0 FAIL (3 yeni + 20 mevcut). `dart analyze lib/main.dart lib/src/util test/util` temiz. `test/widget_test.dart` çalıştırılmadı (Run #10'da açıklanan mevcut/bağımsız FAIL).
- Seviye: Kod tamamlandı / Test geçti (yalnızca saf karar fonksiyonları; koşullu güncellemenin kendisi için entegrasyon testi YOK — Supabase mock altyapısı yok). Entegre edilmedi (commit yok). Gerçek sunucu/iki kurye doğrulaması YOK; canlı veriye dokunulmadı.
- Ödeme sistemi: dokunulmadı. Olumlu yan etki: yarışı kaybeden kurye artık `wallet_capture_seller_delivery_by_reference` çağrısına ulaşmıyor (ilk yazım başarısız olunca akış kesiliyor); Run #7'deki idempotency anahtarı bulgusu aynen duruyor (yalnızca rapor).
- Kanıtlanan ama düzeltilmeyen (devreden): P1 personel "garson fallback" kararı (Run #8/#11), İHIZ teslim/iptal kurye sahipliği + cüzdan idempotency anahtarı, kurye iptalinin kalemi `cancelled` yapması, harita "Şu an açık" sahte filtresi, `home_ui_no_demo_test`, `home_speed_slice` prefetch kararı, İHIZ `widget_test.dart` Supabase kurulumu.
## Sonraki en değerli görev
1. P1: personel "garson fallback" — kullanıcı kararı (Run #11'deki iki seçenek).
2. Dengeli ilerleme → İBUL E-Ticaret: `home_ui_no_demo_test` `IbulOpportunityShortcutsSection` kök nedeni; harita "Şu an açık" filtresi önerisi.
3. Satıcı: `local_print_bridge` pytest regresyonu (uzun süredir çalıştırılmadı); golden test hataları (`test/screens/failures`).
4. İHIZ: teslim etme (`_markOrderDelivered`) için aynı tür durum ön koşulu incelemesi (mükerrer "teslim edildi" yazımı); `widget_test.dart` Supabase kurulumu.
5. Commit edilmemiş değişikliklerin kullanıcı tarafından gözden geçirilip commit edilmesi.

## Çalıştırma #13 — 2026-11-18 (08:14 +03) — yerel Mac, Flutter var
- Son denetlenen uygulama/modül: İBUL E-Ticaret (müşteri) — harita "Sadece Açık Olanlar" filtresi (Run #6'dan devreden) + `home_ui_no_demo_test`.
- Ortam: disk 12 GB boş; aktif build yok; son 120 dk'da yalnızca Run #11/#12 dosyaları değişmiş (başka oturum etkinliği yok). 148 commit edilmemiş dosya korundu. Ağır build yok. `claude-flow` MCP bağlanamadı (kullanılmadı). Eski `flutter_tester` ve başka oturumun `fake_printer.py` süreci çalışıyordu — dokunulmadı.
- Bulunan hata (P2, yanıltıcı gösterge/filtre): haritadaki "Sadece Açık Olanlar" anahtarı sahteydi — `if (filterOpenNow && i % 5 == 0) continue;` ile liste indeksine göre her 5. mağazayı gizliyor, mağazanın açık/kapalı durumuna hiç bakmıyordu (açık mağaza gizlenebiliyor, kapalı mağaza "açık" diye listeleniyordu).
  - Kök neden: yer tutucu kod; harita sorgusu `is_store_open` / `working_hours` sütunlarını hiç çekmiyordu. Oysa `stores` tablosunda ikisi de var ve satıcı panelinden yönetiliyor (Mağaza açık anahtarı; Çalışma Saatleri: "09:00 - 18:00" / "10:00 - 19:00" / "24 Saat").
  - Düzeltme (şema/veri sözleşmesi değişikliği YOK, yalnızca okuma):
    - `mapStoreSelectBase`'e `working_hours, is_store_open` eklendi. Sütun eksikse mevcut "eksik sütun → `mapStoreSelectMinimal`" geri düşüşü aynen çalışır (minimal seçim değiştirilmedi); o durumda açıklık "bilinmiyor" olur.
    - `MapStoreMarker.toBusinessRecord` iki alanı kayda taşıyor.
    - Yeni saf fonksiyon `resolveMapStoreOpenNow` (bool?): `is_store_open == false` → kapalı; "24 Saat"/"7/24" → açık; saat aralığı mevcut `mallHoursPresentation` ayrıştırıcısıyla (yeni ayrıştırıcı yazılmadı; gece yarısını aşan aralık destekli) cihaz saatine göre; veri yok/çözülemedi → null.
    - `filterMapStoreIndices`: `isOpenNowAt` geri çağrısı; filtre yalnızca kapalı olduğu BİLİNEN mağazaları gizler (bilinmeyenler listede kalır — bilinçli tercih).
    - Filtre sonucu boşsa artık "Filtreye uygun mağaza bulunamadı." (eskiden yalnızca açık filtresi etkinken "Gösterilecek mağaza bulunamadı." çıkıyordu).
  - Sınırlar: saat karşılaştırması cihazın yerel saatiyle; `is_holiday_mode` (Tatil Modu) hesaba katılmadı (ürün kararı); gün bazlı çalışma saati verisi yok. Üretimde `working_hours`/`is_store_open` sütunlarının varlığı canlı sorguyla doğrulanmadı (yalnızca `SUPABASE_SETUP.sql`, test fixture ve `store_service.dart` içindeki mevcut seçimlerden çıkarıldı). Not: `SUPABASE_PUBLIC_ACCESS.sql` genel okuma politikası `is_store_open = true` — bu politika canlıdaysa satıcının kapattığı mağazalar haritaya zaten hiç gelmez; filtrenin asıl etkisi çalışma saatinden gelir.
- `home_ui_no_demo_test` (Run #9'dan devreden, P3 eskimiş test): `IbulOpportunityShortcutsSection` commit 9cc3c71'de web ana sayfasından bilinçli kaldırılmış (mobil kısayollar `IbulMobileHomeChrome`/`FeatureMenu` içinde); uygulama hatası değil. Test beklentisi güncel bölüme (`HomeNearbyDiscoverySection`) çevrildi. Not: `lib/screens/home/sections/ibul_opportunity_shortcuts_section.dart` artık hiçbir yerden kullanılmıyor (ölü kod, silinmedi).
- Değişen dosyalar:
  - `ibul_app/lib/core/map_store_filter_helpers.dart`
  - `ibul_app/lib/core/map_store_marker.dart`
  - `ibul_app/lib/services/store/store_mapping_helpers.dart` (`mapStoreSelectBase`)
  - `ibul_app/lib/screens/map_page.dart` (`_rebuildFilteredIndices`, `_mapListEmptyMessage`)
  - `ibul_app/test/core/map_store_filter_helpers_test.dart` (+8 test), `ibul_app/test/home/home_ui_no_demo_test.dart`
- Testler: map_store_filter_helpers + home_ui_no_demo + store_map_select_fallback + map_store_popup_helpers + test/mall → 141 PASS / 0 FAIL; diğer harita testleri (loading/pipeline/coordinate/emergency pipeline/logo/tab route) → 32 PASS / 0 FAIL. `dart analyze` (4 kaynak + 2 test) temiz. Ayrı A/B koşusu yapılmadı; "does not hide stores by index" testi eski `i % 5` koduyla tanım gereği düşer. Tam `flutter test` çalıştırılmadı (RAM).
- Seviye: Kod tamamlandı / Test geçti (saf filtre + çözümleme birim testleri; `map_page` bağlantısı için widget testi YOK — yalnızca analyze). Entegre edilmedi (commit yok). Gerçek cihaz/web ve canlı Supabase sorgusu doğrulaması YOK.
- Ödeme sistemi: dokunulmadı.
- Kanıtlanan ama düzeltilmeyen (devreden): P1 personel "garson fallback" kararı (Run #8/#11), İHIZ teslim/iptal kurye sahipliği + cüzdan idempotency anahtarı (yalnızca rapor), kurye iptalinin kalemi `cancelled` yapması, `home_speed_slice` prefetch kararı, İHIZ `widget_test.dart` Supabase kurulumu.
## Sonraki en değerli görev
1. P1: personel "garson fallback" — kullanıcı kararı (Run #11'deki iki seçenek).
2. Dengeli ilerleme → İBUL Satıcı: `local_print_bridge` pytest regresyonu (uzun süredir çalıştırılmadı); golden test hataları (`test/screens/failures`).
3. İHIZ: teslim etme (`_markOrderDelivered`) için durum ön koşulu incelemesi (mükerrer "teslim edildi" yazımı); `widget_test.dart` Supabase kurulumu.
4. Müşteri: harita mağaza kartında/popup'ında "Açık / Kapalı" rozeti (veri artık kayıtta mevcut); `nearby_sellers_map_page` `is_store_open` kullanımıyla tutarlılık.
5. Commit edilmemiş değişikliklerin kullanıcı tarafından gözden geçirilip commit edilmesi.

## Çalıştırma #14 — 2026-11-18 (20:25 +03) — yerel Mac, Flutter var
- Son denetlenen uygulama/modül: İHIZ (`ihiz_web`) — kurye "teslim edildi" yazımı (`_markOrderDelivered`, Run #12/#13'ten devreden).
- Ortam: disk 6.9 → 6.4 GB boş (8 GB eşiğinin ALTINDA — ağır build/disk işlemi yapılmadı); swap 12.4/13.3 GB dolu. Eşzamanlı çalışma VAR: `xcodebuild` (SellerOfflinetest, izole DerivedData) sürüyordu; `seller_panel_page.dart` 19:56'da, `PROJECT_MAP.md`/`CLAUDE.md` 19:48'de başka oturumca değiştirilmiş. Bu yüzden satıcı/yazıcı/çevrimdışı dosyalarına ve `PROJECT_MAP.md`'ye DOKUNULMADI (sıradaki satıcı görevi `local_print_bridge` pytest ertelendi). 156 commit edilmemiş dosya korundu. `claude-flow` MCP bağlanamadı (zaman aşımı; kullanılmadı). Eski `flutter_tester` ve başka oturumun `fake_printer.py` süreci — dokunulmadı.
- Bulunan hata (P1, yanlış/mükerrer teslimat — kod okumasıyla kanıtlı; canlı sunucuda yeniden üretilmedi): normal (iade olmayan) "teslim edildi" güncellemesi yalnızca `.eq('id', orderItemId)` ile yapılıyordu. Kurye yoldayken sipariş iptal/iade edilmişse (`cancelled`, `refunded`, `return_*`) kuryenin onayı bu durumun üzerine `delivered` yazıyor, müşteriye "teslim edilmiştir" bildirimi + geçmiş kaydı gidiyordu. Zaten `delivered` olan kalemde tekrar onay ikinci bildirim/geçmiş kaydı üretiyordu.
  - Kök neden: güncellemede durum ön koşulu yok.
  - Düzeltme (şema/veri sözleşmesi değişikliği YOK, yalnızca istemci sorgusu): güncellemeye `.not('status','in', <delivered,cancelled,return_requested,return_approved,return_shipped_back,return_received,returned,refunded>)` eklendi. Negatif koşul bilinçli: teslim alma doğrulanamamış (`unverified`) ya da satıcı durumu `shipped` yapmış meşru teslimatlar engellenmez. 0 satırda güncel durum okunur:
    - `delivered` → teslimat başarılı sayılır (idempotent); `order_item_status_history`'de `delivered` kaydı varsa geçmiş/bildirim yeniden yazılmaz, yoksa (yanıtı kaybolmuş ilk istek) eski yan adımlar bir kez çalışır.
    - iptal/iade durumları → teslim kaydedilmez; kuryeye "Teslim kaydedilemedi. Bu sipariş iptal edilmiş veya iade sürecine alınmış. Paket için destekle iletişime geçin." gösterilir ve yerel teslimat mevcut `_resetDeliveryFlow()` ile kapatılır (uygulama yeniden açıldığında zaten aynı şey oluyordu: `_isTerminalOrderItemStatus` → kalıcı durum temizleniyor).
    - durum okunamıyor/engelleyici değil → eski yetki-reddi hata yolu aynen.
  - Kapsam dışı (bilinçli): iade teslimi (`return_received`) ve kurye iptal yolu (`cancelled` yazımı hâlâ koşulsuz; `delivered` kalemin üzerine iptal yazabilir — sonraki İHIZ görevi).
  - Kalan risk: ön koşul yalnızca istemcide; RLS izin veriyorsa değiştirilmiş istemci koşulsuz yazabilir. Kurye sahipliği kontrolü hâlâ yok (veri sözleşmesi, kullanıcı kararı).
- Değişen dosyalar:
  - `ihiz_web/lib/main.dart` (`_markOrderDelivered` normal yol, `_completeDelivery` kapanmış sipariş dalı)
  - `ihiz_web/lib/src/util/ihiz_pickup_sync_outcome.dart` (`ihizDeliveryBlockedStatuses`, `ihizDeliveryBlockedStatusFilter`, `IhizDeliveryConflict`, `resolveDeliveryConflict`)
  - `ihiz_web/lib/src/util/ihiz_courier_error_text.dart` (`ihizDeliveryOrderClosedSyncError` + metin)
  - `ihiz_web/test/util/ihiz_pickup_sync_outcome_test.dart` (+4), `ihiz_web/test/util/ihiz_courier_error_text_test.dart` (+1)
- Testler: `flutter test test/util` (ihiz_web) → 28 PASS / 0 FAIL (5 yeni + 23 mevcut). `dart analyze lib/main.dart lib/src/util test/util` temiz. `test/widget_test.dart` çalıştırılmadı (Run #10'daki mevcut/bağımsız FAIL).
- Seviye: Kod tamamlandı / Test geçti (yalnızca saf karar fonksiyonları + filtre metni; koşullu güncelleme ve `_completeDelivery` dalı için entegrasyon/widget testi YOK — Supabase mock altyapısı yok). Entegre edilmedi (commit yok). Gerçek sunucu/kurye doğrulaması YOK; PostgREST `not.in` filtresinin canlıda davranışı doğrulanmadı (aynı sözdizimi `finance_repository.dart`'ta kullanılıyor). Canlı veriye dokunulmadı.
- Ödeme sistemi: dokunulmadı.
- `PROJECT_MAP.md` güncellenmedi (başka oturum 19:48'de düzenlemiş; eşzamanlı düzenleme yapılmadı). İşlenecek not: İHIZ teslim alma `.eq('status','ready_to_ship')`, teslim etme `not.in` sonlanmış durumlar ön koşuluyla yazılır (`ihiz_pickup_sync_outcome.dart`).
- Kanıtlanan ama düzeltilmeyen (devreden): P1 personel "garson fallback" kararı (Run #8/#11), İHIZ kurye sahipliği + cüzdan idempotency anahtarı (yalnızca rapor), kurye iptalinin kalemi koşulsuz `cancelled` yapması, `home_speed_slice` prefetch kararı, İHIZ `widget_test.dart` Supabase kurulumu, "Teslim onayi icin hedef noktaya daha yakin olmaniz gerekiyor" ASCII metni (`_completeDeliveryWithVerification`).
## Sonraki en değerli görev
1. P1: personel "garson fallback" — kullanıcı kararı (Run #11'deki iki seçenek).
2. DİSK: 6.4 GB boş — kullanıcı yer açmadan build başlatılmamalı.
3. Dengeli ilerleme → İBUL Satıcı (başka oturum bitince): `local_print_bridge` pytest regresyonu; golden test hataları (`test/screens/failures`).
4. Müşteri: harita mağaza kartında "Açık / Kapalı" rozeti; `nearby_sellers_map_page` tutarlılığı.
5. İHIZ: kurye iptal yolunda `delivered` üzerine yazma koruması; kalan ASCII metin; `PROJECT_MAP.md`'ye yukarıdaki sözleşme notu.
6. Commit edilmemiş değişikliklerin kullanıcı tarafından gözden geçirilip commit edilmesi.

## Çalıştırma #15 — 2026-11-18 (21:14 +03) — yerel Mac, Flutter var
- Son denetlenen uygulama/modül: İHIZ (`ihiz_web`) — kurye "Paketi iptal et" yazımı (`_cancelActiveDelivery`, Run #14'ten devreden).
- Görev seçimi notu: sıradaki dengeli görev İBUL Satıcı idi (`local_print_bridge` pytest), ancak başka oturum 21:00'de satıcı/çevrimdışı dosyalarını (`seller_panel_page.dart`, `order_print_job_service.dart`, `restaurant_offline/*`, `lib/main_seller.dart`, `PROJECT_MAP.md`) değiştirmişti ve `.claude/worktrees/ibul-restaurant-completion-e60b65` worktree'si etkin → satıcı alanına ve `PROJECT_MAP.md`'ye DOKUNULMADI. Devreden açık veri bütünlüğü bulgusu (P1) seçildi.
- Ortam: disk 9.3 → 8.3 GB boş (10 GB altı: build yok; 8 GB eşiğine çok yakın). Aktif `xcodebuild` yok. 160 commit edilmemiş dosya korundu. `claude-flow` MCP bağlanamadı (zaman aşımı; kullanılmadı). Eski `flutter_tester` ve başka oturumun `fake_printer.py` süreci — dokunulmadı.
- Bulunan hata (P1, veri bütünlüğü/mükerrer işlem — kod okumasıyla kanıtlı; canlı sunucuda yeniden üretilmedi): normal (iade olmayan) kurye iptali `order_items.status = 'cancelled'` değerini yalnızca `.eq('id', orderItemId)` ile yazıyordu. Kalem sunucuda zaten `delivered` ise (ör. teslim yazımı uygulanmış ama yerel durum eski) kurye iptali teslim edilmiş siparişi `cancelled` yapıyor, müşteriye "siparişiniz iptal edilmiştir" bildirimi + geçmiş kaydı gidiyordu. Zaten iptal/iade edilmiş kalemde de ikinci bildirim/geçmiş kaydı üretiliyor, iade durumu (`return_*`, `refunded`) `cancelled` ile eziliyordu.
  - Kök neden: güncellemede durum ön koşulu yok (Run #12/#14'teki teslim alma / teslim etme ile aynı sınıf).
  - Düzeltme (şema/veri sözleşmesi değişikliği YOK, yalnızca istemci sorgusu): iptal güncellemesine mevcut `ihizDeliveryBlockedStatusFilter` ile `.not('status','in', …)` eklendi (yeni liste oluşturulmadı). 0 satırda güncel durum okunur; kalem sonlanmışsa durum/geçmiş/bildirim YAZILMAZ, yerel teslimat `_resetDeliveryFlow()` ile kapatılır ve kuryeye durum bildirilir ("Bu sipariş teslim edilmiş olarak kayıtlı; iptal kaydedilmedi. Teslimat kapatıldı." / "Bu sipariş zaten iptal edilmiş veya iade sürecine alınmış; iptal yeniden kaydedilmedi. Teslimat kapatıldı."). Durum okunamıyor/sonlanmış değilse eski yetki-reddi hata yolu aynen.
  - Kapsam dışı (bilinçli): iade görevi iptal yolu (`return_approved` yazımı) — iade durum makinesi ayrı, dokunulmadı. Üst sipariş için `orders.status='cancelled'` yedek yazımı değiştirilmedi (yalnızca kalem yazımı başarılı olduktan sonra çalışır).
  - Kalan risk: ön koşul yalnızca istemcide; RLS izin veriyorsa değiştirilmiş istemci koşulsuz yazabilir. Kurye sahipliği kontrolü hâlâ yok (atanan kurye sütunu → veri sözleşmesi, kullanıcı kararı).
- Ek (P3, Türkçe metin): kuryeye gösterilen "Teslim onayi icin hedef noktaya daha yakin olmaniz gerekiyor" → "Teslim onayı için hedef noktaya daha yakın olmanız gerekiyor". Yönetici ekranındaki ASCII/ham hata metinleri (Run #10) yine dokunulmadı.
- Değişen dosyalar:
  - `ihiz_web/lib/main.dart` (`_cancelActiveDelivery` normal yol; geofence SnackBar metni)
  - `ihiz_web/lib/src/util/ihiz_pickup_sync_outcome.dart` (`ihizCancelBlockedMessage`)
  - `ihiz_web/test/util/ihiz_pickup_sync_outcome_test.dart` (+3)
- Testler: `flutter test test/util` (ihiz_web) → 31 PASS / 0 FAIL (3 yeni + 28 mevcut). `dart analyze lib/main.dart lib/src/util test/util` temiz. `test/widget_test.dart` çalıştırılmadı (Run #10'daki mevcut/bağımsız FAIL).
- Seviye: Kod tamamlandı / Test geçti (yalnızca saf karar fonksiyonu; koşullu güncelleme ve SnackBar dalı için entegrasyon/widget testi YOK — Supabase mock altyapısı yok). Entegre edilmedi (commit yok). Gerçek sunucu/kurye doğrulaması YOK; canlı veriye dokunulmadı.
- Ödeme sistemi: dokunulmadı. Rapor notu (değiştirilmedi): kurye iptali kalemi `cancelled` yapıyor ama istemcide iade/cüzdan geri alma çağrısı görünmüyor — ödeme bağlanırken iptal → iade akışı ayrıca ele alınmalı.
- `PROJECT_MAP.md` güncellenmedi (başka oturum 21:00'de düzenlemiş). İşlenecek not (Run #14 ile birlikte): İHIZ `order_items` yazımları durum ön koşulludur — teslim alma `.eq('status','ready_to_ship')`; teslim etme ve kurye iptali `not.in` sonlanmış durumlar (`ihiz_pickup_sync_outcome.dart`).
- Kanıtlanan ama düzeltilmeyen (devreden): P1 personel "garson fallback" kararı (Run #8/#11), İHIZ kurye sahipliği + cüzdan idempotency anahtarı (yalnızca rapor), iade görevi iptal/teslim yollarında ön koşul, `home_speed_slice` prefetch kararı, İHIZ `widget_test.dart` Supabase kurulumu.
## Sonraki en değerli görev
1. P1: personel "garson fallback" — kullanıcı kararı (Run #11'deki iki seçenek).
2. DİSK: 8.3 GB boş — kullanıcı yer açmadan build başlatılmamalı.
3. Dengeli ilerleme → İBUL E-Ticaret (İHIZ üst üste 2 kez çalışıldı): harita mağaza kartında "Açık / Kapalı" rozeti; `nearby_sellers_map_page` `is_store_open` tutarlılığı.
4. İBUL Satıcı (başka oturum/worktree bitince): `local_print_bridge` pytest regresyonu; golden test hataları (`test/screens/failures`).
5. `PROJECT_MAP.md`'ye yukarıdaki İHIZ sözleşme notu (eşzamanlı düzenleme bitince).
6. Commit edilmemiş değişikliklerin kullanıcı tarafından gözden geçirilip commit edilmesi.
