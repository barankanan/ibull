-- AVM yönetimi v2 operasyon: reklam (mevcut campaigns tablosu), istatistik, ekip, son işlemler.
-- Önkoşul: core + 20261009_mall_management_v2_patch.sql. db push yok.
-- campaigns tablosunun kolonları değişmez; yalnız type='mall_feature' satırları için guard trigger eklenir.

begin;

-- ---------------------------------------------------------------- ads (reuse campaigns)
create or replace function public.enforce_mall_ad_campaign_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.type, '') <> 'mall_feature' and (tg_op = 'INSERT' or coalesce(old.type, '') <> 'mall_feature') then
    return new;
  end if;
  if public.is_admin_user() or current_setting('ibul.mall_ad_rpc', true) = 'on' then
    return new;
  end if;
  if tg_op = 'INSERT' or new.type is distinct from old.type then
    raise exception 'AVM reklamı yalnız AVM panelinden oluşturulur.' using errcode = '42501';
  end if;
  if new.status is distinct from old.status
     or new.approved_at is distinct from old.approved_at
     or new.rejected_at is distinct from old.rejected_at
     or new.review_notes is distinct from old.review_notes
     or new.metadata is distinct from old.metadata then
    raise exception 'AVM reklamı durumu admin onayı gerektirir.' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_mall_ad_campaign_status on public.campaigns;
create trigger trg_enforce_mall_ad_campaign_status
before insert or update on public.campaigns
for each row execute function public.enforce_mall_ad_campaign_status();

create or replace function public.create_mall_ad(
  p_mall_id uuid, p_name text, p_placement text, p_starts_at timestamptz, p_ends_at timestamptz,
  p_total_budget numeric, p_submit boolean
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id text := gen_random_uuid()::text;
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager', 'mall_ad_manager']);
  if p_placement not in ('mall_home_banner', 'mall_map_featured', 'mall_detail_banner', 'mall_campaign_featured') then
    raise exception 'Geçersiz reklam alanı.';
  end if;
  if char_length(btrim(coalesce(p_name, ''))) not between 1 and 120 then
    raise exception 'Reklam adı gerekli.';
  end if;
  if p_ends_at <= p_starts_at then
    raise exception 'Bitiş tarihi başlangıçtan sonra olmalı.';
  end if;
  perform set_config('ibul.mall_ad_rpc', 'on', true);
  insert into public.campaigns (id, seller_id, name, type, objective, status, billing_model,
    daily_budget, total_budget, starts_at, ends_at, metadata)
  values (v_id, auth.uid(), btrim(p_name), 'mall_feature', 'store_visits',
    case when p_submit then 'pending_review' else 'draft' end, 'flat', 0, greatest(coalesce(p_total_budget, 0), 0),
    p_starts_at, p_ends_at,
    jsonb_build_object('scope', 'mall', 'mall_id', p_mall_id, 'placement', p_placement));
  insert into public.campaign_targets (campaign_id, objective, placements)
  values (v_id, 'store_visits', jsonb_build_array(p_placement));
  perform set_config('ibul.mall_ad_rpc', 'off', true);
  return v_id;
end;
$$;

create or replace function public.submit_mall_ad(p_mall_id uuid, p_campaign_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager', 'mall_ad_manager']);
  perform set_config('ibul.mall_ad_rpc', 'on', true);
  update public.campaigns set status = 'pending_review'
  where id = p_campaign_id and type = 'mall_feature' and status = 'draft'
    and metadata ->> 'mall_id' = p_mall_id::text;
  if not found then
    raise exception 'Taslak reklam bulunamadı.';
  end if;
  perform set_config('ibul.mall_ad_rpc', 'off', true);
end;
$$;

create or replace function public.mall_ad_campaigns(p_mall_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.mall_management_assert_role(p_mall_id, public.mall_any_role());
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'name', c.name, 'status', c.status, 'placement', c.metadata ->> 'placement',
      'starts_at', c.starts_at, 'ends_at', c.ends_at, 'total_budget', c.total_budget,
      'review_notes', c.review_notes, 'created_at', c.created_at) order by c.created_at desc)
    from public.campaigns c
    where c.type = 'mall_feature' and c.metadata ->> 'mall_id' = p_mall_id::text
  ), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------- analytics
create table if not exists public.mall_analytics_events (
  id bigserial primary key,
  mall_id uuid not null references public.malls (id) on delete cascade,
  event_type text not null,
  ref_id text,
  user_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  constraint mall_analytics_events_type_check check (
    event_type in ('mall_view', 'map_open', 'store_profile_click', 'directions_click', 'campaign_view')
  ),
  constraint mall_analytics_events_ref_len check (ref_id is null or char_length(ref_id) <= 80)
);

create index if not exists idx_mall_analytics_events_mall on public.mall_analytics_events (mall_id, created_at desc);

alter table public.mall_analytics_events enable row level security;
revoke all on table public.mall_analytics_events from public, anon, authenticated;

create or replace function public.track_mall_event(p_mall_id uuid, p_event text, p_ref text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.malls m where m.id = p_mall_id and m.status = 'active') then
    return;
  end if;
  insert into public.mall_analytics_events (mall_id, event_type, ref_id, user_id)
  values (p_mall_id, p_event, left(p_ref, 80), auth.uid());
end;
$$;

create or replace function public.mall_event_stats(p_mall_id uuid, p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_since timestamptz := timezone('utc', now()) - make_interval(days => greatest(1, least(coalesce(p_days, 30), 365)));
begin
  perform public.mall_management_assert_role(p_mall_id, public.mall_any_role());
  return jsonb_build_object(
    'totals', coalesce((
      select jsonb_object_agg(event_type, n)
      from (select event_type, count(*) n from public.mall_analytics_events
            where mall_id = p_mall_id and created_at >= v_since group by event_type) t
    ), '{}'::jsonb),
    'daily', coalesce((
      select jsonb_agg(jsonb_build_object('day', d.event_day, 'count', d.n) order by d.event_day)
      from (select date_trunc('day', created_at)::date as event_day, count(*) as n from public.mall_analytics_events
            where mall_id = p_mall_id and created_at >= v_since group by 1) d
    ), '[]'::jsonb)
  );
end;
$$;

-- ---------------------------------------------------------------- team
create or replace function public.mall_member_directory(p_mall_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.mall_management_assert_role(p_mall_id, public.mall_any_role());
  return jsonb_build_object(
    'members', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', mm.user_id, 'role', mm.role, 'status', mm.status, 'created_at', mm.created_at,
        'display_name', coalesce(nullif(btrim(u.display_name), ''), split_part(u.email, '@', 1)),
        'email', u.email, 'is_self', mm.user_id = auth.uid()) order by mm.created_at)
      from public.mall_members mm
      left join public.users u on u.id = mm.user_id
      where mm.mall_id = p_mall_id and mm.status <> 'removed'
    ), '[]'::jsonb),
    'invitations', coalesce((
      select jsonb_agg(jsonb_build_object('email', i.email, 'role', i.role, 'created_at', i.created_at)
                       order by i.created_at desc)
      from public.mall_invitations i
      where i.mall_id = p_mall_id and i.status = 'pending'
        and not exists (select 1 from public.users u where lower(u.email) = lower(i.email))
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.update_mall_member(p_mall_id uuid, p_user_id uuid, p_role text, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager']);
  if p_user_id = auth.uid() then
    raise exception 'Kendi rolünüzü veya durumunuzu değiştiremezsiniz.' using errcode = '42501';
  end if;
  if p_role not in ('mall_manager', 'mall_ad_manager', 'mall_content_editor', 'mall_store_manager')
     or p_status not in ('active', 'suspended', 'removed') then
    raise exception 'Geçersiz rol veya durum.';
  end if;
  update public.mall_members
  set role = p_role,
      status = case when status = 'invited' and p_status = 'active' then 'invited' else p_status end
  where mall_id = p_mall_id and user_id = p_user_id;
  if not found then
    raise exception 'Yetkili bulunamadı.';
  end if;
end;
$$;

create or replace function public.invite_mall_member(p_mall_id uuid, p_email text, p_role text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(btrim(p_email));
  v_user uuid;
begin
  if not public.mall_member_has_role(p_mall_id, array['mall_manager']) then
    raise exception 'Bu AVM için yönetim yetkiniz bulunmuyor.' using errcode = '42501';
  end if;
  if p_role not in ('mall_manager', 'mall_ad_manager', 'mall_content_editor', 'mall_store_manager') then
    raise exception 'Geçersiz rol.';
  end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Geçerli bir e-posta girin.';
  end if;
  select u.id into v_user from public.users u where lower(u.email) = v_email limit 1;
  if v_user = auth.uid() then
    raise exception 'Kendi rolünüzü değiştiremezsiniz.' using errcode = '42501';
  end if;
  if exists (select 1 from public.mall_members m
             where m.mall_id = p_mall_id and m.user_id = v_user and m.status = 'active') then
    raise exception 'Bu kişi zaten aktif yetkili. Rolü listeden değiştirin.';
  end if;

  insert into public.mall_invitations (mall_id, email, role, status, created_by)
  values (p_mall_id, v_email, p_role, 'pending', auth.uid())
  on conflict (mall_id, email) do update set role = excluded.role, status = 'pending';

  if v_user is null then
    return jsonb_build_object('status', 'pending_account',
      'message', 'Bu e-posta için İBUL hesabı oluşturulduktan sonra davet kabul edilebilir.');
  end if;

  insert into public.mall_members (mall_id, user_id, role, status, created_by)
  values (p_mall_id, v_user, p_role, 'invited', auth.uid())
  on conflict (mall_id, user_id) do update set role = excluded.role, status = 'invited';

  insert into public.user_notifications (user_id, title, body, data, type)
  select v_user, 'AVM yetkili daveti',
         format('%s AVM yönetimine davet edildiniz.', m.name),
         jsonb_build_object('type', 'mall_invitation', 'mall_id', p_mall_id), 'mall_invitation'
  from public.malls m where m.id = p_mall_id;

  return jsonb_build_object('status', 'invited', 'user_id', v_user);
end;
$$;

-- ---------------------------------------------------------------- activity
create or replace function public.mall_recent_activity(p_mall_id uuid, p_limit integer default 12)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.mall_management_assert_role(p_mall_id, public.mall_any_role());
  return coalesce((
    select jsonb_agg(row_to_json(a)::jsonb order by a.at desc)
    from (
      select * from (
        select 'floor_created' kind, f.name subject, null::text detail, f.created_at at
        from public.mall_floors f where f.mall_id = p_mall_id
        union all
        select 'unit_created', u.unit_code, f.name, u.created_at
        from public.mall_units u join public.mall_floors f on f.id = u.floor_id where u.mall_id = p_mall_id
        union all
        select 'link_' || l.status, s.business_name, u.unit_code, coalesce(l.reviewed_at, l.requested_at)
        from public.mall_branch_links l
        join public.store_branches b on b.id = l.branch_id
        join public.stores s on s.seller_id = b.store_id
        join public.mall_units u on u.id = l.mall_unit_id
        where l.mall_id = p_mall_id
        union all
        select 'campaign_' || c.status, c.title, null, c.updated_at
        from public.mall_campaigns c where c.mall_id = p_mall_id
      ) all_events
      order by at desc
      limit greatest(1, least(coalesce(p_limit, 12), 50))
    ) a
  ), '[]'::jsonb);
end;
$$;

do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'public.create_mall_ad(uuid, text, text, timestamptz, timestamptz, numeric, boolean)',
    'public.submit_mall_ad(uuid, text)',
    'public.mall_ad_campaigns(uuid)',
    'public.mall_event_stats(uuid, integer)',
    'public.mall_member_directory(uuid)',
    'public.update_mall_member(uuid, uuid, text, text)',
    'public.invite_mall_member(uuid, text, text)',
    'public.mall_recent_activity(uuid, integer)'
  ] loop
    execute format('revoke all on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated', v_fn);
  end loop;
  revoke all on function public.track_mall_event(uuid, text, text) from public;
  grant execute on function public.track_mall_event(uuid, text, text) to anon, authenticated;
end $$;

commit;
