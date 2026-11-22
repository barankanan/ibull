#!/bin/bash
# Runs the LAN print-evidence sync proof on a throwaway database.
#
# Nothing here touches production or the local Supabase stack: a temporary
# PostgreSQL cluster is created, the isolated test schema and the evidence
# migrations are loaded from this repository, PostgREST is started from a
# local Docker image, and everything is removed at the end.
#
# Needs: PostgreSQL binaries (initdb, pg_ctl, psql), Docker with a PostgREST
# image, Node, Flutter. Deno is optional; without it the Node twins of the
# verifier are used.
#
#   scripts/run_lan_evidence_sync_test.sh
#   IBUL_PG_BIN=/path/to/pg/bin IBUL_POSTGREST_IMAGE=postgrest/postgrest scripts/run_lan_evidence_sync_test.sh
set -euo pipefail
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/ibul_app"
PG_BIN="${IBUL_PG_BIN:-$(dirname "$(command -v initdb)")}"
IMAGE="${IBUL_POSTGREST_IMAGE:-public.ecr.aws/supabase/postgrest:v16.1}"
PG_PORT="${IBUL_PGPORT:-55432}"
REST_PORT="${IBUL_POSTGREST_PORT:-55433}"
# The address under which containers reach this machine (Colima/Lima default).
HOST_FROM_DOCKER="${IBUL_DOCKER_HOST_ADDR:-192.168.5.2}"
NAME="ibul_evidence_postgrest_$$"
WORK="$(mktemp -d /tmp/ibul-ev.XXXXXX)"   # short path: Unix socket limit

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  "$PG_BIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

"$PG_BIN/initdb" -D "$WORK/data" -U ibul --auth=trust -E UTF8 >/dev/null
echo "host all all 0.0.0.0/0 trust" >> "$WORK/data/pg_hba.conf"
"$PG_BIN/pg_ctl" -D "$WORK/data" -l "$WORK/pg.log" \
  -o "-p $PG_PORT -c listen_addresses='*' -k $WORK -c lc_messages=C" -w start >/dev/null
"$PG_BIN/createdb" -h 127.0.0.1 -p "$PG_PORT" -U ibul ibul_iso

sql() { "$PG_BIN/psql" -h 127.0.0.1 -p "$PG_PORT" -U ibul -d ibul_iso -v ON_ERROR_STOP=1 -q "$@"; }
sql -f "$APP/supabase/tests/isolated_lan_sync_print.sql" >/dev/null
sql -f "$APP/supabase/migrations/20261103223000_order_sync_print_evidence.sql" >/dev/null
sql -f "$APP/supabase/migrations/20261119090000_lan_print_evidence_key_registration.sql" >/dev/null

echo "== key registration (SQL) =="
sql -At -f "$APP/supabase/tests/isolated_lan_evidence_key_registration.sql" | tail -1

SECRET="$(python3 -c 'import secrets,base64;print(base64.urlsafe_b64encode(secrets.token_bytes(32)).decode())')"
docker run -d --name "$NAME" -p "127.0.0.1:$REST_PORT:3000" \
  -e PGRST_DB_URI="postgres://ibul@$HOST_FROM_DOCKER:$PG_PORT/ibul_iso" \
  -e PGRST_DB_SCHEMAS=public -e PGRST_DB_ANON_ROLE=anon \
  -e PGRST_JWT_SECRET="$SECRET" "$IMAGE" >/dev/null
for _ in $(seq 1 30); do
  curl -s -o /dev/null -m 2 "http://127.0.0.1:$REST_PORT/" && break
  sleep 1
done

echo "== evidence sync (Flutter) =="
cd "$APP"
IBUL_JWT_SECRET="$SECRET" IBUL_POSTGREST="http://127.0.0.1:$REST_PORT" \
IBUL_PSQL="$PG_BIN/psql" IBUL_PGPORT="$PG_PORT" IBUL_PGUSER=ibul IBUL_PGDB=ibul_iso \
  flutter test test/services/lan_bridge_sync_test.dart
