-- STAGE B rollback. Fail closed.
-- Does not restore orders_user_insert, order_items insert grants,
-- create_paid_order, refund_order_return, or anonymous categories write.
-- WARN: dropping the money triggers reopens client UPDATE of money columns.
-- Direct INSERT stays revoked, so old clients still cannot create orders.
-- Recreate the triggers from stage B as soon as the bad trigger revision is fixed.
-- Not applied.

drop trigger if exists trg_orders_money_authority on public.orders;
drop trigger if exists trg_order_items_money_authority on public.order_items;
drop function if exists public.orders_money_authority_guard();
drop function if exists public.order_items_money_authority_guard();

do $stage_b_rollback$
begin
  if to_regnamespace('seller_ops') is null then
    return;
  end if;
  execute 'drop trigger if exists trg_seller_ops_money_authority on seller_ops.orders';
  execute 'drop function if exists seller_ops.block_client_money()';
end
$stage_b_rollback$;

-- WARN: do not recreate orders_user_insert or grant insert back to authenticated.
-- WARN: do not recreate anonymous categories write policies.
-- Those statements are omitted on purpose.
