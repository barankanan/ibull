-- Throwaway database only. Run after the schema stand-ins and the migration.
-- Every block raises on failure; a clean run prints one PASS line per case.

\set ON_ERROR_STOP on

-- Fixed identities.
--   R  restaurant / owner      11111111-…
--   S  staff with closeBill     22222222-…
--   N  staff without closeBill  33333333-…
--   X  revoked staff            44444444-…
--   B  staff bound to another branch 55555555-…
insert into public.store_tables (id, seller_id, table_number, branch_id) values
  ('aaaaaaaa-0000-0000-0000-000000000007', '11111111-1111-1111-1111-111111111111', 7,
   'bbbbbbbb-0000-0000-0000-000000000001'),
  ('aaaaaaaa-0000-0000-0000-000000000008', '11111111-1111-1111-1111-111111111111', 8,
   'bbbbbbbb-0000-0000-0000-000000000001'),
  ('aaaaaaaa-0000-0000-0000-000000000009', '11111111-1111-1111-1111-111111111111', 9,
   'bbbbbbbb-0000-0000-0000-000000000001');
insert into public.store_sub_admins (store_id, auth_user_id, branch_id, status, permissions) values
  ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', null,
   'active', array['closeBill', 'manageOrders']),
  ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', null,
   'active', array['manageOrders']),
  ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', null,
   'passive', array['closeBill']),
  ('11111111-1111-1111-1111-111111111111', '55555555-5555-5555-5555-555555555555',
   'bbbbbbbb-0000-0000-0000-000000000002', 'active', array['closeBill']);

create or replace function pg_temp.add_order(
  p_local text, p_table integer, p_price numeric, p_qty integer default 1,
  p_status text default 'confirmed'
) returns uuid language plpgsql as $$
declare v_id uuid;
begin
  insert into public.orders (restaurant_id, table_id, order_type, status, order_status, local_order_id)
  values ('11111111-1111-1111-1111-111111111111',
          ('aaaaaaaa-0000-0000-0000-00000000000' || p_table)::uuid,
          'table', p_status, 'sent', p_local)
  returning id into v_id;
  insert into public.order_items (order_id, product_name, quantity, unit_price, total_price, line_total)
  values (v_id, 'Ürün', p_qty, p_price, p_price * p_qty, p_price * p_qty);
  return v_id;
end $$;

create or replace function pg_temp.settle(
  p_id text, p_table integer, p_locals text[], p_total numeric,
  p_by uuid default '22222222-2222-2222-2222-222222222222',
  p_method text default 'cash',
  p_at timestamptz default '2026-11-22T10:00:00Z'
) returns jsonb language sql as $$
  select public.apply_offline_table_settlement(
    '11111111-1111-1111-1111-111111111111', p_table, p_id, p_locals, p_total,
    p_method, p_at, p_by, '11111111-1111-1111-1111-111111111111');
$$;

create or replace function pg_temp.expect_error(p_sql text, p_fragment text, p_label text)
returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if position(p_fragment in sqlerrm) = 0 and sqlstate <> p_fragment then
      raise exception 'FAIL %: beklenen "%", gelen "%" (%)', p_label, p_fragment, sqlerrm, sqlstate;
    end if;
    raise notice 'PASS %', p_label;
    return;
  end;
  raise exception 'FAIL %: hata bekleniyordu, çağrı başarılı oldu', p_label;
end $$;

-- 1. Switched off by default: nothing runs, nothing is stored.
select pg_temp.add_order('L-1', 7, 320);
select pg_temp.add_order('L-2', 7, 200);
select pg_temp.expect_error(
  $q$select pg_temp.settle('S-off', 7, array['L-1','L-2'], 520)$q$,
  'offline_settlement_disabled', '01 anahtar kapalıyken çalışmaz');
do $$ begin
  if (select count(*) from public.restaurant_offline_settlements) <> 0 then
    raise exception 'FAIL 01b: kapalıyken kayıt oluştu';
  end if;
  raise notice 'PASS 01b kapalıyken kayıt yok';
end $$;

insert into public.restaurant_offline_settlement_settings (restaurant_id, enabled)
values ('11111111-1111-1111-1111-111111111111', true);

-- 2. Only the named orders close; an order added later stays open.
select pg_temp.add_order('L-3-sonradan', 7, 90);
do $$
declare v jsonb;
begin
  v := pg_temp.settle('S-1', 7, array['L-2', 'L-1', ' L-1 '], 520);
  if v ->> 'status' <> 'applied' or (v ->> 'replayed')::boolean
     or (v ->> 'closed_total')::numeric <> 520
     or (v ->> 'remaining_open_orders')::integer <> 1
     or jsonb_array_length(v -> 'history_ids') <> 2 then
    raise exception 'FAIL 02: %', v;
  end if;
  if (select count(*) from public.orders where local_order_id in ('L-1','L-2') and status = 'closed' and order_status = 'closed') <> 2 then
    raise exception 'FAIL 02b: adı geçen siparişler kapanmadı';
  end if;
  if (select status from public.orders where local_order_id = 'L-3-sonradan') <> 'confirmed' then
    raise exception 'FAIL 02c: sonradan eklenen sipariş de kapandı';
  end if;
  if (select count(*) from public.table_order_history) <> 2
     or (select sum(grand_total) from public.table_order_history) <> 520 then
    raise exception 'FAIL 02d: geçmiş kaydı yanlış';
  end if;
  raise notice 'PASS 02 yalnız adı geçen siparişler kapanır, sonradan eklenen açık kalır';
end $$;

-- 3. The same settlement again: same answer, no second history, no second close.
do $$
declare v jsonb;
begin
  v := pg_temp.settle('S-1', 7, array['L-1', 'L-2'], 520);
  if v ->> 'status' <> 'applied' or not (v ->> 'replayed')::boolean then
    raise exception 'FAIL 03: %', v;
  end if;
  if (select count(*) from public.table_order_history) <> 2
     or (select count(*) from public.restaurant_offline_settlements) <> 1
     or (select count(*) from public.restaurant_offline_settlement_orders) <> 2 then
    raise exception 'FAIL 03b: tekrar gönderim ikinci kayıt üretti';
  end if;
  raise notice 'PASS 03 aynı işlem kimliği tekrarında ikinci kayıt yok';
end $$;

-- 4. The same id with different content is refused.
select pg_temp.expect_error(
  $q$select pg_temp.settle('S-1', 7, array['L-1','L-2'], 999)$q$,
  'settlement_id_reused_with_different_content', '04 aynı kimlik farklı içerikle reddedilir');

-- 5. Orders not on the server yet: an error, nothing stored, retry works later.
select pg_temp.add_order('L-5a', 8, 100);
select pg_temp.expect_error(
  $q$select pg_temp.settle('S-5', 8, array['L-5a','L-5b-henuz-yok'], 250)$q$,
  'orders_not_synced', '05 siparişler eşitlenmeden uygulanmaz');
do $$
declare v jsonb;
begin
  if exists (select 1 from public.restaurant_offline_settlements where settlement_id = 'S-5')
     or (select status from public.orders where local_order_id = 'L-5a') <> 'confirmed' then
    raise exception 'FAIL 05b: eksik siparişle kayıt/kapanış oluştu';
  end if;
  perform pg_temp.add_order('L-5b-henuz-yok', 8, 150);
  v := pg_temp.settle('S-5', 8, array['L-5a','L-5b-henuz-yok'], 250);
  if v ->> 'status' <> 'applied' or (v ->> 'remaining_open_orders')::integer <> 0 then
    raise exception 'FAIL 05c: %', v;
  end if;
  raise notice 'PASS 05b sipariş eşitlenince aynı kimlikle uygulanır';
end $$;

-- 6. The device charged a different amount than the server holds: conflict,
--    nothing closes, and a repeat returns the same conflict.
select pg_temp.add_order('L-6', 9, 400);
do $$
declare v jsonb; v2 jsonb;
begin
  v := pg_temp.settle('S-6', 9, array['L-6'], 380);
  v2 := pg_temp.settle('S-6', 9, array['L-6'], 380);
  if v ->> 'status' <> 'conflict' or v ->> 'conflict_reason' is distinct from 'total_mismatch'
     or v2 ->> 'conflict_reason' is distinct from 'total_mismatch' or not (v2 ->> 'replayed')::boolean then
    raise exception 'FAIL 06: % / %', v, v2;
  end if;
  if (select status from public.orders where local_order_id = 'L-6') <> 'confirmed'
     or exists (select 1 from public.table_order_history h
                join public.orders o on o.id = h.original_order_id
                where o.local_order_id = 'L-6') then
    raise exception 'FAIL 06b: tutar uyuşmazlığında sipariş kapandı';
  end if;
  raise notice 'PASS 06 tutar uyuşmazlığı çatışma olarak kaydedilir, sipariş açık kalır';
end $$;

-- 7. The order was already closed online: the offline payment is not taken too.
select pg_temp.add_order('L-7', 9, 60, 1, 'closed');
do $$
declare v jsonb;
begin
  v := pg_temp.settle('S-7', 9, array['L-7'], 60);
  if v ->> 'conflict_reason' is distinct from 'order_already_closed' then
    raise exception 'FAIL 07: %', v;
  end if;
  raise notice 'PASS 07 çevrimiçi kapanmış sipariş ikinci kez tahsil edilmez';
end $$;

-- 8. An order already settled offline cannot be settled under a new id.
do $$
declare v jsonb;
begin
  v := pg_temp.settle('S-8-yeni-kimlik', 7, array['L-1'], 320);
  if coalesce(v ->> 'conflict_reason', '') not in ('order_already_settled', 'order_already_closed') then
    raise exception 'FAIL 08: %', v;
  end if;
  if (select count(*) from public.table_order_history h
      join public.orders o on o.id = h.original_order_id
      where o.local_order_id = 'L-1') <> 1 then
    raise exception 'FAIL 08b: aynı sipariş için ikinci geçmiş kaydı';
  end if;
  raise notice 'PASS 08 aynı sipariş farklı işlem kimliğiyle ikinci kez kapanmaz (%)', v ->> 'conflict_reason';
end $$;

-- 9. An order from another table is not closed through this table.
select pg_temp.add_order('L-9-masa8', 8, 70);
do $$
declare v jsonb;
begin
  v := pg_temp.settle('S-9', 9, array['L-9-masa8'], 70);
  if v ->> 'conflict_reason' is distinct from 'order_table_mismatch'
     or (select status from public.orders where local_order_id = 'L-9-masa8') <> 'confirmed' then
    raise exception 'FAIL 09: %', v;
  end if;
  raise notice 'PASS 09 başka masanın siparişi bu masadan kapanmaz';
end $$;

-- 10. Authority is checked at apply time.
select pg_temp.add_order('L-10', 9, 45);
select pg_temp.expect_error(
  $q$select pg_temp.settle('S-10a', 9, array['L-10'], 45, '33333333-3333-3333-3333-333333333333')$q$,
  '42501', '10a hesap kapatma yetkisi olmayan personel reddedilir');
select pg_temp.expect_error(
  $q$select pg_temp.settle('S-10b', 9, array['L-10'], 45, '44444444-4444-4444-4444-444444444444')$q$,
  '42501', '10b erişimi kaldırılmış personel reddedilir');
select pg_temp.expect_error(
  $q$select pg_temp.settle('S-10c', 9, array['L-10'], 45, '55555555-5555-5555-5555-555555555555')$q$,
  '42501', '10c başka şubenin personeli reddedilir');
select pg_temp.expect_error(
  $q$select pg_temp.settle('S-10d', 9, array['L-10'], 45, '99999999-9999-9999-9999-999999999999')$q$,
  '42501', '10d işletmeyle ilgisi olmayan kimlik reddedilir');
do $$
declare v jsonb;
begin
  if exists (select 1 from public.restaurant_offline_settlements where settlement_id like 'S-10%') then
    raise exception 'FAIL 10e: yetkisiz çağrı kayıt bıraktı';
  end if;
  v := pg_temp.settle('S-10-sahip', 9, array['L-10'], 45, '11111111-1111-1111-1111-111111111111', 'card');
  if v ->> 'status' <> 'applied' then raise exception 'FAIL 10f: %', v; end if;
  raise notice 'PASS 10e yetkisiz çağrı iz bırakmaz, işletme sahibi uygulayabilir';
end $$;

-- 11. Shape checks.
select pg_temp.expect_error(
  $q$select pg_temp.settle('S-11a', 9, array[]::text[], 0)$q$, '22023', '11a boş sipariş kümesi reddedilir');
select pg_temp.expect_error(
  $q$select pg_temp.settle('S-11b', 9, array['L-10'], 45, '22222222-2222-2222-2222-222222222222', 'iban')$q$,
  '22023', '11b tanımsız ödeme yöntemi reddedilir');
select pg_temp.expect_error(
  $q$select pg_temp.settle('S-11c', 99, array['L-10'], 45)$q$, '22023', '11c olmayan masa reddedilir');

-- 12. Clients cannot call it or read the records; the service role can.
do $$
declare v_ok boolean;
begin
  if has_function_privilege('authenticated',
       'public.apply_offline_table_settlement(uuid,integer,text,text[],numeric,text,timestamptz,uuid,uuid,uuid,text,text)',
       'execute')
     or has_function_privilege('anon',
       'public.apply_offline_table_settlement(uuid,integer,text,text[],numeric,text,timestamptz,uuid,uuid,uuid,text,text)',
       'execute')
     or has_table_privilege('authenticated', 'public.restaurant_offline_settlements', 'select')
     or has_table_privilege('authenticated', 'public.restaurant_offline_settlement_settings', 'update')
     or has_table_privilege('anon', 'public.restaurant_offline_settlement_orders', 'select') then
    raise exception 'FAIL 12: istemci rollerinde yetki var';
  end if;
  if not has_function_privilege('service_role',
       'public.apply_offline_table_settlement(uuid,integer,text,text[],numeric,text,timestamptz,uuid,uuid,uuid,text,text)',
       'execute') then
    raise exception 'FAIL 12b: servis rolü çalıştıramıyor';
  end if;
  select bool_and(c.relrowsecurity) into v_ok
  from pg_class c
  where c.oid in ('public.restaurant_offline_settlements'::regclass,
                  'public.restaurant_offline_settlement_orders'::regclass,
                  'public.restaurant_offline_settlement_settings'::regclass);
  if not v_ok then raise exception 'FAIL 12c: satır güvenliği kapalı'; end if;
  raise notice 'PASS 12 istemci rolleri çağıramaz/okuyamaz, satır güvenliği açık';
end $$;

-- 13. Money totals: what was applied equals what the history holds.
do $$
declare v_applied numeric; v_history numeric; v_orders numeric;
begin
  select coalesce(sum(closed_total), 0) into v_applied
  from public.restaurant_offline_settlements where status = 'applied';
  select coalesce(sum(grand_total), 0) into v_history from public.table_order_history;
  select coalesce(sum(order_total), 0) into v_orders from public.restaurant_offline_settlement_orders;
  if v_applied <> v_history or v_applied <> v_orders or v_applied <> 520 + 250 + 45 then
    raise exception 'FAIL 13: uygulanan %, geçmiş %, sipariş %', v_applied, v_history, v_orders;
  end if;
  raise notice 'PASS 13 uygulanan toplam = geçmiş toplamı = sipariş toplamı (%)', v_applied;
end $$;
