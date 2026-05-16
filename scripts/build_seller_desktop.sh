#!/usr/bin/env bash
# İbul Satıcı — macOS desktop release builder
#
# Usage:
#   ./scripts/build_seller_desktop.sh
#
# Output: build/macos/Build/Products/Release/IbulSellerDesktop.app
#
# Secrets are read from a .env file in the project root.
# First-time setup:
#   cp .env.example .env   <-- then fill in real values
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_DIR/.env"

# ── 1. Load .env ─────────────────────────────────────────────────────────────
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  echo "✓ .env yüklendi: $ENV_FILE"
else
  echo "⚠  .env dosyası bulunamadı: $ENV_FILE"
  echo "   Export edilmiş ortam değişkenleri varsa onlarla devam edilecek."
fi

# ── 1b. Backward-compatible env aliases ──────────────────────────────────────
if [[ -z "${IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL:-}" && -n "${IBUL_WINDOWS_INSTALLER_DOWNLOAD_URL:-}" ]]; then
  export IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL="$IBUL_WINDOWS_INSTALLER_DOWNLOAD_URL"
fi

if [[ -z "${IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL:-}" && -n "${IBUL_MACOS_INSTALLER_DOWNLOAD_URL:-}" ]]; then
  export IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL="$IBUL_MACOS_INSTALLER_DOWNLOAD_URL"
fi

# ── 2. Validate required keys ─────────────────────────────────────────────────
MISSING=()
[[ -z "${IBUL_SUPABASE_URL:-}" ]]      && MISSING+=("IBUL_SUPABASE_URL")
[[ -z "${IBUL_SUPABASE_ANON_KEY:-}" ]] && MISSING+=("IBUL_SUPABASE_ANON_KEY")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo ""
  echo "❌  Eksik zorunlu ortam değişkeni:"
  for key in "${MISSING[@]}"; do
    echo "    - $key"
  done
  echo ""
  echo "   .env dosyasını oluşturup bu değerleri girin veya shell ortamına export edin."
  exit 1
fi

echo "✓ IBUL_SUPABASE_URL  = ${IBUL_SUPABASE_URL:0:40}..."
echo "✓ IBUL_SUPABASE_ANON_KEY = ${IBUL_SUPABASE_ANON_KEY:0:20}..."

# ── 3. Build dart-define array ────────────────────────────────────────────────
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
  IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL \
  IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL
do
  append_define "$define_name"
done

# ── 4. Build ──────────────────────────────────────────────────────────────────
cd "$PROJECT_DIR"
echo ""
echo "▶  İbul Satıcı release build başlatılıyor..."
echo ""

flutter build macos \
  --target lib/main_seller.dart \
  --release \
  "${DART_DEFINES[@]}"

APP_PATH="$PROJECT_DIR/build/macos/Build/Products/Release/IbulSellerDesktop.app"

echo ""
if [[ -d "$APP_PATH" ]]; then
  echo "✅  Build başarılı!"
  echo "    Konum: $APP_PATH"
  echo ""
  echo "    Uygulamayı açmak için:"
  echo "      open \"$APP_PATH\""
else
  echo "⚠  Build tamamlandı ancak .app paketi beklenen konumda bulunamadı:"
  echo "   $APP_PATH"
  echo "   build/ dizinini kontrol edin."
  exit 1
fi
