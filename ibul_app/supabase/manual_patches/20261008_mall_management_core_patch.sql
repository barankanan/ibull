-- AVM yönetim çekirdeği: mall_floors, mall_units, profil RPC.
-- SQL Editor'da tek transaction olarak uygulanır. CLI db push kullanmayın.
-- Bu dosya migrations/ altında değildir.
-- Şube, mağaza bağlantısı, kampanya ve reklam: 20261009_mall_management_v2_patch.sql.

begin;

alter table public.malls
  add column if not exists opening_hours text;

alter table public.malls
  drop constraint if exists malls_opening_hours_len;
alter table public.malls
  add constraint malls_opening_hours_len check (
    opening_hours is null or char_length(btrim(opening_hours)) between 1 and 500
  );

create table if not exists public.mall_floors (
  id uuid primary key default gen_random_uuid(),
  mall_id uuid not null references public.malls (id) on delete restrict,
  name text not null,
  level_number integer,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  plan_url text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint mall_floors_plan_url_len check (
    plan_url is null or char_length(plan_url) between 1 and 1000
  ),
  constraint mall_floors_name_len check (char_length(btrim(name)) between 1 and 80),
  constraint mall_floors_level_range check (
    level_number is null or level_number between -20 and 200
  ),
  constraint mall_floors_sort_range check (sort_order between -1000 and 10000)
);

create unique index if not exists mall_floors_mall_name_unique
  on public.mall_floors (mall_id, lower(btrim(name)));

create unique index if not exists mall_floors_mall_level_unique
  on public.mall_floors (mall_id, level_number)
  where level_number is not null;

create index if not exists idx_mall_floors_mall_sort
  on public.mall_floors (mall_id, sort_order, name);

drop trigger if exists mall_floors_set_updated_at on public.mall_floors;
create trigger mall_floors_set_updated_at
before insert or update on public.mall_floors
for each row execute function public.mall_set_updated_at();

create table if not exists public.mall_units (
  id uuid primary key default gen_random_uuid(),
  mall_id uuid not null references public.malls (id) on delete restrict,
  floor_id uuid not null references public.mall_floors (id) on delete restrict,
  unit_code text not null,
  name text,
  unit_type text not null,
  occupancy text not null default 'vacant',
  area_m2 numeric(10, 2),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  map_x numeric(6, 5),
  map_y numeric(6, 5),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint mall_units_map_point check (
    (map_x is null and map_y is null)
    or (map_x between 0 and 1 and map_y between 0 and 1)
  ),
  constraint mall_units_code_len check (char_length(btrim(unit_code)) between 1 and 40),
  constraint mall_units_name_len check (
    name is null or char_length(btrim(name)) between 1 and 120
  ),
  constraint mall_units_type_check check (
    unit_type in ('store', 'restaurant', 'cafe', 'kiosk', 'cinema', 'service', 'other')
  ),
  constraint mall_units_occupancy_check check (
    occupancy in ('vacant', 'reserved', 'occupied', 'temporarily_closed')
  ),
  constraint mall_units_area_range check (
    area_m2 is null or (area_m2 > 0 and area_m2 <= 100000)
  ),
  constraint mall_units_sort_range check (sort_order between -1000 and 10000)
);

create unique index if not exists mall_units_mall_code_unique
  on public.mall_units (mall_id, lower(btrim(unit_code)));

create index if not exists idx_mall_units_mall_floor
  on public.mall_units (mall_id, floor_id, sort_order);

comment on table public.mall_units is
  'AVM içindeki fiziksel birim. occupied yalnızca onaylı mall_branch_links ile yazılır. map_x/map_y 0-1 normalize.';

create or replace function public.mall_units_require_same_mall()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_floor_mall uuid;
begin
  select f.mall_id into v_floor_mall
  from public.mall_floors f
  where f.id = new.floor_id;
  if v_floor_mall is null or v_floor_mall <> new.mall_id then
    raise exception 'Birim, seçilen kata ait değil.';
  end if;
  return new;
end;
$$;

drop trigger if exists mall_units_require_same_mall on public.mall_units;
create trigger mall_units_require_same_mall
before insert or update on public.mall_units
for each row execute function public.mall_units_require_same_mall();

drop trigger if exists mall_units_set_updated_at on public.mall_units;
create trigger mall_units_set_updated_at
before insert or update on public.mall_units
for each row execute function public.mall_set_updated_at();

revoke all on function public.mall_units_require_same_mall() from public, anon;
grant execute on function public.mall_units_require_same_mall() to authenticated;

alter table public.mall_floors enable row level security;
alter table public.mall_units enable row level security;

revoke all on table public.mall_floors from public, anon, authenticated;
revoke all on table public.mall_units from public, anon, authenticated;
grant select on table public.mall_floors to authenticated;
grant select on table public.mall_units to authenticated;

drop policy if exists mall_floors_select_member on public.mall_floors;
create policy mall_floors_select_member
on public.mall_floors
for select
to authenticated
using (
  public.mall_member_has_role(
    mall_id,
    array['mall_manager', 'mall_ad_manager', 'mall_content_editor', 'mall_store_manager']
  )
  or public.is_admin_user()
);

drop policy if exists mall_units_select_member on public.mall_units;
create policy mall_units_select_member
on public.mall_units
for select
to authenticated
using (
  public.mall_member_has_role(
    mall_id,
    array['mall_manager', 'mall_ad_manager', 'mall_content_editor', 'mall_store_manager']
  )
  or public.is_admin_user()
);

create or replace function public.mall_management_assert_role(
  p_mall_id uuid,
  p_roles text[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Bu AVM için yönetim yetkiniz bulunmuyor.' using errcode = '42501';
  end if;
  if not public.mall_member_has_role(p_mall_id, p_roles) then
    raise exception 'Bu AVM için yönetim yetkiniz bulunmuyor.' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.update_mall_profile(
  p_mall_id uuid,
  p_name text,
  p_legal_name text,
  p_city text,
  p_district text,
  p_address_text text,
  p_phone text,
  p_website text,
  p_opening_hours text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.malls%rowtype;
begin
  perform public.mall_management_assert_role(
    p_mall_id,
    array['mall_manager', 'mall_content_editor']
  );
  update public.malls
  set
    name = btrim(p_name),
    legal_name = nullif(btrim(coalesce(p_legal_name, '')), ''),
    city = btrim(p_city),
    district = btrim(p_district),
    address_text = btrim(p_address_text),
    phone = nullif(btrim(coalesce(p_phone, '')), ''),
    website = nullif(btrim(coalesce(p_website, '')), ''),
    opening_hours = nullif(btrim(coalesce(p_opening_hours, '')), '')
  where id = p_mall_id
  returning * into v_row;
  if v_row.id is null then
    raise exception 'Bu AVM için yönetim yetkiniz bulunmuyor.' using errcode = '42501';
  end if;
  return to_jsonb(v_row);
end;
$$;

create or replace function public.upsert_mall_floor(
  p_mall_id uuid,
  p_floor_id uuid,
  p_name text,
  p_level_number integer,
  p_sort_order integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.mall_floors%rowtype;
  v_sort integer := coalesce(p_sort_order, 0);
begin
  perform public.mall_management_assert_role(
    p_mall_id,
    array['mall_manager', 'mall_store_manager']
  );
  if p_floor_id is null then
    insert into public.mall_floors (mall_id, name, level_number, sort_order)
    values (p_mall_id, btrim(p_name), p_level_number, v_sort)
    returning * into v_row;
  else
    update public.mall_floors
    set
      name = btrim(p_name),
      level_number = p_level_number,
      sort_order = v_sort
    where id = p_floor_id
      and mall_id = p_mall_id
    returning * into v_row;
    if v_row.id is null then
      raise exception 'Kat bulunamadı.';
    end if;
  end if;
  return to_jsonb(v_row);
end;
$$;

create or replace function public.delete_mall_floor(
  p_mall_id uuid,
  p_floor_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  perform public.mall_management_assert_role(
    p_mall_id,
    array['mall_manager', 'mall_store_manager']
  );
  select count(*) into v_count
  from public.mall_units u
  where u.mall_id = p_mall_id
    and u.floor_id = p_floor_id;
  if v_count > 0 then
    raise exception
      'Bu katta % mağaza birimi bulunuyor. Önce birimleri kaldırın veya başka kata taşıyın.',
      v_count;
  end if;
  delete from public.mall_floors
  where id = p_floor_id
    and mall_id = p_mall_id;
  if not found then
    raise exception 'Kat bulunamadı.';
  end if;
end;
$$;

create or replace function public.upsert_mall_unit(
  p_mall_id uuid,
  p_unit_id uuid,
  p_floor_id uuid,
  p_unit_code text,
  p_name text,
  p_unit_type text,
  p_occupancy text,
  p_area_m2 numeric,
  p_sort_order integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.mall_units%rowtype;
  v_occupancy text := coalesce(nullif(btrim(p_occupancy), ''), 'vacant');
begin
  perform public.mall_management_assert_role(
    p_mall_id,
    array['mall_manager', 'mall_store_manager']
  );
  if v_occupancy = 'occupied' then
    raise exception 'Doluluk, mağaza bağlantısı onaylandığında belirlenir.';
  end if;
  if v_occupancy not in ('vacant', 'reserved', 'temporarily_closed') then
    raise exception 'Geçersiz birim durumu.';
  end if;
  if p_unit_id is null then
    insert into public.mall_units (
      mall_id, floor_id, unit_code, name, unit_type, occupancy, area_m2, sort_order
    )
    values (
      p_mall_id,
      p_floor_id,
      btrim(p_unit_code),
      nullif(btrim(coalesce(p_name, '')), ''),
      p_unit_type,
      v_occupancy,
      p_area_m2,
      coalesce(p_sort_order, 0)
    )
    returning * into v_row;
  else
    update public.mall_units
    set
      floor_id = p_floor_id,
      unit_code = btrim(p_unit_code),
      name = nullif(btrim(coalesce(p_name, '')), ''),
      unit_type = p_unit_type,
      occupancy = case when occupancy = 'occupied' then 'occupied' else v_occupancy end,
      area_m2 = p_area_m2,
      sort_order = coalesce(p_sort_order, 0)
    where id = p_unit_id
      and mall_id = p_mall_id
    returning * into v_row;
    if v_row.id is null then
      raise exception 'Birim bulunamadı.';
    end if;
  end if;
  return to_jsonb(v_row);
end;
$$;

create or replace function public.delete_mall_unit(
  p_mall_id uuid,
  p_unit_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.mall_management_assert_role(
    p_mall_id,
    array['mall_manager', 'mall_store_manager']
  );
  delete from public.mall_units
  where id = p_unit_id
    and mall_id = p_mall_id;
  if not found then
    raise exception 'Birim bulunamadı.';
  end if;
end;
$$;

revoke all on function public.mall_management_assert_role(uuid, text[]) from public, anon;
revoke all on function public.update_mall_profile(uuid, text, text, text, text, text, text, text, text) from public, anon;
revoke all on function public.upsert_mall_floor(uuid, uuid, text, integer, integer) from public, anon;
revoke all on function public.delete_mall_floor(uuid, uuid) from public, anon;
revoke all on function public.upsert_mall_unit(uuid, uuid, uuid, text, text, text, text, numeric, integer) from public, anon;
revoke all on function public.delete_mall_unit(uuid, uuid) from public, anon;

grant execute on function public.mall_management_assert_role(uuid, text[]) to authenticated;
grant execute on function public.update_mall_profile(uuid, text, text, text, text, text, text, text, text) to authenticated;
grant execute on function public.upsert_mall_floor(uuid, uuid, text, integer, integer) to authenticated;
grant execute on function public.delete_mall_floor(uuid, uuid) to authenticated;
grant execute on function public.upsert_mall_unit(uuid, uuid, uuid, text, text, text, text, numeric, integer) to authenticated;
grant execute on function public.delete_mall_unit(uuid, uuid) to authenticated;

commit;
