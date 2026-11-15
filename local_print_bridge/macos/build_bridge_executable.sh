#!/bin/sh
# Build a standalone macOS bridge binary. Does not install or start it.
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
PYTHON="${PYTHON:-$ROOT/.venv/bin/python3}"
if ! "$PYTHON" -c "import PyInstaller" >/dev/null 2>&1; then
  echo "PyInstaller is required in the build environment." >&2
  exit 1
fi
"$PYTHON" -m PyInstaller \
  --noconfirm \
  --clean \
  --distpath "$ROOT/local_print_bridge/dist/macos" \
  --workpath "$ROOT/local_print_bridge/build/macos" \
  "$ROOT/local_print_bridge/macos/IbulPrintBridge.spec"
echo "Built $ROOT/local_print_bridge/dist/macos/IbulPrintBridge"
