-- =============================================================================
-- Migration: table_orders_table_label_fields
-- Date: 2026-06-12
-- Purpose:
--   Store printable table label metadata on table_orders rows so the mobile app
--   can persist `display_table_label` / area labels without PostgREST errors.
--   Fixes runtime error:
--     "Could not find the 'area_name' column of 'table_orders' in the schema cache"
-- =============================================================================

alter table public.table_orders
  add column if not exists display_table_label text;

alter table public.table_orders
  add column if not exists table_display_name text;

alter table public.table_orders
  add column if not exists table_name text;

alter table public.table_orders
  add column if not exists table_area_name text;

alter table public.table_orders
  add column if not exists area_name text;

alter table public.table_orders
  add column if not exists area_table_number integer;

