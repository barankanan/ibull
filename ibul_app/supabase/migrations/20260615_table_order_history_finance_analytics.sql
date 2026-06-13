-- Finance analytics fields on closed-table history.
-- Backward compatible: ADD COLUMN IF NOT EXISTS only.

alter table public.table_order_history
  add column if not exists table_name text,
  add column if not exists display_table_label text,
  add column if not exists table_display_name text,
  add column if not exists table_area_name text,
  add column if not exists archived_at timestamptz,
  add column if not exists archived_orders jsonb;

create index if not exists idx_table_order_history_seller_area_closed
  on public.table_order_history (seller_id, table_area_name, closed_at desc);

-- Extend close_table_with_history to persist table labels + area at archive time.
-- Looks up store_tables when caller omits label/area params.
create or replace function public.close_table_with_history(
  p_seller_id        uuid,
  p_table_number     integer,
  p_payment_method   text default 'cash',
  p_payment_note     text default null,
  p_waiter_id        uuid default null,
  p_waiter_name      text default null,
  p_session_key      text default null,
  p_table_name       text default null,
  p_table_area_name  text default null,
  p_display_table_label text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_grand_total numeric(12,2);
  v_session text;
  v_table_name text;
  v_area_name text;
  v_display_label text;
begin
  if p_seller_id <> auth.uid() then
    raise exception 'Yetki hatası: bu masayı kapatma yetkiniz yok.' using errcode = '42501';
  end if;

  select
    coalesce(nullif(trim(p_table_name), ''), nullif(trim(st.display_label), ''), 'Masa ' || p_table_number::text),
    coalesce(nullif(trim(p_table_area_name), ''), nullif(trim(st.area_name), ''), ''),
    coalesce(nullif(trim(p_display_table_label), ''), nullif(trim(st.display_label), ''), 'Masa ' || p_table_number::text)
  into v_table_name, v_area_name, v_display_label
  from public.store_tables st
  where st.seller_id = p_seller_id
    and st.table_number = p_table_number
  limit 1;

  if v_table_name is null then
    v_table_name := coalesce(nullif(trim(p_table_name), ''), 'Masa ' || p_table_number::text);
    v_area_name := coalesce(nullif(trim(p_table_area_name), ''), '');
    v_display_label := coalesce(nullif(trim(p_display_table_label), ''), v_table_name);
  end if;

  v_session := coalesce(
    p_session_key,
    'session_' || p_seller_id || '_' || p_table_number || '_' || extract(epoch from now())::bigint::text
  );

  for v_order in
    select * from public.table_orders
    where seller_id = p_seller_id::text
      and table_number = p_table_number
  loop
    select coalesce(sum(
      (item->>'price')::numeric * coalesce((item->>'quantity')::numeric, 1)
    ), 0)
    into v_grand_total
    from jsonb_array_elements(coalesce(v_order.items, '[]'::jsonb)) as item;

    insert into public.table_order_history (
      original_order_id, seller_id, table_number,
      items, status, revision,
      last_edit_summary, last_edit_note,
      payment_method, payment_note,
      waiter_id, waiter_name,
      grand_total, session_key,
      table_name, display_table_label, table_display_name, table_area_name,
      opened_at, closed_at, created_at
    ) values (
      v_order.id, p_seller_id, p_table_number,
      coalesce(v_order.items, '[]'::jsonb),
      'closed',
      coalesce(v_order.revision, 1),
      coalesce(v_order.last_edit_summary, '{}'::jsonb),
      v_order.last_edit_note,
      p_payment_method, p_payment_note,
      p_waiter_id, p_waiter_name,
      v_grand_total, v_session,
      v_table_name, v_display_label, v_display_label, nullif(v_area_name, ''),
      v_order.created_at, timezone('utc', now()),
      v_order.created_at
    );
  end loop;

  delete from public.table_orders
  where seller_id = p_seller_id::text
    and table_number = p_table_number;
end;
$$;

comment on function public.close_table_with_history is
  'Atomically archives active table orders to history with payment/area/label metadata, then removes table_orders rows.';
