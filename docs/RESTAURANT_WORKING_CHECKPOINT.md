# İBUL Restoran — Çalışan Sürüm Checkpoint'i

Kayıt tarihi: **2026-11-21 ~23:40 (+03)**. Bu belge bir **güvenli geri dönüş noktasıdır**; yeni geliştirme, migration, deploy veya derleme
bu kayıt sırasında yapılmadı. Yalnız okuma, yedekleme ve belge güncellemesi yapıldı.

> Kural: bu belgede **PASS** yalnız gerçek test kanıtı olan maddelere yazılır. Kullanıcının "çalışıyor" demesi kanıt değildir ve ayrı bölümde durur.
> Bu checkpoint sırasında `flutter analyze` / `flutter test` / `pytest` YENİDEN ÇALIŞTIRILMADI; aşağıdaki test sayıları
> `docs/RESTAURANT_PILOT_PROGRESS.md` kayıtlarından alıntıdır (kanıt kaynağı orada).

## 1. Kaydedilen sürüm

| Alan | Değer |
| --- | --- |
| Git dal / worktree | `claude/ibul-restaurant-completion-e60b65` — `/Users/barankananogullari/ibul-work/.claude/worktrees/ibul-restaurant-completion-e60b65` |
| Dalın HEAD'i (checkpoint'in ebeveyni) | `dbdad866767b884a5a894ddf90a6315da01dd2bd` (`feat(staff): owner-only staff accounts, access revocation and LAN credential epoch`) |
| Ana klasör | `/Users/barankananogullari/ibul-work`, dal `backup/ibul-work-uncommitted-20261115`, HEAD `9c39dc6bb42a2b56d4ed0262b4d0e9941f6b517b` |
| Checkpoint dalı / etiketi | `checkpoint/restaurant-working-20261121` / `ibul-restaurant-checkpoint-20261121` (anlık görüntü; "tamamı doğrulandı" anlamına GELMEZ) |
| Çalışma ağacı durumu (kayıt anı) | 151 değişmiş (izlenen) + 105 izlenmeyen yol; hiçbiri commit edilmemişti. Dal, indeks ve çalışma dosyalarına dokunulmadı |
| Ana klasör durumu (kayıt anı) | 137 değişmiş + 110 izlenmeyen yol (commit edilmemiş); yalnız salt okunur yedeklendi |
| Yedek klasörü (repo dışı) | `~/IBUL_checkpoints/20261121-restaurant-working/` (içerik ve doğrulama: bölüm 8) |

Checkpoint commit'i `git commit-tree` ile **geçici bir indeksten** üretildi: izlenen + izlenmeyen kaynaklar (gitignore'a uyarak) tek anlık görüntüde,
çalışma ağacı ve gerçek indeks değişmedi. Anlık görüntüye girmeyenler: `.claude-flow/` otomatik öğrenme dosyaları, `ibul_app/test/screens/failures/*.png`
(test hata görüntüleri), tüm gitignore'lu dosyalar (gizli anahtar/yapılandırma/derleme çıktıları). Anahtar taraması: eşleşen tek şey
`runtime_config_resolution_test.dart` içindeki sahte örnek JWT (`{"sub":"1234567890"}`); gerçek anahtar bulunmadı.

## 2. Gerçek uygulama derlemesi (İBUL Satıcı, macOS Release)

| Alan | Değer |
| --- | --- |
| Paket kimliği | `com.ibul.sellerdesktop` (sürüm 1.0.0, build 1) |
| Konum | `~/IBUL_isolated_build/flutter-build/macos/Build/Products/Release/IbulSellerDesktop.app` |
| Derleme zamanı | çerçeveler 23:09, ana çalıştırılabilir (yeniden mühür) 23:24:47 |
| İmza | `codesign --verify --deep --strict` OK; Apple Development (kişisel geliştirici sertifikası), takım `B4849QMKTU`, App Sandbox AÇIK, universal (arm64 + x86_64). **Developer ID / noter onayı YOK** (dağıtım imzası değil) |
| SHA-256 ana ikili | `e07f660252cc8b9f053a9fd88e24ab7444e4ace11c69785cb448f2da35f74d1a` |
| SHA-256 köprü yardımcısı | `39469246830eb207870ba4acdb98cbfe2e71905ae5cfa69305680c05ec7fa293` (`Contents/Resources/PrintBridge/IbulPrintBridge`) |
| Kaynak ↔ derleme eşleşmesi | Derlemeden SONRA değişen kayıtlı dosyalar yalnız `20261122090000_print_settings_staff_permission.sql` ve `docs/RESTAURANT_PILOT_PROGRESS.md`; yani derleme bu anlık görüntünün kodudur. Köprü `/health`: `bridge_version=dev`, `git_commit` boş (sürüm damgası yok) |
| Kayıt anındaki çalışma durumu | Uygulama (PID 78003) + paket içi köprü yardımcısı (PID 78115) çalışıyor, `127.0.0.1:3001` dinliyor, `/health ok:true`. Bu durum **değiştirilmedi** |
| Yazıcı köprüsü başlatma yöntemi | Uygulamanın paket içi imzalı yardımcısı (sandbox inherit), Yazıcı Servisi → Başlat ile; `SMAppService` sandbox'ta reddedildiği için kullanılmıyor |
| Derleme kopyalanmadı | Disk %98 dolu (9,3 GiB boş); derleme klasörü çoğaltılmadı. Yeniden üretim: bölüm 7 |

Diğer derlemeler (hepsi **test**, gerçek uygulama değil): `IbulSellerDesktopTest` `com.ibul.sellerdesktop.debuglocal` / `…realtest`
(`Debug-Offlinetest`, izole veya yazdırma KAPALI), iOS simülatör garson derlemesi.

## 3. Doğrulama durumu (kanıt düzeyiyle)

Düzey: **G** = gerçek uygulama (`com.ibul.sellerdesktop` Release) · **T** = test/izole derleme ekranı · **B** = birim/sunucu/SQL testi ·
**K** = yalnız kod okuma · **—** = kanıt yok.

### 3a. PASS (kanıtlı)

| Özellik | Düzey | Kanıt |
| --- | --- | --- |
| Yazıcı Servisi Başlat → tek köprü 3001, /health ok | **G** | Progress "P0" tablosu; checkpoint anında köprü canlı (PID 78115, `/health ok`) |
| Durdur → süreç + port kapanır; yeniden Başlat → tek yeni süreç | **G** | Progress "P0" |
| Uygulamadan çıkış köprüyü kapatır; açılışta servis kapalı | **G** | Progress "P0" |
| Başlat sonrası rozet bayatlığı düzeltildi | **G** | Progress "P1": 9 sn sonra "Yazıcı doğrulanmadı" |
| Otomatik Tara gerçek yazıcıyı bulur (192.168.10.100:9100) | **G** (tek gözlem) + köprü 3/3 | Progress "P1" + devam 15 |
| Eşleştirme salt-okunur görünüm, çelişki yok | **G** | Progress "P1" |
| Kullanıcı onaylı 1 mutfak TEST fişi: köprü `completed`, 854 bayt | **G** köprü kaydı | **Kâğıt çıktısı kullanıcı teyidi BEKLİYOR** (TCP yazımı kâğıt kanıtı değildir) |
| Sahip normal girişi (production, yazdırma KAPALI) | **T** (`…realtest`) | Progress devam 16 |
| Pasif alt yönetici girişte "Hesabınız pasif" kartı | **T** (`…realtest`) | Progress devam 16 |
| Personel oluştur → garson normal girişi, zorunlu şifre ekranı yok | **T** (iOS sim + izole DB) | Progress devam 5 |
| Garson siparişi → tek `print_jobs` → sahte yazıcıya tek fiş (28→33 serisi), tekrar yok | **T** (izole macOS merkez + sim) | Progress devam 10–13 |
| Çevrimdışı sipariş → kalıcı → bulut dönünce tek senkron, mükerrer yok, tek fiş | **T** (izole) | Progress devam 12 (11 ayrı `local_order_id`) |
| LAN kodla eşleştirme, LAN siparişi merkeze ulaşır | **T** (sim) | Progress devam 7 |
| İzin kaldırılınca açık oturumda işlem reddi | **T** | Progress devam 5 (#13) |
| Personel şifre/erişim iptali sunucu sözleşmesi | **B** (izole gerçek GoTrue+PG) | `staff_owner_only_password_test.mjs` 94/94, `staff_edge_function_http_test.mjs` 33/33 (geliştirici + QA bağımsız) |
| Flutter personel kuralları, yazıcı hazır olma, LAN ambiguity vb. | **B** | Birim testleri (progress'te sayılar; bu checkpoint'te yeniden koşulmadı) |

### 3b. FAIL / BLOCKED / DOĞRULANMADI

| Özellik | Etiket | Not |
| --- | --- | --- |
| **Alt yönetici `managePrintSettings` ile yazıcı ekleme / eşleştirme (SUNUCU)** | **FAIL — BLOCKED (onay)** | Production RLS yalnız sahibe yazma izni veriyor; bölüm 5 |
| `restaurant_print_station_configs` izin hizalaması (servis ayarı yanlışlıkla `manageOrders/viewOrders`'a bağlı) | **FAIL — BLOCKED (onay)** | Aynı migration; bölüm 5 |
| `20261121090000` + `20261121100000` (personel şifre/iptal) production'da | **UYGULANMADI** | Üretim sunucu kapısı yok; yalnız izole/yerel kanıt |
| Gerçek uygulamada Yazıcı Merkezi tam akışı (Tara→Ekle→Eşle→Sipariş→Tek fiş→Durdur) | **BLOCKED** | Gerçek uygulama ekranı otomasyona kapalı; kısmi P0/P1 yukarıda |
| Gerçek uygulamadan yazıcı **Kaydet** (arayüz) | **TEST EDİLMEDİ** | Kaydet'e basılmadı (gerçek kaydı değiştirir); çift kayıt koruması kodlandı, ekranda doğrulanmadı |
| Gerçek alt yönetici (aktif) izin/masa ekranı testi | **BLOCKED** | Hesap pasif; aktifleştirme onayı yok |
| Gerçek iPhone → Mac LAN merkezi → Yazıcı (P3) | **TEST EDİLMEDİ** | Yalnız simülatörde; Bonjour otomatik bulma simülatörde **FAIL** (kök neden bilinmiyor), kodla eşleştirme PASS |
| İnternetsiz sipariş (gerçek uygulama, gerçek WAN kesme) (P4) | **BLOCKED** | Yalnız izole yığında yönlendirici kapatılarak; gerçek WAN kesme onayı yok |
| 12 saatlik çevrimdışı LAN mührü anında iptal | **FAIL / AÇIK RİSK** | Kabul edilmiş sınır; "anında iptal" PASS DEĞİL |
| Aktif personel sunucu iptali — hosted Supabase auth tetikleyici/izin | **DOĞRULANMADI** | Production BLOCKED (Opus incelemeleri) |
| Fiziksel kâğıt çıktısı doğrulaması | **BEKLİYOR** | Kullanıcı teyidi |

### 3c. Kullanıcının "çalışıyor" dediği, ayrıca kanıtı olmayanlar

Bu checkpoint isteğinde kullanıcı "önemli ilerleme" bildirdi. Kullanıcı beyanı bu belgede **kanıt sayılmadı**; yukarıdaki PASS'ler yalnız kayıtlı
ekran/günlük/test çıktısına dayanır. Beyana dayalı ama bu belgede kanıtı bulunmayan her madde 3b'de "doğrulanmadı" kalır.

## 4. Bilinen açık hatalar (özet; ayrıntı progress ve PROJECT_MAP §7)

1. **P2 (production, BLOCKED):** bölüm 5.
2. Çevrimdışı 12 sa LAN mührü iptal gecikmesi (kabul edilmiş risk).
3. `claimed` baskı işi için lease/zaman aşımı yok (uygulama gönderimden önce kapanırsa iş görünmez kalır).
4. `desktop_print_hub._warmPrinterConfigCache` `printers.seller_id` sorguluyor (sütun `restaurant_id`); sessizce başarısız.
5. `order_print_job_service.dart` içinde bölgesiz yerel saat yazımı (3624/3640/3690/3769) düzeltilmedi.
6. Garson masasında aynı sipariş iki satır görünebilir (yerel+bulut birleşmiyor); incelenmedi.
7. Çevrimdışı soğuk açılışta merkez masaları "Boş Masa" gösterebilir; incelenmedi.
8. Garson uygulaması canlı köprü portu `127.0.0.1:3001`'i yokluyor (yalnız GET).
9. Köprü kapalıyken iş `last_error` metni yanıltıcı ("Bu rol için yazıcı seçilmemiş").
10. `local_print_bridge/tests/test_device_platform.py` `print_station.reported_device_platform` içe aktaramıyor.
11. Alt yönetici hesabı için bayraksız eski personel backfill'i ve hosted Supabase tetikleyici izinleri doğrulanmadı.
12. Gerçek uygulamada "1 yerel sipariş senkron bekliyor" mesajı incelenmedi.
13. Bonjour otomatik bulma simülatörde başarısız; gerçek iPhone'da denenmedi.
14. Doğrulanmamış davranış değişikliği: kalemler artık ürünün istasyonunu taşıyor → fiş hedefleri çok istasyonlu gerçek işletmede değişebilir (gerçek cihazda doğrulanmadı).
15. Bilinen önceden başarısız testler (PROJECT_MAP §7 madde 12) hâlâ geçerli.

## 5. P2 — AÇIK BLOKAJ: `20261122090000_print_settings_staff_permission.sql`

- Dosya: `ibul_app/supabase/migrations/20261122090000_print_settings_staff_permission.sql` (kaynakta var, **production'a UYGULANMADI**).
- Önceki iki uygulama isteği **declined** edildi. İzin mekanizması başka araçla, doğrudan SQL ile veya dolaylı yoldan **aşılmadı** ve aşılmayacak.
- Production'daki etki: `managePrintSettings` bulunan alt yönetici yazıcı ekleme ve eşleştirmede sunucudan 42501 alıyor; servis ayarı yazma izni
  `manageOrders`/`viewOrders` ile yanlış ilişkili (yalnız sipariş görenler yazabiliyor, `managePrintSettings` olanlar yazamıyor).
- Durum: **ÇÖZÜLMEDİ.** Yetkili onay ve erişim sağlanana kadar açık blokaj. Çözüldü diye işaretlenmeyecek.
- Uygulama sonrası zorunlu: salt-okunur `pg_policies` yeniden kontrolü + gerçek alt yönetici hesabıyla ekran testi + geri alma planı.

## 6. Değiştirilen önemli dosyalar (özet)

Tam liste ve diff: yedek klasörünün `manifest/` dosyaları (bölüm 8). Gruplar:

- **Yazıcı/köprü:** `ibul_app/lib/services/desktop_print_hub.dart`, `print_agent_*.dart`, `bridge_manager.dart`, `bridge_lifecycle_service.dart`, `printer_readiness.dart`,
  `print_service_start_gate.dart`, `print_job_payload_identity.dart`, `local_print_service.dart`, `local_print_bridge/network_scan.py`, `server.py`, `kitchen_print_management_page.dart`, `printer_ethernet_dialog.dart`.
- **Personel/yetki:** `staff_login_policy.dart`, `seller_login_page.dart`, `seller_panel_page.dart`, `auth_service.dart`, `store_service.dart`,
  `supabase/functions/manage-restaurant-staff/index.ts`, migration'lar `20261121090000`, `20261121100000`, `20261122090000` (+ rollback'ler, testler).
- **LAN/çevrimdışı:** `ibul_app/lib/services/restaurant_offline/*` (yeni: `lan_advertiser`, `lan_authority_seal`, `offline_identity_seal`, `seller_lan_center`, `waiter_lan_link`, …).
- **Yapılandırma/derleme:** `runtime_config.dart`, `macos/`, `android/app/src/main/AndroidManifest.xml`, `scripts/`.
- **Testler:** ~70 yeni test dosyası (`ibul_app/test/**`, `supabase/tests/**`).
- **Belgeler:** `CLAUDE.md`, `PROJECT_MAP.md`, `docs/RESTAURANT_PILOT_PROGRESS.md`, bu dosya, `docs/PILOT_REAL_DEVICE_LAN_TEST_PLAN.md`.

## 7. Güvenli geri dönüş talimatları (ŞU AN ÇALIŞTIRMA)

**Hiçbir adım mevcut dosyaların üzerine yazmaz; her zaman yeni bir klasör/dala geri yükle, sonra karşılaştır.**

Seçenek A — kaynak, git'ten (en hızlı, yedek gerekmez):

```bash
cd /Users/barankananogullari/ibul-work
git worktree add ../ibul-restore-20261121 checkpoint/restaurant-working-20261121   # yeni klasör, mevcut işe dokunmaz
```

Seçenek B — repo bozulursa, repo dışı yedekten:

```bash
mkdir -p ~/ibul-restore && cd ~/ibul-restore
git clone ~/IBUL_checkpoints/20261121-restaurant-working/ibul-checkpoint.bundle ibul
cd ibul && git checkout checkpoint/restaurant-working-20261121
```

Seçenek C — dalı değiştirmeden dosya geri alma: `git show checkpoint/restaurant-working-20261121:<yol> > /geçici/<dosya>` ve elle karşılaştır.

Checkpoint'te OLMAYAN ve elle geri konması gerekenler (gizli/gitignore'lu; yedeğe KOYULMADI):
`ibul_app/ios/Runner/GoogleService-Info.plist` (ana klasörden kopyala), üretilmiş Supabase yapılandırması (`generated_runtime_config.g.dart`, yerel `.env`'ler),
Keychain kayıtları, imza sertifikası (Apple Development, takım `B4849QMKTU`), `~/IBUL_isolated_build/` altındaki derleme betikleri ve DerivedData.

Gerçek Release uygulamasını yeniden üretmek (kaynak geri yüklendikten sonra): `~/IBUL_isolated_build/` altındaki Release derleme betiği +
`embed_print_bridge_macos.sh`; sonuç ikilisini bölüm 2 SHA-256 değerleriyle karşılaştır (imza/zaman damgası farkı hash'i değiştirir; birebir
eşleşme beklenmemeli, `codesign --verify --deep --strict` ve `/health` ile doğrula).

Doğrulama (geri yükleme provası, yazmadan): bölüm 8'deki "probe" adımları — bundle klonlanıp `git fsck`, dosya sayısı ve SHA-256 manifesti
karşılaştırılarak yapıldı; gerçek geri yükleme çalıştırılmadı.

Veritabanı geri dönüşü bu checkpoint'in kapsamı DEĞİL; production'a hiçbir şey uygulanmadı. İzole migration'ların geri alma dosyaları
`ibul_app/supabase/rollbacks/` altında.

## 8. Yedek içeriği (repo dışı)

`~/IBUL_checkpoints/20261121-restaurant-working/`:

- `ibul-checkpoint.bundle` — checkpoint dalı + etiket + ebeveyn geçmişi (tam repo geri yüklemesi).
- `worktree/tracked.patch` (`git diff HEAD --binary`) + `worktree/untracked.tar.gz` (izlenmeyen, gitignore dışı, gürültüsüz) + `worktree/status.txt`.
- `main-folder/tracked.patch`, `untracked.tar.gz`, `status.txt` — ana klasörün commit edilmemiş işi (salt okunur alındı, ana klasöre yazılmadı).
- `manifest/` — HEAD'ler, `git worktree list`, dosya listeleri, SHA-256 özetleri, gerçek uygulama imza/özet kaydı.
- Gizli anahtar, şifre, production oturumu, `.env`, GoogleService plist, Keychain, derleme klasörleri YOK.

## 9. Bundan sonra izlenecek geliştirme sırası

Ana test ortamı: **gerçek İBUL Satıcı uygulaması** (`com.ibul.sellerdesktop` Release).

1. **P0** — Gerçek uygulamada Yazıcı Servisi Başlat/Durdur/yeniden Başlat/çıkış döngüsünü ekran + süreç + port kanıtıyla yeniden kesinleştir (rozet bayatlığı dahil).
2. **P1** — Gerçek yazıcı tarama, eşleştirme ve kontrollü TEST fişi; kâğıt çıktısı kullanıcı teyidi; arayüzden Kaydet (onayla).
3. **P2** — Alt yönetici sunucu yetkileri: **yetkili onay gelene kadar BLOCKED**; onaydan sonra bölüm 5 adımları.
4. **P3** — iPhone → Mac LAN merkezi → Yazıcı (gerçek cihazlar, gerçek Bonjour).
5. **P4** — İnternetsiz sipariş ve mükerrersiz senkronizasyon (gerçek WAN kesme onayıyla).
6. **P5** — Kullanılabilirlik, performans, regresyon (`flutter analyze && flutter test`, `local_print_bridge` pytest, ön bilinen hata listesi).
