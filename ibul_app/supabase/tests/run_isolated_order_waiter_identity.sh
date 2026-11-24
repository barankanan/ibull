#!/bin/bash
# Proves drafts/20261124_order_waiter_identity_DRAFT.sql on a THROWAWAY PostgreSQL.
# Never connects to Supabase. Runs the PRODUCTION bodies (md5-checked) of the order RPC
# and `_impl`; the same 14 sends run before and after the draft. Then the history
# snapshot, an old order, the rollback and a replay are checked.
set -euo pipefail
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
HERE="$(cd "$(dirname "$0")" && pwd)"; SUP="$(cd "$HERE/.." && pwd)"
T="$HERE"; M="$SUP/migrations"; D="$SUP/drafts"; P="$SUP/manual_patches"
PG_BIN="${IBUL_PG_BIN:-$(dirname "$(command -v initdb)")}"
PORT="${IBUL_PGPORT:-55450}"
WORK="$(mktemp -d /tmp/ibul-waiter.XXXXXX)"
cleanup(){ "$PG_BIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT
"$PG_BIN/initdb" -D "$WORK/data" -U ibul --auth=trust -E UTF8 >/dev/null
"$PG_BIN/pg_ctl" -D "$WORK/data" -l "$WORK/pg.log" -o "-p $PORT -k $WORK -c lc_messages=C" -w start >/dev/null
"$PG_BIN/createdb" -h 127.0.0.1 -p "$PORT" -U ibul wi
q(){ "$PG_BIN/psql" -h 127.0.0.1 -p "$PORT" -U ibul -d wi -v ON_ERROR_STOP=1 -q -At "$@"; }
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
q -f "$D/20261124_table_order_totals_DRAFT.sql" >/dev/null   # production already carries the totals wrapper (v2)

IMPL="$(q -c "select md5(prosrc) from pg_proc where pronamespace='public'::regnamespace and proname='create_table_order_with_print_jobs_impl'")"
WRAP="$(q -c "select md5(prosrc) from pg_proc where pronamespace='public'::regnamespace and proname='create_table_order_with_print_jobs'")"
echo "production _impl identical (b521ede6…): $([ "$IMPL" = "b521ede60c1f275836a002aed75fd1cd" ] && echo true || echo FALSE)"
echo "production wrapper identical (v2 b328f59d…): $([ "$WRAP" = "b328f59d4ab26730ea26f4c034d64a22" ] && echo true || echo FALSE)"
[ "$IMPL" = "b521ede60c1f275836a002aed75fd1cd" ] && [ "$WRAP" = "b328f59d4ab26730ea26f4c034d64a22" ] || exit 1

q -f "$T/isolated_order_waiter_identity_fixture.sql" >/dev/null
q -v phase=before -f "$T/isolated_order_waiter_identity.sql" >/dev/null
OLD_FP="$(q -c "select md5(string_agg(o.id::text||coalesce(o.waiter_id::text,'-'),'|' order by o.id)) from public.orders o where o.local_order_id like 'wi-before-%'")"
q -f "$D/20261124_order_waiter_identity_DRAFT.sql" >/dev/null
echo "_impl after draft: $(q -c "select length(prosrc), prosrc like '%-- p9: garson kimliği%' from pg_proc where pronamespace='public'::regnamespace and proname='create_table_order_with_print_jobs_impl'")"
q -f "$D/20261124_order_waiter_identity_DRAFT.sql" >/dev/null   # second apply is a no-op
q -v phase=after -f "$T/isolated_order_waiter_identity.sql" >/dev/null

OWNER=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb; STAFF=cccccccc-cccc-cccc-cccc-cccccccccccc
echo "---- orders.waiter_id by sender (before draft | after draft)"
q -c "select rpad(b.k, 20) || ' ' || rpad(replace(replace(replace(b.v,'$OWNER','OWNER'),'$STAFF','STAFF'),'abababab-abab-abab-abab-abababababab','CUSTOMER'), 38) || ' | ' || replace(replace(replace(a.v,'$OWNER','OWNER'),'$STAFF','STAFF'),'abababab-abab-abab-abab-abababababab','CUSTOMER') from public.t_wi b join public.t_wi a on a.k=b.k and a.phase='after' where b.phase='before' order by b.k"
chk(){ q -c "select case when ($2) then 'OK   ' else 'FAIL ' end || '$1'"; }
v(){ q -c "select v from public.t_wi where phase='$1' and k='$2'"; }
FAILS=0; run(){ local r; r="$(chk "$1" "$2")"; echo "$r"; case "$r" in FAIL*) FAILS=$((FAILS+1));; esac; }
run "before_draft_any_user_could_be_named (customer)"        "'$(v before customer)' = 'abababab-abab-abab-abab-abababababab'"
run "before_draft_other_restaurant_staff_could_be_named"       "'$(v before other_rest)' = 'ffffffff-ffff-ffff-ffff-ffffffffffff'"
run "before_draft_unknown_id_gave_null_waiter"                 "'$(v before not_a_user)' = 'null'"
run "after_active_staff_with_manageOrders_is_the_waiter"       "'$(v after efe_staff)' = '$STAFF'"
run "after_empty_waiter_is_the_caller"                         "'$(v after empty)' = '$OWNER'"
run "after_caller_itself_is_the_waiter"                        "'$(v after self)' = '$OWNER'"
run "after_inactive_staff_falls_back_to_caller_not_refused"    "'$(v after inactive)' = '$OWNER'"
run "after_other_restaurant_staff_falls_back_to_caller"        "'$(v after other_rest)' = '$OWNER'"
run "after_other_branch_staff_falls_back_to_caller"            "'$(v after other_branch)' = '$OWNER'"
run "after_staff_without_manageOrders_falls_back_to_caller"    "'$(v after noperm)' = '$OWNER'"
run "after_customer_falls_back_to_caller"                      "'$(v after customer)' = '$OWNER'"
run "after_unknown_id_is_the_caller_not_null"                  "'$(v after not_a_user)' = '$OWNER'"
run "after_staff_sending_for_self_unchanged"                   "'$(v after staff_self)' = '$STAFF' and '$(v before staff_self)' = '$STAFF'"
run "after_staff_naming_someone_else_still_refused_as_before"  "'$(v after staff_names_other)' = '$(v before staff_names_other)' and '$(v after staff_names_other)' like 'ERR:%'"
run "after_verifier_path_staff_is_kept"                        "'$(v after verifier_staff)' = '$STAFF'"
run "after_verifier_path_customer_is_not_kept"                 "'$(v after verifier_customer)' = '$OWNER'"
run "no_order_refused_that_was_accepted_before"                "(select count(*) from public.t_wi b join public.t_wi a on a.k=b.k and a.phase='after' where b.phase='before' and b.v not like 'ERR:%' and a.v like 'ERR:%') = 0"
run "one_order_per_send_and_resend_adds_none"                  "(select count(*) from public.orders where local_order_id like 'wi-after-efe_staff%') = 1 and (select count(*) from public.orders where local_order_id like 'wi-after-%') = 12"
run "totals_still_written_360"                                  "(select count(*) from public.orders where local_order_id like 'wi-after-%' and total_amount=360 and subtotal_amount=360) = 12"
run "orders_before_the_draft_were_not_rewritten"               "(select md5(string_agg(o.id::text||coalesce(o.waiter_id::text,'-'),'|' order by o.id)) from public.orders o where o.local_order_id like 'wi-before-%') = '$OLD_FP'"
# History keeps the verified staff: close table 1 as the owner and read the snapshot.
q -c "select set_config('ibul.test_uid','$OWNER',false); select public.close_table_with_history('$OWNER'::uuid, 1, 'cash', null, '$OWNER'::uuid, 'Sahip', 'sess-wi')" >/dev/null
run "history_snapshot_keeps_the_staff_waiter"                  "(select count(*) from public.table_order_history h join public.orders o on o.id=h.original_order_id where o.local_order_id='wi-after-efe_staff' and h.archived_orders->0->>'waiter_id' = '$STAFF') = 1"
# Rollback restores production's body, leaves written waiter ids alone.
q -f "$D/20261124_order_waiter_identity_ROLLBACK_DRAFT.sql" >/dev/null
run "rollback_restores_production_impl_md5"                    "(select md5(prosrc) from pg_proc where pronamespace='public'::regnamespace and proname='create_table_order_with_print_jobs_impl') = 'b521ede60c1f275836a002aed75fd1cd'"
run "rollback_keeps_written_waiter_ids"                        "(select waiter_id::text from public.orders where local_order_id='wi-after-efe_staff') = '$STAFF'"
echo "failed=$FAILS"
[ "$FAILS" = "0" ] && echo WAITER_IDENTITY_ALL_OK || { echo WAITER_IDENTITY_FAILED; exit 1; }
