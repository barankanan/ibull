-- DRAFT — DO NOT APPLY. Üretime uygulamak için operatörün dosyayı adıyla
-- anıp onay vermesi gerekir. Üretimde şu an çalışan close_table_with_history
-- (md5 ae2bbeeec475e796f5683273b90127c0) order_items'ı hiç okumaz.
--
-- Düzeltme: kapanış snapshot'ına sipariş kalemlerini (archived_orders[0].items)
-- ekler ve başlık toplamı 0 iken kalem birim fiyatlarından türetilen tutarı
-- kullanır. Geçmiş (zaten kapanmış) kayıtları DEĞİŞTİRMEZ; onlar için istemci
-- order_items'ı salt-okunur okuyup "kalemlerden" etiketiyle gösterir.
-- Asıl kaynak: 20261112234500_bill_line_price_authority.sql de üretimde yok;
-- o uygulanana kadar yeni siparişler total_price=0 / başlık 0,00 yazılır.

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
        greatest(
          coalesce(o.total_amount, 0),
          coalesce((
            select sum(coalesce(nullif(oi.line_total, 0), nullif(oi.total_price, 0),
                                oi.unit_price * oi.quantity, 0))
            from public.order_items oi where oi.order_id = o.id
          ), 0)
        )::numeric(12,2) as row_total,
        to_jsonb(o) || jsonb_build_object('items', coalesce((
          select jsonb_agg(jsonb_build_object(
            'name', oi.product_name,
            'quantity', oi.quantity,
            'price', oi.unit_price,
            'line_total', coalesce(nullif(oi.line_total, 0), nullif(oi.total_price, 0),
                                   oi.unit_price * oi.quantity),
            'notes', oi.item_note,
            'product_id', oi.product_id
          ) order by oi.created_at)
          from public.order_items oi where oi.order_id = o.id
        ), '[]'::jsonb)) as payload,
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
