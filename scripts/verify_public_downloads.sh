#!/usr/bin/env bash
# İbul — Public downloads doğrulama scripti
#
# Kontroller:
#   1. GitHub release asset'leri (ibul-public-downloads) HTTP 200 dönüyor mu?
#   2. Android APK indirilip apksigner ile doğrulanıyor (v2 scheme: true şart).
#   3. Asset dosya boyutları raporlanır.
#   4. Web build (ibul_app/build/web) içinde eski link kalmış mı?
#
# Başarılıysa son satır: PUBLIC DOWNLOADS VERIFIED
#
# Usage:
#   ./scripts/verify_public_downloads.sh
#   IBUL_VERIFY_SKIP_APKSIGNER=1 ./scripts/verify_public_downloads.sh  # apksigner yoksa
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

RELEASE_TAG="ibul-public-downloads"
BASE_URL="https://github.com/barankanan/ibull/releases/download/$RELEASE_TAG"
APK_URL="$BASE_URL/IbulCustomer.apk"
DMG_URL="$BASE_URL/IbulSellerDesktop.dmg"
EXE_URL="$BASE_URL/IbulSellerSetup.exe"
APK_TMP="/tmp/IbulCustomer.apk"
WEB_BUILD_DIR="$PROJECT_DIR/ibul_app/build/web"

FAIL=0

human_size() {
  local bytes="$1"
  if [[ -z "$bytes" || "$bytes" == "0" ]]; then
    echo "bilinmiyor"
  else
    echo "$((bytes / 1048576)) MB ($bytes bayt)"
  fi
}

check_remote() {
  local name="$1"
  local url="$2"
  local http_code content_length
  http_code="$(curl -sIL -o /dev/null -w '%{http_code}' "$url" || echo "000")"
  if [[ "$http_code" != "200" ]]; then
    echo "❌ $name: HTTP $http_code — $url"
    FAIL=1
    return
  fi
  content_length="$(curl -sIL "$url" | tr -d '\r' | grep -i '^content-length:' | tail -1 | awk '{print $2}')"
  echo "✓ $name: HTTP 200, boyut: $(human_size "${content_length:-0}")"
}

echo "════════════════════════════════════════════════════════════"
echo "  İbul Public Downloads Doğrulama"
echo "  Release tag: $RELEASE_TAG"
echo "════════════════════════════════════════════════════════════"

# ── 1. Remote HTTP 200 kontrolleri ───────────────────────────────────────────
echo ""
echo "▶  Remote asset kontrolleri..."
check_remote "IbulCustomer.apk     " "$APK_URL"
check_remote "IbulSellerDesktop.dmg" "$DMG_URL"
check_remote "IbulSellerSetup.exe  " "$EXE_URL"

if [[ "$FAIL" -ne 0 ]]; then
  echo ""
  echo "❌ Remote asset kontrolü başarısız. Upload eksik veya tag yanlış olabilir."
  exit 1
fi

# ── 2. APK indir + apksigner doğrulaması ─────────────────────────────────────
echo ""
echo "▶  Android APK indiriliyor: $APK_TMP"
curl -sL -o "$APK_TMP" "$APK_URL"
APK_SIZE=$(wc -c < "$APK_TMP" | tr -d ' ')
echo "✓ İndirildi: $(human_size "$APK_SIZE")"

if command -v apksigner >/dev/null 2>&1; then
  echo ""
  echo "▶  apksigner verify..."
  VERIFY_OUT="$(apksigner verify --verbose "$APK_TMP" 2>&1)" || {
    echo "$VERIFY_OUT"
    echo "❌ apksigner verify BAŞARISIZ."
    exit 1
  }
  echo "$VERIFY_OUT" | head -8
  if ! echo "$VERIFY_OUT" | grep -q "^Verifies"; then
    echo "❌ apksigner çıktısında 'Verifies' yok."
    exit 1
  fi
  if ! echo "$VERIFY_OUT" | grep -q "Verified using v2 scheme (APK Signature Scheme v2): true"; then
    echo "❌ v2 imza şeması true değil. Release imzalı build yükleyin."
    exit 1
  fi
  echo "✓ apksigner: Verifies + v2 scheme true"
elif [[ "${IBUL_VERIFY_SKIP_APKSIGNER:-0}" == "1" ]]; then
  echo "⚠  apksigner atlandı (IBUL_VERIFY_SKIP_APKSIGNER=1)."
else
  echo "❌ apksigner bulunamadı. Android SDK build-tools kurun"
  echo "   veya bilinçli atlamak için IBUL_VERIFY_SKIP_APKSIGNER=1 kullanın."
  exit 1
fi

# ── 3. Web build eski link taraması ──────────────────────────────────────────
echo ""
if [[ -d "$WEB_BUILD_DIR" ]]; then
  echo "▶  Web build eski link taraması: $WEB_BUILD_DIR"
  FORBIDDEN_TOKENS=(
    "v1.0.2-windows-seller"
    "releases/latest/download"
  )
  for token in "${FORBIDDEN_TOKENS[@]}"; do
    if grep -rF -l -- "$token" "$WEB_BUILD_DIR" --include='*.js' --include='*.html' >/dev/null 2>&1; then
      echo "❌ ESKİ LİNK YAKALANDI: '$token'"
      grep -rF -l -- "$token" "$WEB_BUILD_DIR" --include='*.js' --include='*.html' || true
      FAIL=1
    fi
  done
  if [[ "$FAIL" -ne 0 ]]; then
    echo "❌ Web build eski link içeriyor. ./scripts/build_customer_web_hosting.sh ile yeniden build alın."
    exit 1
  fi
  echo "✓ Web build'de eski link yok"

  MAIN_JS="$WEB_BUILD_DIR/main.dart.js"
  if [[ -f "$MAIN_JS" ]]; then
    for token in "$RELEASE_TAG" "IbulCustomer.apk" "IbulSellerDesktop.dmg" "IbulSellerSetup.exe"; do
      if ! grep -rF -q -- "$token" "$WEB_BUILD_DIR" --include='*.js'; then
        echo "❌ Web build'de beklenen token yok: '$token'"
        exit 1
      fi
    done
    echo "✓ Web build güncel release linklerini içeriyor"
  fi
else
  echo "⚠  Web build bulunamadı ($WEB_BUILD_DIR); web taraması atlandı."
  echo "   Tam doğrulama için önce: ./scripts/build_customer_web_hosting.sh"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "PUBLIC DOWNLOADS VERIFIED"
echo "════════════════════════════════════════════════════════════"
