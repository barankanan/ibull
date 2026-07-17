#!/usr/bin/env bash
# İbul — Public downloads paketleme scripti
#
# Sırayla:
#   1. Android arm64 APK build eder (build_customer_android_release.sh).
#   2. macOS'ta ise DMG paketini üretir (package_seller_desktop_macos.sh).
#   3. Windows EXE'yi release_artifacts/windows altında doğrular
#      (Windows build'i bu makinede alınamaz; hazır EXE beklenir).
#   4. release_artifacts altındaki final dosyaları listeler.
#   5. sha256 çıktılarının release_artifacts/checksums altına yazar.
#   6. gh CLI varsa opsiyonel upload komutunu raporlar (otomatik upload YOK).
#
# Usage:
#   ./scripts/package_public_downloads.sh
#   ./scripts/package_public_downloads.sh --skip-android   # APK build atla
#   ./scripts/package_public_downloads.sh --skip-macos     # DMG build atla
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

RELEASE_TAG="ibul-public-downloads"
ARTIFACTS_DIR="$PROJECT_DIR/release_artifacts"
CHECKSUMS_DIR="$ARTIFACTS_DIR/checksums"
APK_FINAL="$ARTIFACTS_DIR/android/IbulCustomer.apk"
DMG_FINAL="$ARTIFACTS_DIR/macos/IbulSellerDesktop.dmg"
EXE_FINAL="$ARTIFACTS_DIR/windows/IbulSellerSetup.exe"

SKIP_ANDROID=false
SKIP_MACOS=false
for arg in "$@"; do
  case "$arg" in
    --skip-android) SKIP_ANDROID=true ;;
    --skip-macos)   SKIP_MACOS=true ;;
  esac
done

mkdir -p "$CHECKSUMS_DIR"

# ── 1. Android arm64 APK ─────────────────────────────────────────────────────
if [[ "$SKIP_ANDROID" == "true" ]]; then
  echo "⚠  Android build atlandı (--skip-android)."
else
  echo "▶  Android arm64 APK build..."
  "$SCRIPT_DIR/build_customer_android_release.sh"
fi

# ── 2. macOS DMG ─────────────────────────────────────────────────────────────
if [[ "$SKIP_MACOS" == "true" ]]; then
  echo "⚠  macOS DMG build atlandı (--skip-macos)."
elif [[ "$(uname -s)" == "Darwin" && -x "$SCRIPT_DIR/package_seller_desktop_macos.sh" ]]; then
  echo ""
  echo "▶  macOS DMG paketi..."
  "$SCRIPT_DIR/package_seller_desktop_macos.sh"
else
  echo "⚠  macOS DMG build bu makinede çağrılamıyor (Darwin değil veya script yok)."
  echo "   Mevcut $DMG_FINAL dosyası doğrulanacak."
fi

# ── 3. Final artifact doğrulaması ────────────────────────────────────────────
echo ""
echo "▶  Final artifact doğrulaması..."
MISSING=()
[[ -f "$APK_FINAL" ]] || MISSING+=("$APK_FINAL — ./scripts/build_customer_android_release.sh ile üretin")
[[ -f "$DMG_FINAL" ]] || MISSING+=("$DMG_FINAL — macOS'ta ./scripts/package_seller_desktop_macos.sh ile üretin")
[[ -f "$EXE_FINAL" ]] || MISSING+=("$EXE_FINAL — Windows'ta build_seller_desktop_windows.ps1 ile üretip buraya kopyalayın")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo ""
  echo "❌ Eksik release artifact(lar):"
  for m in "${MISSING[@]}"; do
    echo "   - $m"
  done
  exit 1
fi

# ── 4. sha256 checksums ──────────────────────────────────────────────────────
echo ""
echo "▶  sha256 checksums yazılıyor: $CHECKSUMS_DIR"
shasum -a 256 "$APK_FINAL" | tee "$CHECKSUMS_DIR/IbulCustomer.apk.sha256"
shasum -a 256 "$DMG_FINAL" | tee "$CHECKSUMS_DIR/IbulSellerDesktop.dmg.sha256"
shasum -a 256 "$EXE_FINAL" | tee "$CHECKSUMS_DIR/IbulSellerSetup.exe.sha256"

# ── 5. Özet ──────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Final release artifact'ları"
echo "════════════════════════════════════════════════════════════"
for f in "$APK_FINAL" "$DMG_FINAL" "$EXE_FINAL"; do
  SIZE=$(wc -c < "$f" | tr -d ' ')
  echo "  $f"
  echo "    Boyut: $((SIZE / 1048576)) MB ($SIZE bayt)"
done

# ── 6. Opsiyonel GitHub upload komutu (otomatik ÇALIŞTIRILMAZ) ───────────────
echo ""
if command -v gh >/dev/null 2>&1; then
  echo "gh CLI mevcut. Manuel upload için (asset isimleri DEĞİŞMEZ):"
else
  echo "gh CLI yok. Kurulumdan sonra manuel upload için:"
fi
cat <<EOF

  gh release upload $RELEASE_TAG \\
    "$APK_FINAL" \\
    "$DMG_FINAL" \\
    "$EXE_FINAL" \\
    --repo barankanan/ibull --clobber

  Upload sonrası doğrulama:
    ./scripts/verify_public_downloads.sh
EOF

echo "✓ Paketleme tamamlandı."
