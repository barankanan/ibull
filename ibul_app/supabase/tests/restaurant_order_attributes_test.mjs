// Isolated order_items.attributes coverage. No live database, Auth, or printer.
// IBUL_PGLITE_MODULE=/tmp/ibul-sql-test-runtime/node_modules/@electric-sql/pglite/dist/index.js node ibul_app/supabase/tests/restaurant_order_attributes_test.mjs
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.IBUL_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const read = (file) => readFile(new URL(file, import.meta.url), 'utf8');
await db.exec(await read('restaurant_operations_fixture.sql'));
await db.exec(await read('../migrations/2026102901_restaurant_staff_access.sql'));
await db.exec(await read('../migrations/2026102902_restaurant_order_commit.sql'));
await db.exec(await read('../migrations/2026103002_restaurant_service_ticket_details.sql'));
await db.exec(await read('../migrations/2026103001_restaurant_order_update.sql'));

const owner = '10000000-0000-0000-0000-000000000001';
const staff = '20000000-0000-0000-0000-000000000001';
const branch = '30000000-0000-0000-0000-000000000001';
const table = '40000000-0000-0000-0000-000000000001';
const station = '50000000-0000-0000-0000-000000000001';
const printer = '60000000-0000-0000-0000-000000000001';
await db.exec(`insert into auth.users(id,email,email_confirmed_at,raw_app_meta_data) values
 ('${owner}','owner@example.test',now(),'{}'),('${staff}','staff@example.test',now(),'{"managed_restaurant_staff":true}');
 insert into users(id,email) values('${owner}','owner@example.test'),('${staff}','staff@example.test');
 insert into stores(seller_id,business_name) values('${owner}','Fixture');
 insert into store_branches(id,store_id,status) values('${branch}','${owner}','active');
 insert into store_tables(id,seller_id,table_number,is_active,branch_id) values('${table}','${owner}',1,true,'${branch}');
 insert into stations(id,restaurant_id,name,code,is_active) values('${station}','${owner}','Ocak','OCAK',true);
 insert into printers(id,restaurant_id,name,code,connection_type,is_active) values('${printer}','${owner}','Ocak Yazici','OCAK','tcp',true);
 insert into station_printers(station_id,printer_id,is_primary) values('${station}','${printer}',true);
 insert into store_sub_admins(store_id,auth_user_id,email,status,permissions,branch_id,staff_role)
 values('${owner}','${staff}','staff@example.test','active',array['viewOrders','manageOrders'],'${branch}','waiter');`);
const constraint = (await db.query(`select attnotnull from pg_attribute
 where attrelid='public.order_items'::regclass and attname='attributes' and not attisdropped`)).rows[0];
assert.equal(constraint.attnotnull, true);
await db.exec(`select set_config('ibul.marketplace_order_rpc','on',false);`);
await assert.rejects(
  db.query(`insert into order_items(order_id,product_name,quantity,unit_price,attributes) values(gen_random_uuid(),'Null Deneme',1,1,null)`),
  /not-null/,
);
await db.exec(`select set_config('ibul.marketplace_order_rpc','',false);`);
await db.exec(`select set_config('request.jwt.claim.sub','${staff}',false); select set_config('request.jwt.claim.role','authenticated',false);`);

const create = (items, key) => db.query(
  `select create_table_order_with_print_jobs_impl($1,1,$2::jsonb,$3,'Fixture',null,'new_order','table',$4) result`,
  [owner, JSON.stringify(items), staff, key],
);
const plain = { product_id: 'peynir', name: 'Peynir Tabağı', quantity: 1, price: 40, station_id: station, notes: 'az tuz' };
const plainOrder = (await create([plain], 'plain-only')).rows[0].result;
const plainRow = (await db.query(`select attributes, item_note from order_items where order_id=$1`, [plainOrder.order_id])).rows[0];
assert.deepEqual(plainRow.attributes, {});
assert.equal(plainRow.item_note, 'az tuz');
assert.equal(plainOrder.print_job_count, 1);

const child = (name, round, quantity, note, variation) => ({
  product_name: name, quantity, service_round: round, note, attributes: [variation],
});
const plate = (round, items) => ({ label: `Tabak ${round}`, items });
const mixed = (price, plates, children) => ({
  product_id: 'mix', name: 'Karışık Servis', quantity: 1, price, station_id: station,
  plates, child_items: children,
});
const mixA = mixed(100,
  [plate(2, [{ name: 'Ordövr Tabağı', quantity: 1, note: 'limon', attributes: ['acılı'] }])],
  [child('Ordövr Tabağı', 2, 1, 'limon', 'acılı')]);
const mixB = mixed(130,
  [plate(4, [{ name: 'Katı Cacık', quantity: 2, note: 'sarımsaksız', attributes: ['yoğurtlu'] }])],
  [child('Katı Cacık', 4, 2, 'sarımsaksız', 'yoğurtlu')]);
const combined = (await create([mixA, plain, mixB], 'mixed-plus-plain')).rows[0].result;
assert.equal(combined.print_job_count, 1);
assert.equal((await db.query('select count(*)::int n from orders where id=$1', [combined.order_id])).rows[0].n, 1);
const lines = (await db.query(`select product_name, attributes from order_items where order_id=$1 order by unit_price`, [combined.order_id])).rows;
assert.equal(lines.length, 3);
assert.equal(lines[0].product_name, 'Peynir Tabağı');
assert.deepEqual(lines[0].attributes, {});
assert.equal(lines[1].product_name, 'Karışık Servis');
assert.equal(lines[1].attributes.kitchen_plates[0].label, 'Tabak 2');
assert.equal(lines[1].attributes.kitchen_plates[0].items[0].quantity, 1);
assert.equal(lines[1].attributes.kitchen_plates[0].items[0].note, 'limon');
assert.deepEqual(lines[1].attributes.kitchen_plates[0].items[0].attributes, ['acılı']);
assert.deepEqual(lines[1].attributes.child_items[0].attributes, ['acılı']);
assert.equal(lines[1].attributes.child_items[0].note, 'limon');
assert.equal(lines[2].attributes.kitchen_plates[0].label, 'Tabak 4');
assert.equal(lines[2].attributes.child_items[0].quantity, 2);
assert.equal(lines[2].attributes.child_items[0].note, 'sarımsaksız');
assert.deepEqual(lines[2].attributes.child_items[0].attributes, ['yoğurtlu']);
const ticket = (await db.query(`select payload->'items' items from print_jobs where order_id=$1`, [combined.order_id])).rows[0].items;
assert.equal(ticket.length, 3);
const firstPlate = ticket.find((item) => item.plates?.[0]?.label === 'Tabak 2');
const secondPlate = ticket.find((item) => item.plates?.[0]?.label === 'Tabak 4');
const plainTicket = ticket.find((item) => item.product_name === 'Peynir Tabağı');
assert.equal(firstPlate.plates[0].items[0].name, 'Ordövr Tabağı');
assert.equal(secondPlate.child_items[0].quantity, 2);
assert.deepEqual(plainTicket.child_items, []);
assert.deepEqual(plainTicket.plates, []);

const beforeFail = (await db.query('select count(*)::int n from print_jobs')).rows[0].n;
const ordersBeforeFail = (await db.query('select count(*)::int n from orders')).rows[0].n;
await assert.rejects(create([{ ...plain, station_id: '50000000-0000-0000-0000-000000000099' }], 'bad-station'), /İstasyon/);
assert.equal((await db.query('select count(*)::int n from print_jobs')).rows[0].n, beforeFail);
assert.equal((await db.query('select count(*)::int n from orders')).rows[0].n, ordersBeforeFail);

const editable = (await db.query(`select id::text, unit_price from order_items where order_id=$1`, [combined.order_id])).rows;
const mixId = editable.find((row) => Number(row.unit_price) === 100).id;
const plainId = editable.find((row) => Number(row.unit_price) === 40).id;
const jobsBeforeEdit = (await db.query('select count(*)::int n from print_jobs where order_id=$1', [combined.order_id])).rows[0].n;
const kept = [
  { order_item_id: mixId, product_id: 'mix', name: 'Karışık Servis', quantity: 1, price: 100, station_id: station, plates: mixA.plates, child_items: mixA.child_items },
  { order_item_id: plainId, product_id: 'peynir', name: 'Peynir Tabağı', quantity: 2, price: 40, station_id: station, notes: 'az tuz' },
];
const updated = (await db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,'[]'::jsonb,'add_item','[]'::jsonb,'cancel_item','edit-keep-mix',$4,'Fixture') result`,
  [owner, combined.order_id, JSON.stringify(kept), staff])).rows[0].result;
assert.equal(updated.idempotent_replay, false);
assert.equal((await db.query('select count(*)::int n from print_jobs where order_id=$1', [combined.order_id])).rows[0].n, jobsBeforeEdit);
const afterEdit = (await db.query(`select id::text, product_name, quantity, attributes from order_items where order_id=$1 order by unit_price`, [combined.order_id])).rows;
assert.equal(afterEdit.length, 2);
assert.equal(afterEdit[0].id, plainId);
assert.deepEqual(afterEdit[0].attributes, {});
assert.equal(afterEdit[0].quantity, 2);
assert.equal(afterEdit[1].id, mixId);
assert.equal(afterEdit[1].attributes.child_items[0].note, 'limon');
assert.equal(afterEdit[1].attributes.kitchen_plates[0].label, 'Tabak 2');
console.log('PASS: empty attributes object, mixed-service isolation, single ticket, failed save leaves no print job.');
await db.close();
