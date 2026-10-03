# SECURITY AUDIT

## LIVE ENVIRONMENT
- **Project Ref:** ihmixxzqnpamcwmrfibx
- **Project URL:** https://ihmixxzqnpamcwmrfibx.supabase.co
- **Environment:** Production (Linked)
- **Local Migrations:** 1 (in supabase/migrations/20260825163448_remote_commit.sql)
- **Remote Migrations:** 0 (Drift detected via CLI)
- **Status:** HIGH DRIFT. Local migration count is extremely low compared to the 60+ scattered SQL files found in the root and `ibul_app` directories. Remote migrations are not tracked via `supabase_migrations.schema_migrations` table properly, indicating manual SQL execution or UI-based schema changes.

## 1. RLS ENABLED & POLICY INVENTORY
**LIVE RLS:** VERIFIED
- RLS is explicitly enabled (`rls_enabled = true`) for all critical tables including `users`, `stores`, `products`, `orders`, `order_items`, `addresses`, `vehicle_kyc_documents`, `vehicle_listings`, `table_orders`.
- The database heavily relies on `SECURITY DEFINER` RPC functions with `search_path=public` configured, preventing search path hijacking.

## 2. ATTACK TESTS
- **Customer A vs B (Cross-account isolation):** SECURITY TEST RESULT: PASS. (`orders` policies enforce `auth.uid() = user_id`)
- **Seller A vs B (Seller isolation):** SECURITY TEST RESULT: PASS. (`orders` policies enforce `can_access_order_as_seller()`)
- **Payment Bypass / Price Tampering:** SECURITY TEST RESULT: FAIL. (The `orders_user_insert` policy currently allows customers to manually insert `status='paid'` and `total_amount=1.00`. Test yapılmış ve `authenticated` rolünün Supabase'de `BYPASSRLS` yetkisi OLMADIĞI doğrulanarak RLS aktifken manipüle edilebildiği kanıtlanmıştır. Test transaction içinde yapılıp rollback edildiği için canlı veritabanında sahte kayıt kalmamıştır).
- **ID Guessing:** SECURITY TEST RESULT: PASS (UUID v4 usage).
- **Privilege Escalation:** SECURITY TEST RESULT: PASS. (`users_protect_privileged_columns` trigger is LIVE and enforcing).
- **Anon to Private Data:** SECURITY TEST RESULT: PASS.

## 3. MASS ASSIGNMENT AUDIT
- Client API üzerinden gönderilen `total_amount`, `status` değerleri `orders_user_insert` politikası sebebiyle REST API'ye açıktı. Ayrıca `create_order_from_cart` RPC'sinde `p_shipping_amount` parametresine negatif değer gönderilerek sepet tutarı manipüle edilebiliyordu.
- **Fix (Hazırlanan Çözüm):** `20241027120000_harden_orders.sql` migration'ı ile:
  1. `orders_user_insert` politikası siliniyor.
  2. `create_order_from_cart` içinde kargo tutarı güvenli şekilde (`greatest(0, coalesce(p_shipping_amount, 0))`) kısıtlanıyor.
  3. `orders_status_guard` trigger'ı ile siparişlerin müşteri tarafından `paid` yapılması sunucu düzeyinde engelleniyor.

## 4. PUBLIC / ANON RPC
- Anon anahtarı built JS içinde `eyJhbG...` şeklinde bulunmaktadır (Beklenen ve güvenli durum).
- **Service Role Leak:** NO (Derlenmiş JS dosyalarında `service_role` bulunmamaktadır).

## 5. STORAGE IMAGE BUCKETS
- `seller-documents`, `vehicle-documents`, `store-contracts`: `public = false` (VERIFIED - PASS)
- `store-images`, `product-images`, vs: `public = true` (VERIFIED - PASS)

## BULGULAR (SEVERITY)
- **P0:** Payment bypass ve Order price tampering kanıtlandı (Canlıda risk devam ediyor). Düzeltme için migration oluşturuldu (`20241027120000_harden_orders.sql`).
- **P0:** `table_orders` üzerinde aşırı yetkilendirme (`Anyone can insert`, `qual=true` for all authenticated users). Herkes diğer masalara sipariş yazabilir (Canlıda risk devam ediyor). Düzeltme migration'a eklendi.
- **P2:** Migration dosyaları klasör yapısına standart olarak geçirilmelidir (High Drift).
