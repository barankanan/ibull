-- AVM mağaza akışı + yayın süreci + public AVM detayı.
-- Önkoşul: 20261009_mall_management_v2_patch.sql ve _ops_patch.sql. SQL Editor'da uygulanır; db push yok.
-- Mevcut veri değişmez: yalnız fonksiyonlar yenilenir, mall_branch_links'e nullable "note" eklenir,
-- yeni mall_publication_requests tablosu açılır.

begin;

-- ---------------------------------------------------------------- search
-- Haritada görünen her aktif şube AVM aramasında da bulunur (silme talebi haritayı gizlemiyor).
create or replace function public.mall_find_store_branches(p_mall_id uuid, p_query text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_query text := btrim(coalesce(p_query, ''));
  v_code text := upper(replace(btrim(coalesce(p_query, '')), ' ', ''));
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager', 'mall_store_manager']);
  if char_length(v_query) < 2 then
    return '[]'::jsonb;
  end if;
  if v_code ~ '^IBL[A-Z0-9]{6}$' then
    v_code := 'IBL-' || substr(v_code, 4);
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(r)::jsonb)
    from (
      select b.id as branch_id, b.branch_code, b.name as branch_name, b.city, b.district,
             s.seller_id as store_id, s.business_name as store_name, s.category, s.logo_url,
             coalesce(s.is_verified, false) as is_verified,
             (select l.status from public.mall_branch_links l
               where l.mall_id = p_mall_id and l.branch_id = b.id and l.status in ('pending', 'approved')
               limit 1) as link_status
      from public.store_branches b
      join public.stores s on s.seller_id = b.store_id
      where b.status = 'active'
        and (
          (v_code ~ '^IBL-[A-Z0-9]{6}$' and b.branch_code = v_code)
          or (v_code !~ '^IBL-' and (s.business_name ilike '%' || v_query || '%'
                                     or b.name ilike '%' || v_query || '%'
                                     or s.category ilike '%' || v_query || '%'))
        )
      order by s.is_verified desc nulls last, s.business_name
      limit 20
    ) r
  ), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------- link request
alter table public.mall_branch_links add column if not exists note text;
alter table public.mall_branch_links drop constraint if exists mall_branch_links_note_len;
alter table public.mall_branch_links
  add constraint mall_branch_links_note_len check (note is null or char_length(note) <= 500);

create or replace function public.request_mall_branch_link(p_mall_id uuid, p_unit_id uuid, p_branch_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_unit public.mall_units%rowtype;
  v_owner uuid;
  v_mall text;
  v_floor text;
  v_id uuid;
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager', 'mall_store_manager']);
  select * into v_unit from public.mall_units where id = p_unit_id and mall_id = p_mall_id for update;
  if v_unit.id is null then
    raise exception 'Mağaza alanı bulunamadı.';
  end if;
  if v_unit.occupancy = 'occupied' then
    raise exception 'Mağaza % dolu. Önce mevcut bağlantıyı kaldırın.', v_unit.unit_code;
  end if;
  select b.store_id into v_owner from public.store_branches b where b.id = p_branch_id and b.status = 'active';
  if v_owner is null then
    raise exception 'Mağaza bulunamadı.';
  end if;
  begin
    insert into public.mall_branch_links (mall_id, mall_unit_id, branch_id, requested_by)
    values (p_mall_id, p_unit_id, p_branch_id, auth.uid())
    returning id into v_id;
  exception when unique_violation then
    raise exception 'Bu mağaza veya mağaza no için bekleyen ya da aktif bir bağlantı zaten var.';
  end;
  update public.mall_units set occupancy = 'reserved' where id = p_unit_id and occupancy = 'vacant';
  select m.name into v_mall from public.malls m where m.id = p_mall_id;
  select f.name into v_floor from public.mall_floors f where f.id = v_unit.floor_id;
  insert into public.user_notifications (user_id, title, body, data, type)
  values (
    v_owner,
    'AVM bağlantı talebi',
    format('%s mağazanızı %s / Mağaza %s alanına bağlamak istiyor.', v_mall, v_floor, v_unit.unit_code),
    jsonb_build_object('type', 'mall_branch_link', 'link_id', v_id, 'mall_id', p_mall_id),
    'mall_branch_link'
  );
  return v_id;
end;
$$;

-- Kat + mağaza no ile bağlantı: alan yoksa otomatik oluşturulur (type=store), talep onunla açılır.
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
  v_created boolean := false;
  v_link uuid;
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager', 'mall_store_manager']);
  select f.name into v_floor_name from public.mall_floors f where f.id = p_floor_id and f.mall_id = p_mall_id;
  if v_floor_name is null then
    raise exception 'Kat bulunamadı.';
  end if;
  if char_length(v_code) not between 1 and 40 then
    raise exception 'Mağaza no gerekli (en fazla 40 karakter).';
  end if;
  if p_area_m2 is not null and (p_area_m2 <= 0 or p_area_m2 > 100000) then
    raise exception 'Alan 0 ile 100000 m² arasında olmalı.';
  end if;
  if v_note is not null and char_length(v_note) > 500 then
    raise exception 'Not en fazla 500 karakter olabilir.';
  end if;

  select * into v_unit from public.mall_units
  where mall_id = p_mall_id and lower(btrim(unit_code)) = lower(v_code)
  for update;
  if v_unit.id is not null and v_unit.floor_id <> p_floor_id then
    select f.name into v_floor_name from public.mall_floors f where f.id = v_unit.floor_id;
    raise exception 'Mağaza % başka bir katta kayıtlı (%).', v_code, v_floor_name;
  end if;
  if v_unit.id is null then
    insert into public.mall_units (mall_id, floor_id, unit_code, unit_type, occupancy, area_m2)
    values (p_mall_id, p_floor_id, v_code, 'store', 'vacant', p_area_m2)
    returning * into v_unit;
    v_created := true;
  elsif p_area_m2 is not null and v_unit.area_m2 is null then
    update public.mall_units set area_m2 = p_area_m2 where id = v_unit.id;
  end if;

  v_link := public.request_mall_branch_link(p_mall_id, v_unit.id, p_branch_id);
  if v_note is not null then
    update public.mall_branch_links set note = v_note where id = v_link;
  end if;
  return jsonb_build_object('link_id', v_link, 'unit_id', v_unit.id, 'unit_created', v_created);
end;
$$;

create or replace function public.mall_store_links(p_mall_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.mall_management_assert_role(p_mall_id, public.mall_any_role());
  return coalesce((
    select jsonb_agg(row_to_json(r)::jsonb order by r.requested_at desc)
    from (
      select l.id, l.status, l.requested_at, l.reviewed_at, l.note, l.mall_unit_id, u.unit_code, u.area_m2,
             u.floor_id, f.name as floor_name, f.level_number, b.id as branch_id, b.branch_code,
             b.name as branch_name, b.city, b.district,
             s.seller_id as store_id, s.business_name as store_name, s.category, s.logo_url
      from public.mall_branch_links l
      join public.mall_units u on u.id = l.mall_unit_id
      join public.mall_floors f on f.id = u.floor_id
      join public.store_branches b on b.id = l.branch_id
      join public.stores s on s.seller_id = b.store_id
      where l.mall_id = p_mall_id and l.status in ('pending', 'approved', 'rejected')
    ) r
  ), '[]'::jsonb);
end;
$$;

create or replace function public.seller_mall_link_requests()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(row_to_json(r)::jsonb order by r.requested_at desc), '[]'::jsonb)
  from (
    select l.id, l.status, l.requested_at, l.reviewed_at, l.note, m.id as mall_id, m.name as mall_name,
           m.city, m.district, m.logo_url, f.name as floor_name, f.level_number, u.unit_code, u.area_m2,
           b.branch_code
    from public.mall_branch_links l
    join public.store_branches b on b.id = l.branch_id
    join public.malls m on m.id = l.mall_id
    join public.mall_units u on u.id = l.mall_unit_id
    join public.mall_floors f on f.id = u.floor_id
    where b.store_id = auth.uid() and l.status in ('pending', 'approved', 'rejected')
  ) r
$$;

-- ---------------------------------------------------------------- setup summary (dashboard tek kaynak)
create or replace function public.mall_publication_missing(p_mall_id uuid)
returns text[]
language sql
stable
security definer
set search_path = public
as $$
  select array_remove(array[
    case when btrim(coalesce(m.name, '')) = '' or btrim(coalesce(m.city, '')) = ''
              or btrim(coalesce(m.address_text, '')) = '' then 'profile' end,
    case when btrim(coalesce(m.opening_hours, '')) = '' then 'hours' end,
    case when not exists (select 1 from public.mall_floors f where f.mall_id = m.id) then 'floor' end,
    case when not exists (select 1 from public.mall_branch_links l
                          where l.mall_id = m.id and l.status = 'approved') then 'store' end
  ], null)
  from public.malls m
  where m.id = p_mall_id
$$;

create table if not exists public.mall_publication_requests (
  id uuid primary key default gen_random_uuid(),
  mall_id uuid not null references public.malls (id) on delete cascade,
  status text not null default 'pending',
  requested_by uuid,
  requested_at timestamptz not null default timezone('utc', now()),
  reviewed_by uuid,
  reviewed_at timestamptz,
  admin_note text,
  constraint mall_publication_requests_status_check
    check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  constraint mall_publication_requests_note_len check (admin_note is null or char_length(admin_note) <= 1000)
);

create unique index if not exists mall_publication_requests_open_unique
  on public.mall_publication_requests (mall_id) where status = 'pending';
create index if not exists idx_mall_publication_requests_mall
  on public.mall_publication_requests (mall_id, requested_at desc);

alter table public.mall_publication_requests enable row level security;
revoke all on table public.mall_publication_requests from public, anon, authenticated;

create or replace function public.mall_setup_summary(p_mall_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_mall public.malls%rowtype;
begin
  perform public.mall_management_assert_role(p_mall_id, public.mall_any_role());
  select * into v_mall from public.malls where id = p_mall_id;
  return jsonb_build_object(
    'status', v_mall.status,
    'is_verified', coalesce(v_mall.is_verified, false),
    'floor_count', (select count(*) from public.mall_floors where mall_id = p_mall_id),
    'unit_count', (select count(*) from public.mall_units where mall_id = p_mall_id),
    'vacant_unit_count', (select count(*) from public.mall_units where mall_id = p_mall_id and occupancy = 'vacant'),
    'active_store_count', (select count(*) from public.mall_branch_links where mall_id = p_mall_id and status = 'approved'),
    'pending_request_count', (select count(*) from public.mall_branch_links where mall_id = p_mall_id and status = 'pending'),
    'floor_plan_count', (select count(*) from public.mall_floors where mall_id = p_mall_id and plan_url is not null),
    'profile_ready', btrim(coalesce(v_mall.name, '')) <> '' and btrim(coalesce(v_mall.city, '')) <> ''
                     and btrim(coalesce(v_mall.address_text, '')) <> '',
    'media_ready', v_mall.logo_url is not null and v_mall.cover_url is not null,
    'hours_ready', btrim(coalesce(v_mall.opening_hours, '')) <> '',
    'missing', to_jsonb(public.mall_publication_missing(p_mall_id)),
    'publication', (
      select jsonb_build_object('status', r.status, 'requested_at', r.requested_at,
                                'reviewed_at', r.reviewed_at, 'admin_note', r.admin_note)
      from public.mall_publication_requests r
      where r.mall_id = p_mall_id
      order by r.requested_at desc
      limit 1
    )
  );
end;
$$;

-- ---------------------------------------------------------------- publication lifecycle
-- draft --(yönetici: Yayına Gönder)--> pending_review --(admin onay)--> active
--                                                    \--(admin red)--> draft
create or replace function public.request_mall_publication(p_mall_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mall public.malls%rowtype;
  v_missing text[];
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager']);
  select * into v_mall from public.malls where id = p_mall_id for update;
  if v_mall.status = 'active' then
    raise exception 'AVM zaten yayında.';
  elsif v_mall.status = 'pending_review' then
    raise exception 'Yayın talebiniz İBUL ekibi tarafından inceleniyor.';
  elsif v_mall.status <> 'draft' then
    raise exception 'Bu AVM şu an yayına gönderilemez (durum: %).', v_mall.status;
  end if;
  if not coalesce(v_mall.is_verified, false) then
    raise exception 'AVM doğrulanmadan yayına gönderilemez.';
  end if;
  v_missing := public.mall_publication_missing(p_mall_id);
  if cardinality(v_missing) > 0 then
    raise exception 'Yayın için eksik adımlar var: %.', array_to_string(v_missing, ', ');
  end if;
  insert into public.mall_publication_requests (mall_id, requested_by) values (p_mall_id, auth.uid());
  update public.malls set status = 'pending_review' where id = p_mall_id;
  return public.mall_setup_summary(p_mall_id);
end;
$$;

create or replace function public.cancel_mall_publication(p_mall_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager']);
  update public.mall_publication_requests set status = 'cancelled', reviewed_at = timezone('utc', now()),
    reviewed_by = auth.uid()
  where mall_id = p_mall_id and status = 'pending';
  update public.malls set status = 'draft' where id = p_mall_id and status = 'pending_review';
  if not found then
    raise exception 'Bekleyen yayın talebi yok.';
  end if;
  return public.mall_setup_summary(p_mall_id);
end;
$$;

create or replace function public.admin_mall_publication_queue()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'Bu işlem için yetkiniz yok.' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(q)::jsonb order by q.requested_at)
    from (
      select r.id, r.mall_id, r.requested_at, m.name as mall_name, m.city, m.district, m.logo_url, m.cover_url,
             m.opening_hours, m.latitude, m.longitude, u.email as requested_by_email,
             (select count(*) from public.mall_floors f where f.mall_id = m.id) as floor_count,
             (select count(*) from public.mall_branch_links l where l.mall_id = m.id and l.status = 'approved') as store_count
      from public.mall_publication_requests r
      join public.malls m on m.id = r.mall_id
      left join public.users u on u.id = r.requested_by
      where r.status = 'pending' and m.status = 'pending_review'
    ) q
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_review_mall_publication(p_mall_id uuid, p_approve boolean, p_note text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_status text;
  v_request public.mall_publication_requests%rowtype;
  v_name text;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'Bu işlem için yetkiniz yok.' using errcode = '42501';
  end if;
  if not p_approve and v_note is null then
    raise exception 'Red nedeni yazın.';
  end if;
  select * into v_request from public.mall_publication_requests
  where mall_id = p_mall_id and status = 'pending' for update;
  update public.malls set status = case when p_approve then 'active' else 'draft' end
  where id = p_mall_id and status = 'pending_review'
  returning status, name into v_status, v_name;
  if v_status is null then
    raise exception 'Bu AVM için bekleyen yayın talebi yok.';
  end if;
  update public.mall_publication_requests
  set status = case when p_approve then 'approved' else 'rejected' end,
      reviewed_by = auth.uid(), reviewed_at = timezone('utc', now()), admin_note = v_note
  where id = v_request.id;
  if v_request.requested_by is not null then
    insert into public.user_notifications (user_id, title, body, data, type)
    values (
      v_request.requested_by,
      case when p_approve then 'AVM yayında' else 'AVM yayın talebi reddedildi' end,
      case when p_approve then format('%s artık İBUL haritasında görünüyor.', v_name)
           else format('%s yayına alınmadı: %s', v_name, v_note) end,
      jsonb_build_object('type', 'mall_publication', 'mall_id', p_mall_id),
      'mall_publication'
    );
  end if;
  return v_status;
end;
$$;

-- ---------------------------------------------------------------- public detail
-- Aktif AVM herkese açık; taslak yalnız AVM yetkilisi ve admin için önizleme.
create or replace function public.public_mall_detail(p_mall_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_mall public.malls%rowtype;
  v_preview boolean;
begin
  select * into v_mall from public.malls where id = p_mall_id;
  if v_mall.id is null then
    return null;
  end if;
  v_preview := v_mall.status <> 'active';
  if v_preview and not (public.mall_member_has_role(p_mall_id, public.mall_any_role())
                        or public.is_admin_user(auth.uid())) then
    return null;
  end if;
  return jsonb_build_object(
    'preview', v_preview,
    'mall', jsonb_build_object(
      'id', v_mall.id, 'name', v_mall.name, 'slug', v_mall.slug, 'status', v_mall.status,
      'city', v_mall.city, 'district', v_mall.district, 'address_text', v_mall.address_text,
      'phone', v_mall.phone, 'website', v_mall.website, 'opening_hours', v_mall.opening_hours,
      'logo_url', v_mall.logo_url, 'cover_url', v_mall.cover_url,
      'latitude', v_mall.latitude, 'longitude', v_mall.longitude, 'is_verified', v_mall.is_verified),
    'floors', coalesce((
      select jsonb_agg(jsonb_build_object('id', f.id, 'name', f.name, 'level_number', f.level_number,
                                          'sort_order', f.sort_order, 'plan_url', f.plan_url)
                       order by f.level_number nulls last, f.sort_order, f.name)
      from public.mall_floors f where f.mall_id = p_mall_id and f.is_active
    ), '[]'::jsonb),
    'stores', coalesce((
      select jsonb_agg(jsonb_build_object('unit_code', u.unit_code, 'floor_id', u.floor_id,
                                          'map_x', u.map_x, 'map_y', u.map_y, 'store_id', s.seller_id,
                                          'store_name', s.business_name, 'category', s.category,
                                          'logo_url', s.logo_url)
                       order by u.unit_code)
      from public.mall_branch_links l
      join public.mall_units u on u.id = l.mall_unit_id
      join public.store_branches b on b.id = l.branch_id
      join public.stores s on s.seller_id = b.store_id
      where l.mall_id = p_mall_id and l.status = 'approved'
    ), '[]'::jsonb),
    'campaigns', coalesce((
      select jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title, 'description', c.description,
                                          'image_url', c.image_url, 'starts_at', c.starts_at, 'ends_at', c.ends_at)
                       order by c.starts_at desc)
      from public.mall_campaigns c
      where c.mall_id = p_mall_id and c.status = 'published' and c.ends_at > timezone('utc', now())
    ), '[]'::jsonb)
  );
end;
$$;

-- ---------------------------------------------------------------- grants
do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'public.mall_find_store_branches(uuid, text)',
    'public.request_mall_branch_link(uuid, uuid, uuid)',
    'public.request_mall_store_link(uuid, uuid, uuid, text, numeric, text)',
    'public.mall_store_links(uuid)',
    'public.seller_mall_link_requests()',
    'public.mall_setup_summary(uuid)',
    'public.request_mall_publication(uuid)',
    'public.cancel_mall_publication(uuid)',
    'public.admin_mall_publication_queue()',
    'public.admin_review_mall_publication(uuid, boolean, text)'
  ] loop
    execute format('revoke all on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated', v_fn);
  end loop;
  revoke all on function public.mall_publication_missing(uuid) from public, anon, authenticated;
  revoke all on function public.public_mall_detail(uuid) from public;
  grant execute on function public.public_mall_detail(uuid) to anon, authenticated;
end $$;

commit;
