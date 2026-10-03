-- AVM ↔ mağaza konum mimarisi. Önce mall_management_runtime_fix.sql ve mall_store_link_system.sql uygulanmış olmalı.
-- Sonra: store_location_change_moderation.sql. Geri alma: mall_store_location_rollback.sql.
--
-- Kural: şubenin fiziksel konumu store_branches.location_type ile belirlenir ve yalnız sunucu değiştirir.
--   standalone              → kendi adresi/pini ile haritada
--   mall                    → AVM içinde; ayrı pin yok, AVM pini + AVM detayı + arama ile bulunur
--   pending_location_change → AVM bağlantısı bitti; yeni konum onaylanana kadar haritada yok
-- AVM bağlantısı tek kaynaktır (mall_branch_links); current_mall_id gibi ikinci bir alan tutulmaz.
-- Unique: aynı AVM + aynı fiziksel şube için tek açık (pending/approved) satır.
-- Marka (store) başka AVM'de de olabilir.
begin;
create unique index if not exists mall_branch_links_branch_open_unique
  on public.mall_branch_links (mall_id, branch_id)
  where status in ('pending', 'approved');
create unique index if not exists mall_floors_level_open_unique
  on public.mall_floors (mall_id, level_number)
  where is_active and level_number is not null;

-- ---------------------------------------------------------------- location_type
alter table public.store_branches add column if not exists location_type text not null default 'standalone';
alter table public.store_branches drop constraint if exists store_branches_location_type_check;
alter table public.store_branches add constraint store_branches_location_type_check
  check (location_type in ('standalone', 'mall', 'pending_location_change'));

update public.store_branches b set location_type = 'mall'
where b.location_type <> 'mall'
  and exists (select 1 from public.mall_branch_links l where l.branch_id = b.id and l.status = 'approved');

-- İstemci rolleri (authenticated/anon) location_type'ı değiştiremez; SECURITY DEFINER fonksiyonlar sahibi adına çalışır.
create or replace function public.store_branches_guard_location_type()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.location_type is distinct from old.location_type and current_user in ('authenticated', 'anon') then
    raise exception 'Konum tipi yalnız AVM onayı veya konum onayı ile değişir.' using errcode = '42501';
  end if;
  return new;
end;
$$;
drop trigger if exists store_branches_guard_location_type on public.store_branches;
create trigger store_branches_guard_location_type
  before update of location_type on public.store_branches
  for each row execute function public.store_branches_guard_location_type();

-- ---------------------------------------------------------------- bağlantı durumu → konum tipi
-- approved → mall. Aktif bağlantı biterse (veya AVM içinde açılan mağazanın başvurusu düşerse) → pending_location_change.
create or replace function public.mall_branch_links_sync_location()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_branch public.store_branches%rowtype;
  v_store text;
  v_mall text;
begin
  if new.status = old.status then return new; end if;
  select * into v_branch from public.store_branches where id = new.branch_id;
  if v_branch.id is null then return new; end if;

  if new.status = 'approved' then
    update public.store_branches set location_type = 'mall' where id = v_branch.id and location_type <> 'mall';
    return new;
  end if;
  if exists (select 1 from public.mall_branch_links l
             where l.branch_id = v_branch.id and l.status = 'approved' and l.id <> new.id) then
    return new;
  end if;
  if old.status = 'approved' or (v_branch.location_type = 'mall' and new.status in ('rejected', 'cancelled')) then
    update public.store_branches set location_type = 'pending_location_change' where id = v_branch.id;
  end if;

  if old.status = 'approved' and new.status = 'removed' then
    select s.business_name into v_store from public.stores s where s.seller_id = v_branch.store_id;
    select m.name into v_mall from public.malls m where m.id = new.mall_id;
    insert into public.user_notifications (user_id, title, body, data, type)
    values (v_branch.store_id, 'AVM bağlantısı sona erdi',
            format('%s bağlantınız sona erdi. Mağazayı İBUL''da yayınlamaya devam etmek için yeni konum bilgisi girin.', v_mall),
            jsonb_build_object('type', 'mall_branch_link', 'link_id', new.id, 'mall_id', new.mall_id), 'mall_branch_link');
    if new.reviewed_by is not distinct from v_branch.store_id then
      insert into public.user_notifications (user_id, title, body, data, type)
      select mm.user_id, 'Mağaza ayrıldı', format('%s AVM''nizden ayrıldı.', v_store),
             jsonb_build_object('type', 'mall_branch_link', 'link_id', new.id, 'mall_id', new.mall_id), 'mall_branch_link'
      from public.mall_members mm
      where mm.mall_id = new.mall_id and mm.status = 'active' and mm.role in ('mall_manager', 'mall_store_manager');
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists mall_branch_links_sync_location on public.mall_branch_links;
create trigger mall_branch_links_sync_location
  after update of status on public.mall_branch_links
  for each row execute function public.mall_branch_links_sync_location();

-- ---------------------------------------------------------------- mağaza başvurusu çekirdeği
-- apply_mall_store_link (satıcı paneli) ve yeni mağaza onayı (seller_applications) aynı kuralı kullanır.
create or replace function public.mall_store_link_application_core(
  p_uid uuid, p_request_id uuid, p_mall_id uuid, p_branch_id uuid, p_floor_id uuid,
  p_unit_code text, p_area_m2 numeric, p_note text, p_documents jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := btrim(coalesce(p_unit_code, ''));
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_mall public.malls%rowtype;
  v_unit public.mall_units%rowtype;
  v_store text;
  v_doc jsonb;
  v_prefix text := p_uid::text || '/mall-links/' || p_request_id::text || '/';
begin
  if p_uid is null or p_request_id is null then raise exception 'Oturum gerekli.' using errcode = '42501'; end if;
  select s.business_name into v_store
  from public.store_branches b join public.stores s on s.seller_id = b.store_id
  where b.id = p_branch_id and b.store_id = p_uid and b.status = 'active';
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

  if jsonb_typeof(p_documents) is distinct from 'array' or jsonb_array_length(p_documents) not between 1 and 8 then
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
    values (p_request_id, p_mall_id, v_unit.id, p_branch_id, p_uid, 'store', p_floor_id, v_code, p_area_m2, v_note);
  exception when unique_violation then
    raise exception 'Bu AVM''de bu mağaza veya mağaza no için bekleyen ya da aktif bir bağlantı zaten var.';
  end;
  insert into public.mall_branch_link_documents
    (link_id, document_type, storage_path, original_filename, mime_type, size_bytes, uploaded_by)
  select p_request_id, d->>'type', d->>'path', left(coalesce(nullif(d->>'name', ''), 'belge'), 200),
         coalesce(o.metadata->>'mimetype', d->>'mime'), coalesce((o.metadata->>'size')::bigint, (d->>'size')::bigint), p_uid
  from jsonb_array_elements(p_documents) d
  join storage.objects o on o.bucket_id = 'seller-documents' and o.name = d->>'path';

  insert into public.user_notifications (user_id, title, body, data, type)
  select mm.user_id, 'Yeni mağaza başvurusu', format('%s AVM''nize katılmak için başvuru yaptı.', v_store),
         jsonb_build_object('type', 'mall_branch_link', 'link_id', p_request_id, 'mall_id', p_mall_id), 'mall_branch_link'
  from public.mall_members mm
  where mm.mall_id = p_mall_id and mm.status = 'active' and mm.role in ('mall_manager', 'mall_store_manager');
  return jsonb_build_object('link_id', p_request_id, 'mall_name', v_mall.name);
end;
$$;
revoke all on function public.mall_store_link_application_core(uuid, uuid, uuid, uuid, uuid, text, numeric, text, jsonb)
  from public, anon, authenticated;

create or replace function public.apply_mall_store_link(
  p_request_id uuid, p_mall_id uuid, p_branch_id uuid, p_floor_id uuid,
  p_unit_code text, p_area_m2 numeric, p_note text, p_documents jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Oturum gerekli.' using errcode = '42501'; end if;
  return public.mall_store_link_application_core(auth.uid(), p_request_id, p_mall_id, p_branch_id, p_floor_id,
                                                 p_unit_code, p_area_m2, p_note, p_documents);
end;
$$;

-- ---------------------------------------------------------------- yeni mağaza: "AVM içerisinde"
-- Başvuru AVM seçimini taşır; mağaza + şube admin onayıyla oluşunca AVM'ye BEKLEYEN başvuru açılır.
alter table public.seller_applications add column if not exists mall_placement jsonb;
alter table public.seller_applications drop constraint if exists seller_applications_mall_placement_shape;
alter table public.seller_applications add constraint seller_applications_mall_placement_shape
  check (mall_placement is null or (jsonb_typeof(mall_placement) = 'object' and pg_column_size(mall_placement) < 8192));

create or replace function public.seller_applications_apply_mall_placement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  p jsonb := new.mall_placement;
  v_branch uuid;
  m text;
begin
  if p is null or new.status <> 'approved' or old.status is not distinct from 'approved' then return new; end if;
  select b.id into v_branch from public.store_branches b
  where b.store_id = new.user_id order by b.is_primary desc, b.created_at limit 1;
  if v_branch is null then return new; end if;
  begin
    perform public.mall_store_link_application_core(
      new.user_id, (p->>'request_id')::uuid, (p->>'mall_id')::uuid, v_branch, (p->>'floor_id')::uuid,
      p->>'unit_code', nullif(p->>'area_m2', '')::numeric, p->>'note', coalesce(p->'documents', '[]'::jsonb));
    update public.store_branches set location_type = 'mall' where id = v_branch;
  exception when others then
    get stacked diagnostics m = message_text;
    update public.store_branches set location_type = 'pending_location_change' where id = v_branch;
    insert into public.user_notifications (user_id, title, body, data, type)
    values (new.user_id, 'AVM başvurunuz oluşturulamadı',
            format('Mağazanız onaylandı ancak AVM başvurusu oluşturulamadı: %s Mağaza Profili''nden konum bilgisi girin.', m),
            jsonb_build_object('type', 'mall_branch_link'), 'mall_branch_link');
  end;
  return new;
end;
$$;
drop trigger if exists seller_applications_apply_mall_placement on public.seller_applications;
create trigger seller_applications_apply_mall_placement
  after update of status on public.seller_applications
  for each row execute function public.seller_applications_apply_mall_placement();

-- ---------------------------------------------------------------- herkese açık okuma
-- Başvuru formunda (henüz mağaza yokken) AVM arama: yalnız yayında ve doğrulanmış AVM'ler.
create or replace function public.public_find_malls(p_query text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_query text := btrim(coalesce(p_query, ''));
begin
  if char_length(v_query) < 2 or char_length(v_query) > 80 then return '[]'::jsonb; end if;
  v_query := replace(replace(replace(v_query, '\', '\\'), '%', '\%'), '_', '\_');
  return coalesce((
    select jsonb_agg(row_to_json(r)::jsonb)
    from (
      select m.id, m.name, m.city, m.district, m.logo_url, m.is_verified, m.status,
             coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'name', f.name, 'level_number', f.level_number)
                                        order by f.level_number nulls last, f.sort_order, f.name)
                       from public.mall_floors f where f.mall_id = m.id and f.is_active), '[]'::jsonb) as floors
      from public.malls m
      where m.is_verified and m.status in ('draft', 'pending_review', 'active') and m.name ilike '%' || v_query || '%'
      order by m.name
      limit 20
    ) r
  ), '[]'::jsonb);
end;
$$;

-- Aktif AVM'lerdeki onaylı mağazalar: arama + AVM koordinatıyla mesafe. Geçmiş kayıtlar değil, yalnız güncel bağlantı.
create or replace function public.public_mall_store_directory()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'store_id', s.seller_id, 'store_name', s.business_name, 'category', s.category, 'logo_url', s.logo_url,
           'mall_id', m.id, 'mall_name', m.name, 'city', m.city, 'district', m.district,
           'latitude', m.latitude, 'longitude', m.longitude,
           'floor_id', u.floor_id, 'floor_name', f.name, 'level_number', f.level_number, 'unit_code', u.unit_code)
         order by s.business_name), '[]'::jsonb)
  from public.mall_branch_links l
  join public.malls m on m.id = l.mall_id and m.status = 'active' and m.latitude is not null and m.longitude is not null
  join public.mall_units u on u.id = l.mall_unit_id
  join public.mall_floors f on f.id = u.floor_id
  join public.store_branches b on b.id = l.branch_id
  join public.stores s on s.seller_id = b.store_id
  where l.status = 'approved';
$$;

-- Haritada kendi pini olmaması gereken mağazalar (AVM içinde / konum onayı bekleyen).
create or replace function public.public_map_hidden_store_ids()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(distinct b.store_id), '[]'::jsonb)
  from public.store_branches b
  where b.is_primary and b.location_type <> 'standalone';
$$;

-- Public AVM detayı: yalnız güncel approved satır, şube başına bir kez.
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
  if v_mall.id is null then return null; end if;
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
      select jsonb_agg(row_to_json(s)::jsonb order by s.unit_code)
      from (
        select distinct on (l.branch_id)
               u.unit_code, u.floor_id, u.map_x, u.map_y, s.seller_id as store_id,
               s.business_name as store_name, s.category, s.logo_url
        from public.mall_branch_links l
        join public.mall_units u on u.id = l.mall_unit_id
        join public.store_branches b on b.id = l.branch_id
        join public.stores s on s.seller_id = b.store_id
        where l.mall_id = p_mall_id and l.status = 'approved'
        order by l.branch_id, l.updated_at desc
      ) s
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
revoke all on function public.public_mall_detail(uuid) from public;
grant execute on function public.public_mall_detail(uuid) to anon, authenticated;

revoke all on function public.public_find_malls(text) from public;
revoke all on function public.public_mall_store_directory() from public;
revoke all on function public.public_map_hidden_store_ids() from public;
grant execute on function public.public_find_malls(text) to anon, authenticated;
grant execute on function public.public_mall_store_directory() to anon, authenticated;
grant execute on function public.public_map_hidden_store_ids() to anon, authenticated;
grant execute on function public.apply_mall_store_link(uuid, uuid, uuid, uuid, text, numeric, text, jsonb) to authenticated;

commit;
