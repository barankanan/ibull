-- Rollback for 20261121100000_staff_access_revocation.sql.
-- DO NOT APPLY to the live project from this workspace.
-- Restores staff_must_change_password() as left by 20261121090000 and removes
-- the membership triggers. Accounts banned by the policy are unbanned first, so
-- nobody stays locked out by a rule that no longer exists.
-- Apply together with the previous manage-restaurant-staff Edge Function.

begin;

update auth.users u set banned_until = null
where exists(select 1 from public.staff_credentials c
             where c.auth_user_id = u.id and c.banned_by_policy);

drop trigger if exists ibul_staff_membership_revoke on public.store_sub_admins;
drop trigger if exists ibul_guard_staff_membership_link on public.store_sub_admins;
drop trigger if exists ibul_staff_credentials_cutoff on public.staff_credentials;
drop function if exists public.staff_membership_revoke_on_change();
drop function if exists public.guard_staff_membership_link();
drop function if exists public.staff_credentials_touch_cutoff();
drop function if exists public.staff_sync_login_ban(uuid, uuid);
drop function if exists public.staff_revoke_access(uuid, uuid);
drop function if exists public.staff_account_provisioned_by(uuid, uuid);

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

alter table public.staff_credentials
  drop column if exists sessions_valid_after,
  drop column if exists banned_by_policy;

commit;
