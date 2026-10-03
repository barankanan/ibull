-- mall_management_runtime_fix.sql geri alma. Yayın bekleyen AVM'ler taslağa döner; aktif AVM'lere dokunulmaz.
-- note kolonu kalkacağı için mall_store_links / seller_mall_link_requests note okumayan hale döndürülür
-- (aksi halde panel yeniden 42703 verir).

begin;

update public.malls set status = 'draft' where status = 'pending_review';

drop function if exists public.request_mall_store_link(uuid, uuid, uuid, text, numeric, text);
drop function if exists public.mall_setup_summary(uuid);
drop function if exists public.request_mall_publication(uuid);
drop function if exists public.cancel_mall_publication(uuid);
drop function if exists public.admin_mall_publication_queue();
drop function if exists public.admin_review_mall_publication(uuid, boolean, text);
drop function if exists public.public_mall_detail(uuid);
drop function if exists public.mall_publication_missing(uuid);
drop table if exists public.mall_publication_requests;

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
      select l.id, l.status, l.requested_at, l.reviewed_at, l.mall_unit_id, u.unit_code, u.area_m2,
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
    select l.id, l.status, l.requested_at, l.reviewed_at, m.id as mall_id, m.name as mall_name,
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

alter table public.mall_branch_links drop constraint if exists mall_branch_links_note_len;
alter table public.mall_branch_links drop column if exists note;

commit;
