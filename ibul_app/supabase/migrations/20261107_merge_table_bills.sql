-- =============================================================================
-- Migration: merge_table_bills
-- Date: 2026-11-07
--
-- Merges the open bill on one table into another. Order lines keep their
-- ids, quantities, notes and prices. Partial payments for that open visit
-- move with the bill. Kitchen print_jobs are not created or reprinted.
-- The whole change is one transaction. A mismatch with the bills the caller
-- saw aborts without leaving a partial move.
--
-- Only the owner, or active staff with manageOrders / Tam Erişim, may merge.
-- Do not apply this file to production from automation.
-- =============================================================================

begin;

create or replace function public.merge_table_bills(
  p_seller_id uuid,
  p_source_table integer,
  p_target_table integer,
  p_source_order_ids jsonb,
  p_target_order_ids jsonb,
  p_waiter_id uuid default null,
  p_waiter_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source_ids uuid[];
  v_target_ids uuid[];
  v_seen_source uuid[];
  v_seen_target uuid[];
  v_opened timestamptz;
  v_moved_orders integer := 0;
  v_moved_payments integer := 0;
  v_moved_customer_orders integer := 0;
  v_target_table_id uuid;
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role'
     and not public.user_can_manage_restaurant_orders(p_seller_id)
  then
    raise exception 'Bu restoran için masa birleştirme yetkiniz yok.'
      using errcode = '42501';
  end if;

  if p_seller_id is null
     or p_source_table is null
     or p_target_table is null
     or p_source_table <= 0
     or p_target_table <= 0
     or p_source_table = p_target_table
  then
    raise exception 'Kaynak ve hedef masa geçersiz.';
  end if;

  if p_source_table < p_target_table then
    perform pg_advisory_xact_lock(hashtext(p_seller_id::text), p_source_table);
    perform pg_advisory_xact_lock(hashtext(p_seller_id::text), p_target_table);
  else
    perform pg_advisory_xact_lock(hashtext(p_seller_id::text), p_target_table);
    perform pg_advisory_xact_lock(hashtext(p_seller_id::text), p_source_table);
  end if;

  select coalesce(array_agg(id order by id), '{}'::uuid[])
    into v_source_ids
  from (
    select id
    from public.table_orders
    where seller_id = p_seller_id
      and table_number = p_source_table
      and coalesce(lower(status), '') not in (
        'closed', 'paid', 'cancelled', 'canceled', 'completed', 'complete',
        'completed_payment', 'payment_completed', 'archived', 'delivered',
        'print_anchor'
      )
    for update
  ) locked_source;

  select coalesce(array_agg(id order by id), '{}'::uuid[])
    into v_target_ids
  from (
    select id
    from public.table_orders
    where seller_id = p_seller_id
      and table_number = p_target_table
      and coalesce(lower(status), '') not in (
        'closed', 'paid', 'cancelled', 'canceled', 'completed', 'complete',
        'completed_payment', 'payment_completed', 'archived', 'delivered',
        'print_anchor'
      )
    for update
  ) locked_target;

  select coalesce(array_agg(value::uuid order by value::uuid), '{}'::uuid[])
    into v_seen_source
  from jsonb_array_elements_text(coalesce(p_source_order_ids, '[]'::jsonb));

  select coalesce(array_agg(value::uuid order by value::uuid), '{}'::uuid[])
    into v_seen_target
  from jsonb_array_elements_text(coalesce(p_target_order_ids, '[]'::jsonb));

  if v_source_ids is distinct from v_seen_source
     or v_target_ids is distinct from v_seen_target
  then
    raise exception 'Masalar değişti. Birleştirme yapılmadı.';
  end if;

  if cardinality(v_source_ids) = 0 then
    raise exception 'Kaynak masada birleştirilecek açık adisyon yok.';
  end if;

  select min(created_at)
    into v_opened
  from public.table_orders
  where id = any(v_source_ids);

  update public.table_orders
  set table_number = p_target_table
  where id = any(v_source_ids)
    and seller_id = p_seller_id
    and table_number = p_source_table;
  get diagnostics v_moved_orders = row_count;

  if v_moved_orders <> cardinality(v_source_ids) then
    raise exception 'Kaynak adisyon taşınamadı. Birleştirme yapılmadı.';
  end if;

  if to_regclass('public.table_payments') is not null then
    update public.table_payments
    set table_number = p_target_table
    where seller_id = p_seller_id
      and table_number = p_source_table
      and created_at >= coalesce(v_opened, '-infinity'::timestamptz);
    get diagnostics v_moved_payments = row_count;
  end if;

  if to_regclass('public.orders') is not null
     and to_regclass('public.store_tables') is not null
     and exists (
       select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'orders'
         and column_name = 'table_id'
     )
     and exists (
       select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'orders'
         and column_name = 'restaurant_id'
     )
  then
    execute
      'select id from public.store_tables
       where seller_id::text = $1 and table_number = $2
       limit 1'
      into v_target_table_id
      using p_seller_id::text, p_target_table;

    if v_target_table_id is not null then
      execute
        'with moved as (
           update public.orders
           set table_id = $1
           where restaurant_id = $2
             and table_id in (
               select id from public.store_tables
               where seller_id::text = $3 and table_number = $4
             )
             and coalesce(lower(status), '''') not in (
               ''closed'', ''paid'', ''cancelled'', ''canceled'', ''completed'',
               ''complete'', ''completed_payment'', ''payment_completed'',
               ''archived'', ''print_anchor''
             )
           returning id
         )
         select count(*) from moved'
        into v_moved_customer_orders
        using v_target_table_id, p_seller_id, p_seller_id::text, p_source_table;
    end if;
  end if;

  if to_regclass('public.table_transfers_log') is not null then
    insert into public.table_transfers_log (
      seller_id, from_table, to_table, transfer_type,
      transferred_items, order_ids, waiter_id, waiter_name, note
    ) values (
      p_seller_id,
      p_source_table,
      p_target_table,
      'merge',
      '[]'::jsonb,
      (
        select coalesce(jsonb_agg(id::text), '[]'::jsonb)
        from unnest(v_source_ids) as id
      ),
      p_waiter_id,
      p_waiter_name,
      'Açık adisyon ve bu ziyaretin ara ödemeleri hedef masaya taşındı. Mutfak fişi yeniden basılmadı.'
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'source_table', p_source_table,
    'target_table', p_target_table,
    'moved_orders', v_moved_orders,
    'moved_payments', v_moved_payments,
    'moved_customer_orders', v_moved_customer_orders
  );
end;
$$;

revoke all on function public.merge_table_bills(
  uuid, integer, integer, jsonb, jsonb, uuid, text
) from public;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on function public.merge_table_bills(
      uuid, integer, integer, jsonb, jsonb, uuid, text
    ) from anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.merge_table_bills(
      uuid, integer, integer, jsonb, jsonb, uuid, text
    ) to authenticated;
  end if;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.merge_table_bills(
      uuid, integer, integer, jsonb, jsonb, uuid, text
    ) to service_role;
  end if;
end
$$;

comment on function public.merge_table_bills(
  uuid, integer, integer, jsonb, jsonb, uuid, text
) is
  'Atomically moves an open table bill and its visit payments onto another table. Does not reprint kitchen tickets.';

notify pgrst, 'reload schema';

commit;
