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

## 2026-11-21 (devam 5) — Disk çözüldü, simülatör derlendi, GERÇEK ARAYÜZ testleri başladı

### Disk
- `/Volumes/IBULBuildAPFS` yoktu (imaj silinmiş). PortableSSD'de yeni imaj: `IBUL_Build/IBULBuild-APFS.sparseimage` (80 GiB, APFS).
- `~/IBUL_isolated_build/DerivedData{IOS,IOSSim,Local,Release}` (~23 GiB, eski test derleme önbellekleri) imaja taşındı, eski yollarda sembolik bağ var.
  Release: rsync + sağlama toplamı (fark 0). Diğer üçü: dosya sayısı eşleşmesi + sonradan tam okuma testi (hata 0); asılları olmadığından sağlama karşılaştırması yapılamadı.
- Boş alan: iç disk ~20 GiB (derlemelerden sonra), harici imaj 57 GiB. SSD çıkarılırsa dört bağ kırılır (veri SSD'de).

### Derleme
- `flutter build ios --simulator --debug -t lib/main_seller.dart` (izole yığına bağlı) BAŞARILI. Yol üstünde düzeltilenler:
  kök `lib/main_seller.dart` kaldırılan zorunlu şifre kodunu çağırıyordu (2 satır); `ios/Runner/GoogleService-Info.plist` (gitignore) çalışma ağacında yoktu, ana klasörden kopyalandı.

### Arayüz testi (iOS simülatör, iPhone 16 Pro, gerçek uygulama; izole yığın `ibul-iso-staff`)
| # | Adım | Sonuç | Kanıt |
|---|---|---|---|
| 1 | Sahip normal Satıcı girişi | **PASS** | "Genel Bakış · Sentetik Restoran" |
| 2-3 | Personel Yönetimi'nden garson + alt yönetici (e-posta, şifre, görev, şube, izin) | **PASS** | Liste: "Ayse Garson · Garson · Merkez · Aktif", "Mehmet Mudur · Restoran Müdürü · Merkez · Aktif"; DB: bayrak true, must_change false, provisioned_by = işletme |
| 4 | Garson normal Satıcı girişi | **PASS** | Zorunlu şifre ekranı YOK; doğrudan "Garson · Sentetik Restoran" |
| 5 | Restoran, masalar, ürünler | **PASS** | 24 masa (Bahçe/Salon/Test), ürün listesi |
| 6 | Güvenli LAN eşleştirmesi | **BLOCKED** | Merkez (macOS Satıcı uygulaması) izole yığına karşı henüz çalıştırılmadı; uygulama "Ana bilgisayar bu ağda bulunamadı · Kodla bağla" gösteriyor (beklenen) |
| 7-8 | Bahçe 1'e ürün ekle, sipariş gönder | **PASS** | "Kuyruğa alındı. Mutfak fişi kuyruğa alındı. Yazıcı Merkezi baskıyı bekliyor."; masa "Mutfağa İletildi · 1 x Cay" |
| 9 | Sahte yazıcıya tek fiş | **KISMEN** | DB: 1 `orders`, 1 `order_items`, 1 `print_jobs` (pending) — tek iş. Fişin sahte yazıcıya ULAŞMASI doğrulanmadı (yazıcı merkezi çalışmıyor) |
| 10-12 | Çevrimdışı sipariş, dönüşte tekilleştirme | **BLOCKED** | LAN merkezi gerekli (adım 6) |
| 13 | İzin kaldırma → ret | **PASS** | İzin sahip adına API ile kaldırıldı (API ADIMI); garsonun AÇIK oturumunda arayüz: "Bu işlem için yetkiniz yok. İşletme sahibine başvurun."; DB: sipariş sayısı 1'de kaldı |
| — | Eski personelin alt yöneticiyle yeniden bağlanması (arayüz) | **TEST EDİLMEDİ** | API düzeyinde 403 kanıtlı (33/33) |

Fikstür notları: "Bahçe 1" masası tohum veride yoktu, izole DB'ye eklendi. `order_items → orders` yabancı anahtarı fikstürde eksikti (staging'de var), eklendi.

### Arayüz testinde bulunan ve düzeltilen
- Yetki reddinde mesaj "Sipariş kaydedilemedi. Aynı gönderim tekrar denenebilir." idi (yanıltıcı) → "Bu işlem için yetkiniz yok. İşletme sahibine başvurun." (`seller_panel_page.dart`, dar düzenleme; yeniden derlenip arayüzde doğrulandı).

### Arayüz testinde görülen, DÜZELTİLMEYEN
- Sipariş akışı okunamayınca ham `PostgrestException` metni ekrana basılıyor (fikstür eksiğiyle tetiklendi; kullanıcı dostu değil).
- Sahip panelinde "0 aktif ürün" (9 ürün var) — incelenmedi.
- Simülatörde metin girişi: yalnız pano + uzun bas → Paste çalıştı (test aracı kısıtı, uygulama hatası olduğu doğrulanmadı).

### Sonraki kesin adım
1) macOS Satıcı uygulamasını (izole, `IBUL_ISOLATED_DESKTOP`, izole yığın) derle → LAN merkezi + sahte yazıcı (19100) → adım 6, 9, 10-12.
2) Arayüzde: pasifleştirilmiş garson girişi mesajı; alt yöneticide "Yeni personel/Aktifleştir/Şifre belirle" gizli mi; sahip "Şifre belirle".
3) Mobil hatalar (ürün kartı, Yazıcı Ayarları taşması, Otomatik Tara). 4) 29(+2) dosyalık ana klasöre aktarım planı.

## 2026-11-21 (devam 6) — İzole macOS Satıcı uygulaması derlendi; sahip girişi KULLANICI BEKLİYOR

- Derleme BAŞARILI: `/Volumes/IBULBuildAPFS/DerivedDataIsoStaff/Build/Products/Debug-Offlinetest/IbulSellerDesktopTest.app`
  (çalışma ağacından; izole yığın `127.0.0.1:55400`; paket `com.ibul.sellerdesktop.debuglocal`; Anahtar Zinciri hesabı `ibul.sellerdesktop.isostaff`;
  LAN portu 18793; test köprüsü 18771 → sahte yazıcı 19100; canlı 3001 ve gerçek yazıcı devrede değil). Tarif: scratchpad `build_macos_iso.sh`
  (`~/IBUL_isolated_build/scripts/build_kc_managed.sh` uyarlaması).
- Uygulama açıldı, giriş ekranı görüldü. **BLOCKED:** arka plan denetimiyle Flutter metin alanlarına yazılamıyor; tam ekran denetimi parola alanı için
  kullanılamaz. Sahip girişini kullanıcı yapmalı (hesap `owner@ibul-local.test`, şifre yalnız izole DB'de geçerli, scratchpad `ui_creds.env` → `OWNER_PW`).
- Girişten sonra: Yerel ağ merkezini başlat → simülatördeki garsonu eşleştir (adım 6) → sipariş → sahte yazıcıda tek fiş (adım 9) →
  yönlendiriciyi (55400) durdurarak çevrimdışı sipariş (10-11) → yeniden başlatıp tekilleştirme (12).
- Henüz başlatılmadı: izole yığın için baskı kanıtı doğrulayıcısı (19210).

## 2026-11-21 (devam 7) — macOS merkez + simülatör garson: LAN eşleşti, LAN siparişi merkeze ulaştı; fiş ve senkron FAIL

Ortam: izole macOS Satıcı (sahip girişi kullanıcı tarafından yapıldı; sonraki adımlar arka plan tıklamalarıyla), iOS simülatör garson, izole yığın.
iOS derlemesine `--dart-define=IBUL_LAN_PORT=18793` eklendi (ilk denemede yoktu → kod "bu uygulamanın ana bilgisayarına ait değil" diye reddedildi; test yapılandırma hatası).

| # | Adım | Sonuç | Kanıt (arayüz) |
|---|---|---|---|
| 6a | Yerel merkezi başlat (macOS) | **PASS** | "Yerel sunucu: açık · port 18793", `192.168.10.158:18793` dinliyor; test köprüsü 18771 uygulama tarafından başlatıldı |
| 6b | Normal girişten OTOMATİK merkez bulma | **FAIL** | Doğru portla da garson "Ana bilgisayar bu ağda bulunamadı" gösterdi. Kök neden bilinmiyor (simülatör Bonjour/yerel ağ kısıtı olabilir; gerçek iPhone'da denenmeli) |
| 6c | Kodla eşleştirme | **PASS** | Merkezde "Garson cihazı bağla" → kod → garsonda "Kodla bağla" → "Ana bilgisayarın onayı bekleniyor" → merkezde "Bağlı cihaz: 1" |
| 7-8 (LAN) | Bahçe 8 siparişi LAN üzerinden | **PASS (düzeltmeden sonra)** | Önce "Bu masada işlem yetkiniz yok" (HATA, aşağıda). Düzeltme sonrası sipariş kabul edildi; merkezde "Kuyruk: 1 kayıt" |
| 9 | Sahte yazıcıya tek fiş | **FAIL** | Garson ekranı: "Mutfak yazdırma için eşleşen yazıcı/istasyon bulunamadı." Sahte yazıcı kaydı 27 satırda kaldı (yeni fiş yok). DB'de ürün→istasyon→"Zincir Sahte Yazıcı" eşlemesi VAR; merkezin yerel yönlendirme verisi incelenmedi |
| 12 (ön) | Merkez → bulut senkron | **FAIL** | Merkez: "syncFailed · SocketException: Connection refused, 127.0.0.1:53928". Bulutta sipariş sayısı 1'de kaldı (LAN siparişi senkronlanmadı). 53928'deki bileşen tanımlanmadı |
| 10-11 | Çevrimdışı sipariş | **BAŞLANMADI** | 9 ve senkron çözülmeden anlamlı değil |

### Bulunan ve düzeltilen GERÇEK hata
- `restaurant_lan_host.dart` `_tableScopeError`: şubesi tanımsız (NULL) masa, şubeli garsona reddediliyordu; sunucu kuralı
  (`restaurant_staff_branch_can_see_table`) buna izin veriyor (yorum "sunucuyla aynı kural" diyordu ama değildi). NULL şubeli masa artık kabul;
  farklı şube hâlâ kapalı. `restaurant_lan_host_test.dart` 50/50 geçti; NULL-şube için yeni test EKLENMEDİ (test boşluğu).

### Açık bulgular (düzeltilmedi)
- Bulutta ilk siparişin `print_jobs` satırı merkez açılınca `paused_by_operator` oldu (neden incelenmedi).
- Yerel merkez LAN arayüzünde (192.168.10.158) dinliyor: eşleştirme korumalı ama gerçek ağda görünür; test bitince durdurulmalı.
- Commit edilmeyen kod değişiklikleri: `lib/main_seller.dart`, `seller_panel_page.dart` (ret mesajı), `restaurant_lan_host.dart` (şube kuralı).

### Sonraki kesin adım
1) Merkez senkronunun bağlandığı 127.0.0.1:53928 bileşenini bul (`restaurant_offline_sync_service.dart`, kanıt doğrulayıcı `IBUL_LAN_EVIDENCE_VERIFIER_URL`=19210 henüz çalışmıyor)
   ve izole yığın için başlat. 2) "eşleşen yazıcı/istasyon bulunamadı": merkezin yerel önbelleğindeki istasyon/yazıcı verisi ve `kitchen_routing_service`.
3) Sonra tek fiş (sahte yazıcı kaydı 27 → 28) ve çevrimdışı/tekilleştirme. 4) Otomatik bulmayı gerçek iPhone'da dene.

## 2026-11-21 (devam 8) — Fiş ve senkron hatalarının kök nedeni (kısmen çözüldü)

- **Senkron hatası (ÇÖZÜLDÜ, ortam):** hata metnindeki `port = 53928` hedef değil yerel geçici porttu. Asıl hedef, derlemeye verdiğim
  baskı kanıtı doğrulayıcısı `127.0.0.1:19210` idi ve çalışmıyordu. İzole yığına bağlı doğrulayıcı başlatıldı (`verify-lan-print-evidence`, deno, 19210).
  Kuyruktaki siparişin senkronu HENÜZ yeniden denenmedi (fiş basılmadan senkron beklenen davranış olmayabilir).
- **"Eşleşen yazıcı/istasyon bulunamadı" (KÖK NEDEN: kurulum, hata değil):** test merkezinde Yazıcı Servisi kapalıydı ve cihaz rolü
  "Yalnızca sipariş gönderir" idi → LAN siparişi için baskı işi üretilmedi. Arayüzden: Yazıcı Servisi AÇILDI ("Yazıcı servisi açıldı").
- **Hâlâ BLOCKED:** "Bu cihazı Yazıcı Merkezi yap" → "Önce Eşleştirme sekmesinden adisyon ve mutfak yazıcılarını kaydedin."
  Eşleştirme sekmesi izole ortamda "Eşleştirmeler yüklenemedi." gösteriyor (neden bulunmadı; büyük olasılıkla fikstürde eksik tablo/sütun).
  Bu çözülmeden sahte yazıcıya fiş (adım 9) ve çevrimdışı adımlar (10-12) denenemez.
- UX gözlemi (düzeltilmedi): "Cihaz Rolü" kartları seçilebilir görünüyor ama tıklanamıyor; rol yalnız alttaki düğmeyle değişiyor.

### Sonraki kesin adım
1) Eşleştirme sekmesinin hangi isteği/tabloyu okuyamadığını bul (`printer_role_mappings_card.dart`, `printer_repository.dart:828`), izole fikstürü tamamla.
2) Adisyon + mutfak yazıcısı olarak "Zincir Sahte Yazıcı"yı kaydet → "Bu cihazı Yazıcı Merkezi yap".
3) Garsondan yeni sipariş → sahte yazıcı kaydı 27 → 28 (tek fiş) → merkez senkronu → bulutta tek sipariş.
4) Yönlendiriciyi (55400) durdur → çevrimdışı sipariş → yeniden başlat → tekilleştirme.
Çalışan test süreçleri: izole yığın (5532x), Edge Function 55390, yönlendirici 55400, doğrulayıcı 19210, macOS test merkezi (LAN 192.168.10.158:18793), test köprüsü 18771.

## 2026-11-21 (devam 9) — Yazıcı merkezi kuruldu, senkron çalışıyor; fiş sahte yazıcıya HÂLÂ ULAŞMIYOR (kullanım limiti nedeniyle durduruldu)

- Eşleştirme sekmesi hatası: izole fikstürde `station_printers → stations/printers` yabancı anahtarları eksikti (staging'de var) → eklendi, sekme yüklendi.
- Arayüzden: adisyon + mutfak yazıcısı "Zincir Sahte Yazıcı" kaydedildi; "Bu cihazı Yazıcı Merkezi yap" → "Açık ve yazıcı servisi çalışıyor".
- Garsondan Salon 8 siparişi: hatasız ("Mutfağa İletildi"). **Senkron PASS:** bulutta 3 sipariş, 3 ayrı `local_order_id` (mükerrer yok).
- **Tek fiş FAIL:** sahte yazıcı kaydı 27 satırda kaldı. Bulutta 2 baskı işi `claimed` (İşleniyor) durumunda takılı, yazıcı/istasyon alanları boş;
  test köprüsüne bugün hiç `POST /print/kitchen` gelmedi (köprü ayakta, ağ modunda 19100'e bağlı). İşi `claimed` yapan: `desktop_print_hub.dart` (~1709-2490).
  Kök neden BULUNAMADI. Aday: merkezin "Gelen Siparişler" sekmesi `RealtimeSubscribeException` veriyor (izole yığında realtime yok, yönlendirici websocket'i kesiyor);
  baskı merkezi akışı realtime'a bağlıysa iş alınıp yazdırılamıyor olabilir — DOĞRULANMADI.
- Olası gerçek hata (doğrulanmadı): `claimed_at` yerel saatle UTC gibi yazılıyor (17:42+00, gerçek 14:42 UTC).
- Çevrimdışı sipariş (10-11) ve yeniden bağlanma tekilleştirmesi (12): BAŞLANMADI.

### Çalışır halde bırakılan test süreçleri (elle durdurulmalı)
izole yığın `ibul-iso-staff`, Edge Function 55390, yönlendirici 55400, doğrulayıcı 19210, test köprüsü 18771,
macOS test merkezi (LAN `192.168.10.158:18793`), simülatörde garson uygulaması.

### Commit edilmeyen kod değişiklikleri
`lib/main_seller.dart`, `ibul_app/lib/screens/seller_panel_page.dart` (ret mesajı), `ibul_app/lib/services/restaurant_offline/restaurant_lan_host.dart` (şubesiz masa kuralı).

### Sonraki kesin adım
1) İzole yığına realtime ekle (veya yönlendiricide websocket geçişi) ve `desktop_print_hub.dart` iş alma → köprü gönderim yolunu izle. 2) Tek fiş (27 → 28).
3) Çevrimdışı + tekilleştirme. 4) Mobil hatalar. 5) Ana klasöre aktarım planı (29 + 3 dosya).

## 2026-11-21 (devam 10) — P0 "mutfak fişi çıkmıyor": kök nedenler bulundu, düzeltmeler uygulandı (sonuç tablosu aşağıda güncellenecek)

### Zincir izi (tek iş: `b3a92d07`, Test 71, 18:03:08)
| Geçiş | Durum | Kanıt |
|---|---|---|
| Sipariş → `print_jobs` | PASS | 15:03:08.07 UTC `pending` (1 satır) |
| Hub sahiplenme | PASS (0,3 sn) | `pickup=pending_sweep` (1 sn'lik REST taraması; Realtime YOK iken de çalışıyor), `claimed` |
| Yazıcı çözümleme | **FAIL (sessiz)** | `printer_repository.resolveExpectedKitchenPrinter` → `restaurant_print_station_configs.kitchen_printer_id` sütunu izole fikstürde yok (42703) → istisna |
| Köprü isteği | hiç gönderilmedi | köprü günlüğünde `POST /print/kitchen` yok; sahte yazıcı 27 satır |

### Kök nedenler
1. **Fikstür (izole test altyapısı):** `restaurant_print_station_configs` tablosunda repo göçündeki (`20260427_print_station_architecture`) 10 sütun eksikti
   (yerel staging'de de eksik). İzole DB'ye eklendi (`alter table … add column if not exists`, yalnız 55322).
2. **GERÇEK HATA (ürün):** `desktop_print_hub._dispatchJobAsync` istisnayı `.ignore()` ile yutuyordu. Sahiplenmeden sonra, köprüye gönderimden önce
   atılan her istisna işi sonsuza dek `claimed` bırakıyor, arayüze hiçbir hata yansımıyordu. Düzeltme: bu pencerede çöken iş `failed` + okunur mesaj +
   merkezin başarısız işler listesi (`_failClaimedJobBeforeDispatch`; yalnız `status='claimed'` iken ve köprü çağrısı başlamadıysa — çift baskı riski yok).
3. **GERÇEK HATA (ürün):** `PhysicalPrintGate` (baskı izni) yalnız Satıcı Paneli **Garson** modülü açıkken (30 sn'lik yoklama) güncelleniyordu.
   Merkez başka ekrandayken (Sistem, Genel Bakış…) her fiş "Baskı sistemi kapalı" diye `failed` oluyordu (`cf751229` ile kanıtlı).
   Düzeltme: hub kendi `checkBridge()` sağlık yanıtından izni okuyor (+ ısınmadan hemen sonra bir kez).
4. **GERÇEK HATA (ürün, küçük):** hub `claimed_at/hub_job_received_at/dispatch_started_at/printed_at/completed_at` alanlarına yerel saati
   bölgesiz yazıyordu → DB'de +3 saat (17:42 yerel → `17:42+00`). `toUtc()` eklendi. İşlevsel etkisi bulunmadı (bu alanları okuyan lease/zaman aşımı yok).
   Aynı kalıp `order_print_job_service.dart` 3624/3640/3690/3769'da DURUYOR (düzeltilmedi, kapsam dışı bırakıldı).

### Sorulara yanıtlar
- İşi `claimed` yapan: macOS merkezdeki Dart `DesktopPrintHub` (`claimed_by` boş, `hub_job_received_at` dolu). Köprünün içindeki Python
  `print_station` tüketicisi de aynı kuyruğu yoklayabiliyor (2,5 sn; atomik `pending→claimed` ile tekilleşir); testte `waiting_config` kaldı, iş almadı.
- Lease/zaman aşımı: `claimed` iş için YOK. Tetikleyici `claimed→pending` dönüşünü yasaklıyor (çift baskıya karşı doğru). Uygulama sahiplenme ile gönderim
  arasında kapanırsa iş `claimed` kalır ve görünmez — AÇIK (bu oturumda eklenmedi).
- Realtime: izole yığında servis yok (kong 503), yönlendirici `upgrade` soketini kesiyor. Baskı kuyruğu Realtime'a bağlı DEĞİL (tarama ile alındı).
  Yayın (publication): print_jobs, printers, station_printers, stations.
- Köprü URI/profil: `http://127.0.0.1:18771`, hedef `tcp 127.0.0.1:19100`, doğru.
- Eski worker: yok (canlı 3001 dinlemiyor; tek merkez süreci).

### Test köprüsü güvenliği (repo dışı, `~/IBUL_isolated_build/guarded-bridge/loopback_only_bridge.py`, yedek `.bak-20261121`)
- Merkez `/configure/print-station` ile köprüyü ÇALIŞIRKEN `PRINT_BRIDGE_TRANSPORT=cups` + kuyruk "Zincir Sahte Yazıcı" yapabiliyor (veri klasörü `.env`).
  Sarmalayıcı yalnız soketleri koruyordu; `lp` alt süreci ve USB (pyusb) korumasızdı.
- Eklendi: `lp/lpr/lpadmin/cupsenable…` alt süreçleri reddedilir, `usb` içe aktarılamaz, giden TCP yalnız 127.0.0.1:{19100, 55400, 55321}.
  Öz sınama: `selftest ok`; engeller `blocked_connections.log`'da.

### Sonuç tablosu (devam 10; izole macOS merkez + iOS simülatör garson, sahte yazıcı 19100)
| # | Adım | Sonuç | Kanıt |
|---|---|---|---|
| A3-1/2 | Tek sipariş → tek `print_jobs` | **PASS** | iş `6838ee5d`, sipariş `be05339a` için 1 satır |
| A3-3 | Hub işi aldı | **PASS** | `pickup=pending_sweep`, oluşturma→sahiplenme 0,22 sn (UTC damgalar doğru) |
| A3-4 | Köprü isteği | **PASS** | köprü günlüğü 18:11:08 `POST /print/kitchen 200` |
| A3-5/6 | Sahte yazıcıya veri + tek kesim | **PASS** | kayıt 27 → 28; `bytes=40355, cuts=1`; iş `completed` (toplam ~0,4 sn) |
| A3-7 | Aynı iş yeniden → ikinci fiş yok | **PASS** | `completed→pending` tetikleyicide reddedildi; kopya INSERT atlandı; kayıt 28'de kaldı |
| A3-8 | Köprü kapalı → hata görünür | **PASS** | iş `b874849f` `failed` (takılmadı); merkezde kırmızı "Yazıcı köprüsü çalışmıyor. Fiş basılamaz."; garsonda turuncu uyarı; fiş yok |
| A3-9 | Yeniden açılışta belirsiz işler basılmaz | **PASS** | 3 yeniden başlatma + servis açma; 3 `claimed` + 2 `failed` + 1 `paused` iş basılmadı (kayıt 28) |
| A4 | Çevrimdışı garson siparişi | **FAIL** | yönlendirici (55400) durdurulunca garson: "Sipariş kaydedilemedi. Aynı gönderim tekrar denenebilir."; günlük: `[GarsonSubmit] Bad state: Bu restoran için çevrimdışı veri bulunamadı` |
| A4 | Kalıcılık / tek senkron / tekilleştirme | **BLOCKED** | çevrimdışı sipariş oluşmadığı için sınanamadı. Bulut dönünce: 7 sipariş, 7 ayrı `local_order_id`, fiş 28 (mükerrer yok) |
| A2 | Realtime izole yığına eklendi mi | **YAPILMADI** | teşhis edildi; baskı zincirini engellemediği kanıtlandı; yığın yeniden başlatma riski nedeniyle eklenmedi |

Not: tek fiş PASS'i bir önceki derlemede alındı; son derleme yalnız "izin bilinmiyorsa köprüye bir kez sor" satırını ekler ve bu satır
gerçek bir fişle ayrıca SINANMADI (analyze temiz, ilgili 106 birim testi geçti).

### Çevrimdışı FAIL — bulgu (kök neden KESİNLEŞMEDİ)
- Garson `restaurant_offline_order_router.dispatchOfflineOrder` içinde `_cacheService.read(restaurantId)` boş dönüyor.
- Aday 1: garson sayfası önbelleği `upsertFromSellerPanelState(storeCategory: widget.storeCategory ?? '')` ile yazıyor; kategori boşsa
  `canUseRestaurantPrinterSystem('')` false → hiç yazılmıyor (`restaurant_local_cache_service.dart:64`).
- Aday 2: personel oturumunda bazı sorgular garsonun kendi kullanıcı kimliğiyle (`b8c33b88…`) yapılıyor (`GARSON_ACTIVE_ORDERS_FETCH seller_id=b8c33b88…`);
  önbellek anahtarı işletme kimliği (`7daf9d05…`) ile uyuşmuyor olabilir.

### Bu oturumda görülen, DÜZELTİLMEYEN
- Garson masasında aynı sipariş iki kez listeleniyor (Salon 8: bulutta 1 sipariş, ekranda 2 satır, toplam ₺50) — yerel+bulut kopyası birleştirilmiyor gibi. İncelenmedi.
- Garson uygulaması `http://127.0.0.1:3001/printers` (canlı köprü portu) yokluyor; simülatörde ana makineye gider (yalnız GET, 3001 dinlemiyor).
- `desktop_print_hub._warmPrinterConfigCache` `printers.seller_id` sorguluyor (sütun `restaurant_id`); her açılışta sessizce başarısız. PROJECT_MAP "düzeltildi" diyor, kod öyle değil.
- Köprü kapalıyken işin `last_error` metni yanıltıcı: "Bu rol için yazıcı seçilmemiş" (asıl neden köprü).
- `claimed` işler için lease/operatör görünürlüğü yok (3 eski test işi öyle duruyor; bilerek dokunulmadı).
- Yazıcı Ayarları'nda "Yazıcı bulundu, henüz kayıtlı değil — tcp:192.168.10.100:9100" kartı çıkıyor (GERÇEK yazıcı). **Kaydet'e basılmadı**; kart geç belirip düzeni kaydırıyor.
- Yazıcı Servisi bir kez açıldıktan hemen sonra kendiliğinden kapandı (büyük olasılıkla düzen kayması yüzünden çift tıklama; doğrulanmadı).
- İzole/yerel staging fikstürü repo göçleriyle hizalı değil (`restaurant_print_station_configs` 10 sütun eksikti). Hosted Supabase'de bu sütunların varlığı DOĞRULANMADI.

### Değişen dosyalar (commit YOK)
- `ibul_app/lib/services/desktop_print_hub.dart` (4 düzeltme, yukarıda), `PROJECT_MAP.md` (sözleşme notu), bu dosya.
- Repo dışı: `~/IBUL_isolated_build/guarded-bridge/loopback_only_bridge.py`; izole DB'de `restaurant_print_station_configs` sütunları.

### Çalışır halde bırakılan test süreçleri
izole yığın `ibul-iso-staff`, Edge Function 55390, yönlendirici 55400 (yeniden başlatıldı), doğrulayıcı 19210, sahte yazıcı 19100,
test köprüsü 18771 (korumalı), macOS test merkezi (LAN `192.168.10.158:18793`, günlük: oturum scratchpad `hub3.log`), simülatörde garson (Salon 8 taslağı açık).

### Sonraki kesin adım
1) Çevrimdışı önbellek: garsonda `read(restaurantId)` neden boş — kimlik mi, kategori mi (iki adaydan biri) → dar düzeltme → A4'ü baştan koş.
2) Son derlemede bir fişle "izin bilinmiyor" yolunu doğrula (servisi aç, ilk 30 sn içinde sipariş).
3) Garsonda çift sipariş satırı. 4) İzole yığına Realtime + yönlendiricide `upgrade` geçişi. 5) Aşama 5 işleri (mobil kartlar, Yazıcı Ayarları taşması, Otomatik Tara, alt yönetici arayüz testleri, aktarım planı).

## 2026-11-21 (devam 11) — Çevrimdışı sipariş: kök neden bulundu ve düzeltildi; fiş çevrimdışıyken ÇIKMIYOR (açık)

### Kök neden (GERÇEK HATA, düzeltildi)
`store_service.resolveStoreOwnerIdForCurrentUser`: iki sorgu da internet yokken hata verince fonksiyon oturum açan kullanıcının KENDİ kimliğini
döndürüyordu ("soramadım" = "sahip sensin"). Garson masayı çevrimdışı açınca işletme kimliği `7daf…` yerine garsonun `b8c33b88…` kimliği oluyor,
çevrimdışı önbellek bu anahtarla aranıp bulunamıyor → "Sipariş kaydedilemedi". Yanlış kimlik ayrıca `SharedPreferences`'a da yazılıyordu.
Kanıt: `GARSON_ACTIVE_ORDERS_FETCH restaurant_id` 18:16:16'da `7daf…`, bulut kesildikten sonra 18:16:25'te `b8c33b88…`.
Düzeltme: sorgu çalışamadıysa `null` (bilinmiyor) döner; çağıranlar zaten hatırlanan sahibe düşüyor. Grep testi güncellendi (4/4).

### Çevrimdışı test (yönlendirici 55400 durduruldu, LAN açık) — iki tur
| Adım | Sonuç | Kanıt |
|---|---|---|
| Garson çevrimdışı sipariş gönderir | **PASS** | garsonda "Az önce" sipariş; günlük `restaurantId=7daf…`, `returned_order_status=sent` |
| Merkezde yerel kayıt | **PASS** | Yerel Operasyon → Bekleyen Siparişler: `waiter-1795274568956105…` / `…4854505110…` · `pendingSync` |
| Çevrimdışıyken tek mutfak fişi | **FAIL** | fiş sayısı değişmedi; merkezde "Belirsiz Baskılar … yazıcıya iletilmedi"; garsonda "Mutfak yazdırma için eşleşen yazıcı/istasyon bulunamadı" |
| Bulut dönünce tek sefer senkron | **PASS** | siparişler 7 → 8 → 9, her seferinde ayrı `local_order_id` (9/9) |
| Çift sipariş / çift baskı yok | **PASS** | her çevrimdışı sipariş için bulut dönünce TEK fiş (28 → 29, 29 → 30), `print_jobs completed` 1 → 3 |
| Uygulama kapanıp açılınca kalıcılık | **SINANMADI** | merkez bu turda yeniden başlatılmadı |

### Açık: çevrimdışıyken fiş neden çıkmıyor (kök neden KESİN DEĞİL)
- `restaurant_lan_host._deliverStationJobs` yalnız kalemde/merkez kataloğunda `station_id` varsa yerel baskı işi üretip köprüye yolluyor; yoksa sipariş
  `not_sent` kalır ve tasarım gereği bulut senkronu basar (gözlenen davranış bu). DB'de `products.station_id` DOLU ama merkezde de garsonda da
  kalem `station_id` boş geliyor (`HubStampCache mappingCount=0`, `GroupInput station_id=""`).
- Garson tarafında kaleme istasyon damgalayan bir deneme yapıldı; fiş yine çıkmadı → **geri alındı** (kaynakta yok; simülatörde kurulu derlemede hâlâ var, zararsız).
- Sonraki adım: merkezin yerel önbelleğindeki ürünlerde `station_id` var mı (SecureLocalStore), `SellerProduct.fromMap` → `_productToCacheMap` zinciri.
- Garsondaki uyarı metni LAN yolunda her zaman çıkıyor (`printJobCount: 0` sabit) — fiş basılsa bile yanıltıcı olur.

### Değişen dosyalar (commit YOK) — devam 10'a ek
- `ibul_app/lib/services/store_service.dart`, `ibul_app/test/features/seller/panel/seller_panel_owner_id_resolution_grep_test.dart`.
- Test süreçleri çalışır durumda (yönlendirici 55400 yeniden başlatıldı); merkez LAN `192.168.10.158:18793` açık.

## 2026-11-21 (devam 12) — Çevrimdışı fiş: kök neden bulundu, düzeltildi, zincir PASS

### Kök neden (GERÇEK HATA, düzeltildi)
`store/store_mapping_helpers.mapSnakeCaseToProduct` ürün satırındaki `station_id` (ve istasyon adı/kodu) alanını modele HİÇ taşımıyordu.
Bu yoldan gelen her üründe `stationId` boş → merkezin ve garsonun yerel önbelleğinde ürün-istasyon eşlemesi yok → LAN ile gelen siparişte
`restaurant_lan_host` istasyon bulamıyor, yerel baskı işi üretmiyor, fiş bulut senkronuna kalıyordu. Düzeltme: dört alan eşlemeye eklendi
(`station_id`, `station_name`, `station_code`, `stations`). Yeni test: `test/services/product_mapper_station_test.dart` (2/2).

### Sonuç (son derlemeler: macOS merkez + iOS garson, ikisi de bu düzeltmeyle)
| Adım | Sonuç | Kanıt |
|---|---|---|
| Çevrimiçi tek fiş (regresyon) | **PASS** | 30 → 31; köprü 18:34:11 `POST /print/kitchen 200`; bulut işi `e1505671` `paused_by_operator / local_forwarded` (ikinci baskı yok) |
| Bulut kesik: garson siparişi | **PASS** | yönlendirici 55400 kapalı (`000`), sipariş garsonda "Az önce" |
| Bulut kesik: TEK mutfak fişi, hemen | **PASS** | 31 → 32, 18:34:50, `bytes=40355 cuts=1` |
| Merkez kapanıp açılınca kalıcılık | **PASS** | çevrimdışı soğuk açılış: "Yerel restoran modu · 1 yerel sipariş senkron bekliyor"; fiş 32'de kaldı |
| Bulut dönünce tek sefer senkron | **PASS** | merkez başlatılınca siparişler 10 → 11, 11 ayrı `local_order_id` |
| Çift sipariş / çift baskı yok | **PASS** | bulut işi `2a5c0359` `local_forwarded` olarak park edildi; fiş 32'de kaldı; CUPS kuyruğu boş |

### Bilinmesi gerekenler
- **Davranış değişikliği (çevrimiçi de):** kalemler artık ürünün istasyonunu taşıyor. Fiş, "GENEL / mutfak rolü" yedeği yerine ürünün eşlendiği
  istasyonun yazıcısına gidiyor ve merkez fişi sipariş kabulünde yerelden basıyor (bulut işi park ediliyor). Çok istasyonlu gerçek işletmede fiş hedefleri değişebilir — canlıya almadan önce gerçek cihazda doğrulanmalı.
- Senkron, merkez (Yazıcı Servisi) başlatılana kadar bekliyor; yeniden açılışta merkez kapalı geldiği için operatör başlatmalı (tasarım).
- Garsondaki "Mutfak yazdırma için eşleşen yazıcı/istasyon bulunamadı" uyarısı fiş BASILDIĞI halde çıkıyor (LAN yolunda `printJobCount: 0` sabit) — düzeltilmedi, yanıltıcı.
- Çevrimdışı soğuk açılışta merkez masaları "Boş Masa" gösterdi (bulut dönünce düzeldi) — incelenmedi.
- Yerelden basılan fişin bulut işi `paused_by_operator` durumunda kalıyor (not: `local_forwarded`) — raporlarda "bekleyen" gibi görünebilir.
- `printer_routing_enabled` hâlâ bu eşlemede taşınmıyor (bilerek dokunulmadı; her ürün "yönlendirme açık" sayılıyor).

### Değişen dosyalar (commit YOK) — toplam
`desktop_print_hub.dart`, `store_service.dart`, `store/store_mapping_helpers.dart`, `seller_panel_owner_id_resolution_grep_test.dart`,
`test/services/product_mapper_station_test.dart` (yeni), `PROJECT_MAP.md`, bu dosya.

### Sonraki kesin adım
1) Garsondaki yanıltıcı uyarı. 2) Gerçek iPhone + gerçek yazıcıda aynı zincir (kullanıcı onayıyla). 3) Aşama 5 işleri. 4) Ana klasöre aktarım planı.

## 2026-11-21 (devam 13) — Garsondaki yanıltıcı "yazıcı bulunamadı" uyarısı düzeltildi

- Neden: LAN yolunda `dispatchOfflineOrder` her zaman `printJobCount: 0` döndürüyordu; garson `printJobIds.isEmpty` görüp "Mutfak yazdırma için eşleşen
  yazıcı/istasyon bulunamadı" diyordu (fiş basılsa bile).
- Düzeltme: `PairedLanTransport.lastPrintStatus` merkezin `print_status` yanıtını tutar; yönlendirici `raw['print_status']` olarak iletir;
  `seller_panel_page._feedbackFromDispatchResult` LAN siparişinde `lanTicketStatusText(...)` gösterir (`forwarded` → "Fiş yazıcıya iletildi; basıldığı onaylanmadı").
  `RestaurantLanOrderTransport` arayüzü DEĞİŞMEDİ (mevcut test sınıfı `implements` kullanıyor).
- Doğrulama (arayüz): bulut kesik, Salon 8 → garsonda "Sipariş kaydedildi. Fiş yazıcıya iletildi; basıldığı onaylanmadı."; sahte yazıcı 32 → 33 (tek fiş).
- Testler: yeni `test/services/paired_lan_transport_print_status_test.dart`; ilgili 99 test geçti.
- Dosyalar (commit YOK): `paired_lan_transport.dart`, `restaurant_offline_order_router.dart`, `seller_panel_page.dart`, yeni test.
- Bulut yönlendiricisi (55400) test sonunda yeniden başlatıldı; bu sipariş çevrimdışı olduğu için bulut dönünce senkron bekliyor (merkez servisi açık).

## 2026-11-21 (devam 14) — Aşama 5 (kısmi): mobil kart boşluğu düzeltildi; Yazıcı Ayarları taşması ve Otomatik Tara YENİDEN ÜRETİLEMEDİ; aktarım planı

### Mobil garson masa kartı boşluğu — DÜZELTİLDİ, arayüzde doğrulandı
- `seller_panel_page._mobileGarsonGridAspectRatio`: kart en/boy oranı ~1.0 idi, kart en çok 3 kalem + "+N ürün" gösterirken tek kalemli masada büyük boş blok kalıyordu.
  Yeni oranlar (normal / compact): geniş 1.42 / 1.5, orta 1.32 / 1.4, dar 1.18 / 1.28. iPhone 16 Pro: kart yüksekliği ≈380 → ≈308 px (≈%19 kısa), taşma yok.
- Sınır: en kötü durum (3 kalem + "+N ürün") yaklaşık 250 px içerik; kart ≈308 px. Sistem yazı boyutu büyütülürse taşabilir (BÜYÜK YAZI TESTİ YAPILMADI).
- Kalan: "Boş Masa" kartları aynı oranı kullanır ve hâlâ yüksektir (boş kart için ayrı oran uygulanmadı).

### Yazıcı Ayarları taşmaları — YENİDEN ÜRETİLEMEDİ
- `kitchen_print_management_page_test.dart`'a 7 sekme için dar telefon testi eklendi (390 px, gerçek Roboto yazı tipi yüklenerek). Varsayılan test yazı tipi (Ahem) her harfi 1 em
  genişlikte çizip taşmayı şişirir: ilk koşuda her sekmede 2,3 px (satır 3624, "Yazıcı bulundu, henüz kayıtlı değil" kartı) ve Alanlar'da 89 px (satır 5181 araç çubuğu) çıktı;
  gerçek yazı tipiyle 390/360/320 px ve 1,0/1,3 yazı ölçeğinde SIFIR taşma. Yani bu iki satır YANLIŞ ALARM; kod değişmedi.
- Kapsam dışı kalanlar: `desktop_printer_setup_page`, `printer_wizard`, `printer_quick_setup`, `printer_test_dialog`, `printer_system_setup_wizard` ve Ethernet ekranının dar hali.
  Kullanıcı hangi ekranda/boyutta taşma gördüğünü söylemeli (ekran görüntüsü veya cihaz).
- Test ortam değişkenleriyle ayarlanabilir: `PHONE_W=<px> PHONE_SCALE=<ölçek> flutter test test/screens/kitchen_print_management_page_test.dart --plain-name tasmaz`.

### Otomatik Tara — YENİDEN ÜRETİLEMEDİ (kök neden BULUNAMADI)
- Köprü tarafı: `test_network_scan*.py` + `test_network_transport.py` 24/24 geçti. Arayüz: `ethernet_printer_dialog_test.dart` içindeki 4 tarama senaryosu (başarılı, boş, farklı alt ağ, hata) geçti.
- Telefon yolu (gözden geçirildi, çalıştırılmadı): iOS/Android'de eşleşmemiş cihaz "ana bilgisayar gerekli" (`centerNeededForScan`) der; eşleşmişse `/lan/printers/scan` ile merkezin köprüsüne gider (istemci zaman aşımı 55 sn).
- Gerçek tarama bu oturumda ÇALIŞTIRILMADI: izole köprü 127.0.0.1 dışına çıkamaz (bilerek) ve gerçek ağdaki yazıcıya dokunulmaz. Kullanıcıdan hata metni / cihaz / adım gerekli.
- Ayrı bulgu: `local_print_bridge/tests/test_device_platform.py` `print_station.reported_device_platform` içe aktaramıyor (çalışma ağacındaki değişmiş `print_station.py`'de yok) — bu oturumda dokunulmadı.

### Alt yönetici arayüz testleri — YAPILMADI
- macOS test uygulamasında kullanıcı "Alt Yöneticiler → Personel yetkileri" penceresini elle kullanıyordu; kullanıcının durumuna müdahale edilmesin diye arka plan tıklamaları durduruldu.

### Ana klasöre aktarım için güvenli fark planı (HİÇBİR ŞEY UYGULANMADI; salt okunur karşılaştırma)
Ana klasör: `/Users/barankananogullari/ibul-work`, dal `backup/ibul-work-uncommitted-20261115`, HEAD `9c39dc6`. Çalışma ağacı: dal `claude/ibul-restaurant-completion-e60b65`, HEAD `dbdad86`
(`9c39dc6`'nın soyundan). Kapsam: `ibul_app/{lib,test,supabase,integration_test}`, `lib`, `macos`, `ios`, `android`, `local_print_bridge`, `scripts`, `docs` (build/.dart_tool/.claude-flow hariç):
47 dosya farklı, 7 yalnız çalışma ağacında, 9 yalnız ana klasörde (6'sı derleme artığı: `android/.gradle`, `.kotlin`, `gradlew`, `gradle-wrapper.jar`, `local_print_bridge/.deps`, `.last_kitchen_tcp`).

**A. Ana klasörde TEMİZ (HEAD'den değişmemiş) → doğrudan kopyalanabilir (18 dosya):**
`staff_account_dialog.dart`, `account_security_page.dart`, `settings_page.dart`, `auth_service.dart`, `lan_staff_probe.dart`, `offline_panel_identity.dart`, `paired_lan_transport.dart`,
`20261121090000_staff_owner_only_password.sql` + rollback + `staff_owner_only_password_test.mjs`, `staff_gate_permissions_test.dart`, `offline_identity_seal_test.dart`,
`offline_panel_identity_test.dart`, `order_update_and_staff_guards_test.dart`, `seller_lan_center_test.dart`, `staff_login_policy_test.dart`, `staff_store_access_test.dart`,
`scripts/rehearse_order_rpc_migration.sh`, `docs/RESTAURANT_PILOT_PROGRESS.md`.

**B. Ana klasörde DE DEĞİŞMİŞ → 3'lü birleştirme gerekir, KÖRLEMESİNE ÜZERİNE YAZMA (13 dosya):**
`seller_panel_page.dart` (ana klasör +967/−230 vs HEAD), `desktop_print_hub.dart` (+155/−40), `store_service.dart` (+48/−4), `store/store_mapping_helpers.dart`, `restaurant_offline_order_router.dart`,
`restaurant_lan_host.dart`, `staff_login_policy.dart`, `staff_team_panel.dart`, `manage-restaurant-staff/index.ts`, `lib/main_seller.dart`, `seller_panel_owner_id_resolution_grep_test.dart`,
`kitchen_print_management_page_test.dart`, `restaurant_lan_host_test.dart`. Yöntem: `git diff 9c39dc6 -- <dosya>` ile ana klasörün yerel değişikliğini çıkar, çalışma ağacı sürümüne yeniden uygula; her dosya için `flutter analyze` + ilgili test.

**C. Yalnız çalışma ağacında (yeni; kopyalanır, 7 dosya):** `20261121100000_staff_access_revocation.sql` + rollback, `20261121_staff_legacy_classification.sql` (diagnostics), `paused_job_semantics.sql`,
`staff_edge_function_http_test.mjs`, `paired_lan_transport_print_status_test.dart`, `product_mapper_station_test.dart`. (+ izlenmeyen: `docs/PILOT_REAL_DEVICE_LAN_TEST_PLAN.md`, `print_agent_starter.dart`, `print_job_payload_identity.dart`,
`print_service_start_gate.dart`, `printer_readiness.dart`, `lan_*`/`offline_identity_seal`/`restaurant_center_*`/`seller_lan_center`/`waiter_lan_link` vb.: aktarılacak tam liste `git ls-files --others --exclude-standard` ile çıkarılmalı; ana klasörde bu yollar YOK.)

**D. Yalnız ana klasörde — ÇAKIŞMA RİSKİ (3 dosya):** `staff_password_change_dialog.dart`, `staff_password_change_dialog_test.dart`, `staff_password_change_policy_test.dart`.
Çalışma ağacı "yalnız işletme sahibi şifre belirler" tasarımına geçti (migration `…090000_staff_owner_only_password`) ve bu iletişim kutusunu içermiyor. Aktarımdan ÖNCE karar: ana klasördeki bu 3 dosya silinecek mi, korunacak mı? (Silmek geri dönüşsüzdür; önce yedekle.)

**E. Aktarılmaz / gürültü:** `test/screens/failures/*.png` (12 test hata görüntüsü), `ios/Flutter/Generated.xcconfig`, `flutter_export_environment.sh`, `macos/Podfile.lock`, `.claude-flow/*`, derleme artıkları. `Podfile.lock` farkı gerçek mi (macOS derlemesi) ayrıca incelenmeli.

**Sıra (öneri):** (1) ana klasörü yedekle (`git stash` KULLANMA; dalı zaten yedek dal: `git worktree`/`cp -R` ile kopya); (2) A+C'yi kopyala; (3) B'yi dosya dosya birleştir; (4) D kararı; (5) `flutter analyze && flutter test` + `cd restaurant-ops-web && npm run build` + `cd local_print_bridge && python -m pytest`;
(6) SQL'ler önce izole yığında (`chain.sh`), sonra staging'de; production'a dokunulmaz. Çalışma ağacında kaydedilmemiş toplam 240 yol var (143 değişmiş, 97 izlenmeyen) — bu oturumun dışındaki çalışmaları da içerir.

### Değişen dosyalar (bu tur, commit YOK)
`seller_panel_page.dart` (kart oranları), `kitchen_print_management_page_test.dart` (7 dar ekran testi), `docs/RESTAURANT_PILOT_PROGRESS.md`.

## 2026-11-21 (devam 15) — Gerçek hesap turu: ortam doğrulaması ve Otomatik Tara kök nedeni

### Ortam doğrulaması (GERÇEK HESAPLAR İÇİN ENGEL)
- Çalışan macOS uygulaması `IbulSellerDesktopTest` (`Debug-Offlinetest`) İZOLE derlemedir: `AppRuntimeConfig.resolveSupabaseValue` supabase.co adreslerini ve üretilmiş (generated) yapılandırmayı reddeder (`isolated_refused`). Bu derlemede `ozcanduymaz@…` / `efeknn@…` ile giriş **yapılamaz**; bu bilerek böyledir.
- Gerçek hesaplar için production'a bağlı, yazdırma açık bir derleme gerekir. Bu derleme canlı köprüyü (3001) ve yazıcı hub'ını başlatıp production `print_jobs` kuyruğunu sahiplenebilir → gerçek müşteri fişi basma riski. Kullanıcı kararı bekleniyor; hiçbir production bağlantısı kurulmadı.

### Otomatik Tara — kök neden (kanıtlı)
1. Test uygulamasındaki başarısızlık: test köprüsü (`loopback_only_bridge.py`, 18771) her loopback-dışı bağlantıyı reddediyor (`blocked_connections.log`: 192.168.10.x:9100 BLOCKED). `/printer/tcp/scan` `ok:true, devices:[]` ve "Aynı ağda port 9100 açık cihaz bulunamadı" döndü. Yani test uygulamasında tarama tasarım gereği yazıcıyı bulamaz.
2. Gerçek köprü taraması macOS ana bilgisayarda ÇALIŞIYOR: `scan_local_network_printers(['192.168.10.158'])` 3/3 koşuda `192.168.10.100:9100` bulundu, ESC/POS durum yanıtıyla doğrulandı, 0,75 sn. `nc -z 192.168.10.100 9100` açık. (Yalnız bağlantı + salt-okunur durum sorgusu; fiş basılmadı.)
3. Gerçek ürün hatası (düzeltildi): `_probe_tcp_port` her `OSError`'ı "port kapalı" sayıyordu. macOS Yerel Ağ izni yokken her LAN adresi `EHOSTUNREACH` verir ve arayüz "yazıcı yok" derdi. Şimdi engellenen yoklamalar (`EHOSTUNREACH/ENETUNREACH/ENETDOWN/EPERM/EACCES`) sayılır; hiç cihaz yok ve engellenen ≥ kapalı ise `no_device_reason=local_network_blocked` ve gerçek neden metni döner. Genel "Beklenmeyen hata" değil.
- Testler: `local_print_bridge/tests/test_network_scan_blocked.py` (2/2) + mevcut tarama/ağ testleri geçti. Dart tarafı değişmedi (sunucu mesajını gösteriyor).
- Dosyalar (commit YOK): `local_print_bridge/network_scan.py`, `local_print_bridge/server.py`, yeni test, bu dosya.

### Durum tablosu (bu tur)
| Test | Sonuç |
|---|---|
| Gerçek işletme sahibi girişi | **BLOCKED** (izole derleme production'ı reddeder; production derleme kararı bekliyor) |
| Gerçek alt yönetici girişi | **BLOCKED** (aynı) |
| Otomatik Tara (köprü, gerçek LAN) | **PASS** (köprü düzeyinde; arayüzden gerçek eklemeye geçilmedi) |
| Yazıcıyı arayüzden ekleme | **BLOCKED** (arayüz için production/eşleşmiş derleme gerekir; Kaydet'e basılmadı) |
| Fiziksel baskı / süre ölçümü | **BLOCKED** (kullanıcı onayı yok) |
| İnternetsiz gerçek test | **BLOCKED** (WAN kesme onayı yok) |

## 2026-11-21 (devam 16) — RealTest derlemesi (production'a bağlı, yazdırma KAPALI) hazır

- Derleme: `~/IBUL_isolated_build/DerivedDataRealPrintOff/Build/Products/Debug-Offlinetest/IbulSellerDesktopTest.app`; `BUILD SUCCEEDED`, bundle `com.ibul.sellerdesktop.realtest`, imza geçerli (takım B4849QMKTU, sandbox kapalı, keychain grubu realtest). Dart tanımları: `IBUL_DISABLE_PRINT_START=true`, izole mod YOK, Keychain hesabı `ibul.sellerdesktop.realtest`, LAN 18793. Çekirdekte yalnız production Supabase adresi (`ihmixxzqnpamcwmrfibx`), yerel 54321 yok.
- İlk derleme `/Volumes/IBULBuildAPFS` biriminin derleme sırasında kaybolmasıyla `clang` çöküşüyle düştü; artık ana diskte derleniyor, birime bağımlılık yok.
- Açık kapatıldı: yazdırma kapalı + izole olmayan derleme `127.0.0.1:3001` (canlı köprü) adresine gidebiliyordu (hub/köprü başlatma/istasyon servisi zaten kapalıydı; elle test baskısı ve doğrudan köprü çağrısı açıktı). `AppRuntimeConfig.localPrintBridgeUri/coercePrintBridgeUri` artık bu durumda ölü probe adresine (`127.0.0.1:9`) yönlendirir; 18771 test köprüsü istisnası korunur. Test: `runtime_config_resolution_test.dart` 38/38 (3 yeni; eski bir beklenti güncellendi).
- Durum: uygulama açıldı, 3001'de dinleyen yok, köprü/hub başlamadı. Giriş bekleniyor (şifreleri kullanıcı yazar). Commit YOK.

### Gerçek hesap turu (RealTest, production, yazdırma KAPALI) — ilk sonuçlar
- İşletme sahibi girişi: **PASS** (mağaza "destina", Satıcı ID 7264153b…; Alt Yöneticiler sayfası okundu, 4 personel: baran aktif; garson11, efe, gulsen pasif). Hesabın e-postasının `ozcanduymaz@gmail.com` olduğu arayüzden doğrulanamadı (üst çubukta yalnız mağaza adı var).
- Alt yönetici `efeknn@gmail.com` (efe, listede PASİF): **FAIL (arayüz kapısı)** — giriş oturum açtı ve "Satıcı Paneli · efe" kabuğu açıldı (kenar çubuğunda yalnız Garson, "Mağaza profili yüklenemedi", Satıcı ID 2e2f1814…, 0 masa). Mağaza verisi/masa görünmedi (veri PASS), ama pasif hesap net bir "pasif" reddi yerine boş kabuk görüyor. Olası neden (DOĞRULANMADI): `resolveStaffLoginAccess` yalnız `managedStaffFlag` + erişim yok iken "hesap pasif" mesajı veriyor; efe için bayrak production'da yoksa düz kullanıcı gibi geçiyor. `20261121100000_staff_access_revocation.sql` production'a UYGULANMADI (yasak).
- Hiçbir production kaydı değiştirilmedi; sipariş/fiş yok.
- Production salt-okunur doğrulama (efe): `store_sub_admins.status='inactive'`, `managed_restaurant_staff=true`, Auth hesabı yasaklı DEĞİL, sahip olduğu mağaza yok. Yani menü kapısı ESKİ kodda da `revoked` döndürüyordu (veri sızmadı); asıl kusur arayüz: `revoked` iken Garson modülü (mağaza profili korumasının dışında) boş "Henüz tanımlı masa yok" listesiyle açık kalıyordu ve net "pasif" mesajı yoktu. Pasif hesap Auth düzeyinde oturum açabiliyor (tasarım: üyelik durumu panelde kontrol ediliyor).
- Düzeltme (commit YOK): `seller_panel_page.dart` `_buildStaffAccessRevokedPanel` — gate `revoked` ise hem masaüstü (`_buildContent`) hem mobil (`_buildMobileContent`) tüm modüller yerine "Hesabınız pasif" kartı gösterir. Arayüzde DOĞRULANMADI (yeniden derleme gerekir); widget testi yazılmadı. `resolveStaffMenuGate` (önceki düzeltme) bayraksız eski hesaplar için ek savunma.
- Arayüz doğrulaması (yeniden derlenen RealTest, efe pasif): **PASS** — giriş sonrası tüm modüller yerine "Hesabınız pasif — Bu personel hesabının işletme erişimi kapatılmış…" kartı, kenar çubuğunda yalnız Çıkış Yap. Kalan küçük kusur: üst çubukta hâlâ "Mağaza profili yüklenemedi" yazıyor (pasif hesap için yanıltıcı). Aktif alt yönetici izin/masa testleri hâlâ BLOCKED (hesap pasif; aktifleştirme onayı yok).
- Düzeltme (kod, commit YOK): `resolveStaffMenuGate` (`staff_login_policy.dart`) — üyelik satırı VAR ama `active` değilse, `managed_restaurant_staff` bayrağı olsun olmasın `revoked` döner (önceden bayraksız hesap `owner` menüsüne düşüyordu). `AuthService.loadStaffMenuGate` buna bağlandı. 5 yeni test. DOĞRULANMADI: efe'nin production satırının gerçek durumu (satır görünmüyorsa veya `status=active` ise bu düzeltme tek başına yetmez); yeni derlemeyle arayüzde yeniden denenmeli. Sağlam kapı için giriş anında reddetme ayrı iş.

## 2026-11-21 (devam 17) — P0-2 KÖK NEDEN: alt yönetici yalnız Garson görüyordu (istemci düzeltildi); P0-1 giriş kapısı

### P0-2 kök neden (kanıtlı, kod okuma + birim testi)
- `manage-restaurant-staff` (create) bütün personele `users.role = 'waiter'` yazıyor (`index.ts` ~satır 490), alt yönetici dahil.
- `AuthService.resolveLoginRoute` bu rolü `LoginResolvedRole.waiter` yapıyor; `seller_login_page.dart` bunu **koşulsuz** `SellerPanelEntryRole.waiter` ile açıyor;
  panelde `_isWaiterEntry` → `visibleSellerModules(garsonOnly: true)` yalnız `[garson]` katalogu verir. Sahibin kaydettiği `visible_modules`/izinler hiç uygulanmıyordu.
- Düzeltme (istemci, commit YOK): `staffGateIsGarsonOnly(gate)` (`staff_login_policy.dart`) — Garson'a kilit yalnız üyelik yalnız `garson` sayfası verdiyse (veya sayfa kaydı yok ve rol `waiter` ise).
  `seller_login_page.dart` waiter dalı artık önce `loadStaffMenuGate()` okur; `seller_panel_page.dart` `_isWaiterEntry` kapıya bağlandı (oturum geri yükleme yolu dahil).
- Sayfa görme / işlem yetkisi ayrımı: değişmedi (`visible_modules` sayfayı, `permissions` işlemi belirler; Tam Erişim `manageStaff` ve `manageStoreProfile` vermez).
- Testler (BİRİM): yeni `test/features/staff_entry_garson_pin_test.dart` 4/4 + `staff_gate_permissions_test.dart` geçti. `flutter analyze` değişen dosyalarda yeni uyarı yok.

### P0-1 giriş kapısı
- Pasif üyelikli personel artık `seller_login_page` waiter dalında oturum açıldıktan hemen sonra `signOutSeller()` + "Hesabınız pasif" ile reddedilir (önceden boş "Garson" kabuğu açılıyordu).
- Kapı okunamazsa (ağ hatası) giriş reddedilir, açık bırakılmaz.
- SUNUCU KATMANI: `20261121100000_staff_access_revocation.sql` yalnız yerel/izole; production'a UYGULANMADI (yasak). Doğrudan RPC/LAN/RLS reddi bu turda yeniden KANITLANMADI.
- 12 saatlik çevrimdışı mühür iptal gecikmesi: anında iptal KANITLI DEĞİL → PASS DENMEZ.

### Durum tablosu (bu tur)
| Madde | Etiket | Sonuç |
|---|---|---|
| P0-2 alt yönetici tüm izinli sayfaları görür (mantık) | birim testi | PASS |
| P0-2 gerçek Satıcı girişi, gerçek uygulama | gerçek uygulama | **BLOCKED** (yeniden derleme + onaylı hesap gerekli; yapılmadı) |
| P0-1 pasif personel girişte reddedilir | birim/kod | KOD HAZIR; gerçek uygulama **BLOCKED** |
| P0-1 doğrudan RPC / LAN / eski oturum | sunucu | **BLOCKED** (migration production'da yok; bu turda izole yığın koşulmadı) |
| P0-1 12 sa çevrimdışı mühür iptali | — | **FAIL/AÇIK** (anında iptal kanıtlanmadı) |
| P0-3…P0-7 | — | Bu turda DOKUNULMADI (önceki turların kayıtları yukarıda; yeniden doğrulanmadı) |

### Değişen dosyalar (commit YOK)
`lib/services/staff_login_policy.dart`, `lib/screens/seller_login_page.dart`, `lib/screens/seller_panel_page.dart` (`_isWaiterEntry`), yeni `test/features/staff_entry_garson_pin_test.dart`, bu dosya.

## 2026-11-21 (devam 18) — Kapat butonu kök nedeni, RealTest yapılandırma kök nedeni

- RealTest "Yapılandırma Eksik" kök nedeni: `macos` `Debug-Offlinetest` yapılandırması `DART_DEFINES`'a `IBUL_ISOLATED_DESKTOP=true` ekliyor; izole mod üretilmiş Supabase yedeğini okumaz. RealTest derlemesi bu tanımı komut satırında geçersiz kılmalı (URL/anahtar `generated_runtime_config.g.dart`'tan, loglanmadan). Derleme betiği scratchpad'de; ekran doğrulaması yapılamadı (erişim reddedildi).
- Kapat (garson masa kartı) kök nedeni: düğme `_staffHas('closeBill')` ile açılır. Production'daki etkin alt yöneticinin kaydında `closeBill`, `transferTable`, `takePartialPayment`, `splitBill` YOK (yalnız sayfa görünürlüğü var). Yani gri olması izin modeline göre doğru; eksik olan sebep metniydi. Düzeltme: `tableCloseDisabledReason` (`staff_login_policy.dart`) + kart Kapat düğmesinde Tooltip (dokunmayla açılır). Menü/izin modeli değişmedi, paralel yetki yok. Test: `test/services/table_close_disabled_reason_test.dart` 3/3.
- Sunucu (izole `ibul-iso-staff`, geri alınan işlem): `closeBill`'siz alt yönetici → 42501 "Bu işlem için yetkiniz yok"; `closeBill`'li alt yönetici ve `closeBill`+`manageOrders` garson → `close_table_with_history` başarılı. Not: izole veritabanı 20261121090000 öncesi şemada; `staff_must_change_password` işlem içinde "oturum geçerli" olarak değiştirildi (geri alındı).
- Yazıcı Merkezi izole arayüz akışı (Başlat/Tara/Ekle/Eşle/Sipariş/Tek fiş/Durdur/Yeniden başlat): YAPILMADI (BLOCKED, uygulama ekranına erişim yok). Fiziksel 192.168.10.100:9100 testi ayrı, onay bekliyor. Commit YOK.

## 2026-11-21 — P0: Yazıcı Servisi başlatma (gerçek com.ibul.sellerdesktop Release)

| Özellik | Kök neden | Gerçek uygulama sonucu | Durum |
|---|---|---|---|
| Yazıcı Servisi → Başlat | Release paketinde canlı ajan kapalıydı; SMAppService sandbox'ta reddedilir; sayfa gerçek hatayı yutuyordu | Paket içi imzalı yardımcı (sandbox inherit) başlar; 3001'de tek köprü, /health ok | PASS |
| Durdur / yeniden Başlat | — | Süreç ve port kapanır; yeniden başlatınca tek yeni süreç | PASS |
| Çıkış ve yeniden açılış | — | Çıkış köprüyü kapatır; açılışta servis kapalı | PASS |

Kalan risk: "Yazıcı köprüsü kapalı" rozeti Başlat sonrası bayat kalıyor; "1 yerel sipariş senkron bekliyor" henüz incelenmedi; fiziksel test fişi ve P1–P5 yapılmadı. Backend (Supabase) bu aşamada değiştirilmedi.


## 2026-11-21 — P1 (kısmi): tarama, kayıt, eşleştirme

| Özellik | Kök neden | Değişen dosyalar | Gerçek uygulama sonucu | Durum |
|---|---|---|---|---|
| Başlat sonrası rozet "köprüsü kapalı" | Hub 30 sn'lik yoklamayı bekliyordu | `kitchen_print_management_page.dart` (`checkBridge` anında) | Başlat'tan 9 sn sonra "Yazıcı doğrulanmadı" | PASS |
| Otomatik Tara ilk denemede boş | Soğuk ağda 0,18 sn bağlantı zaman aşımı; yazıcı gerçekte erişilebilir (ping 2,6 ms) | `local_print_service.dart` (boş sonuçta bir kez tekrar) | Yeni derlemede ilk tıkta "1 doğrulanmış yazıcı", 192.168.10.100:9100 | PASS (tek gözlem) |
| Aynı yazıcı ikinci kez kaydı | Yalnız ad/kod çakışması denetleniyordu | `printer_ethernet_dialog.dart` (host:port koruması) | Ekranda Kaydet denenmedi (gerçek kaydı değiştirebilir) | Kodlandı, ekranda doğrulanmadı |
| Eşleştirme | — | — | Adisyon/Mutfak/kasap/Ocak/fırın hepsi `aa`; çelişki yok; "yeni alna" atanmamış | PASS (salt-okunur) |
| Test fişi | — | — | Kullanıcı onayıyla 1 mutfak TEST fişi (23:28): Print Log `role_test_print_success`, printer=aa 192.168.10.100:9100, 854 bayt yazıldı, köprü `completed`. Kâğıt çıktısını ekrandan doğrulayamam (TCP yazımı kâğıt kanıtı değildir) | PASS (köprü kaydı) / kâğıt: kullanıcı teyidi bekliyor |
| Derleme imzası | Artımlı derlemede gömme betiği kütüphaneleri yeniden imzalıyor, dış mühür bozuluyor | `embed_print_bridge_macos.sh` (damga ile dokunma) | Bu kopya elle yeniden mühürlendi, imza geçerli | PASS |

## 2026-11-21 — P2: alt yönetici / `managePrintSettings` (salt-okunur inceleme)

| Özellik | Kök neden | Durum |
|---|---|---|
| Flutter kapıları | Sayfa görünürlüğü (`_actorMaySeePrinterSettings`), merkez başlatma (`decideRestaurantCenterAccess`) ve LAN yetki probu `managePrintSettings` ister; yetki yükseltme yok | PASS (kod + 28 test) |
| Sunucu: `printers`, `stations`, `station_printers` | Canlı pg_policies: yalnız sahip yazabiliyor; `managePrintSettings` personeli sayfayı görür ama yazıcı ekleme/eşleştirme 42501 | **FAIL** (düzeltme hazır, uygulanmadı) |
| Sunucu: `restaurant_print_station_configs` | `user_can_access_restaurant` = `manageOrders` VEYA `viewOrders`: yalnız sipariş gören personel yazıcı servisini değiştirebiliyor, `managePrintSettings` olan yazamıyor (ters hizalama) | **FAIL** (düzeltme hazır, uygulanmadı) |
| Düzeltme | `supabase/migrations/20261122090000_print_settings_staff_permission.sql` — üretime UYGULANMADI, onay bekliyor. Okuma politikaları değişmez, başka izin verilmez | BLOCKED (onay) |
| Gerçek ekranda alt yönetici testi | Test personel hesabı oluşturmak/yetki vermek canlı personel verisini değiştirir; yapılmadı | BLOCKED |

## 2026-11-21 (gece) — CHECKPOINT: çalışan sürüm güvenceye alındı (kod değişmedi, migration/deploy/derleme YOK)

- Anlık görüntü: dal `checkpoint/restaurant-working-20261121`, etiket `ibul-restaurant-checkpoint-20261121` (ebeveyn `dbdad86`); çalışma ağacı/indeks/dal değişmedi.
- Repo dışı yedek: `~/IBUL_checkpoints/20261121-restaurant-working/` (bundle, yamalar, izlenmeyen dosyalar, ana klasörün commit edilmemiş işi, manifest). Gizli bilgi yok.
- Gerçek uygulama: `com.ibul.sellerdesktop` Release, imza `--deep --strict` OK (Apple Development, `B4849QMKTU`, noter yok), köprü 3001 canlı; kayıt sırasında dokunulmadı.
- Tam kayıt ve PASS/FAIL/BLOCKED tablosu: `docs/RESTAURANT_WORKING_CHECKPOINT.md`.
- **P2 açık blokaj:** `20261122090000_print_settings_staff_permission.sql` production'a UYGULANMADI (iki istek declined). Başka araçla/doğrudan SQL ile aşılmadı. Çözüldü DEĞİL.
- Bu kayıtta `flutter analyze/test` yeniden koşulmadı; yukarıdaki sayılar önceki kayıtlardan.
- Sonraki sıra: P0 → P1 → P2 (onay bekliyor) → P3 → P4 → P5.

## 2026-11-21 (gece 2) — P1 gerçek uygulamada (com.ibul.sellerdesktop Release), kullanıcı onaylı tek test fişi

- Sistem → Yazıcı Ayarları: Yazıcı Servisi açık, rol "Yazıcı merkezi", 1 kayıtlı yazıcı "aa" (192.168.10.100:9100).
- Otomatik Tara (ekran): "1 doğrulanmış yazıcı bulundu" 192.168.10.100:9100 (Bilgisayar IP 192.168.10.158, ağ 192.168.10.0/24) → PASS (gerçek uygulama).
- Yazıcı Kaydet: BASILMADI — aynı adreste "aa" kayıtlı, çift kayıt olurdu; kullanıcı yalnız test fişi onayı verdi. Yazıcı sayısı 1'de kaldı.
- Eşleştirme (salt-okunur, değiştirilmedi): adisyon/mutfak/kasap/Ocak/fırın = aa; "yeni alna" atanmamış.
- Kontrollü test fişi: "Mutfak Genel Test Fişi" TEK kez. İlk tık düzen kayması yüzünden boşa düştü (Print Log'da olay yok, köprüde POST yok); ikinci tık: toast "Mutfak Genel test fişi gönderildi."
  Köprü: 23:44:48 `POST /print/test 200`, `queue_status=completed`, `success=True`, 854 bayt, hedef tcp:192.168.10.100:9100. Önceki test 23:28:00 → toplam 2 fiş.
- **Kâğıt çıktısı DOĞRULANMADI** (completed + bayt sayısı fiziksel baskı kanıtı değildir). Kullanıcı teyidi bekleniyor.
- Gözlem: sayfa sekme geçişinde yatay kayıyor, tıklama zamanlaması bozuyor. Köprü kaydı "isStaleSavedMapping=True / bağlantı test edilmedi" meta alanı taşıyor (yazma başarılıydı).
- P2 migration production'a UYGULANMADI, çözülmedi.

### Kâğıt teyidi (kullanıcı beyanı, 2026-11-21 gece)
Kullanıcı, 23:44:48'deki "Mutfak Genel Test Fişi"nin kâğıt çıktısının geldiğini bildirdi. Kanıt türü: kullanıcı gözlemi (kayıtlı fotoğraf/ölçüm yok) + köprü `completed` kaydı (854 bayt).
Bu iki kanıt birlikte P1 gerçek yazıcı test fişi için **PASS** (fiziksel baskı, tek fiş). 23:28'deki önceki fişin kâğıt çıktısı ayrıca teyit edilmedi.
Hâlâ açık: yazıcı Kaydet (arayüz) denenmedi, eşleştirme değişikliği denenmedi, P2 production migration UYGULANMADI/çözülmedi.

## 2026-11-22 — P0: Production Supabase SALT-OKUNUR doğrulama (yazma yok)

Proje `ihmixxzqnpamcwmrfibx`. Yalnız SELECT / katalog sorgusu çalıştırıldı; production'a hiçbir şey uygulanmadı.

| Nesne | Production gerçeği | Sonuç |
| --- | --- | --- |
| Migration geçmişi | Yalnız `remote_commit` + `20261120090000_lan_staff_authority` kayıtlı | SQL Editor uygulamaları geçmişe işlenmemiş (drift) |
| `staff_credentials` (epoch, sessions_valid_after, banned_by_policy) | VAR; hiçbir personelde satır yok (epoch=0 sayılır) | Uygulanmış |
| `owner_set_staff_password`, `guard_managed_staff_*`, `staff_membership_revoke_on_change`, auth.users/identities/one_time_tokens tetikleyicileri | VAR | `20261121090000/100000` büyük ölçüde uygulanmış (checkpoint "UYGULANMADI" diyordu: GÜNCEL DEĞİL) |
| `lan_staff_authority` | VAR, `credential_epoch` döndürüyor, yalnız sahip (auth.uid()=restaurant_id) çağırabilir | Uygulanmış |
| Edge Function `manage-restaurant-staff` | v6 ACTIVE (yerel kaynakla eşleşmesi doğrulanmadı) | Doğrulanacak |
| `printers` RLS | yazma yalnız `auth.uid()=restaurant_id` (sahip); alt yönetici SELECT | **managePrintSettings alt yöneticisi yazamaz — `20261122090000` UYGULANMAMIŞ** |
| `restaurant_print_station_configs` RLS | `user_can_access_restaurant` = manageOrders OR viewOrders | **Yanlış izne bağlı (managePrintSettings değil)** |
| `print_jobs` | benzersiz mantıksal anahtar tetikleyicileri (`stamp_print_job_logical_key`, `skip_duplicate_print_job`) | Mevcut |
| `orders` | UNIQUE (restaurant_id, local_order_id) | Çevrimdışı mükerrer koruması VAR |

### P4 — Masa aktarımı: güçlü kök neden adayı (izole DB'de doğrulanacak)
`transfer_table_orders` (SECURITY DEFINER) tam aktarımda `orders.table_id` günceller. `orders` üzerindeki
`restaurant_staff_write_guard` (`guard_restaurant_staff_order_write`) yönetilen personel için `table_id` değişimini
koşulsuz "İşletme veya masa kimliği değiştirilemez" (42501) ile reddediyor; `auth.uid()` DEFINER içinde de personeldir.
Sahipte tetikleyici geçtiği için hata yalnız alt yöneticide görünür; `transferTable` yetkisi kaydı doğru olsa bile aktarım düşer.
Düzeltme taslağı: tetikleyicide, RPC'nin ayarladığı işlem-yerel GUC (örn. `ibul.table_transfer_rpc`) ile yalnız `table_id`
değişimine izin ver (kimlik/restaurant_id değişimi yine yasak). Henüz yazılmadı.

### P1 — "Personel yetkisi doğrulanamadı"
`lan_staff_authority` production'a ancak 2026-11-21 21:20'de uygulanmış; önceki hata büyük olasılıkla fonksiyonun yokluğuydu.
Mevcut SQL tarafı tutarlı (aktif alt yönetici: managed=true, must_change boş→false). Gerçek iPhone'la yeniden denenmeden PASS DEĞİL.

### Onay gerektiren production değişiklikleri
1. `20261122090000_print_settings_staff_permission.sql` (yazıcı RLS).
2. Yeni migration: masa aktarımı tetikleyici düzeltmesi (önce izole prova).
Declined edilen kapılar aşılmadı.

### 2026-11-22 — `20261122090000` production'a uygulandı (kullanıcı, SQL Editor) — SUNUCU POLİTİKA DOĞRULAMASI PASS
Araç (`apply_migration`) iki kez declined; kapı aşılmadı, kullanıcı dosyayı SQL Editor'de çalıştırdı.
`pg_policies` salt-okunur kontrol: `printers/stations/station_printers/restaurant_print_station_configs` için `*_print_settings_write`
(managePrintSettings) VAR; `restaurant_print_station_configs_owner_all` KALKTI; `*_owner_all` (printers/stations/station_printers) ve
`*_waiter_select` yerinde. Henüz DOĞRULANMADI: gerçek alt yönetici hesabıyla ekran testi (hesap aktif ve `managePrintSettings` izinli olmalı).
Migration geçmişi tablosuna kayıt düşmedi (SQL Editor) — drift notu geçerli. Rollback: `ibul_app/supabase/rollbacks/20261122090000_print_settings_staff_permission_rollback.sql`.

## 2026-11-22 — P4 Masa aktarımı: kök neden KANITLANDI, düzeltme izole DB'de PASS (production'a UYGULANMADI)
- Yeniden üretim (izole `ibul-iso-staff`, rollback'li işlem): `transferTable` izinli aktif alt yönetici, `transfer_table_orders` → 42501
  "İşletme veya masa kimliği değiştirilemez" (`guard_restaurant_staff_order_write`, `orders.table_id` değişimi). İzin, oturum, masa erişimi doğruydu.
- Düzeltme: `ibul_app/supabase/migrations/20261122100000_table_transfer_staff_guard.sql` (+ rollback). Yalnız RPC'nin işlem-yerel
  işaretiyle, `transferTable` + eski/yeni masa erişimiyle, yalnız `table_id`/`updated_at` değişiyorsa izin verir; manageOrders gerekmez.
- İzole test (hepsi rollback'li): pozitif aktarım PASS (2 sipariş taşındı, durum ve tutar aynı); negatif N1–N6 hepsi REDDEDİLDİ
  (işaretsiz doğrudan, sahte işaret+status, sahte işaret+restaurant_id, transferTable yok RPC/doğrudan, garson). Rollback gövdesi production'daki
  guard ile bayt-bayt aynı (md5 001a41d3…), `transfer_table_orders` production ile aynı (md5 14bdf8bb…).
- Doğrulanmadı: production'da gerçek alt yönetici ekran testi, kısmi aktarım yolu, `table_payments` güncellemesi (izole testte geçti),
  baskı işlerinin aktarım sonrası davranışı (izole veride print_jobs yok).

### 2026-11-22 — `20261122100000` production'a uygulandı (kullanıcı, SQL Editor) — KATALOG DOĞRULAMASI PASS
`guard_restaurant_staff_order_write` içinde `ibul.staff_table_transfer_rpc` dalı VAR (1); `transfer_table_orders` (8 argümanlı) içinde işaret 2 kez (aç/kapat);
5 tablodaki `restaurant_staff_write_guard` tetikleyicileri etkin. Doğrulanmadı: gerçek alt yönetici ile gerçek uygulamada aktarım (test masası gerekir; gerçek müşteri masası değiştirilmeyecek).
Rollback: `ibul_app/supabase/rollbacks/20261122100000_table_transfer_staff_guard_rollback.sql`.

## 2026-11-22 — P2 Sipariş gönderme gecikmesi (KISMİ: sunucu/ağ ölçüldü, gerçek uygulama p50/p95 ÖLÇÜLMEDİ)
Ölçülenler (üretime sipariş yazılmadı):
- Sunucu `create_table_order_with_print_jobs` (izole PG, rollback'li, RLS+guard tetikleyicileri dahil, n=40, 2 kalem): sahip p50 0,7 ms / p95 1,8 ms; alt yönetici p50 1,4 ms / p95 2,7 ms.
- Production ağ RTT'si bu Mac'ten (Supabase ap-southeast-1, bağlantı yeniden kullanımıyla, n=20): p50 45 ms, p95 61 ms; yeni bağlantı ~136 ms.
- Sonuç: veritabanı darboğaz DEĞİL. Garson gönderiminde ardışık bulut turları (table_orders SELECT → RPC → köprü/yazıcı → `updateTableOrderStatus('sent')`) ~4×RTT ≈ 180–250 ms ağ süresi; "yavaş" hissi büyük olasılıkla yazıcı köprüsü/LAN, yetki doğrulama veya UI tarafında. Gerçek uygulamada ölçüm yapılmadan nedeni PASS/FAIL denmez.
- Mevcut zamanlama kayıtları: `[PrintPerf][kitchen_order]` (seller_panel_page ~13066) yalnız toplam + DB güncelleme + dispatch ms verir; aşama kırılımı (yetki, fiyat doğrulama, köprü teslimi, UI) yok. Gerçek uygulamada günlük yakalanmadı (kayıtlı hiç `total_ms` bulunamadı).
Yapılan değişiklik: `dispatchNewOrderFromTableOrder` artık kararlı `localOrderId` (`tblsend-<tableOrderId>-<kalem özeti>`) gönderiyor → aynı gönderim tekrarlanırsa
sunucu ikinci sipariş açmaz (`idx_orders_restaurant_local_order`); kalem değişirse yeni anahtar. Test: `test/services/table_order_send_idempotency_test.dart` 2/2; analyze temiz.
Bilinen sınır: yanıt kaybında yeniden deneme mevcut siparişi bulur, `print_job_ids=[]` döner; fiş beklemede kalmış print_job için `recoverPendingJobs` yoluna güvenilir (gerçek cihazda doğrulanmadı).
Gerçek ölçüm için gereken: test masası + (fiziksel baskı kapalı veya kotalı) gerçek uygulamada ~20 gönderim; onay bekliyor.

### 2026-11-22 (düzeltme) — P2: önceki "27 numaralı masa ölçümü" GEÇERSİZ; üretimde hiç sipariş/adisyon/baskı oluşturulmadı
Kullanıcı düzeltmesi: gönderim yapılmadı, "Bitti/Bulut" yanlışlıkla yazıldı; 20 gerçek sipariş istenmiyor. Ölçüm yerine kod + log analizi.
Gerçek-uygulama gecikme logu mevcut değil (release `debugPrint` yakalanmıyor, kayıtlı `total_ms` yok) → p50/p95 YOK; aşağıdakiler kod yapısından çıkarım, ölçüm değildir.

**Kök neden adayları (kod, sıralı bulut turları)** — ağ RTT'si bu Mac'ten p50 45 ms; restoran Wi-Fi'ında Singapur'a daha yüksek olabilir:
1. Garson yeni sipariş yolu (`seller_panel_page` ~36755): `dispatchNewOrder` → RPC (1 tur). Bu yolda idempotency anahtarı ZATEN VAR (`resolveGarsonSubmitKey`); önceki notumdaki "anahtar yok" yalnız `dispatchNewOrderFromTableOrder` (müşteri mutfak onayı) yolu için doğruydu.
2. RPC sonrası, sipariş kabulünden SONRA ardışık: `settleLanPrint` (≤600 ms, zaman aşımında +350 ms) → `_markPrintJobsLanPrinted` (İŞ BAŞINA 1 UPDATE turu, ardışık) → `_fetchPrintJobsByIds` (1 tur) → [LAN başarısızsa] `_dispatchCreatedPrintJobsGarsonFast` içinde AYNI işler için ikinci `_fetchPrintJobsByIds` (1 tur) → iş başına ardışık `claim` + `mark printing` + köprü + `mark completed` turları → `updateTableOrderStatus('sent')` (1 tur).
3. Çok istasyonlu siparişte (mutfak+bar) yukarıdaki iş-başına turlar N ile çarpılıyor ve işler birbirini bekliyor.
4. Düzenleme yolunda `updateFuture()` sonra `printFuture()` ardışık (adı "parallel" olsa da); baskının kayıttan sonra başlaması bilinçli güvenlik kuralı olduğundan DEĞİŞTİRİLMEDİ.
5. DB tarafı darboğaz değil: RPC p50 0,7–1,4 ms / p95 1,8–2,7 ms (izole, rollback'li).

**Yapılan dar kapsamlı iyileştirmeler** (`ibul_app/lib/services/order_print_job_service.dart`, yalnız ardışık ağ turu azaltma; sipariş/yazdırma sırası, kimlik, yetki ve idempotency semantiği aynı):
- `_markPrintJobsLanPrinted`: iş başına UPDATE döngüsü → tek koşullu UPDATE (aynı değerler, aynı `pending/claimed` koşulu). Kazanç: (N−1) tur.
- `_dispatchCreatedPrintJobsGarsonFast`: çağıranın az önce çektiği işleri yeniden kullan (`garsonFastJobsFromPrefetch`; eksik/boş yükte yeniden sorgu). Kazanç: LAN-direct başarısız yolda 1 tur.
- `dispatchNewOrderFromTableOrder`: kararlı `localOrderId` (`tblsend-<id>-<kalem özeti>`) — müşteri mutfak onayı yolunda yinelenen gönderimde çift sipariş olmaz.
Test: `test/services/table_order_send_idempotency_test.dart` 4/4; ilgili baskı testleri (kitchen_print_after_commit, lan_print_ambiguity, print_job_retry_confirmation, print_job_payload_identity, kitchen_hub_payload_stamp) 33/33; `flutter analyze` temiz (değişen dosyalar). Tam `flutter test` ve gerçek cihaz DOĞRULANMADI.

**Yapılmayan / sonraya (ölçüm gerektirir):** iş başına claim→yazdır→tamamla döngüsünü işler arası eşzamanlı yapmak (aynı yazıcıda sıra riski), RPC yanıtına print_job yükü ekleyerek `_fetchPrintJobsByIds`'i tamamen kaldırmak (sunucu migration), aşama kırılımlı telemetri. İzole yığında üretim-dışı yük/performans testi hazırlanabilir (açık görev).

## 2026-11-22 — P3 Alt yönetici izinleri: SALT-OKUNUR sözleşme denetimi (kod + production katalog); production'a yazılmadı
**KRİTİK GÜVENLİK BULGUSU (production, doğrulandı, silme DENENMEDİ):** `public.products` üzerinde politika "Enable delete for users based on user_id":
roles={public}, cmd=DELETE, USING (true); `anon` ve `authenticated` rollerinde products DELETE/UPDATE tablo yetkisi var → herkese açık anon anahtarıyla
herhangi bir ürün silinebilir görünüyor. Düzeltme HAZIR, UYGULANMADI: `ibul_app/supabase/migrations/20261122110000_products_close_public_delete.sql`
(+ rollback). Eski politikayı kaldırır, yönetim paneli silmesi için yalnız admin/super_admin `products_admin_delete_all` ekler; sahip ve `manageProducts` personel
silme politikaları (`Sellers can delete own products`, `staff_permission_delete`) değişmez. İzole DB'de söz dizimi rollback'li denendi (1 admin politikası oluştu).
Yönetim paneli silme akışı (`admin_service.dart` ~4569) gerçek kullanımda doğrulanmadı.

Sözleşme matrisi (production RLS + Flutter):
| Alan | Sunucu (RLS/RPC) | Flutter / LAN | Durum |
| --- | --- | --- | --- |
| Ürün ekle/düzenle/sil | `staff_permission_*` = manageProducts (4 politika) | modül `products`=manageProducts | Hizalı (silme açığı yukarıda ayrı) |
| Yazıcı/istasyon yazma | `*_print_settings_write` = managePrintSettings (bugün uygulandı) | `_staffHas('managePrintSettings')`, LAN `restaurant_center_access`/`restaurant_lan_host` | Hizalı; gerçek alt yönetici ekran testi YOK |
| Sistem: alan ve masa yönetimi | `store_tables`, `store_table_areas`: YALNIZ sahip (`auth.uid()=seller_id`) | `system` modülü manageOrders VEYA managePrintSettings ile görünür | **UYUMSUZ**: personel sayfayı açar, yazamaz; bu iş için SellerPermission YOK |
| QR yönetimi | QR tablosu bulunamadı (ad araması); kaynak incelenmedi | — | Belirsiz |
| Masa aktarımı | RPC + guard (bugün düzeltildi) | transferTable | Hizalı (gerçek ekran testi yok) |
| Ara ödeme | `table_payments_staff_insert/select` = takePartialPayment + masa erişimi | — | Hizalı (yalnız katalog) |
| Hesap kes / böl | guard: closeBill; splitBill için sunucu politikası İNCELENMEDİ | — | Doğrulanmadı |
| Stok yönetimi | stok tablosu adı bulunamadı | — | Belirsiz |
Karar bekleyen: Sistem sayfası (alan/masa/QR) için yeni izin (örn. `manageTables`) mi, mevcut izin mi? Yeni izin Flutter enum + Edge Function izin listesi + `validate_restaurant_staff` + LAN + RLS'e aynı anda girmeli; sahip/şifre/finans izinleri otomatik dahil edilmeyecek.

### 2026-11-22 — Ürün silme açığı KAPATILDI (kullanıcı, SQL Editor) + aynı desende iki açık daha bulundu
`20261122110000` production'da doğrulandı (katalog): "Enable delete…" kalktı; products DELETE politikaları: sahip ×2, `products_admin_delete_all`, `staff_permission_delete`; `true` koşullu politika 0/16. Yönetim paneli silme akışı gerçek kullanımda doğrulanmadı.
Aynı desende (roles=public, koşul true) AÇIK, UYGULANMADI, düzeltme HAZIR:
- `stores` DELETE herkese açık; sahip silme politikası yoktu → `20261122120000_stores_close_public_delete.sql` (sahip `auth.uid()=seller_id` + admin politikası ekler). İzole DB'de rollback'li söz dizimi PASS.
- `system_layouts` INSERT/UPDATE/DELETE herkese açık (SELECT açık kalır) → `20261122130000_system_layouts_admin_only_write.sql` (yazma yalnız admin/super_admin; tek yazan istemci admin_service). Üretimde tablo yok değil, izole DB'de yok; geçici tabloyla söz dizimi PASS.
Rollback dosyaları `ibul_app/supabase/rollbacks/` altında (açıkları yeniden açar). Gerçek yönetim paneli (mağaza silme, düzen kaydetme) ve sahip hesap silme akışı doğrulanmadı.

### 2026-11-22 — `20261122120000` (stores silme) production'a uygulandı (kullanıcı, SQL Editor) — KATALOG DOĞRULAMASI PASS
`stores` DELETE: "Enable delete…" KALKTI; `stores_owner_delete`, `stores_admin_delete_all`, `staff_permission_delete` VAR; `true` koşullu yazma politikası kalmadı.
Doğrulanmadı: sahip hesap silme ve yönetim paneli mağaza silme akışı. `system_layouts` (`20261122130000`) HÂLÂ UYGULANMADI.

### 2026-11-22 — `20261122130000` (system_layouts) production'a uygulandı (kullanıcı, SQL Editor) — KATALOG DOĞRULAMASI PASS
`system_layouts`: açık INSERT/UPDATE/DELETE politikaları KALKTI; `system_layouts_admin_write` (admin/super_admin) VAR; `system_layouts_select_all` (okuma) yerinde.
Tüm `public` şemada roles=public/anon + koşul `true` yazma politikası taraması: 0 sonuç. Doğrulanmadı: yönetim paneli düzen kaydetme (admin hesabı).

## 2026-11-22 — P3: yeni izin `manageTables` (alan, masa, QR düzeni) — KOD + MİGRATION HAZIR, production'a UYGULANMADI
Karar (kullanıcı): Sistem sayfası alan/masa/QR için yeni izin. Sahip, personel şifresi/yönetimi, finans ve ödeme izinleri bu izne DAHİL DEĞİL.
Sözleşme tek ad: `manageTables` — Flutter `SellerPermission` (+ etiket, grup "İşletme Yönetimi", `staffPermissionsStoredOnServer`, `restaurantFloorPermissions`, Sistem "Tam Erişim" = managePrintSettings + manageTables,
`modulesForStaff` Sistem sayfası, `staff_account_dialog`), Edge Function (`allowed`, `restaurantOnly`, `triggerPermissions`), `validate_restaurant_staff_membership`, RLS. Garson tavanında YOK (garson alamaz); alt yönetici tavanında var.
Migration: `ibul_app/supabase/migrations/20261122140000_manage_tables_permission.sql` (+ rollback). İçerik: doğrulama tetikleyicisi (production gövdesi + yeni izin); `restaurant_branch_scope_ok` (sahip her zaman; şubeli personel yalnız kendi aktif şubesi);
`store_tables` personel politikası (manageTables + şube kapsamı); `store_table_areas` insert/update/delete (update/delete yalnız alanı başka şubenin masaları kullanmıyorsa). Sahip ve herkese açık okuma politikaları değişmez.
İzole test (production benzeri RLS açık, rollback'li) 14/14 beklenen: kendi şubesine masa ekle/güncelle/sil İZİNLİ; şubesiz/başka şube masa ekleme-güncelleme ENGELLİ; izinsiz personel masa/alan ENGELLİ; başka şubenin kullandığı alan güncelle/sil ENGELLİ; boş alan sil İZİNLİ;
sipariş tablosu ENGELLİ; sahip İZİNLİ; geçersiz izin hâlâ reddedilir. Not: izole DB'de `store_tables` RLS kapalıydı (production'da açık); test işlem içinde RLS açılıp production politikalarıyla yapıldı.
Flutter: `test/models` + `test/features/seller` 327/327; yeni `test/models/manage_tables_permission_test.dart` 5/5; analyze'de hata yok (3 eski bilgi/uyarı).
Production için GEREKENLER (onay): (1) migration SQL Editor'de; (2) Edge Function `manage-restaurant-staff` yeniden dağıtımı (izin listesi; yerel kaynak ≠ v6 farkı doğrulanmadı) — yapılmazsa Edge Function `manageTables` izni kaydını reddeder;
(3) yeni uygulama derlemesi. SIRA ÖNEMLİ: önce migration, sonra Edge Function, sonra uygulama.
Doğrulanmayan: Flutter Sistem sayfası alan/masa/QR butonlarının `manageTables` ile gerçekten etkinleşmesi (sayfa içi kontroller `_actorIsStoreOwner` ile mi kapalı, incelenmedi); QR üretimi `store_tables.qr_token` güncellemesi olduğundan RLS ile kapsanır, ekran testi yok.

### 2026-11-22 — `20261122140000` (manageTables) production'a uygulandı (kullanıcı, SQL Editor) — KATALOG DOĞRULAMASI PASS
`validate_restaurant_staff_membership` içinde manageTables VAR; `restaurant_branch_scope_ok` VAR (anon=false, authenticated=true); `store_tables_manage_tables_staff` + 3 `store_table_areas_manage_tables_*` politikası VAR; sahip ve herkese açık okuma politikaları yerinde.
**EDGE FUNCTION DRİFT (kritik, salt-okunur `get_edge_function` ile doğrulandı):** production `manage-restaurant-staff` v6 ESKİ kod: `change_staff_password` açık, `set_temporary_password` doğrudan `admin.updateUserById` (RPC `owner_set_staff_password` YOK),
oluşturmada `must_change_password: true`. Yerel (commit dbdad86) sürüm: sahip-yalnız şifre, `change_staff_password` 403, `owner_set_staff_password` RPC, `must_change_password:false` + bu oturumdaki manageTables. DB tarafı (20261121090000/100000) uygulanmış olduğundan
v6'daki `set_temporary_password`/`change_staff_password` auth.users koruma tetikleyicisine takılma ihtimali var (denenmedi); deploy edilene kadar sahip-yalnız şifre politikası ve manageTables izni üretimde TAM ÇALIŞMAZ.
Dağıtım BEKLİYOR (onay): `supabase functions deploy manage-restaurant-staff --project-ref ihmixxzqnpamcwmrfibx` (kullanıcı) ya da yetkili araç. Dağıtım sonrası: get_edge_function ile içerik doğrulaması + gerçek hesapla personel oluşturma/izin kaydetme testi (test personeli; gerçek personele dokunma).

### 2026-11-22 — Edge Function `manage-restaurant-staff` v7 production'a dağıtıldı (kullanıcı, `supabase functions deploy --use-api`) — İÇERİK DOĞRULAMASI PASS
İlk deneme Docker imaj indirme hatasıyla (DNS) düştü, hiçbir şey değişmedi; `--use-api` ile dağıtıldı. `get_edge_function`: sürüm 7; içerikte `manageTables` (allowed/restaurantOnly/triggerPermissions) VAR,
`change_staff_password`/`clear_password_change` 403, `set_temporary_password` yalnız sahip + `owner_set_staff_password` RPC, oluşturma yalnız sahip ve `must_change_password:false`, `list_branches` işlemi VAR. Diğer 4 fonksiyonun sürümü/özeti değişmedi.
Doğrulanmadı: gerçek çağrıyla (test personeli) oluşturma / izin kaydetme / şifre belirleme; uygulama tarafı `manageTables` düğme etkinleşmesi. Önceki sürüm (v6) panel sürüm geçmişinden geri alınabilir.

### 2026-11-22 — P3: Sistem sayfası düğme/servis incelemesi (SALT KOD OKUMA; değişiklik yok)
`manageTables` sunucuda hazır ama Flutter Sistem sayfası alt yönetici için HENÜZ kullanılamaz. Bulgular (`seller_panel_page.dart`, `store_table_service.dart`):
1. **Yanlış kısayol:** `_buildSystemModule` (~25252) ve `_buildMobileSystemModule` (~11620): `!manageOrders && managePrintSettings` → yalnız yazıcı ekranı. managePrintSettings + manageTables olup manageOrders olmayan personel masa/alan/QR'a ULAŞAMAZ.
2. **Düğmeler izinsiz görünür:** "Alan Ekle", "Masa Ekle", masa silme/alan taşıma `manageTables` ile kapılanmıyor; modülü gören herkese (örn. yalnız manageOrders) görünür ve sunucu RLS'inden ham hata alır.
3. **Yanlış restoran kimliği:** `addStoreTable` / `addTableArea` / `getStoreTables()` çağrıları `sellerId` vermiyor; `_resolveSellerId` oturumdaki kullanıcı kimliğini (personel kimliği) kullanır → personelde `seller_id` yanlış, RLS reddeder, liste boş döner. Garson kodu doğru kimliği `_resolveGarsonSellerId()` ile çözüyor.
4. **Şube yok:** yeni masa `branch_id` yazmıyor; şubeli alt yönetici için `restaurant_branch_scope_ok(…, null)` false → eklenemez. Personel şubesi panel kapısında (`StaffMenuGate`) taşınmıyor; sunucuda `get_my_staff_access()` branch_id döndürüyor ama istemci çağırmıyor.
Önerilen dar kapsamlı düzeltme: (a) kısayol koşuluna `&& !manageTables`; (b) 4 masa/alan eylem fonksiyonunda merkezi `manageTables` ön-kontrolü ("Alan ve masa düzenleme yetkiniz yok."); (c) restoran kimliğini `_resolveGarsonSellerId()` ile geçir; (d) personel şubesini `get_my_staff_access()` ile al ve `addStoreTable`'a `branchId` ver. Gerçek cihazda doğrulama gerekir.

### 2026-11-22 — P3: Sistem sayfası `manageTables` düzeltmeleri UYGULANDI (kod; gerçek cihazda DOĞRULANMADI)
Dosyalar: `seller_panel_page.dart`, `store_service.dart`, `store/store_table_service.dart`, `staff_login_policy.dart`, test `test/models/manage_tables_permission_test.dart`.
1. Yazıcı-yalnız kısayolu `systemModuleIsPrinterOnly` (masa izni varsa kapalı; sahip için devre dışı) — masaüstü + mobil.
2. `_requireManageTables()` merkezi ön-kontrol: `_addStoreTable`, `_addTableArea`, `_addStoreTableForArea`, `_removeStoreTable`, `_moveTableToArea`, `_initializeDefaultStoreTables` ("Alan ve masa düzenleme yetkiniz yok."). Düğmeler hâlâ GÖRÜNÜR (tıklayınca uyarı); gizleme/pasifleştirme yapılmadı.
3. Restoran kimliği: `_tableAdminSellerId` (= `_resolveGarsonSellerId()`, yoksa oturum kimliği) masa/alan ekleme ve varsayılan masa listelemesine geçirildi.
4. Şube: `_resolveStaffBranchIdForTables()` → `get_my_staff_access` RPC'si (sahipte null); `addStoreTable(branchId:)` `branch_id` yazar.
Test: `test/models` + `test/features/seller` + idempotency 339/339; analyze'de hata yok (3 eski uyarı: kullanılmayan öğeler). Gerçek alt yönetici ile alan/masa/QR akışı, düğme görünürlüğü ve macOS/iOS derlemesi DOĞRULANMADI.

## 2026-11-22 — P5 Personel yetki ekranı (KOD HAZIR; gerçek cihazda/ekranda DOĞRULANMADI, production'a dokunulmadı)
Yeni sunucu sözleşmesi yok; mevcut `StaffAccountDialog` genişletildi, aynı İBUL tasarım dili.
- **Yeni dosyalar:** `features/seller/staff/staff_permission_summary.dart` (saf mantık: sayfa düzeyleri, canlı özet, kayıt doğrulaması), `staff_permission_widgets.dart` (özet kartı, düzey satırı, önizleme).
- **Personel detayı:** başlıkta ad, Aktif/Pasif, şube adı, rol etiketi, oluşturulma tarihi. **"Son izin güncellemesi" YOK:** `store_sub_admins` tablosunda `updated_at` sütunu yok (production'da doğrulandı); gösterilmesi yeni migration (sütun+tetikleyici) ister.
- **Şablonlar (ChoiceChip, seçili durum):** Garson, Alt Yönetici (restoran için eski "Müdür Yardımcısı" yeniden adlandırıldı; izinler aynı), Restoran Müdürü, Kasiyer, Sipariş Sorumlusu, **Özel Yetki** (seçimi korur). Şablonlar closeBill/transferTable/manageStaff içermez (mevcut test korunur).
- **Sayfa erişimi: Erişim yok / Görüntüle / Tam yönetim** (Wrap, taşma yok). "Görüntüle" yalnız sunucuda gerçek salt-okunur izni olan sayfalarda (Garson, Siparişler, Genel Bakış → viewOrders); Ürünler/Kampanya/Destek/Sistem'de yalnız Yok/Tam (okuma bile yönetim iznine bağlı). Başka sayfanın ihtiyaç duyduğu izin silinmez; hiçbir hazır düzeye uymayan kayıt "Özel seçim" gösterilir.
- **Özel işlem izinleri** ayrı gruplarda (mevcut grup kartları) kalır; kritik izinler onay penceresiyle.
- **Canlı özet:** seçili izinlerden hesaplanır (Sipariş gönderebilir, Ürün yönetebilir, Masa aktarabilir, Ara ödeme, Masa kapatabilir/kapatamaz, Yazıcı ayarları, Alan-masa-QR, Finans, Kampanya, Destek, Personel; "Personel şifresi değiştiremez" her zaman — sunucuda yalnız sahip).
- **Kaydet / Geri al / Önizleme:** Geri al açılış durumuna döner; Önizleme sayfa düzeylerini, özeti ve sunucuya yazılacak izin adlarını gösterir.
- **Sunucuda doğrulama:** düzenleme kaydından sonra `getSubAdminsSnapshot` ile okunan izinler gönderilenle karşılaştırılır; eşleşirse "sunucuda doğrulandı", değilse eksik/fazla izinler listelenir. Yeni personel oluşturma yolunda bu doğrulama YOK.
- **Test:** `test/features/seller` + `test/models` + idempotency 352/352; yeni `staff_permission_summary_test.dart` (11) ve `staff_permission_dialog_test.dart` (360 px ve 1280 px, taşma istisnası yok); `staff_business_catalog_test.dart` çip türü `ActionChip→ChoiceChip` güncellendi (kasıtlı arayüz değişikliği). analyze'de hata yok (1 eski uyarı).
- **Doğrulanmadı:** gerçek ekranda görsel kontrol (ekran görüntüsü alınmadı), gerçek sahip hesabıyla kaydet→sunucu doğrulaması, mobil gerçek cihaz. Yeni derleme gerekir.
