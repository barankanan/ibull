-- DO NOT APPLY to the live project from this workspace.
-- Staff password policy, enforced in the database:
--   * staff (waiter / sub-admin) are NOT forced to change the password on first login;
--   * staff cannot change their own password, e-mail, phone, or start a
--     recovery / magic-link flow (those would hand out a session without the password);
--   * a sub-admin, even with manageStaff, cannot set another member's password;
--   * only the verified restaurant OWNER, through owner_set_staff_password()
--     (service_role only, called by the manage-restaurant-staff Edge Function).
-- When the owner sets a password every session of that account is deleted and
-- staff_credentials.epoch is raised. An old access JWT stays valid for its
-- lifetime in PostgREST, so staff_must_change_password() (used by the existing
-- restaurant_has_permission / restaurant_table_access gates) now answers true
-- when the JWT session_id no longer exists in auth.sessions.

begin;

-- 0. Preconditions. Fail loudly instead of creating half a policy.
do $pre$
declare
  v_missing text;
begin
  select string_agg(x, ', ') into v_missing from (values
    ('auth.users'), ('auth.sessions'), ('auth.refresh_tokens'), ('auth.identities'),
    ('auth.one_time_tokens'), ('public.stores'), ('public.store_sub_admins')
  ) t(x) where to_regclass(x) is null;
  if v_missing is not null then
    raise exception 'Önkoşul eksik, tablo yok: %', v_missing;
  end if;
  if to_regprocedure('public.restaurant_has_permission(uuid,text)') is null
     or to_regprocedure('public.restaurant_table_access(uuid,uuid)') is null
     or to_regprocedure('public.staff_must_change_password()') is null
     or to_regprocedure('public.lan_staff_authority(uuid,uuid)') is null then
    raise exception 'Önkoşul eksik: personel kapı fonksiyonları yok (2026110101 / 2026110116 / 20261120090000).';
  end if;
  if position('staff_must_change_password' in
       pg_get_functiondef('public.restaurant_has_permission(uuid,text)'::regprocedure)) = 0
     or position('staff_must_change_password' in
       pg_get_functiondef('public.restaurant_table_access(uuid,uuid)'::regprocedure)) = 0 then
    raise exception 'Önkoşul eksik: restaurant_has_permission / restaurant_table_access kapıyı çağırmıyor.';
  end if;
  -- Order rows are protected by policies that call the gate; they only work with RLS on.
  if to_regclass('public.table_orders') is null
     or not (select relrowsecurity from pg_class where oid = 'public.table_orders'::regclass) then
    raise exception 'Önkoşul eksik: table_orders üzerinde RLS kapalı (20260915_table_orders_store_isolation).';
  end if;
  if not exists(select 1 from pg_extension where extname = 'pgcrypto') then
    raise exception 'Önkoşul eksik: pgcrypto uzantısı yok.';
  end if;
end
$pre$;

-- 1. Protected-account test. ONLY the app_metadata flag counts (writable by
-- service_role only). A store_sub_admins row is NOT enough: an owner can insert
-- a membership row for anybody's e-mail and would lock that person out
-- (password / recovery). Staff created before the flag existed are unprotected
-- until backfilled. The no-argument is_managed_restaurant_staff() is untouched.
create or replace function public.is_managed_restaurant_staff(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, pg_temp
as $$
  select uid is not null and exists(
    select 1 from auth.users u
    where u.id = uid
      and u.raw_app_meta_data ->> 'managed_restaurant_staff' = 'true'
  );
$$;

revoke all on function public.is_managed_restaurant_staff(uuid) from public, anon, authenticated;
grant execute on function public.is_managed_restaurant_staff(uuid) to service_role;

-- 2. Credential epoch. RLS on, no policy: only service_role / definer functions.
create table if not exists public.staff_credentials (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  epoch bigint not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.staff_credentials enable row level security;
revoke all on table public.staff_credentials from public, anon, authenticated;
grant all on table public.staff_credentials to service_role;

-- 3a. auth.users guard. Login, refresh, last_sign_in_at, app_metadata stay free.
create or replace function public.guard_managed_staff_auth_update()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
begin
  if coalesce(current_setting('ibul.owner_pw_change', true), '') = '1' then
    return new;
  end if;
  if not public.is_managed_restaurant_staff(old.id) then
    return new;
  end if;
  if new.encrypted_password is distinct from old.encrypted_password
     or new.email is distinct from old.email
     or new.phone is distinct from old.phone
     or new.email_change is distinct from old.email_change
     or new.phone_change is distinct from old.phone_change
     or (nullif(new.recovery_token, '') is not null
         and new.recovery_token is distinct from old.recovery_token)
     or (nullif(new.confirmation_token, '') is not null
         and new.confirmation_token is distinct from old.confirmation_token) then
    raise exception 'Personel hesabı bilgileri yalnız işletme sahibi tarafından değiştirilebilir.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function public.guard_managed_staff_auth_update() from public, anon, authenticated;

drop trigger if exists ibul_guard_managed_staff_users on auth.users;
create trigger ibul_guard_managed_staff_users
  before update on auth.users
  for each row
  execute function public.guard_managed_staff_auth_update();

-- 3b. One-time tokens (recovery, magic link, confirmation, e-mail / phone change) for staff.
-- Verified locally: createUser(email_confirm), login and refresh never write confirmation_token.
create or replace function public.guard_managed_staff_one_time_token()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
begin
  if coalesce(current_setting('ibul.owner_pw_change', true), '') = '1' then
    return new;
  end if;
  if new.token_type::text in ('recovery_token', 'confirmation_token', 'email_change_token_new',
       'email_change_token_current', 'phone_change_token')
     and public.is_managed_restaurant_staff(new.user_id) then
    raise exception 'Personel hesabı için kurtarma veya değişiklik bağlantısı oluşturulamaz.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function public.guard_managed_staff_one_time_token() from public, anon, authenticated;

drop trigger if exists ibul_guard_managed_staff_ott on auth.one_time_tokens;
create trigger ibul_guard_managed_staff_ott
  before insert or update on auth.one_time_tokens
  for each row
  execute function public.guard_managed_staff_one_time_token();

-- 3c. auth.identities: no ADDITIONAL identity for staff. The first (email)
-- identity is written by admin.createUser right after the user row, when the
-- account has none yet, so account creation is not blocked.
create or replace function public.guard_managed_staff_identity_insert()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
begin
  if coalesce(current_setting('ibul.owner_pw_change', true), '') = '1' then
    return new;
  end if;
  if public.is_managed_restaurant_staff(new.user_id)
     and exists(select 1 from auth.identities i where i.user_id = new.user_id) then
    raise exception 'Personel hesabına ek kimlik bağlanamaz.' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function public.guard_managed_staff_identity_insert() from public, anon, authenticated;

drop trigger if exists ibul_guard_managed_staff_identities on auth.identities;
create trigger ibul_guard_managed_staff_identities
  before insert on auth.identities
  for each row
  execute function public.guard_managed_staff_identity_insert();

-- 4. The only way to set a staff password. service_role only. The password is
-- never logged or put into an error message.
create or replace function public.owner_set_staff_password(
  p_owner_id uuid,
  p_member_id uuid,
  p_password text
) returns void
language plpgsql
security definer
set search_path = pg_catalog, extensions, public, pg_temp
as $$
declare
  v_auth uuid;
begin
  -- Same owner test as the Edge Function: a stores row with seller_id = caller.
  -- A sub-admin is never accepted here.
  if p_owner_id is null
     or not exists(select 1 from public.stores where seller_id = p_owner_id) then
    raise exception 'Yalnız işletme sahibi personel şifresi belirleyebilir.' using errcode = '42501';
  end if;
  if p_password is null or char_length(p_password) < 8 or char_length(p_password) > 128 then
    raise exception 'Şifre 8-128 karakter olmalıdır.' using errcode = '22023';
  end if;
  select sa.auth_user_id into v_auth
  from public.store_sub_admins sa
  where sa.id = p_member_id and sa.store_id = p_owner_id;
  if v_auth is null then
    raise exception 'Personel kaydı bulunamadı.' using errcode = 'P0002';
  end if;
  if v_auth = p_owner_id
     or exists(select 1 from public.stores where seller_id = v_auth)
     or exists(select 1 from public.store_sub_admins sa
               where sa.auth_user_id = v_auth and sa.store_id <> p_owner_id) then
    raise exception 'Bu hesap başka bir işletmeye bağlı. Şifre değiştirilmedi.' using errcode = '23505';
  end if;
  -- The account must have been provisioned by THIS owner's store (written by the
  -- manage-restaurant-staff create flow). A membership row alone is not proof:
  -- an owner can insert store_sub_admins rows with any e-mail's auth id.
  perform 1 from auth.users u
  where u.id = v_auth
    and u.raw_app_meta_data ->> 'managed_restaurant_staff' = 'true'
    and u.raw_app_meta_data ->> 'provisioned_by_store_id' = p_owner_id::text
  for update;
  if not found then
    raise exception 'Bu hesap bu işletme tarafından oluşturulmuş yönetilen personel değil. Şifre değiştirilmedi.' using errcode = '23514';
  end if;

  perform set_config('ibul.owner_pw_change', '1', true);
  update auth.users
  set encrypted_password = crypt(p_password, gen_salt('bf', 10)),
      raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
        || jsonb_build_object('must_change_password', false, 'managed_restaurant_staff', true),
      updated_at = now()
  where id = v_auth;
  perform set_config('ibul.owner_pw_change', '', true);

  delete from auth.refresh_tokens where user_id = v_auth::text;
  delete from auth.sessions where user_id = v_auth;

  insert into public.staff_credentials(auth_user_id, epoch, updated_at)
  values (v_auth, 1, now())
  on conflict (auth_user_id)
  do update set epoch = public.staff_credentials.epoch + 1, updated_at = now();
end;
$$;

revoke all on function public.owner_set_staff_password(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.owner_set_staff_password(uuid, uuid, text) to service_role;

-- 5. Name kept for compatibility: the restaurant gates still call it. It no
-- longer looks at must_change_password (no forced change on first login). It is
-- true only for a staff account whose JWT session was deleted (the owner set a
-- new password): that JWT is refused in RLS/RPC for the rest of its hour.
-- Calls without a session_id claim (service_role etc.) and non-staff are not affected.
create or replace function public.staff_must_change_password()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, pg_temp
as $$
  select coalesce(
    case
      when auth.uid() is null then false
      when not public.is_managed_restaurant_staff(auth.uid()) then false
      -- Protected staff without a usable session_id claim: fail closed.
      when (auth.jwt() ->> 'session_id') is null
        or (auth.jwt() ->> 'session_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then true
      else not exists(
             select 1 from auth.sessions s
             where s.id::text = lower(auth.jwt() ->> 'session_id')
               and s.user_id = auth.uid()
           )
    end,
    false
  );
$$;

-- 6. lan_staff_authority: same fields plus credential_epoch.
create or replace function public.lan_staff_authority(
  p_restaurant_id uuid,
  p_staff_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $authority$
declare
  v_member public.store_sub_admins%rowtype;
  v_must_change boolean;
  v_epoch bigint;
begin
  if auth.uid() is null
     or p_restaurant_id is null
     or auth.uid() <> p_restaurant_id then
    raise exception 'Personel yetkisini yalnız işletme sahibi sorgulayabilir.'
      using errcode = '42501';
  end if;
  if p_staff_id is null then
    return jsonb_build_object('found', false);
  end if;

  select * into v_member
  from public.store_sub_admins sa
  where sa.store_id = p_restaurant_id
    and sa.auth_user_id = p_staff_id
  limit 1;
  if not found then
    return jsonb_build_object('found', false);
  end if;

  select coalesce(
           (u.raw_app_meta_data ->> 'managed_restaurant_staff') = 'true'
           and (u.raw_app_meta_data ->> 'must_change_password') = 'true',
           false)
    into v_must_change
  from auth.users u
  where u.id = p_staff_id;
  v_must_change := coalesce(v_must_change, true);

  select c.epoch into v_epoch
  from public.staff_credentials c
  where c.auth_user_id = p_staff_id;

  return jsonb_build_object(
    'found', true,
    'store_id', v_member.store_id,
    'status', v_member.status,
    'staff_role', v_member.staff_role,
    'permissions', to_jsonb(coalesce(v_member.permissions, '{}'::text[])),
    'branch_id', v_member.branch_id,
    'must_change_password', v_must_change,
    'credential_epoch', coalesce(v_epoch, 0)
  );
end;
$authority$;

revoke all on function public.lan_staff_authority(uuid, uuid) from public, anon;
grant execute on function public.lan_staff_authority(uuid, uuid) to authenticated;

-- One-time normalisation: the policy has no forced first-login change.
update auth.users
set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('must_change_password', false)
where raw_app_meta_data ->> 'managed_restaurant_staff' = 'true'
  and raw_app_meta_data ->> 'must_change_password' = 'true';

-- 7. Stale access JWT (session deleted by owner_set_staff_password) on paths that
-- do not call restaurant_has_permission / restaurant_table_access. Owner and
-- customer access is unchanged: the gate is true only for protected staff.
-- Nothing is skipped: a missing or unexpected object stops the migration, so a
-- database that is behind the repository can never look "migrated" without the gate.
-- Not changed: restaurant_table_number_access (its only shortcut is
-- auth.uid() = restaurant id, the owner; staff go through restaurant_table_access,
-- which already calls the gate) and the table_orders policies built on it.
do $gate$
declare
  v_body text;
begin
  if to_regprocedure('public.get_my_staff_access()') is null then
    raise exception 'Önkoşul eksik: public.get_my_staff_access() yok (2026102901 uygulanmamış).';
  end if;
  if (select count(*) from information_schema.columns
      where table_schema = 'public' and table_name = 'store_sub_admins'
        and column_name in ('job_title', 'visible_modules')) <> 2 then
    raise exception 'Önkoşul eksik: store_sub_admins.job_title / visible_modules yok (20261105123000 uygulanmamış).';
  end if;
  -- The body replaced below must be the one from 20261105123000. Anything else
  -- (hotfix, older multi-membership body) is not overwritten blindly.
  select regexp_replace(lower(p.prosrc), '\s+', '', 'g') into v_body
  from pg_proc p where p.oid = to_regprocedure('public.get_my_staff_access()');
  if v_body is distinct from regexp_replace(lower($expected$
  select jsonb_build_object(
    'store_id', store_id,
    'branch_id', branch_id,
    'staff_role', staff_role,
    'permissions', permissions,
    'job_title', job_title,
    'visible_modules', visible_modules
  )
  from public.store_sub_admins
  where auth_user_id = auth.uid()
    and status = 'active'
  order by created_at
  limit 1;
$expected$), '\s+', '', 'g')
     -- re-run: the gated body written below is accepted as well
     and position('andnotpublic.staff_must_change_password()orderbycreated_atlimit1' in v_body) = 0 then
    raise exception 'get_my_staff_access() gövdesi beklenen sürüm değil; kapı eklenmedi. Canlı gövdeyi inceleyin.';
  end if;
  if not exists(select 1 from pg_policies where schemaname = 'public'
                and tablename = 'store_sub_admins'
                and policyname = 'store_sub_admins_active_self_select') then
    raise exception 'Önkoşul eksik: store_sub_admins_active_self_select politikası yok (2026102901 uygulanmamış).';
  end if;
  if not (select relrowsecurity from pg_class where oid = 'public.store_sub_admins'::regclass) then
    raise exception 'Önkoşul eksik: store_sub_admins üzerinde RLS kapalı.';
  end if;
end
$gate$;

create or replace function public.get_my_staff_access()
returns jsonb language sql stable security definer set search_path = public
as $b$
  select jsonb_build_object(
    'store_id', store_id, 'branch_id', branch_id, 'staff_role', staff_role,
    'permissions', permissions, 'job_title', job_title,
    'visible_modules', visible_modules)
  from public.store_sub_admins
  where auth_user_id = auth.uid()
    and status = 'active'
    and not public.staff_must_change_password()
  order by created_at
  limit 1;
$b$;

alter policy store_sub_admins_active_self_select on public.store_sub_admins
  using ((auth_user_id = auth.uid() and not (select public.staff_must_change_password()))
         or store_id = auth.uid());

commit;
