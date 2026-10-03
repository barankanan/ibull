-- mall_store_link_system.sql sonrası. Her iki akış + yetki sınırları gerçek kullanıcılar adına denenir.
-- Primall new yöneticisi 7b02727f, Teknosa sahibi 72f73ba9, başka AVM yöneticisi (admin olabilir), rolsüz rastgele kullanıcı.
-- Tek DO ifadesidir ve her zaman bilinçli bir hatayla biter: hata ifadeyi bütünüyle geri alır, yani
-- Dashboard SQL Editor'de de CLI'da da hiçbir test verisi kalıcı yazılmaz. Sonuç raporu hata mesajındadır:
--   "POSTCHECK OK ..." → tüm adımlar geçti; "POSTCHECK FAIL ..." → FAIL/UNEXPECTED satırlarına bakın.
do $$
declare
  v_mall uuid := '6076965d-e3d2-452a-93ae-784e9fc6a021';
  v_branch uuid := '65f9be3c-8f25-42ce-9f02-1801f5ecb362';
  v_seller uuid := '72f73ba9-8355-4573-923d-a2bc8b99bb75';
  v_mgr uuid := '7b02727f-c24e-494e-b355-a5f2883a1721';
  v_other uuid;
  v_stranger uuid := gen_random_uuid();
  v_floor uuid;
  v_req uuid := gen_random_uuid();
  v_res jsonb;
  v_link uuid;
  v_path text;
  v text;
  c text; m text;
  r text[] := '{}';
begin
  begin
    select user_id into v_other from public.mall_members
    where mall_id <> v_mall and role = 'mall_manager' and status = 'active' limit 1;
    select id into v_floor from public.mall_floors where mall_id = v_mall and level_number = 1 limit 1;

    -- 1) AVM → mağaza daveti
    perform set_config('request.jwt.claims', json_build_object('sub', v_mgr, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_res := public.request_mall_store_link(v_mall, v_branch, v_floor, '105', 80, 'Test daveti');
    v_link := (v_res->>'link_id')::uuid;
    r := r || ('invite: OK ' || v_res::text);
    reset role;
    perform set_config('request.jwt.claims', json_build_object('sub', v_seller, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select count(*)::text into v from jsonb_array_elements(public.seller_mall_link_requests()) x
      where x->>'id' = v_link::text and x->>'request_source' = 'mall';
    r := r || ('seller_sees_invite: ' || v);
    if v_other is not null then
      reset role;
      perform set_config('request.jwt.claims', json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
      execute 'set local role authenticated';
      begin perform public.respond_mall_branch_link(v_link, true); r := r || 'other_mall_approve: FAIL allowed'::text;
      exception when others then get stacked diagnostics c = returned_sqlstate; r := r || ('other_mall_approve: OK blocked ' || c); end;
      reset role;
      perform set_config('request.jwt.claims', json_build_object('sub', v_seller, 'role', 'authenticated')::text, true);
      execute 'set local role authenticated';
    end if;
    r := r || ('seller_approves_invite: ' || public.respond_mall_branch_link(v_link, true)::text);
    reset role;
    select unit_code || ' ' || occupancy || ' ' || coalesce(area_m2::text, '-') into v
      from public.mall_units where mall_id = v_mall and unit_code = '105';
    r := r || ('unit_after_invite: ' || coalesce(v, '-'));
    perform set_config('request.jwt.claims', json_build_object('sub', v_seller, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    r := r || ('seller_removes: ' || public.cancel_mall_branch_link(v_link)::text);
    reset role;

    -- 2) Mağaza → AVM başvurusu (belge storage'a yüklenmiş gibi)
    v_path := v_seller::text || '/mall-links/' || v_req::text || '/lease_contract.pdf';
    insert into storage.objects (bucket_id, name, owner, metadata)
    values ('seller-documents', v_path, v_seller, '{"mimetype":"application/pdf","size":2048}'::jsonb);
    perform set_config('request.jwt.claims', json_build_object('sub', v_seller, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select string_agg((x->>'name') || ' floors=' || jsonb_array_length(x->'floors'), ', ') into v
      from jsonb_array_elements(public.seller_find_malls('Primall')) x;
    r := r || ('seller_find_malls: ' || coalesce(v, '-'));
    begin
      perform public.apply_mall_store_link(v_req, v_mall, v_branch, v_floor, '105', 80, 'Başvuru', '[]'::jsonb);
      r := r || 'apply_without_docs: FAIL allowed'::text;
    exception when others then get stacked diagnostics m = message_text; r := r || ('apply_without_docs: OK blocked ' || m); end;
    v_res := public.apply_mall_store_link(v_req, v_mall, v_branch, v_floor, '105', 80, 'Başvuru',
      jsonb_build_array(jsonb_build_object('type', 'lease_contract', 'path', v_path, 'name', 'kira.pdf', 'mime', 'application/pdf', 'size', 2048)));
    r := r || ('apply: OK ' || v_res::text);
    begin perform public.respond_mall_branch_link(v_req, true); r := r || 'seller_self_approve: FAIL allowed'::text;
    exception when others then get stacked diagnostics c = returned_sqlstate; r := r || ('seller_self_approve: OK blocked ' || c); end;
    begin
      insert into public.mall_branch_link_documents (link_id, document_type, storage_path, original_filename, mime_type, size_bytes, uploaded_by)
      values (v_req, 'other', v_path || 'x', 'x.pdf', 'application/pdf', 1, v_seller);
      r := r || 'direct_doc_insert: FAIL allowed'::text;
    exception when others then get stacked diagnostics c = returned_sqlstate; r := r || ('direct_doc_insert: OK blocked ' || c); end;
    reset role;

    perform set_config('request.jwt.claims', json_build_object('sub', v_mgr, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select (x->>'request_source') || ' ' || (x->>'status') || ' docs=' || jsonb_array_length(x->'documents') into v
      from jsonb_array_elements(public.mall_store_links(v_mall)) x where x->>'id' = v_req::text;
    r := r || ('mall_sees_application: ' || coalesce(v, '-'));
    select count(*)::text into v from public.mall_branch_link_documents where link_id = v_req;
    r := r || ('mall_reads_doc_row: ' || v);
    select count(*)::text into v from storage.objects where name = v_path;
    r := r || ('mall_reads_doc_object: ' || v);
    perform public.request_mall_link_info(v_req, 'Kira sözleşmesinin imzalı sayfasını ekleyin.');
    r := r || ('mall_approves: ' || public.respond_mall_branch_link(v_req, true, 'Hoş geldiniz')::text);
    reset role;
    select unit_code || ' ' || occupancy into v from public.mall_units where mall_id = v_mall and unit_code = '105';
    r := r || ('unit_after_application: ' || coalesce(v, '-'));
    select string_agg(title, ' | ' order by created_at) into v from public.user_notifications
      where data->>'type' = 'mall_branch_link' and created_at >= now() - interval '1 minute';
    r := r || ('notifications: ' || coalesce(v, '-'));

    perform set_config('request.jwt.claims', json_build_object('sub', v_stranger, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select count(*)::text into v from public.mall_branch_link_documents where link_id = v_req;
    r := r || ('stranger_reads_doc_row: ' || v);
    select count(*)::text into v from storage.objects where name = v_path;
    r := r || ('stranger_reads_doc_object: ' || v);
    begin perform public.request_mall_link_info(v_req, 'yetkisiz deneme'); r := r || 'stranger_info: FAIL allowed'::text;
    exception when others then get stacked diagnostics c = returned_sqlstate; r := r || ('stranger_info: OK blocked ' || c); end;
    reset role;
    execute 'set local role anon';
    r := r || ('anon_map_pins: ' || jsonb_array_length(public.public_mall_map_pins())::text);
    reset role;
  exception when others then
    get stacked diagnostics c = returned_sqlstate, m = message_text;
    r := r || ('UNEXPECTED: ' || c || ' ' || m);
  end;

  raise exception '%', format(E'POSTCHECK %s — hiçbir değişiklik kaydedilmedi\n%s',
    case when array_to_string(r, E'\n') ~ '(FAIL|UNEXPECTED)' then 'FAIL' else 'OK' end,
    array_to_string(r, E'\n'));
end $$;
