#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
IBUL_PUBLIC_DOWNLOADS_BASE="https://github.com/barankanan/ibull/releases/download/ibul-public-downloads"

load_dotenv_fill_missing() {
  local env_file="$1"
  [[ -f "$env_file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%$'\r'}"
    [[ -z "${line//[[:space:]]}" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local val="${BASH_REMATCH[2]}"
      if [[ -z "${!key:-}" ]]; then
        export "$key=$val"
      fi
    fi
  done < "$env_file"
}

normalize_public_download_urls() {
  if [[ -z "${IBUL_CUSTOMER_ANDROID_APK_DOWNLOAD_URL:-}" \
    || "${IBUL_CUSTOMER_ANDROID_APK_DOWNLOAD_URL}" == *"/releases/latest/download/"* \
    || "${IBUL_CUSTOMER_ANDROID_APK_DOWNLOAD_URL}" == *"v1.0.2"* ]]; then
    export IBUL_CUSTOMER_ANDROID_APK_DOWNLOAD_URL="$IBUL_PUBLIC_DOWNLOADS_BASE/IbulCustomer.apk"
  fi
  if [[ -z "${IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL:-}" \
    || "${IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL}" == *"/releases/latest/download/"* \
    || "${IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL}" == *"v1.0.2"* ]]; then
    export IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL="$IBUL_PUBLIC_DOWNLOADS_BASE/IbulSellerSetup.exe"
  fi
  if [[ -z "${IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL:-}" \
    || "${IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL}" == *"/releases/latest/download/"* \
    || "${IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL}" == *"v1.0.2"* ]]; then
    export IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL="$IBUL_PUBLIC_DOWNLOADS_BASE/IbulSellerDesktop.dmg"
  fi
}

load_dotenv_fill_missing "$PROJECT_DIR/.env"
normalize_public_download_urls

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
  IBUL_FIREBASE_WEB_MEASUREMENT_ID \
  IBUL_CUSTOMER_ANDROID_APK_DOWNLOAD_URL \
  IBUL_CUSTOMER_ANDROID_PLAY_STORE_URL \
  IBUL_CUSTOMER_IOS_APP_STORE_URL \
  IBUL_CUSTOMER_IOS_TESTFLIGHT_URL \
  IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL \
  IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL
do
  append_define "$define_name"
done

if [[ ${#MISSING_DEFINES[@]} -gt 0 ]]; then
  echo "Eksik env/değer: ${MISSING_DEFINES[*]}"
  echo "Repo kökünde .env oluşturun veya komut öncesi değişkenleri export edin."
  exit 1
fi

cd "$PROJECT_DIR/ibul_app"

# runtime_config.dart, generated_runtime_config.g.dart'ı import eder.
# Dosya yoksa (taze clone) committed stub'dan oluştur ki build kırılmasın.
# Web'de asıl kaynak dart-define'lardır; generated yalnızca fallback'tir.
GENERATED_CONFIG="lib/core/config/generated_runtime_config.g.dart"
GENERATED_STUB="lib/core/config/generated_runtime_config_stub.dart"
if [[ ! -f "$GENERATED_CONFIG" ]]; then
  cp "$GENERATED_STUB" "$GENERATED_CONFIG"
  echo "✓ generated_runtime_config.g.dart stub'dan oluşturuldu (boş değerler)"
fi

echo "Customer web build başlıyor (target=lib/main_customer.dart)..."
echo "✓ IBUL_SUPABASE_URL = ${IBUL_SUPABASE_URL:0:40}..."
echo "✓ IBUL_SUPABASE_ANON_KEY = ${IBUL_SUPABASE_ANON_KEY:0:20}..."

if [[ -n "${IBUL_CUSTOMER_ANDROID_APK_DOWNLOAD_URL:-}" ]]; then
  echo "✓ IBUL_CUSTOMER_ANDROID_APK_DOWNLOAD_URL = ${IBUL_CUSTOMER_ANDROID_APK_DOWNLOAD_URL}"
else
  echo "✓ IBUL_CUSTOMER_ANDROID_APK_DOWNLOAD_URL = empty"
fi

if [[ -n "${IBUL_CUSTOMER_ANDROID_PLAY_STORE_URL:-}" ]]; then
  echo "✓ IBUL_CUSTOMER_ANDROID_PLAY_STORE_URL = ${IBUL_CUSTOMER_ANDROID_PLAY_STORE_URL}"
else
  echo "✓ IBUL_CUSTOMER_ANDROID_PLAY_STORE_URL = empty"
fi

if [[ -n "${IBUL_CUSTOMER_IOS_APP_STORE_URL:-}" ]]; then
  echo "✓ IBUL_CUSTOMER_IOS_APP_STORE_URL = ${IBUL_CUSTOMER_IOS_APP_STORE_URL}"
else
  echo "✓ IBUL_CUSTOMER_IOS_APP_STORE_URL = empty"
fi

if [[ -n "${IBUL_CUSTOMER_IOS_TESTFLIGHT_URL:-}" ]]; then
  echo "✓ IBUL_CUSTOMER_IOS_TESTFLIGHT_URL = ${IBUL_CUSTOMER_IOS_TESTFLIGHT_URL}"
else
  echo "✓ IBUL_CUSTOMER_IOS_TESTFLIGHT_URL = empty"
fi

if [[ -n "${IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL:-}" ]]; then
  echo "✓ IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL = ${IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL}"
else
  echo "✓ IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL = empty (runtime default)"
fi

if [[ -n "${IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL:-}" ]]; then
  echo "✓ IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL = ${IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL}"
else
  echo "✓ IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL = empty (runtime default)"
fi

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
  echo "❌ $MAIN_JS bulunamadı; build başarısız sayılıyor."
  exit 1
fi

# ── Post-build link doğrulaması (main.dart.js + part dosyaları) ──────────────
# Eski/kırık release linki bundle'a sızarsa build burada durur.
echo ""
echo "▶  Bundle link doğrulaması başlıyor..."

JS_BUNDLE_FILES=("$MAIN_JS")
while IFS= read -r part_file; do
  JS_BUNDLE_FILES+=("$part_file")
done < <(find build/web -maxdepth 1 -name 'main.dart.js_*.part.js' -type f)

FORBIDDEN_TOKENS=(
  "v1.0.2-windows-seller"
  "releases/latest/download"
)
for token in "${FORBIDDEN_TOKENS[@]}"; do
  if grep -F -l -- "$token" "${JS_BUNDLE_FILES[@]}" >/dev/null 2>&1; then
    echo "❌ ESKİ LİNK YAKALANDI: '$token' aşağıdaki dosyalarda bulundu:"
    grep -F -l -- "$token" "${JS_BUNDLE_FILES[@]}" || true
    echo "   Build durduruldu. .env ve dart-define değerlerini kontrol edin."
    exit 1
  fi
done
echo "✓ Yasaklı token yok (v1.0.2-windows-seller, releases/latest/download)"

REQUIRED_TOKENS=(
  "ibul-public-downloads"
  "IbulCustomer.apk"
  "IbulSellerDesktop.dmg"
  "IbulSellerSetup.exe"
)
for token in "${REQUIRED_TOKENS[@]}"; do
  if ! grep -F -q -- "$token" "${JS_BUNDLE_FILES[@]}"; then
    echo "❌ Beklenen token bundle'da yok: '$token'"
    echo "   Runtime config fallback'leri veya dart-define'lar eksik olabilir."
    exit 1
  fi
done
echo "✓ Beklenen tokenlar bundle'da: ${REQUIRED_TOKENS[*]}"

# ── Cache kırma stratejisi ───────────────────────────────────────────────────
# --pwa-strategy=none kullanılıyor; yine de service worker dosyası üretilmişse
# eski JS'in cache'ten servis edilmemesi için deploy paketinden çıkarılır.
SW_FILE="build/web/flutter_service_worker.js"
if [[ -f "$SW_FILE" ]]; then
  if grep -q "flutter_service_worker" build/web/flutter_bootstrap.js 2>/dev/null; then
    echo "⚠  flutter_bootstrap.js service worker'a referans veriyor;"
    echo "   dosya siliniyor ve firebase.json no-cache header'ına güvenilecek."
  fi
  rm -f "$SW_FILE"
  echo "✓ flutter_service_worker.js kaldırıldı (pwa-strategy=none, eski cache kırıldı)"
else
  echo "✓ flutter_service_worker.js üretilmedi (pwa-strategy=none)"
fi

# firebase.json cache header kontrolü (index.html / main.dart.js no-cache).
FIREBASE_JSON="$PROJECT_DIR/firebase.json"
if [[ -f "$FIREBASE_JSON" ]]; then
  if grep -q "no-store" "$FIREBASE_JSON" && grep -q "main.dart.js" "$FIREBASE_JSON"; then
    echo "✓ firebase.json: index.html/main.dart.js için no-cache header mevcut"
  else
    echo "⚠  firebase.json içinde main.dart.js/no-store cache header'ı doğrulanamadı."
    echo "   Deploy sonrası eski JS cache riski için hosting header'larını kontrol edin."
  fi
fi

echo ""
echo "✓ Bundle link doğrulaması başarılı."
echo "Customer web build tamamlandı: ibul_app/build/web"
