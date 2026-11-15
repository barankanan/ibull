// IBUL_PGLITE_MODULE=/tmp/ibul-sql-test-runtime/node_modules/@electric-sql/pglite/dist/index.js node ibul_app/supabase/tests/restaurant_go_live_check_test.mjs
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.IBUL_PGLITE_MODULE || '@electric-sql/pglite');
const read = (file) => readFile(new URL(file, import.meta.url), 'utf8');
const db = new PGlite();
await db.exec(await read('restaurant_operations_fixture.sql'));
await db.exec(await read('../migrations/2026102901_restaurant_staff_access.sql'));
await db.exec(await read('../migrations/2026102902_restaurant_order_commit.sql'));
await db.exec(await read('../migrations/2026103002_restaurant_service_ticket_details.sql'));
await db.exec(await read('../migrations/2026103001_restaurant_order_update.sql'));

const owner = '10000000-0000-0000-0000-000000000001';
const otherOwner = '10000000-0000-0000-0000-000000000009';
const staff = '20000000-0000-0000-0000-000000000001';
const branch = '30000000-0000-0000-0000-000000000001';
const table = '40000000-0000-0000-0000-000000000001';
const ocak = '50000000-0000-0000-0000-000000000001';
const firin = '50000000-0000-0000-0000-000000000003';
const ocakPrinter = '60000000-0000-0000-0000-000000000001';
const firinPrinter = '60000000-0000-0000-0000-000000000003';
await db.exec(`insert into auth.users(id,email,email_confirmed_at,raw_app_meta_data) values
 ('${owner}','owner@example.test',now(),'{}'),
 ('${otherOwner}','other-owner@example.test',now(),'{}'),
 ('${staff}','staff@example.test',now(),'{"managed_restaurant_staff":true}');
 insert into users(id,email) values
 ('${owner}','owner@example.test'),('${otherOwner}','other-owner@example.test'),('${staff}','staff@example.test');
 insert into stores(seller_id,business_name) values ('${owner}','Fixture'),('${otherOwner}','Other');
 insert into store_branches(id,store_id,status) values ('${branch}','${owner}','active');
 insert into store_tables(id,seller_id,table_number,is_active,branch_id) values ('${table}','${owner}',1,true,'${branch}');
 insert into stations(id,restaurant_id,name,code,is_active) values
 ('${ocak}','${owner}','Ocak','OCAK',true),('${firin}','${owner}','Firin','FIRIN',true);
 insert into printers(id,restaurant_id,name,is_active,print_size) values
 ('${ocakPrinter}','${owner}','Ocak',true,'large'),('${firinPrinter}','${owner}','Firin',true,'large');
 insert into station_printers(station_id,printer_id,is_primary) values
 ('${ocak}','${ocakPrinter}',true),('${firin}','${firinPrinter}',true);
 insert into store_sub_admins(store_id,auth_user_id,email,status,permissions,branch_id,staff_role)
 values('${owner}','${staff}','staff@example.test','active',array['viewOrders','manageOrders'],'${branch}','waiter');`);
const actor = (id) => db.exec(`select set_config('request.jwt.claim.sub','${id}',false); select set_config('request.jwt.claim.role','authenticated',false);`);
await actor(staff);

const tabak2 = [{label:'Tabak 2', items:[
  {name:'Ciğer Dürüm', quantity:1, note:'acı'},
  {name:'Ciğer Servis', quantity:1},
]}];
const tabak3 = [{label:'Tabak 3', items:[
  {name:'Beyti Kebap', quantity:1},
  {name:'Ciğer Dürüm', quantity:2, note:'soğansız'},
]}];
const children2 = [
  {product_name:'Ciğer Dürüm', quantity:1, service_round:2, note:'acı', station_id:ocak},
  {product_name:'Ciğer Servis', quantity:1, service_round:2, station_id:ocak},
];
const children3 = [
  {product_name:'Beyti Kebap', quantity:1, service_round:3, station_id:firin},
  {product_name:'Ciğer Dürüm', quantity:2, service_round:3, note:'soğansız', station_id:firin},
];
const created = (await db.query(`select create_table_order_with_print_jobs($1,1,$2::jsonb,$3,'Fixture',null,'new_order','table',null) result`,
  [owner, JSON.stringify([
    {product_id:'mix', name:'Karışık Servis', quantity:1, price:100, station_id:ocak, plates:tabak2, child_items:children2},
    {product_id:'mix', name:'Karışık Servis', quantity:1, price:120, station_id:firin, plates:tabak3, child_items:children3},
  ]), staff])).rows[0].result;
assert.equal(created.print_job_count, 2);
const orderId = created.order_id;
const jobs = (await db.query(`select id, station_id::text station_id, status, payload from print_jobs where order_id=$1 order by station_id`, [orderId])).rows;
const originalPayloads = new Map(jobs.map((job) => [job.id, JSON.stringify(job.payload)]));
assert.equal(jobs.length, 2);
const ocakJob = jobs.find((job) => job.station_id === ocak);
const firinJob = jobs.find((job) => job.station_id === firin);
assert.equal(ocakJob.payload.print_size, 'large');
assert.equal(firinJob.payload.print_size, 'large');
assert.equal(ocakJob.payload.items.length, 1);
assert.equal(ocakJob.payload.items[0].plates[0].label, 'Tabak 2');
assert.equal(ocakJob.payload.items[0].plates[0].items[0].quantity, 1);
assert.equal(ocakJob.payload.items[0].plates[0].items[0].note, 'acı');
assert.equal(ocakJob.payload.items[0].child_items[1].product_name, 'Ciğer Servis');
assert.equal(firinJob.payload.items[0].plates[0].label, 'Tabak 3');
assert.equal(firinJob.payload.items[0].plates[0].items[1].quantity, 2);
assert.equal(Number(ocakJob.payload.items[0].unit_price), 100);
assert.equal(Number(firinJob.payload.items[0].unit_price), 120);
assert.notEqual(ocakJob.payload.items[0].order_item_id, firinJob.payload.items[0].order_item_id);

const reopened = (await db.query(`select id::text, station_id::text station_id, unit_price, attributes from order_items where order_id=$1 order by unit_price`, [orderId])).rows;
assert.equal(reopened[0].attributes.kitchen_plates[0].label, 'Tabak 2');
assert.equal(reopened[0].attributes.child_items[0].product_name, 'Ciğer Dürüm');
assert.equal(reopened[0].attributes.child_items[0].note, 'acı');
assert.equal(reopened[1].attributes.kitchen_plates[0].label, 'Tabak 3');
assert.equal(reopened[1].attributes.child_items[1].quantity, 2);

const kept = reopened.map((row) => ({
  order_item_id: row.id,
  product_id: 'mix',
  name: 'Karışık Servis',
  quantity: Number(row.unit_price) === 100 ? 2 : 1,
  price: Number(row.unit_price),
  station_id: row.station_id,
}));
const updated = (await db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,$4::jsonb,'add_item','[]'::jsonb,'cancel_item','edit-qty',$5,'Fixture') result`,
  [owner, orderId, JSON.stringify(kept), JSON.stringify([{...kept[0], quantity:1}]), staff])).rows[0].result;
assert.equal(updated.idempotent_replay, false);
assert.equal(updated.print_job_count, 1);
const afterQty = (await db.query(`select id::text, quantity, attributes from order_items where order_id=$1 order by unit_price`, [orderId])).rows;
assert.equal(afterQty[0].quantity, 2);
assert.equal(afterQty[0].attributes.child_items[0].note, 'acı');
assert.equal(afterQty[0].attributes.kitchen_plates[0].label, 'Tabak 2');
assert.equal(afterQty[1].attributes.kitchen_plates[0].label, 'Tabak 3');
assert.equal(afterQty[1].attributes.child_items[1].quantity, 2);
for (const job of jobs) {
  const current = (await db.query('select status, payload from print_jobs where id=$1', [job.id])).rows[0];
  assert.equal(current.status, 'pending');
  assert.equal(JSON.stringify(current.payload), originalPayloads.get(job.id));
}
const replay = (await db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,$4::jsonb,'add_item','[]'::jsonb,'cancel_item','edit-qty',$5,'Fixture') result`,
  [owner, orderId, JSON.stringify(kept), JSON.stringify([{...kept[0], quantity:1}]), staff])).rows[0].result;
assert.equal(replay.idempotent_replay, true);
assert.deepEqual(replay.print_job_ids, updated.print_job_ids);
assert.equal((await db.query('select count(*)::int n from print_jobs where order_id=$1', [orderId])).rows[0].n, 3);

await db.query(`update order_items set kitchen_status='preparing', sent_to_kitchen_at=now() where id=$1`, [reopened[1].id]);
const jobsBeforeCancel = (await db.query('select count(*)::int n from print_jobs where order_id=$1', [orderId])).rows[0].n;
const cancelItem = {
  order_item_id: reopened[1].id,
  product_id: 'mix',
  name: 'Karışık Servis',
  quantity: 1,
  price: 120,
  station_id: firin,
  plates: tabak3,
  child_items: children3,
};
const cancelled = (await db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,'[]'::jsonb,'add_item',$4::jsonb,'cancel_item','edit-cancel',$5,'Fixture') result`,
  [owner, orderId, JSON.stringify([kept[0]]), JSON.stringify([cancelItem]), staff])).rows[0].result;
assert.equal(cancelled.print_job_count, 1);
const remaining = (await db.query('select id::text, attributes, kitchen_status from order_items where order_id=$1', [orderId])).rows;
assert.equal(remaining.length, 1);
assert.equal(remaining[0].id, reopened[0].id);
assert.equal(remaining[0].attributes.kitchen_plates[0].label, 'Tabak 2');
assert.equal(remaining[0].kitchen_status, null);
const cancelJob = (await db.query(`select job_type, station_id::text station_id, payload from print_jobs where id=$1::uuid`, [cancelled.print_job_ids[0]])).rows[0];
assert.equal(cancelJob.job_type, 'cancel_item');
assert.equal(cancelJob.station_id, firin);
assert.equal(cancelJob.payload.print_size, 'large');
assert.equal(cancelJob.payload.items[0].plates[0].label, 'Tabak 3');
assert.equal(cancelJob.payload.items[0].child_items[1].quantity, 2);
assert.equal((await db.query('select count(*)::int n from print_jobs where order_id=$1', [orderId])).rows[0].n, jobsBeforeCancel + 1);
for (const job of jobs) {
  const current = (await db.query('select payload from print_jobs where id=$1', [job.id])).rows[0];
  assert.equal(JSON.stringify(current.payload), originalPayloads.get(job.id));
}

await db.exec(`update store_sub_admins set status='inactive' where auth_user_id='${staff}' and store_id='${owner}'`);
assert.equal((await db.query(`select restaurant_has_permission($1,'manageOrders') ok`, [owner])).rows[0].ok, false);
await assert.rejects(db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,'[]'::jsonb,'add_item','[]'::jsonb,'cancel_item','edit-after-inactive',$4,'Fixture')`,
  [owner, orderId, JSON.stringify([kept[0]]), staff]), /yetkiniz/);
assert.equal((await db.query('select count(*)::int n from order_items where order_id=$1', [orderId])).rows[0].n, 1);

await db.exec(`reset role; select set_config('request.jwt.claim.sub','',false); select set_config('request.jwt.claim.role','',false);`);
const ordersBeforeStaff = (await db.query('select count(*)::int n from orders')).rows[0].n;
await db.exec(`insert into store_sub_admins(store_id,auth_user_id,email,status,permissions,staff_role)
 values('${otherOwner}','${staff}','staff@example.test','active',array['manageOrders'],'waiter');
 insert into store_sub_admins(store_id,email,status,permissions,staff_role)
 values('${owner}','invited@example.test','invited',array['viewOrders'],'waiter');`);
const invited = (await db.query(`select id from store_sub_admins where email='invited@example.test'`)).rows[0];
await db.exec(`delete from store_sub_admins where id='${invited.id}'`);
assert.equal((await db.query(`select count(*)::int n from store_sub_admins where email='invited@example.test'`)).rows[0].n, 0);
await db.exec(`delete from store_sub_admins where store_id='${owner}' and auth_user_id='${staff}'`);
await actor(staff);
assert.equal((await db.query(`select restaurant_has_permission($1,'manageOrders') ok`, [owner])).rows[0].ok, false);
assert.equal((await db.query(`select restaurant_has_permission($1,'manageOrders') ok`, [otherOwner])).rows[0].ok, true);
assert.equal((await db.query('select count(*)::int n from orders')).rows[0].n, ordersBeforeStaff);
assert.equal((await db.query(`select count(*)::int n from users where id='${staff}'`)).rows[0].n, 1);

await db.exec('begin');
await db.exec('drop function public.update_restaurant_table_order(uuid,uuid,jsonb,jsonb,text,jsonb,text,text,uuid,text)');
await assert.rejects(db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,'[]'::jsonb,'add_item','[]'::jsonb,'cancel_item','edit-dropped',$4,'Fixture')`,
  [owner, orderId, JSON.stringify([kept[0]]), owner]), /update_restaurant_table_order/);
await db.exec('rollback');
await actor(owner);
const reprintItems = [{...kept[0], plates:tabak2, child_items:children2}];
const restored = (await db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,$3::jsonb,'reprint','[]'::jsonb,'cancel_item','edit-reprint',$4,'Fixture') result`,
  [owner, orderId, JSON.stringify(reprintItems), owner])).rows[0].result;
assert.equal(restored.idempotent_replay, false);
const reprint = (await db.query(`select payload->'items'->0 items from print_jobs where id=$1::uuid`, [restored.print_job_ids[0]])).rows[0];
assert.equal(reprint.items.plates[0].label, 'Tabak 2');
assert.equal((await db.query(`select attributes->'kitchen_plates'->0->>'label' label from order_items where id=$1`, [reopened[0].id])).rows[0].label, 'Tabak 2');
console.log('PASS: mixed-service lifecycle, station routing, inactive staff gate, update rollback.');
await db.close();
