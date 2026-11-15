// IBUL_PGLITE_MODULE=/tmp/ibul-sql-test-runtime/node_modules/@electric-sql/pglite/dist/index.js node ibul_app/supabase/tests/restaurant_order_update_test.mjs
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.IBUL_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const read = (file) => readFile(new URL(file, import.meta.url), 'utf8');
await db.exec(await read('restaurant_operations_fixture.sql'));
await db.exec(await read('../migrations/2026102901_restaurant_staff_access.sql'));
await db.exec(await read('../migrations/2026102902_restaurant_order_commit.sql'));
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
 insert into stations(id,restaurant_id,name,code,is_active) values('${station}','${owner}','Kitchen','K',true);
 insert into printers(id,restaurant_id,name,is_active,print_size) values('${printer}','${owner}','Ethernet',true,'large');
 insert into station_printers(station_id,printer_id,is_primary) values('${station}','${printer}',true);
 insert into store_sub_admins(store_id,auth_user_id,email,status,permissions,branch_id)
 values('${owner}','${staff}','staff@example.test','active',array['viewOrders','manageOrders'],'${branch}');`);
const actor = async (id) => db.exec(`select set_config('request.jwt.claim.sub','${id}',false); select set_config('request.jwt.claim.role','authenticated',false);`);
await actor(staff);
const created = (await db.query(`select create_table_order_with_print_jobs_impl($1,1,$2::jsonb,$3,'Fixture',null,'new_order','table','create-1') result`,
  [owner, JSON.stringify([{product_id:'soup',name:'Corba',quantity:1,price:10,station_id:station}]), staff])).rows[0].result;
assert.equal(created.print_job_count, 1);
const orderId = created.order_id;
const nextItems = [{product_id:'soup',name:'Corba',quantity:2,price:10,station_id:station}];
const added = [{product_id:'soup',name:'Corba',quantity:1,price:10,station_id:station}];
const update = (key) => db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,$4::jsonb,'add_item','[]'::jsonb,'cancel_item',$5,$6,'Fixture') result`,
  [owner, orderId, JSON.stringify(nextItems), JSON.stringify(added), key, staff]);
const originalJob = (await db.query('select id, status from print_jobs where order_id=$1', [orderId])).rows[0];
const originalItem = (await db.query('select id from order_items where order_id=$1', [orderId])).rows[0];
await db.query(`update order_items set kitchen_status='preparing', sent_to_kitchen_at=now() where id=$1`, [originalItem.id]);
const ordersBefore = (await db.query('select count(*)::int n from orders')).rows[0].n;
const first = (await update('edit-1')).rows[0].result;
assert.equal(first.idempotent_replay, false);
assert.equal(first.print_job_count, 1);
assert.equal((await db.query('select count(*)::int n from orders')).rows[0].n, ordersBefore);
const line = (await db.query('select id, quantity, unit_price, total_price, line_total, kitchen_status, sent_to_kitchen_at from order_items where order_id=$1', [orderId])).rows[0];
assert.equal(line.quantity, 2);
assert.equal(line.id, originalItem.id);
assert.equal(line.kitchen_status, 'preparing');
assert.ok(line.sent_to_kitchen_at);
assert.equal(Number(line.total_price), 20);
assert.equal(Number(line.line_total), 20);
const money = (await db.query('select subtotal_amount, total_amount, shipping_amount, payment_status from orders where id=$1', [orderId])).rows[0];
assert.equal(Number(money.subtotal_amount), 20);
assert.equal(Number(money.total_amount), 20);
assert.equal(Number(money.shipping_amount), 0);
const kept = (await db.query('select status from print_jobs where id=$1', [originalJob.id])).rows[0];
assert.equal(kept.status, originalJob.status);
const job = (await db.query(`select status, payload->>'print_size' print_size, payload->>'revision_key' revision_key from print_jobs where id=$1::uuid`, [first.print_job_ids[0]])).rows[0];
assert.equal(job.status, 'pending');
assert.equal(job.print_size, 'large');
assert.equal(job.revision_key, 'edit-1');
const replay = (await update('edit-1')).rows[0].result;
assert.equal(replay.idempotent_replay, true);
assert.deepEqual(replay.print_job_ids, first.print_job_ids);
assert.equal((await db.query('select count(*)::int n from print_jobs where order_id=$1', [orderId])).rows[0].n, 2);
const salad = {product_id:'salad', name:'Salata', quantity:1, price:5, station_id:station};
const addedLine = (await db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,$4::jsonb,'add_item','[]'::jsonb,'cancel_item','edit-add',$5,'Fixture') result`,
  [owner, orderId, JSON.stringify([...nextItems, salad]), JSON.stringify([salad]), staff])).rows[0].result;
assert.equal(addedLine.idempotent_replay, false);
assert.equal(addedLine.print_job_count, 1);
const afterAdd = (await db.query('select id, product_id, kitchen_status from order_items where order_id=$1', [orderId])).rows;
assert.equal(afterAdd.find((row) => row.product_id === 'soup').id, originalItem.id);
assert.equal(afterAdd.find((row) => row.product_id === 'soup').kitchen_status, 'preparing');
assert.notEqual(afterAdd.find((row) => row.product_id === 'salad').id, originalItem.id);
assert.equal(afterAdd.find((row) => row.product_id === 'salad').kitchen_status, null);
assert.equal(Number((await db.query('select total_amount from orders where id=$1', [orderId])).rows[0].total_amount), 25);
const beforeRemove = (await db.query('select count(*)::int n from print_jobs where order_id=$1', [orderId])).rows[0].n;
const removed = (await db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,'[]'::jsonb,'add_item',$4::jsonb,'cancel_item','edit-remove',$5,'Fixture') result`,
  [owner, orderId, JSON.stringify(nextItems), JSON.stringify([salad]), staff])).rows[0].result;
assert.equal(removed.print_job_count, 1);
const afterRemove = (await db.query('select id, product_id, kitchen_status, quantity from order_items where order_id=$1', [orderId])).rows;
assert.equal(afterRemove.length, 1);
assert.equal(afterRemove[0].id, originalItem.id);
assert.equal(afterRemove[0].kitchen_status, 'preparing');
assert.equal(afterRemove[0].quantity, 2);
assert.equal(Number((await db.query('select total_amount from orders where id=$1', [orderId])).rows[0].total_amount), 20);
const replayRemove = (await db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,'[]'::jsonb,'add_item',$4::jsonb,'cancel_item','edit-remove',$5,'Fixture') result`,
  [owner, orderId, JSON.stringify(nextItems), JSON.stringify([salad]), staff])).rows[0].result;
assert.equal(replayRemove.idempotent_replay, true);
assert.equal((await db.query('select count(*)::int n from print_jobs where order_id=$1', [orderId])).rows[0].n, beforeRemove + 1);
const variantItems = [
  {product_id:'soup', name:'Corba', quantity:1, price:10, station_id:station, notes:'az tuz'},
  {product_id:'soup', name:'Corba', quantity:1, price:12, station_id:station, notes:'ekstra peynir'},
];
const variantCreated = (await db.query(`select create_table_order_with_print_jobs_impl($1,1,$2::jsonb,$3,'Fixture',null,'new_order','table','create-variants') result`,
  [owner, JSON.stringify(variantItems), staff])).rows[0].result;
const variantRows = (await db.query('select id, item_note from order_items where order_id=$1 order by item_note', [variantCreated.order_id])).rows;
assert.equal(variantRows.length, 2);
const plainLine = variantRows.find((row) => row.item_note === 'az tuz');
const extraLine = variantRows.find((row) => row.item_note === 'ekstra peynir');
await db.query(`update order_items set kitchen_status='preparing', sent_to_kitchen_at=now(), attributes='["tuzsuz"]'::jsonb where id=$1`, [plainLine.id]);
await db.query(`update order_items set kitchen_status='ready', attributes='["peynir"]'::jsonb where id=$1`, [extraLine.id]);
const identified = [
  {order_item_id: plainLine.id, product_id:'soup', name:'Corba', quantity:2, price:10, station_id:station, notes:'az tuz'},
  {order_item_id: extraLine.id, product_id:'soup', name:'Corba', quantity:1, price:12, station_id:station, notes:'ekstra peynir'},
];
const identifiedResult = (await db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,'[]'::jsonb,'add_item','[]'::jsonb,'cancel_item','edit-variants',$4,'Fixture') result`,
  [owner, variantCreated.order_id, JSON.stringify(identified), staff])).rows[0].result;
assert.equal(identifiedResult.idempotent_replay, false);
const keptVariants = (await db.query('select id, item_note, quantity, kitchen_status, attributes from order_items where order_id=$1 order by item_note', [variantCreated.order_id])).rows;
assert.equal(keptVariants.length, 2);
assert.equal(keptVariants[0].id, plainLine.id);
assert.equal(keptVariants[0].kitchen_status, 'preparing');
assert.equal(keptVariants[0].quantity, 2);
assert.deepEqual(keptVariants[0].attributes, ['tuzsuz']);
assert.equal(keptVariants[1].id, extraLine.id);
assert.equal(keptVariants[1].kitchen_status, 'ready');
assert.equal(keptVariants[1].item_note, 'ekstra peynir');
assert.deepEqual(keptVariants[1].attributes, ['peynir']);
const ambiguous = variantItems.map((item) => ({...item, quantity: 3}));
await assert.rejects(db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,'[]'::jsonb,'add_item','[]'::jsonb,'cancel_item','edit-ambiguous',$4,'Fixture')`,
  [owner, variantCreated.order_id, JSON.stringify(ambiguous), staff]), /kimliği olmadan güncellenemez/);
const afterAmbiguous = (await db.query('select id, quantity, kitchen_status, item_note from order_items where order_id=$1 order by item_note', [variantCreated.order_id])).rows;
assert.equal(afterAmbiguous[0].id, plainLine.id);
assert.equal(afterAmbiguous[0].quantity, 2);
assert.equal(afterAmbiguous[0].kitchen_status, 'preparing');
assert.equal(afterAmbiguous[1].kitchen_status, 'ready');
await assert.rejects(db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,'[]'::jsonb,'add_item','[]'::jsonb,'cancel_item','edit-missing-line',$4,'Fixture')`,
  [owner, variantCreated.order_id, JSON.stringify([{...identified[0], order_item_id:'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'}]), staff]), /Sipariş kalemi bulunamadı/);
assert.equal((await db.query('select count(*)::int n from order_items where order_id=$1', [variantCreated.order_id])).rows[0].n, 2);
const jobsBeforeCancel = (await db.query('select count(*)::int n from print_jobs where order_id=$1', [variantCreated.order_id])).rows[0].n;
const keptOnly = [identified[1]];
await assert.rejects(db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,'[]'::jsonb,'add_item','[]'::jsonb,'cancel_item','edit-cancel-missing',$4,'Fixture')`,
  [owner, variantCreated.order_id, JSON.stringify(keptOnly), staff]), /iptal fişi oluşturulamadı/);
const wrongCancel = [{order_item_id: extraLine.id, product_id:'soup', name:'Corba', quantity:1, price:12, station_id:station, notes:'ekstra peynir'}];
await assert.rejects(db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,'[]'::jsonb,'add_item',$4::jsonb,'cancel_item','edit-cancel-wrong',$5,'Fixture')`,
  [owner, variantCreated.order_id, JSON.stringify(keptOnly), JSON.stringify(wrongCancel), staff]), /uyuşmuyor/);
assert.equal((await db.query('select count(*)::int n from order_items where order_id=$1', [variantCreated.order_id])).rows[0].n, 2);
assert.equal((await db.query(`select kitchen_status from order_items where id=$1`, [plainLine.id])).rows[0].kitchen_status, 'preparing');
assert.equal((await db.query('select count(*)::int n from print_jobs where order_id=$1', [variantCreated.order_id])).rows[0].n, jobsBeforeCancel);
const cancelTicket = [{order_item_id: plainLine.id, product_id:'soup', name:'Corba', quantity:2, price:10, station_id:station, item_note:'az tuz'}];
const cancelled = (await db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,'[]'::jsonb,'add_item',$4::jsonb,'cancel_item','edit-cancel-ok',$5,'Fixture') result`,
  [owner, variantCreated.order_id, JSON.stringify(keptOnly), JSON.stringify(cancelTicket), staff])).rows[0].result;
assert.equal(cancelled.print_job_count, 1);
const remaining = (await db.query('select id, kitchen_status, quantity from order_items where order_id=$1', [variantCreated.order_id])).rows;
assert.equal(remaining.length, 1);
assert.equal(remaining[0].id, extraLine.id);
assert.equal(remaining[0].kitchen_status, 'ready');
const cancelJob = (await db.query(`select job_type, station_id::text station_id, payload->'items' items from print_jobs where id=$1::uuid`, [cancelled.print_job_ids[0]])).rows[0];
assert.equal(cancelJob.job_type, 'cancel_item');
assert.equal(cancelJob.station_id, station);
assert.equal(cancelJob.items.length, 1);
assert.equal(cancelJob.items[0].product_id, 'soup');
assert.equal(cancelJob.items[0].quantity, 2);
assert.equal(cancelJob.items[0].order_item_id, plainLine.id);
assert.equal(cancelJob.items[0].station_id, station);
assert.equal((await db.query(`select id from order_items where id=$1`, [plainLine.id])).rows.length, 0);
await assert.rejects(db.query(`select update_restaurant_table_order($1,$2,'[]'::jsonb,'[]'::jsonb,'add_item','[]'::jsonb,'cancel_item','edit-empty',$3,null) result`, [owner, orderId, staff]), /boş/);
assert.equal((await db.query('select quantity from order_items where order_id=$1', [orderId])).rows[0].quantity, 2);
await db.exec(`update store_sub_admins set permissions=array['viewOrders'] where auth_user_id='${staff}'`);
await assert.rejects(update('edit-denied'), /yetkiniz/);
assert.equal((await db.query('select quantity from order_items where order_id=$1', [orderId])).rows[0].quantity, 2);
const other = '10000000-0000-0000-0000-000000000002';
const otherBranch = '30000000-0000-0000-0000-000000000002';
const otherTable = '40000000-0000-0000-0000-000000000002';
const foreignStation = '50000000-0000-0000-0000-000000000002';
await db.exec(`reset role; select set_config('request.jwt.claim.sub','',false); select set_config('request.jwt.claim.role','',false);`);
await db.exec(`insert into auth.users(id,email) values('${other}','other@example.test');
 insert into stores(seller_id,business_name) values('${other}','Other');
 insert into store_branches(id,store_id,status) values('${otherBranch}','${owner}','active');
 insert into store_tables(id,seller_id,table_number,is_active,branch_id) values('${otherTable}','${owner}',2,true,'${otherBranch}');
 insert into stations(id,restaurant_id,name,code,is_active) values('${foreignStation}','${other}','Foreign','F',true);`);
await actor(other);
await assert.rejects(update('edit-other'), /yetkiniz|bulunamadı/);
await db.exec(`update store_sub_admins set permissions=array['viewOrders','manageOrders'], branch_id='${otherBranch}' where auth_user_id='${staff}'`);
await actor(staff);
await assert.rejects(update('edit-branch'), /şubede/);
await db.exec(`update store_sub_admins set branch_id='${branch}' where auth_user_id='${staff}'`);
const foreignItems = [{product_id:'soup',name:'Corba',quantity:1,price:10,station_id:foreignStation}];
await assert.rejects(db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,'[]'::jsonb,'add_item','[]'::jsonb,'cancel_item','edit-station',$4,null)`,
  [owner, orderId, JSON.stringify(foreignItems), staff]), /İstasyon/);
const deliveryId = '70000000-0000-0000-0000-000000000001';
await db.exec(`reset role; select set_config('request.jwt.claim.sub','',false); select set_config('request.jwt.claim.role','',false);`);
await db.exec(`select set_config('ibul.marketplace_order_rpc','on',true);
 insert into orders(id,restaurant_id,order_type,order_number,subtotal_amount,total_amount)
 values('${deliveryId}','${owner}','delivery','WEB-1',40,40);
 insert into order_items(order_id,product_name,quantity,unit_price,total_price) values('${deliveryId}','Paket',1,40,40);
 select set_config('ibul.marketplace_order_rpc','',true);`);
await actor(staff);
await assert.rejects(db.query(`select update_restaurant_table_order($1,$2,$3::jsonb,'[]'::jsonb,'add_item','[]'::jsonb,'cancel_item','edit-delivery',$4,null)`,
  [owner, deliveryId, JSON.stringify(nextItems), staff]), /masa siparişi/);
assert.equal((await db.query('select product_name from order_items where order_id=$1', [deliveryId])).rows[0].product_name, 'Paket');
assert.equal(Number((await db.query('select total_amount from orders where id=$1', [deliveryId])).rows[0].total_amount), 40);
const acl = (await db.query(`select
 has_function_privilege('anon', 'public.update_restaurant_table_order(uuid,uuid,jsonb,jsonb,text,jsonb,text,text,uuid,text)', 'execute') anon_exec,
 has_function_privilege('public', 'public.update_restaurant_table_order(uuid,uuid,jsonb,jsonb,text,jsonb,text,text,uuid,text)', 'execute') public_exec,
 has_function_privilege('authenticated', 'public.update_restaurant_table_order(uuid,uuid,jsonb,jsonb,text,jsonb,text,text,uuid,text)', 'execute') auth_exec,
 prosecdef, proconfig
 from pg_proc where proname='update_restaurant_table_order'`)).rows[0];
assert.equal(acl.anon_exec, false);
assert.equal(acl.public_exec, false);
assert.equal(acl.auth_exec, true);
assert.equal(acl.prosecdef, true);
assert.match(String(acl.proconfig), /search_path=public/);
await db.exec('begin');
await db.exec('drop function public.update_restaurant_table_order(uuid,uuid,jsonb,jsonb,text,jsonb,text,text,uuid,text)');
await assert.rejects(update('edit-dropped'), /update_restaurant_table_order/);
await db.exec('rollback');
const stillThere = (await update('edit-1')).rows[0].result;
assert.equal(stillThere.idempotent_replay, true);
assert.equal((await db.query('select count(*)::int n from orders')).rows[0].n, ordersBefore + 2);
const createStill = (await db.query(`select create_table_order_with_print_jobs_impl($1,1,$2::jsonb,$3,'Fixture',null,'new_order','table','after-rollback') result`,
  [owner, JSON.stringify([{product_id:'soup',name:'Corba',quantity:1,price:10,station_id:station}]), staff])).rows[0].result;
assert.ok(createStill.order_id);
const mixA = [{label:'Tabak 2', items:[{name:'Ciğer Dürüm', quantity:1, note:'acı'},{name:'Ciğer Servis', quantity:1}]}];
const mixB = [{label:'Tabak 3', items:[{name:'Beyti Kebap', quantity:1},{name:'Ciğer Dürüm', quantity:2, note:'soğansız'}]}];
const mixedItems = [
  {product_id:'mix', name:'Karışık Servis', quantity:1, price:100, station_id:station, plates:mixA, child_items:[{product_name:'Ciğer Dürüm', quantity:1, service_round:2, note:'acı'}]},
  {product_id:'mix', name:'Karışık Servis', quantity:1, price:120, station_id:station, plates:mixB, child_items:[{product_name:'Beyti Kebap', quantity:1, service_round:3}]},
];
const mixedOrder = (await db.query(`select create_table_order_with_print_jobs_impl($1,1,$2::jsonb,$3,'Fixture',null,'new_order','table','create-mix') result`,
  [owner, JSON.stringify(mixedItems), staff])).rows[0].result;
const mixedPayload = (await db.query(`select payload->'items' items from print_jobs where order_id=$1 and job_type='new_order'`, [mixedOrder.order_id])).rows[0].items;
assert.equal(mixedPayload.length, 2);
assert.equal(mixedPayload[0].plates[0].label, 'Tabak 2');
assert.equal(mixedPayload[0].plates[0].items[0].name, 'Ciğer Dürüm');
assert.equal(mixedPayload[0].plates[0].items[0].quantity, 1);
assert.equal(mixedPayload[0].plates[0].items[0].note, 'acı');
assert.equal(mixedPayload[0].plates[0].items[1].name, 'Ciğer Servis');
assert.equal(mixedPayload[1].plates[0].label, 'Tabak 3');
assert.equal(mixedPayload[1].plates[0].items[1].quantity, 2);
assert.equal(Number(mixedPayload[0].unit_price), 100);
assert.equal(Number(mixedPayload[1].unit_price), 120);
const stored = (await db.query(`select attributes from order_items where order_id=$1 order by unit_price`, [mixedOrder.order_id])).rows;
assert.equal(stored[0].attributes.kitchen_plates[0].label, 'Tabak 2');
assert.equal(stored[1].attributes.child_items[0].product_name, 'Beyti Kebap');
console.log('PASS: totals, revision replay, tenant/branch/station denial, table-only, ACL, rollback compatibility.');
await db.close();
