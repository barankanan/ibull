-- GÜVENLİK: public.system_layouts yazma (INSERT/UPDATE/DELETE) herkese açıktı.
-- Canlıda doğrulanan durum (salt-okunur, 2026-11-22): system_layouts_insert_all, system_layouts_update_all ve
-- "Enable delete for users based on user_id" roles={public}; SELECT herkese açık KALIR (uygulama düzeni okur).
-- Yazan tek istemci kodu: admin_service.dart (yönetim paneli). Düzeltme: yazma yalnız admin/super_admin.
-- Yönetim paneli düzen kaydetme akışı gerçek kullanımda doğrulanmadı; bozulursa rollback.
begin;
drop policy if exists system_layouts_insert_all on public.system_layouts;
drop policy if exists system_layouts_update_all on public.system_layouts;
drop policy if exists "Enable delete for users based on user_id" on public.system_layouts;
drop policy if exists system_layouts_admin_write on public.system_layouts;
create policy system_layouts_admin_write on public.system_layouts for all
using (
  (coalesce((auth.jwt() ->> 'role'), '') = any (array['admin','super_admin']))
  or (coalesce(((auth.jwt() -> 'app_metadata') ->> 'role'), '') = any (array['admin','super_admin']))
  or exists (select 1 from public.users u where u.id = auth.uid() and u.role = any (array['admin','super_admin']))
)
with check (
  (coalesce((auth.jwt() ->> 'role'), '') = any (array['admin','super_admin']))
  or (coalesce(((auth.jwt() -> 'app_metadata') ->> 'role'), '') = any (array['admin','super_admin']))
  or exists (select 1 from public.users u where u.id = auth.uid() and u.role = any (array['admin','super_admin']))
);
commit;
