#!/usr/bin/env bash
# İBUL müşteri uygulaması — macOS.
#
# Satıcı uygulamasından ayrı paket adı, bundle kimliği ve Keychain hesabı
# kullanır. Production satıcı derlemesi scripts/run_seller_desktop.sh ile
# aynı Debug kimliğinde kalır.
#
# Usage:
#   ./scripts/run_customer_macos.sh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

MISSING=()
[[ -z "${IBUL_SUPABASE_URL:-}" ]] && MISSING+=("IBUL_SUPABASE_URL")
[[ -z "${IBUL_SUPABASE_ANON_KEY:-}" ]] && MISSING+=("IBUL_SUPABASE_ANON_KEY")
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Eksik env/değer: ${MISSING[*]}"
  echo "Repo kökünde .env oluşturun veya komut öncesi değişkenleri export edin."
  exit 1
fi

declare -a DART_DEFINES=()
append_define() {
  local name="$1"
  local value="${!name:-}"
  if [[ -n "$value" ]]; then
    DART_DEFINES+=("--dart-define=$name=$value")
  fi
}

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

cd "$PROJECT_DIR"
echo "▶  İBUL müşteri uygulaması başlatılıyor (macOS)..."
flutter run -d macos \
  --flavor customer \
  --target lib/main.dart \
  "${DART_DEFINES[@]}" \
  "$@"
