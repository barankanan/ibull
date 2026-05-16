#!/usr/bin/env bash
# install_print_bridge_service.sh
# Installs local_print_bridge as a macOS LaunchAgent with KeepAlive.
# Run once per machine; the bridge then starts automatically on login.
#
# Usage: bash scripts/install_print_bridge_service.sh [--uninstall]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_DIR="$PROJECT_DIR/.venv"
PYTHON_BIN="$VENV_DIR/bin/python3"
AGENT_LABEL="com.ibul.print-bridge"
PLIST_PATH="$HOME/Library/LaunchAgents/$AGENT_LABEL.plist"
LOG_DIR="$HOME/Library/Logs/ibul"
LOG_OUT="$LOG_DIR/print-bridge.out.log"
LOG_ERR="$LOG_DIR/print-bridge.err.log"

# ── Uninstall mode ────────────────────────────────────────────────────────────
if [[ "${1-}" == "--uninstall" ]]; then
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  rm -f "$PLIST_PATH"
  echo "Local print bridge service uninstalled."
  exit 0
fi

# ── Validate venv ─────────────────────────────────────────────────────────────
if [[ ! -f "$PYTHON_BIN" ]]; then
  echo "ERROR: Python venv not found at $VENV_DIR" >&2
  echo "Create it first:" >&2
  echo "  cd \"$PROJECT_DIR\"" >&2
  echo "  python3 -m venv .venv" >&2
  echo "  .venv/bin/pip install -r local_print_bridge/requirements.txt" >&2
  exit 1
fi

# ── Create log directory ──────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"

# ── Write plist ───────────────────────────────────────────────────────────────
mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${AGENT_LABEL}</string>

    <key>ProgramArguments</key>
    <array>
        <string>${PYTHON_BIN}</string>
        <string>-m</string>
        <string>local_print_bridge</string>
    </array>

    <key>WorkingDirectory</key>
    <string>${PROJECT_DIR}</string>

    <!-- Start at login -->
    <key>RunAtLoad</key>
    <true/>

    <!-- Restart automatically if it crashes -->
    <key>KeepAlive</key>
    <true/>

    <!-- Wait at least 10s before restarting after a crash -->
    <key>ThrottleInterval</key>
    <integer>10</integer>

    <!-- Log files -->
    <key>StandardOutPath</key>
    <string>${LOG_OUT}</string>

    <key>StandardErrorPath</key>
    <string>${LOG_ERR}</string>
</dict>
</plist>
PLIST

# ── (Re-)load the agent ───────────────────────────────────────────────────────
# Unload quietly if already loaded (handles re-install after path change)
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load   "$PLIST_PATH"

echo ""
echo "Local print bridge service installed and started."
echo ""
echo "  Label  : $AGENT_LABEL"
echo "  Plist  : $PLIST_PATH"
echo "  Logs   : $LOG_DIR"
echo ""
echo "Useful commands:"
echo "  launchctl list | grep ibul          # check status"
echo "  tail -f \"$LOG_OUT\"         # live stdout"
echo "  tail -f \"$LOG_ERR\"         # live stderr"
echo "  bash scripts/install_print_bridge_service.sh --uninstall"
