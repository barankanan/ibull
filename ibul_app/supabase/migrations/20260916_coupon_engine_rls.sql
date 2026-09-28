-- Coupon engine helpers, computed status, RLS.
-- Relies on public.is_admin_user(uuid) from existing admin auth.

create or replace function public.coupon_effective_status(
  p_approval text,
  p_lifecycle text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_now timestamptz default timezone('utc', now())
)
returns text
language sql
immutable
as $$
  select case
    when p_approval = 'rejected' then 'rejected'
    when p_approval = 'draft' then 'draft'
    when p_approval = 'pending_review' then 'pending_review'
    when p_lifecycle = 'paused' then 'paused'
    when p_approval = 'approved' and p_now < p_starts_at then 'scheduled'
    when p_approval = 'approved' and p_now > p_ends_at then 'expired'
    when p_approval = 'approved' then 'active'
    else coalesce(p_approval, 'draft')
  end;
$$;

create or replace function public.coupon_is_redeemable(
  p_approval text,
  p_lifecycle text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_now timestamptz default timezone('utc', now())
)
returns boolean
language sql
immutable
as $$
  select public.coupon_effective_status(
    p_approval, p_lifecycle, p_starts_at, p_ends_at, p_now
  ) = 'active';
$$;

create or replace function public.coupon_seller_owns_store(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_store_id is not null
    and p_store_id = auth.uid()
    and (
      to_regclass('public.stores') is null
      or exists (
        select 1 from public.stores s
        where s.seller_id = p_store_id
      )
    );
$$;

create or replace function public.coupon_protect_campaign_row()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin_user(auth.uid()) then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.seller_id := auth.uid();
    new.store_id := coalesce(new.store_id, auth.uid());
    new.created_by := auth.uid();
    if new.approval_status not in ('draft', 'pending_review') then
      new.approval_status := 'pending_review';
    end if;
    if new.source_type = 'ibul' then
      new.source_type := 'seller';
    end if;
    new.used_count := 0;
    new.view_count := 0;
    new.claim_count := 0;
    new.total_discount_granted := 0;
    new.wheel_enabled := false;
    if not public.coupon_seller_owns_store(new.store_id) then
      raise exception 'not authorized';
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if old.seller_id is distinct from auth.uid() then
      raise exception 'not authorized';
    end if;
    new.seller_id := old.seller_id;
    new.store_id := old.store_id;
    new.created_by := old.created_by;
    new.used_count := old.used_count;
    new.view_count := old.view_count;
    new.claim_count := old.claim_count;
    new.total_discount_granted := old.total_discount_granted;
    new.wheel_enabled := old.wheel_enabled;
    new.source_type := old.source_type;
    if old.approval_status in ('approved', 'rejected', 'pending_review')
       and new.approval_status = 'approved' then
      new.approval_status := old.approval_status;
    end if;
    if new.approval_status = 'approved' and old.approval_status is distinct from 'approved' then
      raise exception 'not authorized';
    end if;
    if new.approval_status not in ('draft', 'pending_review', old.approval_status) then
      new.approval_status := old.approval_status;
    end if;
    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists coupon_campaigns_protect_row on public.coupon_campaigns;
create trigger coupon_campaigns_protect_row
before insert or update on public.coupon_campaigns
for each row execute function public.coupon_protect_campaign_row();

alter table public.coupon_campaigns enable row level security;
alter table public.coupon_campaign_categories enable row level security;
alter table public.coupon_campaign_products enable row level security;
alter table public.coupon_campaign_stores enable row level security;
alter table public.user_coupons enable row level security;
alter table public.coupon_redemptions enable row level security;
alter table public.reward_wheel_configs enable row level security;
alter table public.reward_wheel_items enable row level security;
alter table public.reward_wheel_spins enable row level security;

drop policy if exists coupon_campaigns_admin_all on public.coupon_campaigns;
create policy coupon_campaigns_admin_all
on public.coupon_campaigns
for all
to authenticated
using (public.is_admin_user(auth.uid()))
with check (public.is_admin_user(auth.uid()));

drop policy if exists coupon_campaigns_seller_select on public.coupon_campaigns;
create policy coupon_campaigns_seller_select
on public.coupon_campaigns
for select
to authenticated
using (seller_id = auth.uid());

drop policy if exists coupon_campaigns_seller_insert on public.coupon_campaigns;
create policy coupon_campaigns_seller_insert
on public.coupon_campaigns
for insert
to authenticated
with check (
  seller_id = auth.uid()
  and store_id = auth.uid()
  and approval_status in ('draft', 'pending_review')
  and source_type in ('seller', 'coupon_ad')
);

drop policy if exists coupon_campaigns_seller_update on public.coupon_campaigns;
create policy coupon_campaigns_seller_update
on public.coupon_campaigns
for update
to authenticated
using (seller_id = auth.uid())
with check (
  seller_id = auth.uid()
  and store_id = auth.uid()
  and approval_status in ('draft', 'pending_review', 'rejected')
);

drop policy if exists coupon_campaigns_public_select on public.coupon_campaigns;
create policy coupon_campaigns_public_select
on public.coupon_campaigns
for select
to anon, authenticated
using (
  is_public = true
  and approval_status = 'approved'
  and lifecycle_status <> 'paused'
  and starts_at <= timezone('utc', now())
  and ends_at >= timezone('utc', now())
);

drop policy if exists coupon_campaigns_owner_select on public.coupon_campaigns;
create policy coupon_campaigns_owner_select
on public.coupon_campaigns
for select
to authenticated
using (
  exists (
    select 1 from public.user_coupons uc
    where uc.campaign_id = coupon_campaigns.id
      and uc.user_id = auth.uid()
  )
);

drop policy if exists coupon_scope_admin_all_categories on public.coupon_campaign_categories;
create policy coupon_scope_admin_all_categories
on public.coupon_campaign_categories
for all
to authenticated
using (public.is_admin_user(auth.uid()))
with check (public.is_admin_user(auth.uid()));

drop policy if exists coupon_scope_seller_categories on public.coupon_campaign_categories;
create policy coupon_scope_seller_categories
on public.coupon_campaign_categories
for all
to authenticated
using (
  exists (
    select 1 from public.coupon_campaigns c
    where c.id = campaign_id and c.seller_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.coupon_campaigns c
    where c.id = campaign_id and c.seller_id = auth.uid()
  )
);

drop policy if exists coupon_scope_public_categories on public.coupon_campaign_categories;
create policy coupon_scope_public_categories
on public.coupon_campaign_categories
for select
to anon, authenticated
using (
  exists (
    select 1 from public.coupon_campaigns c
    where c.id = campaign_id
      and c.is_public = true
      and c.approval_status = 'approved'
      and c.lifecycle_status <> 'paused'
      and c.starts_at <= timezone('utc', now())
      and c.ends_at >= timezone('utc', now())
  )
);

drop policy if exists coupon_scope_admin_all_products on public.coupon_campaign_products;
create policy coupon_scope_admin_all_products
on public.coupon_campaign_products
for all
to authenticated
using (public.is_admin_user(auth.uid()))
with check (public.is_admin_user(auth.uid()));

drop policy if exists coupon_scope_seller_products on public.coupon_campaign_products;
create policy coupon_scope_seller_products
on public.coupon_campaign_products
for all
to authenticated
using (
  exists (
    select 1 from public.coupon_campaigns c
    where c.id = campaign_id and c.seller_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.coupon_campaigns c
    where c.id = campaign_id and c.seller_id = auth.uid()
  )
  and exists (
    select 1 from public.products p
    where p.id = product_id and p.seller_id = auth.uid()
  )
);

drop policy if exists coupon_scope_public_products on public.coupon_campaign_products;
create policy coupon_scope_public_products
on public.coupon_campaign_products
for select
to anon, authenticated
using (
  exists (
    select 1 from public.coupon_campaigns c
    where c.id = campaign_id
      and c.is_public = true
      and c.approval_status = 'approved'
      and c.lifecycle_status <> 'paused'
      and c.starts_at <= timezone('utc', now())
      and c.ends_at >= timezone('utc', now())
  )
);

drop policy if exists coupon_scope_admin_all_stores on public.coupon_campaign_stores;
create policy coupon_scope_admin_all_stores
on public.coupon_campaign_stores
for all
to authenticated
using (public.is_admin_user(auth.uid()))
with check (public.is_admin_user(auth.uid()));

drop policy if exists coupon_scope_seller_stores on public.coupon_campaign_stores;
create policy coupon_scope_seller_stores
on public.coupon_campaign_stores
for all
to authenticated
using (
  exists (
    select 1 from public.coupon_campaigns c
    where c.id = campaign_id and c.seller_id = auth.uid()
  )
)
with check (
  store_id = auth.uid()
  and exists (
    select 1 from public.coupon_campaigns c
    where c.id = campaign_id and c.seller_id = auth.uid()
  )
);

drop policy if exists coupon_scope_public_stores on public.coupon_campaign_stores;
create policy coupon_scope_public_stores
on public.coupon_campaign_stores
for select
to anon, authenticated
using (
  exists (
    select 1 from public.coupon_campaigns c
    where c.id = campaign_id
      and c.is_public = true
      and c.approval_status = 'approved'
      and c.lifecycle_status <> 'paused'
      and c.starts_at <= timezone('utc', now())
      and c.ends_at >= timezone('utc', now())
  )
);

drop policy if exists user_coupons_owner_select on public.user_coupons;
create policy user_coupons_owner_select
on public.user_coupons
for select
to authenticated
using (user_id = auth.uid() or public.is_admin_user(auth.uid()));

drop policy if exists user_coupons_no_client_write on public.user_coupons;
create policy user_coupons_no_client_write
on public.user_coupons
for insert
to authenticated
with check (false);

drop policy if exists user_coupons_no_client_update on public.user_coupons;
create policy user_coupons_no_client_update
on public.user_coupons
for update
to authenticated
using (public.is_admin_user(auth.uid()))
with check (public.is_admin_user(auth.uid()));

drop policy if exists coupon_redemptions_owner_select on public.coupon_redemptions;
create policy coupon_redemptions_owner_select
on public.coupon_redemptions
for select
to authenticated
using (user_id = auth.uid() or public.is_admin_user(auth.uid()));

drop policy if exists coupon_redemptions_no_client_insert on public.coupon_redemptions;
create policy coupon_redemptions_no_client_insert
on public.coupon_redemptions
for insert
to authenticated
with check (false);

drop policy if exists reward_wheel_configs_public_select on public.reward_wheel_configs;
create policy reward_wheel_configs_public_select
on public.reward_wheel_configs
for select
to anon, authenticated
using (true);

drop policy if exists reward_wheel_configs_admin_write on public.reward_wheel_configs;
create policy reward_wheel_configs_admin_write
on public.reward_wheel_configs
for all
to authenticated
using (public.is_admin_user(auth.uid()))
with check (public.is_admin_user(auth.uid()));

drop policy if exists reward_wheel_items_public_select on public.reward_wheel_items;
create policy reward_wheel_items_public_select
on public.reward_wheel_items
for select
to anon, authenticated
using (true);

drop policy if exists reward_wheel_items_admin_write on public.reward_wheel_items;
create policy reward_wheel_items_admin_write
on public.reward_wheel_items
for all
to authenticated
using (public.is_admin_user(auth.uid()))
with check (public.is_admin_user(auth.uid()));

drop policy if exists reward_wheel_spins_owner_select on public.reward_wheel_spins;
create policy reward_wheel_spins_owner_select
on public.reward_wheel_spins
for select
to authenticated
using (user_id = auth.uid() or public.is_admin_user(auth.uid()));

drop policy if exists reward_wheel_spins_no_client_insert on public.reward_wheel_spins;
create policy reward_wheel_spins_no_client_insert
on public.reward_wheel_spins
for insert
to authenticated
with check (false);

grant select on public.coupon_campaigns to anon, authenticated;
grant insert, update, delete on public.coupon_campaigns to authenticated;
grant select, insert, update, delete on public.coupon_campaign_categories to authenticated;
grant select on public.coupon_campaign_categories to anon;
grant select, insert, update, delete on public.coupon_campaign_products to authenticated;
grant select on public.coupon_campaign_products to anon;
grant select, insert, update, delete on public.coupon_campaign_stores to authenticated;
grant select on public.coupon_campaign_stores to anon;
grant select on public.user_coupons to authenticated;
grant select on public.coupon_redemptions to authenticated;
grant select on public.reward_wheel_configs to anon, authenticated;
grant insert, update, delete on public.reward_wheel_configs to authenticated;
grant select on public.reward_wheel_items to anon, authenticated;
grant insert, update, delete on public.reward_wheel_items to authenticated;
grant select on public.reward_wheel_spins to authenticated;

grant execute on function public.coupon_effective_status(text, text, timestamptz, timestamptz, timestamptz)
  to anon, authenticated;
grant execute on function public.coupon_is_redeemable(text, text, timestamptz, timestamptz, timestamptz)
  to anon, authenticated;
grant execute on function public.coupon_seller_owns_store(uuid) to authenticated;
