import {readFile, mkdir, writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {capture, rollbackSql} from './restaurant_rollback_snapshot.mjs';
const {PGlite} = await import(process.env.IBUL_PGLITE_MODULE || '@electric-sql/pglite');
const read = (p) => readFile(new URL(p,import.meta.url),'utf8');
const evidence = new URL('../../../docs/preprod/restaurant_security_20261030/',import.meta.url);
const historical = async (name) => JSON.parse(await readFile(new URL(`historical_${name}.json`, evidence),'utf8')).rows;
const source = await historical('source');
const auth = await historical('auth-rpcs');
for (const scenario of ['first-only','both-empty','both-printers','both-existing','all-tables','failure-between']) {
  const db = new PGlite();
  await db.exec(await read('restaurant_operations_fixture.sql'));
  // Restore historical function BODIES with explicit known signatures. These
  // artifacts do not include historical ACL/owner; those remain fixture values.
  const args = 'p_restaurant_id uuid,p_table_number integer,p_items jsonb,p_waiter_id uuid default null,p_waiter_name text default null,p_notes text default null,p_job_type text default \'new_order\',p_order_type text default \'table\',p_local_order_id text default null';
  for (const f of source) await db.exec(`create or replace function public.${f.proname}(${args}) returns jsonb language plpgsql security definer set search_path=public as $historical$${f.prosrc}$historical$`);
  for (const name of ['user_can_access_restaurant','activate_my_sub_admin_invites']) {
    const f = auth.find((r) => r.proname === name);
    await db.exec(`create function public.${name}(${name==='user_can_access_restaurant'?'p_restaurant_id uuid':''}) returns ${name==='user_can_access_restaurant'?'boolean':'integer'} language plpgsql security definer set search_path=public as $historical$${f.prosrc}$historical$`);
  }
  await db.exec(`create function finance_get_monthly_trend(uuid,integer) returns integer language sql security invoker as $$select 42$$;
    revoke all on function user_can_access_restaurant(uuid) from public;
    grant execute on function user_can_access_restaurant(uuid) to authenticated with grant option;
    comment on function user_can_access_restaurant(uuid) is 'baseline ACL/comment sentinel';
    alter table table_orders enable row level security;
    create policy "Anyone can insert" on table_orders for insert to anon with check(true);
    create policy table_orders_authenticated_all on table_orders for all to authenticated using(true) with check(true);
    create policy store_sub_admins_self_activate_update on store_sub_admins for update to authenticated using(true);
    create policy sentinel_restrictive on table_orders as restrictive for select to authenticated using(table_number>0);
    alter table print_jobs force row level security;
    insert into stores(seller_id,business_name) values('10000000-0000-0000-0000-000000000001','Rollback fixture');
    insert into printers(id,name,print_size) values('90000000-0000-0000-0000-000000000001','Unchanged printer','large');
    insert into print_jobs(id,status,payload) values('90000000-0000-0000-0000-000000000002','printing','{"uncertain":true}');`);
  if (scenario === 'both-printers') await db.exec('alter publication supabase_realtime add table printers;');
  if (scenario === 'both-existing') await db.exec('alter publication supabase_realtime add table printers,print_jobs;');
  if (scenario === 'all-tables') await db.exec('drop publication supabase_realtime; create publication supabase_realtime for all tables;');
  const before = await capture(db);
  if(scenario==='first-only') {
    await assert.rejects(db.exec(await read('../manual_patches/deprecated/2026102903_rollback_restaurant_operations.DO_NOT_RUN.sql')),/UNSAFE_ROLLBACK_DRAFT/);
    assert.deepEqual(await capture(db),before);
    console.log('PASS archived unsafe rollback refuses execution without catalog changes');
  }
  const data = async () => (await db.query(`select (select jsonb_agg(to_jsonb(t) order by id) from printers t) printers,
    (select jsonb_agg(to_jsonb(t) order by id) from print_jobs t) jobs`)).rows;
  const preData = await data();
  await db.exec(await read('../migrations/2026102901_restaurant_staff_access.sql'));
  if (scenario === 'failure-between') {
    // PostgreSQL transaction failure: the entire second migration rolls back.
    const broken = (await read('../migrations/2026102902_restaurant_order_commit.sql')).replace("notify pgrst, 'reload schema';", "select 1/0;");
    await assert.rejects(db.exec(broken), /division by zero/);
    await db.exec('rollback');
  } else if (scenario !== 'first-only') await db.exec(await read('../migrations/2026102902_restaurant_order_commit.sql'));
  // Data written AFTER migration must survive rollback too.
  await db.exec(`insert into print_jobs(id,restaurant_id,job_type,status,payload) values('90000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','test_receipt','completed','{"after_migration":true}')`);
  const expectedData = await data();
  const after = await capture(db);
  const sql = rollbackSql(before,after);
  assert.ok(!/\bcascade\b|drop column/i.test(sql));
  if(scenario==='first-only') {
    await db.exec('create policy unexpected_release_change on table_orders for select using(true)');
    await assert.rejects(db.exec(sql),/Rollback catalog drift: policies/);
    await db.exec('rollback');
    // Failure must be atomic: baseline migration function still exists.
    assert.ok((await db.query("select to_regprocedure('restaurant_has_permission(uuid,text)') f")).rows[0].f);
    await db.exec('drop policy unexpected_release_change on table_orders');
    console.log('PASS rollback drift: stale policy snapshot rejected atomically');
  }
  await db.exec(sql);
  assert.deepEqual(await capture(db), before, `Catalog mismatch: ${scenario}`);
  assert.deepEqual(await data(),expectedData, `Operational data loss: ${scenario}`);
  assert.equal(expectedData[0].jobs.length,preData[0].jobs.length+1);
  assert.equal((await db.query('select finance_get_monthly_trend(null,1) n')).rows[0].n,42);
  if (scenario==='both-existing') {
    await mkdir(evidence,{recursive:true});
    await writeFile(new URL('isolated_before.json',evidence),JSON.stringify(before,null,2)+'\n');
    await writeFile(new URL('isolated_after.json',evidence),JSON.stringify(after,null,2)+'\n');
    await writeFile(new URL('isolated_rollback.sql',evidence),sql);
  }
  console.log(`PASS rollback ${scenario}: exact catalog/ACL/policies/triggers/RLS/Realtime restored; operational rows retained`);
  await db.close();
}
