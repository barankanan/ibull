-- Coupon engine write RPCs: upsert, moderate, claim, quote, apply.

create or replace function public.coupon_replace_scopes(
  p_campaign_id uuid,
  p_scope_type text,
  p_category_ids bigint[],
  p_product_ids text[],
  p_store_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_admin boolean := public.is_admin_user(auth.uid());
  v_seller uuid;
begin
  select seller_id into v_seller
  from public.coupon_campaigns
  where id = p_campaign_id;

  if not found then
    raise exception 'campaign not found';
  end if;
  if not v_is_admin and v_seller is distinct from auth.uid() then
    raise exception 'not authorized';
  end if;

  delete from public.coupon_campaign_categories where campaign_id = p_campaign_id;
  delete from public.coupon_campaign_products where campaign_id = p_campaign_id;
  delete from public.coupon_campaign_stores where campaign_id = p_campaign_id;

  if p_scope_type = 'categories' then
    insert into public.coupon_campaign_categories (campaign_id, category_id)
    select p_campaign_id, x
    from unnest(coalesce(p_category_ids, '{}'::bigint[])) as x
    where x is not null
    on conflict do nothing;
  elsif p_scope_type = 'products' then
    if not v_is_admin then
      if exists (
        select 1
        from unnest(coalesce(p_product_ids, '{}'::text[])) as pid
        where pid is not null
          and not exists (
            select 1 from public.products p
            where p.id = pid and p.seller_id = auth.uid()
          )
      ) then
        raise exception 'not authorized';
      end if;
    end if;
    insert into public.coupon_campaign_products (campaign_id, product_id)
    select p_campaign_id, x
    from unnest(coalesce(p_product_ids, '{}'::text[])) as x
    where x is not null and x <> ''
    on conflict do nothing;
  elsif p_scope_type = 'stores' then
    if not v_is_admin then
      if exists (
        select 1
        from unnest(coalesce(p_store_ids, '{}'::uuid[])) as sid
        where sid is distinct from auth.uid()
      ) then
        raise exception 'not authorized';
      end if;
    end if;
    insert into public.coupon_campaign_stores (campaign_id, store_id)
    select p_campaign_id, x
    from unnest(coalesce(p_store_ids, '{}'::uuid[])) as x
    where x is not null
    on conflict do nothing;
  end if;
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
    approval_status, lifecycle_status, starts_at, ends_at, created_by
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
    auth.uid()
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

create or replace function public.coupon_moderate_campaign(
  p_campaign_id uuid,
  p_action text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.coupon_campaigns%rowtype;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'not authorized';
  end if;

  select * into v_row from public.coupon_campaigns where id = p_campaign_id for update;
  if not found then
    raise exception 'campaign not found';
  end if;

  if p_action = 'approve' then
    update public.coupon_campaigns
    set approval_status = 'approved',
        rejection_reason = null,
        lifecycle_status = 'draft'
    where id = p_campaign_id;
  elsif p_action = 'reject' then
    update public.coupon_campaigns
    set approval_status = 'rejected',
        rejection_reason = nullif(btrim(coalesce(p_reason, '')), '')
    where id = p_campaign_id;
  elsif p_action = 'pause' then
    update public.coupon_campaigns
    set lifecycle_status = 'paused'
    where id = p_campaign_id;
  elsif p_action = 'resume' then
    update public.coupon_campaigns
    set lifecycle_status = 'draft'
    where id = p_campaign_id;
  else
    raise exception 'invalid action';
  end if;

  return jsonb_build_object('id', p_campaign_id, 'action', p_action);
end;
$$;

create or replace function public.coupon_product_in_scope(
  p_campaign public.coupon_campaigns,
  p_product_id text,
  p_seller_id uuid,
  p_main_category text,
  p_sub_category text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_campaign.scope_type = 'all' then
    if p_campaign.store_id is not null then
      return p_seller_id = p_campaign.store_id;
    end if;
    if p_campaign.seller_id is not null then
      return p_seller_id = p_campaign.seller_id;
    end if;
    return true;
  end if;

  if p_campaign.scope_type = 'stores' then
    return exists (
      select 1 from public.coupon_campaign_stores s
      where s.campaign_id = p_campaign.id
        and s.store_id = p_seller_id
    );
  end if;

  if p_campaign.scope_type = 'products' then
    return exists (
      select 1 from public.coupon_campaign_products p
      where p.campaign_id = p_campaign.id
        and p.product_id = p_product_id
    );
  end if;

  if p_campaign.scope_type = 'categories' then
    return exists (
      with recursive tree as (
        select c.id, c.name, c.parent_id
        from public.coupon_campaign_categories cc
        join public.categories c on c.id = cc.category_id
        where cc.campaign_id = p_campaign.id
        union all
        select child.id, child.name, child.parent_id
        from public.categories child
        join tree t on child.parent_id = t.id
      )
      select 1 from tree
      where tree.name is not null
        and (
          lower(btrim(coalesce(p_main_category, ''))) = lower(tree.name)
          or lower(btrim(coalesce(p_sub_category, ''))) = lower(tree.name)
        )
    );
  end if;

  return false;
end;
$$;

create or replace function public.coupon_compute_discount(
  p_campaign public.coupon_campaigns,
  p_eligible_subtotal numeric
)
returns numeric
language plpgsql
immutable
as $$
declare
  v_discount numeric := 0;
begin
  if p_eligible_subtotal <= 0 then
    return 0;
  end if;
  if p_campaign.min_order_amount > 0
     and p_eligible_subtotal < p_campaign.min_order_amount then
    return 0;
  end if;
  if p_campaign.discount_type = 'percent' then
    v_discount := round(p_eligible_subtotal * p_campaign.discount_value / 100.0, 2);
    if p_campaign.max_discount is not null then
      v_discount := least(v_discount, p_campaign.max_discount);
    end if;
  elsif p_campaign.discount_type = 'fixed' then
    v_discount := least(p_campaign.discount_value, p_eligible_subtotal);
  elsif p_campaign.discount_type = 'free_shipping' then
    v_discount := 0;
  elsif p_campaign.discount_type = 'special' then
    v_discount := least(coalesce(p_campaign.discount_value, 0), p_eligible_subtotal);
  end if;
  return greatest(v_discount, 0);
end;
$$;

create or replace function public.coupon_quote(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_campaign public.coupon_campaigns%rowtype;
  v_code text := upper(btrim(coalesce(p_payload->>'code', '')));
  v_campaign_id uuid := nullif(p_payload->>'campaign_id', '')::uuid;
  v_item jsonb;
  v_eligible numeric := 0;
  v_subtotal numeric := 0;
  v_discount numeric := 0;
  v_now timestamptz := timezone('utc', now());
  v_user uuid := auth.uid();
  v_owned boolean := false;
  v_user_uses int := 0;
begin
  if v_campaign_id is not null then
    select * into v_campaign from public.coupon_campaigns where id = v_campaign_id;
  elsif v_code <> '' then
    select * into v_campaign from public.coupon_campaigns where lower(code) = lower(v_code);
  end if;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Kupon bulunamadı.');
  end if;

  if not public.coupon_is_redeemable(
    v_campaign.approval_status,
    v_campaign.lifecycle_status,
    v_campaign.starts_at,
    v_campaign.ends_at,
    v_now
  ) then
    return jsonb_build_object('ok', false, 'error', 'Bu kupon şu anda geçerli değil.');
  end if;

  if v_campaign.total_usage_limit is not null
     and v_campaign.used_count >= v_campaign.total_usage_limit then
    return jsonb_build_object('ok', false, 'error', 'Kupon kullanım kotası doldu.');
  end if;

  if v_user is not null then
    select exists (
      select 1 from public.user_coupons uc
      where uc.user_id = v_user
        and uc.campaign_id = v_campaign.id
        and uc.status in ('claimed', 'reserved')
    ) into v_owned;
    select count(*) into v_user_uses
    from public.coupon_redemptions r
    where r.user_id = v_user and r.campaign_id = v_campaign.id;
    if v_campaign.per_user_limit > 0 and v_user_uses >= v_campaign.per_user_limit then
      return jsonb_build_object('ok', false, 'error', 'Bu kuponu kullanım limitine ulaştınız.');
    end if;
  end if;

  if not v_campaign.is_public and not v_owned then
    return jsonb_build_object('ok', false, 'error', 'Bu kupon size atanmamış.');
  end if;

  for v_item in
    select value from jsonb_array_elements(coalesce(p_payload->'items', '[]'::jsonb))
  loop
    v_subtotal := v_subtotal + coalesce((v_item->>'line_total')::numeric, 0);
    if public.coupon_product_in_scope(
      v_campaign,
      v_item->>'product_id',
      nullif(v_item->>'seller_id', '')::uuid,
      v_item->>'main_category',
      v_item->>'sub_category'
    ) then
      v_eligible := v_eligible + coalesce((v_item->>'line_total')::numeric, 0);
    end if;
  end loop;

  if v_eligible <= 0 then
    return jsonb_build_object(
      'ok', false,
      'error', 'Bu kupon sepetinizdeki ürünler için geçerli değil.'
    );
  end if;

  v_discount := public.coupon_compute_discount(v_campaign, v_eligible);
  if v_discount <= 0 and v_campaign.discount_type <> 'free_shipping' then
    return jsonb_build_object(
      'ok', false,
      'error', 'Minimum sepet tutarı karşılanmıyor.'
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'campaign_id', v_campaign.id,
    'code', v_campaign.code,
    'discount_amount', v_discount,
    'free_shipping', v_campaign.discount_type = 'free_shipping',
    'eligible_subtotal', v_eligible,
    'cart_subtotal', v_subtotal
  );
end;
$$;

create or replace function public.coupon_apply_to_order(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quote jsonb;
  v_campaign_id uuid;
  v_discount numeric;
  v_free boolean;
  v_order_id text := nullif(p_payload->>'order_id', '');
  v_user uuid := auth.uid();
  v_idemp text := coalesce(nullif(p_payload->>'idempotency_key', ''), v_order_id);
  v_existing uuid;
  v_used int;
  v_user_coupon uuid;
  v_campaign public.coupon_campaigns%rowtype;
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;
  if v_order_id is null then
    return jsonb_build_object('ok', false, 'error', 'Sipariş bulunamadı.');
  end if;

  select id into v_existing
  from public.coupon_redemptions
  where user_id = v_user and idempotency_key = v_idemp;
  if found then
    return jsonb_build_object('ok', true, 'already_applied', true, 'redemption_id', v_existing);
  end if;

  v_quote := public.coupon_quote(p_payload);
  if coalesce((v_quote->>'ok')::boolean, false) is not true then
    return v_quote;
  end if;

  v_campaign_id := (v_quote->>'campaign_id')::uuid;
  v_discount := coalesce((v_quote->>'discount_amount')::numeric, 0);
  v_free := coalesce((v_quote->>'free_shipping')::boolean, false);

  select * into v_campaign
  from public.coupon_campaigns
  where id = v_campaign_id
  for update;

  if v_campaign.total_usage_limit is not null
     and v_campaign.used_count >= v_campaign.total_usage_limit then
    return jsonb_build_object('ok', false, 'error', 'Kupon kullanım kotası doldu.');
  end if;

  update public.coupon_campaigns
  set used_count = used_count + 1,
      total_discount_granted = total_discount_granted + v_discount
  where id = v_campaign_id
    and (total_usage_limit is null or used_count < total_usage_limit)
  returning used_count into v_used;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Kupon kullanım kotası doldu.');
  end if;

  update public.user_coupons
  set status = 'used',
      used_at = timezone('utc', now()),
      order_id = v_order_id
  where user_id = v_user
    and campaign_id = v_campaign_id
    and status in ('claimed', 'reserved')
  returning id into v_user_coupon;

  if v_user_coupon is null then
    insert into public.user_coupons (
      user_id, campaign_id, status, source, used_at, order_id
    ) values (
      v_user, v_campaign_id, 'used', 'checkout', timezone('utc', now()), v_order_id
    )
    returning id into v_user_coupon;
  end if;

  insert into public.coupon_redemptions (
    campaign_id, user_id, user_coupon_id, order_id, discount_amount, free_shipping, idempotency_key
  ) values (
    v_campaign_id, v_user, v_user_coupon, v_order_id, v_discount, v_free, v_idemp
  );

  if to_regclass('public.orders') is not null then
    update public.orders
    set discount_amount = coalesce(discount_amount, 0) + v_discount,
        total_amount = greatest(coalesce(total_amount, 0) - v_discount, 0)
    where id::text = v_order_id
      and user_id = v_user;
  end if;

  return jsonb_build_object(
    'ok', true,
    'campaign_id', v_campaign_id,
    'discount_amount', v_discount,
    'free_shipping', v_free,
    'used_count', v_used
  );
exception
  when unique_violation then
    return jsonb_build_object('ok', true, 'already_applied', true);
end;
$$;

create or replace function public.coupon_claim(p_campaign_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_campaign public.coupon_campaigns%rowtype;
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_campaign
  from public.coupon_campaigns
  where id = p_campaign_id
  for update;
  if not found then
    raise exception 'campaign not found';
  end if;
  if not v_campaign.is_public then
    return jsonb_build_object('ok', false, 'error', 'Bu kupon herkese açık değil.');
  end if;
  if not public.coupon_is_redeemable(
    v_campaign.approval_status,
    v_campaign.lifecycle_status,
    v_campaign.starts_at,
    v_campaign.ends_at,
    timezone('utc', now())
  ) then
    return jsonb_build_object('ok', false, 'error', 'Bu kupon şu anda geçerli değil.');
  end if;

  insert into public.user_coupons (user_id, campaign_id, status, source)
  values (auth.uid(), p_campaign_id, 'claimed', 'claim')
  on conflict (user_id, campaign_id) where status in ('claimed', 'reserved')
  do nothing
  returning id into v_id;

  if v_id is not null then
    update public.coupon_campaigns
    set claim_count = claim_count + 1
    where id = p_campaign_id;
  else
    select id into v_id
    from public.user_coupons
    where user_id = auth.uid() and campaign_id = p_campaign_id
    order by claimed_at desc
    limit 1;
  end if;

  return jsonb_build_object('ok', true, 'user_coupon_id', v_id);
end;
$$;

create or replace function public.coupon_record_view(p_campaign_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.coupon_campaigns
  set view_count = view_count + 1
  where id = p_campaign_id
    and is_public = true
    and approval_status = 'approved';
end;
$$;

revoke all on function public.coupon_replace_scopes(uuid, text, bigint[], text[], uuid[]) from public;
revoke all on function public.coupon_upsert_campaign(jsonb) from public, anon;
revoke all on function public.coupon_moderate_campaign(uuid, text, text) from public, anon;
revoke all on function public.coupon_quote(jsonb) from public;
revoke all on function public.coupon_apply_to_order(jsonb) from public, anon;
revoke all on function public.coupon_claim(uuid) from public, anon;
revoke all on function public.coupon_record_view(uuid) from public;

grant execute on function public.coupon_upsert_campaign(jsonb) to authenticated;
grant execute on function public.coupon_moderate_campaign(uuid, text, text) to authenticated;
grant execute on function public.coupon_quote(jsonb) to authenticated;
grant execute on function public.coupon_apply_to_order(jsonb) to authenticated;
grant execute on function public.coupon_claim(uuid) to authenticated;
grant execute on function public.coupon_record_view(uuid) to anon, authenticated;
grant execute on function public.coupon_product_in_scope(public.coupon_campaigns, text, uuid, text, text) to authenticated;
grant execute on function public.coupon_compute_discount(public.coupon_campaigns, numeric) to authenticated;
grant execute on function public.coupon_replace_scopes(uuid, text, bigint[], text[], uuid[]) to authenticated;
