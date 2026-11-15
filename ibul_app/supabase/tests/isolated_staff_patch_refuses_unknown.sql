-- A close function whose authorization text is not one of the known gates
-- must abort the migration and remain unchanged.

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
end $$;

create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
create table if not exists public.table_payments (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  session_key text not null,
  amount numeric(12,2) not null,
  method text not null default 'cash',
  is_closing boolean not null default false
);
create table if not exists public.stores (seller_id uuid primary key);
create or replace function public.restaurant_has_permission(p_restaurant_id uuid, p_permission text)
returns boolean language sql stable as $$ select false; $$;
create or replace function public.restaurant_table_number_access(p_restaurant_id uuid, p_number integer)
returns boolean language sql stable as $$ select false; $$;
create or replace function public.validate_restaurant_staff_membership()
returns trigger language plpgsql as $$
begin
  if not new.permissions <@ array['manageProducts','viewOrders','manageOrders','manageCampaigns','viewFinance','manageSupport','manageStoreProfile']::text[] then
    raise exception 'Geçersiz yetki.';
  end if;
  return new;
end $$;
create or replace function public.close_table_with_history(p_seller_id uuid, p_table_number integer)
returns void language plpgsql as $$
begin
  raise exception 'ozel-kapi';
end $$;
create or replace function public.transfer_table_orders(p_seller_id uuid, p_from_table integer, p_to_table integer)
returns void language plpgsql as $$
begin
  if p_seller_id <> auth.uid() then
    raise exception 'Yetki hatası.' using errcode = '42501';
  end if;
end $$;

\ir ../migrations/2026110117_staff_operation_permissions.sql
