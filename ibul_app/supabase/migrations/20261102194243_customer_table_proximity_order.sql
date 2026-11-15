-- DO NOT APPLY to the live project from this workspace.
-- Customer table_orders inserts fail the restrictive staff branch policy.
-- One security-definer request checks store coordinates, a 100 metre limit,
-- catalog price, and waiter-call rate. It does not disable RLS and does not
-- grant a blanket INSERT policy. Coordinates are not stored.

begin;

create or replace function public.ibul_distance_meters(
  p_lat1 double precision,
  p_lon1 double precision,
  p_lat2 double precision,
  p_lon2 double precision
)
returns double precision
language sql
immutable
set search_path = pg_catalog
as $$
  select 6371000 * 2 * asin(least(1, sqrt(
    power(sin(radians(p_lat2 - p_lat1) / 2), 2)
    + cos(radians(p_lat1)) * cos(radians(p_lat2))
      * power(sin(radians(p_lon2 - p_lon1) / 2), 2)
  )));
$$;

revoke all on function public.ibul_distance_meters(
  double precision, double precision, double precision, double precision
) from public, anon, authenticated;

create or replace function public.ibul_as_numeric(p_text text)
returns numeric
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  v text := nullif(btrim(coalesce(p_text, '')), '');
begin
  if v is null then
    return null;
  end if;
  if v !~ '^[0-9]+(\.[0-9]+)?$' then
    raise exception 'Sayı biçimi geçersiz.' using errcode = '22023';
  end if;
  return v::numeric;
end;
$$;

revoke all on function public.ibul_as_numeric(text)
  from public, anon, authenticated;

create table if not exists public.customer_proximity_grants (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  grant_code text not null,
  customer_session_id text not null,
  staff_confirmed boolean not null default false,
  expires_at timestamptz not null,
  used_at timestamptz,
  used_request_id text,
  created_by uuid not null,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.customer_proximity_grants enable row level security;
revoke all on public.customer_proximity_grants from public, anon, authenticated;

drop function if exists public.issue_customer_proximity_grant(uuid, integer);

create or replace function public.issue_customer_proximity_grant(
  p_seller_id uuid,
  p_table_number integer,
  p_customer_session_id text,
  p_staff_confirmed boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_session text := nullif(btrim(coalesce(p_customer_session_id, '')), '');
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;
  if coalesce(p_staff_confirmed, false) is not true then
    raise exception 'Müşteriyi masada gördüğünüz onaylanmadı. Kod üretilmedi.'
      using errcode = '42501';
  end if;
  if v_session is null or length(v_session) < 8 or length(v_session) > 64
     or v_session !~ '^[A-Za-z0-9-]+$' then
    raise exception 'Müşteri oturum kodu geçersiz.' using errcode = '22023';
  end if;
  if not public.restaurant_has_permission(p_seller_id, 'manageOrders') then
    raise exception 'Bu işlem için yetkiniz yok.' using errcode = '42501';
  end if;
  if not public.restaurant_table_number_access(p_seller_id, p_table_number) then
    raise exception 'Bu masada işlem yetkiniz yok.' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.store_tables t
    where t.seller_id = p_seller_id
      and t.table_number = p_table_number
      and coalesce(t.is_active, true)
  ) then
    raise exception 'Masa bu işletmede yok.' using errcode = '22023';
  end if;
  v_code := replace(gen_random_uuid()::text, '-', '');
  insert into public.customer_proximity_grants (
    seller_id, table_number, grant_code, customer_session_id,
    staff_confirmed, expires_at, created_by
  ) values (
    p_seller_id, p_table_number, v_code, v_session,
    true, timezone('utc', now()) + interval '15 minutes', auth.uid()
  );
  return jsonb_build_object(
    'grant_code', v_code,
    'expires_in_seconds', 900,
    'table_number', p_table_number
  );
end;
$$;

revoke all on function public.issue_customer_proximity_grant(uuid, integer, text, boolean)
  from public, anon;
grant execute on function public.issue_customer_proximity_grant(uuid, integer, text, boolean)
  to authenticated;

create or replace function public.ibul_quote_customer_unit(
  p_product jsonb,
  p_item jsonb
)
returns numeric
language plpgsql
stable
set search_path = public
as $$
declare
  v_size_id text := nullif(btrim(coalesce(p_item->>'selectedSizeId', p_item->>'sizeId', '')), '');
  v_size_name text := nullif(btrim(coalesce(p_item->>'selectedSizeName', '')), '');
  v_sku text := nullif(btrim(coalesce(p_item->>'variantSku', p_item->>'sku', '')), '');
  v_service text := lower(btrim(coalesce(p_item->>'serviceControlType', '')));
  v_grams numeric := public.ibul_as_numeric(coalesce(p_item->>'selectedWeightGrams', p_item->>'weightGrams'));
  v_portion numeric := public.ibul_as_numeric(coalesce(p_item->>'selectedServiceAmount', p_item->>'portionAmount'));
  v_price numeric;
  v_base numeric;
  v_diff numeric;
  v_step numeric;
  v_min numeric;
  v_max numeric;
  v_kg numeric;
  v_options jsonb;
begin
  if p_product->>'status' is distinct from 'Aktif'
     or p_product->>'approval_status' is distinct from 'approved' then
    raise exception 'Ürün satışı kapalı.' using errcode = '42501';
  end if;
  if p_product->>'stock' is not null and public.ibul_as_numeric(p_product->>'stock') <= 0 then
    raise exception 'Ürün satışı kapalı.' using errcode = '42501';
  end if;
  if jsonb_typeof(p_item->'extras') = 'array'
     and jsonb_array_length(p_item->'extras') > 0 then
    raise exception 'Ekstra malzeme fiyatı katalogda yok. Sipariş gönderilmedi.'
      using errcode = '22023';
  end if;

  if v_size_id is not null or v_size_name is not null then
    v_options := p_product->'size_options';
    select round(public.ibul_as_numeric(coalesce(entry->>'price', entry->>'size_price')), 2)
      into v_price
    from jsonb_array_elements(
      case when jsonb_typeof(v_options) = 'array' then v_options else '[]'::jsonb end
    ) entry
    where (v_size_id is not null and entry->>'id' = v_size_id)
       or (v_size_name is not null and lower(btrim(coalesce(entry->>'name', ''))) = lower(v_size_name))
    limit 1;
    if v_price is null then
      raise exception 'Boyut seçeneği bulunamadı.' using errcode = '42501';
    end if;
    return v_price;
  end if;

  if v_sku is not null then
    select
      public.ibul_as_numeric(coalesce(entry->>'priceDifference', entry->>'price_difference', '0')),
      public.ibul_as_numeric(entry->>'price')
      into v_diff, v_price
    from jsonb_array_elements(
      case
        when jsonb_typeof(p_product->'variants') = 'array' then p_product->'variants'
        else '[]'::jsonb
      end
    ) entry
    where entry->>'sku' = v_sku or entry->>'id' = v_sku
    limit 1;
    if not found then
      raise exception 'Varyant bu ürüne ait değil.' using errcode = '42501';
    end if;
    if v_price is not null then
      return round(v_price, 2);
    end if;
    v_base := coalesce(
      public.ibul_as_numeric(p_product->>'base_price'),
      public.ibul_as_numeric(p_product->>'price')
    );
    if v_base is null then
      raise exception 'Varyant fiyatı katalogda yok. Sipariş gönderilmedi.'
        using errcode = '22023';
    end if;
    return round(v_base + v_diff, 2);
  end if;

  if v_grams is not null
     or v_service = 'weight_stepper'
     or lower(coalesce(p_product->>'pricing_type', '')) = 'weight'
     or lower(coalesce(p_product->>'service_control_type', '')) = 'weight_stepper' then
    v_kg := public.ibul_as_numeric(p_product->>'price_per_kg');
    if v_kg is null or v_kg <= 0 then
      raise exception 'Kilogram fiyatı katalogda yok. Sipariş gönderilmedi.'
        using errcode = '22023';
    end if;
    if v_grams is null or v_grams <= 0 or v_grams > 100000 then
      raise exception 'Gramaj geçersiz. Sipariş gönderilmedi.' using errcode = '22023';
    end if;
    if public.ibul_as_numeric(p_product->>'min_weight_grams') is null
       and public.ibul_as_numeric(p_product->>'weight_step_grams') is null then
      v_min := 500;
      v_step := 250;
    else
      v_min := coalesce(public.ibul_as_numeric(p_product->>'min_weight_grams'), 1);
      v_step := coalesce(public.ibul_as_numeric(p_product->>'weight_step_grams'), 1);
    end if;
    v_max := public.ibul_as_numeric(p_product->>'max_weight_grams');
    if v_grams < v_min or (v_max is not null and v_grams > v_max)
       or mod(v_grams - v_min, v_step) <> 0 then
      raise exception 'Gramaj katalog adımıyla uyuşmuyor.' using errcode = '22023';
    end if;
    return round(v_grams * v_kg / 1000, 2);
  end if;

  if v_portion is not null
     or v_service in ('portion_stepper', 'skewer_stepper')
     or lower(coalesce(p_product->>'service_control_type', '')) in ('portion_stepper', 'skewer_stepper') then
    v_base := coalesce(
      public.ibul_as_numeric(p_product->>'portion_price'),
      public.ibul_as_numeric(p_product->>'base_price')
    );
    if v_base is null or v_base <= 0 then
      raise exception 'Porsiyon fiyatı katalogda yok. Sipariş gönderilmedi.'
        using errcode = '22023';
    end if;
    if v_portion is null or v_portion <= 0 then
      raise exception 'Porsiyon miktarı geçersiz. Sipariş gönderilmedi.'
        using errcode = '22023';
    end if;
    if v_service = 'skewer_stepper'
       or lower(coalesce(p_product->>'service_control_type', '')) = 'skewer_stepper' then
      v_min := coalesce(public.ibul_as_numeric(p_product->>'min_portion'), 1);
      v_step := coalesce(public.ibul_as_numeric(p_product->>'portion_step'), 1);
      v_max := coalesce(public.ibul_as_numeric(p_product->>'max_portion'), 3);
    else
      v_min := coalesce(public.ibul_as_numeric(p_product->>'min_portion'), 0.5);
      v_step := coalesce(public.ibul_as_numeric(p_product->>'portion_step'), 0.5);
      v_max := coalesce(public.ibul_as_numeric(p_product->>'max_portion'), 20);
    end if;
    if v_portion < v_min or v_portion > v_max or mod(v_portion - v_min, v_step) <> 0 then
      raise exception 'Porsiyon miktarı katalog adımıyla uyuşmuyor.'
        using errcode = '22023';
    end if;
    return round(v_base * v_portion, 2);
  end if;

  v_price := public.ibul_as_numeric(p_product->>'price');
  if v_price is null then
    raise exception 'Ürün fiyatı katalogda yok. Sipariş gönderilmedi.'
      using errcode = '22023';
  end if;
  return round(v_price, 2);
end;
$$;

revoke all on function public.ibul_quote_customer_unit(jsonb, jsonb)
  from public, anon, authenticated;

drop function if exists public.place_customer_table_order(
  uuid, integer, jsonb, double precision, double precision, double precision, text, text, text
);
drop function if exists public.place_customer_table_order(
  uuid, integer, jsonb, double precision, double precision, double precision,
  text, text, text, text, boolean, text
);

create or replace function public.place_customer_table_order(
  p_seller_id uuid,
  p_table_number integer,
  p_items jsonb,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_m double precision,
  p_action text,
  p_client_request_id text,
  p_grant_code text default null,
  p_customer_session_id text default null,
  p_confirm_server_price boolean default false,
  p_qr_token text default null,
  p_price_confirm_token text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_lat double precision;
  v_store_lng double precision;
  v_distance double precision;
  v_action text := lower(btrim(coalesce(p_action, 'order')));
  v_request text := nullif(btrim(coalesce(p_client_request_id, '')), '');
  v_session text := nullif(btrim(coalesce(p_customer_session_id, '')), '');
  v_qr text := nullif(btrim(coalesce(p_qr_token, '')), '');
  v_table_qr text;
  v_existing public.table_orders;
  v_items jsonb := '[]'::jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_item jsonb;
  v_product jsonb;
  v_product_id text;
  v_qty integer;
  v_unit numeric;
  v_client numeric;
  v_total numeric := 0;
  v_shape text := '';
  v_mismatch boolean := false;
  v_grant_id uuid;
  v_inserted public.table_orders;
  v_recent_call public.table_orders;
  v_price_token text;
begin
  if p_seller_id is null or p_table_number is null or p_table_number <= 0 then
    raise exception 'Geçersiz masa.' using errcode = '22023';
  end if;
  if v_request is null or length(v_request) > 80 then
    raise exception 'Sipariş isteği kimliği zorunlu.' using errcode = '22023';
  end if;
  if v_action not in ('order', 'waiter_call') then
    raise exception 'Geçersiz masa isteği.' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.stores s where s.seller_id = p_seller_id
  ) then
    raise exception 'İşletme bulunamadı.' using errcode = '22023';
  end if;
  select t.qr_token into v_table_qr
  from public.store_tables t
  where t.seller_id = p_seller_id
    and t.table_number = p_table_number
    and coalesce(t.is_active, true)
  limit 1;
  if not found then
    raise exception 'Masa bu işletmede yok.' using errcode = '22023';
  end if;
  if v_qr is not null and v_table_qr is distinct from v_qr then
    raise exception 'QR kodu bu masa ile eşleşmiyor.' using errcode = '42501';
  end if;

  if v_action = 'waiter_call' then
    v_shape := 'waiter_call';
  else
    if p_items is null or jsonb_typeof(p_items) <> 'array'
       or jsonb_array_length(p_items) = 0
       or jsonb_array_length(p_items) > 60 then
      raise exception 'Sipariş boş. Gönderilmedi.' using errcode = '22023';
    end if;
    for v_item in select value from jsonb_array_elements(p_items) loop
      v_product_id := nullif(btrim(coalesce(v_item->>'productId', v_item->>'product_id', '')), '');
      v_qty := least(99, greatest(1, coalesce(public.ibul_as_numeric(v_item->>'quantity'), 1)::integer));
      v_shape := v_shape || coalesce(v_product_id, '') || ':' || v_qty::text || ':'
        || lower(btrim(coalesce(v_item->>'selectedSizeName', ''))) || ':'
        || coalesce(v_item->>'selectedWeightGrams', '') || ':'
        || coalesce(v_item->>'selectedServiceAmount', '') || ':'
        || coalesce(v_item->>'variantSku', '') || ';';
    end loop;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    p_seller_id::text || ':customer:' || v_request, 0
  ));
  select * into v_existing
  from public.table_orders
  where seller_id = p_seller_id::text
    and last_edit_summary->>'client_request_id' = v_request
  limit 1;
  if found then
    if coalesce(v_existing.last_edit_summary->>'line_shape', '')
        is distinct from v_shape then
      raise exception
        'Bu gönderim kimliği başka bir siparişe ait. Yeni sipariş açılmadı.'
        using errcode = '23505';
    end if;
    return jsonb_build_object(
      'id', v_existing.id,
      'status', v_existing.status,
      'idempotent_replay', true,
      'content_mismatch', false,
      'notification_delivered', false
    );
  end if;

  if nullif(btrim(coalesce(p_grant_code, '')), '') is not null then
    if v_session is null then
      raise exception 'Personel onay kodu bu oturuma bağlı değil.'
        using errcode = '42501';
    end if;
    select g.id into v_grant_id
    from public.customer_proximity_grants g
    where g.seller_id = p_seller_id
      and g.table_number = p_table_number
      and g.grant_code = btrim(p_grant_code)
      and g.customer_session_id = v_session
      and g.staff_confirmed is true
      and g.used_at is null
      and g.expires_at > timezone('utc', now());
    if v_grant_id is null then
      raise exception 'Personel onay kodu geçersiz. Sipariş gönderilmedi.'
        using errcode = '42501';
    end if;
  else
    if p_latitude is null or p_longitude is null
       or p_latitude < -90 or p_latitude > 90
       or p_longitude < -180 or p_longitude > 180
       or p_accuracy_m is null or p_accuracy_m <= 0 or p_accuracy_m > 50 then
      raise exception 'Konum doğrulanamadı. Sipariş gönderilmedi.'
        using errcode = '42501';
    end if;
    select s.store_lat, s.store_lng into v_store_lat, v_store_lng
    from public.stores s
    where s.seller_id = p_seller_id;
    if v_store_lat is null or v_store_lng is null then
      raise exception 'İşletme konumu doğrulanamadı. Sipariş gönderilmedi.'
        using errcode = '42501';
    end if;
    v_distance := public.ibul_distance_meters(
      p_latitude, p_longitude, v_store_lat, v_store_lng
    );
    if v_distance + p_accuracy_m > 100 then
      raise exception 'İşletmeye 100 metreden uzaksınız. Sipariş gönderilmedi.'
        using errcode = '42501';
    end if;
  end if;

  if v_action = 'waiter_call' then
    select * into v_recent_call
    from public.table_orders
    where seller_id = p_seller_id::text
      and table_number = p_table_number
      and status = 'call_waiter'
      and created_at > timezone('utc', now()) - interval '90 seconds'
    order by created_at desc
    limit 1;
    if found then
      return jsonb_build_object(
        'id', v_recent_call.id,
        'status', v_recent_call.status,
        'idempotent_replay', true,
        'call_recorded', true,
        'notification_delivered', false
      );
    end if;
    v_items := jsonb_build_array(jsonb_build_object(
      'name', 'Garson Çağrıldı',
      'quantity', 1,
      'price', 0,
      'type', 'waiter_call'
    ));
  else
    for v_item in select value from jsonb_array_elements(p_items) loop
      v_product_id := nullif(btrim(coalesce(v_item->>'productId', v_item->>'product_id', '')), '');
      if v_product_id is null then
        raise exception 'Ürün bu işletmeye ait değil.' using errcode = '42501';
      end if;
      select to_jsonb(p) into v_product
      from public.products p
      where p.id = v_product_id
        and p.seller_id = p_seller_id;
      if v_product is null then
        raise exception 'Ürün bu işletmeye ait değil.' using errcode = '42501';
      end if;
      v_qty := least(99, greatest(1, coalesce(public.ibul_as_numeric(v_item->>'quantity'), 1)::integer));
      v_unit := public.ibul_quote_customer_unit(v_product, v_item);
      v_client := public.ibul_as_numeric(v_item->>'price');
      if v_client is null or abs(v_client - v_unit) > 0.01 then
        v_mismatch := true;
      end if;
      v_total := v_total + round(v_unit * v_qty, 2);
      v_lines := v_lines || jsonb_build_array(jsonb_build_object(
        'productId', v_product_id,
        'name', v_product->>'name',
        'price', v_unit,
        'quantity', v_qty
      ));
      v_items := v_items || jsonb_build_array(jsonb_build_object(
        'productId', v_product_id,
        'name', v_product->>'name',
        'price', v_unit,
        'quantity', v_qty
      ));
    end loop;
    v_price_token := encode(
      extensions.digest(
        convert_to(v_request || '|' || v_shape || '|' || v_total::text, 'UTF8'),
        'sha256'
      ),
      'hex'
    );
    if v_mismatch and coalesce(p_confirm_server_price, false) is not true then
      return jsonb_build_object(
        'needs_confirmation', true,
        'saved', false,
        'server_total', v_total,
        'lines', v_lines,
        'price_confirm_token', v_price_token,
        'idempotent_replay', false
      );
    end if;
    if v_mismatch and p_price_confirm_token is distinct from v_price_token then
      raise exception
        'Fiyat onayı bu sipariş içeriğiyle eşleşmiyor. Sipariş kaydedilmedi.'
        using errcode = '22023';
    end if;
  end if;

  if v_grant_id is not null then
    update public.customer_proximity_grants
    set used_at = timezone('utc', now()),
        used_request_id = v_request
    where id = v_grant_id
      and used_at is null;
    if not found then
      raise exception 'Personel onay kodu geçersiz. Sipariş gönderilmedi.'
        using errcode = '42501';
    end if;
  end if;

  perform set_config('ibul.customer_table_order', '1', true);
  insert into public.table_orders (
    seller_id, table_number, items, status, created_at,
    placement_source, last_edit_summary
  ) values (
    p_seller_id::text,
    p_table_number,
    v_items,
    case when v_action = 'waiter_call' then 'call_waiter' else 'new' end,
    timezone('utc', now()),
    'customer',
    jsonb_build_object(
      'client_request_id', v_request,
      'line_shape', v_shape
    )
  )
  returning * into v_inserted;

  return jsonb_build_object(
    'id', v_inserted.id,
    'status', v_inserted.status,
    'server_total', v_total,
    'idempotent_replay', false,
    'call_recorded', v_action = 'waiter_call',
    'notification_delivered', false
  );
end;
$$;

revoke all on function public.place_customer_table_order(
  uuid, integer, jsonb, double precision, double precision, double precision,
  text, text, text, text, boolean, text, text
) from public;
grant execute on function public.place_customer_table_order(
  uuid, integer, jsonb, double precision, double precision, double precision,
  text, text, text, text, boolean, text, text
) to anon, authenticated;

do $$
declare
  original text;
  patched text;
  fn_signature text;
begin
  select p.oid::regprocedure::text, pg_get_functiondef(p.oid)
  into fn_signature, original
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'guard_restaurant_staff_order_write'
  limit 1;
  if fn_signature is null then
    return;
  end if;
  if position('ibul.customer_table_order' in original) > 0 then
    return;
  end if;
  if position('if not public.is_managed_restaurant_staff() then' in original) = 0 then
    raise exception 'Personel yazma kapısı tanınmadı; müşteri isteği kapısı yazılmadı.';
  end if;
  patched := replace(
    original,
    'if not public.is_managed_restaurant_staff() then',
    'if current_setting(''ibul.customer_table_order'', true) = ''1'' and tg_table_name = ''table_orders'' and tg_op = ''INSERT'' then return new; end if; if not public.is_managed_restaurant_staff() then'
  );
  execute patched;
end $$;

commit;
