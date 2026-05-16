-- Hotfix: repair live RPC definitions that reference v_item.* without alias scope.
--
-- Symptoms (client snackbar):
--   missing FROM-clause entry for table "v_item"
--
-- Root cause:
--   A stale deployed version of public.create_table_order_with_print_jobs()
--   used v_item.<field> in a SELECT/JSON build scope where v_item alias did
--   not exist. This migration replaces the function with the repo-canonical
--   version that consistently treats v_item as a loop RECORD over
--   jsonb_array_elements(p_items) and references v_item.value ->> ... fields.
--
-- Notes:
-- - We intentionally keep table_area_name/area_name in payload (for logs/UI),
--   but renderer may choose not to print "Alan:" line.
-- - After deployment, refresh PostgREST schema cache:
--     notify pgrst, 'reload schema';

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
  v_restaurant_name text;
  v_waiter_name text;
  v_waiter_ref uuid;
  v_table_id uuid;
  v_table_name text;
  v_table_area_name text;
  v_area_table_number integer;
  v_order_id uuid;
  v_order_number text;
  v_print_job_id uuid;
  v_print_job_ids jsonb := '[]'::jsonb;
  v_item record;
  v_item_product_id text;
  v_item_name text;
  v_item_note text;
  v_item_qty integer;
  v_item_price numeric;
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
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  if auth.uid() <> p_restaurant_id then
    if not exists (
      select 1
      from public.store_sub_admins sa
      join public.users u
        on lower(trim(u.email)) = lower(trim(sa.email))
      where sa.store_id = p_restaurant_id
        and u.id         = auth.uid()
        and sa.status    = 'active'
    ) then
      raise exception 'Bu restoran için işlem yetkiniz yok.' using errcode = '42501';
    end if;
  end if;

  if p_items is null
    or jsonb_typeof(p_items) <> 'array'
    or jsonb_array_length(p_items) = 0 then
    raise exception 'Sipariş kalemleri boş olamaz.' using errcode = '22023';
  end if;

  if p_job_type not in ('new_order', 'add_item', 'cancel_item', 'reprint') then
    raise exception 'Geçersiz job_type: %', p_job_type using errcode = '22023';
  end if;

  select business_name
  into v_restaurant_name
  from public.stores
  where seller_id = p_restaurant_id
  limit 1;

  if v_restaurant_name is null then
    raise exception 'Restoran bulunamadı.' using errcode = '22023';
  end if;

  select id,
         coalesce(nullif(trim(display_label), ''), nullif(trim(table_name), ''), format('Masa %s', table_number)) as resolved_label,
         coalesce(nullif(trim(area_name), ''), '') as resolved_area,
         coalesce(area_table_number, table_number) as resolved_area_no
  into v_table_id, v_table_name, v_table_area_name, v_area_table_number
  from public.store_tables
  where seller_id = p_restaurant_id
    and table_number = p_table_number
    and is_active = true
  order by created_at desc
  limit 1;

  if v_table_name is null or trim(v_table_name) = '' then
    v_table_name := format('Masa %s', p_table_number);
  end if;
  if v_table_area_name is null then
    v_table_area_name := '';
  end if;
  if v_area_table_number is null or v_area_table_number <= 0 then
    v_area_table_number := p_table_number;
  end if;

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

  -- Persist order_items first (same behaviour as existing function).
  for v_item in
    select value from jsonb_array_elements(p_items)
  loop
    v_item_product_id := nullif(trim(coalesce(v_item.value ->> 'product_id', '')), '');
    v_item_name := coalesce(nullif(trim(coalesce(v_item.value ->> 'name', '')), ''), 'Ürün');
    v_item_note := nullif(trim(coalesce(v_item.value ->> 'notes', '')), '');

    v_item_qty := greatest(
      coalesce((v_item.value ->> 'quantity')::int, 1),
      1
    );
    v_item_price := coalesce((v_item.value ->> 'price')::numeric, 0);

    insert into public.order_items (
      order_id,
      product_id,
      product_name,
      quantity,
      item_note,
      unit_price,
      station_id
    )
    values (
      v_order_id,
      v_item_product_id,
      v_item_name,
      v_item_qty,
      v_item_note,
      v_item_price,
      nullif(trim(coalesce(v_item.value ->> 'station_id', '')), '')::uuid
    );
  end loop;

  -- Station grouping + print job creation (delegate to the existing routing logic
  -- by reusing the same group query shape).
  for v_group in
    select
      oi.station_id,
      coalesce(s.name, 'Genel') as station_name,
      coalesce(s.code, 'GENEL') as station_code
    from public.order_items oi
    left join public.stations s on s.id = oi.station_id
    where oi.order_id = v_order_id
    group by oi.station_id, s.name, s.code
    order by station_name asc
  loop
    -- Resolve station printer mapping (best effort; nullable ok).
    select sp.printer_id,
           coalesce(pr.name, '') as printer_name,
           coalesce(pr.code, '') as printer_code,
           coalesce(pr.connection_type, '') as printer_connection_type,
           pr.ip_address,
           pr.port,
           pr.device_identifier,
           pr.paper_width_mm
    into v_printer_id,
         v_printer_name,
         v_printer_code,
         v_printer_connection_type,
         v_printer_ip_address,
         v_printer_port,
         v_printer_device_identifier,
         v_printer_paper_width_mm
    from public.station_printers sp
    join public.printers pr on pr.id = sp.printer_id and pr.is_active = true
    where sp.station_id = v_group.station_id
    order by sp.is_primary desc, sp.created_at asc
    limit 1;

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
    where oi.order_id = v_order_id
      and oi.station_id is not distinct from v_group.station_id;

    if jsonb_array_length(v_items_payload) = 0 then
      continue;
    end if;

    v_job_payload := jsonb_build_object(
      'restaurant_id', p_restaurant_id,
      'restaurant_name', v_restaurant_name,
      'order_id', v_order_id,
      'order_no', v_order_number,
      'table_id', v_table_id,
      'table_number', p_table_number,
      'area_table_number', v_area_table_number,
      'area_name', v_table_area_name,
      'table_name', v_table_name,
      'table_display_name', v_table_name,
      'display_table_label', v_table_name,
      'table_area_name', v_table_area_name,
      'table_area', v_table_area_name,
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

    v_print_job_ids := v_print_job_ids || to_jsonb(v_print_job_id);
  end loop;

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'print_job_ids', v_print_job_ids
  );
end;
$$;

-- Refresh PostgREST schema cache for immediate client usage.
notify pgrst, 'reload schema';

