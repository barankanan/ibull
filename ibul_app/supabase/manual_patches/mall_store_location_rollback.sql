-- mall_store_location_architecture.sql + store_location_change_moderation.sql geri alma.
-- AVM bağlantıları (mall_branch_links) ve konum talepleri korunur; yalnız yeni kolon/tetik/fonksiyonlar kaldırılır.
-- Not: eski "admin_*_all" politikaları qual = true idi; geri alma bu açık durumu da geri getirir.
begin;

drop function if exists public.update_mall_store_link_place(uuid, uuid, text, numeric);
drop function if exists public.admin_review_store_location_change(uuid, boolean, text);
drop function if exists public.submit_store_location_change(text, text, text, double precision, double precision);
drop function if exists public.seller_store_location();

drop policy if exists store_location_change_requests_admin_select on public.store_location_change_requests;
drop policy if exists store_location_change_requests_admin_update on public.store_location_change_requests;
drop policy if exists store_location_change_requests_admin_select_all on public.store_location_change_requests;
drop policy if exists store_location_change_requests_admin_update_all on public.store_location_change_requests;
create policy store_location_change_requests_admin_select_all on public.store_location_change_requests
  for select to authenticated using (true);
create policy store_location_change_requests_admin_update_all on public.store_location_change_requests
  for update to authenticated using (true) with check (true);
alter table public.store_location_change_requests drop column if exists requested_address;
alter table public.store_location_change_requests drop column if exists requested_district;
alter table public.store_location_change_requests drop column if exists requested_city;

drop function if exists public.public_map_hidden_store_ids();
drop function if exists public.public_mall_store_directory();
drop function if exists public.public_find_malls(text);

drop trigger if exists seller_applications_apply_mall_placement on public.seller_applications;
drop function if exists public.seller_applications_apply_mall_placement();
alter table public.seller_applications drop constraint if exists seller_applications_mall_placement_shape;
alter table public.seller_applications drop column if exists mall_placement;

drop trigger if exists mall_branch_links_sync_location on public.mall_branch_links;
drop function if exists public.mall_branch_links_sync_location();
drop trigger if exists store_branches_guard_location_type on public.store_branches;
drop function if exists public.store_branches_guard_location_type();
alter table public.store_branches drop constraint if exists store_branches_location_type_check;
alter table public.store_branches drop column if exists location_type;

-- apply_mall_store_link: mall_store_link_system.sql sürümü.
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
drop function if exists public.mall_store_link_application_core(uuid, uuid, uuid, uuid, uuid, text, numeric, text, jsonb);
grant execute on function public.apply_mall_store_link(uuid, uuid, uuid, uuid, text, numeric, text, jsonb) to authenticated;

commit;
