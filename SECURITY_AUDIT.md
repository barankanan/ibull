# İBUL — SECURITY AUDIT

**Audit date:** 2026-09-26 · **Branch:** `perf/web-wasm-secure-storage` · **HEAD:** `5b44d30`

**Method:** static source review (file reads + repo-wide pattern search). **No dynamic penetration testing, no database connection, and no authenticated request testing was performed** — the machine's process table was exhausted (see `PREPROD_AUDIT.md` §1), which blocked the browser and all tooling.

Findings are split into **VERIFIED** (I read the code and can cite it) and **NOT VERIFIED** (requires execution or a staging environment). Nothing is marked PASS on inference alone.

---

## SUMMARY

| Gate (requirement 103) | Result |
| --- | --- |
| No exposed service-role key | **PASS (verified)** |
| No critical secret leak in repo | **PASS (verified, with one gap — git history not scanned)** |
| No open redirect | **PASS (verified)** |
| Web shell input safety / XSS | **PASS (verified)** |
| Security headers present | **PASS (verified)** |
| RLS isolation | **NOT VERIFIED** |
| No role escalation | **NOT VERIFIED** |
| Private KYC documents | **NOT VERIFIED** |
| RPC auth checks | **NOT VERIFIED** |
| No fake payment | **NOT VERIFIED** |
| No raw card data | **NOT VERIFIED** |
| No cross-store access | **NOT VERIFIED** |

**Security gate: FAIL** — not because a vulnerability was proven, but because six of twelve required gates were never exercised.

---

## SEC-001 — Boot shell escalates any late error into a full-screen app takeover

- **Severity:** P0 (availability / denial of service against your own users)
- **Status:** **FIXED (written, not yet compiled or tested)**
- **Affected file:** `ibul_app/web/index.html`

**Attack scenario.** No attacker is strictly required — a flaky network is enough — but it is remotely triggerable. The page registered two permanent global listeners:

```js
window.addEventListener('error', function (event) { ... window.__ibulShowBootError(...) });
window.addEventListener('unhandledrejection', function (event) { ... window.__ibulShowBootError(...) });
```

`__ibulShowBootError` sets `#ibul-loader` to `display:none` and reveals a fixed, full-viewport `#ibul-boot-error` panel at `z-index: 100000`. Because the listeners had **no boot-window scope**, this fired at *any* point in the session. A single deferred `*.part.js` that fails to fetch — or any unhandled promise rejection from a background Supabase call — would blank out a fully loaded, logged-in application, mid-checkout included. An attacker able to degrade one chunk request (hostile Wi-Fi, an injected 500 on one asset) can reliably deny the app to that user.

**Second, opposite defect.** The filter that decided whether an error "belonged to app code" was:

```js
file.indexOf('main.dart.js') >= 0 || file.indexOf('canvaskit') >= 0 ||
file.indexOf('flutter_bootstrap') >= 0 || file.indexOf('.part.js') >= 0
```

`scripts/build_web_hosting.sh` renames the entry bundle to `app.<16-hex>.js` and `fingerprint_web_js.py` rewrites part names to `main.dart.js_N.part.<digest>.js`. So in production:

- the **entry bundle never matched** → a real boot failure in the main bundle was silently dropped;
- `.part.js` **never matched** either (the name ends `.part.<digest>.js`), though parts still matched via the `main.dart.js` prefix.

Net effect: the handler suppressed the failures you need and surfaced the ones you don't. This is the most likely origin of the reported `"Uygulama kodu yüklenemedi: Uncaught"` — a perf build (un-fingerprinted, so `main.dart.js` still matched) reporting an error that a production build would have hidden.

**Fix.** Errors are now **always** recorded to `localStorage` (nothing masked), but the fatal takeover only happens while the runtime is not yet up:

```js
function isFlutterRuntimeUp() {
  if (window.__ibulHomeBootTrace && window.__ibulHomeBootTrace.bootComplete) return true;
  if (document.querySelector('flt-glass-pane')) return true;
  return document.getElementById('ibul-loader') === null;
}
```

and the filter now also matches `/(^|\/)app\.[0-9a-f]{8,}\.js(\?|$)/`.

**Verification test.** `ibul_app/test/home/home_phase16_startup_regression_test.dart` → group *"Web boot error shell"* asserts both `isFlutterRuntimeUp` scoping and the fingerprinted-entry pattern. **Not yet executed.** Manual re-confirmation still required: load the production build in Chrome, force one `*.part.js` to 500 after first frame, and confirm the app survives with an inline retry instead of a takeover.

---

## SEC-002 — Unhandled deferred-chunk rejection (the trigger for SEC-001)

- **Severity:** P1
- **Status:** **FIXED (written, not tested)**
- **Affected file:** `ibul_app/lib/screens/home/home_viewport_section.dart`

**Attack scenario.** `_trigger()` called `widget.loadLibrary().then(...)`. On failure the rejection was either fully unhandled (feeding SEC-001's global handler and blanking the app) or, after a partial patch, swallowed into `debugPrint` — while `_triggered` stayed latched `true`, so the section was permanently stuck on an empty `SizedBox` with no path to recovery.

**Fix.** The failure now un-latches `_triggered`, re-binds the scroll listener, and renders the existing `HomeSectionError` with a working *"Tekrar dene"* retry. Error is still logged — not masked.

**Verification test.** `home_phase16_startup_regression_test.dart` → *"a failed section chunk surfaces retry instead of a blank slot"*. **Not yet executed.**

---

## SEC-003 — Service-role key exposure

- **Severity:** P0 if present
- **Status:** **PASS — VERIFIED**

Repo-wide search for `service_role`, `SUPABASE_SERVICE_ROLE`, `serviceRoleKey` (excluding `build/`, `node_modules/`, `.git/`). Every hit is server-side only:

| Location | Context |
| --- | --- |
| `ibul_app/supabase/functions/_shared/http.ts:5`, `_shared.ts:12`, `expire_vehicle_rentals/index.ts:10` | Deno edge functions — `Deno.env.get(...)`, server runtime |
| `restaurant-ops-web/src/features/restaurant/data/supabase/client.ts:12` | Next.js server-side admin client, `process.env` |
| `ibul_app/functions/index.js:12` | Firebase Functions, `process.env` |
| `restaurant-ops-web/.env.example:4`, `README.md:52` | Placeholder, no value |
| `ibul_app/supabase/migrations/*`, `SUPABASE_HOME_FEATURE_ADS.sql:356` | SQL role checks (`auth.role() = 'service_role'`) — correct usage |

**No service-role key appears anywhere in the Flutter client graph (`ibul_app/lib`).** A regression test already guards one edge function: `ibul_app/test/security/p0_security_hardening_contract_test.dart:89`.

**Residual gap:** the *built* bundle (`ibul_app/build/web/app.*.js`) was **not** scanned, because the search tools exclude build output and the shell was unavailable. Requirement 22 asks for this. Add to the re-run list:

```bash
grep -c 'service_role' ibul_app/build/web/app.*.js   # expect 0
```

---

## SEC-004 — Secrets in the repository

- **Severity:** P0 if present
- **Status:** **PASS for the working tree — VERIFIED. Git history NOT scanned.**

- `.env` exists at repo root but is **gitignored** (`.gitignore:39` → `**/.env`), confirmed via `git check-ignore -v`.
- `git ls-files` shows only **`.env.example`**, `local_print_bridge/.env.example`, `restaurant-ops-web/.env.example` tracked — templates, no values.
- The Supabase **anon** key and URL are passed at build time via `--dart-define` from `.env` (`scripts/build_web_hosting.sh:49–66`). The anon key is public by design and its presence in the bundle is **not** a finding.

**Residual gap (must close before release):** history was never scanned. Run:

```bash
git log --all -p -- '*.env' '*.env.*' | head -200
git log --all -p -S 'eyJ' --oneline | head -40          # JWT-shaped strings
git log --all -p -S 'BEGIN PRIVATE KEY' --oneline | head
```

If any real secret is found in history, mark **ROTATION NEEDED** and rotate — removing the file from the tip does not help.

**Google / Maps API keys (requirement 24):** **NOT VERIFIED.** The referrer/bundle-id restriction status of each key was not enumerated. This needs a pass over `web/index.html`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/AppDelegate.swift`, `macos/`, plus the Google Cloud console to confirm each client key is referrer- or bundle-restricted and that no backend-only key ships in the client.

---

## SEC-005 — Open redirect via `next`

- **Severity:** P0 if present
- **Status:** **PASS — VERIFIED** (one P2 hardening note)

The router emits the parameter at `ibul_app/lib/app/ibul_go_router.dart:205`:

```dart
return '/login?next=${Uri.encodeComponent(path)}';
```

and it is consumed at `ibul_app/lib/core/auth/customer_login_completion.dart:33–36`:

```dart
final next = GoRouter.maybeOf(context)?.state.uri.queryParameters['next'];
if (next != null && next.startsWith('/') && !next.startsWith('//')) {
  IbulRouter.go(context, next);
```

`https://evil.example` fails `startsWith('/')`. Protocol-relative `//evil.example` is explicitly rejected. **Not exploitable.**

**P2 hardening.** `/\evil.example` passes the check (starts with `/`, not `//`). Some URL parsers treat `/\` equivalently to `//`. Here it is **not** an open redirect — `IbulRouter.go` is a client-side go_router navigation, not a browser location assignment, so the worst outcome is the `errorBuilder` 404 (`ibul_go_router.dart:39–42`). Still worth tightening:

```dart
if (next != null && next.startsWith('/') && !next.startsWith('//') && !next.startsWith(r'/\')) {
```

**Verification test:** none exists. Recommend adding a table-driven test over `['https://evil.example', '//evil.example', r'/\evil.example', '/hesabim/favoriler']`.

---

## SEC-006 — Web shell input handling (XSS)

- **Severity:** P0 if present
- **Status:** **PASS — VERIFIED**

`ibul_app/web/index.html` was read in full. The pre-Flutter shell takes the search query through a plain HTML form:

```html
<form class="ibul-search" action="/" method="get">
  <input name="q" type="search" minlength="3" ...>
```

The browser performs the navigation; **no JavaScript reads `?q=` and no JavaScript writes it into the DOM.** The category links are static, pre-encoded hrefs (`/?category=Kad%C4%B1n`). Within the shell's inline script there is **no** `innerHTML`, `document.write`, `eval`, or `new Function`. The only DOM text assignment is safe:

```js
if (msg && message) msg.textContent = message;   // textContent, not innerHTML
```

Requirement 55 is satisfied for the shell.

**NOT VERIFIED — the Flutter-side surface (requirement 54).** Injection payloads (`<script>alert(1)</script>`, `<img onerror=...>`, quotes, raw tags) were **never submitted** into product name, store name, description, review, question, search, or campaign fields. Flutter renders text via `Text`/`RichText`, which does not interpret HTML, so the web XSS risk is structurally low; but stored-payload handling in server-rendered SEO metadata and in any `Html`/`WebView` widget must still be checked, and the payloads must actually be tried.

---

## SEC-007 — Hosting security headers

- **Severity:** informational
- **Status:** **PASS — VERIFIED** (stronger than expected)

`firebase.json` already sets, on `source: "**"`:

| Header | Value |
| --- | --- |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=(self), payment=(), usb=(), interest-cohort=()` |
| `Content-Security-Policy` | full policy below |

```
default-src 'self'; base-uri 'self'; object-src 'none'; form-action 'self';
frame-ancestors 'none';
script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval'
  https://apis.google.com https://www.gstatic.com https://cdnjs.cloudflare.com;
style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com;
img-src 'self' data: blob: https:;
font-src 'self' data: https://fonts.gstatic.com;
connect-src 'self' https://*.supabase.co wss://*.supabase.co https://*.googleapis.com
  https://*.google.com https://*.gstatic.com https://nominatim.openstreetmap.org
  https://*.openstreetmap.org https://{a,b,c.}tile.openstreetmap.org;
worker-src 'self' blob:; frame-src 'self' https://accounts.google.com https://*.google.com;
media-src 'self' blob: data:;
```

Requirement 59 explicitly warns against applying a blind strict CSP — **none was applied.** The existing policy is left untouched. Observations:

- `frame-ancestors 'none'` plus `X-Frame-Options: DENY` — clickjacking covered twice.
- `object-src 'none'`, `base-uri 'self'`, `form-action 'self'` — good hardening.
- `script-src 'unsafe-inline' 'unsafe-eval'` is currently **required** by the Flutter web bootstrap (inline `preloadCanvasKitVariant` script) and CanvasKit's wasm path. Recorded as **accepted risk (P2-3)**, not a defect. Removing it needs a nonce/hash strategy and `flutter_bootstrap.js` changes — explicitly out of scope per requirement 100.
- `img-src https:` is broad (any HTTPS host). Defensible for a marketplace with third-party product imagery; tightening to the Supabase storage origin + CDN would be an improvement.

**NOT VERIFIED:** requirement 60 (enumerate the *actual* external origins from a real network waterfall and flag unexpected third parties) — needs a browser.

**Cache policy (requirement 58): VERIFIED by reading `firebase.json`.** `/`, `/index.html`, `/**/*.html`, `flutter_bootstrap.js`, `flutter.js`, `main.dart.js`, `manifest.json`, `version.json` → `no-cache`. `app.*.js` and `main.dart.js_*.part.*.js` (both content-hashed) → `public, max-age=31536000, immutable`. `canvaskit/**` and `assets/**` → `max-age=86400, stale-while-revalidate`. SPA rewrite `** → /index.html` present. This is correct. `--pwa-strategy=none` is used and the build script deletes an empty `flutter_service_worker.js`; the shell also actively unregisters any surviving `flutter_service_worker` registration (`index.html:389–398`), which addresses the stale-service-worker concern in requirement 58.

---

## SEC-008 — Production error telemetry and PII

- **Severity:** P1
- **Status:** **OPEN**
- **Affected file:** `ibul_app/lib/app/app_bootstrap.dart:62–77`

```dart
FlutterError.onError = (FlutterErrorDetails details) {
  FlutterError.dumpErrorToConsole(details);
  debugPrint('Unhandled Flutter error: ${details.exception}');
  ...
};
PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
  saveWebBootError(module: 'platform_dispatcher', message: error.toString(), ...);
```

Both hooks **are** installed (requirement 72's first half passes), but the only sinks are the browser console and `localStorage['ibul_web_boot_error_v1']`. **There is no telemetry provider** — no Sentry, no Crashlytics for web. Production failures are therefore invisible unless a user manually reports and you read their `localStorage`.

On the positive side, this also means **no PII is shipped to a third party**, so requirement 35's telemetry clause is trivially satisfied today. That changes the moment a provider is added — scrub before then.

**NOT VERIFIED — PII in logs (requirement 35).** Whether TC kimlik / national ID reaches `debugPrint` was **not** audited; `ibul_app/lib/features/vehicle/domain/turkish_national_id.dart` and its callers still need review, as does UI masking. Note that `debugPrint` is compiled out in release Flutter web, which limits but does not eliminate exposure.

---

## NOT VERIFIED — required work that was never executed

These are the security gates that remain genuinely unknown. **Do not treat absence of a finding here as absence of a vulnerability.**

| Req | Area | What is needed |
| --- | --- | --- |
| 25 | RLS enablement + SELECT/INSERT/UPDATE/DELETE policy coverage for `orders`, `order_items`, `stores`, `products`, `favorites`, `cart`, `addresses`, `coupons`, `ads`, `vehicle_listings`, `vehicle_reservations`, `vehicle_kyc_documents`, seller finance, restaurant, print jobs, `notifications` | Static pass over `SUPABASE_*.sql` + `ibul_app/supabase/migrations/`, then live confirmation on staging |
| 26 | Cross-account read/write (USER A ↔ B, SELLER A ↔ B) | **Staging project with seeded users.** Must not run against production |
| 27 | Privilege escalation via client-written `role` / `is_admin` / `seller_id` / `store_id`. `20260915_users_privileged_column_guard.sql` exists — coverage unconfirmed | Staging + authenticated PostgREST calls |
| 28, 29 | Every `SECURITY DEFINER` function: explicit `search_path`, `auth.uid()` check, tenant check, input validation, `GRANT EXECUTE` audience | Static SQL pass; flag anything granted to `anon`/`public` that mutates or reads others' rows |
| 30 | Idempotency: double-click order, double submit, checkout refresh, pay-twice, ad submit twice | Needs server-side unique-constraint review + live test |
| 32 | Rental availability state machine + double-book race; atomic server-side recheck at payment confirmation | Staging concurrency test |
| 33, 34 | KYC document bucket **must be private**; signed-URL expiry; size/MIME/extension validation; `reservation_id + doc_type` uniqueness | Storage policy review + live upload attempts |
| 36 | Immutable contract-acceptance snapshot (version, `accepted_at`, customer, reservation) | Schema review |
| 37, 38, 39 | **Payment.** Real PSP or not; webhook signature verification, amount verification, replay/duplicate protection; if no PSP, every fake-success path must be disabled and card capture removed | **Highest-priority open item.** Requirement 38 makes this a hard blocker in either direction |
| 41, 42 | Server-authoritative price/total; server-side coupon validation | Order-creation payload review + manipulated-total test |
| 46, 47 | Seller cannot self-approve ads; homepage shows only approved/active; wheel probability validated server-side | RLS/RPC review + live test |
| 48, 49 | Non-admin blocked at **backend**, not just UI; admin action audit trail | Staging test with a non-admin JWT |
| 91 | Rate limiting on public endpoints | Design review |
| 92 | Mass assignment of `user_id`/`seller_id`/`store_id`/`status`/`approved`/`price`/`role` | Payload + policy review |
| 94 | Unauthorized notification insert for another user | Staging test |
