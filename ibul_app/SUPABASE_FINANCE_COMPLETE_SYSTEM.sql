-- Finans modülü: admin okuma, güvenli insert RPC, komisyon ayarları.
-- SUPABASE_ADMIN_EXPENSES + SUPABASE_ADMIN_REVENUES + SUPABASE_FINANCE_REVENUE_EXPENSE_RLS_FINAL_FIX sonrası uygulanır.

-- ---------------------------------------------------------------------------
-- is_admin_user — case/trim güvenli (reklam tabloları için)
-- ---------------------------------------------------------------------------
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

  select lower(trim(u.role))
  into role_key
  from public.users u
  where u.id = target_user_id
  limit 1;

  return role_key = 'admin'
    or role_key = 'super_admin'
    or coalesce(role_key, '') like 'admin\_%' escape '\';
end;
$$;

grant execute on function public.is_admin_user(uuid) to authenticated;

-- Finans yazma izni — admin rolü yeterli (modül override olmadan)
create or replace function public.admin_can_write_finance()
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
begin
  uid := auth.uid();
  if uid is null then return false; end if;

  select lower(trim(u.role)) into current_role
  from public.users u where u.id = uid limit 1;

  if current_role is null then return false; end if;
  if current_role in ('super_admin', 'admin', 'admin_finance', 'admin_investor') then
    return true;
  end if;
  if public.is_admin_role(current_role) then return true; end if;

  if to_regclass('public.admin_user_permissions') is not null then
    select coalesce(a.denied_modules, '{}'::text[]) into denied_modules
    from public.admin_user_permissions a
    where a.user_id = uid and a.is_active = true limit 1;
    if 'finance' = any(coalesce(denied_modules, '{}'::text[])) then return false; end if;
  end if;
  return false;
end;
$$;

grant execute on function public.admin_can_write_finance() to authenticated;

-- ---------------------------------------------------------------------------
-- Admin finans okuma — orders / order_items (RLS boş döndürüyordu)
-- ---------------------------------------------------------------------------
drop policy if exists "orders_admin_finance_select" on public.orders;
create policy "orders_admin_finance_select"
on public.orders for select to authenticated
using (public.current_admin_can_access_finance());

drop policy if exists "order_items_admin_finance_select" on public.order_items;
create policy "order_items_admin_finance_select"
on public.order_items for select to authenticated
using (public.current_admin_can_access_finance());

drop policy if exists "stores_admin_finance_select" on public.stores;
create policy "stores_admin_finance_select"
on public.stores for select to authenticated
using (public.current_admin_can_access_finance());

-- ---------------------------------------------------------------------------
-- Komisyon / vergi / kargo ayarları
-- ---------------------------------------------------------------------------
create table if not exists public.admin_finance_settings (
  id uuid primary key default gen_random_uuid(),
  setting_key text not null unique,
  setting_value jsonb not null default '{}'::jsonb,
  updated_by uuid null references public.users (id) on delete set null,
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_admin_finance_settings_key
  on public.admin_finance_settings (setting_key);

alter table public.admin_finance_settings enable row level security;

drop policy if exists "admin_finance_settings_select" on public.admin_finance_settings;
drop policy if exists "admin_finance_settings_manage" on public.admin_finance_settings;

create policy "admin_finance_settings_select"
on public.admin_finance_settings for select to authenticated
using (public.current_admin_can_access_finance());

create policy "admin_finance_settings_manage"
on public.admin_finance_settings for all to authenticated
using (public.current_admin_can_access_finance())
with check (public.current_admin_can_access_finance());

grant select, insert, update, delete on table public.admin_finance_settings to authenticated;

insert into public.admin_finance_settings (setting_key, setting_value)
values
  (
    'commission_config',
    jsonb_build_object(
      'default_percent', 15,
      'category_rules', '[]'::jsonb,
      'cargo_mode', 'percent',
      'cargo_percent', 10,
      'cargo_fixed', 0,
      'kdv_percent', 20,
      'stopaj_percent', 0,
      'corporate_tax_percent', 25
    )
  )
on conflict (setting_key) do nothing;

-- ---------------------------------------------------------------------------
-- Güvenli insert RPC — RLS çakışmalarında fallback
-- ---------------------------------------------------------------------------
create or replace function public.admin_insert_expense(
  p_title text,
  p_category text,
  p_amount numeric,
  p_expense_date date,
  p_type text,
  p_recurrence text,
  p_status text,
  p_payment_method text default null,
  p_vendor text default null,
  p_invoice_url text default null,
  p_note text default null
)
returns public.admin_expenses
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.admin_expenses;
  v_uid uuid;
  v_created_by uuid;
begin
  if not public.admin_can_write_finance() then
    raise exception 'permission denied for admin expense insert' using errcode = '42501';
  end if;

  v_uid := auth.uid();
  v_created_by := null;
  if v_uid is not null and exists (select 1 from public.users u where u.id = v_uid) then
    v_created_by := v_uid;
  end if;

  insert into public.admin_expenses (
    title, category, amount, expense_date, type, recurrence, status,
    payment_method, vendor, invoice_url, note, created_by
  )
  values (
    trim(p_title),
    trim(p_category),
    p_amount,
    p_expense_date,
    p_type,
    p_recurrence,
    p_status,
    nullif(trim(coalesce(p_payment_method, '')), ''),
    nullif(trim(coalesce(p_vendor, '')), ''),
    nullif(trim(coalesce(p_invoice_url, '')), ''),
    nullif(trim(coalesce(p_note, '')), ''),
    v_created_by
  )
  returning * into result;

  return result;
end;
$$;

create or replace function public.admin_insert_revenue(
  p_title text,
  p_category text,
  p_amount numeric,
  p_revenue_date date,
  p_type text,
  p_recurrence text,
  p_status text,
  p_source text default null,
  p_payment_method text default null,
  p_reference_no text default null,
  p_note text default null
)
returns public.admin_revenues
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.admin_revenues;
  v_uid uuid;
  v_created_by uuid;
begin
  if not public.admin_can_write_finance() then
    raise exception 'permission denied for admin revenue insert' using errcode = '42501';
  end if;

  v_uid := auth.uid();
  v_created_by := null;
  if v_uid is not null and exists (select 1 from public.users u where u.id = v_uid) then
    v_created_by := v_uid;
  end if;

  insert into public.admin_revenues (
    title, category, amount, revenue_date, type, recurrence, status,
    source, payment_method, reference_no, note, created_by
  )
  values (
    trim(p_title),
    trim(p_category),
    p_amount,
    p_revenue_date,
    p_type,
    p_recurrence,
    p_status,
    nullif(trim(coalesce(p_source, '')), ''),
    nullif(trim(coalesce(p_payment_method, '')), ''),
    nullif(trim(coalesce(p_reference_no, '')), ''),
    nullif(trim(coalesce(p_note, '')), ''),
    v_created_by
  )
  returning * into result;

  return result;
end;
$$;

grant execute on function public.admin_insert_expense(
  text, text, numeric, date, text, text, text, text, text, text, text
) to authenticated;

grant execute on function public.admin_insert_revenue(
  text, text, numeric, date, text, text, text, text, text, text, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- Finans sipariş kalemleri — kategori ile (security definer)
-- ---------------------------------------------------------------------------
create or replace function public.admin_finance_order_items_snapshot(p_from timestamptz default null)
returns table (
  order_id uuid,
  seller_id uuid,
  store_name text,
  status text,
  total_price numeric,
  created_at timestamptz,
  updated_at timestamptz,
  category_name text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    oi.order_id,
    oi.seller_id,
    oi.store_name,
    oi.status,
    oi.total_price,
    oi.created_at,
    oi.updated_at,
    nullif(trim(coalesce(p.main_category, p.sub_category, '')), '') as category_name
  from public.order_items oi
  left join public.products p on p.id = oi.product_id
  where public.current_admin_can_access_finance()
    and (p_from is null or oi.created_at >= p_from)
  order by oi.created_at asc;
$$;

grant execute on function public.admin_finance_order_items_snapshot(timestamptz) to authenticated;

-- ---------------------------------------------------------------------------
-- Komisyon ayarı kaydet
-- ---------------------------------------------------------------------------
create or replace function public.admin_save_finance_commission_config(p_config jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.current_admin_can_access_finance() then
    raise exception 'permission denied' using errcode = '42501';
  end if;

  insert into public.admin_finance_settings (setting_key, setting_value, updated_by, updated_at)
  values (
    'commission_config',
    coalesce(p_config, '{}'::jsonb),
    case
      when auth.uid() is not null
        and exists (select 1 from public.users u where u.id = auth.uid())
      then auth.uid()
      else null
    end,
    timezone('utc', now())
  )
  on conflict (setting_key) do update
  set
    setting_value = excluded.setting_value,
    updated_by = excluded.updated_by,
    updated_at = excluded.updated_at;

  return (select setting_value from public.admin_finance_settings where setting_key = 'commission_config');
end;
$$;

grant execute on function public.admin_save_finance_commission_config(jsonb) to authenticated;
