-- GÜVENLİK: public.stores DELETE herkese açıktı.
-- Canlıda doğrulanan durum (salt-okunur, 2026-11-22): politika "Enable delete for users based on user_id",
-- roles={public}, USING (true). Başka sahip silme politikası YOK; mağaza silme bu geniş politikaya dayanıyordu.
-- Düzeltme: açık politikayı kaldırır; sahip (store_service.dart hesap silme) ve yönetim paneli (admin_service.dart)
-- için ayrı DELETE politikaları ekler. Mevcut staff_permission_delete (manageStoreProfile) DEĞİŞMEZ.
begin;
drop policy if exists "Enable delete for users based on user_id" on public.stores;
drop policy if exists stores_owner_delete on public.stores;
create policy stores_owner_delete on public.stores for delete using (auth.uid() = seller_id);
drop policy if exists stores_admin_delete_all on public.stores;
create policy stores_admin_delete_all on public.stores for delete using (
  (coalesce((auth.jwt() ->> 'role'), '') = any (array['admin','super_admin']))
  or (coalesce(((auth.jwt() -> 'app_metadata') ->> 'role'), '') = any (array['admin','super_admin']))
  or exists (select 1 from public.users u where u.id = auth.uid() and u.role = any (array['admin','super_admin']))
);
commit;
