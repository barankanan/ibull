create extension if not exists pgcrypto;

create table if not exists public.product_questions (
  id uuid primary key default gen_random_uuid(),
  product_name text not null,
  store_name text not null,
  seller_id uuid,
  product_image_url text,
  user_id uuid,
  user_name text,
  question text not null,
  answer text default '',
  answer_by uuid,
  likes integer not null default 0,
  created_at timestamptz not null default now(),
  answered_at timestamptz
);

create index if not exists idx_product_questions_product_name
  on public.product_questions (lower(product_name));
create index if not exists idx_product_questions_store_name
  on public.product_questions (lower(store_name));
create index if not exists idx_product_questions_seller_id
  on public.product_questions (seller_id);

alter table public.product_questions enable row level security;

drop policy if exists "product_questions_public_read" on public.product_questions;
create policy "product_questions_public_read"
on public.product_questions
for select
to public
using (true);

drop policy if exists "product_questions_auth_insert" on public.product_questions;
create policy "product_questions_auth_insert"
on public.product_questions
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "product_questions_seller_update" on public.product_questions;
create policy "product_questions_seller_update"
on public.product_questions
for update
to authenticated
using (seller_id = auth.uid())
with check (seller_id = auth.uid());

alter table public.order_items
  add column if not exists cargo_company text default 'ihız';
alter table public.order_items
  add column if not exists tracking_number text;
alter table public.order_items
  add column if not exists shipment_step text default 'confirmed';

create table if not exists public.order_item_status_history (
  id uuid primary key default gen_random_uuid(),
  order_item_id uuid not null references public.order_items(id) on delete cascade,
  status text not null,
  title text,
  description text,
  tracking_number text,
  cargo_company text,
  created_at timestamptz not null default now()
);

create index if not exists idx_order_item_status_history_item_id
  on public.order_item_status_history(order_item_id, created_at desc);

alter table public.order_item_status_history enable row level security;

drop policy if exists "order_item_status_history_buyer_select" on public.order_item_status_history;
create policy "order_item_status_history_buyer_select"
on public.order_item_status_history
for select
to authenticated
using (
  exists (
    select 1
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where oi.id = order_item_status_history.order_item_id
      and o.user_id = auth.uid()
  )
  or exists (
    select 1
    from public.order_items oi
    where oi.id = order_item_status_history.order_item_id
      and oi.seller_id = auth.uid()
  )
);

drop policy if exists "order_item_status_history_seller_insert" on public.order_item_status_history;
create policy "order_item_status_history_seller_insert"
on public.order_item_status_history
for insert
to authenticated
with check (
  exists (
    select 1
    from public.order_items oi
    where oi.id = order_item_status_history.order_item_id
      and oi.seller_id = auth.uid()
  )
);

drop policy if exists "order_item_status_history_buyer_insert" on public.order_item_status_history;
create policy "order_item_status_history_buyer_insert"
on public.order_item_status_history
for insert
to authenticated
with check (
  exists (
    select 1
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where oi.id = order_item_status_history.order_item_id
      and o.user_id = auth.uid()
  )
);

create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  title text not null,
  body text not null,
  data jsonb default '{}'::jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_user_notifications_user_id
  on public.user_notifications(user_id, created_at desc);

alter table public.user_notifications enable row level security;

drop policy if exists "user_notifications_select_own" on public.user_notifications;
create policy "user_notifications_select_own"
on public.user_notifications
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "user_notifications_insert_authenticated" on public.user_notifications;
create policy "user_notifications_insert_authenticated"
on public.user_notifications
for insert
to authenticated
with check (true);
