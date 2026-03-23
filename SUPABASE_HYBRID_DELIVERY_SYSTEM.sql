begin;

create extension if not exists pgcrypto;

create or replace function public.delivery_is_admin(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = target_user_id
      and lower(coalesce(u.role, '')) in ('admin', 'super_admin')
  );
$$;

grant execute on function public.delivery_is_admin(uuid) to authenticated;

create or replace function public.delivery_jsonb_get_numeric(
  p_json jsonb,
  p_key text,
  p_fallback numeric
)
returns numeric
language plpgsql
immutable
as $$
declare
  raw text;
begin
  raw := coalesce(p_json ->> p_key, '');
  if trim(raw) = '' then
    return p_fallback;
  end if;
  begin
    return raw::numeric;
  exception when others then
    return p_fallback;
  end;
end;
$$;

create or replace function public.delivery_geo_distance_km(
  p_lat1 double precision,
  p_lng1 double precision,
  p_lat2 double precision,
  p_lng2 double precision
)
returns numeric
language sql
immutable
as $$
  select (
    6371 * acos(
      greatest(
        least(
          cos(radians(p_lat1)) * cos(radians(p_lat2)) * cos(radians(p_lng2) - radians(p_lng1))
          + sin(radians(p_lat1)) * sin(radians(p_lat2)),
          1
        ),
        -1
      )
    )
  )::numeric;
$$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'shipment_type') then
    create type public.shipment_type as enum ('ihiz_direct', 'standard_cargo', 'ihiz_to_branch');
  end if;
  if not exists (select 1 from pg_type where typname = 'payer_mode') then
    create type public.payer_mode as enum ('customer_pays', 'seller_pays', 'hybrid');
  end if;
end;
$$;

create table if not exists public.addresses (
  id uuid primary key default gen_random_uuid(),
  formatted_address text not null,
  city text,
  district text,
  latitude double precision not null,
  longitude double precision not null,
  place_id text,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_addresses_city_district on public.addresses(city, district);

create table if not exists public.user_saved_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  address_id uuid not null references public.addresses(id) on delete cascade,
  label text,
  is_default boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  unique(user_id, address_id)
);

create index if not exists idx_user_saved_addresses_user on public.user_saved_addresses(user_id, created_at desc);

create table if not exists public.seller_locations (
  seller_id uuid primary key references public.users(id) on delete cascade,
  address_id uuid references public.addresses(id) on delete set null,
  latitude double precision not null,
  longitude double precision not null,
  city text,
  district text,
  is_active boolean not null default true,
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.cargo_companies (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  is_enabled boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.cargo_branches (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.cargo_companies(id) on delete cascade,
  branch_code text,
  name text not null,
  city text,
  district text,
  address text,
  latitude double precision not null,
  longitude double precision not null,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_cargo_branches_company_city on public.cargo_branches(company_id, city, is_active);

create table if not exists public.delivery_quotes (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.users(id) on delete cascade,
  user_id uuid references public.users(id) on delete set null,
  source text not null,
  payer_mode public.payer_mode not null default 'seller_pays',
  customer_address_id uuid references public.addresses(id) on delete set null,
  distance_km numeric(10, 3) not null,
  eta_minutes numeric(10, 2) not null,
  recommended_type public.shipment_type not null,
  options jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz not null
);

create index if not exists idx_delivery_quotes_seller_created on public.delivery_quotes(seller_id, created_at desc);
create index if not exists idx_delivery_quotes_user_created on public.delivery_quotes(user_id, created_at desc);

create table if not exists public.delivery_options (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.delivery_quotes(id) on delete cascade,
  shipment_type public.shipment_type not null,
  is_available boolean not null default false,
  reason_code text,
  delivery_fee numeric(12, 2),
  courier_fee numeric(12, 2),
  platform_fee numeric(12, 2),
  customer_delivery_fee numeric(12, 2),
  seller_delivery_fee numeric(12, 2),
  surge_multiplier numeric(5, 2),
  weather_bonus numeric(12, 2),
  night_bonus numeric(12, 2),
  multi_order_bonus numeric(12, 2),
  distance_km numeric(10, 3),
  eta_minutes numeric(10, 2),
  branch_distance_km numeric(10, 3),
  selected_branch_id uuid references public.cargo_branches(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  unique(quote_id, shipment_type)
);

create index if not exists idx_delivery_options_quote on public.delivery_options(quote_id, shipment_type);

alter table if exists public.orders
  add column if not exists shipment_type public.shipment_type,
  add column if not exists selected_branch_id uuid references public.cargo_branches(id) on delete set null,
  add column if not exists customer_delivery_fee numeric(12,2),
  add column if not exists seller_delivery_fee numeric(12,2),
  add column if not exists distance_km numeric(10,3),
  add column if not exists branch_distance_km numeric(10,3),
  add column if not exists delivery_quote_id uuid references public.delivery_quotes(id) on delete set null;

insert into public.cargo_companies(code, name, is_enabled)
values
  ('aras', 'Aras Kargo', true),
  ('mng', 'MNG Kargo', true),
  ('ptt', 'PTT Kargo', true)
on conflict (code) do nothing;

-- Optional sample branches for quick demo
insert into public.cargo_branches(company_id, branch_code, name, city, district, address, latitude, longitude, is_active)
select c.id, 'EKS-001', 'Aras Eskişehir Merkez', 'Eskişehir', 'Odunpazarı', 'Arifiye Mah. Demo Sok. 1', 39.776, 30.520, true
from public.cargo_companies c
where c.code = 'aras'
  and not exists (
    select 1 from public.cargo_branches b where b.company_id = c.id and b.branch_code = 'EKS-001'
  )
union all
select c.id, 'EKS-101', 'MNG Tepebaşı', 'Eskişehir', 'Tepebaşı', 'Bahçelievler Mah. Demo Sok. 2', 39.789, 30.506, true
from public.cargo_companies c
where c.code = 'mng'
  and not exists (
    select 1 from public.cargo_branches b where b.company_id = c.id and b.branch_code = 'EKS-101'
  )
union all
select c.id, 'EKS-201', 'PTT Doktorlar', 'Eskişehir', 'Tepebaşı', 'Doktorlar Cad. Demo Sok. 3', 39.782, 30.522, true
from public.cargo_companies c
where c.code = 'ptt'
  and not exists (
    select 1 from public.cargo_branches b where b.company_id = c.id and b.branch_code = 'EKS-201'
  );

create or replace function public.hybrid_delivery_branch_search(
  p_company_id uuid,
  p_origin_lat double precision,
  p_origin_lng double precision,
  p_city text default null,
  p_limit integer default 10
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_config jsonb := '{}'::jsonb;
  v_branch_base_fee numeric := 20;
  v_branch_km_fee numeric := 6;
  v_rows jsonb := '[]'::jsonb;
begin
  if p_company_id is null then
    return jsonb_build_object('ok', false, 'error', 'company_required');
  end if;

  select config
  into v_config
  from public.ihiz_pricing_rule_versions
  where is_active = true
  order by version desc
  limit 1;

  v_branch_base_fee := public.delivery_jsonb_get_numeric(v_config, 'branch_base_fee', 20);
  v_branch_km_fee := public.delivery_jsonb_get_numeric(v_config, 'branch_km_fee', 6);

  with branch_rows as (
    select
      b.id,
      b.name,
      b.branch_code,
      b.city,
      b.district,
      b.address,
      c.code as company_code,
      c.name as company_name,
      public.delivery_geo_distance_km(p_origin_lat, p_origin_lng, b.latitude, b.longitude) as distance_km
    from public.cargo_branches b
    join public.cargo_companies c on c.id = b.company_id
    where b.company_id = p_company_id
      and b.is_active = true
      and c.is_enabled = true
      and (coalesce(trim(p_city), '') = '' or lower(coalesce(b.city, '')) = lower(trim(p_city)))
    order by distance_km asc
    limit greatest(1, least(coalesce(p_limit, 10), 30))
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'branch_id', id,
        'name', name,
        'branch_code', branch_code,
        'city', city,
        'district', district,
        'address', address,
        'company_code', company_code,
        'company_name', company_name,
        'distance_km', round(distance_km::numeric, 3),
        'branch_drop_fee', round((v_branch_base_fee + (distance_km * v_branch_km_fee))::numeric, 2)
      )
      order by distance_km asc
    ),
    '[]'::jsonb
  )
  into v_rows
  from branch_rows;

  return jsonb_build_object('ok', true, 'branches', v_rows);
end;
$$;

grant execute on function public.hybrid_delivery_branch_search(uuid, double precision, double precision, text, integer) to authenticated;

create or replace function public.hybrid_delivery_quote(
  p_actor_user_id uuid,
  p_source text,
  p_seller_id uuid,
  p_customer_address jsonb,
  p_weather text default 'clear',
  p_is_night boolean default false,
  p_surge_level text default 'normal',
  p_payer_mode public.payer_mode default 'seller_pays',
  p_selected_company_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_config jsonb := '{}'::jsonb;

  v_nearby_threshold numeric := 8;
  v_medium_threshold numeric := 20;
  v_direct_max_distance numeric := 20;
  v_direct_base_fee numeric := 28;
  v_direct_km_fee numeric := 7;
  v_platform_fee numeric := 10;
  v_branch_base_fee numeric := 20;
  v_branch_km_fee numeric := 6;
  v_min_fee numeric := 35;
  v_max_fee numeric := 350;

  v_minute_price numeric := 4;
  v_eta_per_km_minute numeric := 5;
  v_eta_base_minute numeric := 6;
  v_night_bonus numeric := 12;
  v_rain_bonus numeric := 15;
  v_storm_bonus numeric := 20;
  v_snow_bonus numeric := 25;
  v_multi_order_bonus numeric := 25;

  v_active_cities_csv text := '';
  v_enabled_companies_csv text := '';

  v_seller_lat double precision;
  v_seller_lng double precision;
  v_customer_lat double precision;
  v_customer_lng double precision;

  v_distance_km numeric;
  v_eta_minutes numeric;
  v_surge_multiplier numeric := 1.0;
  v_weather_bonus numeric := 0;

  v_direct_available boolean := false;
  v_standard_available boolean := false;
  v_branch_available boolean := false;
  v_city_allowed boolean := true;

  v_recommended public.shipment_type := 'standard_cargo';
  v_customer_address_id uuid;
  v_quote_id uuid;

  v_direct_courier_fee numeric := 0;
  v_direct_total numeric := 0;
  v_direct_customer_fee numeric := 0;
  v_direct_seller_fee numeric := 0;

  v_branch_distance_km numeric := null;
  v_branch_total numeric := null;
  v_branch_customer_fee numeric := null;
  v_branch_seller_fee numeric := null;
  v_branch_id uuid := null;

  v_customer_tier_fee numeric := 0;
  v_options jsonb := '[]'::jsonb;
  v_selected_city text := null;
begin
  if p_actor_user_id is null then
    return jsonb_build_object('ok', false, 'error', 'actor_required');
  end if;
  if p_seller_id is null then
    return jsonb_build_object('ok', false, 'error', 'seller_required');
  end if;
  if p_customer_address is null then
    return jsonb_build_object('ok', false, 'error', 'customer_address_required');
  end if;

  select config
  into v_config
  from public.ihiz_pricing_rule_versions
  where is_active = true
  order by version desc
  limit 1;

  v_nearby_threshold := public.delivery_jsonb_get_numeric(v_config, 'nearby_threshold_km', 8);
  v_medium_threshold := public.delivery_jsonb_get_numeric(v_config, 'medium_distance_threshold_km', 20);
  v_direct_max_distance := public.delivery_jsonb_get_numeric(v_config, 'ihiz_direct_max_distance_km', 20);
  v_direct_base_fee := public.delivery_jsonb_get_numeric(v_config, 'base_fee', 28);
  v_direct_km_fee := public.delivery_jsonb_get_numeric(v_config, 'per_km_fee', 7);
  v_platform_fee := public.delivery_jsonb_get_numeric(v_config, 'platform_fee', 10);
  v_branch_base_fee := public.delivery_jsonb_get_numeric(v_config, 'branch_base_fee', 20);
  v_branch_km_fee := public.delivery_jsonb_get_numeric(v_config, 'branch_km_fee', 6);
  v_min_fee := public.delivery_jsonb_get_numeric(v_config, 'min_delivery_fee', 35);
  v_max_fee := public.delivery_jsonb_get_numeric(v_config, 'max_delivery_fee', 350);
  v_minute_price := public.delivery_jsonb_get_numeric(v_config, 'courier_minute_price', 4);
  v_eta_per_km_minute := public.delivery_jsonb_get_numeric(v_config, 'eta_per_km_minute', 5);
  v_eta_base_minute := public.delivery_jsonb_get_numeric(v_config, 'eta_base_minute', 6);
  v_night_bonus := public.delivery_jsonb_get_numeric(v_config, 'courier_night_bonus', 12);
  v_rain_bonus := public.delivery_jsonb_get_numeric(v_config, 'courier_rain_bonus', 15);
  v_storm_bonus := public.delivery_jsonb_get_numeric(v_config, 'courier_storm_bonus', 20);
  v_snow_bonus := public.delivery_jsonb_get_numeric(v_config, 'courier_snow_bonus', 25);
  v_multi_order_bonus := public.delivery_jsonb_get_numeric(v_config, 'courier_multi_order_bonus', 25);

  v_active_cities_csv := coalesce(v_config ->> 'ihiz_active_cities', '');
  v_enabled_companies_csv := coalesce(v_config ->> 'enabled_cargo_companies', '');

  select
    coalesce(sl.latitude, s.store_lat),
    coalesce(sl.longitude, s.store_lng)
  into v_seller_lat, v_seller_lng
  from public.users u
  left join public.seller_locations sl on sl.seller_id = u.id and sl.is_active = true
  left join public.stores s on s.seller_id = u.id
  where u.id = p_seller_id
  limit 1;

  if v_seller_lat is null or v_seller_lng is null then
    return jsonb_build_object('ok', false, 'error', 'seller_location_missing');
  end if;

  begin
    v_customer_lat := coalesce(
      nullif(trim(coalesce(p_customer_address ->> 'lat', '')), '')::double precision,
      nullif(trim(coalesce(p_customer_address ->> 'latitude', '')), '')::double precision
    );
    v_customer_lng := coalesce(
      nullif(trim(coalesce(p_customer_address ->> 'lng', '')), '')::double precision,
      nullif(trim(coalesce(p_customer_address ->> 'longitude', '')), '')::double precision
    );
  exception when others then
    return jsonb_build_object('ok', false, 'error', 'invalid_customer_coordinates');
  end;

  if v_customer_lat is null or v_customer_lng is null then
    return jsonb_build_object('ok', false, 'error', 'customer_coordinates_missing');
  end if;

  v_selected_city := coalesce(
    nullif(trim(coalesce(p_customer_address ->> 'city', '')), ''),
    nullif(trim(coalesce(p_customer_address ->> 'il', '')), '')
  );

  if trim(v_active_cities_csv) <> '' and v_selected_city is not null then
    v_city_allowed := lower(v_selected_city) = any(
      string_to_array(lower(replace(v_active_cities_csv, ' ', '')), ',')
    );
  end if;

  insert into public.addresses(
    formatted_address,
    city,
    district,
    latitude,
    longitude,
    place_id,
    created_by
  ) values (
    coalesce(nullif(trim(coalesce(p_customer_address ->> 'formatted_address', '')), ''), 'Adres'),
    v_selected_city,
    nullif(trim(coalesce(p_customer_address ->> 'district', '')), ''),
    v_customer_lat,
    v_customer_lng,
    nullif(trim(coalesce(p_customer_address ->> 'place_id', '')), ''),
    p_actor_user_id
  ) returning id into v_customer_address_id;

  if p_source = 'ibul_checkout' then
    insert into public.user_saved_addresses(user_id, address_id, label, is_default)
    values (
      p_actor_user_id,
      v_customer_address_id,
      nullif(trim(coalesce(p_customer_address ->> 'label', '')), ''),
      coalesce((p_customer_address ->> 'is_default')::boolean, false)
    )
    on conflict (user_id, address_id) do nothing;
  end if;

  v_distance_km := public.delivery_geo_distance_km(v_seller_lat, v_seller_lng, v_customer_lat, v_customer_lng);
  v_distance_km := round(greatest(v_distance_km, 0)::numeric, 3);
  v_eta_minutes := round((v_eta_base_minute + (v_distance_km * v_eta_per_km_minute))::numeric, 2);

  case lower(coalesce(p_surge_level, 'normal'))
    when 'medium' then v_surge_multiplier := 1.2;
    when 'high' then v_surge_multiplier := 1.4;
    else v_surge_multiplier := 1.0;
  end case;

  case lower(coalesce(p_weather, 'clear'))
    when 'rain' then v_weather_bonus := v_rain_bonus;
    when 'storm' then v_weather_bonus := v_storm_bonus;
    when 'snow' then v_weather_bonus := v_snow_bonus;
    else v_weather_bonus := 0;
  end case;

  if v_distance_km <= v_nearby_threshold then
    v_direct_available := true;
    v_standard_available := false;
    v_branch_available := false;
    v_recommended := 'ihiz_direct';
  elsif v_distance_km <= v_medium_threshold then
    v_direct_available := true;
    v_standard_available := true;
    v_branch_available := false;
    v_recommended := 'ihiz_direct';
  else
    v_direct_available := false;
    v_standard_available := true;
    v_branch_available := true;
    v_recommended := 'standard_cargo';
  end if;

  if v_distance_km > v_direct_max_distance then
    v_direct_available := false;
    if v_recommended = 'ihiz_direct' then
      v_recommended := 'standard_cargo';
    end if;
  end if;

  if not v_city_allowed then
    v_direct_available := false;
    v_branch_available := false;
    v_recommended := 'standard_cargo';
  end if;

  if v_direct_available then
    v_direct_courier_fee := greatest(
      v_direct_base_fee + (v_distance_km * v_direct_km_fee),
      v_eta_minutes * v_minute_price
    );
    v_direct_courier_fee := (v_direct_courier_fee * v_surge_multiplier)
      + case when p_is_night then v_night_bonus else 0 end
      + v_weather_bonus;

    v_direct_total := v_direct_courier_fee + v_platform_fee;
    v_direct_total := least(greatest(v_direct_total, v_min_fee), v_max_fee);

    if p_payer_mode = 'customer_pays' then
      v_direct_customer_fee := v_direct_total;
      v_direct_seller_fee := 0;
    elsif p_payer_mode = 'hybrid' then
      if v_distance_km <= 3 then
        v_customer_tier_fee := public.delivery_jsonb_get_numeric(v_config, 'customer_fee_0_3_km', 35);
      elsif v_distance_km <= 6 then
        v_customer_tier_fee := public.delivery_jsonb_get_numeric(v_config, 'customer_fee_3_6_km', 45);
      else
        v_customer_tier_fee := public.delivery_jsonb_get_numeric(v_config, 'customer_fee_6_plus_km', 55);
      end if;
      v_direct_customer_fee := least(v_direct_total, v_customer_tier_fee);
      v_direct_seller_fee := greatest(v_direct_total - v_direct_customer_fee, 0);
    else
      v_direct_customer_fee := 0;
      v_direct_seller_fee := v_direct_total;
    end if;
  end if;

  if v_branch_available then
    if p_selected_company_id is not null then
      select
        b.id,
        public.delivery_geo_distance_km(v_seller_lat, v_seller_lng, b.latitude, b.longitude)
      into v_branch_id, v_branch_distance_km
      from public.cargo_branches b
      join public.cargo_companies c on c.id = b.company_id
      where b.company_id = p_selected_company_id
        and b.is_active = true
        and c.is_enabled = true
        and (
          trim(v_enabled_companies_csv) = ''
          or lower(c.code) = any(string_to_array(lower(replace(v_enabled_companies_csv, ' ', '')), ','))
        )
      order by public.delivery_geo_distance_km(v_seller_lat, v_seller_lng, b.latitude, b.longitude)
      limit 1;
    end if;

    if v_branch_id is not null then
      v_branch_total := round((v_branch_base_fee + (v_branch_distance_km * v_branch_km_fee))::numeric, 2);
      if p_payer_mode = 'customer_pays' then
        v_branch_customer_fee := v_branch_total;
        v_branch_seller_fee := 0;
      elsif p_payer_mode = 'hybrid' then
        v_branch_customer_fee := least(v_branch_total, public.delivery_jsonb_get_numeric(v_config, 'customer_fee_0_3_km', 35));
        v_branch_seller_fee := greatest(v_branch_total - v_branch_customer_fee, 0);
      else
        v_branch_customer_fee := 0;
        v_branch_seller_fee := v_branch_total;
      end if;
    end if;
  end if;

  insert into public.delivery_quotes(
    seller_id,
    user_id,
    source,
    payer_mode,
    customer_address_id,
    distance_km,
    eta_minutes,
    recommended_type,
    expires_at
  )
  values (
    p_seller_id,
    case when p_source = 'ibul_checkout' then p_actor_user_id else null end,
    p_source,
    p_payer_mode,
    v_customer_address_id,
    v_distance_km,
    v_eta_minutes,
    v_recommended,
    v_now + interval '15 minutes'
  )
  returning id into v_quote_id;

  insert into public.delivery_options(
    quote_id,
    shipment_type,
    is_available,
    reason_code,
    delivery_fee,
    courier_fee,
    platform_fee,
    customer_delivery_fee,
    seller_delivery_fee,
    surge_multiplier,
    weather_bonus,
    night_bonus,
    multi_order_bonus,
    distance_km,
    eta_minutes,
    metadata
  ) values (
    v_quote_id,
    'ihiz_direct',
    v_direct_available,
    case
      when not v_city_allowed then 'city_not_active'
      when v_distance_km > v_direct_max_distance then 'exceeds_direct_max_distance'
      when v_distance_km > v_medium_threshold then 'distance_over_medium_threshold'
      else null
    end,
    case when v_direct_available then round(v_direct_total::numeric, 2) else null end,
    case when v_direct_available then round(v_direct_courier_fee::numeric, 2) else null end,
    case when v_direct_available then round(v_platform_fee::numeric, 2) else null end,
    case when v_direct_available then round(v_direct_customer_fee::numeric, 2) else null end,
    case when v_direct_available then round(v_direct_seller_fee::numeric, 2) else null end,
    round(v_surge_multiplier::numeric, 2),
    round(v_weather_bonus::numeric, 2),
    round((case when p_is_night then v_night_bonus else 0 end)::numeric, 2),
    round(v_multi_order_bonus::numeric, 2),
    v_distance_km,
    v_eta_minutes,
    jsonb_build_object('type', 'ihiz_direct')
  );

  insert into public.delivery_options(
    quote_id,
    shipment_type,
    is_available,
    reason_code,
    metadata
  ) values (
    v_quote_id,
    'standard_cargo',
    v_standard_available,
    case
      when v_distance_km <= v_nearby_threshold then 'prefer_ihiz_direct_for_nearby'
      else null
    end,
    jsonb_build_object('note', 'seller_contract_cargo')
  );

  insert into public.delivery_options(
    quote_id,
    shipment_type,
    is_available,
    reason_code,
    delivery_fee,
    courier_fee,
    platform_fee,
    customer_delivery_fee,
    seller_delivery_fee,
    distance_km,
    eta_minutes,
    branch_distance_km,
    selected_branch_id,
    metadata
  ) values (
    v_quote_id,
    'ihiz_to_branch',
    v_branch_available,
    case
      when not v_city_allowed then 'city_not_active'
      when v_distance_km <= v_medium_threshold then 'only_for_long_distance'
      when v_branch_id is null then 'branch_not_selected_or_not_found'
      else null
    end,
    case when v_branch_available and v_branch_total is not null then round(v_branch_total::numeric, 2) else null end,
    case when v_branch_available and v_branch_total is not null then round(v_branch_total::numeric, 2) else null end,
    0,
    case when v_branch_available then round(coalesce(v_branch_customer_fee, 0)::numeric, 2) else null end,
    case when v_branch_available then round(coalesce(v_branch_seller_fee, 0)::numeric, 2) else null end,
    v_distance_km,
    v_eta_minutes,
    case when v_branch_distance_km is not null then round(v_branch_distance_km::numeric, 3) else null end,
    v_branch_id,
    jsonb_build_object(
      'type', 'ihiz_to_branch',
      'branch_base_fee', v_branch_base_fee,
      'branch_km_fee', v_branch_km_fee
    )
  );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'option_id', o.id,
        'shipment_type', o.shipment_type,
        'is_available', o.is_available,
        'reason_code', o.reason_code,
        'delivery_fee', o.delivery_fee,
        'courier_fee', o.courier_fee,
        'platform_fee', o.platform_fee,
        'customer_delivery_fee', o.customer_delivery_fee,
        'seller_delivery_fee', o.seller_delivery_fee,
        'surge_multiplier', o.surge_multiplier,
        'weather_bonus', o.weather_bonus,
        'night_bonus', o.night_bonus,
        'distance_km', o.distance_km,
        'eta_minutes', o.eta_minutes,
        'branch_distance_km', o.branch_distance_km,
        'selected_branch_id', o.selected_branch_id,
        'metadata', o.metadata
      )
      order by
        case o.shipment_type
          when 'ihiz_direct' then 1
          when 'standard_cargo' then 2
          else 3
        end
    ),
    '[]'::jsonb
  )
  into v_options
  from public.delivery_options o
  where o.quote_id = v_quote_id;

  update public.delivery_quotes
  set options = v_options,
      recommended_type = v_recommended
  where id = v_quote_id;

  return jsonb_build_object(
    'ok', true,
    'quote_id', v_quote_id,
    'distance_km', v_distance_km,
    'eta_minutes', v_eta_minutes,
    'recommended_type', v_recommended,
    'options', v_options
  );
end;
$$;

grant execute on function public.hybrid_delivery_quote(
  uuid,
  text,
  uuid,
  jsonb,
  text,
  boolean,
  text,
  public.payer_mode,
  uuid
) to authenticated;

create or replace function public.hybrid_delivery_confirm_option(
  p_actor_user_id uuid,
  p_order_id text,
  p_quote_id uuid,
  p_option_id uuid,
  p_selected_branch_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quote public.delivery_quotes%rowtype;
  v_option public.delivery_options%rowtype;
  v_allowed boolean := false;
  v_order_exists boolean := false;
  v_updated_count bigint := 0;
begin
  if p_actor_user_id is null then
    return jsonb_build_object('ok', false, 'error', 'actor_required');
  end if;

  select *
  into v_quote
  from public.delivery_quotes
  where id = p_quote_id;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'quote_not_found');
  end if;

  select *
  into v_option
  from public.delivery_options
  where id = p_option_id
    and quote_id = p_quote_id;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'option_not_found');
  end if;

  if not v_option.is_available then
    return jsonb_build_object('ok', false, 'error', 'option_not_available', 'reason', v_option.reason_code);
  end if;

  v_allowed := (
    p_actor_user_id = v_quote.seller_id
    or p_actor_user_id = v_quote.user_id
    or public.delivery_is_admin(p_actor_user_id)
  );

  if not v_allowed then
    return jsonb_build_object('ok', false, 'error', 'not_authorized');
  end if;

  if to_regclass('public.orders') is not null then
    update public.orders
    set
      shipment_type = v_option.shipment_type,
      selected_branch_id = coalesce(p_selected_branch_id, v_option.selected_branch_id),
      customer_delivery_fee = coalesce(v_option.customer_delivery_fee, 0),
      seller_delivery_fee = coalesce(v_option.seller_delivery_fee, 0),
      distance_km = v_quote.distance_km,
      branch_distance_km = v_option.branch_distance_km,
      delivery_quote_id = v_quote.id,
      total_delivery_fee = coalesce(v_option.delivery_fee, 0),
      updated_at = timezone('utc', now())
    where id::text = p_order_id;

    get diagnostics v_updated_count = row_count;
    v_order_exists := v_updated_count > 0;
  end if;

  return jsonb_build_object(
    'ok', true,
    'order_updated', v_order_exists,
    'order_id', p_order_id,
    'quote_id', v_quote.id,
    'selected_option_id', v_option.id,
    'shipment_type', v_option.shipment_type,
    'delivery_fee', v_option.delivery_fee,
    'customer_delivery_fee', v_option.customer_delivery_fee,
    'seller_delivery_fee', v_option.seller_delivery_fee,
    'seller_id', v_quote.seller_id,
    'source', v_quote.source
  );
end;
$$;

grant execute on function public.hybrid_delivery_confirm_option(uuid, text, uuid, uuid, uuid) to authenticated;

-- Ensure active config has hybrid keys.
update public.ihiz_pricing_rule_versions
set config = config
  || jsonb_build_object(
    'nearby_threshold_km', coalesce(config -> 'nearby_threshold_km', to_jsonb(8)),
    'medium_distance_threshold_km', coalesce(config -> 'medium_distance_threshold_km', to_jsonb(20)),
    'ihiz_direct_max_distance_km', coalesce(config -> 'ihiz_direct_max_distance_km', to_jsonb(20)),
    'platform_fee', coalesce(config -> 'platform_fee', to_jsonb(10)),
    'branch_base_fee', coalesce(config -> 'branch_base_fee', to_jsonb(20)),
    'branch_km_fee', coalesce(config -> 'branch_km_fee', to_jsonb(6)),
    'courier_minute_price', coalesce(config -> 'courier_minute_price', to_jsonb(4)),
    'courier_storm_bonus', coalesce(config -> 'courier_storm_bonus', to_jsonb(20)),
    'courier_snow_bonus', coalesce(config -> 'courier_snow_bonus', to_jsonb(25)),
    'ihiz_active_cities', coalesce(config -> 'ihiz_active_cities', to_jsonb('Eskişehir,İstanbul,Ankara'::text)),
    'enabled_cargo_companies', coalesce(config -> 'enabled_cargo_companies', to_jsonb('aras,mng,ptt'::text))
  )
where config is not null;

create or replace function public.get_active_ihiz_pricing_config()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (
      select config
      from public.ihiz_pricing_rule_versions
      where is_active = true
      order by version desc
      limit 1
    ),
    '{}'::jsonb
  );
$$;

revoke all on function public.get_active_ihiz_pricing_config() from public;
grant execute on function public.get_active_ihiz_pricing_config() to anon, authenticated;

alter table public.addresses enable row level security;
alter table public.user_saved_addresses enable row level security;
alter table public.seller_locations enable row level security;
alter table public.cargo_companies enable row level security;
alter table public.cargo_branches enable row level security;
alter table public.delivery_quotes enable row level security;
alter table public.delivery_options enable row level security;

drop policy if exists "addresses_read_write_authenticated" on public.addresses;
create policy "addresses_read_write_authenticated"
on public.addresses
for all
to authenticated
using (true)
with check (true);

drop policy if exists "user_saved_addresses_owner" on public.user_saved_addresses;
create policy "user_saved_addresses_owner"
on public.user_saved_addresses
for all
to authenticated
using (auth.uid() = user_id or public.delivery_is_admin(auth.uid()))
with check (auth.uid() = user_id or public.delivery_is_admin(auth.uid()));

drop policy if exists "seller_locations_select" on public.seller_locations;
create policy "seller_locations_select"
on public.seller_locations
for select
to authenticated
using (true);

drop policy if exists "seller_locations_manage" on public.seller_locations;
create policy "seller_locations_manage"
on public.seller_locations
for all
to authenticated
using (auth.uid() = seller_id or public.delivery_is_admin(auth.uid()))
with check (auth.uid() = seller_id or public.delivery_is_admin(auth.uid()));

drop policy if exists "cargo_companies_select" on public.cargo_companies;
create policy "cargo_companies_select"
on public.cargo_companies
for select
to authenticated
using (true);

drop policy if exists "cargo_companies_manage" on public.cargo_companies;
create policy "cargo_companies_manage"
on public.cargo_companies
for all
to authenticated
using (public.delivery_is_admin(auth.uid()))
with check (public.delivery_is_admin(auth.uid()));

drop policy if exists "cargo_branches_select" on public.cargo_branches;
create policy "cargo_branches_select"
on public.cargo_branches
for select
to authenticated
using (true);

drop policy if exists "cargo_branches_manage" on public.cargo_branches;
create policy "cargo_branches_manage"
on public.cargo_branches
for all
to authenticated
using (public.delivery_is_admin(auth.uid()))
with check (public.delivery_is_admin(auth.uid()));

drop policy if exists "delivery_quotes_select" on public.delivery_quotes;
create policy "delivery_quotes_select"
on public.delivery_quotes
for select
to authenticated
using (
  auth.uid() = seller_id
  or auth.uid() = user_id
  or public.delivery_is_admin(auth.uid())
);

drop policy if exists "delivery_quotes_insert" on public.delivery_quotes;
create policy "delivery_quotes_insert"
on public.delivery_quotes
for insert
to authenticated
with check (
  auth.uid() = seller_id
  or auth.uid() = user_id
  or public.delivery_is_admin(auth.uid())
);

drop policy if exists "delivery_options_select" on public.delivery_options;
create policy "delivery_options_select"
on public.delivery_options
for select
to authenticated
using (
  exists (
    select 1
    from public.delivery_quotes q
    where q.id = quote_id
      and (
        q.seller_id = auth.uid()
        or q.user_id = auth.uid()
        or public.delivery_is_admin(auth.uid())
      )
  )
);

commit;
