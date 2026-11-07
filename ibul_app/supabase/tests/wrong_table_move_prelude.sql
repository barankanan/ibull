-- Isolated schema for a wrong-table correction. Not a production dump.
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

create table if not exists public.store_tables (
  id uuid primary key,
  seller_id uuid not null,
  table_number integer not null,
  qr_token text not null,
  is_active boolean not null default true,
  display_label text,
  table_name text,
  area_name text,
  area_table_number integer,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.table_orders (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  items jsonb not null default '[]'::jsonb,
  status text not null default 'sent',
  created_at timestamptz not null default timezone('utc', now())
);

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

create table if not exists public.orders (
  id uuid primary key,
  restaurant_id uuid,
  table_id uuid,
  status text not null,
  order_status text,
  order_type text,
  delivery_type text,
  total_amount numeric not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.print_jobs (
  id uuid primary key,
  restaurant_id uuid not null,
  order_id uuid not null references public.orders (id) on delete cascade,
  job_type text not null,
  status text not null default 'pending',
  payload jsonb not null default '{}'::jsonb
);

create or replace function public.user_can_manage_restaurant_orders(p_seller_id uuid)
returns boolean
language sql
stable
as $$
  select
    coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'
    or auth.uid() = p_seller_id
    or exists (
      select 1
      from public.store_sub_admins sa
      join public.users u on u.id = auth.uid()
      where sa.store_id = p_seller_id
        and sa.status = 'active'
        and (
          lower(btrim(coalesce(u.email, ''))) = lower(btrim(coalesce(sa.email, '')))
          and btrim(coalesce(sa.email, '')) <> ''
        )
        and exists (
          select 1
          from unnest(coalesce(sa.permissions, '{}'::text[])) token(value)
          where token.value in ('manageOrders', 'fullAccess')
        )
    );
$$;

insert into public.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'owner@example.test'),
  ('22222222-2222-4222-8222-222222222222', 'manage@example.test'),
  ('33333333-3333-4333-8333-333333333333', 'view@example.test')
on conflict (id) do nothing;

insert into public.store_sub_admins (store_id, email, permissions, status) values
  ('11111111-1111-4111-8111-111111111111', 'manage@example.test', array['manageOrders'], 'active'),
  ('11111111-1111-4111-8111-111111111111', 'view@example.test', array['viewOrders'], 'active');

create or replace function public.seed_wrong_table_case()
returns void
language plpgsql
as $$
begin
  delete from public.print_jobs
  where restaurant_id in (
    '11111111-1111-4111-8111-111111111111',
    '44444444-4444-4444-8444-444444444444'
  );
  delete from public.orders
  where restaurant_id in (
    '11111111-1111-4111-8111-111111111111',
    '44444444-4444-4444-8444-444444444444'
  );
  delete from public.table_orders
  where seller_id in (
    '11111111-1111-4111-8111-111111111111',
    '44444444-4444-4444-8444-444444444444'
  );
  delete from public.table_transfers_log
  where seller_id in (
    '11111111-1111-4111-8111-111111111111',
    '44444444-4444-4444-8444-444444444444'
  );
  delete from public.store_tables
  where seller_id in (
    '11111111-1111-4111-8111-111111111111',
    '44444444-4444-4444-8444-444444444444'
  );

  insert into public.store_tables (
    id, seller_id, table_number, qr_token, display_label, table_name,
    area_name, area_table_number
  ) values
    ('11111111-1111-4111-8111-111111111104', '11111111-1111-4111-8111-111111111111', 4, 'qr-4', 'Salon 4', 'Salon 4', 'Salon', 4),
    ('11111111-1111-4111-8111-111111111107', '11111111-1111-4111-8111-111111111111', 7, 'qr-7', 'Bahçe 2', 'Bahçe 2', 'Bahçe', 2),
    ('11111111-1111-4111-8111-111111111108', '11111111-1111-4111-8111-111111111111', 8, 'qr-8', 'Salon 8', 'Salon 8', 'Salon', 8),
    ('11111111-1111-4111-8111-111111111109', '11111111-1111-4111-8111-111111111111', 9, 'qr-9', 'Salon 9', 'Salon 9', 'Salon', 9),
    ('11111111-1111-4111-8111-111111111114', '11111111-1111-4111-8111-111111111111', 14, 'qr-14', 'Masa 14', 'Masa 14', '', 14),
    ('11111111-1111-4111-8111-111111111115', '11111111-1111-4111-8111-111111111111', 15, 'qr-15', 'Masa 15', 'Masa 15', '', 15),
    ('11111111-1111-4111-8111-111111111116', '11111111-1111-4111-8111-111111111111', 16, 'qr-16', 'Masa 16', 'Masa 16', '', 16),
    ('11111111-1111-4111-8111-111111111117', '11111111-1111-4111-8111-111111111111', 17, 'qr-17', 'Masa 17', 'Masa 17', '', 17),
    ('44444444-4444-4444-8444-444444444404', '44444444-4444-4444-8444-444444444444', 4, 'qr-other', 'Diğer 4', 'Diğer 4', '', 4);

  insert into public.table_orders (id, seller_id, table_number, items, status) values
    (
      '11111111-1111-4111-8111-111111111140',
      '11111111-1111-4111-8111-111111111111',
      4,
      '[{"name":"Çay","quantity":1,"price":20}]'::jsonb,
      'sent'
    ),
    (
      '11111111-1111-4111-8111-111111111180',
      '11111111-1111-4111-8111-111111111111',
      8,
      '[{"id":"tea","name":"Çay","quantity":1},{"id":"water","name":"Su","quantity":1}]'::jsonb,
      'sent'
    ),
    (
      '11111111-1111-4111-8111-111111111114',
      '11111111-1111-4111-8111-111111111111',
      14,
      '[{"name":"Çorba","quantity":1}]'::jsonb,
      'sent'
    ),
    (
      '11111111-1111-4111-8111-111111111116',
      '11111111-1111-4111-8111-111111111111',
      16,
      '[{"name":"Tatlı","quantity":1}]'::jsonb,
      'sent'
    );

  insert into public.orders (
    id, restaurant_id, table_id, status, order_status, order_type, delivery_type
  ) values
    (
      '11111111-1111-4111-8111-111111111141',
      '11111111-1111-4111-8111-111111111111',
      '11111111-1111-4111-8111-111111111104',
      'confirmed', 'sent', 'table', 'table'
    ),
    (
      '11111111-1111-4111-8111-111111111142',
      '11111111-1111-4111-8111-111111111111',
      '11111111-1111-4111-8111-111111111104',
      'closed', 'closed', 'table', 'table'
    ),
    (
      '11111111-1111-4111-8111-111111111143',
      '11111111-1111-4111-8111-111111111111',
      '11111111-1111-4111-8111-111111111104',
      'confirmed', 'sent', 'delivery', 'courier'
    ),
    (
      '11111111-1111-4111-8111-111111111181',
      '11111111-1111-4111-8111-111111111111',
      '11111111-1111-4111-8111-111111111108',
      'confirmed', 'sent', 'table', 'table'
    ),
    (
      '11111111-1111-4111-8111-111111111191',
      '11111111-1111-4111-8111-111111111111',
      '11111111-1111-4111-8111-111111111114',
      'confirmed', 'sent', 'table', 'table'
    ),
    (
      '11111111-1111-4111-8111-111111111192',
      '11111111-1111-4111-8111-111111111111',
      '11111111-1111-4111-8111-111111111116',
      'confirmed', 'sent', 'table', 'table'
    ),
    (
      '44444444-4444-4444-8444-444444444441',
      '44444444-4444-4444-8444-444444444444',
      '44444444-4444-4444-8444-444444444404',
      'confirmed', 'sent', 'table', 'table'
    );

  insert into public.print_jobs (
    id, restaurant_id, order_id, job_type, status, payload
  ) values
    (
      '11111111-1111-4111-8111-111111111151',
      '11111111-1111-4111-8111-111111111111',
      '11111111-1111-4111-8111-111111111141',
      'new_order',
      'pending',
      '{"table_number":4,"display_table_label":"Salon 4","table_id":"11111111-1111-4111-8111-111111111104"}'::jsonb
    ),
    (
      '11111111-1111-4111-8111-111111111152',
      '11111111-1111-4111-8111-111111111111',
      '11111111-1111-4111-8111-111111111141',
      'new_order',
      'printed',
      '{"table_number":4,"display_table_label":"Salon 4","table_id":"11111111-1111-4111-8111-111111111104"}'::jsonb
    ),
    (
      '11111111-1111-4111-8111-111111111181',
      '11111111-1111-4111-8111-111111111111',
      '11111111-1111-4111-8111-111111111181',
      'new_order',
      'pending',
      '{"table_number":8,"display_table_label":"Salon 8"}'::jsonb
    ),
    (
      '11111111-1111-4111-8111-111111111191',
      '11111111-1111-4111-8111-111111111111',
      '11111111-1111-4111-8111-111111111191',
      'new_order',
      'pending',
      '{"table_number":14,"display_table_label":"Masa 14"}'::jsonb
    ),
    (
      '11111111-1111-4111-8111-111111111193',
      '11111111-1111-4111-8111-111111111111',
      '11111111-1111-4111-8111-111111111192',
      'new_order',
      'pending',
      '{"table_number":16,"display_table_label":"Masa 16"}'::jsonb
    );
end;
$$;

commit;
