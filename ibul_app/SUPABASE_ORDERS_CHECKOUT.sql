-- Kullanıcı checkout / sipariş sistemi
-- 1) Kullanıcı profilinde adres ve kart alanlarını garanti altına al
alter table public.users
  add column if not exists addresses jsonb not null default '[]'::jsonb;

alter table public.users
  add column if not exists "savedCards" jsonb not null default '[]'::jsonb;

alter table public.users
  add column if not exists favorites jsonb not null default '[]'::jsonb;

alter table public.users
  add column if not exists cart jsonb not null default '[]'::jsonb;

alter table public.users
  add column if not exists "followedStores" jsonb not null default '[]'::jsonb;

-- 2) Sipariş ana tablosu
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  order_number text not null unique,
  status text not null default 'confirmed',
  payment_method text not null default 'card',
  payment_card_name text,
  payment_card_last4 text,
  delivery_type text,
  delivery_slot text,
  delivery_address jsonb not null default '{}'::jsonb,
  subtotal_amount numeric(12,2) not null default 0,
  shipping_amount numeric(12,2) not null default 0,
  discount_amount numeric(12,2) not null default 0,
  total_amount numeric(12,2) not null default 0,
  currency text not null default 'TRY',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_orders_user_id on public.orders(user_id);
create index if not exists idx_orders_created_at on public.orders(created_at desc);
create index if not exists idx_orders_status on public.orders(status);

-- 3) Sipariş kalemleri
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  seller_id uuid references public.users(id) on delete set null,
  product_id text,
  product_code text,
  product_name text not null,
  store_name text,
  product_image_url text,
  attributes jsonb not null default '[]'::jsonb,
  quantity integer not null default 1,
  unit_price numeric(12,2) not null default 0,
  total_price numeric(12,2) not null default 0,
  status text not null default 'new',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_order_items_order_id on public.order_items(order_id);
create index if not exists idx_order_items_seller_id on public.order_items(seller_id);
create index if not exists idx_order_items_status on public.order_items(status);

-- 4) updated_at trigger
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_orders_updated_at on public.orders;
create trigger trg_orders_updated_at
before update on public.orders
for each row
execute function public.set_updated_at();

drop trigger if exists trg_order_items_updated_at on public.order_items;
create trigger trg_order_items_updated_at
before update on public.order_items
for each row
execute function public.set_updated_at();

-- 5) RLS
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

create or replace function public.can_access_order_as_seller(target_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.order_items oi
    where oi.order_id = target_order_id
      and oi.seller_id = auth.uid()
  );
$$;

drop policy if exists "orders_user_select" on public.orders;
create policy "orders_user_select"
on public.orders
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "orders_user_insert" on public.orders;
create policy "orders_user_insert"
on public.orders
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "orders_seller_select" on public.orders;
create policy "orders_seller_select"
on public.orders
for select
to authenticated
using (public.can_access_order_as_seller(id));

drop policy if exists "orders_seller_update" on public.orders;
create policy "orders_seller_update"
on public.orders
for update
to authenticated
using (public.can_access_order_as_seller(id))
with check (public.can_access_order_as_seller(id));

drop policy if exists "order_items_buyer_select" on public.order_items;
create policy "order_items_buyer_select"
on public.order_items
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.user_id = auth.uid()
  )
);

drop policy if exists "order_items_buyer_insert" on public.order_items;
create policy "order_items_buyer_insert"
on public.order_items
for insert
to authenticated
with check (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.user_id = auth.uid()
  )
);

drop policy if exists "order_items_seller_select" on public.order_items;
create policy "order_items_seller_select"
on public.order_items
for select
to authenticated
using (seller_id = auth.uid());

drop policy if exists "order_items_seller_update" on public.order_items;
create policy "order_items_seller_update"
on public.order_items
for update
to authenticated
using (seller_id = auth.uid())
with check (seller_id = auth.uid());
