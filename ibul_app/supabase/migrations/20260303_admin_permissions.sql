create extension if not exists pgcrypto;

create or replace function public.is_admin_role(role_key text)
returns boolean
language sql
stable
as $$
  select
    role_key = 'admin'
    or role_key = 'super_admin'
    or role_key like 'admin\_%' escape '\'
$$;

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.users
  where id = auth.uid()
  limit 1
$$;

create table if not exists public.admin_role_catalog (
  role_key text primary key,
  title text not null,
  description text not null default '',
  color_hex text not null default '#2563EB',
  icon_name text not null default 'shield',
  modules text[] not null default '{}',
  scopes text[] not null default '{}',
  is_system boolean not null default false,
  is_active boolean not null default true,
  sort_order integer not null default 100,
  created_by uuid references public.users (id) on delete set null,
  updated_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint admin_role_catalog_key_format check (
    role_key = 'admin'
    or role_key = 'super_admin'
    or role_key like 'admin\_%' escape '\'
  )
);

create table if not exists public.admin_user_permissions (
  user_id uuid primary key references public.users (id) on delete cascade,
  role_key text not null references public.admin_role_catalog (role_key) on delete restrict,
  allowed_modules text[] not null default '{}',
  denied_modules text[] not null default '{}',
  is_active boolean not null default true,
  note text,
  assigned_by uuid references public.users (id) on delete set null,
  assigned_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.admin_role_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users (id) on delete set null,
  actor_id uuid references public.users (id) on delete set null,
  event_type text not null,
  previous_role_key text,
  new_role_key text,
  previous_modules text[] not null default '{}',
  new_modules text[] not null default '{}',
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint admin_role_history_event_type check (
    event_type in (
      'granted',
      'updated',
      'revoked',
      'catalog_created',
      'catalog_updated'
    )
  )
);

create index if not exists idx_admin_role_catalog_active
  on public.admin_role_catalog (is_active, sort_order);

create index if not exists idx_admin_user_permissions_role_key
  on public.admin_user_permissions (role_key, is_active);

create index if not exists idx_admin_role_history_created_at
  on public.admin_role_history (created_at desc);

create index if not exists idx_users_role
  on public.users (role);

create or replace function public.set_updated_at_admin_permissions()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists admin_role_catalog_set_updated_at on public.admin_role_catalog;
create trigger admin_role_catalog_set_updated_at
before update on public.admin_role_catalog
for each row execute function public.set_updated_at_admin_permissions();

drop trigger if exists admin_user_permissions_set_updated_at on public.admin_user_permissions;
create trigger admin_user_permissions_set_updated_at
before update on public.admin_user_permissions
for each row execute function public.set_updated_at_admin_permissions();

create or replace function public.current_admin_has_module(module_key text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_role text;
  allowed_modules text[];
  denied_modules text[];
begin
  select role
  into current_role
  from public.users
  where id = auth.uid()
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
    case
      when cardinality(a.allowed_modules) > 0 then a.allowed_modules
      else c.modules
    end,
    coalesce(a.denied_modules, '{}'::text[])
  into allowed_modules, denied_modules
  from public.users u
  left join public.admin_user_permissions a
    on a.user_id = u.id and a.is_active = true
  left join public.admin_role_catalog c
    on c.role_key = u.role
  where u.id = auth.uid()
  limit 1;

  allowed_modules := coalesce(allowed_modules, '{}'::text[]);
  denied_modules := coalesce(denied_modules, '{}'::text[]);

  return module_key = any(allowed_modules) and not module_key = any(denied_modules);
end;
$$;

alter table public.admin_role_catalog enable row level security;
alter table public.admin_user_permissions enable row level security;
alter table public.admin_role_history enable row level security;

drop policy if exists "admin_role_catalog_select" on public.admin_role_catalog;
create policy "admin_role_catalog_select"
on public.admin_role_catalog
for select
to authenticated
using (
  public.current_admin_has_module('permission_system')
  or public.current_user_role() = 'super_admin'
);

drop policy if exists "admin_role_catalog_manage" on public.admin_role_catalog;
create policy "admin_role_catalog_manage"
on public.admin_role_catalog
for all
to authenticated
using (
  public.current_admin_has_module('permission_system')
  or public.current_user_role() = 'super_admin'
)
with check (
  public.current_admin_has_module('permission_system')
  or public.current_user_role() = 'super_admin'
);

drop policy if exists "admin_user_permissions_select" on public.admin_user_permissions;
create policy "admin_user_permissions_select"
on public.admin_user_permissions
for select
to authenticated
using (
  auth.uid() = user_id
  or public.current_admin_has_module('permission_system')
  or public.current_user_role() = 'super_admin'
);

drop policy if exists "admin_user_permissions_manage" on public.admin_user_permissions;
create policy "admin_user_permissions_manage"
on public.admin_user_permissions
for all
to authenticated
using (
  public.current_admin_has_module('permission_system')
  or public.current_user_role() = 'super_admin'
)
with check (
  public.current_admin_has_module('permission_system')
  or public.current_user_role() = 'super_admin'
);

drop policy if exists "admin_role_history_select" on public.admin_role_history;
create policy "admin_role_history_select"
on public.admin_role_history
for select
to authenticated
using (
  auth.uid() = user_id
  or public.current_admin_has_module('permission_system')
  or public.current_admin_has_module('security_logs')
  or public.current_user_role() = 'super_admin'
);

drop policy if exists "admin_role_history_insert" on public.admin_role_history;
create policy "admin_role_history_insert"
on public.admin_role_history
for insert
to authenticated
with check (
  actor_id = auth.uid()
  and (
    public.current_admin_has_module('permission_system')
    or public.current_user_role() = 'super_admin'
  )
);

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
  ),
  (
    'admin_marketing',
    'Reklam Ekibi',
    'Kampanya, vitrin ve icerik akislarini yoneten ekip rolu.',
    '#F97316',
    'campaign',
    array['dashboard', 'analytics', 'campaign_content']::text[],
    array['Kampanyalar', 'Vitrin', 'Icerik']::text[],
    true,
    true,
    20
  ),
  (
    'admin_support',
    'Destek Ekibi',
    'Destek, sikayet ve iade akislarina odaklanan ekip rolu.',
    '#10B981',
    'support_agent',
    array['dashboard', 'support', 'orders_returns']::text[],
    array['Ticket', 'Iade sorunlari', 'Escalation']::text[],
    true,
    true,
    30
  ),
  (
    'admin_store_ops',
    'Magaza Yonetimi',
    'Magaza ve satici operasyonlarini yoneten ekip rolu.',
    '#0891B2',
    'storefront',
    array[
      'dashboard',
      'analytics',
      'store_management',
      'product_approval',
      'orders_returns',
      'map_search'
    ]::text[],
    array['Basvurular', 'Urun onay', 'Konum degisimi']::text[],
    true,
    true,
    40
  ),
  (
    'admin_investor',
    'Yatirimcilar',
    'Yuksek seviye performans izleme ve raporlama rolu.',
    '#6366F1',
    'insights',
    array['dashboard', 'analytics', 'finance']::text[],
    array['KPI', 'Gelir trendi', 'Yonetici raporu']::text[],
    true,
    true,
    50
  ),
  (
    'admin_finance',
    'Muhasebe',
    'Finans ve odeme akislarina odaklanan ekip rolu.',
    '#16A34A',
    'account_balance_wallet',
    array['dashboard', 'analytics', 'finance', 'orders_returns']::text[],
    array['Hakedis', 'Komisyon', 'Odeme takibi']::text[],
    true,
    true,
    60
  ),
  (
    'admin_security',
    'Siberciler',
    'Guvenlik loglari ve erisim takibini yoneten ekip rolu.',
    '#DC2626',
    'gpp_good',
    array['dashboard', 'security_logs']::text[],
    array['Oturum takibi', 'Loglar', 'Risk inceleme']::text[],
    true,
    true,
    70
  )
on conflict (role_key) do update
set
  title = excluded.title,
  description = excluded.description,
  color_hex = excluded.color_hex,
  icon_name = excluded.icon_name,
  modules = excluded.modules,
  scopes = excluded.scopes,
  is_system = excluded.is_system,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order,
  updated_at = timezone('utc', now());
