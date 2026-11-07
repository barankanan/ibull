#!/bin/sh
# Isolated check for a wrong-table correction.
# Does not connect to production and does not print.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)"
MIG="$ROOT/ibul_app/supabase/migrations"
TEST="$ROOT/ibul_app/supabase/tests"
PSQL="sudo -u postgres psql -v ON_ERROR_STOP=1"

reset_db() {
  db="$1"
  $PSQL -d postgres -c "drop database if exists $db;"
  $PSQL -d postgres -c "create database $db;"
  $PSQL -d "$db" -f "$TEST/wrong_table_move_prelude.sql"
  $PSQL -d "$db" -f "$MIG/20261106_transfer_table_orders_v2.sql"
}

reset_db ibul_wrong_table_before
$PSQL -d ibul_wrong_table_before -f "$TEST/wrong_table_move_bug.sql"

reset_db ibul_wrong_table_after
$PSQL -d ibul_wrong_table_after -f "$MIG/20261107_follow_orders_on_table_move.sql"
$PSQL -d ibul_wrong_table_after -f "$TEST/wrong_table_move_assertions.sql"

echo "WRONG_TABLE_MOVE_OK"
