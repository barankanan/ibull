// npm install --prefix /tmp/ibul-sql-test-runtime @electric-sql/pglite
// IBUL_PGLITE_MODULE=/tmp/ibul-sql-test-runtime/node_modules/@electric-sql/pglite/dist/index.js node ibul_app/supabase/tests/restaurant_operations_test.mjs
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.IBUL_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const read = (file) => readFile(new URL(file, import.meta.url), 'utf8');
await db.exec(await read('restaurant_operations_fixture.sql'));
await db.exec(await read('../migrations/2026102901_restaurant_staff_access.sql'));
await db.exec(await read('../migrations/2026102902_restaurant_order_commit.sql'));
assert.equal((await db.query("select count(*)::int n from pg_publication_tables where pubname='supabase_realtime' and tablename in ('print_jobs','printers')")).rows[0].n,2);
const owner='10000000-0000-0000-0000-000000000001';
const other='10000000-0000-0000-0000-000000000002';
const staff='20000000-0000-0000-0000-000000000001';
const branch='30000000-0000-0000-0000-000000000001';
const table='40000000-0000-0000-0000-000000000001';
const station='50000000-0000-0000-0000-000000000001';
const otherBranch='30000000-0000-0000-0000-000000000002';
const otherTable='40000000-0000-0000-0000-000000000002';
await db.exec(`insert into auth.users(id,email,email_confirmed_at,raw_app_meta_data) values
 ('${owner}','owner@example.test',now(),'{}'),('${other}','other@example.test',now(),'{}'),
 ('${staff}','staff@example.test',now(),'{"managed_restaurant_staff":true}');
 insert into users(id,email) values('${owner}','owner@example.test'),('${staff}','staff@example.test');
 insert into stores(seller_id,business_name) values('${owner}','Fixture'),('${other}','Other');
 insert into store_branches(id,store_id,status) values('${branch}','${owner}','active'),('${otherBranch}','${owner}','active');
 insert into store_tables(id,seller_id,table_number,is_active,branch_id) values('${table}','${owner}',1,true,'${branch}'),('${otherTable}','${owner}',2,true,'${otherBranch}');
 insert into stations(id,restaurant_id,name,code,is_active) values('${station}','${owner}','Kitchen','K',true);
 insert into store_sub_admins(store_id,auth_user_id,email,status,permissions,branch_id)
 values('${owner}','${staff}','staff@example.test','active',array['viewOrders','manageOrders'],'${branch}');`);
const actor = async (id) => db.exec(`select set_config('request.jwt.claim.sub','${id}',false); select set_config('request.jwt.claim.role','authenticated',false);`);
const check = async (sql) => (await db.query(sql)).rows[0].ok;
await actor(staff);
assert.equal(await check(`select restaurant_has_permission('${owner}','manageOrders') ok`),true);
assert.equal(await check(`select restaurant_has_permission('${other}','manageOrders') ok`),false);
assert.equal(await check(`select restaurant_has_permission('${owner}','viewFinance') ok`),false);
assert.equal(await check(`select restaurant_table_access('${owner}','${table}') ok`),true);
assert.equal(await check(`select restaurant_table_access('${owner}','${otherTable}') ok`),false);
const submit = (key='retry-1',st=station,tableNumber=1) => db.query(`select create_table_order_with_print_jobs_impl($1,$5,$2::jsonb,$3,'Fixture',null,'new_order','table',$4) result`,
 [owner,JSON.stringify([{product_id:'fixture',name:'Soup',quantity:1,price:10,station_id:st}]),staff,key,tableNumber]);
const first=(await submit()).rows[0].result;
assert.ok(first.order_id);
assert.equal(first.print_job_count,1);
const replay=(await submit()).rows[0].result;
assert.equal(replay.order_id,first.order_id);
assert.equal(replay.idempotent_replay,true);
assert.equal((await db.query('select count(*)::int n from orders')).rows[0].n,1);
assert.equal((await db.query('select count(*)::int n from print_jobs')).rows[0].n,1);
assert.notEqual(await check(`select current_setting('ibul.marketplace_order_rpc',true)='on' ok`),true);
// Exercise actual RLS with the same permissive buyer/staff paths seen live.
await db.exec(`alter table orders enable row level security;
 create policy fixture_orders_existing_access on orders for all to authenticated
 using(user_id=auth.uid() or public.user_can_access_restaurant(restaurant_id))
 with check(user_id=auth.uid() or public.user_can_access_restaurant(restaurant_id));
 set role authenticated;`);
assert.equal((await db.query('select count(*)::int n from orders')).rows[0].n,1);
await db.exec('reset role');
await actor(other);
await db.exec('set role authenticated');
assert.equal((await db.query('select count(*)::int n from orders')).rows[0].n,0);
await db.exec('reset role');
await actor(staff);

// Disabled printing still saves the order, with paused jobs, never pending.
await actor(owner);
await db.exec(`insert into restaurant_print_station_configs values('${owner}',false)`);
const paused=(await submit('printing-disabled')).rows[0].result;
assert.equal((await db.query('select status from print_jobs where order_id=$1',[paused.order_id])).rows[0].status,'paused_by_operator');
await db.exec(`update restaurant_print_station_configs set print_system_enabled=true`);
await actor(staff);
await assert.rejects(submit('foreign-branch',station,2),/şubede/);
// Foreign station rejects the whole transaction and cannot create print jobs.
await assert.rejects(submit('invalid-station',table),/İstasyon/);
await actor(owner);
await db.exec(`update store_sub_admins set permissions=array['viewOrders'] where auth_user_id='${staff}'`);
await actor(staff);
await assert.rejects(submit('no-permission'),/yetkiniz/);
await assert.rejects(db.query(`select close_table_with_history('${owner}',1)`),/yetkisi/);
await db.exec('set role authenticated');
assert.equal((await db.query(`select finance_get_overview('${owner}') total`)).rows[0].total,null);
await db.exec('reset role');
// RLS blocks self escalation with an already-issued Auth identity.
await db.exec('set role authenticated');
const escalated=await db.query(`update store_sub_admins set permissions=array['manageOrders'] where auth_user_id='${staff}' returning id`);
assert.equal(escalated.rows.length,0);
await db.exec('reset role');
await actor(owner);
await db.exec(`update store_sub_admins set status='inactive' where auth_user_id='${staff}'`);
await actor(staff);
assert.equal(await check(`select user_can_access_restaurant('${owner}') ok`),false);
await db.exec('set role authenticated');
assert.equal((await db.query('select count(*)::int n from orders')).rows[0].n,0);
await db.exec('reset role');
await assert.rejects(submit('revoked'),/yetkiniz/);
assert.equal((await db.query('select count(*)::int n from orders')).rows[0].n,2);
console.log('PASS: migrations, save-before-job, retry idempotency, tenant/station/branch checks, permission denial, self-escalation denial, revocation with existing Auth identity.');
await db.close();
