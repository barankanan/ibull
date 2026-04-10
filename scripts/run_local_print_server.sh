#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)"
APP_FILE="$ROOT_DIR/app.py"
VENV_DIR="$ROOT_DIR/.venv"
HOST="127.0.0.1"
PORT="3001"

if [[ ! -f "$APP_FILE" ]]; then
  echo "app.py bulunamadı: $APP_FILE" >&2
  exit 1
fi

source "$VENV_DIR/bin/activate"

python3 -m pip install --upgrade pip
python3 -m pip install flask flask-cors pyusb python-escpos
python3 -m py_compile "$APP_FILE"

echo "[run_local_print_server] starting app.py on http://$HOST:$PORT"
echo "[run_local_print_server] health -> http://$HOST:$PORT/health"

exec python3 "$APP_FILE"
