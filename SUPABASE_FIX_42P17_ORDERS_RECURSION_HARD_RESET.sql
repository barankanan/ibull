-- Hard reset fix for:
-- PostgrestException code 42P17
-- "infinite recursion detected in policy for relation orders"
--
-- Run this in Supabase SQL Editor as postgres/admin.
-- Scope: public.orders + public.order_items RLS policies.

begin;

alter table if exists public.orders enable row level security;
alter table if exists public.order_items enable row level security;
alter table if exists public.orders no force row level security;
alter table if exists public.order_items no force row level security;

-- Buyer helper (SECURITY DEFINER + row_security off to avoid recursive policy eval)
create or replace function public.is_order_owner(
  target_order_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.orders o
    where o.id = target_order_id
      and o.user_id = target_user_id
  );
$$;

revoke all on function public.is_order_owner(uuid, uuid) from public;
grant execute on function public.is_order_owner(uuid, uuid) to authenticated;

-- Seller helper
create or replace function public.can_access_order_as_seller(
  target_order_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.order_items oi
    where oi.order_id = target_order_id
      and oi.seller_id = target_user_id
  );
$$;

revoke all on function public.can_access_order_as_seller(uuid, uuid) from public;
grant execute on function public.can_access_order_as_seller(uuid, uuid) to authenticated;

-- Courier helper
create or replace function public.is_ihiz_courier_user(
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.users u
    where u.id = target_user_id
      and coalesce(u.is_ihiz_approved, false) = true
  )
  or exists (
    select 1
    from public.ihiz_courier_applications app
    where app.user_id = target_user_id
      and lower(coalesce(app.status, '')) = 'approved'
  );
$$;

revoke all on function public.is_ihiz_courier_user(uuid) from public;
grant execute on function public.is_ihiz_courier_user(uuid) to authenticated;

-- Drop all existing policies on orders/order_items to remove hidden recursive leftovers.
do $$
declare
  pol record;
begin
  for pol in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('orders', 'order_items')
  loop
    execute format(
      'drop policy if exists %I on %I.%I;',
      pol.policyname,
      pol.schemaname,
      pol.tablename
    );
  end loop;
end $$;

-- ORDERS policies
create policy "orders_user_select"
on public.orders
for select
to authenticated
using (auth.uid() = user_id);

create policy "orders_user_insert"
on public.orders
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "orders_seller_select"
on public.orders
for select
to authenticated
using (public.can_access_order_as_seller(id, auth.uid()));

create policy "orders_seller_update"
on public.orders
for update
to authenticated
using (public.can_access_order_as_seller(id, auth.uid()))
with check (public.can_access_order_as_seller(id, auth.uid()));

create policy "orders_courier_select"
on public.orders
for select
to authenticated
using (
  public.is_ihiz_courier_user(auth.uid())
  and lower(coalesce(delivery_type, '')) like '%ihiz%'
);

create policy "orders_courier_update"
on public.orders
for update
to authenticated
using (
  public.is_ihiz_courier_user(auth.uid())
  and lower(coalesce(delivery_type, '')) like '%ihiz%'
)
with check (
  public.is_ihiz_courier_user(auth.uid())
  and lower(coalesce(delivery_type, '')) like '%ihiz%'
);

-- ORDER_ITEMS policies
create policy "order_items_buyer_select"
on public.order_items
for select
to authenticated
using (public.is_order_owner(order_id, auth.uid()));

create policy "order_items_buyer_insert"
on public.order_items
for insert
to authenticated
with check (public.is_order_owner(order_id, auth.uid()));

create policy "order_items_seller_select"
on public.order_items
for select
to authenticated
using (seller_id = auth.uid());

create policy "order_items_seller_update"
on public.order_items
for update
to authenticated
using (seller_id = auth.uid())
with check (seller_id = auth.uid());

create policy "order_items_courier_select"
on public.order_items
for select
to authenticated
using (
  public.is_ihiz_courier_user(auth.uid())
  and replace(lower(coalesce(cargo_company, '')), 'ı', 'i') like '%hiz%'
);

create policy "order_items_courier_update"
on public.order_items
for update
to authenticated
using (
  public.is_ihiz_courier_user(auth.uid())
  and replace(lower(coalesce(cargo_company, '')), 'ı', 'i') like '%hiz%'
)
with check (
  public.is_ihiz_courier_user(auth.uid())
  and replace(lower(coalesce(cargo_company, '')), 'ı', 'i') like '%hiz%'
);

commit;
