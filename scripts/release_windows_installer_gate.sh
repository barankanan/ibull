#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER_LOCAL="$ROOT_DIR/build/windows/installer/IbulSellerSetup.exe"
URL="${IBUL_SELLER_DESKTOP_WINDOWS_DOWNLOAD_URL:-${IBUL_WINDOWS_INSTALLER_DOWNLOAD_URL:-https://ibul-ecommerce.web.app/downloads/IbulSellerSetup.exe}}"

echo "[1/4] Checking local installer artifact..."
if [[ ! -f "$INSTALLER_LOCAL" ]]; then
  echo "FAIL: Missing unified installer artifact at $INSTALLER_LOCAL"
  echo "Run: pwsh scripts/build_seller_desktop_windows.ps1"
  exit 1
fi

size_bytes=$(wc -c < "$INSTALLER_LOCAL" | tr -d ' ')
echo "Installer size: ${size_bytes} bytes"
if [[ "$size_bytes" -lt 1000000 ]]; then
  echo "FAIL: Installer is unexpectedly small (< 1 MB)."
  exit 1
fi

if [[ "$URL" == *"/downloads/IbulPrintBridgeSetup.exe" ]]; then
  echo "FAIL: Installer URL still points at the retired bridge-only Firebase path: $URL"
  exit 1
fi

echo "[2/4] Checking external installer headers..."
headers=$(curl -sSIL "$URL")
status=$(printf '%s\n' "$headers" | awk 'toupper(substr($0,1,5))=="HTTP/"{status=$0} END{print status}')
ctype=$(printf '%s\n' "$headers" | awk -F': ' 'tolower($1)=="content-type"{print $2}' | tr -d '\r' | tail -n 1)
clen=$(printf '%s\n' "$headers" | awk -F': ' 'tolower($1)=="content-length"{print $2}' | tr -d '\r' | tail -n 1)
cencoding=$(printf '%s\n' "$headers" | awk -F': ' 'tolower($1)=="content-encoding"{print $2}' | tr -d '\r' | tail -n 1)
ccache=$(printf '%s\n' "$headers" | awk -F': ' 'tolower($1)=="cache-control"{print $2}' | tr -d '\r' | tail -n 1)

echo "Status: $status"
echo "Content-Type: ${ctype:-<missing>}"
echo "Content-Length: ${clen:-<missing>}"
echo "Content-Encoding: ${cencoding:-<missing>}"
echo "Cache-Control: ${ccache:-<missing>}"

if ! printf '%s' "$status" | grep -q " 200 "; then
  echo "FAIL: Hosted URL is not 200 OK"
  exit 1
fi

if printf '%s' "$ctype" | grep -qi "text/html"; then
  echo "FAIL: Hosted URL is returning HTML instead of binary"
  exit 1
fi

if [[ -z "${clen:-}" ]] || [[ "$clen" -lt 1000000 ]]; then
  echo "FAIL: Hosted content-length is missing or unexpectedly small"
  exit 1
fi

echo "[3/4] Validating downloaded file..."
tmp_exe="$(mktemp /tmp/ibul-installer.XXXXXX.exe)"
trap 'rm -f "$tmp_exe"' EXIT
curl -sSL "$URL" -o "$tmp_exe"

downloaded_size=$(wc -c < "$tmp_exe" | tr -d ' ')
downloaded_magic=$(xxd -p -l 2 "$tmp_exe" | tr -d '\n')
downloaded_type=$(file -b "$tmp_exe")

echo "Downloaded size: ${downloaded_size} bytes"
echo "Downloaded magic: ${downloaded_magic:-<missing>}"
echo "Downloaded type: ${downloaded_type:-<missing>}"

if [[ "$downloaded_size" -lt 1000000 ]]; then
  echo "FAIL: Downloaded file is unexpectedly small"
  exit 1
fi

if [[ "${downloaded_magic^^}" != "4D5A" ]]; then
  echo "FAIL: Downloaded file is not a valid Windows executable (missing MZ header)"
  exit 1
fi

if printf '%s' "$downloaded_type" | grep -qi "html"; then
  echo "FAIL: Downloaded file is HTML, not an executable"
  exit 1
fi

echo "[4/4] PASS: IbulSellerSetup.exe external download gate checks passed"
