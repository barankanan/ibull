# Worklog

## 2026-10-02 — Blog v1 (code done; not applied live, not deployed)

- Decision: live had no blog (no table/RPC/bucket, verified via anon REST).
  Supabase tables + SECURITY DEFINER RPCs; admin = existing
  `current_admin_has_module('campaign_content')`; authors = `blog_authors.user_id`.
  Published edits go to `blog_post_drafts` (live row untouched until publish).
- Routes `/blog`, `/blog/:slug`, `/blog/onizleme/:id`, `/blog/yazar` in
  `ibul_go_router.dart` + `app_route_table.dart` (deferred library).
- Crawlable HTML: hosting is static Firebase (no Functions; Supabase serves
  HTML as text/plain). Chosen: build-time prerender `scripts/prerender_blog.py`
  writes `build/web/blog/**/index.html` + `blog-sitemap.xml` from public RPCs.
  Limits: new/unpublished posts change static HTML only on next web deploy;
  unknown slugs are soft 404 (noindex), not HTTP 404.
- SQL: `supabase/migrations/20261002_blog_1_schema.sql`, `_2_rpc_public`,
  `_3_rpc_write`, `_4_rpc_admin` (apply in order; NOT applied live). Verified with PGlite harness
  `ibul_app/build/blog_sql_check/check.mjs` (gitignored, stubs auth/storage/
  `current_admin_has_module`): 49/49 permission/flow checks pass.
- Stage 2–4 UI: `lib/features/blog/**` (reader, editor, admin views); admin menu
  'Blog *' items (moduleKey campaignContent) → `BlogAdminSection`; footer
  'Kurumsal' → 'Blog'.
- Hosting: `prerender_blog.py` hooked at end of `build_web_hosting.sh` and
  `build_web_ci.sh` (skips with exit 0 if RPCs missing — live returns 404 now).
  New RPC `blog_list_public_redirects` → old-slug pages (meta refresh, noindex).
  `firebase.json`: `trailingSlash: false` (emulator: `/blog/<slug>` 200 from
  prerender, `/blog/<slug>/` 301, other SPA paths unchanged) and CSP media-src
  `https://*.supabase.co`. Harness now 52/52 and writes `fixture.json`
  (`prerender_blog.py <dir> --fixture ...` for offline checks).
- Verified: analyze clean; `test/blog` 16/16 (fake repo editor flow: blocks →
  save → reopen order → review → admin preview/publish → list/category/search;
  failed save keeps content + backup; 390/820/1440 no overflow, 1/2/3 grid,
  columns stack < 1000px). Release `build_web_hosting.sh` OK. Emulator +
  browser: `/blog/<slug>` serves article HTML/meta/JSON-LD, Flutter boots on the
  blog route (live shows "altyapı kurulmamış"). 13 failures in app/auth/home/
  seller tests come from other in-progress diffs (MarketplacePaths int→String,
  provider count 6, seller test MaterialApp home+'/' assert), not blog.
- Next: apply 4 migrations (staging first), add `blog_authors` rows, run the
  acceptance flow live with a draft only, then deploy so prerender picks posts
  up; optionally list `blog-sitemap.xml` in Search Console.
- 2026-10-02 fix: "Bu bölüm için blog yetkiniz yok" is the successful
  `blog_my_access` path with `is_admin=false` (not a load/RPC error). Cause:
  `blog_is_admin()` required `campaign_content`, while the panel treats role
  `admin` (Genel Operasyon) and `super_admin` as full admins even when that
  module is absent from the catalog. `20261002_blog_5_admin_gate.sql` aligns
  the function; a bad payload or missing session is now an error, not a denial.
  Harness covers genel admin without the module, super_admin, marketing,
  support, allow-list, denial, and a normal user. NOT applied live.
- 2026-10-02 editor: draft save no longer requires a title or byline
  (`20261002_blog_6_draft_save.sql`; publish still checks title, author, cover alt).
  Blocks can be inserted, focused, converted (paragraph/list/quote/heading) and
  undone. Image crop is per-post metadata (`crop`/`fit`/`align`/`width`), original
  URL kept; reader and prerender use the same fractions. Columns already hold a
  block list; blocks can move to the next column and removed columns keep their
  blocks. Harness: authorless draft saves, publish without a title fails.
  `test/blog` green. Crop dialog was not driven in a widget test (network image).
  Migration 6 not applied live. No deploy.

## 2026-10-02 — Seller Yazıcı Merkezi tab redesign

- Conflict cause: banner (connectivity singleton, probed once at mount) vs tab
  (page snapshot) read the same bridge at different times; green "Çevrimiçi"
  tile came from the cloud heartbeat of the station, not the local bridge.
- Done: single 1280px column, header + 4 status tiles, switch-only auto print
  with separate readiness text, role card, compact printer table, mapping/jobs
  pair, one Test ve Tanılama card with collapsed setup/technical/advanced.
- Verified: analyze clean; page + summary tests (12) pass; temp screenshot test
  at 1440/1024/390 with 0/1/3/8 printers, no overflow (before: 390 overflowed).
  3 `test/printer_setup` failures pre-exist on HEAD. No physical print tested.

## 2026-10-01 — Admin Sistem Düzeni content hub

- Causes: shortcut edits never reached customers (`FeatureMenu` got no remote
  data); campaign tab had two nested `Expanded` scroll areas; home coupon card
  used only `listMine`; `list_daily_deal_products`/`list_discoverable_coupons`
  return PGRST202 live.
- Done: 8-tab white hub, reorderable campaign images + preview, shortcut CRUD
  with order, category delete shows linked product count, coupon "Ana sayfa"
  column, migration (NOT applied).
- Verified: `test/admin/system_layout_content_hub_test.dart`, analyze clean on
  changed files, real-data widget run at 700/1440 widths. Failing
  coupon-copy test and admin-nav "Genel Bakış" test are pre-existing.
- Open: apply migration; `coupon_claim` does not block wheel coupons server-side;
  both live coupons are wheel coupons, so none show on home.

## 2026-10-01 — Home: stray skeleton below vehicle listings

- Cause: Promotions block built `DeferredHomeSponsoredSection()` without
  `suppressSkeleton`, so the optional sponsored lists showed a title + card
  skeleton while fetching, then collapsed when the result was empty.
- Fix: `home_promotions_entry.dart` passes `suppressSkeleton: true`;
  `deferred_home_sponsored_section.dart` returns `SizedBox.shrink` (not a
  timeout error) while its library is pending and skeleton is suppressed.
- Verified: temporary widget tests (old path shows skeleton; new path none),
  analyze clean on changed files, `test/home`+`test/ads` failures unchanged (6
  pre-existing). `home_boot_core_test.dart` got a final 11s pump to drain the
  sponsored fetch timeout timer.

## Earlier (same session)

- Category route: boot loader never dismissed on direct `/kategori` URLs → fixed
  in `CategoryRoutePage.initState`.
- Category web grid cards matched to home card size (220×348).
