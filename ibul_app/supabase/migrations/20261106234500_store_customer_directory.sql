-- Prepared only. Do not apply to production without the named approval
-- Bu migration'ı production'a uygula.
--
-- Store-scoped customer directory. A table selection is a separate row.
-- It does not update orders, table_orders, table_payments, or store_tables.

create table if not exists public.store_customers (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null,
  display_name text not null,
  phone text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint store_customers_name_len check (
    char_length(btrim(display_name)) between 1 and 80
  ),
  constraint store_customers_phone_len check (
    phone is null or char_length(btrim(phone)) <= 32
  )
);

create unique index if not exists store_customers_store_phone_uidx
  on public.store_customers (store_id, phone)
  where phone is not null and btrim(phone) <> '';

create index if not exists store_customers_store_name_idx
  on public.store_customers (store_id, lower(display_name));

create table if not exists public.store_table_customer_selections (
  store_id uuid not null,
  table_number integer not null,
  customer_id uuid,
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (store_id, table_number),
  constraint store_table_customer_selections_table_check check (table_number > 0),
  constraint store_table_customer_selections_customer_fkey
    foreign key (customer_id) references public.store_customers (id) on delete cascade
);

create or replace function public.store_table_customer_same_store()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.customer_id is not null and not exists (
    select 1
    from public.store_customers c
    where c.id = new.customer_id
      and c.store_id = new.store_id
  ) then
    raise exception 'Müşteri bu işletmeye ait değil.' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists store_table_customer_same_store
  on public.store_table_customer_selections;
create trigger store_table_customer_same_store
  before insert or update on public.store_table_customer_selections
  for each row
  execute function public.store_table_customer_same_store();

alter table public.store_customers enable row level security;
alter table public.store_table_customer_selections enable row level security;

drop policy if exists store_customers_read on public.store_customers;
create policy store_customers_read
  on public.store_customers
  for select
  to authenticated
  using (
    public.restaurant_has_permission(store_id, 'viewOrders')
    or public.restaurant_has_permission(store_id, 'manageOrders')
  );

drop policy if exists store_customers_write on public.store_customers;
create policy store_customers_write
  on public.store_customers
  for all
  to authenticated
  using (public.restaurant_has_permission(store_id, 'manageOrders'))
  with check (public.restaurant_has_permission(store_id, 'manageOrders'));

drop policy if exists store_table_customer_read on public.store_table_customer_selections;
create policy store_table_customer_read
  on public.store_table_customer_selections
  for select
  to authenticated
  using (
    public.restaurant_has_permission(store_id, 'viewOrders')
    or public.restaurant_has_permission(store_id, 'manageOrders')
  );

drop policy if exists store_table_customer_write on public.store_table_customer_selections;
create policy store_table_customer_write
  on public.store_table_customer_selections
  for all
  to authenticated
  using (public.restaurant_has_permission(store_id, 'manageOrders'))
  with check (public.restaurant_has_permission(store_id, 'manageOrders'));

revoke all on public.store_customers from public, anon;
revoke all on public.store_table_customer_selections from public, anon;
grant select, insert, update, delete on public.store_customers to authenticated;
grant select, insert, update, delete on public.store_table_customer_selections to authenticated;
