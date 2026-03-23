create extension if not exists pgcrypto;

create or replace function public.is_admin_user(target_user_id uuid default auth.uid())
returns boolean
language plpgsql
stable
as $$
declare
  role_key text;
begin
  if target_user_id is null then
    return false;
  end if;

  if to_regclass('public.users') is null then
    return false;
  end if;

  execute 'select role from public.users where id = $1 limit 1'
    into role_key
    using target_user_id;

  return role_key = 'admin'
    or role_key = 'super_admin'
    or coalesce(role_key, '') like 'admin_%';
end;
$$;

create or replace function public.set_ads_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.campaigns (
  id text primary key,
  seller_id uuid not null,
  store_id text,
  name text not null,
  description text,
  type text not null,
  objective text not null,
  status text not null default 'draft',
  billing_model text not null,
  daily_budget numeric(12,2) not null default 0,
  total_budget numeric(12,2) not null default 0,
  spent_amount numeric(12,2) not null default 0,
  remaining_balance numeric(12,2) not null default 0,
  bid_amount numeric(12,2) not null default 0,
  currency text not null default 'TRY',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  paused_at timestamptz,
  approved_at timestamptz,
  rejected_at timestamptz,
  review_notes text,
  is_premium_placement_enabled boolean not null default false,
  use_ai_suggestions boolean not null default false,
  frequency_cap_per_user integer not null default 3,
  targeting_version integer not null default 1,
  ab_test_enabled boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint campaigns_budget_check check (daily_budget >= 0 and total_budget >= 0),
  constraint campaigns_date_check check (ends_at >= starts_at)
);

create index if not exists campaigns_seller_id_idx on public.campaigns (seller_id);
create index if not exists campaigns_status_idx on public.campaigns (status);
create index if not exists campaigns_type_idx on public.campaigns (type);
create index if not exists campaigns_objective_idx on public.campaigns (objective);
create index if not exists campaigns_starts_at_idx on public.campaigns (starts_at desc);

drop trigger if exists campaigns_set_updated_at on public.campaigns;
create trigger campaigns_set_updated_at
before update on public.campaigns
for each row execute function public.set_ads_updated_at();

create table if not exists public.campaign_targets (
  id text primary key default gen_random_uuid()::text,
  campaign_id text not null references public.campaigns(id) on delete cascade,
  objective text not null,
  placements jsonb not null default '[]'::jsonb,
  categories jsonb not null default '[]'::jsonb,
  keywords jsonb not null default '[]'::jsonb,
  city_codes jsonb not null default '[]'::jsonb,
  geohash_prefixes jsonb not null default '[]'::jsonb,
  min_price numeric(12,2),
  max_price numeric(12,2),
  radius_meters integer,
  event_lookback_days integer not null default 30,
  frequency_cap_per_day integer not null default 3,
  retargeting_window_days integer not null default 14,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint campaign_targets_campaign_id_unique unique (campaign_id)
);

create index if not exists campaign_targets_campaign_id_idx
  on public.campaign_targets (campaign_id);

drop trigger if exists campaign_targets_set_updated_at on public.campaign_targets;
create trigger campaign_targets_set_updated_at
before update on public.campaign_targets
for each row execute function public.set_ads_updated_at();

create table if not exists public.campaign_assets (
  id text primary key default gen_random_uuid()::text,
  campaign_id text not null references public.campaigns(id) on delete cascade,
  asset_type text not null,
  entity_id text,
  title text,
  subtitle text,
  media_url text,
  thumbnail_url text,
  deep_link text,
  placements jsonb not null default '[]'::jsonb,
  priority integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists campaign_assets_campaign_id_idx
  on public.campaign_assets (campaign_id);
create index if not exists campaign_assets_asset_type_idx
  on public.campaign_assets (asset_type);

drop trigger if exists campaign_assets_set_updated_at on public.campaign_assets;
create trigger campaign_assets_set_updated_at
before update on public.campaign_assets
for each row execute function public.set_ads_updated_at();

create table if not exists public.ab_test_variants (
  id text primary key default gen_random_uuid()::text,
  campaign_id text not null references public.campaigns(id) on delete cascade,
  name text not null,
  weight numeric(8,4) not null default 0.5,
  headline text,
  cta_label text,
  asset_overrides jsonb not null default '{}'::jsonb,
  target_overrides jsonb not null default '{}'::jsonb,
  impressions integer not null default 0,
  clicks integer not null default 0,
  conversions integer not null default 0,
  is_control boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists ab_test_variants_campaign_id_idx
  on public.ab_test_variants (campaign_id);

create table if not exists public.ad_metrics_daily (
  campaign_id text not null references public.campaigns(id) on delete cascade,
  metric_date timestamptz not null,
  impressions integer not null default 0,
  clicks integer not null default 0,
  detail_views integer not null default 0,
  favorites integer not null default 0,
  add_to_carts integer not null default 0,
  checkouts integer not null default 0,
  orders integer not null default 0,
  store_visits integer not null default 0,
  collection_opens integer not null default 0,
  notifications_sent integer not null default 0,
  notifications_opened integer not null default 0,
  unique_users integer not null default 0,
  conversions integer not null default 0,
  spend numeric(12,2) not null default 0,
  revenue numeric(12,2) not null default 0,
  primary key (campaign_id, metric_date)
);

create index if not exists ad_metrics_daily_metric_date_idx
  on public.ad_metrics_daily (metric_date desc);

create table if not exists public.ad_wallet_transactions (
  id text primary key,
  seller_id uuid not null,
  campaign_id text references public.campaigns(id) on delete set null,
  type text not null,
  status text not null,
  amount numeric(12,2) not null,
  balance_before numeric(12,2) not null default 0,
  balance_after numeric(12,2) not null default 0,
  reference text,
  approved_by uuid,
  note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists ad_wallet_transactions_seller_id_idx
  on public.ad_wallet_transactions (seller_id, created_at desc);
create index if not exists ad_wallet_transactions_campaign_id_idx
  on public.ad_wallet_transactions (campaign_id);

create table if not exists public.ad_revenue_logs (
  id text primary key,
  campaign_id text references public.campaigns(id) on delete set null,
  seller_id uuid,
  wallet_transaction_id text references public.ad_wallet_transactions(id) on delete set null,
  gross_amount numeric(12,2) not null default 0,
  net_amount numeric(12,2) not null default 0,
  tax_amount numeric(12,2) not null default 0,
  platform_fee numeric(12,2) not null default 0,
  currency text not null default 'TRY',
  recorded_at timestamptz not null default timezone('utc', now()),
  source_status text not null default 'approved',
  period_key text,
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists ad_revenue_logs_seller_id_idx
  on public.ad_revenue_logs (seller_id, recorded_at desc);
create index if not exists ad_revenue_logs_campaign_id_idx
  on public.ad_revenue_logs (campaign_id);

create table if not exists public.campaign_reviews (
  id text primary key,
  campaign_id text not null references public.campaigns(id) on delete cascade,
  seller_id uuid not null,
  reviewer_id uuid,
  status text not null,
  note text,
  reasons jsonb not null default '[]'::jsonb,
  reviewed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists campaign_reviews_campaign_id_idx
  on public.campaign_reviews (campaign_id, created_at desc);
create index if not exists campaign_reviews_status_idx
  on public.campaign_reviews (status);

create table if not exists public.admin_review_logs (
  id bigserial primary key,
  campaign_id text not null references public.campaigns(id) on delete cascade,
  reviewer_id uuid,
  status text not null,
  note text,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists admin_review_logs_campaign_id_idx
  on public.admin_review_logs (campaign_id, created_at desc);

create table if not exists public.user_interests (
  user_id uuid not null,
  interest_key text not null,
  interest_type text not null,
  affinity_score numeric(8,4) not null default 0,
  source_event_count integer not null default 0,
  last_interaction_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  primary key (user_id, interest_key, interest_type)
);

create index if not exists user_interests_affinity_score_idx
  on public.user_interests (user_id, affinity_score desc);

create table if not exists public.user_product_events (
  id text primary key,
  user_id uuid not null,
  product_id text,
  store_id text,
  collection_id text,
  event_type text not null,
  source_placement text,
  campaign_id text references public.campaigns(id) on delete set null,
  quantity integer not null default 1,
  city_code text,
  latitude double precision,
  longitude double precision,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists user_product_events_user_id_idx
  on public.user_product_events (user_id, created_at desc);
create index if not exists user_product_events_campaign_id_idx
  on public.user_product_events (campaign_id);

create table if not exists public.notification_logs (
  id bigserial primary key,
  campaign_id text references public.campaigns(id) on delete set null,
  seller_id uuid,
  user_id uuid,
  status text not null default 'queued',
  provider text,
  title text,
  body text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists notification_logs_campaign_id_idx
  on public.notification_logs (campaign_id, created_at desc);

alter table public.campaigns enable row level security;
alter table public.campaign_targets enable row level security;
alter table public.campaign_assets enable row level security;
alter table public.ab_test_variants enable row level security;
alter table public.ad_metrics_daily enable row level security;
alter table public.ad_wallet_transactions enable row level security;
alter table public.ad_revenue_logs enable row level security;
alter table public.campaign_reviews enable row level security;
alter table public.admin_review_logs enable row level security;
alter table public.user_interests enable row level security;
alter table public.user_product_events enable row level security;
alter table public.notification_logs enable row level security;

drop policy if exists "campaigns_select_own_or_admin" on public.campaigns;
create policy "campaigns_select_own_or_admin"
on public.campaigns
for select
using (seller_id = auth.uid() or public.is_admin_user());

drop policy if exists "campaigns_insert_own_or_admin" on public.campaigns;
create policy "campaigns_insert_own_or_admin"
on public.campaigns
for insert
with check (seller_id = auth.uid() or public.is_admin_user());

drop policy if exists "campaigns_update_own_or_admin" on public.campaigns;
create policy "campaigns_update_own_or_admin"
on public.campaigns
for update
using (seller_id = auth.uid() or public.is_admin_user())
with check (seller_id = auth.uid() or public.is_admin_user());

drop policy if exists "campaigns_delete_own_or_admin" on public.campaigns;
create policy "campaigns_delete_own_or_admin"
on public.campaigns
for delete
using (seller_id = auth.uid() or public.is_admin_user());

drop policy if exists "campaign_targets_all_via_campaign_owner_or_admin" on public.campaign_targets;
create policy "campaign_targets_all_via_campaign_owner_or_admin"
on public.campaign_targets
for all
using (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_id
      and (c.seller_id = auth.uid() or public.is_admin_user())
  )
)
with check (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_id
      and (c.seller_id = auth.uid() or public.is_admin_user())
  )
);

drop policy if exists "campaign_assets_all_via_campaign_owner_or_admin" on public.campaign_assets;
create policy "campaign_assets_all_via_campaign_owner_or_admin"
on public.campaign_assets
for all
using (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_id
      and (c.seller_id = auth.uid() or public.is_admin_user())
  )
)
with check (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_id
      and (c.seller_id = auth.uid() or public.is_admin_user())
  )
);

drop policy if exists "ab_test_variants_all_via_campaign_owner_or_admin" on public.ab_test_variants;
create policy "ab_test_variants_all_via_campaign_owner_or_admin"
on public.ab_test_variants
for all
using (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_id
      and (c.seller_id = auth.uid() or public.is_admin_user())
  )
)
with check (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_id
      and (c.seller_id = auth.uid() or public.is_admin_user())
  )
);

drop policy if exists "ad_metrics_daily_select_via_campaign_owner_or_admin" on public.ad_metrics_daily;
create policy "ad_metrics_daily_select_via_campaign_owner_or_admin"
on public.ad_metrics_daily
for select
using (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_id
      and (c.seller_id = auth.uid() or public.is_admin_user())
  )
);

drop policy if exists "ad_metrics_daily_mutate_admin_or_owner" on public.ad_metrics_daily;
create policy "ad_metrics_daily_mutate_admin_or_owner"
on public.ad_metrics_daily
for all
using (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_id
      and (c.seller_id = auth.uid() or public.is_admin_user())
  )
)
with check (
  exists (
    select 1
    from public.campaigns c
    where c.id = campaign_id
      and (c.seller_id = auth.uid() or public.is_admin_user())
  )
);

drop policy if exists "ad_wallet_transactions_select_own_or_admin" on public.ad_wallet_transactions;
create policy "ad_wallet_transactions_select_own_or_admin"
on public.ad_wallet_transactions
for select
using (seller_id = auth.uid() or public.is_admin_user());

drop policy if exists "ad_wallet_transactions_mutate_own_or_admin" on public.ad_wallet_transactions;
create policy "ad_wallet_transactions_mutate_own_or_admin"
on public.ad_wallet_transactions
for all
using (seller_id = auth.uid() or public.is_admin_user())
with check (seller_id = auth.uid() or public.is_admin_user());

drop policy if exists "ad_revenue_logs_select_own_or_admin" on public.ad_revenue_logs;
create policy "ad_revenue_logs_select_own_or_admin"
on public.ad_revenue_logs
for select
using (seller_id = auth.uid() or public.is_admin_user());

drop policy if exists "ad_revenue_logs_mutate_admin_or_owner" on public.ad_revenue_logs;
create policy "ad_revenue_logs_mutate_admin_or_owner"
on public.ad_revenue_logs
for all
using (
  seller_id = auth.uid()
  or public.is_admin_user()
  or (
    campaign_id is not null
    and exists (
      select 1 from public.campaigns c
      where c.id = campaign_id
        and (c.seller_id = auth.uid() or public.is_admin_user())
    )
  )
)
with check (
  seller_id = auth.uid()
  or public.is_admin_user()
  or (
    campaign_id is not null
    and exists (
      select 1 from public.campaigns c
      where c.id = campaign_id
        and (c.seller_id = auth.uid() or public.is_admin_user())
    )
  )
);

drop policy if exists "campaign_reviews_select_own_or_admin" on public.campaign_reviews;
create policy "campaign_reviews_select_own_or_admin"
on public.campaign_reviews
for select
using (seller_id = auth.uid() or public.is_admin_user());

drop policy if exists "campaign_reviews_insert_admin_or_owner" on public.campaign_reviews;
create policy "campaign_reviews_insert_admin_or_owner"
on public.campaign_reviews
for insert
with check (seller_id = auth.uid() or public.is_admin_user());

drop policy if exists "campaign_reviews_update_admin_only" on public.campaign_reviews;
create policy "campaign_reviews_update_admin_only"
on public.campaign_reviews
for update
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists "campaign_reviews_delete_admin_only" on public.campaign_reviews;
create policy "campaign_reviews_delete_admin_only"
on public.campaign_reviews
for delete
using (public.is_admin_user());

drop policy if exists "admin_review_logs_admin_only" on public.admin_review_logs;
create policy "admin_review_logs_admin_only"
on public.admin_review_logs
for all
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists "user_interests_select_own_or_admin" on public.user_interests;
create policy "user_interests_select_own_or_admin"
on public.user_interests
for select
using (user_id = auth.uid() or public.is_admin_user());

drop policy if exists "user_interests_mutate_own_or_admin" on public.user_interests;
create policy "user_interests_mutate_own_or_admin"
on public.user_interests
for all
using (user_id = auth.uid() or public.is_admin_user())
with check (user_id = auth.uid() or public.is_admin_user());

drop policy if exists "user_product_events_select_own_or_admin" on public.user_product_events;
create policy "user_product_events_select_own_or_admin"
on public.user_product_events
for select
using (user_id = auth.uid() or public.is_admin_user());

drop policy if exists "user_product_events_mutate_own_or_admin" on public.user_product_events;
create policy "user_product_events_mutate_own_or_admin"
on public.user_product_events
for all
using (user_id = auth.uid() or public.is_admin_user())
with check (user_id = auth.uid() or public.is_admin_user());

drop policy if exists "notification_logs_select_own_or_admin" on public.notification_logs;
create policy "notification_logs_select_own_or_admin"
on public.notification_logs
for select
using (
  seller_id = auth.uid()
  or user_id = auth.uid()
  or public.is_admin_user()
);

drop policy if exists "notification_logs_mutate_admin_or_owner" on public.notification_logs;
create policy "notification_logs_mutate_admin_or_owner"
on public.notification_logs
for all
using (
  seller_id = auth.uid()
  or user_id = auth.uid()
  or public.is_admin_user()
)
with check (
  seller_id = auth.uid()
  or user_id = auth.uid()
  or public.is_admin_user()
);
