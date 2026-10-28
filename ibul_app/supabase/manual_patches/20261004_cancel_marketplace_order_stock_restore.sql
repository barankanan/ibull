-- Cancel unpaid marketplace orders and restore product stock in the same transaction.
-- Keeps the existing delete model. A second call finds no order and does not add stock again.
-- Does not create orders, change categories, or install Stage B triggers.

create or replace function public.cancel_marketplace_order_if_unpaid(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_owner uuid;
  v_payment text;
  v_product_id text;
  v_qty int;
begin
  if v_user is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;
  select user_id, payment_status
  into v_owner, v_payment
  from public.orders
  where id = p_order_id
  for update;
  if not found then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_owner is distinct from v_user then
    raise exception 'ORDER_OWNER_MISMATCH' using errcode = '42501';
  end if;
  if lower(coalesce(v_payment, 'pending')) not in ('pending', 'unpaid', '') then
    raise exception 'ORDER_NOT_CANCELLABLE' using errcode = '42501';
  end if;

  -- Lock item rows before aggregating so a second cancel cannot restore twice.
  perform 1
  from public.order_items
  where order_id = p_order_id
  order by product_id
  for update;

  for v_product_id, v_qty in
    select oi.product_id, sum(oi.quantity)::int
    from public.order_items oi
    where oi.order_id = p_order_id
      and nullif(btrim(oi.product_id), '') is not null
    group by oi.product_id
    order by oi.product_id
  loop
    if coalesce(v_qty, 0) <= 0 then
      continue;
    end if;
    update public.products
    set stock = coalesce(stock, 0) + v_qty
    where id = v_product_id;
    if not found then
      raise exception 'PRODUCT_NOT_FOUND' using errcode = 'P0002';
    end if;
  end loop;

  perform set_config('ibul.marketplace_order_rpc', 'on', true);
  delete from public.order_items where order_id = p_order_id;
  delete from public.orders where id = p_order_id and user_id = v_user;
end;
$$;


revoke all on function public.cancel_marketplace_order_if_unpaid(uuid) from public, anon;
grant execute on function public.cancel_marketplace_order_if_unpaid(uuid) to authenticated;
