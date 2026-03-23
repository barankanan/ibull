#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/run.sh                -> interactive, lists devices and asks for a number
#   ./scripts/run.sh -n "iPhone 11"   -> try to match device name substring (case-insensitive)
#   ./scripts/run.sh -i 2            -> directly choose device by displayed index (1-based)

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

if [[ -f "$PROJECT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$PROJECT_DIR/.env"
  set +a
fi

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

name_arg=""
index_arg=""
declare -a DART_DEFINES=()
declare -a MISSING_DEFINES=()

require_define "IBUL_SUPABASE_URL"
require_define "IBUL_SUPABASE_ANON_KEY"

if [[ ${#MISSING_DEFINES[@]} -gt 0 ]]; then
  echo "Eksik env/değer: ${MISSING_DEFINES[*]}"
  echo "Repo kökünde .env oluşturun veya komut öncesi değişkenleri export edin."
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)
      name_arg="$2"
      shift 2
      ;;
    -i|--index)
      index_arg="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# Get machine-readable devices list
devices_json="$(flutter devices --machine 2>/dev/null || true)"

# Fallback if flutter fails
if [[ -z "$devices_json" ]]; then
  echo "flutter devices dökümü alınamadı. Cihazların bağlı ve 'flutter' path'inin doğru olduğundan emin olun."
  flutter devices || true
  exit 1
fi

# Parse JSON and build arrays (use python3)
readarray -t IDS < <(python3 - <<PY
import sys, json
data = sys.stdin.read()
try:
    arr = json.loads(data)
except Exception:
    arr = []
out = []
for d in arr:
    nid = d.get("id","")
    name = d.get("name","")
    platform = d.get("platform","")
    # format: id||name||platform
    out.append(f"{nid}||{name}||{platform}")
print("\n".join(out))
PY
<<<"$devices_json")

if [[ ${#IDS[@]} -eq 0 ]]; then
  echo "Cihaz bulunamadı. 'flutter devices' çıktısını kontrol edin."
  flutter devices || true
  exit 1
fi

echo "Available devices:"
i=1
declare -a ID_LIST
declare -a NAME_LIST
for line in "${IDS[@]}"; do
  IFS='||' read -r did dname dplatform <<< "$line"
  printf "  [%d] %s  •  %s\n" "$i" "$dname" "$did"
  ID_LIST[$i]="$did"
  NAME_LIST[$i]="$dname"
  ((i++))
done

# If index arg provided, validate and select
if [[ -n "$index_arg" ]]; then
  if ! [[ "$index_arg" =~ ^[0-9]+$ ]]; then
    echo "Geçersiz index: $index_arg"
    exit 1
  fi
  choice_index="$index_arg"
else
  # If name arg provided, try substring match
  if [[ -n "$name_arg" ]]; then
    needle="$(echo "$name_arg" | tr '[:upper:]' '[:lower:]')"
    found=""
    for idx in "${!NAME_LIST[@]}"; do
      n="${NAME_LIST[$idx]}"
      if [[ -n "$n" && "$(echo "$n" | tr '[:upper:]' '[:lower:]')" == *"$needle"* ]]; then
        found="$idx"
        break
      fi
    done
    if [[ -n "$found" ]]; then
      choice_index="$found"
    else
      echo "İsimle eşleşen cihaz bulunamadı: $name_arg"
      # fall back to interactive selection
    fi
  fi
fi

# If choice_index not set yet, prompt user
if [[ -z "${choice_index-}" ]]; then
  echo ""
  read -rp "Lütfen bir cihaz numarası girin (ör. 2) veya 'q' ile çıkın: " user_in
  if [[ "$user_in" == "q" || "$user_in" == "Q" ]]; then
    echo "Çıkılıyor."
    exit 0
  fi
  if ! [[ "$user_in" =~ ^[0-9]+$ ]]; then
    echo "Geçersiz giriş: $user_in"
    exit 1
  fi
  choice_index="$user_in"
fi

# Validate index
if ! [[ "$choice_index" =~ ^[0-9]+$ ]]; then
  echo "Geçersiz seçim: $choice_index"
  exit 1
fi
if [[ -z "${ID_LIST[$choice_index]-}" ]]; then
  echo "Seçilen numara cihaz listesinde yok: $choice_index"
  exit 1
fi

device_id="${ID_LIST[$choice_index]}"
device_name="${NAME_LIST[$choice_index]}"

echo "Seçildi: [$choice_index] $device_name  •  $device_id"
echo "Uygulama bu cihazda başlatılıyor. Başlatıldıktan sonra aynı terminalde 'r' (hot reload) veya 'R' (hot restart) kullanabilirsiniz."
flutter run -d "$device_id" "${DART_DEFINES[@]}"
