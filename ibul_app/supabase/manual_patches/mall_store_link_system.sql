-- AVM ↔ mağaza bağlantısı: tek kanonik tablo mall_branch_links.
--   request_source = 'mall'  → AVM davet eder, mağaza sahibi onaylar.
--   request_source = 'store' → mağaza başvurur (belgeli), AVM yöneticisi onaylar.
-- Önkoşul: mall_management_runtime_fix.sql. Sıra: _precheck -> bu dosya -> _postcheck; geri alma _rollback.
-- db push / migration repair yok. Idempotent. Belgeler private seller-documents bucket'ında.

begin;

alter table public.mall_branch_links alter column mall_unit_id drop not null;
alter table public.mall_branch_links add column if not exists request_source text not null default 'mall';
alter table public.mall_branch_links add column if not exists floor_id uuid references public.mall_floors(id) on delete restrict;
alter table public.mall_branch_links add column if not exists unit_code text;
alter table public.mall_branch_links add column if not exists area_m2 numeric;
alter table public.mall_branch_links add column if not exists review_note text;
alter table public.mall_branch_links drop constraint if exists mall_branch_links_source_check;
alter table public.mall_branch_links drop constraint if exists mall_branch_links_place_check;
alter table public.mall_branch_links drop constraint if exists mall_branch_links_approved_unit_check;
alter table public.mall_branch_links drop constraint if exists mall_branch_links_extra_len;
alter table public.mall_branch_links
  add constraint mall_branch_links_source_check check (request_source in ('mall', 'store')),
  add constraint mall_branch_links_place_check
    check (mall_unit_id is not null or (floor_id is not null and char_length(btrim(coalesce(unit_code, ''))) between 1 and 40)),
  add constraint mall_branch_links_approved_unit_check check (status <> 'approved' or mall_unit_id is not null),
  add constraint mall_branch_links_extra_len check (
    (area_m2 is null or (area_m2 > 0 and area_m2 <= 100000))
    and (review_note is null or char_length(review_note) <= 500));
create unique index if not exists mall_branch_links_code_open_unique
  on public.mall_branch_links (mall_id, lower(btrim(unit_code)))
  where status in ('pending', 'approved') and unit_code is not null;

create table if not exists public.mall_branch_link_documents (
  id uuid primary key default gen_random_uuid(),
  link_id uuid not null references public.mall_branch_links(id) on delete cascade,
  document_type text not null check (document_type in
    ('lease_contract', 'allocation_letter', 'mall_approval', 'storefront_photo', 'other')),
  storage_path text not null unique,
  original_filename text not null check (char_length(original_filename) between 1 and 200),
  mime_type text not null check (mime_type in ('application/pdf', 'image/jpeg', 'image/png', 'image/webp')),
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 10485760),
  uploaded_by uuid not null,
  created_at timestamptz not null default timezone('utc', now())
);
create index if not exists idx_mall_branch_link_documents_link on public.mall_branch_link_documents (link_id);
alter table public.mall_branch_link_documents enable row level security;
revoke all on public.mall_branch_link_documents from anon, authenticated;
grant select on public.mall_branch_link_documents to authenticated;

-- Belgeyi yalnız mağaza sahibi, ilgili AVM'nin mağaza yetkilileri ve admin görür.
create or replace function public.mall_link_document_readable(p_link_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.mall_branch_links l
    join public.store_branches b on b.id = l.branch_id
    where l.id = p_link_id
      and (b.store_id = auth.uid()
           or public.mall_member_has_role(l.mall_id, array['mall_manager', 'mall_store_manager'])
           or public.is_admin_user(auth.uid())))
$$;

drop policy if exists mall_branch_link_documents_select on public.mall_branch_link_documents;
create policy mall_branch_link_documents_select on public.mall_branch_link_documents
  for select to authenticated using (public.mall_link_document_readable(link_id));

drop policy if exists mall_link_docs_owner_insert on storage.objects;
create policy mall_link_docs_owner_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'seller-documents'
              and (storage.foldername(name))[1] = auth.uid()::text
              and (storage.foldername(name))[2] = 'mall-links'
              and (storage.foldername(name))[3] ~ '^[0-9a-fA-F-]{36}$');
drop policy if exists mall_link_docs_select on storage.objects;
create policy mall_link_docs_select on storage.objects for select to authenticated
  using (bucket_id = 'seller-documents'
         and (storage.foldername(name))[2] = 'mall-links'
         and ((storage.foldername(name))[1] = auth.uid()::text
              or exists (select 1 from public.mall_branch_link_documents d
                         where d.storage_path = objects.name and public.mall_link_document_readable(d.link_id))));
drop policy if exists mall_link_docs_owner_delete on storage.objects;
create policy mall_link_docs_owner_delete on storage.objects for delete to authenticated
  using (bucket_id = 'seller-documents'
         and (storage.foldername(name))[1] = auth.uid()::text
         and (storage.foldername(name))[2] = 'mall-links'
         and not exists (select 1 from public.mall_branch_link_documents d where d.storage_path = objects.name));

-- ---------------------------------------------------------------- AVM → mağaza daveti
create or replace function public.request_mall_store_link(
  p_mall_id uuid, p_branch_id uuid, p_floor_id uuid, p_unit_code text, p_area_m2 numeric, p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := btrim(coalesce(p_unit_code, ''));
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_unit public.mall_units%rowtype;
  v_floor_name text;
  v_owner uuid;
  v_mall text;
  v_created boolean := false;
  v_link uuid;
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager', 'mall_store_manager']);
  select f.name into v_floor_name from public.mall_floors f where f.id = p_floor_id and f.mall_id = p_mall_id;
  if v_floor_name is null then raise exception 'Kat bulunamadı.'; end if;
  if char_length(v_code) not between 1 and 40 then raise exception 'Mağaza no gerekli (en fazla 40 karakter).'; end if;
  if p_area_m2 is not null and (p_area_m2 <= 0 or p_area_m2 > 100000) then
    raise exception 'Alan 0 ile 100000 m² arasında olmalı.';
  end if;
  if v_note is not null and char_length(v_note) > 500 then raise exception 'Not en fazla 500 karakter olabilir.'; end if;
  select b.store_id into v_owner from public.store_branches b where b.id = p_branch_id and b.status = 'active';
  if v_owner is null then raise exception 'Mağaza bulunamadı.'; end if;

  select * into v_unit from public.mall_units
  where mall_id = p_mall_id and lower(btrim(unit_code)) = lower(v_code) for update;
  if v_unit.id is not null and v_unit.floor_id <> p_floor_id then
    raise exception 'Mağaza % başka bir katta kayıtlı.', v_code;
  end if;
  if v_unit.occupancy = 'occupied' then
    raise exception 'Mağaza % dolu. Önce mevcut bağlantıyı kaldırın.', v_code;
  end if;
  if v_unit.id is null then
    insert into public.mall_units (mall_id, floor_id, unit_code, unit_type, occupancy, area_m2)
    values (p_mall_id, p_floor_id, v_code, 'store', 'vacant', p_area_m2)
    returning * into v_unit;
    v_created := true;
  elsif p_area_m2 is not null and v_unit.area_m2 is null then
    update public.mall_units set area_m2 = p_area_m2 where id = v_unit.id;
  end if;

  begin
    insert into public.mall_branch_links
      (mall_id, mall_unit_id, branch_id, requested_by, request_source, floor_id, unit_code, area_m2, note)
    values (p_mall_id, v_unit.id, p_branch_id, auth.uid(), 'mall', p_floor_id, v_unit.unit_code,
            coalesce(p_area_m2, v_unit.area_m2), v_note)
    returning id into v_link;
  exception when unique_violation then
    raise exception 'Bu mağaza veya mağaza no için bekleyen ya da aktif bir bağlantı zaten var.';
  end;
  update public.mall_units set occupancy = 'reserved' where id = v_unit.id and occupancy = 'vacant';

  select m.name into v_mall from public.malls m where m.id = p_mall_id;
  insert into public.user_notifications (user_id, title, body, data, type)
  values (v_owner, 'AVM bağlantı talebi',
          format('%s mağazanızı %s / %s numaralı alana eklemek istiyor.', v_mall, v_floor_name, v_unit.unit_code),
          jsonb_build_object('type', 'mall_branch_link', 'link_id', v_link, 'mall_id', p_mall_id),
          'mall_branch_link');
  return jsonb_build_object('link_id', v_link, 'unit_id', v_unit.id, 'unit_created', v_created);
end;
$$;

create or replace function public.request_mall_branch_link(p_mall_id uuid, p_unit_id uuid, p_branch_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_unit public.mall_units%rowtype;
begin
  select * into v_unit from public.mall_units where id = p_unit_id and mall_id = p_mall_id;
  if v_unit.id is null then raise exception 'Mağaza alanı bulunamadı.'; end if;
  return (public.request_mall_store_link(p_mall_id, p_branch_id, v_unit.floor_id, v_unit.unit_code, null, null)
          ->> 'link_id')::uuid;
end;
$$;

-- ---------------------------------------------------------------- mağaza → AVM başvurusu
-- Kurulumdaki (draft) AVM'ler de aranır: ilk mağazalar yayından önce bağlanmalı.
create or replace function public.seller_find_malls(p_query text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_query text := btrim(coalesce(p_query, ''));
begin
  if auth.uid() is null or not exists (select 1 from public.store_branches b where b.store_id = auth.uid()) then
    raise exception 'AVM başvurusu için mağaza hesabı gerekli.' using errcode = '42501';
  end if;
  if char_length(v_query) < 2 then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(row_to_json(r)::jsonb)
    from (
      select m.id, m.name, m.city, m.district, m.logo_url, m.is_verified, m.status,
             coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'name', f.name, 'level_number', f.level_number)
                                        order by f.level_number nulls last, f.sort_order, f.name)
                       from public.mall_floors f where f.mall_id = m.id and f.is_active), '[]'::jsonb) as floors
      from public.malls m
      where m.is_verified and m.status in ('draft', 'pending_review', 'active')
        and (m.name ilike '%' || v_query || '%' or m.slug = lower(v_query))
      order by (m.status = 'active') desc, m.name
      limit 20
    ) r
  ), '[]'::jsonb);
end;
$$;

create or replace function public.apply_mall_store_link(
  p_request_id uuid, p_mall_id uuid, p_branch_id uuid, p_floor_id uuid,
  p_unit_code text, p_area_m2 numeric, p_note text, p_documents jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_code text := btrim(coalesce(p_unit_code, ''));
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_mall public.malls%rowtype;
  v_unit public.mall_units%rowtype;
  v_store text;
  v_doc jsonb;
  v_prefix text := v_uid::text || '/mall-links/' || p_request_id::text || '/';
begin
  if v_uid is null or p_request_id is null then raise exception 'Oturum gerekli.' using errcode = '42501'; end if;
  select s.business_name into v_store
  from public.store_branches b join public.stores s on s.seller_id = b.store_id
  where b.id = p_branch_id and b.store_id = v_uid and b.status = 'active';
  if v_store is null then raise exception 'Bu şube adına başvuru yetkiniz yok.' using errcode = '42501'; end if;
  select * into v_mall from public.malls where id = p_mall_id;
  if v_mall.id is null or not v_mall.is_verified or v_mall.status not in ('draft', 'pending_review', 'active') then
    raise exception 'AVM bulunamadı.';
  end if;
  if not exists (select 1 from public.mall_floors f where f.id = p_floor_id and f.mall_id = p_mall_id and f.is_active) then
    raise exception 'Kat bulunamadı.';
  end if;
  if char_length(v_code) not between 1 and 40 then raise exception 'Mağaza no gerekli (en fazla 40 karakter).'; end if;
  if p_area_m2 is not null and (p_area_m2 <= 0 or p_area_m2 > 100000) then
    raise exception 'Alan 0 ile 100000 m² arasında olmalı.';
  end if;
  if v_note is not null and char_length(v_note) > 500 then raise exception 'Not en fazla 500 karakter olabilir.'; end if;

  if jsonb_typeof(p_documents) <> 'array' or jsonb_array_length(p_documents) not between 1 and 8 then
    raise exception 'Belgeler eksik.';
  end if;
  if not exists (select 1 from jsonb_array_elements(p_documents) d
                 where d->>'type' in ('lease_contract', 'allocation_letter')) then
    raise exception 'Kira sözleşmesi veya yer tahsis belgesi zorunlu.';
  end if;
  for v_doc in select * from jsonb_array_elements(p_documents) loop
    if coalesce(v_doc->>'path', '') !~ ('^' || v_prefix || '[^/]+$') or (v_doc->>'path') ~ '\.\.'
       or not exists (select 1 from storage.objects o where o.bucket_id = 'seller-documents' and o.name = v_doc->>'path') then
      raise exception 'Belge yüklemesi doğrulanamadı.';
    end if;
  end loop;

  select * into v_unit from public.mall_units where mall_id = p_mall_id and lower(btrim(unit_code)) = lower(v_code);
  if v_unit.id is not null and v_unit.floor_id <> p_floor_id then
    raise exception 'Mağaza % bu AVM''de başka bir katta kayıtlı.', v_code;
  end if;
  if v_unit.occupancy = 'occupied' then raise exception 'Mağaza % dolu.', v_code; end if;

  begin
    insert into public.mall_branch_links
      (id, mall_id, mall_unit_id, branch_id, requested_by, request_source, floor_id, unit_code, area_m2, note)
    values (p_request_id, p_mall_id, v_unit.id, p_branch_id, v_uid, 'store', p_floor_id, v_code, p_area_m2, v_note);
  exception when unique_violation then
    raise exception 'Bu AVM''de bu mağaza veya mağaza no için bekleyen ya da aktif bir bağlantı zaten var.';
  end;
  insert into public.mall_branch_link_documents
    (link_id, document_type, storage_path, original_filename, mime_type, size_bytes, uploaded_by)
  select p_request_id, d->>'type', d->>'path', left(coalesce(nullif(d->>'name', ''), 'belge'), 200),
         coalesce(o.metadata->>'mimetype', d->>'mime'), coalesce((o.metadata->>'size')::bigint, (d->>'size')::bigint), v_uid
  from jsonb_array_elements(p_documents) d
  join storage.objects o on o.bucket_id = 'seller-documents' and o.name = d->>'path';

  insert into public.user_notifications (user_id, title, body, data, type)
  select mm.user_id, 'Yeni mağaza başvurusu', format('%s AVM''nize katılmak için başvuru yaptı.', v_store),
         jsonb_build_object('type', 'mall_branch_link', 'link_id', p_request_id, 'mall_id', p_mall_id),
         'mall_branch_link'
  from public.mall_members mm
  where mm.mall_id = p_mall_id and mm.status = 'active' and mm.role in ('mall_manager', 'mall_store_manager');
  return jsonb_build_object('link_id', p_request_id, 'mall_name', v_mall.name);
end;
$$;

-- ---------------------------------------------------------------- onay / red / bilgi iste
drop function if exists public.respond_mall_branch_link(uuid, boolean);
create or replace function public.respond_mall_branch_link(p_link_id uuid, p_approve boolean, p_note text default null)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_link public.mall_branch_links%rowtype;
  v_owner uuid;
  v_store text;
  v_mall text;
  v_unit public.mall_units%rowtype;
  v_status text := case when p_approve then 'approved' else 'rejected' end;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  select * into v_link from public.mall_branch_links where id = p_link_id for update;
  select b.store_id, s.business_name into v_owner, v_store
  from public.store_branches b join public.stores s on s.seller_id = b.store_id where b.id = v_link.branch_id;
  if v_link.id is null
     or (v_link.request_source = 'mall' and v_owner is distinct from auth.uid())
     or (v_link.request_source = 'store'
         and not public.mall_member_has_role(v_link.mall_id, array['mall_manager', 'mall_store_manager'])) then
    raise exception 'Bu talebi yanıtlama yetkiniz yok.' using errcode = '42501';
  end if;
  if v_link.status <> 'pending' then raise exception 'Bu talep artık beklemede değil.'; end if;
  if v_note is not null and char_length(v_note) > 500 then raise exception 'Not en fazla 500 karakter olabilir.'; end if;

  if p_approve then
    if v_link.mall_unit_id is null then
      select * into v_unit from public.mall_units
      where mall_id = v_link.mall_id and lower(btrim(unit_code)) = lower(btrim(v_link.unit_code)) for update;
      if v_unit.id is null then
        insert into public.mall_units (mall_id, floor_id, unit_code, unit_type, occupancy, area_m2)
        values (v_link.mall_id, v_link.floor_id, btrim(v_link.unit_code), 'store', 'occupied', v_link.area_m2)
        returning * into v_unit;
      elsif v_unit.floor_id <> v_link.floor_id or v_unit.occupancy = 'occupied' then
        raise exception 'Mağaza % artık uygun değil (dolu veya başka katta).', v_link.unit_code;
      end if;
    else
      select * into v_unit from public.mall_units where id = v_link.mall_unit_id for update;
    end if;
    begin
      update public.mall_branch_links
      set status = 'approved', mall_unit_id = v_unit.id, reviewed_at = timezone('utc', now()),
          reviewed_by = auth.uid(), review_note = coalesce(v_note, review_note)
      where id = p_link_id;
    exception when unique_violation then
      raise exception 'Mağaza % için başka bir aktif bağlantı var.', v_unit.unit_code;
    end;
    update public.mall_units
    set occupancy = 'occupied', area_m2 = coalesce(area_m2, v_link.area_m2)
    where id = v_unit.id;
  else
    update public.mall_branch_links
    set status = 'rejected', reviewed_at = timezone('utc', now()), reviewed_by = auth.uid(),
        review_note = coalesce(v_note, review_note)
    where id = p_link_id;
    update public.mall_units set occupancy = 'vacant'
    where id = v_link.mall_unit_id and occupancy = 'reserved';
  end if;

  select m.name into v_mall from public.malls m where m.id = v_link.mall_id;
  if v_link.requested_by is not null then
    insert into public.user_notifications (user_id, title, body, data, type)
    values (
      v_link.requested_by,
      case when v_link.request_source = 'store' then 'AVM başvurunuz' else 'AVM bağlantı yanıtı' end,
      case when v_link.request_source = 'store'
        then format('%s başvurunuzu %s.', v_mall, case when p_approve then 'onayladı' else 'reddetti' end)
        else format('%s bağlantı talebinizi %s.', v_store, case when p_approve then 'onayladı' else 'reddetti' end)
      end,
      jsonb_build_object('type', 'mall_branch_link', 'link_id', p_link_id, 'mall_id', v_link.mall_id),
      'mall_branch_link');
  end if;
  return v_status;
end;
$$;

create or replace function public.request_mall_link_info(p_link_id uuid, p_message text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_link public.mall_branch_links%rowtype;
  v_msg text := btrim(coalesce(p_message, ''));
  v_mall text;
begin
  select * into v_link from public.mall_branch_links where id = p_link_id for update;
  if v_link.id is null or v_link.request_source <> 'store'
     or not public.mall_member_has_role(v_link.mall_id, array['mall_manager', 'mall_store_manager']) then
    raise exception 'Bu başvuru için bilgi isteme yetkiniz yok.' using errcode = '42501';
  end if;
  if v_link.status <> 'pending' then raise exception 'Bu başvuru artık beklemede değil.'; end if;
  if char_length(v_msg) not between 3 and 500 then raise exception 'Mesaj 3-500 karakter olmalı.'; end if;
  update public.mall_branch_links set review_note = v_msg where id = p_link_id;
  select m.name into v_mall from public.malls m where m.id = v_link.mall_id;
  insert into public.user_notifications (user_id, title, body, data, type)
  values (v_link.requested_by, 'AVM ek bilgi istiyor', format('%s: %s', v_mall, v_msg),
          jsonb_build_object('type', 'mall_branch_link', 'link_id', p_link_id, 'mall_id', v_link.mall_id),
          'mall_branch_link');
end;
$$;

-- ---------------------------------------------------------------- listeler
create or replace function public.mall_link_rows(p_mall_id uuid, p_owner uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(row_to_json(r)::jsonb order by r.requested_at desc), '[]'::jsonb)
  from (
    select l.id, l.status, l.request_source, l.requested_at, l.reviewed_at, l.note, l.review_note,
           l.mall_unit_id, coalesce(u.unit_code, l.unit_code) as unit_code, coalesce(u.area_m2, l.area_m2) as area_m2,
           f.id as floor_id, f.name as floor_name, f.level_number,
           m.id as mall_id, m.name as mall_name, m.city as mall_city, m.district as mall_district, m.logo_url as mall_logo_url,
           b.id as branch_id, b.branch_code, b.name as branch_name, b.city, b.district,
           s.seller_id as store_id, s.business_name as store_name, s.category, s.logo_url,
           coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'type', d.document_type, 'path', d.storage_path,
                                                         'name', d.original_filename, 'mime', d.mime_type, 'size', d.size_bytes)
                                      order by d.created_at)
                     from public.mall_branch_link_documents d where d.link_id = l.id), '[]'::jsonb) as documents
    from public.mall_branch_links l
    left join public.mall_units u on u.id = l.mall_unit_id
    join public.mall_floors f on f.id = coalesce(u.floor_id, l.floor_id)
    join public.malls m on m.id = l.mall_id
    join public.store_branches b on b.id = l.branch_id
    join public.stores s on s.seller_id = b.store_id
    where l.status in ('pending', 'approved', 'rejected')
      and (p_mall_id is null or l.mall_id = p_mall_id)
      and (p_owner is null or b.store_id = p_owner)
  ) r
$$;
revoke all on function public.mall_link_rows(uuid, uuid) from public, anon, authenticated;

create or replace function public.mall_store_links(p_mall_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.mall_management_assert_role(p_mall_id, public.mall_any_role());
  return public.mall_link_rows(p_mall_id, null);
end;
$$;

create or replace function public.seller_mall_link_requests()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select case when auth.uid() is null then '[]'::jsonb else public.mall_link_rows(null, auth.uid()) end
$$;

-- Harita: aktif AVM + onaylı mağaza sayısı.
create or replace function public.public_mall_map_pins()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(row_to_json(r)::jsonb), '[]'::jsonb)
  from (
    select m.id, m.name, m.slug, m.city, m.district, m.logo_url, m.opening_hours, m.latitude, m.longitude,
           (select count(*) from public.mall_branch_links l where l.mall_id = m.id and l.status = 'approved') as store_count
    from public.malls m
    where m.status = 'active' and m.latitude is not null and m.longitude is not null
    limit 500
  ) r
$$;

do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'public.request_mall_store_link(uuid, uuid, uuid, text, numeric, text)',
    'public.request_mall_branch_link(uuid, uuid, uuid)',
    'public.seller_find_malls(text)',
    'public.apply_mall_store_link(uuid, uuid, uuid, uuid, text, numeric, text, jsonb)',
    'public.respond_mall_branch_link(uuid, boolean, text)',
    'public.request_mall_link_info(uuid, text)',
    'public.mall_store_links(uuid)',
    'public.seller_mall_link_requests()',
    'public.mall_link_document_readable(uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated', v_fn);
  end loop;
  revoke all on function public.public_mall_map_pins() from public;
  grant execute on function public.public_mall_map_pins() to anon, authenticated;
end $$;

commit;
