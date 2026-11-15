import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';

const { PGlite } = await import(process.env.IBUL_PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const read = (file) => readFile(new URL(file, import.meta.url), 'utf8');

console.log('--- 1. SETTING UP TEST DATABASE & MIGRATIONS ---');
await db.exec(await read('restaurant_operations_fixture.sql'));
await db.exec(await read('../migrations/2026102901_restaurant_staff_access.sql'));
await db.exec(await read('../migrations/2026102902_restaurant_order_commit.sql'));

// Enable RLS and permissive baseline buyer/seller policies on orders, order_items, table_orders, print_jobs
await db.exec(`
  alter table orders enable row level security;
  alter table order_items enable row level security;
  alter table table_orders enable row level security;
  alter table print_jobs enable row level security;

  create policy base_orders_access on orders for all to authenticated
    using (user_id = auth.uid() or restaurant_id = auth.uid() or public.user_can_access_restaurant(restaurant_id))
    with check (user_id = auth.uid() or restaurant_id = auth.uid() or public.user_can_access_restaurant(restaurant_id));

  create policy base_items_access on order_items for all to authenticated
    using (exists (select 1 from orders o where o.id = order_items.order_id and (o.user_id = auth.uid() or o.restaurant_id = auth.uid() or public.user_can_access_restaurant(o.restaurant_id))))
    with check (exists (select 1 from orders o where o.id = order_items.order_id and (o.user_id = auth.uid() or o.restaurant_id = auth.uid() or public.user_can_access_restaurant(o.restaurant_id))));

  create policy base_jobs_access on print_jobs for all to authenticated
    using (restaurant_id = auth.uid() or exists (select 1 from orders o where o.id = print_jobs.order_id and public.user_can_access_restaurant(o.restaurant_id)))
    with check (restaurant_id = auth.uid() or exists (select 1 from orders o where o.id = print_jobs.order_id and public.user_can_access_restaurant(o.restaurant_id)));
`);

// Identities
const ownerA = '10000000-0000-0000-0000-000000000001';
const ownerB = '10000000-0000-0000-0000-000000000002'; // Foreign restaurant
const activeWaiterA = '20000000-0000-0000-0000-000000000001'; // Active, Branch 1
const inactiveWaiterA = '20000000-0000-0000-0000-000000000002'; // Deactivated waiter
const branch1 = '30000000-0000-0000-0000-000000000001';
const branch2 = '30000000-0000-0000-0000-000000000002';
const table1 = '40000000-0000-0000-0000-000000000001'; // In Branch 1
const table2 = '40000000-0000-0000-0000-000000000002'; // In Branch 2
const stationA = '50000000-0000-0000-0000-000000000001';

await db.exec(`
  insert into auth.users(id, email, email_confirmed_at, raw_app_meta_data) values
    ('${ownerA}', 'ownera@example.test', now(), '{}'),
    ('${ownerB}', 'ownerb@example.test', now(), '{}'),
    ('${activeWaiterA}', 'active@example.test', now(), '{"managed_restaurant_staff":true}'),
    ('${inactiveWaiterA}', 'inactive@example.test', now(), '{"managed_restaurant_staff":true}');

  insert into users(id, email) values
    ('${ownerA}', 'ownera@example.test'),
    ('${ownerB}', 'ownerb@example.test'),
    ('${activeWaiterA}', 'active@example.test'),
    ('${inactiveWaiterA}', 'inactive@example.test');

  insert into stores(seller_id, business_name) values
    ('${ownerA}', 'Restaurant A'),
    ('${ownerB}', 'Restaurant B');

  insert into store_branches(id, store_id, status, name) values
    ('${branch1}', '${ownerA}', 'active', 'Branch 1'),
    ('${branch2}', '${ownerA}', 'active', 'Branch 2');

  insert into store_tables(id, seller_id, table_number, is_active, branch_id) values
    ('${table1}', '${ownerA}', 1, true, '${branch1}'),
    ('${table2}', '${ownerA}', 2, true, '${branch2}');

  insert into stations(id, restaurant_id, name, code, is_active) values
    ('${stationA}', '${ownerA}', 'Main Kitchen', 'KIT', true);

  -- Active waiter assigned to Branch 1
  insert into store_sub_admins(store_id, auth_user_id, email, status, permissions, branch_id) values
    ('${ownerA}', '${activeWaiterA}', 'active@example.test', 'active', array['viewOrders','manageOrders'], '${branch1}');

  -- Deactivated waiter (previously at Branch 1, now inactive)
  insert into store_sub_admins(store_id, auth_user_id, email, status, permissions, branch_id) values
    ('${ownerA}', '${inactiveWaiterA}', 'inactive@example.test', 'inactive', array['viewOrders','manageOrders'], '${branch1}');
`);

const actor = async (id) => db.exec(`select set_config('request.jwt.claim.sub','${id}',false); select set_config('request.jwt.claim.role','authenticated',false);`);
const check = async (sql) => (await db.query(sql)).rows[0].ok;

// Create an initial order with print job under Owner A
await actor(ownerA);
const orderSubmit = await db.query(
  `select create_table_order_with_print_jobs_impl($1, 1, $2::jsonb, $3, 'Owner A', null, 'new_order', 'table', 'order-seed') result`,
  [ownerA, JSON.stringify([{ product_id: 'prod-1', name: 'Pizza', quantity: 1, price: 50, station_id: stationA }]), ownerA]
);
const seedOrderId = orderSubmit.rows[0].result.order_id;
const seedPrintJobId = orderSubmit.rows[0].result.print_job_ids[0];
assert.ok(seedOrderId, 'Seed order created');
assert.ok(seedPrintJobId, 'Seed print job created');

console.log('--- 2. TESTING DEACTIVATED WAITER ACCESS ---');
await actor(inactiveWaiterA);

// 2.1 RPC access tests
assert.equal(await check(`select restaurant_has_permission('${ownerA}', 'manageOrders') ok`), false, 'Deactivated waiter must not have manageOrders');
assert.equal(await check(`select restaurant_has_permission('${ownerA}', 'viewOrders') ok`), false, 'Deactivated waiter must not have viewOrders');
assert.equal(await check(`select user_can_access_restaurant('${ownerA}') ok`), false, 'Deactivated waiter user_can_access_restaurant must be false');
assert.equal(await check(`select restaurant_table_access('${ownerA}', '${table1}') ok`), false, 'Deactivated waiter restaurant_table_access must be false');
assert.equal(await check(`select restaurant_table_number_access('${ownerA}', 1) ok`), false, 'Deactivated waiter restaurant_table_number_access must be false');
assert.equal((await db.query('select get_my_staff_access() res')).rows[0].res, null, 'get_my_staff_access must return null for inactive staff');

// create_table_order_with_print_jobs_impl RPC
await assert.rejects(
  db.query(`select create_table_order_with_print_jobs_impl($1, 1, $2::jsonb, $3, 'Deactivated', null, 'new_order', 'table', 'fail-inactive')`,
    [ownerA, JSON.stringify([{ product_id: 'p1', name: 'Soup', quantity: 1, price: 10, station_id: stationA }]), inactiveWaiterA]),
  /yetkiniz yok/,
  'create_table_order_with_print_jobs_impl must reject deactivated waiter'
);

// close_table_with_history RPC
await assert.rejects(
  db.query(`select close_table_with_history('${ownerA}', 1)`),
  /yetkisi yok/,
  'close_table_with_history must reject deactivated waiter'
);

// 2.2 Table RLS direct access tests (orders, order_items, table_orders, print_jobs)
await db.exec('set role authenticated');

// orders: SELECT must return 0
const ordersSelect = await db.query('select * from orders');
assert.equal(ordersSelect.rows.length, 0, 'Deactivated waiter SELECT orders must return 0 rows');

// orders: UPDATE must affect 0 rows (RLS blocks row visibility)
const ordersUpdate = await db.query(`update orders set notes = 'hacked' where id = '${seedOrderId}' returning id`);
assert.equal(ordersUpdate.rows.length, 0, 'Deactivated waiter UPDATE orders must affect 0 rows (RLS block)');

// orders: DELETE must affect 0 rows
const ordersDelete = await db.query(`delete from orders where id = '${seedOrderId}' returning id`);
assert.equal(ordersDelete.rows.length, 0, 'Deactivated waiter DELETE orders must affect 0 rows (RLS block)');

// orders: direct INSERT as restaurant staff must be blocked
await assert.rejects(
  db.query(`insert into orders (user_id, restaurant_id, table_id, order_number, status) values ('${inactiveWaiterA}', '${ownerA}', '${table1}', 'TBL-HACK', 'sent')`),
  /Personel sipariş yetkisi yok|ORDERS_INSERT_RPC_ONLY/,
  'Deactivated waiter direct INSERT orders must be blocked by trigger'
);

// order_items: SELECT must return 0
const itemsSelect = await db.query('select * from order_items');
assert.equal(itemsSelect.rows.length, 0, 'Deactivated waiter SELECT order_items must return 0 rows');

// order_items: UPDATE must affect 0 rows
const itemsUpdate = await db.query(`update order_items set quantity = 99 where order_id = '${seedOrderId}' returning id`);
assert.equal(itemsUpdate.rows.length, 0, 'Deactivated waiter UPDATE order_items must affect 0 rows');

// order_items: DELETE must affect 0 rows
const itemsDelete = await db.query(`delete from order_items where order_id = '${seedOrderId}' returning id`);
assert.equal(itemsDelete.rows.length, 0, 'Deactivated waiter DELETE order_items must affect 0 rows');

// order_items: direct INSERT must fail
await assert.rejects(
  db.query(`insert into order_items (order_id, product_name, quantity, unit_price) values ('${seedOrderId}', 'Hack', 1, 10)`),
  /Personel sipariş yetkisi yok|ORDERS_INSERT_RPC_ONLY/,
  'Deactivated waiter direct INSERT order_items must be blocked'
);

// table_orders: SELECT must return 0
const tableOrdersSelect = await db.query('select * from table_orders');
assert.equal(tableOrdersSelect.rows.length, 0, 'Deactivated waiter SELECT table_orders must return 0 rows');

// table_orders: UPDATE must affect 0 rows
const tableOrdersUpdate = await db.query(`update table_orders set last_edit_note = 'hacked' where seller_id = '${ownerA}' returning id`);
assert.equal(tableOrdersUpdate.rows.length, 0, 'Deactivated waiter UPDATE table_orders must affect 0 rows');

// table_orders: DELETE must affect 0 rows
const tableOrdersDelete = await db.query(`delete from table_orders where seller_id = '${ownerA}' returning id`);
assert.equal(tableOrdersDelete.rows.length, 0, 'Deactivated waiter DELETE table_orders must affect 0 rows');

// table_orders: INSERT must fail
await assert.rejects(
  db.query(`insert into table_orders (seller_id, table_number, items) values ('${ownerA}', 1, '[]'::jsonb)`),
  /Personel sipariş yetkisi yok/,
  'Deactivated waiter INSERT table_orders must be blocked'
);

// print_jobs: SELECT must return 0
const printJobsSelect = await db.query('select * from print_jobs');
assert.equal(printJobsSelect.rows.length, 0, 'Deactivated waiter SELECT print_jobs must return 0 rows');

// print_jobs: UPDATE must affect 0 rows
const printJobsUpdate = await db.query(`update print_jobs set status = 'completed' where id = '${seedPrintJobId}' returning id`);
assert.equal(printJobsUpdate.rows.length, 0, 'Deactivated waiter UPDATE print_jobs must affect 0 rows');

// print_jobs: DELETE must affect 0 rows
const printJobsDelete = await db.query(`delete from print_jobs where id = '${seedPrintJobId}' returning id`);
assert.equal(printJobsDelete.rows.length, 0, 'Deactivated waiter DELETE print_jobs must affect 0 rows');

// print_jobs: INSERT must fail
await assert.rejects(
  db.query(`insert into print_jobs (restaurant_id, order_id, status) values ('${ownerA}', '${seedOrderId}', 'pending')`),
  /Personel sipariş yetkisi yok/,
  'Deactivated waiter INSERT print_jobs must be blocked'
);

await db.exec('reset role');

console.log('--- 3. TESTING BRANCH ISOLATION ---');
await actor(activeWaiterA);

// Active waiter is assigned to Branch 1.
// Access to Table 1 (Branch 1) -> must succeed
assert.equal(await check(`select restaurant_table_access('${ownerA}', '${table1}') ok`), true, 'Waiter in Branch 1 must have access to Table 1');
assert.equal(await check(`select restaurant_table_number_access('${ownerA}', 1) ok`), true, 'Waiter in Branch 1 must have access to Table number 1');

const branch1Order = await db.query(
  `select create_table_order_with_print_jobs_impl($1, 1, $2::jsonb, $3, 'Active Waiter', null, 'new_order', 'table', 'branch1-order') result`,
  [ownerA, JSON.stringify([{ product_id: 'p1', name: 'Salad', quantity: 1, price: 20, station_id: stationA }]), activeWaiterA]
);
assert.ok(branch1Order.rows[0].result.order_id, 'Order on Table 1 (Branch 1) must succeed');

// Access to Table 2 (Branch 2) -> MUST BE BLOCKED
assert.equal(await check(`select restaurant_table_access('${ownerA}', '${table2}') ok`), false, 'Waiter in Branch 1 must NOT have access to Table 2 (Branch 2)');
assert.equal(await check(`select restaurant_table_number_access('${ownerA}', 2) ok`), false, 'Waiter in Branch 1 must NOT have access to Table number 2 (Branch 2)');

await assert.rejects(
  db.query(
    `select create_table_order_with_print_jobs_impl($1, 2, $2::jsonb, $3, 'Active Waiter', null, 'new_order', 'table', 'branch2-order')`,
    [ownerA, JSON.stringify([{ product_id: 'p1', name: 'Salad', quantity: 1, price: 20, station_id: stationA }]), activeWaiterA]
  ),
  /şubede işlem yetkiniz yok/,
  'create_table_order_with_print_jobs_impl on other branch must be rejected'
);

await assert.rejects(
  db.query(`select close_table_with_history('${ownerA}', 2)`),
  /yetkisi yok/,
  'close_table_with_history on other branch must be rejected'
);

// Direct table_orders write on Table 2 by Branch 1 waiter must fail branch guard
await db.exec('set role authenticated');
await assert.rejects(
  db.query(`insert into table_orders (seller_id, table_number, items) values ('${ownerA}', 2, '[]'::jsonb)`),
  /Personel sipariş yetkisi yok/,
  'table_orders write on foreign branch must be rejected'
);
await db.exec('reset role');

console.log('--- 4. TESTING CROSS-TENANT / CROSS-RESTAURANT ISOLATION ---');
await actor(activeWaiterA);

// Waiter in Restaurant A attempting access to Restaurant B
assert.equal(await check(`select restaurant_has_permission('${ownerB}', 'manageOrders') ok`), false, 'Staff of Rest A cannot have manageOrders on Rest B');
assert.equal(await check(`select restaurant_has_permission('${ownerB}', 'viewOrders') ok`), false, 'Staff of Rest A cannot have viewOrders on Rest B');
assert.equal(await check(`select user_can_access_restaurant('${ownerB}') ok`), false, 'Staff of Rest A cannot access Rest B');

await assert.rejects(
  db.query(
    `select create_table_order_with_print_jobs_impl($1, 1, $2::jsonb, $3, 'Active Waiter', null, 'new_order', 'table', 'restb-order')`,
    [ownerB, JSON.stringify([{ product_id: 'p1', name: 'Soup', quantity: 1, price: 15, station_id: stationA }]), activeWaiterA]
  ),
  /Bu restoran için işlem yetkiniz yok/,
  'Order creation on foreign restaurant must be rejected'
);

await assert.rejects(
  db.query(`select close_table_with_history('${ownerB}', 1)`),
  /yetkisi yok/,
  'close_table_with_history on foreign restaurant must be rejected'
);

// Cross-tenant data inspection
await db.exec('set role authenticated');
const crossOrders = await db.query(`select * from orders where restaurant_id = '${ownerB}'`);
assert.equal(crossOrders.rows.length, 0, 'Cannot read orders of foreign restaurant');
await db.exec('reset role');

console.log('PASS: original deactivation/branch/tenant fixture matrix. Rollback is tested separately by restaurant_rollback_test.mjs.');
await db.close();
