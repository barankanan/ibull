-- STAGE A rollback. Drops only the functions added by stage A.
-- Does not change insert policies. An old client that still inserts keeps working.
-- The new client loses its RPC and fails closed until stage A is applied again.
-- Not applied.

drop function if exists public.request_marketplace_refund(uuid);
drop function if exists public.create_marketplace_order(
  jsonb, jsonb, jsonb, uuid, text, text, text, text, text, text
);
drop function if exists public.create_seller_external_cargo_order(
  jsonb, text, text, text, text, text, text, double precision, double precision,
  text, text, text, text, text
);
drop function if exists public.cancel_marketplace_order_if_unpaid(uuid);
drop function if exists public.marketplace_server_shipping_fee(uuid, jsonb);
drop function if exists public.marketplace_haversine_km(double precision, double precision, double precision, double precision);
drop function if exists public.marketplace_payload_forbidden_key(jsonb);

do $stage_a_rollback$
begin
  if to_regnamespace('seller_ops') is null then
    return;
  end if;
  execute 'drop function if exists seller_ops.create_pending_order(uuid, uuid, jsonb, jsonb, text, text)';
  execute 'drop function if exists seller_ops.request_return_refund(uuid, uuid)';
  execute 'drop function if exists seller_ops.confirm_provider_refund(uuid, text, text)';
end
$stage_a_rollback$;
