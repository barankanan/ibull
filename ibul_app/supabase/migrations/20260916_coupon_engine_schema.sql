-- Central coupon engine: campaigns, scopes, ownership, wheel, redemptions.
-- Non-destructive. Does not alter ads campaigns or store_campaigns.
-- Source of truth: ibul_app/supabase/migrations
-- Rollback: drop functions/policies first, then tables in reverse FK order.

create extension if not exists pgcrypto;

create or replace function public.coupon_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.coupon_campaigns (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  code text not null,
  source_type text not null default 'ibul'
    check (source_type in ('ibul', 'seller', 'coupon_ad')),
  discount_type text not null
    check (discount_type in ('percent', 'fixed', 'free_shipping', 'special')),
  discount_value numeric(12,2) not null default 0 check (discount_value >= 0),
  max_discount numeric(12,2) check (max_discount is null or max_discount >= 0),
  min_order_amount numeric(12,2) not null default 0 check (min_order_amount >= 0),
  per_user_limit integer not null default 1 check (per_user_limit >= 0),
  total_usage_limit integer check (total_usage_limit is null or total_usage_limit >= 0),
  used_count integer not null default 0 check (used_count >= 0),
  new_users_only boolean not null default false,
  is_public boolean not null default true,
  payment_type text,
  scope_type text not null default 'all'
    check (scope_type in ('all', 'categories', 'stores', 'products')),
  seller_id uuid,
  store_id uuid,
  approval_status text not null default 'draft'
    check (approval_status in ('draft', 'pending_review', 'approved', 'rejected')),
  lifecycle_status text not null default 'draft'
    check (lifecycle_status in ('draft', 'paused')),
  rejection_reason text,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_by uuid,
  ad_campaign_id text,
  view_count integer not null default 0 check (view_count >= 0),
  claim_count integer not null default 0 check (claim_count >= 0),
  total_discount_granted numeric(14,2) not null default 0,
  wheel_enabled boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint coupon_campaigns_date_check check (ends_at >= starts_at),
  constraint coupon_campaigns_percent_check check (
    discount_type <> 'percent' or (discount_value > 0 and discount_value <= 100)
  ),
  constraint coupon_campaigns_seller_source_check check (
    source_type = 'ibul' or seller_id is not null
  )
);

create unique index if not exists coupon_campaigns_code_lower_uidx
  on public.coupon_campaigns (lower(code));

create index if not exists coupon_campaigns_approval_idx
  on public.coupon_campaigns (approval_status);

create index if not exists coupon_campaigns_window_idx
  on public.coupon_campaigns (starts_at, ends_at);

create index if not exists coupon_campaigns_store_idx
  on public.coupon_campaigns (store_id)
  where store_id is not null;

create index if not exists coupon_campaigns_seller_idx
  on public.coupon_campaigns (seller_id)
  where seller_id is not null;

create index if not exists coupon_campaigns_source_idx
  on public.coupon_campaigns (source_type);

create index if not exists coupon_campaigns_public_active_idx
  on public.coupon_campaigns (is_public, approval_status, starts_at, ends_at)
  where is_public = true and approval_status = 'approved' and lifecycle_status <> 'paused';

drop trigger if exists coupon_campaigns_set_updated_at on public.coupon_campaigns;
create trigger coupon_campaigns_set_updated_at
before update on public.coupon_campaigns
for each row execute function public.coupon_set_updated_at();

create table if not exists public.coupon_campaign_categories (
  campaign_id uuid not null references public.coupon_campaigns(id) on delete cascade,
  category_id bigint not null,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (campaign_id, category_id)
);

create index if not exists coupon_campaign_categories_category_idx
  on public.coupon_campaign_categories (category_id);

create table if not exists public.coupon_campaign_products (
  campaign_id uuid not null references public.coupon_campaigns(id) on delete cascade,
  product_id text not null,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (campaign_id, product_id)
);

create index if not exists coupon_campaign_products_product_idx
  on public.coupon_campaign_products (product_id);

create table if not exists public.coupon_campaign_stores (
  campaign_id uuid not null references public.coupon_campaigns(id) on delete cascade,
  store_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (campaign_id, store_id)
);

create index if not exists coupon_campaign_stores_store_idx
  on public.coupon_campaign_stores (store_id);

create table if not exists public.user_coupons (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  campaign_id uuid not null references public.coupon_campaigns(id) on delete cascade,
  status text not null default 'claimed'
    check (status in ('claimed', 'reserved', 'used', 'expired')),
  source text not null default 'claim'
    check (source in ('claim', 'wheel', 'assigned', 'checkout')),
  claimed_at timestamptz not null default timezone('utc', now()),
  used_at timestamptz,
  order_id text,
  spin_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists user_coupons_user_idx
  on public.user_coupons (user_id, status);

create index if not exists user_coupons_campaign_idx
  on public.user_coupons (campaign_id);

create unique index if not exists user_coupons_user_campaign_claimed_uidx
  on public.user_coupons (user_id, campaign_id)
  where status in ('claimed', 'reserved');

drop trigger if exists user_coupons_set_updated_at on public.user_coupons;
create trigger user_coupons_set_updated_at
before update on public.user_coupons
for each row execute function public.coupon_set_updated_at();

create table if not exists public.coupon_redemptions (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.coupon_campaigns(id) on delete cascade,
  user_id uuid not null,
  user_coupon_id uuid references public.user_coupons(id) on delete set null,
  order_id text,
  discount_amount numeric(12,2) not null default 0,
  free_shipping boolean not null default false,
  idempotency_key text,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists coupon_redemptions_campaign_idx
  on public.coupon_redemptions (campaign_id);

create index if not exists coupon_redemptions_user_idx
  on public.coupon_redemptions (user_id, campaign_id);

create unique index if not exists coupon_redemptions_idempotency_uidx
  on public.coupon_redemptions (user_id, idempotency_key)
  where idempotency_key is not null;

create unique index if not exists coupon_redemptions_order_uidx
  on public.coupon_redemptions (order_id)
  where order_id is not null;

create table if not exists public.reward_wheel_configs (
  id uuid primary key default gen_random_uuid(),
  is_active boolean not null default false,
  daily_free_spins integer not null default 1 check (daily_free_spins >= 0),
  cooldown_hours numeric(8,2) not null default 24 check (cooldown_hours >= 0),
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint reward_wheel_configs_window_check check (
    starts_at is null or ends_at is null or ends_at >= starts_at
  )
);

drop trigger if exists reward_wheel_configs_set_updated_at on public.reward_wheel_configs;
create trigger reward_wheel_configs_set_updated_at
before update on public.reward_wheel_configs
for each row execute function public.coupon_set_updated_at();

create table if not exists public.reward_wheel_items (
  id uuid primary key default gen_random_uuid(),
  config_id uuid not null references public.reward_wheel_configs(id) on delete cascade,
  campaign_id uuid references public.coupon_campaigns(id) on delete cascade,
  label text not null,
  is_no_prize boolean not null default false,
  probability_bps integer not null check (probability_bps >= 0 and probability_bps <= 10000),
  sort_order integer not null default 0,
  color_hex text,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists reward_wheel_items_config_idx
  on public.reward_wheel_items (config_id, sort_order);

create table if not exists public.reward_wheel_spins (
  id uuid primary key default gen_random_uuid(),
  config_id uuid not null references public.reward_wheel_configs(id) on delete restrict,
  user_id uuid not null,
  item_id uuid references public.reward_wheel_items(id) on delete set null,
  campaign_id uuid references public.coupon_campaigns(id) on delete set null,
  user_coupon_id uuid references public.user_coupons(id) on delete set null,
  is_win boolean not null default false,
  idempotency_key text not null,
  created_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists reward_wheel_spins_idempotency_uidx
  on public.reward_wheel_spins (user_id, idempotency_key);

create index if not exists reward_wheel_spins_user_created_idx
  on public.reward_wheel_spins (user_id, created_at desc);

do $$
begin
  if to_regclass('public.categories') is not null then
    if not exists (
      select 1
      from pg_constraint
      where conname = 'coupon_campaign_categories_category_fk'
    ) then
      alter table public.coupon_campaign_categories
        add constraint coupon_campaign_categories_category_fk
        foreign key (category_id) references public.categories(id) on delete cascade;
    end if;
  end if;
end;
$$;

do $$
begin
  if to_regclass('public.stores') is not null then
    if not exists (
      select 1
      from pg_constraint
      where conname = 'coupon_campaigns_store_fk'
    ) then
      alter table public.coupon_campaigns
        add constraint coupon_campaigns_store_fk
        foreign key (store_id) references public.stores(seller_id) on delete set null;
    end if;
    if not exists (
      select 1
      from pg_constraint
      where conname = 'coupon_campaign_stores_store_fk'
    ) then
      alter table public.coupon_campaign_stores
        add constraint coupon_campaign_stores_store_fk
        foreign key (store_id) references public.stores(seller_id) on delete cascade;
    end if;
  end if;
end;
$$;
