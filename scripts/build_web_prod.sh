#!/usr/bin/env bash
# Production Flutter web build with required dart-defines.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/build_web_hosting.sh" "$@"
