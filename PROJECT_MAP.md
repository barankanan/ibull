# Project Overview

Bu repo tek uygulamalı bir yapıdan çok, ortak backend etrafında dönen bir ürün ailesi gibi çalışıyor.

- `lib/` kökü, `ibul_app` paketini sarmalayan Flutter entry shell katmanı.
- `ibul_app/` tüketici uygulaması + satıcı paneli + garson akışlarının ana Flutter kod tabanı.
- `ihiz_web/` ayrı çalışan Flutter web kurye başvuru / kurye giriş deneyimi.
- `restaurant-ops-web/` restoran operasyonları için ayrı Next.js modülü.
- `local_print_bridge/` localhost üzerinden çalışan Python tabanlı yerel yazdırma servisi.
- `SUPABASE_*.sql` dosyaları hem kökte hem alt dizinlerde Supabase schema, policy, RPC ve hotfix birikimini taşıyor.

Monorepo hissi var, ancak resmi workspace orkestrasyonu net görünmüyor. Kök `pubspec.yaml`, `ibul_app` paketini path dependency olarak kullanıyor; bu nedenle pratikte asıl iş mantığı `ibul_app/lib/` içinde.

# Directory Summary

| Yol | Görev | Not |
| --- | --- | --- |
| `lib/` | Kök Flutter girişleri | `ibul_app` ekranlarını ve bootstrap yardımcılarını kullanır. |
| `ibul_app/lib/` | Ana ürün mantığı | UI, servisler, provider tabanlı state, satıcı/garson araçları burada. |
| `ihiz_web/lib/` | Kurye web uygulaması | Ayrı Supabase config ile açılır. |
| `restaurant-ops-web/src/` | Next.js waiter/admin operasyon modülü | Mock veya Supabase repository ile çalışır. |
| `local_print_bridge/` | Yazıcı bridge backend | `127.0.0.1:3001` civarında HTTP API sağlar. |
| `scripts/` | Çalıştırma, build, paketleme | Flutter ve print bridge dev/release akışları. |
| `docs/` | Çalışma notları ve operasyon dokümantasyonu | Özellikle print bridge ve seller desktop süreçleri. |
| `SUPABASE_DIAGNOSE_*.sql` | Canlı veri teşhis / güvenli backfill yardımcıları | Uygulama kodunu değiştirmeden veri anomalisini doğrulamak için kullanılır. |
| `android/`, `ios/`, `macos/`, `windows/`, `linux/`, `web/` | Flutter platform katmanları | Kökteki Flutter uygulamasına ait. |
| `restaurant-ops-web/supabase/migrations/` | Waiter ops DB omurgası | `restaurant` schema için temel migration. |
| `ibul_app/test/`, `local_print_bridge/tests/`, `restaurant-ops-web` tip kontrolleri | Test yüzeyi | Flutter ağırlıklı unit/widget testler, Python unittest, Next typecheck. |

# Entry Points

| Dosya | Amaç | Bağlandığı ana katman |
| --- | --- | --- |
| `lib/main.dart` | Kök consumer/web app entry | `ibul_app/app/app_bootstrap.dart`, `ibul_app` ekranları |
| `lib/main_seller.dart` | macOS seller desktop entry | `ibul_app` seller paneli + desktop print |
| `ibul_app/lib/main.dart` | Paket içi doğrudan Flutter entry | Firebase, Supabase, push, QR hızlı açılış |
| `ihiz_web/lib/main.dart` | İhız kurye web entry | Supabase, pricing config, auth/landing akışı |
| `restaurant-ops-web/src/app/page.tsx` | Next.js root redirect | `/waiter` route’una yönlendirir |
| `restaurant-ops-web/src/app/waiter/page.tsx` | Waiter giriş ekranı | `WaiterRouteScreen` |
| `restaurant-ops-web/src/app/api/restaurant/snapshot/route.ts` | Snapshot API | Server repository |
| `restaurant-ops-web/src/app/api/restaurant/commands/route.ts` | Mutation API | Server repository |
| `local_print_bridge/__main__.py` | Python bridge başlatıcısı | `server.py`, `BridgeSettings` |
| `server.js` | Basit Node tabanlı legacy print server | Muhtemelen eski/alternatif çözüm |
| `app.py` | Flask tabanlı legacy local print server | Yeni `local_print_bridge/` öncesi çözüm gibi görünüyor |

# Core Modules

## Flutter consumer/seller core

- `ibul_app/lib/app/`
  - bootstrap, theme, provider kurulumu, ana `HomeWrapper`.
- `ibul_app/lib/core/`
  - singleton state objeleri, auth kimliği, runtime config, route/QR yardımcıları.
- `ibul_app/lib/services/`
  - Supabase, auth, order, store, print, media, notification, dashboard katmanı.
- `ibul_app/lib/screens/`
  - tüketici ekranları, seller paneli, garson araçları, admin ekranları.
- `ibul_app/lib/widgets/`
  - reusable UI parçaları.

## Restaurant operations web

- `restaurant-ops-web/src/features/restaurant/domain/`
  - tipler, reducer, command sözleşmeleri, runtime error modeli.
- `restaurant-ops-web/src/features/restaurant/data/`
  - client adapter, mock repository, Supabase repository.
- `restaurant-ops-web/src/state/waiter-store.tsx`
  - optimistic UI runtime, rollback, retry.
- `restaurant-ops-web/src/components/RestaurantWaiterApp.tsx`
  - waiter UI orchestration.

## Local print stack

- `ibul_app/lib/services/local_print_service.dart`
  - Flutter tarafında bridge HTTP istemcisi.
- `ibul_app/lib/services/desktop_print_hub.dart`
  - seller desktop tarafında realtime print job dinleyicisi.
- `local_print_bridge/server.py`
  - bridge HTTP API, yazıcı keşfi, receipt/kitchen baskı akışı.
- `local_print_bridge/print_station.py`
  - Supabase tabanlı print station consumer/poller.

# File Relationship Map

## `lib/main.dart`

- `Dosya yolu:` `lib/main.dart`
- `Amaç:` Kök Flutter uygulamasını başlatır; QR hızlı açılış, deferred route’lar ve provider ağacını kurar.
- `Bağlı olduğu dosyalar:` `ibul_app/app/app_bootstrap.dart`, `ibul_app/core/app_ready.dart`, `ibul_app/core/qr_initial_params.dart`, `ibul_app/screens/qr_entry_screen.dart`, deferred `map_page`, `ihiz_courier_page`, `admin_panel_page`, `become_seller_page`, `seller_panel_page`.
- `Bu dosyayı kullanan dosyalar:` Flutter runtime ve platform launcher dosyaları.
- `Değişirse etkilenecek yerler:` route çözümleme, QR başlangıç davranışı, web bundle parçalanması, seller/admin deep-link akışı.
- `Risk notu:` Yanlış route veya provider değişikliği QR akışında blank screen ya da `ProviderNotFound` üretebilir.
- `Durum:` net

## `lib/main_seller.dart`

- `Dosya yolu:` `lib/main_seller.dart`
- `Amaç:` macOS seller desktop kabuğunu başlatır; config doğrular, seller session gate açar, desktop print overlay ekler.
- `Bağlı olduğu dosyalar:` `ibul_app/app/app_bootstrap.dart`, `ibul_app/core/config/runtime_config.dart`, `ibul_app/services/auth_service.dart`, `ibul_app/services/bridge_manager.dart`, `ibul_app/services/desktop_print_hub.dart`, `ibul_app/screens/seller_login_page.dart`, `ibul_app/screens/seller_panel_page.dart`, `ibul_app/screens/seller/desktop_printer_setup_page.dart`.
- `Bu dosyayı kullanan dosyalar:` `scripts/run_seller_desktop.sh`, macOS Flutter target seçimi.
- `Değişirse etkilenecek yerler:` seller desktop login, print setup route’ları, config hata ekranı, desktop status bar.
- `Risk notu:` Buradaki route veya provider değişikliği seller desktop’ı consumer app’ten farklılaştırır.
- `Durum:` net

## `ibul_app/lib/app/app_bootstrap.dart`

- `Dosya yolu:` `ibul_app/lib/app/app_bootstrap.dart`
- `Amaç:` Supabase init, tema, provider listesi, `HomeWrapper`, route argument parser’ları.
- `Bağlı olduğu dosyalar:` `core/app_state.dart`, `core/cart_state.dart`, `core/favorite_state.dart`, `core/review_state.dart`, `core/providers/*`, `core/config/runtime_config.dart`, `services/desktop_print_hub.dart`, `screens/home_screen.dart`.
- `Bu dosyayı kullanan dosyalar:` `lib/main.dart`, `lib/main_seller.dart`, `ibul_app/lib/main.dart`.
- `Değişirse etkilenecek yerler:` tüm Flutter girişleri, global provider ağacı, tema, Supabase bootstrap.
- `Risk notu:` Provider listesi değişirse özellikle `/qr` fast-path ve seller desktop kırılabilir.
- `Durum:` net

## `ibul_app/lib/core/config/runtime_config.dart`

- `Dosya yolu:` `ibul_app/lib/core/config/runtime_config.dart`
- `Amaç:` `--dart-define` ile gelen Supabase, Google ve seller installer URL’lerini doğrular.
- `Bağlı olduğu dosyalar:` Flutter runtime environment.
- `Bu dosyayı kullanan dosyalar:` `app_bootstrap.dart`, `auth_service.dart`, `store_service.dart`, `order_service.dart`, `print_station_service.dart`, `seller_panel_page.dart`, `lib/main_seller.dart`, yazıcı setup ekranları.
- `Değişirse etkilenecek yerler:` login, Supabase erişimi, installer linkleri, desktop print setup.
- `Risk notu:` Hatalı zorunlu alan doğrulaması tüm uygulamayı açılmaz hale getirebilir.
- `Durum:` net

## `ibul_app/lib/core/app_state.dart`

- `Dosya yolu:` `ibul_app/lib/core/app_state.dart`
- `Amaç:` singleton global uygulama state’i; auth, search history, favori, sepet, adresler ve bazı local cache davranışlarını taşır.
- `Bağlı olduğu dosyalar:` `auth/user_identity.dart`, `cart_state.dart`, `favorite_state.dart`, `review_state.dart`, `services/auth_service.dart`, `services/product_list_service.dart`, `services/push_notification_service.dart`, `services/store_follow_service.dart`, `services/supabase_service.dart`.
- `Bu dosyayı kullanan dosyalar:` `app_bootstrap.dart`, `home_screen.dart`, `business_detail_page.dart`, `map_page.dart`, seller panelinin bazı bölümleri ve pek çok widget/provider.
- `Değişirse etkilenecek yerler:` login sonrası hydrate, guest/user cache, sepet/favori göstergeleri, product list sync.
- `Risk notu:` Singleton + provider hibriti; yan etkiler fazla, auth/state bug’ları geniş alana yayılır. Yeni seller-scoped cache yardımcıları seller panel dashboard/finance cache’ini de taşıdığı için anahtar formatı değişirse restart kalıcılığı etkilenir.
- `Durum:` kısmi

## `ibul_app/lib/services/auth_service.dart`

- `Dosya yolu:` `ibul_app/lib/services/auth_service.dart`
- `Amaç:` Supabase auth, Google login, role çözümleme, seller/admin/user route kararı, session backup/restore.
- `Bağlı olduğu dosyalar:` `supabase_flutter`, `google_sign_in`, `core/config/runtime_config.dart`, `store_service.dart`.
- `Bu dosyayı kullanan dosyalar:` `app_state.dart`, `login_page.dart`, `seller_login_page.dart`, `seller/admin_panel_page.dart`, `custom_header.dart`, `notifications_page.dart`, `register_page.dart`, `become_seller_page.dart`.
- `Değişirse etkilenecek yerler:` kullanıcı girişi, seller/admin geçişleri, garson rol çözümü, session switch davranışı.
- `Risk notu:` Role çözümleme ve store profile çekimi seller panel erişimini doğrudan etkiler.
- `Durum:` net

## `ibul_app/lib/services/store_service.dart`

- `Dosya yolu:` `ibul_app/lib/services/store_service.dart`
- `Amaç:` mağaza profili, public store info, menü ürünleri, seller bazlı lookup, tablo işlemleri için ana Supabase servis cephesi.
- `Bağlı olduğu dosyalar:` `core/config/runtime_config.dart`, `store/store_media_service.dart`, `store/store_table_service.dart`, `store_notification_trigger_service.dart`, `store_service_mappers.dart`, `store/store_mapping_helpers.dart`.
- `Bu dosyayı kullanan dosyalar:` `home_screen.dart`, `business_detail_page.dart`, `map_page.dart`, `qr_entry_screen.dart`, `seller_panel_page.dart`, seller product/collection/printer ekranları, ads campaign ekranları, admin map/store sayfaları.
- `Değişirse etkilenecek yerler:` mağaza detayları, QR çözümleme, seller ürün yönetimi, garson masa akışı, harita ve fast-delivery gösterimleri.
- `Risk notu:` Çok geniş sorumluluğu var; tek değişiklik consumer + seller + waiter katmanlarını aynı anda etkileyebilir.
- `Durum:` net

## `ibul_app/lib/services/store/store_table_service.dart`

- `Dosya yolu:` `ibul_app/lib/services/store/store_table_service.dart`
- `Amaç:` masa/QR çözümleme ve store table davranışlarının alt servis katmanı.
- `Bağlı olduğu dosyalar:` Supabase client, `runtime_config.dart`.
- `Bu dosyayı kullanan dosyalar:` öncelikle `store_service.dart`; dolaylı olarak `home_screen.dart`, `qr_entry_screen.dart`, `business_detail_page.dart`.
- `Değişirse etkilenecek yerler:` QR token doğrulama, masa seçimi ve table-order akışları.
- `Risk notu:` QR bug’larının önemli kısmı burada veya bunu saran `store_service` katmanında çıkar. Ayrıca `table_order_history` okuma/yazma bu katmanda `closed_at` merkezli çalışmalı; prod ortamda `archived_at` yoksa fallback zorunludur yoksa garson kapanışları restart sonrası finans/genel bakışta kaybolmuş görünür.
- `Durum:` kısmi

## `ibul_app/lib/services/order_service.dart`

- `Dosya yolu:` `ibul_app/lib/services/order_service.dart`
- `Amaç:` checkout sonrası order oluşturma, seller order fetch ve teslimat ücret mantıklarının önemli kısmı.
- `Bağlı olduğu dosyalar:` `core/config/runtime_config.dart`, `supabase_service.dart`, `utils/order_status_constants.dart`.
- `Bu dosyayı kullanan dosyalar:` `checkout_page.dart`, `account_page.dart`, `orders_page.dart`, `order_detail_page.dart`, `notifications_page.dart`, `seller_panel_page.dart`, `custom_header.dart`.
- `Değişirse etkilenecek yerler:` müşteri checkout, order detail, seller sipariş panelleri, kargo/ihız bağlı alanlar.
- `Risk notu:` Order item shaping ve delivery fee hesabı finans/lojistik tarafını da etkiler.
- `Durum:` kısmi

## `ibul_app/lib/services/local_print_service.dart`

- `Dosya yolu:` `ibul_app/lib/services/local_print_service.dart`
- `Amaç:` Flutter tarafında `local_print_bridge` HTTP API istemcisi; health, printers, setup, print/test çağrıları.
- `Bağlı olduğu dosyalar:` `http`, `models/turkish_encoding_calibration.dart`.
- `Bu dosyayı kullanan dosyalar:` `desktop_print_hub.dart`, `desktop_print_orchestrator.dart`, `print_station_service.dart`, `seller_panel_page.dart`, `desktop_printer_setup_page.dart`, `printer_test_dialog.dart`, `printer_ethernet_dialog.dart`, `printer_wizard.dart`, `bridge_error_dialog.dart`.
- `Değişirse etkilenecek yerler:` seller desktop print setup, test baskıları, bridge availability paneli, direct kitchen dispatch.
- `Risk notu:` İstemci hata kodları UI’de doğrudan mesaj çevriminde kullanılıyor.
- `Durum:` net

## `ibul_app/lib/services/desktop_print_hub.dart`

- `Dosya yolu:` `ibul_app/lib/services/desktop_print_hub.dart`
- `Amaç:` desktop seller ortamında realtime print job dinler, claim eder, bridge’e yollar, başarısız işleri saklar.
- `Bağlı olduğu dosyalar:` `bridge_manager.dart`, `desktop_print_orchestrator.dart`, `kitchen_hub_payload_stamp.dart`, `kitchen_print_trace_log.dart`, `kitchen_product_mapping_cache_store.dart`, `local_print_service.dart`, `printer_event_log_service.dart`, `printer_repository.dart`, `shared_preferences`, Supabase realtime.
- `Bu dosyayı kullanan dosyalar:` `app_bootstrap.dart`, `lib/main_seller.dart`, `seller_panel_page.dart`, `desktop_print_status_bar.dart`, `desktop_printer_setup_page.dart`.
- `Değişirse etkilenecek yerler:` seller desktop print otomasyonu, job retry, realtime listener, UI status bar.
- `Risk notu:` Race condition ve duplicate print riski yüksek; order print job servisiyle etkileşimli.
- `Durum:` net

## `ibul_app/lib/screens/home_screen.dart`

- `Dosya yolu:` `ibul_app/lib/screens/home_screen.dart`
- `Amaç:` consumer ana sayfa; banner, kategori, ürün ve bazı QR fallback davranışlarını yönetir.
- `Bağlı olduğu dosyalar:` `AppState`, `ReviewState`, `DatabaseHelper`, `AdminService`, `ReviewRepository`, `StoreService`, `SupabaseService`, çok sayıda widget ve `business_detail_page.dart`, `map_page.dart`.
- `Bu dosyayı kullanan dosyalar:` `HomeWrapper`, `MaterialApp.home`, kök `/` route.
- `Değişirse etkilenecek yerler:` landing ürün akışı, banner cache, QR’dan home fallback, category/search navigasyonları.
- `Risk notu:` Büyük ve çok sorumluluklu; performans ve init race sorunlarına açık. Web görünümü (`home_screen_sections.dart`) `WebStickyFooterScrollView` kullanır; kategori/boş ürün ekranı footer layout'u bu wrapper'a bağlıdır.
- `Durum:` kısmi

## `ibul_app/lib/screens/qr_entry_screen.dart`

- `Dosya yolu:` `ibul_app/lib/screens/qr_entry_screen.dart`
- `Amaç:` `/qr` ile açılan akışta seller/table/token çözümleyip `BusinessDetailPage`’e yönlendirir.
- `Bağlı olduğu dosyalar:` `core/app_ready.dart`, `core/qr_initial_params.dart`, `services/store_service.dart`, `business_detail_page.dart`.
- `Bu dosyayı kullanan dosyalar:` `lib/main.dart`, `ibul_app/lib/main.dart`.
- `Değişirse etkilenecek yerler:` QR deep-link, verified/unverified table akışı, hızlı masa siparişi açılışı.
- `Risk notu:` Başlangıç servis readiness ve navigation timing çok hassas.
- `Durum:` net

## `ibul_app/lib/screens/business_detail_page.dart`

- `Dosya yolu:` `ibul_app/lib/screens/business_detail_page.dart`
- `Amaç:` mağaza detay ekranı; menü ürünleri, kampanyalar, takip, table ordering ve QR sonrası yemek siparişi akışını yönetir.
- `Bağlı olduğu dosyalar:` `StoreService`, `SupabaseService`, `ProductListService`, `PushNotificationService`, `StoreFollowService`, `CouponService`, `CampaignService`, `WaiterOrderRequestService`, `AppState`, çeşitli restaurant-order widget’ları.
- `Bu dosyayı kullanan dosyalar:` `qr_entry_screen.dart`, `home_screen.dart`, `map_page.dart`, `product_card.dart`, `market_list_page.dart`, `followed_stores_page.dart`, `order_detail_page.dart`, ürün detay widget’ları.
- `Değişirse etkilenecek yerler:` store landing, QR masa siparişi, waiter request fallback, product/store conversion.
- `Risk notu:` UI + API + state + QR katmanlarını aynı dosyada topluyor; etki alanı geniş.
- `Durum:` kısmi

## `ibul_app/lib/services/location_access_service.dart`

- `Dosya yolu:` `ibul_app/lib/services/location_access_service.dart`
- `Amaç:` Konum izni isteme ve mevcut konum okuma akışını tek noktada toplar; paralel `requestPermission` çağrılarını in-flight Future ile engeller.
- `Bağlı olduğu dosyalar:` `geolocator`.
- `Bu dosyayı kullanan dosyalar:` `map_page.dart`, `nearby_sellers_map_page.dart`.
- `Değişirse etkilenecek yerler:` harita açılışı, yakın lokasyon akışı, konum merkezleme, yakın mağaza mesafe sıralaması.
- `Risk notu:` İzin verildikten sonra konum alınamazsa UI katmanı hata mesajını göstermeye devam eder; proximity notification mantığı bu servisten bağımsızdır.
- `Durum:` net

## `ibul_app/lib/screens/delivery_info_page.dart`

- `Dosya yolu:` `ibul_app/lib/screens/delivery_info_page.dart`
- `Amaç:` Ürün detayından açılan Kurye Bilgi ekranı; kargo firması seçimi, teslimat süresi/ücret bilgileri ve teslimat adresi yönetimi.
- `Bağlı olduğu dosyalar:` `core/constants.dart`, `widgets/address_edit_sheet.dart`
- `Bu dosyayı kullanan dosyalar:` `widgets/product_detail/product_delivery_info.dart`
- `Değişirse etkilenecek yerler:` ürün detayı kurye teslimat kartı navigasyonu, kargo firması seçim dialogu, adres ekleme/seçim akışı.
- `Risk notu:` UI-only değişiklikler davranışı etkilememeli; `_selectedCourier`, `_addresses` ve dialog callback’leri korunmalı.
- `Durum:` net

## `ibul_app/lib/screens/reviews_page.dart`

- `Dosya yolu:` `ibul_app/lib/screens/reviews_page.dart`
- `Amaç:` Hesap > **Değerlendirmelerim** ekranı; kullanıcının yazdığı ürün yorumlarını listeler, arama ve sekme filtreleri sunar.
- `Bağlı olduğu dosyalar:` `core/app_state.dart`, `core/constants.dart`, `models/product_model.dart`, `widgets/account_search_filter_row.dart`, `widgets/account_sidebar.dart`, `widgets/web_header.dart`, `widgets/web_sticky_footer_scroll_view.dart`, `screens/product_detail_page.dart`, `screens/search_results_page.dart`
- `Bu dosyayı kullanan dosyalar:` `widgets/account_sidebar.dart`, hesap navigasyon akışı.
- `Değişirse etkilenecek yerler:` kullanıcı değerlendirme geçmişi listesi, arama/filtre UI, boş durum kartı, ürün detayına geçiş.
- `Risk notu:` UI-only değişiklikler davranışı etkilememeli; `_selectedTab`, `_searchQuery`, `_filteredReviews` ve `_openProduct` akışı korunmalı. Filtre butonu dekoratif (onTap yok).
- `Durum:` net

## `ibul_app/lib/screens/account_page.dart`

- `Dosya yolu:` `ibul_app/lib/screens/account_page.dart`
- `Amaç:` Hesap Özeti (web dashboard); kullanıcı istatistikleri, Son Siparişler önizlemesi ve hesap alt sayfalarına geçiş.
- `Bağlı olduğu dosyalar:` `core/app_state.dart`, `services/order_service.dart`, `utils/order_status_constants.dart`, `utils/dynamic_value_helpers.dart`, `screens/order_detail_page.dart`, `screens/shipment_tracking_page.dart`, `widgets/account_sidebar.dart`, `widgets/web_header.dart`
- `Bu dosyayı kullanan dosyalar:` `home_screen.dart`, hesap navigasyon akışı.
- `Değişirse etkilenecek yerler:` Hesap Özeti > Son Siparişler satır tıklaması, kargo takip görünürlüğü, sipariş detay navigasyonu.
- `Risk notu:` Takip kodu sipariş oluşturulurken atanır; görünürlük yalnız `isInTransitShipmentStatus` ile sınırlandırılmalı. Mobil üst profil özeti `AppState.currentUser` + `UserIdentity.resolveProfilePhotoUrl` / `formatHeightWeightSummary` kullanmalı; mock avatar/boy-kilo kullanılmamalı.
- `Durum:` net

## `ibul_app/lib/screens/settings_page.dart`

- `Dosya yolu:` `ibul_app/lib/screens/settings_page.dart`
- `Amaç:` Hesap > **Kullanıcı Bilgilerim** / Ayarlar; profil fotoğrafı, kişisel bilgiler, iletişim, güvenlik ve bildirim tercihleri formu.
- `Bağlı olduğu dosyalar:` `core/app_state.dart`, `services/auth_service.dart`, `screens/addresses_page.dart`, `screens/change_password_page.dart`, `utils/pick_image_file.dart`, `widgets/account_sidebar.dart`, `widgets/web_header.dart`, `widgets/web_sticky_footer_scroll_view.dart`
- `Bu dosyayı kullanan dosyalar:` `widgets/account_sidebar.dart`, hesap navigasyon akışı.
- `Değişirse etkilenecek yerler:` profil kaydetme, adres önizleme (`AppState.currentDeliveryAddress` / `deliveryAddresses`), telefon/e-posta güncelleme diyalogları, şifre değiştir navigasyonu.
- `Risk notu:` Adres alanı `AppState.currentDeliveryAddress` + `deliveryAddresses` tek kaynaktır; `users.address` settings save'de yazılmaz. SMS OTP backend'i yok — telefon değişimi profil kaydı + bilgilendirme diyalogu. E-posta değişimi Supabase `auth.updateUser(email)` + doğrulama maili gerektirir. `ensureCurrentUserRow` mevcut kullanıcıda `photo_url` overwrite etmemeli; profil foto `users.photo_url` + `store-images/{uid}/profiles/...` (RLS: ilk klasör `auth.uid()`). Foto upload fail olsa bile text profil alanları ayrı kaydedilir.
- `Durum:` net

## `ibul_app/lib/screens/change_password_page.dart`

- `Dosya yolu:` `ibul_app/lib/screens/change_password_page.dart`
- `Amaç:` Ayarlar > **Şifre Değiştir** ayrı ekranı; mevcut şifre doğrulama (re-auth), yeni şifre + tekrar, Supabase e-posta sıfırlama (`resetPasswordForEmail`).
- `Bağlı olduğu dosyalar:` `core/app_state.dart`, `services/auth_service.dart`
- `Bu dosyayı kullanan dosyalar:` `screens/settings_page.dart`
- `Değişirse etkilenecek yerler:` şifre güncelleme UX, Google-only hesaplarda şifre formu devre dışı + e-posta reset, oturum yenileme (re-auth `signInWithPassword`).
- `Risk notu:` SMS OTP backend yok — yalnız e-posta reset. Google-only hesaplarda mevcut şifre alanı devre dışı; şifre oluşturmak için e-posta sıfırlama gerekir. Supabase reset redirect URL projede ayrıca yapılandırılmalı.
- `Durum:` net

## `ibul_app/lib/screens/cart_page.dart`

- `Dosya yolu:` `ibul_app/lib/screens/cart_page.dart`
- `Amaç:` **Sepetim** ekranı; mobil 3 sekme (Alışveriş / Market / Yemek), satıcı gruplu ürün kartları, özet/ onay barı; geniş layout (`>=900px`) web görünümü.
- `Bağlı olduğu dosyalar:` `core/app_state.dart`, `core/cart_state.dart`, `core/store_logo_helper.dart`, `models/product_model.dart`, `services/store_service.dart`, `utils/dynamic_value_helpers.dart`, `screens/business_detail_page.dart`, `screens/product_detail_page.dart`, `widgets/optimized_image.dart`
- `Bu dosyayı kullanan dosyalar:` `home_screen.dart`, alt nav sepet route'u.
- `Değişirse etkilenecek yerler:` sepet listesi hydrate, sekme sayaçları, ürün seçimi/miktar/kupon/hızlı teslimat UI, checkout öncesi özet, satıcı header navigasyonu.
- `Risk notu:` UI-only değişiklikler `_toggleProductSelection`, `_updateQuantity`, `_appState.toggleFastDelivery`, kupon ve parça popup callback'lerini korumalı; mobil ürün kartı `_buildProductCard`, web satırı `_buildWebProductRow`. Satıcı logosu BDP ile aynı: `_loadCartStorePublicInfo` → `getStorePublicInfoByBusinessName(businessName)` → `_storePublicInfoByGroupKey`; widget `_buildStoreLogoWidget` parity (`OptimizedImage` width/height + `errorBuilder`). Chip: üst satır Stokta + Avantajlı (`Wrap`), alt satır tam genişlik teslimat. Header → `_openStoreFromCart`.
- `Durum:` net

## `ibul_app/lib/screens/favorites_page.dart`

- `Dosya yolu:` `ibul_app/lib/screens/favorites_page.dart`
- `Amaç:` Hesap > **Beğendiklerim** / Favorilerim ekranı; beğenilen ürünler, kullanıcı listeleri ve öneriler sekmelerini sunar.
- `Bağlı olduğu dosyalar:` `core/app_state.dart`, `core/constants.dart`, `models/product_model.dart`, `widgets/account_search_filter_row.dart`, `widgets/account_sidebar.dart`, `widgets/web_header.dart`, `widgets/web_sticky_footer_scroll_view.dart`, `widgets/product_card.dart`, `screens/list_detail_page.dart`, `screens/product_detail_page.dart`
- `Bu dosyayı kullanan dosyalar:` `widgets/account_sidebar.dart`, `widgets/web_header_menu_items.dart`, `screens/account_page.dart`
- `Değişirse etkilenecek yerler:` favori ürün grid'i, liste oluşturma, öneriler sekmesi, mobil arama/filtre satırı.
- `Risk notu:` Listelerim sekmesindeki Ekle butonu `_showCreateListDialog` açmalı; arama alanı şu an dekoratif (onChanged yok).
- `Durum:` net

## `ibul_app/lib/widgets/account_search_filter_row.dart`

- `Dosya yolu:` `ibul_app/lib/widgets/account_search_filter_row.dart`
- `Amaç:` Hesap alt sayfalarında paylaşılan kompakt arama + filtre satırı (40px, ortalanmış placeholder).
- `Bağlı olduğu dosyalar:` `core/constants.dart`
- `Bu dosyayı kullanan dosyalar:` `screens/favorites_page.dart`, `screens/reviews_page.dart`
- `Değişirse etkilenecek yerler:` Beğendiklerim ve Değerlendirmelerim üst arama/filtre UI'si.
- `Risk notu:` `onSearchChanged` ve `onFilterTap` opsiyonel; sayfa bazlı davranış korunmalı.
- `Durum:` net

## `ibul_app/lib/screens/map_page.dart`

- `Dosya yolu:` `ibul_app/lib/screens/map_page.dart`
- `Amaç:` harita üzerinden mağaza keşfi, yakınlık bildirimleri ve store detail açılışı.
- `Bağlı olduğu dosyalar:` `AppState`, `StoreService`, `SupabaseService`, `PushNotificationService`, `BusinessDetailPage`, map/filter widget’ları.
- `Bu dosyayı kullanan dosyalar:` route `/map`, `home_screen.dart`, `web_header.dart`, `list_detail_page.dart`, `product_search_result_page.dart`, `visual_intelligence_result_page.dart`.
- `Değişirse etkilenecek yerler:` store proximity, harita arama, business detail yönlendirmeleri.
- `Risk notu:` canlı konum sync ve bildirim mantığı mevcut; yan etki alanı yalnız UI değil. Konum izni/konum okuma `LocationAccessService` üzerinden tekilleştirildi; IndexedStack + push edilen ikinci `MapPage` izin yarışı bu katmanda engellenir. Geri butonu: desktop geniş layout veya `product != null` ile push edilmiş yakın lokasyon akışında (`Navigator.canPop`) gösterilir; standalone harita sekmesinde mobilde gizli kalır.
- `Durum:` kısmi

## `ibul_app/lib/screens/seller_login_page.dart`

- `Dosya yolu:` `ibul_app/lib/screens/seller_login_page.dart`
- `Amaç:` seller/admin oturum açma ekranı; role göre `/seller` veya `/admin` yönlendirir.
- `Bağlı olduğu dosyalar:` `AuthService`, `AdminPanelPage`, `SellerPanelPage`, `become_seller_page.dart`.
- `Bu dosyayı kullanan dosyalar:` `lib/main_seller.dart`, named route `/seller-login`.
- `Değişirse etkilenecek yerler:` seller desktop giriş, admin mode giriş, session backup/restore akışı.
- `Risk notu:` yanlış role handling seller ve admin yetki ayrımını bozar. macOS sandbox’ta Keychain entitlement yoksa `AuthService.clearSellerSwitchBackup()` → `SecureLocalStore.delete()` patlayabilir; login catch bloğu ikinci kez aynı cleanup’ı çağırırsa gerçek auth hatası SnackBar’a ulaşmadan unhandled exception olur. `SecureLocalStore` Keychain hatasında SharedPreferences fallback kullanır; macOS entitlements’a `keychain-access-groups` eklenmelidir.
- `Durum:` net

## `ibul_app/lib/screens/seller_panel_page.dart`

- `Dosya yolu:` `ibul_app/lib/screens/seller_panel_page.dart`
- `Amaç:` seller paneli ve garson operasyonlarının ana mega ekranı; dashboard, sipariş, finans, mutfak baskı, ürün yönetimi, masa işlemleri.
- `Bağlı olduğu dosyalar:` `StoreService`, `AuthService`, `OrderService`, `SupportService`, `CampaignService`, `OrderPrintJobService`, `DesktopPrintOrchestrator`, `DesktopPrintHub`, `PrintStationService`, `LocalPrintService`, `SellerDashboardService`, `SellerWalletService`, çok sayıda widget/model/helper ve `part` modülleri.
- `Bu dosyayı kullanan dosyalar:` `lib/main.dart`, `lib/main_seller.dart`, `seller_login_page.dart`, route `/seller`.
- `Değişirse etkilenecek yerler:` seller dashboard, waiter flow, kitchen printing, product ops, finance tabs, support modülleri.
- `Risk notu:` Repodaki en yüksek etki alanlı dosyalardan biri; özellikle garson masa kapatma / hesap kes akışında kullanılan `sellerId` restoran owner kimliğiyle eşleşmezse `table_order_history` yanlış kimlik altında arşivlenebilir ve restart sonrası dashboard/finance `₺0` görünebilir. Ayrıca `ensureTableHistoryRecorded` hataları yutulursa optimistic gelir görünür ama kalıcı history yazılmamış olabilir. Yeni bootstrap akışında owner restore + seller-scoped cache hydrate tamamlanmadan final dashboard/finance state kurulmamaya dikkat edilmeli.
- `Durum:` net

## `ibul_app/lib/screens/seller_panel_finance_modules.dart`

- `Dosya yolu:` `ibul_app/lib/screens/seller_panel_finance_modules.dart`
- `Amaç:` Seller panel içinden finans kabuğunu doğru `sellerId` ve optimistic closed-history ile ayağa kaldırır.
- `Bağlı olduğu dosyalar:` `seller_panel_page.dart`, `features/seller/finance/screens/finance_shell.dart`
- `Bu dosyayı kullanan dosyalar:` `seller_panel_page.dart`
- `Değişirse etkilenecek yerler:` Finans provider oluşturma, restart sonrası doğru owner kimliğiyle finance reload.
- `Risk notu:` `FinanceShell` anahtarı owner `sellerId` değişimini yansıtmazsa provider eski auth fallback UID ile yaşamaya devam eder ve finans verileri aç-kapa sonrası `₺0` görünebilir. Ayrıca owner bootstrap tamamlanmadan shell oluşturulursa cached optimistic history kullanılmadan 0-state render görülebilir.
- `Durum:` net

## `ibul_app/lib/screens/seller_panel_orders_modules.dart`

- `Dosya yolu:` `ibul_app/lib/screens/seller_panel_orders_modules.dart`
- `Amaç:` Seller panel içindeki Siparişler modülünün desktop/mobile liste kabuğu; arama, filtre chip’leri, KPI kartları ve sipariş kartlarını `seller_panel_page.dart` içindeki state/helpers ile render eder.
- `Bağlı olduğu dosyalar:` `seller_panel_page.dart`, `services/order_service.dart`
- `Bu dosyayı kullanan dosyalar:` `seller_panel_page.dart`
- `Değişirse etkilenecek yerler:` seller Siparişler ekranı liste veri kümesi, üst sayaçlar, sipariş kart başlıkları ve detail sayfasına geçiş davranışı.
- `Risk notu:` Restoran / yemek mağazalarında bu modül yalnız online siparişleri göstermeli; `table` / `waiter` kaynaklı kayıtlar Garson akışında kalmalı. Dashboard **Son Siparişler** kartı da aynı `_sellerOrdersVisibleInOrdersModule()` kümesini kullanır; kapalı masa geçmişi (`_dashboardClosedHistory`) yalnız ciro/KPI hesabında kalır, Son Siparişler / Siparişler listesine karışmaz.
- `Durum:` net

## `restaurant-ops-web/src/features/restaurant/app/WaiterRouteScreen.tsx`

- `Dosya yolu:` `restaurant-ops-web/src/features/restaurant/app/WaiterRouteScreen.tsx`
- `Amaç:` server tarafında repository’den snapshot çekip client waiter app’e başlangıç state’i verir.
- `Bağlı olduğu dosyalar:` `components/RestaurantWaiterApp.tsx`, `server/repository.ts`.
- `Bu dosyayı kullanan dosyalar:` `src/app/waiter/page.tsx`, `src/app/waiter/tables/[tableId]/page.tsx`.
- `Değişirse etkilenecek yerler:` waiter initial SSR hydration, masa seçili açılış.
- `Risk notu:` Server snapshot fetch bozulursa tüm waiter UI başlangıçta düşer.
- `Durum:` net

## `restaurant-ops-web/src/components/RestaurantWaiterApp.tsx`

- `Dosya yolu:` `restaurant-ops-web/src/components/RestaurantWaiterApp.tsx`
- `Amaç:` waiter operasyon UI’sinin ana container’ı.
- `Bağlı olduğu dosyalar:` `WaiterStoreProvider`, orders/operations/products/tables/customer/ui bileşenleri.
- `Bu dosyayı kullanan dosyalar:` `WaiterRouteScreen.tsx`.
- `Değişirse etkilenecek yerler:` waiter ekran akışı, drawer/modaller, optimistic action tetikleyicileri.
- `Risk notu:` Dosyanın detayları bu turda tam okunmadı; component içi alt akışlar kısmi doğrulandı.
- `Durum:` kısmi

## `restaurant-ops-web/src/state/waiter-store.tsx`

- `Dosya yolu:` `restaurant-ops-web/src/state/waiter-store.tsx`
- `Amaç:` optimistic reducer uygulaması, rollback, retry ve snapshot refresh state store’u.
- `Bağlı olduğu dosyalar:` domain `commands`, `errors`, `model`, `reducer`, client adapter factory, `lib/mock-data`, `lib/utils`.
- `Bu dosyayı kullanan dosyalar:` `RestaurantWaiterApp.tsx`.
- `Değişirse etkilenecek yerler:` client mutation davranışı, dirty state, retry, conflict yönetimi.
- `Risk notu:` React concurrency ile optimistic update birleşiyor; hatalar kullanıcı durum kaybına yol açabilir.
- `Durum:` net

## `restaurant-ops-web/src/features/restaurant/server/repository.ts`

- `Dosya yolu:` `restaurant-ops-web/src/features/restaurant/server/repository.ts`
- `Amaç:` server tarafında `mock` veya `supabase` repository seçimi yapar.
- `Bağlı olduğu dosyalar:` `MockRestaurantRepository`, `createSupabaseAdminClient`, `SupabaseRestaurantRepository`.
- `Bu dosyayı kullanan dosyalar:` waiter pages, API routes, admin printer jobs route, server actions.
- `Değişirse etkilenecek yerler:` tüm Next.js backend data source yönlendirmesi.
- `Risk notu:` env yanlışsa prod benzeri modda hard fail üretir.
- `Durum:` net

## `restaurant-ops-web/src/features/restaurant/data/supabase/client.ts`

- `Dosya yolu:` `restaurant-ops-web/src/features/restaurant/data/supabase/client.ts`
- `Amaç:` service role ile Supabase admin client oluşturur ve cache’ler.
- `Bağlı olduğu dosyalar:` `@supabase/supabase-js`, generated `database.types`.
- `Bu dosyayı kullanan dosyalar:` `server/repository.ts`.
- `Değişirse etkilenecek yerler:` Supabase repository modu, API route veri erişimi.
- `Risk notu:` Service role key zorunlu; yanlış kullanım yüksek yetki riski taşır.
- `Durum:` net

## `restaurant-ops-web/src/features/restaurant/data/supabase/supabase-repository.ts`

- `Dosya yolu:` `restaurant-ops-web/src/features/restaurant/data/supabase/supabase-repository.ts`
- `Amaç:` `restaurant` schema snapshot ve RPC mutation’larını uygular.
- `Bağlı olduğu dosyalar:` `database.types`, domain commands/errors, `buildSnapshotFromSupabaseRows`.
- `Bu dosyayı kullanan dosyalar:` `server/repository.ts`.
- `Değişirse etkilenecek yerler:` snapshot doğruluğu, RPC mapping, conflict handling.
- `Risk notu:` `RESTAURANT_VENUE_ID` ve schema isimlerine sıkı bağlı.
- `Durum:` net

## `restaurant-ops-web/src/features/restaurant/data/client/api-adapter.ts`

- `Dosya yolu:` `restaurant-ops-web/src/features/restaurant/data/client/api-adapter.ts`
- `Amaç:` browser tarafında `/api/restaurant/snapshot` ve `/api/restaurant/commands` çağrılarını yapar.
- `Bağlı olduğu dosyalar:` domain commands/errors, shared repository arayüzü.
- `Bu dosyayı kullanan dosyalar:` `data/client/index.ts`, dolaylı olarak `waiter-store.tsx`.
- `Değişirse etkilenecek yerler:` waiter frontend runtime, error->runtime error dönüşümü.
- `Risk notu:` Response shape değişirse optimistic store zinciri kırılır.
- `Durum:` net

## `local_print_bridge/config.py`

- `Dosya yolu:` `local_print_bridge/config.py`
- `Amaç:` bridge env yükleme, allowed origins, encoding/codepage profili, `BridgeSettings`.
- `Bağlı olduğu dosyalar:` `runtime_paths.py`, process env.
- `Bu dosyayı kullanan dosyalar:` `server.py`, `print_station.py`, `receipt.py`, `kitchen.py`, `raster.py`, `transport.py`, testler.
- `Değişirse etkilenecek yerler:` CORS, ESC/POS encoding, render mode, transport seçimi, env persistence.
- `Risk notu:` Türkçe karakter baskısı ve CORS davranışı burada hassas.
- `Durum:` net

## `local_print_bridge/server.py`

- `Dosya yolu:` `local_print_bridge/server.py`
- `Amaç:` bridge HTTP API, printer discovery, test/receipt/kitchen dispatch, diagnostics, settings reload.
- `Bağlı olduğu dosyalar:` `config.py`, `diagnostics.py`, `document.py`, `kitchen.py`, `log_store.py`, `models.py`, `network_transport.py`, `printers.py`, `queue_autoselect.py`, `pillow_probe.py`, `print_station.py`, `queue_manager.py`, `raster.py`, `receipt.py`, `runtime_paths.py`, `transport.py`, `usb_transport.py`, `windows_transport.py`.
- `Bu dosyayı kullanan dosyalar:` `__main__.py`, seller desktop/client üzerinden `LocalPrintService`, Python testleri.
- `Değişirse etkilenecek yerler:` tüm local print HTTP contract’ı, setup/warmup, Windows/macOS/network transport davranışı.
- `Risk notu:` Büyük ve çok sorumluluklu; farklı OS path’leri tek dosyada birleşiyor.
- `Durum:` net

## `local_print_bridge/print_station.py`

- `Dosya yolu:` `local_print_bridge/print_station.py`
- `Amaç:` Supabase tabanlı print station consumer, heartbeat, job claim/retry, idempotency.
- `Bağlı olduğu dosyalar:` `BridgeSettings`, `KitchenRenderer`, `PrintLogStore`, `QueueManager`, `RasterEscPosEncoder`, `ReceiptRenderer`.
- `Bu dosyayı kullanan dosyalar:` `server.py`.
- `Değişirse etkilenecek yerler:` restaurant-side auto print istasyonu, claimed/completed job mantığı.
- `Risk notu:` duplicate dispatch önleme için karmaşık state tutuyor.
- `Durum:` net

## `ihiz_web/lib/main.dart`

- `Dosya yolu:` `ihiz_web/lib/main.dart`
- `Amaç:` İhız kurye web uygulamasını başlatır; pricing config’i çeker, auth state’i dinler, landing/login flow sunar.
- `Bağlı olduğu dosyalar:` `src/config/ihiz_runtime_config.dart`, `src/sections/ihiz_login_marketing_section.dart`, `src/widgets/ihiz_landing_widgets.dart`, `src/widgets/ihiz_marketing_chrome.dart`, `part` modelleri.
- `Bu dosyayı kullanan dosyalar:` Flutter web runtime, `ihiz_web` build/run script’leri.
- `Değişirse etkilenecek yerler:` courier onboarding, pricing config sync, session restore.
- `Risk notu:` Tek dosyada yoğun UI + state var; parçalı yapı `part` ile dağıtılmış.
- `Durum:` kısmi

## `ihiz_web/lib/src/config/ihiz_runtime_config.dart`

- `Dosya yolu:` `ihiz_web/lib/src/config/ihiz_runtime_config.dart`
- `Amaç:` `IHIZ_SUPABASE_URL` ve `IHIZ_SUPABASE_ANON_KEY` doğrulaması.
- `Bağlı olduğu dosyalar:` environment dart-define.
- `Bu dosyayı kullanan dosyalar:` `ihiz_web/lib/main.dart`.
- `Değişirse etkilenecek yerler:` kurye web açılışı.
- `Risk notu:` Eksik env olduğunda hard fail.
- `Durum:` net

## `scripts/run.sh`

- `Dosya yolu:` `scripts/run.sh`
- `Amaç:` kök Flutter uygulamasını `.env` yükleyerek cihaz seçimiyle çalıştırır.
- `Bağlı olduğu dosyalar:` `.env`, `flutter devices`, kök `lib/main.dart`.
- `Bu dosyayı kullanan dosyalar:` geliştirici lokal çalışma akışı.
- `Değişirse etkilenecek yerler:` consumer/dev run ergonomisi.
- `Risk notu:` Bash içi JSON parse için `python3` çağırıyor.
- `Durum:` net

## `scripts/run_seller_desktop.sh`

- `Dosya yolu:` `scripts/run_seller_desktop.sh`
- `Amaç:` seller desktop için `.env` yükler ve `lib/main_seller.dart` target’ını çalıştırır.
- `Bağlı olduğu dosyalar:` `.env`, Flutter macOS target, runtime config define’ları.
- `Bu dosyayı kullanan dosyalar:` seller desktop geliştirme akışı.
- `Değişirse etkilenecek yerler:` seller desktop local boot.
- `Risk notu:` Eksik env’de çalışmaz; backward-compatible alias mantığı içeriyor.
- `Durum:` net

# Data Flow

## Consumer app veri akışı

1. `lib/main.dart` veya `ibul_app/lib/main.dart` başlar.
2. `initializeAppSupabase()` ile Supabase bağlanır.
3. `buildAppProviders()` global singleton/provider karışımını kurar.
4. `HomeScreen`, `MapPage`, `BusinessDetailPage` gibi UI katmanları `StoreService`, `OrderService`, `AuthService` gibi servisleri çağırır.
5. Servisler çoğunlukla `Supabase.instance.client` üzerinden `stores`, `products`, `orders`, `profiles`, `table_orders` benzeri tablolara gider.
6. Sonuçlar widget state, `AppState` veya ekran içi cache’lere yazılır.

## QR masa sipariş akışı

1. URL `/qr?...` ile açılır.
2. `QrInitialParams.captureFromUri()` başlangıçta query’yi yakalar.
3. `QrEntryScreen` `appServicesReady` sonrası `StoreService.resolveStoreTableQr()` ve `getBusinessSummaryBySellerId()` çağırır.
4. Başarılıysa `BusinessDetailPage` açılır.
5. `BusinessDetailPage` masa zorlamalı sipariş diyalog akışını başlatır.
6. Doğrulanmamış QR durumunda `WaiterOrderRequestService` üzerinden garson onaylı akış devreye girebilir.

## Seller / waiter / print akışı

1. Seller login `AuthService.resolveLoginRoute()` ile rol çözer.
2. `/seller` route’u `SellerPanelPage` açar.
3. Seller panel sipariş/masa/mutfak işlemlerinde `StoreService`, `OrderService`, `OrderPrintJobService`, `SellerDashboardService` kullanır.
4. Direct local print gerekiyorsa `LocalPrintService` ile localhost bridge çağrılır.
5. Desktop sürekli dinleme gerekiyorsa `DesktopPrintHub` Supabase realtime veya pending sweep ile job claim eder.
6. Bridge tarafında `local_print_bridge/server.py` baskıyı OS transport’una iletir.

## Restaurant ops web veri akışı

1. `WaiterRouteScreen` server-side snapshot alır.
2. `RestaurantWaiterApp` bu snapshot ile client tarafında açılır.
3. `WaiterStoreProvider` local mutation’ı reducer ile uygular.
4. `ApiRestaurantClientAdapter` `/api/restaurant/commands` çağrısı yapar.
5. Server route `getRestaurantServerRepository()` ile mock veya Supabase repository seçer.
6. Supabase modunda `SupabaseRestaurantRepository` RPC/table update yapar.
7. Son snapshot geri dönerek optimistic state’i canonical state ile eşitler.

# API / Service Connections

## Supabase bağlantıları

- Kök Flutter ve `ibul_app`:
  - `IBUL_SUPABASE_URL`
  - `IBUL_SUPABASE_ANON_KEY`
- `ihiz_web`:
  - `IHIZ_SUPABASE_URL`
  - `IHIZ_SUPABASE_ANON_KEY`
- `restaurant-ops-web`:
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `RESTAURANT_VENUE_ID`
- `local_print_bridge` print station:
  - `.env` tabanlı `PRINT_STATION_*` değişkenleri

## Local HTTP servisleri

- `LocalPrintService` varsayılan olarak `http://127.0.0.1:3001` konuşur.
- `local_print_bridge/server.py` şu yüzeyleri sağlar:
  - `GET /health`
  - `GET /printers`
  - `POST /print`
  - `POST /print/receipt`
  - `POST /print/kitchen`
  - `POST /print/test`
  - `POST /configure`
  - `POST /setup`
  - ek warmup/spool/diagnostics route’ları da mevcut görünüyor
- `server.js` ve `app.py` benzer ama daha eski yerel print çözümleri gibi duruyor; aktif üretim yolu olup olmadığı doğrulanmalı.

## Firebase bağlantıları

- `ibul_app/lib/main.dart` yalnız web dışı platformlarda Firebase initialize eder.
- Push bildirimi `PushNotificationService` ile bağlanır.
- Kök `.env.example` Firebase web/android/iOS/macOS alanlarını listeler.

# State Management / Context / Store

## Flutter tarafı

- Ana desen `provider`.
- `AppState`, `CartState`, `FavoriteState`, `ReviewState` singleton eğilimli `ChangeNotifier` yapıları.
- `CartState`: sepet ürün listesi + `CartTabKind` ile Alışveriş/Market/Yemek sınıflandırması; `AppState.cartCountForTab` ve alt nav `cartCountNotifier` aynı listeyi okur.
- `buildAppProviders()` bunları provider ağacına ekler.
- Ekran içi `StatefulWidget` cache’leri çok yaygın; state tamamen merkezi değil.
- `ConnectivityProvider`, `CartProvider`, `DesktopPrintHub` gibi ek notifier’lar var.

## Restaurant ops web

- React context + custom store deseni.
- `WaiterStoreProvider` canonical snapshot ile optimistic snapshot’ı ayrı tutar.
- `pendingMutationIds`, `dirtyTableIds`, `lastError`, `lastFailedMutation` gibi runtime alanlar mevcut.
- Mock ve API adapter modları environment ile seçilir.

# Config and Environment

## Kök `.env.example`

- IBUL Supabase
- Google OAuth
- Firebase web/mobile/desktop alanları
- seller installer URL override’ları
- IHIZ Supabase
- test placeholder değerleri

## Diğer config dosyaları

| Dosya | Etki alanı |
| --- | --- |
| `pubspec.yaml` | Kök Flutter uygulaması, path dependency olarak `ibul_app` |
| `ibul_app/pubspec.yaml` | Asıl Flutter bağımlılıkları ve asset tanımları |
| `ihiz_web/pubspec.yaml` | Kurye web bağımlılıkları |
| `restaurant-ops-web/package.json` | Next.js modülü bağımlılıkları |
| `firebase.json` | Flutter web hosting cache/SPA rewrite ayarları |
| `vercel.json` | SPA rewrite; muhtemelen alternatif deploy yüzeyi |
| `analysis_options.yaml` | Flutter/Dart lint ayarları |
| `restaurant-ops-web/tailwind.config.ts` | Waiter web UI stil sistemi |
| `local_print_bridge/.env.example` | Bridge/print station ayarları |
| `macos/Podfile`, `ios/Podfile` | Native Flutter platform bağımlılıkları |

# Shared Utilities

## Flutter ortak yardımcılar

- `ibul_app/lib/core/qr_initial_params.dart`
  - QR deep-link capture/consume davranışı.
- `ibul_app/lib/core/route_observer.dart`
  - global route gözlemi.
- `ibul_app/lib/core/web_seo*.dart`
  - web SEO/stub ayrımı.
- `ibul_app/lib/utils/order_status_constants.dart`
  - sipariş ve admin onay durum sabitleri; switch-case kullanan seller/admin ekranları için const kaynak. `isInTransitShipmentStatus` müşteri tarafında kargo takip görünürlüğü için kullanılır (`shipped`, `transfer`, `branch`, `out_for_delivery`).
- `ibul_app/lib/services/store/table_order_history_utils.dart`
  - `table_order_history` satırlarından kapanış zamanı, gelir ve masa etiketi türeten ortak helper.
- `ibul_app/lib/services/store/table_close_history_fallback.dart`
  - garson masa kapanışında duplicate archive kontrolü ve fallback insert planı üretir.
- `ibul_app/lib/features/seller/finance/helpers/today_income_builder.dart`
  - finance repository için günlük gelir breakdown ve kapanmış masa ciro toplamı yardımcıları.
- `ibul_app/lib/utils/table_labels.dart`
  - masa etiketi üretimi.
- `ibul_app/lib/widgets/skeleton_loading.dart`
  - `SkeletonLoading` shimmer primitive + `ProductCardSkeleton`; arama/ana sayfa grid loading kartları. `tight` modu arama sonuç grid'i ile hizalı constraint-aware layout kullanır.
- `ibul_app/lib/widgets/web_sticky_footer_scroll_view.dart`
  - Web hesap/checkout/sepet/home sayfalarında paylaşılan scroll + sticky footer layout. `footerReserve` yalnız ölçülen footer slot yüksekliği (gap çift sayılmaz); body `minHeight = viewport − footerReserve`; `WebStickyFooterBodyScope` ile alt içerik alanına body yüksekliği iletilir.
- `ibul_app/lib/core/store_logo_helper.dart`
  - store logo çözümleme.

## Restaurant ops ortak yardımcılar

- `restaurant-ops-web/src/lib/types.ts`
  - paylaşılan TS tipleri.
- `restaurant-ops-web/src/lib/utils.ts`
  - `makeId` benzeri ortak yardımcılar.
- `restaurant-ops-web/src/lib/mock-data.ts`
  - mock başlangıç snapshot üretimi.

## Print bridge ortak yardımcılar

- `local_print_bridge/raster.py`
  - bitmap render ve ESC/POS encoder.
- `local_print_bridge/receipt.py`
  - receipt render.
- `local_print_bridge/kitchen.py`
  - mutfak ticket render.
- `local_print_bridge/printers.py`
  - printer discovery/normalization.

# Change Impact Rules

1. `runtime_config` veya `.env` alanlarını değiştirirken:
   - `lib/main.dart`, `lib/main_seller.dart`, `ibul_app/lib/main.dart`, `scripts/run*.sh`, deploy dokümanları birlikte kontrol edilmeli.
2. `app_bootstrap.dart` provider listesini değiştirirken:
   - QR fast-path, seller desktop ve home route tekrar test edilmeli.
3. `store_service.dart` veya `store_table_service.dart` değiştirirken:
   - `HomeScreen`, `MapPage`, `BusinessDetailPage`, `QrEntryScreen`, `SellerPanelPage` etkilenir.
4. `order_service.dart` değiştirirken:
   - checkout, order detail, seller order listesi ve ilgili testler kontrol edilmeli.
5. `seller_panel_page.dart` değiştirirken:
   - print setup, garson modülü, dashboard, finance ve kitchen ekranları çapraz etkilenir.
   - özellikle garson kapanış akışında owner `sellerId` çözümlemesi doğrulanmalı; auth fallback UID ile arşivleme restart sonrası gelir kaybı gibi görünür.
   - `ensureTableHistoryRecorded` benzeri history doğrulama hataları sessizce yutulmamalı; aksi halde sadece optimistic gelir görünür.
   - persist edilmiş owner `sellerId` restore olunca store profile + closed history yeniden yüklenmeli; ilk build yanlış auth UID ile yapıldıysa tek başına `setState` yeterli olmayabilir.
   - seller-scoped dashboard/finance cache hydrate edilmeden dashboard/finance final state’i kurulursa restart sonrası geçici `₺0` render oluşabilir.
6. `local_print_service.dart` veya `local_print_bridge/server.py` değiştirirken:
   - hem Flutter UI hata mesajları hem OS-level yazdırma yolu etkilenir.
7. `restaurant-ops-web` repository veya command route değiştirirken:
   - optimistic store rollback, conflict ve snapshot response shape birlikte düşünülmeli.
8. `SUPABASE_*.sql` dosyası ekler/değiştirirken:
   - ilgili servis metodunun gerçekten yeni kolon/RPC/policy ile uyumlu olup olmadığı kontrol edilmeli.
9. Restart sonrası dashboard/finance sıfırlanıyor ama aynı oturumda optimistic gelir görünüyorsa:
   - önce `table_order_history.seller_id` değerlerinin gerçekten `stores.seller_id` owner kimliğiyle eşleştiği doğrulanmalı.
   - gerekirse `SUPABASE_DIAGNOSE_TABLE_HISTORY_OWNER_IDS.sql` ile yanlış waiter/sub-admin UID altında kalmış geçmiş kayıtlar raporlanmalı.
   - prod şemada `archived_at` doğrulanmadan kullanılmamalı; mevcut teşhis sorguları `closed_at` / `created_at` ile çalıştırılmalı.
   - uygulama tarafında `table_order_history` sorguları `archived_at` eksikse `closed_at`-only fallback ile çalışmalı; aksi halde reload catch bloğuna düşüp finance/dashboard `0` görünebilir.
   - başarılı close sonrası `table_order_history` tabanlı closed-history sellerId bazlı cache’e de yazılmalı; startup’ta önce bu cache yüklenip sonra network refresh yapılmalı.
   - refresh boş/başarısız dönerse mevcut cache ezilmemeli; son geçerli closed-history state korunmalı.

# Known Uncertainties

- `server.js` ve `app.py` dosyalarının halen aktif kullanımda mı yoksa legacy mi olduğu kesin değil.
- Kök Flutter uygulaması ile `ibul_app/lib/main.dart` arasındaki fiili deploy ayrımı tam net değil; ikisi de benzer ama aynı olmayan bootstrap kodu taşıyor.
- `ibul_app/lib/screens/seller_panel_page.dart` çok büyük olduğu için tüm alt modül davranışları bu turda satır satır doğrulanmadı.
- `ibul_app/lib/services/store_service.dart` ve `order_service.dart` dosyaları geniş; yalnız ana sorumluluklar ve kullanılan kritik çağrılar doğrulandı.
- Supabase tablo adlarının tamamı tek yerden belgelenmiş değil; ilişki büyük ölçüde servis çağrılarından çıkarıldı.
- Root ve `ibul_app/` altındaki SQL/hotfix dosyalarının uygulama sırası veya hangilerinin prod’a işlendiği belirsiz.
- `restaurant-ops-web` içinde bazı admin printer job route’larının `local_print_bridge` ile tam entegrasyon yönü bu turda detaylı izlenmedi.
- Eski `table_order_history` satırlarının waiter/sub-admin UID altında yazılmış olması halinde owner eşlemesi otomatik geri kazanılamaz; güvenli yaklaşım manuel mapping ile backfill çalıştırmaktır.
- Prod `table_order_history` şemasında `archived_at` kolonu görünmüyor; başka ortamda legacy kolon olup olmadığı doğrulanmalı.

# Security / Quality Audit (2026-06-13)

Kapsamlı repo denetimi: secret yönetimi, AI yüzeyi, auth/RLS, network, performans, log/gizlilik, build güvenliği. Kod değişikliği yapılmadı; yalnız bulgular ve minimum düzeltme planı.

## Denetim kapsamı (okunan kritik yüzeyler)

| Alan | Dosyalar |
| --- | --- |
| Config / env | `.env.example`, `runtime_config.dart`, `ihiz_runtime_config.dart`, `firebase_options.dart`, `local_print_bridge/.env.example`, `restaurant-ops-web/.env.example` |
| Bootstrap | `lib/main.dart`, `lib/main_seller.dart`, `app_bootstrap.dart`, `scripts/run.sh` |
| State | `app_state.dart`, `app_state_auth.dart`, `cart_state.dart`, `auth_service.dart` |
| Network / servis | `supabase_service.dart`, `store_service.dart`, `order_service.dart`, `search_telemetry_service.dart`, edge `functions/_shared/http.ts` |
| Auth / yetki | `auth_service.dart`, `admin_panel_page.dart`, `SUPABASE_SEARCH_TELEMETRY.sql`, `SUPABASE_FIX_GARSON_CLOSE_TABLE.sql`, `SUPABASE_ADMIN_GENERAL_CLEANUP_RPC.sql` |
| Restaurant ops | `restaurant-ops-web/.../commands/route.ts`, `snapshot/route.ts`, `server/repository.ts`, `data/supabase/client.ts` |
| Print / local API | `local_print_service.dart`, `local_print_bridge/config.py`, `server.py` |
| AI (mevcut) | `ai_assistant_service.dart`, `ai_chat_page.dart`, `visual_intelligence_service.dart`, `app_feature_flags.dart` |
| Build / CI | `.github/workflows/firebase-hosting-*.yml`, `firebase.json` |
| Performans adayları | `home_screen.dart`, `seller_panel_page.dart`, `desktop_print_hub.dart`, `search_overlay.dart`, `business_detail_page.dart` |

## Özet risk matrisi

| Öncelik | Sayı | Ana temalar |
| --- | --- | --- |
| P0 | 3 | Restaurant ops API auth yok; search_telemetry global SELECT; CI release dart-define eksik |
| P1 | 8 | Session token SharedPreferences; QR token log; table_orders geniş RLS; print station token env; admin client-only guard |
| P2 | 10+ | user_provider cast; yutulan exception; polling/timer; security header eksik; mega dosyalar |
| P3 | çeşitli | Legacy print server belirsizliği; demo AI flag; test placeholder JWT |

## Minimum güvenli düzeltme sırası (öneri)

1. `SUPABASE_SEARCH_TELEMETRY.sql` — SELECT politikasını admin veya `auth.uid() = user_id` ile sınırla; `delivery_address` insert’te hash/şehir-only yap.
2. `restaurant-ops-web` API route’larına auth (waiter session JWT veya server-only secret header) + mutation allowlist.
3. `.github/workflows/firebase-hosting-*.yml` — GitHub Secrets → `--dart-define` enjeksiyonu; boş config ile deploy engeli.
4. `auth_service.dart` — seller switch session backup → `flutter_secure_storage` (veya en azından refresh token hariç).
5. QR debug logları — `kDebugMode` / `AppFeatureFlags.enableVerboseDebugLogs` arkasına al.
6. Prod Supabase’te `table_orders_authenticated_all` yerine seller/garson scoped policy (SQL Bölüm B) doğrula/uygula.
7. `search_overlay.dart` — global 1500 satır telemetry çekimini kaldır veya admin-only RPC’ye taşı.

## AI API durumu

Gerçek OpenAI/Anthropic/Gemini çağrısı **yok**. `AiAssistantService` ve `VisualIntelligenceService` demo/keyword placeholder. `use_ai_suggestions` yalnız ads veri alanı. Gelecek entegrasyon için: server-side proxy, rate limit, prompt izolasyonu, output validation zorunlu.

## Secret envanteri (beklenen client-safe vs server-only)

| Secret | Beklenen konum | Repo durumu |
| --- | --- | --- |
| `IBUL_SUPABASE_ANON_KEY` | Client dart-define | `.env.example` placeholder; CI’da inject eksik |
| `SUPABASE_SERVICE_ROLE_KEY` | Server only | `restaurant-ops-web`, edge functions, Firebase functions — client’ta yok ✓ |
| Firebase API keys | Client (kısıtlı) | `firebase_options.dart` dart-define; git’te ✓ (kısıtlama Firebase console’da olmalı) |
| `PRINT_STATION_*_TOKEN` | Local bridge `.env` | `.env.example`’da; gitignore altında; rotation önerilir |
| Session JWT backup | Cihaz secure store | SharedPreferences’ta — iyileştirme gerekli |

# Security / Quality Audit (2026-06-13, post-patch yenileme)

Önceki turda P0/P1 patch seti uygulandı (bkz. Update Log). Bu bölüm **güncel kod + kalan riskleri** yansıtır.

## Kapatılan / iyileştirilen (kod tarafı)

| Alan | Durum |
| --- | --- |
| restaurant-ops API | `server-action` varsayılan; HTTP route’lar `RESTAURANT_API_SECRET` guard |
| search_telemetry Dart | Tam `delivery_address` insert kaldırıldı; overlay telemetry fetch kaldırıldı |
| CI web build | `scripts/build_web_ci.sh` + GitHub Secrets dart-define |
| Session backup | `SecureLocalStore` (seller switch JWT); macOS Keychain hatasında SharedPreferences fallback |
| Hassas device cache | `addresses` / `savedCards` secure storage + legacy migrate |
| QR token log | `kDebugMode` + `maskSensitiveToken` |
| Print hub sweep | 300ms → 1000ms |

## Açık / prod doğrulama gerektiren

| Öncelik | Bulgu | Not |
| --- | --- | --- |
| P0* | `SUPABASE_FIX_SEARCH_TELEMETRY_RLS.sql` prod’da uygulanmadıysa eski global SELECT devam eder | *Deployment gap |
| P0* | `table_orders_authenticated_all` + `table_order_history_authenticated` (`using true`) prod’da aktifse IDOR | *SQL policy |
| P1 | `user_provider.dart` adres hydrate `Map<String,String>.from` crash riski | `app_state_auth` düzeltilmiş, provider değil |
| P1 | `device_cache_current_delivery_address_v1` hâlâ SharedPreferences | secure storage’a taşınmadı |
| P1 | Admin `/admin` route yalnız client guard | RPC/RLS’ye bağımlı |
| P2 | `google_generative_ai` pubspec’te var, kodda kullanım yok | Gelecek AI entegrasyon riski |
| P2 | `enableDemoAiAssistant` release’te `true` | Yanıltıcı UX |
| P2 | `firebase.json` CSP/HSTS yok | Web hardening eksik |
| P2 | `home_screen.dart` init waterfall + `Timer.periodic` + `IndexedStack` | Ana sayfa perf |

## Performans darboğazları (dosya bazlı, güncel)

1. `home_screen.dart` — paralel cache+network init, banner timer, tüm sekmeler `IndexedStack`’te canlı
2. `seller_panel_page.dart` — çok büyük monolith; bootstrap/owner restore zinciri
3. `business_detail_page.dart` — menü+kampanya+table order tek dosyada
4. `desktop_print_hub.dart` — 1s sweep + realtime + health timer (iyileştirildi ama hâlâ aktif)
5. `app_state.dart` — geniş `notifyListeners` yüzeyi
6. `map_page.dart` — konum + proximity polling

## Minimum kalan düzeltme planı

1. Prod Supabase: `SUPABASE_FIX_SEARCH_TELEMETRY_RLS.sql` uygula + doğrula
2. Prod Supabase: `table_orders` / `table_order_history` policy audit; Bölüm B (seller/garson scoped) geç
3. `user_provider.dart`: `readStringMap` ile adres hydrate
4. `app_state.dart`: current delivery address → secure storage
5. `app_feature_flags.dart`: demo AI/visual flags → `kReleaseMode` veya dart-define
6. `firebase.json`: CSP + HSTS header ekle

# Update Log

## 2026-06-13 (home web kategori — footer reserve + main slot fill)

- **Kök neden (2 parça):** (1) `WebStickyFooterScrollView` footer reserve hesabında `contentFooterGap` slot ölçümüne ekleniyordu → toplam scroll yüksekliği viewport'tan kısa kalıyor, footer gerçek alt kenara oturmuyordu. (2) Home web kategori görünümünde (`home_screen_sections.dart`) ana içerik (Teknoloji Dünyası / empty state) doğal/kısa yükseklikte kalıyordu; body slot dolsa bile orta alan genişlemiyordu.
- `web_sticky_footer_scroll_view.dart`: `footerReserve = _footerSlotHeight` (çift gap sayımı kaldırıldı); `WebStickyFooterBodyScope` eklendi.
- `home_screen_sections.dart`: web sticky footer `contentAlignment: topCenter`; `_wrapWebCategoryMainSlot` ile kısa/boş kategori ana alanı body yüksekliğine göre büyütülüp empty state near-center hizalanır; dolu grid'de expand kapalı.

## 2026-06-13 (home web kategori — sticky footer bağlantısı)

- **Kök neden:** Boş kategori/marka web ekranı (`home_screen_sections.dart` → `_buildWebHomeContentImpl`) `WebStickyFooterScrollView` kullanmıyordu; `SingleChildScrollView` + inline `WebFooter` ile içerik doğal yükseklikte kalıyor, footer viewport altına oturmuyordu. `Teknoloji Dünyası` kartı ve 200px empty state sabit yükseklikte olması sorunu tetikliyordu ama asıl eksik ortak sticky footer wrapper'dı.
- `home_screen_sections.dart`: web scroll → `WebStickyFooterScrollView`; inline `WebFooter` + kategori branch `SizedBox(80)` kaldırıldı.
- `category_products_page.dart` web footer kullanmıyor (mobil header); bu bug owner'ı home web kategori akışı.

## 2026-06-13 (web sticky footer — boş ekran body dengeleme)

- **Kök neden:** İlk sticky footer fix'inde `MainAxisAlignment.spaceBetween` footer'ı alta itiyordu ama content bloğunu üstte pinliyordu; boşluk body içinde dağılmıyor, içerik–footer arasında dengesiz gap oluşuyordu.
- `web_sticky_footer_scroll_view.dart`: `spaceBetween` kaldırıldı → body slot (`minHeight = viewport − footerReserve`) + footer ayrı kolon; kısa içerik `Align(0, -0.1)` ile header'a saygılı near-center; footer slot yüksekliği ölçülerek body reserve güncellenir. Sayfa dosyalarına dokunulmadı.

## 2026-06-13 (web sticky footer — boş ekran layout)

- **Kök neden:** Hesap alt sayfalarında `WebFooter`, `ConstrainedBox(minHeight: viewport)` dışında ayrı `Column` child olarak duruyordu; kısa/boş içerikte footer viewport altına sabitlenmiyor, içeriğin hemen altında kalıyordu.
- `ibul_app/lib/widgets/web_sticky_footer_scroll_view.dart` eklendi: ortak scroll layout — footer içerik ile aynı min-height kolonunda, `spaceBetween` + `contentFooterGap` (varsayılan 32px) ile alta itilir; uzun içerikte scroll davranışı değişmez.
- Web görünümü taşıyan sayfalar ortak layout'a geçirildi: `account_page`, `favorites_page`, `reviews_page`, `orders_page`, `order_detail_page`, `list_detail_page`, `coupons_page`, `addresses_page`, `followed_stores_page`, `settings_page`, `cart_page`, `order_confirmation_page`. Checkout sol kolon scroll yapısı dokunulmadı; ana sayfa web akışı sonraki turda bağlandı (bkz. home web kategori sticky footer).

## 2026-06-13 (Firebase Hosting security headers)

- Kök `firebase.json`: tüm yanıtlar için HSTS, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`, baseline CSP eklendi (`source: **`).
- CSP Flutter web (`unsafe-inline`/`wasm-unsafe-eval`), Supabase (`*.supabase.co` + `wss:`), Firebase/Google APIs, OpenStreetMap tiles/nominatim, Google Sign-In frame için daraltılmış allowlist; mevcut cache header blokları ve SPA `rewrites` korundu.
- Risk notu: `img-src https:` ürün görselleri için geniş; ileride storage host allowlist’e daraltılabilir. `unsafe-eval` CanvasKit uyumluluğu için bilinçli.

## 2026-06-13 (P1/P2 kalan üçlü patch)

- `user_provider.dart`: adres hydrate `readStringMap` ile güvenli normalize (`app_state_auth` parity).
- `app_state.dart` + `app_state_auth.dart`: `device_cache_current_delivery_address_v1` → `SecureLocalStore` (legacy SharedPreferences migrate).
- `app_feature_flags.dart`: demo AI/visual intelligence `!kReleaseMode`; release build’de kapalı.
- `pubspec.yaml`: kullanılmayan `google_generative_ai` bağımlılığı kaldırıldı.

## 2026-06-13 (post-patch audit yenileme)

- Patch sonrası denetim: kapatılan maddeler ve prod deployment gap’leri ayrıldı.
- Kalan P0*: telemetry RLS migration + geniş `table_orders`/`table_order_history` policy prod doğrulaması.
- Kalan P1/P2: user_provider cast, delivery address cache, demo AI flags, firebase headers, home_screen perf.

## 2026-06-13 (P0/P1 security + perf patch set)

- **restaurant-ops-web:** Varsayılan client adapter `server-action` (browser service-role HTTP yok). `/api/restaurant/*` ve `/api/admin/printer-jobs` supabase modunda `RESTAURANT_API_SECRET` + `x-restaurant-api-key` zorunlu (`api-auth.ts`). `.env.example` güncellendi.
- **search_telemetry:** RLS daraltıldı — `search_telemetry_select_own` + `search_telemetry_select_admin`; hotfix `SUPABASE_FIX_SEARCH_TELEMETRY_RLS.sql`. Dart insert artık tam `delivery_address` yazmıyor; `getRecentSearches` limit 200.
- **CI:** `scripts/build_web_ci.sh` + Firebase workflow’larda zorunlu `--dart-define` secret injection.
- **Flutter secure storage:** `secure_local_store.dart`; seller session backup + device `addresses`/`savedCards` cache taşındı; legacy SharedPreferences otomatik migrate.
- **Log privacy:** `log_mask_helpers.dart`; QR token logları `kDebugMode` + maskeleme (`home_screen`, `qr_entry_screen`).
- **Perf:** `search_overlay` global telemetry fetch kaldırıldı; `desktop_print_hub` pending sweep 300ms → 1000ms.

## 2026-06-13 (repo güvenlik / kalite audit)

- Kapsamlı denetim tamamlandı: P0/P1 bulgular, performans top-10, secret/AI/auth/network/log analizi.
- Kritik: `restaurant-ops-web` `/api/restaurant/*` auth’suz + service role backend; `search_telemetry` authenticated global SELECT; Firebase CI `flutter build web` dart-define’sız.
- AI: gerçek LLM entegrasyonu yok; demo assistant/visual intelligence.
- Minimum düzeltme planı ve denetim kapsamı tablosu eklendi.

## 2026-06-13 (ürün detay satıcı logosu + sepet chip iki satır)

- **Kök neden (ürün detay):** `ProductDetailViewModel.loadStoreLogo` yalnız `getStoreLogoUrlByBusinessName` kullanıyordu; `storeName` null iken `'Teknosa'` fallback → yanlış lookup + harf `T`. `_buildStoreLogo` asset’i remote URL’den önce seçiyordu; `OptimizedImage` boyutsuzdu.
- `product_detail_viewmodel.dart`: BDP/cart parity — `sellerId` → `getStorePublicInfoById`, sonra `getStorePublicInfoByBusinessName`; `storeName` = `product.store ?? brand`.
- `product_store_info.dart`: Logo sırası remote → asset → harf; sized `OptimizedImage` + `errorBuilder` (BDP `_buildStoreLogoWidget` gibi).
- `cart_page.dart`: Chip üst satır `Wrap`(Stokta + Avantajlı), alt satır tam genişlik teslimat.

## 2026-06-13 (Sepetim logo BDP parity + header/chip polish)

- **Kök neden:** Cart logo çok katmanlı cache/fetch kullanıyordu; BDP yalnız `getStorePublicInfoByBusinessName(business['name'])` + `_storePublicInfo['logoUrl']` + `_buildStoreLogoWidget` (sized `OptimizedImage`). Cart'ta farklı render ve erken harf fallback logo URL'yi gizliyordu.
- `ibul_app/lib/screens/cart_page.dart`: `_loadCartStorePublicInfo` BDP `_loadStorePublicInfo` ile hizalandı; logo widget aynı sıra (remote → asset → harf). Header kompakt (40–44px logo, tek satır meta); "Satıcı puanı" kaldırıldı. Chip: Stokta/Avantajlı dikey + teslimat tam genişlik satır.

## 2026-06-13 (Sepetim logo veri akışı — sellerId + BDP parity)

- **Kök neden:** Group map'te `logoUrl` taşınmıyordu; cart'ta `sellerId` çoğu üründe boş kalınca logo lookup yalnız `storeName` (çoğu zaman `brand`) ile yapılıyordu — BDP ise `getSellerIdByBusinessName` + `getStorePublicInfoByBusinessName` kullanıyor. Uzak logo yalnız `http` prefix ile `OptimizedImage`'a gidiyordu; diğer URL'ler `Image.asset` ile düşüyordu.
- `ibul_app/lib/screens/cart_page.dart`: `_storeHeaderIdentityCache` + group map `logoUrl`/`businessName`; logo çözüm sırası BDP ile hizalandı; `OptimizedImage` tüm non-asset URL'ler için; fetch sonrası `setState` + identity persist. Navigation/chip layout değişmedi.

## 2026-06-13 (Sepetim logo sellerId + chip kolon)

- **Kök neden:** Logo yalnız `business_name` ile aranıyordu; sepette `product.brand` store adı olarak kullanıldığında eşleşme başarısız → erken harf avatar. Chip'ler tek satırda kırpılıyordu.
- `ibul_app/lib/screens/cart_page.dart`: Logo `sellerId` öncelikli (`getStorePublicInfoById.logo_url`); yüklemede storefront ikonu, harf yalnızca logo yoksa. Chip: Stokta / Avantajlı dikey kolon + `Expanded` çok satırlı teslimat. Navigasyon korundu.

## 2026-06-13 (Sepetim store header + chip overlap)

- **Kök neden:** Store header yalnızca harf avatar kullanıyordu; logo/navigasyon yoktu. Teslimat chip'i sağa pinlenince dar ekranda `Avantajlı` ile z-index overlap oluşuyordu.
- `ibul_app/lib/screens/cart_page.dart`: `_buildStoreLogoAvatar` (asset + Supabase `logo_url` cache), `_openStoreFromCart` → `BusinessDetailPage`; chip satırı tek `SingleChildScrollView` — overlap yok, kaydırarak tam metin.

## 2026-06-13 (Sepetim teslimat chip dar ekran)

- **Kök neden:** Ürün kartı chip satırında stok + kampanya + teslimat tek `SingleChildScrollView` içindeydi; dar ekranda son chip (`35-45 dk içinde kapında`) viewport kenarında kırpılıyordu. `_buildInfoPill` metninde `TextOverflow.ellipsis` tam okunmayı engelliyordu.
- `ibul_app/lib/screens/cart_page.dart`: Chip satırı `Row` + `Expanded` (stok/kampanya scroll) + sabit teslimat pill olarak ayrıldı; pill metninde ellipsis kaldırıldı (`softWrap: false`). Kompakt kart yüksekliği korundu.

## 2026-06-13 (Sepetim ürün kartı kompakt UI)

- **Kök neden:** Mobil `_buildProductCard` yüksek padding (14px), büyük görsel (70–82px), `Wrap` chip satırının iki satıra taşması ve fiyat / hızlı teslimat / adet stepper'ının dikey yığılması kartları hantal gösteriyordu.
- `ibul_app/lib/screens/cart_page.dart`: Ürün kartı kompaktlaştırıldı — padding/spacing azaltıldı, görsel 56–64px, chip'ler tek satır yatay scroll, action row fiyat + hızlı teslimat + adet aynı hizada; `_buildInfoPill` ve satıcı kartı margin/padding hafif düşürüldü. Seçim, miktar, kupon, hızlı teslimat ve silme callback'leri değişmedi. Web `_buildWebProductRow` dokunulmadı.

## 2026-06-13 (sepet 3 sekme — sayaç / toplam / sekme kalıcılığı)

- **Kök neden:** Mobil `CartPage` sekmeleri (Alışveriş / Market / Yemek) yalnızca listeyi filtreliyordu; üst sayaç, alt bar toplamı ve `Sepeti Onayla` tüm sepetten hesaplanıyordu. Sekme seçimi widget-local `_hasAutoSelectedCartTab` ile yönetildiği için IndexedStack dışı yeniden açılışlarda kullanıcı sekmesi korunmuyordu.
- `ibul_app/lib/core/cart_state.dart`: `CartTabKind`, `tabKindForProduct`, sekme bazlı `countForTab` / `productsForTab` — kategori sınıflandırması tek kaynak.
- `ibul_app/lib/core/app_state.dart`: `selectedCartTabIndex`, `cartCountForTab`, `setSelectedCartTabIndex`; `addToCart` ürün kategorisine göre sekmeyi günceller. Alt nav badge `cartCountNotifier` ← `cart.length` (toplam = sekme sayıları toplamı).
- `ibul_app/lib/screens/cart_page.dart`: Mobil özet/sepet onay yalnız aktif sekmeye göre; sekme etiketlerinde `(n)` sayaç; header `scopedProductCount` aktif sekmeyle hizalı; `AppState.selectedCartTabIndex` geri yüklenir. Web görünümü tüm kategorileri birleşik göstermeye devam eder.

## 2026-06-13 (sepet badge / Sepetim boş mismatch)

- **Kök neden:** Alt nav badge `AppState.cartCountNotifier` ← `CartState.cart.length` ile güncelleniyor (`home_screen.dart`, `web_header_menu_items.dart`). `CartPage` ise `AppState` değişimlerini dinlemeden singleton `_appState.cart` okuyordu; async local/remote hydrate veya sepete ekleme sonrası widget yeniden build olmadığı için liste boş kalıyordu. Ek olarak mobil sepet 3 sekmeye bölünüyor (Alışveriş / Market / Yemek); yalnız `category` alanına göre filtrelenen ürünler varsayılan **Alışveriş** sekmesinde görünmeyebiliyordu — badge toplam sayıyı gösterirken aktif sekme boş görünüyordu.
- **Kaynak hizalama:** Badge ve sepet listesi artık aynı source of truth olan `AppState.cart` / `CartState` üzerinden okunuyor; `CartProvider` merge hack'i kaldırıldı.
- `ibul_app/lib/screens/cart_page.dart`: `context.watch<AppState>()` ile hydrate/ekleme sonrası rebuild; sepete ürün eklenince `CartState.tabIndexForProduct` ile ilgili sekme `AppState.selectedCartTabIndex`'e yazılır.

## 2026-06-13 (ana sayfa product quick view preview)

- **Kök neden:** Ana sayfa `ProductCard` eye icon → `ProductQuickInfoSheet` akışında `_convertToProduct` yalnız temel alanları map'liyordu (`description`/`specifications`/`attributes` eksik). `getInitialHomeProducts` select'i de bu alanları bilinçli olarak dışlıyordu. Satıcı sayfası (`business_detail_page`) `Product.fromDBProduct` + `getMenuProductsBySellerId` zengin select ile aynı modal'da açıklama/özellikleri dolduruyordu.
- `ibul_app/lib/services/supabase_service.dart`: `_homeProductSelectFields` / `_homeProductSelectFieldsSansStore` artık `description`, `specifications`, `attributes` içeriyor (quick view için).
- `ibul_app/lib/screens/home_screen.dart`: `_convertToProduct` → `Product.fromDBProduct(dbProduct)`; satıcı sayfasıyla aynı normalize/model akışı.

## 2026-06-13 (seller dashboard Son Siparişler ↔ Orders tutarlılığı)

- **Kök neden:** Dashboard KPI/recent orders `_combinedDashboardOrders` (online + kapalı masa geçmişi) kullanıyordu; Siparişler modülü `_sellerOrdersVisibleInOrdersModule()` (online-only) kullanıyordu. Son Siparişler kart başlığı `order['id']` / optimistic UUID gösteriyordu.
- **Fix:** `_dashboardRecentOrders` getter eklendi — Orders modülüyle aynı görünür küme. Dashboard kart başlıkları `_sellerOrderDisplayTitle`, alt satır `_sellerOrderDashboardSubtitle` (sipariş no). Kapalı masa geçmişi yalnız ciro/KPI'da kalır.

## 2026-06-13 (Hesap Özeti Son Siparişler detay payload)

- **Kök neden:** `OrderDetailPage` sipariş verisini `orderData['rawOrder']` altında bekliyor. `orders_page.dart` `_mapRealOrderForUi` ile `rawOrder` sarmalıyor; `account_page.dart` Son Siparişler satır tıklamasında ham sipariş map'ini doğrudan geçiriyordu → `_rawOrder` boş kalıyor, satıcı adı generic (`Satıcı`), ürün kodu/özellikleri eksik görünüyordu.
- `ibul_app/lib/utils/dynamic_value_helpers.dart`: `wrapOrderForDetailPage` eklendi — Siparişlerim ile aynı detail payload sözleşmesi.
- `ibul_app/lib/screens/account_page.dart`: `_openRecentOrderDetail` artık `wrapOrderForDetailPage(order)` kullanıyor.

## 2026-06-13 (Hesap Özeti Son Siparişler takip + navigasyon)

- **Kök neden:** `account_page.dart` Son Siparişler satırında takip kodu yalnız `tracking_number` dolu mu diye bakıyordu; `OrderService` sipariş oluşturulurken takip no atadığı için onaylanmış/hazırlanıyor siparişlerde de görünüyordu. Satır ve takip alanı tıklanabilir değildi.
- `ibul_app/lib/utils/order_status_constants.dart`: `isInTransitShipmentStatus` eklendi (`shipped`, `transfer`, `branch`, `out_for_delivery`).
- `ibul_app/lib/screens/account_page.dart`: Takip görünürlüğü `shipment_step` → item `status` → order `status` zinciriyle gerçek sevkiyat statüsüne bağlandı. Sipariş satırı `OrderDetailPage` açar; takip kodu ayrı tıklanabilir ve `ShipmentTrackingPage` açar.

## 2026-06-13 (arama loading skeleton overflow)

- **Kök neden:** `ProductCardSkeleton` sabit 312px yükseklik + sabit görsel/metin placeholder'ları kullanıyordu; `SearchResultsPage` loading grid'i (`0.65` mobil / `0.58` web) gerçek sonuç grid'i (`0.70` mobil / `0.82` web) ile uyumsuzdu → hücre içinde ~5.5px bottom overflow.
- `ibul_app/lib/widgets/skeleton_loading.dart`: `ProductCardSkeleton` artık `LayoutBuilder` ile hücre sınırlarına uyuyor; `tight` modu `ProductCard(tight: true)` gövde oranlarını yansıtıyor (esnek görsel + kompakt metin/CTA placeholder).
- `ibul_app/lib/screens/search_results_page.dart`: Loading grid delegate gerçek sonuç grid'i ile hizalandı; skeleton `tight: !isWeb`, `margin: EdgeInsets.zero`.
- `ProductCard` değişmedi.

## 2026-06-13 (Beğendiklerim / Değerlendirmelerim arama satırı)

- `ibul_app/lib/widgets/account_search_filter_row.dart` eklendi: Hesap alt sayfaları için ortak kompakt arama + filtre satırı (40px yükseklik, ortalanmış placeholder, hafif border).
- `ibul_app/lib/screens/favorites_page.dart`: Mobil **Beğendiklerim** ekranı ortak arama/filtre satırını kullanıyor; Listelerim sekmesindeki Ekle butonu davranışı korundu.
- `ibul_app/lib/screens/reviews_page.dart`: **Değerlendirmelerim** aynı ortak satıra geçirildi; mobil "Yorum geçmişin" özet şeridi kaldırıldı. Arama, sekme filtreleri ve liste davranışı değişmedi.

## 2026-06-13 (Değerlendirmelerim ekranı UI polish)

- `ibul_app/lib/screens/reviews_page.dart`: Hesap > **Değerlendirmelerim** ekranı toparlandı — web başlık + istatistik rozeti, mobil özet şeridi, gölgeli arama/filtre satırı, pill sekme chip’leri (count badge + seçili gölge) ve gradient boş durum kartı eklendi. Arama, sekme filtreleri, liste ve ürün detay navigasyonu değişmedi.

## 2026-06-13 (Kurye Bilgi ekranı UI polish)

- `ibul_app/lib/screens/delivery_info_page.dart`: Ürün detayı > Kurye Teslimatı > **Kurye Bilgi** ekranı yeniden düzenlendi — flat/settings listesi kaldırıldı; gradient hero header, kart tabanlı kurye/teslimat satırları, seçili adres vurgusu ve premium e-ticaret teslimat tipografisi eklendi. Kargo seçimi, adres toggle ve `AddressEditSheet` akışı değişmedi.

## 2026-06-13 (kategori Telefonlar ürün eşleme düzeltmesi)

- **Kök neden:** Arama `searchProductsPaged` ile `ilike`/contains (`name`, `sub_category`, `main_category`) kullanıyor; kategori akışı `getCategoryProductsPaged` + `CategoryProductsPage` içinde `sub_category` için exact match bekliyordu. UI etiketi `Telefonlar`, ürün verisi çoğunlukla `Telefon` (tekil) — `home_screen.dart` bu farkı client-side fuzzy ile çözüyordu, kategori sayfası çözmüyordu.
- `ibul_app/lib/utils/category_product_filter.dart` eklendi: UI ana/alt kategori etiketlerini ürün `main_category`/`sub_category`/`name` ile aynı kurallarla eşleştirir; `Telefonlar` → `telefon`/`iphone`/`galaxy` alias; Supabase `.or(ilike…)` clause üretir.
- `ibul_app/lib/services/supabase_service.dart` `getCategoryProductsPaged`: alt kategori için exact `eq` yerine helper tabanlı flexible `or` filtresi (Elektronik alt kategorileri, öncelik `Telefonlar`).
- `ibul_app/lib/screens/category_products_page.dart` `_getDisplayProducts`: ikinci katman exact match kaldırıldı; `CategoryProductFilter.productMatchesSelection` kullanılıyor.
- Arama (`search_results_page` / `searchProductsPaged`) değişmedi.

## 2026-06-13 (categories top bar overflow fix)

- `ibul_app/lib/screens/categories_page.dart`: Üst kategori şeridinde 2 satırlı label için sabit `_topLabelHeight` (26px) + `StrutStyle` eklendi; dikey padding `8→6`, ikon-label gap `6→5`. Kök neden: 104px şerit − 16px padding = 88px kullanılabilir alan, içerik ~92px (ikon 60 + gap 6 + 2 satır metin ~26) → 4px overflow.

## 2026-06-13 (categories page UI polish)

- `ibul_app/lib/screens/categories_page.dart`: Kategoriler ekranı UI toparlandı — üst kategori şeridi kompakt hizalandı (sabit border alanı, seçili ring/shadow, 104px yükseklik); alt kategori grid'i responsive (`<=900`: 3–4 kolon, `>900`: `maxCrossAxisExtent: 118`), tutarlı kart radius/spacing ve `Expanded` görsel alanı ile dağınık boşluk giderildi. Davranış değişmedi.

## 2026-06-13 (şifre değiştir güvenli akış)

- **Kök neden:** `change_password_page.dart` yalnız yeni şifre + tekrar alanına sahipti; mevcut şifre doğrulaması, re-auth ve forgot-password akışı yoktu.
- `ibul_app/lib/services/auth_service.dart`: `verifyCurrentPassword` (Supabase `signInWithPassword` re-auth), `changePasswordWithVerification`, `sendPasswordResetEmail` (`resetPasswordForEmail`), `hasEmailPasswordProvider`.
- `ibul_app/lib/screens/change_password_page.dart`: Mevcut Şifre + Yeni Şifre + Tekrar; doğrulama geçmeden CTA pasif; Google-only hesap banner'ı; **Şifremi Unuttum** → e-posta reset diyalogu (SMS yok).
- `ibul_app/lib/core/app_state_profile.dart`: `changeUserPasswordWithVerification`, `sendPasswordResetEmail`, `hasEmailPasswordProvider` API.

## 2026-06-13 (hesabım özet kartı profile source of truth)

- **Kök neden:** `account_page.dart` mobil üst profil kartı `AppState.currentUser` okumuyordu; sabit `CircleAvatar(Icons.person)` + hardcoded `Boy: 175 cm / Kilo: 70 kg` mock verisi render ediliyordu. Settings save/state refresh doğru çalışsa bile account summary farklı (statik) kaynaktan besleniyordu.
- `user_identity.dart`: `resolveProfilePhotoUrl`, `formatHeightWeightSummary`, `profilePresetColor`; `buildAuthUserMap` foto alanlarını `photo_url` + `photoURL` olarak senkron tutar (kayıtlı profil öncelikli).
- `account_page.dart`: mobil özet kartı normalized `currentUser` üzerinden avatar (http / preset / initials) ve boy/kilo gösterir; `Provider.of<AppState>(context)` ile save sonrası anında rebuild.

## 2026-06-13 (profil foto storage 403 RLS)

- **Kök neden:** `uploadProfilePhotoBytes` → `store-images` bucket, yol `profiles/{uid}/...` idi. `storage.objects` INSERT policy (`SUPABASE_FIX_SELLER.sql`) ilk klasörün `auth.uid()::text` olmasını şart koşuyor; `profiles` ≠ uid → 403 RLS. Ayrıca upload exception tüm `updateUserProfile` akışını blokluyordu.
- `auth_service.dart`: yol `{uid}/profiles/{timestamp}.ext`; `StorageException` için net kullanıcı mesajı (URL/token loglanmaz).
- `app_state.dart` / `app_state_profile.dart`: `uploadProfilePhotoBytes` (yalnız upload) ayrıldı.
- `settings_page.dart`: foto upload try/catch ayrı; text profil alanları upload fail olsa da kaydedilir; kısmi başarı snackbar.
- `ibul_app/SUPABASE_FIX_PROFILE_PHOTO_STORAGE.sql`: mevcut `store-images` policy doğrulama/hotfix (yeni path kuralı ile uyumlu).

## 2026-06-13 (kullanıcı bilgilerim persist / adres source of truth)

- **Kök neden (5 parça):** (1) `getUserProfile()` her çağrıda `ensureCurrentUserRow` upsert ile `photo_url`'yi auth metadata'dan yeniden yazıyordu → galeri/hazır avatar kaydı restart sonrası siliniyordu. (2) Supabase `users` satırı snake_case (`birth_date`, `photo_url`) dönerken settings hydrate camelCase (`birthDate`) okuyordu → boy/kilo/doğum tarihi/tarz/cinsiyet geri gelmiyordu. (3) Profil save sonrası local state kısmi patch ediliyor, backend readback yoktu. (4) Adreslerim'de varsayılan seçim yoktu; settings `users.address` string'i yazıyordu ama hydrate `currentDeliveryAddress` + `deliveryAddresses` okuyordu → source of truth kırıktı. (5) `updateUserProfile` oturum yokken sessizce return ediyordu.
- `auth_service.dart`: `ensureCurrentUserRow` yalnız yeni kullanıcı insert'inde `photo_url` set eder; `updateUserProfile` oturum yoksa exception.
- `dynamic_value_helpers.dart` + `user_identity.dart`: `normalizeUserProfileForApp` — DB profil alanlarını UI/state için tek forma getirir.
- `app_state_profile.dart`: save sonrası `_refreshCurrentUserProfileFromBackend()` ile gerçek readback.
- `settings_page.dart`: normalize hydrate; adres save'den çıkarıldı (teslimat koleksiyonu tek kaynak); mobil sticky CTA + section polish.
- `addresses_page.dart`: teslimat adresine dokununca `setCurrentDeliveryAddress` + "Varsayılan" rozeti.

## 2026-06-13 (kullanıcı bilgilerim / settings)

- **Kök neden:** `settings_page.dart` profil fotoğrafı dekoratifti (`onPressed: () {}`), adres `user['address']` okuyordu (Adreslerim ise `AppState.deliveryAddresses`), inline şifre alanları kaydetmiyordu, mobilde ana CTA yoktu.
- `ibul_app/lib/screens/settings_page.dart`: Section bazlı yeniden düzenleme (Profil / Kişisel / İletişim / Güvenlik / Bildirimler); adres `currentDeliveryAddress` + `deliveryAddresses` hydrate; galeri + hazır avatar seçimi; doğum tarihi picker; tarz/cinsiyet bottom sheet; telefon/e-posta değişiminde bilgilendirici doğrulama diyalogları (SMS OTP yok, e-posta Supabase confirm); **Bilgileri Güncelle** CTA; şifre inline kaldırıldı.
- `ibul_app/lib/screens/change_password_page.dart` eklendi: ayrı şifre değiştir ekranı.
- `ibul_app/lib/services/auth_service.dart`: `photoUrl` profil güncelleme, `uploadProfilePhotoBytes`, `updateUserEmail`, `updateUserPassword`.
- `ibul_app/lib/core/app_state_profile.dart`: `photoUrl`, `updateUserEmail`, `uploadProfilePhoto`, `updateUserPassword` AppState API.

## 2026-06-13 (product detail nearby map back button)

- `ibul_app/lib/screens/map_page.dart`: Ürün detayından `MapPage(product: …)` ile push edilen yakın lokasyon akışında mobil/tablet sol üst geri butonu gösterilir (`product != null && Navigator.canPop`); IndexedStack’teki standalone harita sekmesinde geri butonu görünmez. Desktop geniş layout (`>=1100px`) davranışı aynı kalır.
- Ürün detayı yakın lokasyon navigasyonu: `product_info_section_mobile.dart` → `MapPage(product, initialSearchQuery)`; ayrı `NearbySellersMapPage` route’u kullanılmıyor.

## 2026-06-13 (location permission gate)

- `ibul_app/lib/services/location_access_service.dart` eklendi: `Geolocator.requestPermission` çağrıları tek in-flight Future ile serialize edilir; konum okuma bu servis üzerinden yapılır.
- `ibul_app/lib/screens/map_page.dart`: Harita açılışı ve “konumuma git” akışı artık `LocationAccessService` kullanıyor; IndexedStack’teki arka plan `MapPage` ile push edilen `MapPage` aynı anda izin isteyemez.
- `ibul_app/lib/screens/nearby_sellers_map_page.dart`: Yakın mağaza haritası konum init/polling akışı aynı servise taşındı.

## 2026-06-13 (store grid birebir search hizalama)

- `ibul_app/lib/screens/business_detail_page.dart`: `_buildProductGrid` artık `SearchResultsPage` ile aynı delegate kullanıyor — mobil (`<=900px`): 2 kolon, `0.70`, `crossAxisSpacing: 10`, `tight: true`; web (`>900px`): `maxCrossAxisExtent: 250`, `0.82`, `tight: false`. Eski `>=600 → 4 kolon` mantığı kaldırıldı.
- `ibul_app/lib/widgets/product_card.dart`: Grid hücresinde kart gövdesi tam yüksekliği doldurur; görsel alanı `Expanded` ile kalan boşluğu absorbe eder (alt beyaz boşluk kalkar).

## 2026-06-13 (store product grid spacing)

- `ibul_app/lib/screens/business_detail_page.dart`: Store ürün grid'i arama sonuçlarıyla hizalandı — `ProductCard(tight: true, margin: EdgeInsets.zero)`, mobil `childAspectRatio` `0.66` → `0.70`, web/tablet `0.76` → `0.80`.

## 2026-06-13 (product card grid spacing)

- `ibul_app/lib/widgets/product_card.dart`: Sabit kart yüksekliği (`312/300/276`) kaldırıldı; görsel yüksekliği genişliğe göre hesaplanıyor, grid hücresi sınırlıysa gövde yüksekliği düşülerek taşma önleniyor.
- `ibul_app/lib/screens/search_results_page.dart`: Mobil grid `childAspectRatio` `0.65` → `0.70`, web grid `0.65` → `0.82`; kartlar `Align(topCenter)` ile hizalanıyor.
- `ibul_app/lib/screens/business_detail_page.dart`: Store ürün grid oranları `0.60–0.72` → `0.66–0.76`; kart üst hizalı.
- `ibul_app/lib/screens/product_search_result_page.dart`: Legacy arama grid oranı `0.48` → `0.68` (aşırı uzun hücre boşluğu giderildi).

## 2026-06-12 (order detail / account summary)

- `ibul_app/lib/utils/dynamic_value_helpers.dart` eklendi: Supabase JSON map alanları için `readString`, `readNullableString`, `readInt`, `readDouble`, `normalizeOrderIdentityFields` ve ürün başlığı fallback yardımcıları.
- `ibul_app/lib/services/order_service.dart` seller/customer order fetch sonuçlarında `order_number`, `tracking_number`, `product_code`, `product_name` gibi kimlik alanları normalize ediliyor; restoran online sipariş detayında double→String runtime hatası bu katmanda önlenir.
- `ibul_app/lib/screens/seller_panel_page.dart` `_openSellerOrderDetail` ve mobil detay sheet açılışında order map normalize edilir.
- `ibul_app/lib/screens/account_page.dart` Hesap Özeti > Son Siparişler kartı: ürün görseli + ürün adı başlık, alt satırda sipariş no; takip no yalnız sevkiyat statüsünde (`shipped`/`transfer`/`branch`/`out_for_delivery`) ve ayrı tıklanabilir. Satır tıklaması `OrderDetailPage` açar.

## 2026-06-12 (food order Online → cart)

- Yemek siparişi akışında `ProductCard` > Sipariş Ver > **Online** → `_navigateToOnlineCart` → `AppState.addToCart` → `HomeScreen(initialIndex: 3)` / `CartPage` sepet hydrate yolu.
- **1. kırılma (önceki):** Supabase / `jsonDecode` sepet JSON'unda `price` double gelirken `Product.fromJson` doğrudan `String` alana yazıyordu.
- **2. kırılma (devam eden crash):** Aynı Online akışında sepet persist/hydrate zincirinde iki ek tip hatası:
  - `app_state_auth.dart` local/remote koleksiyon yükünde `addresses` / `savedCards` için `Map<String, String>.from(e)` — örn. `lat`/`lng`/`postal_code` double gelince `double → String` patlıyor.
  - Supabase ürün/satır JSON'unda snake_case alanlar (`old_price`, `variant_group_id`, `main_category` vb.) ve `fromDBProduct` içinde `additional_info` / `faq` güvensiz map dönüşümü.
- Düzeltmeler:
  - `dynamic_value_helpers.dart`: `readStringMap`, `readStringList`, `normalizeProductCartItem`
  - `app_state_auth.dart`: cart hydrate öncesi `normalizeProductCartItem`, adres/kart map'leri `readStringMap`
  - `product_model.dart`: snake_case alias + güvenli `fromDBProduct` alanları
  - `cart_page.dart`: web satıcı puanı `Text` için `readString`

- İlk `PROJECT_MAP.md` oluşturuldu.
- Repo yapısı dört ana çalışma alanı olarak haritalandı:
  - kök Flutter shell
  - `ibul_app`
  - `ihiz_web`
  - `restaurant-ops-web`
  - `local_print_bridge`
- Kritik entry point, state ve servis bağlantıları doğrulandı.
- QR akışı, seller desktop print akışı ve waiter ops optimistic mutation akışı özetlendi.
- Belirsiz alanlar özellikle legacy print server dosyaları ve büyük mega dosyalar için açıkça işaretlendi.
- `seller_panel_page.dart` için yeni not eklendi: garson masa kapatma / hesap kes sırasında canonical restoran owner `sellerId` kullanımı dashboard ve finance persistence için kritik; yanlış UID ile arşivlenen `table_order_history` satırları restart sonrası görünmeyebilir.
- `SUPABASE_DIAGNOSE_TABLE_HISTORY_OWNER_IDS.sql` eklendi: `table_order_history` içinde owner store kaydıyla eşleşmeyen `seller_id` değerlerini raporlar ve yalnız manuel doğrulama sonrası uygulanacak güvenli backfill şablonu içerir.
- `SUPABASE_DIAGNOSE_TABLE_HISTORY_OWNER_IDS.sql`, prod şemayla uyum için `archived_at` bağımlılığından çıkarıldı; read-only teşhis artık `closed_at` / `created_at` üzerinden çalışır.
- `store_table_service.dart` ve `finance_repository.dart` için yeni not eklendi: prod `table_order_history` şemasında `archived_at` olmayabildiği için history reload/yazma akışı `closed_at` fallback ile çalışmalı.
- `seller_panel_page.dart` garson close akışında `ensureTableHistoryRecorded` hatası artık sessizce yutulmuyor; history doğrulaması patlarsa close başarı gibi gösterilmiyor.
- `seller_panel_page.dart` ve `seller_panel_finance_modules.dart` için restart düzeltmesi eklendi: persist edilmiş canonical owner `sellerId` restore edildiğinde store profile yeniden yükleniyor ve `FinanceShell` anahtarı `sellerId` içeriyor; böylece provider yanlış auth UID ile takılı kalmıyor.
- `app_state.dart` seller-scoped cache yardımcıları ile seller panel için kalıcı dashboard/finance cache desteği aldı.
- `seller_panel_page.dart` startup bootstrap sırası owner restore -> sellerId resolve -> cached closed-history hydrate -> store profile refresh olacak şekilde güçlendirildi; boş fetch artık mevcut cache’i ezmiyor.
- `seller_panel_finance_modules.dart` owner bootstrap tamamlanmadan `FinanceShell` oluşturmuyor; hazır olunca sellerId içeren anahtarla provider yeniden kuruluyor.
- Build restore için eksik helper/constants zinciri tamamlandı: `order_status_constants.dart` artık hem `OrderStatusConstants` hem `AdminApprovalStatusConstants` sağlıyor; `table_order_history_utils.dart`, `table_close_history_fallback.dart` ve `today_income_builder.dart` seller finance/store servisleriyle bağlı.
