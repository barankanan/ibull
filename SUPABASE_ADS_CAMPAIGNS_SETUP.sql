-- ============================================================
-- ADS CAMPAIGNS SYSTEM - SUPABASE TABLE SETUP
-- Run this entire script in your Supabase SQL Editor.
-- Bu SQL yoksa "Reklam > Taslak Kaydet" kaydedilemez.
-- ============================================================

-- ── 1. CAMPAIGNS ─────────────────────────────────────────────
create table if not exists public.campaigns (
  id                          text        primary key,
  seller_id                   uuid        not null references auth.users(id) on delete cascade,
  store_id                    text,
  name                        text        not null default 'Taslak Kampanya',
  description                 text,
  type                        text        not null default 'product_boost',
  objective                   text        not null default 'product_views',
  status                      text        not null default 'draft',
  billing_model               text        not null default 'cpc',
  daily_budget                numeric(14,2) not null default 0,
  total_budget                numeric(14,2) not null default 0,
  spent_amount                numeric(14,2) not null default 0,
  remaining_balance           numeric(14,2) not null default 0,
  bid_amount                  numeric(14,4) not null default 0,
  currency                    text        not null default 'TRY',
  starts_at                   timestamptz not null default now(),
  ends_at                     timestamptz not null default (now() + interval '14 days'),
  paused_at                   timestamptz,
  approved_at                 timestamptz,
  rejected_at                 timestamptz,
  review_notes                text,
  is_premium_placement_enabled boolean    not null default false,
  use_ai_suggestions          boolean     not null default true,
  frequency_cap_per_user      int         not null default 3,
  targeting_version           int         not null default 1,
  ab_test_enabled             boolean     not null default false,
  metadata                    jsonb       not null default '{}'::jsonb,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now()
);

-- ── 2. CAMPAIGN TARGETS ───────────────────────────────────────
create table if not exists public.campaign_targets (
  id                      text        primary key default gen_random_uuid()::text,
  campaign_id             text        not null references public.campaigns(id) on delete cascade,
  objective               text        not null default 'product_views',
  placements              text[]      not null default '{}',
  categories              text[]      not null default '{}',
  keywords                text[]      not null default '{}',
  city_codes              text[]      not null default '{}',
  geohash_prefixes        text[]      not null default '{}',
  min_price               numeric(14,2),
  max_price               numeric(14,2),
  radius_meters           int,
  event_lookback_days     int         not null default 30,
  frequency_cap_per_day   int         not null default 3,
  retargeting_window_days int         not null default 14,
  metadata                jsonb       not null default '{}'::jsonb,
  unique (campaign_id)
);

-- ── 3. CAMPAIGN ASSETS ────────────────────────────────────────
create table if not exists public.campaign_assets (
  id            text        primary key default gen_random_uuid()::text,
  campaign_id   text        not null references public.campaigns(id) on delete cascade,
  asset_type    text        not null default 'product',
  entity_id     text,
  title         text,
  subtitle      text,
  media_url     text,
  thumbnail_url text,
  deep_link     text,
  placements    text[]      not null default '{}',
  priority      int         not null default 0,
  metadata      jsonb       not null default '{}'::jsonb,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ── 4. AB TEST VARIANTS ───────────────────────────────────────
create table if not exists public.ab_test_variants (
  id               text        primary key default gen_random_uuid()::text,
  campaign_id      text        not null references public.campaigns(id) on delete cascade,
  name             text        not null,
  weight           numeric(5,4) not null default 0.5,
  headline         text,
  cta_label        text,
  asset_overrides  jsonb       not null default '{}'::jsonb,
  target_overrides jsonb       not null default '{}'::jsonb,
  impressions      int         not null default 0,
  clicks           int         not null default 0,
  conversions      int         not null default 0,
  is_control       boolean     not null default false,
  is_active        boolean     not null default true,
  created_at       timestamptz not null default now()
);

-- ── 5. AD METRICS DAILY ───────────────────────────────────────
create table if not exists public.ad_metrics_daily (
  id                    text        primary key default gen_random_uuid()::text,
  campaign_id           text        not null references public.campaigns(id) on delete cascade,
  metric_date           date        not null,
  impressions           int         not null default 0,
  clicks                int         not null default 0,
  detail_views          int         not null default 0,
  favorites             int         not null default 0,
  add_to_carts          int         not null default 0,
  checkouts             int         not null default 0,
  orders                int         not null default 0,
  store_visits          int         not null default 0,
  collection_opens      int         not null default 0,
  notifications_sent    int         not null default 0,
  notifications_opened  int         not null default 0,
  unique_users          int         not null default 0,
  conversions           int         not null default 0,
  spend                 numeric(14,4) not null default 0,
  revenue               numeric(14,4) not null default 0,
  unique (campaign_id, metric_date)
);

-- ── 6. AD WALLET TRANSACTIONS ─────────────────────────────────
create table if not exists public.ad_wallet_transactions (
  id              text        primary key default gen_random_uuid()::text,
  seller_id       uuid        not null references auth.users(id) on delete cascade,
  campaign_id     text        references public.campaigns(id) on delete set null,
  type            text        not null,
  amount          numeric(14,4) not null default 0,
  balance_after   numeric(14,4) not null default 0,
  reference_id    text,
  note            text,
  metadata        jsonb       not null default '{}'::jsonb,
  created_at      timestamptz not null default now()
);

-- ── 7. AD REVENUE LOGS ────────────────────────────────────────
create table if not exists public.ad_revenue_logs (
  id              text        primary key default gen_random_uuid()::text,
  seller_id       uuid        not null references auth.users(id) on delete cascade,
  campaign_id     text        references public.campaigns(id) on delete set null,
  amount          numeric(14,4) not null default 0,
  currency        text        not null default 'TRY',
  event_type      text        not null default 'impression',
  reference_id    text,
  metadata        jsonb       not null default '{}'::jsonb,
  recorded_at     timestamptz not null default now()
);

-- ── 8. CAMPAIGN REVIEWS ───────────────────────────────────────
create table if not exists public.campaign_reviews (
  id          text        primary key default gen_random_uuid()::text,
  campaign_id text        not null references public.campaigns(id) on delete cascade,
  seller_id   uuid        not null references auth.users(id) on delete cascade,
  reviewer_id uuid        references auth.users(id) on delete set null,
  status      text        not null default 'pending',
  note        text,
  reasons     text[]      not null default '{}',
  reviewed_at timestamptz,
  metadata    jsonb       not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);

-- ── 9. ADMIN REVIEW LOGS ──────────────────────────────────────
create table if not exists public.admin_review_logs (
  id          text        primary key default gen_random_uuid()::text,
  campaign_id text        references public.campaigns(id) on delete set null,
  reviewer_id uuid        references auth.users(id) on delete set null,
  action      text        not null,
  note        text,
  metadata    jsonb       not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);

-- ── 10. AD FREQUENCY LOGS ─────────────────────────────────────
create table if not exists public.ad_frequency_logs (
  id          text        primary key default gen_random_uuid()::text,
  campaign_id text        not null references public.campaigns(id) on delete cascade,
  user_id     uuid        references auth.users(id) on delete cascade,
  placement   text        not null,
  shown_at    timestamptz not null default now()
);

-- ── 11. USER INTERESTS ────────────────────────────────────────
create table if not exists public.user_interests (
  id          text        primary key default gen_random_uuid()::text,
  user_id     uuid        not null references auth.users(id) on delete cascade,
  category    text        not null,
  score       numeric(8,4) not null default 1.0,
  source      text        not null default 'implicit',
  metadata    jsonb       not null default '{}'::jsonb,
  updated_at  timestamptz not null default now(),
  unique (user_id, category)
);

-- ── 12. USER PRODUCT EVENTS ───────────────────────────────────
create table if not exists public.user_product_events (
  id          text        primary key default gen_random_uuid()::text,
  user_id     uuid        references auth.users(id) on delete cascade,
  product_id  text,
  store_id    text,
  event_type  text        not null,
  campaign_id text        references public.campaigns(id) on delete set null,
  metadata    jsonb       not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

-- ── INDEXES ───────────────────────────────────────────────────
create index if not exists campaigns_seller_id_idx     on public.campaigns(seller_id);
create index if not exists campaigns_status_idx        on public.campaigns(status);
create index if not exists campaigns_starts_at_idx     on public.campaigns(starts_at desc);
create index if not exists campaign_targets_cid_idx    on public.campaign_targets(campaign_id);
create index if not exists campaign_assets_cid_idx     on public.campaign_assets(campaign_id);
create index if not exists ad_metrics_daily_cid_idx    on public.ad_metrics_daily(campaign_id);
create index if not exists ad_wallet_txn_seller_idx    on public.ad_wallet_transactions(seller_id);
create index if not exists ad_freq_logs_cid_user_idx   on public.ad_frequency_logs(campaign_id, user_id);
create index if not exists user_interests_uid_idx      on public.user_interests(user_id);
create index if not exists user_prod_events_uid_idx    on public.user_product_events(user_id);

-- ── ROW LEVEL SECURITY ────────────────────────────────────────
alter table public.campaigns           enable row level security;
alter table public.campaign_targets    enable row level security;
alter table public.campaign_assets     enable row level security;
alter table public.ab_test_variants    enable row level security;
alter table public.ad_metrics_daily    enable row level security;
alter table public.ad_wallet_transactions enable row level security;
alter table public.ad_revenue_logs     enable row level security;
alter table public.campaign_reviews    enable row level security;
alter table public.admin_review_logs   enable row level security;
alter table public.ad_frequency_logs   enable row level security;
alter table public.user_interests      enable row level security;
alter table public.user_product_events enable row level security;

-- campaigns: seller can manage own campaigns
create policy "campaigns_seller_select" on public.campaigns
  for select using (auth.uid() = seller_id);
create policy "campaigns_seller_insert" on public.campaigns
  for insert with check (auth.uid() = seller_id);
create policy "campaigns_seller_update" on public.campaigns
  for update using (auth.uid() = seller_id);
create policy "campaigns_seller_delete" on public.campaigns
  for delete using (auth.uid() = seller_id);

-- campaign_targets: via campaign ownership
create policy "campaign_targets_seller_all" on public.campaign_targets
  for all using (
    exists (select 1 from public.campaigns c where c.id = campaign_id and c.seller_id = auth.uid())
  );

-- campaign_assets: via campaign ownership
create policy "campaign_assets_seller_all" on public.campaign_assets
  for all using (
    exists (select 1 from public.campaigns c where c.id = campaign_id and c.seller_id = auth.uid())
  );

-- ab_test_variants: via campaign ownership
create policy "ab_test_variants_seller_all" on public.ab_test_variants
  for all using (
    exists (select 1 from public.campaigns c where c.id = campaign_id and c.seller_id = auth.uid())
  );

-- ad_metrics_daily: seller can read own campaign metrics
create policy "ad_metrics_daily_seller_select" on public.ad_metrics_daily
  for select using (
    exists (select 1 from public.campaigns c where c.id = campaign_id and c.seller_id = auth.uid())
  );

-- ad_wallet_transactions: seller can read own
create policy "ad_wallet_txn_seller_select" on public.ad_wallet_transactions
  for select using (auth.uid() = seller_id);

-- ad_revenue_logs: seller can read own
create policy "ad_revenue_logs_seller_select" on public.ad_revenue_logs
  for select using (auth.uid() = seller_id);

-- campaign_reviews: seller can read own
create policy "campaign_reviews_seller_select" on public.campaign_reviews
  for select using (auth.uid() = seller_id);

-- ad_frequency_logs: users can read own
create policy "ad_freq_logs_user_select" on public.ad_frequency_logs
  for select using (auth.uid() = user_id);

-- user_interests: users can manage own
create policy "user_interests_user_all" on public.user_interests
  for all using (auth.uid() = user_id);

-- user_product_events: users can insert own
create policy "user_prod_events_user_insert" on public.user_product_events
  for insert with check (auth.uid() = user_id);
create policy "user_prod_events_user_select" on public.user_product_events
  for select using (auth.uid() = user_id);
