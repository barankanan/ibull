#!/bin/bash
# Rehearses the 9 -> 12 argument order RPC migration on a THROWAWAY PostgreSQL.
# Never connects to Supabase production. Steps:
#   1. production-state: the live 9-arg impl + wrapper (ROLLBACK snapshot, md5-checked)
#      and the live approve_waiter_order_request call shape
#   2. old-client call matrix BEFORE
#   3. apply 20261103223000 + 20261119090000 in ONE transaction
#   4. same call matrix AFTER (old clients + approve), pre-existing rows unchanged
#   5. rollback (drop 12-arg, restore snapshot), same matrix again
# The isolated schema is smaller than production (no money/dedup triggers):
# it proves signature/ACL/call compatibility, not production trigger behaviour.
set -euo pipefail
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$ROOT/ibul_app/supabase/tests"; M="$ROOT/ibul_app/supabase/migrations"
PG_BIN="${IBUL_PG_BIN:-$(dirname "$(command -v initdb)")}"
PORT="${IBUL_PGPORT:-55441}"
WORK="$(mktemp -d /tmp/ibul-rh.XXXXXX)"
cleanup(){ "$PG_BIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT
"$PG_BIN/initdb" -D "$WORK/data" -U ibul --auth=trust -E UTF8 >/dev/null
"$PG_BIN/pg_ctl" -D "$WORK/data" -l "$WORK/pg.log" -o "-p $PORT -k $WORK -c lc_messages=C" -w start >/dev/null
"$PG_BIN/createdb" -h 127.0.0.1 -p "$PORT" -U ibul rh
q(){ "$PG_BIN/psql" -h 127.0.0.1 -p "$PORT" -U ibul -d rh -v ON_ERROR_STOP=1 -q -At "$@"; }

q -f "$T/isolated_lan_sync_print.sql" >/dev/null
q -f "$ROOT/ibul_app/supabase/manual_patches/20261031_live_restaurant_rpc_ROLLBACK.sql" >/dev/null 2>"$WORK/rb.err" || { cat "$WORK/rb.err"; exit 1; }
q -f "$T/rehearsal_prod_state_stubs.sql" >/dev/null
echo "== production-state fingerprint (live: impl f7dca415… 14301, wrapper 7ddf4b5b… 204)"
q -c "select proname, md5(prosrc), length(prosrc), pg_get_function_identity_arguments(oid) from pg_proc where pronamespace='public'::regnamespace and proname like 'create_table_order_with_print_jobs%' order by 1;"

echo "== BEFORE: old-client calls on the 9-arg functions"
q -v tag=before -f "$T/rehearsal_rpc_calls.sql" | grep -E "CALLS|ORDERS_FOR|JOB_STATUS"
PRE="$(q -c "select md5(string_agg(o::text, '|' order by id::text)) from public.orders o; select md5(string_agg(p::text, '|' order by id::text)) from public.print_jobs p;" | tr '\n' ' ')"
echo "pre-existing rows fingerprint: $PRE"
ROWS_BEFORE="$(q -c "select count(*) from public.orders; select count(*) from public.print_jobs;" | tr '\n' ' ')"

echo "== APPLY the two migrations (each in its own transaction)"
# Each migration file carries its own BEGIN/COMMIT, so they are applied one
# after the other (never wrapped in an outer transaction).
q -f "$M/20261103223000_order_sync_print_evidence.sql" >/dev/null 2>"$WORK/m1.err"
q -f "$M/20261119090000_lan_print_evidence_key_registration.sql" >/dev/null 2>"$WORK/m2.err"
q -c "select pg_get_function_identity_arguments(oid) from pg_proc where pronamespace='public'::regnamespace and proname like 'create_table_order_with_print_jobs%' order by 1;" | sed 's/^/  sig: /'
echo "  nine-arg left: $(q -c "select count(*) from pg_proc where pronamespace='public'::regnamespace and proname like 'create_table_order_with_print_jobs%' and pronargs=9;")"
echo "  anon may execute: $(q -c "select has_function_privilege('anon', p.oid, 'execute') from pg_proc p where p.pronamespace='public'::regnamespace and p.proname='create_table_order_with_print_jobs';")"
echo "  authenticated may execute: $(q -c "select has_function_privilege('authenticated', p.oid, 'execute') from pg_proc p where p.pronamespace='public'::regnamespace and p.proname='create_table_order_with_print_jobs';")"
echo "  old rows unchanged: $(q -c "select (select md5(string_agg(o::text,'|' order by id::text)) from public.orders o where local_order_id like '%before' or local_order_id is null or order_number is not null) is not null;")"
echo "== AFTER: same old-client calls"
q -v tag=after -f "$T/rehearsal_rpc_calls.sql" | grep -E "CALLS|ORDERS_FOR|JOB_STATUS"
echo "  rows before apply: $ROWS_BEFORE | still present: $(q -c "select count(*) from public.orders where local_order_id like '%before'; select count(*) from public.print_jobs;" | tr '\n' ' ')"

echo "== APPLY third migration: lan_staff_authority (new function only, replaces nothing)"
# store_sub_admins, auth.users and auth.uid() come from the production-state stubs
q -f "$M/20261120090000_lan_staff_authority.sql" >/dev/null 2>"$WORK/m3.err" || { cat "$WORK/m3.err"; exit 1; }
echo "  lan_staff_authority present: $(q -c "select count(*) from pg_proc where pronamespace='public'::regnamespace and proname='lan_staff_authority';")"
echo "  anon may execute: $(q -c "select has_function_privilege('anon', 'public.lan_staff_authority(uuid,uuid)', 'execute');")  authenticated may execute: $(q -c "select has_function_privilege('authenticated', 'public.lan_staff_authority(uuid,uuid)', 'execute');")"
echo "  order RPC still callable by the old client after the third migration:"
q -v tag=after3 -f "$T/rehearsal_rpc_calls.sql" | grep -E "CALLS" 
q -c "drop function public.lan_staff_authority(uuid,uuid);" >/dev/null
echo "  third migration rollback: function gone = $(q -c "select count(*)=0 from pg_proc where proname='lan_staff_authority';")"
echo "== ROLLBACK rehearsal"
q -c "begin; drop function if exists public.create_table_order_with_print_jobs(uuid,integer,jsonb,uuid,text,text,text,text,text,text,uuid,uuid); drop function if exists public.create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text,text,uuid,uuid); commit;" >/dev/null
q -f "$ROOT/ibul_app/supabase/manual_patches/20261031_live_restaurant_rpc_ROLLBACK.sql" >/dev/null
q -c "select proname, md5(prosrc), length(prosrc), pronargs from pg_proc where pronamespace='public'::regnamespace and proname like 'create_table_order_with_print_jobs%' order by 1;"
echo "== AFTER ROLLBACK: same calls"
q -v tag=rolledback -f "$T/rehearsal_rpc_calls.sql" | grep -E "CALLS|ORDERS_FOR|JOB_STATUS"
echo REHEARSAL_DONE
