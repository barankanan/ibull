-- P0: freeze client writes to users.role / is_seller_approved.
-- RLS cannot do column-level UPDATE checks; a BEFORE trigger is the smallest
-- production-safe lock that still allows profile fields and admin RPCs.
--
-- Source of truth: ibul_app/supabase/migrations
-- Rollback: drop trigger users_protect_privileged_columns on public.users;
--           drop function public.protect_users_privileged_columns();

create or replace function public.is_admin_role(role_key text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select
    role_key = 'admin'
    or role_key = 'super_admin'
    or role_key like 'admin\_%' escape '\';
$$;

create or replace function public.is_admin_user(target_user_id uuid default auth.uid())
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  role_key text;
begin
  if target_user_id is null then
    return false;
  end if;
  if to_regclass('public.users') is null then
    return false;
  end if;

  select u.role
  into role_key
  from public.users u
  where u.id = target_user_id
  limit 1;

  return public.is_admin_role(role_key);
end;
$$;

revoke all on function public.is_admin_user(uuid) from public;
revoke all on function public.is_admin_user(uuid) from anon;
grant execute on function public.is_admin_user(uuid) to authenticated;

create or replace function public.vehicle_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_admin_user(auth.uid())
    or exists (
      select 1
      from public.users u
      where u.id = auth.uid()
        and lower(coalesce(u.role, '')) = 'owner'
    );
$$;

revoke all on function public.vehicle_is_admin() from public;
grant execute on function public.vehicle_is_admin() to anon, authenticated;

create or replace function public.admin_can_manage_users()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin_user(auth.uid());
$$;

revoke all on function public.admin_can_manage_users() from public;
revoke all on function public.admin_can_manage_users() from anon;
grant execute on function public.admin_can_manage_users() to authenticated;

create or replace function public.session_is_service_role()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(auth.role(), '') = 'service_role';
$$;

create or replace function public.protect_users_privileged_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_allow boolean := false;
begin
  v_allow :=
    public.session_is_service_role()
    or current_setting('ibul.allow_privileged_user_update', true) = 'on';

  if tg_op = 'INSERT' then
    if v_allow then
      return new;
    end if;
    if public.is_admin_user(auth.uid())
       and auth.uid() is distinct from new.id then
      return new;
    end if;
    if new.role is null or btrim(new.role) = '' then
      new.role := 'user';
    end if;
    if public.is_admin_role(new.role)
       or lower(new.role) not in ('user', 'seller', 'customer', 'buyer') then
      new.role := 'user';
    end if;
    new.is_seller_approved := false;
    return new;
  end if;

  if v_allow then
    return new;
  end if;

  -- Admins may change another user's authorization columns via client or RPC.
  -- They may not self-promote; own-row privileged columns stay frozen.
  if public.is_admin_user(auth.uid())
     and auth.uid() is distinct from old.id then
    return new;
  end if;

  new.role := old.role;
  new.is_seller_approved := old.is_seller_approved;
  return new;
end;
$$;

drop trigger if exists users_protect_privileged_columns on public.users;
create trigger users_protect_privileged_columns
before insert or update on public.users
for each row
execute function public.protect_users_privileged_columns();

-- restore_own_admin_role writes the caller's own role; allow that RPC only.
create or replace function public.restore_own_admin_role()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
begin
  if v_uid is null then
    return null;
  end if;

  select u.role into v_role
  from public.users u
  where u.id = v_uid;

  if public.is_admin_role(v_role) then
    return v_role;
  end if;

  v_role := null;
  if to_regclass('public.admin_user_permissions') is not null then
    execute
      'select coalesce(nullif(btrim(p.role_key), ''''), ''admin'')
         from public.admin_user_permissions p
        where p.user_id = $1
          and coalesce(p.is_active, true) = true
        limit 1'
      into v_role
      using v_uid;
  end if;

  if public.is_admin_role(v_role) then
    perform set_config('ibul.allow_privileged_user_update', 'on', true);
    update public.users
    set role = v_role,
        updated_at = timezone('utc', now())
    where id = v_uid;
    return v_role;
  end if;

  return null;
end;
$$;

revoke all on function public.restore_own_admin_role() from public;
revoke all on function public.restore_own_admin_role() from anon;
grant execute on function public.restore_own_admin_role() to authenticated;
