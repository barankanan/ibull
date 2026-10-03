-- baran.kan@gmail.com admin rolunu geri al.
-- Supabase Dashboard > SQL Editor > yeni bos sorgu.
-- Dart/test kodu yapistirmayin. Yalnizca bu dosya.

select
  au.id,
  au.email as auth_email,
  u.email as users_email,
  u.role
from auth.users au
left join public.users u on u.id = au.id
where lower(au.email) = 'baran.kan@gmail.com';

insert into public.users (id, email, role, updated_at)
select au.id, au.email, 'admin', timezone('utc', now())
from auth.users au
where lower(au.email) = 'baran.kan@gmail.com'
on conflict (id) do update
  set role = 'admin',
      email = coalesce(nullif(trim(public.users.email), ''), excluded.email),
      updated_at = timezone('utc', now());

update auth.users
set raw_user_meta_data =
      coalesce(raw_user_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
where lower(email) = 'baran.kan@gmail.com';

select id, email, role
from public.users
where lower(trim(email)) = 'baran.kan@gmail.com';

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

  if v_role is not null
     and (
       lower(v_role) in ('admin', 'super_admin')
       or lower(v_role) like 'admin_%'
     ) then
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

  if v_role is not null
     and (
       lower(v_role) in ('admin', 'super_admin')
       or lower(v_role) like 'admin_%'
     ) then
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
