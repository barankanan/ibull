begin;

alter table public.restaurant_print_station_configs
  add column if not exists role_mappings jsonb not null default '{}'::jsonb;

commit;
