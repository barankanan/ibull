-- DO NOT APPLY to the live project from this workspace.
-- Staff removal / deactivation / re-linking, enforced in the database.
--
--   * Every change that takes a staff membership away or gives it back
--     (delete, status change, auth identity change, new link) raises
--     staff_credentials.epoch and sets sessions_valid_after: a session created
--     before that moment is refused by the restaurant gates even when the
--     membership is active again. Re-activation never revives an old session.
--   * For an account this store provisioned (app_metadata flag +
--     provisioned_by_store_id) the sessions and refresh tokens are deleted too,
--     and while it has no active membership the Auth account is banned, so a
--     new login is refused by GoTrue itself. The ban is lifted only when a
--     membership becomes active again (owner action).
--   * A signed-in client (the owner through RLS) cannot link an Auth account
--     that this store did not provision. Other accounts are linked only by the
--     manage-restaurant-staff Edge Function (service_role), which is owner-only
--     for create / activate / re-link.
--
-- The work is done by triggers on store_sub_admins, so the Edge Function, a
-- direct PostgREST write by the owner and SQL all take the same path.
-- Requires 20261121090000_staff_owner_only_password.sql.

begin;

do $pre$
begin
  if to_regclass('public.staff_credentials') is null
     or to_regprocedure('public.is_managed_restaurant_staff(uuid)') is null
     or to_regprocedure('public.owner_set_staff_password(uuid,uuid,text)') is null then
    raise exception 'Önkoşul eksik: 20261121090000_staff_owner_only_password uygulanmamış.';
  end if;
  if (select count(*) from information_schema.columns
      where table_schema = 'public' and table_name = 'store_sub_admins'
        and column_name in ('auth_user_id', 'status', 'store_id', 'email', 'phone')) <> 5 then
    raise exception 'Önkoşul eksik: store_sub_admins beklenen sütunları taşımıyor.';
  end if;
  if (select count(*) from information_schema.columns
      where table_schema = 'auth' and table_name = 'users'
        and column_name in ('banned_until', 'raw_app_meta_data')) <> 2
     or not exists(select 1 from information_schema.columns
                   where table_schema = 'auth' and table_name = 'sessions'
                     and column_name = 'created_at') then
    raise exception 'Önkoşul eksik: auth.users.banned_until / auth.sessions.created_at yok.';
  end if;
  if not (select relrowsecurity from pg_class where oid = 'public.store_sub_admins'::regclass) then
    raise exception 'Önkoşul eksik: store_sub_admins üzerinde RLS kapalı.';
  end if;
end
$pre$;

alter table public.staff_credentials
  add column if not exists sessions_valid_after timestamptz,
  add column if not exists banned_by_policy boolean not null default false;

-- 1. Is this account one that THIS store provisioned?
create or replace function public.staff_account_provisioned_by(p_auth uuid, p_store uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, pg_temp
as $$
  select p_auth is not null and p_store is not null and exists(
    select 1 from auth.users u
    where u.id = p_auth
      and u.raw_app_meta_data ->> 'managed_restaurant_staff' = 'true'
      and u.raw_app_meta_data ->> 'provisioned_by_store_id' = p_store::text
  );
$$;

revoke all on function public.staff_account_provisioned_by(uuid, uuid) from public, anon, authenticated;
grant execute on function public.staff_account_provisioned_by(uuid, uuid) to service_role;

-- 2. Revoke everything an account holds from before now.
create or replace function public.staff_revoke_access(p_auth uuid, p_store uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  v_cutoff timestamptz;
begin
  if p_auth is null or not exists(select 1 from auth.users u where u.id = p_auth) then
    return;
  end if;
  -- The cutoff is never earlier than a session that already exists (GoTrue stamps
  -- created_at with its own clock, which may run ahead of the database clock).
  select greatest(clock_timestamp(),
                  coalesce(max(s.created_at), '-infinity'::timestamptz) + interval '1 microsecond')
    into v_cutoff
  from auth.sessions s where s.user_id = p_auth;
  insert into public.staff_credentials(auth_user_id, epoch, sessions_valid_after, updated_at)
  values (p_auth, 1, v_cutoff, now())
  on conflict (auth_user_id)
  do update set epoch = public.staff_credentials.epoch + 1,
                sessions_valid_after = v_cutoff,
                updated_at = now();
  -- Sessions are deleted only for an account this store created. For any other
  -- linked account the cutoff above is enough and nobody else is signed out.
  if public.staff_account_provisioned_by(p_auth, p_store) then
    delete from auth.refresh_tokens where user_id = p_auth::text;
    delete from auth.sessions where user_id = p_auth;
  end if;
end;
$$;

revoke all on function public.staff_revoke_access(uuid, uuid) from public, anon, authenticated;

-- 3. Ban / unban a provisioned account according to its memberships.
create or replace function public.staff_sync_login_ban(p_auth uuid, p_store uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  v_active boolean;
begin
  if not public.staff_account_provisioned_by(p_auth, p_store) then
    return;
  end if;
  select exists(select 1 from public.store_sub_admins sa
                where sa.auth_user_id = p_auth and sa.status = 'active')
    into v_active;
  if v_active then
    update auth.users u set banned_until = null
    where u.id = p_auth
      and exists(select 1 from public.staff_credentials c
                 where c.auth_user_id = p_auth and c.banned_by_policy);
    update public.staff_credentials set banned_by_policy = false
    where auth_user_id = p_auth and banned_by_policy;
  else
    -- A finite far date: GoTrue cannot read 'infinity' (it fails every request for that user).
    -- Never ban a store owner, and never take over a ban somebody else set
    -- (it would be lifted on re-activation).
    if exists(select 1 from public.stores s where s.seller_id = p_auth)
       or exists(select 1 from auth.users u where u.id = p_auth
                 and u.banned_until is not null and u.banned_until > now()
                 and not exists(select 1 from public.staff_credentials c
                                where c.auth_user_id = p_auth and c.banned_by_policy)) then
      return;
    end if;
    update auth.users u set banned_until = now() + interval '100 years' where u.id = p_auth;
    insert into public.staff_credentials(auth_user_id, epoch, banned_by_policy, updated_at)
    values (p_auth, 0, true, now())
    on conflict (auth_user_id) do update set banned_by_policy = true, updated_at = now();
  end if;
end;
$$;

revoke all on function public.staff_sync_login_ban(uuid, uuid) from public, anon, authenticated;

-- 4. (no helper) Only the LINKED account of a membership is revoked. A legacy
-- row without an auth id matches people by e-mail; revoking those would let one
-- owner sign out another restaurant's staff by typing their address. Such rows
-- cannot be made active by a signed-in client any more (5a) and their status is
-- checked live on every request.

-- 5a. BEFORE: a signed-in client may only link an account its store provisioned.
create or replace function public.guard_staff_membership_link()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  v_role text := coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '');
begin
  if v_role not in ('authenticated', 'anon') then
    return new;  -- service_role (Edge Function) or direct SQL
  end if;
  if new.auth_user_id is null then
    -- Legacy e-mail / phone row: it would give access to whoever confirms that
    -- address, an account this store did not create. Invitations may be kept,
    -- but a signed-in client cannot make such a row active or re-target it.
    if new.status = 'active' and (tg_op = 'INSERT' or old.status is distinct from 'active'
         or lower(trim(coalesce(new.email, ''))) <> lower(trim(coalesce(old.email, '')))
         or coalesce(new.phone, '') <> coalesce(old.phone, '')
         or old.auth_user_id is not null) then
      raise exception 'Hesabı bağlı olmayan personel kaydı etkinleştirilemez; personeli Personel Yönetimi ekranından oluşturun.'
        using errcode = '42501';
    end if;
    return new;
  end if;
  if tg_op = 'UPDATE' and new.auth_user_id is not distinct from old.auth_user_id
     and new.store_id is not distinct from old.store_id then
    return new;
  end if;
  if not public.staff_account_provisioned_by(new.auth_user_id, new.store_id) then
    raise exception 'Bu hesap bu işletmenin oluşturduğu personel hesabı değil; bağlanamaz.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function public.guard_staff_membership_link() from public, anon, authenticated;

drop trigger if exists ibul_guard_staff_membership_link on public.store_sub_admins;
create trigger ibul_guard_staff_membership_link
  before insert or update on public.store_sub_admins
  for each row
  execute function public.guard_staff_membership_link();

-- 5b. AFTER: revoke on every change of who holds the membership or whether it is active.
create or replace function public.staff_membership_revoke_on_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
begin
  if tg_op = 'UPDATE'
     and new.status is not distinct from old.status
     and new.auth_user_id is not distinct from old.auth_user_id
     and new.store_id is not distinct from old.store_id then
    return null;  -- permissions, branch, title: checked live on every request
  end if;
  if tg_op in ('UPDATE', 'DELETE') and old.auth_user_id is not null then
    perform public.staff_revoke_access(old.auth_user_id, old.store_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') and new.auth_user_id is not null
     and (tg_op = 'INSERT' or new.auth_user_id is distinct from old.auth_user_id) then
    perform public.staff_revoke_access(new.auth_user_id, new.store_id);
  end if;
  -- The ban follows the linked account only (never an e-mail match).
  if tg_op in ('UPDATE', 'DELETE') and old.auth_user_id is not null then
    perform public.staff_sync_login_ban(old.auth_user_id, old.store_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') and new.auth_user_id is not null then
    perform public.staff_sync_login_ban(new.auth_user_id, new.store_id);
  end if;
  return null;
end;
$$;

revoke all on function public.staff_membership_revoke_on_change() from public, anon, authenticated;

drop trigger if exists ibul_staff_membership_revoke on public.store_sub_admins;
create trigger ibul_staff_membership_revoke
  after insert or update or delete on public.store_sub_admins
  for each row
  execute function public.staff_membership_revoke_on_change();

-- 6. The gate. True = this JWT must be refused on staff paths.
--   protected staff : session row missing, or created before the cutoff;
--   store owner     : never (owners are not gated here);
--   anyone else     : only when a cutoff exists and the session is older than it.
create or replace function public.staff_must_change_password()
returns boolean
language plpgsql
stable
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_sid_text text := auth.jwt() ->> 'session_id';
  v_sid uuid;
  v_managed boolean;
  v_cutoff timestamptz;
  v_created timestamptz;
begin
  if v_uid is null then
    return false;
  end if;
  v_managed := public.is_managed_restaurant_staff(v_uid);
  if not v_managed and exists(select 1 from public.stores s where s.seller_id = v_uid) then
    return false;
  end if;
  select c.sessions_valid_after into v_cutoff
  from public.staff_credentials c where c.auth_user_id = v_uid;
  if not v_managed and v_cutoff is null then
    return false;
  end if;
  if v_sid_text is null
     or v_sid_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return true;
  end if;
  v_sid := v_sid_text::uuid;
  select s.created_at into v_created
  from auth.sessions s where s.id = v_sid and s.user_id = v_uid;
  if v_created is null then
    return true;
  end if;
  return v_cutoff is not null and v_created < v_cutoff;
end;
$$;

revoke all on function public.staff_must_change_password() from public;
grant execute on function public.staff_must_change_password() to anon, authenticated, service_role;

-- 7. Owner password change also moves the cutoff (sessions are deleted there already).
create or replace function public.staff_credentials_touch_cutoff()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
begin
  if new.epoch is distinct from old.epoch
     and new.sessions_valid_after is not distinct from old.sessions_valid_after then
    new.sessions_valid_after := clock_timestamp();
  end if;
  return new;
end;
$$;

revoke all on function public.staff_credentials_touch_cutoff() from public, anon, authenticated;

drop trigger if exists ibul_staff_credentials_cutoff on public.staff_credentials;
create trigger ibul_staff_credentials_cutoff
  before update on public.staff_credentials
  for each row
  execute function public.staff_credentials_touch_cutoff();

commit;
