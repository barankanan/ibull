-- P0: replace table_orders / table_order_history USING(true) hotfix policies
-- with store-staff isolation. Customer QR INSERT stays allowed when the store
-- exists. Occupancy for guests goes through a narrow SECURITY DEFINER RPC.
--
-- Rollback:
--   drop policy table_orders_select_staff on public.table_orders;
--   (recreate previous policy only after live audit)

create or replace function public.user_can_access_restaurant(p_restaurant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_restaurant_id is not null
    and auth.uid() is not null
    and (
      auth.uid() = p_restaurant_id
      or exists (
        select 1
        from public.store_sub_admins sa
        join public.users u on u.id = auth.uid()
        where sa.store_id = p_restaurant_id
          and sa.status = 'active'
          and (
            (
              sa.email is not null
              and trim(sa.email) <> ''
              and lower(trim(u.email)) = lower(trim(sa.email))
            )
            or (
              sa.phone is not null
              and trim(sa.phone) <> ''
              and trim(coalesce(u.phone, '')) = trim(sa.phone)
            )
          )
      )
    );
$$;

create or replace function public.parse_store_uuid(p_store_id text)
returns uuid
language plpgsql
immutable
set search_path = public
as $$
begin
  if p_store_id is null or btrim(p_store_id) = '' then
    return null;
  end if;
  return btrim(p_store_id)::uuid;
exception
  when invalid_text_representation then
    return null;
end;
$$;

create or replace function public.can_manage_table_orders(p_seller_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() is not null
    and (
      public.is_admin_user(auth.uid())
      or public.user_can_access_restaurant(public.parse_store_uuid(p_seller_id))
    );
$$;

revoke all on function public.can_manage_table_orders(text) from public;
grant execute on function public.can_manage_table_orders(text) to authenticated;

create or replace function public.list_occupied_table_numbers(p_seller_id uuid)
returns integer[]
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    array_agg(distinct o.table_number) filter (where o.table_number is not null),
    '{}'::integer[]
  )
  from public.table_orders o
  where o.seller_id::text = p_seller_id::text
    and lower(coalesce(o.status, '')) not in (
      'closed', 'paid', 'cancelled', 'canceled',
      'completed', 'complete', 'archived', 'payment_completed'
    );
$$;

revoke all on function public.list_occupied_table_numbers(uuid) from public;
grant execute on function public.list_occupied_table_numbers(uuid)
  to anon, authenticated;

do $$
begin
  if to_regclass('public.table_orders') is null then
    return;
  end if;

  alter table public.table_orders enable row level security;

  drop policy if exists "table_orders_authenticated_all" on public.table_orders;
  drop policy if exists "table_orders_seller_all" on public.table_orders;
  drop policy if exists "table_orders_select_own" on public.table_orders;
  drop policy if exists "table_orders_insert_own" on public.table_orders;
  drop policy if exists "table_orders_update_own" on public.table_orders;
  drop policy if exists "table_orders_delete_own" on public.table_orders;
  drop policy if exists "table_orders_garson_manage" on public.table_orders;
  drop policy if exists "table_orders_seller_or_garson" on public.table_orders;
  drop policy if exists "table_orders_select_staff" on public.table_orders;
  drop policy if exists "table_orders_insert_authenticated" on public.table_orders;
  drop policy if exists "table_orders_update_staff" on public.table_orders;
  drop policy if exists "table_orders_delete_staff" on public.table_orders;

  execute $sql$
    create policy "table_orders_select_staff"
    on public.table_orders
    for select
    to authenticated
    using (public.can_manage_table_orders(seller_id::text))
  $sql$;

  execute $sql$
    create policy "table_orders_insert_authenticated"
    on public.table_orders
    for insert
    to authenticated
    with check (
      public.can_manage_table_orders(seller_id::text)
      or exists (
        select 1
        from public.stores s
        where s.seller_id::text = table_orders.seller_id::text
      )
    )
  $sql$;

  execute $sql$
    create policy "table_orders_update_staff"
    on public.table_orders
    for update
    to authenticated
    using (public.can_manage_table_orders(seller_id::text))
    with check (public.can_manage_table_orders(seller_id::text))
  $sql$;

  execute $sql$
    create policy "table_orders_delete_staff"
    on public.table_orders
    for delete
    to authenticated
    using (public.can_manage_table_orders(seller_id::text))
  $sql$;
end;
$$;

create or replace function public.table_orders_require_staff()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller text;
begin
  v_seller := coalesce(new.seller_id::text, old.seller_id::text);
  if public.can_manage_table_orders(v_seller) then
    return coalesce(new, old);
  end if;
  raise exception 'Bu restoran için masa siparişi yetkiniz yok.'
    using errcode = '42501';
end;
$$;

drop trigger if exists table_orders_require_staff_trg on public.table_orders;
do $$
begin
  if to_regclass('public.table_orders') is null then
    return;
  end if;
  execute $sql$
    create trigger table_orders_require_staff_trg
    before update or delete on public.table_orders
    for each row
    execute function public.table_orders_require_staff()
  $sql$;
end;
$$;

do $$
begin
  if to_regclass('public.table_order_history') is null then
    return;
  end if;

  alter table public.table_order_history enable row level security;

  drop policy if exists "table_order_history_authenticated" on public.table_order_history;
  drop policy if exists "table_order_history_seller_read" on public.table_order_history;
  drop policy if exists "table_order_history_seller_insert" on public.table_order_history;
  drop policy if exists "table_order_history_select_staff" on public.table_order_history;
  drop policy if exists "table_order_history_insert_staff" on public.table_order_history;

  execute $sql$
    create policy "table_order_history_select_staff"
    on public.table_order_history
    for select
    to authenticated
    using (public.can_manage_table_orders(seller_id::text))
  $sql$;

  execute $sql$
    create policy "table_order_history_insert_staff"
    on public.table_order_history
    for insert
    to authenticated
    with check (public.can_manage_table_orders(seller_id::text))
  $sql$;
end;
$$;
