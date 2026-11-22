# Çevrimdışı Masa Kapatma — Veri Sözleşmesi ve Idempotency Modeli

Durum: **taslak, yalnız yerelde.** Production'a hiçbir şey uygulanmadı. Uygulamadaki
`offlineMoneyOperationBlock` engeli yerinde; bu belge o engelin güvenle kaldırılabilmesi
için gereken sunucu sözleşmesini tanımlar.

- Migration taslağı: `ibul_app/supabase/migrations/20261122160000_offline_table_settlement.sql`
- İzole testler: `ibul_app/supabase/tests/run_isolated_offline_table_settlement.sh`
  (`isolated_offline_table_settlement_schema.sql`, `…_assert.sql`)

## 1. Neden mevcut RPC yetmiyor

`close_table_with_history(seller, masa, ödeme, …)` çağrıldığı anda masadaki **bütün açık
siparişleri** kapatır; hangi siparişlerin kapatılacağını ve işlem kimliğini almaz.
Çevrimdışı yapılan bir kapatma sonradan gönderilirse:

1. o arada başka cihazın aynı masaya eklediği siparişler de kapanır (tahsil edilmemiş para kapanmış görünür),
2. aynı kapatma iki kez gönderilirse ikinci çağrı o an açık ne varsa onu kapatır,
3. masa çevrimiçi başka biri tarafından zaten kapatıldıysa para iki kez sayılabilir.

## 2. Sözleşme

Cihaz, kapatma anında **uzlaştırma kaydı** üretir ve değiştirmeden saklar:

| Alan | Anlamı |
|---|---|
| `settlement_id` | Cihazın kapatma anında ürettiği benzersiz kimlik (UUID). Idempotency anahtarı; yeniden denemelerde AYNI kalır. |
| `restaurant_id`, `table_number` | Masa |
| `local_order_ids[]` | Kapatılan siparişlerin yerel kimlikleri (1–50). Kapsam budur; başka sipariş kapanmaz. |
| `expected_total` | Cihazın tahsil ettiği tutar |
| `payment_method` | `cash, card, online, mixed, complimentary, other` |
| `closed_at` | Cihaz saati (bilgi amaçlı; sunucu ileri tarihi kabul etmez) |
| `closed_by` | Kapatan personelin kimliği |
| `payment_note`, `waiter_name` | İsteğe bağlı |

Sunucu çağrısı: `apply_offline_table_settlement(...)`. Yalnız **servis rolü** çalıştırabilir;
istemci doğrudan çağıramaz. Çağrıyı, sipariş senkronunda olduğu gibi, oturumu ve merkez
imzasını doğrulayan sunucu tarafı doğrulayıcı yapar (`p_verified_actor`, `p_evidence_branch`).

### Sonuçlar

| Sonuç | Sunucuda ne olur | Cihaz ne yapar |
|---|---|---|
| `applied` | Yalnız adı geçen siparişler kapanır, her biri için geçmiş kaydı yazılır | Kaydı "eşitlendi" işaretler |
| `conflict` + neden | Hiçbir sipariş kapanmaz; karar kaydedilir | Otomatik yeniden denemez; operatöre gösterir |
| hata `orders_not_synced` | Hiçbir şey kaydedilmez | Önce siparişleri eşitler, sonra AYNI kimlikle yeniden dener |
| hata `offline_settlement_disabled` | Hiçbir şey kaydedilmez | Bekler; özellik kapalı |
| hata `42501` | Hiçbir şey kaydedilmez | Operatöre gösterir (yetki yok / erişim kaldırılmış) |

Çatışma nedenleri:

| Neden | Durum |
|---|---|
| `total_mismatch` | Sunucudaki hesap, cihazın tahsil ettiği tutardan farklı (sipariş sonradan değişmiş) |
| `order_already_closed` | Sipariş çevrimiçi başka biri tarafından zaten kapatılmış |
| `order_already_settled` | Sipariş başka bir çevrimdışı uzlaştırmayla kapatılmış |
| `order_table_mismatch` | Sipariş bu masaya ait değil (ör. masa taşıma yapılmış) |

`applied` yanıtındaki `remaining_open_orders`, kapatmadan sonra masada açık kalan sipariş
sayısıdır; sıfırdan büyükse masa açık kalır.

## 3. Idempotency modeli

1. Anahtar `(restaurant_id, settlement_id)`; tabloda tekildir.
2. Aynı anahtar + aynı içerik → kayıtlı sonuç `replayed: true` ile döner, hiçbir şey yeniden yazılmaz.
3. Aynı anahtar + farklı içerik → reddedilir (`settlement_id_reused_with_different_content`).
4. Eşzamanlı istekler işlem kimliği üzerinde danışma kilidiyle sıraya girer; siparişler de kilitlenir.
5. Bir sipariş, hangi kimlikle gelirse gelsin, çevrimdışı uzlaştırmayla en fazla bir kez kapanır
   (`restaurant_offline_settlement_orders.order_id` birincil anahtar).
6. Çatışma kararı da kalıcıdır: aynı kimlik tekrarında aynı çatışma döner.

## 4. Yetki

Kapatan kişi işletme sahibi ya da `closeBill` izni olan **etkin** personel olmalı; personel bir
şubeye bağlıysa masa o şubede olmalı. Kontrol **uygulama anında** yapılır: cihaz çevrimdışıyken
erişimi kaldırılan personelin kapatması yüklenince reddedilir.

## 5. Kanıt (izole PostgreSQL 17, 2026-11-22)

25 PASS satırı, 0 hata. Kapsam: anahtar kapalı, yalnız adı geçen siparişler, tekrar gönderim,
farklı içerik, eşitlenmemiş sipariş, tutar uyuşmazlığı, çevrimiçi kapanmış sipariş, ikinci
kimlikle aynı sipariş, başka masa, dört yetki reddi, biçim kontrolleri, istemci rollerinin
erişememesi, para toplamı eşitliği, migration'ın ikinci kez uygulanması, sekiz eşzamanlı aynı
istek (1 uygulama + 7 tekrar), aynı sipariş için dört farklı kimlik yarışı (1 uygulama + 3
çatışma), geri alma bloğu.

Mutasyon denetimi: tutar kontrolü, sipariş kapsamı, işlem kilidi, "zaten kapalı" kontrolü ve
yetki kontrolü tek tek kaldırıldığında testler kırmızıya döndü.

## 6. Bu taslakta OLMAYANLAR (production öncesi gerekli)

1. **Üretimdeki yazma koruyucuları denenmedi.** `orders` ve `table_order_history` üzerinde
   `guard_restaurant_staff_order_write` ve `orders_money_authority_guard` tetikleyicileri var;
   izole şemada yoklar. Servis rolüyle bu yazımların geçtiği bir Supabase dalında doğrulanmalı.
2. **Yetki kuralı kopyası.** Çevrimiçi yol `restaurant_has_permission` / `restaurant_table_number_access`
   kullanıyor (çağıranın oturumuna bakar). Buradaki açık personel kontrolü onlarla birebir
   aynı sonucu vermeli; karşılaştırma testi yazılmadı.
3. **Ödeme defteri.** `table_payments` satırı yazılmıyor ve `record_table_payment` çağrılmıyor.
   Tahsilatın hangi tabloda kayıt altına alınacağı karar bekliyor.
4. **Doğrulayıcı uç noktası ve imza.** Uzlaştırma kaydının merkez anahtarıyla imzalanması ve
   Edge Function tarafı yazılmadı.
5. **Uygulama tarafı.** Yerel uzlaştırma kuyruğu, eşitleme sırası (önce siparişler), çatışma
   ekranı ve `offlineMoneyOperationBlock`'un koşullu kaldırılması yapılmadı.
6. **Eski `table_orders` tablosu.** Yalnız `orders` kapsanıyor; eski tablodaki açık kayıtlar
   bu yolla kapanmaz.
7. **Kısmi ödeme / hesap bölme** kapsam dışı.

## 7. Onay noktaları

- Migration'ın production'a uygulanması (dosyanın başındaki cümleyle).
- Bir işletme için anahtarın açılması (`restaurant_offline_settlement_settings.enabled`).
- Gerçek tahsilat içeren ilk deneme.

Geri alma: migration dosyasının sonundaki blok; kayıtları koruyan yumuşak durdurma için anahtarı
kapatmak ya da servis rolünün çalıştırma iznini kaldırmak yeterli.
