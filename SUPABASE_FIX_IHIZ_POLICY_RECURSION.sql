-- Fix for: PostgresException code 42P17
-- "infinite recursion detected in policy for relation orders"
--
-- Apply this in Supabase SQL Editor (admin).

begin;

-- Ensure helper exists
create or replace function public.is_ihiz_courier_user(target_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = target_user_id
      and coalesce(u.is_ihiz_approved, false) = true
  ) or exists (
    select 1
    from public.ihiz_courier_applications app
    where app.user_id = target_user_id
      and lower(coalesce(app.status, '')) = 'approved'
  );
$$;

grant execute on function public.is_ihiz_courier_user(uuid) to authenticated;

-- Recreate IHIZ policies without orders<->order_items recursive checks.
drop policy if exists "IHIZ couriers can read pool order items" on public.order_items;
create policy "IHIZ couriers can read pool order items"
on public.order_items
for select
to authenticated
using (
  public.is_ihiz_courier_user(auth.uid())
  and exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and (
        lower(coalesce(o.delivery_type, '')) like '%ihiz%'
        or o.order_number like 'IBUL-EXT-%'
      )
  )
  and lower(coalesce(status, '')) in ('ready_to_ship', 'out_for_delivery')
);

drop policy if exists "IHIZ couriers can update pool order items" on public.order_items;
create policy "IHIZ couriers can update pool order items"
on public.order_items
for update
to authenticated
using (
  public.is_ihiz_courier_user(auth.uid())
  and exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and (
        lower(coalesce(o.delivery_type, '')) like '%ihiz%'
        or o.order_number like 'IBUL-EXT-%'
      )
  )
  and lower(coalesce(status, '')) in ('ready_to_ship', 'out_for_delivery')
)
with check (
  public.is_ihiz_courier_user(auth.uid())
  and exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and (
        lower(coalesce(o.delivery_type, '')) like '%ihiz%'
        or o.order_number like 'IBUL-EXT-%'
      )
  )
  and lower(coalesce(status, '')) in ('out_for_delivery', 'delivered')
);

drop policy if exists "IHIZ couriers can read related orders" on public.orders;
create policy "IHIZ couriers can read related orders"
on public.orders
for select
to authenticated
using (
  public.is_ihiz_courier_user(auth.uid())
  and (
    lower(coalesce(delivery_type, '')) like '%ihiz%'
    or order_number like 'IBUL-EXT-%'
  )
);

drop policy if exists "IHIZ couriers can update related orders" on public.orders;
create policy "IHIZ couriers can update related orders"
on public.orders
for update
to authenticated
using (
  public.is_ihiz_courier_user(auth.uid())
  and (
    lower(coalesce(delivery_type, '')) like '%ihiz%'
    or order_number like 'IBUL-EXT-%'
  )
)
with check (
  public.is_ihiz_courier_user(auth.uid())
  and (
    lower(coalesce(delivery_type, '')) like '%ihiz%'
    or order_number like 'IBUL-EXT-%'
  )
);

drop policy if exists "IHIZ couriers can insert order item history" on public.order_item_status_history;
create policy "IHIZ couriers can insert order item history"
on public.order_item_status_history
for insert
to authenticated
with check (
  public.is_ihiz_courier_user(auth.uid())
  and exists (
    select 1
    from public.order_items oi
    where oi.id = order_item_status_history.order_item_id
      and lower(coalesce(oi.status, '')) in ('ready_to_ship', 'out_for_delivery', 'delivered')
  )
);

commit;
