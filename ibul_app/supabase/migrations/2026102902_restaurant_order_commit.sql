-- Prepared from read-only live RPC inspection on 2026-10-29. NOT applied.
-- Requires 2026102901_restaurant_staff_access.sql first. No table recreation.
begin;
create or replace function public.create_table_order_with_print_jobs_impl(
  p_restaurant_id uuid, p_table_number integer, p_items jsonb,
  p_waiter_id uuid default null, p_waiter_name text default null,
  p_notes text default null, p_job_type text default 'new_order',
  p_order_type text default 'table', p_local_order_id text default null
) returns jsonb language plpgsql security definer set search_path = public
as $function$

declare
  v_previous_rpc text := current_setting('ibul.marketplace_order_rpc', true);
  v_restaurant_name text;
  v_waiter_name text;
  v_waiter_ref uuid;
  v_table_id uuid;
  v_table_name text;
  v_table_area_name text;
  v_area_table_number integer;
  v_order_id uuid;
  v_order_number text;
  v_order_created_at timestamptz := now();
  v_daily_order_no integer := 0;
  v_printed_at timestamptz := now();
  v_print_job_id uuid;
  v_print_job_ids jsonb := '[]'::jsonb;
  v_local_order_id text := nullif(trim(coalesce(p_local_order_id, '')), '');
  v_item record;
  v_item_product_id text;
  v_item_name text;
  v_item_note text;
  v_item_qty integer;
  v_item_price numeric;
  v_new_item_id uuid;
  v_line_ids uuid[] := array[]::uuid[];
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

  if not public.restaurant_has_permission(p_restaurant_id, 'manageOrders') then
    raise exception 'Bu restoran için işlem yetkiniz yok.' using errcode = '42501';
  end if;

  if p_items is null
    or jsonb_typeof(p_items) <> 'array'
    or jsonb_array_length(p_items) = 0 then
    raise exception 'Sipariş kalemleri boş olamaz.' using errcode = '22023';
  end if;

  if p_job_type not in ('new_order', 'add_item', 'cancel_item', 'reprint') then
    raise exception 'Geçersiz job_type: %', p_job_type using errcode = '22023';
  end if;

  if p_waiter_id is not null and p_waiter_id <> auth.uid() and auth.uid() <> p_restaurant_id then
    raise exception 'Garson kimliği geçersiz.' using errcode = '42501';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_items) item
    where nullif(item->>'station_id', '') is not null
      and not exists (select 1 from public.stations st where st.id = (item->>'station_id')::uuid
        and st.restaurant_id = p_restaurant_id and st.is_active)
  ) then
    raise exception 'İstasyon bu işletmeye ait değil.' using errcode = '42501';
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

  if v_table_id is null then
    raise exception 'Aktif masa bulunamadı.' using errcode = '22023';
  end if;
  if not public.restaurant_table_access(p_restaurant_id, v_table_id) then
    raise exception 'Bu şubede işlem yetkiniz yok.' using errcode = '42501';
  end if;
  if v_table_name is null or trim(v_table_name) = '' then
    v_table_name := format('Masa %s', p_table_number);
  end if;
  if v_table_area_name is null then
    v_table_area_name := '';
  end if;
  if v_area_table_number is null or v_area_table_number <= 0 then
    v_area_table_number := p_table_number;
  end if;

  if exists(select 1 from jsonb_array_elements(p_items) item
    join public.station_printers sp on sp.station_id=nullif(item->>'station_id','')::uuid
    left join public.printers pr on pr.id=sp.printer_id
    where pr.id is null or pr.restaurant_id is distinct from p_restaurant_id) then
    raise exception 'İstasyon yazıcısı bu işletmeye ait değil.' using errcode='42501';
  end if;

  -- Serialize retries with the existing orders.local_order_id unique key.
  if v_local_order_id is not null then
    perform pg_advisory_xact_lock(hashtextextended(p_restaurant_id::text || ':' || v_local_order_id, 0));
  end if;

  -- IDEMPOTENCY KONTROLÜ: Aynı (restaurant_id, local_order_id) daha önce kaydedildiyse
  -- mükerrer sipariş ve mükerrer print_job oluşturma; mevcut kaydı döndür.
  if v_local_order_id is not null then
    select o.id, o.order_number
    into v_order_id, v_order_number
    from public.orders o
    where o.restaurant_id = p_restaurant_id
      and o.local_order_id = v_local_order_id
    limit 1;

    if v_order_id is not null then
      if not exists(select 1 from public.orders o where o.id=v_order_id
        and o.table_id=v_table_id and public.restaurant_table_access(p_restaurant_id,o.table_id)) then
        raise exception 'Tekrar isteği bu masa veya şubeye ait değil.' using errcode='42501';
      end if;
      select coalesce(jsonb_agg(to_jsonb(pj.id) order by pj.created_at asc), '[]'::jsonb)
      into v_print_job_ids
      from public.print_jobs pj
      where pj.restaurant_id = p_restaurant_id
        and pj.order_id = v_order_id;

      return jsonb_build_object(
        'order_id', v_order_id,
        'order_number', v_order_number,
        'print_job_ids', coalesce(v_print_job_ids, '[]'::jsonb),
        'print_job_count', jsonb_array_length(coalesce(v_print_job_ids, '[]'::jsonb)),
        'idempotent_replay', true
      );
    end if;
  end if;

  -- Günlük restoran sipariş sayacı (atomik).
  insert into public.restaurant_daily_order_counters (restaurant_id, order_date, last_no)
  values (p_restaurant_id, now()::date, 1)
  on conflict (restaurant_id, order_date)
  do update set last_no = public.restaurant_daily_order_counters.last_no + 1,
               updated_at = now()
  returning last_no into v_daily_order_no;

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

  -- Existing money-authority triggers require trusted RPC context.
  -- Only after tenant, membership, table and station checks succeeded.
  perform set_config('ibul.marketplace_order_rpc', 'on', true);
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
    notes,
    local_order_id
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
    nullif(trim(coalesce(p_notes, '')), ''),
    v_local_order_id
  )
  returning id into v_order_id;

  begin
    execute 'select created_at from public.orders where id = $1'
      into v_order_created_at
      using v_order_id;
  exception when others then
    v_order_created_at := now();
  end;

  -- Sipariş kalemlerini kaydet.
  for v_item in
    select value from jsonb_array_elements(p_items)
  loop
    v_item_product_id := nullif(trim(coalesce(v_item.value ->> 'product_id', '')), '');
    v_item_name := coalesce(nullif(trim(coalesce(v_item.value ->> 'name', '')), ''), 'Ürün');
    v_item_note := nullif(trim(coalesce(v_item.value ->> 'notes', '')), '');
    v_item_qty := greatest(coalesce((v_item.value ->> 'quantity')::int, 1), 1);
    v_item_price := coalesce((v_item.value ->> 'price')::numeric, 0);

    insert into public.order_items (
      order_id,
      product_id,
      product_name,
      quantity,
      item_note,
      unit_price,
      station_id,
      attributes
    )
    values (
      v_order_id,
      v_item_product_id,
      v_item_name,
      v_item_qty,
      v_item_note,
      v_item_price,
      nullif(trim(coalesce(v_item.value ->> 'station_id', '')), '')::uuid,
      coalesce(
        case
          when v_item.value ? 'plates'
            or v_item.value ? 'service_children'
            or v_item.value ? 'child_items'
          then jsonb_strip_nulls(jsonb_build_object(
            'kitchen_plates', v_item.value -> 'plates',
            'kitchen_service_children', v_item.value -> 'service_children',
            'child_items', v_item.value -> 'child_items'
          ))
          else '{}'::jsonb
        end,
        '{}'::jsonb
      )
    )
    returning id into v_new_item_id;
    v_line_ids := v_line_ids || v_new_item_id;
  end loop;

  -- İstasyon (Ocak, Fırın, Genel vb.) bazlı gruplama ve print_jobs kayıtları.
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
    v_printer_id := null;
    v_printer_name := '';
    v_printer_code := '';
    v_printer_connection_type := '';
    v_printer_ip_address := null;
    v_printer_port := null;
    v_printer_device_identifier := null;
    v_printer_paper_width_mm := null;

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
          'amount_label', coalesce((p_items -> (array_position(v_line_ids, oi.id) - 1)) ->> 'amount_label', ''),
          'plates', coalesce(
            (p_items -> (array_position(v_line_ids, oi.id) - 1)) -> 'plates',
            oi.attributes -> 'kitchen_plates',
            '[]'::jsonb
          ),
          'service_children', coalesce(
            (p_items -> (array_position(v_line_ids, oi.id) - 1)) -> 'service_children',
            oi.attributes -> 'kitchen_service_children',
            '[]'::jsonb
          ),
          'child_items', coalesce(
            (p_items -> (array_position(v_line_ids, oi.id) - 1)) -> 'child_items',
            oi.attributes -> 'child_items',
            '[]'::jsonb
          )
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
      'order_number', v_order_number,
      'daily_order_no', v_daily_order_no,
      'kitchen_order_no', v_daily_order_no,
      'created_at', now(),
      'order_created_at', v_order_created_at,
      'printed_at', v_printed_at,
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
      'items', v_items_payload
    );

    v_job_payload := v_job_payload || jsonb_build_object(
      'print_size_source', 'printer_settings',
      'print_size', coalesce((select pr.print_size from public.printers pr where pr.id = v_printer_id), 'normal')
    );
    insert into public.print_jobs (
      restaurant_id,
      order_id,
      station_id,
      printer_id,
      job_type,
      status,
      order_saved_at,
      print_job_created_at,
      payload
    )
    values (
      p_restaurant_id,
      v_order_id,
      v_group.station_id,
      v_printer_id,
      p_job_type,
      case when coalesce((select print_system_enabled from public.restaurant_print_station_configs where restaurant_id = p_restaurant_id), true) then 'pending' else 'paused_by_operator' end,
      v_order_created_at,
      clock_timestamp(),
      v_job_payload
    )
    returning id into v_print_job_id;

    v_print_job_ids := v_print_job_ids || to_jsonb(v_print_job_id);
  end loop;

  perform set_config('ibul.marketplace_order_rpc', coalesce(v_previous_rpc, ''), true);
  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'daily_order_no', v_daily_order_no,
    'print_job_ids', v_print_job_ids,
    'print_job_count', jsonb_array_length(v_print_job_ids),
    'order_saved_at', v_order_created_at,
    'print_job_created_at', now()
  );
end;
$function$;
-- The public wrapper delegates to this guarded implementation. Remove direct
-- anonymous access to both entry points; all callers require Supabase Auth.
revoke all on function public.create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text) from public, anon;
grant execute on function public.create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text) to authenticated;
notify pgrst, 'reload schema';
commit;
