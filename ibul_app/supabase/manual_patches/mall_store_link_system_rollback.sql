-- mall_store_link_system.sql'i geri alır ve runtime_fix sürümlerine döner.
-- DİKKAT: alan atanmamış (bekleyen mağaza başvurusu) satırlar ve belge kayıtları silinir; storage dosyaları kalır.
begin;

drop policy if exists mall_link_docs_owner_insert on storage.objects;
drop policy if exists mall_link_docs_select on storage.objects;
drop policy if exists mall_link_docs_owner_delete on storage.objects;

drop function if exists public.seller_find_malls(text);
drop function if exists public.apply_mall_store_link(uuid, uuid, uuid, uuid, text, numeric, text, jsonb);
drop function if exists public.request_mall_link_info(uuid, text);
drop function if exists public.public_mall_map_pins();
drop function if exists public.respond_mall_branch_link(uuid, boolean, text);
drop table if exists public.mall_branch_link_documents;
drop function if exists public.mall_link_document_readable(uuid);

delete from public.mall_branch_links where mall_unit_id is null;
drop index if exists public.mall_branch_links_code_open_unique;
alter table public.mall_branch_links
  drop constraint if exists mall_branch_links_source_check,
  drop constraint if exists mall_branch_links_place_check,
  drop constraint if exists mall_branch_links_approved_unit_check,
  drop constraint if exists mall_branch_links_extra_len;

create or replace function public.respond_mall_branch_link(p_link_id uuid, p_approve boolean)
returns text language plpgsql security definer set search_path = public as $$
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
  if v_link.status <> 'pending' then raise exception 'Bu talep artık beklemede değil.'; end if;
  update public.mall_branch_links set status = v_status, reviewed_at = timezone('utc', now()), reviewed_by = auth.uid()
  where id = p_link_id;
  update public.mall_units set occupancy = case when p_approve then 'occupied' else 'vacant' end
  where id = v_link.mall_unit_id and (p_approve or occupancy = 'reserved');
  if v_link.requested_by is not null then
    insert into public.user_notifications (user_id, title, body, data, type)
    values (v_link.requested_by, 'AVM bağlantı yanıtı',
            case when p_approve then 'Mağaza bağlantı talebinizi onayladı.' else 'Mağaza bağlantı talebinizi reddetti.' end,
            jsonb_build_object('type', 'mall_branch_link', 'link_id', p_link_id, 'mall_id', v_link.mall_id), 'mall_branch_link');
  end if;
  return v_status;
end;
$$;

create or replace function public.request_mall_branch_link(p_mall_id uuid, p_unit_id uuid, p_branch_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_unit public.mall_units%rowtype;
  v_owner uuid;
  v_id uuid;
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager', 'mall_store_manager']);
  select * into v_unit from public.mall_units where id = p_unit_id and mall_id = p_mall_id for update;
  if v_unit.id is null then raise exception 'Mağaza alanı bulunamadı.'; end if;
  if v_unit.occupancy = 'occupied' then raise exception 'Mağaza % dolu. Önce mevcut bağlantıyı kaldırın.', v_unit.unit_code; end if;
  select b.store_id into v_owner from public.store_branches b where b.id = p_branch_id and b.status = 'active';
  if v_owner is null then raise exception 'Mağaza bulunamadı.'; end if;
  begin
    insert into public.mall_branch_links (mall_id, mall_unit_id, branch_id, requested_by)
    values (p_mall_id, p_unit_id, p_branch_id, auth.uid()) returning id into v_id;
  exception when unique_violation then
    raise exception 'Bu mağaza veya mağaza no için bekleyen ya da aktif bir bağlantı zaten var.';
  end;
  update public.mall_units set occupancy = 'reserved' where id = p_unit_id and occupancy = 'vacant';
  return v_id;
end;
$$;

create or replace function public.request_mall_store_link(
  p_mall_id uuid, p_branch_id uuid, p_floor_id uuid, p_unit_code text, p_area_m2 numeric, p_note text
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_code text := btrim(coalesce(p_unit_code, ''));
  v_unit public.mall_units%rowtype;
  v_created boolean := false;
  v_link uuid;
begin
  perform public.mall_management_assert_role(p_mall_id, array['mall_manager', 'mall_store_manager']);
  if not exists (select 1 from public.mall_floors where id = p_floor_id and mall_id = p_mall_id) then
    raise exception 'Kat bulunamadı.';
  end if;
  select * into v_unit from public.mall_units where mall_id = p_mall_id and lower(btrim(unit_code)) = lower(v_code) for update;
  if v_unit.id is null then
    insert into public.mall_units (mall_id, floor_id, unit_code, unit_type, occupancy, area_m2)
    values (p_mall_id, p_floor_id, v_code, 'store', 'vacant', p_area_m2) returning * into v_unit;
    v_created := true;
  end if;
  v_link := public.request_mall_branch_link(p_mall_id, v_unit.id, p_branch_id);
  update public.mall_branch_links set note = nullif(btrim(coalesce(p_note, '')), '') where id = v_link;
  return jsonb_build_object('link_id', v_link, 'unit_id', v_unit.id, 'unit_created', v_created);
end;
$$;

create or replace function public.mall_store_links(p_mall_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
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
returns jsonb language sql stable security definer set search_path = public as $$
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
drop function if exists public.mall_link_rows(uuid, uuid);

alter table public.mall_branch_links
  drop column if exists request_source,
  drop column if exists floor_id,
  drop column if exists unit_code,
  drop column if exists area_m2,
  drop column if exists review_note;
alter table public.mall_branch_links alter column mall_unit_id set not null;

revoke all on function public.respond_mall_branch_link(uuid, boolean) from public, anon;
grant execute on function public.respond_mall_branch_link(uuid, boolean) to authenticated;
commit;
