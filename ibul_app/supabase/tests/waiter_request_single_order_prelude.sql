-- Isolated fixture for the waiter-request double write.
-- Not for production. The runner applies this before the migration.
--
-- The print function inserts an active orders row, matching
-- create_table_order_with_print_jobs on main (status confirmed,
-- order_status sent, notes copied). The approval function inserts one
-- table_orders bill and then calls that print function with the
-- waiter_request:<id> note used by approve_waiter_order_request.

begin;

create schema if not exists auth;

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role;
  end if;
end
$$;

create table if not exists public.users (
  id uuid primary key,
  email text
);

create table if not exists public.table_orders (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  items jsonb not null default '[]'::jsonb,
  status text not null,
  placement_source text,
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  order_number text,
  status text not null,
  order_status text,
  restaurant_id uuid,
  notes text,
  order_type text,
  delivery_type text,
  total_amount numeric not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.print_jobs (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null,
  order_id uuid not null references public.orders (id) on delete cascade,
  job_type text not null,
  status text not null default 'pending',
  payload jsonb not null default '{}'::jsonb
);

create table if not exists public.waiter_order_requests (
  id uuid primary key,
  seller_id uuid not null,
  table_number integer not null,
  items_draft jsonb not null,
  customer_notes text,
  status text not null,
  resulting_table_order_id uuid,
  created_by uuid not null
);

create table if not exists public.fixture_guard (
  name text primary key,
  body text not null
);

grant usage on schema auth, public to authenticated, anon, service_role;
grant execute on function auth.uid() to authenticated, anon, service_role;

create or replace function public.test_set_actor(p_uid uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), false);
end;
$$;

grant execute on function public.test_set_actor(uuid) to authenticated, anon, service_role;

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
  v_job_id uuid;
  v_notes text := nullif(btrim(coalesce(p_notes, '')), '');
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  insert into public.orders (
    user_id,
    order_number,
    status,
    order_status,
    restaurant_id,
    notes,
    order_type,
    delivery_type,
    total_amount
  )
  values (
    auth.uid(),
    'TBL-FIXTURE',
    'confirmed',
    'sent',
    p_restaurant_id,
    v_notes,
    coalesce(nullif(btrim(coalesce(p_order_type, '')), ''), 'table'),
    'table',
    0
  )
  returning id into v_order_id;

  insert into public.print_jobs (
    restaurant_id,
    order_id,
    job_type,
    status,
    payload
  )
  values (
    p_restaurant_id,
    v_order_id,
    coalesce(nullif(btrim(coalesce(p_job_type, '')), ''), 'new_order'),
    'pending',
    jsonb_build_object('table_number', p_table_number, 'items', p_items)
  )
  returning id into v_job_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', 'TBL-FIXTURE',
    'print_job_ids', jsonb_build_array(v_job_id)
  );
end;
$$;

create or replace function public.approve_waiter_order_request(
  p_request_id uuid,
  p_edited_items jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req public.waiter_order_requests%rowtype;
  v_items jsonb;
  v_table_order_id uuid;
  v_print jsonb;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  select * into v_req
  from public.waiter_order_requests
  where id = p_request_id
  for update;

  if v_req.id is null then
    raise exception 'İstek bulunamadı.' using errcode = '22023';
  end if;

  if v_req.status <> 'pending_waiter_approval' then
    raise exception 'Bu istek onay için uygun değil.' using errcode = '22023';
  end if;

  v_items := coalesce(p_edited_items, v_req.items_draft);

  insert into public.table_orders (
    seller_id,
    table_number,
    items,
    status,
    placement_source
  )
  values (
    v_req.seller_id,
    v_req.table_number,
    v_items,
    'new',
    'customer'
  )
  returning id into v_table_order_id;

  update public.waiter_order_requests
  set
    status = 'approved_converted',
    resulting_table_order_id = v_table_order_id
  where id = p_request_id;

  v_print := public.create_table_order_with_print_jobs(
    v_req.seller_id,
    v_req.table_number,
    v_items,
    auth.uid(),
    'Garson',
    format(
      'waiter_request:%s %s',
      p_request_id::text,
      coalesce(nullif(btrim(coalesce(v_req.customer_notes, '')), ''), '')
    ),
    'new_order',
    'table'
  );

  update public.table_orders
  set status = 'sent'
  where id = v_table_order_id;

  return jsonb_build_object(
    'request_id', p_request_id,
    'table_order_id', v_table_order_id,
    'print_result', v_print
  );
end;
$$;

grant execute on function public.create_table_order_with_print_jobs(
  uuid, integer, jsonb, uuid, text, text, text, text
) to authenticated, anon, service_role;
grant execute on function public.approve_waiter_order_request(uuid, jsonb)
  to authenticated, service_role;

insert into public.users (id, email)
values ('11111111-1111-1111-1111-111111111111', 'owner@ibul.test');

insert into public.waiter_order_requests (
  id, seller_id, table_number, items_draft, customer_notes, status, created_by
)
values
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    '11111111-1111-1111-1111-111111111111',
    4,
    '[{"name":"Çorba","quantity":1,"price":90}]'::jsonb,
    'az acılı',
    'pending_waiter_approval',
    '11111111-1111-1111-1111-111111111111'
  ),
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
    '11111111-1111-1111-1111-111111111111',
    5,
    '[{"name":"Izgara","quantity":2,"price":240}]'::jsonb,
    null,
    'pending_waiter_approval',
    '11111111-1111-1111-1111-111111111111'
  );

insert into public.fixture_guard (name, body)
values (
  'approve',
  pg_get_functiondef(
    'public.approve_waiter_order_request(uuid,jsonb)'::regprocedure
  )
);

commit;
