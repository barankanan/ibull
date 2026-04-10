-- =============================================================================
-- Migration: restaurant_ops_upgrade
-- Date: 2026-04-07
-- Purpose: Production-level restaurant operations upgrade.
--   1. table_payments        — partial/full payment timeline per table
--   2. table_order_history   — permanent archive when orders are closed
--   3. table_transfers_log   — audit trail for all table transfers
--   4. waiter_order_stats    — view: per-waiter analytics
--   5. hourly_table_stats    — view: hourly heatmap data
--   6. Printer assignment helpers on station_printers
-- =============================================================================

-- ─── 1. TABLE PAYMENTS ────────────────────────────────────────────────────────
-- Records every payment event (partial or closing) for a table session.

create table if not exists public.table_payments (
  id            uuid primary key default gen_random_uuid(),
  seller_id     uuid not null references auth.users(id) on delete cascade,
  table_number  integer not null check (table_number > 0),
  session_key   text not null,                    -- groups payments in one session
  amount        numeric(12,2) not null check (amount > 0),
  method        text not null default 'cash'
                  check (method in ('cash','card','online','mixed','complimentary','other')),
  paid_by       text,                             -- customer name / identifier
  waiter_id     uuid references auth.users(id) on delete set null,
  waiter_name   text,
  note          text,
  is_closing    boolean not null default false,   -- true = this payment closes the table
  created_at    timestamptz not null default timezone('utc',now())
);

alter table public.table_payments enable row level security;

-- Sellers can manage their own payment records
create policy "table_payments_seller_manage"
  on public.table_payments
  for all
  using  (seller_id = auth.uid())
  with check (seller_id = auth.uid());

create index if not exists idx_table_payments_seller_table
  on public.table_payments (seller_id, table_number, created_at desc);

create index if not exists idx_table_payments_session
  on public.table_payments (session_key, created_at desc);

-- ─── 2. TABLE ORDER HISTORY ───────────────────────────────────────────────────
-- Permanent archive: rows are copied here BEFORE the active table_orders rows
-- are deleted/closed, so historical queries always work.

create table if not exists public.table_order_history (
  id                uuid primary key default gen_random_uuid(),
  original_order_id uuid not null,               -- FK to original table_orders.id (soft)
  seller_id         uuid not null references auth.users(id) on delete cascade,
  table_number      integer not null check (table_number > 0),
  items             jsonb not null default '[]'::jsonb,
  status            text not null default 'closed',
  revision          integer not null default 1,
  last_edit_summary jsonb not null default '{}'::jsonb,
  last_edit_note    text,
  payment_method    text,
  payment_note      text,
  waiter_id         uuid references auth.users(id) on delete set null,
  waiter_name       text,
  grand_total       numeric(12,2),
  session_key       text,                        -- links to table_payments
  opened_at         timestamptz,
  closed_at         timestamptz not null default timezone('utc',now()),
  created_at        timestamptz not null         -- original order created_at
);

alter table public.table_order_history enable row level security;

create policy "table_order_history_seller_read"
  on public.table_order_history
  for select
  using (seller_id = auth.uid());

create policy "table_order_history_seller_insert"
  on public.table_order_history
  for insert
  with check (seller_id = auth.uid());

create index if not exists idx_table_order_history_seller_closed
  on public.table_order_history (seller_id, closed_at desc);

create index if not exists idx_table_order_history_seller_table_closed
  on public.table_order_history (seller_id, table_number, closed_at desc);

-- ─── 3. TABLE TRANSFERS LOG ───────────────────────────────────────────────────

create table if not exists public.table_transfers_log (
  id              uuid primary key default gen_random_uuid(),
  seller_id       uuid not null references auth.users(id) on delete cascade,
  from_table      integer not null check (from_table > 0),
  to_table        integer not null check (to_table > 0),
  transfer_type   text not null default 'full'
                    check (transfer_type in ('full','partial','customer')),
  transferred_items jsonb not null default '[]'::jsonb,  -- items that moved
  order_ids       jsonb not null default '[]'::jsonb,    -- source order IDs
  waiter_id       uuid references auth.users(id) on delete set null,
  waiter_name     text,
  note            text,
  created_at      timestamptz not null default timezone('utc',now())
);

alter table public.table_transfers_log enable row level security;

create policy "table_transfers_log_seller_all"
  on public.table_transfers_log
  for all
  using  (seller_id = auth.uid())
  with check (seller_id = auth.uid());

create index if not exists idx_table_transfers_log_seller
  on public.table_transfers_log (seller_id, created_at desc);

-- ─── 4. WAITER ORDER STATS VIEW ───────────────────────────────────────────────
-- Live view combining active + historical orders per waiter.

create or replace view public.waiter_order_stats as
select
  h.seller_id,
  h.waiter_id,
  h.waiter_name,
  count(*)                          as order_count,
  coalesce(sum(h.grand_total), 0)   as total_revenue,
  round(
    coalesce(avg(h.grand_total), 0)::numeric,
    2
  )                                 as avg_ticket,
  min(h.closed_at)                  as first_order_at,
  max(h.closed_at)                  as last_order_at
from public.table_order_history h
where h.waiter_id is not null
group by h.seller_id, h.waiter_id, h.waiter_name;

-- ─── 5. HOURLY TABLE STATS VIEW ───────────────────────────────────────────────

create or replace view public.hourly_table_stats as
select
  seller_id,
  date_trunc('hour', closed_at at time zone 'UTC') as hour_bucket,
  count(*)                                          as order_count,
  coalesce(sum(grand_total), 0)                     as total_revenue
from public.table_order_history
group by seller_id, hour_bucket;

-- ─── 6. CLOSE TABLE WITH HISTORY RPC ──────────────────────────────────────────
-- Atomically archives orders into history AND deletes active rows in one call.

create or replace function public.close_table_with_history(
  p_seller_id     uuid,
  p_table_number  integer,
  p_payment_method text default 'cash',
  p_payment_note  text default null,
  p_waiter_id     uuid default null,
  p_waiter_name   text default null,
  p_session_key   text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_grand_total numeric(12,2);
  v_session text;
begin
  -- Verify caller owns this store
  if p_seller_id <> auth.uid() then
    raise exception 'Yetki hatası: bu masayı kapatma yetkiniz yok.' using errcode = '42501';
  end if;

  v_session := coalesce(p_session_key, 'session_' || p_seller_id || '_' || p_table_number || '_' || extract(epoch from now())::bigint::text);

  -- Archive each active order
  for v_order in
    select * from public.table_orders
    where seller_id = p_seller_id
      and table_number = p_table_number
  loop
    -- Compute grand total for this order
    select coalesce(sum(
      (item->>'price')::numeric * coalesce((item->>'quantity')::numeric, 1)
    ), 0)
    into v_grand_total
    from jsonb_array_elements(coalesce(v_order.items, '[]'::jsonb)) as item;

    insert into public.table_order_history (
      original_order_id, seller_id, table_number,
      items, status, revision,
      last_edit_summary, last_edit_note,
      payment_method, payment_note,
      waiter_id, waiter_name,
      grand_total, session_key,
      opened_at, closed_at, created_at
    ) values (
      v_order.id, p_seller_id, p_table_number,
      coalesce(v_order.items, '[]'::jsonb),
      'closed',
      coalesce(v_order.revision, 1),
      coalesce(v_order.last_edit_summary, '{}'::jsonb),
      v_order.last_edit_note,
      p_payment_method, p_payment_note,
      p_waiter_id, p_waiter_name,
      v_grand_total, v_session,
      v_order.created_at, timezone('utc',now()),
      v_order.created_at
    );
  end loop;

  -- Remove active orders
  delete from public.table_orders
  where seller_id = p_seller_id
    and table_number = p_table_number;
end;
$$;

-- ─── 7. TRANSFER TABLE RPC ────────────────────────────────────────────────────
-- Moves items from source table to destination. Supports full/partial transfer.

create or replace function public.transfer_table_orders(
  p_seller_id       uuid,
  p_from_table      integer,
  p_to_table        integer,
  p_transfer_type   text default 'full',        -- 'full' | 'partial'
  p_item_ids        jsonb default '[]'::jsonb,  -- order_item ids for partial
  p_waiter_id       uuid default null,
  p_waiter_name     text default null,
  p_note            text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_src_orders   jsonb := '[]'::jsonb;
  v_moved_items  jsonb := '[]'::jsonb;
  v_order        record;
  v_new_items    jsonb;
  v_dst_order    record;
  v_order_id_list jsonb := '[]'::jsonb;
begin
  if p_seller_id <> auth.uid() then
    raise exception 'Yetki hatası.' using errcode = '42501';
  end if;
  if p_from_table = p_to_table then
    raise exception 'Kaynak ve hedef masa aynı olamaz.';
  end if;

  -- Collect source orders
  for v_order in
    select * from public.table_orders
    where seller_id = p_seller_id and table_number = p_from_table
  loop
    v_order_id_list := v_order_id_list || to_jsonb(v_order.id::text);

    if p_transfer_type = 'full' then
      -- Move entire order to destination
      update public.table_orders
      set table_number = p_to_table,
          updated_at   = timezone('utc',now())
      where id = v_order.id;
      v_moved_items := v_moved_items || coalesce(v_order.items,'[]'::jsonb);
    else
      -- Partial: only move items whose 'id' is in p_item_ids
      select
        jsonb_agg(item) filter (where (item->>'id') = any(select jsonb_array_elements_text(p_item_ids))),
        jsonb_agg(item) filter (where (item->>'id') <> all(select jsonb_array_elements_text(p_item_ids)))
      into v_moved_items, v_new_items
      from jsonb_array_elements(coalesce(v_order.items,'[]'::jsonb)) item;

      if v_new_items is null or jsonb_array_length(v_new_items) = 0 then
        -- All items transferred → move entire order row
        update public.table_orders
        set table_number = p_to_table,
            updated_at   = timezone('utc',now())
        where id = v_order.id;
      else
        -- Update source with remaining items
        update public.table_orders
        set items      = v_new_items,
            updated_at = timezone('utc',now())
        where id = v_order.id;
        -- Insert moved items as new order at destination
        insert into public.table_orders (seller_id, table_number, items, status, created_at)
        values (p_seller_id, p_to_table, coalesce(v_moved_items,'[]'::jsonb), 'new', timezone('utc',now()));
      end if;
    end if;
  end loop;

  -- Log the transfer
  insert into public.table_transfers_log (
    seller_id, from_table, to_table, transfer_type,
    transferred_items, order_ids, waiter_id, waiter_name, note
  ) values (
    p_seller_id, p_from_table, p_to_table, p_transfer_type,
    v_moved_items, v_order_id_list, p_waiter_id, p_waiter_name, p_note
  );

  return jsonb_build_object(
    'success', true,
    'moved_items', v_moved_items,
    'transfer_type', p_transfer_type
  );
end;
$$;

-- ─── 8. WAITER PERFORMANCE RPC ────────────────────────────────────────────────
-- Returns per-waiter stats for a date range. Used by admin performance panel.

create or replace function public.get_waiter_performance(
  p_seller_id uuid,
  p_from      timestamptz default now() - interval '30 days',
  p_to        timestamptz default now()
)
returns table (
  waiter_id       uuid,
  waiter_name     text,
  order_count     bigint,
  total_revenue   numeric,
  avg_ticket      numeric,
  top_product     text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_seller_id <> auth.uid() then
    raise exception 'Yetki hatası.' using errcode = '42501';
  end if;

  return query
  with base as (
    select
      h.waiter_id,
      h.waiter_name,
      h.grand_total,
      item->>'name' as product_name
    from public.table_order_history h
    cross join lateral jsonb_array_elements(coalesce(h.items,'[]'::jsonb)) item
    where h.seller_id = p_seller_id
      and h.closed_at between p_from and p_to
      and h.waiter_id is not null
  ),
  stats as (
    select
      waiter_id,
      waiter_name,
      count(distinct grand_total)  as order_count,  -- proxy
      sum(grand_total)             as total_revenue,
      avg(grand_total)             as avg_ticket
    from (select distinct waiter_id, waiter_name, grand_total from base) s
    group by waiter_id, waiter_name
  ),
  top_products as (
    select distinct on (waiter_id)
      waiter_id,
      product_name,
      count(*) as cnt
    from base
    where product_name is not null
    group by waiter_id, product_name
    order by waiter_id, count(*) desc
  )
  select
    s.waiter_id,
    s.waiter_name,
    s.order_count,
    round(coalesce(s.total_revenue,0)::numeric, 2),
    round(coalesce(s.avg_ticket,0)::numeric, 2),
    tp.product_name
  from stats s
  left join top_products tp using (waiter_id)
  order by s.total_revenue desc;
end;
$$;

-- ─── 9. SMART RECOMMENDATION RPC ─────────────────────────────────────────────
-- Returns co-purchased products based on historical order history.

create or replace function public.get_product_recommendations(
  p_seller_id   uuid,
  p_product_ids jsonb,         -- currently in the draft
  p_limit       int default 5
)
returns table (
  product_name  text,
  product_id    text,
  score         bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with basket as (
    -- Select orders containing at least one of the given products
    select h.id as order_id, item->>'id' as pid, item->>'name' as pname
    from public.table_order_history h
    cross join lateral jsonb_array_elements(coalesce(h.items,'[]'::jsonb)) item
    where h.seller_id = p_seller_id
  ),
  seed_orders as (
    select distinct order_id
    from basket
    where pid = any (select jsonb_array_elements_text(p_product_ids))
  ),
  co_items as (
    select b.pid, b.pname, count(*) as cnt
    from basket b
    join seed_orders so using (order_id)
    where b.pid <> all (select jsonb_array_elements_text(p_product_ids))
    group by b.pid, b.pname
  )
  select pname, pid, cnt
  from co_items
  order by cnt desc
  limit p_limit;
end;
$$;

comment on table  public.table_payments       is 'Payment timeline for table sessions (partial + closing payments).';
comment on table  public.table_order_history  is 'Permanent archive of closed table orders. Never deleted.';
comment on table  public.table_transfers_log  is 'Audit log for every table transfer operation.';
comment on function public.close_table_with_history is 'Atomically archives active table orders to history and removes them from table_orders.';
comment on function public.transfer_table_orders    is 'Moves orders (full or partial) from one table to another with audit log.';
comment on function public.get_waiter_performance   is 'Returns per-waiter analytics for a given date range.';
comment on function public.get_product_recommendations is 'Returns co-purchased product suggestions based on historical order data.';
