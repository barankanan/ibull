# İBUL — PRE-PRODUCTION AUDIT

**Audit date:** 2026-09-26
**Branch:** `perf/web-wasm-secure-storage`
**HEAD:** `5b44d30` — *Fix admin store approval RLS, KEP display, and macOS debug signing.*
**Scope:** İBUL only. İHIZ (`ihiz_web/`) was not touched. No production deploy, no production DB mutation, no migration execution.

---

## 0. OVERALL STATUS

**SAFE PRODUCTION CANDIDATE: NO**

Two independent reasons:

1. **Open P0/P1 findings** (payment reality, RLS verification, release version) — see below.
2. **The audit could not be completed.** Roughly 40% of the required verification (test suite, Lighthouse, real-browser smoke, artifact measurement, dependency audit) is **BLOCKED** by a machine-level fault, not by the code. Four code fixes were written but **could not be compiled or tested**.

> **Nothing in this document claims a PASS that was not actually executed.** Every unexecuted item is marked `BLOCKED` or `NOT TESTED`.

---

## 1. ENVIRONMENT BLOCKER (must be cleared before release sign-off)

| Metric | Value |
| --- | --- |
| Processes owned by user | 1326–1506 |
| Zombie (`<defunct>`) processes | **947–950** |
| Zombie parent | **PID 1911 → `/Applications/Opera.app/Contents/MacOS/Opera`** (uptime 26d 17h) |
| `kern.maxprocperuid` | **1333** |

Opera has leaked ~950 un-reaped children over 26 days. Zombies count against `RLIMIT_NPROC`, so the per-user process table is exhausted and `fork()` / `posix_spawn()` fails. Symptoms observed:

- `flutter: fork: Resource temporarily unavailable`
- `clang: error: unable to execute command: posix_spawn failed` during the `objective_c` 9.3.0 native-asset build (this is what kills `flutter test` before the first test runs)
- `Failed to execute sandbox-exec: Resource temporarily unavailable`
- browser automation tool aborted

**Resolution:** quit / Force Quit Opera (PID 1911), or reboot. This reclaims ~950 slots immediately. Then re-run the BLOCKED items listed in §8; they are a single pass.

---

## 2. REPO STATE

| Item | Value |
| --- | --- |
| Branch | `perf/web-wasm-secure-storage` |
| Dirty paths vs HEAD | 207 (modified + untracked) |
| Flutter | 3.41.3 stable, revision `48c32af034` |
| Dart | 3.11.1 |
| DevTools | 2.54.1 |
| Firebase CLI | 15.8.0 |
| Supabase CLI | **UNVERIFIED** — `supabase --version` emitted JS source instead of a version string; the local install appears broken |
| pubspec version (root + `ibul_app`) | `1.0.0+1` — **placeholder, P1** |

The working tree carries large amounts of independent in-progress work (coupon feature, vehicle feature, seller contracts, storefront). **No files were reverted.** Only the four files in §4 were modified.

---

## 3. FINDINGS BY SEVERITY

### P0 — blocks release

| ID | Finding | Status |
| --- | --- | --- |
| P0-1 | **Web boot shell converts any late runtime error into a full-screen fatal takeover.** `web/index.html` registered permanent `error` / `unhandledrejection` listeners with no boot-window scope, so a single failed deferred part or late promise rejection replaced the *running* app with "Uygulama başlatılamadı". Compounding this, the filename filter only matched `main.dart.js`, but `build_web_hosting.sh` fingerprints the entry to `app.<hash>.js` — so genuine boot failures were **not** reported while harmless late errors **were**. | **FIX WRITTEN, UNVERIFIED** |
| P0-2 | **Payment reality not established.** Whether a real PSP exists, and whether any code path can mint a "successful payment" / reserved state / seller credit without one, is **NOT DETERMINED**. Requirement 38 makes this a hard blocker either way. | **NOT TESTED** |
| P0-3 | **RLS / tenant isolation not verified.** No cross-account attack test was executed (requires a staging project with seeded USER A/B, SELLER A/B). Static policy review was delegated but not returned. | **NOT TESTED** |
| P0-4 | **36 failing tests, identities unknown.** A full run completed once (2238 pass / 36 fail) but only the tail was captured. Requirement 83 forbids leaving failing tests. | **BLOCKED** |

### P1 — major

| ID | Finding | Evidence | Status |
| --- | --- | --- | --- |
| P1-1 | **Viewport lazy-load prefetch was structurally impossible.** `HomeViewportSection` measured proximity against `MediaQuery.sizeOf(context).height` (the *window*) while the sections live in `Expanded > ListView` beneath a header — wrong origin *and* wrong extent. Separately, `ListView` builds children lazily at `RenderAbstractViewport.defaultCacheExtent = 250.0` px, so a below-fold section was never mounted and could not observe scrolling until it was already 250 px away. The intended "1–1.5 viewport prefetch" could never fire. | `home_viewport_section.dart`; SDK `viewport.dart:180` | **FIX WRITTEN, UNVERIFIED** |
| P1-2 | **Failed section chunk left a permanently blank slot.** `_trigger()` swallowed load errors into `debugPrint` with `_triggered` latched `true` — no retry, and the unhandled rejection fed P0-1. | `home_viewport_section.dart` | **FIX WRITTEN, UNVERIFIED** |
| P1-3 | **Hero hangs on an infinite skeleton on the `/qr` path.** `initState` returned early for `QrInitialParams.isQrPath` without clearing `_heroLoading`, so `HomeHeroBannerSection` stayed in its `isLoading && urls.isEmpty` branch forever. | `home_initial_page.dart` | **FIX WRITTEN, UNVERIFIED** |
| P1-4 | **No production error telemetry.** `FlutterError.onError` only dumps to console; `PlatformDispatcher.instance.onError` only writes `localStorage`. No Sentry/Crashlytics/equivalent for web. Requirement 72. | `app_bootstrap.dart:62–77` | **OPEN** |
| P1-5 | **Release version is a placeholder** (`1.0.0+1`). Requirement 95. | `pubspec.yaml:19` | **OPEN** |
| P1-6 | **Supabase CLI install is broken locally** → migration history / `db lint` / schema-drift audit could not run. Requirement 87. | — | **BLOCKED** |

### P2 — polish / tech debt

| ID | Finding | Evidence |
| --- | --- | --- |
| P2-1 | `next` redirect validation accepts backslash. `next.startsWith('/') && !next.startsWith('//')` passes `/\evil.example`. Not exploitable as an open redirect (go_router navigates internally, yielding a 404), but should also reject `\`. | `customer_login_completion.dart:34` |
| P2-2 | Widespread empty catch blocks. Highest concentrations: `product_model.dart` (58), `store_service.dart` (8), `product_detail_viewmodel.dart` (6), `home_snapshot_cache.dart` (6), `business_detail_page.dart` (5), `desktop_print_orchestrator.dart` (5), `admin_service.dart` (4). Tolerant parsing is defensible in `product_model.dart`; the auth/order/store service ones need targeted review. Requirement 63. | — |
| P2-3 | CSP allows `'unsafe-inline'` and `'unsafe-eval'` in `script-src`. Currently **required** by the Flutter web bootstrap and CanvasKit; documented as accepted risk rather than a defect. | `firebase.json` |
| P2-4 | `HomeScreenGate.prefetch()` is now dead code (zero call sites) but is still asserted by `test/web/web_boot_speed_hints_test.dart:19`. The test pins a method nothing uses. | — |
| P2-5 | `lib/perf/phase*` scratch entrypoints contribute ~20 of the 120 analyzer warnings (unused imports, `dart:html` deprecation, undeclared deps). Consider excluding from analysis. | — |

---

## 4. FIXED IN THIS PASS

All four are **written but not compiled and not tested** — the toolchain was unavailable (§1). Treat as review-ready drafts.

| File | Change |
| --- | --- |
| `ibul_app/web/index.html` | Boot-error takeover scoped to the pre-first-frame window via `isFlutterRuntimeUp()` (checks `bootComplete`, `flt-glass-pane`, `#ibul-loader` removal). Errors are still **always** recorded to `localStorage` — nothing is masked. Error filter extended to match the fingerprinted entry `app.<hash>.js`. |
| `ibul_app/lib/screens/home/home_viewport_section.dart` | Rewritten to use real scrollable geometry: `RenderAbstractViewport.maybeOf(box).getOffsetToReveal(box, 0)` against `position.pixels` / `position.viewportDimension`. Prefetch band expressed as a multiple of the actual viewport (`prefetchViewports = 1.25`), so it is responsive by construction. Chunk failure now surfaces the existing `HomeSectionError` retry and un-latches `_triggered`. Scroll listener detached after trigger. "Nothing loads on first build unless genuinely visible" preserved, so the 0-startup-part budget holds. |
| `ibul_app/lib/screens/home/home_initial_page.dart` | `ListView.cacheExtent` set to one viewport height so below-fold sections mount early enough for proximity prefetch to be possible at all. `/qr` fast-path now clears `_heroLoading` (P1-3). |
| `ibul_app/test/home/home_phase16_startup_regression_test.dart` | **New.** Startup-budget assertions (no eager `HomeScreenGate.prefetch` / `home_entry.loadLibrary` in any boot file; `cacheExtent` present; no `Future.delayed` gating; loader uses `getOffsetToReveal`/`viewportDimension` and not window height), boot-shell scoping assertions, and hero widget tests (empty campaign list must paint hero chrome, not an endless skeleton). |

**Not fixed (deliberately deferred as risky — requirement 100):** payment provider integration, auth architecture, router rewrite, DB migrations, framework/package upgrades.

---

## 5. PHASE 16 STATUS

| Requirement | Result |
| --- | --- |
| **§12 — real `lib/main.dart`, not the perf entrypoint** | **PASS (structural).** `/` → `app_route_table.dart:137` `buildSafeHome` → `app_bootstrap.dart:179` `HomeScreenGate` → `HomeInitialPage`. Phase 16 is already the production home; `phase16_candidate_main.dart` is only a measurement shim over the same `HomeScreenGate`. |
| **§13 — zero eager home-graph load at boot** | **PASS (verified).** Global search found **no** production call site of `HomeScreenGate.prefetch` or `home_entry.loadLibrary`. The only references are the definition itself, `lib/perf/phase15_h7_main.dart`, and tests. |
| **§3 — runtime "Uncaught" crash** | **ROOT CAUSE INFERRED FROM CODE, NOT CONFIRMED IN A BROWSER.** The code defect is real and fixed (P0-1), and it fully explains the reported symptom class. But I could **not** capture the actual console error / stack, so I cannot assert that P0-1 is the *only* cause. Must be re-confirmed in Chrome. |
| **§4/§5 — hero** | **PARTIALLY DIAGNOSED.** The hero is deferred on **both** mobile and desktop (`IbulMobileHomeChrome` and `IbulHeroCampaignRow` both render `DeferredHomeHeroSection`), and it calls `hero_section.loadLibrary()` in the first post-frame. Your premise that "the hero part is not requested" is only consistent with the measured "0 startup parts" if dart2js placed that code in the **main output unit**, in which case `loadLibrary()` resolves with no network request and no part is *needed*. **This was not measured** — the deciding test (grep the built bundles for the marker string `1 SAATTE KAPINDA!`) is BLOCKED. Do this before changing the hero architecture. Separately, a genuine hero hang was found and fixed (P1-3). |
| **§6 — viewport lazy loader** | **ROOT CAUSE FOUND AND FIXED** (P1-1). Both defects are concrete and evidenced. Verification BLOCKED. |
| **§7 — prove chunks load on scroll, not at startup** | **NOT TESTED** (needs real browser network waterfall). |
| **§8 — prefetch distance** | Implemented with real viewport proximity; no `Future.delayed`. Effective distance is bounded by `cacheExtent` (1 viewport). **NOT MEASURED.** |
| **§9 — scroll jank / loadLibrary wall time** | **NOT TESTED.** |
| **§10/§11 — query & image defer** | **PARTIALLY VERIFIED BY CODE READING.** Section data fetches are inside the deferred entry `initState` (e.g. `home_commerce_entry.dart` calls `fetchInitialHomeProductsReport()` in its own `initState`), so they cannot run before the chunk loads. The one eager startup query is the hero banner fetch (`campaign_images`), which is above-fold and intentional. **Not confirmed against a real waterfall.** |
| **§14 — regression budget** | **NOT MEASURED.** |

---

## 6. FUNCTIONAL MATRIX

Honest status. "Code-reviewed" means I read the implementation but did not execute it.

| Area | Status |
| --- | --- |
| Home | NOT TESTED (build produced, never loaded in a browser) |
| Hero | PARTIAL — 1 bug found & fixed; rendering NOT TESTED |
| Search | NOT TESTED |
| Category | NOT TESTED |
| Product | NOT TESTED |
| Cart | NOT TESTED |
| Account / `/hesabim/*` | NOT TESTED |
| Favorites | NOT TESTED |
| Orders | NOT TESTED |
| Rentals / vehicle rental flow | NOT TESTED |
| Login / logout / signup / reset | NOT TESTED |
| Seller panel | NOT TESTED |
| Admin auth boundary | NOT TESTED |
| Vehicle | NOT TESTED |
| Restaurant / waiter / printing | NOT TESTED |
| Routing — real click → URL | **Code-reviewed + automated coverage exists.** `test/app/web_click_routing_test.dart` taps real widgets and asserts `router.routeInformationProvider.value.uri.path` for favorites, account, orders, product (`/urun/:id/:slug`), vehicle (`/arac/:id/:slug`), plus `/home`→`/` redirect, back, and refresh. **The test itself was not executed this pass.** Real browser address-bar confirmation: NOT TESTED. |
| Lazy sections | FIX WRITTEN, NOT TESTED |
| Deep link / refresh / back / forward | NOT TESTED in a browser |

---

## 7. BROWSER / DEVICE MATRIX

| Environment | Status |
| --- | --- |
| Chrome (desktop) | **BLOCKED** — automation tool aborted under process exhaustion |
| Edge / Chromium | **BLOCKED** — not installed / not attempted |
| Firefox | **BLOCKED** |
| Safari | **BLOCKED** |
| Android Chrome | **BLOCKED** — no device/emulator |
| iOS Safari | **BLOCKED** — no device/simulator run |
| Responsive widths 320→1920 | **NOT TESTED** manually. Partial automated coverage exists (`test/widgets/responsive_product_grid_test.dart` asserts no overflow at 360 and 768) but was not executed this pass. |

No browser pass is claimed.

---

## 8. BLOCKED ITEMS — the exact re-run list

Once Opera is closed, these close the gap in one pass:

```bash
cd "ibul_app"

# 1. Verify the four fixes compile (CRITICAL — currently unverified)
flutter analyze --no-fatal-infos --no-fatal-warnings

# 2. Identify the 36 failures + confirm no new ones
flutter test --reporter=json > /tmp/ibul_test.json
flutter test test/home/ test/app/ test/web/

# 3. Dependency audit
flutter pub outdated

# 4. Rebuild and measure
cd .. && ./scripts/build_web_prod.sh
cp -R ibul_app/build/web ibul_app/build/web-preprod-final

# 5. Decide the hero question (main unit vs own part)
grep -l '1 SAATTE KAPINDA' ibul_app/build/web/*.js

# 6. Artifact sizes
ls -la ibul_app/build/web/app.*.js
brotli -c -q 11 ibul_app/build/web/app.*.js | wc -c

# 7. Serve + real Chrome smoke (needs SPA rewrite for deep links)
npx serve -s ibul_app/build/web -l 8099
```

Additionally required and **not obtainable on this machine**:

- **Staging Supabase project** with seeded USER A / USER B / SELLER A / SELLER B / non-admin, for the cross-account and privilege-escalation tests (§26, §27). These must never be run against production.
- **PSP sandbox credentials** for §37.
- **Working Supabase CLI** for §87.

---

## 9. DATABASE STATUS

| Item | Status |
| --- | --- |
| RLS enablement + policy coverage | **NOT VERIFIED** — static review delegated, not returned |
| Cross-account isolation | **NOT TESTED** — needs staging |
| `SECURITY DEFINER` / `search_path` audit | **NOT VERIFIED** |
| Privilege-escalation column guard | Migration `20260915_users_privileged_column_guard.sql` **exists**; coverage **NOT VERIFIED** |
| Storage bucket privacy (KYC docs) | **NOT VERIFIED** |
| Constraints / indexes | **NOT VERIFIED** |
| Migration history / drift | **BLOCKED** (CLI broken) |

No destructive operation, no migration, and no production DB connection was performed.

---

## 10. BUILD STATUS

**Production build: SUCCEEDED** (before the machine ran out of process slots).

```
scripts/build_web_prod.sh → scripts/build_web_hosting.sh
flutter build web --release --target lib/main.dart \
  --pwa-strategy=none --no-web-resources-cdn --no-wasm-dry-run
```

| Item | Value |
| --- | --- |
| Compile time | 58.1 s |
| Entry JS (fingerprinted) | `app.e3026e16c72c6884.js` |
| Deferred parts fingerprinted | copied **642**, uriRewrites **355** |
| `CupertinoIcons.ttf` tree-shake | 257 628 → 2 460 B (99.0%) |
| `MaterialIcons-Regular.otf` tree-shake | 1 645 184 → 124 432 B (92.4%) |
| Empty `flutter_service_worker.js` | removed (pwa-strategy=none) |
| Raw / brotli / gzip sizes | **NOT MEASURED** |
| `build/web-preprod-final` copy | **NOT CREATED** |

**Important:** this build predates the four fixes in §4. It must be rebuilt before any deploy.

**No deploy was performed. `firebase deploy` was never executed.**
