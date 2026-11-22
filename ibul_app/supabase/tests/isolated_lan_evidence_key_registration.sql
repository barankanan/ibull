-- Isolated proof for the owner-only evidence key registration and the branch
-- rule for restaurants whose tables carry no branch.
-- Load after isolated_lan_sync_print.sql, 20261103223000 and 20261119090000.
-- Every block raises on a wrong result; a clean run prints REGISTRATION_OK.

\set ON_ERROR_STOP on

create or replace function pg_temp.as_user(p_uid uuid) returns void language sql as $$
  select set_config('ibul.test_uid', coalesce(p_uid::text, ''), false),
         set_config('request.jwt.claim.sub', '', false),
         set_config('request.jwt.claims', '', false);
$$;

-- A second restaurant with tables but no branch at all.
insert into public.users values ('dddddddd-dddd-dddd-dddd-dddddddddddd') on conflict do nothing;
insert into public.stores values ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Şubesiz Lokanta')
on conflict do nothing;
insert into public.store_tables (seller_id, table_number, table_name, branch_id)
values ('dddddddd-dddd-dddd-dddd-dddddddddddd', 1, 'Bahçe 1', null);

create temp table k as
select decode(repeat('ab', 256), 'hex') as modulus,
       repeat('ab', 256) as modulus_hex,
       substr(encode(public.digest(decode(repeat('ab', 256), 'hex'), 'sha256'), 'hex'), 1, 16) as key_id;

do $$
declare
  v_seller constant uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  v_lone constant uuid := 'dddddddd-dddd-dddd-dddd-dddddddddddd';
  v_waiter constant uuid := 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  v_branch_a constant uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_key text; v_hex text; v_branch uuid; v_again uuid; v_denied boolean;
begin
  select key_id, modulus_hex into v_key, v_hex from k;

  -- Nobody signed in.
  perform pg_temp.as_user(null);
  v_denied := false;
  begin
    perform public.register_restaurant_lan_print_evidence_key(v_lone, v_key, v_hex, 'fp-1', null);
  exception when insufficient_privilege then v_denied := true; end;
  if not v_denied then raise exception 'anonymous registration was accepted'; end if;

  -- Staff of the restaurant, even an active one, is not the owner.
  perform pg_temp.as_user(v_waiter);
  v_denied := false;
  begin
    perform public.register_restaurant_lan_print_evidence_key(v_seller, v_key, v_hex, 'fp-1', v_branch_a);
  exception when insufficient_privilege then v_denied := true; end;
  if not v_denied then raise exception 'staff registration was accepted'; end if;

  -- The owner of another restaurant.
  perform pg_temp.as_user(v_seller);
  v_denied := false;
  begin
    perform public.register_restaurant_lan_print_evidence_key(v_lone, v_key, v_hex, 'fp-1', null);
  exception when insufficient_privilege then v_denied := true; end;
  if not v_denied then raise exception 'another owner registered a key'; end if;

  -- A branch of another restaurant.
  perform pg_temp.as_user(v_lone);
  v_denied := false;
  begin
    perform public.register_restaurant_lan_print_evidence_key(v_lone, v_key, v_hex, 'fp-1', v_branch_a);
  exception when insufficient_privilege then v_denied := true; end;
  if not v_denied then raise exception 'foreign branch was accepted'; end if;

  -- A key id that does not belong to the modulus.
  v_denied := false;
  begin
    perform public.register_restaurant_lan_print_evidence_key(v_lone, '0123456789abcdef', v_hex, 'fp-1', null);
  exception when invalid_parameter_value then v_denied := true; end;
  if not v_denied then raise exception 'mismatched key id was accepted'; end if;

  -- A short key.
  v_denied := false;
  begin
    perform public.register_restaurant_lan_print_evidence_key(v_lone, v_key, repeat('ab', 64), 'fp-1', null);
  exception when invalid_parameter_value then v_denied := true; end;
  if not v_denied then raise exception 'short key was accepted'; end if;

  if exists (select 1 from public.restaurant_lan_print_evidence_keys where restaurant_id = v_lone) then
    raise exception 'a refused call left a key behind';
  end if;
  -- Without a primary branch even the owner is refused, and no branch is
  -- invented.
  v_denied := false;
  begin
    perform public.register_restaurant_lan_print_evidence_key(v_lone, v_key, v_hex, 'fp-1', null);
  exception when invalid_parameter_value then v_denied := true; end;
  if not v_denied then raise exception 'registration without a primary branch was accepted'; end if;
  if exists (select 1 from public.store_branches where store_id = v_lone) then
    raise exception 'a branch was created by the registration';
  end if;

  -- An inactive or non-primary branch does not count as the primary one.
  insert into public.store_branches (id, store_id, status, name, is_primary) values
    ('eeeeeeee-0000-0000-0000-000000000001', v_lone, 'passive', 'Eski', true),
    ('eeeeeeee-0000-0000-0000-000000000002', v_lone, 'active', 'Yan', false);
  if public.restaurant_primary_branch_id(v_lone) is not null then
    raise exception 'an inactive or secondary branch was taken as primary';
  end if;

  -- The store's primary branch exists (store setup): the key is bound to it,
  -- and the tables without a branch are covered by it.
  insert into public.store_branches (id, store_id, status, name, is_primary) values
    ('eeeeeeee-0000-0000-0000-000000000003', v_lone, 'active', 'Merkez', true);
  v_branch := public.register_restaurant_lan_print_evidence_key(v_lone, v_key, v_hex, 'fp-1', null);
  if v_branch is distinct from 'eeeeeeee-0000-0000-0000-000000000003'::uuid
     or v_branch is distinct from public.restaurant_primary_branch_id(v_lone) then
    raise exception 'key was not bound to the primary branch';
  end if;

  -- Same key again (certificate renewed): no second branch, no second row.
  v_again := public.register_restaurant_lan_print_evidence_key(v_lone, v_key, v_hex, 'fp-2', null);
  if v_again is distinct from v_branch
     or (select count(*) from public.store_branches where store_id = v_lone) <> 3
     or (select count(*) from public.restaurant_lan_print_evidence_keys where restaurant_id = v_lone) <> 1
     or (select server_fingerprint from public.restaurant_lan_print_evidence_keys where restaurant_id = v_lone) <> 'fp-2' then
    raise exception 'repeat registration was not idempotent';
  end if;

  -- The key table itself stays closed to clients.
  if has_table_privilege('authenticated', 'public.restaurant_lan_print_evidence_keys', 'select')
     or has_table_privilege('authenticated', 'public.restaurant_lan_print_evidence_keys', 'insert')
     or has_table_privilege('anon', 'public.restaurant_lan_print_evidence_keys', 'insert')
     or has_function_privilege('anon', 'public.register_restaurant_lan_print_evidence_key(uuid,text,text,text,uuid)', 'execute') then
    raise exception 'key table or registration is open to clients';
  end if;

  -- Revocation: owner only; a revoked key cannot come back.
  perform pg_temp.as_user(v_seller);
  v_denied := false;
  begin
    perform public.revoke_restaurant_lan_print_evidence_key(v_lone, v_key);
  exception when insufficient_privilege then v_denied := true; end;
  if not v_denied then raise exception 'another owner revoked a key'; end if;
  perform pg_temp.as_user(v_lone);
  if not public.revoke_restaurant_lan_print_evidence_key(v_lone, v_key) then
    raise exception 'owner could not revoke';
  end if;
  v_denied := false;
  begin
    perform public.register_restaurant_lan_print_evidence_key(v_lone, v_key, v_hex, 'fp-3', null);
  exception when insufficient_privilege then v_denied := true; end;
  if not v_denied then raise exception 'a revoked key was registered again'; end if;
end
$$;

select 'REGISTRATION_OK';
