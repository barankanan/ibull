-- İBUL Blog — genel admin yetkisini panele bağlar.
-- 20261002_blog_1_schema.sql daha önce uygulandıysa bu dosya blog_is_admin()
-- tanımını değiştirir. Yeni kurulumda 1. dosyadaki tanımla aynıdır.

create or replace function public.blog_is_admin()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_role text;
  v_allowed text[];
  v_denied text[];
begin
  if auth.uid() is null then
    return false;
  end if;

  select lower(btrim(u.role))
  into v_role
  from public.users u
  where u.id = auth.uid()
  limit 1;

  if v_role = 'super_admin' then
    return true;
  end if;

  if to_regclass('public.admin_user_permissions') is not null then
    select
      case
        when p.is_active is true
          and cardinality(coalesce(p.allowed_modules, '{}'::text[])) > 0
          then p.allowed_modules
      end,
      coalesce(p.denied_modules, '{}'::text[])
    into v_allowed, v_denied
    from public.admin_user_permissions p
    where p.user_id = auth.uid()
      and p.is_active is true
    limit 1;
  end if;

  if 'campaign_content' = any(coalesce(v_denied, '{}'::text[])) then
    return false;
  end if;

  if v_role = 'admin' then
    if v_allowed is not null
       and cardinality(v_allowed) > 0
       and not ('campaign_content' = any(v_allowed)) then
      return false;
    end if;
    return true;
  end if;

  return coalesce(public.current_admin_has_module('campaign_content'), false);
end;
$$;


revoke all on function public.blog_is_admin() from public;
grant execute on function public.blog_is_admin() to authenticated;

notify pgrst, 'reload schema';
