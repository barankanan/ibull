-- AVM yönetimi v2: şube, mağaza bağlantısı, kampanya, reklam, istatistik, ekip.
-- Önkoşul: 20261008_mall_management_core_patch.sql. SQL Editor'da uygulanır; db push yok.
-- Var olan tabloların kolonları değişmez. stores üzerine yalnız AFTER INSERT trigger eklenir.

begin;

-- ---------------------------------------------------------------- helpers
create or replace function public.mall_any_role()
returns text[]
language sql
immutable
as $$ select array['mall_manager', 'mall_ad_manager', 'mall_content_editor', 'mall_store_manager'] $$;

-- ---------------------------------------------------------------- branches
create or replace function public.generate_store_branch_code()
returns text
language plpgsql
volatile
set search_path = public
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
begin
  loop
    v_code := 'IBL-';
    for i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * 32)::int, 1);
    end loop;
    exit when to_regclass('public.store_branches') is null
      or not exists (select 1 from public.store_branches b where b.branch_code = v_code);
  end loop;
  return v_code;
end;
$$;

create table if not exists public.store_branches (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (seller_id) on delete cascade,
  branch_code text not null default public.generate_store_branch_code(),
  name text not null,
  city text,
  district text,
  address_text text,
  latitude double precision,
  longitude double precision,
  status text not null default 'active',
  is_primary boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint store_branches_code_format check (branch_code ~ '^IBL-[A-HJ-NP-Z2-9]{6}$'),
  constraint store_branches_name_len check (char_length(btrim(name)) between 1 and 160),
  constraint store_branches_status_check check (status in ('active', 'inactive'))
);

create unique index if not exists store_branches_code_unique on public.store_branches (branch_code);
create unique index if not exists store_branches_primary_unique
  on public.store_branches (store_id) where is_primary;
create index if not exists idx_store_branches_store on public.store_branches (store_id);

drop trigger if exists store_branches_set_updated_at on public.store_branches;
create trigger store_branches_set_updated_at
before update on public.store_branches
for each row execute function public.mall_set_updated_at();

comment on table public.store_branches is
  'Fiziksel şube. Bir stores satırı birden çok şubeye sahip olabilir. branch_code gizli değildir.';

insert into public.store_branches (store_id, name, city, district, address_text, latitude, longitude, is_primary)
select s.seller_id,
       coalesce(nullif(btrim(s.business_name), ''), 'Mağaza'),
       nullif(btrim(s.city), ''),
       nullif(btrim(s.district), ''),
       nullif(btrim(s.address), ''),
       s.store_lat,
       s.store_lng,
       true
from public.stores s
where not exists (select 1 from public.store_branches b where b.store_id = s.seller_id and b.is_primary);

create or replace function public.store_branches_create_primary()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    insert into public.store_branches (store_id, name, city, district, address_text, latitude, longitude, is_primary)
    values (
      new.seller_id,
      coalesce(nullif(btrim(new.business_name), ''), 'Mağaza'),
      nullif(btrim(new.city), ''),
      nullif(btrim(new.district), ''),
      nullif(btrim(new.address), ''),
      new.store_lat,
      new.store_lng,
      true
    )
    on conflict do nothing;
  exception when others then
    raise warning 'store_branches primary insert skipped: %', sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists stores_create_primary_branch on public.stores;
create trigger stores_create_primary_branch
after insert on public.stores
for each row execute function public.store_branches_create_primary();

alter table public.store_branches enable row level security;
revoke all on table public.store_branches from public, anon, authenticated;
grant select on table public.store_branches to authenticated;

drop policy if exists store_branches_select on public.store_branches;
create policy store_branches_select on public.store_branches
for select to authenticated
using (status = 'active' or store_id = auth.uid() or public.is_admin_user());

-- ---------------------------------------------------------------- links
create table if not exists public.mall_branch_links (
  id uuid primary key default gen_random_uuid(),
  mall_id uuid not null references public.malls (id) on delete cascade,
  mall_unit_id uuid not null references public.mall_units (id) on delete restrict,
  branch_id uuid not null references public.store_branches (id) on delete cascade,
  requested_by uuid,
  status text not null default 'pending',
  requested_at timestamptz not null default timezone('utc', now()),
  reviewed_at timestamptz,
  reviewed_by uuid,
  updated_at timestamptz not null default timezone('utc', now()),
  constraint mall_branch_links_status_check
    check (status in ('pending', 'approved', 'rejected', 'cancelled', 'removed'))
);

create unique index if not exists mall_branch_links_branch_open_unique
  on public.mall_branch_links (mall_id, branch_id) where status in ('pending', 'approved');
create unique index if not exists mall_branch_links_unit_open_unique
  on public.mall_branch_links (mall_unit_id) where status in ('pending', 'approved');
create index if not exists idx_mall_branch_links_branch on public.mall_branch_links (branch_id, status);

drop trigger if exists mall_branch_links_set_updated_at on public.mall_branch_links;
create trigger mall_branch_links_set_updated_at
before update on public.mall_branch_links
for each row execute function public.mall_set_updated_at();

alter table public.mall_branch_links enable row level security;
revoke all on table public.mall_branch_links from public, anon, authenticated;
grant select on table public.mall_branch_links to authenticated;

drop policy if exists mall_branch_links_select on public.mall_branch_links;
create policy mall_branch_links_select on public.mall_branch_links
for select to authenticated
using (
  public.mall_member_has_role(mall_id, public.mall_any_role())
  or exists (select 1 from public.store_branches b where b.id = branch_id and b.store_id = auth.uid())
  or public.is_admin_user()
);

create or replace function public.mall_find_store_branches(p_mall_id uuid, p_query text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_query text := btrim(coalesce(p_query, ''));
  v_code text := upper(v_query);
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager', 'mall_store_manager']);
  if char_length(v_query) < 2 then
    return '[]'::jsonb;
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
        and coalesce(s.is_deletion_requested, false) = false
        and (
          (v_code ~ '^IBL-[A-Z0-9]{6}$' and b.branch_code = v_code)
          or (v_code !~ '^IBL-' and (s.business_name ilike '%' || v_query || '%'
                                     or b.name ilike '%' || v_query || '%'))
        )
      order by s.is_verified desc nulls last, s.business_name
      limit 20
    ) r
  ), '[]'::jsonb);
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
  v_owner uuid;
  v_mall text;
  v_floor text;
  v_id uuid;
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager', 'mall_store_manager']);
  select * into v_unit from public.mall_units where id = p_unit_id and mall_id = p_mall_id for update;
  if v_unit.id is null then
    raise exception 'Birim bulunamadı.';
  end if;
  if v_unit.occupancy = 'occupied' then
    raise exception 'Bu birim dolu. Önce mevcut bağlantıyı kaldırın.';
  end if;
  select b.store_id into v_owner from public.store_branches b where b.id = p_branch_id and b.status = 'active';
  if v_owner is null then
    raise exception 'Mağaza şubesi bulunamadı.';
  end if;
  begin
    insert into public.mall_branch_links (mall_id, mall_unit_id, branch_id, requested_by)
    values (p_mall_id, p_unit_id, p_branch_id, auth.uid())
    returning id into v_id;
  exception when unique_violation then
    raise exception 'Bu mağaza veya birim için bekleyen ya da aktif bir bağlantı zaten var.';
  end;
  update public.mall_units set occupancy = 'reserved' where id = p_unit_id and occupancy = 'vacant';
  select m.name into v_mall from public.malls m where m.id = p_mall_id;
  select f.name into v_floor from public.mall_floors f where f.id = v_unit.floor_id;
  insert into public.user_notifications (user_id, title, body, data, type)
  values (
    v_owner,
    'AVM bağlantı talebi',
    format('%s AVM yönetimi mağazanızı %s / %s numaralı birime bağlamak istiyor.', v_mall, v_floor, v_unit.unit_code),
    jsonb_build_object('type', 'mall_branch_link', 'link_id', v_id, 'mall_id', p_mall_id),
    'mall_branch_link'
  );
  return v_id;
end;
$$;

create or replace function public.respond_mall_branch_link(p_link_id uuid, p_approve boolean)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_link public.mall_branch_links%rowtype;
  v_owner uuid;
  v_status text := case when p_approve then 'approved' else 'rejected' end;
begin
  select * into v_link from public.mall_branch_links where id = p_link_id for update;
  select b.store_id into v_owner from public.store_branches b where b.id = v_link.branch_id;
  if v_link.id is null or v_owner is distinct from auth.uid() then
    raise exception 'Bu talebi yanıtlama yetkiniz yok.' using errcode = '42501';
  end if;
  if v_link.status <> 'pending' then
    raise exception 'Bu talep artık beklemede değil.';
  end if;
  update public.mall_branch_links
  set status = v_status, reviewed_at = timezone('utc', now()), reviewed_by = auth.uid()
  where id = p_link_id;
  update public.mall_units
  set occupancy = case when p_approve then 'occupied' else 'vacant' end
  where id = v_link.mall_unit_id and (p_approve or occupancy = 'reserved');
  if v_link.requested_by is not null then
    insert into public.user_notifications (user_id, title, body, data, type)
    values (
      v_link.requested_by,
      'AVM bağlantı yanıtı',
      case when p_approve then 'Mağaza bağlantı talebinizi onayladı.' else 'Mağaza bağlantı talebinizi reddetti.' end,
      jsonb_build_object('type', 'mall_branch_link', 'link_id', p_link_id, 'mall_id', v_link.mall_id),
      'mall_branch_link'
    );
  end if;
  return v_status;
end;
$$;

create or replace function public.cancel_mall_branch_link(p_link_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_link public.mall_branch_links%rowtype;
  v_owner uuid;
  v_status text;
begin
  select * into v_link from public.mall_branch_links where id = p_link_id for update;
  select b.store_id into v_owner from public.store_branches b where b.id = v_link.branch_id;
  if v_link.id is null
     or not (public.mall_member_has_role(v_link.mall_id, array['mall_manager', 'mall_store_manager'])
             or v_owner = auth.uid()) then
    raise exception 'Bu bağlantıyı değiştirme yetkiniz yok.' using errcode = '42501';
  end if;
  v_status := case v_link.status when 'pending' then 'cancelled' when 'approved' then 'removed' end;
  if v_status is null then
    raise exception 'Bu bağlantı zaten kapalı.';
  end if;
  update public.mall_branch_links
  set status = v_status, reviewed_at = timezone('utc', now()), reviewed_by = auth.uid()
  where id = p_link_id;
  update public.mall_units set occupancy = 'vacant'
  where id = v_link.mall_unit_id and occupancy in ('reserved', 'occupied');
  return v_status;
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
      select l.id, l.status, l.requested_at, l.reviewed_at, l.mall_unit_id, u.unit_code, u.floor_id,
             f.name as floor_name, b.id as branch_id, b.branch_code, b.name as branch_name,
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
    select l.id, l.status, l.requested_at, l.reviewed_at, m.id as mall_id, m.name as mall_name,
           m.city, m.district, m.logo_url, f.name as floor_name, u.unit_code, b.branch_code
    from public.mall_branch_links l
    join public.store_branches b on b.id = l.branch_id
    join public.malls m on m.id = l.mall_id
    join public.mall_units u on u.id = l.mall_unit_id
    join public.mall_floors f on f.id = u.floor_id
    where b.store_id = auth.uid() and l.status in ('pending', 'approved', 'rejected')
  ) r
$$;

-- ---------------------------------------------------------------- media
create or replace function public.mall_media_path_writable(p_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when (storage.foldername(p_name))[1] = 'malls'
      and (storage.foldername(p_name))[2] ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    then public.mall_member_has_role(
      ((storage.foldername(p_name))[2])::uuid,
      case (storage.foldername(p_name))[3]
        when 'logo' then array['mall_manager', 'mall_content_editor']
        when 'cover' then array['mall_manager', 'mall_content_editor']
        when 'floor-plans' then array['mall_manager', 'mall_store_manager']
        when 'campaigns' then array['mall_manager', 'mall_content_editor', 'mall_ad_manager']
        else array[]::text[]
      end
    )
    else false
  end
$$;

drop policy if exists mall_media_member_insert on storage.objects;
create policy mall_media_member_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'mall-media' and public.mall_media_path_writable(name));

drop policy if exists mall_media_member_update on storage.objects;
create policy mall_media_member_update on storage.objects
for update to authenticated
using (bucket_id = 'mall-media' and public.mall_media_path_writable(name))
with check (bucket_id = 'mall-media' and public.mall_media_path_writable(name));

drop policy if exists mall_media_member_delete on storage.objects;
create policy mall_media_member_delete on storage.objects
for delete to authenticated
using (bucket_id = 'mall-media' and public.mall_media_path_writable(name));

create or replace function public.set_mall_media(p_mall_id uuid, p_kind text, p_url text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager', 'mall_content_editor']);
  if p_url is not null and position(format('/mall-media/malls/%s/', p_mall_id) in p_url) = 0 then
    raise exception 'Geçersiz görsel adresi.';
  end if;
  if p_kind = 'logo' then
    update public.malls set logo_url = p_url where id = p_mall_id;
  elsif p_kind = 'cover' then
    update public.malls set cover_url = p_url where id = p_mall_id;
  else
    raise exception 'Geçersiz görsel türü.';
  end if;
end;
$$;

create or replace function public.set_mall_floor_plan(p_mall_id uuid, p_floor_id uuid, p_url text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager', 'mall_store_manager']);
  if p_url is not null and position(format('/mall-media/malls/%s/floor-plans/', p_mall_id) in p_url) = 0 then
    raise exception 'Geçersiz plan adresi.';
  end if;
  update public.mall_floors set plan_url = p_url where id = p_floor_id and mall_id = p_mall_id;
  if not found then
    raise exception 'Kat bulunamadı.';
  end if;
end;
$$;

create or replace function public.set_mall_unit_position(p_mall_id uuid, p_unit_id uuid, p_x numeric, p_y numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager', 'mall_store_manager']);
  update public.mall_units set map_x = p_x, map_y = p_y where id = p_unit_id and mall_id = p_mall_id;
  if not found then
    raise exception 'Birim bulunamadı.';
  end if;
end;
$$;

-- ---------------------------------------------------------------- campaigns
create table if not exists public.mall_campaigns (
  id uuid primary key default gen_random_uuid(),
  mall_id uuid not null references public.malls (id) on delete cascade,
  title text not null,
  description text,
  image_url text,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  target_type text not null default 'mall',
  target_branch_ids uuid[] not null default '{}',
  target_category text,
  status text not null default 'draft',
  created_by uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint mall_campaigns_title_len check (char_length(btrim(title)) between 1 and 120),
  constraint mall_campaigns_description_len check (description is null or char_length(description) <= 2000),
  constraint mall_campaigns_dates check (ends_at > starts_at),
  constraint mall_campaigns_target_check check (target_type in ('mall', 'stores', 'category')),
  constraint mall_campaigns_status_check check (status in ('draft', 'published'))
);

create index if not exists idx_mall_campaigns_mall on public.mall_campaigns (mall_id, starts_at desc);

drop trigger if exists mall_campaigns_set_updated_at on public.mall_campaigns;
create trigger mall_campaigns_set_updated_at
before update on public.mall_campaigns
for each row execute function public.mall_set_updated_at();

alter table public.mall_campaigns enable row level security;
revoke all on table public.mall_campaigns from public, anon, authenticated;
grant select on table public.mall_campaigns to anon, authenticated;

drop policy if exists mall_campaigns_select on public.mall_campaigns;
create policy mall_campaigns_select on public.mall_campaigns
for select to anon, authenticated
using (
  (status = 'published' and exists (select 1 from public.malls m where m.id = mall_id and m.status = 'active'))
  or public.mall_member_has_role(mall_id, public.mall_any_role())
  or public.is_admin_user()
);

create or replace function public.upsert_mall_campaign(
  p_mall_id uuid, p_campaign_id uuid, p_title text, p_description text, p_image_url text,
  p_starts_at timestamptz, p_ends_at timestamptz, p_target_type text,
  p_target_branch_ids uuid[], p_target_category text, p_publish boolean
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_status text := case when p_publish then 'published' else 'draft' end;
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager', 'mall_content_editor']);
  if p_image_url is not null and position(format('/mall-media/malls/%s/campaigns/', p_mall_id) in p_image_url) = 0 then
    raise exception 'Geçersiz kampanya görseli.';
  end if;
  if p_campaign_id is null then
    insert into public.mall_campaigns (mall_id, title, description, image_url, starts_at, ends_at,
      target_type, target_branch_ids, target_category, status, created_by)
    values (p_mall_id, btrim(p_title), nullif(btrim(coalesce(p_description, '')), ''), p_image_url,
      p_starts_at, p_ends_at, p_target_type, coalesce(p_target_branch_ids, '{}'),
      nullif(btrim(coalesce(p_target_category, '')), ''), v_status, auth.uid())
    returning id into v_id;
  else
    update public.mall_campaigns
    set title = btrim(p_title), description = nullif(btrim(coalesce(p_description, '')), ''),
        image_url = p_image_url, starts_at = p_starts_at, ends_at = p_ends_at,
        target_type = p_target_type, target_branch_ids = coalesce(p_target_branch_ids, '{}'),
        target_category = nullif(btrim(coalesce(p_target_category, '')), ''), status = v_status
    where id = p_campaign_id and mall_id = p_mall_id
    returning id into v_id;
    if v_id is null then
      raise exception 'Kampanya bulunamadı.';
    end if;
  end if;
  return v_id;
end;
$$;

create or replace function public.delete_mall_campaign(p_mall_id uuid, p_campaign_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager', 'mall_content_editor']);
  delete from public.mall_campaigns where id = p_campaign_id and mall_id = p_mall_id;
  if not found then
    raise exception 'Kampanya bulunamadı.';
  end if;
end;
$$;

-- ---------------------------------------------------------------- grants
do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'public.generate_store_branch_code()',
    'public.store_branches_create_primary()',
    'public.mall_find_store_branches(uuid, text)',
    'public.request_mall_branch_link(uuid, uuid, uuid)',
    'public.respond_mall_branch_link(uuid, boolean)',
    'public.cancel_mall_branch_link(uuid)',
    'public.mall_store_links(uuid)',
    'public.seller_mall_link_requests()',
    'public.mall_media_path_writable(text)',
    'public.set_mall_media(uuid, text, text)',
    'public.set_mall_floor_plan(uuid, uuid, text)',
    'public.set_mall_unit_position(uuid, uuid, numeric, numeric)',
    'public.upsert_mall_campaign(uuid, uuid, text, text, text, timestamptz, timestamptz, text, uuid[], text, boolean)',
    'public.delete_mall_campaign(uuid, uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon', v_fn);
    execute format('grant execute on function %s to authenticated', v_fn);
  end loop;
end $$;

commit;
