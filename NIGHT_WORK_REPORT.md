# Gece çalışma raporu — 13 Kasım 2026

Mevcut commit edilmemiş iş korundu. Production veritabanına, canlı 3001 köprüsüne, canlı 18772 portuna ve fiziksel yazıcıya dokunulmadı. Atılabilir PostgreSQL kullanıldı ve kapatıldı.

Sabah devamı: fiyat trigger’ındaki kaçışlar kapatıldı, sipariş kaydından sonra arayüzün baskı kuyruğunu beklemesi kaldırıldı, izole köprüde 10 uçtan uca ölçüm alındı, 4000 satırlık snapshot planı karşılaştırıldı, web derlemesi ve imzasız iOS Profile derlemesi bitti.

## Masa kapatma bütünlüğü ve Yazıcı Merkezi — 13 Kasım gece

Production’a migration uygulanmadı. Canlı 3001, gerçek sipariş ve fiziksel yazıcı kullanılmadı. Atılabilir PostgreSQL 16 `127.0.0.1:55436` üzerinde çalıştı, ölçüldü ve silindi. Çalışan garson uygulaması bu turda açılmadı.

### Kapanış transaction’ı

`close_table_with_history` tek transaction içinde şunları yazar: her açık sipariş için bir `table_order_history` satırı, `table_orders.status = archived`, `orders.status = closed`. `table_payments` bu fonksiyonda insert veya delete edilmez.

`ensureTableHistoryRecorded` ikinci bir INSERT’tir. RPC `history_id` döndürdüğünde bu insert artık yapılmaz. `history_id` boşsa eski sunucu için fallback durur. `consolidateDuplicateHistoryChain` ve `supersedeRestoredHistoryOnReclose` kapanışın parçası değildir. İlki yalnızca aynı sipariş kimliğini zaten taşıyan fazla geçmiş satırını siler. Farklı `original_order_id` silinmez. Ödeme satırına ikisi de dokunmaz.

Aynı kapanışta iki sipariş varsa iki geçmiş satırı tasarım gereğidir; aynı siparişin kopyası değildir. İkinci cihaz veya kaybolan yanıt, satır kilidi kalktıktan sonra açık sipariş görmez. Yeni fonksiyon son iki dakikadaki geçmiş satırını döndürür ve ikinci satır yazmaz. İzole yarışta masa 21: geçmiş satırı 1, ödeme tutarı 10 durdu, ikinci çağrı `orders_updated = 0`.

Geçmiş doğrulaması başarısızsa kart boş gösterilmez; tahta kapatma öncesi haline döner ve RPC yeniden gönderilmez. Geçmiş temizliği ayrı transaction’dır. Bu transaction rollback edilince kapanış ve ödeme durur.

### 10 gerçek kapatma

Kaynak: `ibul_app/supabase/tests/isolated_close_table_ten_measure.sql`. Bu restoran ağı değildir.

| Aşama | medyan | p95 |
|---|---|---|
| RPC | 0.529 ms | 1.900 ms |
| RPC sonrası geçmiş doğrulaması | 0.015 ms | 0.030 ms |

On kapatmanın hepsinde geçmiş satırı vardı, ödeme durdu, açık sipariş kalmadı ve dolu sayaç bir azaldı. Kartın boşalması ve loading’in temizlenmesi bu SQL satırında aynı koşula bağlandı. Flutter çerçevesi olarak ölçülmedi.

### Yazıcı Merkezi

Kuyruk sayaçları son 40 `print_jobs` kaydının `operatorQueueBucket` alanından hesaplanır. Yalnızca başarısız ve tamamlanan beş kayıtla sınırlı değildir. Panel köprü, servis açık/kapalı, otomatik baskı, Ocak/Fırın kartı, IP, bağlantı türü, son iletim ve hata metnini gösterir. TCP iletimi fiziksel baskı sayılmaz. `physical_confirmation` yoksa “doğrulanmadı” yazar. İzin yüklenmemişse veya servis kapalıysa test fişi düğmesi çıkmaz.

İzole köprü testi, canlı 3001 değil: `/health` içinde `print_system_enabled=false`, mutfak POST 503, TCP baytı 0. İki test geçti.

### Offline

Yeni paralel sistem yok. Mevcut LAN, SQLite kuyruk, çift sipariş ve yerel baskı testlerinden 23’ü geçti. `signed local evidence syncs once through isolated PostgREST` çalışmadı: `IBUL_POSTGREST` boştu. Production adresine bağlanmadı.

### Test ayrımı

| Kontrol | Kaynak testi | Gerçek uygulama |
|---|---|---|
| 10 kapatma RPC ve geçmiş | Atılabilir PostgreSQL | Hayır |
| İkinci kapatma yeni satır yazmaz | Atılabilir PostgreSQL | Hayır |
| Kart, geçmiş yokken boş olmaz | Widget kararı | Hayır |
| Yazıcı kuyruğu ve Ocak kartı | Widget | Hayır |
| Servis kapalıyken 0 bayt | İzole köprü | Hayır |
| LAN / SQLite | 23 mevcut test | Hayır |
| `flutter analyze` | Hata yok, 192 eski bilgi/uyarı | — |

Açık kalan iş: `20261113210000_close_table_recent_history_lookup.sql` production’da değil. Canlı kapatma süresi ölçülmedi. Garson ekranı ve fiziksel yazıcı doğrulanmadı. Masa aktarma ve mutfak baskı yolu değiştirilmedi.

## İzole macOS test uygulaması — 13 Kasım gece

Ayrı çıktı klasöründe debug derleme alındı: `/tmp/ibul-offlinetest-dd/Build/Products/Debug/IbulSellerDesktop.app`. Canlı `build/macos` klasörüne yazılmadı. PID 8988 duruyor. Production scheme ve `AppInfo.xcconfig` değiştirilmedi. İlk `PRODUCT_NAME` override pod çerçevelerini bozduğu için yalnız `PRODUCT_BUNDLE_IDENTIFIER` kullanıldı. CocoaPods kaynak kopyası `firebase_messaging/` alt klasörünü istediği için o iki privacy bundle bağlandı ve derleme geçti.

| Sonuç | Durum |
|---|---|
| Ayrı bundle ID ile derlenmiş macOS test uygulaması | PASS |
| Gerçekten açılmış test satıcı penceresi | PASS |
| Dinleyen ve TLS doğrulaması geçen test LAN hostu | PASS |

Pencere başlığı İBUL Offline Test. Ekran satıcı giriş sayfası. Test restoranı seçilmedi ve masa tuvali çizilmedi: production oturumu kopyalanmadı, izole giriş yok. Bu masa ekranı için TEST EDİLMEDİ.

Host mevcut `RestaurantLanHost`. Port 127.0.0.1:18773. Sertifikalar `~/Library/Application Support/ibul-offline-test/offline-test-restaurant`. `~/Library/Application Support/ibul-lan` yok. 18772 dinlemiyor. Yazıcı sağlık kontrolü 127.0.0.1:18774 adresine gitti ve bağlantı reddedildi. 3001’e iş gönderilmedi.

App Sandbox içinde `openssl` çalışması `Operation not permitted` ile durdu. Test uygulamasının imzasından sandbox çıkarıldı. Production uygulamasının sandbox’ı duruyor. İki debug imzasında da `keychain-access-groups` yok. Test tercih dosyası `com.ibul.sellerdesktop.offlinetest.plist`. Production konteynerinde `native-bahce-3` yok. Keychain yazısı OSStatus 13 verdi; kayıt bu tercih dosyasına düştü.

Supabase adresi bu süreçte `http://127.0.0.1:9`. Production projesine yazılmadı.

TLS: `openssl s_client` TLSv1.3, sertifika `CN=ibul-lan`, Verification OK. Ardından mevcut istemci sertifika isteği, tek kullanımlık eşleştirme ve imzalı istemci sertifikasıyla native mTLS. Bu Android telefon testi değildir.

Bahçe 3 / Çorba / 40 TL, `local_order_id=native-bahce-3`. İlk kayıt `saved=true`. Aynı kimlik `duplicate=true`. Journal satırı 1. Mutfak işi `native-bahce-3|1|ocak|new_order`, durum `queued`, belge `kitchen`. Köprüye gönderilmedi.

Uygulama kapatılıp açılınca 18773 yine dinledi. Journal’daki tek satır durdu. Aynı sipariş tekrar `duplicate=true` döndü ve ikinci satır oluşmadı.

Android emülatörü açılmadı. WAN kesintisi başlatılmadı. GERÇEK WAN KESİNTİSİ TESTİNE HAZIR değil.

| Alan | Değer |
|---|---|
| Test PID | 78951 |
| Bundle ID | com.ibul.sellerdesktop.offlinetest |
| Test LAN portu | 18773 |
| Keychain izolasyonu | PASS, ortak grup yok; kayıt test tercih dosyasında |
| Production erişim engeli | PASS, URL 127.0.0.1:9, 3001 ve 18772 kullanılmadı |
| LAN TLS | PASS, TLSv1.3 Verification OK, mTLS eşleştirme 200 |
| Bahçe 3 sipariş testi | PASS, izole protokol; Android değil |
| Kalıcı kayıt | PASS, journal 1 satır, yeniden açılışta durdu |
| Mutfak baskı işi | PASS, 1 queued iş, 3001’e gitmedi |
| Satıcı masa ekranı | TEST EDİLMEDİ, pencere giriş sayfasında |

## macOS masa ekranı ve yerel ağ — 13 Kasım gece

Test uygulaması yeniden derlendi ve sandbox ile açıldı. Production imzası ve PID 8988 duruyor. App Sandbox test imzasından çıkarılmış hâli kalıcı çözüm sayılmadı; çalışan kopya `DebugProfile` sandbox’ı ile imzalı.

Host `192.168.10.158:18773` adresinde dinliyor. `0.0.0.0` yok. Sertifika SAN: `DNS:localhost`, `IP:127.0.0.1`, `IP:192.168.10.158`. `openssl verify` ve `s_client` Verification OK, TLSv1.3, `CN=ibul-lan`. mTLS kapatılmadı. `/usr/bin/openssl` sandbox içinde çalışmıyor; sertifika mevcut hostun okuduğu PEM dosyalarına uygulama içinde yazıldı. Özel anahtarlar `600` izinli dosyada. Plist veya JSON içinde özel anahtar yok.

Satıcı paneli garson modülünde açıldı. Üretim oturumu kopyalanmadı. Ekran kaydı: masa `Bahçe 3`, sipariş `native-bahce-3`, 1 kalem, toplam 40, dolu sayaç 1.

Keychain grubu elle eklenince süreç 137 ile öldü. Bu yüzden grup takılmadı. OSStatus 13 duruyor. Kayıt, grup kabul edilmediği için hâlâ güvenli depolama yerine sandbox konteynerine düşebilir. Production debug imzasında keychain grubu yok.

Android ve iOS bu turda derlenmedi, emülatör açılmadı, fiziksel cihaz bağlanmadı. İkisi de mevcut `RestaurantLanClient` yolunu kullanır. Ayrı test applicationId uygulanmadı.

| Özellik | macOS | Android | iOS |
|---|---|---|---|
| Uygulama derlemesi | PASS, sandbox debug | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Gerçek uygulama açılışı | PASS, PID 87836 | TEST EDİLMEDİ | TEST EDİLMEDİ |
| LAN bağlantısı | PASS, 192.168.10.158:18773 | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Native mTLS | PASS, TLSv1.3 Verification OK | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Masa ekranı | PASS, Bahçe 3 kartı | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Sipariş gönderme/alma | PASS, önceki kayıt ekranda | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Kalıcı sipariş | PASS, journal | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Duplicate önleme | PASS, önceki tur | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Yeniden başlatma | PASS, önceki tur | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Offline çalışma | Kısmi, bulut 127.0.0.1:9 kapalı, LAN açık | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Gerçek fiziksel cihaz | Bu Mac | TEST EDİLMEDİ | TEST EDİLMEDİ |

GERÇEK WAN KESİNTİSİ TESTİNE HAZIR değil. Android ve iOS bağlantısı doğrulanmadı. OSStatus 13 kapanmadı.

## Android ve iOS garson derlemesi — 13 Kasım gece

macOS test merkezi duruyor: PID 87836, `192.168.10.158:18773`. IP değişmedi. Production PID 8988 duruyor. `adb devices` boş. iOS Simulator açık değil. Boş bellek yaklaşık 60 MB. Emülatör ve simülatör başlatılmadı.

Garson ekranı yeni yazılmadı. `lib/main_waiter_lan.dart` mevcut `RestaurantLanWaiterPage` ekranını açar. Sipariş yine `RestaurantLanClient`. Port varsayılanı 18772. Test derlemesi `IBUL_LAN_PORT=18773` ister. 3001 bu kapıya yazılmaz. Merkez kapalıysa durum metni artık “Sipariş kaydedilmedi” der.

Android kimliği ortam değişkeni `IBUL_ANDROID_APPLICATION_ID=com.ibul.waiter.offlinetest` ile seçilir. Değişken yoksa `com.example.ibul2026` kalır. APK oluşmadı. `flutter build apk --debug --target lib/main_waiter_lan.dart` iki kez Gradle sarmalayıcısında kaldı: süreç GitHub `185.199.109.133:443` bağlantısında, CPU yaklaşık %0, yeni dosya yazılmadı. `gradle-8.14-all` önbellekte duruyor. `curl` aynı dağıtım adresine 2 saniyede HTTP 200 aldı. Üçüncü deneme IPv4 zorlamasıyla da aynı bağlantıda kaldı. Derleme durduruldu. Host düşmedi.

iOS derlemesi başlatılmadı. Proje hedefi iOS 13.0. `Info.plist` içinde yerel ağ açıklaması ve `_ibul-lan._tcp` var. Genel ATS istisnası eklenmedi. Simulator açılmadı. Fiziksel iPhone kurulumu ve imza bu turda yok.

Keychain: gruba `keychain-access-groups` eklenip yeniden imzalanan test uygulaması yaklaşık 300 ms içinde çıkış 137 ile öldü. Bu, çalışan bir sürecin bellek yüzünden atılması değil; imza kabul edilmeden kapanma. Sandbox’lı imza, grup olmadan açılıyor. OSStatus 13 duruyor. Özel anahtarlar `600` dosyada. Plist içinde özel anahtar yok. Güvenli dağıtım için Keychain PASS değil.

| Kontrol | Android | iOS |
|---|---|---|
| Debug build | FAIL, Gradle sarmalayıcısı ilerlemedi | TEST EDİLMEDİ |
| Test uygulaması açılışı | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Gerçek garson ekranı | TEST EDİLMEDİ | TEST EDİLMEDİ |
| LAN host keşfi | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Native mTLS | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Cihaz eşleştirme | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Bahçe 3 masa listesi | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Sipariş gönderme | TEST EDİLMEDİ | TEST EDİLMEDİ |
| macOS ekranına yansıma | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Duplicate önleme | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Yeniden bağlanma | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Offline sipariş | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Fiziksel cihaz testi | TEST EDİLMEDİ, adb boş | TEST EDİLMEDİ, simülatör kapalı |

WAN kesintisi başlatılmadı.

## Gradle ve iOS hazırlık — 14 Kasım

Gradle 8.14 dağıtımı önbellekte tam. SHA-256 `efe9a3d147d948d7528a9887fa35abcf24ca1a43ad06439996490f77569b02d1`, resmi `gradle-8.14-all.zip.sha256` ile aynı. `bin/gradle --version` ve `./gradlew --version` JDK 21 ile birkaç saniyede bitti. Dün takılan süreç Gradle’ın Java indiricisiydi: `services.gradle.org` GitHub release varlığına yönleniyor, soket açık kalıyor, CPU yaklaşık %0, yeni dosya yazılmıyor. `curl` HEAD 200 bunu çürütmez. `android/gradle.properties` bu 8 GB makinede `-Xmx8G` istiyor. Bu derlemede yığın geçici olarak 1 GB ile sınırlandı, dosya sonra eski haline alındı. Sürüm değiştirilmedi.

Android debug APK oluştu: `build/app/outputs/flutter-apk/app-debug.apk` (172 MB). `aapt dump badging` paket adı `com.ibul.waiter.offlinetest`. Çekirdekte `lib/main_waiter_lan.dart`, `18773`, `offline-test-restaurant` ve `127.0.0.1:9` var. Uygulama açılmadı: `adb` boş, emülatör başlatılmadı.

iOS `pod install` 841 saniyede bitti. Simulator derlemesi iki mimaride gRPC derlerken durduruldu. Türetilmiş veri 3,7 GB, boş disk 2,9 GB kalmıştı. `.app` yok. Simulator açılmadı. `ios/Flutter/Generated.xcconfig` eski `lib/main.dart` hedefine geri alındı. Genel ATS istisnası eklenmedi.

LAN host PID 87836, `192.168.10.158:18773`. Production PID 8988 duruyor. Mobil ekrandan sipariş gönderilmedi. OSStatus 13 ayrı duruyor. Keychain grubu eklenen imza yaklaşık 300 ms içinde çıkış 137 verdi. Bu bellek atması değil.

| Kontrol | Durum | Kanıt |
|---|---|---|
| Gradle wrapper kök nedeni | PASS, tespit | Önbellek doğru; takılma GitHub soketinde. 8 GB yığın ayrı risk |
| Gradle çalıştırılabiliyor | PASS | `./gradlew --version` → Gradle 8.14, JDK 21 |
| Android debug APK üretildi | PASS | `build/app/outputs/flutter-apk/app-debug.apk` |
| Android test applicationId doğrulandı | PASS | `com.ibul.waiter.offlinetest` |
| Android LAN port yapılandırması | PASS | çekirdekte 18773 |
| iOS Simulator build üretildi | FAIL | disk dolmadan durduruldu, `.app` yok |
| iOS test bundle identifier | TEST EDİLMEDİ | derleme bitmedi |
| Android garson ekranı açıldı | TEST EDİLMEDİ | cihaz ve emülatör yok |
| iOS garson ekranı açıldı | TEST EDİLMEDİ | Simulator açılmadı |
| Native LAN bağlantısı | TEST EDİLMEDİ | mobil süreç yok |
| Gerçek sipariş gönderildi | TEST EDİLMEDİ | mobil ekran yok |
| Production etkilenmedi | PASS | PID 8988 ve host 87836 duruyor |

## Android cihaz ve iOS disk — 14 Kasım öğleden sonra

APK duruyor: `build/app/outputs/flutter-apk/app-debug.apk`, 172 MB. `aapt` paket adı `com.ibul.waiter.offlinetest`. Çekirdekte `main_waiter_lan.dart`, port `18773`, restoran `offline-test-restaurant`, Supabase adresi `127.0.0.1:9`. Production host dizesi paylaşılan kod yüzünden ikilide duruyor; bu giriş Supabase başlatmıyor. İzinler: INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE. İstemci sertifikayı `writeSecret` ile yazar; başarısız olursa eşleştirme durur ve anahtar tercihlere düşmez. `RestaurantLanClient` parmak izi eşleşmeyen sertifikayı kabul etmez.

`adb devices -l` boş. APK kurulmadı. Emülatör açılmadı. Sipariş testi TEST EDİLMEDİ.

Boş disk 6,6 GB. iOS Simulator derlemesi başlatılmadı. 12–15 GB isteniyor.

| Klasör | Boyut | Silinmedi |
|---|---|---|
| CoreSimulator | 29 GB | Evet, simulator verisi |
| DerivedData/Runner-bvfhrtwjddhlckheiijveagfoums | 11 GB | Evet, Xcode ara derleme |
| iOS DeviceSupport iPhone12,5 26.5 | 5,5 GB | Evet, sembol önbelleği |
| iOS DeviceSupport iPhone12,5 26.3 | 5,3 GB | Evet, eski sembol önbelleği |
| build/macos | 7,8 GB | Evet, çalışan PID 8988 burada |
| .gradle/caches | 7,1 GB | Evet |
| build/app | 2,1 GB | Evet, test APK burada |
| build/offlinetest | 312 MB | Evet, çalışan test uygulaması |
| CocoaPods cache | 196 MB | Evet |

Journal, sertifika ve Git değişiklikleri silinmedi. `flutter clean` ve `pod cache clean --all` çalıştırılmadı.

| Sonuç | Durum |
|---|---|
| Android APK kuruldu | TEST EDİLMEDİ, cihaz yok |
| Fiziksel Android cihaz | TEST EDİLMEDİ |
| Android garson ekranı | TEST EDİLMEDİ |
| Android LAN eşleştirmesi | TEST EDİLMEDİ |
| macOS ekranına yansıma | TEST EDİLMEDİ |
| Duplicate önleme | TEST EDİLMEDİ |
| iOS için gereken boş alan | 12–15 GB, şu an 6,6 GB |
| Güvenle açılan alan | 0 |
| iOS Simulator build | TEST EDİLMEDİ |
| Production etkilenmedi | PASS, PID 8988 ve host 87836 |

## iPhone açılış ve garson denemesi — 14 Kasım akşam

`flutter run --release` hedefsiz çalışınca `lib/main.dart` açılıyor. iOS Firebase seçenekleri yalnız `IBUL_FIREBASE_IOS_API_KEY` dart-define bakıyor. Ekrandaki `firebaseApiKeyPresent=true` ve `firebaseSource=generated` Android anahtarının tanısı. iOS anahtarı boşken `StateError` bu yüzden kalkıyor. `GoogleService-Info.plist` dolu ve artık Runner kaynaklarına bağlı. iOS dart-define boşsa `Firebase.initializeApp()` plist’i okuyor. Anahtar koda veya loga yazılmadı. Bu yol telefonda çalıştırılmadı: garson denemesi `lib/main_waiter_lan.dart` ve Firebase başlatmıyor.

Debug `PRODUCT_BUNDLE_IDENTIFIER` `com.ibul.waiter.offlinetest`. Release ve Profile `com.example.ibul2026` kaldı. Uygulama telefona kurulmadığı için ayrı kimlik cihazda doğrulanmadı.

`pubspec.yaml` ve `pubspec.lock` boyutu duruyordu, ayrılmış bloğu yoktu, okuma 0 bayt dönüyordu. İkisi Git indeksindeki kopyadan yeniden yazıldı. `flutter pub get` bitti. Kökte 56 dosya hâlâ boyutlu ama bloksuz. Kaynak `lib/` ve `ios/` bu listede değil.

IP `192.168.10.158`. İzole test uygulaması PID 66716, `192.168.10.158:18773` dinliyor. Sertifika SAN aynı IP’yi içeriyor. Sağlık kontrolü `127.0.0.1:18774` ve bağlantı reddedildi. 3001’e iş gitmedi. OSStatus 13 yine loglandı, süreç dinlemeye devam etti. Production satıcı süreci bu turda başlatılmadı veya durdurulmadı.

Kablosuz “Baran iPhone’u” `00008030-001610AC14BB802E` göründü. `flutter run --debug --target lib/main_waiter_lan.dart` Dart derleyicisi beklenmeden çıktı. Xcode imzasına ve kuruluma gelinmedi. Boş bellek yaklaşık 66 MB. Garson ekranı açılmadı. Keşif, eşleştirme ve Bahçe 3 siparişi TEST EDİLMEDİ.

| Soru | Sonuç |
|---|---|
| Firebase açılış hatası çözüldü mü | Kod değişti, cihazda TEST EDİLMEDİ |
| Kök neden | Varsayılan `lib/main.dart`; iOS anahtarı Android tanısından ayrı ve boştu |
| Garson girişi | Komut `lib/main_waiter_lan.dart`; derleme bitmedi |
| Ayrı iOS test kimliği | Debug ayarında `com.ibul.waiter.offlinetest`; kurulmadı |
| iPhone garson ekranı | FAIL, Dart derleyicisi çıktı |
| LAN ve mTLS | Host dinliyor; telefondan TEST EDİLMEDİ |
| Bahçe 3 siparişi | TEST EDİLMEDİ |
| Production korundu | Bu turda production satıcı yeniden derlenmedi |

## İzolasyon ve 18772 — 13 Kasım gece

PID 8988 kapatılmadı. 3001’e ve production yazmasına dokunulmadı. Aynı production kimliğiyle ikinci pencere açılmadı. Ayrı test kimliği sonraki bölümde açıldı.

18772 kapalı çünkü `~/Library/Application Support/ibul-lan` yok. Merkez daha önce etkinleştirilmemiş. Portu başka süreç tutmuyor. Host açılıp çökmemiş; hiç başlatılmamış. Kayıtlı IP de yok. Başka bilgisayarın host sayılması IP’ye değil, aynı restoran ve farklı makine kimliğine bağlı.

Aynı `com.ibul.app` kimliği Keychain ve tercih dosyasını paylaşır. Sertifika klasörü de aynı ev dizinindedir. Bu yüzden ikinci GUI kopyası izole değildir ve çalıştırılmadı. Test süreci `IBUL_LAN_HOME` ile bu klasörün dışına yazabilir. Bu ayrımın testi geçti. Keychain hâlâ aynı uygulama kimliğini paylaştığı için GUI açılmadı.

Bellek 8 GB, boş pay yaklaşık %28. Diskte yaklaşık 8,7 GB boş. Pixel 8 emülatörü bu yükte başlatılmadı. `adb` hâlâ boş.

| Soru | Sonuç |
|---|---|
| macOS test uygulaması açıldı mı | TEST EDİLMEDİ, izolasyon güvenli değil |
| LAN host dinliyor mu | FAIL, 18772 kapalı, merkez hiç kurulmamış |
| Android emülatörü | TEST EDİLMEDİ, RAM yetmedi |
| Android uygulaması | TEST EDİLMEDİ |
| Native mTLS | TEST EDİLMEDİ |
| Bahçe 3 siparişi | TEST EDİLMEDİ |
| Gerçek masa kartı | TEST EDİLMEDİ |
| Mutfak işi | TEST EDİLMEDİ |
| İnternetsiz izole sipariş | TEST EDİLMEDİ |
| Yeniden başlatma | TEST EDİLMEDİ |
| Production’a dokunulmadı | PASS |

GERÇEK WAN KESİNTİSİ TESTİNE HAZIR değil.

## Çalışan uygulama kontrolü — 13 Kasım gece

`flutter devices` bu Mac’te macOS, Chrome ve kablosuz “Baran iPhone’u” gördü. `adb devices` boş. Android emülatör tanımları var (Pixel 8, Pixel 2, Medium Tablet, flutter_emulator) ama hiçbiri açık değil. `build` altında hazır apk yok.

Debug `IbulSellerDesktop` süreci zaten açık (PID 8988). İkinci kopya başlatılmadı. `18772` dinlemiyor; bu süreçte LAN merkezi ayakta değil. Süreç production Supabase adresine bağlı derlenmiş. Bu yüzden Bahçe 3 siparişi o sürece gönderilmedi. Canlı 3001’e ve fiziksel yazıcıya dokunulmadı.

| Soru | Sonuç |
|---|---|
| macOS satıcı süreci açık mı | Evet, PID 8988. Bu turda yeniden derlenip açılmadı |
| LAN merkezi bu süreçte | FAIL, 18772 kapalı |
| Android garson açıldı mı | TEST EDİLMEDİ, bağlı cihaz ve çalışan emülatör yok |
| Native mTLS bu turda | TEST EDİLMEDİ |
| Bahçe 3 gerçek ekranda | TEST EDİLMEDİ |
| Fiziksel cihaz | TEST EDİLMEDİ |

## Native satıcı merkezi — 13 Kasım gece

Tarayıcı kapısı satıcı uygulamasından açılmıyor. Garson tabletleri native mTLS portunda kalıyor.

Satıcı uygulaması, daha önce bu bilgisayarda açılmış merkezi, kayıtlı adres duruyorsa yeniden başlatır. Merkez zaten dinliyorsa ikinci host açılmaz. Başka makine bu restoran için yanıt veriyorsa devralma yok. İlk kurulumda arayüz seçimi ve onay duruyor. Açılış hatası artık genel cümlenin yanında gerçek hata metnini gösterir.

Garson modülü açılınca yerel siparişler mağaza sahibi kimliğiyle masa tahtasına yazılır. Personelin kendi kullanıcı kimliği bu kuyruğun anahtarı değildir.

`flutter test test/services/seller_lan_center_action_test.dart` geçti. macOS satıcı penceresi ve Android tablet bu turda açılmadı. Loopback süreleri gerçek Wi-Fi süresi değildir.

| Özellik | İzole test | Gerçek uygulama | Fiziksel cihaz |
|---|---|---|---|
| Satıcı uygulaması offline açılış | Kısmi, önbellek yolu vardı | TEST EDİLMEDİ | TEST EDİLMEDİ |
| LAN host otomatik başlangıç | PASS, karar kuralı | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Native garson bağlantısı | Önceki mTLS PASS | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Offline sipariş kabulü | Önceki TLS PASS | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Kalıcı sipariş kaydı | PASS, dosya günlüğü | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Satıcı masa ekranı güncellemesi | PASS, tahta modeli | TEST EDİLMEDİ | TEST EDİLMEDİ |
| İkinci garson senkronizasyonu | Önceki TLS PASS | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Offline mutfak baskı işi | PASS, kuyruk | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Offline adisyon | Görüntüleme yolu var | TEST EDİLMEDİ | TEST EDİLMEDİ |
| İnternet dönüşü senkronizasyon | Önceki izole PASS | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Duplicate sipariş önleme | PASS | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Duplicate baskı önleme | Önceki bariyer PASS | TEST EDİLMEDİ | TEST EDİLMEDİ |
| Yazıcı Merkezi 2.0 | Kısmi, önceki şerit | TEST EDİLMEDİ | TEST EDİLMEDİ |

Ödeme, iade ve masa kapatma çevrimdışı açılmadı. Disk arızasında kayıt kaybı olmayacağı iddia edilmez. Fiziksel baskı yapılmadı.

## Tarayıcı LAN kapısı — 13 Kasım gece

Tarayıcı, native porta istemci sertifikası gönderemediği için HTTP katmanına hiç varmıyordu. Bu bir CORS hatası değil. `curl` aynı adrese `SSL certificate problem: unable to get local issuer certificate` dedi. Chrome `chrome-error://chromewebdata/` açtı. Sertifika denetimini kapatmadım.

Native mTLS portu duruyor. Yanına, istemci sertifikası istemeyen ayrı bir HTTPS kapısı eklendi. Sipariş yine aynı `RestaurantLanHost` kuyruğuna yazılıyor. Kapı, işletme sertifikasıyla üretilen tek kullanımlık kodu kabul eder, 8 saatlik bearer oturum verir, sıra numarasını tekrar kabul etmez, origin eşleşmezse 401 döner. Kod ikinci kez kullanılamaz. Ödeme ve masa kapatma bu kapıda yok.

`flutter test test/services/lan_browser_gate_test.dart` geçti. İstemci sertifikası olmayan istek Bahçe 3’ü gördü, Çorba siparişini kaydetti, bir mutfak işi açtı, aynı kimliği ikinci kez yeni siparişe çevirmedi ve garson tahtası olayına `browser-bahce-3` düştü. Yabancı origin reddedildi.

Gerçek tarayıcı sayfayı açamadı çünkü kapının sertifikası sistem güven deposunda değil. Bu yüzden tarayıcıda masa listesi ve sipariş gönderme FAIL. Çalışan garson oturumu da açılmadı.

| Kontrol | Sonuç |
|---|---|
| Web release build | PASS, önceki derleme |
| Offline uygulama kabuğu | PASS, önceki tarayıcı |
| Tarayıcı LAN kimlik doğrulaması | FAIL, sertifika güveni; protokol testi PASS |
| Offline masa listesi | FAIL, tarayıcı; protokol testi PASS |
| Offline sipariş gönderme | FAIL, tarayıcı; protokol testi PASS |
| Ana bilgisayar gerçek garson kartı | TEST EDİLMEDİ |
| İkinci garson | Protokolde tek kayıt; cihaz yok |
| Kalıcı sipariş kuyruğu | PASS, aynı test |
| Mutfak baskı işi | PASS, kuyrukta 1 iş; fiziksel baskı yok |
| Cloud senkronizasyonu | Bu turda yeniden çalıştırılmadı |
| Gerçek fiziksel cihaz | TEST EDİLMEDİ |

## Web release ve çevrimdışı yenileme — 13 Kasım gece

`flutter build web --release --pwa-strategy=none` tamamlandı. Çıktı `ibul_app/build/web`. Süre yaklaşık 541 saniye. Firebase deploy yapılmadı. Flutter’ın kendi service worker’ı bilinçli olarak kapalı; eski sürümün takılmaması için. Yerine yalnız aynı origin’deki uygulama kabuğunu tutan `ibul_shell_sw.js` kaydı eklendi. Supabase, auth ve müşteri yanıtları bu önbelleğe yazılmaz.

Gerçek tarayıcıda `http://127.0.0.1:8779` açıldı. Uygulama çizildi. Ardından yerel sunucu kapatıldı ve `supabase.co` engellendi. Normal gezinme yine açıldı: Flutter yüzeyi duruyordu, service worker kontroldeydi, `/index.html` önbellekten 200 döndü. Ürün listesi “yüklenemedi” dedi. Bu, bulut verisinin önbelleğe alınmadığını gösterir.

Bu, garson masa listesi değildir. Tarayıcı yerel merkeze istemci sertifikasıyla bağlanamaz; mevcut metin bunu söyler ve sipariş başarılı gösterilmez. Chrome’un önbelleği atan hard reload’u ve daha önce hiç açılmamış bir tarayıcı offline açılışı bu turda PASS değildir.

Garson kartı çalışan satıcı oturumunda açılmadı. Ekranın kullandığı `resolveGarsonRenderBundle` Bahçe 3 için dolu sayaç 1 verdi. Fiziksel cihaz doğrulaması yok.

| Soru | Sonuç |
|---|---|
| Release web build | PASS |
| Normal offline yenilemede kabuk | PASS, tarayıcı |
| Yenilemede LAN bağlantısı | FAIL, tarayıcı mTLS kullanamaz |
| Masa listesi | FAIL |
| Offline yeni sipariş | FAIL, tarayıcıda gönderilmedi |
| Gerçek garson kartı | TEST EDİLMEDİ, oturum açılmadı |
| İkinci garson | TEST EDİLMEDİ, cihaz yok |
| Süreç sonrası kayıt | Önceki dosya testi PASS |
| Yazıcı Merkezi yeni bağ | Bu turda genişletilmedi |
| Mutfak hızı | Korundu, bu turda o yola dokunulmadı |

## Garson kartı ve web yenileme — 13 Kasım gece

LAN siparişi artık yerel operasyon sayfasının yanında garson tahtasının okuduğu `GarsonBoardState` içine girer. Aynı `local_order_id` ikinci satır açmaz. Daha eski snapshot, karttaki yeni ürünün üzerine yazmaz. Satıcı paneli olay gelince ve açılışta kuyruktan bu tahtayı doldurur. Sayaçlar aynı kart modelinden hesaplanır.

İzole kart testi: Bahçe 3 dolu, Çorba, toplam 40, baskı durumu kuyrukta, dolu sayaç 1, boş sayaç 0. İkinci tahta aynı siparişi görür. Tekrar ve bulut kimliği kaydı 1’de bırakır. Çalışan garson uygulaması açılmadı.

Web hard refresh **FAIL**. Release web derlemesi bu turda üretilmedi. Tarayıcıda internet kesilerek yenileme yapılmadı. Chrome’un hard reload’u service worker önbelleğini de atlar; PASS yazılmadı.

Sipariş kuyruğu, sertifika klasörü varsa aynı JSON’u geçici dosyaya yazıp atomik olarak adlandırır. Ayrı bir `dart` süreci bu dosyayı okudu: 1 sipariş, `local-keep`. Yarım `{` dosyası boş kuyruk sayılmadı ve üzerine yazılmadı. Fiziksel elektrik kesintisi yapılmadı. Mutfak işi kuyruğu bu dosya günlüğüne alınmadı.

| Kontrol | İzole | Gerçek cihaz |
|---|---|---|
| Tablet → LAN | Önceki TLS PASS | TEST EDİLMEDİ |
| Kalıcı sipariş | PASS | TEST EDİLMEDİ |
| Mutfak işi | Önceki TLS PASS | TEST EDİLMEDİ |
| Garson masa kartı | PASS, kart modeli | TEST EDİLMEDİ |
| İkinci garson | PASS, aynı tahta modeli | TEST EDİLMEDİ |
| Web hard refresh | FAIL | TEST EDİLMEDİ |
| Süreç ölünce sipariş | PASS, ikinci dart süreci | TEST EDİLMEDİ |
| Buluta bir kez yazma | Önceki PASS | TEST EDİLMEDİ |
| İkinci fiş yok | Önceki bariyer | TEST EDİLMEDİ |
| Başka restoran | Önceki PASS | TEST EDİLMEDİ |

## Offline restoran — 13 Kasım gece devam

Kök neden: internet yokken bağlantı modu, yerel sipariş merkezi kapalı olsa da `offlineLocalMode` dönüyordu. Wi-Fi tek başına sipariş otoritesi sayılmamalı.

Şimdi karar mevcut `RestaurantConnectivityService` içinde:

- Bulut ve yazıcı köprüsü ayaktaysa çevrimiçi.
- Bulut yok, ana bilgisayar dinliyorsa çevrimdışı yerel mod.
- Ağ yok ve ana bilgisayar dinlemiyorsa yerel merkez kullanılamıyor.
- Ağ var, Supabase yok, yerel merkez yoksa bulut erişilemiyor.
- Eşitleme ve çakışma ayrı durum.

Garson yazısı: **Çevrimdışı — Yerel sistem aktif**, **Yerel sipariş merkezi kullanılamıyor**, **Senkronize ediliyor...**

Eşleşmiş tablet, bulut ayakta olsa da siparişi ana bilgisayarın LAN merkezine gönderir. Ana bilgisayarın kendi garsonu bulut ayaktayken eski hızlı mutfak yolunda kalır. Bulut yoksa ve merkez dinliyorsa kayıt yine LAN’dadır. Aynı `local_order_id` ikinci kez yeni sipariş açmaz.

Kalıcı depo SQLite değildir. Uygulamada SQLite sipariş veritabanı yok; ikinci bir tane açılmadı. Kayıt mevcut güvenli yerel kuyruktadır. Bellek silinip yeni servis nesnesi açılınca 10 sipariş ve 10 mutfak işi durdu. Bu, süreç içi depo kanıtıdır. Elektrik kesilerek kapatılmış bir macOS uygulaması ölçülmedi.

Baskı işi yazılamazsa sipariş kaydı geri alınır ve tablete başarı dönmez. Ödeme, iade ve masa kapatma LAN’da kapalı duruyor.

İzole senkron testi, production değil, yerel HTTP RPC taklididir. Aynı `local-one` kaydı: ilk yanıt koptu, kayıt durdu; ikinci deneme tek `remote-one` yazdı; sonraki sekiz deneme yeni kayıt açmadı. On denemenin medyanı 25 µs, p95 37.8 ms. Medyan, zaten eşitlenmiş kaydın boş kontrolüdür. Bu restoran ağı veya fiziksel baskı süresi değildir.

Flutter Web hard refresh, internet yokken **FAIL**. Derlenmiş `build/web` yok. `index.html` Flutter service worker kaydını siler. Uygulama dosyaları buluttadır. Tarayıcı yenilemesi bu turda internet kapatılarak yapılmadı. PASS yazılmadı.

İzole iki garson, loopback TLS:

| Aşama | Sonuç | Süre |
|---|---|---|
| 10 LAN kabul | PASS | medyan 8.525 ms, p95 35.850 ms |
| Kalıcı sipariş + mutfak işi | PASS, 10/10 | Kabulün içinde |
| İkinci garson `/lan/floor` | PASS, 10 sipariş | — |
| Aynı kimlik tekrarı | PASS, kayıt 10 kaldı | — |
| Bellek silinip yeniden okuma | PASS | Süreç içi |
| 10 kaydın buluta bir kez yazılması | PASS, ikinci tur 0 | p95 33.319 ms; medyan 19 µs boş kontroldür |
| Garson kartı | FAIL | Olay yalnız yerel operasyon sayfasına bağlandı |
| Fiziksel fiş | Ölçülmedi | — |
| Web hard refresh | FAIL | — |

Ödeme, iade, indirim ve masa kapatma offline açılmadı. Eski snapshot tahsilat sayılmaz.

| Özellik | Kod | İzole test | Gerçek cihaz | Durum |
|---|---|---|---|---|
| Otomatik offline geçiş | Evet | Evet | Hayır | Merkez yokken yerel mod yok |
| İnternet olmadan sayfa yenileme | Hayır | Hayır | Hayır | Web PASS değil |
| Offline masa listesi | Vardı | Soğuk okuma | Hayır | Mevcut snapshot |
| Tablet LAN siparişi | Vardı | Önceki LAN testleri | Hayır | Canlı 18772 açılmadı |
| Kalıcı sipariş | Vardı | Evet | Hayır | SQLite değil, mevcut kuyruk |
| Ana bilgisayarda anlık görünüm | Kısmi | Hayır | Hayır | Host olayı bu turda yeni bağlanmadı |
| Offline mutfak baskısı | Vardı | Önceki | Hayır | Fiziksel PASS yok |
| Offline adisyon | Sınırlı | Hayır | Hayır | Tahsilat açılmadı |
| Sipariş idempotency | Evet | Evet | Hayır | 10 deneme, 1 kayıt |
| İnternet dönüşü senkronizasyon | Evet | Yerel RPC taklidi | Hayır | `IBUL_POSTGREST` hâlâ boş |
| Duplicate baskı önleme | Vardı | Önceki bariyer | Hayır | Eşitlenen fiş yeniden basılmadı |
| LAN host otomatik başlangıç | Vardı | Hayır | Hayır | Canlı port açılmadı |
| Yazıcı Merkezi 2.0 | Kısmi | Widget | Hayır | Yerel merkez satırı eklendi |
| Yetki ve güvenlik | Vardı | Önceki mTLS | Hayır | Yeni migration yok |

Masa aktarma ve hızlı mutfak yolu değiştirilmedi. Production migration uygulanmadı. Canlı 3001 ve fiziksel yazıcı kullanılmadı.

## Masa kapatma senkronu — 13 Kasım akşam

Kök neden: kapatma, RPC bitmeden masayı boş gösteren işareti basıyordu ve kapatma yazısı ayrıca duruyordu.

Şimdi kart, geçmiş satırı görünene kadar dolu kalır ve **Masa kapatılıyor...** der. `ensureTableHistoryRecorded` bir SELECT sonrası gerekirse `table_order_history` tablosuna INSERT yapar. Bu zorunlu arşiv yazısıdır; kart bundan önce boş olmaz. `consolidateDuplicateHistoryChain` ve `supersedeRestoredHistoryOnReclose` ise kapanış kaydı durduktan sonra fazla satırları DELETE eden temizliktir. Kapatmanın kendisi değiller; kart güncellendikten sonra arka planda çalışırlar.

Kapatma işareti, masanın kapalı işaretlendiği aynı `setState` içinde silinir. RPC zaman aşımında ikinci bir `close_table_with_history` çağrısı yoktur. Başarısız kapatma tahtayı kapatma öncesi haline alır.

10 izole aşama ölçümü, ağ olmadan boş fonksiyonlarla alındı. Bu restoran kapatma süresi değildir:

| Aşama | medyan | p95 |
|---|---|---|
| RPC yuvası | 11 µs | 97 µs |
| Geçmiş yuvası | 4 µs | 22 µs |
| UI yuvası | 0 µs | 28 µs |

Canlı RPC süresi ölçülmedi.

Yenileme kartı kök overlay içindedir; liste kaydırılınca yer değiştirmez. Aşağı çekerek yenilemede ikinci orta kart açılmaz.

Yazıcı Merkezi şeridine kuyruk sayacı eklendi: bekliyor, başarısız, belirsiz, servis kapalı bekleyen, karantina. TCP yazımı fiziksel çıktı sayılmaz. Mutfak baskı yolu değişmedi.

## Operasyon geri bildirimi — 13 Kasım akşam

Mutfak ve adisyon baskı kodu değiştirilmedi.

| Özellik | Kod | Test | Gerçek uygulama | Durum |
|---|---|---|---|---|
| Web anlık yükleme | Evet | Evet | Tarayıcıda ilk kare | Ortada küçük “Yükleniyor...” |
| Masa kapatma kart animasyonu | Evet | Widget | Hayır | Boş kartta kapatılıyor yazısı kalmaz |
| Masa aktarma animasyonu | Evet | Widget | Hayır | RPC öncesi “Masa aktarılıyor...” |
| Masa aktarım hızı | Kısmi | Hayır | Hayır | Canlı RPC ölçülmedi; tam liste yenilemesi yoktu |
| Mobil yenileme butonu | Evet | Widget | Hayır | Aynı yenileme fonksiyonu, “Yenileniyor...” |
| Pull-to-refresh | Vardı | Hayır | Hayır | Aynı fonksiyon; üst gösterge duruyor |
| Yazıcı Merkezi 2.0 | Kısmi | Hayır | Hayır | Kapalı ve bilinmeyen durum metinleri hizalandı |
| Yazıcı Aç/Kapat | Evet | Evet, izole | Hayır | Kapalıyken 0 TCP baytı |
| Yazıcı durum tutarlılığı | Kısmi | Kısmi | Hayır | Canonical etiketler |
| Mutfak baskı performansı | Korundu | Önceki izole | Hayır | Hızlı yol değiştirilmedi |
| Adisyon baskı performansı | Korundu | Hayır | Hayır | Ölçülmüş yeni hız iddiası yok |
| Offline masa snapshot | Vardı | Soğuk okuma | Hayır | Yeni servis nesnesi aynı depoyu okur |
| Offline sipariş | Vardı | Evet | Hayır | Mevcut kuyruk |
| Offline senkronizasyon | Kısmi | Evet | Hayır | WAN kesintisi yapılmadı |
| Fiyat güvenliği | Evet, uygulanmadı | Evet, izole | Hayır | Production’da değil |

Sayfa yenilemenin ilk karesi tarayıcıda görüldü: ortada mor halka ve “Yükleniyor...”. Sahte menü tıklanabilir değil. `flutter_bootstrap.js` kaynak `web/` klasöründe yok; onu yalnızca `flutter build web` üretir. Kaynak klasörü sunmak bu yüzden bir süre sonra “Uygulama başlatılamadı” paneline düşer. Bu, hazır derlemenin iç mantık hatası değildir. Önceki derlenmiş önizleme geçici bir anon anahtarla açılmıştı.

Masa kapatma, kapanan kartın numarası `_garsonClosingTableNumbers` içine girer girmez kartta “Masa kapatılıyor...” gösterir ve ikinci kapatmayı reddeder. RPC başarısız olursa işaret kalkar. Başarı, kapanmış gibi gösterilmeden önce sunucu yanıtına bağlıdır.

Masa aktarımı, onaydan sonra ve RPC’den önce “Masa aktarılıyor...” açar. İkinci aktarım `_tableTransferBusy` ile durur. Başarıda kaynak ve hedef siparişler mevcut board state içinde taşınır. Canlı aktarım süresi ölçülmedi.

## Durum

| Özellik | Kod tamamlandı | Test geçti | Gerçek cihaz | Durum |
|---|---|---|---|---|
| Yazıcı Aç/Kapat | Evet | Evet | Hayır | İzin bilinmiyorsa ve kapalıysa fiziksel gönderim durur |
| Yazıcı durum tutarlılığı | Evet | Evet | Hayır | Üst panel ve sağ alt aynı yayınlanan durumu okur |
| Mutfak baskı performansı | Evet | Evet, izole | Hayır | Köprü HTTP medyan 5.6 ms; canlı Supabase hattı değil |
| Sipariş Gönder performansı | Evet | Kısmi | Hayır | Kayıt bitince arayüz kuyruk/TCP beklemez |
| Adisyon düzenleme | Evet | Evet | Hayır | Mevcut popup duruyor |
| Adisyon ürün silme | Evet | Evet | Hayır | Onay ve ödenmiş kalem koruması duruyor |
| Sunucu fiyat güvenliği | Evet, uygulanmadı | Evet, izole saldırı | Hayır | Satır toplamı, ödeme işareti ve tip değiştirme kapatıldı |
| Web yükleme ekranı | Evet | Evet | Hayır | Sahte menü gizlendi; Flutter web oturumu açılmadı |
| Offline masa snapshot | Önceden vardı | Evet | Hayır | Bu gecede yeni paralel sistem yazılmadı |
| LAN merkezi | Önceden vardı | Evet | Hayır | Canlı 18772 açılmadı |
| SQLite sipariş | Önceden vardı | Evet | Hayır | Mevcut kuyruk testleri geçti |
| Offline senkronizasyon | Kısmi | Evet | Hayır | Ünvan offline mutfak çağrısına bağlandı |
| 57014 | Kısmi | Evet, izole yük | Hayır | 4000 açık satır 1.05 ms; indeks sonrası 0.59 ms |
| Alt yönetici yetkileri | Kısmi | Evet | Hayır | Fiyat yetkisi `viewFinance` ile hizalandı |
| Personel ünvanı | Evet | Evet | Hayır | Fişte `Garson:` karşısına ünvan gider |
| iPhone Profile | Derleme bitti | Derleme geçti | Hayır | İmzası yok, cihaza kurulmadı, PASS yok |
| PP ve diğer hatalar | Hayır | Hayır | Hayır | PP ifadesinin kaynağı bulunamadı |

## Yazıcı

Tek izin `PhysicalPrintGate`. Bilinmeyen veya kapalı izinle `printPhysicalToPrinter`, `printKitchen`, `printReceipt` ve `printJob` bayt göndermez. Kapalıyken oluşan bekleyen işler açılışta otomatik basılmaz. Buluttaki “açık” kaydı, köprüde görülen “kapalı”yı yeniden açmaz.

Üst şerit ve sağ alttaki çip `PhysicalPrintGate.published` etiketini kullanır. Son TCP yoklaması, sonraki sağlık kontrolü yazıcıyı denemese bile korunur. `PRINT_STATION_ENABLED` ana izin sayılmaz.

Fiziksel fiş ve canlı 3001 bu oturumda doğrulanmadı.

## Mutfak gecikmesinin kök nedeni

Sipariş RPC’si bittikten sonra arayüz hâlâ print job okumasını, claim’i ve mükerrer iş ayıklamasını bekliyordu. `releaseUiAfterQueue` ancak bu turlardan sonra dönüyordu. Kalıcı kayıt doğrulanır doğrulanmaz arayüz artık dönüyor. Baskı aynı iz üzerinde, aynı correlation id ile arka planda sürüyor. Kayıt doğrulanmadan başarı dönülmüyor. Belirsiz TCP hâlâ “basıldı” sayılmıyor.

İzole köprü, 10 ayrı mutfak POST’u, yerel TCP alıcısı. Bu Supabase veya fiziksel yazıcı değildir:

| Aşama | medyan | p95 |
|---|---|---|
| Bridge HTTP kabulü, render dahil | 7.373 ms | 13.109 ms |
| TCP yazımı | 0.195 ms | 0.405 ms |

ESC/POS render tek başına medyan 0.132 ms, p95 0.774 ms. Canlı sipariş RPC süresi bu oturumda ölçülmedi.

## Adisyon güvenliği

Mevcut `update_restaurant_table_order` imzası duruyor. Yeni fonksiyon ek imza. Trigger `SECURITY DEFINER` ve `search_path = public`. Audit tablosunda istemciye GRANT yok, RLS açık, politika yok.

İzole saldırılar geçti:

- Garson katalog dışı fiyat yazamadı.
- `line_total` 1 yapılsa da satır toplamı birim fiyat × adete döndü.
- Ödeme işareti silinip ardından fiyat değiştirilemedi.
- Masa siparişinin tipi `delivery` yapılarak kontrol aşılamadı.
- Üyeliği olmayan oturum adet değiştiremedi.
- Katalog dışı eski birim fiyat dururken adet değişti; fiyat 55 kaldı, toplam 110 oldu.
- Yeni satır katalog fiyatıyla eklendi; istemcinin `line_total=1` değeri 120 olarak yeniden hesaplandı.
- Aynı özel fiyat yeni bir satıra kopyalanınca reddedildi.
- `paid_amount` dolu kısmi ödeme adet değişimini kilitledi.
- Ödenmiş kalem, tahsilatın altına düşen silme ve eski revizyon yine reddedildi.

Production’a uygulanmadı.

## 57014 yükü

4000 masa siparişi, yaklaşık 3765 açık satır, 1500 ödeme. Canlı veri değil.

| Sorgu | Plan | Süre |
|---|---|---|
| Açık masa snapshot, önce | Seq Scan | 1.050 ms |
| Aynı sorgu, kısmi indeks sonrası | Index Scan | 0.588 ms |
| Bir masanın ödemeleri | Bitmap Index Scan | 0.027 ms |

Bu boyutta 57014 oluşmuyor. Kısmi indeks production’a yazılmadı; kazanç mutlak olarak küçük.

Bu ölçüm PostgreSQL sorgu planıdır. SQLite masa snapshot’ını, soğuk açılışı ve LAN siparişini doğrulamaz. Soğuk açılış ayrıca denendi: aynı yerel depoya yazılan masa listesini yeni bir servis nesnesi geri okudu. Bu, süreç öldürülüp uygulamanın yeniden açılması değildir.

## Derlemeler

- Web release: `ibul_app/build/web`, 581 saniye, çıktı ince açılış çubuğunu içeriyor. Tarayıcıda hard refresh yapılmadı. Define olarak gerçek anon anahtar kullanılmadı.
- iOS Profile: `flutter build ios --profile --no-codesign` bitti. `build/ios/iphoneos/Runner.app`, 109.5 MB. İmzalanmadı, iPhone’a kurulmadı.
- macOS derlemesi bu turda çalıştırılmadı.

## Adisyon fiyatı

Canlı `update_restaurant_table_order` hâlâ istemcinin `unit_price` değerini yazıyor. Bunu kapatan dosya:

`ibul_app/supabase/migrations/20261112234500_bill_line_price_authority.sql`

Trigger, masa siparişinde katalog fiyatından sapan değişikliği `viewFinance` olmayan kişide reddeder, ödenmiş kalemi kilitler, tahsilatın altına düşen toplamı reddeder, silme ve fiyat değişimini `restaurant_order_line_audit` tablosuna yazar. `update_restaurant_table_order_guarded` eski revizyonla gelen kaydı `40001` ile geri çevirir.

Fiyat değişikliği istemcisi bu fonksiyonu çağırır. Fonksiyon production’da yoksa eski RPC’ye düşmez ve “Sunucu fiyat kontrolü yok. Fiyat değiştirilmedi.” der. Adet değişikliği mevcut RPC’de kalır; migration uygulanınca trigger o yoldaki sahte fiyatı da keser.

İzole test geçti: `ibul_app/supabase/tests/isolated_bill_line_price_authority.sql`

Production’a uygulanmadı.

## Web

Derlenmiş `ibul_app/build/web` 127.0.0.1:8765 üzerinde açıldı. Erişilebilirlik ağacı “Uygulama başlatılamadı” panelini gösterdi ve tıklanabilir kontrol sayısı 0’dı. Sahte menü tıklanabilir değildi. Flutter, yerel statik sunucuda ve geçici define ile tam açılmadı. Bu bir üretim web PASS’i değildir. Önizleme sunucusu kapatıldı.

## Yazıcı kapalı ve canlı süreçler

İzole köprüde `PRINT_SYSTEM_ENABLED` kapalıyken mutfak POST’u HTTP 503 döndü. TCP alıcısına 0 bayt gitti.

Canlı 3001’i `python -m local_print_bridge` dinliyor. 18772 dinlemiyor. Debug satıcı uygulaması ve iki Release `IbulPrintBridge` süreci duruyor. Hiçbiri durdurulmadı.

## iPhone imzası

Proje takımı `B4849QMKTU`, imza stili Automatic, bundle id `com.ibul.app`. Bu makinede o takıma ait sertifika yok. Yüklü geliştirme sertifikası başka bir takıma ait. `~/Library/MobileDevice/Provisioning Profiles` boş. Profile derlemesi bu yüzden `--no-codesign` ile üretildi.

Kullanıcının yapması gereken: Xcode’da `B4849QMKTU` takımına giriş, `com.ibul.app` için otomatik provisioning profilinin indirilmesi, ardından imzalı profile derleme. Cihaza kurulum ayrıca onay ister. Telefonda açılmadı.

## Canlı köprü geçişi

Onaydan önce:

1. Çalışan Debug satıcı uygulamasını ve 3001 sürecini kullanıcı durdurur.
2. `IbulPrintBridge` Release kopyalarının veri dizini yedeklenir.
3. Yeni köprü geçici bir portta `/health` ile açılır. `print_system_enabled` kapalıyken TCP’ye 0 bayt gittiği tekrar görülür.
4. Eski 3001 süreci durdurulur, yeni sürüm 3001’de başlar, `/health` okunur.
5. Geri dönüş: yeni süreç durdurulur, yedeklenen Release köprü yeniden başlatılır.

Bu adımlar uygulanmadı.

## 57014

Canlı tahmini satır sayıları: `table_orders` 10, `table_payments` 1, `orders` 615, `order_items` 2160. Boş satıcı anahtarıyla `EXPLAIN ANALYZE`: yürütme 1.353 ms, plan 20.672 ms. Mevcut `idx_table_orders_seller_status_table` kullanılıyor. Yeni indeks eklenmedi.

Garson masa sorgusu ve ödeme sorgusu canlıda var olan kolonlarla daraltıldı. `57014` yine hata olarak kalır; boş masa diye gösterilmez. Yoğun dağılımın izole ölçümü yukarıdaki “57014 yükü” bölümündedir.

## Personel

Mutfak fişindeki `Garson:` satırı `waiter_title` doluysa ünvanı, değilse kişi adını basar. Offline gönderim de ünvanı taşır. Fiyat düzenleme ekranı sunucuda kayıtlı olmayan `adjustItemPrice` yerine `viewFinance` kullanır. Canlı personel tetikleyicisi `managePrintSettings` ve `manageStaff` içeriyor. “Tam yetki verince hata” bu gece yeni bir kod yolu olarak üretilmedi.

## PP ve iPhone

Kodda PP diye bir hata metni bulunamadı. Bu adla yama yapılmadı.

iOS Profile derlemesi imzasız bitti. Cihaza kurulmadı. Kurulum ayrıca onay ister.

## Değişen dosyalar

- `ibul_app/lib/services/printer_link_status.dart`
- `ibul_app/lib/services/desktop_print_hub.dart`
- `ibul_app/lib/services/desktop_print_orchestrator.dart`
- `ibul_app/lib/services/local_print_service.dart`
- `ibul_app/lib/services/order_print_job_service.dart`
- `ibul_app/lib/screens/seller_panel_page.dart`
- `ibul_app/lib/widgets/desktop_print_status_bar.dart`
- `ibul_app/lib/utils/garson_active_orders_fetch.dart`
- `ibul_app/lib/services/store/store_table_service.dart`
- `ibul_app/lib/services/restaurant_offline/restaurant_offline_order_router.dart`
- `ibul_app/web/index.html`
- `ibul_app/supabase/migrations/20261112234500_bill_line_price_authority.sql`
- `ibul_app/supabase/tests/isolated_bill_line_price_authority.sql`
- `ibul_app/test/services/printer_canonical_status_test.dart`
- `ibul_app/test/desktop_print_orchestrator_test.dart`
- `ibul_app/test/web/web_boot_speed_hints_test.dart`
- `ibul_app/test/printer_setup/windows_pos58_unified_dispatch_test.dart`
- `ibul_app/test/printer_setup/windows_pos58_encoding_profile_test.dart`
- `ibul_app/test/widgets/garson/adisyon_line_edit_test.dart`
- `ibul_app/test/printer_setup/printer_center_ui_summary_test.dart`
- `ibul_app/lib/features/seller/panel/printer_center/widgets/printer_center_health_banner.dart`
- `local_print_bridge/tests/test_kitchen_path_timing.py`
- `ibul_app/supabase/tests/isolated_garson_snapshot_load.sql`

## Test komutları

Geçti:

```bash
cd ibul_app && flutter test \
  test/services/printer_canonical_status_test.dart \
  test/web/web_boot_speed_hints_test.dart \
  test/web/normal_boot_shell_test.dart \
  test/desktop_print_orchestrator_test.dart \
  test/printer_setup/windows_pos58_unified_dispatch_test.dart \
  test/printer_setup/windows_pos58_encoding_profile_test.dart \
  test/widgets/garson/adisyon_line_edit_test.dart \
  test/restaurant_offline/offline_restaurant_mode_test.dart \
  test/services/order_update_and_staff_guards_test.dart
```

82 + 21 test geçti.

```bash
cd ibul_app && flutter analyze --no-fatal-infos --no-fatal-warnings
```

Hata yok. 192 bilgi/uyarı, çoğu önceden var olan test dosyalarında. Çıkış kodu 0.

```bash
python3 -m unittest \
  local_print_bridge.tests.test_kitchen_header_render \
  local_print_bridge.tests.test_kitchen_dispatch_safety
```

6 test geçti.

```bash
psql -h 127.0.0.1 -p 55432 -U ibul_test -d bill_authority \
  -v ON_ERROR_STOP=1 \
  -f ibul_app/supabase/tests/isolated_bill_line_price_authority.sql
```

Geçti. Garson fiyat sahteciliği, ödenmiş kalem, tahsilat altı silme, eski revizyon ve silme audit kaydı doğrulandı.

Sonraki turda ayrıca geçti: fiyat saldırı SQL’i, kapalı yazıcıda 0 bayt testi, offline soğuk okuma ve adisyon widget testleri. Web release ve imzasız iOS Profile derlemesi bitti.

Hâlâ çalıştırılmadı: tüm `flutter test`, `flutter build macos`, imzalı iOS kurulumu, canlı 3001 değişikliği, fiziksel baskı.

## Canlıya geçiş için gereken onay

Fiyat güvenliği production’da ancak şu cümleyle uygulanır:

`Bu migration'ı production'a uygula`

Dosya: `ibul_app/supabase/migrations/20261112234500_bill_line_price_authority.sql`

Etkilenen nesneler: `restaurant_order_line_audit`, `enforce_restaurant_bill_line` trigger’ı, `update_restaurant_table_order_guarded`. Mevcut sipariş RPC’sinin gövdesi değiştirilmez; trigger her masa kalemi yazımını denetler.

Risk: katalogda olmayan veya fiyatı katalogdan sapan masa kalemi, finans yetkisi yoksa reddedilir. Geri alma, trigger’ı ve guarded fonksiyonu düşüren ileri bir migration’dır. Audit tablosu veri silmez.

Ayrıca ayrıca onay: gerçek iPhone kurulumu, canlı 18772, canlı 3001 yeniden başlatma, fiziksel baskı.

## Sonraki işlem

1. Fiyat migration’ını onay cümlesiyle production’a almak.
2. İmzalayıp iPhone’a kurmak. Derleme cihaz PASS’i değildir.
3. macOS derlemesini çalıştırmak.
4. Canlı Supabase gecikmesini ayrıca ölçmek. İzole köprü süresi onun yerine geçmez.
5. Yazıcıyı kapatıp üst şerit, Yazıcı Merkezi, garson ve sağ alt çipin aynı metni gösterdiğini fiziksel fiş çıkmadan doğrulamak.
6. Xcode’da `B4849QMKTU` profilini indirip imzalı iOS Profile üretmek. Kurulum ayrı onaydır.
7. Köprü geçiş planını ancak çalışan 3001 durdurma onayıyla uygulamak.

İnternet kesilince, son 10 dakika içinde köprünün doğruladığı açık izin baskıyı durdurmaz. Doğrulanmamış izin yine kapalı kalır. PP kaynak metni bulunamadı.
