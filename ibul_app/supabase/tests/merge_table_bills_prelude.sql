-- Isolated schema for merge_table_bills. Not a production connection.

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
  status text not null default 'invited'
);

create table if not exists public.table_orders (
  id uuid primary key,
  seller_id uuid not null,
  table_number integer not null,
  items jsonb not null default '[]'::jsonb,
  status text not null default 'sent',
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.table_payments (
  id uuid primary key,
  seller_id uuid not null,
  table_number integer not null,
  session_key text not null,
  amount numeric(12,2) not null,
  method text not null default 'cash',
  idempotency_key text,
  created_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists table_payments_seller_idempotency_key
  on public.table_payments (seller_id, idempotency_key)
  where idempotency_key is not null;

create table if not exists public.table_transfers_log (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  from_table integer not null,
  to_table integer not null,
  transfer_type text not null,
  transferred_items jsonb,
  order_ids jsonb,
  waiter_id uuid,
  waiter_name text,
  note text,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.store_tables (
  id uuid primary key,
  seller_id uuid not null,
  table_number integer not null
);

create table if not exists public.orders (
  id uuid primary key,
  restaurant_id uuid,
  table_id uuid,
  status text not null,
  notes text
);

create table if not exists public.print_jobs (
  id uuid primary key,
  restaurant_id uuid not null,
  order_id uuid not null,
  job_type text not null,
  status text not null default 'pending',
  payload jsonb not null default '{}'::jsonb
);

create or replace function public.normalize_staff_permission(p_token text)
returns text
language sql
immutable
as $$
  select case folded
    when 'fullaccess' then 'fullAccess'
    when 'tamerisim' then 'fullAccess'
    when 'tam erisim' then 'fullAccess'
    when 'tam erişim' then 'fullAccess'
    when 'manageorders' then 'manageOrders'
    when 'vieworders' then 'viewOrders'
    else null
  end
  from (
    select lower(translate(btrim(coalesce(p_token, '')), 'İIı', 'iii')) as folded
  ) token
  where folded <> '';
$$;

create or replace function public.user_can_manage_restaurant_orders(
  p_seller_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role' then
    return true;
  end if;
  if auth.uid() is null or p_seller_id is null then
    return false;
  end if;
  if auth.uid() = p_seller_id then
    return true;
  end if;
  return exists (
    select 1
    from public.store_sub_admins sa
    join public.users u on u.id = auth.uid()
    where sa.store_id = p_seller_id
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
      and exists (
        select 1
        from unnest(coalesce(sa.permissions, '{}'::text[])) as token(value)
        where public.normalize_staff_permission(token.value) in (
          'manageOrders',
          'fullAccess'
        )
      )
  );
end;
$$;

insert into public.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'owner@ibul.test'),
  ('22222222-2222-4222-8222-222222222222', 'manager@ibul.test'),
  ('33333333-3333-4333-8333-333333333333', 'full@ibul.test'),
  ('44444444-4444-4444-8444-444444444444', 'view@ibul.test'),
  ('77777777-7777-4777-8777-777777777777', 'other@ibul.test')
on conflict (id) do nothing;

insert into public.store_sub_admins (id, store_id, email, permissions, status) values
  (
    '22222222-2222-4222-8222-222222222201',
    '11111111-1111-4111-8111-111111111111',
    'manager@ibul.test',
    array['manageOrders'],
    'active'
  ),
  (
    '33333333-3333-4333-8333-333333333301',
    '11111111-1111-4111-8111-111111111111',
    'full@ibul.test',
    array['Tam Erişim'],
    'active'
  ),
  (
    '44444444-4444-4444-8444-444444444401',
    '11111111-1111-4111-8111-111111111111',
    'view@ibul.test',
    array['viewOrders'],
    'active'
  ),
  (
    '77777777-7777-4777-8777-777777777701',
    '77777777-7777-4777-8777-777777777777',
    'other@ibul.test',
    array['manageOrders'],
    'active'
  )
on conflict (id) do nothing;

insert into public.store_tables (id, seller_id, table_number) values
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2', '11111111-1111-4111-8111-111111111111', 2),
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee3', '11111111-1111-4111-8111-111111111111', 3)
on conflict (id) do nothing;

insert into public.table_orders (id, seller_id, table_number, items, status, created_at) values
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    '11111111-1111-4111-8111-111111111111',
    2,
    '[{"name":"Corba","quantity":2,"price":40,"note":"az tuz"}]'::jsonb,
    'sent',
    '2026-11-07 12:00:00+00'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
    '11111111-1111-4111-8111-111111111111',
    3,
    '[{"name":"Salata","quantity":1,"price":30,"note":"limon"}]'::jsonb,
    'sent',
    '2026-11-07 12:05:00+00'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa9',
    '11111111-1111-4111-8111-111111111111',
    2,
    '[{"name":"Fis","quantity":1,"price":1,"note":"anchor"}]'::jsonb,
    'print_anchor',
    '2026-11-07 12:06:00+00'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',
    '11111111-1111-4111-8111-111111111111',
    4,
    '[{"name":"Kapali","quantity":1,"price":20}]'::jsonb,
    'closed',
    '2026-11-07 11:00:00+00'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa5',
    '11111111-1111-4111-8111-111111111111',
    5,
    '[{"name":"Odendi","quantity":1,"price":20}]'::jsonb,
    'paid',
    '2026-11-07 11:00:00+00'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa6',
    '11111111-1111-4111-8111-111111111111',
    6,
    '[{"name":"Yetki","quantity":1,"price":10}]'::jsonb,
    'sent',
    '2026-11-07 12:00:00+00'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa7',
    '11111111-1111-4111-8111-111111111111',
    7,
    '[{"name":"Hedef","quantity":1,"price":10}]'::jsonb,
    'sent',
    '2026-11-07 12:00:00+00'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',
    '11111111-1111-4111-8111-111111111111',
    8,
    '[{"name":"Yonetici","quantity":1,"price":12}]'::jsonb,
    'sent',
    '2026-11-07 12:00:00+00'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa10',
    '11111111-1111-4111-8111-111111111111',
    10,
    '[{"name":"Tam","quantity":1,"price":12}]'::jsonb,
    'sent',
    '2026-11-07 12:00:00+00'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa11',
    '11111111-1111-4111-8111-111111111111',
    11,
    '[{"name":"Tam hedef","quantity":1,"price":8}]'::jsonb,
    'sent',
    '2026-11-07 12:00:00+00'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa12',
    '11111111-1111-4111-8111-111111111111',
    12,
    '[{"name":"Yaris","quantity":1,"price":18}]'::jsonb,
    'sent',
    '2026-11-07 12:00:00+00'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa13',
    '11111111-1111-4111-8111-111111111111',
    13,
    '[{"name":"Yaris hedef","quantity":1,"price":22}]'::jsonb,
    'sent',
    '2026-11-07 12:00:00+00'
  )
on conflict (id) do nothing;

insert into public.table_payments (
  id, seller_id, table_number, session_key, amount, idempotency_key, created_at
) values
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
    '11111111-1111-4111-8111-111111111111',
    2,
    'visit-2',
    10,
    'pay-source-10',
    '2026-11-07 12:10:00+00'
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
    '11111111-1111-4111-8111-111111111111',
    3,
    'visit-3',
    15,
    'pay-target-15',
    '2026-11-07 12:12:00+00'
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3',
    '11111111-1111-4111-8111-111111111111',
    2,
    'old-visit',
    7,
    'pay-old-7',
    '2026-11-07 09:00:00+00'
  )
on conflict (id) do nothing;

insert into public.orders (id, restaurant_id, table_id, status, notes) values
  (
    'cccccccc-cccc-4ccc-8ccc-ccccccccccc1',
    '11111111-1111-4111-8111-111111111111',
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2',
    'sent',
    'musteri notu'
  )
on conflict (id) do nothing;

insert into public.print_jobs (id, restaurant_id, order_id, job_type, status, payload) values
  (
    'dddddddd-dddd-4ddd-8ddd-ddddddddddd1',
    '11111111-1111-4111-8111-111111111111',
    'cccccccc-cccc-4ccc-8ccc-ccccccccccc1',
    'kitchen',
    'pending',
    '{"ticket":"corba"}'::jsonb
  )
on conflict (id) do nothing;

commit;
