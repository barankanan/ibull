# İBUL Restoran Pilot — İlerleme Kaydı

## 2026-11-21 (00:10 otomatik çalışma) — YALNIZ DENETİM, KOD DEĞİŞMEDİ

### Durum
- Bu dosya ilk kez oluşturuldu (önceki kayıt yoktu).
- Disk: 6.8 GiB boş (ağır Flutter/Xcode derlemesi öncesi dar; yeni derleme başlatılmadı).
- Yerel Supabase konteynerleri (`ibul-local-staging`) çalışıyor. Başka bir Claude oturumu
  `.claude/worktrees/ibul-restaurant-completion-e60b65` çalışma ağacında iOS simülatörüne
  bağlı süreçler bırakmış (Dart VM service 58280, attach betikleri). Çakışmamak için simülatör,
  macOS uygulaması ve yerel DB'ye dokunulmadı.
- Çalışma ağacında 241 commit edilmemiş değişiklik var; korundu.

### Aşama 1 — Personel şifre politikası: MEVCUT KOD İSTENEN POLİTİKANIN TERSİNİ YAPIYOR (FAIL, kod bekliyor)
Kod incelemesi (çalıştırılmadı, yalnız okuma):
| Bulgu | Yer | İstenen |
|---|---|---|
| Personel oluşturma ve `set_temporary_password` `must_change_password: true` yazıyor | `ibul_app/supabase/functions/manage-restaurant-staff/index.ts` (~satır 247-277, 424-430) | İlk girişte zorunlu değişim OLMAYACAK |
| Personelin kendi şifresini değiştirdiği `change_staff_password` işlemi var | aynı dosya ~131-147; `staff_password_change_dialog.dart`; `store_service.dart` `changeStaffTemporaryPassword` | Personel kendi şifresini değiştiremeyecek |
| `staff_must_change_password()` bayrak varsa tüm izinleri reddediyor | `2026110101_print_identity_and_staff_password_gate.sql` | Bayrak artık yanlışlıkla girişi/LAN'ı engellememeli |
| `lan_staff_authority` bayrak `false` değilse reddediyor | `20261120090000_lan_staff_authority.sql` | Bayrak yoksa/false ise kabul; politika değişince uyumlu |
| İstemci `auth.updateUser(password)` her kullanıcıya açık | `lib/services/auth_service.dart:971-980`, `settings_page.dart`, `change_password_page.dart` | Personel için kaldırılmalı |

### Açık güvenlik riski (kritik)
Supabase Auth `PUT /auth/v1/user` ile **oturum açmış her kullanıcı kendi şifresini doğrudan
değiştirebilir**; Flutter'dan düğmeyi kaldırmak bunu engellemez. GoTrue hem bu çağrıyı hem de
Edge Function'ın `admin.updateUserById` çağrısını aynı DB rolüyle (`supabase_auth_admin`) yazdığı için
`auth.users` üzerindeki tetikleyici ikisini kendiliğinden ayıramaz.

Önerilen sunucu tarafı mimari (uygulanabilir, yerelde TEST EDİLMEDİ):
1. Yeni tablo `staff_password_change_tickets(user_id, issued_at, expires_at)` (yalnız service_role).
2. `manage-restaurant-staff` içinde sahip doğrulandıktan sonra: bilet ekle → `admin.updateUserById` →
   bilet tüketilir (kısa TTL, örn. 15 sn, tek kullanımlık).
3. `auth.users` üzerinde `BEFORE UPDATE OF encrypted_password` tetikleyicisi: kullanıcı
   `app_metadata.managed_restaurant_staff = true` ise ve geçerli bilet yoksa `RAISE EXCEPTION`.
   Bilet varsa tüket ve izin ver.
4. Kalan sınır: bilet penceresi içinde (≤15 sn) personelin eşzamanlı kendi çağrısı geçebilir; tetikleyici
   biletin hangi çağrıya ait olduğunu bilemez. Raporlanmalı. Hosted Supabase'de `auth.users`
   üzerine tetikleyici izni production'da ayrıca doğrulanmalı — doğrulanmadan GÜVENLİ denmeyecek.
5. Eski oturum/çevrimdışı yetki iptali: sahip şifre değiştirince personel oturumları
   `auth.admin.signOut(userId, 'global')` ile kapatılabilir; ancak LAN mühürlü çevrimdışı yetki
   (12 sa) bulut dönene kadar geçerli kalır — mevcut sınır, gizlenmeyecek.

Durum: **BLOCKED / FAIL** — politika kodu henüz değiştirilmedi; hiçbir kabul testi PASS değil.

### Aşama 2–9 durumu (bu çalışmada test edilmedi)
Hepsi **TEST EDİLMEDİ**. Gerekçe: başka oturumun simülatör/uygulama süreçleriyle çakışma riski,
dar disk, ve Aşama 1 değişmeden alt yönetici/garson akış testlerinin anlamsız olması.
PROJECT_MAP.md'deki önceki PASS iddiaları (LAN yetkileri, çevrimdışı mühür, 3 sipariş senkronu)
bu çalışmada yeniden doğrulanmadı.

### Değiştirilen dosyalar
- Yalnız bu dosya (`docs/RESTAURANT_PILOT_PROGRESS.md`) oluşturuldu.

### Sonraki çalışmanın kesin başlangıç noktası
1. Önce diğer oturumun bitip bitmediğini kontrol et (`ps`, worktree `git status`).
2. Aşama 1: Edge Function'dan `must_change_password:true` yazımını ve `change_staff_password` işlemini
   kaldır; `staff_must_change_password()` ve `lan_staff_authority` bayrak mantığını uyumla; bilet+tetikleyici
   migration'ını yerel Supabase'de (production'a değil) yaz ve `supabase/tests/` altında negatif test ekle
   (personel `PUT /auth/v1/user` → reddedilmeli; sahip Edge Function → başarılı).
3. Flutter: personel için Şifre Değiştir girişlerini gizle, zorunlu şifre diyaloğunu kaldır; ilgili
   `test/features/staff_*_test.dart` testlerini güncelle.
4. Ardından Aşama 2 → 5 gerçek uygulama testleri.

### GO / NO-GO
**NO-GO** — şifre politikası uygulanmadı, gerçek uygulama kabul akışı bu çalışmada doğrulanmadı.

## 2026-11-21 (gündüz oturumu) — Ekip doğrulandı, şifre politikası Opus incelemesi

### Ekip
- Ana oturum: `claude-fable-5-2`. Ajanlar `.claude/agents/ibul-team/` alt klasöründen keşfedildi ve dördü de çağrıldı:
  `ibul-code-explorer` (claude-haiku-5-5), `ibul-senior-developer` (claude-sonnet-5-5),
  `ibul-qa-engineer` (claude-sonnet-5-5), `ibul-security-architect` (claude-opus-5-5) — modeller ajanların kendi beyanı.
- `ibul-code-explorer` ve `ibul-security-architect` dosyalarından Bash kaldırıldı (yalnız Read/Grep/Glob; sonraki oturumda geçerli).
  `ibul-qa-engineer` test çalıştırmak için Bash tutuyor; Edit/Write yok ama Bash teknik olarak yazabilir (açık sınır).
- QA: `flutter test test/features/staff_password_change_policy_test.dart` 2/2 geçti — ESKİ politikayı doğrulayan birim testi; yeni politika kanıtı değil.

### Opus güvenlik kararı (salt-okunur inceleme)
- Önceki "bilet + tetikleyici" tasarımı: **FAIL** (bilet yarışı; bcrypt salt yüzünden hash'e bağlanamaz; e-posta/telefon/identity
  değişimi ve OTP/magic-link yolları kapsam dışı; tetikleyici koşulu `IS DISTINCT FROM` olmalı).
- Yeni bulgu (YÜKSEK): `manage-restaurant-staff/index.ts` 157-172, 247-277 — `set_temporary_password` `manageStaff` yetkili
  alt yöneticiye de açık; politika gereği yalnız sahibe (`ownerStoreId`) bağlanmalı.
- Alternatif tasarım: **BLOCKED** (yerelde kanıtlanana kadar): service_role'e özel SECURITY DEFINER RPC `owner_set_staff_password`
  (tek işlemde sahiplik+üyelik doğrulama, işlem-yerel GUC, `encrypted_password` yazımı, oturum/refresh token silme,
  `staff_credentials.epoch` artırma) + `auth.users` tetikleyicisi (GUC yoksa personelin şifre/e-posta/telefon değişimini ve
  identity eklemeyi reddeder) + Custom Access Token Hook (epoch claim; personel için otp/magiclink/recovery reddi) +
  `lan_staff_authority` yanıtına epoch.
- Yerelde doğrulanmalı: hosted Supabase'de `auth.users` tetikleyici izni/kalıcılığı, pgcrypto hash'iyle GoTrue girişi,
  GoTrue'nun hata davranışı, hook'ta `amr` reddi, access JWT ömrü.
- Negatif test listesi (a–n): personel PUT password/email/phone, recovery, OTP, linkIdentity, Edge Function
  `change_staff_password` 403, alt yönetici `set_temporary_password` 403, başka mağaza sahibi 403, eşzamanlı yarış,
  eski refresh/access token, LAN eski epoch, müşteri/sahip akışı bozulmamalı, giriş kilitlenmemeli, yeni personelde must_change kapısı yok.
- Kalan sınır: LAN merkezi buluttan kopukken sahibin başka cihazdan yaptığı şifre değişimi en fazla 12 saat görünmez.

### Sonraki kesin adım
Yerel Supabase'de (production değil) prototip: önce "doğrulanmalı" 5 maddeyi tek tek dene, sonra migration + Edge Function
değişikliği (`ibul-senior-developer`), negatif testler (`ibul-qa-engineer`), tekrar Opus incelemesi.
Dikkat: yerel DB diğer oturumun (`ibul-restaurant-completion` iş ağacı) test ortamıyla ortak; `auth.users` tetikleyicisi onun girişlerini etkileyebilir.
Flutter tarafı: `seller_panel_page.dart:17563` (zorunlu pencere), `store_service.dart:2590`, `settings_page.dart:1246`,
`account/account_security_page.dart:42`, `auth_service.dart:971-1050`.

## 2026-11-21 (devam) — Şifre politikası sunucu tarafı: YEREL PROTOTİP (production'a uygulanmadı)

### Yazılan dosyalar
- `ibul_app/supabase/migrations/20261121090000_staff_owner_only_password.sql` (yalnız yerel `ibul-local-staging` DB'ye uygulandı)
- `ibul_app/supabase/rollbacks/20261121090000_staff_owner_only_password_rollback.sql`
- `ibul_app/supabase/tests/staff_owner_only_password_test.mjs`
- `ibul_app/supabase/functions/manage-restaurant-staff/index.ts` (change_staff_password/clear_password_change → 403; oluşturmada
  must_change_password=false; set_temporary_password yalnız sahip, `owner_set_staff_password` RPC ile)

### Tasarım (yerelde deneyle kanıtlanan)
- `auth.users` / `auth.one_time_tokens` / `auth.identities` tetikleyicileri: korumalı personelde şifre, e-posta, telefon,
  recovery/magic-link/confirmation token ve yeni identity yazımı işlem-yerel GUC olmadan reddedilir.
- `owner_set_staff_password` (yalnız service_role): sahiplik + üyelik + `provisioned_by_store_id` eşleşmesi; şifre yazar,
  oturum/refresh siler, `staff_credentials.epoch` artırır.
- `staff_must_change_password()` artık bayrağa bakmaz; personelin JWT `session_id`'si yok/geçersiz/silinmişse true (fail-closed).
- `lan_staff_authority` → `credential_epoch` eklendi (Dart merkez henüz KULLANMIYOR).

### Test sonuçları (API/SQL; ARAYÜZ TESTİ YOK)
- `staff_owner_only_password_test.mjs`: 46/46 PASS (geliştirici); önceki 36'lık sürüm QA tarafından bağımsız 36/36 doğrulandı,
  46'lık sürüm QA tarafından henüz yeniden çalıştırılmadı.
- `lan_staff_authority_negative.sql`: 10/10 PASS.
- DOĞRULANAMADI: telefon OTP (yerelde `phone_provider_disabled`); Edge Function HTTP yolu (yerelde edge runtime yok; yalnız `deno lint`).

### Opus kararı (3. inceleme): yerel prototip KOŞULLU PASS, production BLOCKED
Production öncesi zorunlu:
1. **Kilitleme (DoS), ORTA, YENİ:** korumalı sayılma ölçütü yalnız üyelik satırıyla da sağlanıyor; sahip başkasının e-postası/auth id'siyle
   `store_sub_admins` satırı ekleyebiliyorsa (RLS yolu doğrulanmadı) kurban kendi şifresini/e-postasını değiştiremez, RPC de yazamaz.
   Öneri: korumayı yalnız `managed_restaurant_staff` bayrağına bağla veya istemcinin `auth_user_id` yazmasını RLS ile yasakla.
2. Kapıyı çağırmayan yollarda eski JWT 1 saat geçerli (`get_my_staff_access`, `store_sub_admins_active_self_select`,
   `table_orders` politikası, `restaurant_table_number_access` kısa yolu; restaurant-ops-web taranmadı).
3. `provisioned_by_store_id` boş eski personeller için backfill (yerelde `waiter@ibul-local.test` boş → sahibi şifresini DEĞİŞTİREMEZ).
4. Telefon sağlayıcısı açıkken OTP/recovery negatif testi; hosted Supabase'de auth şeması tetikleyici izni.
5. RLS'te `(select public.staff_must_change_password())` sarmalaması + performans; rollback'in denenmesi (rollback Edge Function ile birlikte uygulanmalı).
6. Ürün kararı: reddedilen recover/otp isteklerinde GoTrue e-postayı yine gönderiyor (link ölü); ret kodu 500.

### Kullanıcı kararı bekleyen
- Alt yönetici (manageStaff) YENİ personel oluştururken başlangıç şifresini belirleyebiliyor. Yalnız sahibe mi kısıtlansın?

### Bilinen uyumsuzluklar (henüz düzeltilmedi)
- Flutter: `store_service.dart:2590` `changeStaffTemporaryPassword` ve `seller_panel_page.dart:17563` zorunlu şifre penceresi artık 403 alan
  işlemi çağırıyor; `settings_page.dart:1246`, `account/account_security_page.dart:42` personelde gizlenmeli; ret kodu 500 için kullanıcı mesajı.
- Eski testler `isolated_staff_lifecycle.mjs`, `restaurant_staff_membership_test.mjs`, `test/features/staff_password_change_policy_test.dart` eski politikayı sınıyor.
- Yerel `GET /auth/v1/admin/users` listeleme bozuk (SQL ile eklenmiş eski satırlarda NULL token) → Edge Function `findAuthUserByEmail` yerelde çalışmaz.

### Sonraki kesin adım
1) Madde 1 (DoS) düzeltmesi + test, QA ile 46'lık testin bağımsız tekrar çalıştırılması. 2) Madde 2 kapı kapsamı. 3) Flutter uyumu
(`ibul-senior-developer`, tek yazar). 4) Arayüzden sahip → personel oluştur → şifre belirle → personel giriş testi (Aşama 2-3).

## 2026-11-21 (devam 2) — Yalnız sahip oluşturur, kilitleme düzeltmesi, kapı kapsamı

### Kullanıcı kararı
Yeni personel hesabını ve başlangıç şifresini YALNIZ sahip oluşturur.

### Yapılan (yalnız yerel `ibul-local-staging`; production'a hiçbir şey gitmedi; commit yok)
- `manage-restaurant-staff/index.ts` ~390-402: `createUser` yalnız sahip; alt yönetici yeni hesap için 403 (yalnız kod okuması + `deno lint`; HTTP testi YOK).
- Migration bölüm 1: `is_managed_restaurant_staff(uid)` yalnız `managed_restaurant_staff` bayrağına bakar (kilitleme/DoS kapandı; depo
  kurallarının simülasyonunda açığın gerçek olduğu görüldü).
- Migration bölüm 7: `get_my_staff_access()` ve `store_sub_admins_active_self_select` politikasına kapı eklendi; rollback güncellendi.
  `restaurant_table_number_access` ve `table_orders` politikalarına dokunulmadı (personel yolu kapılı `restaurant_table_access` üzerinden; Opus koddan doğruladı).

### Test (API/SQL; ARAYÜZ YOK)
- `staff_owner_only_password_test.mjs` 58/58 — geliştirici ve QA bağımsız. `lan_staff_authority_negative.sql` 10/10.
- **Kanıt sınırı:** yerel DB depo şemasından GERİDE (store_sub_admins/table_orders RLS kapalı, `get_my_staff_access` yok; 2026102901 ve
  20261105123000 tam uygulanmamış). Bölüm 7 yalnız geri alınan transaction içinde, kısaltılmış önkoşullarla simüle edildi.
- ÇALIŞTIRILMADI: `isolated_staff_table_access.sql`, `isolated_staff_operation_permissions.sql` (kalıcı yazıyorlar, ayrı throwaway DB ister).

### Opus kararı (4. inceleme): yerel prototip KOŞULLU PASS; production BLOCKED
Production öncesi zorunlu (güncel liste):
a. Bayraksız eski personel backfill'i (bayrak + `provisioned_by_store_id`); yerelde 2 üyelikten 1'i bayraksız = korumasız (YÜKSEK).
b. Alt yöneticinin şifresiz "yeniden bağlama" yolu (index.ts ~415-465): silinmiş eski hesabı `sub_admin`/`manageStaff` rolüyle geri bağlayabiliyor;
   delete Auth hesabını ve oturumlarını silmiyor → kovulan personel eski refresh token ile dönebilir. Yeniden bağlamayı sahibe aç veya rolü
   sınırla; delete ve yeniden bağlamada oturumları sil.
c. Bölüm 7: nesne yoksa sessiz atlama ve sütuna göre gövde seçimi → canlı gövdeyi doğrula, uyuşmazlıkta RAISE.
d. Production benzeri şemada (RLS açık) gerçek migration + rollback provası — izole kopya DB'de.
e. Edge Function HTTP testleri (alt yönetici create 403, yeniden bağlama, set_temporary_password).
f. Doğrulanmalı: şifresi değişen alt yöneticinin eski JWT'si Edge Function'ı çağırabiliyor mu (`_shared/http.ts` okunmadı).
g. Hosted GoTrue sürümüyle auth tetikleyici uyumu/izni; telefon OTP negatif testi.
h. Ürün kararı: ölü bağlantılı e-postalar ve 500 ret kodu.

### Sonraki kesin adım
1) (b) yeniden bağlama + delete oturum iptali düzeltmesi, (c) RAISE. 2) İzole kopya DB'de (d) provası ve `isolated_*.sql` testleri.
3) Flutter uyumu (zorunlu pencere kaldır, şifre girişlerini personelde gizle, 500 için mesaj, eski testleri güncelle).
4) Arayüzden sahip → personel oluştur → giriş (Aşama 2-3).

## 2026-11-21 (devam 3) — Yeniden bağlama yalnız sahip, silme/pasifleştirme iptali, gerçek zincirde test

### Çalışma yeri (ÖNEMLİ)
- Bu oturum `.claude/worktrees/ibul-restaurant-completion-e60b65` çalışma ağacında; ana klasöre (`/Users/barankananogullari/ibul-work`) yazmayı bir
  koruma kancası engelliyor. Şifre politikası dosyaları (index.ts, 20261121090000 migration + rollback, test, bu dosya) ana klasörden buraya kopyalandı;
  **güncel sürüm artık bu çalışma ağacında**. Ana klasördeki kopyalar eski (istisna: 20261121090000 migration'ının sıkılaştırılmış ilk hali kanca fark
  edilmeden önce ana klasöre de yazıldı). Birleştirme kullanıcı onayı bekliyor.

### Kullanıcı kararı (kesin)
Personel hesabı oluşturma, şifre belirleme/değiştirme, pasif/silinmiş personeli yeniden etkinleştirme/bağlama YALNIZ doğrulanmış işletme sahibi.
Alt yönetici (manageStaff dahil) yapamaz. Personel kendi şifresini değiştiremez. İlk girişte zorunlu değişim yok.

### Yapılan (yalnız izole, atılabilir yığın; production'a ve ortak yerel DB'ye yazılmadı; commit yok)
- `manage-restaurant-staff/index.ts`: `create` (yeni hesap + yeniden bağlama) ve `activate` yalnız sahip; alt yönetici 403.
- `20261121090000_staff_owner_only_password.sql`: bölüm 0 önkoşul denetimi + bölüm 7 artık sessiz atlamıyor (eksik fonksiyon/politika/sütun, kapalı RLS,
  beklenmeyen `get_my_staff_access` gövdesi → RAISE). Yeniden çalıştırılabilir.
- YENİ `20261121100000_staff_access_revocation.sql` (+ rollback): `store_sub_admins` tetikleyicileri. Üyelik silme / durum değişimi / kimlik değişimi /
  yeni bağlama → `staff_credentials.epoch` artar + `sessions_valid_after` kesme zamanı; işletmenin oluşturduğu hesapta oturum + refresh token silinir ve
  aktif üyelik yokken Auth hesabı banlanır (GoTrue girişi `user_banned` ile reddeder); ban yalnız üyelik yeniden aktif olunca kalkar. Kapı
  (`staff_must_change_password`) kesme zamanından eski oturumu reddeder → yeniden etkinleştirme eski oturumu diriltmez. Oturum açmış istemci (sahip, RLS)
  işletmenin oluşturmadığı Auth hesabını bağlayamaz.
- Bulgu ve düzeltme: `banned_until='infinity'` GoTrue'yu o kullanıcı için çökertiyor (500, hesap silinemiyor) → 100 yıllık sonlu tarih.
- `supabase/diagnostics/20261121_staff_legacy_classification.sql`: SALT-OKUNUR eski personel sınıflandırması (A korumalı / B bayraklı-mağazasız /
  C bayraksız / D bağsız; kanıt strong/weak). Otomatik backfill YOK; sahip adıyla onaylamadan işaretleme yapılmaz.

### İzole gerçek zincir (yeniden oluşturulabilir)
- Ayrı Supabase yığını `ibul-iso-staff` (portlar 5532x; GoTrue v2.195, PG 17). Canlı katalog fikstürü (`restaurant_operations_fixture.sql`, 2026-10-29) +
  `2026102901` → `20261121100000` arası 30 migration'ın GERÇEK metni sırayla uygulandı (RLS açık).
- Fikstür eksikleri için kullanılan vekiller (kanıt sınırı): `close_table_with_history` canlı anlık görüntüsü, `transfer_table_orders` test vekili,
  `20260407_restaurant_ops_upgrade.sql` (table_payments), `products` ve `store_table_areas` yerel staging şemasından, service_role tablo yetkileri.

### Test sonuçları (API/SQL — ARAYÜZ DEĞİL)
- `staff_owner_only_password_test.mjs`: **89/89** (gerçek GoTrue girişleri + PostgREST; R1–R9: pasifleştirme, yeniden etkinleştirme, bayraksız eski üye,
  silme/yeniden bağlama, başka işletme sahibi, alt yönetici doğrudan yazım, sahip kilitlenmez, migration ret senaryoları).
- YENİ `staff_edge_function_http_test.mjs`: **33/33** (Edge Function `deno run` ile yerelde, HTTP üzerinden: sahip oluşturur; alt yönetici
  create/activate/şifre/yeniden bağlama 403; başka sahip 404/403/409; izin kaldırma aynı oturumda anında ret; eski JWT fonksiyonda 401).
- Rollback provası: iki rollback sırayla → nesne sayıları ön-durumla eşit (46 fonksiyon / 22 tetikleyici / 32 politika), banlı hesap açıldı; yeniden uygulama
  sonrası testler tekrar geçti. `get_my_staff_access` ve `lan_staff_authority` rollback sonrası bayt-özdeş DEĞİL (biçim farkı; anlam denetimi Opus'ta).
- DOĞRULANAMADI: telefon OTP (SMS sağlayıcı kapalı); hosted Supabase'de auth şeması tetikleyici/UPDATE/DELETE izni; gerçek Edge Runtime (Deno Deploy) ortamı.

### Opus kararı (5. inceleme): yerel prototip KOŞULLU PASS; production BLOCKED — bulgular düzeltildi
- A (Yüksek/Orta) hesapsız e-posta satırıyla başka işletmenin personelini düşürme / yabancı hesabı bağlama → DÜZELTİLDİ: yalnız bağlı hesap iptal edilir;
  istemci hesapsız satırı aktif yapamaz; Edge Function hesapsız kaydı etkinleştirmez (409).
- B saat farkı → kesme zamanı var olan en yeni oturumdan önce olamaz. C ban: mağaza sahibi banlanmaz, başkasının banı devralınmaz.
- D alt yönetici son personel yöneticisini / kendini silemez. E şifre rollback'i önce iptal rollback'ini ister (RAISE).
- Düzeltme sonrası: `staff_owner_only_password_test.mjs` **92/92**, `staff_edge_function_http_test.mjs` **33/33** (geliştirici koşusu; QA bağımsız koşusu ayrıca).
- Production öncesi hâlâ zorunlu: hosted Supabase'de auth şeması tetikleyici/DELETE/UPDATE izinleri ve GoTrue ban davranışı; RLS performans ölçümü
  (kapı her satırda `auth.sessions` okur); bayraksız eski personel için sahip onaylı backfill (sınıflandırma sorgusu hazır, otomatik değişiklik yok);
  kapılardaki eski e-posta eşleşme dalının backfill sonrası kaldırılması.

### Flutter uyumu (geliştirici ajan; birim testleri — ARAYÜZ TESTİ DEĞİL)
- Zorunlu şifre penceresi ve `changeStaffTemporaryPassword` kaldırıldı; personelde "Şifre Değiştir" girişleri gizli, servis çağrısı da reddediyor.
- Personel Yönetimi: "Yeni personel", "Aktifleştir", "Şifre belirle" yalnız sahipte; `user_banned` → "Bu personel hesabı pasif. İşletme sahibine başvurun."
- LAN: `credential_epoch` okunuyor (yoksa ret), cihaz kaydına ve mühre giriyor; epoch farkı → cihaz kalıcı iptal (yeniden eşleşme gerekir).
  Eski mühürler geçersiz: güncellemeden sonra bulut yokken eski cihazlar reddedilir, ilk çevrimiçi doğrulamada yenilenir.
- Birim testleri (geliştirici beyanı): ilgili 11 dosyada 150 test geçti, analyze hatasız. Gözden geçirilecek: "Şifre belirle" düğme yerleşimi,
  `settings_page.dart` diff'inde biçim kaynaklı satırlar.

### Çevrimdışı LAN 12 saat mühür riski — değerlendirme
- Merkez buluta erişirken: her istekte canlı doğrulama; pasifleştirme/izin kaldırma anında, yeniden etkinleştirme ve şifre değişimi epoch ile yakalanır.
- Merkez buluttan kopukken: son çevrimiçi doğrulamadan itibaren en fazla 12 saat eski yetki geçerli kalır (pasifleştirme görülmez). KABUL EDİLMİŞ AÇIK RİSK.
  Azaltma: sahip merkezde cihazı elle iptal edebilir; öneri (kullanıcı kararı): süreyi vardiya uzunluğuna indirmek.

### BLOCKED — gerçek uygulama (arayüz) testleri
- Disk 1.9 GiB boş. iOS simülatör/macOS derlemesi bu alanla başlatılmadı (diskin dolması diğer oturumları ve yerel DB'yi bozabilir).
- Hazır olanlar: izole yığın + tohum veri (işletme, 23 masa, 10 ürün), tek adres yönlendirici (55400 → API 55321 + Edge Function 55390).
- Yer açılınca: `--dart-define=IBUL_SUPABASE_URL=http://127.0.0.1:55400` ile simülatör derlemesi → 13 adımlı akış.

## 2026-11-21 (devam 4) — QA bağımsız koşusu; simülatör derlemesi DİSK DOLDUĞU İÇİN BAŞARISIZ

### QA (bağımsız, API/SQL + Flutter birim; ARAYÜZ DEĞİL)
- Sunucu testleri bağımsız: 92/92 ve 33/33. Kendi saldırı denemeleri (eski JWT, alt yönetici doğrudan yazım, personel şifre/e-posta, başka işletmenin
  e-postasıyla üyelik) reddedildi. Flutter 7 dosyada 118 test, analyze hatasız.
- QA bulgusu (ortam): izole DB'de `table_orders` RLS kapalıydı (fikstür `20260915_table_orders_store_isolation` öncesi) → eski JWT sipariş OKUYABİLİYORDU.
  Canlıdaki gibi RLS açıldı; "eski JWT sipariş okuyamaz" kontrolü eklendi; şifre migration'ı `table_orders` RLS kapalıysa RAISE eder. Sonuç **94/94**.
- Açık (düzeltilmedi): personelin şifre değiştirme denemesinde GoTrue 500 döner (değişiklik engellenir; istemcide "sunucu hatası" görünebilir);
  bazı test ret kontrolleri yalnız `status>=400` (RPC yetki kontrolleri); e-postayla `invited` satır hâlâ yazılabiliyor (etkinleştirilemiyor; davet kabul yolu test edilmedi).

### Gerçek uygulama (arayüz) testleri — BLOCKED (disk)
- Kullanıcı onayıyla kullanılmayan Supabase Studio imajı silindi (boş alan 3,9 GiB).
- `flutter build ios --simulator --debug -t lib/main_seller.dart` (izole yığına bağlı) Xcode aşamasında **diski doldurdu ve başarısız oldu** (ENOSPC).
  Bu derlemenin Xcode ara dosyaları (DerivedData, 2,2 GiB) silindi; boş alan 3,4 GiB. Yerel staging ve izole DB sağlam (sorgu ile doğrulandı), PANIC kaydı yok.
- Gereken: en az ~8–10 GiB boş alan. Sonra aynı komutla derleme ve 13 adımlı akış.
- Hazır ve çalışır durumda: izole yığın `ibul-iso-staff` (5532x), Edge Function yerel (55390), yönlendirici (55400), tohum veri, sahip test şifresi
  (yalnız izole DB; scratchpad `ui_creds.env`, oturum kapanınca kaybolabilir).
- Hiçbir arayüz adımı (1–13) doğrulanmadı. Mobil hatalar (ürün kartı boşluğu, yazıcı ayarları taşması, Otomatik Tara, yavaş çevrimdışı açılış) başlamadı.

### GO / NO-GO
**NO-GO.** Sunucu sözleşmesi izole gerçek zincirde kanıtlı; arayüz zinciri ve hosted Supabase izinleri kanıtsız. macOS/iPhone/fiziksel yazıcı testleri
tamamlandığında Windows 11 ARM sanal makinesine geçilecek; Android APK hazırlığı planda duruyor.
