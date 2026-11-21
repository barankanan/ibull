-- GÜVENLİK: public.products DELETE herkese açıktı.
--
-- Canlıda doğrulanan durum (salt-okunur, 2026-11-22):
--  * Politika "Enable delete for users based on user_id": roles={public}, cmd=DELETE, USING (true).
--  * anon ve authenticated rollerinde products üzerinde DELETE yetkisi var.
--  => Herkese açık anon anahtarıyla herhangi bir ürün silinebilir (sahiplik kontrolü yok).
--
-- Düzeltme:
--  * Bu politikayı kaldırır.
--  * Kalan silme yolları: sahip (auth.uid() = seller_id, iki politika), personel
--    (staff_permission_delete = manageProducts) — DEĞİŞMEZ.
--  * Yönetim paneli (admin_service.dart `products.delete`) bu geniş politikaya
--    dayanıyor olabilir; ona özel, yalnız admin/super_admin için DELETE politikası eklenir
--    (products_admin_update_all ile aynı koşul).
--
-- Geri alma: rollbacks/20261122110000_products_close_public_delete_rollback.sql
-- (UYARI: geri alma güvenlik açığını yeniden açar; yalnız yönetim paneli kırılırsa geçici.)

begin;

drop policy if exists "Enable delete for users based on user_id" on public.products;

drop policy if exists products_admin_delete_all on public.products;
create policy products_admin_delete_all
on public.products
for delete
using (
  (coalesce((auth.jwt() ->> 'role'), '') = any (array['admin','super_admin']))
  or (coalesce(((auth.jwt() -> 'app_metadata') ->> 'role'), '') = any (array['admin','super_admin']))
  or exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.role = any (array['admin','super_admin'])
  )
);

commit;
