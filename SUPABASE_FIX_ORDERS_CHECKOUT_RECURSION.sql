-- Fix: Postgres 42P17 infinite recursion on relation "orders"
-- Scope: checkout flow (orders + order_items buyer policies)
-- Run in Supabase SQL Editor as admin/postgres.

begin;

-- Resolve buyer ownership without triggering RLS recursion.
create or replace function public.is_order_owner(
  target_order_id uuid,
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
    from public.orders o
    where o.id = target_order_id
      and o.user_id = target_user_id
  );
$$;

revoke all on function public.is_order_owner(uuid, uuid) from public;
grant execute on function public.is_order_owner(uuid, uuid) to authenticated;

-- Recreate buyer policies on order_items without direct SELECT on orders.
drop policy if exists "order_items_buyer_select" on public.order_items;
create policy "order_items_buyer_select"
on public.order_items
for select
to authenticated
using (public.is_order_owner(order_items.order_id, auth.uid()));

drop policy if exists "order_items_buyer_insert" on public.order_items;
create policy "order_items_buyer_insert"
on public.order_items
for insert
to authenticated
with check (public.is_order_owner(order_items.order_id, auth.uid()));

commit;
