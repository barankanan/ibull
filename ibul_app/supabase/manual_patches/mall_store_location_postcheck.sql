-- mall_store_location_architecture.sql + store_location_change_moderation.sql sonrası, gerçek kullanıcılar adına.
-- Tek DO ifadesidir ve her zaman bilinçli bir hatayla biter: hata ifadeyi bütünüyle geri alır, yani
-- Dashboard SQL Editor'de de CLI'da da hiçbir test verisi kalıcı yazılmaz. Rapor hata mesajındadır:
--   "POSTCHECK OK ..." → tüm adımlar geçti; "POSTCHECK FAIL ..." → FAIL/UNEXPECTED satırlarına bakın.
-- Primall new yöneticisi 7b02727f (mağazası yok → yeni başvuran olarak da kullanılır), Teknosa 72f73ba9, admin 4cd59c3c.
do $$
declare
  v_mall uuid := '6076965d-e3d2-452a-93ae-784e9fc6a021';
  v_seller uuid := '72f73ba9-8355-4573-923d-a2bc8b99bb75';
  v_mgr uuid := '7b02727f-c24e-494e-b355-a5f2883a1721';
  v_admin uuid := '4cd59c3c-dc73-4b51-a652-d3361e3a635c';
  v_branch uuid;
  v_link uuid;
  v_floor uuid;
  v_req uuid;
  v_app uuid := gen_random_uuid();
  v_place uuid := gen_random_uuid();
  v_path text;
  v_res jsonb;
  v text;
  c text; m text;
  r text[] := '{}';
begin
  begin
    select id into v_branch from public.store_branches where store_id = v_seller and is_primary;
    select id into v_link from public.mall_branch_links where branch_id = v_branch and mall_id = v_mall and status = 'approved';
    select id into v_floor from public.mall_floors where mall_id = v_mall and level_number = 1;

    -- TEST 2 / 5 / 6: mevcut durum
    select location_type into v from public.store_branches where id = v_branch;
    r := r || ('t5_teknosa_location_type: ' || v || case when v = 'mall' then '' else ' FAIL' end);
    select count(*)::text into v from jsonb_array_elements(public.public_mall_detail(v_mall)->'stores') x
      where x->>'store_name' = 'Teknosa';
    r := r || ('t2_teknosa_in_public_detail: ' || v || case when v = '1' then '' else ' FAIL' end);
    r := r || ('t5_teknosa_hidden_from_map: ' || (public.public_map_hidden_store_ids() @> to_jsonb(v_seller::text))::text);
    select count(*)::text into v from jsonb_array_elements(public.public_mall_map_pins()) x where x->>'id' = v_mall::text;
    r := r || ('t5_primall_pin: ' || v || case when v = '1' then '' else ' FAIL' end);
    select string_agg((x->>'store_name') || ' / ' || (x->>'mall_name') || ' / ' || (x->>'floor_name') || ' / ' || (x->>'unit_code'), ', ')
      into v from jsonb_array_elements(public.public_mall_store_directory()) x where x->>'store_name' ilike 'teknosa%';
    r := r || ('t6_search_directory: ' || coalesce(v, '- FAIL'));

    -- Aynı AVM + aynı şube için ikinci açık bağlantı
    begin
      insert into public.mall_branch_links (mall_id, branch_id, requested_by, request_source, floor_id, unit_code)
      values (v_mall, v_branch, v_seller, 'store', v_floor, 'DUP-1');
      r := r || 'duplicate_open_link: FAIL allowed'::text;
    exception when unique_violation then r := r || 'duplicate_open_link: OK blocked 23505'::text; end;

    -- AVM: Konumu Düzenle (yalnız yönetici)
    perform set_config('request.jwt.claims', json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin perform public.update_mall_store_link_place(v_link, v_floor, '105', 80); r := r || 'stranger_edit_place: FAIL allowed'::text;
    exception when others then get stacked diagnostics c = returned_sqlstate; r := r || ('stranger_edit_place: OK blocked ' || c); end;
    reset role;
    perform set_config('request.jwt.claims', json_build_object('sub', v_mgr, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    r := r || ('mgr_edit_place: ' || public.update_mall_store_link_place(v_link, v_floor, '105', 80)::text);
    reset role;
    select string_agg((x->>'store_name') || ' No ' || (x->>'unit_code'), ', ') into v
      from jsonb_array_elements(public.public_mall_detail(v_mall)->'stores') x;
    r := r || ('public_detail_after_edit: ' || coalesce(v, '-'));

    -- İstemci location_type'ı doğrudan değiştiremez
    perform set_config('request.jwt.claims', json_build_object('sub', v_seller, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      update public.store_branches set location_type = 'standalone' where id = v_branch;
    exception when others then null; end;
    reset role;
    select location_type into v from public.store_branches where id = v_branch;
    r := r || ('client_location_type_write: ' || v || case when v = 'mall' then ' (unchanged)' else ' FAIL' end);

    -- TEST 7: AVM'den ayrılma → haritada yok, satıcı yeni konum girer
    perform set_config('request.jwt.claims', json_build_object('sub', v_seller, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    r := r || ('t7_seller_leaves: ' || public.cancel_mall_branch_link(v_link));
    v_res := public.seller_store_location();
    r := r || ('t7_seller_card: ' || (v_res->>'location_type') || ' link=' || (v_res->'link'->>'status'));
    reset role;
    r := r || ('t7_still_hidden: ' || (public.public_map_hidden_store_ids() @> to_jsonb(v_seller::text))::text);
    select count(*)::text into v from jsonb_array_elements(public.public_mall_store_directory()) x where x->>'store_id' = v_seller::text;
    r := r || ('t7_not_in_mall_directory: ' || v || case when v = '0' then '' else ' FAIL' end);
    select string_agg(title, ' | ') into v from public.user_notifications
      where created_at >= now() - interval '1 minute' and user_id in (v_seller, v_mgr) and title in ('AVM bağlantısı sona erdi', 'Mağaza ayrıldı');
    r := r || ('t7_notifications: ' || coalesce(v, '- FAIL'));

    -- TEST 8: yeni bağımsız konum → admin onayı → pin geri
    perform set_config('request.jwt.claims', json_build_object('sub', v_seller, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_req := public.submit_store_location_change('Hatay', 'Arsuz', 'Postcheck Cad. No 1', 36.4282, 35.9097);
    r := r || 't8_seller_submits: OK'::text;
    reset role;
    r := r || ('t8_hidden_until_approved: ' || (public.public_map_hidden_store_ids() @> to_jsonb(v_seller::text))::text);
    perform set_config('request.jwt.claims', json_build_object('sub', v_mgr, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin perform public.admin_review_store_location_change(v_req, true); r := r || 'mall_mgr_sets_address: FAIL allowed'::text;
    exception when others then get stacked diagnostics c = returned_sqlstate; r := r || ('mall_mgr_sets_address: OK blocked ' || c); end;
    reset role;
    perform set_config('request.jwt.claims', json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select count(*)::text into v from public.store_location_change_requests;
    r := r || ('stranger_reads_location_requests: ' || v || case when v = '0' then '' else ' FAIL' end);
    reset role;
    perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    r := r || ('t8_admin_approves: ' || public.admin_review_store_location_change(v_req, true));
    reset role;
    select location_type || ' ' || coalesce(address_text, '-') into v from public.store_branches where id = v_branch;
    r := r || ('t8_branch: ' || v);
    r := r || ('t8_pin_back: ' || (not public.public_map_hidden_store_ids() @> to_jsonb(v_seller::text))::text);

    -- TEST 3 / 4: yeni mağaza "AVM içerisinde" → admin onayı → AVM'ye BEKLEYEN başvuru → AVM onayı
    v_path := v_mgr::text || '/mall-links/' || v_place::text || '/lease_contract.pdf';
    insert into storage.objects (bucket_id, name, owner, metadata)
    values ('seller-documents', v_path, v_mgr, '{"mimetype":"application/pdf","size":2048}'::jsonb);
    insert into public.seller_applications (id, user_id, status, business_name, category, email, city, district, mall_placement)
    values (v_app, v_mgr, 'pending', 'Postcheck AVM Mağazası', 'Elektronik', 'postcheck@example.com', 'Hatay', 'İskenderun',
            jsonb_build_object('request_id', v_place, 'mall_id', v_mall, 'floor_id', v_floor, 'unit_code', '106', 'area_m2', 60,
              'documents', jsonb_build_array(jsonb_build_object('type', 'lease_contract', 'path', v_path, 'name', 'kira.pdf'))));
    perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform public.admin_approve_seller_application(v_app);
    reset role;
    select l.status || ' src=' || l.request_source || ' code=' || l.unit_code || ' type=' || b.location_type
      into v from public.mall_branch_links l join public.store_branches b on b.id = l.branch_id where l.id = v_place;
    r := r || ('t3_new_store_request: ' || coalesce(v, '- FAIL'));
    r := r || ('t3_hidden_while_pending: ' || (public.public_map_hidden_store_ids() @> to_jsonb(v_mgr::text))::text);
    perform set_config('request.jwt.claims', json_build_object('sub', v_mgr, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select (x->>'request_source') || ' ' || (x->>'status') || ' docs=' || jsonb_array_length(x->'documents') into v
      from jsonb_array_elements(public.mall_store_links(v_mall)) x where x->>'id' = v_place::text;
    r := r || ('t4_mall_incoming: ' || coalesce(v, '- FAIL'));
    r := r || ('t4_mall_approves: ' || public.respond_mall_branch_link(v_place, true));
    reset role;
    select count(*)::text into v from jsonb_array_elements(public.public_mall_detail(v_mall)->'stores') x
      where x->>'store_name' = 'Postcheck AVM Mağazası' and x->>'unit_code' = '106';
    r := r || ('t4_in_mall_detail: ' || v || case when v = '1' then '' else ' FAIL' end);
    r := r || ('t5_no_own_pin: ' || (public.public_map_hidden_store_ids() @> to_jsonb(v_mgr::text))::text);

    -- Herkese açık fonksiyonlar anon ile
    execute 'set local role anon';
    select string_agg((x->>'name') || ' floors=' || jsonb_array_length(x->'floors'), ', ') into v
      from jsonb_array_elements(public.public_find_malls('Primall')) x;
    r := r || ('anon_find_malls: ' || coalesce(v, '-'));
    r := r || ('anon_directory: ' || jsonb_array_length(public.public_mall_store_directory())::text);
    reset role;
  exception when others then
    get stacked diagnostics c = returned_sqlstate, m = message_text;
    r := r || ('UNEXPECTED: ' || c || ' ' || m);
  end;

  raise exception '%', format(E'POSTCHECK %s — hiçbir değişiklik kaydedilmedi\n%s',
    case when array_to_string(r, E'\n') ~ '(FAIL|UNEXPECTED|: false)' then 'FAIL' else 'OK' end,
    array_to_string(r, E'\n'));
end $$;
