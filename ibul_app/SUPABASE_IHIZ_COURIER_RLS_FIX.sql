begin;

-- Approved ihiz courier check helper.
create or replace function public.is_ihiz_approved_courier(
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
    from public.ihiz_courier_applications app
    where app.user_id = target_user_id
      and lower(coalesce(app.status, '')) = 'approved'
  );
$$;

revoke all on function public.is_ihiz_approved_courier(uuid) from public;
grant execute on function public.is_ihiz_approved_courier(uuid) to authenticated;

-- Courier can view ihiz-related order items.
drop policy if exists "order_items_courier_select" on public.order_items;
create policy "order_items_courier_select"
on public.order_items
for select
to authenticated
using (
  public.is_ihiz_approved_courier(auth.uid())
  and (
    lower(coalesce(order_items.cargo_company, '')) like '%hiz%'
    or exists (
      select 1
      from public.orders o
      where o.id = order_items.order_id
        and lower(coalesce(o.delivery_type, '')) like '%ihiz%'
    )
  )
);

-- Courier can update ihiz-related order item delivery state.
drop policy if exists "order_items_courier_update" on public.order_items;
create policy "order_items_courier_update"
on public.order_items
for update
to authenticated
using (
  public.is_ihiz_approved_courier(auth.uid())
  and (
    lower(coalesce(order_items.cargo_company, '')) like '%hiz%'
    or exists (
      select 1
      from public.orders o
      where o.id = order_items.order_id
        and lower(coalesce(o.delivery_type, '')) like '%ihiz%'
    )
  )
)
with check (
  public.is_ihiz_approved_courier(auth.uid())
  and (
    lower(coalesce(order_items.cargo_company, '')) like '%hiz%'
    or exists (
      select 1
      from public.orders o
      where o.id = order_items.order_id
        and lower(coalesce(o.delivery_type, '')) like '%ihiz%'
    )
  )
);

-- Courier can read ihiz-related parent orders.
drop policy if exists "orders_courier_select" on public.orders;
create policy "orders_courier_select"
on public.orders
for select
to authenticated
using (
  public.is_ihiz_approved_courier(auth.uid())
  and (
    lower(coalesce(orders.delivery_type, '')) like '%ihiz%'
    or exists (
      select 1
      from public.order_items oi
      where oi.order_id = orders.id
        and lower(coalesce(oi.cargo_company, '')) like '%hiz%'
    )
  )
);

-- Courier can update ihiz-related parent order status.
drop policy if exists "orders_courier_update" on public.orders;
create policy "orders_courier_update"
on public.orders
for update
to authenticated
using (
  public.is_ihiz_approved_courier(auth.uid())
  and (
    lower(coalesce(orders.delivery_type, '')) like '%ihiz%'
    or exists (
      select 1
      from public.order_items oi
      where oi.order_id = orders.id
        and lower(coalesce(oi.cargo_company, '')) like '%hiz%'
    )
  )
)
with check (
  public.is_ihiz_approved_courier(auth.uid())
  and (
    lower(coalesce(orders.delivery_type, '')) like '%ihiz%'
    or exists (
      select 1
      from public.order_items oi
      where oi.order_id = orders.id
        and lower(coalesce(oi.cargo_company, '')) like '%hiz%'
    )
  )
);

-- Courier can append tracking history for ihiz deliveries.
drop policy if exists "order_item_status_history_courier_insert" on public.order_item_status_history;
create policy "order_item_status_history_courier_insert"
on public.order_item_status_history
for insert
to authenticated
with check (
  public.is_ihiz_approved_courier(auth.uid())
  and exists (
    select 1
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where oi.id = order_item_status_history.order_item_id
      and (
        lower(coalesce(oi.cargo_company, '')) like '%hiz%'
        or lower(coalesce(o.delivery_type, '')) like '%ihiz%'
      )
  )
);

commit;
