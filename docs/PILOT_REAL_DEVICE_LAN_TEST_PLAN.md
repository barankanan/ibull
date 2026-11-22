# Gerçek iPhone/Android garson cihazı: LAN test planı

Amaç: pilot öncesi telefon/tabletin yerel merkezle eşleşmesini, TLS'yi, izinleri,
siparişi ve bağlantı kesintisini gerçek cihazda güvenle denemek. Bu plan
**uygulanmadı**; cihaz ve ağ erişimi gerektirir.

## 0. Önkoşullar (hepsi sağlanmadan başlanmaz)
- Production'da üç migration ve `verify-lan-print-evidence` kuruldu (bkz. PROJECT_MAP §7 madde 24). Migration yoksa merkez personel kabul etmez (bilinçli).
- Merkez: macOS, Wi-Fi/Ethernet ile aynı alt ağda, uygulama açık, LAN merkezi "çalışıyor", Bonjour yayını görünür (`dns-sd -B _ibul-lan._tcp` başka bir Mac'ten).
- Test personeli: aktif üyelik, `manageOrders`, şifresi **değiştirilmiş** (geçici şifre değil), şube merkezle aynı. İkinci hesap: `viewOrders`-only (yetkisiz kontrol). Üçüncü: geçici şifreli (reddedilmeli).
- Baskı: yalnızca test yazıcısı veya sahte yazıcı; gerçek mutfak yazıcısı ve gerçek WAN pilot sırasında operatör kararıyla.
- Cihazlar: 1 iPhone (iOS 16+), 1 Android (12+), mümkünse biri misafir ağında (izolasyon testi için).
- Bilinen boşluklar (önce kapatılmalı veya kabul edilmeli):
  1. ~~iOS `Info.plist` yerel ağ anahtarları yok~~ — GEÇERSİZ (2026-11-22): satıcı/garson iPhone projesi depo kökündeki `/ios`'tur ve `NSLocalNetworkUsageDescription`, `NSBonjourServices=[_ibul-lan._tcp]` ile `com.ibul.app/lan_center` (NWBrowser) kanalını içerir. `ibul_app/ios` müşteri uygulamasıdır.
  2. Mobilde Bonjour tarama paketi yok (`dns-sd` yalnız macOS). "Merkezi ara" mobilde sonuç vermeyebilir; eşleşme adres + parmak izi + kod elle girişiyle yapılır.
  3. Garson sayfası "Personel kimliği" olarak Auth kullanıcı kimliğini (uuid) ister.

## 1. Eşleştirme
| # | Adım | Beklenen | Kanıt |
|---|---|---|---|
| 1.1 | Operatör eşleştirme kodu üretir (2 dk geçerli) | Kod ve sunucu parmak izi görünür | Ekran görüntüsü |
| 1.2 | Telefonda adres (`https://<ip>:18783`), parmak izi, personel kimliği, kod girilir | Eşleşir, sertifika cihazda saklanır | Merkez cihaz sayısı 1 |
| 1.3 | Yanlış kod 5 kez | 30 sn kilit, eşleşme yok | 429 |
| 1.4 | Aynı kodu ikinci cihazda tekrar | Reddedilir (tek kullanımlık) | 401 |
| 1.5 | `viewOrders`-only personel | Eşleşme reddedilir (403) | Hata metni |
| 1.6 | Geçici şifreli personel | Eşleşme reddedilir (403, "geçici şifresini değiştirmeden") | Hata metni |
| 1.7 | Başka şubenin personeli | Reddedilir | Hata metni |

## 2. TLS
- 2.1 Yanlış parmak izi girilirse bağlantı kurulmaz ("sertifika doğrulanamadı").
- 2.2 Düz `http://` adresi çalışmaz.
- 2.3 Merkez IP'si değişince (DHCP) sertifika yeniden düzenlenir; telefon yeniden eşleşmelidir (parmak izi değişir). Beklenen: eski eşleşme reddedilir, yeni eşleşme çalışır.
- 2.4 Operatör cihazı iptal eder: sonraki istek 401, yeniden aktifleştirme yok (yeniden eşleşme gerekir).

## 3. İzinler ve kapsam
- 3.1 Şubeye bağlı personel yalnız kendi şubesinin aktif masalarını görür; başka şube masasına sipariş 403.
- 3.2 Personel bulut panelinden pasife alınır: bir sonraki istek 401 ("aktif değil").
- 3.3 `manageOrders` kaldırılır: sonraki sipariş reddedilir.
- 3.4 Personel kimliği başkasınınkiyle değiştirilerek gönderilirse 401.

## 4. Sipariş (internet açık)
- 4.1 Masa/ürün listesi gelir (fiyatlar yerel katalogla eşleşir).
- 4.2 Sipariş kaydedilir; aynı `local_order_id` tekrar gönderilirse tekrar fiş basılmaz, çift sipariş oluşmaz.
- 4.3 Ağır tekrar: aynı siparişi ağ kopukken ve sonra yeniden gönder; bulutta tek satır.

## 5. Bağlantı kesintisi (gerçek WAN'ı yalnız operatör keser)
Önerilen güvenli yöntem: yönlendiricinin WAN/uplink'ini yönlendirici arayüzünden kapatmak (kablo çekmeden); Wi-Fi açık kalır.
- 5.1 Kesintiden önce 4.1–4.2 yapılmış olmalı (yetki o sırada mühürlenir).
- 5.2 Kesinti sırasında yetkili garson sipariş gönderir: kaydedilir, fiş merkez bilgisayarın köprüsüne gider, `print_status=forwarded` (köprü açıksa) veya `failed` (köprü kapalıysa; bulutta basılır).
- 5.3 Kesintide **hiç doğrulanmamış** (kesinti sırasında yeni eşleşmiş) cihaz: sipariş reddedilir.
- 5.4 Kesinti 12 saati geçerse yetki sona erer (denemek için saat ilerletilmez; yalnız beklenen davranış kaydı).
- 5.5 Merkez uygulaması kapatılıp açılır (kesinti sürerken): merkez KAPALI açılır (2026-11-19 kararı), bekleyen siparişler kuyrukta durur, hiçbir fiş kendiliğinden basılmaz. Operatör Sistem → Yazıcı Merkezi → Başlat der; önceki oturumun fişleri basılmaz, yalnız yeni siparişler basılır.
- 5.6 Telefon Wi-Fi'ı kapatıp açar / merkez Wi-Fi'ı kesilir: telefon "ana bilgisayara ulaşılamıyor" gösterir, sipariş sessizce kaybolmaz.
- 5.7 İnternet dönünce: bekleyen siparişler **bir kez** aktarılır; baskı kanıtı doğrulanır; iş `paused_by_operator` (yerel basılmış) kalır; yeniden basılmaz.

## 6. Cihaza özel
- iOS: ilk bağlantıda "yerel ağ" izin istemi çıkmalı; reddedilirse anlamlı hata. Uygulama arka plana alınınca ve ön plana dönünce bağlantı yeniden kurulmalı.
- Android: Wi-Fi güç tasarrufu/Doze sonrası bağlantı; misafir ağ izolasyonunda anlamlı hata; `CHANGE_WIFI_MULTICAST_STATE` mevcut.
- Her iki cihazda: bağlantı kesildiğinde tekrar eden sıra numarası (`seq`) hatası görülmemeli; uygulama yeniden başlatılınca eşleşme ve sertifika korunmalı.

## 7. Başarı / iptal ölçütleri
Başarı: 1–5 tablosundaki tüm "beklenen"ler gerçekleşir; çift sipariş/çift fiş 0; yetkisiz sipariş 0.
Durdur: bir yetkisiz siparişin kabulü, bir çift fiş, kaybolan sipariş, veya sunucuda beklenmeyen hata. Pilot durdurulur, `paused_by_operator` ve yerel kuyruk dışa alınır.

## 8. Toplanacak kanıtlar
Merkez günlüğü (`[OfflineLifecycle]`, `[SellerLanCenter]`), cihaz ekran görüntüleri, bulutta `orders`/`print_jobs`/`restaurant_lan_print_evidence_events` sayıları (önce/sonra), yazıcı fiş sayısı.

## 9. macOS ana bilgisayar + gerçek telefon: adım adım (2026-11-20)

Fiziksel teste başlamadan kullanıcı onayı gerekir; gerçek yazıcı ve gerçek WAN kesintisi yalnız operatör eliyle.

1. MacBook ve telefon aynı Wi-Fi ağında olmalı; ağda "istemci yalıtımı / AP isolation" kapalı olmalı. MacBook'un adresi Sistem Ayarları → Wi-Fi → Ayrıntılar'dan okunur (ör. 192.168.x.x).
2. MacBook'ta İBUL Satıcı açılır, restoran sahibi (veya yazıcı ayarı yetkili personel) giriş yapar. Açılışta merkez kapalıdır; turuncu şerit "Yazıcı merkezi kapalı" der.
3. Sistem → Yazıcı Ayarları → Yazıcı Merkezi sekmesinde "Yazıcı Servisi" anahtarı açılır (Başlat). macOS ilk seferde "gelen bağlantılara izin ver" ve (paketli sürümde) Oturum Açma Öğeleri onayı sorabilir: ikisi de kullanıcı eylemidir.
4. Sistem → Yerel operasyon → "Eşleştirme kodu üret": kod 2 dakika geçerli ve tek kullanımlıktır.
5. Telefonda garson uygulaması açılır: iOS ilk açılışta "Yerel Ağ" iznini sorar (izin verilmezse merkez bulunamaz). Merkez adresi (adım 1) ve port (18772), personel kimliği ve eşleştirme kodu girilir.
6. Masa seçilir → ürün eklenir → Siparişi Gönder. Beklenen: telefonda "kaydedildi", mutfak yazıcısından TEK fiş. Aynı sipariş yeniden gönderilirse ikinci fiş çıkmaz.
7. İnternet kesintisi denemesi (operatör modemin WAN kablosunu çeker, Wi-Fi açık kalır): adım 6 tekrarlanır; sipariş yine kaydedilir ve tek fiş çıkar. İnternet dönünce sipariş buluta bir kez gider.
8. Yazıcı Servisi anahtarı kapatılır (Durdur): telefondan sipariş "merkez kapalı" yanıtı alır, sipariş telefonda bekler.

Bilinen sınırlar: LAN siparişinin fişi köprünün kendi yapılandırılmış mutfak yazıcısına gider (istasyon başına yazıcı seçimi bu yolda yok). Android'de test APK'sı `lib/main_waiter_lan.dart` girişini kullanır ve Supabase oturumu açmaz; personel kimliği elle girilir.


## 10. İnternetsiz modem gerçek LAN testi — prosedür ve beklenen sonuçlar (2026-11-22)

Bu bölüm güncel prosedürdür; üstteki bölümlerle çelişirse bu bölüm geçerlidir (üretim portu **18772**; eşleştirme Bonjour + cihaz onayı ile, elle adres yalnız yedek).
Hiçbir adım gerçek müşteri masasına/adisyonuna dokunmaz: yalnız TEST masası (masa 27) ve işletmenin kendi test ürünü kullanılır. Fiziksel baskı yalnız kullanıcı onayıyla, en fazla 1 TEST fişi.

### 10.0 Ön koşullar (hazırlık aşamasında sağlananlar ayrıca `docs/RESTAURANT_PILOT_PROGRESS.md` son bölümünde)
| # | Koşul | Nasıl doğrulanır |
|---|---|---|
| P1 | Mac ve iPhone AYNI modem Wi-Fi'sinde (iPhone hotspot DEĞİL), iPhone mobil veri KAPALI | Mac: `ipconfig getifaddr en0` → `192.168.10.x`; iPhone Ayarlar → Wi-Fi |
| P2 | Yazıcı erişilebilir | Mac: `nc -zv -G 3 192.168.10.100 9100` → succeeded |
| P3 | Mac'te güncel İBUL Satıcı (bu hazırlığın derlemesi) açık, sahip oturumu açık | Uygulama → Sistem |
| P4 | İnternet VARKEN en az bir kez: Mac'te Garson ve Sistem → Yazıcı Ayarları açıldı (ürün/masa/istasyon/yazıcı önbelleği doldu), iPhone'da personel normal Satıcı girişinden oturum açtı ve Garson sayfasını açtı (katalog + yetki mührü) | Genel Bakış çevrimdışı kartında "Bulutla senkronize" zamanı dolu |
| P5 | Yazıcı kayıtlı ve mutfak istasyonuna eşleşmiş (ya da Mutfak rolü atanmış) | Sistem → Yazıcı Ayarları → Eşleştirme |

### 10.1 Adımlar (A–G: sipariş YOK)
| Adım | İşlem | Beklenen sonuç | Kanıt |
|---|---|---|---|
| A | P1 komutları | Mac `192.168.10.x`; iPhone aynı alt ağ | Komut çıktısı |
| B | Mac: Sistem → Yazıcı Merkezi → Başlat. Başka terminal: `dns-sd -B _ibul-lan._tcp` | "IBUL Merkez" yayını görünür; iPhone Garson/Sistem'de merkez otomatik bulunur (iOS ilk seferde "Yerel Ağ" izni sorar → İzin Ver) | Ekran görüntüsü |
| C | İlk kez: iPhone "Eşleş" → Mac'te onay penceresi, iki tarafta AYNI eşleşme kodu → Onayla. Daha önce eşleşmişse: hiçbir şey yapılmaz | İlk kez: eşleşir. Sonraki açılışlarda QR/kod istenmeden "Ana bilgisayara bağlı" | Mac cihaz listesi 1 |
| D | iPhone'da `manageOrders` yetkili personel; ikinci deneme `viewOrders`-only hesap | Yetkili: masalar/ürünler gelir. Yetkisiz: eşleşme/sipariş reddedilir (403), güvenlik kapısı aşılmaz | Hata metni |
| E | Mac: P2 komutu; Sistem → Yazıcı Ayarları rozeti | TCP açık; rozet "hazır/doğrulandı". **Baskı gönderilmez** | Komut çıktısı |
| F | Modemin WAN'ı kesik (ya da operatör keser; Wi-Fi AÇIK kalır). Mac ve iPhone'da Genel Bakış, Garson, Sistem açılır | Üçü de açılır. Genel Bakış: masalar, yerel siparişler, senkron bekleyen; tahsil edilmiş gelir GÖSTERİLMEZ. iPhone Sistem: "Ana bilgisayar · Yazıcı Merkezi" kartı Mac'teki GERÇEK durumu gösterir (telefonun kendi baskı servisi kapalı olsa da "merkez kapalı" yazmaz) | Ekran görüntüleri |
| G | Diğer menü girdilerine (Ürünler, Finans, Siparişler …) dokun; derin bağlantı dene | Bulanık iskelet + "İnternet bağlantısı gerektirir"; etkileşim yok; izinli ilk çevrimdışı sayfaya döner | Ekran görüntüsü |

### 10.2 Sipariş aşaması (yalnız A–G PASS ise; TEST masası 27)
| Adım | İşlem | Beklenen sonuç |
|---|---|---|
| H | WAN kesikken iPhone: masa 27 → 1 test ürünü → Siparişi Gönder (fiziksel baskı için ÖNCE kullanıcı onayı) | iPhone "kaydedildi"; Mac yerel günlüğünde 1 kayıt; fiş, ürünün istasyonuna KAYITLI yazıcıya gider (köprü kaydında `target_host=192.168.10.100`), TEK fiş. İstasyonun yazıcısı yoksa: sipariş yine kaydedilir, fiş "gönderilmedi" (yanlış yazıcıya basılmaz) |
| I | Aynı siparişi yeniden gönder (çift dokunuş / zaman aşımı sonrası) | İkinci kayıt YOK, ikinci fiş YOK (`duplicate:true`) |
| J | iPhone ve Mac uygulamasını kapat-aç (WAN hâlâ kesik) | Sipariş iki tarafta da duruyor; Mac merkezi KAPALI açılır, operatör Başlat der; eski fiş kendiliğinden yeniden basılmaz |
| K | İnternet geri gelir | Otomatik senkron: bulutta TEK sipariş (`local_order_id` tekil), baskı işi `paused_by_operator` (yerelde basıldı; yeniden basılmaz); Genel Bakış ve Garson güncellenir; "senkron bekleyen" 0 |
| L | Bulut sayımları (salt-okunur): `orders`, `print_jobs`, `restaurant_lan_print_evidence_events` önce/sonra | +1 sipariş, +1 kanıt olayı, yeni fiziksel baskı 0 |
| M | Sahip, personelin `manageOrders` iznini kaldırır / pasife alır | Sonraki LAN isteği reddedilir; cihaz otomatik kabul edilmez |
| N | Test kaydının temizliği | Yalnız kullanıcı onayıyla, yalnız masa 27'deki TEST siparişi iptal edilir; başka kayda dokunulmaz |

### 10.3 Durdurma ölçütleri
Yetkisiz bir siparişin kabulü, çift sipariş, çift fiş, kaybolan sipariş, yanlış yazıcıya giden fiş veya gerçek müşteri masasında değişiklik → test hemen durur; yerel kuyruk ve köprü kaydı dışa alınır.

### 10.4 Rapor biçimi
Her satır PASS / FAIL / BLOCKED: gerçek iPhone LAN keşfi · güvenli cihaz eşleştirme · otomatik yeniden bağlantı · alt yönetici yetkisi · yazıcı bağlantısı · internetsiz üç sayfa · yerel sipariş kaydı · tek fiziksel baskı · internet dönüşünde senkronizasyon · mükerrer sipariş/fiş kontrolü. Kanıtsız madde PASS yazılmaz.
