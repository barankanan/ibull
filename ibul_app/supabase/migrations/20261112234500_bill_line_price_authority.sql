-- Prepared only. Do not apply to production without the named approval:
-- "Bu migration'ı production'a uygula"
--
-- Closes client-trusted prices on table-order lines. The existing
-- update_restaurant_table_order function still writes the row; this trigger
-- rejects a price the catalog does not authorize, protects paid lines, keeps
-- the bill above payments taken after the order was opened, and audits
-- deletes and price changes. A guarded wrapper adds an optional revision
-- check so two concurrent edits cannot silently overwrite each other.

create table if not exists public.restaurant_order_line_audit (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null,
  order_id uuid not null,
  order_item_id uuid,
  action text not null,
  actor_id uuid,
  before_row jsonb,
  after_row jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

comment on table public.restaurant_order_line_audit is
  'Append-only bill line audit. Clients cannot insert or read it.';

alter table public.restaurant_order_line_audit enable row level security;
revoke all on table public.restaurant_order_line_audit from public, anon, authenticated;

create or replace function public.restaurant_catalog_unit_price(
  p_restaurant_id uuid,
  p_product_id text
) returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(nullif(p.discount_price, 0), p.price)::numeric
  from public.products p
  where p.id = p_product_id
    and p.seller_id = p_restaurant_id
$$;

create or replace function public.enforce_restaurant_bill_line()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id uuid := coalesce(new.order_id, old.order_id);
  v_restaurant uuid;
  v_order_type text;
  v_table_id uuid;
  v_opened timestamptz;
  v_order_updated timestamptz;
  v_catalog numeric;
  v_paid boolean := false;
  v_finance boolean := false;
  v_price_changed boolean := false;
  v_table_number integer;
  v_paid_sum numeric := 0;
  v_others numeric := 0;
  v_next numeric := 0;
  v_expected text;
begin
  select o.restaurant_id, o.order_type, o.table_id, o.created_at, o.updated_at
    into v_restaurant, v_order_type, v_table_id, v_opened, v_order_updated
  from public.orders o
  where o.id = v_order_id;
  if v_restaurant is null
     or (
       coalesce(v_order_type, '') is distinct from 'table'
       and v_table_id is null
     ) then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;
  if auth.uid() is not null
     and not public.restaurant_has_permission(v_restaurant, 'manageOrders') then
    raise exception 'Bu restoran için sipariş güncelleme yetkiniz yok.'
      using errcode = '42501';
  end if;

  v_expected := nullif(current_setting('ibul.bill_base_updated_at', true), '');
  if v_expected is not null
     and v_order_updated is distinct from v_expected::timestamptz then
    raise exception 'Adisyon başka bir işlemde değişti. Yenileyip tekrar deneyin.'
      using errcode = '40001';
  end if;

  if tg_op <> 'INSERT' then
    v_paid :=
      lower(coalesce(old.attributes->>'paid', '')) in ('true', 't', 'paid')
      or lower(coalesce(old.attributes->>'payment_status', ''))
        in ('paid', 'partial', 'partially_paid')
      or coalesce(nullif(old.attributes->>'paid_amount', '')::numeric, 0) > 0;
  end if;

  if v_paid and (
    tg_op = 'DELETE'
    or new.quantity is distinct from old.quantity
    or coalesce(new.unit_price, 0) is distinct from coalesce(old.unit_price, 0)
    or new.product_id is distinct from old.product_id
    or coalesce(old.attributes->>'paid', '')
       is distinct from coalesce(new.attributes->>'paid', '')
    or coalesce(old.attributes->>'payment_status', '')
       is distinct from coalesce(new.attributes->>'payment_status', '')
    or coalesce(old.attributes->>'paid_amount', '')
       is distinct from coalesce(new.attributes->>'paid_amount', '')
  ) then
    raise exception 'Ödemesi alınmış kalem değiştirilemez.'
      using errcode = '42501';
  end if;

  if tg_op <> 'DELETE' then
    if new.quantity is null or new.quantity < 1 or new.quantity > 99 then
      raise exception 'Adet 1 ile 99 arasında olmalı.'
        using errcode = '22023';
    end if;
    v_finance := public.restaurant_has_permission(v_restaurant, 'viewFinance');
    v_price_changed := tg_op = 'INSERT'
      or abs(coalesce(new.unit_price, 0) - coalesce(old.unit_price, 0)) > 0.01;
    if new.product_id is not null and btrim(new.product_id) <> '' then
      v_catalog := public.restaurant_catalog_unit_price(v_restaurant, new.product_id);
      if v_catalog is null and v_price_changed then
        raise exception 'Ürün bu işletmeye ait değil.'
          using errcode = '42501';
      end if;
      if v_price_changed
         and v_catalog is not null
         and abs(coalesce(new.unit_price, 0) - v_catalog) > 0.01
         and not v_finance then
        raise exception 'Fiyat değiştirme yetkiniz yok.'
          using errcode = '42501';
      end if;
    elsif v_price_changed and not v_finance then
      raise exception 'Fiyat değiştirme yetkiniz yok.'
        using errcode = '42501';
    end if;
    new.line_total := round(coalesce(new.unit_price, 0) * new.quantity, 2);
    new.total_price := new.line_total;
  end if;

  if to_regclass('public.table_payments') is not null
     and to_regclass('public.store_tables') is not null
     and v_table_id is not null then
    select t.table_number into v_table_number
    from public.store_tables t
    where t.id = v_table_id
      and t.seller_id = v_restaurant;
    if v_table_number is not null then
      select coalesce(sum(tp.amount), 0) into v_paid_sum
      from public.table_payments tp
      where tp.seller_id = v_restaurant
        and tp.table_number = v_table_number
        and tp.created_at >= coalesce(v_opened, '-infinity'::timestamptz);
      select coalesce(sum(coalesce(oi.line_total, oi.unit_price * oi.quantity, 0)), 0)
        into v_others
      from public.order_items oi
      where oi.order_id = v_order_id
        and (tg_op = 'INSERT' or oi.id is distinct from old.id);
      if tg_op = 'DELETE' then
        v_next := v_others;
      else
        v_next := v_others + coalesce(new.unit_price, 0) * new.quantity;
      end if;
      if v_paid_sum > v_next + 0.01 then
        raise exception 'Yeni toplam, alınmış ödemenin altında kalamaz.'
          using errcode = 'P0001';
      end if;
    end if;
  end if;

  if tg_op = 'DELETE'
     or (tg_op = 'UPDATE' and (
       new.quantity is distinct from old.quantity
       or coalesce(new.unit_price, 0) is distinct from coalesce(old.unit_price, 0)
     )) then
    insert into public.restaurant_order_line_audit (
      restaurant_id, order_id, order_item_id, action, actor_id, before_row, after_row
    ) values (
      v_restaurant,
      v_order_id,
      case when tg_op = 'DELETE' then old.id else new.id end,
      case
        when tg_op = 'DELETE' then 'delete'
        when coalesce(new.unit_price, 0) is distinct from coalesce(old.unit_price, 0)
          then 'price_change'
        else 'quantity_change'
      end,
      auth.uid(),
      case when tg_op = 'INSERT' then null else to_jsonb(old) end,
      case when tg_op = 'DELETE' then null else to_jsonb(new) end
    );
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_restaurant_bill_line on public.order_items;
create trigger enforce_restaurant_bill_line
  before insert or update or delete on public.order_items
  for each row execute function public.enforce_restaurant_bill_line();

create or replace function public.update_restaurant_table_order_guarded(
  p_restaurant_id uuid,
  p_order_id uuid,
  p_items jsonb,
  p_print_items jsonb default '[]'::jsonb,
  p_job_type text default 'add_item',
  p_extra_print_items jsonb default '[]'::jsonb,
  p_extra_job_type text default 'cancel_item',
  p_revision_key text default null,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_expected_updated_at timestamptz default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Oturum gerekli.' using errcode = '42501';
  end if;
  if not public.restaurant_has_permission(p_restaurant_id, 'manageOrders') then
    raise exception 'Bu restoran için sipariş güncelleme yetkiniz yok.'
      using errcode = '42501';
  end if;
  perform set_config(
    'ibul.bill_base_updated_at',
    coalesce(p_expected_updated_at::text, ''),
    true
  );
  return public.update_restaurant_table_order(
    p_restaurant_id,
    p_order_id,
    p_items,
    p_print_items,
    p_job_type,
    p_extra_print_items,
    p_extra_job_type,
    p_revision_key,
    p_waiter_id,
    p_waiter_name
  );
end;
$$;

revoke all on function public.restaurant_catalog_unit_price(uuid, text) from public, anon, authenticated;
revoke all on function public.enforce_restaurant_bill_line() from public, anon, authenticated;
revoke all on function public.update_restaurant_table_order_guarded(uuid, uuid, jsonb, jsonb, text, jsonb, text, text, uuid, text, timestamptz) from public, anon;
grant execute on function public.update_restaurant_table_order_guarded(uuid, uuid, jsonb, jsonb, text, jsonb, text, text, uuid, text, timestamptz) to authenticated;

create or replace function public.prevent_table_order_retype()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(old.order_type, '') = 'table'
     and coalesce(new.order_type, '') is distinct from 'table'
     and exists (
       select 1 from public.order_items oi where oi.order_id = old.id
     ) then
    raise exception 'Masa siparişinin tipi değiştirilemez.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_table_order_retype on public.orders;
create trigger prevent_table_order_retype
  before update of order_type on public.orders
  for each row execute function public.prevent_table_order_retype();

revoke all on function public.prevent_table_order_retype() from public, anon, authenticated;
