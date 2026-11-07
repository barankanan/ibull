-- =============================================================================
-- Migration: production_contract_compat
-- Version: 20261107223000
--
-- Additive compatibility with production project ihmixxzqnpamcwmrfibx.
-- Does not rename older files and does not repair migration history.
-- Apply this file only after a restored backup has been verified.
-- Do not apply the earlier 20261107_* replacements that drop the 9-argument
-- print contract or add table_payments.idempotency_key.
--
-- Preserves create_table_order_with_print_jobs(9 args), p_local_order_id,
-- auth.uid() and ibul.marketplace_order_rpc inside the existing impl.
-- Payments stay on client_request_id and session_key. seller_id on
-- table_orders is compared as text. Multiple visit_id values are not merged.
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

create or replace function public.lock_restaurant_table(
  p_seller text,
  p_table integer
)
returns void
language plpgsql
as $$
begin
  if p_seller is null or btrim(p_seller) = '' or p_table is null then
    return;
  end if;
  perform pg_advisory_xact_lock(
    hashtextextended(btrim(p_seller) || ':' || p_table::text || ':table', 0)
  );
end;
$$;

create or replace function public.lock_payment_session(
  p_seller text,
  p_table integer,
  p_session text
)
returns void
language plpgsql
as $$
begin
  perform public.lock_restaurant_table(p_seller, p_table);
  perform pg_advisory_xact_lock(
    hashtextextended(
      btrim(p_seller) || ':' || p_table::text || ':' || coalesce(p_session, ''),
      0
    )
  );
end;
$$;

create or replace function public.aaa_lock_table_payment()
returns trigger
language plpgsql
as $$
declare
  v_visit uuid;
  v_distinct integer;
  v_nulls integer;
begin
  perform public.lock_payment_session(
    new.seller_id::text, new.table_number, new.session_key
  );
  if tg_op <> 'INSERT' then
    return new;
  end if;
  select count(distinct visit_id), count(*) filter (where visit_id is null)
    into v_distinct, v_nulls
  from public.table_orders
  where seller_id::text = new.seller_id::text
    and table_number = new.table_number
    and public.table_order_is_open(status);
  if v_distinct = 1 and coalesce(v_nulls, 0) = 0 then
    select visit_id into v_visit
    from public.table_orders
    where seller_id::text = new.seller_id::text
      and table_number = new.table_number
      and public.table_order_is_open(status)
      and visit_id is not null
    limit 1;
    new.visit_id := v_visit;
  else
    new.visit_id := null;
  end if;
  return new;
end;
$$;

drop trigger if exists aaa_table_payment_table_lock on public.table_payments;
create trigger aaa_table_payment_table_lock
  before insert or update on public.table_payments
  for each row
  execute function public.aaa_lock_table_payment();

create or replace function public.aaa_lock_table_order()
returns trigger
language plpgsql
as $$
declare
  v_seller text;
  v_visit uuid;
  v_distinct integer;
  v_nulls integer;
  v_open_count integer;
begin
  if tg_op = 'DELETE' then
    perform public.lock_restaurant_table(old.seller_id::text, old.table_number);
    return old;
  end if;
  v_seller := new.seller_id::text;
  if tg_op = 'UPDATE'
     and new.table_number is distinct from old.table_number then
    if old.table_number < new.table_number then
      perform public.lock_restaurant_table(v_seller, old.table_number);
      perform public.lock_restaurant_table(v_seller, new.table_number);
    else
      perform public.lock_restaurant_table(v_seller, new.table_number);
      perform public.lock_restaurant_table(v_seller, old.table_number);
    end if;
  else
    perform public.lock_restaurant_table(v_seller, new.table_number);
  end if;
  if tg_op = 'INSERT' and public.table_order_is_open(new.status) then
    select count(*),
           count(*) filter (where visit_id is null),
           count(distinct visit_id)
      into v_open_count, v_nulls, v_distinct
    from public.table_orders
    where seller_id::text = v_seller
      and table_number = new.table_number
      and public.table_order_is_open(status);
    if coalesce(v_open_count, 0) = 0 then
      new.visit_id := coalesce(new.visit_id, gen_random_uuid());
    elsif coalesce(v_nulls, 0) > 0 or coalesce(v_distinct, 0) > 1 then
      if coalesce(v_distinct, 0) > 0 then
        new.visit_id := null;
      end if;
    elsif coalesce(v_distinct, 0) = 1 and new.visit_id is null then
      select visit_id into v_visit
      from public.table_orders
      where seller_id::text = v_seller
        and table_number = new.table_number
        and public.table_order_is_open(status)
        and visit_id is not null
      limit 1;
      new.visit_id := v_visit;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists aaa_table_order_bill_lock on public.table_orders;
create trigger aaa_table_order_bill_lock
  before insert or update or delete on public.table_orders
  for each row
  execute function public.aaa_lock_table_order();

create or replace function public.create_table_order_with_print_jobs(
  p_restaurant_id uuid,
  p_table_number integer,
  p_items jsonb,
  p_waiter_id uuid,
  p_waiter_name text,
  p_notes text,
  p_job_type text,
  p_order_type text,
  p_local_order_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_local text := nullif(btrim(coalesce(p_local_order_id, '')), '');
  v_existing uuid;
  v_jobs jsonb;
  v_allowed boolean;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;
  begin
    v_allowed := public.restaurant_has_permission(p_restaurant_id, 'manageOrders');
  exception
    when others then
      raise exception 'Sipariş yetkisi doğrulanamadı.' using errcode = '42501';
  end;
  if v_allowed is not true then
    raise exception 'Sipariş gönderme yetkisi yok.' using errcode = '42501';
  end if;

  if v_local is not null then
    select id into v_existing
    from public.orders
    where restaurant_id = p_restaurant_id
      and local_order_id = v_local
    limit 1;
    if found then
      select coalesce(jsonb_agg(id), '[]'::jsonb) into v_jobs
      from public.print_jobs where order_id = v_existing;
      return jsonb_build_object(
        'order_id', v_existing,
        'print_job_ids', v_jobs,
        'print_job_count', jsonb_array_length(v_jobs),
        'idempotent_replay', true
      );
    end if;
  end if;

  begin
    return public.create_table_order_with_print_jobs_impl(
      p_restaurant_id, p_table_number, p_items, p_waiter_id, p_waiter_name,
      p_notes, p_job_type, p_order_type, p_local_order_id
    );
  exception
    when unique_violation then
      select id into v_existing
      from public.orders
      where restaurant_id = p_restaurant_id
        and local_order_id = v_local
      limit 1;
      if v_existing is null then
        raise;
      end if;
      select coalesce(jsonb_agg(id), '[]'::jsonb) into v_jobs
      from public.print_jobs where order_id = v_existing;
      return jsonb_build_object(
        'order_id', v_existing,
        'print_job_ids', v_jobs,
        'print_job_count', jsonb_array_length(v_jobs),
        'idempotent_replay', true
      );
  end;
end;
$$;

create or replace function public.merge_table_bills(
  p_seller_id text,
  p_source_table integer,
  p_target_table integer,
  p_source_order_ids jsonb,
  p_target_order_ids jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller text := btrim(coalesce(p_seller_id, ''));
  v_source_ids uuid[];
  v_target_ids uuid[];
  v_seen_source uuid[];
  v_seen_target uuid[];
  v_source_visits uuid[];
  v_target_visits uuid[];
  v_moved_orders integer := 0;
  v_moved_payments integer := 0;
  v_low integer;
  v_high integer;
  v_allowed boolean;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;
  if v_seller = '' or p_source_table is null or p_target_table is null
     or p_source_table <= 0 or p_target_table <= 0
     or p_source_table = p_target_table then
    raise exception 'Kaynak ve hedef masa geçersiz.';
  end if;
  begin
    v_allowed := public.restaurant_has_permission(v_seller::uuid, 'transferTable');
  exception
    when others then
      raise exception 'Masa birleştirme yetkisi doğrulanamadı.' using errcode = '42501';
  end;
  if v_allowed is not true then
    raise exception 'Masa aktarma yetkisi yok.' using errcode = '42501';
  end if;

  if p_source_table < p_target_table then
    v_low := p_source_table; v_high := p_target_table;
  else
    v_low := p_target_table; v_high := p_source_table;
  end if;
  perform public.lock_restaurant_table(v_seller, v_low);
  perform public.lock_restaurant_table(v_seller, v_high);

  select coalesce(array_agg(id order by id), '{}')
    into v_source_ids
  from (
    select id from public.table_orders
    where seller_id::text = v_seller and table_number = p_source_table
      and public.table_order_is_open(status)
    for update
  ) s;
  select coalesce(array_agg(id order by id), '{}')
    into v_target_ids
  from (
    select id from public.table_orders
    where seller_id::text = v_seller and table_number = p_target_table
      and public.table_order_is_open(status)
    for update
  ) t;

  select coalesce(array_agg(value::uuid order by value::uuid), '{}')
    into v_seen_source
  from jsonb_array_elements_text(coalesce(p_source_order_ids, '[]'::jsonb));
  select coalesce(array_agg(value::uuid order by value::uuid), '{}')
    into v_seen_target
  from jsonb_array_elements_text(coalesce(p_target_order_ids, '[]'::jsonb));
  if v_source_ids is distinct from v_seen_source
     or v_target_ids is distinct from v_seen_target then
    raise exception 'Masalar değişti. Birleştirme yapılmadı.';
  end if;
  if cardinality(v_source_ids) = 0 then
    raise exception 'Kaynak masada birleştirilecek açık adisyon yok.';
  end if;

  select coalesce(array_agg(distinct visit_id), '{}')
    into v_source_visits
  from public.table_orders
  where id = any(v_source_ids);
  select coalesce(array_agg(distinct visit_id) filter (where visit_id is not null), '{}')
    into v_target_visits
  from public.table_orders
  where id = any(v_target_ids);

  if cardinality(v_source_visits) <> 1
     or exists (select 1 from public.table_orders where id = any(v_source_ids) and visit_id is null)
     or (cardinality(v_target_ids) > 0 and (
       cardinality(v_target_visits) <> 1
       or exists (select 1 from public.table_orders where id = any(v_target_ids) and visit_id is null)
     )) then
    raise exception 'Bu masada birden fazla veya belirsiz ziyaret var. Birleştirme yapılmadı.';
  end if;

  if exists (
    select 1 from public.table_payments p
    where p.seller_id::text = v_seller and p.table_number = p_source_table
      and p.visit_id is null
      and p.created_at >= (select min(created_at) from public.table_orders where id = any(v_source_ids))
  ) or exists (
    select 1 from public.table_payments p
    where p.seller_id::text = v_seller and p.table_number = p_target_table
      and p.visit_id is null
      and cardinality(v_target_ids) > 0
      and p.created_at >= (select min(created_at) from public.table_orders where id = any(v_target_ids))
  ) then
    raise exception 'Bu masadaki ara ödemenin ziyareti belirsiz. Birleştirme yapılmadı.';
  end if;

  perform public.lock_payment_session(v_seller, p_source_table, session_key)
  from (
    select distinct session_key
    from public.table_payments
    where seller_id::text = v_seller
      and table_number = p_source_table
      and visit_id = v_source_visits[1]
    order by session_key
  ) sessions;

  update public.table_orders
  set table_number = p_target_table
  where id = any(v_source_ids) and seller_id::text = v_seller;
  get diagnostics v_moved_orders = row_count;

  update public.table_payments
  set table_number = p_target_table
  where seller_id::text = v_seller
    and table_number = p_source_table
    and visit_id = v_source_visits[1];
  get diagnostics v_moved_payments = row_count;

  return jsonb_build_object(
    'success', true,
    'moved_orders', v_moved_orders,
    'moved_payments', v_moved_payments,
    'source_visit_id', v_source_visits[1]
  );
end;
$$;

comment on function public.merge_table_bills(text, integer, integer, jsonb, jsonb) is
  'Moves one proven visit onto another table. Does not invent visit_id and does not collapse multiple visits.';

revoke all on function public.create_table_order_with_print_jobs(
  uuid, integer, jsonb, uuid, text, text, text, text, text
) from public;
revoke all on function public.merge_table_bills(text, integer, integer, jsonb, jsonb) from public;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on function public.create_table_order_with_print_jobs(
      uuid, integer, jsonb, uuid, text, text, text, text, text
    ) from anon;
    revoke all on function public.merge_table_bills(text, integer, integer, jsonb, jsonb) from anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.create_table_order_with_print_jobs(
      uuid, integer, jsonb, uuid, text, text, text, text, text
    ) to authenticated;
    grant execute on function public.merge_table_bills(text, integer, integer, jsonb, jsonb) to authenticated;
  end if;
end
$$;

notify pgrst, 'reload schema';

commit;
