# İBUL — LAUNCH CHECKLIST

**Date:** 2026-09-26 · **Branch:** `perf/web-wasm-secure-storage` · **HEAD:** `5b44d30`

**Rule applied:** a box is ticked only if the check was **actually executed and passed** in this pass. Nothing is ticked on inference, on "the code looks right", or on a previous session's result.

---

## VERDICT

- [ ] **SAFE PRODUCTION CANDIDATE**

**NO.** Do not deploy. Two independent reasons: unresolved P0 items, and an audit that could not be completed because the machine ran out of process slots (~950 zombies parented by Opera PID 1911 against a 1333 per-user cap).

---

## GATES

- [x] **Build** — `scripts/build_web_prod.sh` succeeded from the real `lib/main.dart`. Entry `app.e3026e16c72c6884.js`, 642 deferred parts fingerprinted, 58.1 s.
      ⚠️ Ticked for *the build that ran*. It **predates the four code fixes** and must be rebuilt. `build/web-preprod-final` was not created, and no artifact sizes were measured.

- [ ] **Analyze** — `flutter analyze` gave **0 errors / 120 warnings+infos**, but that run happened **before** the four fixes. Post-fix analyze could not run (`flutter: fork: Resource temporarily unavailable`). **The edited code has never been compiled.**

- [ ] **Tests** — one full run completed earlier: **2238 passed / 36 failed**. Only the tail was captured, so 35 of the 36 failures are unidentified. The one known failure is `test/mixed_service_dialog_test.dart` → *"template customization starts empty and saves only selected child items"* (finder for key `mixed-service-option-plus-portion-1` matched 0 widgets). Re-runs are blocked; requirement 83 forbids shipping with failing tests.

- [ ] **Routing** — automated real-click coverage **exists and is good** (`test/app/web_click_routing_test.dart` taps real widgets and asserts the router URI for favorites, account, orders, `/urun/:id/:slug`, `/arac/:id/:slug`, plus `/home`→`/`, back, refresh). It was **not executed** this pass, and no real browser address-bar verification was done.

- [ ] **Auth** — signup / login / logout / session restore / wrong password / password reset / expired session / refresh token / multi-tab / protected route / login+logout redirect: **none executed.** Google login untested.

- [ ] **RLS** — not verified. No policy inventory completed, no cross-account test run. Requires a staging project with seeded USER A/B and SELLER A/B; must never be run against production.

- [ ] **Payment** — **not determined.** Whether a real PSP exists, and whether any path can produce a "successful payment" / reserved state / seller credit without one, is unknown. Requirement 38 makes this a hard blocker in either direction. **Highest-priority open item.**

- [ ] **Rental** — full flow (dates → delivery → customer info → documents → summary → contract → seller approval → payment window → payment → reserved → cancel/refund) not executed. Availability state machine and double-book race untested.

- [ ] **Seller** — login, store switch, product add/edit, image upload, inventory, orders, ads, coupons, home feature campaign, approval status, finance, cross-store isolation: none executed.

- [ ] **Admin** — non-admin blocked at the **backend** (not just hidden in UI) not verified. Admin action audit trail not verified.

- [ ] **Storage** — KYC / driver-licence / ID bucket privacy, signed-URL expiry, upload size/MIME/extension validation, `reservation_id + doc_type` uniqueness: none verified.

- [ ] **Security** — mixed. Verified PASS: no service-role key in the client; `.env` gitignored with only `.env.example` tracked; `next` open-redirect validation; web-shell input safety (no `innerHTML`/`eval`/`document.write`, query handled by a plain HTML form); hosting headers (HSTS, nosniff, `X-Frame-Options: DENY`, Referrer-Policy, Permissions-Policy, CSP with `frame-ancestors 'none'`). **Not verified:** RLS, privilege escalation, RPC `SECURITY DEFINER`/`search_path` audit, storage privacy, payment, raw card data, cross-store access, secret scan of git history, secret scan of the built bundle, Google/Maps key restrictions.

- [ ] **Performance** — **zero** Lighthouse runs executed. Requirement 15 asks for 5 cold runs with all runs reported; none were taken. No metric in the final-candidate column of `PERFORMANCE_FINAL.md` is filled.

- [ ] **Monitoring** — **FAIL (known).** `FlutterError.onError` and `PlatformDispatcher.instance.onError` are installed, but the only sinks are the browser console and `localStorage`. No Sentry/Crashlytics/equivalent. Production failures are invisible. (`app_bootstrap.dart:62–77`)

- [ ] **Backup** — Supabase backup/PITR configuration not inspected. Out of reach from the repo.

- [ ] **Rollback** — plan drafted below but **not rehearsed**. Firebase previous-release rollback was never exercised.

- [ ] **Preview smoke** — no preview channel deploy, no local HTTP/2 preprod smoke test. Browser automation aborted under process exhaustion.

**Ticked: 1 of 17** (and that one with a caveat).

---

## MUST-CLOSE BEFORE RELEASE

| # | Item | Why |
| --- | --- | --- |
| 1 | Clear the process-table blocker (quit Opera PID 1911, or reboot) | Everything below is gated on it |
| 2 | `flutter analyze` + `flutter test` on the edited code | Four fixes are **uncompiled and untested** |
| 3 | Identify and resolve all 36 test failures | Requirement 83 |
| 4 | Settle the payment question | Requirement 38 — hard blocker either way |
| 5 | RLS policy inventory + cross-account attack test on **staging** | Requirements 25–27 |
| 6 | Confirm KYC document bucket is private, signed URLs expire | Requirement 33 |
| 7 | Scan git history and the built bundle for secrets | Requirement 23; mark ROTATION NEEDED on any hit |
| 8 | Wire real error telemetry | Requirement 72 |
| 9 | Set a real `pubspec` version (still `1.0.0+1`) | Requirement 95 |
| 10 | 5 cold Lighthouse runs on the rebuilt artifact | Requirement 15 |
| 11 | Real Chrome smoke: routing clicks, hero visibility, lazy-section waterfall | Requirements 7, 17, 86 |
| 12 | Repair the local Supabase CLI, then migration history + `db lint` | Requirement 87 |

---

## ROLLBACK PLAN (drafted, not rehearsed)

**Hosting.** Firebase Hosting keeps prior releases per site. To revert:

```bash
firebase hosting:releases:list --project ibul-ecommerce
# then roll back to the previous release in the Firebase console
# (Hosting → release history → ⋮ → Rollback)
```

This is fast and safe because `firebase.json` sets `no-cache` on `/`, `/index.html`, `flutter_bootstrap.js`, `flutter.js` and `version.json`, so clients pick up the reverted HTML on next load. Hashed assets (`app.<hash>.js`, `main.dart.js_*.part.<digest>.js`) are `immutable`, but their names change per build, so a rollback serves the previous names cleanly with no poisoning risk.

**Service worker.** `--pwa-strategy=none` is used, the build script deletes an empty `flutter_service_worker.js`, and `web/index.html` actively unregisters any surviving `flutter_service_worker` registration. Users should not be pinned to a stale build. **Not verified against a real previously-deployed SW.**

**Database.** No migration is to be run as part of this release. If one becomes necessary, prefer forward-fix over rollback: additive, nullable-by-default changes only, so the previous app build stays compatible with the new schema. Never pair a destructive migration with a release you might roll back.

**Feature flags.** Any feature not covered by the checklist above should be gated off rather than shipped dark. `AppRuntimeConfig` already carries `safeBootMode` and `bootStage`, which give a degraded-boot escape hatch. A feature-flag inventory was **not** produced (requirement 53 — the route status table READY/BETA/BLOCKED/HIDDEN was not completed).

---

## PRODUCTION DEPLOY COMMAND — FOR REFERENCE ONLY, DO NOT RUN

Not executed in this pass, and must not be run until the verdict above flips to YES.

```bash
scripts/build_web_prod.sh
firebase deploy --only hosting:ibul --project ibul-ecommerce
```
