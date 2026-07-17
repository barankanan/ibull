#!/usr/bin/env bash
# İbul Customer — iOS release builder
#
# Usage:
#   ./scripts/build_customer_ios_release.sh
#
# IPA output: build/ios/ipa/*.ipa
#
# Prerequisites:
#   - macOS with Xcode installed
#   - Valid Apple Developer account and signing certificate
#   - Provisioning profile configured in Xcode
#   - CocoaPods installed (gem install cocoapods)
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
  IBUL_FIREBASE_PROJECT_ID \
  IBUL_FIREBASE_MESSAGING_SENDER_ID \
  IBUL_FIREBASE_AUTH_DOMAIN \
  IBUL_FIREBASE_STORAGE_BUCKET \
  IBUL_FIREBASE_IOS_API_KEY \
  IBUL_FIREBASE_IOS_APP_ID \
  IBUL_FIREBASE_IOS_BUNDLE_ID
do
  append_define "$define_name"
done

# ── 4. Pre-build checks ──────────────────────────────────────────────────────
cd "$PROJECT_DIR/ibul_app"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "❌  iOS build yalnızca macOS üzerinde çalışır."
  exit 1
fi

if ! command -v xcodebuild &> /dev/null; then
  echo "❌  Xcode bulunamadı. App Store'dan Xcode yükleyin."
  exit 1
fi

GOOGLE_SERVICE_PLIST="$PROJECT_DIR/ios/Runner/GoogleService-Info.plist"
if [[ ! -f "$GOOGLE_SERVICE_PLIST" ]]; then
  echo ""
  echo "⚠  GoogleService-Info.plist bulunamadı: $GOOGLE_SERVICE_PLIST"
  echo "   Firebase Console'dan indirip ios/Runner/ altına koyun."
  echo ""
fi

# ── 5. Build IPA ─────────────────────────────────────────────────────────────
echo ""
echo "▶  İbul Customer iOS IPA build başlatılıyor..."
echo ""
echo "   NOT: iOS build için geçerli Apple Developer sertifikası ve"
echo "   provisioning profile gereklidir. Xcode'da Signing & Capabilities"
echo "   ayarlarını kontrol edin."
echo ""

flutter build ipa \
  --release \
  --target lib/main_customer.dart \
  "${DART_DEFINES[@]}"

IPA_DIR="$PROJECT_DIR/build/ios/ipa"

echo ""
if [[ -d "$IPA_DIR" ]] && ls "$IPA_DIR"/*.ipa 1>/dev/null 2>&1; then
  IPA_FILE=$(ls "$IPA_DIR"/*.ipa | head -n 1)
  IPA_SIZE=$(wc -c < "$IPA_FILE" | tr -d ' ')
  echo "✅  IPA build başarılı!"
  echo "    Konum: $IPA_FILE"
  echo "    Boyut: $((IPA_SIZE / 1048576)) MB"
else
  echo "⚠  IPA build tamamlandı ancak .ipa dosyası beklenen konumda bulunamadı:"
  echo "   $IPA_DIR"
  echo ""
  echo "   Olası nedenler:"
  echo "   - Xcode signing ayarları eksik"
  echo "   - Provisioning profile eşleşmiyor"
  echo "   - Bundle ID Apple Developer hesabında tanımlı değil"
  exit 1
fi

# ── 6. Summary ───────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  iOS Build tamamlandı"
echo "════════════════════════════════════════════════════════════"
echo "  IPA: $IPA_FILE"
echo ""
echo "  TestFlight yükleme adımları:"
echo "    1. Transporter uygulamasını App Store'dan indirin"
echo "    2. Transporter'ı açın ve IPA dosyasını sürükleyin:"
echo "       $IPA_FILE"
echo "    3. 'Deliver' butonuna tıklayın"
echo ""
echo "  Alternatif — Xcode ile yükleme:"
echo "    1. Xcode > Window > Organizer"
echo "    2. Archives sekmesinden ilgili archive'ı seçin"
echo "    3. 'Distribute App' > App Store Connect"
echo ""
echo "  Alternatif — CLI ile yükleme:"
echo "    xcrun altool --upload-app -f \"$IPA_FILE\" \\"
echo "      -t ios -u YOUR_APPLE_ID -p YOUR_APP_SPECIFIC_PASSWORD"
echo ""
echo "  ÖNEMLİ: iOS için APK değil IPA gerekir."
echo "  Android APK/AAB için: ./scripts/build_customer_android_release.sh"
echo ""
