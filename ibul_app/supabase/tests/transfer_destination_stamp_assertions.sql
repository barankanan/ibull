-- Isolated check for a full move that writes destination labels with
-- table_number. Does not connect to production.

create table if not exists public.store_tables (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  area_name text,
  area_table_number integer,
  display_label text,
  table_name text
);

insert into public.users (id, email, phone)
values (
  '88888888-8888-4888-8888-888888888888',
  'stamp@ibul.test',
  null
)
on conflict (id) do nothing;

insert into public.store_tables (
  seller_id, table_number, area_name, area_table_number, display_label, table_name
) values
  (
    '88888888-8888-4888-8888-888888888888',
    11,
    'Bahçe',
    1,
    'Bahçe 1',
    'Bahçe 1'
  ),
  (
    '88888888-8888-4888-8888-888888888888',
    1,
    'Salon',
    1,
    'Salon 1',
    'Salon 1'
  ),
  (
    '88888888-8888-4888-8888-888888888888',
    2,
    null,
    null,
    null,
    null
  );

insert into public.table_orders (
  id, seller_id, table_number, items, status,
  area_name, area_table_number, display_table_label
) values (
  '88888888-8888-4888-8888-888888888881',
  '88888888-8888-4888-8888-888888888888',
  11,
  '[{"name":"cay","price":15,"quantity":1}]'::jsonb,
  'sent',
  'Bahçe',
  1,
  'Bahçe 1'
), (
  '88888888-8888-4888-8888-888888888882',
  '88888888-8888-4888-8888-888888888888',
  12,
  '[{"name":"cay","price":15,"quantity":1}]'::jsonb,
  'sent',
  'Bahçe',
  1,
  'Bahçe 1'
), (
  '88888888-8888-4888-8888-888888888883',
  '88888888-8888-4888-8888-888888888888',
  13,
  '[{"name":"cay","price":15,"quantity":1},{"name":"su","price":10,"quantity":1}]'::jsonb,
  'sent',
  'Bahçe',
  1,
  'Bahçe 1'
);

do $$
declare
  v_area text;
  v_area_no integer;
  v_label text;
  v_number integer;
  v_blocked boolean := false;
  v_partial_area text;
  v_partial_number integer;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '88888888-8888-4888-8888-888888888888',
    true
  );
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  perform public.transfer_table_orders_v2(
    '88888888-8888-4888-8888-888888888888',
    11,
    1,
    'full'
  );

  select table_number, area_name, area_table_number, display_table_label
    into v_number, v_area, v_area_no, v_label
  from public.table_orders
  where id = '88888888-8888-4888-8888-888888888881';

  if v_number is distinct from 1
     or v_area is distinct from 'Salon'
     or v_area_no is distinct from 1
     or v_label is distinct from 'Salon 1'
  then
    raise exception
      'full move label mismatch number=% area=% area_no=% label=%',
      v_number, v_area, v_area_no, v_label;
  end if;

  begin
    perform public.transfer_table_orders_v2(
      '88888888-8888-4888-8888-888888888888',
      12,
      2,
      'full'
    );
  exception
    when others then
      if position('Aktarım yapılmadı' in sqlerrm) = 0 then
        raise;
      end if;
      v_blocked := true;
  end;

  if not v_blocked then
    raise exception 'incomplete destination label was written';
  end if;

  select table_number, area_name, display_table_label
    into v_number, v_area, v_label
  from public.table_orders
  where id = '88888888-8888-4888-8888-888888888882';

  if v_number is distinct from 12
     or v_area is distinct from 'Bahçe'
     or v_label is distinct from 'Bahçe 1'
  then
    raise exception
      'blocked full move changed the row number=% area=% label=%',
      v_number, v_area, v_label;
  end if;

  perform public.transfer_table_orders_v2(
    '88888888-8888-4888-8888-888888888888',
    13,
    3,
    'partial',
    jsonb_build_array('88888888-8888-4888-8888-888888888883#0')
  );

  select table_number, area_name
    into v_partial_number, v_partial_area
  from public.table_orders
  where id = '88888888-8888-4888-8888-888888888883';

  if v_partial_number is distinct from 13
     or v_partial_area is distinct from 'Bahçe'
  then
    raise exception
      'partial move changed the source label number=% area=%',
      v_partial_number, v_partial_area;
  end if;

  select table_number, area_name
    into v_partial_number, v_partial_area
  from public.table_orders
  where seller_id = '88888888-8888-4888-8888-888888888888'
    and table_number = 3
    and area_name is null;

  if v_partial_number is distinct from 3 then
    raise exception 'partial line did not move without a destination label';
  end if;
end
$$;

-- Repo fixture schema does not define table_orders.table_id or
-- store_table_id. The columns are added only in this isolated database.
-- A full move must leave them unchanged. This is not a production migration.
do $$
declare
  v_before integer;
  v_bahce uuid;
  v_salon uuid;
  v_id uuid := '88888888-8888-4888-8888-888888888884';
  v_table_id uuid;
  v_store_table_id uuid;
  v_number integer;
  v_area text;
  v_label text;
begin
  select count(*)
    into v_before
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'table_orders'
    and column_name in ('table_id', 'store_table_id');

  if v_before <> 0 then
    raise exception
      'repo fixture already carries table identity columns: %',
      v_before;
  end if;

  alter table public.table_orders add column table_id uuid;
  alter table public.table_orders add column store_table_id uuid;

  select id
    into v_bahce
  from public.store_tables
  where seller_id = '88888888-8888-4888-8888-888888888888'
    and table_number = 11;

  select id
    into v_salon
  from public.store_tables
  where seller_id = '88888888-8888-4888-8888-888888888888'
    and table_number = 1;

  insert into public.table_orders (
    id, seller_id, table_number, items, status,
    area_name, area_table_number, display_table_label,
    table_id, store_table_id
  ) values (
    v_id,
    '88888888-8888-4888-8888-888888888888',
    11,
    '[{"name":"cay","price":15,"quantity":1}]'::jsonb,
    'sent',
    'Bahçe',
    1,
    'Bahçe 1',
    v_bahce,
    v_bahce
  );

  perform set_config(
    'request.jwt.claim.sub',
    '88888888-8888-4888-8888-888888888888',
    true
  );
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  perform public.transfer_table_orders_v2(
    '88888888-8888-4888-8888-888888888888',
    11,
    1,
    'full'
  );

  select table_number, area_name, display_table_label, table_id, store_table_id
    into v_number, v_area, v_label, v_table_id, v_store_table_id
  from public.table_orders
  where id = v_id;

  if v_number is distinct from 1
     or v_area is distinct from 'Salon'
     or v_label is distinct from 'Salon 1'
     or v_table_id is distinct from v_bahce
     or v_store_table_id is distinct from v_bahce
     or v_table_id is not distinct from v_salon
  then
    raise exception
      'full move changed table identity number=% area=% label=% table_id=% store_table_id=% bahce=% salon=%',
      v_number, v_area, v_label, v_table_id, v_store_table_id, v_bahce, v_salon;
  end if;
end
$$;
