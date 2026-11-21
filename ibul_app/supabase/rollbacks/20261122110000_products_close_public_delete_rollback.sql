-- Geri alma: 20261122110000_products_close_public_delete.sql
-- UYARI: herkese açık ürün silme açığını yeniden açar.
begin;
drop policy if exists products_admin_delete_all on public.products;
drop policy if exists "Enable delete for users based on user_id" on public.products;
create policy "Enable delete for users based on user_id"
on public.products
for delete
to public
using (true);
commit;
