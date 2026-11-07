-- Expectations after install_waiter_request_single_order_guard.
\set ON_ERROR_STOP on

do $$
begin
  if pg_get_functiondef(
       'public.approve_waiter_order_request(uuid,jsonb)'::regprocedure
     ) is distinct from (
       select body from public.fixture_guard where name = 'approve'
     ) then
    raise exception 'approve_waiter_order_request gövdesi değişti';
  end if;

  if position(
       'waiter_request_order_suppressed'
       in pg_get_functiondef(
         'public.create_table_order_with_print_jobs_request_body(uuid,integer,jsonb,uuid,text,text,text,text)'::regprocedure
       )
     ) > 0 then
    raise exception 'yazdırma gövdesine sarmalayıcı kopyalandı';
  end if;

  if position(
       'create_table_order_with_print_jobs_request_body('
       in pg_get_functiondef(
         'public.create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text)'::regprocedure
       )
     ) = 0 then
    raise exception 'public fonksiyon gövdeyi çağırmıyor';
  end if;
end
$$;

-- Historical approval stays untouched.
do $$
declare
  v_open integer;
begin
  select count(*) into v_open
  from public.orders
  where notes like 'waiter_request:bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1%'
    and status = 'confirmed';
  if v_open <> 1 then
    raise exception 'eski çift kayıt migration tarafından değiştirildi open=%', v_open;
  end if;
end
$$;

select public.test_set_actor('11111111-1111-1111-1111-111111111111'::uuid);

do $$
declare
  v_approved jsonb;
  v_bills integer;
  v_bill_status text;
  v_open integer;
  v_cancelled integer;
  v_jobs integer;
begin
  v_approved := public.approve_waiter_order_request(
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2'::uuid,
    null
  );

  if coalesce(
       (v_approved -> 'print_result' ->> 'waiter_request_order_suppressed')::boolean,
       false
     ) is not true then
    raise exception 'onay baskı çapasını işaretlemedi result=%', v_approved;
  end if;

  select count(*), max(status)
  into v_bills, v_bill_status
  from public.table_orders
  where table_number = 5;

  select count(*) into v_open
  from public.orders
  where notes like 'waiter_request:bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2%'
    and status is distinct from 'cancelled';

  select count(*) into v_cancelled
  from public.orders
  where notes like 'waiter_request:bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2%'
    and status = 'cancelled'
    and order_status = 'cancelled';

  select count(*) into v_jobs
  from public.print_jobs pj
  join public.orders o on o.id = pj.order_id
  where o.notes like 'waiter_request:bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2%'
    and pj.status = 'pending';

  if v_bills <> 1
     or v_bill_status <> 'sent'
     or v_open <> 0
     or v_cancelled <> 1
     or v_jobs <> 1 then
    raise exception
      'tek açık adisyon sağlanamadı bills=% status=% open=% cancelled=% jobs=%',
      v_bills, v_bill_status, v_open, v_cancelled, v_jobs;
  end if;
end
$$;

-- Second approval must not create another bill or ticket.
do $$
declare
  v_bills integer;
  v_orders integer;
begin
  begin
    perform public.approve_waiter_order_request(
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2'::uuid,
      null
    );
    raise exception 'ikinci onay reddedilmedi';
  exception
    when sqlstate '22023' then
      null;
  end;

  select count(*) into v_bills from public.table_orders where table_number = 5;
  select count(*) into v_orders
  from public.orders
  where notes like 'waiter_request:bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2%';
  if v_bills <> 1 or v_orders <> 1 then
    raise exception 'ikinci onay yeni satır açtı bills=% orders=%', v_bills, v_orders;
  end if;
end
$$;

-- Ordinary garson send stays an active order.
select public.create_table_order_with_print_jobs(
  '11111111-1111-1111-1111-111111111111'::uuid,
  9,
  '[{"name":"Ayran","quantity":1}]'::jsonb,
  '11111111-1111-1111-1111-111111111111'::uuid,
  'Garson',
  'a1b2c3d4 masa notu',
  'new_order',
  'table'
);

-- Reprint and add_item keep the prefix from cancelling an existing send.
select public.create_table_order_with_print_jobs(
  '11111111-1111-1111-1111-111111111111'::uuid,
  9,
  '[{"name":"Ayran","quantity":1}]'::jsonb,
  '11111111-1111-1111-1111-111111111111'::uuid,
  'Garson',
  'waiter_request:bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2 tekrar',
  'reprint',
  'table'
);

select public.create_table_order_with_print_jobs(
  '11111111-1111-1111-1111-111111111111'::uuid,
  9,
  '[{"name":"Ayran","quantity":1}]'::jsonb,
  '11111111-1111-1111-1111-111111111111'::uuid,
  'Garson',
  'waiter_request:bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2 ek',
  'add_item',
  'table'
);

do $$
declare
  v_direct integer;
  v_reprint integer;
  v_add integer;
begin
  select count(*) into v_direct
  from public.orders
  where notes = 'a1b2c3d4 masa notu'
    and status = 'confirmed'
    and order_status = 'sent';

  select count(*) into v_reprint
  from public.orders
  where notes like 'waiter_request:%tekrar'
    and status = 'confirmed';

  select count(*) into v_add
  from public.orders
  where notes like 'waiter_request:%ek'
    and status = 'confirmed';

  if v_direct <> 1 or v_reprint <> 1 or v_add <> 1 then
    raise exception
      'normal gönderim bozuldu direct=% reprint=% add=%',
      v_direct, v_reprint, v_add;
  end if;
end
$$;

-- Suppressed approval exposes the flag without dropping the ticket.
do $$
declare
  v_result jsonb;
begin
  perform public.test_set_actor('11111111-1111-1111-1111-111111111111'::uuid);
  v_result := public.create_table_order_with_print_jobs(
    '11111111-1111-1111-1111-111111111111'::uuid,
    6,
    '[{"name":"Salata","quantity":1}]'::jsonb,
    '11111111-1111-1111-1111-111111111111'::uuid,
    'Garson',
    'waiter_request:cccccccc-cccc-cccc-cccc-ccccccccccc1',
    'new_order',
    'table'
  );
  if coalesce((v_result ->> 'waiter_request_order_suppressed')::boolean, false) is not true then
    raise exception 'baskı çapası işaretlenmedi result=%', v_result;
  end if;
  if jsonb_array_length(coalesce(v_result -> 'print_job_ids', '[]'::jsonb)) <> 1 then
    raise exception 'mutfak fişi kayboldu result=%', v_result;
  end if;
end
$$;

select public.install_waiter_request_single_order_guard();

do $$
declare
  v_calls integer;
begin
  select count(*) into v_calls
  from regexp_matches(
    pg_get_functiondef(
      'public.create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text)'::regprocedure
    ),
    'create_table_order_with_print_jobs_request_body',
    'g'
  );
  if v_calls <> 1 then
    raise exception 'ikinci kurulum sarmalayıcıyı iç içe geçirdi calls=%', v_calls;
  end if;
end
$$;

do $$
begin
  if has_function_privilege(
       'authenticated',
       'public.create_table_order_with_print_jobs_request_body(uuid,integer,jsonb,uuid,text,text,text,text)',
       'execute'
     ) then
    raise exception 'iç fonksiyon authenticated rolüne açık';
  end if;
  if has_function_privilege(
       'anon',
       'public.create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text)',
       'execute'
     ) then
    raise exception 'anon public fonksiyonu çalıştırabiliyor';
  end if;
  if not has_function_privilege(
       'authenticated',
       'public.create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text)',
       'execute'
     ) then
    raise exception 'garson public fonksiyonu kaybetti';
  end if;
  if has_function_privilege(
       'authenticated',
       'public.install_waiter_request_single_order_guard()',
       'execute'
     ) then
    raise exception 'kurulum fonksiyonu authenticated rolüne açık';
  end if;
end
$$;

-- A later replacement of the public body is picked up by a fresh install.
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
  v_job_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  insert into public.orders (
    user_id, order_number, status, order_status, restaurant_id, notes,
    order_type, delivery_type, total_amount
  )
  values (
    auth.uid(), 'TBL-REPLACED', 'confirmed', 'sent', p_restaurant_id,
    nullif(btrim(coalesce(p_notes, '')), ''), 'table', 'table', 0
  )
  returning id into v_order_id;

  insert into public.print_jobs (
    restaurant_id, order_id, job_type, status, payload
  )
  values (
    p_restaurant_id, v_order_id, 'new_order', 'pending', '{"replaced":true}'::jsonb
  )
  returning id into v_job_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', 'TBL-REPLACED',
    'print_job_ids', jsonb_build_array(v_job_id)
  );
end;
$$;

select public.install_waiter_request_single_order_guard();

do $$
declare
  v_result jsonb;
  v_status text;
  v_number text;
  v_jobs integer;
begin
  v_result := public.create_table_order_with_print_jobs(
    '11111111-1111-1111-1111-111111111111'::uuid,
    7,
    '[{"name":"Tatlı","quantity":1}]'::jsonb,
    '11111111-1111-1111-1111-111111111111'::uuid,
    'Garson',
    'waiter_request:dddddddd-dddd-dddd-dddd-ddddddddddd1',
    'new_order',
    'table'
  );

  select status, order_number into v_status, v_number
  from public.orders
  where id = (v_result ->> 'order_id')::uuid;

  select count(*) into v_jobs
  from public.print_jobs
  where order_id = (v_result ->> 'order_id')::uuid
    and status = 'pending';

  if v_number <> 'TBL-REPLACED' or v_status <> 'cancelled' or v_jobs <> 1 then
    raise exception
      'yeni gövde sarmalanmadı number=% status=% jobs=% result=%',
      v_number, v_status, v_jobs, v_result;
  end if;

  if pg_get_functiondef(
       'public.approve_waiter_order_request(uuid,jsonb)'::regprocedure
     ) is distinct from (
       select body from public.fixture_guard where name = 'approve'
     ) then
    raise exception 'yeniden kurulum onay gövdesini değiştirdi';
  end if;
end
$$;

-- An outer wrapper that does not call the guard directly must not cause a
-- reinstall to drop the print body.
alter function public.create_table_order_with_print_jobs(
  uuid, integer, jsonb, uuid, text, text, text, text
) rename to create_table_order_with_print_jobs_staff_body;

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
begin
  return public.create_table_order_with_print_jobs_staff_body(
    p_restaurant_id,
    p_table_number,
    p_items,
    p_waiter_id,
    p_waiter_name,
    p_notes,
    p_job_type,
    p_order_type
  );
end;
$$;

select public.install_waiter_request_single_order_guard();

do $$
declare
  v_result jsonb;
  v_number text;
  v_status text;
  v_jobs integer;
begin
  if position(
       'TBL-REPLACED'
       in pg_get_functiondef(
         'public.create_table_order_with_print_jobs_request_body(uuid,integer,jsonb,uuid,text,text,text,text)'::regprocedure
       )
     ) = 0 then
    raise exception 'dış sarmalayıcı kurulumu yazdırma gövdesini sildi';
  end if;

  set local statement_timeout = '3s';
  v_result := public.create_table_order_with_print_jobs(
    '11111111-1111-1111-1111-111111111111'::uuid,
    8,
    '[{"name":"Kahve","quantity":1}]'::jsonb,
    '11111111-1111-1111-1111-111111111111'::uuid,
    'Garson',
    'waiter_request:eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1',
    'new_order',
    'table'
  );

  select order_number, status into v_number, v_status
  from public.orders
  where id = (v_result ->> 'order_id')::uuid;

  select count(*) into v_jobs
  from public.print_jobs
  where order_id = (v_result ->> 'order_id')::uuid
    and status = 'pending';

  if v_number <> 'TBL-REPLACED'
     or v_status <> 'cancelled'
     or v_jobs <> 1
     or coalesce((v_result ->> 'waiter_request_order_suppressed')::boolean, false) is not true then
    raise exception
      'dış sarmalayıcıdan sonra tek kayıt bozuldu number=% status=% jobs=% result=%',
      v_number, v_status, v_jobs, v_result;
  end if;
end
$$;
