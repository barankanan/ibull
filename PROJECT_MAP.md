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
- `Risk notu:` Büyük ve çok sorumluluklu; performans ve init race sorunlarına açık.
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

## `ibul_app/lib/screens/map_page.dart`

- `Dosya yolu:` `ibul_app/lib/screens/map_page.dart`
- `Amaç:` harita üzerinden mağaza keşfi, yakınlık bildirimleri ve store detail açılışı.
- `Bağlı olduğu dosyalar:` `AppState`, `StoreService`, `SupabaseService`, `PushNotificationService`, `BusinessDetailPage`, map/filter widget’ları.
- `Bu dosyayı kullanan dosyalar:` route `/map`, `home_screen.dart`, `web_header.dart`, `list_detail_page.dart`, `product_search_result_page.dart`, `visual_intelligence_result_page.dart`.
- `Değişirse etkilenecek yerler:` store proximity, harita arama, business detail yönlendirmeleri.
- `Risk notu:` canlı konum sync ve bildirim mantığı mevcut; yan etki alanı yalnız UI değil.
- `Durum:` kısmi

## `ibul_app/lib/screens/seller_login_page.dart`

- `Dosya yolu:` `ibul_app/lib/screens/seller_login_page.dart`
- `Amaç:` seller/admin oturum açma ekranı; role göre `/seller` veya `/admin` yönlendirir.
- `Bağlı olduğu dosyalar:` `AuthService`, `AdminPanelPage`, `SellerPanelPage`, `become_seller_page.dart`.
- `Bu dosyayı kullanan dosyalar:` `lib/main_seller.dart`, named route `/seller-login`.
- `Değişirse etkilenecek yerler:` seller desktop giriş, admin mode giriş, session backup/restore akışı.
- `Risk notu:` yanlış role handling seller ve admin yetki ayrımını bozar.
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
- `Risk notu:` Restoran / yemek mağazalarında bu modül yalnız online siparişleri göstermeli; `table` / `waiter` kaynaklı kayıtlar Garson akışında kalmalı. Buradaki filtreler yanlış genişlerse dashboard/finance değil ama Siparişler ekranı yanlış veriyle dolar.
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
  - sipariş ve admin onay durum sabitleri; switch-case kullanan seller/admin ekranları için const kaynak.
- `ibul_app/lib/services/store/table_order_history_utils.dart`
  - `table_order_history` satırlarından kapanış zamanı, gelir ve masa etiketi türeten ortak helper.
- `ibul_app/lib/services/store/table_close_history_fallback.dart`
  - garson masa kapanışında duplicate archive kontrolü ve fallback insert planı üretir.
- `ibul_app/lib/features/seller/finance/helpers/today_income_builder.dart`
  - finance repository için günlük gelir breakdown ve kapanmış masa ciro toplamı yardımcıları.
- `ibul_app/lib/utils/table_labels.dart`
  - masa etiketi üretimi.
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

# Update Log

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
- `ibul_app/lib/screens/account_page.dart` Hesap Özeti > Son Siparişler kartı: ürün görseli + ürün adı başlık, alt satırda sipariş no ve takip no ayrı gösterilir; teknik kod ana başlıkta kullanılmaz.

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
