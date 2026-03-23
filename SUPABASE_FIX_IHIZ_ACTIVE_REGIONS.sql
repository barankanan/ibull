-- IHIZ kurye panelindeki "Aktif Bölgeler" seçimini kalıcı hale getirir.
-- Supabase SQL Editor'da bir kez çalıştırın.

alter table public.ihiz_courier_applications
  add column if not exists active_region_keys text[] default '{}'::text[];

alter table public.ihiz_courier_applications
  add column if not exists active_region_options jsonb default '[]'::jsonb;

update public.ihiz_courier_applications
set active_region_keys = '{}'::text[]
where active_region_keys is null;

update public.ihiz_courier_applications
set active_region_options = '[]'::jsonb
where active_region_options is null;

alter table public.ihiz_courier_applications
  alter column active_region_keys set default '{}'::text[];

alter table public.ihiz_courier_applications
  alter column active_region_options set default '[]'::jsonb;

create index if not exists ihiz_courier_applications_active_region_keys_idx
  on public.ihiz_courier_applications
  using gin (active_region_keys);

