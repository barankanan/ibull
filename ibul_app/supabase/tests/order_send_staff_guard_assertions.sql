-- Assertions for the order-send staff guard.
-- Apply the prelude, then 20261107_order_send_staff_guard.sql, then this file.

create or replace function pg_temp.assert_probe(
  p_name text,
  p_table integer,
  p_actor uuid,
  p_source text
)
returns void
language plpgsql
as $$
declare
  v_actor uuid;
  v_source text;
begin
  select actor_id, source
  into v_actor, v_source
  from public.order_send_probe
  where restaurant_id = '11111111-1111-1111-1111-111111111111'
    and table_number = p_table
  order by id desc
  limit 1;

  if v_actor is distinct from p_actor or v_source is distinct from p_source then
    raise exception
      'ASSERT FAIL % expected actor % source % got actor % source %',
      p_name, p_actor, p_source, v_actor, v_source;
  end if;
  raise notice 'PASS %', p_name;
end;
$$;

create or replace function pg_temp.assert_no_probe(
  p_name text,
  p_table integer
)
returns void
language plpgsql
as $$
begin
  if exists (
    select 1
    from public.order_send_probe
    where table_number = p_table
  ) then
    raise exception 'ASSERT FAIL % wrote a probe row', p_name;
  end if;
  raise notice 'PASS %', p_name;
end;
$$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.create_table_order_with_print_jobs(
    '11111111-1111-1111-1111-111111111111',
    1,
    '[{"name":"corba"}]'::jsonb
  );
end
$$;
select pg_temp.assert_probe(
  'owner sends through preserved body',
  1,
  '11111111-1111-1111-1111-111111111111',
  'impl'
);

do $$
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.create_table_order_with_print_jobs(
    '11111111-1111-1111-1111-111111111111',
    2,
    '[{"name":"corba"}]'::jsonb
  );
end
$$;
select pg_temp.assert_probe(
  'manageOrders sends and preserved body still impersonates owner',
  2,
  '11111111-1111-1111-1111-111111111111',
  'impl'
);

do $$
begin
  perform set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.create_table_order_with_print_jobs(
    '11111111-1111-1111-1111-111111111111',
    3,
    '[{"name":"corba"}]'::jsonb
  );
end
$$;
select pg_temp.assert_probe(
  'fullAccess sends',
  3,
  '11111111-1111-1111-1111-111111111111',
  'impl'
);

do $$
begin
  perform set_config('request.jwt.claim.sub', '99999999-9999-9999-9999-999999999999', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.create_table_order_with_print_jobs(
    '11111111-1111-1111-1111-111111111111',
    4,
    '[{"name":"corba"}]'::jsonb
  );
end
$$;
select pg_temp.assert_probe(
  'Tam Erişim sends',
  4,
  '11111111-1111-1111-1111-111111111111',
  'impl'
);

do $$
begin
  perform set_config('request.jwt.claim.sub', '88888888-8888-8888-8888-888888888888', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.create_table_order_with_print_jobs(
    '11111111-1111-1111-1111-111111111111',
    5,
    '[{"name":"corba"}]'::jsonb
  );
end
$$;
select pg_temp.assert_probe(
  'phone manageOrders sends',
  5,
  '11111111-1111-1111-1111-111111111111',
  'impl'
);

do $$
declare
  v_denied boolean := false;
  v_sqlstate text;
  v_message text;
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.create_table_order_with_print_jobs(
      '11111111-1111-1111-1111-111111111111',
      6,
      '[{"name":"corba"}]'::jsonb
    );
  exception
    when insufficient_privilege then
      get stacked diagnostics v_sqlstate = returned_sqlstate, v_message = message_text;
      v_denied := v_message = 'Bu restoran için sipariş gönderme yetkiniz yok.';
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL view-only was not denied with the order-send message';
  end if;
  if v_sqlstate is distinct from '42501' then
    raise exception 'ASSERT FAIL view-only sqlstate %', v_sqlstate;
  end if;
  raise notice 'PASS view-only cannot send';
end
$$;
select pg_temp.assert_no_probe('view-only wrote nothing', 6);

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555555', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.create_table_order_with_print_jobs(
      '11111111-1111-1111-1111-111111111111',
      7,
      '[{"name":"corba"}]'::jsonb
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL empty grant was allowed to send';
  end if;
  raise notice 'PASS empty grant cannot send';
end
$$;
select pg_temp.assert_no_probe('empty grant wrote nothing', 7);

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '66666666-6666-6666-6666-666666666666', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.create_table_order_with_print_jobs(
      '11111111-1111-1111-1111-111111111111',
      8,
      '[{"name":"corba"}]'::jsonb
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL invited staff was allowed to send';
  end if;
  raise notice 'PASS invited staff cannot send';
end
$$;
select pg_temp.assert_no_probe('invited staff wrote nothing', 8);

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '77777777-7777-7777-7777-777777777777', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.create_table_order_with_print_jobs(
      '11111111-1111-1111-1111-111111111111',
      9,
      '[{"name":"corba"}]'::jsonb
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL other business was allowed to send';
  end if;
  raise notice 'PASS other business cannot send';
end
$$;
select pg_temp.assert_no_probe('other business wrote nothing', 9);

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.create_table_order_with_print_jobs(
      '11111111-1111-1111-1111-111111111111',
      10,
      '[{"name":"corba"}]'::jsonb
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL signed-out caller was allowed to send';
  end if;
  raise notice 'PASS signed-out caller cannot send';
end
$$;
select pg_temp.assert_no_probe('signed-out caller wrote nothing', 10);

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';
  begin
    perform public.create_table_order_with_print_jobs_impl(
      '11111111-1111-1111-1111-111111111111',
      11,
      '[{"name":"corba"}]'::jsonb
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL impl was still executable';
  end if;
  raise notice 'PASS impl execute is revoked';
end
$$;
select pg_temp.assert_no_probe('impl bypass wrote nothing', 11);

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  execute 'set local role authenticated';
  begin
    perform public.create_table_order_with_print_jobs_staff_body(
      '11111111-1111-1111-1111-111111111111',
      12,
      '[{"name":"corba"}]'::jsonb
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL preserved body was still executable';
  end if;
  raise notice 'PASS preserved body execute is revoked';
end
$$;
select pg_temp.assert_no_probe('body bypass wrote nothing', 12);

do $$
declare
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  execute 'set local role anon';
  begin
    perform public.create_table_order_with_print_jobs(
      '11111111-1111-1111-1111-111111111111',
      13,
      '[{"name":"corba"}]'::jsonb
    );
  exception
    when insufficient_privilege then
      v_denied := true;
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL anon could execute the wrapper';
  end if;
  raise notice 'PASS anon cannot execute the wrapper';
end
$$;
select pg_temp.assert_no_probe('anon wrote nothing', 13);

select public.install_order_send_staff_wrapper();

do $$
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.create_table_order_with_print_jobs(
    '11111111-1111-1111-1111-111111111111',
    14,
    '[{"name":"corba"}]'::jsonb
  );
end
$$;
select pg_temp.assert_probe(
  'second install keeps manageOrders send',
  14,
  '11111111-1111-1111-1111-111111111111',
  'impl'
);

-- A later migration may replace the public function with the email-only body.
-- Reinstalling the wrapper must keep that body, including its real auth.uid().
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
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  if auth.uid() <> p_restaurant_id then
    if not exists (
      select 1
      from public.store_sub_admins sa
      join public.users u
        on lower(btrim(coalesce(u.email, ''))) = lower(btrim(coalesce(sa.email, '')))
      where sa.store_id = p_restaurant_id
        and u.id = auth.uid()
        and sa.status = 'active'
        and sa.email is not null
        and btrim(sa.email) <> ''
    ) then
      raise exception 'Bu restoran için işlem yetkiniz yok.'
        using errcode = '42501';
    end if;
  end if;

  insert into public.order_send_probe (
    restaurant_id,
    actor_id,
    table_number,
    source
  )
  values (p_restaurant_id, auth.uid(), p_table_number, 'direct-body');

  return jsonb_build_object('ok', true, 'source', 'direct-body');
end;
$$;

select public.install_order_send_staff_wrapper();

do $$
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform public.create_table_order_with_print_jobs(
    '11111111-1111-1111-1111-111111111111',
    15,
    '[{"name":"corba"}]'::jsonb
  );
end
$$;
select pg_temp.assert_probe(
  'reinstall keeps the caller identity of a replaced body',
  15,
  '22222222-2222-2222-2222-222222222222',
  'direct-body'
);

do $$
declare
  v_denied boolean := false;
  v_message text;
begin
  perform set_config('request.jwt.claim.sub', '88888888-8888-8888-8888-888888888888', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.create_table_order_with_print_jobs(
      '11111111-1111-1111-1111-111111111111',
      16,
      '[{"name":"corba"}]'::jsonb
    );
  exception
    when insufficient_privilege then
      get stacked diagnostics v_message = message_text;
      v_denied := v_message = 'Bu restoran için işlem yetkiniz yok.';
  end;
  if not v_denied then
    raise exception
      'ASSERT FAIL phone staff on the email-only body was not left to that body';
  end if;
  raise notice 'PASS email-only body still rejects phone staff';
end
$$;
select pg_temp.assert_no_probe('email-only body wrote nothing for phone', 16);

do $$
declare
  v_denied boolean := false;
  v_message text;
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  begin
    perform public.create_table_order_with_print_jobs(
      '11111111-1111-1111-1111-111111111111',
      17,
      '[{"name":"corba"}]'::jsonb
    );
  exception
    when insufficient_privilege then
      get stacked diagnostics v_message = message_text;
      v_denied := v_message = 'Bu restoran için sipariş gönderme yetkiniz yok.';
  end;
  if not v_denied then
    raise exception 'ASSERT FAIL view-only passed the reinstalled wrapper';
  end if;
  raise notice 'PASS view-only still denied after body replacement';
end
$$;
select pg_temp.assert_no_probe('view-only wrote nothing after reinstall', 17);

do $$
begin
  if public.normalize_staff_permission('Tam Erişim') is distinct from 'fullAccess' then
    raise exception 'ASSERT FAIL Tam Erişim token';
  end if;
  if public.normalize_staff_permission('manageOrders') is distinct from 'manageOrders' then
    raise exception 'ASSERT FAIL manageOrders token';
  end if;
  raise notice 'PASS permission tokens';
end
$$;
