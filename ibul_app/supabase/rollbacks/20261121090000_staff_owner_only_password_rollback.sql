-- Rollback for 20261121090000_staff_owner_only_password.sql.
-- DO NOT APPLY to the live project from this workspace.
-- Removes the auth guards and restores the previous staff_must_change_password()
-- (flag based, from 2026110101) and lan_staff_authority() (20261120090000).
-- Staff flags that the migration set to false are NOT set back to true.
-- is_managed_restaurant_staff(uuid) (new in this migration) is dropped at the end.
-- Dropping staff_credentials loses only the epoch counters.

begin;

do $pre$
begin
  if exists(select 1 from pg_trigger where tgname = 'ibul_staff_membership_revoke') then
    raise exception 'Önce 20261121100000_staff_access_revocation_rollback uygulanmalı (banlı hesaplar ve üyelik tetikleyicisi).';
  end if;
end
$pre$;

drop trigger if exists ibul_guard_managed_staff_users on auth.users;
drop trigger if exists ibul_guard_managed_staff_ott on auth.one_time_tokens;
drop trigger if exists ibul_guard_managed_staff_identities on auth.identities;
drop function if exists public.guard_managed_staff_auth_update();
drop function if exists public.guard_managed_staff_one_time_token();
drop function if exists public.guard_managed_staff_identity_insert();
drop function if exists public.owner_set_staff_password(uuid, uuid, text);

create or replace function public.staff_must_change_password()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'managed_restaurant_staff') = 'true'
    and (auth.jwt() -> 'app_metadata' ->> 'must_change_password') = 'true',
    false
  );
$$;

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
  return jsonb_build_object(
    'found', true,
    'store_id', v_member.store_id,
    'status', v_member.status,
    'staff_role', v_member.staff_role,
    'permissions', to_jsonb(coalesce(v_member.permissions, '{}'::text[])),
    'branch_id', v_member.branch_id,
    'must_change_password', v_must_change
  );
end;
$authority$;

revoke all on function public.lan_staff_authority(uuid, uuid) from public, anon;
grant execute on function public.lan_staff_authority(uuid, uuid) to authenticated;

-- Restore get_my_staff_access() and store_sub_admins_active_self_select as they
-- were before the gate (same variant choice as the migration; skipped if absent).
do $undo$
begin
  if to_regprocedure('public.get_my_staff_access()') is not null then
    if (select count(*) from information_schema.columns
        where table_schema = 'public' and table_name = 'store_sub_admins'
          and column_name in ('job_title', 'visible_modules')) = 2 then
      execute $fn$
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
          order by created_at
          limit 1;
        $b$ $fn$;
    else
      execute $fn$
        create or replace function public.get_my_staff_access()
        returns jsonb language sql stable security definer set search_path = public
        as $b$
          select case when count(*)=0 then null else jsonb_build_object(
            'store_id',(jsonb_agg(to_jsonb(sa.store_id) order by sa.created_at))->0,
            'branch_id',(jsonb_agg(to_jsonb(sa.branch_id) order by sa.created_at))->0,
            'staff_role',(jsonb_agg(to_jsonb(sa.staff_role) order by sa.created_at))->0,
            'permissions',(jsonb_agg(to_jsonb(sa.permissions) order by sa.created_at))->0,
            'memberships',jsonb_agg(jsonb_build_object(
              'store_id',sa.store_id,'branch_id',sa.branch_id,
              'staff_role',sa.staff_role,'permissions',sa.permissions
            ) order by sa.created_at)
          ) end
          from public.store_sub_admins sa
          join auth.users au on au.id=auth.uid()
          where sa.status='active'
            and (sa.branch_id is null or exists(select 1 from public.store_branches b
              where b.id=sa.branch_id and b.store_id=sa.store_id and b.status='active'))
            and (sa.auth_user_id=au.id or (sa.auth_user_id is null and (
              (au.email_confirmed_at is not null and lower(trim(sa.email))=lower(trim(au.email)))
              or (au.phone_confirmed_at is not null and sa.phone=au.phone))));
        $b$ $fn$;
    end if;
  end if;
  if exists(select 1 from pg_policies where schemaname = 'public'
            and tablename = 'store_sub_admins'
            and policyname = 'store_sub_admins_active_self_select') then
    alter policy store_sub_admins_active_self_select on public.store_sub_admins
      using ((auth_user_id = auth.uid() or store_id = auth.uid()));
  end if;
end
$undo$;

drop table if exists public.staff_credentials;
drop function if exists public.is_managed_restaurant_staff(uuid);

commit;
