# İBUL — WEB PERFORMANCE, FINAL CANDIDATE

**Date:** 2026-09-26 · **Branch:** `perf/web-wasm-secure-storage` · **Entrypoint under test:** `ibul_app/lib/main.dart`

---

## ⚠️ MEASUREMENT STATUS: NOT PERFORMED

**No performance numbers were collected in this pass.** Requirement 15 asks for 5 cold Lighthouse runs, every run reported, median + range. **Zero runs were executed.**

Cause: the machine's per-user process table was exhausted by ~950 leaked zombie processes (parent: Opera PID 1911, 26-day uptime) against a `kern.maxprocperuid` of 1333. `flutter`, `clang`, `sandbox-exec` and the browser automation tool all failed to `fork()`. See `PREPROD_AUDIT.md` §1.

The "Final candidate" column below is therefore **empty on purpose**. It is not an oversight and must not be filled in with estimates. Per requirement 15, cherry-picking a single favourable run is also forbidden — all five runs must be reported when they are taken.

---

## 1. BASELINE HISTORY (supplied, not re-measured this pass)

| Metric | Phase 5 | H3 (old home) | Phase 16 candidate | **Final candidate** |
| --- | --- | --- | --- | --- |
| Scripting | NOT SUPPLIED | 2.045 s | 1.572 s (clean median) | **NOT MEASURED** |
| Script evaluation | NOT SUPPLIED | 2.265 s | 1.734 s | **NOT MEASURED** |
| Largest task | NOT SUPPLIED | 748 ms | 461 ms | **NOT MEASURED** |
| Total Blocking Time | NOT SUPPLIED | 1.662 s | 1.115 s | **NOT MEASURED** |
| Speed Index | NOT SUPPLIED | 5.704 s | 6.526 s | **NOT MEASURED** |
| Requests | NOT SUPPLIED | 201 | 16 | **NOT MEASURED** |
| Home startup deferred parts | NOT SUPPLIED | 185 | 0 | **NOT MEASURED** |
| Transfer | NOT SUPPLIED | 3.835 MB | 3.634 MB | **NOT MEASURED** |
| main JS (brotli) | NOT SUPPLIED | NOT SUPPLIED | 1.178 MB | **NOT MEASURED** |
| FCP | NOT SUPPLIED | NOT SUPPLIED | NOT SUPPLIED | **NOT MEASURED** |
| LCP | NOT SUPPLIED | NOT SUPPLIED | NOT SUPPLIED | **NOT MEASURED** |
| TTI | NOT SUPPLIED | NOT SUPPLIED | NOT SUPPLIED | **NOT MEASURED** |
| First Flutter frame | NOT SUPPLIED | NOT SUPPLIED | NOT SUPPLIED | **NOT MEASURED** |
| Shell removal | NOT SUPPLIED | NOT SUPPLIED | NOT SUPPLIED | **NOT MEASURED** |

Phase 5 figures were not provided in the brief and were not recoverable from the repo.

### Note on the Phase 16 baseline itself

The Phase 16 column was produced from `lib/perf/phase16_candidate_main.dart`, which mounts the **same** `HomeScreenGate` as production but through `runPhase15Home` — a reduced shell (`buildCustomerProviders()`, `createPhase14Router`) rather than the full production tree (`buildAppProviders()`, `IbulMaterialApp`, `createIbulGoRouter`, route observers, `IbulProgressiveBootApp`). The real `lib/main.dart` mounts strictly more at boot. **Expect the production candidate to be somewhat worse than the Phase 16 column**; treating Phase 16 as the production baseline would be optimistic.

Also relevant to the reported "0 startup parts": measurements were taken under Lighthouse **mobile** emulation. At mobile width `IbulChrome.isWebOf(context)` is false, so `IbulHeroCampaignRow` is not in the tree at all and the layout differs from desktop. Desktop startup-part count was never measured.

---

## 2. BUILD FACTS (verified — the one thing that did run)

```
scripts/build_web_prod.sh → scripts/build_web_hosting.sh
flutter build web --release --target lib/main.dart \
  --pwa-strategy=none --no-web-resources-cdn --no-wasm-dry-run
```

| Item | Value |
| --- | --- |
| Result | **SUCCESS** |
| Compile time | 58.1 s |
| Flutter / Dart | 3.41.3 / 3.11.1 |
| Entry JS hash | **`app.e3026e16c72c6884.js`** |
| Deferred parts fingerprinted | copied **642**, uriRewrites **355** |
| `CupertinoIcons.ttf` | 257 628 → 2 460 B (99.0% tree-shaken) |
| `MaterialIcons-Regular.otf` | 1 645 184 → 124 432 B (92.4% tree-shaken) |
| Service worker | empty `flutter_service_worker.js` removed |

**NOT MEASURED:** entry JS raw / gzip / brotli size, total part size, canvaskit + `canvaskit.wasm` size, font file count/weights/KB, and the sizes of `urun-parcala.png` / `sana-ozel.png` / `gorsel-zeka.png` / `yakin-lokasyon.png`.

⚠️ **This artifact predates the four code fixes and must be rebuilt.** `build/web-preprod-final` was **not** created.

---

## 3. ARCHITECTURAL WORK DONE (code-level, unverified by measurement)

Three defects were found by reading the code. Each has a concrete mechanism; none is speculative. All fixes are **written but not compiled or tested**.

### 3.1 Prefetch was structurally impossible — two independent causes

**Cause A — wrong viewport basis.** `HomeViewportSection._evaluate()` measured against the *window*:

```dart
final top = box.localToGlobal(Offset.zero).dy;
final viewport = MediaQuery.sizeOf(context).height;   // window, not the scrollable
final intersects = top < viewport && top + height > 0;
```

The sections live in `SafeArea > Column > Expanded > ListView`, beneath `WebHeader`/`CustomHeader` and above a `BottomNavigationBar`. So the window height is wrong as **both** origin and extent. Consequences in both directions: on a tall window a section below the visible fold can satisfy `top < viewport` and load **at startup** (inflating the 0-part budget); on mobile with a tall header the prefetch band is displaced.

Replaced with true scrollable geometry:

```dart
final viewport = RenderAbstractViewport.maybeOf(box);
final revealOffset = viewport.getOffsetToReveal(box, 0).offset;
final viewportExtent = position.viewportDimension;
final distanceAhead = revealOffset - (position.pixels + viewportExtent);
```

`distanceAhead <= 0` ⇒ genuinely visible. `distanceAhead <= viewportExtent * prefetchViewports` ⇒ inside the prefetch band. Because the band is a multiple of the **actual** viewport, it is responsive across mobile/tablet/desktop with no per-breakpoint constants, and there is **no `Future.delayed`** anywhere in the path (requirement 8).

**Cause B — the sections were never mounted.** This is the more fundamental one. `ListView(children: [...])` builds children lazily through `SliverChildListDelegate`, bounded by `cacheExtent`, whose default is:

```dart
// flutter/lib/src/rendering/viewport.dart:180
static const double defaultCacheExtent = 250.0;
```

A below-fold `HomeViewportSection` therefore had **no `State`, no `initState`, and no scroll listener** until it was already within 250 px of the viewport. It is impossible to prefetch "1–1.5 viewports ahead" from a widget that does not exist yet — the ceiling was 250 px, and at that distance the chunk arrives after the user is already looking at the gap.

Fixed by giving the `ListView` one viewport of cache:

```dart
cacheExtent: MediaQuery.sizeOf(context).height,
```

This is safe **only because Cause A was fixed first**: sections now mount early but, being correctly measured as not-visible and with `_userScrolled == false`, they do not trigger at startup. The 0-startup-part property is preserved by construction. Effective prefetch distance is `min(cacheExtent, prefetchViewports × viewportExtent)` ≈ **1 viewport**, inside the 1–1.5 target.

**Honest caveat.** On a tall desktop window the commerce section (placeholder 396 px) may genuinely fall inside the first viewport, in which case it will load at startup and desktop startup parts will be ≥ 1. That is correct behaviour — a visible section must load — but it means the "0 parts" figure is mobile-specific and should be reported per form factor.

### 3.2 Chunk-failure handling

Load failure previously latched `_triggered = true` and swallowed the error, leaving a permanently blank slot and an unhandled rejection that the boot shell escalated into a full-page error (see `SECURITY_AUDIT.md` SEC-001/002). Now un-latches and renders `HomeSectionError` with a working retry.

### 3.3 Hero

Two things, and they should not be conflated:

**(a) A real bug, fixed.** On the `/qr` path `initState` returned before `_loadHero()` without clearing `_heroLoading`, so `HomeHeroBannerSection` stayed in its `isLoading && bannerImageUrls.isEmpty` branch → skeleton forever.

**(b) The premise in the brief is unconfirmed.** The brief states "the hero slot is in the tree but the hero part is not requested. This is wrong." Code reading shows the hero is reached via `DeferredHomeHeroSection` on **both** form factors (`IbulMobileHomeChrome` → `DeferredHomeHeroSection`; `IbulHeroCampaignRow` → same) and that it calls `hero_section.loadLibrary()` from a first-frame `addPostFrameCallback`. That call is unconditional. So "0 startup parts" and "no hero part requested" are simultaneously true **only if dart2js placed `home_section_hero_banner.dart` in the main output unit** — in which case `loadLibrary()` resolves immediately with no network request and no part is *needed*. That would make the observation correct and harmless rather than a defect.

**This was not measured**, so the hero architecture was deliberately left alone (requirement 75 warns against any change that reintroduces the 185-part graph). The deciding one-liner:

```bash
grep -l '1 SAATTE KAPINDA' ibul_app/build/web/*.js
```

- Match in `app.<hash>.js` → hero is in the main unit; nothing to fix; the brief's §4 concern dissolves.
- Match in a `*.part.js` → the hero does cost a round trip on the LCP element, and statically linking `home_section_hero_banner.dart` (dropping `deferred as`) is the minimal fix, at the cost of pulling `carousel_slider` into the main bundle. Measure entry-bundle delta before accepting.

Do this before touching hero code.

---

## 4. TARGETS vs ACTUAL (requirement 14)

| Metric | Target | Actual |
| --- | --- | --- |
| Home-triggered startup parts | 0 | **NOT MEASURED** |
| Requests | 16–25 | **NOT MEASURED** |
| Largest task | < 500 ms | **NOT MEASURED** |
| TBT | < 1.0 s ideal, < 1.2 s acceptable | **NOT MEASURED** |
| Scripting | < 1.4 s | **NOT MEASURED** |
| Speed Index | < 5.5 s min, < 5.2 s target | **NOT MEASURED** |
| FCP | 1.0–1.2 s | **NOT MEASURED** |
| LCP | 1.1–1.5 s | **NOT MEASURED** |
| Transfer | ≤ 3.634 MB | **NOT MEASURED** |
| main JS brotli | ≈ 1.178 MB, no big regression | **NOT MEASURED** |

**Performance gate: cannot be evaluated.**

Note that Speed Index already **regressed** between H3 (5.704 s) and Phase 16 (6.526 s) in the supplied data, against a target of < 5.5 s. Phase 16 traded a large Speed Index regression for its scripting/TBT/request wins. That trade is unresolved and the deferred-placeholder design is the likely cause: five `SizedBox` placeholders mean the above-fold paint completes with large empty regions, which Speed Index penalises. This deserves explicit attention — it is a *design* consequence, not noise, and it will not be fixed by the three code fixes above.

---

## 5. ITEMS NOT ADDRESSED

| Req | Item | Status |
| --- | --- | --- |
| 9 | `loadLibrary` wall time, frame drops, UI freeze per module; < 500 ms freeze | **NOT MEASURED** |
| 11 | Image defer — confirm vehicle/coupon/ads/sponsor/footer images absent from the startup waterfall | **NOT MEASURED** |
| 16 | `ibul_flutter_first_frame` / `ibul_shell_removed` marks in the production build; HTML-shell-visible → first-frame → shell-removed → hero-visible timeline | **NOT MEASURED.** Code path verified: `markFlutterFirstFrame()` and `dismissWebBootLoader()` are called from a real `addPostFrameCallback` in `HomeInitialPage.initState` — frame-driven, not timer-driven, which satisfies the intent of requirement 16 |
| 73 | main.dart.js raw + brotli | **NOT MEASURED** |
| 74 | Request budget; below-fold chunks absent at startup | **NOT MEASURED** |
| 76 | Non-critical PNGs kept out of startup; WebP/AVIF only on measured gain | **NOT MEASURED** |
| 77 | Startup font count / KB / weights | **NOT MEASURED** |
| 78 | Google GSI requested before login is opened | **NOT MEASURED** |
| 79 | CanvasKit cost | **NOT MEASURED.** No renderer change was made, as instructed |
| 81 | Final JS hash + sizes | Hash known (`app.e3026e16c72c6884.js`, pre-fix); sizes **NOT MEASURED** |
| 90 | N+1 / duplicate queries on home/account/seller | **NOT AUDITED** |

---

## 6. HOW TO COMPLETE THIS DOCUMENT

1. Clear the process-table blocker (quit Opera PID 1911, or reboot).
2. `flutter analyze` + `flutter test` — the four fixes are **unverified**; do not measure unverified code.
3. `./scripts/build_web_prod.sh`, then `cp -R ibul_app/build/web ibul_app/build/web-preprod-final`.
4. Record the new entry hash and its raw/gzip/brotli sizes.
5. Settle the hero output-unit question with the `grep` above.
6. Serve with HTTP/2 + brotli and **SPA rewrite** (`npx serve -s`; plain `python3 -m http.server` will 404 on `/urun/...` and is not a valid harness for deep links).
7. 5 cold Lighthouse mobile-simulate runs. **Report all five**, plus median and range. Investigate any `NO_LCP`.
8. From the network waterfall, prove per requirement 7: at load, none of commerce/discovery/vehicle/promotions/lower is requested; then each appears as its section is approached.
9. Record the four boot marks and confirm desktop vs mobile startup-part counts separately.
