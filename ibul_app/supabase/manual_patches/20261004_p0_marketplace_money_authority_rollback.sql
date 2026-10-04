-- Controlled rollback for 20261004_p0_marketplace_money_authority.sql.
-- Not applied. Do not supabase db push.
--
-- WARN: This script removes the new RPC and money triggers. Checkout and
-- seller external cargo will fail closed because the app calls those RPCs.
--
-- WARN: Restoring orders_user_insert / order_items buyer insert / public
-- categories write would reopen client price and anonymous storage writes.
-- Those statements are intentionally absent. Do not paste them back from
-- SUPABASE_CATEGORIES_STORAGE.sql history or 20241027120000_harden_orders.sql.

drop trigger if exists trg_orders_money_authority on public.orders;
drop trigger if exists trg_order_items_money_authority on public.order_items;
drop function if exists public.orders_money_authority_guard();
drop function if exists public.order_items_money_authority_guard();

drop function if exists public.create_marketplace_order(
  jsonb, jsonb, jsonb, uuid, text, text, text, text, text, text
);
drop function if exists public.create_seller_external_cargo_order(
  jsonb, text, text, text, text, text, text, double precision, double precision,
  text, text, text, text, text
);
drop function if exists public.cancel_marketplace_order_if_unpaid(uuid);

-- seller_ops replacements are removed only when that schema exists.
-- The old create_paid_order and refund_order_return bodies are not restored.
do $rollback_seller_ops$
begin
  if to_regnamespace('seller_ops') is null then
    return;
  end if;
  execute 'drop trigger if exists trg_seller_ops_money_authority on seller_ops.orders';
  execute 'drop function if exists seller_ops.block_client_money()';
  execute 'drop function if exists seller_ops.create_pending_order(uuid, uuid, jsonb, jsonb, text, text)';
  execute 'drop function if exists seller_ops.request_return_refund(uuid, uuid)';
  execute 'drop function if exists seller_ops.confirm_provider_refund(uuid, text, text)';
end
$rollback_seller_ops$;
