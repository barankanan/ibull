#!/usr/bin/env bash
set -euo pipefail

# CI helper: inject required dart-defines from environment for Flutter web release.
# Fails fast when mandatory secrets are missing.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

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

if [[ ${#MISSING_DEFINES[@]} -gt 0 ]]; then
  echo "CI build blocked — missing required secrets/env: ${MISSING_DEFINES[*]}"
  exit 1
fi

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
  IBUL_FIREBASE_WEB_MEASUREMENT_ID \
  IBUL_FIREBASE_ANDROID_API_KEY \
  IBUL_FIREBASE_ANDROID_APP_ID \
  IBUL_FIREBASE_IOS_API_KEY \
  IBUL_FIREBASE_IOS_APP_ID \
  IBUL_FIREBASE_IOS_BUNDLE_ID \
  IBUL_FIREBASE_MACOS_API_KEY \
  IBUL_FIREBASE_MACOS_APP_ID \
  IBUL_FIREBASE_MACOS_BUNDLE_ID
do
  append_define "$define_name"
done

cd "$PROJECT_DIR/ibul_app"
flutter build web --release \
  --target lib/main.dart \
  --pwa-strategy=none \
  --no-web-resources-cdn \
  --no-wasm-dry-run \
  "${DART_DEFINES[@]}"

WEB_DIR="$PROJECT_DIR/ibul_app/build/web"
MAIN_JS="$WEB_DIR/main.dart.js"
if [[ -f "$MAIN_JS" ]]; then
  HASH="$(shasum -a 256 "$MAIN_JS" | awk '{print substr($1,1,16)}')"
  HASHED="app.${HASH}.js"
  mv "$MAIN_JS" "$WEB_DIR/$HASHED"
  python3 "$SCRIPT_DIR/fingerprint_web_js.py" "$WEB_DIR" "$HASHED" "$HASH"
fi

python3 "$SCRIPT_DIR/prerender_blog.py" "$WEB_DIR"
