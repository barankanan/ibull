-- Single eligibility source for homepage visibility and spin_reward_wheel.
-- Daily limit uses Istanbul day. Cooldown uses the user's last spin (any day).

create or replace function public.reward_wheel_user_eligibility(
  p_user uuid,
  p_config public.reward_wheel_configs,
  p_now timestamptz default timezone('utc', now())
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_daily_limit int;
  v_spin_count int := 0;
  v_last timestamptz;
  v_day_start timestamptz;
  v_cooldown_until timestamptz;
  v_next timestamptz;
  v_can boolean := true;
  v_reason text := 'ok';
begin
  if p_user is null then
    return jsonb_build_object(
      'can_spin', false,
      'reason', 'not_authenticated',
      'daily_used', 0,
      'daily_limit', 0,
      'last_spin_at', null,
      'next_spin_at', null
    );
  end if;

  if p_config.id is null or coalesce(p_config.is_active, false) is not true then
    return jsonb_build_object(
      'can_spin', false,
      'reason', 'inactive',
      'daily_used', 0,
      'daily_limit', 0,
      'last_spin_at', null,
      'next_spin_at', null
    );
  end if;

  if p_config.starts_at is not null and p_now < p_config.starts_at then
    return jsonb_build_object(
      'can_spin', false,
      'reason', 'not_started',
      'daily_used', 0,
      'daily_limit', greatest(
        coalesce(p_config.daily_free_spins, 0),
        coalesce(p_config.per_user_daily_limit, 0)
      ),
      'last_spin_at', null,
      'next_spin_at', p_config.starts_at
    );
  end if;

  if p_config.ends_at is not null and p_now > p_config.ends_at then
    return jsonb_build_object(
      'can_spin', false,
      'reason', 'ended',
      'daily_used', 0,
      'daily_limit', greatest(
        coalesce(p_config.daily_free_spins, 0),
        coalesce(p_config.per_user_daily_limit, 0)
      ),
      'last_spin_at', null,
      'next_spin_at', null
    );
  end if;

  v_daily_limit := greatest(
    coalesce(p_config.daily_free_spins, 0),
    coalesce(p_config.per_user_daily_limit, 0)
  );
  v_day_start := date_trunc('day', timezone('Europe/Istanbul', p_now))
    at time zone 'Europe/Istanbul';

  select count(*)
  into v_spin_count
  from public.reward_wheel_spins
  where user_id = p_user
    and created_at >= v_day_start;

  select max(created_at)
  into v_last
  from public.reward_wheel_spins
  where user_id = p_user;

  if v_daily_limit > 0 and v_spin_count >= v_daily_limit then
    v_can := false;
    v_reason := 'daily_limit';
    v_next := v_day_start + interval '1 day';
  end if;

  if p_config.cooldown_hours > 0 and v_last is not null then
    v_cooldown_until := v_last + (p_config.cooldown_hours || ' hours')::interval;
    if v_cooldown_until > p_now then
      v_can := false;
      if v_next is null or v_cooldown_until > v_next then
        v_next := v_cooldown_until;
        v_reason := 'cooldown';
      end if;
    end if;
  end if;

  if v_can then
    v_reason := 'ok';
    v_next := null;
  end if;

  return jsonb_build_object(
    'can_spin', v_can,
    'reason', v_reason,
    'daily_used', v_spin_count,
    'daily_limit', v_daily_limit,
    'last_spin_at', v_last,
    'next_spin_at', v_next
  );
end;
$$;

create or replace function public.get_reward_wheel_for_user()
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_config public.reward_wheel_configs%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_items jsonb;
  v_elig jsonb;
  v_can boolean := false;
begin
  select * into v_config
  from public.reward_wheel_configs
  where is_active = true
  order by updated_at desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'ok', true,
      'is_active', false,
      'can_spin', false,
      'items', '[]'::jsonb
    );
  end if;

  v_elig := public.reward_wheel_user_eligibility(auth.uid(), v_config, v_now);
  if v_elig->>'reason' in ('inactive', 'not_started', 'ended') then
    return jsonb_build_object(
      'ok', true,
      'id', v_config.id,
      'is_active', false,
      'can_spin', false,
      'eligibility_reason', v_elig->>'reason',
      'next_spin_at', v_elig->>'next_spin_at',
      'items', '[]'::jsonb
    );
  end if;

  v_items := public.reward_wheel_compose_for_user(auth.uid(), v_config);
  v_can := coalesce((v_elig->>'can_spin')::boolean, false)
    and coalesce(jsonb_array_length(v_items), 0) > 0;

  return jsonb_build_object(
    'ok', true,
    'id', v_config.id,
    'is_active', true,
    'can_spin', v_can,
    'eligibility_reason', v_elig->>'reason',
    'next_spin_at', v_elig->>'next_spin_at',
    'daily_free_spins', v_config.daily_free_spins,
    'per_user_daily_limit', v_config.per_user_daily_limit,
    'cooldown_hours', v_config.cooldown_hours,
    'use_global_pool', v_config.use_global_pool,
    'items', coalesce(v_items, '[]'::jsonb)
  );
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
  v_campaign public.coupon_campaigns%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_roll int;
  v_cursor int := 0;
  v_spin_id uuid;
  v_user_coupon uuid;
  v_visible jsonb;
  v_choice jsonb;
  v_elig jsonb;
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
      'can_spin', false,
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

  v_elig := public.reward_wheel_user_eligibility(v_user, v_config, v_now);
  if coalesce((v_elig->>'can_spin')::boolean, false) is not true then
    return jsonb_build_object(
      'ok', false,
      'can_spin', false,
      'error', case v_elig->>'reason'
        when 'not_authenticated' then 'Giriş yapmalısınız.'
        when 'inactive' then 'Hediye çarkı şu anda kapalı.'
        when 'not_started' then 'Hediye çarkı henüz başlamadı.'
        when 'ended' then 'Hediye çarkı süresi doldu.'
        when 'daily_limit' then 'Bugünkü çevirme hakkınız doldu.'
        when 'cooldown' then 'Çevirme hakkınız henüz dolmadı.'
        else 'Çark çevrilemedi.'
      end
    );
  end if;

  v_visible := public.reward_wheel_compose_for_user(v_user, v_config);
  if v_visible is null or jsonb_array_length(v_visible) = 0 then
    return jsonb_build_object('ok', false, 'error', 'Çark ödülleri tanımlı değil.');
  end if;

  v_roll := floor(random() * 10000)::int;
  for v_choice in select value from jsonb_array_elements(v_visible)
  loop
    v_cursor := v_cursor + coalesce((v_choice->>'probability_bps')::int, 0);
    if v_roll < v_cursor then
      exit;
    end if;
  end loop;

  if v_choice is null then
    return jsonb_build_object('ok', false, 'error', 'Çark ödülleri tanımlı değil.');
  end if;

  select * into v_item
  from public.reward_wheel_items
  where id = nullif(v_choice->>'id', '')::uuid;

  if coalesce((v_choice->>'is_no_prize')::boolean, false) = false
     and v_item.campaign_id is not null then
    select * into v_campaign
    from public.coupon_campaigns
    where id = v_item.campaign_id
    for update;
    if not found or not public.reward_wheel_coupon_winnable(v_campaign, v_now) then
      v_item.is_no_prize := true;
      v_campaign := null;
    else
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
      else
        update public.coupon_campaigns
        set claim_count = claim_count + 1,
            used_count = used_count + 1
        where id = v_item.campaign_id;
      end if;
    end if;
  end if;

  insert into public.reward_wheel_spins (
    config_id, user_id, item_id, campaign_id, user_coupon_id, is_win, idempotency_key
  ) values (
    v_config.id,
    v_user,
    v_item.id,
    case when v_user_coupon is not null then v_item.campaign_id else null end,
    v_user_coupon,
    v_user_coupon is not null,
    v_key
  )
  returning id into v_spin_id;

  if v_user_coupon is not null then
    update public.user_coupons
    set spin_id = v_spin_id
    where id = v_user_coupon;
  end if;

  v_elig := public.reward_wheel_user_eligibility(v_user, v_config, v_now);

  return jsonb_build_object(
    'ok', true,
    'already_processed', false,
    'can_spin', coalesce((v_elig->>'can_spin')::boolean, false),
    'spin_id', v_spin_id,
    'item_id', v_item.id,
    'label', coalesce(v_choice->>'label', v_item.label),
    'is_win', v_user_coupon is not null,
    'is_no_prize', v_user_coupon is null,
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
      'can_spin', false,
      'spin_id', v_existing.id,
      'is_win', v_existing.is_win,
      'item_id', v_existing.item_id,
      'campaign_id', v_existing.campaign_id,
      'user_coupon_id', v_existing.user_coupon_id
    );
end;
$$;

revoke all on function public.reward_wheel_user_eligibility(uuid, public.reward_wheel_configs, timestamptz) from public, anon;
grant execute on function public.reward_wheel_user_eligibility(uuid, public.reward_wheel_configs, timestamptz) to authenticated;
grant execute on function public.get_reward_wheel_for_user() to anon, authenticated;
grant execute on function public.spin_reward_wheel(text) to authenticated;
