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

## 2026-11-22 — P6 Offline-first yerel veri/LAN mimarisi: DENETİM + 1 düzeltme (gerçek cihazda DOĞRULANMADI)
**Mevcut mimari (yeni paralel sistem yazılmadı):** `ibul_app/lib/services/restaurant_offline/*` (~10 bin satır). Yerel sipariş kuyruğu = restoran başına JSON günlük (`orders_<restaurantId>.json`), yazma: geçici dosya + `flush` + `rename` (yarım kayıt oluşmaz),
yazmalar tek zincirde sıralanır, ayrıca `SecureLocalStore` (Keychain/SharedPreferences) kopyası; okuma sırasında günlük bozuksa `StateError('… Üzerine yazılmadı.')` (sessiz ezme yok). Baskı kuyruğu ve ürün/masa/istasyon önbelleği aynı mantıkta. `sqflite` bağımlılığı var ama siparişler için KULLANILMIYOR; SQLite'a geçiş yapılmadı (gerekçe: atomik günlük + bozulma koruması mevcut, geçiş yüksek risk/düşük kanıt).
**Şartnameye karşı bulgular:**
| Madde | Durum |
| --- | --- |
| Parola/servis anahtarı yerelde düz yazı | `restaurant_offline/` içinde bulunmadı (yalnız `must_change_password` bayrak adı) |
| Yarım yazılan kayıt | Koruma var (atomik rename); gerçek uygulama kapanması testi yapılmadı |
| Bozuk veri / dolu disk → sahte başarı yok | Bozuk günlükte hata atar; yazma hatası `enqueue`'dan yayılır (kod okuma); disk-dolu simülasyonu YAPILMADI |
| **Katalog doğrulaması (ürün/fiyat)** | LAN merkezine gelen cihaz siparişleri kataloga göre fiyatlanıyordu; **merkezin KENDİ çevrimdışı siparişi (router `hostHere` yolu) istemci fiyatına güveniyordu → DÜZELTİLDİ** (aşağıda) |
| Önbellek tazeliği | `cachedAt` var ama sipariş anında HİÇ kontrol edilmiyor; eski fiyatla satış riski → AÇIK |
| Varyant / boy / gram fiyatı | Önbellek yalnız taban `price` tutuyor (`_productToCacheMap`); varyant/ağırlık fiyatı doğrulanamaz → bu kalemler cihaz yolunda zaten reddediliyor, merkezin kendi yolunda artık reddedilecek (AÇIK ÖZELLİK: önbelleğe seçenek/ağırlık fiyatı ekle) |
| Şube/kullanıcı kapsamı | Günlük yalnız `restaurantId`'ye göre; şube/kullanıcıya göre ayrım YOK → AÇIK |
| Offline yetki mührü | Personel 12 sa, sahip 72 sa (`offline_panel_identity.dart:146,154`); anında iptal yok (kabul edilmiş risk) → P7'de |
**Yapılan değişiklik:** `offline_catalog_pricing.dart` (yeni): LAN host'taki `_pricedItems` mantığı bire bir ortak, herkese açık `pricedOfflineItems`'a çıkarıldı (host artık bunu çağırır, davranış aynı). Router `dispatchOfflineOrder` (yalnız merkezin kendi yolu, tekrar gönderim hariç):
`priceLocalOfflineOrder` ile katalog doğrulaması; katalog boşsa "Yerel ürün kataloğu hazır değil."; ürün yok/fiyat uyuşmuyor/istasyon çelişkisi/geçersiz adet → `StateError`, kayıt YAZILMAZ, baskı BAŞLAMAZ. Kayıt ve fiş artık doğrulanmış (katalog) fiyatla. `RestaurantLocalOrderRecord.copyWith` items/total kabul eder.
**Test:** yeni `test/restaurant_offline/offline_catalog_pricing_test.dart` (8); `test/restaurant_offline` + `restaurant_lan_host_test` + `test/restaurant` 76/76. `dispatchOfflineOrder` uçtan uca (gerçek host/TLS) testi YOK; gerçek Mac + yazıcıda doğrulanmadı.
**Davranış riski (dürüst not):** merkezin kendi çevrimdışı yolunda eskiden kabul edilen boy/gram/varyant kalemleri artık reddedilebilir; çevrimdışı satış engellenir ama yanlış fiyatla satılmaz. Gerçek restoran menüsüyle denenmeli.

## 2026-11-22 — P7 Çevrimdışı üç sayfa: KOD HAZIR (gerçek cihazda/WAN kesintisinde DOĞRULANMADI)
**Kural tek yerde:** `features/seller/panel/helpers/offline_page_policy.dart` — çevrimdışıyken yalnız Genel Bakış, Garson, Sistem açılır; mesaj "İnternet bağlantısı gerektirir". Mevcut `offlineOperationModuleNames` (yalnız garson+sistem) `dashboard` ile genişletildi.
**Tetik:** `_cloudDownForRestaurant` = restoran kategorisi ve (ağ yok VEYA Supabase'e ulaşılamıyor) ya da çevrimdışı başlangıç. Önceki `_offlineOperationActive` yalnız LAN merkezi hazırken tetikleniyordu; artık LAN olmasa da sayfalar engellenir. Çevrimiçi hiçbir sayfa engellenmez; bağlantı gelince menü ve içerik otomatik normale döner.
**Katmanlar:** (1) menü: izinli tüm sayfalar görünür, engelliler wifi-off simgesi + "· İnternet gerekir", tıklayınca uyarı; (2) rota/derin bağlantı/kod: `_setActiveSellerModule` ve `_syncStateFromNavigationController` engelli sayfayı reddeder, izinli ilk çevrimdışı sayfaya döner (hesabın sahip olmadığı sayfa eklenmez); (3) içerik: engelli sayfanın GERÇEK widget'ı hiç oluşturulmaz (veri sorgusu/işlem tetiklenmez), yerine bulanık iskelet + açıklama (`OfflineBlockedModuleView`, etkileşimsiz).
**Çevrimdışı Genel Bakış** (`OfflineOverviewLoader/View`, `offline_overview.dart`): bu cihazın yerel önbelleği ve sipariş günlüğünden; kaynaklar AYRI kartlarda: Masalar (toplam/dolu/boş; liste hiç eşitlenmediyse sayı uydurulmaz), Bulutla senkronize (son anlık görüntü zamanı), Yerel kayıtlı (mutfağa iletildi / baskı bekliyor / doğrulanamadı-başarısız), Senkronizasyon bekleyen (bekliyor / hata), Kesinleşmemiş tutarlar ("Yerel geçici toplam", "Açık adisyon (son eşitlemeye göre)"). **Tahsil edilmiş gelir GÖSTERİLMEZ**; "kazanıldı" denmez. Yükleyici 6 sn zaman aşımı + "Yeniden dene" (sonsuz spinner yok), 10 sn'de bir yenilenir.
**Testler:** `offline_page_policy_test.dart` (7), `offline_page_widgets_test.dart` (6; 360/1280 px, taşma yok). Geniş koşu (`test/restaurant_offline`, `features`, `models`, `restaurant`, `security`): 790 geçti, 7 başarısız — yedisi `test/features/checkout/checkout_cart_continuity_test.dart` (müşteri ödeme ekranı; bu çalışmada dokunulmadı; önceden başarısız olduğu bu koşuda KANITLANMADI). analyze'de hata yok.
**Açık / dürüst sınırlar:** (a) iPhone'un LAN merkezindeki yerel durumu görmesi (Genel Bakış'ın merkezden okunması) YAPILMADI — merkezde özet uç noktası yok; iPhone yalnız kendi cihaz günlüğünü gösterir. (b) "Günlük satış/adisyon özeti" ve "Hazırlanan siparişler" yok: kesin ödeme verisi yerelde yok, mutfak hazırlık durumu izlenmiyor (baskı durumlarına eşlendi). (c) "Son senkronizasyon" = son bulut anlık görüntü zamanı (`cachedAt`), son başarılı sipariş eşitleme zamanı değil. (d) Engelli menü girdileri soluk değil (kabuk widget'ları değişmedi), simge+etiketle işaretli. (e) Engelli sayfaların arka plan zamanlayıcı/yükleyicileri (panel dışından tetiklenenler) denetlenmedi. (f) Gerçek WAN kesintisi ve gerçek Mac+iPhone doğrulaması yok; test onayı gerekir.

## 2026-11-22 — P8 Otomatik, mükerrersiz senkronizasyon: İSTEMCİ düzeltmeleri + sunucu kanıtı; ÜRETİM BLOKAJI (onay)
**12 adıma karşı durum (kod + izole kanıt):**
| # | Adım | Durum |
| --- | --- | --- |
| 1 | İnternet doğrula | VAR (`connectivity.refresh`, `hasNetwork && supabaseReachable`); yaşam döngüsü yeniden bağlanınca otomatik tetikler ve ilerleme sürdükçe turları tekrarlar |
| 2 | Oturum/yetki yeniden kontrol | Oturum yoksa gönderim **bekletilir** (YENİ: siparişler `pendingSync` kalır, "hata aldı" işaretlenmez). Yetki sunucuda: RPC `restaurant_has_permission(manageOrders)` + garson kimliği kuralı. İstemci ayrıca personel iznini ÖN-doğrulamaz. Not: merkez sahibin oturumuyla gönderir; çevrimdışı sırada yetkisi iptal edilen personelin kabul edilmiş siparişi yine kaydedilir (kabul edilmiş risk) |
| 3–4 | Sırayla işle | VAR; **YENİ** sıralama: hiç denenmemişler önce (en eski), sonra hata alanlar EN ESKİ denenen önce. Eskiden ilk 10 hatalı sipariş kuyruğun başını tutup yenileri aç bırakıyordu (`take(limit)` açlığı) |
| 5–6 | Benzersiz anahtar, mükerrer yok | VAR ve KANITLANDI: RPC `local_order_id` + `pg_advisory_xact_lock(restaurant:local_order_id)` + `idx_orders_restaurant_local_order` UNIQUE; izole DB'de aynı kimlikle 4 EŞZAMANLI oturum × 2 çağrı = 8 çağrı → 1 sipariş, 1 baskı işi, 1 kalem, hepsi aynı `order_id`, `idempotent_replay=true`. Production RPC gövdesi aynı kilit + replay dalını içeriyor (katalogdan okundu) |
| 7 | Kalem/toplam/masa doğrulama | Sunucu: ürün-işletme sahipliği, istasyon, masa kontrolü RPC'de; tutarın sunucuda yeniden hesaplanıp hesaplanmadığı bu turda DOĞRULANMADI |
| 8 | Başarılıyı işaretle | VAR (`markSynced`) |
| 9 | Başarısız kalıcı hata durumu | VAR (`syncFailed` + `syncError`, yerelde kalır, silinmez) |
| 10 | Geçici hatada kontrollü yeniden deneme | Sonraki turlarda yeniden denenir; zaman bekleme eşiği opsiyonel (`selectOrdersForSync(retryAfter)`; varsayılan 0 çünkü "yanıtı kaybolan gönderim hemen yeniden denenebilir" testi bunu bekliyor) |
| 11 | Çakışmayı ezme | VAR (`conflict` durumu otomatik yeniden denenmez) |
| 12 | Ekranlara yansıt | VAR (senkron sonrası Garson panosu yenilenir; P7 Genel Bakış yerel durumu okur) |
**Değişen:** `restaurant_offline_sync_service.dart` (`selectOrdersForSync`, `hasCloudSession`, `forceRetry`), `restaurant_offline_banner.dart` (elle eşitleme `forceRetry`). Test: `test/restaurant_offline/sync_selection_test.dart` (5); `test/restaurant_offline`, `restaurant_lan_host_test`, `order_queue_sync_marks_test`, `test/restaurant` geçti; `lan_bridge_sync_test` 2 test ortam değişkeni ister (`IBUL_POSTGREST`, `IBUL_PSQL`) → bu koşuda çalıştırılamadı (kod değişikliğinden bağımsız).
**KRİTİK ÜRETİM BLOKAJI (salt-okunur doğrulandı):** basılmış/belirsiz çevrimdışı siparişler yalnız imzalı baskı kanıtıyla gönderilir. Production'da: `register_restaurant_lan_print_evidence_key` YOK, `restaurant_lan_print_evidence_keys` tablosu YOK, `verify-lan-print-evidence` Edge Function YOK; derlemede `IBUL_LAN_EVIDENCE_VERIFIER_URL` ayarı yok. Sonuç: üretimde çevrimdışı alınıp basılan siparişler internet gelince da OTOMATİK GÖNDERİLEMEZ (yerelde "Baskı kanıtı doğrulayıcısı yok" ile bekler; veri kaybolmaz, ama bulut siparişi oluşmaz). Ön koşul sağlam: hiçbir mağazanın aktif şubesi eksik değil (0). Gerekenler (onay): (1) migration `20261119090000` (+ bağımlılığı kontrol), (2) Edge Function dağıtımı, (3) derlemeye https adresi. İzole prova ve geri alma planı hazırlanacak.

### 2026-11-22 — P8: baskı-kanıtı zinciri ÜRETİM PAKETİ HAZIR (uygulanmadı; onay bekliyor)
**Kapsam:** üç parça birlikte gerekir; biri eksikse çevrimdışı basılmış sipariş buluta gidemez: (A) iki migration, (B) Edge Function `verify-lan-print-evidence`, (C) derlemeye doğrulayıcı adresi.
**A — Migration'lar (sırayla, her biri kendi işleminde):** `20261103223000_order_sync_print_evidence.sql`, sonra `20261119090000_lan_print_evidence_key_registration.sql` (ikisi de "Bu migration'ı production'a uygula" şartını başlıkta taşır: dosya adı + açık cümle gerekir).
Ne yapar: kapalı tablolar `restaurant_lan_print_evidence_keys/_events` (RLS açık, istemciye yetki yok); `restaurant_lan_print_evidence_public_key`, `restaurant_print_evidence_outcome`, `register_/revoke_restaurant_lan_print_evidence_key`, `restaurant_primary_branch_id`; **sipariş RPC çiftini (`create_table_order_with_print_jobs` + `_impl`) 9 → 12 argümana değiştirir** (+3 varsayılanlı argüman: kanıt, doğrulanmış aktör, kanıt şubesi). Anon çalıştıramaz; authenticated çalıştırır.
**Üretim ile uyum kanıtı (salt-okunur):** canlı `_impl` md5 `f7dca415f03af4635ceafa4e317ffd1a` (14301) ve sarmalayıcı `7ddf4b5be84a05419f406fcd5749d7a3` (204) repodaki `2026103101` ve `20261031_live_restaurant_rpc_ROLLBACK` ile BİREBİR aynı: migration'ın dayandığı taban gövde canlı gövde. Ön koşullar: `pgcrypto@extensions` + `extensions.digest` var; `store_branches` (`is_primary`,`status`) var; her mağazanın aktif şubesi var (0 eksik); print_jobs durum kontrolü `paused_by_operator` içeriyor.
**Prova (`scripts/rehearse_order_rpc_migration.sh`, geçici PostgreSQL, üretime HİÇ bağlanmaz):** eski istemci çağrıları (adlandırılmış 9 arg, konumsal, minimal, `approve_waiter_order_request`) migration ÖNCESİ, SONRASI ve GERİ ALMA sonrası çalışıyor; yeni yanıta yalnız `print_disposition` anahtarı EKLENİYOR (eklemeli); eski satırlar değişmiyor; 9 argümanlı sürüm kalmıyor; anon `f`, authenticated `t`; geri almadan sonra gövde özetleri canlıyla aynı. **Sınır:** prova şeması üretimden küçük (para/mükerrer-fiş tetikleyicileri yok) → imza/ACL/çağrı uyumu kanıtlı, üretim tetikleyicileriyle davranış KANITLI DEĞİL.
**Geri alma (hazır):** `ibul_app/supabase/rollbacks/20261119090000_lan_print_evidence_rollback.sql` — 12 argümanlıları siler, canlı 9 argümanlı anlık görüntüyü geri yükler; izole DB'de rollback'li denendi: özetler canlıyla aynı (`f7dca415…`/`7ddf4b5b…`). Yeni kapalı tablolar/yardımcı fonksiyonlar bırakılır (zararsız), kayıtlı sipariş/baskı satırlarına dokunulmaz.
**B — Edge Function:** yerel `index.ts` yalnız 127.0.0.1'e dinler (izole test); dağıtılabilir giriş için `scripts/package_verify_evidence_function.sh` ayrı klasörde `Deno.serve(handler)` girişi üretir (`/tmp/ibul-verify-evidence-pkg`). Yerelde Deno ile açıldı: yetkisiz POST→401, GET→405, yapılandırmasız→500. Dağıtım komutu (kullanıcı): `cd /tmp/ibul-verify-evidence-pkg && supabase functions deploy verify-lan-print-evidence --project-ref ihmixxzqnpamcwmrfibx --use-api`. İşlev kendi kimlik doğrulamasını yapar (kullanıcı JWT'sini `/auth/v1/user` ile doğrular; servis anahtarı ortamdan gelir, süreçten çıkmaz). Doğrulayıcı sipariş RPC'sini servis rolüyle `p_verified_actor` ile çağırır → RPC'nin 12 argümanlı olması ŞART (A, B'den ÖNCE).
**C — Derleme:** `--dart-define=IBUL_LAN_EVIDENCE_VERIFIER_URL=https://ihmixxzqnpamcwmrfibx.supabase.co/functions/v1/verify-lan-print-evidence` (https zorunlu). Gereksiz tam Release derlemesi olmaması için P10 (ad/logo) derlemesiyle birleştirilecek. Merkez, sahip oturumuyla internet varken ilk açılışta kanıt anahtarını `register_restaurant_lan_print_evidence_key` ile kaydeder.
**Önerilen sıra:** (1) SQL Editor: iki migration, her biri sonrası katalog doğrulaması; (2) hemen ardından, onaylı tek kontrollü TEST siparişi (masa 27, fiziksel baskı kapalı/kotalı) ile çevrimiçi sipariş yolunun bozulmadığını doğrula — başarısızsa geri alma dosyası; (3) Edge Function dağıtımı + `get_edge_function` doğrulaması; (4) derleme + merkez açılışında anahtar kaydı; (5) TEST B–D (WAN kesintisi, senkron) ayrı onayla.

### 2026-11-22 — `verify-lan-print-evidence` v1 production'a dağıtıldı (kullanıcı, `--use-api`) — LİSTE DOĞRULAMASI PASS
`list_edge_functions`: ACTIVE, v1, `verify_jwt=true`; diğer fonksiyonların sürümü/özeti değişmedi. **Sıra notu:** önerilen sıradan farklı olarak fonksiyon migration'lardan ÖNCE dağıtıldı; şu an hiçbir istemci bu adresi çağırmıyor (derleme ayarı yok), bu yüzden canlı etkisi yok. Fonksiyon sipariş RPC'sini 12 argümanla çağırır: migration'lar uygulanmadan kanıtlı bir çağrı BAŞARISIZ olur. Migration'lar henüz uygulanmadı.

### 2026-11-22 — Kanıt zinciri migration'ları production'da (kullanıcı, SQL Editor) — KATALOG DOĞRULAMASI PASS; canlı sipariş yolu DENENMEDİ
Katalog: `create_table_order_with_print_jobs` ve `_impl` YALNIZ 12 argümanlı (9 argümanlı kalmadı); `_impl` md5 `2f942a7187c3c68eb7ca9c43459af4b8` (17686) = `20261119090000` gövdesi; sarmalayıcı md5 `242e2b133c1c3d021022cd675fc0da78` (269) = `20261103223000` sarmalayıcısı → İKİ migration da uygulanmış. anon çalıştıramaz, authenticated çalıştırır. `restaurant_lan_print_evidence_keys/_events`: RLS açık, anon/authenticated yetkisi YOK. `restaurant_lan_print_evidence_public_key` ve `restaurant_print_evidence_outcome`: anon/authenticated çalıştıramaz (yalnız servis rolü). `register_/revoke_..._key` ve `restaurant_primary_branch_id`: authenticated (sahip denetimi fonksiyon içinde). `restaurant_order_line_fingerprint` anon/authenticated çalıştırabilir (saf özet yardımcısı).
AÇIK: üretim tetikleyicileriyle (para/mükerrer-fiş) çevrimiçi sipariş yolunun bozulmadığı henüz kanıtlanmadı. Önerilen: `BEGIN … ROLLBACK` içinde tek sipariş RPC çağrısı (hiçbir kayıt kalmaz) — onay bekliyor.

### 2026-11-22 — Production'da yeni 12 argümanlı sipariş RPC'si: GERİ ALINAN TEK ÇAĞRI (kullanıcı onaylı) — PASS + yeni bulgu
Yöntem: tek `DO` bloğu, sahip kimliğiyle (`set local role authenticated`, jwt sub=sahip) eski 9-argüman biçiminde `create_table_order_with_print_jobs` (masa 27, `print_evidence` verilmedi), ardından blok SONUNDA zorunlu `RAISE EXCEPTION` ile bütün işlem iptal. Sonuç: çağrı üretim tetikleyicileriyle (para/mükerrer-fiş/personel) BAŞARILI: `order_id`, `print_job_count=1`, `daily_order_no=1`, `print_disposition="online"` (eklemeli anahtar). Doğrulama: siparişler 658→658, baskı işleri 929→929, probe satırı 0 (id ve `local_order_id` ile arandı). Çevrimiçi yol bozulmadı.
**YENİ BULGU (güvenlik/bütünlük):** probe'da `product_id` kasten KATALOGDA OLMAYAN bir değerdi (`…x`) ve istemcinin gönderdiği fiyat verildi; production RPC bunu REDDETMEDİ. İzole veritabanındaki sürümde "Ürün bu işletmeye ait değil" kontrolü vardı; production gövdesinde (`f7dca415…`/`2f942a71…`) yok. Yani bulut RPC'si ürün kimliğini ve fiyatı katalogdan DOĞRULAMIYOR; yetkili bir istemci (sahip/personel) herhangi bir fiyatla sipariş yazabilir. LAN merkezi ise kataloğa göre fiyatlıyordu. Düzeltme sunucu migration'ı gerektirir (ürün sahipliği + katalog fiyatı); henüz yazılmadı.

### 2026-11-22 — Sipariş RPC ürün-sahipliği koruması: MIGRATION HAZIR (uygulanmadı) + fiyat otoritesi analizi
**Dosyalar:** `ibul_app/supabase/migrations/20261122150000_order_rpc_product_ownership_guard.sql` + `rollbacks/20261122150000_order_rpc_product_ownership_guard_rollback.sql`.
**Ne yapar:** canlı `_impl` gövdesinin (md5 `2f942a71…`, 17686) istasyon kontrolünden hemen sonrasına bir blok ekler (başka satır değişmez; kalıp tam bir kez bulunmazsa hiçbir şey yazmaz; tekrar çalıştırılabilir): (1) kalemde `product_id` varsa bu işletmenin kataloğunda olmalı → "Ürün bu işletmeye ait değil." (42501); (2) adet 1–99, fiyat 0–1.000.000 → 22023. **Fiyat eşitliği ZORLANMAZ.**
**Üretim verisi analizi (salt-okunur):** masa siparişi kalemleri 2339; product_id'si olup bu işletmenin kataloğunda olmayan 1324 kalem YALNIZ 11 Mart–20 Mayıs 2026 (hiçbir yerde olmayan silinmiş ürünler); başka işletmenin ürünü 0; en yüksek adet 4; adet>99: 0. Mayıs sonrası tüm kalemler katalogda var → kural bugünkü kullanımı bozmaz. Riskler: (a) silinen ürünün kalemi bekleyen çevrimdışı/taslak siparişte kalırsa reddedilir (görünür hata; sessiz yanlış satış değil), (b) `product_id`'siz kalem hâlâ geçer (kapsam dışı boşluk).
**Test (izole DB, rollback'li):** migration md5 `2f942a71…`→`b521ede6…` (18518); ikinci çalıştırma aynı md5 (idempotent); rollback `2f942a71…` (17686) geri döner; geçerli ürün KABUL; olmayan ürün RED; başka işletmenin ürünü RED; negatif fiyat RED; adet 100 RED; boş product_id KABUL; aynı `local_order_id` tekrarı `idempotent_replay=true` (mükerrer koruması bozulmadı). Mevcut `enforce_restaurant_bill_line` tetikleyicisi testte devre dışı bırakıldı (maskelemesin diye).
**Fiyat otoritesi — BLOKE (tasarım kararı gerekir):** repodaki `20261112234500_bill_line_price_authority.sql` üretimde UYGULANMAMIŞ ve OLDUĞU GİBİ UYGULANMAMALI: yalnız katalog TABAN fiyatını (indirimli/normal) kabul eder, `viewFinance` yoksa farklı fiyatı reddeder. Üretim menüsünde tüm 45 üründe boy seçeneği var (`hybrid` 24, `base_only` 21); geçmiş kalemlerde 1015 eşleşen kalemden 907 taban fiyat, 26 boy fiyatı, 19 sıfır (karışık menü), **63 (~%6) katalogdan türetilemiyor** (ek/ağırlık/seçenek bileşimi). Bu hâliyle garsonların boy/ek fiyatlı siparişleri "Fiyat değiştirme yetkiniz yok" ile reddedilirdi. Önce fiyat modeli (boy + varyant `priceDifference` + ağırlık/ek bileşimi) sunucuda tanımlanmalı.

### 2026-11-22 — `20261122150000` (ürün sahipliği koruması) production'a uygulandı (kullanıcı, SQL Editor) — KATALOG DOĞRULAMASI PASS
`create_table_order_with_print_jobs_impl` (12 arg): md5 `b521ede60c1f275836a002aed75fd1cd`, uzunluk 18518 (izole testte öngörülen değerle BİREBİR), "-- p8: ürün sahipliği" bloğu 2928. konumda; sarmalayıcı md5 `242e2b13…` değişmedi; anon çalıştıramaz, authenticated çalıştırır. Rollback: `rollbacks/20261122150000_order_rpc_product_ownership_guard_rollback.sql`.
Doğrulanmadı: canlı davranış (geçerli ürün KABUL / olmayan ürün RED) — rollback'li `DO` probe'u onay bekliyor.

### 2026-11-22 — Ürün sahipliği koruması: CANLI DAVRANIŞ DOĞRULANDI (rollback'li iki `DO` probe'u, kullanıcı onaylı) — PASS
Sahip kimliğiyle, masa 27, her biri blok sonunda zorunlu `RAISE EXCEPTION` ile iptal: (1) gerçek ürün (`KATI CACIK`, doğru `product_id`) KABUL edildi (`print_job_count=1`, `print_disposition="online"`); (2) olmayan `product_id` (`…x`) REDDEDİLDİ: "Ürün bu işletmeye ait değil." (42501). Doğrulama: siparişler 658→658, baskı işleri 929→929, probe satırı 0 (id ve `local_order_id` ile arandı), son sipariş zamanı değişmedi. Fiyat eşitliği, `product_id`'siz kalem ve gerçek uygulama akışı DOĞRULANMADI/kapsam dışı.

## 2026-11-22 — P9 Gerçek cihaz: ÖN KOŞUL DENETİMİ ve P1 KÖK NEDEN BULUNDU (gerçek test YAPILMADI)
**Ortam (salt-okunur):** Mac LAN IP 192.168.10.158. Eşleşmiş ve erişilebilir iPhone'lar: "Baran iPhone" (iPhone 11 Pro Max), "Gulsen iPhone" (iPhone 11). Çalışan gerçek uygulama (PID 78003) ve köprü (PID 78115) checkpoint derlemesi; P1–P8 kodunu İÇERMEZ. **Yazıcı 192.168.10.100:9100 şu an ERİŞİLEMİYOR** (TCP bağlantısı kurulamadı; yazıcı kapalı/başka ağda olabilir) → fiziksel baskı testi şu an yapılamaz. **Disk: 2,1 GiB boş (%84)** — Release/iOS derlemesi için YETERSİZ (önceki ölçüm 5,0 GiB'ti). Büyük kalemler: CoreSimulator 29 GiB, ~/IBUL_isolated_build 10 GiB (çalışan uygulamanın derlemesi, SİLİNMEMELİ), Xcode DerivedData 7,5 GiB, .pub-cache 1,6 GiB.
**P1 KÖK NEDEN (kodda kanıtlandı):** "Bonjour otomatik bulma simülatörde FAIL, kök neden bilinmiyor" ve gerçek iPhone'un merkezi bulamaması şu üç eksikten kaynaklanıyor:
1. iOS'ta `com.ibul.app/lan_center` kanalının YERLİ (Swift) uygulaması YOKTU → `MissingPluginException` → "this build has no local network search" → hiç sonuç yok.
2. macOS'ta `com.ibul.sellerdesktop/lan_bonjour` kanalının yerli uygulaması YOKTU; geri dönüş `dns-sd` süreci başlatmak, ama Release uygulaması **App Sandbox AÇIK** → dış `dns-sd` çalışamaz → merkez ağda hiç duyurulmuyordu.
3. iOS `Info.plist` (ve macOS) içinde `NSLocalNetworkUsageDescription` ve `NSBonjourServices` YOKTU → iOS 14+ yerel ağ izni istenmez ve yerel ağdaki Mac'e TLS bağlantısı/Bonjour sessizce engellenir (simülatör bunu uygulamadığı için kodla eşleştirme orada PASS idi).
**Yapılan düzeltme (KOD; DERLENMEDİ, gerçek cihazda DENENMEDİ):** `macos/Runner/MainFlutterWindow.swift` → `LanBonjourAdvertiser` (NetService, yayın doğrulanınca true / 5 sn'de değil false) + kanal kaydı; `ios/Runner/AppDelegate.swift` → `LanCenterBrowserService` (NetServiceBrowser, 2,5 sn, IPv4 çözümleme, TXT `svc/rid/mid/fp` → Dart'ın beklediği alanlar) + kanal kaydı; her iki `Info.plist`'e `NSLocalNetworkUsageDescription` (Türkçe) ve `NSBonjourServices=[_ibul-lan._tcp]`. `plutil -lint` OK; sınıflar `swiftc -typecheck` ile macOS 13 ve iOS 13 SDK'larında HATASIZ (Flutter'a bağlı kanal yapıştırma satırları tip denetiminden geçmedi — derlemede görülecek). Xcode proje dosyası değiştirilmedi (sınıflar mevcut dosyalara eklendi).
**Test sırası (onay noktalarıyla):** (0) disk temizliği + tek birleşik derleme (P6–P8 kodu + bu yerli kod + `IBUL_LAN_EVIDENCE_VERIFIER_URL` + P10 ad/logo) → ONAY: DerivedData silme, derleme; (1) A: internet açık, iPhone+Mac LAN eşleştirme, yetkili alt yönetici, masa 27, sipariş, TEK fiş (yazıcı açılmalı; TEST fişi kotası) → ONAY: fiziksel baskı; (2) B: yalnız WAN kesintisi → ONAY: ağ kesintisi; (3) C: uygulamayı kapat-aç; (4) D: internet geri, senkron, mükerrer yok; (5) E: izin iptali. Her sonuç Gerçek uygulama / LAN merkezi / Backend / Fiziksel baskı / Senkronizasyon olarak ayrı PASS/FAIL raporlanacak.

### 2026-11-22 — Disk temizliği (kullanıcı onaylı): Xcode DerivedData `Runner-*` silindi
Aktif derleme/açık dosya yoktu. Silinen: 11 `Runner-*` klasörü (biri 6,0 GiB); kalan `ModuleCache`, `SDKStatCaches`, `SymbolCache`. Disk boşu 2,1 → 8,2 GiB (%84 → %57). `~/IBUL_isolated_build` (çalışan uygulamanın derlemesi) ve CoreSimulator'a dokunulmadı. Tam macOS Release + iOS derlemesi için 8,2 GiB sınırda; derleme öncesi tekrar ölçülecek.

### 2026-11-22 — DÜZELTME (P9 "P1 kök neden" bölümü GEÇERSİZ) + doğru proje ağacı haritası
**Hata:** P9'da iOS/macOS yerli Bonjour koduna ve plist anahtarlarına `ibul_app/ios` ve `ibul_app/macos` içinde baktım; bunlar MÜŞTERİ uygulamasının (`com.ibul.app`) platform klasörleri. Satıcı/garson platform projeleri DEPO KÖKÜNDEKİ `/ios` ve `/macos`'tur ve bu eksikleri ZATEN içerir: `macos/Runner/LanBonjour.swift` (NetService duyurusu, `com.ibul.sellerdesktop/lan_bonjour`), `ios/Runner/AppDelegate.swift` (`com.ibul.app/lan_center` kanalı, `NWBrowser`) ve `ios/Runner/Info.plist` (`NSLocalNetworkUsageDescription`, `NSBonjourServices`). Yani "yerli kod/plist yoktu" bulgusu YANLIŞTI; P1'in gerçek kök nedeni HÂLÂ BİLİNMİYOR (gerçek cihazda ve doğru derlemeyle denenmeli).
**Geri alındı:** benim yanlış ağaca yazdığım 4 dosya `git checkout` ile geri alındı (`ibul_app/ios/Runner/AppDelegate.swift`, `ibul_app/ios/Runner/Info.plist`, `ibul_app/macos/Runner/Info.plist`, `ibul_app/macos/Runner/MainFlutterWindow.swift`; hepsinde fark yalnız benim 195 eklememdi). Müşteri uygulamasına yerel ağ izni/Bonjour eklenmedi. Commit edilmemişti.
**Doğru harita:** `/macos` = satıcı masaüstü (`AppInfo.xcconfig`: `IbulSellerDesktop`, `com.ibul.sellerdesktop`) + müşteri varyantı (`Customer.xcconfig`: `IBUL`, `com.ibul.customer`, `APP_DISPLAY_NAME = İBUL`); `scripts/build_seller_desktop.sh` kökten `lib/main_seller.dart` derler. `/ios` = satıcı/garson iPhone projesi (bundle `com.example.ibul2026`, görünen ad "IBUL App"). Müşteri iOS IPA'sı `ibul_app/ios` ile (`com.ibul.app`, `lib/main_customer.dart`).
**İkon (P10 için):** macOS'ta satıcı ve müşteri varyantı AYNI `AppIcon` setini kullanır (`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`, pbxproj hedef düzeyinde); satıcıya özel ikon için AYRI bir ikon seti (`SellerAppIcon`) + satıcı yapılandırmalarında bu adın seçilmesi gerekir ki müşteri macOS ikonu değişmesin. iOS'ta tek hedef, tek `AppIcon` seti (`/ios/Runner/Assets.xcassets/AppIcon.appiconset`). Logo klasörü: `assets/branding/seller/`.

## P10 — İBUL Satıcı adı ve logosu (2026-11-22)
- Kaynak: `assets/branding/seller/ibul_satici_1024.png` — 1024×1024, PNG, sRGB (gömülü profil yok, sRGB varsayılır), alfa kanalı var ama tüm pikseller opak (0 şeffaf piksel); görsel kare, köşe yuvarlatması yok.
- iOS (kök `/ios`, satıcı/garson): `AppIcon.appiconset` 21 boyut yeniden üretildi, alfa kanalı çıkarıldı (App Store uyumlu). Görünen ad `İBUL Satıcı`.
- macOS (kök `/macos`): yeni `SellerAppIcon.appiconset` (824 px sanat + yuvarlatılmış köşe, 16–1024). Yalnız satıcı konfigürasyonları (Debug/Release/Profile/Debug-Offlinetest) `SellerAppIcon` seçer. Görünen ad `AppInfo.xcconfig` → `İBUL Satıcı`, offlinetest → `İBUL Satıcı Test`.
- Müşteri: `Release-Customer` hâlâ `AppIcon` + `İBUL` + `com.ibul.customer` (xcodebuild -showBuildSettings ile doğrulandı). Bundle id, Keychain, kullanıcı verisi değişmedi. `ibul_app/ios|macos` dokunulmadı.
- Derleme yapılmadı; `actool` ile SellerAppIcon.icns derlendi (PASS).

## 2026-11-22 (akşam) — P11 Gerçek LAN testine hazırlık: istasyon yazıcı yönlendirmesi + telefonda merkez durumu
**Ortam:** Mac "Baran iPhone'u" kişisel erişim noktasında (`172.20.10.2`); yazıcı `192.168.10.100:9100` bu ağdan ERİŞİLEMEZ → fiziksel baskı ve gerçek LAN adımları **BLOCKED (ortam; kod hatası değil)**. Production'a yazılmadı, sipariş/adisyon/ödeme oluşturulmadı, baskı gönderilmedi.
**Production salt-okunur doğrulama:** `lan_staff_authority(uuid,uuid)`, `register_/revoke_restaurant_lan_print_evidence_key`, 12 argümanlı `create_table_order_with_print_jobs(_impl)`, `transfer_table_orders` (8 arg) mevcut; anon çalıştıramaz. Eksik migration bulunmadı.
**KÖK NEDEN (kod, kanıtlı) — LAN siparişinin fişi yazıcı hedefi taşımıyordu:** `RestaurantLanHost._enqueueStationJobs` işi `printerSnapshot: {}` ile yazıyor, `deliverToBridge` `/print/kitchen` isteğine hedef koymuyordu → köprü kendi varsayılanına / son bastığı adrese (`last_kitchen_tcp`) gönderiyordu; istasyon→yazıcı eşleşmesi bu yolda hiç kullanılmıyordu.
**Düzeltme:** `restaurant_offline/lan_station_printer.dart` (yeni): `lanStationPrinterResolver` çevrimiçi mutfak yoluyla AYNI kuralı kullanır (`DesktopPrintOrchestrator.resolveProductionPrinter`: istasyon eşleşmesi, yoksa Mutfak rolü yazıcısı). Host'a `stationPrinter` parametresi; çözülen hedef işe yazılır (yeniden denemede yazıcı değişmez); `_kitchenBody` hedef alanlarını (`target_host/port`, `printer_queue`, profil) köprüye iletir. Yazıcısı olmayan istasyon: sipariş KAYDEDİLİR, iş kesin `failed` ("gönderilmedi"), köprüye hiçbir şey gitmez. Çözüm 30 sn önbellek; okuma 3 sn'de dönmezse/hata verirse son bilinen istasyon yazıcısı kullanılır (kesin "yazıcı yok" yanıtı bunu siler); merkez açılırken istasyonlar önceden çözülür (`warmLanStationPrinters`). `stationPrinter` verilmezse eski davranış aynen (testler).
**Telefonda Mac Yazıcı Merkezi durumu (yeni):** merkezde salt-okunur `POST /lan/center/status` (`lan_center_status.dart`; `/lan/floor` ile aynı zincir: mTLS cihaz sertifikası + iptal + `_staffGrantError` + sıra no; şube süzmesi). İçerik: Mac köprüsü gerçekten yanıt veriyor mu (`/health`, 1,5 sn), kayıtlı yazıcılar, istasyon eşleşmeleri, senkron ve baskı sayıları, masa/yerel sipariş özeti; sır ve tahsil edilmiş gelir YOK. İstemci `WaiterLanLink.centerStatus()`. Arayüz: `widgets/lan_center_status_card.dart` ("Ana bilgisayar · Yazıcı Merkezi"; ulaşılamıyorsa "bilinmiyor", "kapalı" demez; "Yeniden dene") `RestaurantLocalOpsPage` içinde; çevrimdışı Genel Bakış eşleşmiş+erişilebilir merkezden okur ve "Kaynak: Ana bilgisayardan" etiketler, aksi halde cihaz-yerel davranış.
**Testler:** taban (değişiklik öncesi) `test/restaurant_offline`, `test/restaurant`, host/link/center, `test/features/seller` 449/449. Yeni: `lan_station_printer_test.dart` (5), `lan_center_status_test.dart` + host testi + kart/Genel Bakış widget testleri (5). Geniş koşu (`restaurant_offline`, `restaurant`, `services`, `features/seller`, `utils`, `printer_setup`): 1063 geçti / 13 kaldı; 13'ün dökümü: `mobile_order_print_service_test` 7, `lan_bridge_sync_test` 2 (ortam değişkeni ister), `money_session_catch_log_test` 1 (üçü PROJECT_MAP §7-12'de bilinen), `lan_private_listen_test` 1 (test bağlayıcısı başlatılmadan SharedPreferences), `garson_table_area_groups_test` 1 ("Diğer" sıralaması; dosyalar bu çalışmada değişmedi), `offline_panel_identity_test` 1 (P7'de eklenen `dashboard`'ı beklemeyen eski beklenti → GÜNCELLENDİ, şimdi geçiyor). Son dört maddenin değişiklik öncesinde de başarısız olduğu ayrıca koşularak KANITLANMADI (ilgili dosyalara dokunulmadı).
**Açık / doğrulanmadı:** gerçek iPhone↔Mac uçtan uca; `resolveProductionPrinter`'ın WAN kesikken gerçek süresi (3 sn sınırı + son bilinen yazıcı ile korunuyor, ölçülmedi); `RestaurantLocalOpsPage` telefonda yalnız yazıcı ayarını görebilen hesaplara açılır (`_actorMaySeePrinterSettings`); `pubspec.lock` `flutter analyze`'ın `pub get`'i ile değişti (crypto/ffi/pointycastle "direct main").
**Test prosedürü:** `docs/PILOT_REAL_DEVICE_LAN_TEST_PLAN.md` §10.
**Derlemeler (2026-11-22 akşam, ikisi de production yapılandırması + `IBUL_LAN_EVIDENCE_VERIFIER_URL`):** macOS `flutter build macos --target lib/main_seller.dart --release` → `~/IBUL_isolated_build/flutter-build/macos/Build/Products/Release/IbulSellerDesktop.app` (209 MB; `com.ibul.sellerdesktop`, "İBUL Satıcı", `codesign --verify --deep --strict` OK, köprü paket içinde; ikilide `lan/center/status` ve doğrulayıcı adresi var). iOS `flutter build ios --release -t lib/main_seller.dart` → `build/ios/iphoneos/Runner.app` (109 MB; `com.example.ibul2026`, "İBUL Satıcı", `NSBonjourServices=[_ibul-lan._tcp]`, yerel ağ açıklaması var, imza OK) ve `devicectl` ile Baran iPhone'a mevcut uygulamanın ÜZERİNE kuruldu. Önceki (checkpoint) macOS uygulaması yedeği: `~/IBUL_checkpoints/20261121-restaurant-working/app-backup/IbulSellerDesktop.app` (imza OK). **Doğrulanmadı:** iki yeni derleme de henüz AÇILMADI/ekranda denenmedi; derleme anında çalışan eski uygulama süreci kapatılmadı (kullanıcı yeniden başlatacak). Önbellek hazırlığı (katalog/masa/yetki) kullanıcı oturumu gerektirir: internet varken Mac'te ve iPhone'da giriş + Garson ve Sistem sayfalarının açılması (prosedür §10.0 P4). Disk: 12 GiB boş.

## 2026-11-22 (öğleden sonra) — P12 Gerçek cihaz hazırlığı: iki engel bulundu/düzeltildi, Mac gerçek ekranda doğrulandı
**Engel 1 — ağ değişince otomatik yeniden bağlantı ÇALIŞMAZDI (kod, testle kanıtlı):** istemci (`RestaurantLanClient`, `WaiterLanLink`) sunucu SERTİFİKASININ tam SHA-256'sını sabitliyordu; merkez adresi değişince `LanTlsMaterial.ensureServerAddress` sertifikayı yeni IP için yeniden düzenliyor (anahtar aynı, parmak izi yeni) → `_answersAsSavedCenter` ve `chooseLanCenter` eşleşmiyor → yeniden eşleştirme gerekiyor; internetsiz ağda yeni eşleştirme sipariş kabul etmez. **Düzeltme:** açık anahtar sabitleme. `certificatePublicKeySha256Hex` (SPKI özeti; `lan_cert_material.dart`), `LanTlsMaterial.publicKeyPinOf`, `RestaurantLanClient.pinnedServerKey` (+ kabul edilen sunucunun parmak izi/anahtarı), `WaiterLanLink._keyPin` (`server_key` olarak saklanır; eşleşme anında ve eski eşleşmelerde ilk başarılı bağlantıda öğrenilir), `_checkSavedCenter` duyurudaki yeni parmak izine güvenmeden aynı makine kimliğini duyuran adayı TLS'te kayıtlı anahtarı kanıtlamaya zorlar; sonra `_pin` yeni sertifikaya güncellenir. Testler: `test/services/lan_server_key_pin_test.dart` (2), `waiter_lan_link_test.dart` yeni senaryo (adres değişimi → onaysız yeniden bağlanır + sipariş; aynı makine kimliğini duyuran sahte merkez REDDEDİLİR; uygulama yeniden açılınca korunur).
**Engel 2 — eski yerel sipariş kendiliğinden production'a gidecekti:** Mac kuyruğunda `local-order-1793736854400492-1173607028` (2026-11-03, masa 19, 320 TL, baskı `uncertain`, `syncFailed`; bulutta YOK). Kayıt Anahtar Zinciri kopyasından geri yüklendiği için dosyadan ayırmak etkisiz. Kullanıcı kararı: karantina. **Kural:** `selectOrdersForSync(staleAfter: orderSyncStaleAfter = 48 sa)` — 48 saatten eski kayıt otomatik/toplu eşitlemeye girmez; kayıt silinmez/değişmez. Test: `sync_selection_test.dart` (+1); sabit tarihli `restaurant_lan_host_test` senaryosu güncel tarihe çevrildi. Sınır: 2 günü aşan kesintide siparişler kendiliğinden gitmez; tekil "eski kaydı gönder" arayüzü YOK.
**Derleme (3. tur, iki düzeltmeyle):** macOS Release 14:17 (imza OK) ve iOS Release; iPhone'a kuruldu (`devicectl`: installed). Not: iOS paketinde yerel `codesign --verify --deep --strict` "a sealed resource is missing or invalid" dedi (önceki derlemede OK idi); cihaz kurulumu kabul etti, nedeni incelenmedi.
**Mac — GERÇEK EKRANDA (yeni derleme, sahip oturumu kendiliğinden geri geldi):** Genel Bakış AÇILDI; Garson AÇILDI (27 masa, 1 dolu: Bahçe 8 gerçek açık adisyon — dokunulmadı); Sistem AÇILDI; Yazıcı Ayarları: 1 kayıtlı yazıcı; Yazıcı Servisi anahtarı AÇILDI → köprü `127.0.0.1:3001`, LAN merkezi `172.20.10.2:18772` (yalnız özel adres), `/lan/discover` yanıt veriyor, Bonjour `_ibul-lan._tcp` "IBUL Merkez" yayını (TXT rid/mid/fp) görüldü; Eşleştirme: kasap/Ocak/fırın → "aa" (192.168.10.100:9100) KORUNMUŞ; şerit "Bulut bağlı — 1 yerel sipariş henüz eşitlenmedi". Bulut sayımı (salt-okunur, taban): orders 633, print_jobs 927, kanıt olayı 0, eski sipariş bulutta 0 (yeni sürüm göndermedi). Yazıcı bu ağdan erişilemez → "bağlantı henüz doğrulanmadı" (beklenen, BLOCKED-ortam).
**Kalıcı depo (salt-okunur):** `printer_repository_last_good_v1_*` tercihlerde: yazıcı "aa" 192.168.10.100:9100; üç istasyon birincil eşleşmesi → internet yokken yazıcı hedefi buradan çözülür. Masa/ürün/yetki önbelleği Anahtar Zinciri'nde (oturum sırlarıyla aynı depo) → dışarıdan OKUNMADI; ekrandan/merkez kartından doğrulanacak.
**Bağımsız kayıt:** `~/IBUL_checkpoints/lan-test-20261122/kayit.sh` (10 sn'de bir, salt-okunur, sırsız) → `durum-gunlugu.log`. Kılavuz: `~/Desktop/IBUL_LAN_TEST_KILAVUZU.txt`. Yedek: aynı klasörde `onceki-yerel-veri/`.
**Bekleyen:** iPhone ekran kontrolleri, internet varken eşleştirme (anahtar sabitlemesinin öğrenilmesi için şart), telefonda merkez kartı.

## 2026-11-22 (ikindi) — P13 Gerçek LAN testinde bulunan hatalar (P0–P6 + macOS adı)
**P0 yazıcı (ölçüm, kod değil):** Mac `en0` 192.168.10.67/24, ağ geçidi .1. `192.168.10.100` ping + ARP yanıtlıyor (MAC `02:80:fb:94:2a:f4`, TTL 255 = gömülü cihaz), ama 9100/80/4000 SYN'e HİÇ yanıt vermiyor (zaman aşımı); diğer portlar anında RST. Alt ağda 9100 açık başka cihaz yok; iPhone .187 görünüyor (istemci izolasyonu yok). Sonuç: "bulunamadı" doğru, yazıcının ağ kartı/servisi takılı veya hata durumunda → BLOCKED-donanım (yazıcıyı kapat-aç, self-test fişi). Tarama alt ağ seçimi doğru.
**Köprü düzeltmesi (mükerrer fiş):** `network_transport.print_tcp` hata aşamasını işaretler (`phase` connect/write, `write_may_have_started`); `server.py` ve `print_station.py` `_is_transient_transport_error` yazma başladıysa otomatik tekrar YAPMAZ (önceden `tcp_timeout` metni "geçici" sayılıp aynı fiş bir kez daha gönderiliyordu). Test: `tests/test_tcp_write_phase_no_resend.py` (3). Test fişi başarı metni artık fiziksel baskı iddia etmez (`printer_test_dialog.dart`).
**P2 kök neden + düzeltme:** `_offlineStartActive` yalnız başarılı `_loadStoreProfile` ile kalkıyordu ve bulut dönünce TEK deneme yapılıyordu (yalnız `mode` değişiminde); deneme geçici hatada düşerse panel kalıcı üç sayfada kalıyordu. "Bulut erişilemiyor…" metni de yalnız başarılı Garson anlık görüntüsünde siliniyordu. Yeni: `decideCloudRecovery` (`offline_page_policy.dart`) — bulut açıkken 10 sn aralıkla yeniden dener, başarısız denemede çalışan paneli hata sayfasıyla değiştirmez, başarıda Genel Bakış + Garson yenilenir (`_recoverFromOfflineStart`, `_refreshBoardsAfterCloudBack`). İzleyici takılma koruması (`stuckRefreshAfter` 20 sn). Test: `cloud_recovery_plan_test.dart` (8). 48 saat karantina kuralına dokunulmadı.
**P3:** profil/sahip-id/menü kapısı sorguları zaman sınırsızdı (internetsiz Wi-Fi'da sonsuz spinner): `StoreService.cloudLookupTimeout` 8 sn (`store_service.dart` 4 sorgu, `auth_service.loadStaffMenuGate` 2 sorgu, `get_my_staff_access`). Zaman aşımı mevcut çevrimdışı açılış yoluna düşer. Not: iOS Bonjour/yerel ağ izni kök `ios/` projesinde MEVCUT (ajanın `ibul_app/ios` bulgusu yanlış alarm).
**P1:** `RestaurantLanDevice` + `deviceName/platform/lastSeenAt` (eski JSON uyumlu), `LanDeviceInfo`, `revokeDevice` (`/lan/revoke` aynı yolu kullanır), `widgets/lan_paired_devices_section.dart` ("Bağlı Cihazlar"; iptal yalnız sahip veya `managePrintSettings`), telefonda "Bağlandığım Ana Bilgisayar" (`lan_center_status_card.dart`). **Bayat bind:** merkez eski ağ adresinde (172.20.10.2) dinlemeye devam ediyordu; `decideLanRebind` + `SellerLanCenter.followNetworkOnce` (10 sn, iki ardışık bayat okuma) mevcut `start` yoluyla yeni adrese geçer, anahtar/cihaz kayıtları aynı. Açık: yetki özeti ve personel adı eşlemesi (staffId↔`_subAdmins.id`) doğrulanmadı.
**P5:** yetki penceresi yeniden tasarlandı (`staff_account_dialog*.dart`, `staff_dialog_*`, `staff_page_access_widgets.dart`, `staff_live_summary.dart`): masaüstü iki bölüm + sabit alt çubuk, mobil tam ekran; Erişim yok/Görüntüle/Tam yönetim = `StaffPageLevel`; kayıt sözleşmesi aynı.
**P6:** `SellerMenuItemState { open, lockedOffline }`; kilitli satır okunur başlık + kilit + "İnternet gerekli" (kontrast 12.9:1), yetkisiz sayfa gizli kalır.
**P4:** BLOCKED (güvenlik incelemesi): `close_table` RPC'si sipariş kümesi/işlem kimliği almıyor → çevrimdışı kapatma sonradan gönderilirse başka cihazın yeni siparişlerini de kapatabilir; mühür `closeBill` taşımıyor. Gerekli sözleşme: `offline_settlements` tablosu + `apply_offline_table_settlement` RPC + hub imza anahtarı + sunucu bayrağı (yalnız ekleme; geri alma = bayrak kapat + revoke). `offlineMoneyOperationBlock` korunuyor.
**macOS ad:** Dock'taki `IbulSellerDesktop` iki nedenden: (1) Dock'a sabitlenmiş karo ESKİ kopyayı gösteriyor (`Desktop/ibul2026 kopyası 9/build/.../Debug/IbulSellerDesktop.app`); (2) gerçek pakette yerelleştirilmiş ad yoktu. Düzeltme: `scripts/macos_seller_display_name.sh` (yalnız `com.ibul.sellerdesktop*`; `tr/en.lproj/InfoPlist.strings`, `LSHasLocalizedDisplayName`; paket adı/kimliği aynı), "Embed IbulPrintBridge" adımına bağlı; pencere başlığı `IbulAppDisplayName`. `SellerAppIcon` yüklenen logoyla aynı görsel.
**Doğrulama:** macOS Release 15:17 derlendi, imza OK, `LSDisplayName="İBUL Satıcı"`, pencere başlığı "İBUL Satıcı", Genel Bakış çevrimiçi yüklendi (GERÇEK EKRAN). Flutter penceresi arka plan tıklamasını almadığı için Sistem/Bağlı Cihazlar/yetki penceresi/menü ekranda GEZİLEMEDİ. Testler: services+offline+widgets+printer 1116/13 (13'ü bu değişikliklerden bağımsız), köprü 208 testte 27 ortam/eski hata (Pillow yok vb.), yeni köprü testi 3/3.
**iOS:** Release derlendi (109 MB, "İBUL Satıcı", `com.example.ibul2026`) ve `devicectl` ile Baran iPhone'a mevcut uygulamanın üzerine kuruldu (listede görünüyor). iPhone ekranı bu oturumda GÖRÜLMEDİ: donma/yeniden bağlanma/menü doğrulaması kullanıcıda. **Dock:** sabitlenmiş eski karo kaldırılıp gerçek uygulama sabitlenmeli (kullanıcı kararı bekleniyor).

## 2026-11-22 (15:35–15:50) — P14 Gerçek doğrulama turu: yazıcı kök nedeni, Dock, macOS ekranları, kimliğe özel karantina
**P0 yazıcı (ölçüm; yazıcıya veri gönderilmedi, baskı denenmedi):** Mac yalnız Wi‑Fi `en0` 192.168.10.67 (USB Ethernet `en5` takılı, hat yok). `192.168.10.100` ping/ARP yanıtlıyor (MAC `02:80:fb:94:2a:f4`, TTL 255; IP değişmemiş, alt ağda başka aday yok: yalnız .1, .67, .100, .187). 24 portta bağlantı denemesi: 21 kapalı port ANINDA RST (TCP yığını canlı), dinlenen üç port 9100/80/4000 SYN'e yanıtsız (3 sn zaman aşımı, 3/3 tekrar). Mac aynı arayüzden router:80 ve iPhone .187:62078'e TCP açıyor; Mac'te .100'e açık bağlantı yok, uygulama/köprü kapalıyken de aynı. SNMP/Bonjour yanıtı yok. **Sonuç:** kod/Mac/rota değil; yazıcının ağ modülü servisleri dinliyor ama yeni bağlantı kabul edemiyor (bağlantı havuzu dolu/takılı). Çözüm fiziksel: kapat‑aç + self‑test. Neyin tetiklediği KANITLANMADI (köprü soketleri `with` ile kapanıyor; izleme betiği `kayit.sh` dakikada bir `nc -z` yapıyordu).
**Dock:** eski Debug karosu Dock'ta yoktu; Release (`~/IBUL_isolated_build/.../Release/IbulSellerDesktop.app`, `com.ibul.sellerdesktop`, imza OK, yerelleştirilmiş ad "İBUL Satıcı", `SellerAppIcon` = `ibul_satici_1024.png`) Dock'a eklendi; Dock ayarı yedeği oturum scratchpad'inde. **Olay:** paket kimliğiyle açma eski Debug kopyasını (`~/Desktop/ibul2026 kopyası 9/build/.../Debug`, 14 Kasım, karantina kuralı YOK) başlattı; 22 sn açılış ekranında kalıp kapatıldı; bulut salt‑okunur kontrol: eski sipariş 0 kayıt, orders 658 / print_jobs 931, son güncelleme 12:26:25 UTC (açılıştan önce). Eski kopya `lsregister -u` ile kayıttan çıkarıldı (dosya silinmedi); PortableSSD'deki kopyalar hâlâ kayıtlı → uygulama yalnız Dock'tan/yoldan açılmalı.
**macOS GERÇEK EKRAN (Release 15:17, sahip oturumu):** Genel Bakış, Garson (27 masa, 2 dolu), Sistem, Yazıcı Ayarları (servis kapalı, 1 yazıcı "aa" 192.168.10.100:9100, rol Yazıcı merkezi; Adisyon/Mutfak rolü ve kasap/Ocak/fırın → aa korunmuş, "yeni alna" atanmamış), Alt Yöneticiler (4 personel) ve baran için yetki penceresi (iki bölüm, kaydırma, sabit alt çubuk; taşma/çakışma yok; İptal ile kapatıldı, kayıt yapılmadı), Yerel Operasyon Merkezi görüldü. Yazıcı Servisi AÇILMADI → Otomatik Tara, Bağlı Cihazlar listesi, çevrimdışı menü GÖRÜLMEDİ.
**Ekranda bulunan kusurlar (düzeltilmedi):** (1) Alt Yöneticiler yüklenirken spinner yerine "Bu işletmede personel yok / Personel: 0" gösteriyor; (2) Yerel Operasyon "Kayıtlı Ethernet yazıcı yok" diyor, oysa "aa" kayıtlı; (3) "1 kayıtlı yazıcı canlı taramada yok… yazıcıyı yeniden seçin" yönlendirmesi bu arızada yanıltıcı; (4) Sistem'de turuncu şerit geç belirip düğmeleri kaydırıyor (tıklama boşa düşüyor).
**Senkron ekranı:** `local-order-1793736854400492-1173607028` syncFailed (`PGRST301`, JWT yok), baskı belirsiz; `waiter-1795350417518270-…b17d5b1eb014` (bugün 15:27) syncFailed "Senkronizasyon yalnız açık yerel sunucudan yapılır", baskı "yazıcıya iletilmedi".
**P4 kod:** 48 saatlik yaş engeli KALDIRILDI; `quarantinedLocalOrderIds = {local-order-1793736854400492-1173607028}` (`restaurant_offline_sync_service.dart`), `selectOrdersForSync(quarantined:)` otomatik ve elle gönderimde aynı kapı. Testler (`sync_selection_test.dart`): karantina her durumda seçilmez; 30 gün/49 saatlik geçerli kayıt seçilir. `test/restaurant_offline` + `restaurant_lan_host_test` 88/88. **Çalışan Release hâlâ 48 saat kurallı eski derleme; yeni kural için derleme gerekir (yapılmadı).**
**Testler:** Flutter (`services, restaurant_offline, restaurant, features/seller, utils, printer_setup, widgets`): 1699 geçti / 13 kaldı — `mobile_order_print_service_test` 7 (hepsi `print_system_disabled`: test kurulumu Yazıcı Servisi kapısını açmıyor; "aynı sipariş iki kez basılmaz" testi bu yüzden tekilleştirmeyi ÖLÇMÜYOR), `lan_bridge_sync_test` 2 (`IBUL_POSTGREST` ister), `lan_private_listen_test` 1 (bağlayıcı başlatılmıyor), `money_session_catch_log_test` 1, `garson_table_area_groups_test` 1, `web_header_logo_home_test` 1. Köprü (`python3 -m unittest`, pytest kurulu değil): 208 test, 16 başarısız + 11 hata. Yalnız 8'i Pillow yokluğu. Diğerleri ortam DEĞİL: `PrintLogStore.dispatch_checkpoint` yok (5), `reported_device_platform` yok, `PrintStationConsumer` `heartbeat`/`config_loader`/`_legacy_kitchen_checkpoint_key` yok, `is_windows_service` yok, 6 uçta 500≠200 → `test_dispatch_checkpoint` / `test_print_signal_wake` (yeniden başlatma ve çift örnek sonrası tek fiş güvencesi) sınadığı kod bu ağaçta ve yerel kopyalarda BULUNMUYOR. Önceki "27 ortam/eski hata" nitelemesi yanlıştı.
**Test hijyeni hatası:** köprü testleri GERÇEK günlüğe yazıyor (`~/Library/Application Support/IbulPrintBridge/logs/print_logs.jsonl`, koşu sonrası büyüdü; `tcp:192.168.1.100:9100` ve `windows:USB POS-80` satırları testten). Gerçek yazıcıya bağlantı görülmedi.
**Yapılmadı:** P5 çevrimdışı masa kapatma sözleşmesi, iPhone doğrulaması, LAN eşleştirme, çevrimiçi/çevrimdışı geçiş, yeni derleme, checkpoint, commit.
**P0 devam (15:47–15:50, kullanıcı yazıcıyı kapatıp açtı):** açılış sırasında 9100/80/4000 anında RST, ardından üçü de AÇIK; 70 sn'de 6 sn arayla 36 bağlantı denemesinin tamamı başarılı. Köprü tarama kodu (`scan_local_network_printers(['192.168.10.67'])`, bu ağaçtan, yalnız ESC/POS durum sorgusu) 3/3 koşuda 0,75 sn'de `192.168.10.100:9100` `printer_verified=true` buldu; tarama sonrası 9100 hâlâ açık. **Kök neden doğrulandı:** yazıcının ağ modülü takılıydı; yeniden başlatma çözdü. Tetikleyici hâlâ bilinmiyor; tekrar ederse yazıcı firmware/ağ modülü şüphelisi. Gerçek uygulamada Otomatik Tara ve test fişi henüz YAPILMADI (Yazıcı Servisi kapalı; bulutta bekleyen iş yok: son 7 gün completed 24, failed 3, 20 Kasım'dan 1 `claimed`).
**Yazıcı Servisi açıldı (15:50, kullanıcı onayı) — GERÇEK EKRAN:** köprü `127.0.0.1:3001` `/health ok` (paket içi köprü), LAN merkezi yalnız `192.168.10.67:18772`. Otomatik Tara: "1 doğrulanmış yazıcı bulundu — 192.168.10.100:9100, Yazıcı doğrulandı" (Bilgisayar IP 192.168.10.67, ağ 192.168.10.0/24) → **PASS**. Kaydet/Test Fişi basılmadı. Köprü günlüğünde servis açıldıktan sonra yazıcıya gönderim YOK; bulut sayımı değişmedi (orders 658, print_jobs 931). Bağlı Cihazlar: 1 kayıt "Adsız cihaz", platform "Bilinmiyor", "Bağlantı yok", personel `2e2f1914`, ilk eşleştirme 22.11 14:32, son bağlantı 15:26 → cihaz adı/platformu dolmuyor (kusur 5).
**KÖK NEDEN — yerel siparişler buluta HİÇ gidemiyor (kanıtlı, production):** servis açılınca bugünkü geçerli sipariş de eski kayıtla aynı hatayı aldı: `PGRST301 Expected 3 parts in JWT; got 1`. Hata `_postEvidenceVerifier` yolundan. Canlı günlük: `verify-lan-print-evidence` (v1, bugün dağıtıldı) çağrılarının hepsinde (06:18, 10:33, 12:27, 12:30, 12:50 UTC) fonksiyonun KENDİ `rest/v1/rpc/restaurant_lan_print_evidence_public_key` ve `create_table_order_with_print_jobs` çağrıları 401. Neden: `postRpc` servis anahtarını `Authorization: Bearer` + `apikey: anon` ile gönderiyor; ortamdaki servis anahtarı JWT değil (yeni tip `sb_secret_…`), platform bunu veritabanına iletiyor ve veritabanı JWT olmadığı için reddediyor (Supabase "API keys → Known limitations"). Yerel izole geçit bu kuralı modellemediği için testlerde görünmedi. **Yan sonuç:** 3 Kasım kaydının buluta gitmemesinin asıl nedeni de buydu; karantina olmasa da gidemezdi.
**Düzeltme (yerelde, DAĞITILMADI):** `verify_print_evidence.mjs` `serviceKeyHeaders`: JWT biçimli anahtar → `Bearer` + `apikey`; JWT olmayan anahtar → yalnız `apikey`. Test: `verify_print_evidence_deno_test.ts` sahte sunucu artık platform kuralını uyguluyor (düzeltmesiz 5/7 kırmızı, üretimdeki 401 birebir); düzeltmeyle 7/7. Production dağıtımı ONAY bekliyor. Dağıtılırsa: bugünkü `waiter-1795350417518270-…` siparişi (Bahçe 9, 520 TL, baskı "yazıcıya iletilmedi") buluta yazılır ve sunucu mutfak fişi işi üretebilir → Yazıcı Servisi açıkken FİZİKSEL fiş basılabilir.
**Doğrulayıcı v2 production'a dağıtıldı (2026-11-22 ~16:03, kullanıcı onayı):** `verify-lan-print-evidence` sürüm 2, `verify_jwt=true`, canlıdaki `index.ts` korundu; tek fark `serviceKeyHeaders`. **Canlıda henüz DOĞRULANMADI:** dağıtımdan sonra uygulama yeniden denemedi (fonksiyon günlüğünde yeni çağrı yok); senkronu yalnız şerit (`restaurant_offline_banner.dart` `_refreshConnectivityAndCounts`) ve yeniden bağlanma dinleyicisi tetikliyor, Yerel Operasyon'daki yenile düğmesi tetiklemiyor ve elle "şimdi eşitle" düğmesi yok (kusur 6). Arka plan tıklamaları pencereye ulaşmayı bıraktı; tetikleme kullanıcıdan bekleniyor. Geri alma: v1 içeriğini yeniden dağıtmak (fark tek fonksiyon).
**Doğrulayıcı v2 CANLIDA DOĞRULANDI (15:58 yerel / 12:58 UTC):** tam ekran kontrolüyle Garson→Sistem geçişi şeridi yeniden yükleyip senkronu tetikledi. Fonksiyonun `restaurant_lan_print_evidence_public_key` çağrısı 200 (önce 401). Bulut: `waiter-1795350417518270-…b17d5b1eb014` → sipariş `TBL-20261122125827-02DDE4` (`fb2715b7…`, durum `sent`), `order_items` 2 kalem / 520,00 TL (yerelle aynı; `orders.total_amount` açık masa siparişlerinde 0 kalıyor: son 30 günde 81 masa siparişinin 58'i). Sayım 658→659 sipariş, 931→932 baskı işi; yeni iş `failed` olarak yazıldı (yerel kanıt "yazıcıya iletilmedi"), sunucu baskı planlamadı. Köprü günlüğü: yazıcıya gönderim 0. 3 Kasım kaydı bulutta 0. Şerit "1 yerel sipariş henüz eşitlenmedi" (karantinadaki kayıt). Tek sipariş, tekrar yok.
**Kontrollü test fişi (15:59:48, kullanıcı onayı, gerçek uygulama):** Yazıcı Ayarları → Eşleştirme → "Mutfak Genel Test Fişi" TEK tıklama. Uygulama Print Log: `role_test_print_success`, `/print/test`, 854 bayt, hedef `tcp:192.168.10.100:9100`, `queue_status=completed`, `retry_count=0`, bağlantı 6 ms, toplam 7 ms. Köprü `/health` `recentJobs`: köprü 15:50'de başladığından beri TEK iş (`queue-f0b4f6ae1bc7`, completed) → tek fiş, tekrar yok; yazıcı sonrasında da 9100 açık. Kâğıt çıktısı kullanıcı teyidi bekliyor (TCP yazımı kâğıdı kanıtlamaz). Toplam onaylı test fişi: 3 (21.11 23:28, 23:44; 22.11 15:59).
**Düzeltme (kanıt kalitesi):** paket içi köprü `bridge.log` ve `print_logs.jsonl` dosyalarına YAZMIYOR (bridge.log son satırı 19 Kasım; `print_logs.jsonl` bu fişte büyümedi). Bu turdaki "servis açıldıktan sonra yazıcıya gönderim yok" sonucunun dosya günlüğüne dayanan kısmı geçersiz; sonuç `/health recentJobs` (tek iş = bu test fişi) ve bulut sayımıyla ayrıca doğrulandı. Kusur 7: canlı köprünün kalıcı baskı günlüğü yok.
**Kâğıt teyidi:** kullanıcı 15:59:48 "Mutfak Genel Test Fişi"nin TEK kâğıt olarak çıktığını bildirdi (kullanıcı gözlemi; fotoğraf yok) + köprü tek iş `completed` → P0 yazıcı uçtan uca **PASS** (gerçek uygulama → köprü → 192.168.10.100:9100 → kâğıt, tek fiş).
**Yeni macOS Release (16:04, kullanıcı onayı):** `flutter build macos --target lib/main_seller.dart --release --dart-define=IBUL_LAN_EVIDENCE_VERIFIER_URL=…/verify-lan-print-evidence` (önceki derlemeyle aynı tek tanım) → 209,1 MB, `com.ibul.sellerdesktop`, "İBUL Satıcı", `codesign --verify --deep --strict` OK, ikilide karantina kimliği ve doğrulayıcı adresi var. Eski süreç kapatılıp yeni paket yoluyla açıldı (PID 10178, 16:04:48); sahip oturumu geri geldi. **Yazıcı Servisi yeniden açılışta KENDİLİĞİNDEN BAŞLAMADI** (köprü/LAN merkezi kapalı; kusur 8 veya bilinçli kapı — doğrulanmadı); elle açıldı → köprü `127.0.0.1:3001` (derleme 16:05:30), LAN merkezi `192.168.10.67:18772`. Yeni derlemede (48 saat kuralı YOK) servis açıkken: bulutta 3 Kasım kaydı 0, Bahçe 9 siparişi 1 kayıt (tekrar yok), sayım 659/932 değişmedi, şerit "1 yerel sipariş henüz eşitlenmedi" → kimliğe özel karantina GERÇEK uygulamada tutuyor. Yüklenirken geçici yanlış metinler görüldü ("Henüz masa kaydı yok", cihaz rolü "Yalnızca sipariş gönderir") — kusur 1 ile aynı sınıf. iOS derlemesi sürüyor.
**Yeni iOS Release (16:06) + kurulum:** aynı tek derleme tanımıyla `flutter build ios --release -t lib/main_seller.dart` → 109,1 MB, `com.example.ibul2026`, "İBUL Satıcı", ikilide karantina kimliği var, yerel imza doğrulaması hatasız. `devicectl` ile Baran iPhone (iPhone 11 Pro Max, `A6BE074C…`) üzerine kuruldu: "App installed", uygulama listesinde 1.0.0 (1). Gulsen iPhone erişilemez durumda, kurulmadı. **iPhone ekranı GÖRÜLMEDİ; hiçbir iPhone maddesi PASS değil.** Disk: 23 GiB civarı.
**iPhone ekran görüntüleri (kullanıcıdan, 16:08 ve 16:10, yeni iOS derlemesi):** Genel Bakış açılıyor ("Canlı", ciro ₺4.100, Mac ile aynı); sol menü başlığı "efe — Restoran Müdürü" → oturum SAHİP DEĞİL, alt yönetici (önceki "sahip girişi" değerlendirmem yanlıştı). Menü: Genel Bakış, Ürünlerim, Listeler, Siparişler, Garson, Sistem, Mağaza Profili, AVM Talepleri, Reklam, Finans, Başarılarım, Yorumlar, Destek; Alt Yöneticiler ve Sözleşmeler yok (yetkiyle tutarlı mı ayrıca doğrulanmadı). Yerleşim temiz. Kullanıcı: garsona tam yetki verdiğini ve sipariş eklemenin çalıştığını bildirdi. Sahip girişi, Garson/Sistem sayfaları, LAN eşleştirme, çevrimdışı geçiş iPhone'da GÖRÜLMEDİ.
**Yeni derlemede köprü işleri (`/health`, köprü 16:05:30'dan beri 3 iş, hepsi completed, retry 0):** 16:05:42 `receipt` (kaynağı BELİRSİZ — ben göndermedim; servis açıldıktan 12 sn sonra; kullanıcıya soruldu), 16:05:58 `kitchen_ticket` (16:06:00'da buluta yazılan `TBL-20261122130600-0A3468` siparişinin fişi; bulut işi `paused_by_operator` → sunucu ikinci kez bastırmadı, tek sipariş kaydı), 16:11:24 `receipt` (kullanıcının Yazıcılar → Test penceresinden gönderdiği test, 50 297 bayt). Kusur 9: test başarı mesajı uyarı simgesiyle ve "mevcut kayıt güncellendi" metniyle gösteriliyor; baskı başarılı olduğu hâlde sağ alttaki rozet "Yazıcı doğrulanmadı" kalıyor.
**16:05:42 fişi:** kullanıcı kendisinin gönderdiğini bildirdi → yeni derlemede köprünün üç işinin üçü de açıklandı (2 kullanıcı fişi, 1 sipariş mutfak fişi); servis açılışında kendiliğinden baskı YOK.

## 2026-11-22 (16:15) — CHECKPOINT `ibul-restaurant-checkpoint-20261122`
Commit `59bcaa5` (318 dosya; `build` sembolik bağlantısı hariç tüm çalışma ağacı; gizli anahtar taraması temiz; ortak-yazar satırı yok), dal `checkpoint/restaurant-verified-20261122`, açıklamalı etiket. Yedek: `~/IBUL_checkpoints/20261122-restaurant-verified/` (macOS ve iOS paketleri, git paketi, `manifest`, `SHA256SUMS`; 342 MB; Mac yedeğinin imzası doğrulandı ve LaunchServices kaydından çıkarıldı). `2a2e42b` ve dünkü checkpoint yerinde. Uzak sunucuya gönderilmedi. Bu not checkpoint commit'inden SONRA eklendi (commit dışı).

## 2026-11-22 (16:15–16:35) — P5 Çevrimdışı masa kapatma: sözleşme + izole kanıt (production'a DOKUNULMADI)
Üretimdeki `close_table_with_history` salt-okunur okundu: çağrı anında masadaki TÜM açık siparişleri kapatıyor; sipariş kümesi ve işlem kimliği yok. Yeni, yalnız eklemeli taslak: `20261122160000_offline_table_settlement.sql` ("Local only" başlıklı) — `restaurant_offline_settlement_settings` (işletme başına anahtar, varsayılan kapalı), `restaurant_offline_settlements` (`(restaurant_id, settlement_id)` tekil), `restaurant_offline_settlement_orders` (sipariş başına tek uzlaştırma), `apply_offline_table_settlement(...)` (yalnız servis rolü). Sözleşme ve idempotency modeli: `docs/OFFLINE_TABLE_SETTLEMENT_CONTRACT.md`. İzole PostgreSQL 17 (scratchpad, 127.0.0.1:55477, iş bitince durduruldu): `run_isolated_offline_table_settlement.sh` 25 PASS / 0 hata; 5 mutasyonun 5'i kırmızı (07 numaralı testte boş değer karşılaştırması düzeltildi). **Yapılmadı / doğrulanmadı:** üretim tetikleyicileriyle (`guard_restaurant_staff_order_write`, `orders_money_authority_guard`) uyum, `restaurant_has_permission` ile yetki eşdeğerliği, `table_payments` kaydı, doğrulayıcı uç noktası + imza, uygulama tarafı. `offlineMoneyOperationBlock` yerinde. Commit YOK.

## 2026-11-23 (00:00–01:15) — P15 Kalıcı ve otomatik yazıcı sistemi (production'a migration/deploy YOK)

Kapsam: kayıt kalıcılığı, otomatik servis başlatma, yeniden bağlantı görünürlüğü, tek fiş güvencesi. Taban: `4784f12` (checkpoint `59bcaa5` korunuyor). Supabase şemasına, RLS'e, Edge Function'a dokunulmadı. Fiziksel baskı gönderilmedi, Mac yeniden başlatılmadı.

### Kök nedenler (kodda doğrulandı)
| # | Kök neden | Düzeltme | Dosya |
|---|---|---|---|
| 1 | Herhangi bir yazıcıyı silmek iki rolü de (adisyon + mutfak) yerelde ve bulutta siliyordu; silme başarısız olsa bile | Önce kayıt silinir, sonra yalnız o yazıcıya işaret eden rol temizlenir | `services/desktop_print_orchestrator.dart` |
| 2 | Oturum yok/süresi dolmuşken bulut `[]` döner; bu, kayıtlı yazıcıların yerel son iyi kopyasının üzerine yazılıyordu | Oturumsuz boş yanıt dolu kopyayı silmez | `services/printer_repository.dart`, `print_station_service.dart` |
| 3 | Bulut 5xx / ağ geçidi hatasında kopyaya dönülmüyordu; istasyonların hiç yerel kopyası yoktu; internet yokken Yazıcılar sekmesi "Yazıcılar yüklenemedi" gösteriyordu | 5xx "ulaşılamıyor" sayılır; `stations` kopyası; `watchPrinters` bağlantı hatasında kopyayı gösterir | `printer_repository.dart`, `station_repository.dart` |
| 4 | Açılışta hiçbir şey başlamıyordu, tercih yoktu | `RestaurantCenterAutoStart` (tek başlatma dizisi + kalıcı tercih, süreç başına en fazla bir açılış başlatması) | `services/restaurant_offline/restaurant_center_auto_start.dart`, `lib/main_seller.dart`, `screens/seller/kitchen_print_management_page.dart` |
| 5 | Garson modülünün kurtarma taraması (`recoverPendingJobs`) Başlat'tan önce bekleyen işleri zaman süzgeci olmadan alıyordu | `PrintServiceStartGate.jobIsFromBefore` süzgeci | `services/order_print_job_service.dart` |
| 6 | Hızlı yerel mutfak baskısı bütün istasyonları tek yazıcıya, o da yoksa köprünün "son bastığı" adrese gönderiyordu | İstasyonun atanmış yazıcısı, yoksa KAYITLI Mutfak rolü; karar yoksa hızlı yol hiç basmaz | `order_print_job_service.dart` (`resolveFastPathStationPrinters`), `printer_repository.dart` (`SavedStationPrinters`) |
| 7 | Köprü tekilleştirme anahtarını baskıdan önce kaydedip başarısızlıkta silmiyordu: hiç basılmamış fiş sonraki denemede "zaten basıldı" yanıtı alıyordu; yazma aşaması bilgisi HTTP yanıtında yoktu | `retry_safe` / `write_may_have_started` / `print_outcome`; bağlantı aşaması hatasında anahtar unutulur; belirsiz iş tekrar gelirse 409; yalnız `operator_confirmed_retry` yeniden basar | `local_print_bridge/server.py`, `print_station.py`, `restaurant_local_print_queue_service.dart`, `desktop_print_hub.dart` |
| 8 | Hub ısınması `printers.seller_id` (olmayan sütun) sorguluyordu | `restaurant_id` | `desktop_print_hub.dart` |
| 9 | Kayıt ile erişilebilirlik aynı yerde gösteriliyordu; "canlı taramada yok … yeniden seçin" uyarısı; yüklenirken "Eklenmedi" | `PrinterReachabilityMonitor` + "Kurulum özeti" kartı + satır altı durum; metinler düzeltildi; "Temizle" onay ister | `features/seller/panel/printer_center/printer_registry_status.dart`, `kitchen_print_management_page.dart`, `desktop_printer_setup_page.dart` |

### Otomatik testler
- Yeni Dart testleri: `test/services/restaurant_center_auto_start_test.dart` (15), `test/printer_persistence/{station_printer_routing,printer_registry_status,old_jobs_held_at_start}_test.dart` (14 + 12 + 3), `printer_repository_offline_rows_test.dart` (+6). Hepsi PASS.
- Güncellenen testler: `desktop_print_orchestrator_test.dart` (silme yalnız ilgili rolü temizler), `kitchen_print_after_commit_test.dart` (fiş yalnız kayıtlı yazıcıya gider; önceden kayıtsız "bridge-default"a basıyordu).
- Tam Flutter çalıştırması (bu turun ortasında): 57 başarısız; aynı dosyalar `4784f12` kopyasında çalıştırıldı → 47'si HEAD'de de aynı (ana sayfa, araç kiralama, destek, CSV, `desktop_printer_setup_page` anahtar testleri, `garson_lan_pilot_ui`, `mobile_order_print_service`, `lan_bridge_sync`, `lan_private_listen` …). Bu turdan kaynaklanan 7 başarısızlık (yukarıdaki iki test dosyası) düzeltildi. `mixed_service_dialog_test` her iki tarafta da asılı kalıyor.
- Köprü (Python `unittest`, 218 test): sistem Python'unda 27 başarısız = Pillow/pyusb eksikliği. Paketlenmiş yardımcının kendi `_internal` kitaplıklarıyla (`PYTHONPATH`, Pillow 12.2.0, pyusb 1.3.1, libusb) 19 başarısız; aynı 19'u HEAD kaynağında da birebir aynı (test/kaynak kayması: `reported_device_platform` yok, `/health` `print_system_enabled` alanı yok vb.). Yeni 10 köprü testi PASS (`test_print_failure_outcome.py`, `test_stopped_service_and_uncertain_repeat.py`: kapalı serviste 503 + yazıcıya 0 bayt; belirsiz fiş tekrar basılmaz ve "basıldı" denmez).

### Gerçek uygulama (com.ibul.sellerdesktop Release, production'a bağlı; baskı gönderilmedi)
| Adım | Gözlem | Durum |
|---|---|---|
| Yeni derleme | 209,3 MB, `codesign --verify --deep --strict` OK; köprü yardımcısı (22 Kas 10:06) DEĞİŞMEDİ | PASS |
| Açılış (tercih kapalı) | "Yazıcı merkezi kapalı", köprü/LAN yok — eski davranış aynen | PASS |
| Kurulum özeti | 1 kayıtlı yazıcı (`aa` 192.168.10.100:9100), 3/4 alan eşleşti (eşleşmeyen: "yeni alna"), merkez Kapalı | PASS |
| Başlat | tek köprü 127.0.0.1:3001, LAN 192.168.10.67:18772, özet "Açık" | PASS |
| Yazıcı yanıt vermiyorken | "Ulaşılamayan: aa" + "kayıt duruyor, yeniden eklemeniz gerekmez" (ilk yoklama soğuk ağda düştü) | PASS (kayıt silinmedi) |
| Otomatik başlat anahtarı → Çık | köprü + LAN kapandı; tercih diskte `ibul.printer_center.auto_start.<rid>=1` | PASS |
| Yeniden aç (hiç tıklama yok) | 6–8 sn'de tek köprü + LAN açık; `aa` "Kayıtlı · bağlı · baskıya hazır", özet 1/1 bağlı (bağımsız `nc`/ping de açık) | PASS (2 ayrı derlemede) |
| Açılışta baskı | köprü kaydında son giriş 22 Kas 16:33; bu geceki 3 başlatmada yeni kayıt yok | PASS |
| Durdur | köprü süreci yok, 3001/18772 kapalı, `.env PRINT_SYSTEM_ENABLED=False`; tercih açıkken 45 sn sonra da kapalı | PASS |

### Yapılmadı / doğrulanmadı
- Paket içi köprü yeniden derlenmedi (PyInstaller ortamı yok) → kök neden 7'nin Python tarafı gerçek uygulamada ETKİN DEĞİL; Dart tarafı eski köprüyle geriye uyumlu.
- Fiziksel baskı, gerçek sipariş (TEST 15), Mac yeniden başlatma (TEST 4), yazıcıyı fiziksel kapat/aç (TEST 5–6 gerçek), internet kes/aç (TEST 7–8 gerçek), ağ değiştirme (TEST 10): onay bekliyor.
- TEST 14 (alt yönetici): `20261122090000_print_settings_staff_permission.sql` production'da yok → BLOCKED.
- Yazıcı IP'si değişince kimlik doğrulamalı yeniden bulma: yok (köprü MAC toplamıyor; `printer_identity.py` kullanılmıyor). Kullanıcıya DHCP rezervasyonu öneriliyor.
- Kısmi çok istasyonlu başarısızlıkta yerel/bulut tekilleştirme anahtarı uyuşmazlığı (yerel `name`, bulut `product_name`) incelendi, düzeltilmedi.
- Durum şeridindeki "Yazıcı bağlantısı henüz doğrulanmadı" (hub hazır durumu) ile yeni satır altı "bağlı" bilgisi ayrı kaynaklardan geliyor.
- **Son tam Flutter çalıştırması (commit `ba1f285`, 01:10–01:21, `--timeout 90s`):** 3300 geçti, 1 atlandı, 49 başarısız; 49'un tamamı `4784f12` kopyasında da başarısız (bu turdan gelen yeni başarısızlık 0).

### P15 devam (01:20–01:30) — köprü yardımcısı yeniden paketlendi (kullanıcı onayıyla PyInstaller kuruldu)
- Derleme ortamı: `~/IBUL_isolated_build/bridge-venv` (Python 3.14.0, PyInstaller 6.22.3, Pillow 12.2.0, pyusb 1.3.1). Komut: `PYTHON=~/IBUL_isolated_build/bridge-venv/bin/python3 sh local_print_bridge/macos/build_bridge_executable.sh`. Önceki yardımcı: `local_print_bridge/dist/macos/IbulPrintBridge.prev-20261120` (git dışı).
- **Paketlenmiş köprünün uçtan uca kontrolü ek bir kök neden buldu:** gerçek mutfak yolunun kullandığı `NetworkTcpTransport.print_bytes` hata aşamasını hiç işaretlemiyordu (yalnız modül düzeyi `print_tcp` işaretliyordu). Sonuç: yazma sırasında kopan gönderim ("connection reset", "timed out") köprüde "geçici" sayılıp OTOMATİK yeniden gönderilebiliyordu (çift fiş). Düzeltme: bağlantı hatası `phase=connect`, yazma hatası `phase=write` (`local_print_bridge/network_transport.py`); testler `test_print_failure_outcome.py::NetworkTransportPhaseTests`.
- Paketlenmiş köprü, özel portta + loopback sahte yazıcıyla (3001'e ve gerçek yazıcıya dokunmadan): kapalı servis 503 + 0 bayt; yazıcıya bağlanılamadı → `retry_safe=true / not_sent`; aynı fiş tekrar gönderilince GERÇEKTEN basıldı; basılmış fiş tekrar gelince bastırıldı (tek fiş). 6/6 PASS.
- Köprü `unittest` (derleme ortamıyla): 220 test, 19 başarısız = HEAD ile birebir aynı 19.
- Yeni uygulama derlemesi (209,3 MB, imza OK; gömülü yardımcı `com.ibul.sellerdesktop.printbridge`, app-sandbox + inherit). Gerçek uygulama: açılışta 11 sn'de tek köprü + LAN merkezi, `/health` ok, yazıcıya bağlantı yoklaması açık, yeni baskı kaydı yok; çıkışta ikisi de kapandı. PASS.
- Gerçek uygulamada DOĞRULANMADI: belirsiz fişin tutulması ve operatör onaylı yeniden baskı (fiziksel baskı gerektirir).

### P15 devam (01:29) — kullanıcı onaylı TEK fiziksel test fişi (yeni köprülü derleme)
- Açılış: otomatik başlatma ile merkez hazır, şerit "Yazıcı Hazır", özet 1/1 bağlı. Baskı öncesi köprü kaydı 35 giriş (son: 22 Kas 16:33).
- Yazıcı Merkezi → Kayıtlı Yazıcılar → `aa` → **Test** (tek tık). Bu bağlantı pencere açmadan doğrudan yazıcı test fişi gönderiyor (`job_name=ibul-test-receipt`, `document_type=receipt`) — planlanan "Mutfak Genel" fişi DEĞİL; onay tek fiş için olduğundan ikinci fiş gönderilmedi.
- Köprü: 01:29:54 tek yeni giriş (36), hedef `tcp:192.168.10.100:9100`, `queue_status=completed`, `success=True`; 20 sn sonra da 36 (tekrar yok).
- **Kâğıt çıktısı DOĞRULANMADI** (TCP yazımı kâğıt kanıtı değildir); kullanıcı teyidi bekleniyor.
- Hâlâ yapılmadı: mutfak/istasyon fişi ve gerçek sipariş (TEST 15), belirsiz fişin tutulması ve operatör onaylı yeniden baskı, Mac yeniden başlatma, yazıcı kapat/aç, internet kes/aç.
- **Kâğıt teyidi (kullanıcı beyanı, 2026-11-23):** 01:29:54'teki test fişinin kâğıt çıktısı geldi. Kanıt: kullanıcı gözlemi + köprü `completed` kaydı (tek giriş) → yeni köprülü derlemede kayıtlı yazıcıya fiziksel baskı, tek fiş: **PASS**. Mutfak/istasyon fişi ve gerçek sipariş ayrıca doğrulanmadı.

### P15 devam (01:32) — TEST 15: kullanıcı onaylı gerçek sipariş → istasyon fişi (production, yeni köprülü derleme)
- Garson → **Bahçe 1** (boştu) → 1 × KATI CACIK (₺180) → Siparişi Gönder (tek tık). Dolu masalara (12 açık masa) dokunulmadı.
- Ekran: sipariş kaydedildi ("Az önce · 1 KATI CACIK · ₺180"), taslak boşaldı.
- Köprü: 01:32:17 tek yeni giriş (36 → 37) `kitchen_ticket`, `job_name=mutfak-masa-11--`, hedef `aa` `tcp:192.168.10.100:9100`, `completed`, 40355 bayt; 73 sn sonra da 37 (ikinci fiş yok, tekilleştirme reddi kaydı yok).
- **Kâğıt çıktısı DOĞRULANMADI** (kullanıcı teyidi bekleniyor). Bahçe 1 siparişi AÇIK bırakıldı; kapatma/iptal kullanıcıya ait.
- Not: dünkü köprü günlüğünde (22 Kas 16:14:58 zaman aşımı → 16:14:59 aynı işin yeniden gönderimi) bu turda düzeltilen "yazma/zaman aşımı sonrası otomatik tekrar" davranışının izi görülüyor.
- **Kâğıt teyidi (kullanıcı beyanı, 2026-11-23):** 01:32:17'deki Bahçe 1 mutfak fişi yazıcıdan TEK kâğıt olarak çıktı. Kanıt: kullanıcı gözlemi + köprüde tek `completed` kaydı → TEST 15 (gerçek sipariş → kayıtlı istasyon yazıcısı, tek fiş): **PASS** (tek yazıcılı kurulumda). Çok yazıcılı yönlendirme gerçek cihazda denenmedi. Bahçe 1 siparişi açık; kullanıcı kapatacak.


## 2026-11-23 — Üretim güvenliği: `table_order_history` yazma sertleştirmesi (VERIFIED, salt-okunur)

- **Uygulama yolu:** Operatör SQL'i Supabase Dashboard → SQL Editor'den elle çalıştırdı (sonuç "Success. No rows returned"). Claude `apply_migration` denemesi reddedildi; başka yolla uygulanmadı. Proje `ihmixxzqnpamcwmrfibx`.
- **Doğrulama (yalnız katalog/fonksiyon tanımı, veri değiştirilmedi):**
  1. `table_order_history_staff_update_guard` BEFORE UPDATE, `tgenabled=O`; fonksiyon gövdesi taslakla birebir.
  2. `audit_table_order_history_change()` + `table_order_history_audit_trg` (AFTER UPDATE/DELETE) mevcut, etkin.
  3. `table_order_history_audit`: RLS açık; authenticated yalnız SELECT; politika `seller_id = auth.uid()`; anon yetkisi yok. Satır sayısı 0 (henüz değişiklik/silme olmadı).
  4. `table_order_history`: anon yetkisi yok; authenticated DELETE/INSERT/SELECT/UPDATE (TRUNCATE/TRIGGER/REFERENCES kalktı).
  5. `close_table_orders` ve `close_table_with_history`: anon ve public EXECUTE yok; authenticated + service_role var. `close_table_orders` gövdesi `restaurant_staff_may_operate(…,'closeBill',…)` çağırıyor.
  6. `guard_restaurant_staff_order_write` ve tüm RLS politikaları (restrictive okuma koruması, owner insert/select, update/delete) değişmedi.
  7. Meşru yollar: sahip (`auth.uid()=seller_id`) tetikleyiciden muaf; personel kimlik/etiket alanını güncelleyebilir; DELETE hâlâ `closeBill` ister; `close_table_with_history` yalnız INSERT yapar, değişmedi. Sunucuda geçmişi UPDATE eden fonksiyon yok.
  8. Diğer işletme izolasyonu politika koşullarından (`seller_id = auth.uid()` / `user_can_access_restaurant`) korunuyor.
- **Küçük not:** `guard_*`/`audit_*` tetikleyici fonksiyonlarında anon EXECUTE var (tetikleyici fonksiyonu doğrudan RPC ile çağrılamaz; önceden de böyleydi). İstenirse ayrı kapatılabilir.
- **NOT VERIFIED:** Gerçek kullanıcı oturumlarıyla (sahip, `viewOrders`, `manageOrders`, `closeBill`, başka işletme) uygulama içi yetki testi; masa kapatma ve geçmiş ekranı gerçek uygulamada.
- **Migration geçmişi:** `supabase_migrations.schema_migrations` bu SQL'i içermiyor (son kayıt `20261120090000_lan_staff_authority`). Elle uygulandığı için beklenen durum. Uzlaştırma önerisi: dosya `migrations/` altına aynı adla alınıp `supabase migration repair --status applied <sürüm>` ile işaretlenmeli (şema değiştirmez). Yapılmadı; operatör kararı.
- **Diğer bekleyen migration'lara onay DEĞİLDİR:** yazıcı personel izni, geçmiş snapshot, fiyat otoritesi, çevrimdışı masa kapatma ayrı doğrulama/onay bekler.


## 2026-11-23 akşam — Gerçek macOS Release doğrulama turu (G = gerçek uygulama ekranı)

- **Derleme:** kaynak kökü repo kökü (`lib/main_seller.dart`, `build` → `~/IBUL_isolated_build/flutter-build` bağlantısı); `flutter build macos --target lib/main_seller.dart --release --dart-define=IBUL_LAN_EVIDENCE_VERIFIER_URL=…` → `com.ibul.sellerdesktop`, `codesign --verify --deep --strict` OK, ana ikili SHA-256 (son derleme, HEAD 552b8ba) `53b9b48bfb9835eb881bc88db936243857b5ffe5962f9187927b15ee99ee61fd` (görsel doğrulama bir önceki derlemelerde yapıldı; son derlemedeki yalnız üst çubuk Yenile görünürlüğü değişikliği ekranda GÖRÜLMEDİ — ekran kilitliydi). Önceki çalışan derleme `~/IBUL_checkpoints/20261122-restaurant-verified/app-backup` içinde (SHA doğrulandı). Açılışta köprü otomatik başladı (`/health ok:true`). Oturum ve yazıcı kaydı korundu (aynı paket kimliği/kapsayıcı).
- **Gerçek ekranda görülen ve düzeltilen hatalar:** (1) Genel Bakış, Listeler, Siparişler, AVM, Finans, Başarılarım, Yorumlar'da sayfanın kendi Yenile düğmesi varken üst çubukta ikinci Yenile çiziliyordu → `_moduleHasOwnRefresh`; (2) Alt Yöneticiler ilk açılışta sahte "0 personel / personel yok" gösteriyordu (üst Yenile ile 4'e çıktı) → yükleniyor durumu; (3) Sistem ilk karelerde sahte "Henüz masa kaydı yok" + "Varsayılan 20 Masa Oluştur" gösteriyordu (27 masa var) → ilk yükleme bitene kadar spinner, düğme gizli; (4) Yerel Operasyon: "Şu an bağlı 1" iken cihaz kartı "Bağlantı yok" → canlı sayım kartla aynı kaynaktan; kayıtlı yazıcı `aa` yalnız adla görünüyordu → `ip_address/port/connection_type` okunuyor ("Ethernet · 192.168.10.100:9100", Yazıcılar sekmesiyle aynı); ham JSON hata ve ham yerel kimlikler → anlaşılır Türkçe; Baskı durumu sayısı eşitleme hatalarını da sayıyordu; (5) Genel Bakış 6 operasyon kartı 5+1 → 3+3; (6) Alt Yönetici kartında "Şube yok" gürültüsü kaldırıldı.
- **Görsel olarak doğrulanan (G):** Genel Bakış, Garson, Sistem, Yazıcı Ayarları (Yazıcı Merkezi + Yazıcılar sekmesi), Yerel Operasyon Merkezi (masaüstü ve 430 px), Alt Yöneticiler, Yetki editörü (Erişim yok / Görüntüle / Tam yönetim ayrımı net; İptal ile kapatıldı, kayıt yapılmadı), Geçmiş Masalar. Üst çubuk Yenile'nin gerçekten yenilediği: Alt Yöneticiler 0 → 4 personel.
- **NOT VERIFIED / BLOCKED:** internetsiz menü ve sayfa açılış süreleri (WAN kesme onayı yok); Yenile'nin açık form/masa siparişini sıfırlamadığı (yalnız kod okuma: Garson/Sistem kendi düğmesini kullanır, genel yenileme yalnız yükleyici çağırır veya gömülü sayfayı yeniden kurar — form içeren sayfalar için canlı denenmedi); iPhone; fiziksel baskı; gerçek masa kapatma.
- **Bilinen açık sorun (BLOCKED):** yerel sipariş eşitleme `PGRST301 Expected 3 parts in JWT; got 1` ile başarısız (1 yerel sipariş eşitlenmedi, 3 belirsiz baskı). Gerçek sipariş eşitlemesi üretim verisini değiştireceğinden yeniden denenmedi; kök neden araştırması ayrı onay/oturum ister.
- **Migration `20261122090000_print_settings_staff_permission`:** üretimde UYGULANMIŞ (4 `*_print_settings_write` politikası mevcut, eski `restaurant_print_station_configs_owner_all` kaldırılmış; salt-okunur `pg_policies`). Arayüz kapısı (`owner || managePrintSettings`) RLS ile tutarlı. Gerçek alt yönetici oturumuyla test NOT VERIFIED.
- **`close_table_orders` metin/uuid hatası:** izole PG'de kanıtlandı (42883 → `::text` ile çalışır, toplam doğru, yetkisiz 42501); taslak `drafts/20261123_close_table_orders_seller_text_cast_DRAFT.sql`, uygulanmadı.
- **Masa kapatma süre bileşenleri (izole, ağsız):** RPC medyan 0,5 ms / p95 1,5 ms (10 kapanış) → sunucu işi ihmal edilebilir; kullanıcının beklediği süre ağ gidiş-dönüşleridir (RPC + kapanış sonrası geçmiş/masa okumaları + panel yenileme). Kapanış sonrası iki bağımsız okuma artık paralel. Gerçek ağ süresi ölçülmedi (gerçek masa kapatma onayı yok).
