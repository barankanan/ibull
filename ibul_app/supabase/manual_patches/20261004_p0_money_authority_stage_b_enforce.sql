-- STAGE B enforcement. Apply only after the new web build is live and smoke-tested.
-- Idempotent: drop-if-exists then create.
-- Does not restore direct inserts. Running twice keeps enforcement in place.
-- Not applied to the remote database.

-- ---------------------------------------------------------------------------
-- Direct client inserts cannot create monetary rows
-- ---------------------------------------------------------------------------

drop policy if exists "orders_user_insert" on public.orders;
drop policy if exists "orders_restaurant_insert" on public.orders;
drop policy if exists "order_items_buyer_insert" on public.order_items;
drop policy if exists "order_items_restaurant_insert" on public.order_items;

revoke insert on table public.orders from anon, authenticated;
revoke insert on table public.order_items from anon, authenticated;

create or replace function public.orders_money_authority_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rpc boolean := current_setting('ibul.marketplace_order_rpc', true) = 'on';
  v_webhook boolean := current_setting('ibul.payment_webhook', true) = 'on';
  v_service boolean := coalesce(auth.role(), '') = 'service_role';
  v_allowed boolean := false;
  v_courier boolean := false;
begin
  if v_rpc or v_service then
    return new;
  end if;

  if tg_op = 'INSERT' then
    raise exception 'ORDERS_INSERT_RPC_ONLY' using errcode = '42501';
  end if;

  if auth.uid() is not null then
    if to_regprocedure('public.is_ihiz_courier_user(uuid)') is not null then
      execute 'select public.is_ihiz_courier_user($1)' into v_courier using auth.uid();
    end if;
    v_allowed := old.user_id = auth.uid()
      or coalesce(public.is_admin_user(auth.uid()), false)
      or coalesce(v_courier, false);
    if to_regprocedure('public.can_access_order_as_seller(uuid,uuid)') is not null then
      v_allowed := v_allowed or public.can_access_order_as_seller(old.id, auth.uid());
    end if;
    if not v_allowed then
      raise exception 'ORDER_UPDATE_DENIED' using errcode = '42501';
    end if;
  end if;

  if new.user_id is distinct from old.user_id
     or new.subtotal_amount is distinct from old.subtotal_amount
     or new.shipping_amount is distinct from old.shipping_amount
     or new.discount_amount is distinct from old.discount_amount
     or new.total_amount is distinct from old.total_amount
     or new.customer_delivery_fee is distinct from old.customer_delivery_fee
     or new.seller_delivery_fee is distinct from old.seller_delivery_fee
     or new.total_delivery_fee is distinct from old.total_delivery_fee
  then
    raise exception 'ORDER_MONEY_COLUMNS_LOCKED' using errcode = '42501';
  end if;

  if new.payment_status is distinct from old.payment_status
     and lower(coalesce(new.payment_status, '')) in ('paid', 'refunded')
     and not v_webhook
  then
    raise exception 'CLIENT_PAYMENT_STATUS_REJECTED' using errcode = '42501';
  end if;

  if lower(coalesce(new.status, '')) in ('paid', 'refunded')
     and lower(coalesce(old.status, '')) is distinct from lower(coalesce(new.status, ''))
     and not v_webhook
  then
    raise exception 'CLIENT_PAYMENT_STATUS_REJECTED' using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_orders_money_authority on public.orders;
create trigger trg_orders_money_authority
  before insert or update on public.orders
  for each row
  execute function public.orders_money_authority_guard();

drop function if exists public.create_order_from_cart(
  text, jsonb, jsonb, text, text, text, text, text, numeric
);

drop trigger if exists trg_order_items_money_authority on public.order_items;
create or replace function public.order_items_money_authority_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rpc boolean := current_setting('ibul.marketplace_order_rpc', true) = 'on';
begin
  if v_rpc or coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;
  if tg_op = 'INSERT' then
    raise exception 'ORDERS_INSERT_RPC_ONLY' using errcode = '42501';
  end if;
  if new.unit_price is distinct from old.unit_price
     or new.total_price is distinct from old.total_price
     or new.quantity is distinct from old.quantity
     or new.order_id is distinct from old.order_id
     or new.seller_id is distinct from old.seller_id
  then
    raise exception 'ORDER_MONEY_COLUMNS_LOCKED' using errcode = '42501';
  end if;
  if lower(coalesce(new.status, '')) in ('refunded', 'paid')
     and lower(coalesce(old.status, '')) is distinct from lower(coalesce(new.status, ''))
     and current_setting('ibul.payment_webhook', true) is distinct from 'on'
  then
    raise exception 'CLIENT_REFUND_REJECTED' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger trg_order_items_money_authority
  before insert or update on public.order_items
  for each row
  execute function public.order_items_money_authority_guard();

-- ---------------------------------------------------------------------------
-- categories bucket: public read, admin write via users.role
-- ---------------------------------------------------------------------------

drop policy if exists "categories_public_insert" on storage.objects;
drop policy if exists "categories_public_update" on storage.objects;
drop policy if exists "categories_public_delete" on storage.objects;
-- Defensive. The emergency categories patch may already have dropped these.
drop policy if exists "categories_auth_insert" on storage.objects;
drop policy if exists "categories_auth_update" on storage.objects;
drop policy if exists "categories_auth_delete" on storage.objects;
drop policy if exists "categories_admin_insert" on storage.objects;
drop policy if exists "categories_admin_update" on storage.objects;
drop policy if exists "categories_admin_delete" on storage.objects;

drop policy if exists "categories_public_read" on storage.objects;
create policy "categories_public_read"
on storage.objects
for select
to public
using (bucket_id = 'categories');

create policy "categories_admin_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'categories'
  and public.is_admin_user(auth.uid())
);

create policy "categories_admin_update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'categories'
  and public.is_admin_user(auth.uid())
)
with check (
  bucket_id = 'categories'
  and public.is_admin_user(auth.uid())
);

create policy "categories_admin_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'categories'
  and public.is_admin_user(auth.uid())
);


do $seller_ops_stage_b$
begin
  if to_regnamespace('seller_ops') is null then
    raise notice 'seller_ops schema missing; seller_ops enforcement skipped';
    return;
  end if;
  execute $sql$
    drop function if exists seller_ops.create_paid_order(
      uuid, uuid, text, text, text, numeric, numeric, numeric, jsonb, text, jsonb
    );
    drop function if exists seller_ops.refund_order_return(
      uuid, uuid, text, text, numeric, boolean, jsonb
    );

    drop policy if exists orders_insert_buyer on seller_ops.orders;
    drop policy if exists order_items_insert_by_related_order on seller_ops.order_items;
    revoke insert on table seller_ops.orders from anon, authenticated;
    revoke insert on table seller_ops.order_items from anon, authenticated;
  $sql$;

  execute $sql$
    create or replace function seller_ops.block_client_money()
    returns trigger
    language plpgsql
    security definer
    set search_path = seller_ops, public
    as $fn$
    declare
      v_rpc boolean := current_setting('ibul.seller_ops_rpc', true) = 'on';
      v_webhook boolean := current_setting('ibul.payment_webhook', true) = 'on';
    begin
      if v_rpc or coalesce(auth.role(), '') = 'service_role' then
        if tg_op = 'UPDATE'
           and new.payment_status in ('PAID', 'REFUNDED')
           and old.payment_status is distinct from new.payment_status
           and not v_webhook
           and coalesce(auth.role(), '') <> 'service_role'
        then
          raise exception 'CLIENT_PAYMENT_STATUS_REJECTED' using errcode = '42501';
        end if;
        return new;
      end if;
      if tg_op = 'INSERT' then
        raise exception 'SELLER_OPS_INSERT_RPC_ONLY' using errcode = '42501';
      end if;
      if new.buyer_user_id is distinct from old.buyer_user_id
         or new.subtotal is distinct from old.subtotal
         or new.shipping_fee is distinct from old.shipping_fee
         or new.commission_rate is distinct from old.commission_rate
         or new.commission_amount is distinct from old.commission_amount
         or new.net_amount is distinct from old.net_amount
         or new.payment_status is distinct from old.payment_status
      then
        raise exception 'ORDER_MONEY_COLUMNS_LOCKED' using errcode = '42501';
      end if;
      if new.status = 'REFUNDED' and old.status is distinct from 'REFUNDED' then
        raise exception 'CLIENT_REFUND_REJECTED' using errcode = '42501';
      end if;
      return new;
    end;
    $fn$;

    drop trigger if exists trg_seller_ops_money_authority on seller_ops.orders;
    create trigger trg_seller_ops_money_authority
      before insert or update on seller_ops.orders
      for each row
      execute function seller_ops.block_client_money();
  $sql$;

end
$seller_ops_stage_b$;
