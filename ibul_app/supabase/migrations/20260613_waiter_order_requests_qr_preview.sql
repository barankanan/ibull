-- =============================================================================
-- Waiter order requests (unverified QR → garson onayı → table_orders + print)
-- =============================================================================
-- Ops: Supabase Dashboard → Database → Replication → enable for
--      `waiter_order_requests` if garson gerçek zamanlı kartları gerekir.
-- =============================================================================

alter table if exists public.products
  add column if not exists station_id uuid;

-- Garson fiyat RPC'leri bu sütunlara güvenir. Eski projelerde yoksa CREATE FUNCTION
-- aşamasında "column p.base_price does not exist" benzeri hatalar oluşur.
alter table if exists public.products
  add column if not exists base_price numeric;
alter table if exists public.products
  add column if not exists pricing_mode text default 'base_only';
alter table if exists public.products
  add column if not exists size_options jsonb default '[]'::jsonb;
alter table if exists public.products
  add column if not exists price_per_kg numeric;
alter table if exists public.products
  add column if not exists portion_price numeric;

update public.products p
set
  base_price = coalesce(p.base_price, p.portion_price, p.price, 0),
  pricing_mode = coalesce(nullif(trim(p.pricing_mode), ''), 'base_only'),
  size_options = case
    when p.size_options is null then '[]'::jsonb
    when jsonb_typeof(p.size_options) <> 'array' then '[]'::jsonb
    else p.size_options
  end
where p.base_price is null
   or coalesce(nullif(trim(p.pricing_mode), ''), '') = ''
   or p.size_options is null
   or jsonb_typeof(coalesce(p.size_options, 'null'::jsonb)) <> 'array';

-- Customer flow:
--   - submit_waiter_order_request(...) → row status pending_waiter_approval
--   - No table_orders / no print until garson approves
-- Staff flow:
--   - approve_waiter_order_request(id, edited_items?) → server price recompute,
--     insert table_orders, optional kitchen print via create_table_order_with_print_jobs
--   - reject_waiter_order_request(id, reason)
-- =============================================================================

create table if not exists public.waiter_order_requests (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null,
  table_number integer not null,
  items_draft jsonb not null default '[]'::jsonb,
  customer_notes text,
  table_payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending_waiter_approval'
    check (
      status in (
        'pending_waiter_approval',
        'rejected',
        'approved_converted',
        'cancelled'
      )
    ),
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_by uuid references auth.users (id),
  resolved_at timestamptz,
  rejection_reason text,
  resulting_table_order_id uuid references public.table_orders (id) on delete set null,
  server_items_snapshot jsonb,
  constraint waiter_order_requests_table_positive check (table_number > 0)
);

create index if not exists idx_waiter_order_requests_seller_status_created
  on public.waiter_order_requests (seller_id, status, created_at desc);

create index if not exists idx_waiter_order_requests_created_by
  on public.waiter_order_requests (created_by, created_at desc);

create or replace function public.touch_waiter_order_requests_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_waiter_order_requests_touch on public.waiter_order_requests;
create trigger trg_waiter_order_requests_touch
before update on public.waiter_order_requests
for each row execute procedure public.touch_waiter_order_requests_updated_at();

comment on table public.waiter_order_requests is
  'Müşteri (doğrulanmamış QR) garson onayı bekleyen masa istekleri; kesin sipariş table_orders üzerinden oluşur.';

-- ─── Helpers: product lookup & unit price (server-side) ─────────────────────

create or replace function public._waiter_req_product_row(p_seller uuid, p_pid text)
returns table (
  id text,
  name text,
  base_price numeric,
  price numeric,
  pricing_mode text,
  price_per_kg numeric,
  portion_price numeric,
  size_options jsonb,
  station_id uuid
)
language sql
stable
security definer
set search_path = public
as $$
  select
    -- products.id bazı projelerde uuid, bazılarında text: tek tip için text döndür.
    p.id::text as id,
    coalesce(nullif(trim(p.name), ''), 'Ürün') as name,
    coalesce(p.base_price, p.price, 0)::numeric as base_price,
    coalesce(p.price, 0)::numeric as price,
    coalesce(nullif(trim(p.pricing_mode), ''), 'base_only') as pricing_mode,
    coalesce(p.price_per_kg, 0)::numeric as price_per_kg,
    coalesce(p.portion_price, p.price, 0)::numeric as portion_price,
    coalesce(p.size_options, '[]'::jsonb) as size_options,
    nullif(trim(coalesce(p.station_id::text, '')), '')::uuid as station_id
  from public.products p
  where p.seller_id = p_seller
    and (
      p.id::text = trim(p_pid)
      or p.id::text = trim(both '"' from p_pid)
    )
  limit 1;
$$;

create or replace function public._waiter_req_size_unit_price(
  p_size_options jsonb,
  p_selected_size text
) returns numeric
language plpgsql
immutable
as $$
declare
  opt jsonb;
  nm text;
begin
  if p_size_options is null or jsonb_typeof(p_size_options) <> 'array' then
    return null;
  end if;
  if p_selected_size is null or trim(p_selected_size) = '' then
    return null;
  end if;
  for opt in select * from jsonb_array_elements(p_size_options)
  loop
    nm := coalesce(nullif(trim(opt ->> 'name'), ''), '');
    if lower(nm) = lower(trim(p_selected_size)) then
      return coalesce((opt ->> 'price')::numeric, null);
    end if;
  end loop;
  return null;
end;
$$;

create or replace function public._waiter_req_simple_unit_price(
  p_seller uuid,
  p_item jsonb
) returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  pid text := coalesce(
    nullif(trim(p_item ->> 'productId'), ''),
    nullif(trim(p_item ->> 'product_id'), '')
  );
  pr record;
  sel_size text := coalesce(
    nullif(trim(p_item ->> 'selectedSizeName'), ''),
    nullif(trim(p_item ->> 'selected_size_name'), '')
  );
  grams int := coalesce(
    (p_item ->> 'selectedWeightGrams')::int,
    (p_item ->> 'selected_weight_grams')::int,
    0
  );
  svc numeric := coalesce(
    (p_item ->> 'selectedServiceAmount')::numeric,
    (p_item ->> 'selected_service_amount')::numeric,
    null
  );
  sz_price numeric;
  w numeric;
begin
  if pid is null or pid = '' then
    return coalesce((p_item ->> 'price')::numeric, 0);
  end if;
  select * into pr from public._waiter_req_product_row(p_seller, pid);
  if not found then
    raise exception 'Ürün bulunamadı veya bu restorana ait değil: %', pid;
  end if;

  sz_price := public._waiter_req_size_unit_price(pr.size_options, sel_size);
  if sz_price is not null then
    return sz_price;
  end if;

  if coalesce(pr.pricing_mode, '') = 'weight_only'
     or (grams > 0 and coalesce(pr.price_per_kg, 0) > 0) then
    w := greatest(grams, 1);
    return (coalesce(pr.price_per_kg, 0) * (w::numeric / 1000.0));
  end if;

  if svc is not null and coalesce(pr.portion_price, 0) > 0 then
    return coalesce(pr.portion_price, pr.base_price, pr.price, 0) * svc;
  end if;

  return coalesce(pr.base_price, pr.price, 0);
end;
$$;

-- Preserve JSON shape; recompute unit `price` + line totals for simple lines;
-- for mixed_service, recompute each child then parent aggregates.
create or replace function public.recalculate_waiter_request_items(
  p_seller_id uuid,
  p_items jsonb
) returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  out jsonb := '[]'::jsonb;
  el jsonb;
  typ text;
  qty int;
  unit_p numeric;
  line_total numeric;
  children jsonb;
  child_rec record;
  child_unit numeric;
  child_qty int;
  child_lt numeric;
  acc_unit numeric;
  nm text;
  pid text;
  mixed_name text;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    return '[]'::jsonb;
  end if;

  for el in select value from jsonb_array_elements(p_items)
  loop
    typ := lower(coalesce(el.value ->> 'type', ''));
    if typ = 'waiter_call' then
      out := out || jsonb_build_array(el.value);
      continue;
    end if;

    if lower(coalesce(el.value ->> 'item_type', '')) = 'mixed_service' then
      mixed_name := coalesce(
        nullif(trim(el.value ->> 'item_name'), ''),
        nullif(trim(el.value ->> 'name'), ''),
        'Servis'
      );
      qty := greatest(coalesce((el.value ->> 'quantity')::int, 1), 1);
      children := coalesce(el.value -> 'child_items', '[]'::jsonb);
      acc_unit := 0;

      if jsonb_typeof(children) = 'array' then
        for child_rec in select jsonb_array_elements(children) as j
        loop
          child_qty := greatest(coalesce((child_rec.j ->> 'quantity')::int, 1), 1);
          pid := coalesce(
            nullif(trim(child_rec.j ->> 'product_id'), ''),
            nullif(trim(child_rec.j ->> 'productId'), '')
          );
          if pid is null or pid = '' then
            child_unit := coalesce(
              (child_rec.j ->> 'unit_price')::numeric,
              (child_rec.j ->> 'unit_price_snapshot')::numeric,
              0
            );
          else
            child_unit := public._waiter_req_simple_unit_price(
              p_seller_id,
              jsonb_build_object(
                'productId', pid,
                'selectedSizeName', child_rec.j ->> 'selected_size_name',
                'selectedWeightGrams', child_rec.j ->> 'selected_weight_grams',
                'selectedServiceAmount', child_rec.j ->> 'selected_service_amount'
              )
            );
          end if;
          child_lt := child_unit * child_qty::numeric;
          acc_unit := acc_unit + child_lt;
        end loop;
      end if;

      line_total := acc_unit * qty::numeric;
      out := out || jsonb_build_array(
        el.value
          || jsonb_build_object(
            'price', case when qty > 0 then acc_unit else 0 end,
            'unit_price_snapshot', acc_unit,
            'unitPriceSnapshot', acc_unit,
            'calculatedLineTotal', line_total,
            'line_total', line_total,
            'total_price', line_total,
            'server_priced', true
          )
      );
      continue;
    end if;

    qty := greatest(coalesce((el.value ->> 'quantity')::int, 1), 1);
    nm := coalesce(
      nullif(trim(el.value ->> 'name'), ''),
      nullif(trim(el.value ->> 'product_name'), ''),
      'Ürün'
    );
    unit_p := public._waiter_req_simple_unit_price(p_seller_id, el.value);
    line_total := unit_p * qty::numeric;
    out := out || jsonb_build_array(
      el.value
        || jsonb_build_object(
          'name', nm,
          'price', unit_p,
          'unit_price_snapshot', unit_p,
          'unitPriceSnapshot', unit_p,
          'calculatedLineTotal', line_total,
          'line_total', line_total,
          'total_price', line_total,
          'server_priced', true
        )
    );
  end loop;

  return out;
end;
$$;

-- Flatten to kitchen print JSON (snake_case keys expected by print RPC).
create or replace function public.flatten_waiter_items_for_kitchen_print(
  p_seller_id uuid,
  p_items jsonb
) returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  out jsonb := '[]'::jsonb;
  el jsonb;
  typ text;
  qty int;
  pid text;
  pr record;
  nm text;
  note text;
  children jsonb;
  child_rec record;
  child_qty int;
  parent_qty int;
  unit_p numeric;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    return '[]'::jsonb;
  end if;

  for el in select value from jsonb_array_elements(p_items)
  loop
    typ := lower(coalesce(el.value ->> 'type', ''));
    if typ = 'waiter_call' then
      continue;
    end if;

    if lower(coalesce(el.value ->> 'item_type', '')) = 'mixed_service' then
      parent_qty := greatest(coalesce((el.value ->> 'quantity')::int, 1), 1);
      children := coalesce(el.value -> 'child_items', '[]'::jsonb);
      if jsonb_typeof(children) = 'array' then
        for child_rec in select jsonb_array_elements(children) as j
        loop
          child_qty := greatest(coalesce((child_rec.j ->> 'quantity')::int, 1), 1);
          pid := coalesce(
            nullif(trim(child_rec.j ->> 'product_id'), ''),
            nullif(trim(child_rec.j ->> 'productId'), '')
          );
          continue when pid is null or pid = '';
          select * into pr from public._waiter_req_product_row(p_seller_id, pid);
          if not found then
            continue;
          end if;
          nm := coalesce(
            nullif(trim(child_rec.j ->> 'product_name'), ''),
            nullif(trim(child_rec.j ->> 'name'), ''),
            pr.name
          );
          unit_p := public._waiter_req_simple_unit_price(
            p_seller_id,
            jsonb_build_object(
              'productId', pid,
              'selectedSizeName', child_rec.j ->> 'selected_size_name',
              'selectedWeightGrams', child_rec.j ->> 'selected_weight_grams',
              'selectedServiceAmount', child_rec.j ->> 'selected_service_amount'
            )
          );
          note := coalesce(
            nullif(trim(child_rec.j ->> 'notes'), ''),
            nullif(trim(child_rec.j ->> 'note'), ''),
            nullif(trim(el.value ->> 'notes'), '')
          );
          out := out || jsonb_build_array(
            jsonb_build_object(
              'product_id', pid,
              'name', nm,
              'quantity', child_qty * parent_qty,
              'price', unit_p,
              'notes', note,
              'station_id', pr.station_id::text
            )
          );
        end loop;
      end if;
      continue;
    end if;

    pid := coalesce(
      nullif(trim(el.value ->> 'productId'), ''),
      nullif(trim(el.value ->> 'product_id'), '')
    );
    continue when pid is null or pid = '';
    qty := greatest(coalesce((el.value ->> 'quantity')::int, 1), 1);
    select * into pr from public._waiter_req_product_row(p_seller_id, pid);
    continue when not found;
    nm := coalesce(nullif(trim(el.value ->> 'name'), ''), pr.name);
    unit_p := (el.value ->> 'price')::numeric;
    if unit_p is null then
      unit_p := public._waiter_req_simple_unit_price(p_seller_id, el.value);
    end if;
    note := coalesce(
      nullif(trim(el.value ->> 'notes'), ''),
      nullif(trim(el.value ->> 'note'), '')
    );
    out := out || jsonb_build_array(
      jsonb_build_object(
        'product_id', pid,
        'name', nm,
        'quantity', qty,
        'price', unit_p,
        'notes', note,
        'station_id', pr.station_id::text
      )
    );
  end loop;

  return out;
end;
$$;

-- ─── RPC: submit (customer, authenticated) ─────────────────────────────────

create or replace function public.submit_waiter_order_request(
  p_seller_id uuid,
  p_table_number integer,
  p_items jsonb,
  p_customer_notes text default null,
  p_table_payload jsonb default '{}'::jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'Oturum açmanız gerekir.' using errcode = '42501';
  end if;
  if p_table_number is null or p_table_number <= 0 then
    raise exception 'Geçersiz masa numarası.' using errcode = '22023';
  end if;
  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'İstek kalemleri boş olamaz.' using errcode = '22023';
  end if;
  if not exists (select 1 from public.stores s where s.seller_id = p_seller_id) then
    raise exception 'Mağaza bulunamadı.' using errcode = '22023';
  end if;

  insert into public.waiter_order_requests (
    seller_id,
    table_number,
    items_draft,
    customer_notes,
    table_payload,
    status,
    created_by
  ) values (
    p_seller_id,
    p_table_number,
    p_items,
    nullif(trim(coalesce(p_customer_notes, '')), ''),
    coalesce(p_table_payload, '{}'::jsonb),
    'pending_waiter_approval',
    v_uid
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.submit_waiter_order_request from public;
grant execute on function public.submit_waiter_order_request to authenticated;

-- ─── RPC: reject (staff) ───────────────────────────────────────────────────

create or replace function public.reject_waiter_order_request(
  p_request_id uuid,
  p_reason text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller uuid;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  select seller_id into v_seller
  from public.waiter_order_requests
  where id = p_request_id
  for update;

  if v_seller is null then
    raise exception 'İstek bulunamadı.' using errcode = '22023';
  end if;

  if not public.user_can_access_restaurant(v_seller) then
    raise exception 'Bu işletme için yetkiniz yok.' using errcode = '42501';
  end if;

  update public.waiter_order_requests
  set
    status = 'rejected',
    resolved_by = auth.uid(),
    resolved_at = now(),
    rejection_reason = nullif(trim(coalesce(p_reason, '')), '')
  where id = p_request_id
    and status = 'pending_waiter_approval';

  if not found then
    raise exception 'İstek reddedilemedi (durum uygun değil).' using errcode = '22023';
  end if;
end;
$$;

revoke all on function public.reject_waiter_order_request from public;
grant execute on function public.reject_waiter_order_request to authenticated;

-- ─── RPC: approve (staff) ────────────────────────────────────────────────────

create or replace function public.approve_waiter_order_request(
  p_request_id uuid,
  p_edited_items jsonb default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req public.waiter_order_requests%rowtype;
  v_src jsonb;
  v_recalc jsonb;
  v_print jsonb;
  v_table_order_id uuid;
  v_label text;
  v_area text;
  v_area_no int;
  v_print_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;

  select * into v_req
  from public.waiter_order_requests
  where id = p_request_id
  for update;

  if v_req.id is null then
    raise exception 'İstek bulunamadı.' using errcode = '22023';
  end if;

  if v_req.status <> 'pending_waiter_approval' then
    raise exception 'Bu istek onay için uygun değil.' using errcode = '22023';
  end if;

  if not public.user_can_access_restaurant(v_req.seller_id) then
    raise exception 'Bu işletme için yetkiniz yok.' using errcode = '42501';
  end if;

  v_src := coalesce(
    case
      when p_edited_items is null then null
      when jsonb_typeof(p_edited_items) = 'array'
        and jsonb_array_length(p_edited_items) > 0 then p_edited_items
      else null
    end,
    v_req.items_draft
  );

  if v_src is null
     or jsonb_typeof(v_src) <> 'array'
     or jsonb_array_length(v_src) = 0 then
    raise exception 'Onaylanacak kalem bulunamadı.' using errcode = '22023';
  end if;

  v_recalc := public.recalculate_waiter_request_items(v_req.seller_id, v_src);
  v_print := public.flatten_waiter_items_for_kitchen_print(
    v_req.seller_id,
    v_recalc
  );

  v_label := nullif(
    trim(coalesce(v_req.table_payload ->> 'display_table_label', '')),
    ''
  );
  v_area := nullif(trim(coalesce(v_req.table_payload ->> 'table_area_name', '')), '');
  begin
    v_area_no := (nullif(
      trim(coalesce(v_req.table_payload ->> 'area_table_number', '')),
      ''
    ))::integer;
  exception
    when others then
      v_area_no := null;
  end;
  if v_area_no is not null and v_area_no <= 0 then
    v_area_no := null;
  end if;

  insert into public.table_orders (
    seller_id,
    table_number,
    items,
    status,
    created_at,
    display_table_label,
    table_display_name,
    table_name,
    table_area_name,
    area_name,
    area_table_number
  )
  values (
    v_req.seller_id,
    v_req.table_number,
    v_recalc,
    'new',
    now(),
    v_label,
    v_label,
    v_label,
    nullif(v_area, ''),
    nullif(v_area, ''),
    v_area_no
  )
  returning id into v_table_order_id;

  update public.waiter_order_requests
  set
    status = 'approved_converted',
    resolved_by = auth.uid(),
    resolved_at = now(),
    resulting_table_order_id = v_table_order_id,
    server_items_snapshot = v_recalc,
    items_draft = v_src
  where id = p_request_id;

  v_print_result := null;
  if v_print is not null
     and jsonb_typeof(v_print) = 'array'
     and jsonb_array_length(v_print) > 0 then
    v_print_result := public.create_table_order_with_print_jobs(
      v_req.seller_id,
      v_req.table_number,
      v_print,
      auth.uid(),
      coalesce(
        (select u.email from auth.users u where u.id = auth.uid() limit 1),
        'Garson'
      ),
      format(
        'waiter_request:%s %s',
        p_request_id::text,
        coalesce(nullif(trim(v_req.customer_notes), ''), '')
      ),
      'new_order',
      'table'
    );
  end if;

  return jsonb_build_object(
    'request_id', p_request_id,
    'table_order_id', v_table_order_id,
    'items', v_recalc,
    'print_result', v_print_result
  );
end;
$$;

revoke all on function public.approve_waiter_order_request from public;
grant execute on function public.approve_waiter_order_request to authenticated;

-- ─── RLS ─────────────────────────────────────────────────────────────────────

alter table public.waiter_order_requests enable row level security;

drop policy if exists "waiter_req_customer_insert" on public.waiter_order_requests;
create policy "waiter_req_customer_insert"
on public.waiter_order_requests
for insert
to authenticated
with check (created_by = auth.uid());

drop policy if exists "waiter_req_customer_select_own" on public.waiter_order_requests;
create policy "waiter_req_customer_select_own"
on public.waiter_order_requests
for select
to authenticated
using (created_by = auth.uid());

drop policy if exists "waiter_req_customer_cancel_own" on public.waiter_order_requests;
create policy "waiter_req_customer_cancel_own"
on public.waiter_order_requests
for update
to authenticated
using (
  created_by = auth.uid()
  and status = 'pending_waiter_approval'
)
with check (
  created_by = auth.uid()
  and status = 'cancelled'
);

drop policy if exists "waiter_req_staff_select" on public.waiter_order_requests;
create policy "waiter_req_staff_select"
on public.waiter_order_requests
for select
to authenticated
using (public.user_can_access_restaurant(seller_id));

-- Staff mutates only through SECURITY DEFINER RPCs (no direct update policy).

grant select, insert, update on public.waiter_order_requests to authenticated;

revoke all on function public._waiter_req_product_row(uuid, text) from public;
revoke all on function public._waiter_req_size_unit_price(jsonb, text) from public;
revoke all on function public._waiter_req_simple_unit_price(uuid, jsonb) from public;
revoke all on function public.recalculate_waiter_request_items(uuid, jsonb) from public;
revoke all on function public.flatten_waiter_items_for_kitchen_print(uuid, jsonb) from public;
