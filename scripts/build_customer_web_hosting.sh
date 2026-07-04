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

echo "Customer web build başlıyor (target=lib/main_customer.dart)..."
echo "✓ IBUL_SUPABASE_URL = ${IBUL_SUPABASE_URL:0:40}..."
echo "✓ IBUL_SUPABASE_ANON_KEY = ${IBUL_SUPABASE_ANON_KEY:0:20}..."

flutter build web --release \
  --target lib/main_customer.dart \
  --pwa-strategy=none \
  --no-web-resources-cdn \
  --no-wasm-dry-run \
  "${DART_DEFINES[@]}"

MAIN_JS="build/web/main.dart.js"
if [[ -f "$MAIN_JS" ]]; then
  echo "[WebPerf] main js size hint: $(du -h "$MAIN_JS" | awk '{print $1}')"
else
  echo "Uyarı: $MAIN_JS bulunamadı"
fi

echo "Customer web build tamamlandı: ibul_app/build/web"
