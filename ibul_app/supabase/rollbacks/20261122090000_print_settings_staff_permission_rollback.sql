-- Geri alma: 20261122090000_print_settings_staff_permission.sql
-- Production'un 2026-11-22 salt-okunur pg_policies görüntüsüne döner.
begin;

drop policy if exists printers_print_settings_write on public.printers;
drop policy if exists stations_print_settings_write on public.stations;
drop policy if exists station_printers_print_settings_write on public.station_printers;
drop policy if exists restaurant_print_station_configs_print_settings_write
  on public.restaurant_print_station_configs;

drop policy if exists restaurant_print_station_configs_owner_all
  on public.restaurant_print_station_configs;
create policy restaurant_print_station_configs_owner_all
on public.restaurant_print_station_configs
for all
using (public.user_can_access_restaurant(restaurant_id))
with check (public.user_can_access_restaurant(restaurant_id));

commit;
