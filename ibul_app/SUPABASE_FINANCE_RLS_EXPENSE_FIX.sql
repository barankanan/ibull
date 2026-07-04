-- Admin gider (admin_expenses) insert RLS düzeltmesi — idempotent.
-- SUPABASE_ADMIN_EXPENSES + SUPABASE_FINANCE_HARDENING sonrası uygulanır.

-- ---------------------------------------------------------------------------
-- Tablo yetkileri (RLS policy tek başına yetmez)
-- ---------------------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update, delete on table public.admin_expenses to authenticated;
grant select, insert, update, delete on table public.seller_payouts to authenticated;

-- ---------------------------------------------------------------------------
-- is_admin_role: lower/trim güvenli
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
-- current_admin_has_module — user_id bazlı, katalog fallback
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
    on c.role_key = lower(trim(coalesce(nullif(trim(a.role_key), ''), u.role)))
  where u.id = uid
  limit 1;

  denied_modules := coalesce(denied_modules, '{}'::text[]);
  catalog_modules := coalesce(catalog_modules, '{}'::text[]);

  if module_key = any(denied_modules) then
    return false;
  end if;

  if current_role = 'admin' then
    return module_key = any(catalog_modules) or module_key = 'finance';
  end if;

  if allowed_modules is not null and cardinality(allowed_modules) > 0 then
    return module_key = any(allowed_modules);
  end if;

  return module_key = any(catalog_modules);
end;
$$;

-- ---------------------------------------------------------------------------
-- Finans erişim helper — owner / Genel Operasyon / finance modülü
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
  denied_modules text[];
  catalog_has_finance boolean := false;
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

  if not public.is_admin_role(current_role) then
    return false;
  end if;

  select coalesce(a.denied_modules, '{}'::text[])
  into denied_modules
  from public.admin_user_permissions a
  where a.user_id = uid and a.is_active = true
  limit 1;

  if 'finance' = any(coalesce(denied_modules, '{}'::text[])) then
    return false;
  end if;

  -- Genel Operasyon (hesap sahibi / owner admin)
  if current_role = 'admin' then
    return true;
  end if;

  select exists (
    select 1
    from public.admin_role_catalog c
    where c.role_key = current_role
      and 'finance' = any(coalesce(c.modules, '{}'::text[]))
  ) into catalog_has_finance;

  if catalog_has_finance then
    return true;
  end if;

  return public.current_admin_has_module('finance');
end;
$$;

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
  perms jsonb;
begin
  uid := auth.uid();
  if uid is null then
    return jsonb_build_object('authenticated', false);
  end if;

  select lower(trim(role)) into current_role from public.users where id = uid limit 1;

  select to_jsonb(a.*)
  into perms
  from public.admin_user_permissions a
  where a.user_id = uid
  limit 1;

  return jsonb_build_object(
    'authenticated', true,
    'uid', uid,
    'users_role', current_role,
    'is_admin_role', public.is_admin_role(current_role),
    'can_access_finance', public.current_admin_can_access_finance(),
    'has_finance_module', public.current_admin_has_module('finance'),
    'permissions', coalesce(perms, '{}'::jsonb)
  );
end;
$$;

grant execute on function public.debug_admin_finance_access() to authenticated;

grant select, insert, update, delete on table public.admin_revenues to authenticated;

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
-- seller_payouts RLS (seller read-only own rows)
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
