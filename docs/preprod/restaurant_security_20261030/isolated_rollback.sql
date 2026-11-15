-- GENERATED from an actual pre-migration catalog snapshot. ISOLATED CLONE ONLY.
-- Preserve additive staff/branch columns and indexes, and ALL operational rows.
-- Roll application/Edge version back separately; this can restore old security flaws.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
do $drift$ begin
    if to_regprocedure('activate_my_sub_admin_invites()') is null or
      pg_get_functiondef(to_regprocedure('activate_my_sub_admin_invites()')) is distinct from 'CREATE OR REPLACE FUNCTION public.activate_my_sub_admin_invites()
 RETURNS integer
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''public''
AS $function$ select 0; $function$
' then
      raise exception 'Rollback function drift: %','activate_my_sub_admin_invites()';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('close_table_with_history(uuid,integer)') is null or
      pg_get_functiondef(to_regprocedure('close_table_with_history(uuid,integer)')) is distinct from 'CREATE OR REPLACE FUNCTION public.close_table_with_history(p_seller_id uuid, p_table_number integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF NOT public.restaurant_has_permission(p_seller_id, ''manageOrders'') OR NOT public.restaurant_table_number_access(p_seller_id,p_table_number) THEN
    RAISE EXCEPTION ''Sipariş yönetme yetkisi yok.'' USING ERRCODE=''42501'';
  END IF;

  return ''{}''::jsonb;
END;
$function$
' then
      raise exception 'Rollback function drift: %','close_table_with_history(uuid,integer)';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text,text)') is null or
      pg_get_functiondef(to_regprocedure('create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text,text)')) is distinct from 'CREATE OR REPLACE FUNCTION public.create_table_order_with_print_jobs(p_restaurant_id uuid, p_table_number integer, p_items jsonb, p_waiter_id uuid DEFAULT NULL::uuid, p_waiter_name text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_job_type text DEFAULT ''new_order''::text, p_order_type text DEFAULT ''table''::text, p_local_order_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''public''
AS $function$
begin
  if auth.uid() is null then
    raise exception ''Yetkisiz istek.'' using errcode = ''42501'';
  end if;

  if not public.user_can_access_restaurant(p_restaurant_id) then
    raise exception ''Bu restoran için işlem yetkiniz yok.'' using errcode = ''42501'';
  end if;

  return public.create_table_order_with_print_jobs_impl(
    p_restaurant_id,
    p_table_number,
    p_items,
    p_waiter_id,
    p_waiter_name,
    p_notes,
    p_job_type,
    p_order_type,
    p_local_order_id
  );
end;
$function$
' then
      raise exception 'Rollback function drift: %','create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text,text)';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text)') is null or
      pg_get_functiondef(to_regprocedure('create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text)')) is distinct from 'CREATE OR REPLACE FUNCTION public.create_table_order_with_print_jobs_impl(p_restaurant_id uuid, p_table_number integer, p_items jsonb, p_waiter_id uuid DEFAULT NULL::uuid, p_waiter_name text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_job_type text DEFAULT ''new_order''::text, p_order_type text DEFAULT ''table''::text, p_local_order_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''public''
AS $function$

declare
  v_previous_rpc text := current_setting(''ibul.marketplace_order_rpc'', true);
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
  v_print_job_ids jsonb := ''[]''::jsonb;
  v_local_order_id text := nullif(trim(coalesce(p_local_order_id, '''')), '''');
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
    raise exception ''Yetkisiz istek.'' using errcode = ''42501'';
  end if;

  if not public.restaurant_has_permission(p_restaurant_id, ''manageOrders'') then
    raise exception ''Bu restoran için işlem yetkiniz yok.'' using errcode = ''42501'';
  end if;

  if p_items is null
    or jsonb_typeof(p_items) <> ''array''
    or jsonb_array_length(p_items) = 0 then
    raise exception ''Sipariş kalemleri boş olamaz.'' using errcode = ''22023'';
  end if;

  if p_job_type not in (''new_order'', ''add_item'', ''cancel_item'', ''reprint'') then
    raise exception ''Geçersiz job_type: %'', p_job_type using errcode = ''22023'';
  end if;

  if p_waiter_id is not null and p_waiter_id <> auth.uid() and auth.uid() <> p_restaurant_id then
    raise exception ''Garson kimliği geçersiz.'' using errcode = ''42501'';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_items) item
    where nullif(item->>''station_id'', '''') is not null
      and not exists (select 1 from public.stations st where st.id = (item->>''station_id'')::uuid
        and st.restaurant_id = p_restaurant_id and st.is_active)
  ) then
    raise exception ''İstasyon bu işletmeye ait değil.'' using errcode = ''42501'';
  end if;

  select business_name
  into v_restaurant_name
  from public.stores
  where seller_id = p_restaurant_id
  limit 1;

  if v_restaurant_name is null then
    raise exception ''Restoran bulunamadı.'' using errcode = ''22023'';
  end if;

  select id,
         coalesce(nullif(trim(display_label), ''''), nullif(trim(table_name), ''''), format(''Masa %s'', table_number)) as resolved_label,
         coalesce(nullif(trim(area_name), ''''), '''') as resolved_area,
         coalesce(area_table_number, table_number) as resolved_area_no
  into v_table_id, v_table_name, v_table_area_name, v_area_table_number
  from public.store_tables
  where seller_id = p_restaurant_id
    and table_number = p_table_number
    and is_active = true
  order by created_at desc
  limit 1;

  if v_table_id is null then
    raise exception ''Aktif masa bulunamadı.'' using errcode = ''22023'';
  end if;
  if not public.restaurant_table_access(p_restaurant_id, v_table_id) then
    raise exception ''Bu şubede işlem yetkiniz yok.'' using errcode = ''42501'';
  end if;
  if v_table_name is null or trim(v_table_name) = '''' then
    v_table_name := format(''Masa %s'', p_table_number);
  end if;
  if v_table_area_name is null then
    v_table_area_name := '''';
  end if;
  if v_area_table_number is null or v_area_table_number <= 0 then
    v_area_table_number := p_table_number;
  end if;

  if exists(select 1 from jsonb_array_elements(p_items) item
    join public.station_printers sp on sp.station_id=nullif(item->>''station_id'','''')::uuid
    left join public.printers pr on pr.id=sp.printer_id
    where pr.id is null or pr.restaurant_id is distinct from p_restaurant_id) then
    raise exception ''İstasyon yazıcısı bu işletmeye ait değil.'' using errcode=''42501'';
  end if;

  -- Serialize retries with the existing orders.local_order_id unique key.
  if v_local_order_id is not null then
    perform pg_advisory_xact_lock(hashtextextended(p_restaurant_id::text || '':'' || v_local_order_id, 0));
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
        raise exception ''Tekrar isteği bu masa veya şubeye ait değil.'' using errcode=''42501'';
      end if;
      select coalesce(jsonb_agg(to_jsonb(pj.id) order by pj.created_at asc), ''[]''::jsonb)
      into v_print_job_ids
      from public.print_jobs pj
      where pj.restaurant_id = p_restaurant_id
        and pj.order_id = v_order_id;

      return jsonb_build_object(
        ''order_id'', v_order_id,
        ''order_number'', v_order_number,
        ''print_job_ids'', coalesce(v_print_job_ids, ''[]''::jsonb),
        ''print_job_count'', jsonb_array_length(coalesce(v_print_job_ids, ''[]''::jsonb)),
        ''idempotent_replay'', true
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

  v_waiter_name := coalesce(nullif(trim(coalesce(p_waiter_name, '''')), ''''), ''Garson'');
  v_waiter_ref := null;
  select u.id into v_waiter_ref
  from public.users u
  where u.id = coalesce(p_waiter_id, auth.uid())
  limit 1;

  v_order_number := format(
    ''TBL-%s-%s'',
    to_char(now(), ''YYYYMMDDHH24MISS''),
    upper(substr(replace(gen_random_uuid()::text, ''-'', ''''), 1, 6))
  );

  -- Existing money-authority triggers require trusted RPC context.
  -- Only after tenant, membership, table and station checks succeeded.
  perform set_config(''ibul.marketplace_order_rpc'', ''on'', true);
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
    ''confirmed'',
    ''cash'',
    ''table'',
    0,
    0,
    0,
    0,
    ''TRY'',
    p_restaurant_id,
    v_table_id,
    v_waiter_ref,
    ''sent'',
    coalesce(nullif(trim(coalesce(p_order_type, '''')), ''''), ''table''),
    nullif(trim(coalesce(p_notes, '''')), ''''),
    v_local_order_id
  )
  returning id into v_order_id;

  begin
    execute ''select created_at from public.orders where id = $1''
      into v_order_created_at
      using v_order_id;
  exception when others then
    v_order_created_at := now();
  end;

  -- Sipariş kalemlerini kaydet.
  for v_item in
    select value from jsonb_array_elements(p_items)
  loop
    v_item_product_id := nullif(trim(coalesce(v_item.value ->> ''product_id'', '''')), '''');
    v_item_name := coalesce(nullif(trim(coalesce(v_item.value ->> ''name'', '''')), ''''), ''Ürün'');
    v_item_note := nullif(trim(coalesce(v_item.value ->> ''notes'', '''')), '''');
    v_item_qty := greatest(coalesce((v_item.value ->> ''quantity'')::int, 1), 1);
    v_item_price := coalesce((v_item.value ->> ''price'')::numeric, 0);

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
      nullif(trim(coalesce(v_item.value ->> ''station_id'', '''')), '''')::uuid,
      case
        when v_item.value ? ''plates''
          or v_item.value ? ''service_children''
          or v_item.value ? ''child_items''
        then jsonb_strip_nulls(jsonb_build_object(
          ''kitchen_plates'', v_item.value -> ''plates'',
          ''kitchen_service_children'', v_item.value -> ''service_children'',
          ''child_items'', v_item.value -> ''child_items''
        ))
        else null
      end
    )
    returning id into v_new_item_id;
    v_line_ids := v_line_ids || v_new_item_id;
  end loop;

  -- İstasyon (Ocak, Fırın, Genel vb.) bazlı gruplama ve print_jobs kayıtları.
  for v_group in
    select
      oi.station_id,
      coalesce(s.name, ''Genel'') as station_name,
      coalesce(s.code, ''GENEL'') as station_code
    from public.order_items oi
    left join public.stations s on s.id = oi.station_id
    where oi.order_id = v_order_id
    group by oi.station_id, s.name, s.code
    order by station_name asc
  loop
    v_printer_id := null;
    v_printer_name := '''';
    v_printer_code := '''';
    v_printer_connection_type := '''';
    v_printer_ip_address := null;
    v_printer_port := null;
    v_printer_device_identifier := null;
    v_printer_paper_width_mm := null;

    select sp.printer_id,
           coalesce(pr.name, '''') as printer_name,
           coalesce(pr.code, '''') as printer_code,
           coalesce(pr.connection_type, '''') as printer_connection_type,
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
          ''order_item_id'', oi.id,
          ''product_name'', oi.product_name,
          ''quantity'', oi.quantity,
          ''item_note'', oi.item_note,
          ''unit_price'', oi.unit_price,
          ''amount_label'', coalesce((p_items -> (array_position(v_line_ids, oi.id) - 1)) ->> ''amount_label'', ''''),
          ''plates'', coalesce(
            (p_items -> (array_position(v_line_ids, oi.id) - 1)) -> ''plates'',
            oi.attributes -> ''kitchen_plates'',
            ''[]''::jsonb
          ),
          ''service_children'', coalesce(
            (p_items -> (array_position(v_line_ids, oi.id) - 1)) -> ''service_children'',
            oi.attributes -> ''kitchen_service_children'',
            ''[]''::jsonb
          ),
          ''child_items'', coalesce(
            (p_items -> (array_position(v_line_ids, oi.id) - 1)) -> ''child_items'',
            oi.attributes -> ''child_items'',
            ''[]''::jsonb
          )
        )
        order by oi.created_at asc
      ),
      ''[]''::jsonb
    )
    into v_items_payload
    from public.order_items oi
    where oi.order_id = v_order_id
      and oi.station_id is not distinct from v_group.station_id;

    if jsonb_array_length(v_items_payload) = 0 then
      continue;
    end if;

    v_job_payload := jsonb_build_object(
      ''restaurant_id'', p_restaurant_id,
      ''restaurant_name'', v_restaurant_name,
      ''order_id'', v_order_id,
      ''order_no'', v_order_number,
      ''order_number'', v_order_number,
      ''daily_order_no'', v_daily_order_no,
      ''kitchen_order_no'', v_daily_order_no,
      ''created_at'', now(),
      ''order_created_at'', v_order_created_at,
      ''printed_at'', v_printed_at,
      ''table_id'', v_table_id,
      ''table_number'', p_table_number,
      ''area_table_number'', v_area_table_number,
      ''area_name'', v_table_area_name,
      ''table_name'', v_table_name,
      ''table_display_name'', v_table_name,
      ''display_table_label'', v_table_name,
      ''table_area_name'', v_table_area_name,
      ''table_area'', v_table_area_name,
      ''waiter_name'', v_waiter_name,
      ''station_id'', v_group.station_id,
      ''station_name'', v_group.station_name,
      ''station_code'', v_group.station_code,
      ''printer_id'', v_printer_id,
      ''printer_name'', v_printer_name,
      ''printer_code'', v_printer_code,
      ''printer_connection_type'', v_printer_connection_type,
      ''printer_ip_address'', v_printer_ip_address,
      ''printer_port'', v_printer_port,
      ''printer_device_identifier'', v_printer_device_identifier,
      ''paper_width_mm'', v_printer_paper_width_mm,
      ''job_type'', p_job_type,
      ''items'', v_items_payload
    );

    v_job_payload := v_job_payload || jsonb_build_object(
      ''print_size_source'', ''printer_settings'',
      ''print_size'', coalesce((select pr.print_size from public.printers pr where pr.id = v_printer_id), ''normal'')
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
      case when coalesce((select print_system_enabled from public.restaurant_print_station_configs where restaurant_id = p_restaurant_id), true) then ''pending'' else ''paused_by_operator'' end,
      v_order_created_at,
      clock_timestamp(),
      v_job_payload
    )
    returning id into v_print_job_id;

    v_print_job_ids := v_print_job_ids || to_jsonb(v_print_job_id);
  end loop;

  perform set_config(''ibul.marketplace_order_rpc'', coalesce(v_previous_rpc, ''''), true);
  return jsonb_build_object(
    ''order_id'', v_order_id,
    ''order_number'', v_order_number,
    ''daily_order_no'', v_daily_order_no,
    ''print_job_ids'', v_print_job_ids,
    ''print_job_count'', jsonb_array_length(v_print_job_ids),
    ''order_saved_at'', v_order_created_at,
    ''print_job_created_at'', now()
  );
end;
$function$
' then
      raise exception 'Rollback function drift: %','create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text)';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('finance_get_monthly_trend(uuid,integer)') is null or
      pg_get_functiondef(to_regprocedure('finance_get_monthly_trend(uuid,integer)')) is distinct from 'CREATE OR REPLACE FUNCTION public.finance_get_monthly_trend(uuid, integer)
 RETURNS integer
 LANGUAGE sql
AS $function$select 42$function$
' then
      raise exception 'Rollback function drift: %','finance_get_monthly_trend(uuid,integer)';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('finance_get_overview(uuid)') is null or
      pg_get_functiondef(to_regprocedure('finance_get_overview(uuid)')) is distinct from 'CREATE OR REPLACE FUNCTION public.finance_get_overview(p_seller_id uuid)
 RETURNS numeric
 LANGUAGE sql
AS $function$select sum(net_amount) from finance_income_records where seller_id=p_seller_id$function$
' then
      raise exception 'Rollback function drift: %','finance_get_overview(uuid)';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('get_my_staff_access()') is null or
      pg_get_functiondef(to_regprocedure('get_my_staff_access()')) is distinct from 'CREATE OR REPLACE FUNCTION public.get_my_staff_access()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''public''
AS $function$
  select case when count(*)=0 then null else jsonb_build_object(
    ''store_id'',(jsonb_agg(to_jsonb(sa.store_id) order by sa.created_at))->0,
    ''branch_id'',(jsonb_agg(to_jsonb(sa.branch_id) order by sa.created_at))->0,
    ''staff_role'',(jsonb_agg(to_jsonb(sa.staff_role) order by sa.created_at))->0,
    ''permissions'',(jsonb_agg(to_jsonb(sa.permissions) order by sa.created_at))->0,
    ''memberships'',jsonb_agg(jsonb_build_object(
      ''store_id'',sa.store_id,''branch_id'',sa.branch_id,
      ''staff_role'',sa.staff_role,''permissions'',sa.permissions
    ) order by sa.created_at)
  ) end
  from public.store_sub_admins sa
  join auth.users au on au.id=auth.uid()
  where sa.status=''active''
    and (sa.branch_id is null or exists(select 1 from public.store_branches b
      where b.id=sa.branch_id and b.store_id=sa.store_id and b.status=''active''))
    and (sa.auth_user_id=au.id or (sa.auth_user_id is null and (
      (au.email_confirmed_at is not null and lower(trim(sa.email))=lower(trim(au.email)))
      or (au.phone_confirmed_at is not null and sa.phone=au.phone))));
$function$
' then
      raise exception 'Rollback function drift: %','get_my_staff_access()';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('guard_restaurant_staff_order_write()') is null or
      pg_get_functiondef(to_regprocedure('guard_restaurant_staff_order_write()')) is distinct from 'CREATE OR REPLACE FUNCTION public.guard_restaurant_staff_order_write()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''public''
AS $function$
declare r uuid; t uuid; row_data jsonb;
begin
  if not public.is_managed_restaurant_staff() then
    if tg_op=''DELETE'' then return old; else return new; end if;
  end if;
  if tg_op=''DELETE'' then row_data:=to_jsonb(old); else row_data:=to_jsonb(new); end if;
  if tg_table_name=''orders'' then
    r:=(row_data->>''restaurant_id'')::uuid; t:=(row_data->>''table_id'')::uuid;
  elsif tg_table_name in (''order_items'',''print_jobs'') then
    select restaurant_id,table_id into r,t from public.orders where id=(row_data->>''order_id'')::uuid;
  else
    r:=(row_data->>''seller_id'')::uuid;
    select id into t from public.store_tables where seller_id=r and table_number=(row_data->>''table_number'')::integer limit 1;
  end if;
  if tg_op=''UPDATE'' and (
    (to_jsonb(old)->>''restaurant_id'') is distinct from (row_data->>''restaurant_id'')
    or (to_jsonb(old)->>''seller_id'') is distinct from (row_data->>''seller_id'')
    or (to_jsonb(old)->>''order_id'') is distinct from (row_data->>''order_id'')
    or (to_jsonb(old)->>''table_id'') is distinct from (row_data->>''table_id'')
  ) then raise exception ''İşletme veya masa kimliği değiştirilemez.'' using errcode=''42501''; end if;
  if r is null or not public.restaurant_has_permission(r,''manageOrders'')
    or not public.restaurant_table_access(r,t) then
    raise exception ''Personel sipariş yetkisi yok.'' using errcode=''42501'';
  end if;
  if tg_op=''DELETE'' then return old; else return new; end if;
end; $function$
' then
      raise exception 'Rollback function drift: %','guard_restaurant_staff_order_write()';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('guard_restaurant_staff_scoped_write()') is null or
      pg_get_functiondef(to_regprocedure('guard_restaurant_staff_scoped_write()')) is distinct from 'CREATE OR REPLACE FUNCTION public.guard_restaurant_staff_scoped_write()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''public''
AS $function$
declare d jsonb; r uuid;
begin
  if not public.is_managed_restaurant_staff() then
    if tg_op=''DELETE'' then return old; else return new; end if;
  end if;
  if tg_op=''DELETE'' then d:=to_jsonb(old); else d:=to_jsonb(new); end if;
  r:=(d->>tg_argv[0])::uuid;
  if r=auth.uid() then
    if tg_op=''DELETE'' then return old; else return new; end if;
  end if;
  if tg_argv[1]=''viewFinance'' or not public.restaurant_has_permission(r,tg_argv[1]) then
    raise exception ''Personel işlem yetkisi yok.'' using errcode=''42501'';
  end if;
  if tg_op=''UPDATE'' and (to_jsonb(old)->>tg_argv[0]) is distinct from (d->>tg_argv[0]) then
    raise exception ''İşletme kimliği değiştirilemez.'' using errcode=''42501'';
  end if;
  if tg_op=''DELETE'' then return old; else return new; end if;
end; $function$
' then
      raise exception 'Rollback function drift: %','guard_restaurant_staff_scoped_write()';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('is_managed_restaurant_staff()') is null or
      pg_get_functiondef(to_regprocedure('is_managed_restaurant_staff()')) is distinct from 'CREATE OR REPLACE FUNCTION public.is_managed_restaurant_staff()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''public''
AS $function$
  -- Historical name retained for callers. Identify ALL staff, even inactive
  -- legacy memberships; status is checked by authorization, never classification.
  select exists(select 1 from auth.users au where au.id=auth.uid() and (
    au.raw_app_meta_data->>''managed_restaurant_staff''=''true''
    or exists(select 1 from public.store_sub_admins sa where sa.auth_user_id=au.id
      or (sa.auth_user_id is null and (
        (au.email_confirmed_at is not null and lower(trim(sa.email))=lower(trim(au.email)))
        or (au.phone_confirmed_at is not null and sa.phone=au.phone))))));
$function$
' then
      raise exception 'Rollback function drift: %','is_managed_restaurant_staff()';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('restaurant_customer_table_order_target(text)') is null or
      pg_get_functiondef(to_regprocedure('restaurant_customer_table_order_target(text)')) is distinct from 'CREATE OR REPLACE FUNCTION public.restaurant_customer_table_order_target(p_seller_id text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''public''
AS $function$
  select exists(select 1 from public.stores s where s.seller_id::text=nullif(trim(p_seller_id),''''));
$function$
' then
      raise exception 'Rollback function drift: %','restaurant_customer_table_order_target(text)';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('restaurant_has_permission(uuid,text)') is null or
      pg_get_functiondef(to_regprocedure('restaurant_has_permission(uuid,text)')) is distinct from 'CREATE OR REPLACE FUNCTION public.restaurant_has_permission(p_restaurant_id uuid, p_permission text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''public''
AS $function$
  select auth.uid() is not null and (
    exists(select 1 from public.stores where seller_id=p_restaurant_id and seller_id=auth.uid())
    or exists(
      select 1 from public.store_sub_admins sa join auth.users au on au.id=auth.uid()
      where sa.store_id=p_restaurant_id and sa.status=''active''
        and (sa.branch_id is null or exists(select 1 from public.store_branches b
          where b.id=sa.branch_id and b.store_id=sa.store_id and b.status=''active''))
        and (p_permission is null or p_permission=any(sa.permissions))
        and (sa.auth_user_id=au.id or (sa.auth_user_id is null and (
          (au.email_confirmed_at is not null and lower(trim(sa.email))=lower(trim(au.email)))
          or (au.phone_confirmed_at is not null and sa.phone=au.phone))))
    )
  );
$function$
' then
      raise exception 'Rollback function drift: %','restaurant_has_permission(uuid,text)';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('restaurant_order_access(uuid,text)') is null or
      pg_get_functiondef(to_regprocedure('restaurant_order_access(uuid,text)')) is distinct from 'CREATE OR REPLACE FUNCTION public.restaurant_order_access(p_order_id uuid, p_permission text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''public''
AS $function$
  -- A missing restaurant_id is a consumer order, never a staff restaurant grant.
  select exists(select 1 from public.orders o where o.id=p_order_id
    and o.restaurant_id is not null
    and public.restaurant_has_permission(o.restaurant_id,p_permission)
    and public.restaurant_table_access(o.restaurant_id,o.table_id));
$function$
' then
      raise exception 'Rollback function drift: %','restaurant_order_access(uuid,text)';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('restaurant_table_access(uuid,uuid)') is null or
      pg_get_functiondef(to_regprocedure('restaurant_table_access(uuid,uuid)')) is distinct from 'CREATE OR REPLACE FUNCTION public.restaurant_table_access(p_restaurant_id uuid, p_table_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''public''
AS $function$
  select auth.uid()=p_restaurant_id or exists(
    select 1 from public.store_sub_admins sa join auth.users au on au.id=auth.uid()
    join public.store_tables t on t.id=p_table_id and t.seller_id=sa.store_id and t.is_active
    where sa.store_id=p_restaurant_id and sa.status=''active''
      and (sa.branch_id is null or (t.branch_id=sa.branch_id and exists(
        select 1 from public.store_branches b where b.id=sa.branch_id
          and b.store_id=sa.store_id and b.status=''active'')))
      and (sa.auth_user_id=au.id or (sa.auth_user_id is null and (
        (au.email_confirmed_at is not null and lower(trim(sa.email))=lower(trim(au.email)))
        or (au.phone_confirmed_at is not null and sa.phone=au.phone))))
  );
$function$
' then
      raise exception 'Rollback function drift: %','restaurant_table_access(uuid,uuid)';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('restaurant_table_number_access(uuid,integer)') is null or
      pg_get_functiondef(to_regprocedure('restaurant_table_number_access(uuid,integer)')) is distinct from 'CREATE OR REPLACE FUNCTION public.restaurant_table_number_access(p_restaurant_id uuid, p_number integer)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''public''
AS $function$
  select auth.uid()=p_restaurant_id or exists(select 1 from public.store_tables t
    where t.seller_id=p_restaurant_id and t.table_number=p_number
      and public.restaurant_table_access(p_restaurant_id,t.id));
$function$
' then
      raise exception 'Rollback function drift: %','restaurant_table_number_access(uuid,integer)';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('user_can_access_restaurant(uuid)') is null or
      pg_get_functiondef(to_regprocedure('user_can_access_restaurant(uuid)')) is distinct from 'CREATE OR REPLACE FUNCTION public.user_can_access_restaurant(p_restaurant_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''public''
AS $function$ select public.restaurant_has_permission(p_restaurant_id, ''manageOrders'')
  or public.restaurant_has_permission(p_restaurant_id, ''viewOrders''); $function$
' then
      raise exception 'Rollback function drift: %','user_can_access_restaurant(uuid)';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('validate_restaurant_print_job()') is null or
      pg_get_functiondef(to_regprocedure('validate_restaurant_print_job()')) is distinct from 'CREATE OR REPLACE FUNCTION public.validate_restaurant_print_job()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''public''
AS $function$
declare parent_restaurant uuid; payload_key text;
begin
  if tg_op=''UPDATE'' and new.status=''pending'' and old.status in (''claimed'',''printing'',''completed'') then
    raise exception ''Gönderilmiş veya belirsiz iş otomatik yeniden kuyruğa alınamaz.'' using errcode=''42501'';
  end if;
  if tg_op=''UPDATE'' and new.status=''pending'' and old.status=''failed'' then
    if nullif(new.payload->>''manual_reprint_token'','''') is null
      or (new.payload->>''manual_reprint_token'') is not distinct from (old.payload->>''manual_reprint_token'')
      or not public.restaurant_has_permission(new.restaurant_id,''manageOrders'') then
      raise exception ''Manuel yeniden baskı için yetkili operatör onayı gerekli.'' using errcode=''42501'';
    end if;
  end if;
  if new.restaurant_id is null or not exists(select 1 from public.stores where seller_id=new.restaurant_id) then
    raise exception ''Baskı işletmesi geçersiz.'' using errcode=''42501'';
  end if;
  if new.order_id is not null then
    select restaurant_id into parent_restaurant from public.orders where id=new.order_id;
    if parent_restaurant is distinct from new.restaurant_id then
      raise exception ''Baskı siparişi farklı işletmeye ait.'' using errcode=''42501'';
    end if;
  elsif coalesce(new.job_type,'''') not in (''receipt'',''test_receipt'') then
    raise exception ''Baskı siparişi gerekli.'' using errcode=''42501'';
  end if;
  if new.station_id is not null and not exists(select 1 from public.stations
    where id=new.station_id and restaurant_id=new.restaurant_id) then
    raise exception ''Baskı istasyonu farklı işletmeye ait.'' using errcode=''42501'';
  end if;
  if new.printer_id is not null and not exists(select 1 from public.printers
    where id=new.printer_id and restaurant_id=new.restaurant_id) then
    raise exception ''Baskı yazıcısı farklı işletmeye ait.'' using errcode=''42501'';
  end if;
  if new.station_id is not null and new.printer_id is not null and not exists(
    select 1 from public.station_printers where station_id=new.station_id and printer_id=new.printer_id) then
    raise exception ''Baskı istasyonu ve yazıcısı eşleşmiyor.'' using errcode=''42501'';
  end if;
  foreach payload_key in array array[''restaurant_id'',''order_id'',''station_id'',''printer_id''] loop
    if nullif(new.payload->>payload_key,'''') is not null
      and (new.payload->>payload_key)::uuid is distinct from (to_jsonb(new)->>payload_key)::uuid then
      raise exception ''Baskı payload kimliği uyuşmuyor: %'',payload_key using errcode=''42501'';
    end if;
  end loop;
  return new;
end; $function$
' then
      raise exception 'Rollback function drift: %','validate_restaurant_print_job()';
    end if;
  end $drift$;
do $drift$ begin
    if to_regprocedure('validate_restaurant_staff_membership()') is null or
      pg_get_functiondef(to_regprocedure('validate_restaurant_staff_membership()')) is distinct from 'CREATE OR REPLACE FUNCTION public.validate_restaurant_staff_membership()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''public''
AS $function$
begin
  if new.branch_id is not null and not exists(select 1 from public.store_branches
    where id=new.branch_id and store_id=new.store_id) then
    raise exception ''Şube bu işletmeye ait değil.'' using errcode=''42501'';
  end if;
  if not new.permissions <@ array[''manageProducts'',''viewOrders'',''manageOrders'',''manageCampaigns'',''viewFinance'',''manageSupport'',''manageStoreProfile'']::text[] then
    raise exception ''Geçersiz yetki.'' using errcode=''22023'';
  end if;
  if new.auth_user_id is not null and not exists(select 1 from auth.users
    where id=new.auth_user_id and lower(email)=lower(new.email)) then
    raise exception ''Auth kimliği uyuşmuyor.'' using errcode=''42501'';
  end if;
  return new;
end; $function$
' then
      raise exception 'Rollback function drift: %','validate_restaurant_staff_membership()';
    end if;
  end $drift$;
do $drift$ begin
    if (select coalesce(jsonb_agg(to_jsonb(x) order by tablename,policyname),'[]'::jsonb) from (select tablename,policyname,permissive,roles,cmd,qual,with_check
      from pg_policies where schemaname='public' and tablename in ('store_sub_admins','store_tables','orders','order_items','print_jobs','printers','table_orders','table_order_history','products','stores','store_campaigns','support_tickets','finance_suppliers','finance_cash_accounts','finance_cash_movements','finance_income_records','finance_expenses','finance_debts','finance_debt_payments','finance_employees','finance_salary_records','finance_salary_payments','finance_reconciliation_notes','finance_company_settings')) x)
      is distinct from '[{"tablename":"finance_income_records","policyname":"staff_permission_read","permissive":"PERMISSIVE","roles":["authenticated"],"cmd":"SELECT","qual":"restaurant_has_permission(seller_id, ''viewFinance''::text)","with_check":null},{"tablename":"finance_income_records","policyname":"staff_permission_read_guard","permissive":"RESTRICTIVE","roles":["authenticated"],"cmd":"SELECT","qual":"((NOT is_managed_restaurant_staff()) OR restaurant_has_permission(seller_id, ''viewFinance''::text))","with_check":null},{"tablename":"order_items","policyname":"restaurant_staff_items_read_guard","permissive":"RESTRICTIVE","roles":["authenticated"],"cmd":"SELECT","qual":"((NOT is_managed_restaurant_staff()) OR (EXISTS ( SELECT 1\n   FROM orders o\n  WHERE ((o.id = order_items.order_id) AND (o.restaurant_id IS NULL) AND (o.user_id = auth.uid())))) OR restaurant_order_access(order_id, ''viewOrders''::text) OR restaurant_order_access(order_id, ''manageOrders''::text))","with_check":null},{"tablename":"orders","policyname":"restaurant_staff_orders_read_guard","permissive":"RESTRICTIVE","roles":["authenticated"],"cmd":"SELECT","qual":"((NOT is_managed_restaurant_staff()) OR ((restaurant_id IS NULL) AND (user_id = auth.uid())) OR restaurant_order_access(id, ''viewOrders''::text) OR restaurant_order_access(id, ''manageOrders''::text))","with_check":null},{"tablename":"orders","policyname":"restaurant_staff_orders_write_guard","permissive":"RESTRICTIVE","roles":["authenticated"],"cmd":"UPDATE","qual":"((NOT is_managed_restaurant_staff()) OR restaurant_order_access(id, ''manageOrders''::text))","with_check":"((NOT is_managed_restaurant_staff()) OR restaurant_order_access(id, ''manageOrders''::text))"},{"tablename":"print_jobs","policyname":"restaurant_staff_jobs_write_guard","permissive":"RESTRICTIVE","roles":["authenticated"],"cmd":"ALL","qual":"((NOT is_managed_restaurant_staff()) OR restaurant_order_access(order_id, ''manageOrders''::text))","with_check":"((NOT is_managed_restaurant_staff()) OR restaurant_order_access(order_id, ''manageOrders''::text))"},{"tablename":"store_sub_admins","policyname":"staff_membership_delete_guard","permissive":"RESTRICTIVE","roles":["authenticated"],"cmd":"DELETE","qual":"(store_id = auth.uid())","with_check":null},{"tablename":"store_sub_admins","policyname":"staff_membership_insert_guard","permissive":"RESTRICTIVE","roles":["authenticated"],"cmd":"INSERT","qual":null,"with_check":"(store_id = auth.uid())"},{"tablename":"store_sub_admins","policyname":"staff_membership_update_guard","permissive":"RESTRICTIVE","roles":["authenticated"],"cmd":"UPDATE","qual":"(store_id = auth.uid())","with_check":"(store_id = auth.uid())"},{"tablename":"store_sub_admins","policyname":"store_sub_admins_active_self_select","permissive":"PERMISSIVE","roles":["authenticated"],"cmd":"SELECT","qual":"((auth_user_id = auth.uid()) OR (store_id = auth.uid()))","with_check":null},{"tablename":"store_sub_admins","policyname":"store_sub_admins_owner_all","permissive":"PERMISSIVE","roles":["authenticated"],"cmd":"ALL","qual":"(store_id = auth.uid())","with_check":"(store_id = auth.uid())"},{"tablename":"stores","policyname":"staff_permission_delete","permissive":"PERMISSIVE","roles":["authenticated"],"cmd":"DELETE","qual":"restaurant_has_permission(seller_id, ''manageStoreProfile''::text)","with_check":null},{"tablename":"stores","policyname":"staff_permission_insert","permissive":"PERMISSIVE","roles":["authenticated"],"cmd":"INSERT","qual":null,"with_check":"restaurant_has_permission(seller_id, ''manageStoreProfile''::text)"},{"tablename":"stores","policyname":"staff_permission_read","permissive":"PERMISSIVE","roles":["authenticated"],"cmd":"SELECT","qual":"restaurant_has_permission(seller_id, ''manageStoreProfile''::text)","with_check":null},{"tablename":"stores","policyname":"staff_permission_update","permissive":"PERMISSIVE","roles":["authenticated"],"cmd":"UPDATE","qual":"restaurant_has_permission(seller_id, ''manageStoreProfile''::text)","with_check":"restaurant_has_permission(seller_id, ''manageStoreProfile''::text)"},{"tablename":"table_order_history","policyname":"staff_history_read_guard","permissive":"RESTRICTIVE","roles":["authenticated"],"cmd":"SELECT","qual":"((NOT is_managed_restaurant_staff()) OR ((restaurant_has_permission(seller_id, ''viewOrders''::text) OR restaurant_has_permission(seller_id, ''viewFinance''::text) OR restaurant_has_permission(seller_id, ''manageOrders''::text)) AND restaurant_table_number_access(seller_id, table_number)))","with_check":null},{"tablename":"table_orders","policyname":"sentinel_restrictive","permissive":"RESTRICTIVE","roles":["authenticated"],"cmd":"SELECT","qual":"(table_number > 0)","with_check":null},{"tablename":"table_orders","policyname":"staff_table_orders_branch_guard","permissive":"RESTRICTIVE","roles":["authenticated"],"cmd":"ALL","qual":"((NOT is_managed_restaurant_staff()) OR restaurant_table_number_access((seller_id)::uuid, table_number))","with_check":"((NOT is_managed_restaurant_staff()) OR restaurant_table_number_access((seller_id)::uuid, table_number))"},{"tablename":"table_orders","policyname":"table_orders_customer_insert","permissive":"PERMISSIVE","roles":["anon","authenticated"],"cmd":"INSERT","qual":null,"with_check":"restaurant_customer_table_order_target(seller_id)"},{"tablename":"table_orders","policyname":"table_orders_delete_staff","permissive":"PERMISSIVE","roles":["authenticated"],"cmd":"DELETE","qual":"restaurant_has_permission((seller_id)::uuid, ''manageOrders''::text)","with_check":null},{"tablename":"table_orders","policyname":"table_orders_read_staff","permissive":"PERMISSIVE","roles":["authenticated"],"cmd":"SELECT","qual":"(restaurant_has_permission((seller_id)::uuid, ''viewOrders''::text) OR restaurant_has_permission((seller_id)::uuid, ''manageOrders''::text))","with_check":null},{"tablename":"table_orders","policyname":"table_orders_update_staff","permissive":"PERMISSIVE","roles":["authenticated"],"cmd":"UPDATE","qual":"restaurant_has_permission((seller_id)::uuid, ''manageOrders''::text)","with_check":"restaurant_has_permission((seller_id)::uuid, ''manageOrders''::text)"}]'::jsonb then
      raise exception 'Rollback catalog drift: policies';
    end if;
  end $drift$;
do $drift$ begin
    if (select coalesce(jsonb_agg(to_jsonb(x) order by tablename,tgname),'[]'::jsonb) from (select c.relname tablename,t.tgname,pg_get_triggerdef(t.oid) definition,t.tgenabled
      from pg_trigger t join pg_class c on c.oid=t.tgrelid
      where c.relnamespace='public'::regnamespace and not t.tgisinternal
      and c.relname in ('store_sub_admins','store_tables','orders','order_items','print_jobs','printers','table_orders','table_order_history','products','stores','store_campaigns','support_tickets','finance_suppliers','finance_cash_accounts','finance_cash_movements','finance_income_records','finance_expenses','finance_debts','finance_debt_payments','finance_employees','finance_salary_records','finance_salary_payments','finance_reconciliation_notes','finance_company_settings')) x)
      is distinct from '[{"tablename":"finance_income_records","tgname":"staff_scoped_write_guard","definition":"CREATE TRIGGER staff_scoped_write_guard BEFORE INSERT OR DELETE OR UPDATE ON public.finance_income_records FOR EACH ROW EXECUTE FUNCTION guard_restaurant_staff_scoped_write(''seller_id'', ''viewFinance'')","tgenabled":"O"},{"tablename":"order_items","tgname":"restaurant_staff_write_guard","definition":"CREATE TRIGGER restaurant_staff_write_guard BEFORE INSERT OR DELETE OR UPDATE ON public.order_items FOR EACH ROW EXECUTE FUNCTION guard_restaurant_staff_order_write()","tgenabled":"O"},{"tablename":"order_items","tgname":"test_items_money_guard","definition":"CREATE TRIGGER test_items_money_guard BEFORE INSERT ON public.order_items FOR EACH ROW EXECUTE FUNCTION test_money_guard()","tgenabled":"O"},{"tablename":"orders","tgname":"restaurant_staff_write_guard","definition":"CREATE TRIGGER restaurant_staff_write_guard BEFORE INSERT OR DELETE OR UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION guard_restaurant_staff_order_write()","tgenabled":"O"},{"tablename":"orders","tgname":"test_orders_money_guard","definition":"CREATE TRIGGER test_orders_money_guard BEFORE INSERT ON public.orders FOR EACH ROW EXECUTE FUNCTION test_money_guard()","tgenabled":"O"},{"tablename":"print_jobs","tgname":"restaurant_print_job_integrity","definition":"CREATE TRIGGER restaurant_print_job_integrity BEFORE INSERT OR UPDATE ON public.print_jobs FOR EACH ROW EXECUTE FUNCTION validate_restaurant_print_job()","tgenabled":"O"},{"tablename":"print_jobs","tgname":"restaurant_staff_write_guard","definition":"CREATE TRIGGER restaurant_staff_write_guard BEFORE INSERT OR DELETE OR UPDATE ON public.print_jobs FOR EACH ROW EXECUTE FUNCTION guard_restaurant_staff_order_write()","tgenabled":"O"},{"tablename":"store_sub_admins","tgname":"validate_restaurant_staff","definition":"CREATE TRIGGER validate_restaurant_staff BEFORE INSERT OR UPDATE ON public.store_sub_admins FOR EACH ROW EXECUTE FUNCTION validate_restaurant_staff_membership()","tgenabled":"O"},{"tablename":"stores","tgname":"staff_scoped_write_guard","definition":"CREATE TRIGGER staff_scoped_write_guard BEFORE INSERT OR DELETE OR UPDATE ON public.stores FOR EACH ROW EXECUTE FUNCTION guard_restaurant_staff_scoped_write(''seller_id'', ''manageStoreProfile'')","tgenabled":"O"},{"tablename":"table_order_history","tgname":"restaurant_staff_write_guard","definition":"CREATE TRIGGER restaurant_staff_write_guard BEFORE INSERT OR DELETE OR UPDATE ON public.table_order_history FOR EACH ROW EXECUTE FUNCTION guard_restaurant_staff_order_write()","tgenabled":"O"},{"tablename":"table_orders","tgname":"restaurant_staff_write_guard","definition":"CREATE TRIGGER restaurant_staff_write_guard BEFORE INSERT OR DELETE OR UPDATE ON public.table_orders FOR EACH ROW EXECUTE FUNCTION guard_restaurant_staff_order_write()","tgenabled":"O"}]'::jsonb then
      raise exception 'Rollback catalog drift: triggers';
    end if;
  end $drift$;
do $drift$ begin
    if (select coalesce(jsonb_agg(to_jsonb(x) order by pubname),'[]'::jsonb) from (select pubname,puballtables,pubinsert,pubupdate,pubdelete,pubtruncate from pg_publication) x)
      is distinct from '[{"pubname":"supabase_realtime","puballtables":false,"pubinsert":true,"pubupdate":true,"pubdelete":true,"pubtruncate":true}]'::jsonb then
      raise exception 'Rollback catalog drift: publications';
    end if;
  end $drift$;
do $drift$ begin
    if (select coalesce(jsonb_agg(to_jsonb(x) order by pubname,schemaname,tablename),'[]'::jsonb) from (select pubname,schemaname,tablename,attnames,rowfilter from pg_publication_tables
      where schemaname='public' and tablename in ('print_jobs','printers')) x)
      is distinct from '[{"pubname":"supabase_realtime","schemaname":"public","tablename":"print_jobs","attnames":["id","restaurant_id","order_id","station_id","printer_id","job_type","status","payload","retry_count","last_error","printed_at","created_at","order_saved_at","print_job_created_at","hub_job_received_at","claimed_at","dispatch_started_at","printer_write_started_at","printer_write_completed_at","completed_at","document_type","printer_role","claimed_by","last_attempt_at"],"rowfilter":null},{"pubname":"supabase_realtime","schemaname":"public","tablename":"printers","attnames":["id","restaurant_id","name","code","connection_type","ip_address","port","device_identifier","paper_width_mm","is_active","created_at","supports_cut","charset","assigned_roles","last_test_print_at","last_error","test_print_status","code_page","printer_profile_id","receipt_length_preset","receipt_bottom_feed_lines","receipt_cut_feed_lines","receipt_min_trailing_blank_lines","receipt_bottom_padding_px","receipt_min_receipt_height_px","print_size"],"rowfilter":null}]'::jsonb then
      raise exception 'Rollback catalog drift: members';
    end if;
  end $drift$;
do $drift$ begin
    if (select coalesce(jsonb_agg(to_jsonb(x) order by relname,grantee,privilege),'[]'::jsonb) from (select c.relname, case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end grantee,
      a.privilege_type privilege, a.is_grantable grantable
      from pg_class c
      cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
      where c.relnamespace='public'::regnamespace and c.relkind in ('r','p')
      and c.relname in ('store_sub_admins','store_tables','orders','order_items','print_jobs','printers','table_orders','table_order_history','products','stores','store_campaigns','support_tickets','finance_suppliers','finance_cash_accounts','finance_cash_movements','finance_income_records','finance_expenses','finance_debts','finance_debt_payments','finance_employees','finance_salary_records','finance_salary_payments','finance_reconciliation_notes','finance_company_settings')) x)
      is distinct from '[{"relname":"finance_income_records","grantee":"authenticated","privilege":"SELECT","grantable":false},{"relname":"finance_income_records","grantee":"postgres","privilege":"DELETE","grantable":false},{"relname":"finance_income_records","grantee":"postgres","privilege":"INSERT","grantable":false},{"relname":"finance_income_records","grantee":"postgres","privilege":"MAINTAIN","grantable":false},{"relname":"finance_income_records","grantee":"postgres","privilege":"REFERENCES","grantable":false},{"relname":"finance_income_records","grantee":"postgres","privilege":"SELECT","grantable":false},{"relname":"finance_income_records","grantee":"postgres","privilege":"TRIGGER","grantable":false},{"relname":"finance_income_records","grantee":"postgres","privilege":"TRUNCATE","grantable":false},{"relname":"finance_income_records","grantee":"postgres","privilege":"UPDATE","grantable":false},{"relname":"order_items","grantee":"authenticated","privilege":"DELETE","grantable":false},{"relname":"order_items","grantee":"authenticated","privilege":"INSERT","grantable":false},{"relname":"order_items","grantee":"authenticated","privilege":"SELECT","grantable":false},{"relname":"order_items","grantee":"authenticated","privilege":"UPDATE","grantable":false},{"relname":"order_items","grantee":"postgres","privilege":"DELETE","grantable":false},{"relname":"order_items","grantee":"postgres","privilege":"INSERT","grantable":false},{"relname":"order_items","grantee":"postgres","privilege":"MAINTAIN","grantable":false},{"relname":"order_items","grantee":"postgres","privilege":"REFERENCES","grantable":false},{"relname":"order_items","grantee":"postgres","privilege":"SELECT","grantable":false},{"relname":"order_items","grantee":"postgres","privilege":"TRIGGER","grantable":false},{"relname":"order_items","grantee":"postgres","privilege":"TRUNCATE","grantable":false},{"relname":"order_items","grantee":"postgres","privilege":"UPDATE","grantable":false},{"relname":"orders","grantee":"authenticated","privilege":"DELETE","grantable":false},{"relname":"orders","grantee":"authenticated","privilege":"INSERT","grantable":false},{"relname":"orders","grantee":"authenticated","privilege":"SELECT","grantable":false},{"relname":"orders","grantee":"authenticated","privilege":"UPDATE","grantable":false},{"relname":"orders","grantee":"postgres","privilege":"DELETE","grantable":false},{"relname":"orders","grantee":"postgres","privilege":"INSERT","grantable":false},{"relname":"orders","grantee":"postgres","privilege":"MAINTAIN","grantable":false},{"relname":"orders","grantee":"postgres","privilege":"REFERENCES","grantable":false},{"relname":"orders","grantee":"postgres","privilege":"SELECT","grantable":false},{"relname":"orders","grantee":"postgres","privilege":"TRIGGER","grantable":false},{"relname":"orders","grantee":"postgres","privilege":"TRUNCATE","grantable":false},{"relname":"orders","grantee":"postgres","privilege":"UPDATE","grantable":false},{"relname":"print_jobs","grantee":"authenticated","privilege":"DELETE","grantable":false},{"relname":"print_jobs","grantee":"authenticated","privilege":"INSERT","grantable":false},{"relname":"print_jobs","grantee":"authenticated","privilege":"SELECT","grantable":false},{"relname":"print_jobs","grantee":"authenticated","privilege":"UPDATE","grantable":false},{"relname":"print_jobs","grantee":"postgres","privilege":"DELETE","grantable":false},{"relname":"print_jobs","grantee":"postgres","privilege":"INSERT","grantable":false},{"relname":"print_jobs","grantee":"postgres","privilege":"MAINTAIN","grantable":false},{"relname":"print_jobs","grantee":"postgres","privilege":"REFERENCES","grantable":false},{"relname":"print_jobs","grantee":"postgres","privilege":"SELECT","grantable":false},{"relname":"print_jobs","grantee":"postgres","privilege":"TRIGGER","grantable":false},{"relname":"print_jobs","grantee":"postgres","privilege":"TRUNCATE","grantable":false},{"relname":"print_jobs","grantee":"postgres","privilege":"UPDATE","grantable":false},{"relname":"printers","grantee":"authenticated","privilege":"DELETE","grantable":false},{"relname":"printers","grantee":"authenticated","privilege":"INSERT","grantable":false},{"relname":"printers","grantee":"authenticated","privilege":"SELECT","grantable":false},{"relname":"printers","grantee":"authenticated","privilege":"UPDATE","grantable":false},{"relname":"printers","grantee":"postgres","privilege":"DELETE","grantable":false},{"relname":"printers","grantee":"postgres","privilege":"INSERT","grantable":false},{"relname":"printers","grantee":"postgres","privilege":"MAINTAIN","grantable":false},{"relname":"printers","grantee":"postgres","privilege":"REFERENCES","grantable":false},{"relname":"printers","grantee":"postgres","privilege":"SELECT","grantable":false},{"relname":"printers","grantee":"postgres","privilege":"TRIGGER","grantable":false},{"relname":"printers","grantee":"postgres","privilege":"TRUNCATE","grantable":false},{"relname":"printers","grantee":"postgres","privilege":"UPDATE","grantable":false},{"relname":"store_sub_admins","grantee":"authenticated","privilege":"DELETE","grantable":false},{"relname":"store_sub_admins","grantee":"authenticated","privilege":"INSERT","grantable":false},{"relname":"store_sub_admins","grantee":"authenticated","privilege":"SELECT","grantable":false},{"relname":"store_sub_admins","grantee":"authenticated","privilege":"UPDATE","grantable":false},{"relname":"store_sub_admins","grantee":"postgres","privilege":"DELETE","grantable":false},{"relname":"store_sub_admins","grantee":"postgres","privilege":"INSERT","grantable":false},{"relname":"store_sub_admins","grantee":"postgres","privilege":"MAINTAIN","grantable":false},{"relname":"store_sub_admins","grantee":"postgres","privilege":"REFERENCES","grantable":false},{"relname":"store_sub_admins","grantee":"postgres","privilege":"SELECT","grantable":false},{"relname":"store_sub_admins","grantee":"postgres","privilege":"TRIGGER","grantable":false},{"relname":"store_sub_admins","grantee":"postgres","privilege":"TRUNCATE","grantable":false},{"relname":"store_sub_admins","grantee":"postgres","privilege":"UPDATE","grantable":false},{"relname":"store_tables","grantee":"authenticated","privilege":"DELETE","grantable":false},{"relname":"store_tables","grantee":"authenticated","privilege":"INSERT","grantable":false},{"relname":"store_tables","grantee":"authenticated","privilege":"SELECT","grantable":false},{"relname":"store_tables","grantee":"authenticated","privilege":"UPDATE","grantable":false},{"relname":"store_tables","grantee":"postgres","privilege":"DELETE","grantable":false},{"relname":"store_tables","grantee":"postgres","privilege":"INSERT","grantable":false},{"relname":"store_tables","grantee":"postgres","privilege":"MAINTAIN","grantable":false},{"relname":"store_tables","grantee":"postgres","privilege":"REFERENCES","grantable":false},{"relname":"store_tables","grantee":"postgres","privilege":"SELECT","grantable":false},{"relname":"store_tables","grantee":"postgres","privilege":"TRIGGER","grantable":false},{"relname":"store_tables","grantee":"postgres","privilege":"TRUNCATE","grantable":false},{"relname":"store_tables","grantee":"postgres","privilege":"UPDATE","grantable":false},{"relname":"stores","grantee":"authenticated","privilege":"DELETE","grantable":false},{"relname":"stores","grantee":"authenticated","privilege":"INSERT","grantable":false},{"relname":"stores","grantee":"authenticated","privilege":"SELECT","grantable":false},{"relname":"stores","grantee":"authenticated","privilege":"UPDATE","grantable":false},{"relname":"stores","grantee":"postgres","privilege":"DELETE","grantable":false},{"relname":"stores","grantee":"postgres","privilege":"INSERT","grantable":false},{"relname":"stores","grantee":"postgres","privilege":"MAINTAIN","grantable":false},{"relname":"stores","grantee":"postgres","privilege":"REFERENCES","grantable":false},{"relname":"stores","grantee":"postgres","privilege":"SELECT","grantable":false},{"relname":"stores","grantee":"postgres","privilege":"TRIGGER","grantable":false},{"relname":"stores","grantee":"postgres","privilege":"TRUNCATE","grantable":false},{"relname":"stores","grantee":"postgres","privilege":"UPDATE","grantable":false},{"relname":"table_order_history","grantee":"authenticated","privilege":"DELETE","grantable":false},{"relname":"table_order_history","grantee":"authenticated","privilege":"INSERT","grantable":false},{"relname":"table_order_history","grantee":"authenticated","privilege":"SELECT","grantable":false},{"relname":"table_order_history","grantee":"authenticated","privilege":"UPDATE","grantable":false},{"relname":"table_order_history","grantee":"postgres","privilege":"DELETE","grantable":false},{"relname":"table_order_history","grantee":"postgres","privilege":"INSERT","grantable":false},{"relname":"table_order_history","grantee":"postgres","privilege":"MAINTAIN","grantable":false},{"relname":"table_order_history","grantee":"postgres","privilege":"REFERENCES","grantable":false},{"relname":"table_order_history","grantee":"postgres","privilege":"SELECT","grantable":false},{"relname":"table_order_history","grantee":"postgres","privilege":"TRIGGER","grantable":false},{"relname":"table_order_history","grantee":"postgres","privilege":"TRUNCATE","grantable":false},{"relname":"table_order_history","grantee":"postgres","privilege":"UPDATE","grantable":false},{"relname":"table_orders","grantee":"anon","privilege":"INSERT","grantable":false},{"relname":"table_orders","grantee":"authenticated","privilege":"DELETE","grantable":false},{"relname":"table_orders","grantee":"authenticated","privilege":"INSERT","grantable":false},{"relname":"table_orders","grantee":"authenticated","privilege":"SELECT","grantable":false},{"relname":"table_orders","grantee":"authenticated","privilege":"UPDATE","grantable":false},{"relname":"table_orders","grantee":"postgres","privilege":"DELETE","grantable":false},{"relname":"table_orders","grantee":"postgres","privilege":"INSERT","grantable":false},{"relname":"table_orders","grantee":"postgres","privilege":"MAINTAIN","grantable":false},{"relname":"table_orders","grantee":"postgres","privilege":"REFERENCES","grantable":false},{"relname":"table_orders","grantee":"postgres","privilege":"SELECT","grantable":false},{"relname":"table_orders","grantee":"postgres","privilege":"TRIGGER","grantable":false},{"relname":"table_orders","grantee":"postgres","privilege":"TRUNCATE","grantable":false},{"relname":"table_orders","grantee":"postgres","privilege":"UPDATE","grantable":false}]'::jsonb then
      raise exception 'Rollback catalog drift: privileges';
    end if;
  end $drift$;
drop trigger "staff_scoped_write_guard" on public."finance_income_records";
drop trigger "restaurant_staff_write_guard" on public."order_items";
drop trigger "test_items_money_guard" on public."order_items";
drop trigger "restaurant_staff_write_guard" on public."orders";
drop trigger "test_orders_money_guard" on public."orders";
drop trigger "restaurant_print_job_integrity" on public."print_jobs";
drop trigger "restaurant_staff_write_guard" on public."print_jobs";
drop trigger "validate_restaurant_staff" on public."store_sub_admins";
drop trigger "staff_scoped_write_guard" on public."stores";
drop trigger "restaurant_staff_write_guard" on public."table_order_history";
drop trigger "restaurant_staff_write_guard" on public."table_orders";
drop policy "staff_permission_read" on public."finance_income_records";
drop policy "staff_permission_read_guard" on public."finance_income_records";
drop policy "restaurant_staff_items_read_guard" on public."order_items";
drop policy "restaurant_staff_orders_read_guard" on public."orders";
drop policy "restaurant_staff_orders_write_guard" on public."orders";
drop policy "restaurant_staff_jobs_write_guard" on public."print_jobs";
drop policy "staff_membership_delete_guard" on public."store_sub_admins";
drop policy "staff_membership_insert_guard" on public."store_sub_admins";
drop policy "staff_membership_update_guard" on public."store_sub_admins";
drop policy "store_sub_admins_active_self_select" on public."store_sub_admins";
drop policy "store_sub_admins_owner_all" on public."store_sub_admins";
drop policy "staff_permission_delete" on public."stores";
drop policy "staff_permission_insert" on public."stores";
drop policy "staff_permission_read" on public."stores";
drop policy "staff_permission_update" on public."stores";
drop policy "staff_history_read_guard" on public."table_order_history";
drop policy "sentinel_restrictive" on public."table_orders";
drop policy "staff_table_orders_branch_guard" on public."table_orders";
drop policy "table_orders_customer_insert" on public."table_orders";
drop policy "table_orders_delete_staff" on public."table_orders";
drop policy "table_orders_read_staff" on public."table_orders";
drop policy "table_orders_update_staff" on public."table_orders";
CREATE OR REPLACE FUNCTION public.activate_my_sub_admin_invites()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_u_email text := '';
  v_u_phone text := '';
  v_au_email text := '';
  v_au_phone text := '';
  v_meta_email text := '';
  v_meta_phone text := '';
  v_jwt_email text := '';
  v_jwt_phone text := '';
  v_updated integer := 0;
begin
  if v_uid is null then
    return 0;
  end if;

  begin
    select
      lower(trim(coalesce(u.email, ''))),
      public.normalize_tr_phone(u.phone)
    into v_u_email, v_u_phone
    from public.users u
    where u.id = v_uid
    limit 1;
  exception when others then
    null;
  end;

  begin
    select
      lower(trim(coalesce(au.email, ''))),
      public.normalize_tr_phone(au.phone),
      lower(trim(coalesce(au.raw_user_meta_data ->> 'email', ''))),
      public.normalize_tr_phone(coalesce(au.raw_user_meta_data ->> 'phone', au.raw_user_meta_data ->> 'phone_number', ''))
    into v_au_email, v_au_phone, v_meta_email, v_meta_phone
    from auth.users au
    where au.id = v_uid
    limit 1;
  exception when others then
    null;
  end;

  begin
    v_jwt_email := lower(trim(coalesce(
      auth.jwt() ->> 'email',
      auth.jwt() -> 'user_metadata' ->> 'email',
      ''
    )));
    v_jwt_phone := public.normalize_tr_phone(coalesce(
      auth.jwt() ->> 'phone',
      auth.jwt() -> 'user_metadata' ->> 'phone',
      ''
    ));
  exception when others then
    null;
  end;

  update public.store_sub_admins sa
  set status = 'active'
  where coalesce(lower(trim(sa.status)), 'invited') = 'invited'
    and (
      (
        nullif(lower(trim(coalesce(sa.email, ''))), '') is not null
        and lower(trim(sa.email)) in (
          nullif(v_u_email, ''),
          nullif(v_au_email, ''),
          nullif(v_meta_email, ''),
          nullif(v_jwt_email, '')
        )
      )
      or (
        length(public.normalize_tr_phone(sa.phone)) >= 10
        and public.normalize_tr_phone(sa.phone) in (
          nullif(v_u_phone, ''),
          nullif(v_au_phone, ''),
          nullif(v_meta_phone, ''),
          nullif(v_jwt_phone, '')
        )
      )
    );

  get diagnostics v_updated = row_count;
  return v_updated;
end;
$function$
;
alter function activate_my_sub_admin_invites() owner to "postgres";
revoke all on function activate_my_sub_admin_invites() from PUBLIC;
revoke all on function activate_my_sub_admin_invites() from "postgres";
grant execute on function activate_my_sub_admin_invites() to PUBLIC;
grant execute on function activate_my_sub_admin_invites() to "postgres";
comment on function activate_my_sub_admin_invites() is null;
CREATE OR REPLACE FUNCTION public.close_table_with_history(p_seller_id uuid, p_table_number integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  return '{}'::jsonb;
END;
$function$
;
alter function close_table_with_history(uuid,integer) owner to "postgres";
revoke all on function close_table_with_history(uuid,integer) from PUBLIC;
revoke all on function close_table_with_history(uuid,integer) from "postgres";
grant execute on function close_table_with_history(uuid,integer) to PUBLIC;
grant execute on function close_table_with_history(uuid,integer) to "postgres";
comment on function close_table_with_history(uuid,integer) is null;
CREATE OR REPLACE FUNCTION public.create_table_order_with_print_jobs(p_restaurant_id uuid, p_table_number integer, p_items jsonb, p_waiter_id uuid DEFAULT NULL::uuid, p_waiter_name text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_job_type text DEFAULT 'new_order'::text, p_order_type text DEFAULT 'table'::text, p_local_order_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  if not public.user_can_access_restaurant(p_restaurant_id) then
    raise exception 'Bu restoran için işlem yetkiniz yok.' using errcode = '42501';
  end if;

  return public.create_table_order_with_print_jobs_impl(
    p_restaurant_id,
    p_table_number,
    p_items,
    p_waiter_id,
    p_waiter_name,
    p_notes,
    p_job_type,
    p_order_type,
    p_local_order_id
  );
end;
$function$
;
alter function create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text,text) owner to "postgres";
revoke all on function create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text,text) from PUBLIC;
revoke all on function create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text,text) from "postgres";
grant execute on function create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text,text) to PUBLIC;
grant execute on function create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text,text) to "postgres";
comment on function create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text,text) is null;
CREATE OR REPLACE FUNCTION public.create_table_order_with_print_jobs_impl(p_restaurant_id uuid, p_table_number integer, p_items jsonb, p_waiter_id uuid DEFAULT NULL::uuid, p_waiter_name text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_job_type text DEFAULT 'new_order'::text, p_order_type text DEFAULT 'table'::text, p_local_order_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  if not public.user_can_access_restaurant(p_restaurant_id) then
    raise exception 'Bu restoran için işlem yetkiniz yok.' using errcode = '42501';
  end if;

  -- Davet durumundaki garson kaydını otomatik aktif et (best-effort).
  begin
    perform public.activate_my_sub_admin_invites();
  exception when others then
    null;
  end;

  if p_items is null
    or jsonb_typeof(p_items) <> 'array'
    or jsonb_array_length(p_items) = 0 then
    raise exception 'Sipariş kalemleri boş olamaz.' using errcode = '22023';
  end if;

  if p_job_type not in ('new_order', 'add_item', 'cancel_item', 'reprint') then
    raise exception 'Geçersiz job_type: %', p_job_type using errcode = '22023';
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

  select business_name
  into v_restaurant_name
  from public.stores
  where seller_id = p_restaurant_id
     or id = p_restaurant_id
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
    'daily_order_no', v_daily_order_no,
    'print_job_ids', v_print_job_ids,
    'print_job_count', jsonb_array_length(v_print_job_ids),
    'order_saved_at', v_order_created_at,
    'print_job_created_at', now()
  );
end;
$function$
;
alter function create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text) owner to "postgres";
revoke all on function create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text) from PUBLIC;
revoke all on function create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text) from "postgres";
revoke all on function create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text) from "authenticated";
grant execute on function create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text) to PUBLIC;
grant execute on function create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text) to "postgres";
comment on function create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text) is null;
CREATE OR REPLACE FUNCTION public.finance_get_monthly_trend(uuid, integer)
 RETURNS integer
 LANGUAGE sql
AS $function$select 42$function$
;
alter function finance_get_monthly_trend(uuid,integer) owner to "postgres";
revoke all on function finance_get_monthly_trend(uuid,integer) from PUBLIC;
revoke all on function finance_get_monthly_trend(uuid,integer) from "postgres";
grant execute on function finance_get_monthly_trend(uuid,integer) to PUBLIC;
grant execute on function finance_get_monthly_trend(uuid,integer) to "postgres";
comment on function finance_get_monthly_trend(uuid,integer) is null;
CREATE OR REPLACE FUNCTION public.finance_get_overview(p_seller_id uuid)
 RETURNS numeric
 LANGUAGE sql
 SECURITY DEFINER
AS $function$select sum(net_amount) from finance_income_records where seller_id=p_seller_id$function$
;
alter function finance_get_overview(uuid) owner to "postgres";
revoke all on function finance_get_overview(uuid) from PUBLIC;
revoke all on function finance_get_overview(uuid) from "postgres";
grant execute on function finance_get_overview(uuid) to PUBLIC;
grant execute on function finance_get_overview(uuid) to "postgres";
comment on function finance_get_overview(uuid) is null;
CREATE OR REPLACE FUNCTION public.user_can_access_restaurant(p_restaurant_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_u_email text := '';
  v_u_phone text := '';
  v_au_email text := '';
  v_au_phone text := '';
  v_meta_email text := '';
  v_meta_phone text := '';
  v_jwt_email text := '';
  v_jwt_phone text := '';
  v_claim_email text := '';
  v_claim_phone text := '';
begin
  if p_restaurant_id is null or v_uid is null then
    return false;
  end if;

  -- Restoran sahibi doğrudan erişebilir.
  if v_uid = p_restaurant_id then
    return true;
  end if;

  -- stores.id veya stores.seller_id eşleşmesi.
  if exists (
    select 1
    from public.stores s
    where (s.seller_id = p_restaurant_id and s.id = v_uid)
       or (s.id = p_restaurant_id and s.seller_id = v_uid)
  ) then
    return true;
  end if;

  -- public.users tablosundan kimlik bilgisi.
  begin
    select
      lower(trim(coalesce(u.email, ''))),
      public.normalize_tr_phone(u.phone)
    into v_u_email, v_u_phone
    from public.users u
    where u.id = v_uid
    limit 1;
  exception when others then
    v_u_email := '';
    v_u_phone := '';
  end;

  -- auth.users tablosundan kimlik ve metadata bilgisi.
  begin
    select
      lower(trim(coalesce(au.email, ''))),
      public.normalize_tr_phone(au.phone),
      lower(trim(coalesce(au.raw_user_meta_data ->> 'email', ''))),
      public.normalize_tr_phone(coalesce(au.raw_user_meta_data ->> 'phone', au.raw_user_meta_data ->> 'phone_number', ''))
    into v_au_email, v_au_phone, v_meta_email, v_meta_phone
    from auth.users au
    where au.id = v_uid
    limit 1;
  exception when others then
    v_au_email := '';
    v_au_phone := '';
    v_meta_email := '';
    v_meta_phone := '';
  end;

  -- JWT claim bilgileri.
  begin
    v_jwt_email := lower(trim(coalesce(
      auth.jwt() ->> 'email',
      auth.jwt() -> 'user_metadata' ->> 'email',
      ''
    )));
    v_jwt_phone := public.normalize_tr_phone(coalesce(
      auth.jwt() ->> 'phone',
      auth.jwt() -> 'user_metadata' ->> 'phone',
      auth.jwt() -> 'user_metadata' ->> 'phone_number',
      ''
    ));
  exception when others then
    v_jwt_email := '';
    v_jwt_phone := '';
  end;

  v_claim_email := lower(trim(coalesce(current_setting('request.jwt.claim.email', true), '')));
  v_claim_phone := public.normalize_tr_phone(coalesce(current_setting('request.jwt.claim.phone', true), ''));

  return exists (
    select 1
    from public.store_sub_admins sa
    where (
      sa.store_id = p_restaurant_id
      or exists (
        select 1
        from public.stores s
        where s.id = sa.store_id
          and s.seller_id = p_restaurant_id
      )
    )
    and coalesce(lower(trim(sa.status)), 'active') in ('active', 'invited', 'approved', 'enabled')
    and (
      (
        nullif(lower(trim(coalesce(sa.email, ''))), '') is not null
        and lower(trim(sa.email)) in (
          nullif(v_u_email, ''),
          nullif(v_au_email, ''),
          nullif(v_meta_email, ''),
          nullif(v_jwt_email, ''),
          nullif(v_claim_email, '')
        )
      )
      or (
        length(public.normalize_tr_phone(sa.phone)) >= 10
        and public.normalize_tr_phone(sa.phone) in (
          nullif(v_u_phone, ''),
          nullif(v_au_phone, ''),
          nullif(v_meta_phone, ''),
          nullif(v_jwt_phone, ''),
          nullif(v_claim_phone, '')
        )
      )
    )
  );
end;
$function$
;
alter function user_can_access_restaurant(uuid) owner to "postgres";
revoke all on function user_can_access_restaurant(uuid) from PUBLIC;
revoke all on function user_can_access_restaurant(uuid) from "postgres";
revoke all on function user_can_access_restaurant(uuid) from "authenticated";
grant execute on function user_can_access_restaurant(uuid) to "postgres";
grant execute on function user_can_access_restaurant(uuid) to "authenticated" with grant option;
comment on function user_can_access_restaurant(uuid) is 'baseline ACL/comment sentinel';
do $rollback$ declare pending text[]:=array['get_my_staff_access()','guard_restaurant_staff_order_write()','guard_restaurant_staff_scoped_write()','is_managed_restaurant_staff()','restaurant_customer_table_order_target(text)','restaurant_has_permission(uuid,text)','restaurant_order_access(uuid,text)','restaurant_table_access(uuid,uuid)','restaurant_table_number_access(uuid,integer)','validate_restaurant_print_job()','validate_restaurant_staff_membership()'];
    next_pending text[]; sig text; n integer;
    begin
      loop
        n:=cardinality(pending); exit when n=0; next_pending:='{}';
        foreach sig in array pending loop
          begin execute 'drop function '||sig;
          exception when dependent_objects_still_exist then next_pending:=array_append(next_pending,sig); end;
        end loop;
        if cardinality(next_pending)=n then raise exception 'Rollback external dependencies: %',next_pending; end if;
        pending:=next_pending;
      end loop;
    end $rollback$;
create policy "store_sub_admins_owner_all" on public."store_sub_admins" as PERMISSIVE
      for ALL to "authenticated"
      using ((store_id = auth.uid()))
      with check ((store_id = auth.uid()));
create policy "store_sub_admins_self_activate_update" on public."store_sub_admins" as PERMISSIVE
      for UPDATE to "authenticated"
      using (true)
      ;
create policy "Anyone can insert" on public."table_orders" as PERMISSIVE
      for INSERT to "anon"
      
      with check (true);
create policy "sentinel_restrictive" on public."table_orders" as RESTRICTIVE
      for SELECT to "authenticated"
      using ((table_number > 0))
      ;
create policy "table_orders_authenticated_all" on public."table_orders" as PERMISSIVE
      for ALL to "authenticated"
      using (true)
      with check (true);
CREATE TRIGGER test_items_money_guard BEFORE INSERT ON public.order_items FOR EACH ROW EXECUTE FUNCTION test_money_guard();
alter table public."order_items" enable trigger "test_items_money_guard";
CREATE TRIGGER test_orders_money_guard BEFORE INSERT ON public.orders FOR EACH ROW EXECUTE FUNCTION test_money_guard();
alter table public."orders" enable trigger "test_orders_money_guard";
revoke all on table public."table_orders" from "anon";
alter table public."finance_income_records" enable row level security;
alter table public."finance_income_records" no force row level security;
alter table public."order_items" disable row level security;
alter table public."order_items" no force row level security;
alter table public."orders" disable row level security;
alter table public."orders" no force row level security;
alter table public."print_jobs" disable row level security;
alter table public."print_jobs" force row level security;
alter table public."printers" disable row level security;
alter table public."printers" no force row level security;
alter table public."store_sub_admins" enable row level security;
alter table public."store_sub_admins" no force row level security;
alter table public."store_tables" disable row level security;
alter table public."store_tables" no force row level security;
alter table public."stores" disable row level security;
alter table public."stores" no force row level security;
alter table public."table_order_history" disable row level security;
alter table public."table_order_history" no force row level security;
alter table public."table_orders" enable row level security;
alter table public."table_orders" no force row level security;
notify pgrst,'reload schema';
commit;
