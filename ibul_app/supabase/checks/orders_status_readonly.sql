-- =============================================================================
-- READ ONLY. Do not run this file as a migration and do not change data.
-- Review it in the Supabase SQL editor. Every statement is a SELECT.
--
-- Purpose: see whether live public.orders.status can store print_anchor
-- before 20261107_waiter_request_single_order.sql is applied.
-- =============================================================================

select
  current_database() as database_name,
  current_setting('server_version') as server_version;

select
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'orders'
  and column_name in ('status', 'order_status')
order by column_name;

select
  n.nspname as enum_schema,
  t.typname as enum_name,
  e.enumlabel as enum_label
from pg_type t
join pg_namespace n on n.oid = t.typnamespace
join pg_enum e on e.enumtypid = t.oid
where n.nspname = 'public'
  and t.typname in (
    select udt_name
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'orders'
      and column_name in ('status', 'order_status')
  )
order by t.typname, e.enumsortorder;

select
  con.conname as constraint_name,
  con.contype as constraint_type,
  pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
  and rel.relname = 'orders'
  and (
    pg_get_constraintdef(con.oid) ilike '%status%'
    or con.contype in ('c', 't')
  )
order by con.conname;

select
  tg.tgname as trigger_name,
  pg_get_triggerdef(tg.oid) as definition,
  p.proname as function_name
from pg_trigger tg
join pg_class rel on rel.oid = tg.tgrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
join pg_proc p on p.oid = tg.tgfoid
where nsp.nspname = 'public'
  and rel.relname = 'orders'
  and not tg.tgisinternal
order by tg.tgname;

select
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and (
    p.proname = 'send_table_order_idempotent'
    or p.proname = 'create_table_order_with_print_jobs'
    or p.proname = 'order_send_request_fingerprint'
  )
order by p.proname, identity_arguments;
