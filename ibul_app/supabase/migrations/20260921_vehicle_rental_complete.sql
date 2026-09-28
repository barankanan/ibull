-- Vehicle rental production close-out:
-- 1) gen_random_bytes search_path (42883)
-- 2) accept_terms must not jump to pending_payment
-- 3) national id + store contracts + acceptance snapshot
-- 4) submit idempotency + rental_code on seller review

create extension if not exists pgcrypto;

create or replace function public.tr_national_id_valid(p_value text)
returns boolean
language plpgsql
immutable
as $$
declare
  v text := regexp_replace(coalesce(p_value, ''), '\D', '', 'g');
  d int[];
  i int;
  odd int := 0;
  even int := 0;
  tenth int;
  eleventh int := 0;
begin
  if v !~ '^[1-9][0-9]{10}$' then
    return false;
  end if;
  d := array(
    select (substr(v, g.n, 1))::int
    from generate_series(1, 11) as g(n)
  );
  for i in 1..9 loop
    if (i % 2) = 1 then
      odd := odd + d[i];
    else
      even := even + d[i];
    end if;
  end loop;
  tenth := mod((odd * 7) - even, 10);
  if tenth < 0 then
    tenth := tenth + 10;
  end if;
  if d[10] <> tenth then
    return false;
  end if;
  for i in 1..10 loop
    eleventh := eleventh + d[i];
  end loop;
  return d[11] = mod(eleventh, 10);
end;
$$;

create or replace function public.vehicle_rental_make_code()
returns text
language plpgsql
set search_path = public, extensions, pg_catalog
as $$
declare
  v_code text;
  v_tries int := 0;
begin
  loop
    v_tries := v_tries + 1;
    v_code := 'IBR-' || upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 6));
    exit when not exists (
      select 1 from public.vehicle_reservations where rental_code = v_code
    ) or v_tries > 8;
  end loop;
  return v_code;
end;
$$;

create or replace function public.vehicle_rental_fill_code()
returns trigger
language plpgsql
set search_path = public, extensions, pg_catalog
as $$
begin
  if NEW.status in (
       'pending_seller_review', 'pending_payment', 'confirmed', 'reserved'
     )
     and NEW.rental_code is null then
    NEW.rental_code := public.vehicle_rental_make_code();
  end if;
  return NEW;
end;
$$;

alter table public.vehicle_reservations
  add column if not exists customer_national_id text;

alter table public.vehicle_reservations
  drop constraint if exists vehicle_reservations_national_id_chk;
alter table public.vehicle_reservations
  add constraint vehicle_reservations_national_id_chk
  check (
    customer_national_id is null
    or public.tr_national_id_valid(customer_national_id)
  );

create or replace function public.accept_vehicle_rental_terms(p_reservation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  update public.vehicle_reservations
  set terms_accepted_at = timezone('utc', now())
  where id = p_reservation_id
    and customer_id = v_uid
    and status in ('pending_docs', 'pending_seller_review');
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

create table if not exists public.store_contracts (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.stores (seller_id) on delete cascade,
  contract_type text not null check (contract_type in ('product_sale', 'vehicle_rental')),
  title text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (seller_id, contract_type)
);

create table if not exists public.store_contract_versions (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.store_contracts (id) on delete cascade,
  version int not null check (version > 0),
  body_text text,
  pdf_bucket text,
  pdf_path text,
  content_sha256 text,
  created_by uuid,
  created_at timestamptz not null default timezone('utc', now()),
  unique (contract_id, version),
  check (
    nullif(btrim(coalesce(body_text, '')), '') is not null
    or nullif(btrim(coalesce(pdf_path, '')), '') is not null
  )
);

create table if not exists public.store_contract_acceptances (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null references public.vehicle_reservations (id) on delete cascade,
  contract_version_id uuid not null references public.store_contract_versions (id),
  accepted_by uuid not null,
  accepted_at timestamptz not null default timezone('utc', now()),
  unique (reservation_id)
);

create index if not exists store_contracts_seller_idx
  on public.store_contracts (seller_id, contract_type);
create index if not exists store_contract_versions_contract_idx
  on public.store_contract_versions (contract_id, version desc);

alter table public.store_contracts enable row level security;
alter table public.store_contract_versions enable row level security;
alter table public.store_contract_acceptances enable row level security;

drop policy if exists store_contracts_seller_all on public.store_contracts;
create policy store_contracts_seller_all on public.store_contracts
for all using (
  seller_id = auth.uid() or public.vehicle_is_admin()
) with check (
  seller_id = auth.uid() or public.vehicle_is_admin()
);

drop policy if exists store_contracts_reader_select on public.store_contracts;
create policy store_contracts_reader_select on public.store_contracts
for select using (
  is_active
  or seller_id = auth.uid()
  or public.vehicle_is_admin()
);

drop policy if exists store_contract_versions_seller_all on public.store_contract_versions;
create policy store_contract_versions_seller_all on public.store_contract_versions
for all using (
  exists (
    select 1 from public.store_contracts c
    where c.id = contract_id
      and (c.seller_id = auth.uid() or public.vehicle_is_admin())
  )
) with check (
  exists (
    select 1 from public.store_contracts c
    where c.id = contract_id
      and (c.seller_id = auth.uid() or public.vehicle_is_admin())
  )
);

drop policy if exists store_contract_versions_reader_select on public.store_contract_versions;
create policy store_contract_versions_reader_select on public.store_contract_versions
for select using (
  exists (
    select 1 from public.store_contracts c
    where c.id = contract_id
      and (
        c.is_active
        or c.seller_id = auth.uid()
        or public.vehicle_is_admin()
      )
  )
);

drop policy if exists store_contract_acceptances_party on public.store_contract_acceptances;
create policy store_contract_acceptances_party on public.store_contract_acceptances
for select using (
  accepted_by = auth.uid()
  or public.vehicle_is_admin()
  or exists (
    select 1 from public.vehicle_reservations r
    where r.id = reservation_id
      and (r.customer_id = auth.uid() or r.seller_id = auth.uid())
  )
);

insert into storage.buckets (id, name, public)
values ('store-contracts', 'store-contracts', false)
on conflict (id) do update set public = false;

drop policy if exists store_contracts_owner_read on storage.objects;
create policy store_contracts_owner_read on storage.objects
for select using (
  bucket_id = 'store-contracts'
  and (
    auth.uid()::text = (storage.foldername(name))[1]
    or public.vehicle_is_admin()
  )
);

drop policy if exists store_contracts_owner_write on storage.objects;
create policy store_contracts_owner_write on storage.objects
for insert with check (
  bucket_id = 'store-contracts'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists store_contracts_owner_update on storage.objects;
create policy store_contracts_owner_update on storage.objects
for update using (
  bucket_id = 'store-contracts'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists store_contracts_owner_delete on storage.objects;
create policy store_contracts_owner_delete on storage.objects
for delete using (
  bucket_id = 'store-contracts'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists store_contracts_customer_read on storage.objects;
create policy store_contracts_customer_read on storage.objects
for select using (
  bucket_id = 'store-contracts'
  and exists (
    select 1
    from public.store_contract_versions v
    join public.store_contracts c on c.id = v.contract_id
    where v.pdf_path = name
      and c.is_active
  )
);

grant select, insert, update, delete on public.store_contracts to authenticated;
grant select, insert, update, delete on public.store_contract_versions to authenticated;
grant select, insert on public.store_contract_acceptances to authenticated;

create or replace function public.publish_store_contract(
  p_contract_type text,
  p_title text,
  p_body_text text default null,
  p_pdf_path text default null,
  p_pdf_bucket text default 'store-contracts'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_catalog
as $$
declare
  v_uid uuid := auth.uid();
  v_contract public.store_contracts%rowtype;
  v_version int;
  v_id uuid;
  v_hash text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if p_contract_type not in ('product_sale', 'vehicle_rental') then
    return jsonb_build_object('ok', false, 'error', 'invalid_type');
  end if;
  if nullif(btrim(coalesce(p_title, '')), '') is null then
    return jsonb_build_object('ok', false, 'error', 'title_required');
  end if;
  if nullif(btrim(coalesce(p_body_text, '')), '') is null
     and nullif(btrim(coalesce(p_pdf_path, '')), '') is null then
    return jsonb_build_object('ok', false, 'error', 'content_required');
  end if;

  insert into public.store_contracts (seller_id, contract_type, title, is_active)
  values (v_uid, p_contract_type, btrim(p_title), true)
  on conflict (seller_id, contract_type) do update
    set title = excluded.title,
        is_active = true,
        updated_at = timezone('utc', now())
  returning * into v_contract;

  select coalesce(max(version), 0) + 1 into v_version
  from public.store_contract_versions
  where contract_id = v_contract.id;

  v_hash := encode(
    digest(convert_to(coalesce(p_body_text, '') || '|' || coalesce(p_pdf_path, ''), 'utf8'), 'sha256'),
    'hex'
  );

  insert into public.store_contract_versions (
    contract_id, version, body_text, pdf_bucket, pdf_path, content_sha256, created_by
  ) values (
    v_contract.id, v_version, nullif(btrim(coalesce(p_body_text, '')), ''),
    case when p_pdf_path is null then null else p_pdf_bucket end,
    nullif(btrim(coalesce(p_pdf_path, '')), ''),
    v_hash, v_uid
  ) returning id into v_id;

  return jsonb_build_object(
    'ok', true,
    'contract_id', v_contract.id,
    'version_id', v_id,
    'version', v_version
  );
end;
$$;

create or replace function public.set_store_contract_active(
  p_contract_type text,
  p_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  update public.store_contracts
  set is_active = p_active, updated_at = timezone('utc', now())
  where seller_id = v_uid and contract_type = p_contract_type;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.active_store_contract(
  p_seller_id uuid,
  p_contract_type text
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_row record;
begin
  select c.id as contract_id, c.title, c.is_active, v.id as version_id,
         v.version, v.body_text, v.pdf_bucket, v.pdf_path, v.created_at
  into v_row
  from public.store_contracts c
  join public.store_contract_versions v on v.contract_id = c.id
  where c.seller_id = p_seller_id
    and c.contract_type = p_contract_type
    and c.is_active
  order by v.version desc
  limit 1;
  if not found then
    return jsonb_build_object('ok', true, 'missing', true);
  end if;
  return jsonb_build_object(
    'ok', true,
    'missing', false,
    'contract_id', v_row.contract_id,
    'title', v_row.title,
    'version_id', v_row.version_id,
    'version', v_row.version,
    'body_text', v_row.body_text,
    'pdf_bucket', v_row.pdf_bucket,
    'pdf_path', v_row.pdf_path,
    'created_at', v_row.created_at
  );
end;
$$;

create or replace function public.accept_store_contract_for_rental(
  p_reservation_id uuid,
  p_version_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_res public.vehicle_reservations%rowtype;
  v_ok boolean;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  select * into v_res from public.vehicle_reservations where id = p_reservation_id for update;
  if not found or v_res.customer_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  select exists (
    select 1
    from public.store_contract_versions v
    join public.store_contracts c on c.id = v.contract_id
    where v.id = p_version_id
      and c.seller_id = v_res.seller_id
      and c.contract_type = 'vehicle_rental'
      and c.is_active
  ) into v_ok;
  if not v_ok then
    return jsonb_build_object('ok', false, 'error', 'contract_mismatch');
  end if;
  insert into public.store_contract_acceptances (
    reservation_id, contract_version_id, accepted_by
  ) values (p_reservation_id, p_version_id, v_uid)
  on conflict (reservation_id) do update
    set contract_version_id = excluded.contract_version_id,
        accepted_by = excluded.accepted_by,
        accepted_at = timezone('utc', now());
  update public.vehicle_reservations
  set terms_accepted_at = timezone('utc', now())
  where id = p_reservation_id;
  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.publish_store_contract(text, text, text, text, text) to authenticated;
grant execute on function public.set_store_contract_active(text, boolean) to authenticated;
grant execute on function public.active_store_contract(uuid, text) to authenticated;
grant execute on function public.accept_store_contract_for_rental(uuid, uuid) to authenticated;
grant execute on function public.tr_national_id_valid(text) to authenticated;
