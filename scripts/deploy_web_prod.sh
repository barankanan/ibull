#!/usr/bin/env bash
# Build and deploy IBUL web to Firebase Hosting.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

"$SCRIPT_DIR/build_web_prod.sh"

cd "$PROJECT_DIR"
echo "Deploying to Firebase Hosting..."
firebase deploy --only hosting

echo "Post-deploy cache headers (index.html):"
curl -sI "${IBUL_WEB_DEPLOY_URL:-https://ibul.com.tr}/index.html" | rg -i 'cache-control|content-length|last-modified' || true

echo "Post-deploy main.dart.js size:"
curl -sI "${IBUL_WEB_DEPLOY_URL:-https://ibul.com.tr}/main.dart.js" | rg -i 'content-length|last-modified' || true
