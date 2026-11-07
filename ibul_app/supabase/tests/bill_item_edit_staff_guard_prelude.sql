-- Isolated bill-edit and waiter-request fixtures.
-- Not for production. The runner applies this before the migration.
-- table_orders is granted to authenticated with a permissive policy so the
-- trigger, not a missing grant, is what stops a view-only edit.

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
  email text,
  phone text
);

create table if not exists public.store_sub_admins (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null,
  email text,
  phone text,
  permissions text[] not null default '{}'::text[],
  status text not null default 'invited',
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.table_orders (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  items jsonb not null default '[]'::jsonb,
  status text not null default 'sent',
  updated_at timestamptz
);

create table if not exists public.waiter_order_requests (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  status text not null default 'pending_waiter_approval',
  resolved_by uuid,
  rejection_reason text
);

create table if not exists public.waiter_request_probe (
  id integer generated always as identity primary key,
  request_id uuid not null,
  actor_id uuid,
  action text not null,
  seller_id uuid not null
);

alter table public.table_orders enable row level security;

drop policy if exists table_orders_authenticated_all on public.table_orders;
create policy table_orders_authenticated_all
  on public.table_orders
  for all
  to authenticated
  using (true)
  with check (true);

grant usage on schema auth, public to authenticated, anon, service_role;
grant execute on function auth.uid() to authenticated, anon, service_role;
grant select on public.users to authenticated, service_role;
grant select on public.store_sub_admins to authenticated, service_role;
grant select, insert, update, delete on public.table_orders to authenticated, service_role;
grant select, insert, update on public.waiter_order_requests to authenticated, service_role;
grant select, insert on public.waiter_request_probe to authenticated, service_role;

-- Any active member, including view-only, may pass. This is the loose check
-- the current public RPCs use before the staff wrapper.
create or replace function public.user_can_access_restaurant(
  p_restaurant_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() = p_restaurant_id
    or exists (
      select 1
      from public.store_sub_admins sa
      join public.users u
        on u.id = auth.uid()
      where sa.store_id = p_restaurant_id
        and sa.status = 'active'
        and (
          (
            sa.email is not null
            and btrim(sa.email) <> ''
            and lower(btrim(coalesce(u.email, ''))) = lower(btrim(sa.email))
          )
          or (
            sa.phone is not null
            and btrim(sa.phone) <> ''
            and btrim(coalesce(u.phone, '')) = btrim(sa.phone)
          )
        )
    );
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
  v_seller uuid;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  select seller_id
  into v_seller
  from public.waiter_order_requests
  where id = p_request_id
  for update;

  if v_seller is null then
    raise exception 'İstek bulunamadı.' using errcode = '22023';
  end if;

  if not public.user_can_access_restaurant(v_seller) then
    raise exception 'Bu işletme için yetkiniz yok.' using errcode = '42501';
  end if;

  update public.waiter_order_requests
  set status = 'approved_converted',
      resolved_by = auth.uid()
  where id = p_request_id;

  insert into public.waiter_request_probe (request_id, actor_id, action, seller_id)
  values (p_request_id, auth.uid(), 'approve-body', v_seller);

  return jsonb_build_object('ok', true, 'actor', auth.uid(), 'source', 'approve-body');
end;
$$;

create or replace function public.reject_waiter_order_request(
  p_request_id uuid,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller uuid;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  select seller_id
  into v_seller
  from public.waiter_order_requests
  where id = p_request_id
  for update;

  if v_seller is null then
    raise exception 'İstek bulunamadı.' using errcode = '22023';
  end if;

  if not public.user_can_access_restaurant(v_seller) then
    raise exception 'Bu işletme için yetkiniz yok.' using errcode = '42501';
  end if;

  update public.waiter_order_requests
  set status = 'rejected',
      resolved_by = auth.uid(),
      rejection_reason = nullif(btrim(coalesce(p_reason, '')), '')
  where id = p_request_id;

  insert into public.waiter_request_probe (request_id, actor_id, action, seller_id)
  values (p_request_id, auth.uid(), 'reject-body', v_seller);
end;
$$;

grant execute on function public.user_can_access_restaurant(uuid)
  to authenticated, anon, service_role;
grant execute on function public.approve_waiter_order_request(uuid, jsonb)
  to authenticated, anon, service_role;
grant execute on function public.reject_waiter_order_request(uuid, text)
  to authenticated, anon, service_role;

insert into public.users (id, email, phone) values
  ('11111111-1111-1111-1111-111111111111', 'owner@ibul.test', null),
  ('22222222-2222-2222-2222-222222222222', 'manager@ibul.test', null),
  ('33333333-3333-3333-3333-333333333333', 'full@ibul.test', null),
  ('44444444-4444-4444-4444-444444444444', 'view@ibul.test', null),
  ('55555555-5555-5555-5555-555555555555', 'empty@ibul.test', null),
  ('66666666-6666-6666-6666-666666666666', 'invited@ibul.test', null),
  ('77777777-7777-7777-7777-777777777777', 'other@ibul.test', null),
  ('88888888-8888-8888-8888-888888888888', null, '5550001111'),
  ('99999999-9999-9999-9999-999999999999', 'tam@ibul.test', null);

insert into public.store_sub_admins (store_id, email, phone, permissions, status) values
  ('11111111-1111-1111-1111-111111111111', 'manager@ibul.test', null, array['manageOrders'], 'active'),
  ('11111111-1111-1111-1111-111111111111', 'full@ibul.test', null, array['fullAccess'], 'active'),
  ('11111111-1111-1111-1111-111111111111', 'view@ibul.test', null, array['viewOrders'], 'active'),
  ('11111111-1111-1111-1111-111111111111', 'empty@ibul.test', null, '{}'::text[], 'active'),
  ('11111111-1111-1111-1111-111111111111', 'invited@ibul.test', null, array['manageOrders'], 'invited'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'other@ibul.test', null, array['manageOrders'], 'active'),
  ('11111111-1111-1111-1111-111111111111', null, '5550001111', array['manageOrders'], 'active'),
  ('11111111-1111-1111-1111-111111111111', 'tam@ibul.test', null, array['Tam Erişim'], 'active');

insert into public.table_orders (id, seller_id, table_number, items, status) values
  (
    'abababab-abab-abab-abab-abababababab',
    '11111111-1111-1111-1111-111111111111',
    4,
    '[{"name":"corba","price":40,"quantity":1}]'::jsonb,
    'sent'
  );

commit;
