# Verified Architecture Notes

## Home page (`ibul_app/lib/screens/home/`)

- `home_initial_page.dart` lists deferred sections in order, each wrapped in
  `HomeViewportSection`: Commerce → Discovery → Vehicles → Promotions → Lower.
- `HomeViewportSection` placeholder is an empty `SizedBox(placeholderHeight)`
  (not a skeleton); it is required for the scroll/3s-fallback lazy trigger.
- Promotions (`entries/home_promotions_entry.dart`) = ad card groups +
  `DeferredHomeSponsoredSection` → `sections/home_section_sponsored.dart` →
  `widgets/sponsored_product_lists_section.dart` ("Öne Çıkan Listeler").
- `SponsoredProductListsSection`: loading shows `_SponsoredListsSectionSkeleton`
  unless `suppressSkeleton`; empty → `SizedBox.shrink`; error → retry box.
  Fetch has a 10s `.timeout` (relevant for widget tests' pending timers).
- Product rail cards on home: 220×348, gap 12 (`sections/home_section_full_rail.dart`).

## Category page

- Web grid in `screens/category_products_page.dart` uses the home card size
  (220×348) with width-based column count; mobile grid unchanged.
- `app/marketplace_route_pages.dart` `CategoryRoutePage` dismisses the web boot
  loader (direct `/kategori` URLs never mount home).

## Admin › Sistem Düzeni (content hub)

- Entry: `lib/features/admin/panel/pages/system_layout_page.dart` (8 tabs).
  Shared white UI: `panel/widgets/system_layout_section.dart`.
- Campaign images → `campaign_images` table; hero desktop 264px tall contain
  (crop 996×412), mobile 160px (crop 768×400, falls back to desktop image).
  Hero does not use `link_url`; table has no date/platform columns.
- Categories → `categories` table; products link by name text
  (`products.main_category`/`sub_category`); delete is soft.
- Mobile home shortcuts → `app_categories` (key = fixed `FeatureMenu` action).
  Customer read: `services/home_shortcuts_fetch.dart` → `IbulMobileHomeChrome`
  → `FeatureMenu.resolveConfigs`. `sort_order` column comes from migration.
- Logo: bundled asset only (no DB setting); seller logos = `stores.logo_url`.
- Coupons: `couponDiscoveryBlockReason` (coupon_helpers) mirrors SQL
  `list_discoverable_coupons` (public, not wheel, redeemable, quota).
- Migration `ibul_app/supabase/migrations/20261001_system_layout_content_hub.sql`
  restores `list_daily_deal_products` + `list_discoverable_coupons` (missing
  live → "Günün fırsatı yüklenemedi"), adds `app_categories.sort_order` + RLS.

## Seller › Yazıcı Ayarları › Yazıcı Merkezi tab

- Built by `_buildPrintStationTab` in `lib/screens/seller/kitchen_print_management_page.dart`
  (other 6 tabs live in the same file). Shared layout widgets:
  `features/seller/panel/printer_center/widgets/printer_center_layout.dart`;
  list/summary/jobs cards: `printer_center_sections.dart`.
- State source: page `_loadPrintStationState` → `DesktopPrintOrchestrator.loadSetupSnapshot`
  (`_bridgeReachable/_bridgeHealthy/_localQueueStatus/_remotePrintStationConfig`).
- Red page banner = `RestaurantOfflineBanner` → `RestaurantConnectivityService.mode`
  (`bridgeUnreachable`), same local `/health` but probed separately; page now
  re-probes the service when its snapshot disagrees.
- "Yazıcı Merkezi çevrimiçi" was the *cloud heartbeat* (`isStationOnline`,
  `last_seen_at`), not this device's bridge; now shown only in Bağlantı detayları.
- `hardResetPrinters` deletes all printers, station mappings, cloud role mapping
  and local config (UI label: "Tüm Yazıcı Kayıtlarını Sıfırla").
- Do not wrap cards containing `LayoutBuilder` in `IntrinsicHeight` (assertion).

## Blog (`ibul_app/lib/features/blog/`)

- Routes: `BlogPaths` (`/blog`, `/blog/:slug`, `/blog/onizleme/:id`, `/blog/yazar`);
  `ibul_go_router.dart` + `app_route_table.dart` → deferred `blog_route_pages.dart`.
- Data: `BlogRepository` (RPC only; injectable for tests), media
  `BlogMediaService` → bucket `blog-media`, path `{uid}/blog/...`.
- SQL: `supabase/migrations/20261002_blog_1_schema.sql` … `_5_admin_gate.sql`
  (apply in number order).
  Blog admin = `users.role` super_admin, Genel Operasyon (`admin`, unless
  campaign_content is denied or missing from an active allow-list), or any
  role with `current_admin_has_module('campaign_content')`. An author row is
  only the byline, not the management grant. Edits to published posts live in
  `blog_post_drafts` until `blog_publish_post`; old slugs → `blog_slug_redirects`.
- Content contract: `models/blog_content.dart` ⇄ SQL `blog_content_is_safe`
  ⇄ `scripts/prerender_blog.py` (keep the three in sync).
- Admin menu 'Blog *' (`admin_menu_registry.dart`) → `BlogAdminSection`.
- Crawlable HTML: `prerender_blog.py` runs at the end of `build_web_hosting.sh`
  / `build_web_ci.sh`; needs `firebase.json` `trailingSlash: false`. Static HTML
  refreshes only on deploy. Offline check: PGlite harness in
  `ibul_app/build/blog_sql_check/` (gitignored) writes `fixture.json`.

## Testing

- Run `flutter` outside the sandbox. Widgets using Supabase services need
  `Supabase.initialize` in `setUpAll`.
