-- Fix: Allow active waiter/sub-admin accounts to call
-- create_table_order_with_print_jobs on behalf of their restaurant.
--
-- Root cause: the previous permission check was:
--   if auth.uid() <> p_restaurant_id then raise exception ...
-- This blocked all waiter sub-accounts (their auth.uid() ≠ seller_id).
--
-- Fix: extend the check to also allow users who have an active record in
-- store_sub_admins for the target restaurant (matched by email or phone).
--
-- Run in Supabase SQL Editor (safe to re-run: uses create or replace).

create or replace function public.create_table_order_with_print_jobs(
  p_restaurant_id uuid,
  p_table_number integer,
  p_items jsonb,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_notes text default null,
  p_job_type text default 'new_order',
  p_order_type text default 'table'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id uuid;
  v_order_number text;
  v_table_id uuid;
  v_restaurant_name text;
  v_table_name text;
  v_waiter_name text;
  v_waiter_ref uuid;

  v_item jsonb;
  v_item_qty integer;
  v_item_unit_price numeric(12,2);
  v_item_line_total numeric(12,2);
  v_item_note text;
  v_item_name text;
  v_item_product_id text;
  v_item_station_id uuid;
  v_item_routing_enabled boolean;
  v_item_inserted_id uuid;

  v_product record;

  v_group record;
  v_printer_id uuid;
  v_printer_name text;
  v_printer_code text;
  v_printer_connection_type text;
  v_printer_ip_address text;
  v_printer_port integer;
  v_printer_device_identifier text;
  v_printer_paper_width_mm integer;
  v_items_payload jsonb;
  v_job_payload jsonb;
  v_print_job_id uuid;

  v_subtotal numeric(12,2) := 0;
  v_print_job_count integer := 0;
  v_print_job_ids jsonb := '[]'::jsonb;
begin
  -- ── Auth guard ────────────────────────────────────────────────────────────
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  if auth.uid() <> p_restaurant_id then
    -- Allow active waiter / sub-admin accounts for this restaurant.
    -- Matched via store_sub_admins.email = users.email
    -- OR store_sub_admins.phone = users.phone.
    if not exists (
      select 1
      from public.store_sub_admins sa
      join public.users u
        on (
          (
            sa.email is not null
            and trim(sa.email) <> ''
            and lower(trim(u.email)) = lower(trim(sa.email))
          )
          or (
            sa.phone is not null
            and trim(sa.phone) <> ''
            and trim(coalesce(u.phone, '')) = trim(sa.phone)
          )
        )
      where sa.store_id = p_restaurant_id
        and u.id         = auth.uid()
        and sa.status    = 'active'
    ) then
      raise exception 'Bu restoran için işlem yetkiniz yok.' using errcode = '42501';
    end if;
  end if;

  -- ── Input validation ──────────────────────────────────────────────────────
  if p_items is null
    or jsonb_typeof(p_items) <> 'array'
    or jsonb_array_length(p_items) = 0 then
    raise exception 'Sipariş kalemleri boş olamaz.' using errcode = '22023';
  end if;

  if p_job_type not in ('new_order', 'add_item', 'cancel_item', 'reprint') then
    raise exception 'Geçersiz job_type: %', p_job_type using errcode = '22023';
  end if;

  -- ── Restaurant & table lookup ─────────────────────────────────────────────
  select business_name
  into v_restaurant_name
  from public.stores
  where seller_id = p_restaurant_id
  limit 1;

  if v_restaurant_name is null then
    raise exception 'Restoran bulunamadı.' using errcode = '22023';
  end if;

  select id
  into v_table_id
  from public.store_tables
  where seller_id = p_restaurant_id
    and table_number = p_table_number
    and is_active = true
  order by created_at desc
  limit 1;

  v_table_name := format('Masa %s', p_table_number);
  v_waiter_name := coalesce(nullif(trim(coalesce(p_waiter_name, '')), ''), 'Garson');
  v_waiter_ref := null;
  select u.id into v_waiter_ref
  from public.users u
  where u.id = coalesce(p_waiter_id, auth.uid())
  limit 1;

  v_order_number := format(
    'TBL-%s-%s',
    to_char(now(), 'YYYYMMDDHH24MISS'),
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6))
  );

  -- ── Create order ──────────────────────────────────────────────────────────
  insert into public.orders (
    user_id,
    order_number,
    status,
    payment_method,
    delivery_type,
    subtotal_amount,
    shipping_amount,
    discount_amount,
    total_amount,
    currency,
    restaurant_id,
    table_id,
    waiter_id,
    order_status,
    order_type,
    notes
  )
  values (
    auth.uid(),
    v_order_number,
    'confirmed',
    'cash',
    'table',
    0,
    0,
    0,
    0,
    'TRY',
    p_restaurant_id,
    v_table_id,
    v_waiter_ref,
    'sent',
    coalesce(nullif(trim(coalesce(p_order_type, '')), ''), 'table'),
    nullif(trim(coalesce(p_notes, '')), '')
  )
  returning id into v_order_id;

  -- ── Create order items ────────────────────────────────────────────────────
  for v_item in
    select value from jsonb_array_elements(p_items)
  loop
    v_item_product_id := nullif(trim(coalesce(v_item ->> 'product_id', '')), '');
    v_item_name := coalesce(nullif(trim(coalesce(v_item ->> 'name', '')), ''), 'Ürün');
    v_item_note := nullif(trim(coalesce(v_item ->> 'notes', '')), '');

    v_item_qty := greatest(
      coalesce(nullif(regexp_replace(coalesce(v_item ->> 'quantity', '1'), '[^0-9]', '', 'g'), '')::integer, 1),
      1
    );

    if (v_item ? 'price') and jsonb_typeof(v_item -> 'price') = 'number' then
      v_item_unit_price := coalesce((v_item ->> 'price')::numeric, 0);
    else
      v_item_unit_price := public.parse_price_numeric(v_item ->> 'price');
    end if;

    select
      p.id::text as product_id_text,
      p.name,
      p.station_id,
      coalesce(p.printer_routing_enabled, true) as routing_enabled,
      coalesce(p.discount_price, p.price, 0)::numeric as fallback_price
    into v_product
    from public.products p
    where p.seller_id = p_restaurant_id
      and (
        (v_item_product_id is not null and p.id::text = v_item_product_id)
        or (v_item_product_id is null and lower(p.name) = lower(v_item_name))
      )
    limit 1;

    if found then
      v_item_product_id := coalesce(v_item_product_id, v_product.product_id_text);
      v_item_name := coalesce(nullif(v_item_name, 'Ürün'), v_product.name, v_item_name);
      v_item_station_id := coalesce(
        public.try_uuid(v_item ->> 'station_id'),
        v_product.station_id
      );
      v_item_routing_enabled := v_product.routing_enabled;
      if v_item_unit_price <= 0 then
        v_item_unit_price := coalesce(v_product.fallback_price, 0);
      end if;
    else
      v_item_station_id := public.try_uuid(v_item ->> 'station_id');
      v_item_routing_enabled := true;
    end if;

    v_item_line_total := round((v_item_qty::numeric * coalesce(v_item_unit_price, 0))::numeric, 2);
    v_subtotal := v_subtotal + v_item_line_total;

    insert into public.order_items (
      order_id,
      seller_id,
      product_id,
      product_name,
      quantity,
      unit_price,
      total_price,
      line_total,
      status,
      station_id,
      item_note,
      kitchen_status,
      sent_to_kitchen_at
    )
    values (
      v_order_id,
      p_restaurant_id,
      v_item_product_id,
      v_item_name,
      v_item_qty,
      coalesce(v_item_unit_price, 0),
      v_item_line_total,
      v_item_line_total,
      'new',
      v_item_station_id,
      v_item_note,
      case when v_item_routing_enabled then 'pending' else 'skipped' end,
      null
    )
    returning id into v_item_inserted_id;
  end loop;

  update public.orders
  set subtotal_amount = v_subtotal,
      total_amount = v_subtotal,
      order_status = 'sent'
  where id = v_order_id;

  -- ── Create print_jobs grouped by station ──────────────────────────────────
  for v_group in
    select
      oi.station_id,
      coalesce(s.name, 'Genel') as station_name,
      coalesce(s.code, 'GENEL') as station_code
    from public.order_items oi
    left join public.products p
      on p.id::text = oi.product_id
      and p.seller_id = p_restaurant_id
    left join public.stations s
      on s.id = oi.station_id
    where oi.order_id = v_order_id
      and coalesce(p.printer_routing_enabled, true)
    group by oi.station_id, s.name, s.code
  loop
    if v_group.station_id is not null then
      select
        sp.printer_id,
        pr.name as printer_name,
        pr.code as printer_code,
        pr.connection_type,
        pr.ip_address,
        pr.port,
        pr.device_identifier,
        pr.paper_width_mm
      into
        v_printer_id,
        v_printer_name,
        v_printer_code,
        v_printer_connection_type,
        v_printer_ip_address,
        v_printer_port,
        v_printer_device_identifier,
        v_printer_paper_width_mm
      from public.station_printers sp
      join public.printers pr
        on pr.id = sp.printer_id
       and pr.is_active = true
      where sp.station_id = v_group.station_id
      order by sp.is_primary desc, sp.created_at asc
      limit 1;
    else
      v_printer_id := null;
      v_printer_name := null;
      v_printer_code := null;
      v_printer_connection_type := null;
      v_printer_ip_address := null;
      v_printer_port := null;
      v_printer_device_identifier := null;
      v_printer_paper_width_mm := null;
      -- Skip the null-station "Genel" print job when the order has at least
      -- one item assigned to a named station.
      if exists (
        select 1
        from public.order_items oi2
        where oi2.order_id = v_order_id
          and oi2.station_id is not null
      ) then
        continue;
      end if;
    end if;

    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'order_item_id', oi.id,
          'product_name', oi.product_name,
          'quantity', oi.quantity,
          'item_note', oi.item_note,
          'unit_price', oi.unit_price,
          'amount_label', coalesce((
            select elem ->> 'amount_label'
            from jsonb_array_elements(p_items) elem
            where (elem ->> 'product_id') = oi.product_id::text
               or lower(elem ->> 'name') = lower(oi.product_name)
            limit 1
          ), ''),
          'plates', coalesce((
            select elem -> 'plates'
            from jsonb_array_elements(p_items) elem
            where (elem ->> 'product_id') = oi.product_id::text
               or lower(elem ->> 'name') = lower(oi.product_name)
            limit 1
          ), '[]'::jsonb),
          'service_children', coalesce((
            select elem -> 'service_children'
            from jsonb_array_elements(p_items) elem
            where (elem ->> 'product_id') = oi.product_id::text
               or lower(elem ->> 'name') = lower(oi.product_name)
            limit 1
          ), '[]'::jsonb)
        )
        order by oi.created_at asc
      ),
      '[]'::jsonb
    )
    into v_items_payload
    from public.order_items oi
    left join public.products p
      on p.id::text = oi.product_id
      and p.seller_id = p_restaurant_id
    where oi.order_id = v_order_id
      and oi.station_id is not distinct from v_group.station_id
      and coalesce(p.printer_routing_enabled, true);

    if jsonb_array_length(v_items_payload) = 0 then
      continue;
    end if;

    v_job_payload := jsonb_build_object(
      'restaurant_id', p_restaurant_id,
      'restaurant_name', v_restaurant_name,
      'order_id', v_order_id,
      'order_no', v_order_number,
      'table_name', v_table_name,
      'waiter_name', v_waiter_name,
      'station_id', v_group.station_id,
      'station_name', v_group.station_name,
      'station_code', v_group.station_code,
      'printer_id', v_printer_id,
      'printer_name', v_printer_name,
      'printer_code', v_printer_code,
      'printer_connection_type', v_printer_connection_type,
      'printer_ip_address', v_printer_ip_address,
      'printer_port', v_printer_port,
      'printer_device_identifier', v_printer_device_identifier,
      'paper_width_mm', v_printer_paper_width_mm,
      'job_type', p_job_type,
      'created_at', now(),
      'items', v_items_payload
    );

    insert into public.print_jobs (
      restaurant_id,
      order_id,
      station_id,
      printer_id,
      job_type,
      status,
      payload
    )
    values (
      p_restaurant_id,
      v_order_id,
      v_group.station_id,
      v_printer_id,
      p_job_type,
      'pending',
      v_job_payload
    )
    returning id into v_print_job_id;

    insert into public.print_job_items (print_job_id, order_item_id)
    select v_print_job_id, oi.id
    from public.order_items oi
    left join public.products p
      on p.id::text = oi.product_id
      and p.seller_id = p_restaurant_id
    where oi.order_id = v_order_id
      and oi.station_id is not distinct from v_group.station_id
      and coalesce(p.printer_routing_enabled, true);

    update public.order_items
    set kitchen_status = 'sent',
        sent_to_kitchen_at = now()
    where order_id = v_order_id
      and station_id is not distinct from v_group.station_id;

    v_print_job_ids := v_print_job_ids || jsonb_build_array(v_print_job_id::text);
    v_print_job_count := v_print_job_count + 1;
  end loop;

  return jsonb_build_object(
    'order_id',       v_order_id,
    'order_number',   v_order_number,
    'print_job_count', v_print_job_count,
    'print_job_ids',  v_print_job_ids
  );
end;
$$;

-- Re-grant execute so existing grants are preserved.
grant execute on function public.create_table_order_with_print_jobs(
  uuid, integer, jsonb, uuid, text, text, text, text
) to authenticated;

comment on function public.create_table_order_with_print_jobs(
  uuid, integer, jsonb, uuid, text, text, text, text
) is
'Transactional pipeline: inserts order + order_items + print_jobs in one call.
Permission: restaurant owner (auth.uid = p_restaurant_id) OR active sub-admin
(store_sub_admins.email matched via users.email).
Mobile devices leave print_jobs as pending; DesktopPrintHub on the restaurant
desktop picks them up via Supabase realtime and dispatches to the local bridge.';
