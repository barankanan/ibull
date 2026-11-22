#!/bin/bash
# Kanıt doğrulayıcı Edge Function'ını DAĞITILABİLİR biçimde hazırlar (dağıtmaz).
# Yerel `index.ts` 127.0.0.1'e dinler (yalnız izole testler); Supabase'e giden giriş
# `Deno.serve(handler)` olmalıdır. Bu betik ayrı bir klasörde doğru girişi üretir.
# Çıktı klasörü: $OUT (varsayılan /tmp/ibul-verify-evidence-pkg)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/ibul_app/supabase/functions/verify-lan-print-evidence"
OUT="${1:-/tmp/ibul-verify-evidence-pkg}"
FN="$OUT/supabase/functions/verify-lan-print-evidence"
rm -rf "$OUT"; mkdir -p "$FN"
cp "$SRC/verify_print_evidence.mjs" "$FN/verify_print_evidence.mjs"
cat > "$FN/index.ts" <<'TS'
import { handleEvidenceRequest } from './verify_print_evidence.mjs';

// Supabase Edge Functions: SUPABASE_URL, SUPABASE_ANON_KEY ve SUPABASE_SERVICE_ROLE_KEY
// ortamda hazır gelir. Servis anahtarı bu süreçten çıkmaz; çağıran kendi JWT'sini sunar.
Deno.serve((request: Request) => handleEvidenceRequest(request));
TS
echo "Paket hazır: $OUT"
echo "Dağıtım (kullanıcı çalıştırır, Docker gerekmez):"
echo "  cd $OUT && supabase functions deploy verify-lan-print-evidence --project-ref ihmixxzqnpamcwmrfibx --use-api"
