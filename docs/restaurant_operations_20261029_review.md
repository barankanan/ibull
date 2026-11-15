# Restoran sipariş, baskı ve personel incelemesi — 29 Ekim 2026

## Durum ve kapsam

Kod ve iki SQL migration incelemeye hazırdır. Canlı veritabanında yalnız SELECT/katalog sorguları çalıştırıldı; migration, veri güncellemesi, Auth hesabı oluşturma veya Edge Function deploy yapılmadı. Fiziksel yazıcıyla macOS/Windows/Android kabul testi yapılmadı. Mevcut UI bileşenleri, provider/state, Supabase Auth, sipariş tabloları, print_jobs ve OS taşıma yöntemleri kullanılıyor.

Başlangıçta değişmiş macOS/Windows generated plugin dosyaları, Podfile.lock ve pubspec.lock korunmuştur. Bunlar bu düzeltmenin parçası değildir.

## 1. Sipariş hatasının doğrulanmış kaynağı

Canlı katalogda `stores` anahtarı `seller_id`; `id` yok. `orders`, `order_items`, `store_tables`, `printers`, `stations`, `print_jobs` tablolarında `id` var. Foreign key ilişkileri `orders.restaurant_id → stores.seller_id`, `orders.table_id → store_tables.id`, `order_items.order_id → orders.id`, `print_jobs.order_id → orders.id` şeklindedir.

Canlı `create_table_order_with_print_jobs_impl` içinde hata üreten sorgu:

```sql
select business_name into v_restaurant_name
from public.stores
where seller_id = p_restaurant_id or id = p_restaurant_id
limit 1;
```

`user_can_access_restaurant` içinde de `s.id` kullanan iki alternatif mağaza eşlemesi ve üyelik alt sorgusu var. Sahip erişiminde yardımcı fonksiyon erken dönebilse de `_impl` aynı olmayan kolonu sorguluyor. Personel erişiminde yardımcı fonksiyonun kendisi de hata verebiliyor. Dolayısıyla yalnız Dart tarafında kolon adını değiştirmek yeterli değil.

Ek bulgular:

- Yeni siparişte LAN baskısı RPC'den önce başlıyordu; başarısız kayıt fiziksel fiş çıkarabiliyordu.
- Düzenlemede `Future.wait(update, print)` kayıt ve baskıyı paralel çalıştırıyordu.
- Online UI mevcut `local_order_id` idempotency parametresini kullanmıyordu.
- Canlı para güvenliği tetikleyicileri `ibul.marketplace_order_rpc=on` olmadan INSERT reddediyor. Eski restoran RPC'si bu sözleşmeye uymuyor.

Düzeltme:

- Hatalı `stores.id` alternatifleri kaldırıldı. Üyelik doğrulaması gerçek Auth UID'si veya eski kayıtlarda doğrulanmış Auth iletişim bilgileriyle yapılır; kullanıcı metadata'sından yetki verilmez.
- Online baskı, RPC sonucunda order_id doğrulandıktan sonra mevcut print_jobs claim yoluna bırakılır. Kayıt öncesi bağımsız LAN gönderimi kaldırıldı. macOS/Windows transport ve fiş şablonları değiştirilmedi.
- Düzenleme kaydı doğrulanmadan baskı başlatılmaz.
- UI aynı taslakta hata sonrası aynı `p_local_order_id` değerini korur; taslak değişirse veya işlem başarılı olursa yeni işlem kimliği kullanılır.
- Mevcut unique index doğrulandı: `(restaurant_id,local_order_id) WHERE local_order_id IS NOT NULL`. RPC aynı anahtarı advisory transaction lock ile serileştirir ve mevcut siparişi döndürür.
- Güvenilir RPC bağlamı yalnız yetki/masa/istasyon kontrollerinden sonra açılır, işlem sonunda eski değeri geri yüklenir. Bu kontrol istemciye taşınmadı.
- Baskı sistemi kapalıyken sipariş kaydedilir; işler mevcut `paused_by_operator` durumunda oluşur.

## 2. Yazı boyutunun kopması

Canlı `printers.print_size` kolonu mevcut. Bunun için yeni kolon migration'ı gerekmiyor.

- Hub zenginleştirmesi yalnız kodlama/rol ayarlarını taşıyor, boyutu taşımıyordu. Warm-up sorgusu da yanlış `printers.seller_id` kolonunu kullanıyordu; gerçek kolon `restaurant_id`.
- Python `PrintStationConsumer`, payload modeline dönüştürürken boyutu kaybediyor ve global BridgeSettings ile çiziyordu.
- Android adisyon builder'ı sabit normal gövde komutu kullanıyordu.
- Merkezi dispatch çözümlemesinde eski iş payload'ı kayıtlı yazıcı boyutunun önüne geçebiliyordu.

Düzeltme: kaydedilmiş yazıcı ayarı üretim fişinde öncelikli; açık test formu override'ı korunur. Hub ayarı taşır ve yazıcı değişim event'inde cache'i geçersiz kılar. RPC istasyon işlerine kayıtlı yazıcı boyutunu ekler. Python consumer isteğe özel settings oluşturur; global ayarları değiştirmez. Android aynı preset'i ESC/POS gövde boyutuna çevirir. ESC/POS metin modu tam sayı büyütmeleri kullanır; raster ölçekleri kesirlidir.

## 3. Android gecikmesi: ölçülebilen ve ölçülemeyen

Canlı son 30 günde baskı işi: **0**. Tüm geçmişte **762** iş var; son iş **9 Ağustos 2026 (UTC)**. 451 kayıtta hub alma zamanı, 374 kayıtta yazıcı yazma zamanı var.

Geçmiş medyanlar: iş→hub yaklaşık 10.800.353 ms, hub→dispatch 1.966 ms, dispatch→yazıcı yaklaşık -10.799.814 ms. Yaklaşık üç saatlik ters yönlü kayma gerçek yazıcı gecikmesi değildir. Flutter yerel saati timezone eki olmadan ISO metnine çevirirken köprü UTC kaydediyordu. Bu nedenle mevcut geçmişle aşama bazlı Android performans sonucu çıkarılamaz.

**Ek doğrulanmış kök neden:** Canlı `pg_publication_tables` sorgusunda `supabase_realtime` için `public.print_jobs` ve `public.printers` kaydı yok. Beklenen Postgres olayları bu tablolardan yayınlanmıyor; baskı bildirimi broadcast/polling fallback'ine bağımlı kalıyor. İş sayısının son dönemde sıfır olması nedeniyle bunun bugünkü cihaz gecikmesindeki payı ölçülemedi.

Düzeltmeler:

- Mevcut `supabase_realtime` yayınına eksik print_jobs/printers tabloları koşullu eklenir; yeni event sistemi kurulmaz.
- OrderPrintJobService ve DesktopPrintHub aşama zamanları UTC (`Z`) kaydedilir.
- RPC order_saved_at ve print_job_created_at alanlarını iş satırına yazar.
- Mevcut broadcast + postgres_changes hattı kayıt sonrası hemen kullanılır. 600+350 ms bağımsız LAN timeout/settle beklemeleri kaldırıldı.
- Mevcut atomik pending→claimed kontrolü korunur; realtime, desktop fast-path ve recovery aynı işi yarışarak iki kere göndermez.
- Hub printer-cache sorgusu düzeltildi; her işte başarısız warm-up sonrası gereksiz config sorgusuna düşme azaltılır.
- Python istasyonun mevcut polling fallback'i (varsayılan 2500 ms) korunur. Yeni timer, kuyruk veya realtime sistemi eklenmedi.

**Ölçülmemiş:** yeni Android siparişinde gerçek DB→event→satıcı→bridge→yazıcı süreleri, fiziksel baskının başlaması, ağ kopması/yeniden bağlanmada kağıt sayısı. `printer_write_started_at` transport'a yazma başlangıcıdır; yazıcının kağıdı hareket ettirdiğini kanıtlamaz. Sonuç kabul testinde cihaz ve yazıcıyla doğrulanmalı; hızlanma yüzdesi iddia edilmiyor. Eski zaman damgalarına backfill yapılmadı.

## 4. Personel hesabı ve yetkilendirme

Eski davet yalnız `store_sub_admins` satırı ekliyordu; Auth hesabı veya e-posta oluşturmuyordu. Canlı self-activate UPDATE politikası personelin yetki/status alanlarını da değiştirmesine izin verebiliyordu. `table_orders` üzerinde unconditional SELECT/UPDATE/DELETE ve ALL politikaları vardı.

Yeni akış mevcut ekip ekranında personel adı, e-posta, Garson/Alt Yönetici, mevcut aktif şube, geçici şifre ve mevcut ayrı izin kutularını kullanır.

- `manage-restaurant-staff` Edge Function JWT'yi Auth üzerinden doğrular, yalnız gerçek `stores.seller_id` sahibine izin verir. Flutter service_role anahtarı almaz.
- Auth Admin createUser sunucuda çalışır. Şifre DB üyelik tablosuna/loglara yazılmaz. Mevcut başka Auth hesabı ele geçirilmez veya şifresi sıfırlanmaz.
- Auth hesabı + profil + mevcut üyelik ilişkilendirilir; üyelik kaydı başarısızsa yalnız yeni oluşturulan Auth hesabı geri alınır. Auth ve Postgres arasında dağıtık transaction yoktur; cleanup başarısızlığı açık hata verir.
- Şube işletmeye ait ve aktif olmak zorundadır. Üyelik ve masa şubesi doğrulanır.
- Yeni hesapta e-posta gönderilmez; başarı metni bunu açıkça söyler. Geçici şifre işletme sahibi tarafından personele iletilir. Şifre değiştirme mevcut Ayarlar akışındadır; ilk girişte zorunlu değiştirme kapısı eklenmedi.
- İzin güncelleme ve pasifleştirme aynı yetkili sunucu işlemini kullanır; sessiz sıfır-satır başarısı kabul edilmez.
- Pasifleştirme kaydı silmez. Yeni ve mevcut JWT'lerle DB erişimi aktif üyelik üzerinden kontrol edilir. Auth hesabı global olarak banlanmaz.
- Giriş ve owner çözümlemesi server membership üzerinden yapılır; ana kullanıcı/satıcı giriş yöntemi korunur.
- RLS, ana sipariş RPC'si, masa kapatma RPC'si ve sipariş yazma tetikleyicileri yetki/işletme kontrollerini uygular. Finance aggregate RPC'leri aynı RLS'ye tabi SECURITY INVOKER olur. Ürün/kampanya/profil/destek/finans yüzeylerinde mevcut izin isimleri kullanılır; `viewFinance` finans yazma yetkisi vermez.

Şube devreye alma koşulu: Mevcut masalara otomatik şube atanmadı. `store_tables.branch_id` doğru mevcut `store_branches.id` ile işletme sahibi tarafından doğrulanarak eşlenmelidir. Yeni şube personeli eşlenmemiş masada işlem yapamaz. Sahip hesabının masa erişimi korunur.

## Değişen dosyalar

- `ibul_app/lib/screens/seller_panel_page.dart`: kayıt/baskı sırası, retry anahtarı, personel formu ve doğru başarı metinleri.
- `ibul_app/lib/services/order_print_job_service.dart`: kayıt sonrası mevcut claim akışı, belirsiz timeout'ta ikinci offline siparişe otomatik düşmeme, UTC.
- `ibul_app/lib/services/desktop_print_hub.dart`: gerçek printer scope, boyut aktarımı/cache invalidation, UTC.
- `ibul_app/lib/services/printer_print_size_settings.dart`: kayıtlı ayar önceliği.
- `ibul_app/lib/services/mobile_order_print_service.dart`: Android gövde boyutu.
- `ibul_app/lib/services/store_service.dart`: mevcut personel hizmetlerinin sunucuya bağlanması, managed staff owner çözümlemesi.
- `ibul_app/lib/services/auth_service.dart`: aktif personel rolü/işletmesinin sunucudan çözülmesi.
- `local_print_bridge/print_station.py`: kuyruğun boyut ayarını renderer'a aktarır.
- `ibul_app/supabase/functions/manage-restaurant-staff/index.ts`: yetkili Auth/personel işlemi.
- `ibul_app/supabase/migrations/2026102901_restaurant_staff_access.sql`.
- `ibul_app/supabase/migrations/2026102902_restaurant_order_commit.sql`.
- `ibul_app/supabase/tests/restaurant_operations_fixture.sql`, `restaurant_operations_test.mjs`: izole PostgreSQL davranış testleri; production verisi içermez.
- `ibul_app/test/services/order_commit_failure_test.dart`.
- `ibul_app/test/services/mobile_order_print_service_test.dart`.
- `ibul_app/test/printer_setup/printer_print_size_settings_test.dart`.
- `local_print_bridge/tests/test_print_station_size.py`.
- Bu inceleme raporu.

## SQL inceleme ve uygulama sırası

1. `2026102901_restaurant_staff_access.sql`: mevcut üyeliğe Auth UID/rol/şube/istek kimliği; mevcut masaya branch_id; scoped helper/policy/trigger ve RPC erişim kontrolleri. Tablo veya sipariş verisi silmez. Eski davetlerin otomatik aktifleştirilmesi kapatılır.
2. `2026102902_restaurant_order_commit.sql`: salt okunur incelenen canlı `_impl` gövdesinden hazırlanmış düzeltme. Public wrapper korunur. İstasyon payload'ı, günlük sayaç ve mevcut print_jobs korunur.
3. Mevcut aktif şubeler ve doğru masa→şube ilişkileri incelenip açık bir mapping ile atanmalı. Rapordaki örnek kimlikler canlı işlem talimatı değildir.
4. Edge Function inceleme sonrası deploy edilmeli. Supabase'in server ortamındaki SUPABASE_URL/ANON_KEY/SERVICE_ROLE_KEY kullanılır; istemciye anahtar taşınmaz.
5. Aynı sürüm Flutter ve bridge güncellemeleriyle staging kabul testleri, ardından onaylı canlı rollout yapılmalı. PostgREST reload notify migration sonlarında bulunur.

**İki migration da canlıda uygulanmadı. Körlemesine `supabase db push` çalıştırılmamalı:** depodaki geçmiş migration'ların canlıyla sırası zaten farklı. Canlıya bu dosyaların uygulanması ve function deploy ayrı onaylı işlemdir.

## Manuel kabul adımları

1. Staging'de önce sahip hesabıyla MacBook'ta çalışan yazıcıyı doğrulayın: test, adisyon, mutfak, toplu ve istasyon ayrımlı sipariş. Aynı kontrolleri Windows'ta USB/spool ve Ethernet için yapın.
2. Yazıcıyı Büyük yapıp kaydedin, ayar ekranını yeniden açın. Test/adisyon/mutfak/toplu fiş gövdesini karşılaştırın. Normal/Çok Büyük ile tekrarlayın; kesim, Türkçe karakter, not ve tabak içeriklerinin korunduğunu kontrol edin.
3. Garson yeni siparişini bir kez gönderin. DB'de tek orders kaydı ve istasyon başına beklenen print_jobs sayısı, UI'da kalıcı order_id görülmeli. Aynı retry kimliğini tekrarlayın: order sayısı değişmemeli, tamamlanan iş tekrar basılmamalı.
4. RPC'yi staging'de kontrollü hata ile durdurun: başarı bildirimi ve fiziksel baskı olmamalı; taslak korunmalı. Timeout sonrası aynı anahtarla retry yapın. Aynı işi iki satıcı uygulaması ve recovery sweep ile yarıştırın; tek atomik claim ve tek fiş bekleyin.
5. Baskı sistemi kapalıyken sipariş gönderin: kayıt başarılı, iş paused_by_operator, kağıt çıkışı yok.
6. Android cihazdan 10 ayrı sipariş gönderin. Her print_job_id için aşağıdaki alanları kaydedin. Cihaz saatlerini eşitleyin; tüm timestamp'lerde timezone bulunmalı. Realtime bağlı/kopuk durumunu ayrıca kaydedin.

| Aşama | Kanıt |
|---|---|
| Sipariş kaydı | orders.created_at / print_jobs.order_saved_at |
| İş oluşumu | print_jobs.print_job_created_at |
| Satıcıya ulaşma | print_jobs.hub_job_received_at + pickup_source logu |
| Köprüye gönderme | print_jobs.dispatch_started_at + bridge request logu |
| Yazıcıya veri başlangıcı | printer_write_started_at + queue/transport logu |
| Fiziksel kağıt başlangıcı | Cihazda gözlem/video; DB alanı tek başına yeterli değil |

7. Personel hesabını sahip panelinden oluşturun; e-posta gönderilmediği mesajını ve Auth UID/üyelik eşleşmesini kontrol edin. Geçici şifreyle mevcut satıcı girişini kullanın. Garson ve Alt Yönetici yönlendirmelerini ayrı deneyin.
8. Yabancı işletmeye ve başka şubenin masasına doğrudan REST/RPC isteği gönderin: veri/işlem reddedilmeli. Kendi permission/status/branch_id alanlarını değiştirmeyi deneyin: reddedilmeli.
9. Her izni ayrı açıp kapatın. Özellikle viewOrders ile sipariş değiştirme/kapatma, viewFinance ile finans yazma reddedilmeli. Menü görünürlüğü kabul kanıtı değildir.
10. Personel açık oturumdayken pasifleştirin. Aynı eski JWT ile sipariş okuma/yazma, mutfak işi ve yetki yükseltme reddedilmeli. Sahip ve normal müşteri girişini tekrar kontrol edin.

## Test kanıtları

- Odaklı Flutter testleri: **33 başarılı** (kayıt hatası/retry kimliği, merkezi boyut ve Android adisyon).
- Geniş Flutter yazıcı/offline grubu: **283 başarılı, 3 başarısız**. Eklenen son boyut testi ayrıca odaklı grupta geçti.
- Üç başarısızlık ayrı temiz HEAD checkout'ta da aynı şekilde tekrarlandı: Ethernet queued payload profil beklentisi `generic_80mm_escpos` / gerçek `pos80`; wizard tanılama kopyalama mesajı beklentisi; Ethernet test payload'ında printer_name beklentisi. Bu turda mevcut davranış/test beklentilerine dokunulmadı.
- Python bridge: **120 test başarılı**; kuyruk üzerinden receipt/kitchen boyut aktarımı dahil.
- İki migration izole PostgreSQL/PGlite motorunda uygulandı; kayıt/iş oluşturma, retry, yabancı işletme/istasyon/şube reddi, gerçek RLS SELECT, kendi yetkisini yükseltememe, mevcut JWT kimliğiyle pasifleştirme, salt-okunur finans ve kapalı baskı testleri başarılı.
- Deno Edge Function tip kontrolü başarılı (`deno check --node-modules-dir=auto`). Canlı Auth hesabı oluşturma denenmedi.
- Tam repo `flutter analyze`: ilk çalıştırmada 197 diagnostic, derleme hatası yok. Son değişen 8 dosya analizinde yalnız önceden mevcut `_localPrintStatusColor` kullanılmama uyarısı var; aynı metot temiz HEAD'de de mevcut. Bu nedenle analyze tamamen yeşil raporlanmıyor.
- `git diff --check` başarılı.
- macOS/Windows/Android fiziksel baskı ve kullanıcı etkileşimi **yapılmadı**. Windows native build veya Android cihaz testi yapılmadı; Flutter/Python testleri bunların yerine geçmez.

Yerel SQL testini tekrar çalıştırma: Yerel SQL testini tekrar çalıştırma:

```sh
npm install --prefix /tmp/ibul-sql-test-runtime @electric-sql/pglite
IBUL_PGLITE_MODULE=/tmp/ibul-sql-test-runtime/node_modules/@electric-sql/pglite/dist/index.js node ibul_app/supabase/tests/restaurant_operations_test.mjs
```

Bu test izole PostgreSQL motorunda yürür; canlı Supabase'e bağlanmaz. Auth sunucusunun kendisi, gerçek e-posta teslimatı, cihaz etkileşimi ve fiziksel yazıcı bu testin kapsamı değildir.
