#!/usr/bin/env bash
# İbul Customer — Android release builder
#
# Usage:
#   ./scripts/build_customer_android_release.sh          # arm64 APK only
#   ./scripts/build_customer_android_release.sh --aab    # APK + AAB (Play Store)
#
# Varsayılan çıktı arm64-v8a split APK'dır (universal ~118 MB APK yerine).
# Universal fallback YOKTUR: app-arm64-v8a-release.apk üretilmezse script
# hata ile durur; yanlışlıkla büyük universal APK stage edilemez.
#
# APK output:  ibul_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# Staged:      release_artifacts/android/IbulCustomer.apk
# AAB output:  ibul_app/build/app/outputs/bundle/release/app-release.aab
#
# Secrets are read from a .env file in the project root.
# First-time setup:
#   cp .env.example .env   <-- then fill in real values
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
IBUL_APP_DIR="$PROJECT_DIR/ibul_app"
ENV_FILE="$PROJECT_DIR/.env"
BUILD_AAB=false
ARTIFACTS_APK="$PROJECT_DIR/release_artifacts/android/IbulCustomer.apk"
CHECKSUMS_DIR="$PROJECT_DIR/release_artifacts/checksums"

for arg in "$@"; do
  case "$arg" in
    --aab) BUILD_AAB=true ;;
  esac
done

# APK içindeki AOT snapshot'ta (libapp.so) Supabase host'unu arar.
# BEST-EFFORT kontroldür, varsayılan olarak FATAL DEĞİLDİR:
# String.fromEnvironment değerleri Flutter AOT release'te her zaman düz metin
# olarak görünmeyebilir (false-negative). Zorunlu doğrulama, build öncesi
# env non-empty kontrolü + 8 dart-define'ın koşulsuz build komutuna
# geçirilmesiyle yapılır.
#
# Strict mod: IBUL_ANDROID_STRICT_AOT_CONFIG_GREP=1 ise bulunamazsa hata verir.
#
# Not: `grep -q` bilinçli KULLANILMIYOR — set -o pipefail altında grep -q ilk
# eşleşmede çıkınca unzip SIGPIPE (141) alır ve pipeline eşleşme VARKEN bile
# başarısız görünür (false-negative kaynağı). `grep -c` tüm stream'i okur.
verify_supabase_config_embedded() {
  local apk="$1"
  local strict="${IBUL_ANDROID_STRICT_AOT_CONFIG_GREP:-0}"
  local supabase_host
  supabase_host="$(echo "$IBUL_SUPABASE_URL" | sed -E 's#^https?://##; s#/.*$##')"
  if [[ -z "$supabase_host" ]]; then
    echo "⚠  Supabase host çözülemedi; gömülü config kontrolü atlandı."
    return 0
  fi
  echo ""
  echo "▶  Gömülü Supabase config kontrolü (best-effort, host: $supabase_host)..."
  local matches=0
  if command -v strings >/dev/null 2>&1; then
    matches="$(unzip -p "$apk" 'lib/*/libapp.so' 2>/dev/null | strings 2>/dev/null | grep -c -- "$supabase_host" || true)"
  fi
  if [[ "${matches:-0}" -eq 0 ]]; then
    matches="$(unzip -p "$apk" 'lib/*/libapp.so' 2>/dev/null | grep -ac -- "$supabase_host" || true)"
  fi
  if [[ "${matches:-0}" -gt 0 ]]; then
    echo "✓ Supabase host AOT snapshot içinde düz metin olarak görüldü"
  else
    echo "⚠  Supabase host AOT snapshot içinde düz metin görünmedi; bu Flutter"
    echo "   AOT release için normal olabilir. Zorunlu doğrulama env non-empty"
    echo "   + dart-define build komutu üzerinden yapıldı."
    if [[ "$strict" == "1" ]]; then
      echo "❌  IBUL_ANDROID_STRICT_AOT_CONFIG_GREP=1: strict mod aktif, build durduruldu."
      exit 1
    fi
  fi
  return 0
}

# apksigner'ı sırasıyla arar:
#   1. PATH (command -v apksigner)
#   2. $ANDROID_HOME/build-tools/<en güncel sürüm>/apksigner
#   3. $ANDROID_SDK_ROOT/build-tools/<en güncel sürüm>/apksigner
#   4. $HOME/Library/Android/sdk/build-tools/<en güncel sürüm>/apksigner (macOS)
# Bulursa tam yolu stdout'a yazar ve 0 döner; bulamazsa 1 döner.
resolve_apksigner() {
  if command -v apksigner >/dev/null 2>&1; then
    command -v apksigner
    return 0
  fi
  local sdk_roots=()
  [[ -n "${ANDROID_HOME:-}" ]] && sdk_roots+=("$ANDROID_HOME")
  [[ -n "${ANDROID_SDK_ROOT:-}" ]] && sdk_roots+=("$ANDROID_SDK_ROOT")
  sdk_roots+=("$HOME/Library/Android/sdk")
  local root ver
  for root in "${sdk_roots[@]}"; do
    [[ -d "$root/build-tools" ]] || continue
    while IFS= read -r ver; do
      if [[ -x "$root/build-tools/$ver/apksigner" ]]; then
        echo "$root/build-tools/$ver/apksigner"
        return 0
      fi
    done < <(ls -1 "$root/build-tools" 2>/dev/null | sort -rV)
  done
  return 1
}

verify_apk() {
  local apk="$1"
  echo ""
  echo "▶  APK geçerlilik kontrolü: $apk"
  file "$apk"
  unzip -t "$apk" >/dev/null && echo "✓ ZIP bütünlüğü doğrulandı"
  local apksigner_bin
  if apksigner_bin="$(resolve_apksigner)"; then
    echo "✓ apksigner: $apksigner_bin"
    local verify_out
    verify_out="$("$apksigner_bin" verify --verbose "$apk" 2>&1)" || {
      echo "$verify_out"
      echo "❌ apksigner verify BAŞARISIZ."
      exit 1
    }
    echo "$verify_out" | head -10
    if ! echo "$verify_out" | grep -q "^Verifies"; then
      echo "❌ apksigner çıktısında 'Verifies' bulunamadı."
      exit 1
    fi
    if ! echo "$verify_out" | grep -Eq "Verified using v2 scheme.*: true"; then
      echo "❌ v2 imza şeması doğrulanamadı (v2 scheme ... true bekleniyor)."
      echo "   key.properties / signingConfig release ayarlarını kontrol edin."
      exit 1
    fi
    echo "✓ apksigner: Verifies + v2 scheme true"
  else
    echo "⚠  apksigner bulunamadı; imza doğrulaması atlandı."
    echo "   Arandı: PATH, \$ANDROID_HOME/build-tools, \$ANDROID_SDK_ROOT/build-tools,"
    echo "           \$HOME/Library/Android/sdk/build-tools"
  fi
}

stage_apk_artifact() {
  local source_apk="$1"
  mkdir -p "$(dirname "$ARTIFACTS_APK")" "$CHECKSUMS_DIR"
  cp -f "$source_apk" "$ARTIFACTS_APK"
  shasum -a 256 "$ARTIFACTS_APK" | tee "$CHECKSUMS_DIR/IbulCustomer.apk.sha256"
  echo "✓ Staged: $ARTIFACTS_APK"
}

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

# Windows/CRLF kaynaklı görünmez \r karakterlerini temizle; aksi halde
# dart-define değeri bozulur ve runtime config hatalı çalışır.
strip_cr() {
  local name="$1"
  local value="${!name:-}"
  printf -v "$name" '%s' "${value%$'\r'}"
}
for var_name in \
  IBUL_SUPABASE_URL \
  IBUL_SUPABASE_ANON_KEY \
  IBUL_CUSTOMER_ANDROID_APK_DOWNLOAD_URL \
  IBUL_CUSTOMER_ANDROID_PLAY_STORE_URL \
  IBUL_CUSTOMER_IOS_APP_STORE_URL \
  IBUL_CUSTOMER_IOS_TESTFLIGHT_URL \
  IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL \
  IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL \
  IBUL_FIREBASE_ANDROID_API_KEY \
  IBUL_FIREBASE_ANDROID_APP_ID \
  IBUL_FIREBASE_MESSAGING_SENDER_ID \
  IBUL_FIREBASE_PROJECT_ID \
  IBUL_FIREBASE_STORAGE_BUCKET
do
  strip_cr "$var_name"
done

# ── 1b. Firebase Android config: .env boşsa google-services.json'dan türet ───
# Otoritatif kaynak Firebase Console'un ürettiği google-services.json'dur
# (com.ibul.app client'ı). .env'de IBUL_FIREBASE_* doluysa .env öncelikli.
GOOGLE_SERVICES_JSON="$PROJECT_DIR/ibul_app/android/app/google-services.json"
if [[ -f "$GOOGLE_SERVICES_JSON" ]] && command -v python3 >/dev/null 2>&1; then
  while IFS='=' read -r gs_name gs_value; do
    [[ -n "$gs_name" && -n "$gs_value" ]] || continue
    if [[ -z "${!gs_name:-}" ]]; then
      printf -v "$gs_name" '%s' "$gs_value"
      export "${gs_name?}"
    fi
  done < <(python3 - "$GOOGLE_SERVICES_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
pi = d.get("project_info", {})
client = None
for c in d.get("client", []):
    if c["client_info"]["android_client_info"]["package_name"] == "com.ibul.app":
        client = c
        break
if client is None and d.get("client"):
    client = d["client"][0]
def emit(name, value):
    if value:
        print(f"{name}={value}")
emit("IBUL_FIREBASE_PROJECT_ID", pi.get("project_id", ""))
emit("IBUL_FIREBASE_STORAGE_BUCKET", pi.get("storage_bucket", ""))
emit("IBUL_FIREBASE_MESSAGING_SENDER_ID", pi.get("project_number", ""))
if client:
    emit("IBUL_FIREBASE_ANDROID_APP_ID", client["client_info"]["mobilesdk_app_id"])
    emit("IBUL_FIREBASE_ANDROID_API_KEY", client["api_key"][0]["current_key"])
PY
)
  echo "✓ Firebase Android config google-services.json'dan tamamlandı (boş olanlar)"
fi

# ── 2. Validate required keys ─────────────────────────────────────────────────
if [[ -z "${IBUL_SUPABASE_URL:-}" || -z "${IBUL_SUPABASE_ANON_KEY:-}" ]]; then
  echo ""
  echo "❌  Android release build durduruldu: Supabase config eksik."
  [[ -z "${IBUL_SUPABASE_URL:-}" ]]      && echo "    - IBUL_SUPABASE_URL boş"
  [[ -z "${IBUL_SUPABASE_ANON_KEY:-}" ]] && echo "    - IBUL_SUPABASE_ANON_KEY boş"
  echo ""
  echo "   .env dosyasını oluşturup bu değerleri girin veya shell ortamına export edin."
  echo "   Bu değerler olmadan build alınırsa APK açılışta"
  echo "   'Sunucu yapılandırması eksik' hatası verir."
  exit 1
fi

echo "✓ IBUL_SUPABASE_URL  = ${IBUL_SUPABASE_URL:0:40}..."
echo "✓ IBUL_SUPABASE_ANON_KEY = ${IBUL_SUPABASE_ANON_KEY:0:20}..."
echo "Supabase URL present: true"
echo "Supabase anon key present: true"

# ── 2a. Validate Firebase Android config ──────────────────────────────────────
# firebase_options.dart `android` getter'ı bu 5 değeri zorunlu okur; biri boşsa
# uygulama açılışta StateError ile "Uygulama başlatılamadı" ekranına düşer.
FIREBASE_MISSING=()
for fb_name in \
  IBUL_FIREBASE_ANDROID_API_KEY \
  IBUL_FIREBASE_ANDROID_APP_ID \
  IBUL_FIREBASE_MESSAGING_SENDER_ID \
  IBUL_FIREBASE_PROJECT_ID \
  IBUL_FIREBASE_STORAGE_BUCKET
do
  [[ -z "${!fb_name:-}" ]] && FIREBASE_MISSING+=("$fb_name")
done
if [[ ${#FIREBASE_MISSING[@]} -gt 0 ]]; then
  echo ""
  echo "❌  Android release build durduruldu: Firebase Android config eksik."
  for fb_name in "${FIREBASE_MISSING[@]}"; do
    echo "    - $fb_name boş"
  done
  echo ""
  echo "   Bu değerler .env'e girilebilir veya ibul_app/android/app/"
  echo "   google-services.json (com.ibul.app client) içinden otomatik türetilir."
  echo "   google-services.json eksik/bozuksa Firebase Console'dan indirin."
  exit 1
fi
echo "Firebase Android API key present: true (len=${#IBUL_FIREBASE_ANDROID_API_KEY})"
echo "Firebase Android App ID present: true"
echo "Firebase project: $IBUL_FIREBASE_PROJECT_ID / sender: $IBUL_FIREBASE_MESSAGING_SENDER_ID"

# ── 2b. generated_runtime_config.g.dart üretimi ──────────────────────────────
# String.fromEnvironment'in başarısız olduğu durumlara karşı deterministik
# ikinci katman: .env değerleri derlemeye const Dart dosyası olarak girer.
# Okuma sırası runtime_config.dart'ta: dart-define → legacy define → generated.
# Bu dosya .gitignore'dadır; commit EDİLMEZ. Stub: generated_runtime_config_stub.dart
GENERATED_CONFIG="$IBUL_APP_DIR/lib/core/config/generated_runtime_config.g.dart"

# GEÇİCİ teşhis build'i için: hangi build'in cihazda çalıştığını hata ekranında
# görebilmek adına build marker + git commit hint üretilir. Secret İÇERMEZ.
BUILD_MARKER="android-runtime-config-fixed-$(date -u +%Y-%m-%d)-01"
BUILD_SHA_HINT="$(cd "$PROJECT_DIR" && git rev-parse --short=8 HEAD 2>/dev/null || echo '')"

dart_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"   # \  -> \\
  s="${s//\'/\\\'}"   # '  -> \'
  s="${s//\$/\\\$}"   # $  -> \$  (Dart string interpolation'ı kapat)
  printf '%s' "$s"
}

cat > "$GENERATED_CONFIG" <<EOF
// GENERATED by scripts/build_customer_android_release.sh
// BU DOSYAYI COMMIT ETMEYİN (.gitignore'da). Stub: generated_runtime_config_stub.dart
//
// Okuma sırası (runtime_config.dart):
//   1. --dart-define (IBUL_*)   2. legacy define   3. bu dosya   4. hata

const String generatedBuildMarker = '$(dart_escape "$BUILD_MARKER")';
const String generatedBuildSha256Hint = '$(dart_escape "$BUILD_SHA_HINT")';
const String generatedIbulSupabaseUrl = '$(dart_escape "$IBUL_SUPABASE_URL")';
const String generatedIbulSupabaseAnonKey = '$(dart_escape "$IBUL_SUPABASE_ANON_KEY")';
const String generatedCustomerAndroidApkDownloadUrl = '$(dart_escape "${IBUL_CUSTOMER_ANDROID_APK_DOWNLOAD_URL:-}")';
const String generatedCustomerAndroidPlayStoreUrl = '$(dart_escape "${IBUL_CUSTOMER_ANDROID_PLAY_STORE_URL:-}")';
const String generatedCustomerIosAppStoreUrl = '$(dart_escape "${IBUL_CUSTOMER_IOS_APP_STORE_URL:-}")';
const String generatedCustomerIosTestFlightUrl = '$(dart_escape "${IBUL_CUSTOMER_IOS_TESTFLIGHT_URL:-}")';
const String generatedSellerWindowsDownloadUrl = '$(dart_escape "${IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL:-}")';
const String generatedSellerMacosDownloadUrl = '$(dart_escape "${IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL:-}")';
const String generatedFirebaseAndroidApiKey = '$(dart_escape "${IBUL_FIREBASE_ANDROID_API_KEY:-}")';
const String generatedFirebaseAndroidAppId = '$(dart_escape "${IBUL_FIREBASE_ANDROID_APP_ID:-}")';
const String generatedFirebaseMessagingSenderId = '$(dart_escape "${IBUL_FIREBASE_MESSAGING_SENDER_ID:-}")';
const String generatedFirebaseProjectId = '$(dart_escape "${IBUL_FIREBASE_PROJECT_ID:-}")';
const String generatedFirebaseStorageBucket = '$(dart_escape "${IBUL_FIREBASE_STORAGE_BUCKET:-}")';
EOF
echo "✓ generated_runtime_config.g.dart üretildi: $GENERATED_CONFIG"
echo "✓ buildMarker  = $BUILD_MARKER"
echo "✓ buildShaHint = ${BUILD_SHA_HINT:-<git yok>}"

# ── 3. Build dart-define array ────────────────────────────────────────────────
# Aşağıdaki 8 define HER ZAMAN build'e geçirilir (boş olsa bile; runtime
# config boş değeri normalize edip güvenli fallback'e düşer).
declare -a DART_DEFINES=(
  "--dart-define=IBUL_SUPABASE_URL=${IBUL_SUPABASE_URL}"
  "--dart-define=IBUL_SUPABASE_ANON_KEY=${IBUL_SUPABASE_ANON_KEY}"
  "--dart-define=IBUL_CUSTOMER_ANDROID_APK_DOWNLOAD_URL=${IBUL_CUSTOMER_ANDROID_APK_DOWNLOAD_URL:-}"
  "--dart-define=IBUL_CUSTOMER_ANDROID_PLAY_STORE_URL=${IBUL_CUSTOMER_ANDROID_PLAY_STORE_URL:-}"
  "--dart-define=IBUL_CUSTOMER_IOS_APP_STORE_URL=${IBUL_CUSTOMER_IOS_APP_STORE_URL:-}"
  "--dart-define=IBUL_CUSTOMER_IOS_TESTFLIGHT_URL=${IBUL_CUSTOMER_IOS_TESTFLIGHT_URL:-}"
  "--dart-define=IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL=${IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL:-}"
  "--dart-define=IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL=${IBUL_SELLER_DESKTOP_MACOS_DOWNLOAD_URL:-}"
  # Firebase Android — firebase_options.dart android getter'ının zorunlu
  # alanları; 2a adımında non-empty doğrulandı, koşulsuz geçirilir.
  "--dart-define=IBUL_FIREBASE_ANDROID_API_KEY=${IBUL_FIREBASE_ANDROID_API_KEY}"
  "--dart-define=IBUL_FIREBASE_ANDROID_APP_ID=${IBUL_FIREBASE_ANDROID_APP_ID}"
  "--dart-define=IBUL_FIREBASE_MESSAGING_SENDER_ID=${IBUL_FIREBASE_MESSAGING_SENDER_ID}"
  "--dart-define=IBUL_FIREBASE_PROJECT_ID=${IBUL_FIREBASE_PROJECT_ID}"
  "--dart-define=IBUL_FIREBASE_STORAGE_BUCKET=${IBUL_FIREBASE_STORAGE_BUCKET}"
)

append_define() {
  local name="$1"
  local value="${!name:-}"
  if [[ -n "$value" ]]; then
    DART_DEFINES+=("--dart-define=$name=$value")
  fi
}

# Opsiyonel define'lar (doluysa geçirilir). Firebase Android define'ları
# artık opsiyonel DEĞİL — yukarıdaki zorunlu listeye taşındı.
for define_name in \
  IBUL_GOOGLE_CLIENT_ID \
  IBUL_GOOGLE_SERVER_CLIENT_ID \
  IBUL_FIREBASE_AUTH_DOMAIN
do
  append_define "$define_name"
done

echo "✓ dart-define sayısı: ${#DART_DEFINES[@]} (13 zorunlu + opsiyoneller)"

# ── 4. Pre-build checks (ibul_app/android — customer target) ─────────────────
cd "$IBUL_APP_DIR"

GOOGLE_SERVICES="$IBUL_APP_DIR/android/app/google-services.json"
if [[ ! -f "$GOOGLE_SERVICES" ]]; then
  echo ""
  echo "⚠  google-services.json bulunamadı: $GOOGLE_SERVICES"
  echo "   Firebase Console'dan indirip ibul_app/android/app/ altına koyun."
  echo "   Firebase push notification ve auth servisleri çalışmayabilir."
  echo ""
fi

KEY_PROPS="$IBUL_APP_DIR/android/key.properties"
if [[ ! -f "$KEY_PROPS" ]]; then
  echo ""
  echo "⚠  key.properties bulunamadı: $KEY_PROPS"
  echo "   Release signing yapılamaz. Debug key ile devam edilecek."
  echo "   Telefonda 'geçersiz APK' veya imza çakışması görülebilir."
  echo ""
fi

# ── 5. Build APK (arm64-v8a split, target=lib/main_customer.dart) ────────────
echo ""
echo "▶  İbul Customer Android APK build başlatılıyor (arm64-v8a)..."
echo "    Project:  $IBUL_APP_DIR"
echo "    Target:   lib/main_customer.dart"
echo "    Package:  com.ibul.app"
echo "    Platform: android-arm64 (--split-per-abi, universal fallback YOK)"
echo ""

flutter build apk \
  --release \
  --target lib/main_customer.dart \
  --target-platform android-arm64 \
  --split-per-abi \
  "${DART_DEFINES[@]}"

APK_PATH="$IBUL_APP_DIR/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
UNIVERSAL_APK="$IBUL_APP_DIR/build/app/outputs/flutter-apk/app-release.apk"

echo ""
if [[ ! -f "$APK_PATH" ]]; then
  echo "❌  app-arm64-v8a-release.apk üretilmedi:"
  echo "   $APK_PATH"
  if [[ -f "$UNIVERSAL_APK" ]]; then
    echo "   Not: Universal app-release.apk bulundu ama bilinçli olarak"
    echo "   STAGE EDİLMEYECEK (118 MB universal APK yanlış asset riski)."
  fi
  echo "   Not: Kök android/ (com.example.ibul2026) ile karıştırmayın."
  exit 1
fi

APK_SIZE=$(wc -c < "$APK_PATH" | tr -d ' ')
echo "✅  arm64 APK build başarılı!"
echo "    Konum: $APK_PATH"
echo "    Boyut: $((APK_SIZE / 1048576)) MB ($APK_SIZE bayt)"
verify_supabase_config_embedded "$APK_PATH"
verify_apk "$APK_PATH"
stage_apk_artifact "$APK_PATH"

# ── 6. Build AAB (optional) ──────────────────────────────────────────────────
if [[ "$BUILD_AAB" == "true" ]]; then
  echo ""
  echo "▶  İbul Customer Android AAB (Play Store) build başlatılıyor..."
  echo ""

  flutter build appbundle \
    --release \
    --target lib/main_customer.dart \
    "${DART_DEFINES[@]}"

  AAB_PATH="$IBUL_APP_DIR/build/app/outputs/bundle/release/app-release.aab"

  echo ""
  if [[ -f "$AAB_PATH" ]]; then
    AAB_SIZE=$(wc -c < "$AAB_PATH" | tr -d ' ')
    echo "✅  AAB build başarılı!"
    echo "    Konum: $AAB_PATH"
    echo "    Boyut: $((AAB_SIZE / 1048576)) MB"
  else
    echo "⚠  AAB build tamamlandı ancak dosya beklenen konumda bulunamadı:"
    echo "   $AAB_PATH"
    exit 1
  fi
fi

# ── 7. Summary ───────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Build tamamlandı"
echo "════════════════════════════════════════════════════════════"
echo "  APK (build):  $APK_PATH"
echo "  APK (staged): $ARTIFACTS_APK"
if [[ "$BUILD_AAB" == "true" ]]; then
  echo "  AAB: $AAB_PATH"
fi
echo ""
echo "  GitHub Release tag: ibul-public-downloads"
echo "  Asset adı: IbulCustomer.apk"
echo ""
echo "  Test için APK kurulum:"
echo "    adb install -r $ARTIFACTS_APK"
echo ""
if [[ "$BUILD_AAB" == "true" ]]; then
  echo "  Play Store yükleme:"
  echo "    Google Play Console > Release > Production > Upload AAB"
  echo ""
fi
