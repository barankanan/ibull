-- 20261010 akış testi. Gerçek kullanıcılar JWT claim ile simüle edilir; sonunda ROLLBACK, veri kalıcı yazılmaz.
-- Kimlikler: Primall new yöneticisi, Teknosa satıcısı (IBL-7LXD6N), destina satıcısı, admin, müşteri.

begin;

create temp table flow_result (step text, name text, ok boolean, detail text);
grant all on flow_result to public;

do $$
declare
  c_mall constant uuid := '6076965d-e3d2-452a-93ae-784e9fc6a021';
  c_floor1 constant uuid := '33436739-7da0-4524-a0b5-88395d80b373';
  c_mgr constant uuid := '7b02727f-c24e-494e-b355-a5f2883a1721';
  c_teknosa constant uuid := '72f73ba9-8355-4573-923d-a2bc8b99bb75';
  c_teknosa_branch constant uuid := '65f9be3c-8f25-42ce-9f02-1801f5ecb362';
  c_other_seller constant uuid := '7264153b-f493-4508-8402-5fa8cfaabed8';
  c_admin constant uuid := '4cd59c3c-dc73-4b51-a652-d3361e3a635c';
  c_customer constant uuid := 'f60894fe-79c7-40f4-8f1b-4de14df20e54';
  m public.malls%rowtype;
  v_json jsonb;
  v_link uuid;
  v_unit uuid;
  v_text text;
  n int;
  n0 int;

  procedure_claims text;
begin
  select * into m from public.malls where id = c_mall;

  -- ------------------------------------------------ manager
  perform set_config('request.jwt.claims', json_build_object('sub', c_mgr, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';

  perform public.update_mall_profile(c_mall, m.name, m.legal_name, m.city, m.district, m.address_text,
    m.phone, m.website, null);
  v_json := public.mall_setup_summary(c_mall);
  insert into flow_result values ('A1', 'Saat boş -> hours_ready false', (v_json ->> 'hours_ready')::boolean = false, v_json ->> 'hours_ready');
  perform public.update_mall_profile(c_mall, m.name, m.legal_name, m.city, m.district, m.address_text,
    m.phone, m.website, '08:00 - 22:00');
  v_json := public.mall_setup_summary(c_mall);
  insert into flow_result values ('A2', 'Saat kaydet -> hours_ready true', (v_json ->> 'hours_ready')::boolean, v_json::text);

  n0 := (v_json ->> 'floor_count')::int;
  perform public.upsert_mall_floor(c_mall, null, '2. Kat', 2, 2);
  v_json := public.mall_setup_summary(c_mall);
  insert into flow_result values ('B', 'Kat ekle -> floor_count +1', (v_json ->> 'floor_count')::int = n0 + 1,
    n0 || ' -> ' || (v_json ->> 'floor_count'));

  foreach v_text in array array['teknosa', 'Teknosa', 'TEKNO', 'elektron'] loop
    v_json := public.mall_find_store_branches(c_mall, v_text);
    insert into flow_result values ('C', 'Ara "' || v_text || '" -> Teknosa',
      exists (select 1 from jsonb_array_elements(v_json) e where (e ->> 'branch_id')::uuid = c_teknosa_branch),
      coalesce(v_json -> 0 ->> 'store_name', '-') || ' / ' || coalesce(v_json -> 0 ->> 'category', '') || ' / '
        || coalesce(v_json -> 0 ->> 'district', '') || ' / verified=' || coalesce(v_json -> 0 ->> 'is_verified', ''));
  end loop;

  foreach v_text in array array['IBL-7LXD6N', 'ibl-7lxd6n', 'IBL7LXD6N', ' IBL-7LXD6N '] loop
    v_json := public.mall_find_store_branches(c_mall, v_text);
    insert into flow_result values ('D', 'Kod "' || v_text || '" -> Teknosa',
      jsonb_array_length(v_json) = 1 and (v_json -> 0 ->> 'branch_id')::uuid = c_teknosa_branch,
      coalesce(v_json -> 0 ->> 'store_name', '-') || ' ' || coalesce(v_json -> 0 ->> 'branch_code', ''));
  end loop;

  v_json := public.request_mall_store_link(c_mall, c_teknosa_branch, c_floor1, '105', 120, 'Giriş yanı');
  v_link := (v_json ->> 'link_id')::uuid;
  v_unit := (v_json ->> 'unit_id')::uuid;
  select occupancy || '/' || unit_code || '/' || unit_type || '/' || area_m2 into v_text from public.mall_units where id = v_unit;
  insert into flow_result values ('E1', '1. Kat / 105 -> alan otomatik, reserved',
    (v_json ->> 'unit_created')::boolean and v_text = 'reserved/105/store/120.00', v_text);
  select status || '/' || coalesce(note, '') into v_text from public.mall_branch_links where id = v_link;
  insert into flow_result values ('E2', 'Talep pending + not', v_text = 'pending/Giriş yanı', v_text);

  begin
    perform public.request_mall_store_link(c_mall, c_teknosa_branch, c_floor1, '106', null, null);
    insert into flow_result values ('E3', 'Aynı mağaza ikinci talep -> red', false, 'accepted');
  exception when others then
    insert into flow_result values ('E3', 'Aynı mağaza ikinci talep -> red', true, sqlerrm);
  end;
  begin
    perform public.request_mall_store_link(c_mall, c_teknosa_branch, c_floor1, '0', null, null);
    insert into flow_result values ('E4', 'Başka kattaki no -> red', false, 'accepted');
  exception when others then
    insert into flow_result values ('E4', 'Başka kattaki no -> red', sqlerrm like '%başka bir katta%', sqlerrm);
  end;
  begin
    perform public.respond_mall_branch_link(v_link, true);
    insert into flow_result values ('E5', 'AVM kendi talebini onaylayamaz', false, 'approved');
  exception when others then
    insert into flow_result values ('E5', 'AVM kendi talebini onaylayamaz', sqlstate = '42501', sqlerrm);
  end;

  update public.malls set status = 'active' where id = c_mall;
  select status into v_text from public.malls where id = c_mall;
  insert into flow_result values ('I0', 'Yönetici status=active yazamaz', v_text = 'draft', v_text);

  begin
    perform public.request_mall_publication(c_mall);
    insert into flow_result values ('I1', 'Onaylı mağaza yokken yayın talebi -> red', false, 'accepted');
  exception when others then
    insert into flow_result values ('I1', 'Onaylı mağaza yokken yayın talebi -> red', sqlerrm like '%store%', sqlerrm);
  end;

  -- ------------------------------------------------ other seller / other mall manager
  perform set_config('request.jwt.claims', json_build_object('sub', c_other_seller, 'role', 'authenticated')::text, true);
  begin
    perform public.respond_mall_branch_link(v_link, true);
    insert into flow_result values ('F0', 'Başka satıcı onaylayamaz', false, 'approved');
  exception when others then
    insert into flow_result values ('F0', 'Başka satıcı onaylayamaz', sqlstate = '42501', sqlerrm);
  end;
  perform set_config('request.jwt.claims', json_build_object('sub', c_admin, 'role', 'authenticated')::text, true);
  begin
    perform public.request_mall_store_link(c_mall, c_teknosa_branch, c_floor1, '107', null, null);
    insert into flow_result values ('E6', 'Başka AVM yöneticisi bağlayamaz', false, 'accepted');
  exception when others then
    insert into flow_result values ('E6', 'Başka AVM yöneticisi bağlayamaz', sqlstate = '42501', sqlerrm);
  end;

  -- ------------------------------------------------ Teknosa seller
  perform set_config('request.jwt.claims', json_build_object('sub', c_teknosa, 'role', 'authenticated')::text, true);
  select branch_code into v_text from public.store_branches where store_id = c_teknosa and is_primary;
  insert into flow_result values ('D0', 'Satıcı panel kodu = arama kodu', v_text = 'IBL-7LXD6N', v_text);
  select body into v_text from public.user_notifications where user_id = c_teknosa and data ->> 'link_id' = v_link::text;
  insert into flow_result values ('F1', 'Teknosa bildirim', v_text is not null, v_text);
  v_json := public.seller_mall_link_requests();
  select e into v_json from jsonb_array_elements(v_json) e where (e ->> 'id')::uuid = v_link;
  insert into flow_result values ('F2', 'AVM Talepleri: Primall new / 1. kat / 105',
    v_json ->> 'mall_name' = 'Primall new' and v_json ->> 'unit_code' = '105' and (v_json ->> 'level_number')::int = 1,
    concat_ws(' / ', v_json ->> 'mall_name', v_json ->> 'city', v_json ->> 'district', v_json ->> 'floor_name',
              'Mağaza ' || (v_json ->> 'unit_code'), v_json ->> 'status'));
  v_text := public.respond_mall_branch_link(v_link, true);
  insert into flow_result values ('G1', 'Teknosa Onayla', v_text = 'approved', v_text);

  -- ------------------------------------------------ manager sees result
  perform set_config('request.jwt.claims', json_build_object('sub', c_mgr, 'role', 'authenticated')::text, true);
  select occupancy into v_text from public.mall_units where id = v_unit;
  v_json := public.mall_store_links(c_mall);
  select e into v_json from jsonb_array_elements(v_json) e where (e ->> 'id')::uuid = v_link;
  insert into flow_result values ('G2', 'AVM: 1. Kat / 105 Teknosa Aktif',
    v_json ->> 'status' = 'approved' and v_json ->> 'store_name' = 'Teknosa' and v_text = 'occupied',
    concat_ws(' / ', v_json ->> 'floor_name', (v_json ->> 'unit_code') || ' ' || (v_json ->> 'store_name'), v_json ->> 'status', v_text));
  v_json := public.mall_setup_summary(c_mall);
  insert into flow_result values ('G3', 'Özet: aktif mağaza >= 1, eksik yok',
    (v_json ->> 'active_store_count')::int >= 1 and jsonb_array_length(v_json -> 'missing') = 0, v_json::text);

  -- ------------------------------------------------ publication
  execute 'set local role anon';
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  v_json := public.public_mall_detail(c_mall);
  insert into flow_result values ('I2', 'Taslak AVM anonim detayda yok', v_json is null, coalesce(v_json::text, 'null'));
  select count(*) into n from public.malls where id = c_mall and status = 'active';
  insert into flow_result values ('I3', 'Taslak AVM harita sorgusunda yok', n = 0, n::text);

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub', c_mgr, 'role', 'authenticated')::text, true);
  v_json := public.request_mall_publication(c_mall);
  insert into flow_result values ('I4', 'Yayına Gönder -> pending_review', v_json ->> 'status' = 'pending_review',
    (v_json ->> 'status') || ' / ' || coalesce(v_json -> 'publication' ->> 'status', ''));
  begin
    perform public.admin_review_mall_publication(c_mall, true, null);
    insert into flow_result values ('I5', 'Yönetici kendi yayınını onaylayamaz', false, 'approved');
  exception when others then
    insert into flow_result values ('I5', 'Yönetici kendi yayınını onaylayamaz', sqlstate = '42501', sqlerrm);
  end;

  perform set_config('request.jwt.claims', json_build_object('sub', c_admin, 'role', 'authenticated')::text, true);
  v_json := public.admin_mall_publication_queue();
  insert into flow_result values ('I6', 'Admin kuyruğunda', exists (
    select 1 from jsonb_array_elements(v_json) e where (e ->> 'mall_id')::uuid = c_mall), v_json::text);
  v_text := public.admin_review_mall_publication(c_mall, true, null);
  insert into flow_result values ('I7', 'Admin onay -> active', v_text = 'active', v_text);

  execute 'set local role anon';
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  select count(*) into n from public.malls where id = c_mall and status = 'active' and latitude is not null;
  insert into flow_result values ('I8', 'Aktif AVM harita sorgusunda (anon)', n = 1, n::text);
  v_json := public.public_mall_detail(c_mall);
  insert into flow_result values ('I9', 'Public detay: katlar + 105 Teknosa',
    jsonb_array_length(v_json -> 'floors') >= 3 and exists (
      select 1 from jsonb_array_elements(v_json -> 'stores') e
      where e ->> 'unit_code' = '105' and e ->> 'store_name' = 'Teknosa'),
    (v_json -> 'mall' ->> 'name') || ' floors=' || jsonb_array_length(v_json -> 'floors')
      || ' stores=' || (v_json -> 'stores')::text);

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub', c_customer, 'role', 'authenticated')::text, true);
  begin
    perform public.admin_mall_publication_queue();
    insert into flow_result values ('X1', 'Müşteri yayın kuyruğunu göremez', false, 'allowed');
  exception when others then
    insert into flow_result values ('X1', 'Müşteri yayın kuyruğunu göremez', sqlstate = '42501', sqlerrm);
  end;
  begin
    perform public.mall_setup_summary(c_mall);
    insert into flow_result values ('X2', 'Müşteri AVM özetini göremez', false, 'allowed');
  exception when others then
    insert into flow_result values ('X2', 'Müşteri AVM özetini göremez', sqlstate = '42501', sqlerrm);
  end;

  execute 'reset role';
end $$;

select step, name, ok, left(detail, 220) as detail from flow_result order by step;

rollback;
