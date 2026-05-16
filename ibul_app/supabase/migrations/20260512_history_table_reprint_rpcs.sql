-- =============================================================================
-- Migration: history_table_reprint_rpcs
-- Date: 2026-05-12
-- Purpose: Garson "Geçmiş Masalar" sayfasından kapanmış masalar için
--          adisyon / mutfak fişi yeniden yazdırılabilsin diye eklenen
--          RPC'ler. Hiçbiri canlı `table_orders` satırı oluşturmaz, sadece
--          `print_jobs` kuyruğuna kayıt düşer.
--
-- 1. ensure_table_order_history() - 20260407 migration'ı uygulanmadıysa,
--    tablonun var olduğundan emin olur (idempotent).
-- 2. create_kitchen_reprint_print_job(...) - geçmiş masadan mutfak fişi
--    yeniden basımı için. Payload'a "(ESKİ MASA)" başlığı eklenir.
-- 3. create_adisyon_reprint_print_job(...) - geçmiş masadan adisyon
--    yeniden basımı için. (`create_adisyon_print_job` ile aynı şemada
--    ama "(ESKİ MASA)" header_note ile.)
-- =============================================================================

begin;

-- ─── 0. table_order_history tablosunu garanti et ──────────────────────────────
-- 20260407 migration'ı uygulanmamış olabilir. Eksikse oluştururuz.

create table if not exists public.table_order_history (
  id                uuid primary key default gen_random_uuid(),
  original_order_id uuid not null,
  seller_id         uuid not null references auth.users(id) on delete cascade,
  table_number      integer not null check (table_number > 0),
  items             jsonb not null default '[]'::jsonb,
  status            text not null default 'closed',
  revision          integer not null default 1,
  last_edit_summary jsonb not null default '{}'::jsonb,
  last_edit_note    text,
  payment_method    text,
  payment_note      text,
  waiter_id         uuid references auth.users(id) on delete set null,
  waiter_name       text,
  grand_total       numeric(12,2),
  session_key       text,
  opened_at         timestamptz,
  closed_at         timestamptz not null default timezone('utc', now()),
  created_at        timestamptz not null default timezone('utc', now())
);

alter table public.table_order_history enable row level security;

drop policy if exists "table_order_history_seller_read" on public.table_order_history;
create policy "table_order_history_seller_read"
  on public.table_order_history
  for select
  using (
    seller_id = auth.uid()
    or public.user_can_access_restaurant(seller_id)
  );

drop policy if exists "table_order_history_seller_insert" on public.table_order_history;
create policy "table_order_history_seller_insert"
  on public.table_order_history
  for insert
  with check (
    seller_id = auth.uid()
    or public.user_can_access_restaurant(seller_id)
  );

create index if not exists idx_table_order_history_seller_closed
  on public.table_order_history (seller_id, closed_at desc);

create index if not exists idx_table_order_history_seller_table_closed
  on public.table_order_history (seller_id, table_number, closed_at desc);

-- ─── 1. Mutfak fişi yeniden basımı RPC ────────────────────────────────────────

create or replace function public.create_kitchen_reprint_print_job(
  p_restaurant_id uuid,
  p_table_number  integer,
  p_payload       jsonb,
  p_waiter_id     uuid default null,
  p_waiter_name   text default null,
  p_source_device text default null,
  p_history_id    uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job_id          uuid;
  v_restaurant_name text;
  v_waiter_name     text;
  v_payload         jsonb;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  if not public.user_can_access_restaurant(p_restaurant_id) then
    raise exception 'Bu restoran için işlem yetkiniz yok.' using errcode = '42501';
  end if;

  if p_table_number <= 0 then
    raise exception 'Masa numarası geçersiz.' using errcode = '22023';
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Mutfak fişi payload geçersiz.' using errcode = '22023';
  end if;

  select business_name
    into v_restaurant_name
  from public.stores
  where seller_id = p_restaurant_id
  limit 1;

  v_restaurant_name := coalesce(v_restaurant_name, 'Restoran');
  v_waiter_name := coalesce(nullif(trim(coalesce(p_waiter_name, '')), ''), 'Garson');

  v_payload := p_payload
    || jsonb_build_object(
      'restaurant_id', p_restaurant_id,
      'restaurant_name', v_restaurant_name,
      'table_no', p_table_number::text,
      'table_number', p_table_number,
      'waiter_id', p_waiter_id,
      'waiter_name', v_waiter_name,
      'printer_role', 'mutfak',
      'document_type', 'kitchen',
      'job_type', 'reprint',
      'is_history_reprint', true,
      'history_record_id', p_history_id,
      'header_note', '(ESKİ MASA)',
      'reprint_label', '(ESKİ MASA)',
      'source_device', coalesce(nullif(trim(coalesce(p_source_device, '')), ''), 'seller_panel'),
      'created_at', now()
    );

  insert into public.print_jobs (
    restaurant_id,
    order_id,
    station_id,
    printer_id,
    job_type,
    document_type,
    printer_role,
    status,
    payload
  )
  values (
    p_restaurant_id,
    null,
    null,
    null,
    'reprint',
    'kitchen',
    'mutfak',
    'pending',
    v_payload
  )
  returning id into v_job_id;

  return jsonb_build_object(
    'status', 'ok',
    'print_job_id', v_job_id,
    'print_job_count', 1,
    'print_job_ids', jsonb_build_array(v_job_id),
    'is_history_reprint', true
  );
end;
$$;

grant execute on function public.create_kitchen_reprint_print_job(
  uuid,
  integer,
  jsonb,
  uuid,
  text,
  text,
  uuid
) to authenticated;

comment on function public.create_kitchen_reprint_print_job(
  uuid,
  integer,
  jsonb,
  uuid,
  text,
  text,
  uuid
)
is 'Geçmiş masalar için mutfak fişini yeniden yazdırır. Canlı sipariş satırı oluşturmaz; sadece print_jobs kuyruğuna "(ESKİ MASA)" başlıklı bir mutfak fişi düşer.';

-- ─── 2. Adisyon yeniden basımı RPC (history) ──────────────────────────────────
-- create_adisyon_print_job ile aynı semantik, ama header_note=(ESKİ MASA).

create or replace function public.create_adisyon_reprint_print_job(
  p_restaurant_id uuid,
  p_table_number  integer,
  p_payload       jsonb,
  p_waiter_id     uuid default null,
  p_waiter_name   text default null,
  p_source_device text default null,
  p_history_id    uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job_id          uuid;
  v_restaurant_name text;
  v_waiter_name     text;
  v_payload         jsonb;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  if not public.user_can_access_restaurant(p_restaurant_id) then
    raise exception 'Bu restoran için işlem yetkiniz yok.' using errcode = '42501';
  end if;

  if p_table_number <= 0 then
    raise exception 'Masa numarası geçersiz.' using errcode = '22023';
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Adisyon payload geçersiz.' using errcode = '22023';
  end if;

  select business_name
    into v_restaurant_name
  from public.stores
  where seller_id = p_restaurant_id
  limit 1;

  v_restaurant_name := coalesce(v_restaurant_name, 'Restoran');
  v_waiter_name := coalesce(nullif(trim(coalesce(p_waiter_name, '')), ''), 'Garson');

  v_payload := p_payload
    || jsonb_build_object(
      'restaurant_id', p_restaurant_id,
      'restaurant_name', v_restaurant_name,
      'table_no', p_table_number::text,
      'table_number', p_table_number,
      'waiter_id', p_waiter_id,
      'waiter_name', v_waiter_name,
      'printer_role', 'adisyon',
      'document_type', 'receipt',
      'job_type', 'receipt',
      'is_history_reprint', true,
      'history_record_id', p_history_id,
      'header_note', '(ESKİ MASA)',
      'reprint_label', '(ESKİ MASA)',
      'source_device', coalesce(nullif(trim(coalesce(p_source_device, '')), ''), 'seller_panel'),
      'created_at', now()
    );

  insert into public.print_jobs (
    restaurant_id,
    order_id,
    station_id,
    printer_id,
    job_type,
    document_type,
    printer_role,
    status,
    payload
  )
  values (
    p_restaurant_id,
    null,
    null,
    null,
    'receipt',
    'receipt',
    'adisyon',
    'pending',
    v_payload
  )
  returning id into v_job_id;

  return jsonb_build_object(
    'status', 'ok',
    'print_job_id', v_job_id,
    'print_job_count', 1,
    'print_job_ids', jsonb_build_array(v_job_id),
    'is_history_reprint', true
  );
end;
$$;

grant execute on function public.create_adisyon_reprint_print_job(
  uuid,
  integer,
  jsonb,
  uuid,
  text,
  text,
  uuid
) to authenticated;

comment on function public.create_adisyon_reprint_print_job(
  uuid,
  integer,
  jsonb,
  uuid,
  text,
  text,
  uuid
)
is 'Geçmiş masalar için adisyonu yeniden yazdırır. "(ESKİ MASA)" başlığı eklenir; canlı sipariş satırı oluşturmaz.';

-- ─── 3. PostgREST schema reload ───────────────────────────────────────────────

notify pgrst, 'reload schema';

commit;
