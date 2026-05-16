-- Kitchen print routing infrastructure
-- Creates station/printer routing model and transactional order->print_job pipeline.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1) Core tables
-- ---------------------------------------------------------------------------

create table if not exists public.stations (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.stores(seller_id) on delete cascade,
  name text not null,
  code text not null,
  color text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index if not exists idx_stations_restaurant_code_unique
  on public.stations(restaurant_id, code);
create index if not exists idx_stations_restaurant_id
  on public.stations(restaurant_id);
create index if not exists idx_stations_restaurant_active
  on public.stations(restaurant_id, is_active);

create table if not exists public.printers (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.stores(seller_id) on delete cascade,
  name text not null,
  code text not null,
  connection_type text not null default 'network'
    check (connection_type in ('network', 'usb', 'bluetooth')),
  ip_address text,
  port integer,
  device_identifier text,
  paper_width_mm integer not null default 80,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index if not exists idx_printers_restaurant_code_unique
  on public.printers(restaurant_id, code);
create index if not exists idx_printers_restaurant_id
  on public.printers(restaurant_id);
create index if not exists idx_printers_restaurant_active
  on public.printers(restaurant_id, is_active);

create table if not exists public.station_printers (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references public.stations(id) on delete cascade,
  printer_id uuid not null references public.printers(id) on delete cascade,
  is_primary boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index if not exists idx_station_printers_unique
  on public.station_printers(station_id, printer_id);
create index if not exists idx_station_printers_station_id
  on public.station_printers(station_id, is_primary);
create index if not exists idx_station_printers_printer_id
  on public.station_printers(printer_id);

-- Existing products table extensions
alter table public.products
  add column if not exists station_id uuid references public.stations(id) on delete set null;

alter table public.products
  add column if not exists printer_routing_enabled boolean not null default true;

create index if not exists idx_products_station_id
  on public.products(station_id);

-- Existing orders table extensions (table service + kitchen routing)
alter table public.orders
  add column if not exists restaurant_id uuid references public.stores(seller_id) on delete set null;

alter table public.orders
  add column if not exists table_id uuid references public.store_tables(id) on delete set null;

alter table public.orders
  add column if not exists waiter_id uuid references public.users(id) on delete set null;

alter table public.orders
  add column if not exists order_status text;

alter table public.orders
  add column if not exists order_type text not null default 'table';

alter table public.orders
  add column if not exists notes text;

update public.orders
set order_status = coalesce(nullif(order_status, ''), status)
where order_status is null;

create index if not exists idx_orders_restaurant_id
  on public.orders(restaurant_id);

-- Existing order_items table extensions
alter table public.order_items
  add column if not exists station_id uuid references public.stations(id) on delete set null;

alter table public.order_items
  add column if not exists item_note text;

alter table public.order_items
  add column if not exists kitchen_status text not null default 'pending';

alter table public.order_items
  add column if not exists sent_to_kitchen_at timestamptz;

alter table public.order_items
  add column if not exists line_total numeric(12,2);

update public.order_items
set line_total = coalesce(line_total, total_price, (quantity::numeric * unit_price))
where line_total is null;

create index if not exists idx_order_items_order_id
  on public.order_items(order_id);
create index if not exists idx_order_items_station_id
  on public.order_items(station_id);

create table if not exists public.print_jobs (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.stores(seller_id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  station_id uuid references public.stations(id) on delete set null,
  printer_id uuid references public.printers(id) on delete set null,
  job_type text not null check (job_type in ('new_order', 'add_item', 'cancel_item', 'reprint')),
  status text not null default 'pending' check (status in ('pending', 'claimed', 'printing', 'completed', 'failed')),
  payload jsonb not null default '{}'::jsonb,
  retry_count integer not null default 0 check (retry_count >= 0),
  last_error text,
  printed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.print_job_items (
  id uuid primary key default gen_random_uuid(),
  print_job_id uuid not null references public.print_jobs(id) on delete cascade,
  order_item_id uuid not null references public.order_items(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists idx_print_jobs_order_id
  on public.print_jobs(order_id);
create index if not exists idx_print_jobs_station_id
  on public.print_jobs(station_id);
create index if not exists idx_print_jobs_status
  on public.print_jobs(status);
create index if not exists idx_print_jobs_restaurant_id
  on public.print_jobs(restaurant_id);
create index if not exists idx_print_job_items_job_id
  on public.print_job_items(print_job_id);
create index if not exists idx_print_job_items_order_item_id
  on public.print_job_items(order_item_id);

-- ---------------------------------------------------------------------------
-- 2) RLS
-- ---------------------------------------------------------------------------

alter table public.stations enable row level security;
alter table public.printers enable row level security;
alter table public.station_printers enable row level security;
alter table public.print_jobs enable row level security;
alter table public.print_job_items enable row level security;

drop policy if exists "stations_owner_all" on public.stations;
create policy "stations_owner_all"
on public.stations
for all
to authenticated
using (auth.uid() = restaurant_id)
with check (auth.uid() = restaurant_id);

drop policy if exists "printers_owner_all" on public.printers;
create policy "printers_owner_all"
on public.printers
for all
to authenticated
using (auth.uid() = restaurant_id)
with check (auth.uid() = restaurant_id);

drop policy if exists "station_printers_owner_all" on public.station_printers;
create policy "station_printers_owner_all"
on public.station_printers
for all
to authenticated
using (
  exists (
    select 1
    from public.stations s
    where s.id = station_printers.station_id
      and s.restaurant_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.stations s
    where s.id = station_printers.station_id
      and s.restaurant_id = auth.uid()
  )
  and exists (
    select 1
    from public.printers p
    where p.id = station_printers.printer_id
      and p.restaurant_id = auth.uid()
  )
);

drop policy if exists "orders_restaurant_select" on public.orders;
create policy "orders_restaurant_select"
on public.orders
for select
to authenticated
using (auth.uid() = restaurant_id);

drop policy if exists "orders_restaurant_insert" on public.orders;
create policy "orders_restaurant_insert"
on public.orders
for insert
to authenticated
with check (
  auth.uid() = restaurant_id
  and auth.uid() = user_id
);

drop policy if exists "orders_restaurant_update" on public.orders;
create policy "orders_restaurant_update"
on public.orders
for update
to authenticated
using (auth.uid() = restaurant_id)
with check (auth.uid() = restaurant_id);

drop policy if exists "order_items_restaurant_select" on public.order_items;
create policy "order_items_restaurant_select"
on public.order_items
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.restaurant_id = auth.uid()
  )
);

drop policy if exists "order_items_restaurant_insert" on public.order_items;
create policy "order_items_restaurant_insert"
on public.order_items
for insert
to authenticated
with check (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.restaurant_id = auth.uid()
      and o.user_id = auth.uid()
  )
);

drop policy if exists "order_items_restaurant_update" on public.order_items;
create policy "order_items_restaurant_update"
on public.order_items
for update
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.restaurant_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.restaurant_id = auth.uid()
  )
);

drop policy if exists "print_jobs_owner_all" on public.print_jobs;
create policy "print_jobs_owner_all"
on public.print_jobs
for all
to authenticated
using (auth.uid() = restaurant_id)
with check (auth.uid() = restaurant_id);

drop policy if exists "print_job_items_owner_all" on public.print_job_items;
create policy "print_job_items_owner_all"
on public.print_job_items
for all
to authenticated
using (
  exists (
    select 1
    from public.print_jobs pj
    where pj.id = print_job_items.print_job_id
      and pj.restaurant_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.print_jobs pj
    where pj.id = print_job_items.print_job_id
      and pj.restaurant_id = auth.uid()
  )
);

-- ---------------------------------------------------------------------------
-- 3) Helper functions
-- ---------------------------------------------------------------------------

create or replace function public.try_uuid(p_raw text)
returns uuid
language plpgsql
immutable
as $$
declare
  v_value text;
begin
  v_value := nullif(trim(coalesce(p_raw, '')), '');
  if v_value is null then
    return null;
  end if;
  return v_value::uuid;
exception when others then
  return null;
end;
$$;

create or replace function public.parse_price_numeric(p_raw text)
returns numeric
language plpgsql
immutable
as $$
declare
  v text;
begin
  v := regexp_replace(coalesce(trim(p_raw), ''), '[^0-9,.-]', '', 'g');
  if v = '' then
    return 0;
  end if;

  if strpos(v, ',') > 0 and strpos(v, '.') > 0 then
    -- If comma appears after dot, comma is decimal separator.
    if strpos(reverse(v), ',') < strpos(reverse(v), '.') then
      v := replace(v, '.', '');
      v := replace(v, ',', '.');
    else
      v := replace(v, ',', '');
    end if;
  elsif strpos(v, ',') > 0 then
    v := replace(v, '.', '');
    v := replace(v, ',', '.');
  end if;

  return coalesce(v::numeric, 0);
exception when others then
  return 0;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Transactional order + item + print job pipeline
-- ---------------------------------------------------------------------------

create or replace function public.create_table_order_with_print_jobs(
  p_restaurant_id uuid,
  p_table_number integer,
  p_items jsonb,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_notes text default null,
  p_job_type text default 'new_order',
  p_order_type text default 'table'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id uuid;
  v_order_number text;
  v_table_id uuid;
  v_restaurant_name text;
  v_table_name text;
  v_waiter_name text;
  v_waiter_ref uuid;

  v_item jsonb;
  v_item_qty integer;
  v_item_unit_price numeric(12,2);
  v_item_line_total numeric(12,2);
  v_item_note text;
  v_item_name text;
  v_item_product_id text;
  v_item_station_id uuid;
  v_item_routing_enabled boolean;
  v_item_inserted_id uuid;

  v_product record;

  v_group record;
  v_printer_id uuid;
  v_printer_name text;
  v_printer_code text;
  v_printer_connection_type text;
  v_printer_ip_address text;
  v_printer_port integer;
  v_printer_device_identifier text;
  v_printer_paper_width_mm integer;
  v_items_payload jsonb;
  v_job_payload jsonb;
  v_print_job_id uuid;

  v_subtotal numeric(12,2) := 0;
  v_print_job_count integer := 0;
  v_print_job_ids jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  if auth.uid() <> p_restaurant_id then
    -- Allow active waiter/sub-admin accounts for this restaurant.
    if not exists (
      select 1
      from public.store_sub_admins sa
      join public.users u
        on lower(trim(u.email)) = lower(trim(sa.email))
      where sa.store_id = p_restaurant_id
        and u.id         = auth.uid()
        and sa.status    = 'active'
    ) then
      raise exception 'Bu restoran için işlem yetkiniz yok.' using errcode = '42501';
    end if;
  end if;

  if p_items is null
    or jsonb_typeof(p_items) <> 'array'
    or jsonb_array_length(p_items) = 0 then
    raise exception 'Sipariş kalemleri boş olamaz.' using errcode = '22023';
  end if;

  if p_job_type not in ('new_order', 'add_item', 'cancel_item', 'reprint') then
    raise exception 'Geçersiz job_type: %', p_job_type using errcode = '22023';
  end if;

  select business_name
  into v_restaurant_name
  from public.stores
  where seller_id = p_restaurant_id
  limit 1;

  if v_restaurant_name is null then
    raise exception 'Restoran bulunamadı.' using errcode = '22023';
  end if;

  select id
  into v_table_id
  from public.store_tables
  where seller_id = p_restaurant_id
    and table_number = p_table_number
    and is_active = true
  order by created_at desc
  limit 1;

  v_table_name := format('Masa %s', p_table_number);
  v_waiter_name := coalesce(nullif(trim(coalesce(p_waiter_name, '')), ''), 'Garson');
  v_waiter_ref := null;
  select u.id into v_waiter_ref
  from public.users u
  where u.id = coalesce(p_waiter_id, auth.uid())
  limit 1;

  v_order_number := format(
    'TBL-%s-%s',
    to_char(now(), 'YYYYMMDDHH24MISS'),
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6))
  );

  insert into public.orders (
    user_id,
    order_number,
    status,
    payment_method,
    delivery_type,
    subtotal_amount,
    shipping_amount,
    discount_amount,
    total_amount,
    currency,
    restaurant_id,
    table_id,
    waiter_id,
    order_status,
    order_type,
    notes
  )
  values (
    auth.uid(),
    v_order_number,
    'confirmed',
    'cash',
    'table',
    0,
    0,
    0,
    0,
    'TRY',
    p_restaurant_id,
    v_table_id,
    v_waiter_ref,
    'sent',
    coalesce(nullif(trim(coalesce(p_order_type, '')), ''), 'table'),
    nullif(trim(coalesce(p_notes, '')), '')
  )
  returning id into v_order_id;

  for v_item in
    select value from jsonb_array_elements(p_items)
  loop
    v_item_product_id := nullif(trim(coalesce(v_item.value ->> 'product_id', '')), '');
    v_item_name := coalesce(nullif(trim(coalesce(v_item.value ->> 'name', '')), ''), 'Ürün');
    v_item_note := nullif(trim(coalesce(v_item.value ->> 'notes', '')), '');

    v_item_qty := greatest(
      coalesce(nullif(regexp_replace(coalesce(v_item.value ->> 'quantity', '1'), '[^0-9]', '', 'g'), '')::integer, 1),
      1
    );

    if (v_item.value ? 'price') and jsonb_typeof(v_item.value -> 'price') = 'number' then
      v_item_unit_price := coalesce((v_item.value ->> 'price')::numeric, 0);
    else
      v_item_unit_price := public.parse_price_numeric(v_item.value ->> 'price');
    end if;

    select
      p.id::text as product_id_text,
      p.name,
      p.station_id,
      coalesce(p.printer_routing_enabled, true) as routing_enabled,
      coalesce(p.discount_price, p.price, 0)::numeric as fallback_price
    into v_product
    from public.products p
    where p.seller_id = p_restaurant_id
      and (
        (v_item_product_id is not null and p.id::text = v_item_product_id)
        or (v_item_product_id is null and lower(p.name) = lower(v_item_name))
      )
    limit 1;

    if found then
      v_item_product_id := coalesce(v_item_product_id, v_product.product_id_text);
      v_item_name := coalesce(nullif(v_item_name, 'Ürün'), v_product.name, v_item_name);
      v_item_station_id := coalesce(
        public.try_uuid(v_item.value ->> 'station_id'),
        v_product.station_id
      );
      v_item_routing_enabled := v_product.routing_enabled;
      if v_item_unit_price <= 0 then
        v_item_unit_price := coalesce(v_product.fallback_price, 0);
      end if;
    else
      v_item_station_id := public.try_uuid(v_item.value ->> 'station_id');
      v_item_routing_enabled := true;
    end if;

    v_item_line_total := round((v_item_qty::numeric * coalesce(v_item_unit_price, 0))::numeric, 2);
    v_subtotal := v_subtotal + v_item_line_total;

    insert into public.order_items (
      order_id,
      seller_id,
      product_id,
      product_name,
      quantity,
      unit_price,
      total_price,
      line_total,
      status,
      station_id,
      item_note,
      kitchen_status,
      sent_to_kitchen_at
    )
    values (
      v_order_id,
      p_restaurant_id,
      v_item_product_id,
      v_item_name,
      v_item_qty,
      coalesce(v_item_unit_price, 0),
      v_item_line_total,
      v_item_line_total,
      'new',
      v_item_station_id,
      v_item_note,
      case when v_item_routing_enabled then 'pending' else 'skipped' end,
      null
    )
    returning id into v_item_inserted_id;
  end loop;

  update public.orders
  set subtotal_amount = v_subtotal,
      total_amount = v_subtotal,
      order_status = 'sent'
  where id = v_order_id;

  for v_group in
    select
      oi.station_id,
      coalesce(s.name, 'Genel') as station_name,
      coalesce(s.code, 'GENEL') as station_code
    from public.order_items oi
    left join public.products p
      on p.id::text = oi.product_id
      and p.seller_id = p_restaurant_id
    left join public.stations s
      on s.id = oi.station_id
    where oi.order_id = v_order_id
      and coalesce(p.printer_routing_enabled, true)
    group by oi.station_id, s.name, s.code
  loop
    if v_group.station_id is not null then
      select
        sp.printer_id,
        pr.name as printer_name,
        pr.code as printer_code,
        pr.connection_type,
        pr.ip_address,
        pr.port,
        pr.device_identifier,
        pr.paper_width_mm
      into
        v_printer_id,
        v_printer_name,
        v_printer_code,
        v_printer_connection_type,
        v_printer_ip_address,
        v_printer_port,
        v_printer_device_identifier,
        v_printer_paper_width_mm
      from public.station_printers sp
      join public.printers pr
        on pr.id = sp.printer_id
       and pr.is_active = true
      where sp.station_id = v_group.station_id
      order by sp.is_primary desc, sp.created_at asc
      limit 1;
    else
      v_printer_id := null;
      v_printer_name := null;
      v_printer_code := null;
      v_printer_connection_type := null;
      v_printer_ip_address := null;
      v_printer_port := null;
      v_printer_device_identifier := null;
      v_printer_paper_width_mm := null;
      -- Skip the null-station "Genel" print job when the order has at least
      -- one item assigned to a named station.  Every routed item already goes
      -- to its own station ticket; a duplicate Genel ticket would only add
      -- noise.  When NO items have a station (station-free restaurants) the
      -- check evaluates to false and the single Genel ticket is kept.
      if exists (
        select 1
        from public.order_items oi2
        where oi2.order_id = v_order_id
          and oi2.station_id is not null
      ) then
        continue;
      end if;
    end if;

    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'order_item_id', oi.id,
          'product_name', oi.product_name,
          'quantity', oi.quantity,
          'item_note', oi.item_note,
          'unit_price', oi.unit_price,
          -- Persist structured display data from the incoming p_items payload
          -- so that reprints (which have no sourceItems) can still render
          -- plates, service_children and gramaj correctly.
          'amount_label', coalesce((
            select elem ->> 'amount_label'
            from jsonb_array_elements(p_items) elem
            where (elem ->> 'product_id') = oi.product_id::text
               or lower(elem ->> 'name') = lower(oi.product_name)
            limit 1
          ), ''),
          'plates', coalesce((
            select elem -> 'plates'
            from jsonb_array_elements(p_items) elem
            where (elem ->> 'product_id') = oi.product_id::text
               or lower(elem ->> 'name') = lower(oi.product_name)
            limit 1
          ), '[]'::jsonb),
          'service_children', coalesce((
            select elem -> 'service_children'
            from jsonb_array_elements(p_items) elem
            where (elem ->> 'product_id') = oi.product_id::text
               or lower(elem ->> 'name') = lower(oi.product_name)
            limit 1
          ), '[]'::jsonb)
        )
        order by oi.created_at asc
      ),
      '[]'::jsonb
    )
    into v_items_payload
    from public.order_items oi
    left join public.products p
      on p.id::text = oi.product_id
      and p.seller_id = p_restaurant_id
    where oi.order_id = v_order_id
      and oi.station_id is not distinct from v_group.station_id
      and coalesce(p.printer_routing_enabled, true);

    if jsonb_array_length(v_items_payload) = 0 then
      continue;
    end if;

    v_job_payload := jsonb_build_object(
      'restaurant_id', p_restaurant_id,
      'restaurant_name', v_restaurant_name,
      'order_id', v_order_id,
      'order_no', v_order_number,
      'table_name', v_table_name,
      'waiter_name', v_waiter_name,
      'station_id', v_group.station_id,
      'station_name', v_group.station_name,
      'station_code', v_group.station_code,
      'printer_id', v_printer_id,
      'printer_name', v_printer_name,
      'printer_code', v_printer_code,
      'printer_connection_type', v_printer_connection_type,
      'printer_ip_address', v_printer_ip_address,
      'printer_port', v_printer_port,
      'printer_device_identifier', v_printer_device_identifier,
      'paper_width_mm', v_printer_paper_width_mm,
      'job_type', p_job_type,
      'created_at', now(),
      'items', v_items_payload
    );

    insert into public.print_jobs (
      restaurant_id,
      order_id,
      station_id,
      printer_id,
      job_type,
      status,
      payload
    )
    values (
      p_restaurant_id,
      v_order_id,
      v_group.station_id,
      v_printer_id,
      p_job_type,
      'pending',
      v_job_payload
    )
    returning id into v_print_job_id;

    insert into public.print_job_items (print_job_id, order_item_id)
    select v_print_job_id, oi.id
    from public.order_items oi
    left join public.products p
      on p.id::text = oi.product_id
      and p.seller_id = p_restaurant_id
    where oi.order_id = v_order_id
      and oi.station_id is not distinct from v_group.station_id
      and coalesce(p.printer_routing_enabled, true);

    update public.order_items
    set sent_to_kitchen_at = coalesce(sent_to_kitchen_at, now()),
        kitchen_status = 'queued'
    where id in (
      select pji.order_item_id
      from public.print_job_items pji
      where pji.print_job_id = v_print_job_id
    );

    v_print_job_count := v_print_job_count + 1;
    v_print_job_ids := v_print_job_ids || to_jsonb(v_print_job_id);
  end loop;

  return jsonb_build_object(
    'status', 'ok',
    'restaurant_id', p_restaurant_id,
    'order_id', v_order_id,
    'order_number', v_order_number,
    'table_number', p_table_number,
    'print_job_count', v_print_job_count,
    'print_job_ids', v_print_job_ids
  );
end;
$$;

grant execute on function public.create_table_order_with_print_jobs(
  uuid,
  integer,
  jsonb,
  uuid,
  text,
  text,
  text,
  text
) to authenticated;

comment on function public.create_table_order_with_print_jobs(
  uuid,
  integer,
  jsonb,
  uuid,
  text,
  text,
  text,
  text
)
is 'Creates order/order_items and station-based print_jobs transactionally. TODO: Edge Function or webhook worker can consume pending print_jobs and forward to local print agents.';
