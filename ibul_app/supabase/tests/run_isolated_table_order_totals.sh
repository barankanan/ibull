#!/bin/bash
# Proves 20261124_table_order_totals_DRAFT on a THROWAWAY PostgreSQL. Never
# connects to Supabase. before: header 0 / no line totals (today's behaviour);
# after: header and line totals from unit_price * quantity, replay writes
# nothing, an old zero-total order is not rewritten, a client without the RPC
# flag still cannot change money columns; rolledback: today's behaviour again.
set -euo pipefail
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../.." && pwd)"
T="$HERE"; M="$HERE/../migrations"; D="$HERE/../drafts"
PG_BIN="${IBUL_PG_BIN:-$(dirname "$(command -v initdb)")}"
PORT="${IBUL_PGPORT:-55447}"
WORK="$(mktemp -d /tmp/ibul-tot.XXXXXX)"
cleanup(){ "$PG_BIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT
"$PG_BIN/initdb" -D "$WORK/data" -U ibul --auth=trust -E UTF8 >/dev/null
"$PG_BIN/pg_ctl" -D "$WORK/data" -l "$WORK/pg.log" -o "-p $PORT -k $WORK -c lc_messages=C" -w start >/dev/null
"$PG_BIN/createdb" -h 127.0.0.1 -p "$PORT" -U ibul tot
q(){ "$PG_BIN/psql" -h 127.0.0.1 -p "$PORT" -U ibul -d tot -v ON_ERROR_STOP=1 -q -At "$@"; }

q -f "$T/isolated_lan_sync_print.sql" >/dev/null
q -f "$ROOT/ibul_app/supabase/manual_patches/20261031_live_restaurant_rpc_ROLLBACK.sql" >/dev/null
q -f "$T/rehearsal_prod_state_stubs.sql" >/dev/null
q -f "$M/20261103223000_order_sync_print_evidence.sql" >/dev/null
q -f "$M/20261119090000_lan_print_evidence_key_registration.sql" >/dev/null
# Production columns and money locks the isolated schema does not carry.
q >/dev/null <<'SQL'
alter table public.orders add column if not exists updated_at timestamptz default now();
alter table public.order_items add column if not exists total_price numeric not null default 0;
alter table public.order_items add column if not exists line_total numeric;
create or replace function public.t_money_lock() returns trigger language plpgsql as $$
begin
  if current_setting('ibul.marketplace_order_rpc', true) = 'on' then return new; end if;
  if tg_op = 'INSERT' then raise exception 'ORDERS_INSERT_RPC_ONLY' using errcode='42501'; end if;
  if tg_table_name = 'orders' and (new.total_amount is distinct from old.total_amount
     or new.subtotal_amount is distinct from old.subtotal_amount) then
    raise exception 'ORDER_MONEY_COLUMNS_LOCKED' using errcode='42501'; end if;
  if tg_table_name = 'order_items' and (new.total_price is distinct from old.total_price
     or new.unit_price is distinct from old.unit_price or new.quantity is distinct from old.quantity) then
    raise exception 'ORDER_MONEY_COLUMNS_LOCKED' using errcode='42501'; end if;
  return new;
end $$;
create trigger t_orders_money before insert or update on public.orders for each row execute function public.t_money_lock();
create trigger t_items_money before insert or update on public.order_items for each row execute function public.t_money_lock();
SQL
echo "wrapper before: $(q -c "select md5(prosrc), length(prosrc) from pg_proc where pronamespace='public'::regnamespace and proname='create_table_order_with_print_jobs' and pronargs=12;")"
q -v phase=before -f "$T/isolated_table_order_totals_assert.sql" | grep RESULT
OLD="$(q -c "select md5(string_agg(o::text,'|' order by id::text)) from public.orders o; select md5(string_agg(i::text,'|' order by id::text)) from public.order_items i;" | tr '\n' ' ')"

q -f "$D/20261124_table_order_totals_DRAFT.sql" >/dev/null
q -v phase=after -f "$T/isolated_table_order_totals_assert.sql" | grep RESULT
echo "old zero-total rows untouched: $([ "$OLD" = "$(q -c "select md5(string_agg(o::text,'|' order by id::text)) from public.orders o where local_order_id like '%before'; select md5(string_agg(i::text,'|' order by i.id::text)) from public.order_items i join public.orders o on o.id=i.order_id where o.local_order_id like '%before';" | tr '\n' ' ')" ] && echo true || echo false)"
echo "old order replayed after the fix stays zero: $(q -c "select set_config('ibul.test_uid','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',false); select (public.create_table_order_with_print_jobs(p_restaurant_id => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', p_table_number => 1, p_items => '[{\"name\":\"Zeytin Salatası\",\"product_id\":\"p1\",\"quantity\":1,\"price\":200,\"station_id\":\"11111111-1111-1111-1111-111111111111\"},{\"name\":\"Tavuk Tava\",\"product_id\":\"p1\",\"quantity\":2,\"price\":300,\"station_id\":\"11111111-1111-1111-1111-111111111111\"}]'::jsonb, p_waiter_id => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', p_waiter_name => 'Ali', p_local_order_id => 'tot-before')->>'idempotent_replay'); select total_amount from public.orders where local_order_id='tot-before';" | tail -2 | tr '\n' ' ')"
echo "client without the RPC flag cannot change a total: $(q -c "update public.orders set total_amount = 1 where local_order_id = 'tot-after';" 2>&1 | grep -c ORDER_MONEY_COLUMNS_LOCKED)"
echo "acl after: anon=$(q -c "select has_function_privilege('anon', p.oid, 'execute') from pg_proc p where p.pronamespace='public'::regnamespace and p.proname='create_table_order_with_print_jobs' and pronargs=12;") authenticated=$(q -c "select has_function_privilege('authenticated', p.oid, 'execute') from pg_proc p where p.pronamespace='public'::regnamespace and p.proname='create_table_order_with_print_jobs' and pronargs=12;")"

q -f "$D/20261124_table_order_totals_ROLLBACK_DRAFT.sql" >/dev/null
echo "wrapper rolled back: $(q -c "select md5(prosrc), length(prosrc) from pg_proc where pronamespace='public'::regnamespace and proname='create_table_order_with_print_jobs' and pronargs=12;")"
q -v phase=rolledback -f "$T/isolated_table_order_totals_assert.sql" | grep RESULT
echo TOTALS_DONE
