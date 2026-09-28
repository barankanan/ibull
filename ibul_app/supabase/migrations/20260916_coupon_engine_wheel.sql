-- Reward wheel config + server-side spin + daily deal product list.

create or replace function public.reward_wheel_save_config(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_total int := 0;
  v_item jsonb;
  v_campaign uuid;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'not authorized';
  end if;

  if jsonb_typeof(p_payload->'items') is distinct from 'array' then
    raise exception 'wheel items required';
  end if;

  select coalesce(sum((value->>'probability_bps')::int), 0)
  into v_total
  from jsonb_array_elements(p_payload->'items');

  if v_total <> 10000 then
    raise exception 'probability total must be 100 percent'
      using errcode = 'P0001',
            hint = v_total::text;
  end if;

  v_id := nullif(p_payload->>'id', '')::uuid;

  if v_id is null then
    insert into public.reward_wheel_configs (
      is_active, daily_free_spins, cooldown_hours, starts_at, ends_at, created_by
    ) values (
      coalesce((p_payload->>'is_active')::boolean, false),
      coalesce((p_payload->>'daily_free_spins')::int, 1),
      coalesce((p_payload->>'cooldown_hours')::numeric, 24),
      nullif(p_payload->>'starts_at', '')::timestamptz,
      nullif(p_payload->>'ends_at', '')::timestamptz,
      auth.uid()
    )
    returning id into v_id;
  else
    update public.reward_wheel_configs
    set is_active = coalesce((p_payload->>'is_active')::boolean, is_active),
        daily_free_spins = coalesce((p_payload->>'daily_free_spins')::int, daily_free_spins),
        cooldown_hours = coalesce((p_payload->>'cooldown_hours')::numeric, cooldown_hours),
        starts_at = nullif(p_payload->>'starts_at', '')::timestamptz,
        ends_at = nullif(p_payload->>'ends_at', '')::timestamptz
    where id = v_id;
    if not found then
      raise exception 'wheel config not found';
    end if;
  end if;

  delete from public.reward_wheel_items where config_id = v_id;

  for v_item in select value from jsonb_array_elements(p_payload->'items')
  loop
    v_campaign := nullif(v_item->>'campaign_id', '')::uuid;
    if v_campaign is not null then
      if not exists (
        select 1 from public.coupon_campaigns c
        where c.id = v_campaign
          and c.approval_status = 'approved'
      ) then
        raise exception 'wheel item must reference an approved coupon';
      end if;
      update public.coupon_campaigns
      set wheel_enabled = true
      where id = v_campaign;
    end if;

    insert into public.reward_wheel_items (
      config_id, campaign_id, label, is_no_prize, probability_bps, sort_order, color_hex
    ) values (
      v_id,
      v_campaign,
      coalesce(nullif(v_item->>'label', ''), 'Ödül'),
      coalesce((v_item->>'is_no_prize')::boolean, v_campaign is null),
      coalesce((v_item->>'probability_bps')::int, 0),
      coalesce((v_item->>'sort_order')::int, 0),
      nullif(v_item->>'color_hex', '')
    );
  end loop;

  update public.coupon_campaigns c
  set wheel_enabled = exists (
    select 1 from public.reward_wheel_items i
    where i.config_id = v_id and i.campaign_id = c.id
  )
  where c.wheel_enabled = true
     or exists (
       select 1 from public.reward_wheel_items i
       where i.config_id = v_id and i.campaign_id = c.id
     );

  return jsonb_build_object('ok', true, 'id', v_id, 'probability_bps', v_total);
end;
$$;

create or replace function public.spin_reward_wheel(p_idempotency_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_key text := btrim(coalesce(p_idempotency_key, ''));
  v_existing public.reward_wheel_spins%rowtype;
  v_config public.reward_wheel_configs%rowtype;
  v_item public.reward_wheel_items%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_spin_count int := 0;
  v_last timestamptz;
  v_roll int;
  v_cursor int := 0;
  v_spin_id uuid;
  v_user_coupon uuid;
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;
  if v_key = '' then
    raise exception 'idempotency key required';
  end if;

  select * into v_existing
  from public.reward_wheel_spins
  where user_id = v_user and idempotency_key = v_key;
  if found then
    return jsonb_build_object(
      'ok', true,
      'already_processed', true,
      'spin_id', v_existing.id,
      'is_win', v_existing.is_win,
      'item_id', v_existing.item_id,
      'campaign_id', v_existing.campaign_id,
      'user_coupon_id', v_existing.user_coupon_id
    );
  end if;

  select * into v_config
  from public.reward_wheel_configs
  where is_active = true
  order by updated_at desc
  limit 1
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Hediye çarkı şu anda kapalı.');
  end if;
  if v_config.starts_at is not null and v_now < v_config.starts_at then
    return jsonb_build_object('ok', false, 'error', 'Hediye çarkı henüz başlamadı.');
  end if;
  if v_config.ends_at is not null and v_now > v_config.ends_at then
    return jsonb_build_object('ok', false, 'error', 'Hediye çarkı süresi doldu.');
  end if;

  select count(*), max(created_at)
  into v_spin_count, v_last
  from public.reward_wheel_spins
  where user_id = v_user
    and created_at >= (
      date_trunc('day', timezone('Europe/Istanbul', v_now))
      at time zone 'Europe/Istanbul'
    );

  if v_config.daily_free_spins > 0 and v_spin_count >= v_config.daily_free_spins then
    return jsonb_build_object('ok', false, 'error', 'Bugünkü çevirme hakkınız doldu.');
  end if;
  if v_config.cooldown_hours > 0 and v_last is not null
     and v_last + (v_config.cooldown_hours || ' hours')::interval > v_now then
    return jsonb_build_object('ok', false, 'error', 'Çevirme hakkınız henüz dolmadı.');
  end if;

  v_roll := floor(random() * 10000)::int;
  for v_item in
    select * from public.reward_wheel_items
    where config_id = v_config.id
    order by sort_order, created_at
  loop
    v_cursor := v_cursor + v_item.probability_bps;
    if v_roll < v_cursor then
      exit;
    end if;
  end loop;

  if v_item.id is null then
    return jsonb_build_object('ok', false, 'error', 'Çark ödülleri tanımlı değil.');
  end if;

  if v_item.campaign_id is not null and not v_item.is_no_prize then
    insert into public.user_coupons (user_id, campaign_id, status, source)
    values (v_user, v_item.campaign_id, 'claimed', 'wheel')
    on conflict (user_id, campaign_id) where status in ('claimed', 'reserved')
    do nothing
    returning id into v_user_coupon;
    if v_user_coupon is null then
      select id into v_user_coupon
      from public.user_coupons
      where user_id = v_user
        and campaign_id = v_item.campaign_id
        and status in ('claimed', 'reserved', 'used')
      order by claimed_at desc
      limit 1;
    end if;
  end if;

  insert into public.reward_wheel_spins (
    config_id, user_id, item_id, campaign_id, user_coupon_id, is_win, idempotency_key
  ) values (
    v_config.id,
    v_user,
    v_item.id,
    v_item.campaign_id,
    v_user_coupon,
    v_user_coupon is not null,
    v_key
  )
  returning id into v_spin_id;

  if v_user_coupon is not null then
    update public.user_coupons
    set spin_id = v_spin_id
    where id = v_user_coupon;
    update public.coupon_campaigns
    set claim_count = claim_count + 1
    where id = v_item.campaign_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'already_processed', false,
    'spin_id', v_spin_id,
    'item_id', v_item.id,
    'label', v_item.label,
    'is_win', v_user_coupon is not null,
    'is_no_prize', v_item.is_no_prize,
    'campaign_id', v_item.campaign_id,
    'user_coupon_id', v_user_coupon,
    'sort_order', v_item.sort_order
  );
exception
  when unique_violation then
    select * into v_existing
    from public.reward_wheel_spins
    where user_id = v_user and idempotency_key = v_key;
    return jsonb_build_object(
      'ok', true,
      'already_processed', true,
      'spin_id', v_existing.id,
      'is_win', v_existing.is_win,
      'item_id', v_existing.item_id,
      'campaign_id', v_existing.campaign_id,
      'user_coupon_id', v_existing.user_coupon_id
    );
end;
$$;

create or replace function public.list_daily_deal_products(p_limit integer default 12)
returns table (
  id text,
  name text,
  brand text,
  image_url text,
  price numeric,
  discount_price numeric,
  discount_percent numeric,
  stock integer,
  seller_id uuid,
  store_name text,
  main_category text,
  sub_category text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.name,
    p.brand,
    p.image_url,
    p.price::numeric,
    p.discount_price::numeric,
    case
      when p.price > 0 and p.discount_price > 0 and p.discount_price < p.price
        then round((1 - p.discount_price / p.price) * 100)
      else 0
    end as discount_percent,
    p.stock,
    p.seller_id,
    s.business_name,
    p.main_category,
    p.sub_category
  from public.products p
  left join public.stores s on s.seller_id = p.seller_id
  where lower(coalesce(p.status, '')) in ('aktif', 'active')
    and (
      lower(coalesce(p.approval_status, '')) in ('approved', 'onaylandi', 'onaylandı', 'onayli', 'onaylı')
      or lower(coalesce(p.admin_approval_status, '')) in ('approved', 'onaylandi', 'onaylandı', 'onayli', 'onaylı')
    )
    and coalesce(p.stock, 0) > 0
    and p.discount_price is not null
    and p.discount_price > 0
    and p.price is not null
    and p.discount_price < p.price
    and coalesce(s.is_store_open, true) = true
    and coalesce(s.is_holiday_mode, false) = false
    and coalesce(s.accept_new_orders, true) = true
  order by
    (1 - p.discount_price / nullif(p.price, 0)) desc,
    p.created_at desc
  limit greatest(coalesce(p_limit, 12), 1);
$$;

create or replace function public.list_discoverable_coupons()
returns table (
  id uuid,
  name text,
  description text,
  code text,
  source_type text,
  discount_type text,
  discount_value numeric,
  max_discount numeric,
  min_order_amount numeric,
  starts_at timestamptz,
  ends_at timestamptz,
  store_id uuid,
  store_name text,
  scope_type text,
  effective_status text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    c.name,
    c.description,
    c.code,
    c.source_type,
    c.discount_type,
    c.discount_value,
    c.max_discount,
    c.min_order_amount,
    c.starts_at,
    c.ends_at,
    c.store_id,
    s.business_name,
    c.scope_type,
    public.coupon_effective_status(
      c.approval_status, c.lifecycle_status, c.starts_at, c.ends_at, timezone('utc', now())
    )
  from public.coupon_campaigns c
  left join public.stores s on s.seller_id = c.store_id
  where c.is_public = true
    and public.coupon_is_redeemable(
      c.approval_status, c.lifecycle_status, c.starts_at, c.ends_at, timezone('utc', now())
    )
    and (c.total_usage_limit is null or c.used_count < c.total_usage_limit)
  order by c.starts_at desc;
$$;

revoke all on function public.reward_wheel_save_config(jsonb) from public, anon;
revoke all on function public.spin_reward_wheel(text) from public, anon;
grant execute on function public.reward_wheel_save_config(jsonb) to authenticated;
grant execute on function public.spin_reward_wheel(text) to authenticated;
grant execute on function public.list_daily_deal_products(integer) to anon, authenticated;
grant execute on function public.list_discoverable_coupons() to anon, authenticated;
