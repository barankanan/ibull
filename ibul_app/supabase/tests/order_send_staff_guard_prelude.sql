-- Isolated legacy order-send RPC for the staff-guard migration.
-- Not for production. The runner applies this before the migration.

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

create table if not exists public.order_send_probe (
  id integer generated always as identity primary key,
  restaurant_id uuid not null,
  actor_id uuid,
  table_number integer not null,
  source text not null
);

grant usage on schema auth, public to authenticated, anon, service_role;
grant execute on function auth.uid() to authenticated, anon, service_role;
grant select on public.users to authenticated, service_role;
grant select on public.store_sub_admins to authenticated, service_role;
grant select, insert on public.order_send_probe to authenticated, service_role;

-- Any active member, including view-only, may pass. This is the loose check
-- the current public RPC uses before the staff wrapper.
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

-- Legacy inner body. It accepts only the restaurant owner, which the old
-- public wrapper impersonates before the call.
create or replace function public.create_table_order_with_print_jobs_impl(
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
begin
  if auth.uid() is distinct from p_restaurant_id then
    raise exception 'Bu restoran için işlem yetkiniz yok.'
      using errcode = '42501';
  end if;

  insert into public.order_send_probe (
    restaurant_id,
    actor_id,
    table_number,
    source
  )
  values (p_restaurant_id, auth.uid(), p_table_number, 'impl');

  return jsonb_build_object('ok', true, 'source', 'impl');
end;
$$;

-- Public RPC as deployed by the waiter-access wrapper: any active member.
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
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  if not public.user_can_access_restaurant(p_restaurant_id) then
    raise exception 'Bu restoran için işlem yetkiniz yok.'
      using errcode = '42501';
  end if;

  perform set_config('request.jwt.claim.sub', p_restaurant_id::text, true);

  return public.create_table_order_with_print_jobs_impl(
    p_restaurant_id,
    p_table_number,
    p_items,
    p_waiter_id,
    p_waiter_name,
    p_notes,
    p_job_type,
    p_order_type
  );
end;
$$;

grant execute on function public.user_can_access_restaurant(uuid)
  to authenticated, anon, service_role;
grant execute on function public.create_table_order_with_print_jobs(
  uuid, integer, jsonb, uuid, text, text, text, text
) to authenticated, anon, service_role;
grant execute on function public.create_table_order_with_print_jobs_impl(
  uuid, integer, jsonb, uuid, text, text, text, text
) to authenticated, anon, service_role;

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

commit;
