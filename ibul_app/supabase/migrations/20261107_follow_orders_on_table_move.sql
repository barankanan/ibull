-- When a bill row leaves its table, the kitchen row in public.orders must
-- follow that table. transfer_table_orders_v2 only updates table_orders, so
-- the old table_id stays active and the garson board shows the order again.
-- Sending it a second time inserts another orders row and another print job.
--
-- This trigger updates the existing orders.table_id. It does not insert an
-- order. It does not insert a print job and does not change a job's status.
-- A ticket that is still pending gets the destination table label. A ticket
-- that already left the pending state is left untouched, so it is not printed
-- again.
--
-- Do not apply this file to production from automation.

begin;

create or replace function public.follow_restaurant_orders_on_table_move()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller uuid;
  v_allowed boolean := false;
  v_from_id uuid;
  v_to_id uuid;
  v_label text;
  v_area text := '';
  v_area_no integer;
  v_moved_ids uuid[];
  v_patch jsonb;
begin
  if current_setting('ibul.follow_table_move', true) = '1' then
    return new;
  end if;
  if old.table_number is not distinct from new.table_number then
    return new;
  end if;
  if old.table_number is null or new.table_number is null then
    return new;
  end if;
  if to_regclass('public.orders') is null
     or to_regclass('public.store_tables') is null
  then
    return new;
  end if;

  begin
    v_seller := nullif(btrim(coalesce(new.seller_id::text, '')), '')::uuid;
  exception
    when invalid_text_representation then
      return new;
  end;
  if v_seller is null then
    return new;
  end if;

  if coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role' then
    v_allowed := true;
  elsif to_regprocedure('public.user_can_manage_restaurant_orders(uuid)') is not null then
    v_allowed := public.user_can_manage_restaurant_orders(v_seller);
  else
    v_allowed := auth.uid() is not distinct from v_seller;
  end if;
  if not v_allowed then
    return new;
  end if;

  if exists (
    select 1
    from public.table_orders t
    where t.seller_id::text = new.seller_id::text
      and t.table_number = old.table_number
      and t.id is distinct from new.id
      and coalesce(lower(btrim(t.status)), '') not in (
        'closed', 'paid', 'cancelled', 'canceled', 'completed', 'complete',
        'completed_payment', 'payment_completed', 'archived', 'delivered',
        'print_anchor'
      )
  ) then
    return new;
  end if;

  select st.id
    into v_from_id
  from public.store_tables st
  where st.seller_id::text = new.seller_id::text
    and st.table_number = old.table_number
  order by st.created_at
  limit 1;

  begin
    select st.id,
           coalesce(
             nullif(btrim(st.display_label), ''),
             nullif(btrim(st.table_name), ''),
             format('Masa %s', st.table_number)
           ),
           coalesce(st.area_table_number, st.table_number),
           coalesce(st.area_name, '')
      into v_to_id, v_label, v_area_no, v_area
    from public.store_tables st
    where st.seller_id::text = new.seller_id::text
      and st.table_number = new.table_number
    order by st.is_active desc nulls last, st.created_at
    limit 1;
  exception
    when undefined_column then
      select st.id
        into v_to_id
      from public.store_tables st
      where st.seller_id::text = new.seller_id::text
        and st.table_number = new.table_number
      limit 1;
      v_label := format('Masa %s', new.table_number);
      v_area_no := new.table_number;
      v_area := '';
  end;

  if v_from_id is null or v_to_id is null or v_from_id = v_to_id then
    return new;
  end if;

  -- Local to this transaction, so clear it before returning. Otherwise the
  -- next table move in the same transaction would skip the kitchen row.
  perform set_config('ibul.follow_table_move', '1', true);

  with moved as (
    update public.orders o
    set table_id = v_to_id
    where o.restaurant_id::text = new.seller_id::text
      and o.table_id = v_from_id
      and coalesce(lower(btrim(o.status)), '') not in (
        'closed', 'paid', 'cancelled', 'canceled', 'completed', 'complete',
        'completed_payment', 'payment_completed', 'archived', 'delivered',
        'print_anchor'
      )
      and (
        lower(btrim(coalesce(o.order_type, ''))) = 'table'
        or lower(btrim(coalesce(o.delivery_type, ''))) = 'table'
      )
    returning o.id
  )
  select coalesce(array_agg(id), '{}'::uuid[])
    into v_moved_ids
  from moved;

  if v_moved_ids is not null
     and cardinality(v_moved_ids) > 0
     and to_regclass('public.print_jobs') is not null
  then
    v_patch := jsonb_build_object(
      'table_id', v_to_id,
      'table_number', new.table_number,
      'area_table_number', v_area_no,
      'table_name', v_label,
      'table_display_name', v_label,
      'display_table_label', v_label
    );
    if btrim(v_area) <> '' then
      v_patch := v_patch || jsonb_build_object(
        'table_area_name', v_area,
        'area_name', v_area
      );
    end if;

    update public.print_jobs
    set payload = coalesce(payload, '{}'::jsonb) || v_patch
    where order_id = any(v_moved_ids)
      and status = 'pending';
  end if;

  perform set_config('ibul.follow_table_move', '', true);
  return new;
exception
  when others then
    perform set_config('ibul.follow_table_move', '', true);
    raise;
end;
$$;

comment on function public.follow_restaurant_orders_on_table_move() is
  'Moves the existing kitchen order onto the destination table without inserting an order or a print job.';

revoke all on function public.follow_restaurant_orders_on_table_move() from public;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke all on function public.follow_restaurant_orders_on_table_move() from anon';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'grant execute on function public.follow_restaurant_orders_on_table_move() to authenticated';
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function public.follow_restaurant_orders_on_table_move() to service_role';
  end if;

  if to_regclass('public.table_orders') is null
     or to_regclass('public.orders') is null
     or to_regclass('public.store_tables') is null
  then
    return;
  end if;
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'orders'
      and column_name = 'table_id'
  ) then
    return;
  end if;
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'table_orders'
      and column_name = 'table_number'
  ) then
    return;
  end if;

  execute 'drop trigger if exists trg_follow_restaurant_orders_on_table_move on public.table_orders';
  execute 'create trigger trg_follow_restaurant_orders_on_table_move after update of table_number on public.table_orders for each row when (old.table_number is distinct from new.table_number) execute function public.follow_restaurant_orders_on_table_move()';
end
$$;

notify pgrst, 'reload schema';

commit;
