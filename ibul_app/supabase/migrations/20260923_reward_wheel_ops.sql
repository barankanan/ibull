-- Gift wheel ops: persist extra config, seller wheel requests, eligibility,
-- personalized visibility without mutating admin probabilities, safer spin.

alter table public.coupon_campaigns
  add column if not exists wheel_requested boolean not null default false;

alter table public.coupon_campaigns
  add column if not exists ad_budget numeric(12,2);

alter table public.coupon_campaigns
  add column if not exists ad_duration_days integer;

alter table public.reward_wheel_configs
  add column if not exists use_global_pool boolean not null default true;

alter table public.reward_wheel_configs
  add column if not exists per_user_daily_limit integer not null default 1;

alter table public.reward_wheel_items
  add column if not exists is_active boolean not null default true;

create index if not exists coupon_campaigns_wheel_requested_idx
  on public.coupon_campaigns (wheel_requested, approval_status)
  where wheel_requested = true;

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
    new.wheel_requested := coalesce(new.wheel_requested, false);
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
    if old.approval_status = 'approved' then
      new.wheel_requested := old.wheel_requested;
    end if;
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

create or replace function public.coupon_upsert_campaign(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_admin boolean := public.is_admin_user(auth.uid());
  v_id uuid;
  v_code text;
  v_source text;
  v_approval text;
  v_existing public.coupon_campaigns%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  v_id := nullif(p_payload->>'id', '')::uuid;
  v_code := upper(btrim(coalesce(p_payload->>'code', '')));
  if v_code = '' then
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  end if;

  if exists (
    select 1 from public.coupon_campaigns c
    where lower(c.code) = lower(v_code)
      and (v_id is null or c.id <> v_id)
  ) then
    raise exception 'coupon code already exists';
  end if;

  v_source := coalesce(p_payload->>'source_type', 'ibul');
  if v_is_admin then
    v_approval := coalesce(p_payload->>'approval_status', 'approved');
  else
    v_source := case when v_source = 'coupon_ad' then 'coupon_ad' else 'seller' end;
    v_approval := coalesce(nullif(p_payload->>'approval_status', ''), 'pending_review');
    if v_approval not in ('draft', 'pending_review') then
      v_approval := 'pending_review';
    end if;
  end if;

  if v_id is not null then
    select * into v_existing from public.coupon_campaigns where id = v_id;
    if not found then
      raise exception 'campaign not found';
    end if;
    if not v_is_admin and v_existing.seller_id is distinct from auth.uid() then
      raise exception 'not authorized';
    end if;
  end if;

  insert into public.coupon_campaigns (
    id, name, description, code, source_type, discount_type, discount_value,
    max_discount, min_order_amount, per_user_limit, total_usage_limit,
    new_users_only, is_public, payment_type, scope_type, seller_id, store_id,
    approval_status, lifecycle_status, starts_at, ends_at, created_by,
    wheel_requested, ad_budget, ad_duration_days
  ) values (
    coalesce(v_id, gen_random_uuid()),
    btrim(coalesce(p_payload->>'name', '')),
    nullif(p_payload->>'description', ''),
    v_code,
    v_source,
    coalesce(p_payload->>'discount_type', 'percent'),
    coalesce((p_payload->>'discount_value')::numeric, 0),
    nullif(p_payload->>'max_discount', '')::numeric,
    coalesce((p_payload->>'min_order_amount')::numeric, 0),
    coalesce((p_payload->>'per_user_limit')::int, 1),
    nullif(p_payload->>'total_usage_limit', '')::int,
    coalesce((p_payload->>'new_users_only')::boolean, false),
    coalesce((p_payload->>'is_public')::boolean, true),
    nullif(p_payload->>'payment_type', ''),
    coalesce(p_payload->>'scope_type', 'all'),
    case when v_is_admin then nullif(p_payload->>'seller_id', '')::uuid else auth.uid() end,
    case
      when v_is_admin then coalesce(
        nullif(p_payload->>'store_id', '')::uuid,
        nullif(p_payload->>'seller_id', '')::uuid
      )
      else auth.uid()
    end,
    v_approval,
    coalesce(p_payload->>'lifecycle_status', 'draft'),
    coalesce((p_payload->>'starts_at')::timestamptz, timezone('utc', now())),
    coalesce((p_payload->>'ends_at')::timestamptz, timezone('utc', now()) + interval '1 day'),
    auth.uid(),
    coalesce((p_payload->>'wheel_requested')::boolean, false),
    nullif(p_payload->>'ad_budget', '')::numeric,
    nullif(p_payload->>'ad_duration_days', '')::int
  )
  on conflict (id) do update set
    name = excluded.name,
    description = excluded.description,
    code = excluded.code,
    discount_type = excluded.discount_type,
    discount_value = excluded.discount_value,
    max_discount = excluded.max_discount,
    min_order_amount = excluded.min_order_amount,
    per_user_limit = excluded.per_user_limit,
    total_usage_limit = excluded.total_usage_limit,
    new_users_only = excluded.new_users_only,
    is_public = excluded.is_public,
    payment_type = excluded.payment_type,
    scope_type = excluded.scope_type,
    approval_status = case
      when public.is_admin_user(auth.uid()) then excluded.approval_status
      else public.coupon_campaigns.approval_status
    end,
    lifecycle_status = excluded.lifecycle_status,
    starts_at = excluded.starts_at,
    ends_at = excluded.ends_at,
    wheel_requested = case
      when public.is_admin_user(auth.uid()) then excluded.wheel_requested
      when public.coupon_campaigns.approval_status = 'approved' then public.coupon_campaigns.wheel_requested
      else excluded.wheel_requested
    end,
    ad_budget = excluded.ad_budget,
    ad_duration_days = excluded.ad_duration_days,
    rejection_reason = case
      when excluded.approval_status = 'pending_review' then null
      else public.coupon_campaigns.rejection_reason
    end
  returning id into v_id;

  perform public.coupon_replace_scopes(
    v_id,
    coalesce(p_payload->>'scope_type', 'all'),
    case
      when jsonb_typeof(p_payload->'category_ids') = 'array'
        then array(select jsonb_array_elements_text(p_payload->'category_ids')::bigint)
      else '{}'::bigint[]
    end,
    case
      when jsonb_typeof(p_payload->'product_ids') = 'array'
        then array(select jsonb_array_elements_text(p_payload->'product_ids'))
      else '{}'::text[]
    end,
    case
      when jsonb_typeof(p_payload->'store_ids') = 'array'
        then array(select jsonb_array_elements_text(p_payload->'store_ids')::uuid)
      else '{}'::uuid[]
    end
  );

  return jsonb_build_object('id', v_id, 'code', v_code, 'approval_status', v_approval);
end;
$$;

create or replace function public.reward_wheel_coupon_winnable(
  p_campaign public.coupon_campaigns,
  p_now timestamptz default timezone('utc', now())
)
returns boolean
language sql
stable
set search_path = public
as $$
  select
    p_campaign.approval_status = 'approved'
    and public.coupon_is_redeemable(
      p_campaign.approval_status,
      p_campaign.lifecycle_status,
      p_campaign.starts_at,
      p_campaign.ends_at,
      p_now
    )
    and (p_campaign.total_usage_limit is null or p_campaign.used_count < p_campaign.total_usage_limit)
    and (p_campaign.total_usage_limit is null or p_campaign.claim_count < p_campaign.total_usage_limit);
$$;

create or replace function public.reward_wheel_compose_for_user(
  p_user uuid,
  p_config public.reward_wheel_configs
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_has_signals boolean := false;
  v_items jsonb := '[]'::jsonb;
  v_dropped int := 0;
  v_row record;
  v_no_prize jsonb;
  v_cat_tokens text[] := '{}';
  v_store_ids uuid[] := '{}';
  v_product_ids text[] := '{}';
begin
  if p_user is not null and to_regclass('public.orders') is not null then
    begin
      select coalesce(array_agg(distinct o.seller_id), '{}')
      into v_store_ids
      from public.orders o
      where o.user_id = p_user
        and o.seller_id is not null;

      if to_regclass('public.order_items') is not null then
        select coalesce(array_agg(distinct oi.product_id::text), '{}')
        into v_product_ids
        from public.orders o
        join public.order_items oi on oi.order_id = o.id
        where o.user_id = p_user
          and oi.product_id is not null;

        select coalesce(array_agg(distinct lower(btrim(p.main_category))), '{}')
        into v_cat_tokens
        from public.orders o
        join public.order_items oi on oi.order_id = o.id
        join public.products p on p.id = oi.product_id
        where o.user_id = p_user
          and coalesce(p.main_category, '') <> '';
      end if;
    exception when others then
      v_cat_tokens := '{}';
      v_store_ids := '{}';
      v_product_ids := '{}';
    end;
  end if;

  v_has_signals :=
    coalesce(array_length(v_cat_tokens, 1), 0) > 0
    or coalesce(array_length(v_store_ids, 1), 0) > 0
    or coalesce(array_length(v_product_ids, 1), 0) > 0;

  for v_row in
    select
      i.*,
      c as campaign,
      (
        case
          when i.is_no_prize then 1
          when c.id is null then 0
          else
            (case when exists (
                  select 1 from unnest(v_cat_tokens) s(token)
                  where length(s.token) >= 3
                    and position(s.token in lower(coalesce(i.label, '') || ' ' || coalesce(c.name, ''))) > 0
                ) then 3 else 0 end)
            + (case when c.store_id = any(v_store_ids) or c.seller_id = any(v_store_ids)
               then 2 else 0 end)
            + (
              select count(*) from public.coupon_campaign_products cp
              where cp.campaign_id = c.id
                and cp.product_id = any(v_product_ids)
            ) * 2
        end
      ) as relevance
    from public.reward_wheel_items i
    left join public.coupon_campaigns c on c.id = i.campaign_id
    where i.config_id = p_config.id
      and coalesce(i.is_active, true)
    order by i.sort_order, i.created_at
  loop
    if v_row.is_no_prize then
      v_items := v_items || jsonb_build_array(jsonb_build_object(
        'id', v_row.id,
        'campaign_id', v_row.campaign_id,
        'label', v_row.label,
        'is_no_prize', true,
        'is_active', true,
        'probability_bps', v_row.probability_bps,
        'sort_order', v_row.sort_order,
        'color_hex', v_row.color_hex,
        'relevance', 1
      ));
      continue;
    end if;

    if v_row.campaign is null
       or not public.reward_wheel_coupon_winnable(v_row.campaign, v_now) then
      v_dropped := v_dropped + v_row.probability_bps;
      continue;
    end if;

    if coalesce(p_config.use_global_pool, true) or not v_has_signals or v_row.relevance > 0 then
      v_items := v_items || jsonb_build_array(jsonb_build_object(
        'id', v_row.id,
        'campaign_id', v_row.campaign_id,
        'label', v_row.label,
        'is_no_prize', false,
        'is_active', true,
        'probability_bps', v_row.probability_bps,
        'sort_order', v_row.sort_order,
        'color_hex', v_row.color_hex,
        'relevance', v_row.relevance
      ));
    else
      v_dropped := v_dropped + v_row.probability_bps;
    end if;
  end loop;

  if v_dropped > 0 then
    select value
      into v_no_prize
    from jsonb_array_elements(v_items) as t(value)
    where (value->>'is_no_prize')::boolean
    limit 1;

    if v_no_prize is not null then
      v_items := (
        select jsonb_agg(
          case
            when (value->>'is_no_prize')::boolean then
              jsonb_set(
                value,
                '{probability_bps}',
                to_jsonb(least(10000, (value->>'probability_bps')::int + v_dropped))
              )
            else value
          end
        )
        from jsonb_array_elements(v_items) as t(value)
      );
    end if;
  end if;

  if v_has_signals
     and not coalesce(p_config.use_global_pool, true)
     and not exists (
       select 1 from jsonb_array_elements(v_items) t(value)
       where coalesce((value->>'is_no_prize')::boolean, false) = false
     ) then
    return public.reward_wheel_compose_for_user(null, p_config);
  end if;

  return coalesce(v_items, '[]'::jsonb);
end;
$$;

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
  v_active_total int := 0;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'not authorized';
  end if;

  if jsonb_typeof(p_payload->'items') is distinct from 'array' then
    raise exception 'wheel items required';
  end if;

  select coalesce(sum((value->>'probability_bps')::int), 0)
  into v_total
  from jsonb_array_elements(p_payload->'items')
  where coalesce((value->>'is_active')::boolean, true);

  if v_total <> 10000 then
    raise exception 'probability total must be 100 percent'
      using errcode = 'P0001',
            hint = v_total::text;
  end if;

  v_id := nullif(p_payload->>'id', '')::uuid;

  if v_id is null then
    insert into public.reward_wheel_configs (
      is_active, daily_free_spins, cooldown_hours, starts_at, ends_at,
      created_by, use_global_pool, per_user_daily_limit
    ) values (
      coalesce((p_payload->>'is_active')::boolean, false),
      coalesce((p_payload->>'daily_free_spins')::int, 1),
      coalesce((p_payload->>'cooldown_hours')::numeric, 24),
      nullif(p_payload->>'starts_at', '')::timestamptz,
      nullif(p_payload->>'ends_at', '')::timestamptz,
      auth.uid(),
      coalesce((p_payload->>'use_global_pool')::boolean, true),
      coalesce((p_payload->>'per_user_daily_limit')::int, 1)
    )
    returning id into v_id;
  else
    update public.reward_wheel_configs
    set is_active = coalesce((p_payload->>'is_active')::boolean, is_active),
        daily_free_spins = coalesce((p_payload->>'daily_free_spins')::int, daily_free_spins),
        cooldown_hours = coalesce((p_payload->>'cooldown_hours')::numeric, cooldown_hours),
        starts_at = nullif(p_payload->>'starts_at', '')::timestamptz,
        ends_at = nullif(p_payload->>'ends_at', '')::timestamptz,
        use_global_pool = coalesce((p_payload->>'use_global_pool')::boolean, use_global_pool),
        per_user_daily_limit = coalesce(
          (p_payload->>'per_user_daily_limit')::int,
          per_user_daily_limit
        )
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
      config_id, campaign_id, label, is_no_prize, probability_bps, sort_order,
      color_hex, is_active
    ) values (
      v_id,
      v_campaign,
      coalesce(nullif(v_item->>'label', ''), 'Ödül'),
      coalesce((v_item->>'is_no_prize')::boolean, v_campaign is null),
      coalesce((v_item->>'probability_bps')::int, 0),
      coalesce((v_item->>'sort_order')::int, 0),
      nullif(v_item->>'color_hex', ''),
      coalesce((v_item->>'is_active')::boolean, true)
    );
    if coalesce((v_item->>'is_active')::boolean, true) then
      v_active_total := v_active_total + 1;
    end if;
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

  return jsonb_build_object(
    'ok', true,
    'id', v_id,
    'probability_bps', v_total,
    'active_item_count', v_active_total
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
begin
  select * into v_config
  from public.reward_wheel_configs
  where is_active = true
  order by updated_at desc
  limit 1;

  if not found then
    return jsonb_build_object('ok', true, 'is_active', false, 'items', '[]'::jsonb);
  end if;
  if v_config.starts_at is not null and v_now < v_config.starts_at then
    return jsonb_build_object('ok', true, 'is_active', false, 'items', '[]'::jsonb);
  end if;
  if v_config.ends_at is not null and v_now > v_config.ends_at then
    return jsonb_build_object('ok', true, 'is_active', false, 'items', '[]'::jsonb);
  end if;

  v_items := public.reward_wheel_compose_for_user(auth.uid(), v_config);
  return jsonb_build_object(
    'ok', true,
    'id', v_config.id,
    'is_active', true,
    'daily_free_spins', v_config.daily_free_spins,
    'per_user_daily_limit', v_config.per_user_daily_limit,
    'cooldown_hours', v_config.cooldown_hours,
    'use_global_pool', v_config.use_global_pool,
    'items', coalesce(v_items, '[]'::jsonb)
  );
end;
$$;

create or replace function public.reward_wheel_admin_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_today timestamptz := date_trunc('day', timezone('Europe/Istanbul', timezone('utc', now())))
    at time zone 'Europe/Istanbul';
  v_config uuid;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'not authorized';
  end if;

  select id into v_config
  from public.reward_wheel_configs
  order by updated_at desc
  limit 1;

  return jsonb_build_object(
    'active_rewards', (
      select count(*) from public.reward_wheel_items
      where config_id = v_config and coalesce(is_active, true)
    ),
    'pending_seller_offers', (
      select count(*) from public.coupon_campaigns
      where wheel_requested = true
        and approval_status = 'pending_review'
    ),
    'today_spins', (
      select count(*) from public.reward_wheel_spins
      where created_at >= v_today
    ),
    'today_wins', (
      select count(*) from public.reward_wheel_spins
      where created_at >= v_today and is_win = true
    )
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
  v_spin_count int := 0;
  v_last timestamptz;
  v_roll int;
  v_cursor int := 0;
  v_spin_id uuid;
  v_user_coupon uuid;
  v_visible jsonb;
  v_choice jsonb;
  v_daily_limit int;
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

  v_daily_limit := greatest(
    coalesce(v_config.daily_free_spins, 0),
    coalesce(v_config.per_user_daily_limit, 0)
  );

  select count(*), max(created_at)
  into v_spin_count, v_last
  from public.reward_wheel_spins
  where user_id = v_user
    and created_at >= (
      date_trunc('day', timezone('Europe/Istanbul', v_now))
      at time zone 'Europe/Istanbul'
    );

  if v_daily_limit > 0 and v_spin_count >= v_daily_limit then
    return jsonb_build_object('ok', false, 'error', 'Bugünkü çevirme hakkınız doldu.');
  end if;
  if v_config.cooldown_hours > 0 and v_last is not null
     and v_last + (v_config.cooldown_hours || ' hours')::interval > v_now then
    return jsonb_build_object('ok', false, 'error', 'Çevirme hakkınız henüz dolmadı.');
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

  return jsonb_build_object(
    'ok', true,
    'already_processed', false,
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
      'spin_id', v_existing.id,
      'is_win', v_existing.is_win,
      'item_id', v_existing.item_id,
      'campaign_id', v_existing.campaign_id,
      'user_coupon_id', v_existing.user_coupon_id
    );
end;
$$;

revoke all on function public.reward_wheel_save_config(jsonb) from public, anon;
revoke all on function public.spin_reward_wheel(text) from public, anon;
revoke all on function public.reward_wheel_admin_stats() from public, anon;
grant execute on function public.reward_wheel_save_config(jsonb) to authenticated;
grant execute on function public.spin_reward_wheel(text) to authenticated;
grant execute on function public.reward_wheel_admin_stats() to authenticated;
grant execute on function public.get_reward_wheel_for_user() to anon, authenticated;
grant execute on function public.reward_wheel_compose_for_user(uuid, public.reward_wheel_configs) to authenticated;
grant execute on function public.reward_wheel_coupon_winnable(public.coupon_campaigns, timestamptz) to authenticated;
