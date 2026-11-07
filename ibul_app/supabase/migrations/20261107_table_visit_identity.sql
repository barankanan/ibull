-- =============================================================================
-- Migration: table_visit_identity
-- Date: 2026-11-07
--
-- A table payment belongs to a bill only when both rows share visit_id.
-- session_key is a client session and is not a visit. Payments with a null
-- visit_id are not guessed onto another table. If one of those payments falls
-- inside the open bill's time window, merge stops and leaves every row as it
-- was. New orders and payments receive the open bill's visit_id in a trigger,
-- and that trigger takes the same table lock as merge and record_table_payment.
--
-- Do not apply this file to production from automation.
-- =============================================================================

begin;

alter table public.table_orders
  add column if not exists visit_id uuid;

alter table public.table_payments
  add column if not exists visit_id uuid;

create index if not exists idx_table_orders_visit
  on public.table_orders (seller_id, visit_id);

create index if not exists idx_table_payments_visit
  on public.table_payments (seller_id, visit_id);

create or replace function public.table_order_is_open(p_status text)
returns boolean
language sql
immutable
as $$
  select coalesce(lower(p_status), '') not in (
    'closed', 'paid', 'cancelled', 'canceled', 'completed', 'complete',
    'completed_payment', 'payment_completed', 'archived', 'delivered',
    'print_anchor'
  );
$$;

create or replace function public.lock_table_bill(
  p_seller_id uuid,
  p_table_number integer
)
returns void
language plpgsql
as $$
begin
  if p_seller_id is null or p_table_number is null then
    return;
  end if;
  perform pg_advisory_xact_lock(hashtext(p_seller_id::text), p_table_number);
end;
$$;

create or replace function public.ensure_open_table_visit(
  p_seller_id uuid,
  p_table_number integer
)
returns uuid
language plpgsql
as $$
declare
  v_visits uuid[];
  v_visit uuid;
begin
  perform public.lock_table_bill(p_seller_id, p_table_number);

  perform 1
  from public.table_orders
  where seller_id::text = p_seller_id::text
    and table_number = p_table_number
    and public.table_order_is_open(status)
  for update;

  if not found then
    return null;
  end if;

  select coalesce(array_agg(distinct visit_id), '{}'::uuid[])
    into v_visits
  from public.table_orders
  where seller_id::text = p_seller_id::text
    and table_number = p_table_number
    and public.table_order_is_open(status)
    and visit_id is not null;

  if cardinality(v_visits) = 0 then
    v_visit := gen_random_uuid();
  else
    select visit
      into v_visit
    from unnest(v_visits) as visit
    order by visit::text
    limit 1;
  end if;

  update public.table_orders
  set visit_id = v_visit
  where seller_id::text = p_seller_id::text
    and table_number = p_table_number
    and public.table_order_is_open(status)
    and visit_id is distinct from v_visit;

  if cardinality(v_visits) > 1 then
    update public.table_payments
    set visit_id = v_visit
    where seller_id::text = p_seller_id::text
      and table_number = p_table_number
      and visit_id = any(v_visits)
      and visit_id is distinct from v_visit;
  end if;

  return v_visit;
end;
$$;

create or replace function public.table_bill_has_ambiguous_payment(
  p_seller_id uuid,
  p_table_number integer,
  p_order_ids uuid[]
)
returns boolean
language sql
stable
as $$
  select coalesce(cardinality(p_order_ids), 0) > 0
    and exists (
      select 1
      from public.table_payments p
      where p.seller_id::text = p_seller_id::text
        and p.table_number = p_table_number
        and p.visit_id is null
        and p.created_at >= (
          select min(o.created_at)
          from public.table_orders o
          where o.id = any(p_order_ids)
        )
    );
$$;

create or replace function public.open_table_payment_total(
  p_seller_id uuid,
  p_table_number integer,
  p_opened timestamptz
)
returns numeric
language sql
stable
as $$
  select coalesce(sum(p.amount), 0)
  from public.table_payments p
  where p.seller_id::text = p_seller_id::text
    and p.table_number = p_table_number
    and (
      p.visit_id in (
        select o.visit_id
        from public.table_orders o
        where o.seller_id::text = p_seller_id::text
          and o.table_number = p_table_number
          and public.table_order_is_open(o.status)
          and o.visit_id is not null
      )
      or (
        p.visit_id is null
        and p.created_at >= coalesce(p_opened, '-infinity'::timestamptz)
      )
    );
$$;

create or replace function public.assign_table_order_visit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller uuid;
  v_visit uuid;
begin
  if not public.table_order_is_open(new.status) then
    return new;
  end if;
  begin
    v_seller := new.seller_id::text::uuid;
  exception
    when invalid_text_representation then
      return new;
  end;
  v_visit := public.ensure_open_table_visit(v_seller, new.table_number);
  new.visit_id := coalesce(v_visit, new.visit_id, gen_random_uuid());
  return new;
end;
$$;

create or replace function public.assign_table_payment_visit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller uuid;
  v_visit uuid;
begin
  begin
    v_seller := new.seller_id::text::uuid;
  exception
    when invalid_text_representation then
      return new;
  end;

  perform public.lock_table_bill(v_seller, new.table_number);
  if tg_op = 'UPDATE' and new.table_number is distinct from old.table_number then
    perform public.lock_table_bill(v_seller, old.table_number);
    return new;
  end if;
  if tg_op <> 'INSERT' then
    return new;
  end if;

  v_visit := public.ensure_open_table_visit(v_seller, new.table_number);
  if v_visit is null then
    raise exception 'Masa hesabı değişti. Ödeme kaydedilmedi.';
  end if;
  new.visit_id := v_visit;
  return new;
end;
$$;

drop trigger if exists trg_assign_table_order_visit on public.table_orders;
create trigger trg_assign_table_order_visit
  before insert on public.table_orders
  for each row
  execute function public.assign_table_order_visit();

drop trigger if exists trg_assign_table_payment_visit on public.table_payments;
create trigger trg_assign_table_payment_visit
  before insert or update on public.table_payments
  for each row
  execute function public.assign_table_payment_visit();

do $$
declare
  v_old text;
  v_new text;
  v_fn regprocedure;
begin
  v_fn := to_regprocedure(
    'public.record_table_payment(uuid,integer,text,numeric,text,text,boolean,text,uuid,text,text)'
  );
  if v_fn is null then
    return;
  end if;
  v_old := pg_get_functiondef(v_fn);
  v_new := regexp_replace(
    v_old,
    'select coalesce\(sum\(amount\), 0\)\s+into v_paid\s+from public\.table_payments\s+where seller_id = p_seller_id\s+and table_number = p_table_number\s+and created_at >= v_window_start\s*;',
    'select public.open_table_payment_total(p_seller_id, p_table_number, v_window_start) into v_paid;',
    'n'
  );
  if v_new = v_old then
    raise exception 'record_table_payment ödeme toplamı ziyaret kuralına bağlanamadı.';
  end if;
  execute v_new;
end
$$;

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
  v_source_visits uuid[];
  v_target_visit uuid;
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
    perform public.lock_table_bill(p_seller_id, p_source_table);
    perform public.lock_table_bill(p_seller_id, p_target_table);
  else
    perform public.lock_table_bill(p_seller_id, p_target_table);
    perform public.lock_table_bill(p_seller_id, p_source_table);
  end if;

  select coalesce(array_agg(id order by id), '{}'::uuid[])
    into v_source_ids
  from (
    select id
    from public.table_orders
    where seller_id = p_seller_id
      and table_number = p_source_table
      and public.table_order_is_open(status)
    for update
  ) locked_source;

  select coalesce(array_agg(id order by id), '{}'::uuid[])
    into v_target_ids
  from (
    select id
    from public.table_orders
    where seller_id = p_seller_id
      and table_number = p_target_table
      and public.table_order_is_open(status)
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

  if public.table_bill_has_ambiguous_payment(p_seller_id, p_source_table, v_source_ids)
     or public.table_bill_has_ambiguous_payment(p_seller_id, p_target_table, v_target_ids)
  then
    raise exception 'Bu masadaki ara ödemenin ziyareti belirsiz. Birleştirme yapılmadı.';
  end if;

  v_target_visit := public.ensure_open_table_visit(p_seller_id, p_target_table);
  if v_target_visit is null then
    v_target_visit := gen_random_uuid();
  end if;

  select coalesce(array_agg(distinct visit_id), '{}'::uuid[])
    into v_source_visits
  from public.table_orders
  where id = any(v_source_ids)
    and visit_id is not null;

  if cardinality(v_source_visits) > 0 then
    update public.table_payments
    set table_number = p_target_table,
        visit_id = v_target_visit
    where seller_id = p_seller_id
      and table_number = p_source_table
      and visit_id = any(v_source_visits);
    get diagnostics v_moved_payments = row_count;
  end if;

  update public.table_orders
  set table_number = p_target_table,
      visit_id = v_target_visit
  where id = any(v_source_ids)
    and seller_id = p_seller_id
    and table_number = p_source_table;
  get diagnostics v_moved_orders = row_count;

  if v_moved_orders <> cardinality(v_source_ids) then
    raise exception 'Kaynak adisyon taşınamadı. Birleştirme yapılmadı.';
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
             and public.table_order_is_open(status)
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
      'Açık adisyon ve visit_id eşleşen ara ödemeler hedef masaya taşındı. Kimliksiz ödeme tahmin edilmedi. Mutfak fişi yeniden basılmadı.'
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'source_table', p_source_table,
    'target_table', p_target_table,
    'target_visit_id', v_target_visit,
    'moved_orders', v_moved_orders,
    'moved_payments', v_moved_payments,
    'moved_customer_orders', v_moved_customer_orders
  );
end;
$$;

comment on function public.merge_table_bills(
  uuid, integer, integer, jsonb, jsonb, uuid, text
) is
  'Moves an open bill and payments that share its visit_id. Refuses when an in-window payment has no visit. Does not reprint.';

notify pgrst, 'reload schema';

commit;
