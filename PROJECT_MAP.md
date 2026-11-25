# İBUL Hızlı Başlangıç ve Güncel Durum

> **CHECKPOINT (2026-11-21):** güvenli geri dönüş noktası `checkpoint/restaurant-working-20261121` (etiket `ibul-restaurant-checkpoint-20261121`, ebeveyn `dbdad86`); ayrıntı, kanıt düzeyleri ve geri dönüş adımları: `docs/RESTAURANT_WORKING_CHECKPOINT.md`. Gerçek uygulama: `com.ibul.sellerdesktop` Release (`~/IBUL_isolated_build/flutter-build/macos/Build/Products/Release/IbulSellerDesktop.app`, Apple Development imzası, noter onayı yok). **Açık blokaj P2:** `20261122090000_print_settings_staff_permission.sql` production'a UYGULANMADI (onay reddedildi) — alt yönetici `managePrintSettings` yazıcı ekleme/eşleştirme sunucuda 42501 alır; çözüldü sayılmaz.
>
> Son güncelleme: 2026-11-19 (üstteki checkpoint notu 2026-11-21). Önce bu bölümü ve ilgili özellik satırını oku; yalnızca o dosyalara git. Aşağıdaki eski bölümler dokunulmadan duruyor. Bu bölüm kısa tutulur: değişen sözleşme veya hata durumu görev sonunda burada güncellenir.

> **2026-11-22 P13:** bulut geri dönüşü `decideCloudRecovery` (`features/seller/panel/helpers/offline_page_policy.dart`) ile aralıklı yinelenir; başlangıç sorguları `StoreService.cloudLookupTimeout` (8 sn) ile sınırlı; TCP yazma başladıktan sonraki hata otomatik tekrar edilmez (`network_transport.write_may_have_started`); LAN merkezi ağ değişimini izler (`decideLanRebind`, `SellerLanCenter.followNetworkOnce`); Bağlı Cihazlar `widgets/lan_paired_devices_section.dart`; yetki penceresi `features/seller/staff/staff_account_dialog*.dart`; menü durumu `SellerMenuItemState`; macOS görünen ad `scripts/macos_seller_display_name.sh` (paket adı `IbulSellerDesktop.app` DEĞİŞMEZ). Çevrimdışı para işlemleri BLOCKED (sunucu sözleşmesi gerekir). Ayrıntı: `docs/RESTAURANT_PILOT_PROGRESS.md` P13.

> **2026-11-23 Aşama 1 — yerel-önce sipariş (ayrıntı: `docs/RESTAURANT_PILOT_PROGRESS.md` "AŞAMA 1"):** (a) Sipariş kimliği = gönderim anahtarı `local_order_id` (`waiter-…`); bulut anlık görüntüsü bu kolonu TAŞIR ve pano bulut satırı gelince cihaz kopyasını düşürür (`dropLocalCopiesOfCloudOrders`, `cloudOrderSendKey` — `utils/garson_table_order_state.dart`; `reconcileLanFloorOrders`). Bu kolonu sorgudan çıkarma: masa iki sipariş/iki kat tutar gösterir. (b) Merkezin kendi siparişinde sıra: kalıcı kayıt → fiş; garson fişi en çok `RestaurantOfflineOrderRouter.localPrintAnswerBudget` (5 sn) bekler, sonra `dispatchPath = offline_local_queue_print_pending` ("kaydedildi, fiş bekliyor") döner; baskı çağrısı sürer, yeniden başlatılmaz. (c) Baskısı süren sipariş senkrona alınmaz (`localTicketsInFlight`). (d) Baskı yolundaki her bulut okuması `PrinterRepository.cloudReadTimeout` ile sınırlı olmalı (`printerByIdFrom`). (e) Telefon merkeze ulaşamazsa metin `LanPilotContract.heldOnDeviceMessage`; "mutfağa iletildi" denmez. Sunucu başlık/kalem toplamı 0,00 sorunu: düzeltme 2026-11-24'te canlıya elle uygulandı (aşağıda (i)); eski sıfır kayıtlar düzeltilmedi.
>
> **2026-11-24 Aşama 1 kapısı (ayrıntı: ilerleme belgesi "son doğrulama kapısı"):** (f) Merkez açılışında `settleInterruptedTickets`: sahipsiz `pending` fiş → kalıcı `uncertain`, otomatik yeniden baskı yok. (g) Baskı işi `pending`'e yalnız `OrderPrintJobService.printFailureIsCertainlyNotSent` doğruysa döner; zaman aşımı/kopma belirsizdir. (h) Telefon: `held_for_center` işaretli kayıtlar merkez dönünce `DeviceHeldOrderForwarder` ile aynı anahtarla iletilir (30 dk sınırı, yalnız kendi personeli). (i) Sunucu toplamı düzeltmesi `supabase/drafts/20261124_table_order_totals_DRAFT.sql` (v2) — **CANLIDA: 2026-11-24'te sahip SQL Editor'den ELLE uyguladı; migration geçmişinde kaydı yok, YENİDEN UYGULAMA.** Canlı sarmalayıcı md5 `b328f59d…` = v2; şema VERIFIED, gerçek sipariş NOT VERIFIED. (j) Taslak v2 (para bayrağı geri konur); risk kanıtı `supabase/tests/run_isolated_table_order_totals_risks.sh` production gövdeleriyle (md5) 23/23. Satıcı finansı "online" toplamı `order_items.seller_id`'ye bağlıdır: sipariş RPC'si bu kolonu YAZMAZ (yazarsa masa geliri iki kez sayılır); düzenleme RPC'sinin eklediği satırlar yazar (bilinen, açık çift sayım). Gerçek cihaz test planı: ilerleme belgesi 2026-11-24 19:45 bölümü. (k) **Kalem tutarı sözleşmesi:** `price` = BİRİM fiyat; `MixedServiceOrder.normalizeOrderItem` yalnız `total_price`'ı adede böler, `price`'ı ASLA (2026-11-24 gerçek cihaz: 2 × 180 panoda 180 görünüyordu; test `test/garson_quantity_line_total_test.dart`). Masa kartı, hesap penceresi ve pano cirosu bu fonksiyondan geçer.
>
> **2026-11-25 Yazıcı durumu tek otorite + kalıcı Başlat/Durdur (ayrıntı: `docs/RESTAURANT_PILOT_PROGRESS.md` "2026-11-25 Yazıcı ve LAN güvenilirliği"):**
> - **Yazıcı erişilebilirliğini yalnız hub ölçer ve yayımlar.** `DesktopPrintHub.checkBridge` (30 sn; yazıcı yoklaması en sık 60 sn) KAYITLI, rol atanmış ağ yazıcılarını yoklar (`savedPrinterProbeTargets`, `probeSavedPrinters` — `services/printer_link_status.dart`; yalnız bağlantı aç/kapa, bayt yazılmaz) ve `PhysicalPrintGate.noteSavedPrinters` + `publish` ile yayımlar. Bu hüküm tazeyken (3 dk) başka bir ekranın başka adrese yaptığı yoklama onu ezemez. Sağ alt rozet (`hub.readiness`), Garson rozeti (`_applyLocalPrintStatus` artık `PhysicalPrintGate.published` okur) ve Yazıcı Merkezi kartı (`_printReadiness`) aynı kaynağı okur. Yeni gösterge eklerken kendi yoklamanı YAZMA; `PhysicalPrintGate.published` oku. Eski hata: erişilebilirlik yalnız Garson ekranı açıkken ve köprünün "son bastığı adres" (`last_kitchen_tcp`) üzerinden ölçülüyordu → yeniden başlatmadan sonra rozet "Yazıcı doğrulanmadı", merkez "bağlı" diyordu. USB/sistem kuyruğu yazıcıların yoklanacak adresi yoktur: onlar için hüküm `null` kalır ("doğrulanmadı").
> - **Başlat kalıcıdır, Durdur kalıcıdır** (14k ve §4.6'daki "her açılışta kapalı" kuralının yerine geçer; kullanıcı kararı 2026-11-25). Operatörün Başlat'ı `RestaurantCenterAutoStart.rememberOperatorChoice(started: true)`, Durdur'u `false` yazar (`ibul.printer_center.auto_start.<rid>`; Yazıcı Merkezi anahtarı, "Yazıcı Servisini Başlat" düğmesi, Yerel Operasyon sayfası). Uygulama kapanışı Durdur DEĞİLDİR: `RestaurantCenterControl.stop(byOperator: false)` tercihi ve merkez sahipliğini (`ibul.lan_center.owned.*`) silmez. Açılış yolu aynı tek dizidir (`openAtLaunch` → `open`): yetki kapısı, eski fişlerin bekletilmesi ve tek köprü/tek merkez korumaları aynen uygulanır. `openAtLaunch` "hiç denenmedi" (null) sonucunu saklamaz (işletmeyi henüz bilmeyen ilk çağıran tek hakkı tüketmez); denenmiş sonuç (başarılı/başarısız) süreç boyunca kalır.
> - **Beklenmedik köprü kapanması:** hub çalışırken (Başlat–Durdur arası) köprü yanıt vermezse `RestaurantCenterAutoStart.printServiceStoppedAnswering` → `RestaurantCenterControl.reviveBridge` (30 sn, 1, 2, 4, 8 dk arayla en çok 5 deneme; aynı `startedAt` sınırı köprüye yeniden bildirilir, eski iş basılmaz). Durdur'dan sonra, merkez olmayan cihazda ve restoran dışı işletmede çalışmaz.
>
> **2026-11-23 Kalıcı yazıcı sistemi (commit edilmedi sayılmadan önce `docs/RESTAURANT_PILOT_PROGRESS.md` "P15" bölümüne bak):**
> - **Kayıt ≠ erişilebilirlik.** Kayıt: Supabase `printers` / `station_printers` / `stations` / `restaurant_print_station_configs` (kaynak) + bu cihazdaki son iyi kopya `printer_repository_last_good_v1_{printers|station_printers|station_config|stations}_<rid>` (SharedPreferences, sürümden bağımsız; güncelleme/yeniden başlatmada kalır). Erişilebilirlik: `features/seller/panel/printer_center/printer_registry_status.dart` (`PrinterReachabilityMonitor`, yalnız Yazıcı Merkezi ekranı açıkken 60 sn; kayıt silmez, tarama yapmaz).
> - **Boş bulut yanıtı kopyayı silmez:** oturum yok/süresi dolmuşken gelen `[]` son iyi kopyanın üzerine yazılmaz (`PrinterRepository.emptyAnswerIsAuthoritative`). 5xx/ağ geçidi hataları "ulaşılamıyor" sayılır (`isCloudOutageAnswer`); 401/403/4xx sayılmaz. `watchPrinters` bağlantı hatasında kopyayı gösterir.
> - **Yazıcı silme yalnız o yazıcının rolünü temizler**, önce kayıt silinir (`DesktopPrintOrchestrator.deletePrinter`); tam sıfırlama (`hardResetPrinters`) eskisi gibi her şeyi temizler.
> - **Tek başlatma dizisi:** `services/restaurant_offline/restaurant_center_auto_start.dart` → `RestaurantCenterAutoStart.open` (Başlat anahtarı da açılış da bunu çağırır; `RestaurantCenterControl.start` üzerinden). Tercih: `ibul.printer_center.auto_start.<rid>` (bu bilgisayar, varsayılan kapalı). Açılışta `openAtLaunch` süreç başına EN FAZLA bir kez çalışır → Durdur o oturumda kalıcıdır. Önce eski köprü kapatılır ve portun boşalması beklenir (iki köprü yok).
> - **Açılışta eski iş basılmaz:** hub + köprü + artık `OrderPrintJobService.recoverPendingJobs` da `PrintServiceStartGate.jobIsFromBefore` ile süzer.
> - **Hızlı yerel mutfak baskısı istasyona göre yazıcı seçer** (`resolveFastPathStationPrinters`): istasyonun atanmış yazıcısı, yoksa KAYITLI Mutfak rolü. Karar verilemezse hızlı yol hiç basmaz, iş kuyruk yoluna kalır. "Köprünün son bastığı yazıcı" artık hedef olarak kullanılmaz (`tcp:bridge-default` kaldırıldı).
> - **Köprü yanıtı:** başarısız gönderimde `retry_safe` / `write_may_have_started` / `print_outcome` (`not_sent`|`uncertain`). Bağlantı aşamasında başarısız iş için tekilleştirme anahtarı unutulur (sonraki deneme gerçekten basar); belirsiz iş tekrar gelirse 409 `print_outcome_uncertain` (asla "zaten basıldı" değil); yalnız `operator_confirmed_retry: true` yeniden basar. TCP hata aşaması `NetworkTcpTransport.print_bytes` içinde de işaretlenir (yazma aşaması hatası köprüde otomatik tekrar gönderilmez). **Python değişikliği paket içi köprüye ancak yeniden paketlemeyle girer:** `PYTHON=~/IBUL_isolated_build/bridge-venv/bin/python3 sh local_print_bridge/macos/build_bridge_executable.sh`, ardından uygulama derlemesi (2026-11-23 01:27 derlemesi güncel köprüyü içerir).

## 1. Çalışma dizini ve bileşen konumları

Gerçek çalışma dizini: `/Users/barankananogullari/ibul-work` (eski `Desktop/ibul2026 kopyası 9` klasörü kullanılmaz). Dal: `backup/ibul-work-uncommitted-20261115`, 100+ commit edilmemiş dosya var; hiçbiri commit/push edilmedi.
**2026-11-21 güncel kaynak** `.claude/worktrees/ibul-restaurant-completion-e60b65` çalışma ağacında (dal `claude/ibul-restaurant-completion-e60b65`, HEAD `dbdad86`, +commit edilmemiş değişiklikler checkpoint dalında anlık görüntülendi). Ana klasör eski (`9c39dc6`); birleştirme planı: `docs/RESTAURANT_PILOT_PROGRESS.md` "devam 14". Yedekler repo dışı: `~/IBUL_checkpoints/20261121-restaurant-working/`.

| Bileşen | Konum |
| --- | --- |
| Satıcı masaüstü girişi (oturum kapısı) | `lib/main_seller.dart` (`_SellerSessionGate`) |
| Satıcı paneli + Garson ekranı | `ibul_app/lib/screens/seller_panel_page.dart` (çok büyük; bkz. teknik borç) |
| Yazıcı Ayarları ekranı | `ibul_app/lib/screens/seller/kitchen_print_management_page.dart` |
| Yazıcı kurulum diyalogları | `ibul_app/lib/screens/seller/printer_ethernet_dialog.dart`, `printer_test_dialog.dart` |
| Yazıcı köprüsü (Python) | `local_print_bridge/` (`server.py`, `network_scan.py`, `raster.py`) |
| macOS derleme/proje | `macos/` (şema `SellerOfflinetest`, yapılandırma `Debug-Offlinetest`) |
| Edge Function (personel) | `ibul_app/supabase/functions/manage-restaurant-staff/index.ts` |
| Migration'lar | `ibul_app/supabase/migrations/` |

## 2. Özellik → dosya → servis/RPC

Tüm yollar `ibul_app/lib/` altındadır (aksi belirtilmedikçe).

| Özellik | Dosyalar | Servis / RPC / tablo |
| --- | --- | --- |
| Garson sipariş gönderimi | `services/order_print_job_service.dart` (`dispatchNewOrder`), `screens/seller_panel_page.dart` | RPC `create_table_order_with_print_jobs`; tablolar `orders`, `print_jobs` |
| Baskı tekilleştirme anahtarı | `utils/kitchen_print_dedup.dart` (`buildKitchenLogicalPrintKey`, `kitchenOrderKeyForPrint`) | `print_jobs.payload.logical_print_key`; köprüde `local_print_bridge/server.py` (15 dk içerik kuralı) |
| Baskı işi kimlik hizası | `services/print_job_payload_identity.dart` | Tetikleyici `validate_restaurant_print_job` (payload ≠ sütun ise 42501) |
| Ortak yazıcı hazır durumu | `services/printer_readiness.dart`, `services/printer_link_status.dart` (`PhysicalPrintGate`) | Hub: `services/desktop_print_hub.dart` (`readiness`) |
| Yazıcı servisi aç/kapa | `services/print_station_service.dart` (`setPrintSystemEnabled`) | Köprü `POST /configure/print-station`; bulut `restaurant_print_station_configs` |
| Köprü istemcisi / sağlık | `services/local_print_service.dart`, `services/bridge_manager.dart`, `services/bridge_lifecycle_service.dart` | Köprü `/health`, `/print/kitchen`, `/print/receipt` |
| Baskı kapısı (güvenlik) | `core/config/runtime_config.dart` (`printStartDisabled`, `controlledTestBridge`) | Derleme tanımları, bkz. §6 |
| Alan/yazıcı/ürün eşleme | `screens/seller/kitchen_print_management_page.dart`, `services/station_repository.dart`, `services/printer_repository.dart`, `services/kitchen_product_mapping_cache_store.dart` | `stations`, `printers`, `station_printers`, `products.station_id` |
| LAN yerel merkez | `services/restaurant_offline/restaurant_center_control.dart` (operatör Başlat/Durdur, tek giriş), `restaurant_center_access.dart` (yetki kapısı), `seller_lan_center.dart` (başlat/durdur/`resumeOwned`), `restaurant_lan_host.dart` (`RestaurantLanHost`), `lan_advertiser.dart` (Bonjour), `lan_staff_probe.dart` (üyelik doğrulama) | Port `lanOrderPort` (18772, test 18773/18783) |
| Yerel sipariş günlüğü | `services/restaurant_offline/restaurant_local_order_queue_service.dart`, `restaurant_local_print_queue_service.dart` | Güvenli yerel depo (`core/secure_local_store.dart`) |
| Çevrimdışı yönlendirme | `services/restaurant_offline/restaurant_offline_order_router.dart` | `restaurantOrderRoute` (`services/staff_login_policy.dart`) kararı |
| Bağlantı durumu (bulut/LAN/köprü ayrı) | `services/restaurant_offline/restaurant_connectivity_service.dart` (`startMonitoring`, 2 başarısızlık kuralı) | `/auth/v1/health` yoklaması |
| Çevrimdışı kimlik ve açılış kararı | `services/restaurant_offline/offline_panel_identity.dart` (`decideOfflineStart`), `restaurant_local_cache_service.dart`, `restaurant_offline_snapshot_sync.dart` | Yerel önbellek anahtarları `restaurant_offline_cache_v1_*`, `ibul.offline_panel_identity.*` |
| Bulut senkronizasyonu | `services/restaurant_offline/restaurant_offline_sync_service.dart` | `orders.local_order_id` tekilliği; kanıt doğrulayıcı `supabase/functions/verify-lan-print-evidence` |
| Personel yetki kuralları | `services/staff_login_policy.dart` (`StaffMenuGate`, `staffOperationAllowed`), `services/auth_service.dart` (`loadStaffMenuGate`) | Tablo `store_sub_admins`; fonksiyonlar `restaurant_has_permission`, `restaurant_staff_may_operate` |
| Personel şifre politikası (2026-11-21: yalnız sahip; zorunlu değişim KALDIRILDI) | `supabase/migrations/20261121090000_staff_owner_only_password.sql`, `20261121100000_staff_access_revocation.sql`, `functions/manage-restaurant-staff/index.ts`, `features/seller/staff/staff_team_panel.dart` (Şifre belirle), `services/auth_service.dart` (`isManagedStaffUser`) |
| Bulut hata metinleri | `utils/cloud_error_text.dart` | — |
| Ara ödeme / hesap kesme | `screens/seller_panel_page.dart`, `services/store/store_table_service.dart` | RPC `record_table_payment`, `close_table_with_history` |
| Masa kartında müşteri adı | `services/store/store_customer_directory.dart`, `widgets/garson/store_customer_picker.dart` | `store_customers`, `store_table_customer_selections` |
| Geçmiş masa arama | `screens/seller/table_history_screen.dart`, `services/store/table_order_history_utils.dart` (`filterTableHistoryRecords`) | `table_order_history` (müşteri alanı yok) |

## 3. Son değiştirilen önemli dosyalar

- Yeni: `services/printer_readiness.dart`, `services/print_job_payload_identity.dart`, `services/restaurant_offline/offline_panel_identity.dart`, `features/seller/staff/staff_password_change_dialog.dart`, `utils/cloud_error_text.dart`, `services/restaurant_offline/{lan_staff_probe,lan_advertiser,seller_lan_center}.dart`.
- Değişen: `services/order_print_job_service.dart`, `services/desktop_print_hub.dart`, `services/print_station_service.dart`, `services/local_print_service.dart`, `services/restaurant_offline/restaurant_connectivity_service.dart`, `utils/kitchen_print_dedup.dart`, `screens/seller_panel_page.dart`, `lib/main_seller.dart`, `local_print_bridge/server.py`.
- Yerel migration (yalnız yerel DB'ye uygulandı, üretime uygulanmadı): `20261117000000_printers_schema_catch_up.sql`, `20261117000100_stations_products_catch_up.sql`.

## 4. Kritik sözleşmeler (kodu değiştirmeden önce oku)

1. **Önce kayıt, sonra fiş.** Hiçbir oturumda mutfak fişi sipariş sunucuda kesinleşmeden basılmaz (`dispatchNewOrder`). 403/zaman aşımı/bağlantı hatasında sıfır baskı.
2. **Tekilleştirme sipariş kimliğini içerir.** Anahtar: işletme | masa | alan | revizyon | ürün özeti | sipariş kimliği (`local_order_id`, yoksa sipariş id; ek fişte `#revision_key`). Aynı sipariş tekrarı tek fiş; aynı masaya iki gerçek sipariş iki fiş. Sipariş kimliği olmayan eski payload eski anahtar biçimini korur.
3. **Fiş başlığı seçilen masayı taşır** (`kitchenTableLabelFields`): "Bahçe 1", dahili "Masa 11" değil.
4. **Yazıcı servisi kapalıysa fiziksel baskı yok.** Köprü anahtarı çalışan işleyicileri yeniden yükler (`/configure/print-station` → `_reload_handlers`); kapalıyken `/print/kitchen` 503 döner.
5. **Üç ayrı durum:** bulut (`supabaseReachable`), yerel merkez (`lanHostReachable`), köprü (`bridgeReachable`). Tek başarısız yoklama bulutu kapalı saymaz; art arda 2 başarısızlık gerekir.
6. **Yerel merkez / yazıcı merkezi (GÜNCEL 2026-11-25: operatörün son Başlat/Durdur seçimi kalıcıdır, açılış o seçime uyar; aşağıdaki eski metin yalnız Durdur seçilmişken geçerlidir):** HER AÇILIŞTA KAPALI. Önceki oturumda Başlat seçilmiş olsa bile kendiliğinden açılmaz; yalnız yetkili restoranda Sistem → Yazıcı Merkezi → Başlat ile açılır (bkz. 14k). Güvenilir özel ağ arayüzü gerekir; yalnız localhost yetmez.
7. **Çevrimdışı kimlik (mühürlü):** çevrimiçi her başarılı yetki okumasında hesap, işletme, kategori, yetkiler saklanır ve kayıt cihaz sırrıyla HMAC-SHA256 mühürlenir (`offline_identity_seal.dart`; sır yalnız Anahtar Zinciri'nde, ayar dosyasına düşmez). Mühür tutmayan (düzenlenmiş, mühürsüz, başka cihazdan kopyalanmış) kayıt veya cihaz sırrı yoksa açılış reddedilir (`integrityFailed`). Çevrimdışı açılış için ayrıca: açık oturum + aynı hesap + geçici şifre işareti yok + **sahip ≤ 72 saat / personel ≤ 12 saat** + saat geri alınmamış (`last_seen_at`, 10 dk tolerans) + yerel menü ve masa verisi. Personel hesabı asla sahip olarak açılmaz; yetkiler genişlemez. Çevrimdışıyken menü yalnız Garson ve Sistem'e daralır. Bulut erişilebilirken yetkiler 30 dakikada bir ve her bağlantı dönüşünde yeniden okunur (kayıt tazelenir, iptal edilen hesap kapanır).
8. **Çevrimdışı para ve masa işlemi yok:** bulut yokken ara ödeme, hesap kesme, kişi başı tutar (hesap bölme) ve masa aktarma baştan reddedilir, açık uyarı gösterilir (`offlineMoneyOperationBlock`: `partialPayment`, `closeTable`, `splitBill`, `transferTable`).
11. **Çevrimdışı sipariş kimliği:** çevrimdışı yola sapan sipariş, panelin gönderim anahtarını (`localOrderId`) taşır. Aynı anahtar yerel günlükte varsa ikinci kayıt ve ikinci fiş oluşmaz (yalnız kesin `failed` baskı yeniden denenir); fiş anahtarı sipariş kimliğini içerir (`logical_print_key`). Zaman aşımına uğrayan bulut kaydıyla aynı anahtar kullanıldığı için senkron mükerrer sipariş açmaz.
9. **Personel:** geçici şifreli hesapta sunucu tüm izinleri reddeder (`staff_must_change_password`); uygulama zorunlu şifre penceresi gösterir. Görev adı yetki vermez. Pasif üyelik, başka işletme, şifresi değişmemiş hesap çevrimdışı açılamaz.
   **GÜNCEL (2026-11-21, yerel/izole; production'a uygulanmadı):** yukarıdaki geçici şifre kuralı GEÇERSİZ. Personel oluşturma, şifre belirleme, yeniden etkinleştirme/bağlama yalnız sahip (Edge Function + DB). `staff_must_change_password()` adı korundu ama artık "bu oturum iptal edildi mi" kapısıdır (oturum silinmiş veya `staff_credentials.sessions_valid_after` kesmesinden eski). Üyelik silme/pasifleştirme/yeniden bağlama `store_sub_admins` tetikleyicisiyle epoch artırır, işletmenin oluşturduğu hesabın oturumlarını siler ve hesabı banlar (`user_banned`). LAN merkezi `lan_staff_authority.credential_epoch` değerini cihaz kaydında (`RestaurantLanDevice.staffEpoch`) tutar; fark → cihaz kalıcı iptal. Ayrıntı ve kanıt: `docs/RESTAURANT_PILOT_PROGRESS.md`.
10. **Üretim yazma yasağı:** üretim Supabase'e test verisi, gerçek yazıcıya test fişi, üretim migration'ı ve canlı servis değişikliği ayrıca onay ister. RLS ve `printer_id` doğrulamaları gevşetilmez.

12. **Uygulama düzeyi yaşam döngüsü (2026-11-18):** `lib/main_seller.dart` oturum kapısı, oturum kurulunca `RestaurantOfflineLifecycle` (`services/restaurant_offline/restaurant_offline_lifecycle.dart`) başlatır: sahip olunan yerel merkezi `resumeOwned` ile açar (cihaz daha önce operatörce merkez yapılmamışsa hiçbir şey açılmaz), internet dönüşünde bekleyen siparişleri merkez dinlemeye başladıktan sonra tek sefer gönderir. Aynı işletme için ikinci başlatma etkisizdir; `SellerLanCenter.start` tek uçuşludur (aynı anda iki istek tek sunucu); `RestaurantOfflineSyncService._syncInFlight` artık statik (banner, dinleyici ve yaşam döngüsü ayrı nesne yaratıyor). İşletme kimliği mühürlü çevrimdışı kimlikten (`integrity ok`) ya da sahibin kendi kimliği + sahiplik işaretinden gelir. Çıkışta (`signedOut`) durur. Test: `test/services/restaurant_offline_lifecycle_test.dart`.

13. **LAN personel yetkisi (2026-11-19):** her LAN isteğinde (eşleşmiş cihaz ve tarayıcı oturumu dahil) üyelik bulutta yeniden okunur (`lanStaffProbe`): aktif üyelik + aynı `store_id` + saklı `manageOrders` izni + (üyelik şubeye bağlıysa) merkezin şubesiyle aynı şube. **Rol veya görev adı yetki vermez** (`role=='waiter'` kısayolu kaldırıldı). Şube bağlı üye için masa yalnız kendi şubesinin aktif masasıdır, masa bulunamazsa reddedilir (sunucudaki `restaurant_table_access` ile aynı kural); masa listesi de süzülür. Bulut yokken yalnız daha önce doğrulanmış, süresi dolmamış cihaz çalışır (şube bilgisi cihaz kaydında saklanır). Eşleştirme sertifikası tek başına yetki vermez; pasif/izinsiz/başka şube/başka işletme/üyeliksiz personel sipariş kaydedemez (testler: `restaurant_lan_host_test.dart` "LAN staff authorization (negative)", `seller_lan_center_test.dart`).
14b. **Çevrimdışı personel yetkisi (2026-11-20):** bulut erişilebilirken doğrulanan yetki (aktif üyelik, işletme, `manageOrders`, şube) cihaz kaydına yazılır ve Anahtar Zinciri'ndeki cihaz sırrıyla HMAC-SHA256 mühürlenir (`lan_authority_seal.dart`; sır yoksa/yazılamıyorsa mühür yok, çevrimdışı yetki yok; ayar dosyasına düşme yok). Bulut yokken (`unreachable`) yalnız mühürlü + süresi dolmamış (`deviceGrantTtl`, varsayılan 12 sa, çevrimdışıyken uzatılmaz) + saat geri alınmamış + şube eşleşen kayıt kabul edilir; düzenlenmiş/kopyalanmış/mühürsüz/çevrimdışı eşleşmiş cihaz reddedilir. Eşleştirme sırasında personel buluttan doğrulanır (reddedilen eşleşemez, 403). Bulut dönünce `RestaurantLanHost.reverifyDevices()` (lifecycle `onReconnected`) tüm cihazları yeniden doğrular, iptal edilenleri kapatır; her çevrimiçi istek de yeniden doğrular. Sınırlar: çevrimdışıyken yapılan iptal bulut dönene/12 saate kadar görünmez (operatör elle iptal edebilir); geçici-şifre işareti merkezde hâlâ görünmez (§7.5, sunucu tarafı değişiklik gerekir).
14c. **Geçici şifre ve yetki RPC'si (2026-11-20, yerel migration, production'a uygulanmadı):** `public.lan_staff_authority(p_restaurant_id, p_staff_id)` (`20261120090000_lan_staff_authority.sql`, negatif testler `supabase/tests/lan_staff_authority_negative.sql`) yalnız işletme sahibine üyelik durumu, izinler, şube ve `must_change_password` (Auth `app_metadata`) döner. Merkez (`lanStaffAuthorityReader` + `lanStaffDecision`) bayrak yalnız `false` (bool) ise kabul eder; eksik/bool olmayan/RPC yok = reddedilir. Mühür "şifre doğrulandı" bilgisini kapsar. Dağıtım sırası: migration → istemci; migration olmadan merkez hiçbir personeli kabul etmez (bilinçli, güvenlik şartı kaldırılmaz).
14d. **macOS sandbox'ta LAN merkezi (2026-11-20):** merkez dış süreç kullanmaz: TLS/CA/sunucu/cihaz sertifikası ve baskı kanıtı imzası Dart içinde (`lan_cert_material.dart`, `signSha256Rsa`; openssl ile çapraz test), `chmod` libc FFI (`lan_file_mode.dart`), otorite kilidi işletim sistemi dosya kilidi (`LanAuthorityLock`), Bonjour yerel `NetService` (`macos/Runner/LanBonjour.swift`, `NativeBonjourAdvertiser`; `dns-sd` yalnız yedek). Debug ve Release sandbox'lı; ikisinde `network.client/server`, Debug'da `keychain-access-groups`. Baskı köprüsü (Python) sandbox'lı uygulamadan başlatılamaz: LaunchAgent gerekir.
14d2. **macOS Yazıcı Servisi başlatma (2026-11-21, gerçek Release'te doğrulandı):** Kök neden: gerçek paket `IbulAllowLivePrintAgent=NO` ile derlenmişti (pakette LaunchAgent yok, `notConfigured`), sandbox'ta Python yedek yolu yok, sayfa köprü hatasını yutup "Önce köprüyü başlatın" gösteriyordu. Ayrıca gerçek uygulamada `SMAppService.register` sandbox `job-creation` yüzünden reddedilir (kod 1): **LaunchAgent yolu sandbox'lı satıcıda ÇALIŞMAZ.** Çözüm: paketteki köprü (`Contents/Resources/PrintBridge/IbulPrintBridge`) `PrintBridgeHelper.entitlements` (app-sandbox + inherit) ile imzalanır ve `BridgeManager` onu doğrudan başlatır (`macOsPackagedHelper`, env `PRINT_BRIDGE_HOST/PORT`, `PRINT_STATION_ENABLED=false`); ajan yalnız yardımcısı olmayan derlemede denenir. `kitchen_print_management_page` köprü açılmadıysa gerçek nedeni gösterir. Doğrulama: Başlat → tek süreç, 127.0.0.1:3001 LISTEN, `/health` ok; Durdur → süreç yok, 3001 boş; yeniden Başlat → tek yeni süreç; uygulama çıkışı köprüyü kapatır; yeniden açılış → servis kapalı. Derleme: `flutter build macos --target lib/main_seller.dart --release` (kökten; `build` → `~/IBUL_isolated_build/flutter-build`). Açık: sağ alttaki "Yazıcı köprüsü kapalı" rozeti Başlat sonrası bir süre bayat kalıyor (tek durum kaynağı, P2).
14e. **Baskı zinciri (2026-11-20):** merkez, masaüstünde yerel baskı kuyruğu + `AppRuntimeConfig.localPrintBridgeUri()` ile fişi kabulde bu bilgisayarın köprüsüne verir (forwarded/failed/uncertain kayıt). Köprüye gönderim `Content-Length` taşımalıdır (Dart'ın chunked gövdesini Python köprüsü reddediyordu; test köprüsü artık bunu zorlar). Kanıt anahtarı kaydı başlangıçta VE her bulut dönüşünde (`SellerLanCenter.ensureEvidenceKeyRegistered`, sipariş gönderiminden önce); bulut izleme (`startMonitoring`) artık uygulama yaşam döngüsünce başlar, ekrana bağlı değildir.
14f. **Pilot hazırlığı: sunucu sırası ve uyumluluk (2026-11-19):** üretime elle uygulanacak sıra: `20261103223000` → `20261119090000` → Edge `verify-lan-print-evidence` → `20261120090000` (`lan_staff_authority`, bağımsız) → yeni istemci. Her dosya kendi BEGIN/COMMIT'ini taşır. Eski istemci çağrıları (9 argümanlı adlı/konumsal, replay, `approve_waiter_order_request`) üç migration sonrasında da çalışır; yanıta yalnız `print_disposition` eklenir. Yeni istemci migration'sız sunucuda personeli kabul etmez, kanıtlı siparişi cihazda tutar. Prova: `scripts/rehearse_order_rpc_migration.sh` (üç migration, geri alma üretim md5'lerine döner). Üretimde Edge fonksiyonu ve üç migration henüz YOK.
14g. **`paused_by_operator` semantiği (2026-11-19):** forwarded/unverified yerel baskı → sunucuda `paused_by_operator` (hub yalnız `pending` alır, bulut ikinci kez basmaz); uncertain → `failed`; failed/kanıtsız → `pending`. Operatör yalnız duraklı işi bırakır. Kanıt: `ibul_app/supabase/tests/paused_job_semantics.sql` (6/6). Açık risk: köprü işi kabul edip kâğıt bitmesiyle basmazsa iş duraklı kalır, uyarı yok; pilotta operatör duraklı işler panelini kesinti sonrası kontrol eder.
14h. **Köprü LaunchAgent (2026-11-19):** launchctl ile izole etiket (`com.ibul.localprint.pilot-rehearsal`, port 18772, loopback-only koruma) başlat/kickstart-yeniden başlat/kill -9 ile KeepAlive/bootout sınandı: PASS; üretim `com.ibul.localprint` ve 3001 dokunulmadı. Paketli `local_print_bridge/dist/macos/IbulPrintBridge` (11 Kasım) ~8 sn'de `/health` verir. Açık: `PrintBridgeAgent.register` ve `PrintAgentMac` ürün koduna BAĞLI DEĞİL; SMAppService kaydı kullanıcı onayı ister (BLOCKED, kullanıcı eylemi). Makinede eski `com.ibul.localprint` (üretim, exit 1, Masaüstü kopyasındaki venv'e işaret ediyor) ve bayat `...isolated-test` (exit 78) kayıtları var; elle temizlenmeli.
14i. **Gerçek cihaz planı:** `docs/PILOT_REAL_DEVICE_LAN_TEST_PLAN.md` (eşleştirme, TLS, izinler, sipariş, kesinti, kanıt/iptal ölçütleri). Bilinen boşluklar: (iOS yerel ağ anahtarları 14j ile eklendi) mobilde Bonjour tarama yok (eşleşme elle). `IBUL_POSTGREST` testleri için tarif: izole PG17 + PostgREST (`~/IBUL_isolated_build/pgiso/reset_and_env.sh`), `IBUL_PSQL/PGPORT/PGUSER/PGDB/JWT_SECRET/DENO` değişkenleri gerekir.
14j. **Platform mimarisi: masaüstü ana bilgisayar + mobil garson (2026-11-19):** Masaüstü = macOS + Windows, mobil = iOS + Android. Ortak mantık Dart'ta (`RestaurantOfflineLifecycle`, `SellerLanCenter`, `RestaurantLanHost`, `BridgeManager`); platforma özel yalnız servis başlatma ve ağ izni.
    - **Açılışta başlama yok:** hiçbir İBUL servisi bilgisayar açılışında başlamaz. Windows kurulumu (`windows/installer/IbulSellerSetup.iss`) artık `HKCU\...\Run\IbulLocalPrintBridge` yazmaz, eski değeri ve `ibul-local-print.cmd` başlangıç betiğini siler, kurulumda köprüyü başlatmaz. macOS paket plist'leri (`macos/Runner/Library/LaunchAgents/*.plist`) `RunAtLoad=false` + `Sockets` (launchd 127.0.0.1:port dinler) taşır; **`KeepAlive.SuccessfulExit` YASAK** (launchd bunu açılışta çalıştır sayar, izole testte doğrulandı). Hızlı kurulum artık sessizce LaunchAgent kurmaz. Kurulum sihirbazındaki "otomatik başlat" anahtarı operatörün açık tercihi olarak durur (varsayılan kapalı).
    - **Uygulama açılınca başlama (GEÇERSİZ, 14k geçerli: restoranda açılışta hiçbir şey başlamaz; aşağıdaki akış yalnız Başlat'tan sonra işler):** oturum kurulunca `resumeOwned` yalnız önceden merkez yapılmış bilgisayarda merkezi açar ve ardından `BridgeManager.ensureReady()` çağırır. Windows: paketli `IbulPrintBridge.exe` ayrık süreç olarak başlar. macOS: `MacPrintAgentStarter` (`services/print_agent_starter.dart`) SMAppService ajanını bir kez kaydeder (`PrintBridgeAgent.swift`, kanal artık `MainFlutterWindow`'da bağlı), ilk `/health` isteği launchd'nin köprüyü başlatmasını tetikler; köprü launchd soketini devralır (`local_print_bridge/launchd_socket.py`, `PRINT_BRIDGE_LAUNCHD_SOCKET`). Canlı ajan yalnız `IBUL_ALLOW_LIVE_PRINT_AGENT` (Xcode ayarı `YES` + dart-define `true`) ile seçilir; varsayılan `NO`.
    - **Tek örnek:** köprü dosya kilidi + Windows mutex + launchd tek iş; LAN merkezi `LanAuthorityLock` + tek uçuşlu `start`; uygulama Windows'ta `Local\IbulSellerDesktop.SingleInstance` mutex (ikinci kopya ilk pencereyi öne alıp çıkar, `windows/runner/main.cpp`), macOS'ta `LSMultipleInstancesProhibited`.
    - **Güvenli kapanış:** `AppLifecycleListener.onExitRequested` (`lib/main_seller.dart`) → `SellerLanCenter.stop(byOperator:false)` → `RestaurantLanHost.stop(grace)`: yeni sipariş 503 `saved:false` + `Retry-After` (garson cihazı siparişi kendi kuyruğunda tutar), süren sipariş kaydı/baskısı bitene kadar (en çok 5 sn) beklenir, sonra soketler kapanır. Sahiplik işareti kalır, sonraki açılış merkezi yeniden açar. Kalıcı kuyruklara dokunulmaz.
    - **Ağ izinleri:** macOS sandbox `network.client/server`; Windows kurulumu satıcı programına yalnız **özel ağ** profilinde gelen TCP izni ekler (`netsh`, kaldırmada siler); iOS `Info.plist` `NSLocalNetworkUsageDescription` + `NSBonjourServices(_ibul-lan._tcp)`; Android ana manifest `INTERNET` (release için açıkça).
    - **Güvenli depolama:** `flutter_secure_storage` → macOS/iOS Keychain, Windows Credential Manager (DPAPI), Android Keystore. Mühür sırları ve garson cihaz anahtarı yalnız buradadır, ayar dosyasına düşmez. Windows'ta merkez sertifika dosyaları `%LOCALAPPDATA%\IbulLan` altında kullanıcı profili ACL'iyle korunur (`chmod` karşılığı yok).
    - **macOS köprü paketi (2026-11-19):** köprü **klasör modunda** üretilir (`local_print_bridge/macos/IbulPrintBridge.spec` + `build_bridge_executable.sh` → `dist/macos/IbulPrintBridge/{IbulPrintBridge,_internal}`); tek dosya modu KULLANILMAZ (alt süreç açar, launchd soketi alt sürece vermez → `Address already in use`). `scripts/embed_print_bridge_macos.sh` klasörü `Contents/Resources/PrintBridge/` altına kopyalar, kitaplıkları ve yardımcıyı imzalar, eski `Contents/MacOS/IbulPrintBridge`'i siler; plist `BundleProgram` = `Contents/Resources/PrintBridge/IbulPrintBridge`. Canlı plist yalnız `IBUL_ALLOW_LIVE_PRINT_AGENT=YES` derlemesinde gömülür. İzole launchd provası (port 18772): yüklemede çalışmıyor, ilk istekte ~9 sn (soğuk) / <1 sn (sonraki), ikinci kopya çıkıyor, tek dinleyici. Üretim için PyInstaller'lı bir sanal ortam gerekir (depoda yok; `PYTHON=` ile verilir).
    - **Açık:** Windows derleme/çalıştırma ve kurulum bu Mac'te sınanamaz; Windows'ta mDNS yayını yok (eşleşme adres/kodla); SMAppService onayı kullanıcı eylemi; gerçek iPhone/Android testi `docs/PILOT_REAL_DEVICE_LAN_TEST_PLAN.md`.
14k. **Yazıcı merkezi: her açılışta kapalı, yalnız yetkili restoranda operatör Başlat deyince çalışır (2026-11-19; GÜNCEL 2026-11-25: operatörün son Başlat/Durdur seçimi kalıcıdır ve açılış ona uyar, bkz. en üstteki 2026-11-25 notu; yetki kapısı ve eski fiş bekletme aynen geçerli):**
    - **Oturum kapısı:** `services/print_service_start_gate.dart` (`PrintServiceStartGate`) yalnız bellekte durur; `lib/main_seller.dart` `main()` içinde `enforce()` ile her açılışta kapalı başlar. Hiçbir kalıcı işaret (eski `ibul.lan_center.owned.*` dahil) merkezi geri açmaz; `resumeCenter` artık hep `false`, panelde `resumeOwned` çağrısı YOK. Kapıyı yalnız `RestaurantCenterControl.start` açar, `stop` kapatır.
    - **Tek giriş:** `services/restaurant_offline/restaurant_center_control.dart`. `start` sırası: yetki kapısı → önceden bekleyen fişleri beklet → oturum kapısını aç → köprü (`BridgeManager.ensureReady`) → LAN merkezi. Yetki reddinde hiçbir şey başlamaz. Başlat yarıda kalırsa (`kitchen_print_management_page.dart` `_togglePrintSystemEnabled` catch) merkez geri kapatılır.
    - **Yetkisiz yol yok:** `BridgeManager.ensureReady` (dolayısıyla `ensureRunning`, kurulum sihirbazı, `desktop_printer_setup_page`, hızlı kurulum, hub `tryStartBridge`), `BridgeLifecycleService.ensureRunning` (test penceresi) ve `installLaunchAgent` kapı kapalıyken reddeder (`startGateClosed`). Restoranda oturum açılışında çalışan LaunchAgent kurulumu her zaman reddedilir. `DesktopPrintHub.start` kapı kapalıyken salt-okunur kalır: baskı işi sahiplenmez, işler kuyrukta dokunulmadan bekler; `main_seller` kapı değişimini dinleyip hub'ı açar/kapatır.
    - **Yetki kapısı:** `restaurant_center_access.dart` → `decideRestaurantCenterAccess`. Hepsi gerekir: macOS/Windows masaüstü (web/iOS/Android ret, yalnız istemci), bu cihazda mühürlü doğrulanmış hesap (`OfflinePanelIdentity`), işletme dikeyi `StoreVertical.restaurant`, restoran kaydı (yerel önbellekte masa, alan veya yazıcı), sahip ya da `managePrintSettings` yetkili personel. `SellerLanCenter.start/resumeOwned` her seferinde `accessReader` ile sorar; ret → `SellerLanCenterState.notAllowed`.
    - **Eski fişler:** Başlat anında, o andan önce oluşmuş `pending` baskı işleri `paused_by_operator` yapılır (`holdJobsWaitingSince`, not: `heldJobNote`); kendiliğinden basılmaz, operatör kuyruktan başlatır. Bulut yokken yapılamazsa internet dönünce `holdOwedOldJobs` tamamlar (`_offlineLifecycle.onReconnected`).
    - **Durdur / uygulama kapanışı:** önce LAN merkezi kapanır (yeni sipariş 503 `saved:false`, süren sipariş biter), sonra baskı kapatılır, sonra `closePrintServiceSafely`: köprüye `POST /shutdown` (`local_print_bridge/graceful_stop.py`; kuyruktan yeni iş almaz, yazılmakta olan fiş bitince yanıt verir ve kendiliğinden çıkar, en çok 30 sn bekler; yalnız loopback), en son macOS ajan kaydı bırakılır. `/shutdown` bilmeyen eski köprü öldürülmez, baskı kapalı ayakta kalır. Aynı kapanış restoran bilgisayarında her açılışta da yapılır (önceki oturumdan kalan servis kalmasın). İzole/test derlemeleri köprüyü ne başlatır ne durdurur.
    - **Diğer işletmeler:** e-ticaret, galeri, emlak için kapı açık sayılır (`noteBusiness(restaurantRules:false)`), açılış davranışı değişmedi. Türü bilinmeyen işletme restoran gibi kapalı başlar.
    - **Arayüz (yeni alan yok):** Başlat/Durdur = Yazıcı Merkezi'ndeki mevcut "Yazıcı Servisi" anahtarı; "Yazıcı Servisini Başlat" düğmesi ve Yerel Operasyon sayfasındaki başlat/durdur aynı denetimden geçer.
    - **Anahtarın gösterimi:** restoran ana bilgisayarında anahtar yalnız bu oturumdaki Başlat–Durdur arasında açık görünür (`_centerClosedThisSession`); açık kalmış bir köprü "açık" dese bile kapalı gösterilir.
    - **Gerçek deneme (izole derleme, yerel Supabase, sahte yazıcı, 2026-11-19):** açılışta LAN portu kapalı; Başlat → LAN dinliyor, önceden bekleyen 18 iş `paused_by_operator`, sahte yazıcıya 0 bayt; Durdur → LAN kapalı, köprüde baskı kapalı, kuyruk aynı; Başlat'lı oturumdan sonra yeniden açılış → kapalı. `print_jobs` tablosunda `updated_at`/`last_attempt_at` sütunu YOK (yerel şema): bekletme yalnız `status` + `last_error` yazar.
    - **Tam test takımı:** 3559 geçti, 48 kaldı; 48'in tamamı değişiklik öncesi dosyalarla (yedekler p7+p8+p9) da aynı adla kalıyor (`fails_now` = `fails_base`). Nedenler: eksik `OfflineTest.xcconfig`, `IBUL_POSTGREST` isteyen 2 test, mobil baskı servisi 7, toplu ürün içe aktarma 7, kaynak-metin denetimleri, müşteri/ödeme ekran testleri.
    - **Testler:** `test/services/restaurant_center_control_test.dart`, `local_print_bridge/tests/test_graceful_stop.py`; süren siparişin korunması `restaurant_lan_host_test.dart` "closing the app...".
    - **Açık:** paketli Windows köprüsü `/shutdown` için yeniden derlenmeli (bu Mac'te yapılamaz); o zamana dek Windows'ta köprü süreci baskı kapalı ayakta kalır. macOS `SMAppService` kayıt bırakma gerçek cihazda sınanmadı.
14l. **Gerçek macOS sipariş/yazıcı testi ve bulunan hatalar (2026-11-20):**
    - **Garson cihazı eşleşip siparişte kopuyordu (P0, düzeltildi):** uygulama içi imzalama (`lan_cert_material.dart` `signCsrWithDartCa`, `ensureServerAddress`) sertifikanın "issuer" adını PrintableString yazıyordu; CA'sı eski yolla (`openssl`, UTF8String) üretilmiş kurulumda Dart TLS adları bayt bayt karşılaştırdığı için cihaz sertifikası el sıkışmada reddediliyordu (`CERTIFICATE_VERIFY_FAILED`). Artık CA'nın konu adı baytları aynen kopyalanır (`_subjectNameDerFromCertificate`). Güvenli kapanış/merkez kapısı değişikliklerinden kaynaklanmıyordu. Test: `test/services/lan_device_cert_issuer_name_test.dart`. Düzeltmeden önce eşleşmiş cihazlar yeniden eşleştirilmelidir.
    - **Uygulama kapanışı güvenli kapanışı çalıştırmıyordu (düzeltildi):** `AppLifecycleListener` giriş ekranına bağlıydı ve girişten sonra siliniyordu; artık uygulama ömrü boyunca tek (`_SellerSessionGateState._exitListener` static). Kapanışta LAN merkezi + köprü kapanır.
    - **Eski fişler (P0):** üç katman. (1) Başlat anı `PrintServiceStartGate.startedAt`; `DesktopPrintHub._executeDispatch` bundan önce oluşmuş işi basmaz, bekletir (`jobIsFromBefore`, süpürme sorgusuna `created_at` eklendi). (2) Köprüye `print_jobs_not_before` gönderilir (`/configure/print-station` → `PRINT_STATION_JOBS_NOT_BEFORE`; `print_station.py` `job_is_from_before` + `_hold_old_job`). (3) Senkronda, Başlat'tan önce alınmış ve fişi çıkmamış (`failed`/`not_sent`) yerel sipariş buluta `uncertain` gider (`planLanOrderSync(fromEarlierSession:)`), bulut kendiliğinden basmaz. Buluttaki işaretleme (`holdJobsWaitingSince`) görünürlük içindir; başarısız olsa da eski iş basılamaz.
    - **Çevrimiçi LAN siparişi buluta gecikiyordu (düzeltildi):** merkez siparişi kabul edip fiş sonucunu kaydedince `RestaurantLanHostRegistry.ordersSettled` yayınlar; `RestaurantOfflineLifecycle.localOrderAccepted` bulut erişilebilirse hemen senkronlar (kabul anında değil: o an fiş yoldadır ve `uncertain` giderdi).
    - **Köprü /health ağ adı çözümlüyordu (düzeltildi):** her sorguda `getaddrinfo(hostname)` + gerekirse `ifconfig`; internet kesilince yanıt gecikebiliyor, uygulama her fişten önce /health sorduğu için kesintinin ilk siparişleri basılamıyordu. Artık `_cached_lan_addresses()` (30 sn önbellek, arka planda yenileme).
    - **Sıcak başlangıç:** Başlat köprü açılınca `prepareBridge` ile sınırı yollar ve `/warmup` çağırır. Kapalıyken şeritler arıza değil "Yazıcı merkezi kapalı" der (`restaurant_offline_banner.dart`, `kitchen_print_management_page.dart`). Başlat yarıda kalırsa merkez ve köprü geri kapatılır.
    - **Test derlemesi:** `AppRuntimeConfig.managedTestBridge` (`IBUL_TEST_BRIDGE_COMMAND` + port 18771 + üretim olmayan Supabase): uygulama kendi atılabilir test köprüsünü başlatıp `/shutdown` ile kapatır; canlı köprü/3001 hiç kullanılmaz. Üretim yolları (SMAppService, paketli exe) bu modla sınanmaz.
    - **Ölçüm (sahte yazıcı 127.0.0.1:19100, gerçek kâğıt çıkışı DEĞİL):** garson isteği → sahte yazıcıya bayt: sıcak 140 ms, Başlat sonrası ilk sipariş 650–710 ms; yanıt 180–770 ms; köprü → yazıcı <10 ms.
    - **Bilinen sınırlar:** LAN siparişinin baskı isteği yazıcı hedefi taşımaz (`printerSnapshot` boş); köprü kendi yapılandırılmış ağ yazıcısını kullanır, istasyon başına yazıcı seçimi bu yolda YOK. Yerel Supabase şeması uygulamanın gerisinde (`print_jobs.hub_job_received_at`, `updated_at`, `last_attempt_at` yok): hub'ın bulut kuyruğu süpürmesi yerelde çalışmaz, `resumePausedPrintJob` ve köprünün `_pause_pending_jobs` yazımları yerelde hata verir; üretim şeması salt-okunur doğrulanmalı.
    - **Gerçek cihaz adımları:** `docs/PILOT_REAL_DEVICE_LAN_TEST_PLAN.md` §9.
14m. **macOS çevrimdışı açılış / senkron turu (2026-11-20, ikinci tur) — bulunan ve düzeltilen hatalar:**
    - **İnternet yokken açılınca Başlat'a ulaşılamıyordu:** `KitchenPrintManagementPage._resolveEligibility` işletme türünü yalnız buluttan soruyordu; yanıt gelmeyince "yalnızca restoran işletmeleri içindir" gösteriyordu. Artık bulut yanıt vermezse bu cihazın daha önce doğrulayıp mühürlediği tür okunur (`readVerifiedStoreCategory`, `restaurant_center_access.dart`).
    - **İnternet yokken Başlat/Durdur geri alınıyordu:** `setPrintSystemEnabled` bulut satırını yazamayınca hata veriyor, sayfa merkezi geri kapatıyordu (Durdur'da ise köprü baskı açık halde kalıyordu). Merkez bilgisayarında ve bulut gerçekten yokken (`_cloudAnswers`) ayar yalnız bu bilgisayarın köprüsüne uygulanır (`_setPrintSystemOnThisComputer`), bulut kaydı borç yazılır (`RestaurantCenterControl.oweCloudSetting`) ve internet dönünce `holdOwedOldJobs` içinde yazılır. Yalnız son seçim tutulur.
    - **Senkron 10'luk partide kalıyordu:** `syncPendingOrders(limit: 10)` tek kez çağrılıyordu; kalan siparişler bir sonraki siparişe/bağlantı değişimine kadar bekliyordu. `RestaurantOfflineLifecycle._syncIfPending` bekleyen sayı azaldığı sürece yeniden çalışır (ilerleme yoksa durur).
    - **Başlat senkronu tetiklemiyordu:** önceki oturumdan kalan siparişlerin baskı kanıtını merkez imzalar; merkez artık yalnız Başlat ile açıldığı için gönderim hiç başlamıyordu. `PrintServiceStartGate.operatorStarted` → `RestaurantOfflineLifecycle.centerStarted` (`main_seller.dart` `_onCenterStartedForSync`).
    - **"Buluta gönderildi" işareti kalıcı dosyaya yazılmıyordu:** senkron servisi kendi `RestaurantLocalOrderQueueService` nesnesini klasörsüz kurduğu için işaretler yalnız cihaz deposuna gidiyor, `orders_<id>.json` eski kalıyordu; sonraki açılışta merkez dosyayı önce okursa gönderilmiş siparişler yeniden bekliyor görünebiliyordu. Artık klasör bir kez bilinince tüm nesneler aynı dosyaya yazar (`_journalDirectories`), merkez açılırken dosyayı devralır (`adoptJournal`, `RestaurantLanHost.start`) ve yüklemede dosya ile depo arasından daha yeni ve eksiksiz olan seçilir. Test: `test/services/order_queue_sync_marks_test.dart`.
    - **Doğrulananlar (izole derleme, sahte yazıcı):** bulut kapalı açılış → Başlat (eski fiş yok) → çevrimdışı Durdur; kesintiden sonraki 80 sn'de 18/18 sipariş tek fiş; internet dönüşü + yeniden açılış + Başlat sonrası her sipariş bulutta tek satır, fiş tekrar yok; Çıkış köprüyü ve LAN merkezini kapatır.
    - **Açık kalanlar:** (1) internet yokken açılışta restoran panelinin gelmesi 2–3 dk sürüyor (bulut isteklerinin zaman aşımı bekleniyor); (2) merkez açıkken sayfadaki "Bu cihaz yalnızca sipariş gönderir" / "merkezden sinyal yok" / "Yazıcı köprüsü kapalı" metinleri cihaz rolüne bakıyor ve yanıltıcı olabiliyor; (3) önceki oturumdan kalan fişi çıkmış siparişler Başlat'a kadar buluta gitmez; (4) yeniden derlenen uygulamada macOS güvenlik duvarı gelen bağlantı onayı beklerken LAN portu dinler ama bağlantı kabul etmez (kullanıcı onayı gerekir); (5) yerel şemada `orders.local_order_id` üzerinde tekil dizin yok, mükerrer koruması uygulama tarafında.
    - **Test betikleri:** `~/IBUL_isolated_build/scripts/` (`build_kc_managed.sh`, `test_bridge.sh`, `e2e.sh`, `fake_printer_ms.py`) — geçici klasör yeniden başlatmada silindiği için buraya taşındı.
14. **Baskı belirsizliği (2026-11-19):** yerel sipariş buluta **her zaman imzalı kanıtla** gider, kanıtsız gitmez. `printed/forwarded`→forwarded, `failed` ve `not_sent` (hiçbir yazıcıya iletilmedi, artık kayıtlı gerçek durum)→failed (bulut basabilir), **diğer her şey** (`pending`, boş, `uncertain`, bilinmeyen; merkez yazıcıya yazıp durumu güncellemeden durmuş olabilir)→uncertain: sunucuda iş `failed/locally_uncertain` olur, operatör onayı olmadan basılmaz. Çok istasyonlu siparişte biri iletilmiş biri başarısızsa sonuç `uncertain` (`combineStationPrintStatuses`). Edge doğrulayıcı: gönderilmiş ama doğrulanamayan/biçimi bozuk kanıt 'rejected' olarak iletilir (sunucuda duraklatılır), asla "kanıt yok"a düşmez. Kimlik (`local_order_id`) ve yerel kayıt korunur. 15 dk içerik kuralı artık tek mekanizma değil. Testler: `lan_print_ambiguity_test.dart`, `restaurant_lan_host_test.dart` ("LAN print state…"), Deno testi.

**LAN yazıcı ve merkez durumu sözleşmesi (2026-11-22, P11):** LAN siparişinin mutfak fişi, merkezde `lanStationPrinterResolver` (`ibul_app/lib/services/restaurant_offline/lan_station_printer.dart`) ile çözülen İSTASYON yazıcısına gider; hedef `RestaurantLocalPrintJobRecord.printerSnapshot`'ta saklanır, `resolution_error` taşıyan iş köprüye gönderilmez (kesin `failed`). Telefon Mac'teki durumu salt-okunur `POST /lan/center/status` ile okur (`lan_center_status.dart`, `WaiterLanLink.centerStatus()`, kart `widgets/lan_center_status_card.dart`); telefonun kendi köprüsü kapalı diye "merkez kapalı" gösterilmez. Gerçek cihaz prosedürü: `docs/PILOT_REAL_DEVICE_LAN_TEST_PLAN.md` §10.

## 5. Doğrulama durumu (PASS / FAIL / BLOCKED)

| Özellik | Durum | Kanıt / not |
| --- | --- | --- |
| **(2026-11-21)** Gerçek uygulama (`com.ibul.sellerdesktop` Release): Yazıcı Servisi Başlat/Durdur/yeniden Başlat/çıkış | PASS (gerçek uygulama) | progress "P0"; 3001'de tek köprü, `/health ok` |
| **(2026-11-21)** Gerçek uygulama: Otomatik Tara, salt-okunur eşleştirme, 1 onaylı TEST fişi | PASS (köprü kaydı; kâğıt teyidi BEKLİYOR) | progress "P1"; arayüzden yazıcı Kaydet DENENMEDİ |
| **(2026-11-21)** Alt yönetici `managePrintSettings` sunucu yazma (printers/stations/station_printers/print_station_configs) | **FAIL — BLOCKED (onay)** | migration `20261122090000` production'a uygulanmadı; yalnız sahip yazabiliyor |
| **(2026-11-21)** Personel şifre/iptal migration'ları (`20261121090000/100000`) | Yalnız izole/yerel BİRİM+SQL (94/94, 33/33); production UYGULANMADI | ekran testi iOS sim + test derlemesi (**gerçek uygulama değil**) |
| **(2026-11-21)** iPhone→Mac LAN→Yazıcı, gerçek WAN kesme, 12 sa mühür iptali | TEST EDİLMEDİ / BLOCKED / AÇIK | `docs/RESTAURANT_WORKING_CHECKPOINT.md` §3b |
| Önce kayıt sonra fiş; 403'te sıfır baskı | PASS | `test/services/kitchen_print_after_commit_test.dart` (sahte sunucu + sahte köprü); üretim günlüğünde 403 görüldü |
| Aynı istek tekrarı → tek fiş; iki gerçek sipariş → iki fiş | PASS | aynı test + `test/utils/kitchen_logical_key_order_identity_test.dart`; yerel köprü + sahte yazıcı |
| Fişte doğru masa (Bahçe 1/4, Salon 1) | PASS | `test/utils/kitchen_table_label_fields_test.dart`, köprü günlüğü |
| Servis kapalıyken baskı engeli | PASS (test köprüsü) | `local_print_bridge/tests/test_print_station_configure_reload.py`; üretim köprüsü (3001) yeniden başlatılmadı |
| `printer_id` kimlik uyuşmazlığı düzeltmesi | PASS (birim + yerel tetikleyici) | `test/services/print_job_payload_identity_test.dart`; gerçek RPC ile denenmedi |
| Bağlantı izleme, WAN kesintisinde otomatik yerel mod | PASS (sahte yoklama + yerel ekran) | `test/services/restaurant_connectivity_wan_cut_test.dart`; yerel derlemede menü ~20 sn'de daraldı |
| Yerel merkez dinleme ve kendiliğinden açılış | PASS (izole + yerel derleme) | `test/services/seller_lan_center_real_interface_test.dart` (`IBUL_LAN_REAL_IFACE=1`), yerel derleme 192.168.10.158:18783; **üretime bağlı Debug'da hiç başlatılmadı** |
| Çevrimdışı açılış kararı | PASS (karar) | `test/services/offline_panel_identity_test.dart` |
| Garson sayfasının internetsiz yüklenmesi | PASS (ekran, yerel derleme, 2026-11-18) | Bulut kesikken tam kapat-aç: giriş ekranı yok, spinner yok, 23 masa, menü Garson+Sistem, LAN merkezi 18783. Üç kök neden düzeltildi: (1) uygulamanın kendi yaptığı menü geçişi modül yükleyicisini çalıştırmıyordu (`_seedGarsonAfterProgrammaticSwitch`), (2) bulut yüklemesi atlanınca önbellek masaları panoya aktarılmıyordu (`applyInitialBootstrap` çağrısı), (3) önbellek ürün stoğunu saklamıyordu, tüm ürünler "stok 0" olup Ekle kapanıyordu (`_productToCacheMap`, `sellerProductsFromOfflineSnapshot`) |
| Çevrimdışı masa sayfasında ürün listesi | PASS (ekran) | Uyarı şeridi + 9 önbellek ürünü, Ekle çalışıyor |
| Çevrimdışı sipariş → kalıcı yerel kayıt → yeniden açılış | PASS (ekran, baskı kapalı derleme) | Bahçe 8'e iki sipariş; yerel günlükte iki kayıt (`pendingSync`), tam kapat-aç sonrası korundu, şeritte "2 yerel sipariş senkron bekliyor" |
| Bulut dönünce senkron (basılmamış sipariş) | PASS (yerel Supabase) | Üç deneme boyunca her `local_order_id` için tek `orders` satırı (41→43), yerel kayıt bulut kimliğiyle `synced`. Menü ~10 sn'de tam haline döndü |
| Çevrimdışı tek mutfak fişi (ekran → sahte yazıcı) | PASS (2026-11-18, korumalı köprü) | Bulut kesik, Bahçe 8: sipariş → yerel günlük (`printed`) → 127.0.0.1:19100'e tek fiş; başlık "Bahçe 8", anahtar sipariş kimliğini içeriyor. Aynı içerikli ikinci sipariş → ikinci fiş. Aynı anahtarın köprüye tekrarı → `duplicate`, 0 bayt. Servis kapalı → 503, 0 bayt. Gerçek yazıcı adresine 0 bağlantı denemesi |
| Basılamamış fişin senkronda telafisi | PASS (gözlem) | Çevrimdışı baskısı `failed` kalan sipariş bulut dönünce tek kayıt + tek fiş |
| Bulut dönünce senkron (fişi basılmış sipariş) | PASS (2026-11-18, yerel) | Ekran: çevrimdışı sipariş → tek fiş → bulut dönüşü → 2 deneme doğrulayıcı kapalıyken güvenle başarısız → uygulama yeniden başlatma → 3. denemede doğrulanmış kanıtla tek `orders` satırı, yerel `synced`, baskı işi `paused_by_operator/local_forwarded`, sahte yazıcıya 0 ek bayt. Temiz DB: `scripts/run_lan_evidence_sync_test.sh` (SQL kayıt kanıtı + `lan_bridge_sync_test.dart` 3/3). Üretime dağıtılmadı |
| Üretim şema uyumu (salt okunur, 2026-11-18) | PASS (koşullu) | Üretim `ihmixxzqnpamcwmrfibx`: tüm 7 işletmenin aktif birincil şubesi var, tekrar birincil yok; `orders.local_order_id` + tekil indeks var; üretim `create_table_order_with_print_jobs_impl` gövdesi `2026103101` ile bayt bayt aynı (md5 f7dca415…), yani migration'ın "Based on" varsayımı doğru. Üretimde kanıt tabloları/fonksiyonları ve `verify-lan-print-evidence` yok; `list_migrations` yalnız `remote_commit` (migration geçmişi izlenmiyor) |
| Gerçek Edge çalışma ortamı (Deno) | PASS | Deno 2.9.8, gerçek `index.ts`, kısıtlı izinler, sahte Supabase; 5/5 (geçerli imza, sahte/yeniden kullanılmış/iptal/üs≠65537, 401/405/500 kapıları) |
| Uygulama açılışında LAN merkez + senkron | PASS (birim + gerçek yerel masaüstü derlemesi) / açık (bulut kesintisi ekranda) | Birim: `restaurant_offline_lifecycle_test.dart` 6/6. Gerçek derleme (`build_macos_local_debug.sh`, ana klasör kodu, 2026-11-19): açılışta `[OfflineLifecycle] start #1` bir kez, `center resumed=true`, 192.168.10.158:18783 dinliyor, Garson sayfası günlüğü yok; sahiplik işareti silinince merkez AÇILMADI (0 dinleyici); işaret geri konup yeniden açılışta tek başlangıç + tek dinleyici; yerel sipariş kuyruğu anahtarı yeniden açılışta duruyor. **Denenmedi:** bulut kesintisi + bekleyen sipariş + bulut dönüşü senkronu bu derlemede ekranla yürütülmedi (yalnız birim/izole PG kanıtı) |
| Anahtar Zinciri kalıcılığı (imzalı macOS, gerçek cihaz) | PASS (izole imzalı probe) / açık (gerçek uygulama) | `ibul_app/tool/keychain_probe/build_and_run.sh`: Firebase'siz ayrı macOS hedefi (`com.ibul.keychainProbe`, Apple Development imzası, takım B4849QMKTU, `keychain-access-groups` doğrulandı), uygulamanın gerçek `SecureLocalStore` + `OfflinePanelIdentityStore` kodu. Beş aşama ayrı süreçte (write→read→tamper→nokey→cleanup): sır ve kuyruk Anahtar Zinciri'ne yazıldı, SharedPreferences'a kopya düşmedi, tam kapat-aç sonrası kimlik mührü `ok`, düzenlenmiş kayıt `tampered`, cihaz anahtarı silinince `noDeviceKey` ile reddedildi. **Açık:** gerçek uygulamanın `macos/Runner/DebugProfile.entitlements` dosyasında `keychain-access-groups` YOK (yalnız Release'te var) → gerçek Debug derlemeleri Anahtar Zinciri'ne yazamaz (-34018) ve SharedPreferences'a düşer; bu yüzden bu güvenlik doğrulaması gerçek uygulamanın Debug'ında değil probede yapıldı. Release imzası/noter onayı denenmedi; ücretsiz sağlama takımı kullanıldı |
| LAN personel yetkileri (alt yönetici, ayrı garson cihazı) | PASS (birim + gerçek TLS LAN sunucusu) | §4 madde 13; 12 negatif test. Çevrimdışı mühürlü yetki: §4 madde 14b; gerçek uygulamada (yerel Supabase, kong durdurularak) doğrulandı: yetkili garson bulut yokken sipariş gönderdi, yetkisiz eşleşemedi, kimlik taklidi reddedildi, kapat-aç sonrası yetki ve kayıt korundu, bulut dönünce 3 sipariş tek sefer (çift yok) senkronlandı. Kalan: gerçek ayrı telefon/tablet; geçici-şifre işareti: §4 madde 14c (yerel migration; production'a uygulanmadı) |
| Baskı belirsizliği / çift baskı | PASS (birim + sahte yazıcı + Deno) | §4 madde 14; `lan_print_ambiguity_test.dart` 7 test, host testleri; gerçek DB/PostgREST testi yok (`lan_bridge_sync_test.dart` önceden BLOCKED) |
| Sipariş RPC 9→12 argüman uyumu (izole PG) | PASS | `scripts/rehearse_order_rpc_migration.sh`: üretim durumu (md5 f7dca415…/7ddf4b5b… yeniden kuruldu) → eski istemci çağrıları (adlandırılmış 9, konumsal 9, asgari, gerçek `approve_waiter_order_request` 8 konumsal) önce/sonra aynı; yanıta yalnız `print_disposition` eklenir; anon çalıştıramaz; eski satırlar korunur; geri dönüş üretim md5'lerine döner. İzole şema üretimden küçük (para/tekilleştirme tetikleyicileri yok) |
| Çevrimdışı kimlik mührü | PASS (birim + yerel derleme) | `test/services/offline_identity_seal_test.dart` (13 test); yerel derlemede mühürlü kayıtla açılış |
| LAN üzerinden sipariş → yerel kayıt → fiş | PASS (sahte köprü) / BLOCKED (ekran) | `test/services/restaurant_lan_host_test.dart`; Garson cihazından uçtan uca denenmedi |
| İnternet gelince tekilleştirilmiş senkron | BLOCKED | PostgREST senkron testi (`lan_bridge_sync_test.dart`) Deno/ayrı Postgres olmadan çalışmıyor; yerel Supabase'te `local_order_id` tekrarı tek sipariş verdi |
| Personel kuralları (şifre, yetki, çevrimdışı süre) | PASS (birim) | `test/features/staff_*_test.dart`; gerçek personel girişi ekranda doğrulanmadı |
| Masa kapatma sonrası liste dönüşü, müşteri adı, geçmiş arama | Kodlandı, ekranda doğrulanmadı | `table_history_search_test.dart`, `table_customers_map_test.dart` |
| Masa kapatma hızı | BLOCKED | Yerel DB'de kapatma fonksiyonları yok; ölçülmedi |

## 6. İzole test ve üretim farkları

| | Üretime bağlı Debug | Yerel Debug | Eski izole test |
| --- | --- | --- | --- |
| Paket kimliği | `com.ibul.sellerdesktop.debug` | `com.ibul.sellerdesktop.debuglocal` | `com.ibul.sellerdesktop.offlinetest` |
| Supabase | üretim (gömülü yapılandırma) | yerel `127.0.0.1:54321` | yerel |
| Köprü | `18771` test köprüsü (`IBUL_ISOLATED_BRIDGE_PORT`) | verilmez, baskı kapalı | `18771` |
| Otomatik baskı (`IBUL_DISABLE_PRINT_START`) | kapalı | kapalı | kapalı |
| LAN portu (`IBUL_LAN_PORT`) | 18773 | 18783 | 18773 |
| Keychain hesabı | `ibul.sellerdesktop.debug` | `ibul.sellerdesktop.debuglocal` | `…offlinetest` |

- Derleme betikleri repo dışındadır: `/private/tmp/claude-501/build_macos_real_debug.sh`, `build_macos_local_debug.sh`, `build_macos_test_final.sh` (geçici; sistem yeniden başlayınca silinebilir). Çıktılar `~/IBUL_isolated_build/DerivedData*`.
- Üretim köprüsü `3001`, test köprüsü `18771`, sahte yazıcı `127.0.0.1:19100` (`/private/tmp/claude-501/fake_printer.py`), yerel Supabase `~/ibul-local-staging` (Colima + Docker).
- Yerel Supabase'te üretim şeması eksik olabilir; yerelde onaylanan davranış üretimle aynı olmayabilir (örnek: yerel RLS kapalı).

## 7. Açık hatalar, tamamlanmamış işler ve teknik borç

1. **Çözüldü (2026-11-18):** `seller_panel_page.dart` biçim gürültüsü temizlendi. HEAD farkı 5.893 → 794 satır (712 ekleme, 82 silme); `dart format` çıktısı temizlik öncesi dosyayla birebir aynı (belirteç düzeyinde eşdeğer). Yedekler: `~/IBUL_safety_backups/20261118-1955/` (`.current`, `.cleaned`, fark dosyaları, `unformat.py`). **Bu dosyaya yine `dart format` çalıştırma.**
2. Garson sayfası çevrimdışı yüklemesi (yukarıdaki FAIL) derlenip doğrulanmalı.
3. Çevrimdışı sipariş → senkron → geri dönüş senaryoları ekranda koşulmadı.
4. **Güvenlik (kısmen çözüldü, 2026-11-18):** çevrimdışı kimlik kaydı artık cihaza bağlı mühür taşır (§4 madde 7). Kalan risk: mühür anahtarı Anahtar Zinciri'ndedir; aynı işletim sistemi hesabıyla Anahtar Zinciri'ni okuyabilen biri mührü yeniden üretebilir. Sunucu imzalı çevrimdışı yetki belgesi (istemcide yalnız açık anahtar) bunu kapatır ama yeni Edge Function + üretim dağıtımı ister; yapılmadı, onay bekliyor. İmzasız test derlemeleri Anahtar Zinciri'ne yazamaz (-34018); onlarda çevrimdışı açılış yalnız `IBUL_DEBUG_UNPROTECTED_OFFLINE_SEAL=true` (yalnız debug) ile çalışır.
5. Yerel merkez personelin "geçici şifre" işaretini üyelik kaydından göremez (işaret oturum belirtecinde; `store_sub_admins` tablosunda sütun yok). Kapatmak için sunucu tarafı değişiklik gerekir (üyelik sütunu veya Edge Function); dağıtılmadı.
5b. macOS Debug (`macos/Runner/DebugProfile.entitlements`) `keychain-access-groups` taşır (Apple Development imzası şart; ad-hoc imza bu yetkiyle açılmaz). Sandbox'lı derleme artık LAN merkezini açar (§4 madde 14d). Gerçek AOT Release derlemesi (Apple Development imzası, `Release.entitlements`, bundle `com.ibul.sellerdesktop.releaseiso`, yerel Supabase define'ları) 2026-11-19'da BAŞARILI: `kernel_blob` yok (AOT), `codesign --verify --deep --strict` OK, yetkiler sandbox+network.client/server+keychain grubu; uygulama açıldı, sandbox konteyneri oluştu, çökme yok. Açık: Release'te giriş yapıp LAN merkezini uçtan uca çalıştırmak (elle) ve `get-task-allow` taşımayan dağıtım imzası.
6. Ara ödeme: sunucu toplamı (`guard_table_payment`) yalnız `line_total`/`price×quantity` toplar; uygulama karışık servis ürünlerinde alt kalemleri sayar. Şubat'tan kalma açık satırlarda fiyat metin ("₺544") ve sayı çevirme hatası verebilir. Üretim fonksiyonu değişikliği onay bekliyor.
7. Köprü 15 dk içerik anahtarı: sipariş kimliği taşımayan istekte aynı masa+ürün ikinci fişi basmayabilir. LAN yolunun anahtarı her zaman gönderdiği doğrulanmadı.
8. Müşteri: elle hızlı ad girişi var, ama telefonsuz girişte işletme müşteri listesine kayıt eklenir; geçici-ad seçeneği, geçmiş kaydında müşteri alanı ve müşteri/telefonla geçmiş arama şema değişikliği ister (migration hazırlanmadı).
9. Alan: yazıcı atamasını kaldıran arayüz yok; ürün listesi 500 ile sınırlı.
10. Personel silme gerçek silme değil pasifleştirme; düzenleme (ad, şube, izinler) ve güvenli davet akışı yapılmadı. Panel "3 pasif" kayıtlarını kasıtlı pasifleştirme saymak için kayıt geçmişine bakılmadı.
11. Çevrimdışı açılışta oturum geri yükleme varsayımı yerel derlemede doğrulandı; üretime bağlı Debug'da denenmedi.
13. **Senkron kapısı (yerelde çözüldü, üretim dağıtımı bekliyor):** (a) doğrulayıcı adresi derleme ayarı `IBUL_LAN_EVIDENCE_VERIFIER_URL` (https zorunlu; yalnız 127.0.0.1/localhost için http), ayar yoksa basılmış sipariş yerelde bekler; çağrı kullanıcının oturum belirteciyle yapılır. (b) Yerel merkez açılırken sahip oturumu açık anahtarını `register_restaurant_lan_print_evidence_key` ile kaydeder (yalnız sahip; anahtar kimliği = SHA-256(modül) ilk 16 hane; iptal edilen anahtar geri gelmez; özel anahtar cihazdan çıkmaz). (c) Şubesiz masalar işletmenin **aktif birincil şubesi** üzerinden karşılaştırılır (`restaurant_primary_branch_id`); denetim gevşetilmedi, şube uydurulmaz: birincil şube yoksa kayıt reddedilir. Merkez şubesini kayıttan öğrenir ve cihazda saklar (`ibul.lan_center.branch.*`); şubesi olmayan merkezin basılmış siparişleri gönderilmez. (d) Yerelde Node ikizi `node_server.mjs` (PORT ile) çalıştırıldı. Migration: `20261119090000_lan_print_evidence_key_registration.sql`. Üretim için: bu migration + `20261103223000` uygulanmış mı kontrol + Edge Function `verify-lan-print-evidence` dağıtımı + derlemeye adres. **Dağıtımdan önce:** üretimde her restoranın aktif birincil şubesi var mı (salt-okunur sorgu) ve `store_branches`/`stores` sütunları migration'ın varsayımıyla uyumlu mu doğrulanmalı. Yerel merkez artık uygulama açılışında (oturum kapısı) başlıyor, bkz. §4 madde 12; kanıt imzası senkron anında üretiliyor.
    - **Servis anahtarı başlığı (2026-11-22):** doğrulayıcı `serviceKeyHeaders` kullanır — JWT biçimli `service_role` → `Authorization: Bearer` + `apikey`; yeni tip `sb_secret_…` → YALNIZ `apikey` (Bearer'da gönderilirse `PGRST301 Expected 3 parts in JWT`). Production v1 bu hatayı taşıyor; düzeltme yerelde, dağıtım onay bekliyor. Yerel sipariş karantinası yaşa göre DEĞİL kimliğe göre: `quarantinedLocalOrderIds` (`restaurant_offline_sync_service.dart`).
    - **Çevrimdışı masa kapatma (taslak, yalnız yerel):** sözleşme `docs/OFFLINE_TABLE_SETTLEMENT_CONTRACT.md`; migration `ibul_app/supabase/migrations/20261122160000_offline_table_settlement.sql` production'a UYGULANMADI; kanıt `ibul_app/supabase/tests/run_isolated_offline_table_settlement.sh`. Uygulamadaki `offlineMoneyOperationBlock` bu sözleşme canlıya alınana kadar kalır.
14. **Gerçek yazıcı riski:** eski test köprüsü (`/private/tmp/claude-501/ibul-test-bridge-data`) 16–17 Kasım'da 192.168.10.100:9100'e ~30 başarılı fiş/adisyon göndermiş; `last_kitchen_tcp` yedeği o adresi gösteriyordu. Köprüde hedef adres kısıtı yok. Artık testler **yalnız korumalı köprüyle** yapılır: `~/IBUL_isolated_build/guarded-bridge/loopback_only_bridge.py` (loopback dışı her bağlantıyı reddeder ve `blocked_connections.log`'a yazar; kendi veri klasörü, `last_kitchen_tcp=127.0.0.1:19100`). Yerel DB'de `POS Yazıcı - 100` pasifleştirildi, ürünler `Zincir Ocak` alanına bağlandı, mutfak/adisyon rolü sahte yazıcıya atandı. Eski köprü yeniden başlatılmamalı.
20. **Çevrimdışı baskı yolu bulut okuyordu (düzeltildi):** yazıcı listesi, alan–yazıcı eşlemesi ve yazıcı yapılandırması okumaları bulut erişilemezken hata verip fişi engelliyordu. Artık son başarılı okuma cihazda saklanır ve yalnız erişilemezlik hatasında kullanılır (`printer_repository.dart`: `rememberLastGoodRows`, `lastGoodRowsWhenUnreachable`; `print_station_service.dart`: `fetchStationConfig`). Cihaz bir kez çevrimiçi açılmış ve mutfak rolü atanmış olmalı; rol ataması yoksa "Mutfak yazıcısı atanmadı" ile fiş çıkmaz.
23. Senkronlanan yerel kayıtta eski `syncError` metni temizlenmiyor (yalnız görsel). **Çözüldü (2026-11-18):** Deno 2.9.8 kuruldu (brew); gerçek `index.ts` Deno alt süreci olarak sahte Supabase'e karşı 5/5 geçti (`ibul_app/supabase/tests/verify_print_evidence_deno_test.ts`). Biçimi bozuk kanıt jetonu 'kanıt yok' olarak iletilir (basılmış sayılmaz).
21. **Yerel test DB durumu:** (2026-11-18 ek: yeni migration uygulandı, sipariş RPC'sine yerel tetikleyiciler için izin satırları yeniden eklendi `local_impl_v2_with_local_grants.sql`; test restoranına `TEST-MERKEZ` birincil şubesi eklendi. Tekrarlanabilir kanıt bu DB'ye değil `scripts/run_lan_evidence_sync_test.sh` geçici veritabanına dayanır.) `20261103223000_order_sync_print_evidence.sql` yanlışlıkla kalıcı uygulandı ve yerel sipariş RPC'sinin elle yamalı sürümünün üzerine yazdı; yerel para-yetki tetikleyicileri için izin kayıtları eklenerek onarıldı (`~/IBUL_safety_backups/20261118-1955/local_impl_repaired.sql`). Önceki yerel sürümün kopyası yok. Yerel taban şemaya (`~/ibul-local-staging/sql/restaurant_baseline.sql`) `print_jobs.last_error/printed_at` ve `station_printers` yabancı anahtarları eklendi; yerel `ibul_order_money_*` yardımcıları ve tetikleyicileri repoda yok.
22. **Düzeltildi:** çevrimdışıyken ham bağlantı hatası gösterilmiyor; erişilemezlikte metin "Bulut erişilemiyor. Sipariş listesi yenilenemedi." Masa kartı, fişi basılamayan yerel siparişte "Kaydedildi · Fiş basılamadı/belirsiz/bekliyor" yazıyor (`lanFloorPrintStatusLabel`); senkron bitince pano kendiliğinden yenileniyor (`_refreshGarsonBoardAfterSync`). Üçü de birim testli/kod düzeyinde; "Fiş basılamadı" metni ve otomatik yenileme ekranda ayrıca gözlenmedi. Rol eşleştirmesi yerelde bulut kaydı başarısız (`cloud_saved=false`) kaydedildi.
15. Masa kartı, fişi basılamayan çevrimdışı siparişte de "Mutfağa İletildi" yazıyor (uyarı şeridi doğru). **Fazladan satır düzeltildi:** senkronlanmış yerel günlük kayıtları panoya bulut kaydının yanında ikinci kez ekleniyordu (`_hydrateLanFloorBoard`); artık atlanır (`lanFloorOrdersAfterJournal`, test `test/utils/lan_floor_orders_after_journal_test.dart`). Gerçek DB'de mükerrer sipariş yoktu. Oturum içinde senkron bittiğinde kart, Garson yeniden açılana kadar eski satırı gösterebilir.
16. Masa alanı değiştirme, adisyon satırı düzenleme/silme ve adisyon yazdırma çevrimdışı için ayrıca engellenmedi/doğrulanmadı; bulut çağrısı hata verir.
17. Çevrimdışı yönlendirici için birim test yok (tekrar gönderimde tek kayıt/tek fiş yalnız ekranda ve kod okumayla doğrulandı). Yerel test DB'sine `print_jobs.last_error`, `printed_at` sütunları elle eklendi (üretim migration'ında var).
18. **Düzeltildi:** izni olmayan (garson rolünde olmayan) personel artık hiçbir bölüm görmüyor; `modulesForStaff` içindeki Garson yedeği kaldırıldı. Eski kuralı bekleyen `test/services/staff_menu_gate_test.dart` testi yeni kurala çevrildi. Gerçek işlem yetkisi ayrı: sunucuda `restaurant_has_permission`, LAN'da `staffStillAuthorized` (`restaurant_lan_host_test.dart`). Gerçek personel hesabıyla ekranda denenmedi.
19. İkinci tur değişikliklerinin yaması: `~/IBUL_safety_backups/20261118-1955/session2-changes.patch` (ilk tur `session-changes.patch` ana klasöre uygulandı). Derleme betiği: aynı klasörde `build_wt_local_debug.sh` (yerel Supabase, korumalı köprü 18771, LAN 18783).
12. Bilinen önceden başarısız testler (temiz HEAD'de de başarısız): `mobile_order_print_service_test`, `lan_bridge_sync_test`, `money_session_catch_log_test`, `seller_logout_helper_test`, `bulk_product_*`, `desktop_printer_setup_page_test` vb. Köprü Python testlerinde 20 başarısız (HEAD'de de).
13. **Üretim güvenliği — `table_order_history` yazma sertleştirmesi (2026-11-23, VERIFIED salt-okunur katalog):** Operatör `ibul_app/supabase/drafts/20261123_table_order_history_write_hardening_DRAFT.sql` dosyasını Supabase SQL Editor'den elle çalıştırdı (migration geçmişinde kayıt YOK; uzlaştırma gerekir, bkz. `docs/RESTAURANT_PILOT_PROGRESS.md`). Doğrulananlar: `table_order_history_staff_update_guard` (BEFORE UPDATE, etkin; yalnız `display_table_label/table_area_name/waiter_id/waiter_name/updated_at` personelce değişir), `table_order_history_audit_trg` + `audit_table_order_history_change()`, `table_order_history_audit` (RLS açık, authenticated yalnız SELECT, politika `seller_id = auth.uid()`), tabloda anon yetkisi yok, authenticated yalnız SELECT/INSERT/UPDATE/DELETE, `close_table_orders` gövdesinde `restaurant_staff_may_operate(...'closeBill'...)`, iki kapanış RPC'sinde anon/public EXECUTE yok, `guard_restaurant_staff_order_write` ve RLS politikaları değişmedi. **Gerçek kullanıcı oturumuyla yetki testi NOT VERIFIED.** `close_table_orders` içindeki `table_orders.seller_id`(text)=uuid tip hatası bilinçli düzeltilmedi (fonksiyon bugün çalışmıyor; uygulama `close_table_with_history`'ye düşüyor).
14. **Satıcı paneli arayüz turu (2026-11-23, testlerle doğrulandı; gerçek uygulamada GÖRÜLMEDİ):** (a) Ortak sağ üst Yenile: `SellerPanelTopBar.onRefresh/refreshBusy` + `SellerPanelTabletShell`; panelde `_refreshCurrentModule()` (`seller_panel_page.dart`). **Yalnız** Ürünlerim, Alt Yöneticiler ve Reklam'da çıkar (`_topBarRefreshVisible`); gerçek ekranda Genel Bakış, Listeler, Siparişler, AVM, Finans, Başarılarım, Yorumlar, Garson, Sistem kendi Yenile düğmesini taşıdığı için ikincisi çizilmez. Mağaza Profili'nde bilerek YOK (yenileme doldurulmuş formu sunucu verisiyle ezerdi: `_syncStoreProfileControllersFromData`); Sözleşmeler/Destek/Araç/İndir'de de yok (yeniden kurma açık formu kaybettirir). Çevrimdışı kilitli sayfalarda düğme yok. Test: `test/features/seller/panel/seller_top_bar_refresh_test.dart`. (b) Çevrimdışı menü kilidi zaten vardı (`offline_page_policy.dart`, `SellerMenuItemState.lockedOffline`, `OfflineBlockedModuleView`); değiştirilmedi. (c) `widgets/restaurant_local_ops_page.dart` kart tabanlı yeniden tasarlandı (durum rozetleri, Garson cihazları, Kayıtlı yazıcılar = yerel önbellekteki `printers`, Senkron, Baskı); mantık/anahtarlar (`lan_pairing_link`) aynı. Test: `test/widgets/restaurant_local_ops_page_test.dart`. (d) Alt Yöneticiler kartı (`features/seller/staff/staff_team_panel.dart`): avatar + durum rozeti, tek "Yetkileri düzenle" düğmesi, ikincil işlemler menüde (Pasifleştir/Aktifleştir/Şifre belirle/Sil); `canManage`/`isOwner`/`canDelete` kapıları aynen. Test: `test/features/staff_team_panel_card_test.dart`. (e) Geçici müşteri adı: kapanışta sunucudan silinemezse ad yeni misafire dönmez (`_pendingTableCustomerClears`).

24. **Sipariş RPC migration planı (üretime uygulanmadı):** `20261103223000` 9 argümanlı `create_table_order_with_print_jobs` ve `_impl` fonksiyonlarını DROP edip 12 argümanlı (son 3'ü `default null`) sürümleri kurar. Üretim bağımlılıkları (salt okunur, 2026-11-18): tek PL/pgSQL çağıran `approve_waiter_order_request` (8 konumsal argüman, 12'liye çözülür); `pg_depend`'te trigger/view bağımlılığı yok; ACL aynı kalır (postgres, authenticated, service_role; anon/public yok). **Her migration dosyası kendi BEGIN/COMMIT'ini taşır: ayrı ayrı uygulanır, dışarıdan tek işleme sarılmaz.** Sıra: `20261103223000` → `20261119090000` → Edge Function `verify-lan-print-evidence` → derleme adresi. Ön koşul: şubesiz restoran sorgusu yeniden (şu an 0). **Geri dönüş:** (1) 12 argümanlı iki fonksiyonu DROP et, (2) `ibul_app/supabase/manual_patches/20261031_live_restaurant_rpc_ROLLBACK.sql` (üretim md5'leri: impl f7dca415… 14301, sarmalayıcı 7ddf4b5b… 204) çalıştır; tablolar/ek fonksiyonlar eklemeli, zararsız kalır. İzolede uçtan uca prova edildi. Migration geçmişi üretimde izlenmiyor (`list_migrations` yalnız `remote_commit`): uygulamadan sonra manuel not düşülmeli.

## 8. Hangi test neyi doğrular

| Test | Doğruladığı |
| --- | --- |
| `test/services/kitchen_print_after_commit_test.dart` | kayıt-fiş sırası, 403/bağlantı kopması, tekrar, çapraz masa |
| `test/utils/kitchen_logical_key_order_identity_test.dart` | tekilleştirme anahtarı sipariş kimliği |
| `test/services/print_job_payload_identity_test.dart` | payload/sütun `printer_id` hizası |
| `test/services/printer_readiness_test.dart`, `print_start_disabled_test.dart` | ortak hazır durum, baskı kapısı |
| `test/services/restaurant_connectivity_wan_cut_test.dart` | bulut kesinti algılama ve geri dönüş |
| `test/services/seller_lan_center_*_test.dart`, `restaurant_lan_host_test.dart` | yerel merkez, LAN host, güvenlik |
| `test/services/offline_panel_identity_test.dart` | çevrimdışı açılış kararı ve süreler |
| `test/features/staff_*_test.dart` | şifre penceresi ve yetki kuralları |
| `local_print_bridge/tests/test_print_station_configure_reload.py` | servis anahtarının canlı işleyicilere ulaşması |

## 9. Kod değiştirmeden önce

- Önce §2'deki ilgili satırı bul; yalnız o dosyaları ve ilgili §4 sözleşmesini oku. Aynı hata §7 veya §5'te çözülmüş/kanıtlanmışsa analizi baştan yapma.
- Üretime yazma, gerçek yazıcıya baskı, canlı servis değişikliği ve migration için ayrıca onay al. Parola, anahtar veya kişisel veriyi dosyaya/loga yazma.
- Büyük dosyalarda (`seller_panel_page.dart`, `kitchen_print_management_page.dart`, `order_print_job_service.dart`) dar `Edit` kullan; biçimlendirici çalıştırma.
- Görev sonunda değişen sözleşmeyi §4'e, durumu §5'e, açık işi §7'ye işle. Tüm dosyayı yeniden okuma/yazma.

---

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
- `Kritik sözleşme (2026-11-21):` İş alma Realtime'a bağlı değil; 1 sn'lik `pending` taraması (`_recoverPendingJobs`) tek başına yeterli. Sahiplenmeden (`claimed`) sonra ve köprü çağrısından ÖNCE atılan istisna işi `failed` yapar (`_failClaimedJobBeforeDispatch`, yalnız `status='claimed'` iken); köprü çağrısı başladıktan sonraki belirsiz iş asla otomatik `pending`/`failed` yapılmaz. `PhysicalPrintGate` iznini hub kendi `checkBridge()` sağlık yanıtından besler (yalnız Garson modülü yoklamasına bağlı değil). `print_jobs` zaman damgaları UTC yazılır.
- `Çevrimdışı fiş sözleşmesi (2026-11-21):` LAN ile gelen siparişin yerel fişi kalemdeki/merkez kataloğundaki `station_id` ile üretilir (`restaurant_lan_host._enqueueStationJobs`). Bu alan `store/store_mapping_helpers.mapSnakeCaseToProduct` üzerinden gelir; eşlemeden çıkarılırsa çevrimdışı fiş bulut dönene kadar basılmaz. `store_service.resolveStoreOwnerIdForCurrentUser` sorgu çalışamazsa `null` döner (oturum kimliğini sahip saymaz).
- `Durum:` net

## `ibul_app/lib/screens/home_screen.dart`

- `Dosya yolu:` `ibul_app/lib/screens/home_screen.dart`
- `Amaç:` consumer ana sayfa; banner, kategori, ürün ve bazı QR fallback davranışlarını yönetir.
- `Bağlı olduğu dosyalar:` `AppState`, `ReviewState`, `DatabaseHelper`, `AdminService`, `ReviewRepository`, `StoreService`, `SupabaseService`, çok sayıda widget ve `business_detail_page.dart`, `map_page.dart`.
- `Bu dosyayı kullanan dosyalar:` `HomeWrapper`, `MaterialApp.home`, kök `/` route.
- `Değişirse etkilenecek yerler:` landing ürün akışı, banner cache, QR’dan home fallback, category/search navigasyonları.
- `Risk notu:` Büyük ve çok sorumluluklu; performans ve init race sorunlarına açık. Web görünümü (`home_screen_sections.dart`) `WebStickyFooterScrollView` kullanır; kategori/boş ürün ekranı footer layout'u bu wrapper'a bağlıdır. Web ana sayfa **Neden iBul?** bölümü `_buildWhyIbulSection()` ile action card olarak render edilir; kartlar gerçek route'lara bağlıdır (`MapPage`, `CategoriesPage`, `AIChatPage`/`CameraPage`).
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

## `ibul_app/lib/screens/all_reviews_page.dart`

- `Dosya yolu:` `ibul_app/lib/screens/all_reviews_page.dart`
- `Amaç:` Ürün detayından açılan tam sayfa **ürün değerlendirmeleri** ekranı; web’de sol özet kartı (puan, yıldız dağılımı, fotoğraflı yorumlar) + sağ yorum listesi (arama, yıldız filtresi, sıralama).
- `Bağlı olduğu dosyalar:` `core/review_state.dart`, `services/review_repository.dart`, `screens/photo_review_detail_page.dart`, `widgets/web_header.dart`, `widgets/optimized_image.dart`
- `Bu dosyayı kullanan dosyalar:` `widgets/product_detail/product_info_section.dart`, `product_info_section_web.dart`, `product_info_section_mobile.dart`, `product_reviews_section.dart`, `product_reviews_full_section.dart`
- `Değişirse etkilenecek yerler:` ürün detayı değerlendirme navigasyonu, özet/liste veri tutarlılığı, yıldız filtresi sayaçları, fotoğraflı yorum viewer.
- `Risk notu:` Tek kaynak `ReviewRepository.getProductReviewSummary` + `ReviewState.getProductReviewsFor` (productName + storeName); snapshot `customReviews`/`product.reviewCount` kullanılmamalı. Yükleme bitmeden empty state gösterilmemeli.
- `Durum:` net

## `ibul_app/lib/screens/photo_review_detail_page.dart`

- `Dosya yolu:` `ibul_app/lib/screens/photo_review_detail_page.dart`
- `Amaç:` Değerlendirme fotoğrafı tam ekran viewer; geri butonu, viewport içi `InteractiveViewer`, alt bilgi kartı.
- `Bağlı olduğu dosyalar:` `widgets/optimized_image.dart`, `core/constants.dart`
- `Bu dosyayı kullanan dosyalar:` `screens/all_reviews_page.dart`
- `Değişirse etkilenecek yerler:` fotoğraflı yorum galerisi navigasyonu, görsel boyutlandırma, yorum metni kartı.
- `Risk notu:` Yorum metni tam genişlik mor bar olmamalı; görsel `maxWidth`/`maxHeight` ile sınırlı kalmalı.
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
- `Bağlı olduğu dosyalar:` `AppState`, `StoreService`, `StoreFollowService`, `StoreFollowState`, `SupabaseService`, `PushNotificationService`, `BusinessDetailPage`, `StoreAchievementBadges`, map/filter widget’ları.
- `Bu dosyayı kullanan dosyalar:` route `/map`, `home_screen.dart`, `web_header.dart`, `list_detail_page.dart`, `product_search_result_page.dart`, `visual_intelligence_result_page.dart`.
- `Değişirse etkilenecek yerler:` store proximity, harita arama, business detail yönlendirmeleri, harita mağaza popup (rating/takipçi/rozet).
- `Risk notu:` canlı konum sync ve bildirim mantığı mevcut; yan etki alanı yalnız UI değil. Konum izni/konum okuma `LocationAccessService` üzerinden tekilleştirildi; IndexedStack + push edilen ikinci `MapPage` izin yarışı bu katmanda engellenir. Geri butonu: desktop geniş layout veya `product != null` ile push edilmiş yakın lokasyon akışında (`Navigator.canPop`) gösterilir; standalone harita sekmesinde mobilde gizli kalır. Mağaza popup `_MapBusinessDetailSheet` üzerinden `getStoresForMap` + `get_store_follow_state` RPC ile gerçek `rating`/`follower_count` gösterir; demo `9.8B`/`8.2` sabitleri kaldırıldı.
- `Durum:` net

## `ibul_app/lib/screens/seller_login_page.dart`

- `Dosya yolu:` `ibul_app/lib/screens/seller_login_page.dart`
- `Amaç:` seller/admin oturum açma ekranı; role göre `/seller` veya `/admin` yönlendirir.
- `Bağlı olduğu dosyalar:` `AuthService`, `AdminPanelPage`, `SellerPanelPage`, `become_seller_page.dart`.
- `Bu dosyayı kullanan dosyalar:` `lib/main_seller.dart`, named route `/seller-login`.
- `Değişirse etkilenecek yerler:` seller desktop giriş, admin mode giriş, session backup/restore akışı.
- `Risk notu:` yanlış role handling seller ve admin yetki ayrımını bozar. macOS sandbox’ta Keychain entitlement yoksa `SecureLocalStore` Keychain hatasında SharedPreferences fallback kullanır (seller login/session backup akışı devam eder). **Debug:** `macos/Runner/DebugProfile.entitlements` içinde `keychain-access-groups` yok — imzasız local debug için; Keychain yerine SharedPreferences. **Release:** `Release.entitlements` içinde `keychain-access-groups` kalır — imzalı dağıtımda gerçek Keychain kullanımı için.
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
- `Risk notu:` `FinanceShell` anahtarı owner `sellerId` + `_financeRefreshToken` değişimini yansıtmalı; provider eski optimistic history ile yaşamaya devam ederse finans KPI'ları gecikir. Bugünkü Gelir artık `getSalesRevenue` (online + kapalı masa) ile dashboard cirosuyla hizalı; manuel `finance_income_records` Gelirler sekmesinde kalır.
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
- `ibul_app/lib/features/seller/finance/helpers/today_revenue_breakdown_builder.dart`
  - Bugünkü gelir detayı: masa / alan / ödeme tipi kırılımı; `TableOrderHistoryUtils` + `order_items` + manuel gelir kaynaklarını birleştirir.
- `ibul_app/lib/features/seller/finance/helpers/store_table_area_resolver.dart`
  - Finance breakdown için alan adı çözümlemesi: önce `table_order_history.table_area_name`, boşsa `store_tables.area_name` (`table_id` / `table_number` eşleşmesi).
- `ibul_app/lib/features/seller/finance/widgets/today_income_detail_sheet.dart`
  - Bugünkü Gelir Detayı modal/sheet UI; kompakt dashboard-style sunum (`TodayRevenueBreakdown` → alan/ödeme/masa kırılımı, veri mantığına dokunmaz).
- `ibul_app/supabase/migrations/20260615_table_order_history_finance_analytics.sql`
  - `table_order_history` için `table_area_name`, masa etiket kolonları ve `close_table_with_history` RPC genişlemesi (payment/area/label persist).
- `ibul_app/lib/utils/table_labels.dart`
  - masa etiketi üretimi.
- `ibul_app/lib/widgets/skeleton_loading.dart`
  - `SkeletonLoading` shimmer primitive + `ProductCardSkeleton`; arama/ana sayfa grid loading kartları. `tight` modu arama sonuç grid'i ile hizalı constraint-aware layout kullanır.
- `ibul_app/lib/widgets/web_sticky_footer_scroll_view.dart`
  - Tek web footer kabuğu: `MarketplaceWebPageShell` ve `WebStickyFooterScrollView` / `WebStickyFooterEndSliver`. Sayfalar `WebFooter` kurmaz. Aralık yalnız `IbulChrome.footerGap`: kısa sayfada desktop 200 / tablet 140 / mobil 80, uzun sayfada içeriğin sonunda 64/48. Footer fixed/absolute değildir.
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
| Session backup | `SecureLocalStore` (seller switch JWT); macOS debug’da SharedPreferences fallback, release’de Keychain (`Release.entitlements`) |
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

## 2026-06-15 (ethernet test receipt — connection guard + POS80 receipt validator)

- **Kök neden (çift hata):** Bağlantı testi başarısızken `printer_ethernet_dialog` "Yine de Gönder" ile `printBridgeTest` çağırıyordu; bridge `_complete_receipt_request` içindeki ters mantık (`paper != 58 OR raster != 384 OR "80" in profile`) POS-80 payload'ını da reddediyordu → ekranda hem ağ hatası hem "POS-58 adisyon profili geçersiz" birlikte görünüyordu.
- **Fix:** `printer_ethernet_dialog.dart` — Test Fişi Gönder yalnızca `_connectionOk` iken aktif; bağlantı yokken bridge print çağrısı yok; print diagnostic yalnızca bağlantı başarılıyken gösterilir; profil seçimi `bridgeProfileFields` ile test/save payload'ına taşınır.
- **Fix:** `server.py` — `_validate_receipt_profile_metadata`: POS-80 / generic 80mm receipt metadata kabul; POS-58 doğrulaması yalnızca 58mm profilde; TCP ethernet'de profil boşsa anlamlı hata.
- **Fix:** `printer_error_messages.dart` — `ethernetPrintBlockedWithoutConnectionMessage`.
- **Test:** `ethernet_printer_dialog_test.dart` — başarısız bağlantıda print bridge çağrısı yok, POS58 profil hatası yok, POS80/POS58/generic metadata; `test_server.py` — POS80/generic receipt accept + tutarsız boyut reject.

## 2026-06-14 (printer ethernet/usb stable startup + add flow)

- **Kök neden (Ethernet baskı yok):** Windows'ta canlı USB/CUPS taraması doluyken `_mergeCanonicalPrinterCatalog` erken dönüyor ve kayıtlı Ethernet (`tcp:HOST:PORT`) satırlarını kataloga eklemiyordu → rol çözümleme / `prepareQueuedPrintPayload` mutfak hedefini USB'ye düşürüyor veya host/port boş kalıyordu.
- **Kök neden (startup restore):** Bridge kapalıyken `loadSetupSnapshot` kayıtlı yazıcıları hiç merge etmiyordu; UI ve rol restore boş kalıyordu.
- **Kök neden (hub warm cache):** `DesktopPrintHub._warmPrinterConfigCache` yanlış kolon `seller_id` ile sorguluyordu (`printers.restaurant_id` olmalı) → startup config cache boş, Ethernet metadata enrich edilmiyordu.
- **Kök neden (Ethernet UI kayboluyor):** Ana `desktop_printer_setup_page` yalnızca `showPrinterWizard` FAB açıyordu; kalıcı **Ethernet Yazıcı Ekle** CTA yalnızca adım adım sihirbazın tarama adımındaydı. Rol seçimi `_hasDetectedPrinters` yalnız `isLive` USB taramasına bakıyordu → yalnız Ethernet kayıtlı ortamda rol dropdown kilitli kalıyordu.
- **Fix:** `desktop_print_orchestrator.dart` — Windows live-scan dalında Ethernet merge; bridge offline iken saved printer catalog restore; `isSelectableLivePrinter` TCP backend için host/port guard.
- **Fix:** `desktop_print_hub.dart` — warm cache `restaurant_id` + Ethernet bridge payload alanları.
- **Fix:** `desktop_printer_setup_page.dart` — kalıcı Ethernet ekleme butonu; TCP yazıcılar rol seçiminde selectable; test printer resolve OS-aware.
- **Test:** `ethernet_role_mapping_test.dart` — Windows live USB + saved Ethernet merge regression.

## 2026-06-14 (printer setup mode guard — TCP vs CUPS)

- **Kök neden:** Ethernet kurulumunda `printer_wizard` CUPS kuyruk alanı gösteriyordu; `deviceCtrl` dolunca `printBridgeTest` kuyruk adıyla CUPS yazıcı çözümlüyordu → `targetHost` olsa bile `cups_queue_stuck` / `tcp_timeout` karışık hatalar.
- **Fix:** `desktop_print_orchestrator.dart` — `targetHost` varken `_buildDirectTcpPrinterFromTarget` öncelikli; CUPS kuyruk çözümlemesi atlanır.
- **Fix:** `printer_wizard.dart` — Ethernet modunda CUPS alanı gizlendi; test/save `upsertEthernetPrinter` + `skipSetupSnapshot` TCP fast-path; IP/port doğrulama.
- **Fix:** `printer_error_messages.dart` — `PrinterSetupMode.ethernetTcp` ile CUPS hatalarına mode-aware kullanıcı mesajı.
- **Test:** `desktop_print_orchestrator_test.dart` TCP-over-CUPS-name guard; `printer_error_messages_test.dart` mode guard copy.

## 2026-06-14 (ethernet separate flow + generic profile resolution)

- **Kök neden:** `printer_wizard` test payload'ı `paper_width_mm=80` gönderiyordu ama `printer_profile` / `raster_width_px` eksikti; bridge `_complete_receipt_request` varsayılan `pos58` ile 80mm'i reddediyordu → "POS-58 receipt profile invalid".
- **Fix:** `printer_profile.dart` — `resolveForEthernetSetup` + `bridgeProfileFields`; 80mm → `generic_80mm_escpos`, 58mm → `pos58`.
- **Fix:** `printer_wizard.dart` / `printer_ethernet_dialog.dart` — test/save payload'larına tam profil metadata.
- **Fix:** `local_print_bridge/server.py` — `_complete_receipt_request` 80mm profil yolunu kabul eder; pos58 doğrulaması yalnızca 58mm için.
- **Fix:** `desktop_printer_setup_page.dart` — **Ethernet Yazıcı Ekle** birincil (mor filled) buton; adım adım kurulum ikincil.
- **Test:** `printer_error_messages_test.dart` profile resolution; `test_server.py` 80mm receipt accept.

## 2026-06-15 (ethernet ağ uyumsuzluğu — kalıcı kurulum UX)

- **Kök neden:** Yazıcı fabrika IP’si (`192.168.1.100`) ile işletme LAN’ı (`192.168.10.x`) farklıydı. Otomatik tarama yalnızca bilgisayarın `/24` subnet’ini taradığı için yazıcı bulunmuyordu; geçici `ifconfig alias` kaldırılınca kurulum “bozulmuş” gibi görünüyordu.
- **Fix:** `network_scan.py` — `suggest_ethernet_network_settings`, `scan_no_device_reason`, `format_subnet_mismatch_guidance`.
- **Fix:** `server.py` — probe/scan yanıtlarına `suggested_printer_ip`, `suggested_target_subnet`, `mismatch_guidance`, `no_device_reason`, `discovered_printers`; farklı subnet’te `errorCode=network_mismatch`.
- **Fix:** `printer_error_messages.dart` — `EthernetNetworkCompatibilityPlan`, IP taşıma rehberi metinleri, `ethernetScanNoDeviceMessage`, teknik alias komutları (yalnız gelişmiş bölüm).
- **Fix:** `printer_ethernet_dialog.dart` — **Ağ Uyumluluk Durumu** kartı; **Yazıcı IP’sini İşletme Ağına Taşı** sihirbazı (router DHCP / üretici araç / teknik servis); kayıt `is_active=false` + `test_print_status=pending` bağlantı doğrulanmadan.
- **Fix:** `local_print_service.dart` — taramada opsiyonel `printer_host` ipucu.
- **Test:** `ethernet_printer_dialog_test.dart`, `printer_error_messages_test.dart`, `local_print_bridge/tests/test_network_scan.py`, `local_print_bridge/tests/test_server.py`.

## 2026-06-15 (ethernet add-printer entry regression restore)

- **Kök neden:** Refactor sırasında `showAddPrinterFlow` ve `_AddPrinterEntryScreen` `printer_wizard.dart` içinden kaldırıldı; `desktop_printer_setup_page` ve `kitchen_print_management_page` doğrudan `showPrinterWizard` çağırdığı için **Yazıcı Ekle** akışında Ethernet seçeneği kayboldu.
- **Fix:** `showAddPrinterFlow` geri eklendi — iki kartlı giriş: **Standart Yazıcı** / **Ethernet Yazıcı**; web’de seçenekler gizlenmez, bilgi notu gösterilir.
- **Fix:** `printer_ethernet_dialog.dart` — açık profil seçici (POS-80 varsayılan, POS-58, Generic 80mm); `resolveForEthernetSetup` + `bridgeProfileFields` ile test/save payload’ları; `connectionType=network`, `backend=tcp` ayrı kalır.
- **Fix:** `printer_profile.dart` — `ethernetSetupProfiles`, `resolveForEthernetSetup`, `bridgeProfileFields`.
- **Test:** `add_printer_flow_test.dart` — Ethernet kartı görünür ve dialog açılır; `ethernet_printer_dialog_test.dart` — POS-80 profili pos58’e düşmez.

## 2026-06-14 (printer add two entry points — standard vs ethernet)

- **Kök neden:** Tek `showPrinterWizard` girişi Ethernet’i standart akışa gömdü; test payload eksik profille bridge `pos58` varsayılanına düşüyordu.
- **Fix:** `showAddPrinterFlow` — ilk ekran iki seçenek: Standart Yazıcı / Ethernet Yazıcı; edit’te `isEthernetConnection` → ethernet dialog.
- **Fix:** `printer_wizard.dart` — step 1’den Ethernet bağlantı tipi kaldırıldı.
- **Fix:** `printer_ethernet_dialog.dart` — Kod alanı; test/save aynı `resolveForEthernetSetup` + `bridgeProfileFields`; `setupMode: ethernetTcp` hatalar.
- **Fix:** FAB ve edit çağrıları `showAddPrinterFlow` kullanır (`desktop_printer_setup_page`, `kitchen_print_management_page`).

## 2026-06-14 (ethernet dialog — split network/print test, single error)

- **Kök neden:** `printer_ethernet_dialog` bağlantı ve test fişi banner'larını aynı anda gösteriyordu; bağlantı testi receipt payload taşıyordu; test fişi `_connectionOk` guard'ı olmadan çalışıyordu; bridge `ethernet_test` modunda global `pos58` varsayılanına düşebiliyordu.
- **Fix:** `printer_ethernet_dialog.dart` — `_buildTcpProbePayload` (TCP-only); print test öncesi bağlantı guard; tek aktif banner (print > connection); `resolveEthernetSetupTestError`.
- **Fix:** `printer_error_messages.dart` — `EthernetSetupTestPhase` + TCP öncelikli tek hata çözümleyici.
- **Fix:** `server.py` — `_complete_ethernet_test_request` (`ethernet_test`/`tcp_test` için POS-58 global fallback yok).
- **Test:** `printer_error_messages_test.dart` — combined tcp+profile öncelik testleri.

## 2026-06-14 (ethernet dialog — single status banner, no dual error)

- **Kök neden (kalan):** İki ayrı state (`_connectionMessage` + `_printMessage`) birikebiliyordu; teknik detayda POS-58 metni TCP mesajının altında ikinci hata gibi görünüyordu; IP/port değişince `_connectionOk` stale kalabiliyordu.
- **Fix:** `printer_ethernet_dialog.dart` — tek `_statusMessage` banner; IP/port/kağıt değişince bağlantı geçersiz; eşzamanlı test engeli.
- **Fix:** `printer_error_messages.dart` — bağlantı fazında profil hatası → ağ mesajı; TCP+profil birleşik payload'da teknik detaydan profil gürültüsü temizlenir.

## 2026-06-15 (ethernet TCP setup diagnostics — operator-facing)

- **Kök neden:** Bridge `/printer/tcp/probe` `local_ips` / `same_subnet` / `errorCode` üretiyordu; `printer_ethernet_dialog` ham `LocalPrintServiceException` ve generic timeout metni gösteriyordu. Gerçek cihazda TCP timeout doğru hedefe (`192.168.1.100:9100`) gidiyordu ama operatör neden yanıt alamadığını göremiyordu.
- **Fix:** `server.py` — `invalid_ip` doğrulama; `diagnostic_only` / `network_preflight` ile TCP’siz subnet ön kontrolü.
- **Fix:** `local_print_service.dart` — `LocalPrintServiceException.errorCode`; `fetchEthernetNetworkPreflight`.
- **Fix:** `printer_error_messages.dart` — `EthernetConnectionDiagnostic`, `resolveEthernetConnectionProbeResult`, TCP error code haritası (`tcp_timeout`, `tcp_refused`, `invalid_ip`, `network_unreachable`, `bridge_unreachable`).
- **Fix:** `printer_ethernet_dialog.dart` — Ağ Teşhisi kartı, IP yardım paneli, kullanıcı dostu hata kartı + teknik detay expand/kopyala; bağlantı testi zorunlu; başarısız bağlantıda test fişi onayı; kayıt durumu `Hazır` / `Bağlantı doğrulanmadı`.
- **Test:** `printer_error_messages_test.dart`, `ethernet_printer_dialog_test.dart`, `local_print_bridge/tests/test_server.py`.

## 2026-06-14 (ethernet guided network diagnostics)

- **Kök neden:** Bridge TCP probe `local_ips` / `same_subnet` / `suggested_message` üretiyordu ama `printer_ethernet_dialog` yalnızca generic `tcp_unreachable` gösteriyordu; operatör farklı subnet’te neden bağlanamadığını anlayamıyordu.
- **Fix:** `server.py` — `diagnostic_only` / `network_preflight` TCP’siz subnet ön kontrolü.
- **Fix:** `local_print_service.dart` — `fetchEthernetNetworkPreflight`.
- **Fix:** `printer_error_messages.dart` — `EthernetNetworkDiagnostics`, `resolveEthernetConnectionProbeResult`, rehber adımları.
- **Fix:** `printer_ethernet_dialog.dart` — Ağ Tanılama kartı, Kolay Kurulum Yardımı, IP değişince preflight, Test Fişi yalnız `_connectionOk` iken aktif.
- **Polish:** Port durumu etiketi (`Test edilmedi` / `Açık` / `Kapalı`); teknik detay açılır bölüm; rehber 5 adım (açık / kablo ayrı).


- **Kök neden (1):** Bootstrap bitmeden `shouldShowGarsonInitialLoading` false dönüyordu (`initialLoading` henüz true olmadan); empty/error state erken render ediliyordu. Owner id hydrate olmadan `sellerId.isEmpty` → "Oturum bulunamadı" flash'i.
- **Kök neden (2):** `TableHistoryScreen` `Align(topCenter)` + `ConstrainedBox(maxWidth:640)` + `compact:true` tam genişlik satır layout kullanıyordu → kartlar ortalanıyor, strip kart hissinden uzaklaşıyordu.
- `shouldShowGarsonInitialLoading`: `!initialBootstrapFinished && !initialVisibleSeedDone` iken loading.
- `resolveGarsonRenderBundle`: bootstrap bitmeden grid boşsa `willShowLoading=true`.
- `_buildGarsonModule`: owner id fallback + bootstrap sırasında spinner; empty/error yalnızca bootstrap bittikten sonra.
- `TableHistoryScreen`: ortalama kaldırıldı; `GarsonClosedTableCard(width:220)` soldan hizalı dikey kart.

## 2026-06-13 (garson history — delete doğrulama + restore supersede)

- **Kök neden (delete):** `delete().eq(seller_id).eq(id)` 0 satırda da başarı dönüyordu; waiter/owner `seller_id` uyumsuzluğunda snackbar yine başarı gösteriyordu. RLS DELETE policy uygulanmamışsa sessiz no-op.
- **Kök neden (duplicate devam):** restore→re-close sonrası eski history satırı DB'de kalıyordu; `session_key` farklı zincirler `dedupeHistoryRowsLatestPerChain` ile birleşmiyordu.
- `deleteTableOrderHistoryRecord`: yalnız `id` ile delete + `.select('id')` → gerçek silme doğrulaması, `false` dönüş.
- `supersedeRestoredHistoryOnReclose`: restore kaynağı history id re-close sonrası silinir.
- Delete UI: `record.sellerId` / owner id; snackbar yalnız `deleted==true`; liste optimistic remove + refresh.

## 2026-06-13 (garson restore/re-close — duplicate history zinciri)

- **Kök neden (3 parça):** (1) `close_table_with_history` RPC her aktif `table_order` için ayrı history satırı insert eder (aynı `session_key` ile). (2) Restore sonrası re-close yeni `session_key` üretir; eski zincirle bağ kopar, listede 2 kayıt kalır. (3) `_closeGarsonTable` board kapanışında `sessionKey` geçirmiyordu; `ensureTableHistoryRecorded` fallback'i farklı `session_key` ile ikinci satır riski taşıyordu.
- `restore` → `sessionKeyOverride`: history `session_key` flow page + panel map'e taşınır.
- `consolidateDuplicateHistoryChain`: aynı `session_key` zincirinde yalnızca en güncel `closed_at` satırı kalır (fazlalar DB'den silinir).
- `getTableOrderHistory`: `dedupeHistoryRowsLatestPerChain` güvenlik ağı.
- `ensureTableHistoryRecorded`: RPC ile aynı `session_key` fallback insert'te kullanılır.

## 2026-06-13 (garson restore/re-close — masa kimliği + geçmiş silme)

- **Kök neden (2 parça):** (1) `close_table_with_history` RPC history satırını label alanları olmadan yazabiliyor; ardından `ensureTableHistoryRecorded` yeni `table_order` id'leriyle ikinci insert deniyordu — dedup yalnızca `original_order_id` / `session_key` eşleşmesine bakıyordu. (2) Label eksik history + UI'da `Masa ${table_number}` fallback'i fiziksel numarayı (11) gösteriyordu; alan içi numara (Bahçe 1) kayboluyordu.
- `table_close_history_fallback.dart`: aynı `table_number` için 3 dakikalık close dedup; duplicate'te insert yerine identity patch.
- `table_order_history_utils.dart`: `tableLabel` öncelik sırası (display → archived_orders → area+number → fallback); `historyIdentityForArchive` / `historyRowMissingIdentity`.
- `store_table_service.dart`: history insert'lerde identity alanları; `_patchRecentHistoryIdentityIfMissing`; `restoreTableFromHistory` history identity'yi `tableRow`'a taşır; `deleteTableOrderHistoryRecord`.
- `garson_closed_tables_strip.dart` + `TableOrderHistoryRecord.fromMap`: kart başlığı `tableLabel`; sol üst sil ikonu.
- `table_history_screen.dart` + `seller_panel_page.dart`: onaylı tek kayıt silme + liste refresh.
- `ibul_app/SUPABASE_TABLE_HISTORY_DELETE_POLICY.sql`: `table_order_history` DELETE + UPDATE RLS (seller / `user_can_access_restaurant`).

## 2026-06-13 (garson geçmiş masalar — yatay kompakt kart)

- **Kök neden:** `TableHistoryScreen` `GarsonClosedTableCard`'ı `width: null` ile tam genişlik + dikey kolon layout'ta render ediyordu; kartlar yatayda fazla geniş ve yüksek görünüyordu.
- `GarsonClosedTableCard`: `compact: true` modu — yatay satır layout (sol: masa/alan/özet/zaman, sağ: tutar + mini ikonlar); padding 8×6, radius 8.
- `TableHistoryScreen`: liste `maxWidth: 640` ile ortalandı; kartlar `compact: true`; separator/padding küçültüldü.

## 2026-06-13 (garson geçmiş masalar — buton-only kompakt liste)

- **Kök neden:** Garson ana sayfada inline `GarsonClosedTablesStrip` şeridi ile `TableHistoryScreen` tam ekran listesi farklı kart bileşenleri (`GarsonClosedTableCard` vs `_HistoryRecordCard`) kullanıyordu; üst şerit + buton çift giriş kafa karıştırıcıydı.
- `seller_panel_page.dart`: garson modülünden inline strip kaldırıldı; erişim yalnızca üst bar / masa yönetimi "Geçmiş Masalar" butonlarından.
- `GarsonClosedTableCard`: strip'ten export edildi; tam genişlik dikey liste modu (`width: null`) eklendi.
- `TableHistoryScreen`: büyük analitik kart + özet bar kaldırıldı; aynı kompakt kart + dönem filtreleri + sayfalama; veri kaynağı `getTableOrderHistory` ve detay sheet/print/restore callback'leri aynı.

## 2026-06-13 (garson geçmiş masa — close sonrası görünmeme fix)

- **Kök neden (3 parça):** (1) `getTableOrderHistory` Supabase sorgusunda `order('closed_at')` yoktu — `limit` rastgele satır döndürüp Bugün filtresi sonrası yeni kapanış kaybolabiliyordu. (2) Geçmiş okuma `_resolveGarsonSellerId()` (auth fallback) ile yazma `_resolveCanonicalGarsonSellerId()` (owner) arasında seller_id uyumsuzluğu riski. (3) `ensureTableHistoryRecorded` tablo yokken `false` dönüp snackbar yine başarı gösteriyordu; gerçek DB insert doğrulanmıyordu.
- `getTableOrderHistory`: `order('closed_at', desc)` + `range(offset…)` + `toDate` üst sınırı; `_resolveSellerId` ile owner id.
- `_closeGarsonTable`: kapanış sonrası `hasRecentTableHistory` doğrulaması — kayıt yoksa snackbar yok; owner id persist; optimistic row doğru `seller_id`.
- `GarsonClosedTablesStrip` / `TableHistoryScreen`: Bugün filtresi `endOfLocalDay`; garson modülü `_resolveSellerDataOwnerId()` kullanır.

## 2026-06-13 (garson geçmiş masalar — inline strip + restore)

- **Kök neden:** Garson modülünde "Geçmiş Masalar" yalnızca ayrı `TableHistoryScreen` navigasyonu olarak vardı; board üstünde gerçek `table_order_history` verisiyle kart listesi yoktu. Kapalı masayı tekrar açma (`restore`) servisi hiç tanımlı değildi; miktar düzenleme kapalı kayıt üzerinde güvenli değildi.
- `GarsonClosedTablesStrip`: garson board üstünde Bugün/Hafta/30 Gün/Tarih Seç filtreli kompakt yatay kart şeridi; kaynak `StoreService.getTableOrderHistory` (`table_order_history`, `closed_at` merkezli).
- `GarsonHistoryDetailSheet`: tam sipariş listesi + adisyon/mutfak yazdır + "Masayı Tekrar Aç"; miktar +/- kapalı kayıtta restore yönlendirmesi yapar.
- `StoreTableService.restoreTableFromHistory`: history satırından `table_orders` insert (guard: masa zaten açıksa hata); history satırı değiştirilmez.
- `TableOrderHistoryRecord` + `TableOrderHistoryUtils`: alan/özet/ archived_orders birleşimi; kartlarda alan adı, açılış-kapanış, ürün özeti, toplam.
- `seller_panel_page.dart`: strip embed, restore/print callback'leri, kapanış sonrası strip refresh token.

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

## 2026-06-13 (garson masa kapanış → finance bugünkü gelir)

- **Kök neden:** Dashboard ciro `_combinedDashboardOrders` + `_dashboardClosedHistory` (optimistic dahil) kullanıyordu; Finance KPI "Bugünkü Gelir" yalnız `finance_income_records` manuel kayıtlarından hesaplanıyordu. `FinanceRepository.getSalesRevenue` optimistic geçmişi yalnız DB toplamı 0 ise ekliyordu — bugün daha önce kapanmış masa varsa yeni kapanış finance'a yansımıyordu.
- **Fix:** `getSalesRevenue` / `getTodayIncomeBreakdown` / `getSalesBreakdown` → `_mergeFetchedHistoryWithOptimistic`. `finance_shell` Bugünkü Gelir = `getSalesRevenue(today)`. Fallback overview `monthIncome` += aylık satış cirosu. Finans modülü açılışında `_reloadRestaurantDashboardMetrics` tetiklenir.

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

## 2026-06-14 (map store popup real data)

- `ibul_app/lib/screens/map_page.dart`: Mağaza popup `_MapBusinessDetailSheet` olarak ayrıldı; takipçi sayısı `StoreFollowService.getStoreFollowState` + `StoreFollowState.formattedFollowerCount`, puan `stores.rating`, açıklama `stores.description/slogan` üzerinden gelir. Sabit demo değerler (`9.8B Takipçi`, `8.2`) kaldırıldı.
- `ibul_app/lib/services/store_service.dart`: `getStoresForMap` artık `rating`, `follower_count`, `description`, `slogan` kolonlarını da çeker.
- `ibul_app/lib/models/store_follow_state.dart`: `parseFollowerCount`, `formatFollowerLabel`, `formatRatingLabel` yardımcıları eklendi.
- `ibul_app/lib/widgets/store_achievement_badges.dart`: Rozet alanı için geleceğe hazır pasif placeholder; sahte kazanılmış turuncu rozet gösterilmez.

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

## 2026-06-14 (compare features — dynamic parity + category guard)

- `ibul_app/lib/widgets/compare_page_helpers.dart`: Ortak dinamik özellik toplama (`collectProductCompareFieldMap`, `buildDynamicProductSpecRows`, `buildCompareFeatureSections`); `ProductDetailContentHelper.buildSpecs` + `specifications` JSON/map + `attributes` + gerçek ürün alanları; normalize edilmiş label birleştirme; ana kategori doğrulama (`compareProductsShareMainCategory`); header görseli `Product.images` → `imageFor(card)` → `thumbnailPublicUrl`.
- `ibul_app/lib/screens/compare_features_page.dart`: Sabit kalıp satırlar kaldırıldı; ortak helper kullanılıyor; farklı ana kategoride blocked state.
- `ibul_app/lib/screens/compare_products_page.dart`: Özellik karşılaştırmaya gitmeden önce ana kategori kontrolü + SnackBar uyarısı.
- `ibul_app/lib/widgets/product_detail/product_comparison_section.dart`: Aynı dinamik helper; header görselleri gerçek URL/CDN ile (`OptimizedImage`).
- `Product.category` = ana kategori (`main_category` fallback); görsel kaynağı: `images` (birincil), `thumbnailPublicUrl` (yedek).


- `CompareFeaturesPanel`: özellik compare header + spec tablosu tek grid; solda 180px label kolonu header’da da var → orta divider header/tablo ile hizalı.
- Ürün header sırası: ad → mağaza → fiyat → görsel (görsel en altta).
- `CompareColumnDivider(compact: true)`: grid içi divider margin’siz, 2 üründe tam orta çizgi.
- Genel Bilgiler üstünde ayrı `CompareProductColumnsHeader` kaldırıldı; tekrarlayan görsel bloğu yok.

## 2026-06-14 (product compare — fullscreen grid layout)

- Web compare yüzeyi artık dar kart/modal değil: `CompareWebShell` tam genişlik, `WebHeader` + `maxWidth:1200` kart kaldırıldı.
- `CompareColumnLayout` / `CompareSpecTable`: 2–4 ürün için eşit kolonlar; 2 üründe ortada vurgulu dikey divider.
- `CompareProductColumnsHeader`: üstte hizalı görsel + ad/mağaza/fiyat; altında Excel tarzı özellik tablosu.
- Yorum/görsel compare: `ReviewRepository` + `Product.images`; N ürün kolon desteği; demo listeler yok.
- Navigasyon: `openCompareRoute` (`rootNavigator`) ile tam sayfa compare rotası.

## 2026-06-14 (ai discover — fullscreen + no demo responses)

- `ibul_app/lib/screens/ai_discover_page.dart`: **Kendini Keşfet** web'de kart/modal görünümünden tam sayfa layout'a geçirildi (`WebHeader` + full-bleed panel, `maxWidth: 1400`); demo chat mesajları, sahte ürün önerileri ve `_sendMessage` mock yanıt üretimi kaldırıldı; AI kapalıyken dürüst info card (`Yapay Zeka Asistanı` / `Size nasıl yardımcı olabilirim?`); input disabled + sağ **Nasıl Çalışır?** paneli korundu.
- `ibul_app/lib/services/ai_assistant_service.dart`: `isDiscoverChatLive` getter eklendi (`false` — gerçek backend bağlanınca açılacak); discover yüzeyi demo bypass için bunu kontrol eder.
- `ibul_app/lib/screens/ai_chat_page.dart`: Kendini Keşfet navigasyonu `rootNavigator: true` ile tam sayfa route.

## 2026-06-14 (product compare — real data + UI cleanup)

- `ibul_app/lib/screens/compare_products_page.dart`: Favori ürün seçimi sonrası üç karşılaştırma rotası — özellik / yorum / görsel.
- `ibul_app/lib/widgets/compare_page_helpers.dart`: Ortak web shell, ürün başlık satırı, `loadReviewsForProduct` (`ReviewRepository` + `ReviewState`), empty-state yardımcıları.
- `ibul_app/lib/screens/compare_features_page.dart`: Yalnız gerçek `Product` alanları (marka, kategori, açıklama, specifications, attributes, features, ingredients, puan); demo kategori tablosu yok.
- `ibul_app/lib/screens/compare_reviews_page.dart`: Hardcoded demo yorum listesi kaldırıldı; Supabase/local review özeti; boşsa “Bu ürün için henüz yorum yok.”
- `ibul_app/lib/screens/compare_images_page.dart`: `product.images` + review `imageUrls`; demo görsel/yorum kartları kaldırıldı; boş galeri empty state.
- `ibul_app/lib/widgets/product_detail/comparison_modal.dart`: Kategori bazlı sahte spec satırları (Ekran/RAM vb.) kaldırıldı; gerçek ürün alanları kullanılır.
- Veri kaynakları: `Product.images`, `ReviewRepository.getProductReviewSummary`, `ReviewState.getProductReviewsFor`.

## 2026-06-14 (home — Neden iBul action cards)

- `ibul_app/lib/screens/home_screen.dart`: Web ana sayfadaki **Neden iBul?** bölümü statik bilgi kartlarından premium action card'lara dönüştürüldü (`_WhyIbulActionCard`: hover/focus/press, ok CTA, responsive 4→2 kolon).
- Navigation eşlemesi (fake route yok):
  - **Yakın Lokasyon** → `MapPage` (`web_header` ile aynı pattern)
  - **Fiyat Karşılaştırma** → `CompareProductsPage` (beğendiğim ürünleri karşılaştır)
  - **Yapay Zeka Asistanı** → web: `AIChatPage` dialog (FAB ile aynı); mobil fallback: `CameraPage`
  - **Güvenilir Satıcılar** → `MapPage` (`StoreService.getStoresForMap` onaylı mağazalar; ayrı verified-list ekranı yok)
- `ibul_app/lib/screens/account_page.dart`: Web **Hesabım > Hesap Özeti** içinde istatistik kartlarının altına mobildeki **Yapay Zekaya Danış** alanı eklendi (`_AccountAiConsultCard`, responsive, dialog ile `AIChatPage` açar).

## 2026-06-14 (ürün değerlendirmeleri — web tutarlılık + viewer)

- `ibul_app/lib/screens/all_reviews_page.dart`: Snapshot `customReviews`/`product.reviewCount` kaldırıldı; sayfa açılışında `ReviewRepository.getProductReviewSummary` + `ReviewState.getProductReviewsFor` ile tek kaynaktan yüklenir. Loading/error/empty/filtered-empty ayrı state’ler. Sol özet kartında overflow düzeltmesi (`Wrap`, `maxLines`, `ellipsis`). Yıldız dağılımı ve filtre sayaçları aynı `_allReviews` listesinden. Web layout: `WebHeader` altında sol üst geri butonu (`_buildWebBackButton` → `_goBack` / `Navigator.pop`).
- `ibul_app/lib/screens/photo_review_detail_page.dart`: Tam ekran koyu viewer; net geri butonu; `InteractiveViewer` + viewport sınırlı görsel; yorum metni beyaz kart içinde (`maxWidth`), mor tam genişlik bar kaldırıldı.
- Giriş noktaları (`product_info_section*.dart`, `product_reviews_section.dart`, `product_reviews_full_section.dart`): `AllReviewsPage` artık yalnız `productName`, `brand`, `storeName`, `images` alır.

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
