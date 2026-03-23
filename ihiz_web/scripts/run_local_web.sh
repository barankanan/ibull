#!/usr/bin/env bash
set -euo pipefail

# ihiz_web local runner:
# - Finds an available port starting from 8083
# - Starts Flutter web-server in foreground (r/R/q work normally)
#
# Usage examples:
#   ./scripts/run_local_web.sh
#   ./scripts/run_local_web.sh --port 8083
#   ./scripts/run_local_web.sh --host 0.0.0.0
#   ./scripts/run_local_web.sh --pub-get

host="127.0.0.1"
start_port=8083
max_port=8100
fixed_port=""
run_pub_get="false"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd -- "$PROJECT_DIR/.." && pwd)"

if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$REPO_ROOT/.env"
  set +a
fi

declare -a DART_DEFINES=()

append_define() {
  local name="$1"
  local value="${!name:-}"
  if [[ -n "$value" ]]; then
    DART_DEFINES+=("--dart-define=$name=$value")
  fi
}

print_usage() {
  cat <<'EOF'
Usage: ./scripts/run_local_web.sh [options]

Options:
  --port <n>      Use a fixed port directly (example: 8083)
  --host <addr>   Web host (default: 127.0.0.1)
  --pub-get       Run flutter pub get before flutter run
  --help          Show this help
EOF
}

is_number() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

port_in_use() {
  local port="$1"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
}

find_available_port() {
  local port="$1"
  while [[ "$port" -le "$max_port" ]]; do
    if ! port_in_use "$port"; then
      echo "$port"
      return 0
    fi
    port=$((port + 1))
  done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      fixed_port="${2:-}"
      shift 2
      ;;
    --host)
      host="${2:-}"
      shift 2
      ;;
    --pub-get)
      run_pub_get="true"
      shift
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

if [[ -n "$fixed_port" ]] && ! is_number "$fixed_port"; then
  echo "Invalid port: $fixed_port"
  exit 1
fi

if ! is_number "$start_port" || ! is_number "$max_port"; then
  echo "Internal config error: invalid port range."
  exit 1
fi

if [[ "$run_pub_get" == "true" ]]; then
  echo "Running flutter pub get..."
  (cd "$PROJECT_DIR" && flutter pub get)
fi

missing_env=()
for required_name in IHIZ_SUPABASE_URL IHIZ_SUPABASE_ANON_KEY; do
  if [[ -z "${!required_name:-}" ]]; then
    missing_env+=("$required_name")
  fi
done

if [[ ${#missing_env[@]} -gt 0 ]]; then
  echo "Eksik env/değer: ${missing_env[*]}"
  echo "Repo kökünde .env oluşturun veya komut öncesi değişkenleri export edin."
  exit 1
fi

append_define "IHIZ_SUPABASE_URL"
append_define "IHIZ_SUPABASE_ANON_KEY"

if [[ -n "$fixed_port" ]]; then
  chosen_port="$fixed_port"
  if port_in_use "$chosen_port"; then
    echo "Port $chosen_port is already in use."
    echo "Try without --port for auto port selection."
    exit 1
  fi
else
  chosen_port="$(find_available_port "$start_port")" || {
    echo "No available port found between $start_port and $max_port."
    exit 1
  }
fi

echo "Starting ihiz_web on http://$host:$chosen_port"
echo "Keys: r=hot reload, R=hot restart, q=quit"
cd "$PROJECT_DIR"
exec flutter run -d web-server --web-port "$chosen_port" --web-hostname "$host" "${DART_DEFINES[@]}"
