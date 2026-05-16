-- Idempotent fix for production when 20260504_print_system_enabled_and_paused_status.sql
-- was not applied or PostgREST schema cache is stale (PGRST204 on print_system_enabled).
--
-- Safe to run multiple times.

begin;

-- 1) Canonical column on print station config
alter table public.restaurant_print_station_configs
  add column if not exists print_system_enabled boolean not null default true;

comment on column public.restaurant_print_station_configs.print_system_enabled is
  'Whether the print system is enabled for this restaurant. When false, bridge/runtime may report print_system_disabled.';

-- 2) Tell PostgREST to reload schema cache (Supabase / PostgREST).
-- print_jobs paused_by_operator migration: use 20260504_print_system_enabled_and_paused_status.sql
notify pgrst, 'reload schema';

commit;
