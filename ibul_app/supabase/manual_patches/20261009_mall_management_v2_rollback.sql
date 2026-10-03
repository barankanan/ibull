-- Rollback v2 + v2_ops. Bağlantı, kampanya veya olay satırı varsa durur; veri silinmez.
-- invite_mall_member eski hâline 20261008_mall_company_documents_invites.sql ile döner.

begin;

do $$
begin
  if exists (select 1 from public.mall_branch_links) then
    raise exception 'Rollback reddedildi: mall_branch_links satır içeriyor.';
  end if;
  if exists (select 1 from public.mall_campaigns) then
    raise exception 'Rollback reddedildi: mall_campaigns satır içeriyor.';
  end if;
  if exists (select 1 from public.campaigns where type = 'mall_feature') then
    raise exception 'Rollback reddedildi: mall_feature reklam satırı var.';
  end if;
end $$;

drop trigger if exists trg_enforce_mall_ad_campaign_status on public.campaigns;
drop trigger if exists stores_create_primary_branch on public.stores;

drop policy if exists mall_media_member_insert on storage.objects;
drop policy if exists mall_media_member_update on storage.objects;
drop policy if exists mall_media_member_delete on storage.objects;

drop function if exists public.mall_recent_activity(uuid, integer);
drop function if exists public.update_mall_member(uuid, uuid, text, text);
drop function if exists public.mall_member_directory(uuid);
drop function if exists public.mall_event_stats(uuid, integer);
drop function if exists public.track_mall_event(uuid, text, text);
drop function if exists public.mall_ad_campaigns(uuid);
drop function if exists public.submit_mall_ad(uuid, text);
drop function if exists public.create_mall_ad(uuid, text, text, timestamptz, timestamptz, numeric, boolean);
drop function if exists public.enforce_mall_ad_campaign_status();
drop function if exists public.delete_mall_campaign(uuid, uuid);
drop function if exists public.upsert_mall_campaign(uuid, uuid, text, text, text, timestamptz, timestamptz, text, uuid[], text, boolean);
drop function if exists public.set_mall_unit_position(uuid, uuid, numeric, numeric);
drop function if exists public.set_mall_floor_plan(uuid, uuid, text);
drop function if exists public.set_mall_media(uuid, text, text);
drop function if exists public.mall_media_path_writable(text);
drop function if exists public.seller_mall_link_requests();
drop function if exists public.mall_store_links(uuid);
drop function if exists public.cancel_mall_branch_link(uuid);
drop function if exists public.respond_mall_branch_link(uuid, boolean);
drop function if exists public.request_mall_branch_link(uuid, uuid, uuid);
drop function if exists public.mall_find_store_branches(uuid, text);

drop table if exists public.mall_analytics_events;
drop table if exists public.mall_campaigns;
drop table if exists public.mall_branch_links;
drop table if exists public.store_branches;
drop function if exists public.store_branches_create_primary();
drop function if exists public.generate_store_branch_code();
drop function if exists public.mall_any_role();

commit;
