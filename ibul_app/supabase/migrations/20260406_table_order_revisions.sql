-- =============================================================================
-- Migration: table_order_revisions
-- Date: 2026-04-06
-- Purpose: Masa siparişlerinde aynı kaydı revize edip değişiklik özetini
--          saklayabilmek için revision / updated_at / summary alanlarını ekler.
-- =============================================================================

alter table public.table_orders
  add column if not exists revision integer not null default 1;

alter table public.table_orders
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

alter table public.table_orders
  add column if not exists last_edit_summary jsonb not null default '{}'::jsonb;

alter table public.table_orders
  add column if not exists last_edit_note text;

update public.table_orders
set revision = greatest(coalesce(revision, 1), 1),
    updated_at = coalesce(updated_at, created_at, timezone('utc', now()))
where true;

create or replace function public.set_table_orders_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  if coalesce(new.revision, 0) <= 0 then
    new.revision = 1;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_table_orders_updated_at on public.table_orders;
create trigger trg_table_orders_updated_at
before update on public.table_orders
for each row
execute procedure public.set_table_orders_updated_at();

create index if not exists idx_table_orders_seller_table_updated_at
  on public.table_orders (seller_id, table_number, updated_at desc);

comment on column public.table_orders.revision is
  'Same table order row revision counter. Editing an order should update this row instead of inserting a duplicate.';

comment on column public.table_orders.last_edit_summary is
  'Compact JSON summary of the last waiter-side revision (added/removed/updated preview lines).';

comment on column public.table_orders.last_edit_note is
  'Human-readable helper note describing how the last revision should be interpreted by the UI.';
