-- Finans gelir/gider RLS + GRANT nihai düzeltme — idempotent.
-- SUPABASE_ADMIN_EXPENSES + SUPABASE_ADMIN_REVENUES sonrası uygulanır.
-- HARDENING / eski policy'ler current_admin_has_module('finance') ile admin insert'i
-- engelliyorsa bu patch tüm finans tablolarını current_admin_can_access_finance() ile hizalar.

-- ---------------------------------------------------------------------------
-- GRANT (RLS policy tek başına yetmez)
-- ---------------------------------------------------------------------------
grant usage on schema public to authenticated;

grant select, insert, update, delete on table public.admin_expenses to authenticated;
grant select, insert, update, delete on table public.admin_revenues to authenticated;
grant select, insert, update, delete on table public.seller_payouts to authenticated;

-- ---------------------------------------------------------------------------
-- Rol kataloğu: finance modülü
-- ---------------------------------------------------------------------------
insert into public.admin_role_catalog (
  role_key, title, description, color_hex, icon_name, modules, scopes, is_system, is_active, sort_order
)
values
  (
    'super_admin', 'Super Admin', 'Tum modullere tam erisim.', '#7C3AED', 'workspace_premium',
    array['dashboard','analytics','store_management','product_approval','orders_returns','map_search','finance','campaign_content','system_layout','support','permission_system','security_logs']::text[],
    array['Tum sistem']::text[], true, true, 0
  ),
  (
    'admin', 'Genel Operasyon', 'Genel operasyon admin rolu.', '#2563EB', 'admin_panel_settings',
    array['dashboard','analytics','store_management','product_approval','orders_returns','map_search','finance','campaign_content','system_layout','support','permission_system','security_logs']::text[],
    array['Tum operasyon']::text[], true, true, 10
  ),
  (
    'admin_finance', 'Finans Admin', 'Finans modulu yoneticisi.', '#0F766E', 'account_balance',
    array['dashboard','analytics','finance']::text[],
    array['Finans']::text[], true, true, 20
  ),
  (
    'admin_investor', 'Yatirim Admin', 'Yatirim takibi.', '#6366F1', 'insights',
    array['dashboard','finance']::text[],
    array['Yatirim']::text[], true, true, 30
  )
on conflict (role_key) do update
set
  modules = (
    select array(
      select distinct m
      from unnest(
        coalesce(public.admin_role_catalog.modules, '{}'::text[]) ||
        excluded.modules
      ) as m
    )
  ),
  updated_at = timezone('utc', now())
where not ('finance' = any(coalesce(public.admin_role_catalog.modules, '{}'::text[])))
   or excluded.role_key in ('admin_finance', 'admin_investor');

-- ---------------------------------------------------------------------------
-- is_admin_role — case/trim güvenli
-- ---------------------------------------------------------------------------
create or replace function public.is_admin_role(role_key text)
returns boolean
language sql
stable
as $$
  select
    lower(trim(role_key)) = 'admin'
    or lower(trim(role_key)) = 'super_admin'
    or lower(trim(role_key)) like 'admin\_%' escape '\'
$$;

-- ---------------------------------------------------------------------------
-- current_admin_has_module
-- ---------------------------------------------------------------------------
create or replace function public.current_admin_has_module(module_key text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid;
  current_role text;
  effective_role text;
  allowed_modules text[];
  denied_modules text[];
  catalog_modules text[];
begin
  uid := auth.uid();
  if uid is null or module_key is null or trim(module_key) = '' then
    return false;
  end if;

  select lower(trim(u.role))
  into current_role
  from public.users u
  where u.id = uid
  limit 1;

  if current_role is null then
    return false;
  end if;

  if current_role = 'super_admin' then
    return true;
  end if;

  if not public.is_admin_role(current_role) then
    return false;
  end if;

  select
    lower(trim(coalesce(nullif(trim(a.role_key), ''), u.role))),
    case
      when a.is_active is true
        and cardinality(coalesce(a.allowed_modules, '{}'::text[])) > 0
        then a.allowed_modules
      else null::text[]
    end,
    coalesce(a.denied_modules, '{}'::text[]),
    coalesce(c.modules, '{}'::text[])
  into effective_role, allowed_modules, denied_modules, catalog_modules
  from public.users u
  left join public.admin_user_permissions a
    on a.user_id = u.id and a.is_active = true
  left join public.admin_role_catalog c
    on lower(trim(c.role_key)) = lower(trim(coalesce(nullif(trim(a.role_key), ''), u.role)))
  where u.id = uid
  limit 1;

  denied_modules := coalesce(denied_modules, '{}'::text[]);
  catalog_modules := coalesce(catalog_modules, '{}'::text[]);

  if module_key = any(denied_modules) then
    return false;
  end if;

  -- Genel Operasyon: finance katalogda yoksa bile finance erişimi
  if current_role = 'admin' then
    return module_key = any(catalog_modules) or module_key = 'finance';
  end if;

  if effective_role in ('admin_finance', 'admin_investor') then
    return module_key = 'finance' or module_key = any(catalog_modules);
  end if;

  if allowed_modules is not null and cardinality(allowed_modules) > 0 then
    return module_key = any(allowed_modules);
  end if;

  return module_key = any(catalog_modules);
end;
$$;

-- ---------------------------------------------------------------------------
-- current_admin_can_access_finance
-- ---------------------------------------------------------------------------
create or replace function public.current_admin_can_access_finance()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid;
  current_role text;
  permission_role_key text;
  denied_modules text[];
begin
  uid := auth.uid();
  if uid is null then
    return false;
  end if;

  select lower(trim(u.role))
  into current_role
  from public.users u
  where u.id = uid
  limit 1;

  if current_role is null then
    return false;
  end if;

  if current_role = 'super_admin' then
    return true;
  end if;

  select
    lower(trim(coalesce(nullif(trim(a.role_key), ''), ''))),
    coalesce(a.denied_modules, '{}'::text[])
  into permission_role_key, denied_modules
  from public.admin_user_permissions a
  where a.user_id = uid and a.is_active = true
  limit 1;

  denied_modules := coalesce(denied_modules, '{}'::text[]);

  if 'finance' = any(denied_modules) then
    return false;
  end if;

  -- Genel Operasyon / hesap sahibi
  if current_role = 'admin' then
    return true;
  end if;

  -- Finans / yatırım admin rolleri
  if current_role in ('admin_finance', 'admin_investor') then
    return true;
  end if;

  if permission_role_key in ('admin_finance', 'admin_investor') then
    return true;
  end if;

  if not public.is_admin_role(current_role) then
    return false;
  end if;

  return public.current_admin_has_module('finance');
end;
$$;

-- ---------------------------------------------------------------------------
-- debug_admin_finance_access
-- ---------------------------------------------------------------------------
create or replace function public.debug_admin_finance_access()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid;
  current_role text;
  user_email text;
  permission_role_key text;
  allowed_modules text[];
  denied_modules text[];
begin
  uid := auth.uid();
  if uid is null then
    return jsonb_build_object('authenticated', false);
  end if;

  select lower(trim(u.role))
  into current_role
  from public.users u
  where u.id = uid
  limit 1;

  select coalesce(au.email::text, '')
  into user_email
  from auth.users au
  where au.id = uid
  limit 1;

  select
    lower(trim(coalesce(nullif(trim(a.role_key), ''), ''))),
    case
      when a.is_active is true then coalesce(a.allowed_modules, '{}'::text[])
      else '{}'::text[]
    end,
    case
      when a.is_active is true then coalesce(a.denied_modules, '{}'::text[])
      else '{}'::text[]
    end
  into permission_role_key, allowed_modules, denied_modules
  from public.admin_user_permissions a
  where a.user_id = uid
  limit 1;

  return jsonb_build_object(
    'authenticated', true,
    'auth_uid', uid,
    'user_email', user_email,
    'user_role', current_role,
    'permission_role_key', coalesce(nullif(permission_role_key, ''), null),
    'allowed_modules', coalesce(allowed_modules, '{}'::text[]),
    'denied_modules', coalesce(denied_modules, '{}'::text[]),
    'has_finance', public.current_admin_has_module('finance'),
    'can_access_finance', public.current_admin_can_access_finance(),
    'is_admin', public.is_admin_role(current_role),
    'is_super_admin', current_role = 'super_admin'
  );
end;
$$;

grant execute on function public.debug_admin_finance_access() to authenticated;
grant execute on function public.current_admin_can_access_finance() to authenticated;
grant execute on function public.current_admin_has_module(text) to authenticated;

-- ---------------------------------------------------------------------------
-- admin_expenses RLS
-- ---------------------------------------------------------------------------
alter table public.admin_expenses enable row level security;

drop policy if exists "admin_expenses_select" on public.admin_expenses;
drop policy if exists "admin_expenses_manage" on public.admin_expenses;
drop policy if exists "admin_expenses_insert" on public.admin_expenses;
drop policy if exists "admin_expenses_update" on public.admin_expenses;
drop policy if exists "admin_expenses_delete" on public.admin_expenses;

create policy "admin_expenses_select"
on public.admin_expenses for select to authenticated
using (public.current_admin_can_access_finance());

create policy "admin_expenses_insert"
on public.admin_expenses for insert to authenticated
with check (public.current_admin_can_access_finance());

create policy "admin_expenses_update"
on public.admin_expenses for update to authenticated
using (public.current_admin_can_access_finance())
with check (public.current_admin_can_access_finance());

create policy "admin_expenses_delete"
on public.admin_expenses for delete to authenticated
using (public.current_admin_can_access_finance());

-- ---------------------------------------------------------------------------
-- admin_revenues RLS
-- ---------------------------------------------------------------------------
alter table public.admin_revenues enable row level security;

drop policy if exists "admin_revenues_select" on public.admin_revenues;
drop policy if exists "admin_revenues_insert" on public.admin_revenues;
drop policy if exists "admin_revenues_update" on public.admin_revenues;
drop policy if exists "admin_revenues_delete" on public.admin_revenues;
drop policy if exists "admin_revenues_manage" on public.admin_revenues;

create policy "admin_revenues_select"
on public.admin_revenues for select to authenticated
using (public.current_admin_can_access_finance());

create policy "admin_revenues_insert"
on public.admin_revenues for insert to authenticated
with check (public.current_admin_can_access_finance());

create policy "admin_revenues_update"
on public.admin_revenues for update to authenticated
using (public.current_admin_can_access_finance())
with check (public.current_admin_can_access_finance());

create policy "admin_revenues_delete"
on public.admin_revenues for delete to authenticated
using (public.current_admin_can_access_finance());

-- ---------------------------------------------------------------------------
-- seller_payouts RLS
-- ---------------------------------------------------------------------------
alter table public.seller_payouts enable row level security;

drop policy if exists "seller_payouts_admin_select" on public.seller_payouts;
drop policy if exists "seller_payouts_admin_manage" on public.seller_payouts;
drop policy if exists "seller_payouts_seller_select" on public.seller_payouts;
drop policy if exists "seller_payouts_admin_insert" on public.seller_payouts;
drop policy if exists "seller_payouts_admin_update" on public.seller_payouts;
drop policy if exists "seller_payouts_admin_delete" on public.seller_payouts;

create policy "seller_payouts_seller_select"
on public.seller_payouts for select to authenticated
using (seller_id = auth.uid());

create policy "seller_payouts_admin_select"
on public.seller_payouts for select to authenticated
using (public.current_admin_can_access_finance());

create policy "seller_payouts_admin_insert"
on public.seller_payouts for insert to authenticated
with check (public.current_admin_can_access_finance());

create policy "seller_payouts_admin_update"
on public.seller_payouts for update to authenticated
using (public.current_admin_can_access_finance())
with check (public.current_admin_can_access_finance());

create policy "seller_payouts_admin_delete"
on public.seller_payouts for delete to authenticated
using (public.current_admin_can_access_finance());
