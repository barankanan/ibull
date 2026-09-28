-- Category-independent gallery detection + admin role self-restore.
-- Does not rewrite existing restaurant / e-commerce category values.

create or replace function public.store_is_gallery_category(p_category text)
returns boolean
language sql
immutable
as $$
  select (
    lower(translate(coalesce(p_category, ''), 'İIıĞğÜüŞşÖöÇç', 'iiigguusssoocc'))
      like '%galeri%'
    or lower(coalesce(p_category, '')) like '%kiralama%'
    or lower(coalesce(p_category, '')) like '%rent%car%'
    or lower(coalesce(p_category, '')) like '%dealer%'
    or lower(coalesce(p_category, '')) like '%dealership%'
  );
$$;

revoke all on function public.store_is_gallery_category(text) from public;
grant execute on function public.store_is_gallery_category(text)
  to authenticated;

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

do $$
begin
  if to_regclass('public.vehicle_galleries') is null then
    return;
  end if;
  insert into public.vehicle_galleries (seller_id)
  select s.seller_id
  from public.stores s
  where public.store_is_gallery_category(s.category)
    and s.seller_id is not null
  on conflict (seller_id) do nothing;
end;
$$;
