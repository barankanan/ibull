-- Local only. Do not apply to production unless this file is named and the
-- operator says: Bu migration'ı production'a uygula.
--
-- Offline table settlement (çevrimdışı masa kapatma uzlaştırması).
--
-- Why a new contract: close_table_with_history closes EVERY open order on the
-- table at the moment it runs. A close made offline and sent later would also
-- close orders another device added in the meantime. This contract closes only
-- the orders the device actually settled, named by their local order ids.
--
-- Additive only: two tables, one function. Nothing existing is altered, and
-- the function refuses to run until a restaurant is switched on explicitly.
-- Rollback: see the block at the end of this file.

begin;

-- ---------------------------------------------------------------------------
-- Per-restaurant switch. No row = off.
-- ---------------------------------------------------------------------------
create table if not exists public.restaurant_offline_settlement_settings (
  restaurant_id uuid primary key,
  enabled boolean not null default false,
  updated_at timestamptz not null default timezone('utc', now())
);
alter table public.restaurant_offline_settlement_settings enable row level security;
revoke all on public.restaurant_offline_settlement_settings from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- One row per settlement attempt the server has decided on (applied/conflict).
-- (restaurant_id, settlement_id) is the idempotency key.
-- ---------------------------------------------------------------------------
create table if not exists public.restaurant_offline_settlements (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null,
  settlement_id text not null,
  table_number integer not null check (table_number > 0),
  local_order_ids text[] not null
    check (cardinality(local_order_ids) between 1 and 50),
  request_hash text not null,
  expected_total numeric(12,2) not null check (expected_total >= 0),
  payment_method text not null check (
    payment_method in ('cash', 'card', 'online', 'mixed', 'complimentary', 'other')
  ),
  payment_note text,
  closed_at_device timestamptz not null,
  closed_by uuid not null,
  verified_actor uuid not null,
  evidence_branch uuid,
  status text not null check (status in ('applied', 'conflict')),
  conflict_reason text,
  order_ids uuid[] not null default '{}'::uuid[],
  history_ids uuid[] not null default '{}'::uuid[],
  closed_total numeric(12,2),
  remaining_open_orders integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  constraint restaurant_offline_settlements_key unique (restaurant_id, settlement_id),
  constraint restaurant_offline_settlements_reason check (
    (status = 'applied' and conflict_reason is null)
    or (status = 'conflict' and conflict_reason is not null)
  )
);
alter table public.restaurant_offline_settlements enable row level security;
revoke all on public.restaurant_offline_settlements from public, anon, authenticated;

-- An order is settled offline at most once, whatever settlement id is used.
create table if not exists public.restaurant_offline_settlement_orders (
  order_id uuid primary key,
  restaurant_id uuid not null,
  settlement_pk uuid not null
    references public.restaurant_offline_settlements (id) on delete restrict,
  local_order_id text not null,
  order_total numeric(12,2) not null,
  history_id uuid not null
);
alter table public.restaurant_offline_settlement_orders enable row level security;
revoke all on public.restaurant_offline_settlement_orders from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- apply_offline_table_settlement
--
-- Called by the server-side verifier only (service role), after it has checked
-- the caller's session and the hub signature — the same path order sync uses.
--
-- Outcomes
--   applied   named orders closed, history written, row stored
--   conflict  nothing closed, the reason stored; a repeat returns the same row
--   error     nothing stored; the device may retry later (e.g. orders_not_synced)
--
-- Idempotency: a repeat of the same settlement id with the same content
-- returns the stored outcome with replayed=true. The same id with different
-- content is refused.
-- ---------------------------------------------------------------------------
create or replace function public.apply_offline_table_settlement(
  p_restaurant_id uuid,
  p_table_number integer,
  p_settlement_id text,
  p_local_order_ids text[],
  p_expected_total numeric,
  p_payment_method text,
  p_closed_at timestamptz,
  p_closed_by uuid,
  p_verified_actor uuid,
  p_evidence_branch uuid default null,
  p_payment_note text default null,
  p_waiter_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
  v_settlement_id text := nullif(btrim(coalesce(p_settlement_id, '')), '');
  v_local_ids text[];
  v_hash text;
  v_existing public.restaurant_offline_settlements%rowtype;
  v_enabled boolean := false;
  v_member public.store_sub_admins%rowtype;
  v_table_ids uuid[];
  v_table_branch uuid;
  v_order_ids uuid[] := '{}'::uuid[];
  v_found integer := 0;
  v_total numeric(12,2) := 0;
  v_conflict text;
  v_settlement_pk uuid;
  v_history_ids uuid[] := '{}'::uuid[];
  v_history_id uuid;
  v_remaining integer := 0;
  v_closed_at timestamptz;
  r record;
begin
  -- 1. Shape.
  if p_restaurant_id is null or p_table_number is null or p_table_number <= 0
     or v_settlement_id is null or length(v_settlement_id) > 120
     or p_expected_total is null or p_expected_total < 0
     or p_closed_at is null or p_closed_by is null or p_verified_actor is null then
    raise exception 'Geçersiz parametre.' using errcode = '22023';
  end if;
  if coalesce(p_payment_method, '') not in
     ('cash', 'card', 'online', 'mixed', 'complimentary', 'other') then
    raise exception 'Geçersiz ödeme yöntemi.' using errcode = '22023';
  end if;
  select coalesce(array_agg(x order by x), '{}'::text[])
    into v_local_ids
  from (
    select distinct nullif(btrim(u), '') as x
    from unnest(coalesce(p_local_order_ids, '{}'::text[])) as u
  ) s
  where x is not null;
  if cardinality(v_local_ids) = 0 or cardinality(v_local_ids) > 50 then
    raise exception 'Sipariş kümesi boş veya çok büyük.' using errcode = '22023';
  end if;

  -- 2. Switch. Off blocks everything, including repeats.
  select s.enabled into v_enabled
  from public.restaurant_offline_settlement_settings s
  where s.restaurant_id = p_restaurant_id;
  if not coalesce(v_enabled, false) then
    raise exception 'offline_settlement_disabled' using errcode = '55000';
  end if;

  -- 3. One decision per settlement id, even when two requests race.
  perform pg_advisory_xact_lock(
    hashtextextended(p_restaurant_id::text || '|' || v_settlement_id, 0)
  );
  v_hash := md5(concat_ws('|',
    p_table_number::text,
    array_to_string(v_local_ids, ','),
    to_char(p_expected_total::numeric(12,2), 'FM999999999990.00'),
    p_payment_method,
    to_char(p_closed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.US'),
    p_closed_by::text
  ));
  select * into v_existing
  from public.restaurant_offline_settlements s
  where s.restaurant_id = p_restaurant_id
    and s.settlement_id = v_settlement_id;
  if found then
    if v_existing.request_hash <> v_hash then
      raise exception 'settlement_id_reused_with_different_content'
        using errcode = '22023';
    end if;
    return jsonb_build_object(
      'status', v_existing.status,
      'conflict_reason', v_existing.conflict_reason,
      'settlement_id', v_existing.settlement_id,
      'order_ids', to_jsonb(v_existing.order_ids),
      'history_ids', to_jsonb(v_existing.history_ids),
      'closed_total', v_existing.closed_total,
      'remaining_open_orders', v_existing.remaining_open_orders,
      'replayed', true
    );
  end if;

  -- 4. Who closed it: the owner, or an active member allowed to close bills
  --    on this table's branch. Checked now, at apply time: access revoked
  --    while the device was offline does not survive the upload.
  select array_agg(t.id), max(t.branch_id::text)::uuid
    into v_table_ids, v_table_branch
  from public.store_tables t
  where t.seller_id = p_restaurant_id
    and t.table_number = p_table_number
    and t.is_active;
  if v_table_ids is null then
    raise exception 'Masa bulunamadı.' using errcode = '22023';
  end if;
  if p_closed_by <> p_restaurant_id then
    select * into v_member
    from public.store_sub_admins sa
    where sa.store_id = p_restaurant_id
      and sa.auth_user_id = p_closed_by
    limit 1;
    if not found
       or v_member.status <> 'active'
       or not ('closeBill' = any(coalesce(v_member.permissions, '{}'::text[])))
       or (v_member.branch_id is not null
           and v_table_branch is not null
           and v_member.branch_id <> v_table_branch) then
      raise exception 'Bu işlem için yetkiniz yok.' using errcode = '42501';
    end if;
  end if;

  -- 5. The named orders, locked. All of them must already be on the server:
  --    otherwise nothing is stored and the device retries after order sync.
  for r in
    select o.id, o.local_order_id, o.table_id, o.order_type, o.delivery_type,
           coalesce(o.status, '') as status
    from public.orders o
    where o.restaurant_id = p_restaurant_id
      and o.local_order_id = any(v_local_ids)
    order by o.id
    for update
  loop
    v_found := v_found + 1;
    v_order_ids := v_order_ids || r.id;
    if v_conflict is null then
      if not (coalesce(r.order_type, '') = 'table'
              or coalesce(r.delivery_type, '') = 'table')
         or r.table_id is null
         or not (r.table_id = any(v_table_ids)) then
        v_conflict := 'order_table_mismatch';
      elsif exists (
        select 1 from public.restaurant_offline_settlement_orders so
        where so.order_id = r.id
      ) then
        v_conflict := 'order_already_settled';
      elsif r.status in ('closed', 'paid', 'cancelled', 'canceled', 'completed',
                         'complete', 'archived', 'payment_completed') then
        -- Closed online by someone else while this device was offline. Taking
        -- the offline payment as well would count the money twice.
        v_conflict := 'order_already_closed';
      end if;
    end if;
  end loop;
  if v_found < cardinality(v_local_ids) then
    raise exception 'orders_not_synced' using errcode = 'P0002';
  end if;

  -- 6. The bill the device charged must be the bill the server holds.
  select coalesce(sum(coalesce(
           i.line_total, i.total_price, i.unit_price * i.quantity, 0)), 0)::numeric(12,2)
    into v_total
  from public.order_items i
  where i.order_id = any(v_order_ids);
  if v_conflict is null and v_total <> p_expected_total::numeric(12,2) then
    v_conflict := 'total_mismatch';
  end if;

  if v_conflict is not null then
    insert into public.restaurant_offline_settlements (
      restaurant_id, settlement_id, table_number, local_order_ids, request_hash,
      expected_total, payment_method, payment_note, closed_at_device, closed_by,
      verified_actor, evidence_branch, status, conflict_reason, order_ids,
      closed_total
    ) values (
      p_restaurant_id, v_settlement_id, p_table_number, v_local_ids, v_hash,
      p_expected_total, p_payment_method, p_payment_note, p_closed_at, p_closed_by,
      p_verified_actor, p_evidence_branch, 'conflict', v_conflict, v_order_ids,
      v_total
    );
    return jsonb_build_object(
      'status', 'conflict',
      'conflict_reason', v_conflict,
      'settlement_id', v_settlement_id,
      'order_ids', to_jsonb(v_order_ids),
      'history_ids', '[]'::jsonb,
      'closed_total', v_total,
      'remaining_open_orders', 0,
      'replayed', false
    );
  end if;

  -- 7. Apply: the settlement row, one history row per order, then close
  --    exactly those orders.
  v_closed_at := least(p_closed_at, timezone('utc', now()));
  insert into public.restaurant_offline_settlements (
    restaurant_id, settlement_id, table_number, local_order_ids, request_hash,
    expected_total, payment_method, payment_note, closed_at_device, closed_by,
    verified_actor, evidence_branch, status, order_ids, closed_total
  ) values (
    p_restaurant_id, v_settlement_id, p_table_number, v_local_ids, v_hash,
    p_expected_total, p_payment_method, p_payment_note, p_closed_at, p_closed_by,
    p_verified_actor, p_evidence_branch, 'applied', v_order_ids, v_total
  )
  returning id into v_settlement_pk;

  for r in
    select o.id, o.local_order_id, to_jsonb(o) as payload,
           coalesce((
             select sum(coalesce(i.line_total, i.total_price,
                                 i.unit_price * i.quantity, 0))
             from public.order_items i where i.order_id = o.id
           ), 0)::numeric(12,2) as row_total,
           coalesce((
             select jsonb_agg(to_jsonb(i) order by i.created_at, i.id)
             from public.order_items i where i.order_id = o.id
           ), '[]'::jsonb) as items
    from public.orders o
    where o.id = any(v_order_ids)
    order by o.created_at, o.id
  loop
    insert into public.table_order_history (
      original_order_id, seller_id, table_number, items, status, session_key,
      payment_method, payment_note, waiter_id, waiter_name, grand_total,
      archived_orders, archived_at, closed_at
    ) values (
      r.id, p_restaurant_id, p_table_number, r.items, 'closed',
      'offline-settlement:' || v_settlement_id || ':' || r.id::text,
      p_payment_method, p_payment_note, p_closed_by, p_waiter_name, r.row_total,
      jsonb_build_array(r.payload), timezone('utc', now()), v_closed_at
    )
    returning id into v_history_id;
    v_history_ids := v_history_ids || v_history_id;
    insert into public.restaurant_offline_settlement_orders (
      order_id, restaurant_id, settlement_pk, local_order_id, order_total, history_id
    ) values (
      r.id, p_restaurant_id, v_settlement_pk, r.local_order_id, r.row_total,
      v_history_id
    );
  end loop;

  perform set_config('ibul.marketplace_order_rpc', 'on', true);
  update public.orders o
  set status = 'closed',
      order_status = 'closed',
      updated_at = timezone('utc', now())
  where o.id = any(v_order_ids);
  perform set_config('ibul.marketplace_order_rpc', 'off', true);

  -- Orders someone added to the table after the offline close stay open.
  select count(*) into v_remaining
  from public.orders o
  where o.restaurant_id = p_restaurant_id
    and (o.order_type = 'table' or o.delivery_type = 'table')
    and o.table_id = any(v_table_ids)
    and not (o.id = any(v_order_ids))
    and coalesce(o.status, '') not in (
      'closed', 'paid', 'cancelled', 'canceled', 'completed', 'complete',
      'archived', 'payment_completed'
    );

  update public.restaurant_offline_settlements
  set history_ids = v_history_ids,
      remaining_open_orders = v_remaining
  where id = v_settlement_pk;

  return jsonb_build_object(
    'status', 'applied',
    'conflict_reason', null,
    'settlement_id', v_settlement_id,
    'order_ids', to_jsonb(v_order_ids),
    'history_ids', to_jsonb(v_history_ids),
    'closed_total', v_total,
    'remaining_open_orders', v_remaining,
    'replayed', false
  );
end;
$function$;

revoke all on function public.apply_offline_table_settlement(
  uuid, integer, text, text[], numeric, text, timestamptz, uuid, uuid, uuid, text, text
) from public, anon, authenticated;
grant execute on function public.apply_offline_table_settlement(
  uuid, integer, text, text[], numeric, text, timestamptz, uuid, uuid, uuid, text, text
) to service_role;

commit;

-- ---------------------------------------------------------------------------
-- Rollback (run by hand; safe while no settlement has been applied):
--
--   begin;
--   drop function if exists public.apply_offline_table_settlement(
--     uuid, integer, text, text[], numeric, text, timestamptz, uuid, uuid, uuid, text, text);
--   drop table if exists public.restaurant_offline_settlement_orders;
--   drop table if exists public.restaurant_offline_settlements;
--   drop table if exists public.restaurant_offline_settlement_settings;
--   commit;
--
-- Softer stop that keeps the records: set enabled = false for the restaurant,
-- or revoke execute from service_role.
-- ---------------------------------------------------------------------------
