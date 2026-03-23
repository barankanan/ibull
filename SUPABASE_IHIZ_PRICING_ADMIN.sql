-- IHIZ Admin Pricing & Earnings module storage
-- Run in Supabase SQL Editor once.

create extension if not exists pgcrypto;

create or replace function public.is_admin_user(target_user_id uuid default auth.uid())
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  role_text text;
begin
  if target_user_id is null then
    return false;
  end if;

  begin
    select lower(coalesce(role, ''))
    into role_text
    from public.users
    where id = target_user_id
    limit 1;
  exception when others then
    return false;
  end;

  return role_text in ('admin', 'super_admin', 'owner');
end;
$$;

create table if not exists public.ihiz_pricing_rule_versions (
  id uuid primary key default gen_random_uuid(),
  version integer not null unique,
  config jsonb not null default '{}'::jsonb,
  active_from timestamptz not null default now(),
  active_to timestamptz,
  is_active boolean not null default true,
  note text not null default '',
  created_by uuid,
  created_at timestamptz not null default now()
);

create index if not exists idx_ihiz_pricing_rule_versions_active
  on public.ihiz_pricing_rule_versions (is_active, version desc);

create unique index if not exists uniq_ihiz_pricing_rule_versions_one_active
  on public.ihiz_pricing_rule_versions ((is_active))
  where is_active = true;

alter table public.ihiz_pricing_rule_versions enable row level security;

drop policy if exists ihiz_pricing_rule_versions_select on public.ihiz_pricing_rule_versions;
create policy ihiz_pricing_rule_versions_select
on public.ihiz_pricing_rule_versions
for select
to authenticated
using (
  public.is_admin_user(auth.uid()) or created_by = auth.uid()
);

drop policy if exists ihiz_pricing_rule_versions_insert on public.ihiz_pricing_rule_versions;
create policy ihiz_pricing_rule_versions_insert
on public.ihiz_pricing_rule_versions
for insert
to authenticated
with check (
  public.is_admin_user(auth.uid())
);

drop policy if exists ihiz_pricing_rule_versions_update on public.ihiz_pricing_rule_versions;
create policy ihiz_pricing_rule_versions_update
on public.ihiz_pricing_rule_versions
for update
to authenticated
using (
  public.is_admin_user(auth.uid())
)
with check (
  public.is_admin_user(auth.uid())
);

grant select, insert, update on public.ihiz_pricing_rule_versions to authenticated;

create or replace function public.get_active_ihiz_pricing_config()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (
      select config
      from public.ihiz_pricing_rule_versions
      where is_active = true
      order by version desc
      limit 1
    ),
    '{}'::jsonb
  );
$$;

revoke all on function public.get_active_ihiz_pricing_config() from public;
grant execute on function public.get_active_ihiz_pricing_config() to anon, authenticated;

insert into public.ihiz_pricing_rule_versions (
  version,
  config,
  active_from,
  active_to,
  is_active,
  note,
  created_by
)
select
  1,
  jsonb_build_object(
    'base_fee', 28,
    'per_km_fee', 7,
    'nearby_threshold_km', 8,
    'medium_distance_threshold_km', 20,
    'ihiz_direct_max_distance_km', 20,
    'platform_fee', 10,
    'min_delivery_fee', 35,
    'max_delivery_fee', 350,
    'dynamic_pricing_enabled', true,
    'customer_fee_0_3_km', 35,
    'customer_fee_3_6_km', 45,
    'customer_fee_6_plus_km', 55,
    'seller_contribution_mode', 'remaining_after_customer',
    'free_delivery_campaign_enabled', false,
    'external_seller_pays_all', true,
    'external_service_fee', 0,
    'external_min_fee', 45,
    'branch_base_fee', 20,
    'branch_km_fee', 6,
    'night_bonus', 12,
    'rain_bonus', 15,
    'surge_bonus', 10,
    'multi_order_extra_fee', 25,
    'multi_order_enabled', true,
    'min_wallet_balance', 100,
    'low_balance_warning_level', 200,
    'wallet_flow_mode', 'reserve_capture_release',
    'cancel_before_assign_refund_pct', 100,
    'cancel_after_assign_refund_pct', 70,
    'cancel_after_pickup_refund_pct', 10,
    'cancel_penalty_pct', 15,
    'courier_base_earning', 28,
    'courier_per_km_earning', 7,
    'courier_minute_price', 4,
    'courier_night_bonus', 12,
    'courier_rain_bonus', 15,
    'courier_storm_bonus', 20,
    'courier_snow_bonus', 25,
    'courier_surge_bonus', 10,
    'courier_multi_order_bonus', 25,
    'weekly_payout_day', 'Cuma',
    'otp_required', true,
    'delivery_geo_fence_meters', 150,
    'eta_per_km_minute', 5,
    'eta_base_minute', 6,
    'ihiz_active_cities', 'Eskişehir,İstanbul,Ankara',
    'enabled_cargo_companies', 'aras,mng,ptt'
  ),
  now(),
  null,
  true,
  'İlk fiyatlandırma kuralı',
  auth.uid()
where not exists (
  select 1 from public.ihiz_pricing_rule_versions
);
