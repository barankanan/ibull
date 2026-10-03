-- Konum değişikliği onayı + satıcı konum kartı + AVM içi yer düzenleme.
-- Önce mall_store_location_architecture.sql. Geri alma: mall_store_location_rollback.sql.
-- Yeni bağımsız konum doğrudan yayınlanmaz: satıcı talep eder, admin onaylar, sonra pin geri gelir.
begin;

alter table public.store_location_change_requests add column if not exists requested_city text;
alter table public.store_location_change_requests add column if not exists requested_district text;
alter table public.store_location_change_requests add column if not exists requested_address text;

-- Eski politikalar her authenticated kullanıcıya tüm talepleri okuma/güncelleme veriyordu (qual = true).
drop policy if exists store_location_change_requests_admin_select_all on public.store_location_change_requests;
drop policy if exists store_location_change_requests_admin_update_all on public.store_location_change_requests;
drop policy if exists store_location_change_requests_admin_select on public.store_location_change_requests;
drop policy if exists store_location_change_requests_admin_update on public.store_location_change_requests;
create policy store_location_change_requests_admin_select on public.store_location_change_requests
  for select to authenticated using (public.is_admin_user());
create policy store_location_change_requests_admin_update on public.store_location_change_requests
  for update to authenticated using (public.is_admin_user()) with check (public.is_admin_user());

-- ---------------------------------------------------------------- satıcı: konum kartı
create or replace function public.seller_store_location()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_branch public.store_branches%rowtype;
  v_store public.stores%rowtype;
begin
  if v_uid is null then raise exception 'Oturum gerekli.' using errcode = '42501'; end if;
  select * into v_branch from public.store_branches where store_id = v_uid order by is_primary desc, created_at limit 1;
  if v_branch.id is null then return null; end if;
  select * into v_store from public.stores where seller_id = v_uid;
  return jsonb_build_object(
    'branch_id', v_branch.id,
    'branch_name', coalesce(v_branch.name, v_store.business_name),
    'location_type', v_branch.location_type,
    'city', coalesce(v_store.city, v_branch.city),
    'district', coalesce(v_store.district, v_branch.district),
    'address', coalesce(v_store.address, v_branch.address_text),
    'link', (
      select jsonb_build_object('id', l.id, 'status', l.status, 'request_source', l.request_source,
                                'mall_id', m.id, 'mall_name', m.name, 'mall_city', m.city, 'mall_district', m.district,
                                'floor_name', f.name, 'level_number', f.level_number,
                                'unit_code', coalesce(u.unit_code, l.unit_code), 'review_note', l.review_note)
      from public.mall_branch_links l
      join public.malls m on m.id = l.mall_id
      left join public.mall_units u on u.id = l.mall_unit_id
      left join public.mall_floors f on f.id = coalesce(u.floor_id, l.floor_id)
      where l.branch_id = v_branch.id
      order by (l.status = 'approved') desc, (l.status = 'pending') desc, l.updated_at desc
      limit 1),
    'pending_change', (
      select jsonb_build_object('id', r.id, 'city', coalesce(r.requested_city, r.city),
                                'district', coalesce(r.requested_district, r.district),
                                'address', coalesce(r.requested_address, r.address), 'created_at', r.created_at)
      from public.store_location_change_requests r
      where r.seller_id = v_uid and r.status = 'pending'
      order by r.created_at desc
      limit 1)
  );
end;
$$;

-- ---------------------------------------------------------------- satıcı: yeni bağımsız konum talebi
create or replace function public.submit_store_location_change(
  p_city text, p_district text, p_address text, p_latitude double precision, p_longitude double precision
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_store public.stores%rowtype;
  v_branch uuid;
  v_id uuid;
  v_city text := btrim(coalesce(p_city, ''));
  v_district text := btrim(coalesce(p_district, ''));
  v_address text := btrim(coalesce(p_address, ''));
begin
  if v_uid is null then raise exception 'Oturum gerekli.' using errcode = '42501'; end if;
  select * into v_store from public.stores where seller_id = v_uid;
  if v_store.seller_id is null then raise exception 'Mağaza profili bulunamadı.' using errcode = '42501'; end if;
  select id into v_branch from public.store_branches where store_id = v_uid order by is_primary desc, created_at limit 1;
  if exists (select 1 from public.mall_branch_links l where l.branch_id = v_branch and l.status = 'approved') then
    raise exception 'Mağazanız bir AVM içinde. Önce AVM bağlantısını sonlandırın.';
  end if;
  if char_length(v_city) not between 2 and 80 or char_length(v_district) not between 2 and 80 then
    raise exception 'Şehir ve ilçe gerekli.';
  end if;
  if char_length(v_address) not between 5 and 300 then raise exception 'Açık adres 5-300 karakter olmalı.'; end if;
  if p_latitude is null or p_longitude is null or p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception 'Haritadan konum seçin.';
  end if;

  delete from public.store_location_change_requests where seller_id = v_uid and status = 'pending';
  insert into public.store_location_change_requests
    (seller_id, business_name, address, city, district, current_lat, current_lng, requested_lat, requested_lng,
     requested_city, requested_district, requested_address, status, created_at)
  values (v_uid, v_store.business_name, v_store.address, v_store.city, v_store.district, v_store.store_lat, v_store.store_lng,
          p_latitude, p_longitude, v_city, v_district, v_address, 'pending', timezone('utc', now()))
  returning id into v_id;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------- admin: konum onayı
create or replace function public.admin_review_store_location_change(p_request_id uuid, p_approve boolean, p_note text default null)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req public.store_location_change_requests%rowtype;
  v_branch uuid;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if not public.is_admin_user(auth.uid()) then raise exception 'Bu işlem için admin yetkisi gerekli.' using errcode = '42501'; end if;
  select * into v_req from public.store_location_change_requests where id = p_request_id for update;
  if v_req.id is null or v_req.status <> 'pending' then raise exception 'Bekleyen konum talebi bulunamadı.'; end if;
  select id into v_branch from public.store_branches where store_id = v_req.seller_id order by is_primary desc, created_at limit 1;

  if not p_approve then
    update public.store_location_change_requests
    set status = 'rejected', rejected_at = timezone('utc', now()), admin_note = coalesce(v_note, 'Admin tarafından reddedildi')
    where id = p_request_id;
  else
    if exists (select 1 from public.mall_branch_links l where l.branch_id = v_branch and l.status = 'approved') then
      raise exception 'Mağaza bir AVM içinde; bağımsız konum onaylanamaz.';
    end if;
    update public.stores
    set store_lat = v_req.requested_lat, store_lng = v_req.requested_lng,
        city = coalesce(v_req.requested_city, city), district = coalesce(v_req.requested_district, district),
        address = coalesce(v_req.requested_address, address), updated_at = timezone('utc', now())
    where seller_id = v_req.seller_id;
    update public.store_branches
    set latitude = v_req.requested_lat, longitude = v_req.requested_lng,
        city = coalesce(v_req.requested_city, city), district = coalesce(v_req.requested_district, district),
        address_text = coalesce(v_req.requested_address, address_text), location_type = 'standalone'
    where id = v_branch;
    update public.store_location_change_requests
    set status = 'approved', approved_at = timezone('utc', now()), admin_note = v_note
    where id = p_request_id;
  end if;

  insert into public.user_notifications (user_id, title, body, data, type)
  values (v_req.seller_id, 'Konum talebiniz',
          case when p_approve then 'Yeni mağaza konumunuz onaylandı; mağazanız haritada yeniden görünüyor.'
               else format('Konum talebiniz reddedildi.%s', coalesce(' Not: ' || v_note, '')) end,
          jsonb_build_object('type', 'store_location_change', 'request_id', p_request_id), 'store_location_change');
  return case when p_approve then 'approved' else 'rejected' end;
end;
$$;

-- ---------------------------------------------------------------- AVM: aktif mağazanın katını / numarasını düzenle
create or replace function public.update_mall_store_link_place(
  p_link_id uuid, p_floor_id uuid, p_unit_code text, p_area_m2 numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_link public.mall_branch_links%rowtype;
  v_unit public.mall_units%rowtype;
  v_code text := btrim(coalesce(p_unit_code, ''));
  v_owner uuid;
  v_mall text;
  v_floor text;
begin
  select * into v_link from public.mall_branch_links where id = p_link_id for update;
  if v_link.id is null or not public.mall_member_has_role(v_link.mall_id, array['mall_manager', 'mall_store_manager']) then
    raise exception 'Bu mağazayı düzenleme yetkiniz yok.' using errcode = '42501';
  end if;
  if v_link.status <> 'approved' then raise exception 'Yalnız aktif mağazanın yeri düzenlenebilir.'; end if;
  select f.name into v_floor from public.mall_floors f where f.id = p_floor_id and f.mall_id = v_link.mall_id and f.is_active;
  if v_floor is null then raise exception 'Kat bulunamadı.'; end if;
  if char_length(v_code) not between 1 and 40 then raise exception 'Mağaza no gerekli (en fazla 40 karakter).'; end if;
  if p_area_m2 is not null and (p_area_m2 <= 0 or p_area_m2 > 100000) then
    raise exception 'Alan 0 ile 100000 m² arasında olmalı.';
  end if;

  select * into v_unit from public.mall_units
  where mall_id = v_link.mall_id and lower(btrim(unit_code)) = lower(v_code) for update;
  if v_unit.id is null then
    insert into public.mall_units (mall_id, floor_id, unit_code, unit_type, occupancy, area_m2)
    values (v_link.mall_id, p_floor_id, v_code, 'store', 'occupied', p_area_m2)
    returning * into v_unit;
  elsif v_unit.id <> v_link.mall_unit_id then
    if v_unit.floor_id <> p_floor_id then raise exception 'Mağaza % bu AVM''de başka bir katta kayıtlı.', v_code; end if;
    if v_unit.occupancy = 'occupied' then raise exception 'Mağaza % dolu.', v_code; end if;
  elsif v_unit.floor_id <> p_floor_id then
    update public.mall_units set floor_id = p_floor_id where id = v_unit.id;
  end if;

  begin
    update public.mall_branch_links
    set mall_unit_id = v_unit.id, floor_id = p_floor_id, unit_code = v_unit.unit_code, area_m2 = p_area_m2
    where id = p_link_id;
  exception when unique_violation then
    raise exception 'Mağaza % için başka bir açık bağlantı var.', v_code;
  end;
  update public.mall_units set occupancy = 'occupied', area_m2 = coalesce(p_area_m2, area_m2) where id = v_unit.id;
  if v_link.mall_unit_id is distinct from v_unit.id then
    update public.mall_units set occupancy = 'vacant' where id = v_link.mall_unit_id;
  end if;

  select b.store_id into v_owner from public.store_branches b where b.id = v_link.branch_id;
  select m.name into v_mall from public.malls m where m.id = v_link.mall_id;
  insert into public.user_notifications (user_id, title, body, data, type)
  values (v_owner, 'AVM konumunuz güncellendi',
          format('%s mağazanızın yerini %s / %s olarak güncelledi.', v_mall, v_floor, v_unit.unit_code),
          jsonb_build_object('type', 'mall_branch_link', 'link_id', p_link_id, 'mall_id', v_link.mall_id), 'mall_branch_link');
  return jsonb_build_object('unit_id', v_unit.id, 'unit_code', v_unit.unit_code, 'floor_name', v_floor);
end;
$$;

revoke all on function public.seller_store_location() from public;
revoke all on function public.submit_store_location_change(text, text, text, double precision, double precision) from public;
revoke all on function public.admin_review_store_location_change(uuid, boolean, text) from public;
revoke all on function public.update_mall_store_link_place(uuid, uuid, text, numeric) from public;
grant execute on function public.seller_store_location() to authenticated;
grant execute on function public.submit_store_location_change(text, text, text, double precision, double precision) to authenticated;
grant execute on function public.admin_review_store_location_change(uuid, boolean, text) to authenticated;
grant execute on function public.update_mall_store_link_place(uuid, uuid, text, numeric) to authenticated;

commit;
