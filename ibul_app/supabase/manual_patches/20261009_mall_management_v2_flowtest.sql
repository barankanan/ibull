-- Uçtan uca akış testi. Gerçek kullanıcılar JWT claim ile simüle edilir; sonunda ROLLBACK.
-- Hiçbir veri kalıcı yazılmaz. Kimlikler: Primall new yöneticisi, destina satıcısı, sıradan müşteri.
-- Teknosa silme talebinde olduğu için aday listesinde çıkmamalı (adım 3).

begin;

create temp table flow_result (step int, name text, ok boolean, detail text);
grant all on flow_result to public;

do $$
declare
  c_mall constant uuid := '6076965d-e3d2-452a-93ae-784e9fc6a021';
  c_mgr constant uuid := '7b02727f-c24e-494e-b355-a5f2883a1721';
  c_seller constant uuid := '7264153b-f493-4508-8402-5fa8cfaabed8';
  c_customer constant uuid := 'f60894fe-79c7-40f4-8f1b-4de14df20e54';
  v_floor uuid;
  v_unit uuid;
  v_branch uuid;
  v_code text;
  v_link uuid;
  v_json jsonb;
  v_text text;
  v_ad text;
  n int;

  procedure_as text;
begin
  -- manager
  perform set_config('request.jwt.claims', json_build_object('sub', c_mgr, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';

  v_floor := (public.upsert_mall_floor(c_mall, null, '1. Kat', 1, 1) ->> 'id')::uuid;
  select count(*) into n from public.mall_floors where id = v_floor;
  insert into flow_result values (1, 'Kat Ekle -> listede', n = 1, v_floor::text);

  v_unit := (public.upsert_mall_unit(c_mall, null, v_floor, '102', null, 'store', 'vacant', 120, 2) ->> 'id')::uuid;
  select count(*) into n from public.mall_units where id = v_unit and floor_id = v_floor;
  insert into flow_result values (2, 'Birim Ekle -> kata bağlı', n = 1, v_unit::text);

  v_json := public.mall_find_store_branches(c_mall, 'Teknosa');
  insert into flow_result values (3, 'Silme talepli Teknosa adaylarda yok', jsonb_array_length(v_json) = 0, v_json::text);

  v_json := public.mall_find_store_branches(c_mall, 'desti');
  v_branch := (v_json -> 0 ->> 'branch_id')::uuid;
  v_code := v_json -> 0 ->> 'branch_code';
  insert into flow_result values (3, 'Mağaza ara -> sonuç', jsonb_array_length(v_json) >= 1 and v_json -> 0 ->> 'store_name' = 'destina',
    (v_json -> 0 ->> 'store_name') || ' / ' || coalesce(v_json -> 0 ->> 'category', '') || ' / verified=' || (v_json -> 0 ->> 'is_verified'));

  v_json := public.mall_find_store_branches(c_mall, lower(v_code));
  insert into flow_result values (4, 'Mağaza kodu -> doğru mağaza', (v_json -> 0 ->> 'branch_id')::uuid = v_branch, v_code);

  v_link := public.request_mall_branch_link(c_mall, v_unit, v_branch);
  select occupancy into v_text from public.mall_units where id = v_unit;
  select status into procedure_as from public.mall_branch_links where id = v_link;
  insert into flow_result values (5, 'Bağlantı iste -> pending, birim reserved', procedure_as = 'pending' and v_text = 'reserved', procedure_as || '/' || v_text);

  begin
    perform public.request_mall_branch_link(c_mall, v_unit, v_branch);
    insert into flow_result values (6, 'Aynı talep tekrar -> red', false, 'duplicate accepted');
  exception when others then
    insert into flow_result values (6, 'Aynı talep tekrar -> red', true, sqlerrm);
  end;

  begin
    perform public.respond_mall_branch_link(v_link, true);
    insert into flow_result values (7, 'Yönetici kendi talebini onaylayamaz', false, 'approved by manager');
  exception when others then
    insert into flow_result values (7, 'Yönetici kendi talebini onaylayamaz', sqlstate = '42501', sqlerrm);
  end;

  -- seller
  perform set_config('request.jwt.claims', json_build_object('sub', c_seller, 'role', 'authenticated')::text, true);
  select count(*) into n from public.user_notifications
  where user_id = c_seller and data ->> 'link_id' = v_link::text;
  select body into v_text from public.user_notifications where user_id = c_seller and data ->> 'link_id' = v_link::text limit 1;
  insert into flow_result values (8, 'Satıcıya bildirim', n = 1, v_text);

  v_json := public.seller_mall_link_requests();
  insert into flow_result values (9, 'Satıcı AVM Talepleri listesi',
    exists (select 1 from jsonb_array_elements(v_json) e where (e ->> 'id')::uuid = v_link and e ->> 'unit_code' = '102'),
    (v_json -> 0 ->> 'mall_name') || ' / ' || (v_json -> 0 ->> 'floor_name') || ' / ' || (v_json -> 0 ->> 'unit_code'));

  select branch_code into v_text from public.store_branches where store_id = c_seller and is_primary;
  insert into flow_result values (10, 'Satıcı kendi bağlantı kodunu görür', v_text = v_code, v_text);

  v_text := public.respond_mall_branch_link(v_link, true);

  -- manager again
  perform set_config('request.jwt.claims', json_build_object('sub', c_mgr, 'role', 'authenticated')::text, true);
  select occupancy into procedure_as from public.mall_units where id = v_unit;
  insert into flow_result values (11, 'Seller approve -> approved, birim occupied', v_text = 'approved' and procedure_as = 'occupied', v_text || '/' || procedure_as);
  v_json := public.mall_store_links(c_mall);
  insert into flow_result values (12, 'AVM Mağazalar -> aktif',
    exists (select 1 from jsonb_array_elements(v_json) e where (e ->> 'id')::uuid = v_link and e ->> 'status' = 'approved'),
    (v_json -> 0 ->> 'store_name') || ' / ' || (v_json -> 0 ->> 'floor_name') || ' • ' || (v_json -> 0 ->> 'unit_code'));

  begin
    perform public.delete_mall_floor(c_mall, v_floor);
    insert into flow_result values (13, 'Birimli kat silinemez', false, 'deleted');
  exception when others then
    insert into flow_result values (13, 'Birimli kat silinemez', true, sqlerrm);
  end;

  v_json := public.mall_member_directory(c_mall);
  insert into flow_result values (14, 'Yetkililer listesi', jsonb_array_length(v_json -> 'members') >= 1,
    (v_json -> 'members' -> 0 ->> 'display_name') || ' / ' || (v_json -> 'members' -> 0 ->> 'role'));

  begin
    perform public.update_mall_member(c_mall, c_mgr, 'mall_ad_manager', 'active');
    insert into flow_result values (15, 'Kendi rolünü değiştiremez', false, 'changed');
  exception when others then
    insert into flow_result values (15, 'Kendi rolünü değiştiremez', true, sqlerrm);
  end;

  perform public.upsert_mall_campaign(c_mall, null, 'Hafta sonu indirimi', 'Tüm AVM', null,
    now(), now() + interval '7 days', 'mall', '{}', null, true);
  select count(*) into n from public.mall_campaigns where mall_id = c_mall;
  insert into flow_result values (16, 'Kampanya oluştur', n >= 1, n::text);

  v_ad := public.create_mall_ad(c_mall, 'Ana sayfa AVM banner', 'mall_home_banner', now(), now() + interval '14 days', 0, false);
  v_json := public.mall_ad_campaigns(c_mall);
  insert into flow_result values (17, 'Reklam taslağı mevcut campaigns tablosunda', exists (
    select 1 from jsonb_array_elements(v_json) e where e ->> 'id' = v_ad and e ->> 'status' = 'draft'), v_ad);

  begin
    update public.campaigns set status = 'active' where id = v_ad;
    insert into flow_result values (18, 'Reklamı kendisi aktif edemez', false, 'activated');
  exception when others then
    insert into flow_result values (18, 'Reklamı kendisi aktif edemez', sqlstate = '42501', sqlerrm);
  end;

  v_json := public.mall_recent_activity(c_mall, 10);
  insert into flow_result values (19, 'Son işlemler gerçek kayıttan', jsonb_array_length(v_json) >= 3, v_json::text);

  v_json := public.mall_event_stats(c_mall, 30);
  insert into flow_result values (20, 'İstatistik RPC', v_json ? 'totals', v_json::text);

  -- customer
  perform set_config('request.jwt.claims', json_build_object('sub', c_customer, 'role', 'authenticated')::text, true);
  begin
    perform public.upsert_mall_floor(c_mall, null, 'Hack', 9, 9);
    insert into flow_result values (21, 'Müşteri kat yazamaz (RPC)', false, 'written');
  exception when others then
    insert into flow_result values (21, 'Müşteri kat yazamaz (RPC)', sqlstate = '42501', sqlerrm);
  end;
  begin
    insert into public.mall_floors (mall_id, name) values (c_mall, 'Hack');
    insert into flow_result values (22, 'Müşteri kat yazamaz (tablo)', false, 'written');
  exception when others then
    insert into flow_result values (22, 'Müşteri kat yazamaz (tablo)', true, sqlerrm);
  end;
  select count(*) into n from public.mall_branch_links where id = v_link;
  insert into flow_result values (23, 'Müşteri bağlantıları göremez', n = 0, n::text);
  begin
    perform public.mall_find_store_branches(c_mall, 'Teknosa');
    insert into flow_result values (24, 'Müşteri AVM araması yapamaz', false, 'allowed');
  exception when others then
    insert into flow_result values (24, 'Müşteri AVM araması yapamaz', sqlstate = '42501', sqlerrm);
  end;

  execute 'reset role';
end $$;

select step, name, ok, left(detail, 160) as detail from flow_result order by step;

rollback;
