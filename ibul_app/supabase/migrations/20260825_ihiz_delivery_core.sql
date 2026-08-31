-- IHIZ delivery operating system core.
-- Does not alter order_items.tracking_number, print tables, or return pickup tasks.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Helpers (security definer, no policy recursion into orders/order_items)
-- ---------------------------------------------------------------------------

create or replace function public.ihiz_actor_is_admin(target_user_id uuid default auth.uid())
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
      and (
        lower(coalesce(u.role, '')) in ('admin', 'super_admin', 'owner')
        or coalesce(u.role, '') like 'admin_%'
      )
  );
$$;

create or replace function public.ihiz_actor_is_approved_courier(target_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.ihiz_courier_applications app
    where app.user_id = target_user_id
      and lower(coalesce(app.status, '')) = 'approved'
  );
$$;

create or replace function public.ihiz_actor_owns_store(
  p_store_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.stores s
    where s.seller_id = p_store_id
      and s.seller_id = target_user_id
  );
$$;

create or replace function public.ihiz_normalize_tracking_code(p_code text)
returns text
language sql
immutable
as $$
  select upper(trim(both from coalesce(p_code, '')));
$$;

create or replace function public.ihiz_generate_tracking_code()
returns text
language plpgsql
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  bytes bytea;
  code text;
  i int;
  idx int;
begin
  loop
    bytes := gen_random_bytes(6);
    code := 'IHZ-';
    for i in 0..5 loop
      idx := get_byte(bytes, i) % length(alphabet);
      code := code || substr(alphabet, idx + 1, 1);
    end loop;
    exit when not exists (
      select 1 from public.ihiz_delivery_tasks t where t.tracking_code = code
    );
  end loop;
  return code;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.ihiz_business_accounts (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.users(id) on delete cascade,
  store_id uuid not null references public.stores(seller_id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'active', 'suspended')),
  business_name text,
  contact_name text,
  contact_phone text,
  contact_email text,
  has_own_couriers boolean not null default false,
  courier_count integer,
  delivery_region text,
  notes text,
  activated_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (seller_id),
  unique (store_id)
);

create table if not exists public.ihiz_store_couriers (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(seller_id) on delete cascade,
  courier_user_id uuid not null references public.users(id) on delete cascade,
  is_active boolean not null default true,
  is_selected boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (store_id, courier_user_id)
);

create table if not exists public.ihiz_delivery_tasks (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.orders(id) on delete set null,
  seller_id uuid references public.users(id) on delete set null,
  store_id uuid references public.stores(seller_id) on delete set null,
  created_by_user_id uuid references public.users(id) on delete set null,
  source_type text not null default 'package_send'
    check (source_type in ('ibul_order', 'package_send')),
  tracking_code text not null unique,
  status text not null default 'created'
    check (status in (
      'created',
      'preparing',
      'ready_for_pickup',
      'courier_assigned',
      'courier_picked_up',
      'in_transit',
      'delivered',
      'cancelled'
    )),
  pickup_name text,
  pickup_phone text,
  pickup_address text,
  pickup_city text,
  pickup_district text,
  pickup_lat double precision,
  pickup_lng double precision,
  dropoff_name text,
  dropoff_phone text,
  dropoff_address text,
  dropoff_city text,
  dropoff_district text,
  dropoff_lat double precision,
  dropoff_lng double precision,
  package_size text,
  package_weight numeric,
  notes text,
  assigned_courier_id uuid references public.users(id) on delete set null,
  courier_lat double precision,
  courier_lng double precision,
  courier_location_updated_at timestamptz,
  package_media_url text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  picked_up_at timestamptz,
  delivered_at timestamptz,
  cancelled_at timestamptz
);

create unique index if not exists uq_ihiz_delivery_tasks_order_id
  on public.ihiz_delivery_tasks (order_id)
  where order_id is not null;

create index if not exists idx_ihiz_delivery_tasks_status
  on public.ihiz_delivery_tasks (status, created_at desc);
create index if not exists idx_ihiz_delivery_tasks_store
  on public.ihiz_delivery_tasks (store_id, status);
create index if not exists idx_ihiz_delivery_tasks_courier
  on public.ihiz_delivery_tasks (assigned_courier_id, status);

create table if not exists public.ihiz_delivery_events (
  id uuid primary key default gen_random_uuid(),
  delivery_task_id uuid not null references public.ihiz_delivery_tasks(id) on delete cascade,
  event_type text not null,
  status text,
  title text,
  description text,
  actor_type text,
  actor_user_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_ihiz_delivery_events_task
  on public.ihiz_delivery_events (delivery_task_id, created_at);

create table if not exists public.ihiz_tracking_lookup_log (
  id bigint generated by default as identity primary key,
  tracking_code_hash text not null,
  client_addr inet,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_ihiz_tracking_lookup_log_addr
  on public.ihiz_tracking_lookup_log (client_addr, created_at desc);

create or replace function public.ihiz_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_ihiz_business_accounts_updated_at on public.ihiz_business_accounts;
create trigger trg_ihiz_business_accounts_updated_at
before update on public.ihiz_business_accounts
for each row execute function public.ihiz_set_updated_at();

drop trigger if exists trg_ihiz_store_couriers_updated_at on public.ihiz_store_couriers;
create trigger trg_ihiz_store_couriers_updated_at
before update on public.ihiz_store_couriers
for each row execute function public.ihiz_set_updated_at();

drop trigger if exists trg_ihiz_delivery_tasks_updated_at on public.ihiz_delivery_tasks;
create trigger trg_ihiz_delivery_tasks_updated_at
before update on public.ihiz_delivery_tasks
for each row execute function public.ihiz_set_updated_at();

create or replace function public.ihiz_delivery_task_can_access(
  p_task public.ihiz_delivery_tasks,
  target_user_id uuid default auth.uid()
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if target_user_id is null then
    return false;
  end if;
  if public.ihiz_actor_is_admin(target_user_id) then
    return true;
  end if;
  if p_task.seller_id = target_user_id or p_task.created_by_user_id = target_user_id then
    return true;
  end if;
  if p_task.assigned_courier_id = target_user_id then
    return true;
  end if;
  if p_task.store_id is not null and public.ihiz_actor_owns_store(p_task.store_id, target_user_id) then
    return true;
  end if;
  if public.ihiz_actor_is_approved_courier(target_user_id)
     and p_task.status in ('created', 'preparing', 'ready_for_pickup')
     and p_task.assigned_courier_id is null then
    if p_task.store_id is null then
      return true;
    end if;
    if exists (
      select 1
      from public.ihiz_store_couriers sc
      where sc.store_id = p_task.store_id
        and sc.is_selected = true
        and sc.is_active = true
    ) then
      return exists (
        select 1
        from public.ihiz_store_couriers sc
        where sc.store_id = p_task.store_id
          and sc.courier_user_id = target_user_id
          and sc.is_selected = true
          and sc.is_active = true
      );
    end if;
    return true;
  end if;
  return false;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.ihiz_business_accounts enable row level security;
alter table public.ihiz_store_couriers enable row level security;
alter table public.ihiz_delivery_tasks enable row level security;
alter table public.ihiz_delivery_events enable row level security;
alter table public.ihiz_tracking_lookup_log enable row level security;

drop policy if exists ihiz_business_accounts_select on public.ihiz_business_accounts;
create policy ihiz_business_accounts_select
on public.ihiz_business_accounts
for select
to authenticated
using (
  seller_id = auth.uid()
  or public.ihiz_actor_is_admin(auth.uid())
);

drop policy if exists ihiz_business_accounts_insert on public.ihiz_business_accounts;
create policy ihiz_business_accounts_insert
on public.ihiz_business_accounts
for insert
to authenticated
with check (
  seller_id = auth.uid()
  and public.ihiz_actor_owns_store(store_id, auth.uid())
);

drop policy if exists ihiz_business_accounts_update on public.ihiz_business_accounts;
create policy ihiz_business_accounts_update
on public.ihiz_business_accounts
for update
to authenticated
using (
  seller_id = auth.uid()
  or public.ihiz_actor_is_admin(auth.uid())
)
with check (
  seller_id = auth.uid()
  or public.ihiz_actor_is_admin(auth.uid())
);

drop policy if exists ihiz_store_couriers_select on public.ihiz_store_couriers;
create policy ihiz_store_couriers_select
on public.ihiz_store_couriers
for select
to authenticated
using (
  courier_user_id = auth.uid()
  or public.ihiz_actor_owns_store(store_id, auth.uid())
  or public.ihiz_actor_is_admin(auth.uid())
);

drop policy if exists ihiz_store_couriers_write on public.ihiz_store_couriers;
create policy ihiz_store_couriers_write
on public.ihiz_store_couriers
for all
to authenticated
using (
  public.ihiz_actor_owns_store(store_id, auth.uid())
  or public.ihiz_actor_is_admin(auth.uid())
)
with check (
  public.ihiz_actor_owns_store(store_id, auth.uid())
  or public.ihiz_actor_is_admin(auth.uid())
);

drop policy if exists ihiz_delivery_tasks_select on public.ihiz_delivery_tasks;
create policy ihiz_delivery_tasks_select
on public.ihiz_delivery_tasks
for select
to authenticated
using (public.ihiz_delivery_task_can_access(ihiz_delivery_tasks, auth.uid()));

drop policy if exists ihiz_delivery_tasks_insert on public.ihiz_delivery_tasks;
create policy ihiz_delivery_tasks_insert
on public.ihiz_delivery_tasks
for insert
to authenticated
with check (
  created_by_user_id = auth.uid()
  or seller_id = auth.uid()
  or public.ihiz_actor_is_admin(auth.uid())
);

drop policy if exists ihiz_delivery_tasks_update on public.ihiz_delivery_tasks;
create policy ihiz_delivery_tasks_update
on public.ihiz_delivery_tasks
for update
to authenticated
using (public.ihiz_delivery_task_can_access(ihiz_delivery_tasks, auth.uid()))
with check (public.ihiz_delivery_task_can_access(ihiz_delivery_tasks, auth.uid()));

drop policy if exists ihiz_delivery_events_select on public.ihiz_delivery_events;
create policy ihiz_delivery_events_select
on public.ihiz_delivery_events
for select
to authenticated
using (
  exists (
    select 1
    from public.ihiz_delivery_tasks t
    where t.id = ihiz_delivery_events.delivery_task_id
      and public.ihiz_delivery_task_can_access(t, auth.uid())
  )
);

drop policy if exists ihiz_delivery_events_insert on public.ihiz_delivery_events;
create policy ihiz_delivery_events_insert
on public.ihiz_delivery_events
for insert
to authenticated
with check (
  exists (
    select 1
    from public.ihiz_delivery_tasks t
    where t.id = ihiz_delivery_events.delivery_task_id
      and public.ihiz_delivery_task_can_access(t, auth.uid())
  )
);

-- No direct SELECT for anon/authenticated on lookup log.
drop policy if exists ihiz_tracking_lookup_log_admin on public.ihiz_tracking_lookup_log;
create policy ihiz_tracking_lookup_log_admin
on public.ihiz_tracking_lookup_log
for select
to authenticated
using (public.ihiz_actor_is_admin(auth.uid()));

grant select, insert, update on public.ihiz_business_accounts to authenticated;
grant select, insert, update, delete on public.ihiz_store_couriers to authenticated;
grant select, insert, update on public.ihiz_delivery_tasks to authenticated;
grant select, insert on public.ihiz_delivery_events to authenticated;

-- ---------------------------------------------------------------------------
-- Event helper
-- ---------------------------------------------------------------------------

create or replace function public.ihiz_append_delivery_event(
  p_task_id uuid,
  p_event_type text,
  p_status text,
  p_title text,
  p_description text default null,
  p_actor_type text default null,
  p_actor_user_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.ihiz_delivery_events (
    delivery_task_id, event_type, status, title, description, actor_type, actor_user_id, metadata
  ) values (
    p_task_id, p_event_type, p_status, p_title, p_description, p_actor_type, p_actor_user_id, coalesce(p_metadata, '{}'::jsonb)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Public tracking RPC (projection only)
-- ---------------------------------------------------------------------------

create or replace function public.get_ihiz_public_tracking(p_tracking_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := public.ihiz_normalize_tracking_code(p_tracking_code);
  v_hash text;
  v_addr inet := inet_client_addr();
  v_recent int := 0;
  v_task public.ihiz_delivery_tasks%rowtype;
  v_live boolean := false;
  v_events jsonb := '[]'::jsonb;
  v_store_name text;
begin
  if v_code is null or v_code = '' or v_code !~ '^IHZ-[A-Z0-9]{6}$' then
    return jsonb_build_object('found', false, 'error', 'not_found');
  end if;

  v_hash := encode(digest(v_code, 'sha256'), 'hex');
  insert into public.ihiz_tracking_lookup_log (tracking_code_hash, client_addr)
  values (v_hash, v_addr);

  select count(*)::int
  into v_recent
  from public.ihiz_tracking_lookup_log
  where created_at > timezone('utc', now()) - interval '10 minutes'
    and (
      (v_addr is not null and client_addr = v_addr)
      or (v_addr is null and client_addr is null and tracking_code_hash = v_hash)
    );

  if v_recent > 40 then
    return jsonb_build_object('found', false, 'error', 'rate_limited');
  end if;

  select *
  into v_task
  from public.ihiz_delivery_tasks
  where tracking_code = v_code
  limit 1;

  if not found then
    return jsonb_build_object('found', false, 'error', 'not_found');
  end if;

  v_live := v_task.status in ('courier_picked_up', 'in_transit');

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'event_type', e.event_type,
        'status', e.status,
        'title', e.title,
        'description', e.description,
        'created_at', e.created_at
      )
      order by e.created_at
    ),
    '[]'::jsonb
  )
  into v_events
  from public.ihiz_delivery_events e
  where e.delivery_task_id = v_task.id;

  if v_task.store_id is not null then
    select s.business_name
    into v_store_name
    from public.stores s
    where s.seller_id = v_task.store_id
    limit 1;
  end if;

  return jsonb_build_object(
    'found', true,
    'tracking_code', v_task.tracking_code,
    'status', v_task.status,
    'source_type', v_task.source_type,
    'created_at', v_task.created_at,
    'picked_up_at', v_task.picked_up_at,
    'delivered_at', v_task.delivered_at,
    'cancelled_at', v_task.cancelled_at,
    'package_size', v_task.package_size,
    'package_weight', v_task.package_weight,
    'notes', case
      when v_task.notes is null then null
      when length(v_task.notes) > 180 then left(v_task.notes, 180)
      else v_task.notes
    end,
    'package_media_url', v_task.package_media_url,
    'sender_name', coalesce(nullif(v_store_name, ''), v_task.pickup_name),
    'pickup_label', nullif(trim(both from concat_ws(' / ', v_task.pickup_city, v_task.pickup_district)), ''),
    'dropoff_label', nullif(trim(both from concat_ws(' / ', v_task.dropoff_city, v_task.dropoff_district)), ''),
    'live', case
      when v_live then jsonb_build_object(
        'courier_lat', v_task.courier_lat,
        'courier_lng', v_task.courier_lng,
        'courier_location_updated_at', v_task.courier_location_updated_at,
        'pickup_lat', v_task.pickup_lat,
        'pickup_lng', v_task.pickup_lng,
        'dropoff_lat', v_task.dropoff_lat,
        'dropoff_lng', v_task.dropoff_lng
      )
      else null
    end,
    'events', v_events
  );
end;
$$;

revoke all on function public.get_ihiz_public_tracking(text) from public;
grant execute on function public.get_ihiz_public_tracking(text) to anon, authenticated;

grant execute on function public.ihiz_actor_is_admin(uuid) to authenticated;
grant execute on function public.ihiz_actor_is_approved_courier(uuid) to authenticated;
grant execute on function public.ihiz_actor_owns_store(uuid, uuid) to authenticated;
grant execute on function public.ihiz_normalize_tracking_code(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Create / claim / location RPCs
-- ---------------------------------------------------------------------------

create or replace function public.create_ihiz_package_delivery(
  p_pickup_name text,
  p_pickup_phone text,
  p_pickup_address text,
  p_pickup_city text,
  p_pickup_district text,
  p_pickup_lat double precision,
  p_pickup_lng double precision,
  p_dropoff_name text,
  p_dropoff_phone text,
  p_dropoff_address text,
  p_dropoff_city text,
  p_dropoff_district text,
  p_dropoff_lat double precision,
  p_dropoff_lng double precision,
  p_package_size text,
  p_package_weight numeric,
  p_notes text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_task public.ihiz_delivery_tasks%rowtype;
begin
  if v_uid is null then
    raise exception 'auth_required';
  end if;
  if coalesce(trim(p_pickup_address), '') = '' or coalesce(trim(p_dropoff_address), '') = '' then
    raise exception 'addresses_required';
  end if;

  insert into public.ihiz_delivery_tasks (
    created_by_user_id,
    source_type,
    tracking_code,
    status,
    pickup_name,
    pickup_phone,
    pickup_address,
    pickup_city,
    pickup_district,
    pickup_lat,
    pickup_lng,
    dropoff_name,
    dropoff_phone,
    dropoff_address,
    dropoff_city,
    dropoff_district,
    dropoff_lat,
    dropoff_lng,
    package_size,
    package_weight,
    notes
  ) values (
    v_uid,
    'package_send',
    public.ihiz_generate_tracking_code(),
    'ready_for_pickup',
    nullif(trim(p_pickup_name), ''),
    nullif(trim(p_pickup_phone), ''),
    nullif(trim(p_pickup_address), ''),
    nullif(trim(p_pickup_city), ''),
    nullif(trim(p_pickup_district), ''),
    p_pickup_lat,
    p_pickup_lng,
    nullif(trim(p_dropoff_name), ''),
    nullif(trim(p_dropoff_phone), ''),
    nullif(trim(p_dropoff_address), ''),
    nullif(trim(p_dropoff_city), ''),
    nullif(trim(p_dropoff_district), ''),
    p_dropoff_lat,
    p_dropoff_lng,
    nullif(trim(p_package_size), ''),
    p_package_weight,
    nullif(trim(p_notes), '')
  )
  returning * into v_task;

  perform public.ihiz_append_delivery_event(
    v_task.id,
    'created',
    'created',
    'Paket talebi oluşturuldu',
    'Evden teslim alma talebi İHIZ havuzuna düştü.',
    'customer',
    v_uid,
    '{}'::jsonb
  );
  perform public.ihiz_append_delivery_event(
    v_task.id,
    'ready_for_pickup',
    'ready_for_pickup',
    'Kurye bekleniyor',
    'Paket kurye havuzuna alındı.',
    'system',
    v_uid,
    '{}'::jsonb
  );

  return jsonb_build_object(
    'ok', true,
    'id', v_task.id,
    'tracking_code', v_task.tracking_code,
    'status', v_task.status
  );
end;
$$;

revoke all on function public.create_ihiz_package_delivery(
  text, text, text, text, text, double precision, double precision,
  text, text, text, text, text, double precision, double precision,
  text, numeric, text
) from public;
grant execute on function public.create_ihiz_package_delivery(
  text, text, text, text, text, double precision, double precision,
  text, text, text, text, text, double precision, double precision,
  text, numeric, text
) to authenticated;

create or replace function public.ensure_ihiz_delivery_task_for_order(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_order public.orders%rowtype;
  v_item record;
  v_store record;
  v_account public.ihiz_business_accounts%rowtype;
  v_task public.ihiz_delivery_tasks%rowtype;
  v_status text := 'created';
  v_addr jsonb;
  v_delivery_type text;
  v_media text;
begin
  if v_uid is null then
    raise exception 'auth_required';
  end if;
  if p_order_id is null then
    return jsonb_build_object('ok', false, 'error', 'missing_order');
  end if;

  select * into v_order from public.orders where id = p_order_id limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'order_not_found');
  end if;

  v_delivery_type := lower(coalesce(v_order.delivery_type, ''));
  if position('ihiz' in v_delivery_type) = 0 and position('kurye' in v_delivery_type) = 0 then
    return jsonb_build_object('ok', false, 'error', 'not_ihiz_delivery');
  end if;

  select *
  into v_item
  from public.order_items
  where order_id = p_order_id
  order by created_at
  limit 1;

  if v_item.seller_id is null then
    return jsonb_build_object('ok', false, 'error', 'missing_seller');
  end if;

  if v_order.user_id is distinct from v_uid
     and v_item.seller_id is distinct from v_uid
     and not public.ihiz_actor_is_admin(v_uid) then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;

  select * into v_account
  from public.ihiz_business_accounts
  where seller_id = v_item.seller_id
    and status = 'active'
  limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'business_inactive');
  end if;

  select * into v_store
  from public.stores
  where seller_id = v_item.seller_id
  limit 1;

  v_addr := coalesce(v_order.delivery_address, '{}'::jsonb);

  if lower(coalesce(v_item.status, '')) in ('ready_to_ship') then
    v_status := 'ready_for_pickup';
  elsif lower(coalesce(v_item.status, '')) = 'preparing' then
    v_status := 'preparing';
  elsif lower(coalesce(v_item.status, '')) = 'out_for_delivery' then
    v_status := 'courier_picked_up';
  elsif lower(coalesce(v_item.status, '')) = 'delivered' then
    v_status := 'delivered';
  elsif lower(coalesce(v_item.status, '')) in ('cancelled', 'canceled') then
    v_status := 'cancelled';
  end if;

  select split_part(replace(h.description, 'VIDEO::', ''), '|', 1)
  into v_media
  from public.order_item_status_history h
  where h.order_item_id = v_item.id
    and h.description like 'VIDEO::http%'
  order by h.created_at desc
  limit 1;

  insert into public.ihiz_delivery_tasks (
    order_id,
    seller_id,
    store_id,
    created_by_user_id,
    source_type,
    tracking_code,
    status,
    pickup_name,
    pickup_phone,
    pickup_address,
    pickup_city,
    pickup_district,
    pickup_lat,
    pickup_lng,
    dropoff_name,
    dropoff_phone,
    dropoff_address,
    dropoff_city,
    dropoff_district,
    dropoff_lat,
    dropoff_lng,
    notes,
    package_media_url
  ) values (
    p_order_id,
    v_item.seller_id,
    v_item.seller_id,
    v_uid,
    'ibul_order',
    public.ihiz_generate_tracking_code(),
    v_status,
    v_store.business_name,
    coalesce(v_store.support_phone, v_store.phone),
    v_store.address,
    v_store.city,
    v_store.district,
    v_store.store_lat,
    v_store.store_lng,
    coalesce(v_addr->>'fullName', v_addr->>'name'),
    coalesce(v_addr->>'phone', v_addr->>'phoneNumber'),
    coalesce(v_addr->>'address', v_addr->>'detail'),
    v_addr->>'city',
    v_addr->>'district',
    case
      when coalesce(v_addr->>'lat', v_addr->>'latitude', '') ~ '^-?[0-9]+(\\.[0-9]+)?$'
      then coalesce(v_addr->>'lat', v_addr->>'latitude')::double precision
      else null
    end,
    case
      when coalesce(v_addr->>'lng', v_addr->>'longitude', '') ~ '^-?[0-9]+(\\.[0-9]+)?$'
      then coalesce(v_addr->>'lng', v_addr->>'longitude')::double precision
      else null
    end,
    v_addr->>'note',
    nullif(trim(v_media), '')
  )
  on conflict (order_id) where order_id is not null
  do update set
    status = case
      when public.ihiz_delivery_tasks.status in ('delivered', 'cancelled') then public.ihiz_delivery_tasks.status
      else excluded.status
    end,
    package_media_url = coalesce(
      public.ihiz_delivery_tasks.package_media_url,
      excluded.package_media_url
    ),
    updated_at = timezone('utc', now())
  returning * into v_task;

  if not exists (
    select 1
    from public.ihiz_delivery_events e
    where e.delivery_task_id = v_task.id
      and e.event_type = 'created'
  ) then
    perform public.ihiz_append_delivery_event(
      v_task.id,
      'created',
      'created',
      'Sipariş İHIZ teslimatına alındı',
      'İBUL siparişi için teslimat görevi oluşturuldu.',
      'seller',
      v_uid,
      jsonb_build_object('order_number', v_order.order_number)
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', v_task.id,
    'tracking_code', v_task.tracking_code,
    'status', v_task.status,
    'duplicate', false
  );
exception
  when unique_violation then
    select * into v_task
    from public.ihiz_delivery_tasks
    where order_id = p_order_id
    limit 1;
    return jsonb_build_object(
      'ok', true,
      'id', v_task.id,
      'tracking_code', v_task.tracking_code,
      'status', v_task.status,
      'duplicate', true
    );
end;
$$;

revoke all on function public.ensure_ihiz_delivery_task_for_order(uuid) from public;
grant execute on function public.ensure_ihiz_delivery_task_for_order(uuid) to authenticated;

create or replace function public.claim_ihiz_delivery_task(p_task_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_task public.ihiz_delivery_tasks%rowtype;
begin
  if v_uid is null or not public.ihiz_actor_is_approved_courier(v_uid) then
    return jsonb_build_object('ok', false, 'error', 'not_courier');
  end if;

  update public.ihiz_delivery_tasks
  set
    assigned_courier_id = v_uid,
    status = 'courier_assigned',
    updated_at = timezone('utc', now())
  where id = p_task_id
    and assigned_courier_id is null
    and status in ('created', 'preparing', 'ready_for_pickup')
  returning * into v_task;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'already_claimed');
  end if;

  perform public.ihiz_append_delivery_event(
    v_task.id,
    'courier_assigned',
    'courier_assigned',
    'Kurye atandı',
    'Teslimat görevi bir kurye tarafından alındı.',
    'courier',
    v_uid,
    '{}'::jsonb
  );

  return jsonb_build_object('ok', true, 'id', v_task.id, 'status', v_task.status);
end;
$$;

revoke all on function public.claim_ihiz_delivery_task(uuid) from public;
grant execute on function public.claim_ihiz_delivery_task(uuid) to authenticated;

create or replace function public.advance_ihiz_delivery_task(
  p_task_id uuid,
  p_next_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_task public.ihiz_delivery_tasks%rowtype;
  v_now timestamptz := timezone('utc', now());
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if p_next_status not in (
    'preparing', 'ready_for_pickup', 'courier_assigned',
    'courier_picked_up', 'in_transit', 'delivered', 'cancelled'
  ) then
    return jsonb_build_object('ok', false, 'error', 'invalid_status');
  end if;

  select * into v_task from public.ihiz_delivery_tasks where id = p_task_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if not public.ihiz_delivery_task_can_access(v_task, v_uid) then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;

  update public.ihiz_delivery_tasks
  set
    status = p_next_status,
    picked_up_at = case when p_next_status = 'courier_picked_up' then coalesce(picked_up_at, v_now) else picked_up_at end,
    delivered_at = case when p_next_status = 'delivered' then coalesce(delivered_at, v_now) else delivered_at end,
    cancelled_at = case when p_next_status = 'cancelled' then coalesce(cancelled_at, v_now) else cancelled_at end,
    courier_lat = case when p_next_status in ('delivered', 'cancelled') then null else courier_lat end,
    courier_lng = case when p_next_status in ('delivered', 'cancelled') then null else courier_lng end,
    courier_location_updated_at = case when p_next_status in ('delivered', 'cancelled') then null else courier_location_updated_at end,
    updated_at = v_now
  where id = p_task_id
  returning * into v_task;

  perform public.ihiz_append_delivery_event(
    v_task.id,
    p_next_status,
    p_next_status,
    case p_next_status
      when 'courier_picked_up' then 'Kurye paketi teslim aldı'
      when 'in_transit' then 'Teslimat başladı'
      when 'delivered' then 'Teslim edildi'
      when 'cancelled' then 'Teslimat iptal edildi'
      when 'ready_for_pickup' then 'Paket kurye için hazır'
      when 'preparing' then 'Paket hazırlanıyor'
      else 'Durum güncellendi'
    end,
    null,
    'courier',
    v_uid,
    '{}'::jsonb
  );

  return jsonb_build_object('ok', true, 'status', v_task.status);
end;
$$;

revoke all on function public.advance_ihiz_delivery_task(uuid, text) from public;
grant execute on function public.advance_ihiz_delivery_task(uuid, text) to authenticated;

create or replace function public.update_ihiz_courier_location(
  p_task_id uuid,
  p_lat double precision,
  p_lng double precision
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_task public.ihiz_delivery_tasks%rowtype;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;

  update public.ihiz_delivery_tasks
  set
    courier_lat = p_lat,
    courier_lng = p_lng,
    courier_location_updated_at = timezone('utc', now())
  where id = p_task_id
    and assigned_courier_id = v_uid
    and status in ('courier_assigned', 'courier_picked_up', 'in_transit')
  returning * into v_task;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_live');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.update_ihiz_courier_location(uuid, double precision, double precision) from public;
grant execute on function public.update_ihiz_courier_location(uuid, double precision, double precision) to authenticated;

create or replace function public.apply_ihiz_business_account(
  p_store_id uuid,
  p_business_name text,
  p_contact_name text,
  p_contact_phone text,
  p_contact_email text,
  p_has_own_couriers boolean,
  p_courier_count integer,
  p_delivery_region text,
  p_notes text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.ihiz_business_accounts%rowtype;
begin
  if v_uid is null then
    raise exception 'auth_required';
  end if;
  if not public.ihiz_actor_owns_store(p_store_id, v_uid) then
    raise exception 'store_forbidden';
  end if;

  insert into public.ihiz_business_accounts (
    seller_id, store_id, status, business_name, contact_name, contact_phone,
    contact_email, has_own_couriers, courier_count, delivery_region, notes
  ) values (
    v_uid, p_store_id, 'pending',
    nullif(trim(p_business_name), ''),
    nullif(trim(p_contact_name), ''),
    nullif(trim(p_contact_phone), ''),
    nullif(trim(p_contact_email), ''),
    coalesce(p_has_own_couriers, false),
    p_courier_count,
    nullif(trim(p_delivery_region), ''),
    nullif(trim(p_notes), '')
  )
  on conflict (seller_id) do update set
    business_name = excluded.business_name,
    contact_name = excluded.contact_name,
    contact_phone = excluded.contact_phone,
    contact_email = excluded.contact_email,
    has_own_couriers = excluded.has_own_couriers,
    courier_count = excluded.courier_count,
    delivery_region = excluded.delivery_region,
    notes = excluded.notes,
    updated_at = timezone('utc', now())
  returning * into v_row;

  return jsonb_build_object(
    'ok', true,
    'id', v_row.id,
    'status', v_row.status
  );
end;
$$;

revoke all on function public.apply_ihiz_business_account(
  uuid, text, text, text, text, boolean, integer, text, text
) from public;
grant execute on function public.apply_ihiz_business_account(
  uuid, text, text, text, text, boolean, integer, text, text
) to authenticated;

create or replace function public.activate_ihiz_business_account(p_store_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.ihiz_business_accounts%rowtype;
begin
  if v_uid is null then
    raise exception 'auth_required';
  end if;
  if not (
    public.ihiz_actor_owns_store(p_store_id, v_uid)
    or public.ihiz_actor_is_admin(v_uid)
  ) then
    raise exception 'forbidden';
  end if;

  update public.ihiz_business_accounts
  set
    status = 'active',
    activated_at = coalesce(activated_at, timezone('utc', now()))
  where store_id = p_store_id
  returning * into v_row;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  return jsonb_build_object('ok', true, 'status', v_row.status);
end;
$$;

revoke all on function public.activate_ihiz_business_account(uuid) from public;
grant execute on function public.activate_ihiz_business_account(uuid) to authenticated;

create or replace function public.list_ihiz_approved_couriers_directory()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return '[]'::jsonb;
  end if;
  if not (
    public.ihiz_actor_is_admin(v_uid)
    or exists (
      select 1
      from public.ihiz_business_accounts a
      where a.seller_id = v_uid
        and a.status in ('pending', 'active')
    )
  ) then
    return '[]'::jsonb;
  end if;

  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'user_id', app.user_id,
          'full_name', app.full_name,
          'city', app.city,
          'district', app.district
        )
        order by app.full_name
      )
      from public.ihiz_courier_applications app
      where lower(coalesce(app.status, '')) = 'approved'
    ),
    '[]'::jsonb
  );
end;
$$;

revoke all on function public.list_ihiz_approved_couriers_directory() from public;
grant execute on function public.list_ihiz_approved_couriers_directory() to authenticated;

-- Realtime (authenticated dashboards). Public tracking still uses RPC projection.
alter table public.ihiz_delivery_tasks replica identity full;
alter table public.ihiz_delivery_events replica identity full;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.ihiz_delivery_tasks;
    exception when duplicate_object then
      null;
    end;
    begin
      alter publication supabase_realtime add table public.ihiz_delivery_events;
    exception when duplicate_object then
      null;
    end;
  end if;
end $$;
