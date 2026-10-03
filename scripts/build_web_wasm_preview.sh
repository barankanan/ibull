#!/usr/bin/env bash
# WASM preview build. Does not touch the JS production output (build/web)
# and does not edit ibul_app/web/index.html.
set -euo pipefail

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

declare -a DART_DEFINES=()
declare -a MISSING_DEFINES=()

require_define "IBUL_SUPABASE_URL"
require_define "IBUL_SUPABASE_ANON_KEY"

if [[ ${#MISSING_DEFINES[@]} -gt 0 ]]; then
  echo "WASM preview blocked — missing env: ${MISSING_DEFINES[*]}"
  exit 1
fi

if [[ "$IBUL_SUPABASE_URL" == *"example.supabase.co"* ]]; then
  echo "WASM preview blocked — dummy Supabase URL is not accepted."
  exit 1
fi

SUPABASE_HOST="${IBUL_SUPABASE_URL#*://}"
SUPABASE_HOST="${SUPABASE_HOST%%/*}"
echo "WASM preview build"
echo "Supabase host: ${SUPABASE_HOST}"
echo "This script does not deploy."

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

OUT_DIR="$PROJECT_DIR/ibul_app/build/web-wasm-preview"
cd "$PROJECT_DIR/ibul_app"

flutter build web --release --wasm \
  --target lib/main.dart \
  --pwa-strategy=none \
  --no-web-resources-cdn \
  --no-wasm-dry-run \
  -o "$OUT_DIR" \
  "${DART_DEFINES[@]}"

python3 - "$OUT_DIR/index.html" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = """  <link rel=\"preload\" href=\"flutter_bootstrap.js\" as=\"script\" fetchpriority=\"high\">
  <link rel=\"preload\" href=\"main.dart.js\" as=\"script\" fetchpriority=\"high\">

  <!-- CanvasKit varyantı flutter.js ile AYNI kural: Blink + ImageDecoder +
       v8BreakIterator ise chromium/, aksi hâlde tam canvaskit/.
       Yanlış dosyayı preload etmek 2.5 MB israf + bant yarışı yapıyordu;
       doğru varyant main.dart.js ile paralel iner. -->
  <script>
    (function preloadCanvasKitVariant() {
      var ua = navigator.userAgent || '';
      var isBlink = navigator.vendor === 'Google Inc.' || ua.indexOf('Edg/') >= 0;
      var hasImageCodecs = typeof ImageDecoder !== 'undefined' && isBlink;
      var hasChromiumBreakIterators =
        typeof Intl.v8BreakIterator !== 'undefined' &&
        typeof Intl.Segmenter !== 'undefined';
      var base = (hasImageCodecs && hasChromiumBreakIterators)
        ? 'canvaskit/chromium/'
        : 'canvaskit/';
      function addHint(rel, href, asValue) {
        var link = document.createElement('link');
        link.rel = rel;
        link.href = href;
        if (asValue) link.as = asValue;
        link.crossOrigin = 'anonymous';
        if (asValue === 'fetch') link.setAttribute('fetchpriority', 'high');
        document.head.appendChild(link);
      }
      addHint('modulepreload', base + 'canvaskit.js');
      addHint('preload', base + 'canvaskit.wasm', 'fetch');
    })();
  </script>"""
new = """  <link rel=\"preload\" href=\"flutter_bootstrap.js\" as=\"script\" fetchpriority=\"high\">
  <link rel=\"modulepreload\" href=\"main.dart.mjs\" fetchpriority=\"high\">
  <link rel=\"preload\" href=\"main.dart.wasm\" as=\"fetch\" crossorigin=\"anonymous\" fetchpriority=\"high\">

  <!-- WASM preview output only. Blink uses skwasm; other engines use skwasm_heavy.
       main.dart.js and canvaskit.wasm stay on disk for the JS fallback and are not preloaded. -->
  <script>
    (function preloadSkwasmVariant() {
      var ua = navigator.userAgent || '';
      var isBlink = navigator.vendor === 'Google Inc.' || ua.indexOf('Edg/') >= 0;
      var hasImageCodecs = typeof ImageDecoder !== 'undefined' && isBlink;
      var hasChromiumBreakIterators =
        typeof Intl.v8BreakIterator !== 'undefined' &&
        typeof Intl.Segmenter !== 'undefined';
      var name = (hasImageCodecs && hasChromiumBreakIterators) ? 'skwasm' : 'skwasm_heavy';
      function addHint(rel, href, asValue) {
        var link = document.createElement('link');
        link.rel = rel;
        link.href = href;
        if (asValue) link.as = asValue;
        link.crossOrigin = 'anonymous';
        if (asValue === 'fetch') link.setAttribute('fetchpriority', 'high');
        document.head.appendChild(link);
      }
      addHint('modulepreload', 'canvaskit/' + name + '.js');
      addHint('preload', 'canvaskit/' + name + '.wasm', 'fetch');
    })();
  </script>"""
if old not in text:
    raise SystemExit("WASM preview index.html preload block was not found; source HTML changed.")
if 'href="main.dart.js"' in text.replace(old, "", 1):
    raise SystemExit("Unexpected main.dart.js preload outside the replaced block.")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
print("WASM preload hints written to output index.html")
PY

if grep -q 'href="main.dart.js"' "$PROJECT_DIR/ibul_app/web/index.html"; then
  echo "JS source index.html still preloads main.dart.js"
else
  echo "JS source index.html no longer preloads main.dart.js" >&2
  exit 1
fi

echo "Output: $OUT_DIR"
echo "Not deployed."
