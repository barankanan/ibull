-- DO NOT APPLY to production unless the operator names this file and says
-- Bu migration'ı production'a uygula.
--
-- Narrow follow-up to 20261105183000. Same 7-argument signature. The close
-- still inserts history, archives table_orders and closes orders in one
-- transaction, and still does not write table_payments.
--
-- When the table is already closed, a second caller — another device or a
-- retry whose first response was lost — returns the history row committed
-- in the last two minutes even if its session key differs. It does not
-- insert a second history row.
--
-- Live close_table_with_history keeps the 7-argument signature. Its history
-- insert omits table_order_history.original_order_id (uuid NOT NULL, no
-- default, no foreign key). An aggregate over zero table_orders still returns
-- one row, so PostgreSQL raises 23502 and the transaction rolls back.
--
-- This seller's open checks live in public.orders. public.table_orders has
-- no rows for the seller, which is why the board can show orders while
-- table_orders looks empty. Live history is one row per order: 62 rows,
-- 62 distinct original_order_id values, and archived_orders is either null
-- or a one-element array. original_order_id is that order's id, not a
-- stand-in for the other orders on the table. A close therefore inserts one
-- history row per open order. The first row keeps the caller session key so
-- the existing payment session still finds it. Further orders on the same
-- close use that key plus their own id, so a later same-session dedupe
-- cannot delete them. A missing id is not invented. An empty table inserts
-- nothing.
--
-- The same session key, or a history row that already names one of the open
-- order ids, does not insert a second history row. Nothing here deletes or
-- rewrites table_payments. restaurant_staff_may_operate(closeBill) stays the
-- gate. The orders update changes status and order_status to closed only.
-- ibul.marketplace_order_rpc is set for that update because orders_money_authority_guard
-- otherwise rejects rows whose order_items.seller_id is null, then turned off.
-- Money columns and payment_status are not written.

create or replace function public.close_table_with_history(
  p_seller_id uuid,
  p_table_number integer,
  p_payment_method text default 'cash',
  p_payment_note text default null,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_session_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path to public
as $function$
declare
  v_history_id uuid;
  v_grand_total numeric(12,2) := 0;
  v_session text;
  v_table_orders_count integer := 0;
  v_orders_updated integer := 0;
  v_actor_authorized boolean := false;
  v_actor_email text := '';
  v_actor_phone text := '';
  v_open_orders integer := 0;
  v_open_table_orders integer := 0;
  v_caller_session text := nullif(btrim(coalesce(p_session_key, '')), '');
  v_existing_history uuid;
  v_row_session text;
  v_row_history uuid;
  r record;
begin
  if p_seller_id is null or p_table_number <= 0 then
    raise exception 'Geçersiz parametre.' using errcode = '22023';
  end if;

  v_actor_email := lower(trim(coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    nullif(auth.jwt() ->> 'email', ''),
    nullif(auth.jwt() -> 'user_metadata' ->> 'email', ''),
    nullif((
      select u.email
      from public.users u
      where u.id = auth.uid()
      limit 1
    ), ''),
    ''
  )));
  v_actor_phone := trim(coalesce(
    nullif(current_setting('request.jwt.claim.phone', true), ''),
    nullif(auth.jwt() ->> 'phone', ''),
    nullif((
      select u.phone
      from public.users u
      where u.id = auth.uid()
      limit 1
    ), ''),
    ''
  ));

  select (
    auth.uid() = p_seller_id
    or exists (
      select 1
      from public.store_sub_admins sa
      where sa.store_id = p_seller_id
        and sa.status = 'active'
        and (
          (
            sa.email is not null
            and trim(sa.email) <> ''
            and v_actor_email <> ''
            and lower(trim(sa.email)) = v_actor_email
          )
          or (
            sa.phone is not null
            and trim(sa.phone) <> ''
            and v_actor_phone <> ''
            and trim(sa.phone) = v_actor_phone
          )
        )
        and (
          sa.permissions is null
          or cardinality(sa.permissions) = 0
          or 'manageOrders' = any(sa.permissions)
          or 'viewOrders' = any(sa.permissions)
        )
    )
  )
  into v_actor_authorized;

  perform public.restaurant_staff_may_operate(
    p_seller_id,
    'closeBill',
    p_table_number
  );

  perform 1
  from public.table_orders
  where seller_id = p_seller_id::text
    and table_number = p_table_number
    and coalesce(status, '') not in (
      'archived', 'closed', 'cancelled', 'canceled',
      'completed', 'complete', 'paid'
    )
  for update;

  perform 1
  from public.orders o
  where o.restaurant_id = p_seller_id
    and (o.order_type = 'table' or o.delivery_type = 'table')
    and o.table_id in (
      select id
      from public.store_tables
      where seller_id::text = p_seller_id::text
        and table_number = p_table_number
    )
    and coalesce(o.status, '') not in (
      'closed', 'paid', 'cancelled', 'canceled',
      'completed', 'complete', 'archived', 'payment_completed'
    )
  for update;

  select count(*) into v_open_table_orders
  from public.table_orders
  where seller_id = p_seller_id::text
    and table_number = p_table_number
    and coalesce(status, '') not in (
      'archived', 'closed', 'cancelled', 'canceled',
      'completed', 'complete', 'paid'
    );

  select count(*) into v_open_orders
  from public.orders o
  where o.restaurant_id = p_seller_id
    and (o.order_type = 'table' or o.delivery_type = 'table')
    and o.table_id in (
      select id
      from public.store_tables
      where seller_id::text = p_seller_id::text
        and table_number = p_table_number
    )
    and coalesce(o.status, '') not in (
      'closed', 'paid', 'cancelled', 'canceled',
      'completed', 'complete', 'archived', 'payment_completed'
    );

  if v_open_orders = 0 and v_open_table_orders = 0 then
    if v_caller_session is not null then
      select h.id, coalesce(h.grand_total, 0), h.session_key
      into v_history_id, v_grand_total, v_session
      from public.table_order_history h
      where h.seller_id = p_seller_id
        and h.table_number = p_table_number
        and h.session_key = v_caller_session
      order by h.closed_at desc
      limit 1;
    end if;
    if v_history_id is null then
      select h.id, coalesce(h.grand_total, 0), h.session_key
      into v_history_id, v_grand_total, v_session
      from public.table_order_history h
      where h.seller_id = p_seller_id
        and h.table_number = p_table_number
        and coalesce(h.closed_at, h.archived_at, h.created_at)
            > timezone('utc', now()) - interval '2 minutes'
      order by coalesce(h.closed_at, h.archived_at, h.created_at) desc
      limit 1;
    end if;
    return jsonb_build_object(
      'history_id', v_history_id,
      'grand_total', coalesce(v_grand_total, 0),
      'session_key', v_caller_session,
      'table_orders_updated', 0,
      'orders_updated', 0
    );
  end if;

  v_grand_total := 0;

  for r in
    select src.id, src.row_total, src.payload
    from (
      select
        o.id,
        coalesce(o.total_amount, 0)::numeric(12,2) as row_total,
        to_jsonb(o) as payload,
        o.created_at as sort_at,
        0 as source_rank
      from public.orders o
      where o.restaurant_id = p_seller_id
        and (o.order_type = 'table' or o.delivery_type = 'table')
        and o.table_id in (
          select id
          from public.store_tables
          where seller_id::text = p_seller_id::text
            and table_number = p_table_number
        )
        and coalesce(o.status, '') not in (
          'closed', 'paid', 'cancelled', 'canceled',
          'completed', 'complete', 'archived', 'payment_completed'
        )
      union all
      select
        t.id,
        coalesce((
          select sum(
            coalesce(
              nullif(item ->> 'line_total', '')::numeric,
              coalesce(nullif(item ->> 'price', '')::numeric, 0)
              * coalesce(nullif(item ->> 'quantity', '')::numeric, 1)
            )
          )
          from jsonb_array_elements(coalesce(t.items, '[]'::jsonb)) as item
        ), 0)::numeric(12,2),
        to_jsonb(t),
        t.created_at,
        1
      from public.table_orders t
      where v_open_orders = 0
        and t.seller_id = p_seller_id::text
        and t.table_number = p_table_number
        and coalesce(t.status, '') not in (
          'archived', 'closed', 'cancelled', 'canceled',
          'completed', 'complete', 'paid'
        )
    ) src
    order by src.source_rank, src.sort_at, src.id
  loop
    v_existing_history := null;
    select h.id
    into v_existing_history
    from public.table_order_history h
    where h.seller_id = p_seller_id
      and h.table_number = p_table_number
      and h.original_order_id = r.id
    limit 1;

    if v_existing_history is not null then
      if v_history_id is null then
        v_history_id := v_existing_history;
        select h.session_key
        into v_session
        from public.table_order_history h
        where h.id = v_existing_history;
      end if;
      continue;
    end if;

    if v_caller_session is null then
      v_row_session := 'history-' || gen_random_uuid()::text;
    elsif v_history_id is null then
      v_row_session := v_caller_session;
    else
      v_row_session := v_caller_session || ':' || r.id::text;
    end if;

    insert into public.table_order_history (
      original_order_id,
      seller_id,
      table_number,
      session_key,
      payment_method,
      payment_note,
      waiter_id,
      waiter_name,
      grand_total,
      archived_orders,
      archived_at
    ) values (
      r.id,
      p_seller_id,
      p_table_number,
      v_row_session,
      p_payment_method,
      p_payment_note,
      p_waiter_id,
      p_waiter_name,
      r.row_total,
      jsonb_build_array(r.payload),
      timezone('utc', now())
    )
    returning id into v_row_history;

    v_grand_total := v_grand_total + r.row_total;
    if v_history_id is null then
      v_history_id := v_row_history;
      v_session := v_row_session;
    end if;
  end loop;

  if v_history_id is null then
    raise exception
      'Masa geçmiş kaydı için gerçek sipariş bulunamadı.'
      using errcode = '23502';
  end if;

  with updated as (
    update public.table_orders
    set status = 'archived',
        updated_at = timezone('utc', now())
    where seller_id = p_seller_id::text
      and table_number = p_table_number
      and coalesce(status, '') not in (
        'archived', 'closed', 'cancelled', 'canceled',
        'completed', 'complete', 'paid'
      )
    returning id
  )
  select count(*) into v_table_orders_count from updated;

  perform set_config('ibul.marketplace_order_rpc', 'on', true);
  with target_ids as (
    select id
    from public.store_tables
    where seller_id::text = p_seller_id::text
      and table_number = p_table_number
  ),
  closed_orders as (
    update public.orders o
    set status = 'closed',
        order_status = 'closed',
        updated_at = timezone('utc', now())
    where o.restaurant_id = p_seller_id
      and (o.order_type = 'table' or o.delivery_type = 'table')
      and o.table_id in (select id from target_ids)
      and coalesce(o.status, '') not in (
        'closed', 'paid', 'cancelled', 'canceled',
        'completed', 'complete', 'archived', 'payment_completed'
      )
    returning o.id
  )
  select count(*) into v_orders_updated from closed_orders;
  perform set_config('ibul.marketplace_order_rpc', 'off', true);

  return jsonb_build_object(
    'history_id', v_history_id,
    'grand_total', v_grand_total,
    'session_key', v_session,
    'table_orders_updated', v_table_orders_count,
    'orders_updated', v_orders_updated
  );
end;
$function$;
