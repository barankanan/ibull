-- 20261010_mall_store_flow_patch.sql geri alma.
-- 1) Bu dosyayı çalıştırın. 2) Ardından 20261009_mall_management_v2_patch.sql dosyasını tekrar çalıştırın
--    (idempotent; mall_find_store_branches, request_mall_branch_link, mall_store_links,
--    seller_mall_link_requests eski hallerine döner).
-- Yayın talebi bekleyen AVM'ler taslağa döner; aktif AVM'lere dokunulmaz.

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

alter table public.mall_branch_links drop constraint if exists mall_branch_links_note_len;
alter table public.mall_branch_links drop column if exists note;

commit;
