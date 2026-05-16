-- Mağaza takip + bildirim sistemi (store_followers, preferences, notifications, RPC)

-- ---------------------------------------------------------------------------
-- stores.follower_count
-- ---------------------------------------------------------------------------
alter table public.stores
  add column if not exists follower_count integer not null default 0;

-- ---------------------------------------------------------------------------
-- store_followers
-- ---------------------------------------------------------------------------
create table if not exists public.store_followers (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(seller_id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (store_id, user_id)
);

create index if not exists idx_store_followers_user_id
  on public.store_followers(user_id, created_at desc);

create index if not exists idx_store_followers_store_id
  on public.store_followers(store_id);

-- ---------------------------------------------------------------------------
-- store_notification_preferences
-- ---------------------------------------------------------------------------
create table if not exists public.store_notification_preferences (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(seller_id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  enabled boolean not null default true,
  fcm_token text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, user_id)
);

create index if not exists idx_store_notification_preferences_user
  on public.store_notification_preferences(user_id, store_id);

-- ---------------------------------------------------------------------------
-- store_notifications (mağaza olay kaydı / şablon)
-- ---------------------------------------------------------------------------
create table if not exists public.store_notifications (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(seller_id) on delete cascade,
  title text not null,
  body text not null,
  type text not null,
  product_id text null,
  announcement_id text null,
  created_at timestamptz not null default now()
);

create index if not exists idx_store_notifications_store_created
  on public.store_notifications(store_id, created_at desc);

-- ---------------------------------------------------------------------------
-- user_notifications genişletme (mevcut sipariş bildirimleriyle uyumlu)
-- ---------------------------------------------------------------------------
alter table public.user_notifications
  add column if not exists store_id uuid null references public.stores(seller_id) on delete cascade;

alter table public.user_notifications
  add column if not exists notification_id uuid null references public.store_notifications(id) on delete set null;

alter table public.user_notifications
  add column if not exists type text null;

alter table public.user_notifications
  add column if not exists product_id text null;

create index if not exists idx_user_notifications_store_user
  on public.user_notifications(user_id, store_id, created_at desc)
  where store_id is not null;

-- ---------------------------------------------------------------------------
-- Takipçi sayısı senkronu
-- ---------------------------------------------------------------------------
create or replace function public.sync_store_follower_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid := coalesce(new.store_id, old.store_id);
begin
  if v_store_id is null then
    return coalesce(new, old);
  end if;

  update public.stores
  set follower_count = (
    select count(*)::integer
    from public.store_followers sf
    where sf.store_id = v_store_id
  ),
  updated_at = now()
  where seller_id = v_store_id;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_store_followers_sync_count on public.store_followers;
create trigger trg_store_followers_sync_count
after insert or delete on public.store_followers
for each row execute function public.sync_store_follower_count();

-- Mevcut takipçileri say (migration sonrası bir kez)
update public.stores s
set follower_count = coalesce((
  select count(*)::integer
  from public.store_followers sf
  where sf.store_id = s.seller_id
), 0);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.store_followers enable row level security;
alter table public.store_notification_preferences enable row level security;
alter table public.store_notifications enable row level security;

drop policy if exists "store_followers_select_own" on public.store_followers;
create policy "store_followers_select_own"
on public.store_followers for select to authenticated
using (user_id = auth.uid());

drop policy if exists "store_followers_insert_own" on public.store_followers;
create policy "store_followers_insert_own"
on public.store_followers for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "store_followers_delete_own" on public.store_followers;
create policy "store_followers_delete_own"
on public.store_followers for delete to authenticated
using (user_id = auth.uid());

drop policy if exists "store_notification_preferences_select_own" on public.store_notification_preferences;
create policy "store_notification_preferences_select_own"
on public.store_notification_preferences for select to authenticated
using (user_id = auth.uid());

drop policy if exists "store_notification_preferences_insert_own" on public.store_notification_preferences;
create policy "store_notification_preferences_insert_own"
on public.store_notification_preferences for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "store_notification_preferences_update_own" on public.store_notification_preferences;
create policy "store_notification_preferences_update_own"
on public.store_notification_preferences for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "store_notification_preferences_delete_own" on public.store_notification_preferences;
create policy "store_notification_preferences_delete_own"
on public.store_notification_preferences for delete to authenticated
using (user_id = auth.uid());

drop policy if exists "store_notifications_select_public" on public.store_notifications;
create policy "store_notifications_select_public"
on public.store_notifications for select to authenticated
using (true);

drop policy if exists "store_notifications_insert_owner" on public.store_notifications;
create policy "store_notifications_insert_owner"
on public.store_notifications for insert to authenticated
with check (
  exists (
    select 1 from public.stores s
    where s.seller_id = store_id and s.seller_id = auth.uid()
  )
);

drop policy if exists "user_notifications_update_own" on public.user_notifications;
create policy "user_notifications_update_own"
on public.user_notifications for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- RPC: follow_store
-- ---------------------------------------------------------------------------
create or replace function public.follow_store(p_store_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_count integer;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.stores where seller_id = p_store_id) then
    raise exception 'store_not_found';
  end if;

  insert into public.store_followers(store_id, user_id)
  values (p_store_id, v_user_id)
  on conflict (store_id, user_id) do nothing;

  select follower_count into v_count
  from public.stores
  where seller_id = p_store_id;

  return jsonb_build_object(
    'is_following', true,
    'notifications_enabled', coalesce((
      select snp.enabled
      from public.store_notification_preferences snp
      where snp.store_id = p_store_id and snp.user_id = v_user_id
    ), false),
    'follower_count', coalesce(v_count, 0)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: unfollow_store
-- ---------------------------------------------------------------------------
create or replace function public.unfollow_store(p_store_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_count integer;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  delete from public.store_followers
  where store_id = p_store_id and user_id = v_user_id;

  delete from public.store_notification_preferences
  where store_id = p_store_id and user_id = v_user_id;

  select follower_count into v_count
  from public.stores
  where seller_id = p_store_id;

  return jsonb_build_object(
    'is_following', false,
    'notifications_enabled', false,
    'follower_count', coalesce(v_count, 0)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: is_following_store
-- ---------------------------------------------------------------------------
create or replace function public.is_following_store(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.store_followers sf
    where sf.store_id = p_store_id
      and sf.user_id = auth.uid()
  );
$$;

-- ---------------------------------------------------------------------------
-- RPC: toggle_store_notifications
-- ---------------------------------------------------------------------------
create or replace function public.toggle_store_notifications(
  p_store_id uuid,
  p_enabled boolean,
  p_fcm_token text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_enabled boolean;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (
    select 1 from public.store_followers
    where store_id = p_store_id and user_id = v_user_id
  ) then
    raise exception 'not_following';
  end if;

  if p_enabled then
    insert into public.store_notification_preferences (
      store_id, user_id, enabled, fcm_token, updated_at
    )
    values (
      p_store_id, v_user_id, true, nullif(trim(p_fcm_token), ''), now()
    )
    on conflict (store_id, user_id) do update
    set enabled = true,
        fcm_token = coalesce(nullif(trim(excluded.fcm_token), ''), store_notification_preferences.fcm_token),
        updated_at = now();
    v_enabled := true;
  else
    update public.store_notification_preferences
    set enabled = false, updated_at = now()
    where store_id = p_store_id and user_id = v_user_id;

    if not found then
      v_enabled := false;
    else
      v_enabled := false;
    end if;
  end if;

  return jsonb_build_object('enabled', v_enabled);
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: get_store_follow_state
-- ---------------------------------------------------------------------------
create or replace function public.get_store_follow_state(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_following boolean := false;
  v_notifications boolean := false;
  v_count integer := 0;
begin
  select coalesce(follower_count, 0) into v_count
  from public.stores
  where seller_id = p_store_id;

  if v_user_id is not null then
    v_following := exists (
      select 1 from public.store_followers
      where store_id = p_store_id and user_id = v_user_id
    );

    v_notifications := exists (
      select 1 from public.store_notification_preferences snp
      where snp.store_id = p_store_id
        and snp.user_id = v_user_id
        and snp.enabled = true
    );
  end if;

  return jsonb_build_object(
    'is_following', v_following,
    'notifications_enabled', v_notifications,
    'follower_count', coalesce(v_count, 0)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: create_store_notification
-- ---------------------------------------------------------------------------
create or replace function public.create_store_notification(
  p_store_id uuid,
  p_title text,
  p_body text,
  p_type text,
  p_product_id text default null,
  p_announcement_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_notification_id uuid;
  v_store_name text;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (
    select 1 from public.stores s
    where s.seller_id = p_store_id and s.seller_id = auth.uid()
  ) then
    raise exception 'forbidden';
  end if;

  select business_name into v_store_name
  from public.stores
  where seller_id = p_store_id;

  insert into public.store_notifications (
    store_id, title, body, type, product_id, announcement_id
  )
  values (
    p_store_id,
    trim(p_title),
    trim(p_body),
    trim(p_type),
    nullif(trim(p_product_id), ''),
    nullif(trim(p_announcement_id), '')
  )
  returning id into v_notification_id;

  insert into public.user_notifications (
    user_id,
    store_id,
    notification_id,
    title,
    body,
    type,
    product_id,
    is_read,
    data
  )
  select
    sf.user_id,
    p_store_id,
    v_notification_id,
    trim(p_title),
    trim(p_body),
    trim(p_type),
    nullif(trim(p_product_id), ''),
    false,
    jsonb_build_object(
      'type', trim(p_type),
      'store_id', p_store_id::text,
      'store_name', coalesce(v_store_name, ''),
      'product_id', nullif(trim(p_product_id), ''),
      'announcement_id', nullif(trim(p_announcement_id), ''),
      'notification_id', v_notification_id::text,
      'open_tab', 'store_profile'
    )
  from public.store_followers sf
  inner join public.store_notification_preferences snp
    on snp.store_id = sf.store_id
   and snp.user_id = sf.user_id
   and snp.enabled = true
  where sf.store_id = p_store_id;

  return v_notification_id;
end;
$$;

grant execute on function public.follow_store(uuid) to authenticated;
grant execute on function public.unfollow_store(uuid) to authenticated;
grant execute on function public.is_following_store(uuid) to authenticated, anon;
grant execute on function public.toggle_store_notifications(uuid, boolean, text) to authenticated;
grant execute on function public.get_store_follow_state(uuid) to authenticated, anon;
grant execute on function public.create_store_notification(uuid, text, text, text, text, text) to authenticated;
