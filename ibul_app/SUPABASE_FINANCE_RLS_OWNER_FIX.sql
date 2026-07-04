-- Admin Finans RLS owner / Genel Operasyon düzeltmesi.
-- Idempotent: güvenle tekrar çalıştırılabilir.
-- Sorun: admin_expenses insert policy current_admin_has_module('finance') false döndüğünde
--        Genel Operasyon (users.role = admin) ve hesap sahibi adminler gider kaydedemiyordu.

-- ---------------------------------------------------------------------------
-- Rol kataloğunda finance modülünü doğrula (Genel Operasyon + super_admin)
-- ---------------------------------------------------------------------------
insert into public.admin_role_catalog (
  role_key,
  title,
  description,
  color_hex,
  icon_name,
  modules,
  scopes,
  is_system,
  is_active,
  sort_order
)
values
  (
    'super_admin',
    'Super Admin',
    'Tum modullere tam erisim ve kritik ayar yonetimi.',
    '#7C3AED',
    'workspace_premium',
    array[
      'dashboard',
      'analytics',
      'store_management',
      'product_approval',
      'orders_returns',
      'map_search',
      'finance',
      'campaign_content',
      'system_layout',
      'support',
      'permission_system',
      'security_logs'
    ]::text[],
    array['Tum sistem', 'Rol atama', 'Kritik ayarlar', 'Guvenlik']::text[],
    true,
    true,
    0
  ),
  (
    'admin',
    'Genel Operasyon',
    'Genel operasyon akislarini yoneten ana admin rolu.',
    '#2563EB',
    'admin_panel_settings',
    array[
      'dashboard',
      'analytics',
      'store_management',
      'product_approval',
      'orders_returns',
      'map_search',
      'finance',
      'campaign_content',
      'system_layout',
      'support',
      'permission_system',
      'security_logs'
    ]::text[],
    array['Tum operasyon', 'Panel yonetimi', 'Rol atama']::text[],
    true,
    true,
    10
  )
on conflict (role_key) do update
set
  modules = excluded.modules,
  updated_at = timezone('utc', now())
where not ('finance' = any(coalesce(public.admin_role_catalog.modules, '{}'::text[])));

-- ---------------------------------------------------------------------------
-- current_admin_has_module: role_key eşleşmesi + katalog fallback düzeltmesi
-- ---------------------------------------------------------------------------
create or replace function public.current_admin_has_module(module_key text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_role text;
  effective_role text;
  allowed_modules text[];
  denied_modules text[];
  catalog_modules text[];
begin
  if auth.uid() is null or module_key is null or trim(module_key) = '' then
    return false;
  end if;

  select u.role
  into current_role
  from public.users u
  where u.id = auth.uid()
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
    coalesce(nullif(trim(a.role_key), ''), u.role),
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
    on c.role_key = coalesce(nullif(trim(a.role_key), ''), u.role)
  where u.id = auth.uid()
  limit 1;

  denied_modules := coalesce(denied_modules, '{}'::text[]);
  catalog_modules := coalesce(catalog_modules, '{}'::text[]);

  if module_key = any(denied_modules) then
    return false;
  end if;

  -- Genel Operasyon: katalog modülleri kaynak; kısmi override finance'i kesmesin.
  if current_role = 'admin' then
    return module_key = any(catalog_modules);
  end if;

  if allowed_modules is not null and cardinality(allowed_modules) > 0 then
    return module_key = any(allowed_modules);
  end if;

  return module_key = any(catalog_modules);
end;
$$;

-- ---------------------------------------------------------------------------
-- Finans tabloları için merkezi yetki helper
-- ---------------------------------------------------------------------------
create or replace function public.current_admin_can_access_finance()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_role text;
  denied_modules text[];
begin
  if auth.uid() is null then
    return false;
  end if;

  select u.role
  into current_role
  from public.users u
  where u.id = auth.uid()
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

  select coalesce(a.denied_modules, '{}'::text[])
  into denied_modules
  from public.admin_user_permissions a
  where a.user_id = auth.uid()
    and a.is_active = true
  limit 1;

  if 'finance' = any(coalesce(denied_modules, '{}'::text[])) then
    return false;
  end if;

  -- Genel Operasyon (hesap sahibi / owner admin): tam finans erişimi.
  if current_role = 'admin' then
    return true;
  end if;

  return public.current_admin_has_module('finance');
end;
$$;

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
on public.admin_expenses
for select
to authenticated
using (public.current_admin_can_access_finance());

create policy "admin_expenses_insert"
on public.admin_expenses
for insert
to authenticated
with check (public.current_admin_can_access_finance());

create policy "admin_expenses_update"
on public.admin_expenses
for update
to authenticated
using (public.current_admin_can_access_finance())
with check (public.current_admin_can_access_finance());

create policy "admin_expenses_delete"
on public.admin_expenses
for delete
to authenticated
using (public.current_admin_can_access_finance());

-- ---------------------------------------------------------------------------
-- seller_payouts RLS (admin write, seller read-only own rows)
-- ---------------------------------------------------------------------------
alter table public.seller_payouts enable row level security;

drop policy if exists "seller_payouts_admin_select" on public.seller_payouts;
drop policy if exists "seller_payouts_admin_manage" on public.seller_payouts;
drop policy if exists "seller_payouts_seller_select" on public.seller_payouts;
drop policy if exists "seller_payouts_admin_insert" on public.seller_payouts;
drop policy if exists "seller_payouts_admin_update" on public.seller_payouts;
drop policy if exists "seller_payouts_admin_delete" on public.seller_payouts;

create policy "seller_payouts_seller_select"
on public.seller_payouts
for select
to authenticated
using (seller_id = auth.uid());

create policy "seller_payouts_admin_select"
on public.seller_payouts
for select
to authenticated
using (public.current_admin_can_access_finance());

create policy "seller_payouts_admin_insert"
on public.seller_payouts
for insert
to authenticated
with check (public.current_admin_can_access_finance());

create policy "seller_payouts_admin_update"
on public.seller_payouts
for update
to authenticated
using (public.current_admin_can_access_finance())
with check (public.current_admin_can_access_finance());

create policy "seller_payouts_admin_delete"
on public.seller_payouts
for delete
to authenticated
using (public.current_admin_can_access_finance());
