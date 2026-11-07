-- Isolated checks for staff permission enforcement.
-- The runner creates a scratch database, applies the prelude below, then the
-- migration, then these assertions. Not for production.

begin;

create schema if not exists auth;

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated;
  end if;
end
$$;

create table if not exists public.users (
  id uuid primary key,
  email text,
  phone text
);

create table if not exists public.store_sub_admins (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null,
  email text,
  phone text,
  permissions text[] not null default '{}'::text[],
  status text not null default 'invited',
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.store_sub_admins enable row level security;

drop policy if exists store_sub_admins_owner_all on public.store_sub_admins;
create policy store_sub_admins_owner_all
  on public.store_sub_admins
  for all
  to authenticated
  using (auth.uid() = store_id)
  with check (auth.uid() = store_id);

drop policy if exists store_sub_admins_active_self_select on public.store_sub_admins;
create policy store_sub_admins_active_self_select
  on public.store_sub_admins
  for select
  to authenticated
  using (
    status = 'active'
    and exists (
      select 1
      from public.users u
      where u.id = auth.uid()
        and (
          (
            store_sub_admins.email is not null
            and btrim(store_sub_admins.email) <> ''
            and lower(btrim(coalesce(u.email, ''))) = lower(btrim(store_sub_admins.email))
          )
          or (
            store_sub_admins.phone is not null
            and btrim(store_sub_admins.phone) <> ''
            and btrim(coalesce(u.phone, '')) = btrim(store_sub_admins.phone)
          )
        )
    )
  );

create table if not exists public.table_payments (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  session_key text not null,
  amount numeric(12,2) not null,
  method text not null default 'cash',
  is_closing boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.table_payments enable row level security;

drop policy if exists table_payments_seller_manage on public.table_payments;
create policy table_payments_seller_manage
  on public.table_payments
  for all
  to authenticated
  using (seller_id = auth.uid())
  with check (seller_id = auth.uid());

grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.store_sub_admins to authenticated;
grant select, insert, update, delete on public.table_payments to authenticated;
grant select on public.users to authenticated;

commit;
