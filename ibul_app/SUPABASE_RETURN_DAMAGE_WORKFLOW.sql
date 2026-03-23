create extension if not exists pgcrypto;

create table if not exists public.order_item_return_requests (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  order_item_id uuid not null references public.order_items(id) on delete cascade,
  buyer_user_id uuid not null,
  seller_id uuid,
  store_name text,
  product_name text,
  product_image_url text,
  reason text not null,
  issue_tags text[] not null default '{}'::text[],
  detail text,
  damage_level text not null default 'belirsiz',
  damage_description text,
  evidence_image_urls text[] not null default '{}'::text[],
  status text not null default 'pending_seller_review',
  seller_decision text not null default 'pending',
  seller_decision_note text,
  seller_decision_due_at timestamptz,
  seller_decided_at timestamptz,
  seller_will_receive_product boolean not null default true,
  customer_pickup_slot_start timestamptz,
  customer_pickup_slot_end timestamptz,
  buyer_pickup_note text,
  courier_dispatch_status text not null default 'not_scheduled',
  ibul_case_status text not null default 'none',
  ibul_resolution_note text,
  ibul_resolved_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ihiz_return_pickup_tasks (
  id uuid primary key default gen_random_uuid(),
  return_request_id uuid not null references public.order_item_return_requests(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  order_item_id uuid not null references public.order_items(id) on delete cascade,
  buyer_user_id uuid not null,
  seller_id uuid,
  pickup_window_start timestamptz not null,
  pickup_window_end timestamptz not null,
  pickup_address jsonb not null default '{}'::jsonb,
  dropoff_store_name text,
  status text not null default 'queued',
  note text,
  assigned_courier_id uuid,
  assigned_at timestamptz,
  picked_up_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_order_item_return_requests_order_item_id
  on public.order_item_return_requests(order_item_id, created_at desc);
create index if not exists idx_order_item_return_requests_seller_status
  on public.order_item_return_requests(seller_id, status, created_at desc);
create index if not exists idx_order_item_return_requests_buyer_status
  on public.order_item_return_requests(buyer_user_id, status, created_at desc);

create unique index if not exists uq_order_item_return_requests_open
  on public.order_item_return_requests(order_item_id)
  where status in (
    'pending_seller_review',
    'awaiting_customer_pickup_slot',
    'pickup_scheduled',
    'reported_to_ibul'
  );

create index if not exists idx_ihiz_return_pickup_tasks_status
  on public.ihiz_return_pickup_tasks(status, pickup_window_start);
create index if not exists idx_ihiz_return_pickup_tasks_return_request
  on public.ihiz_return_pickup_tasks(return_request_id, created_at desc);

create or replace function public.set_updated_at_timestamp()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_order_item_return_requests_updated_at on public.order_item_return_requests;
create trigger trg_order_item_return_requests_updated_at
before update on public.order_item_return_requests
for each row execute function public.set_updated_at_timestamp();

drop trigger if exists trg_ihiz_return_pickup_tasks_updated_at on public.ihiz_return_pickup_tasks;
create trigger trg_ihiz_return_pickup_tasks_updated_at
before update on public.ihiz_return_pickup_tasks
for each row execute function public.set_updated_at_timestamp();

alter table public.order_item_return_requests enable row level security;
alter table public.ihiz_return_pickup_tasks enable row level security;

drop policy if exists "return_requests_select_related" on public.order_item_return_requests;
create policy "return_requests_select_related"
on public.order_item_return_requests
for select
to authenticated
using (
  buyer_user_id = auth.uid()
  or seller_id = auth.uid()
  or exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and lower(coalesce(u.role, '')) in ('admin', 'super_admin')
  )
);

drop policy if exists "return_requests_insert_buyer" on public.order_item_return_requests;
create policy "return_requests_insert_buyer"
on public.order_item_return_requests
for insert
to authenticated
with check (
  buyer_user_id = auth.uid()
  and exists (
    select 1
    from public.orders o
    join public.order_items oi on oi.order_id = o.id
    where o.id = order_item_return_requests.order_id
      and oi.id = order_item_return_requests.order_item_id
      and o.user_id = auth.uid()
  )
);

drop policy if exists "return_requests_update_buyer" on public.order_item_return_requests;
create policy "return_requests_update_buyer"
on public.order_item_return_requests
for update
to authenticated
using (buyer_user_id = auth.uid())
with check (buyer_user_id = auth.uid());

drop policy if exists "return_requests_update_seller" on public.order_item_return_requests;
create policy "return_requests_update_seller"
on public.order_item_return_requests
for update
to authenticated
using (seller_id = auth.uid())
with check (seller_id = auth.uid());

drop policy if exists "return_requests_update_admin" on public.order_item_return_requests;
create policy "return_requests_update_admin"
on public.order_item_return_requests
for update
to authenticated
using (
  exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and lower(coalesce(u.role, '')) in ('admin', 'super_admin')
  )
)
with check (
  exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and lower(coalesce(u.role, '')) in ('admin', 'super_admin')
  )
);

drop policy if exists "return_pickup_tasks_select_related" on public.ihiz_return_pickup_tasks;
create policy "return_pickup_tasks_select_related"
on public.ihiz_return_pickup_tasks
for select
to authenticated
using (
  buyer_user_id = auth.uid()
  or seller_id = auth.uid()
  or exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and lower(coalesce(u.role, '')) in ('admin', 'super_admin', 'courier')
  )
);

drop policy if exists "return_pickup_tasks_insert_related" on public.ihiz_return_pickup_tasks;
create policy "return_pickup_tasks_insert_related"
on public.ihiz_return_pickup_tasks
for insert
to authenticated
with check (
  buyer_user_id = auth.uid()
  or seller_id = auth.uid()
  or exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and lower(coalesce(u.role, '')) in ('admin', 'super_admin')
  )
);

drop policy if exists "return_pickup_tasks_update_admin_or_courier" on public.ihiz_return_pickup_tasks;
create policy "return_pickup_tasks_update_admin_or_courier"
on public.ihiz_return_pickup_tasks
for update
to authenticated
using (
  exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and lower(coalesce(u.role, '')) in ('admin', 'super_admin', 'courier')
  )
)
with check (
  exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and lower(coalesce(u.role, '')) in ('admin', 'super_admin', 'courier')
  )
);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'return-evidence',
  'return-evidence',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = true,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "return_evidence_insert_own" on storage.objects;
create policy "return_evidence_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'return-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "return_evidence_update_own" on storage.objects;
create policy "return_evidence_update_own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'return-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'return-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "return_evidence_delete_own" on storage.objects;
create policy "return_evidence_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'return-evidence'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "return_evidence_select_all" on storage.objects;
create policy "return_evidence_select_all"
on storage.objects
for select
using (bucket_id = 'return-evidence');
