#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

if [[ -f "$PROJECT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$PROJECT_DIR/.env"
  set +a
fi

normalize_firebase_aliases() {
  if [[ -z "${IBUL_FIREBASE_WEB_API_KEY:-}" && -n "${IBUL_FIREBASE_API_KEY:-}" ]]; then
    export IBUL_FIREBASE_WEB_API_KEY="$IBUL_FIREBASE_API_KEY"
  fi
  if [[ -z "${IBUL_FIREBASE_WEB_APP_ID:-}" && -n "${IBUL_FIREBASE_APP_ID:-}" ]]; then
    export IBUL_FIREBASE_WEB_APP_ID="$IBUL_FIREBASE_APP_ID"
  fi
  if [[ -z "${IBUL_FIREBASE_WEB_MEASUREMENT_ID:-}" && -n "${IBUL_FIREBASE_MEASUREMENT_ID:-}" ]]; then
    export IBUL_FIREBASE_WEB_MEASUREMENT_ID="$IBUL_FIREBASE_MEASUREMENT_ID"
  fi
  if [[ -z "${IBUL_FIREBASE_WEB_MEASUREMENT_ID:-}" && -n "${IBUL_FIREBASE_EB_MEASUREMENT_ID:-}" ]]; then
    export IBUL_FIREBASE_WEB_MEASUREMENT_ID="$IBUL_FIREBASE_EB_MEASUREMENT_ID"
  fi
}

normalize_firebase_aliases

append_define() {
  local name="$1"
  local value="${!name:-}"
  if [[ -n "$value" ]]; then
    DART_DEFINES+=("--dart-define=$name=$value")
  fi
}

require_define() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    MISSING_DEFINES+=("$name")
  fi
}

declare -a DART_DEFINES=()
declare -a MISSING_DEFINES=()

require_define "IBUL_SUPABASE_URL"
require_define "IBUL_SUPABASE_ANON_KEY"

for define_name in \
  IBUL_SUPABASE_URL \
  IBUL_SUPABASE_ANON_KEY \
  IBUL_GOOGLE_CLIENT_ID \
  IBUL_GOOGLE_SERVER_CLIENT_ID \
  IBUL_FIREBASE_PROJECT_ID \
  IBUL_FIREBASE_MESSAGING_SENDER_ID \
  IBUL_FIREBASE_AUTH_DOMAIN \
  IBUL_FIREBASE_STORAGE_BUCKET \
  IBUL_FIREBASE_WEB_API_KEY \
  IBUL_FIREBASE_WEB_APP_ID \
  IBUL_FIREBASE_WEB_MEASUREMENT_ID
do
  append_define "$define_name"
done

if [[ ${#MISSING_DEFINES[@]} -gt 0 ]]; then
  echo "Eksik env/değer: ${MISSING_DEFINES[*]}"
  echo "Repo kökünde .env oluşturun veya komut öncesi değişkenleri export edin."
  exit 1
fi

cd "$PROJECT_DIR/ibul_app"

echo "Web build başlıyor (ibul_app, target=lib/main.dart)..."
echo "✓ IBUL_SUPABASE_URL = ${IBUL_SUPABASE_URL:0:40}..."
echo "✓ IBUL_SUPABASE_ANON_KEY = ${IBUL_SUPABASE_ANON_KEY:0:20}..."

flutter build web --release \
  --target lib/main.dart \
  --pwa-strategy=none \
  --no-web-resources-cdn \
  --no-wasm-dry-run \
  "${DART_DEFINES[@]}"

WEB_DIR="$PROJECT_DIR/ibul_app/build/web"
SW_FILE="$WEB_DIR/flutter_service_worker.js"
if [[ -f "$SW_FILE" ]] && [[ ! -s "$SW_FILE" ]]; then
  rm -f "$SW_FILE"
  echo "✓ Removed empty flutter_service_worker.js (pwa-strategy=none)"
fi

MAIN_JS="$WEB_DIR/main.dart.js"
BOOTSTRAP_JS="$WEB_DIR/flutter_bootstrap.js"
INDEX_HTML="$WEB_DIR/index.html"
if [[ -f "$MAIN_JS" && -f "$BOOTSTRAP_JS" && -f "$INDEX_HTML" ]]; then
  HASH="$(shasum -a 256 "$MAIN_JS" | awk '{print substr($1,1,16)}')"
  HASHED="app.${HASH}.js"
  mv "$MAIN_JS" "$WEB_DIR/$HASHED"
  python3 - "$WEB_DIR" "$HASHED" <<'PY'
import pathlib, sys
web, hashed = pathlib.Path(sys.argv[1]), sys.argv[2]
boot = web / "flutter_bootstrap.js"
html = web / "index.html"
boot.write_text(
    boot.read_text().replace('"mainJsPath":"main.dart.js"', f'"mainJsPath":"{hashed}"'),
    encoding="utf-8",
)
html.write_text(
    html.read_text().replace('href="main.dart.js"', f'href="{hashed}"'),
    encoding="utf-8",
)
PY
  echo "✓ Fingerprinted JS: $HASHED (immutable cache)"
fi

python3 "$SCRIPT_DIR/prerender_blog.py" "$WEB_DIR"
