-- =============================================================================
-- IBUL live security audit — READ ONLY
-- Run in Supabase SQL Editor. Do not apply schema changes with this file.
-- Expected: zero ALTER / DROP / CREATE / GRANT / REVOKE / INSERT / UPDATE.
--
-- SQL Editor runs the whole file as one batch: if any statement errors, you
-- get 0 result sets. This script must not reference tables that may be absent.
-- =============================================================================

-- 1) RLS enabled?
select
  n.nspname as schema_name,
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname in (
    'users',
    'table_orders',
    'table_order_history',
    'store_brand_verification_applications',
    'vehicle_listings',
    'vehicle_reservations',
    'vehicle_favorites',
    'vehicle_kyc_documents',
    'admin_user_permissions',
    'admin_role_catalog',
    'stores',
    'orders',
    'search_telemetry'
  )
order by c.relname;

-- 2) All policies on relevant tables
select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual as using_expr,
  with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'users',
    'table_orders',
    'table_order_history',
    'store_brand_verification_applications',
    'vehicle_listings',
    'vehicle_reservations',
    'vehicle_favorites',
    'vehicle_kyc_documents',
    'admin_user_permissions',
    'stores',
    'orders',
    'search_telemetry'
  )
order by tablename, policyname;

-- 3) Open USING(true) / WITH CHECK(true) policies (P0 candidates)
select
  tablename,
  policyname,
  cmd,
  roles,
  qual as using_expr,
  with_check
from pg_policies
where schemaname = 'public'
  and (
    coalesce(qual, '') in ('true', '(true)')
    or coalesce(with_check, '') in ('true', '(true)')
  )
order by tablename, policyname;

-- 4) users columns (role / seller flags)
select
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'users'
order by ordinal_position;

-- 5) users UPDATE policies specifically
select policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename = 'users'
order by cmd, policyname;

-- 6) users privileged-column trigger
select
  t.tgname,
  p.proname,
  t.tgenabled
from pg_trigger t
join pg_proc p on p.oid = t.tgfoid
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = 'users'
  and not t.tgisinternal
order by t.tgname;

-- 7) Admin / role helper functions
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as args,
  case when p.prosecdef then 'SECURITY DEFINER' else 'SECURITY INVOKER' end
    as security,
  p.proowner::regrole as owner,
  p.proconfig as search_path_settings
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'is_admin_user',
    'is_admin_role',
    'vehicle_is_admin',
    'admin_can_manage_users',
    'current_user_role',
    'current_admin_has_module',
    'restore_own_admin_role',
    'user_can_access_restaurant',
    'can_manage_table_orders',
    'protect_users_privileged_columns',
    'close_table_orders',
    'close_table_orders_v2',
    'update_vehicle_rental_draft',
    'create_vehicle_rental_reservation',
    'vehicle_rental_window_blocked'
  )
order by p.proname;

-- 8) All SECURITY DEFINER functions in public
select
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as args,
  p.proowner::regrole as owner,
  p.proconfig as search_path_settings,
  has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_execute,
  has_function_privilege('public', p.oid, 'EXECUTE') as public_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef
order by p.proname;

-- 9) SECURITY DEFINER missing fixed search_path
select p.proname, pg_get_function_identity_arguments(p.oid) as args, p.proconfig
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef
  and (
    p.proconfig is null
    or not exists (
      select 1
      from unnest(p.proconfig) cfg
      where cfg like 'search_path=%'
    )
  )
order by p.proname;

-- 10) Table grants
select
  table_name,
  grantee,
  privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in (
    'users',
    'table_orders',
    'table_order_history',
    'store_brand_verification_applications',
    'vehicle_listings',
    'vehicle_reservations',
    'vehicle_favorites'
  )
  and grantee in ('anon', 'authenticated', 'public', 'service_role')
order by table_name, grantee, privilege_type;

-- 11) Exclusion / unique constraints on reservations
select
  c.conname,
  c.contype,
  pg_get_constraintdef(c.oid) as definition
from pg_constraint c
join pg_class t on t.oid = c.conrelid
join pg_namespace n on n.oid = t.relnamespace
where n.nspname = 'public'
  and t.relname in ('vehicle_reservations', 'vehicle_rental_blocks', 'users')
order by t.relname, c.conname;

-- 12) Relevant indexes
select
  tablename,
  indexname,
  indexdef
from pg_indexes
where schemaname = 'public'
  and tablename in (
    'users',
    'table_orders',
    'vehicle_reservations',
    'vehicle_favorites',
    'store_brand_verification_applications',
    'admin_user_permissions'
  )
order by tablename, indexname;

-- 13) Migration history catalog — do NOT select from the table directly.
-- This project applies SQL via Dashboard; supabase_migrations.schema_migrations
-- often does not exist (42P01). Listing pg_catalog is enough.
select
  n.nspname as schema_name,
  c.relname as table_name,
  case
    when n.nspname = 'supabase_migrations' then 'cli_history'
    else 'other_migration_table'
  end as kind
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r'
  and (
    (n.nspname = 'supabase_migrations' and c.relname in ('schema_migrations', 'seed_files'))
    or (n.nspname in ('public', 'auth') and c.relname = 'schema_migrations')
  )
order by n.nspname, c.relname;

-- 14) P0 boolean flags for paste-back
select
  exists (
    select 1 from pg_policies
    where tablename = 'users'
      and cmd = 'UPDATE'
      and coalesce(qual, '') in ('true', '(true)', '(auth.uid() = id)')
  ) as users_update_policy_exists,
  exists (
    select 1 from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_proc p on p.oid = t.tgfoid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'users'
      and p.proname = 'protect_users_privileged_columns'
      and not t.tgisinternal
  ) as users_privileged_trigger_present,
  exists (
    select 1 from pg_policies
    where tablename = 'table_orders'
      and policyname = 'table_orders_authenticated_all'
  ) as table_orders_authenticated_all_present,
  exists (
    select 1 from pg_policies
    where tablename = 'table_order_history'
      and policyname = 'table_order_history_authenticated'
  ) as table_order_history_authenticated_present,
  exists (
    select 1 from pg_policies
    where tablename = 'store_brand_verification_applications'
      and policyname in (
        'brand_verification_admin_select_all',
        'brand_verification_admin_update_all'
      )
      and (
        coalesce(qual, '') in ('true', '(true)')
        or coalesce(with_check, '') in ('true', '(true)')
      )
  ) as brand_verification_open_admin_policy,
  exists (
    select 1 from pg_constraint
    where conname = 'vehicle_reservations_no_overlap_excl'
  ) as rental_exclusion_present;
