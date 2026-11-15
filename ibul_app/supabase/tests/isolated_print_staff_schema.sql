-- Isolated schema for the print-identity and staff-password gate.
-- This file is a test harness. Do not run it on the live project.

create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key,
  email text,
  phone text,
  email_confirmed_at timestamptz,
  phone_confirmed_at timestamptz
);

create or replace function auth.jwt()
returns jsonb
language sql
stable
as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb;
$$;

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(auth.jwt()->>'sub', '')::uuid;
$$;

create table if not exists public.stores (
  seller_id uuid primary key
);

create table if not exists public.store_branches (
  id uuid primary key,
  store_id uuid not null,
  status text not null
);

create table if not exists public.store_sub_admins (
  id uuid primary key,
  store_id uuid not null,
  branch_id uuid,
  status text not null,
  permissions text[] not null default '{}',
  auth_user_id uuid,
  email text,
  phone text
);

create table if not exists public.store_tables (
  id uuid primary key,
  seller_id uuid not null,
  branch_id uuid,
  is_active boolean not null
);

create table if not exists public.orders (
  id uuid primary key,
  local_order_id text
);

create table if not exists public.print_jobs (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null,
  order_id uuid,
  station_id uuid,
  job_type text,
  payload jsonb,
  status text not null
);
