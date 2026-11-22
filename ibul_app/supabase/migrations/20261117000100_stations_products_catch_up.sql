-- Preparation areas ("Hazırlama Alanları") and product-to-area mapping.
--
-- Symptom: "Alan Ekle" does nothing visible. StationRepository.upsertStation
-- sends { restaurant_id, name, code, color, is_active }; a database built
-- without ibul_app/SUPABASE_KITCHEN_PRINT_ROUTING.sql has no stations.color
-- and answers PGRST204. The editor swallowed the error, so the list simply
-- stayed at "Kayıtlı hazırlama alanı bulunamadı".
--
-- Source of truth (unchanged): ibul_app/SUPABASE_KITCHEN_PRINT_ROUTING.sql.
-- Additive and idempotent: nothing is dropped or rewritten.

alter table public.stations
  add column if not exists color text;

create unique index if not exists idx_stations_restaurant_code_unique
  on public.stations(restaurant_id, code);
create index if not exists idx_stations_restaurant_id
  on public.stations(restaurant_id);
create index if not exists idx_stations_restaurant_active
  on public.stations(restaurant_id, is_active);

-- Product-to-area mapping used by kitchen routing.
alter table public.products
  add column if not exists station_id uuid
    references public.stations(id) on delete set null;
create index if not exists idx_products_station_id
  on public.products(station_id);

-- The area and printer lists use Supabase Realtime streams. A publication
-- without these tables delivers the first snapshot and then nothing.
do $$
declare
  t text;
begin
  foreach t in array array['stations', 'printers', 'station_printers'] loop
    if to_regclass('public.' || t) is not null
       and not exists (
         select 1 from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
           and tablename = t
       ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

notify pgrst, 'reload schema';
