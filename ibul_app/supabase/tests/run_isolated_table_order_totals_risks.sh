#!/bin/bash
# Risk proof for drafts/20261124_table_order_totals_DRAFT.sql on a THROWAWAY
# PostgreSQL. Never connects to Supabase. Unlike run_isolated_table_order_totals.sh
# this one runs the PRODUCTION bodies (md5-checked) of the order RPC, the staff
# write guard, both money guards, the edit RPC and the close RPC, and answers:
# is an amount counted twice, does stored history change, are old zero rows
# rewritten, do staff still order, do line kinds add up, does a resend or a
# race add the amount again, is the money flag left on, does rollback work.
set -euo pipefail
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
HERE="$(cd "$(dirname "$0")" && pwd)"; SUP="$(cd "$HERE/.." && pwd)"
T="$HERE"; M="$SUP/migrations"; D="$SUP/drafts"; P="$SUP/manual_patches"
PG_BIN="${IBUL_PG_BIN:-$(dirname "$(command -v initdb)")}"
PORT="${IBUL_PGPORT:-55449}"
WORK="$(mktemp -d /tmp/ibul-totrisk.XXXXXX)"
cleanup(){ "$PG_BIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT
"$PG_BIN/initdb" -D "$WORK/data" -U ibul --auth=trust -E UTF8 >/dev/null
"$PG_BIN/pg_ctl" -D "$WORK/data" -l "$WORK/pg.log" -o "-p $PORT -k $WORK -c lc_messages=C" -w start >/dev/null
"$PG_BIN/createdb" -h 127.0.0.1 -p "$PORT" -U ibul tot
q(){ "$PG_BIN/psql" -h 127.0.0.1 -p "$PORT" -U ibul -d tot -v ON_ERROR_STOP=1 -q -At "$@"; }

# CREATE FUNCTION statement of <name> whose body md5 starts with <md5> in <file>.
fn(){ python3 - "$1" "$2" "$3" <<'PY'
import re,sys,hashlib
f,name,want=sys.argv[1:4]; s=open(f,encoding='utf-8').read()
pat=re.compile(r'create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?'+re.escape(name)+r'\s*\(.*?\bas\s+(\$\w*\$)(.*?)\1[^;]*;',re.S|re.I)
for m in pat.finditer(s):
    if hashlib.md5(m.group(2).encode()).hexdigest().startswith(want):
        print(re.sub(r'^create\s+function','create or replace function',m.group(0),flags=re.I)); sys.exit(0)
sys.exit('body %s %s not found in %s'%(name,want,f))
PY
}

q -f "$T/isolated_lan_sync_print.sql" >/dev/null 2>&1
q -f "$P/20261031_live_restaurant_rpc_ROLLBACK.sql" >/dev/null 2>&1
q -f "$T/rehearsal_prod_state_stubs.sql" >/dev/null 2>&1
q -f "$M/20261103223000_order_sync_print_evidence.sql" >/dev/null 2>&1
q -f "$M/20261119090000_lan_print_evidence_key_registration.sql" >/dev/null 2>&1
q -f "$T/isolated_table_order_totals_risks_setup.sql" >/dev/null
q -f "$M/20261122150000_order_rpc_product_ownership_guard.sql" >/dev/null 2>&1
{
  fn "$M/2026102901_restaurant_staff_access.sql" is_managed_restaurant_staff 418d25bc
  fn "$M/2026110101_print_identity_and_staff_password_gate.sql" restaurant_has_permission 0e3ee1dd
  fn "$M/2026110101_print_identity_and_staff_password_gate.sql" restaurant_table_access cc94f03b
  fn "$M/2026110117_staff_operation_permissions.sql" restaurant_staff_may_operate 0808107c
  fn "$M/20261122100000_table_transfer_staff_guard.sql" guard_restaurant_staff_order_write f1a286b2
  fn "$P/20261004_p0_money_authority_stage_b_enforce.sql" orders_money_authority_guard e82dc94f
  fn "$P/20261004_p0_money_authority_stage_b_enforce.sql" order_items_money_authority_guard 18fbaf74
  fn "$M/20261105183000_close_table_history_order_id.sql" close_table_with_history ae2bbeee
} > "$WORK/prod_bodies.sql"
q -f "$WORK/prod_bodies.sql" >/dev/null
q -f "$T/isolated_table_order_totals_risks_lib.sql" >/dev/null

# Bodies read from production (read-only) on 2026-11-24.
EXPECT="close_table_with_history:ae2bbeeec475e796f5683273b90127c0
create_table_order_with_print_jobs:242e2b133c1c3d021022cd675fc0da78
create_table_order_with_print_jobs_impl:b521ede60c1f275836a002aed75fd1cd
guard_restaurant_staff_order_write:f1a286b2a2b964cb2f3e863defe888b2
is_managed_restaurant_staff:418d25bce3d76b3810697d4441f06dce
order_items_money_authority_guard:18fbaf74cacb225219452e1947855110
orders_money_authority_guard:e82dc94fd4b5bc2233cd04469adc64f7
restaurant_has_permission:0e3ee1dd693db469ade63e507455d0ed
restaurant_staff_may_operate:0808107c4e7f089c6c822c3801152004
restaurant_table_access:cc94f03b7ef7d7908927afb64f127c09
update_restaurant_table_order:ee208c4fd6ac0e97a2ea7a1f79b73a24"
GOT="$(q -c "select proname || ':' || md5(prosrc) from pg_proc where pronamespace='public'::regnamespace and proname in ('close_table_with_history','create_table_order_with_print_jobs','create_table_order_with_print_jobs_impl','guard_restaurant_staff_order_write','order_items_money_authority_guard','orders_money_authority_guard','restaurant_has_permission','restaurant_staff_may_operate','restaurant_table_access','update_restaurant_table_order') or (proname='is_managed_restaurant_staff' and pronargs=0) order by 1")"
if [ "$GOT" = "$EXPECT" ]; then echo "production bodies identical (11 functions, md5): true"; else echo "production bodies identical: FALSE"; diff <(echo "$EXPECT") <(echo "$GOT") || true; exit 1; fi

q -f "$T/isolated_table_order_totals_risks_before.sql" | grep '^BEFORE'
q -f "$D/20261124_table_order_totals_DRAFT.sql" >/dev/null
# Production wrapper after the manual apply of 2026-11-24 (read-only): b328f59d4ab26730ea26f4c034d64a22
W="$(q -c "select md5(prosrc) from pg_proc where pronamespace='public'::regnamespace and proname='create_table_order_with_print_jobs'")"
echo "wrapper under test: $W (same as production now: $([ "$W" = "b328f59d4ab26730ea26f4c034d64a22" ] && echo true || echo FALSE))"
[ "$W" = "b328f59d4ab26730ea26f4c034d64a22" ] || exit 1
q -f "$T/isolated_table_order_totals_risks_after.sql" | grep -E '^(OK|FAIL|AFTER)'

# Two devices send the same order at the same moment (same key).
ITEMS='[{"name":"Zeytin Salatası","product_id":"p1","quantity":1,"price":200,"station_id":"11111111-1111-1111-1111-111111111111"},{"name":"Tavuk Tava","product_id":"p2","quantity":2,"price":300,"station_id":"11111111-1111-1111-1111-111111111111"}]'
for i in 1 2 3 4 5 6; do
  q -c "select public.t_send('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 1, 'race-1', '$ITEMS'::jsonb)" >/dev/null &
done
wait
q -c "select public.t_check('six_simultaneous_sends_one_order_one_amount',
  (select count(*) from public.orders where local_order_id='race-1') = 1 and public.t_show('race-1') like '800.00/800.00 sum=800.00 lines=200.00:200.00,600.00:600.00 %',
  'orders=' || (select count(*) from public.orders where local_order_id='race-1') || ' ' || public.t_show('race-1'))"

# Rollback: the function is production's again; written totals stay; new orders are zero again.
q -f "$D/20261124_table_order_totals_ROLLBACK_DRAFT.sql" >/dev/null
q -c "select public.t_send('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 1, 'after-rollback', '$ITEMS'::jsonb)" >/dev/null
q -c "select public.t_check('rollback_restores_production_function',
  (select md5(prosrc) from pg_proc where pronamespace='public'::regnamespace and proname='create_table_order_with_print_jobs') = '242e2b133c1c3d021022cd675fc0da78'
  and public.t_show('after-rollback') like '0/0 sum=800.00 lines=0:null,0:null %' and public.t_show('new-1') like '800.00/800.00 %',
  'after-rollback ' || public.t_show('after-rollback') || ' | new-1 ' || public.t_show('new-1'))"

FAILS="$(q -c "select count(*) from public.t_result where not ok")"
TOTAL="$(q -c "select count(*) from public.t_result")"
echo "checks=$TOTAL failed=$FAILS"
[ "$FAILS" = "0" ] && echo TOTALS_RISKS_ALL_OK || { echo TOTALS_RISKS_FAILED; exit 1; }
