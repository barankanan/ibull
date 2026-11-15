// Behavioral audit. FAIL rows deliberately keep the release gate red.
import {readFile,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const {PGlite}=await import(process.env.IBUL_PGLITE_MODULE || '@electric-sql/pglite');
const db=new PGlite();
const read=(p)=>readFile(new URL(p,import.meta.url),'utf8');
const evidence=new URL('../../../docs/preprod/restaurant_security_20261030/',import.meta.url);
const result=[];
const test=async(name,fn)=>{try {await fn();result.push({name,status:'PASS'});} catch(e){result.push({name,status:'FAIL',detail:e.message});}};
const owner='10000000-0000-0000-0000-000000000001',foreign='10000000-0000-0000-0000-000000000002';
const managed='20000000-0000-0000-0000-000000000001',legacy='20000000-0000-0000-0000-000000000002';
const contact='20000000-0000-0000-0000-000000000003';
const branch='30000000-0000-0000-0000-000000000001',branch2='30000000-0000-0000-0000-000000000002';
const table='40000000-0000-0000-0000-000000000001',table2='40000000-0000-0000-0000-000000000002',foreignTable='40000000-0000-0000-0000-000000000003';
const station='50000000-0000-0000-0000-000000000001';
await db.exec(await read('restaurant_operations_fixture.sql'));
await db.exec(`create function user_can_access_restaurant(uuid) returns boolean language sql as $$select false$$;
 create function is_order_owner(uuid,uuid) returns boolean language sql security definer as $$select exists(select 1 from orders where id=$1 and user_id=$2)$$;
 create function can_access_order_as_seller(uuid,uuid) returns boolean language sql security definer as $$select exists(select 1 from order_items where order_id=$1 and seller_id=$2)$$;
 create function is_ihiz_courier_user(uuid) returns boolean language sql as $$select false$$;`);
// Replay historical policy EXPRESSIONS. Historical export omitted roles and
// permissive flags: roles are authenticated here; this is not a full live clone.
const policies=JSON.parse(await readFile(new URL('historical_policies.json',evidence),'utf8')).rows;
for (const p of policies.filter(p=>['orders','order_items','print_jobs','table_orders'].includes(p.tablename))) {
 await db.exec(`alter table ${p.tablename} enable row level security;
 create policy "${p.policyname}" on ${p.tablename} for ${p.cmd} to authenticated
 ${p.qual===null?'':`using(${p.qual})`} ${p.with_check===null?'':`with check(${p.with_check})`};`);
}
await db.exec(await read('../migrations/2026102901_restaurant_staff_access.sql'));
await db.exec(await read('../migrations/2026102902_restaurant_order_commit.sql'));
const wrapper=JSON.parse(await readFile(new URL('historical_source.json',evidence),'utf8')).rows.find(p=>p.proname==='create_table_order_with_print_jobs');
await db.exec(`create function create_table_order_with_print_jobs(p_restaurant_id uuid,p_table_number integer,p_items jsonb,p_waiter_id uuid default null,p_waiter_name text default null,p_notes text default null,p_job_type text default 'new_order',p_order_type text default 'table',p_local_order_id text default null) returns jsonb language plpgsql security definer set search_path=public as $body$${wrapper.prosrc}$body$`);
await db.exec(`insert into auth.users(id,email,email_confirmed_at,raw_app_meta_data) values
 ('${owner}','owner@example.test',now(),'{}'),('${foreign}','foreign@example.test',now(),'{}'),
 ('${managed}','managed@example.test',now(),'{"managed_restaurant_staff":true}'),('${legacy}','legacy@example.test',now(),'{}'),('${contact}','contact@example.test',now(),'{}');
 insert into users(id,email) select id,email from auth.users;
 insert into stores(seller_id) values('${owner}'),('${foreign}');
 update stores set business_name='Fixture';
 insert into store_branches(id,store_id,status) values('${branch}','${owner}','active'),('${branch2}','${owner}','active');
 insert into store_tables(id,seller_id,table_number,is_active,branch_id) values
 ('${table}','${owner}',1,true,'${branch}'),('${table2}','${owner}',2,true,'${branch2}'),('${foreignTable}','${foreign}',1,true,null);
 insert into stations(id,restaurant_id,name,is_active) values('${station}','${owner}','Kitchen',true);
 insert into finance_income_records(seller_id,net_amount) values('${owner}',123);
 insert into store_sub_admins(store_id,auth_user_id,email,status,permissions,branch_id) values
 ('${owner}','${managed}','managed@example.test','active',array['viewOrders','manageOrders'],'${branch}'),
 ('${owner}','${legacy}','legacy@example.test','active',array['viewOrders','manageOrders'],'${branch}'),
 ('${owner}',null,'contact@example.test','active',array['viewOrders','manageOrders'],'${branch}');`);
const actor=async(id)=>db.exec(`reset role; select set_config('request.jwt.claim.sub','${id}',false); select set_config('request.jwt.claim.role','authenticated',false); set role authenticated;`);
const root=()=>db.exec('reset role');
const scalar=async(sql,args)=>(await db.query(sql,args)).rows[0];
const submit=async(tenant,num,key,who=managed,fn='create_table_order_with_print_jobs_impl')=>
 (await scalar(`select ${fn}($1,$2,$3::jsonb,$4,'Fixture',null,'new_order','table',$5) r`,
 [tenant,num,JSON.stringify([{name:'Soup',quantity:1,price:10,station_id:tenant===owner?station:null}]),who,key])).r;
const seed={};
await actor(owner);
await test('finance owner positive control',async()=>assert.equal((await scalar('select finance_get_overview($1) r',[owner])).r,'123'));
for (const who of [managed,legacy,contact]) {await actor(who);seed[who]=await submit(owner,1,`own-${who}`,who);}
await actor(owner);seed.branch2=await submit(owner,2,'secret-branch2',owner);
await actor(foreign);seed.foreign=await submit(foreign,1,'foreign',foreign);
await root();
for(const [key,s] of Object.entries(seed)) await db.query('insert into table_orders(seller_id,table_number,items) values($1,$2,$3)',[key==='foreign'?foreign:owner,key==='branch2'?2:1,'[]']);
// Denials must be real 42501 (not a parser/undefined-column error).
const denied=async(sql,args)=>{
 try {const r=await db.query(sql,args);assert.equal(r.rows.length,0,`Access succeeded: ${r.rows.length} row(s)`);}
 catch(e){if(e.code!=='42501' && !(e.code==='P0001' && e.message==='ORDERS_INSERT_RPC_ONLY'))throw e;}
};
// Every mutation runs in a rolled-back transaction to preserve seeded targets.
const deniedInsert=async(sql,args)=>{
 try {await db.query(sql.replace(/ returning id$/,''),args);}
 catch(e){if(e.code==='42501'||(e.code==='P0001'&&e.message==='ORDERS_INSERT_RPC_ONLY'))return;throw e;}
 assert.fail('INSERT succeeded without RETURNING');
};
const isolated=async(fn)=>{await db.exec('begin');try {await fn();}finally {await db.exec('rollback');}};
for(const who of [managed,legacy,contact]) {
 await actor(who);
 await test(`${who===managed?'managed':'legacy'} active own-branch positive control`,async()=>assert.ok((await db.query('select id from orders where id=$1',[seed[who].order_id])).rows.length));
}
await root();await db.exec("update store_sub_admins set status='inactive'");
for(const [label,who] of [['managed inactive',managed],['legacy inactive',legacy],['legacy contact inactive',contact]]) {
 await actor(who); // Same identity as before revocation. No JWT refresh required.
 for(const [t,filter,params] of [
  ['orders','id=$1',[seed[who].order_id]],['order_items','order_id=$1',[seed[who].order_id]],
  ['print_jobs','order_id=$1',[seed[who].order_id]],['table_orders','seller_id=$1',[owner]]]) {
  for(const [op,sql] of [
   ['SELECT',`select * from ${t} where ${filter}`],
   ['UPDATE',`update ${t} set ${t==='orders'?"notes='blocked'":t==='order_items'?'quantity=99':"status='completed'"} where ${filter} returning id`],
   ['DELETE',`delete from ${t} where ${filter} returning id`]])
   await test(`${label} ${t} ${op}`,()=>isolated(()=>denied(sql,params)));
 }
 for(const [t,sql,args] of [
  ['orders','insert into orders(user_id,restaurant_id,table_id) values($1,$2,$3) returning id',[who,owner,table]],
  ['order_items','insert into order_items(order_id,quantity) values($1,1) returning id',[seed[who].order_id]],
  ['table_orders',"insert into table_orders(seller_id,table_number,items) values($1,1,'[]') returning id",[owner]],
  ['print_jobs',"insert into print_jobs(restaurant_id,order_id,status) values($1,$2,'pending') returning id",[owner,seed[who].order_id]]])
   await test(`${label} ${t} INSERT`,()=>isolated(()=>deniedInsert(sql,args)));
 for(const fn of ['create_table_order_with_print_jobs','create_table_order_with_print_jobs_impl'])
  await test(`${label} RPC ${fn}`,()=>assert.rejects(submit(owner,1,'inactive',who,fn),e=>e.code==='42501'));
 await test(`${label} RPC close_table_with_history`,()=>assert.rejects(db.query('select close_table_with_history($1,1)',[owner]),e=>e.code==='42501'));
 await test(`${label} RPC get_my_staff_access`,async()=>assert.equal((await scalar('select get_my_staff_access() r')).r,null));
 await test(`${label} RPC finance_get_overview`,async()=>assert.equal((await scalar('select finance_get_overview($1) r',[owner])).r,null));
}
await root();await db.exec("update store_sub_admins set status='active'");
for(const [label,who] of [['managed branch',managed],['legacy branch',legacy],['legacy contact branch',contact]]) {
 await actor(who);
 for(const [scope,tenant,order,number] of [['other branch',owner,seed.branch2.order_id,2],['foreign tenant',foreign,seed.foreign.order_id,1]]) {
  for(const [t,filter,args] of [['orders','id=$1',[order]],['order_items','order_id=$1',[order]],['print_jobs','order_id=$1',[order]],['table_orders','seller_id=$1 and table_number=$2',[tenant,number]]])
   for(const [op,sql] of [['SELECT',`select * from ${t} where ${filter}`],['UPDATE',`update ${t} set ${t==='orders'?"notes='bad'":t==='order_items'?'quantity=99':"status='completed'"} where ${filter} returning id`],['DELETE',`delete from ${t} where ${filter} returning id`]])
    await test(`${label} ${scope} ${t} ${op}`,()=>isolated(()=>denied(sql,args)));
  await test(`${label} ${scope} RPC create`,()=>assert.rejects(submit(tenant,number,`${label}-${scope}`,who),e=>e.code==='42501'));
  await test(`${label} ${scope} RPC close`,()=>assert.rejects(db.query('select close_table_with_history($1,$2)',[tenant,number]),e=>e.code==='42501'));
  for(const [t,sql,args] of [
   ['table_orders',"insert into table_orders(seller_id,table_number,items) values($1,$2,'[]') returning id",[tenant,number]],
   ['print_jobs',"insert into print_jobs(restaurant_id,order_id,status) values($1,$2,'pending') returning id",[tenant,order]],
   ['order_items','insert into order_items(order_id,quantity) values($1,1) returning id',[order]]])
   await test(`${label} ${scope} ${t} INSERT`,()=>isolated(()=>deniedInsert(sql,args)));
 }
 await test(`${label} other branch idempotent replay`,()=>assert.rejects(submit(owner,2,'secret-branch2',who),e=>e.code==='42501'));
}
await root();
// A bad pre-existing station mapping must not expose another business's printer.
await db.exec(`insert into printers(id,restaurant_id,name,is_active) values('${foreignTable}','${foreign}','Foreign printer',true);
 insert into station_printers(station_id,printer_id,is_primary) values('${station}','${foreignTable}',true);`);
await actor(managed);
await test('RPC rejects foreign printer behind own station mapping',async()=>{
 const before=(await scalar('select count(*)::int n from orders')).n;
 await assert.rejects(submit(owner,1,'corrupt-printer-map',managed),e=>e.code==='42501');
 assert.equal((await scalar('select count(*)::int n from orders')).n,before);
});
await root();
// Additional regression controls; all original 173 scenarios above remain.
await db.exec(`delete from station_printers; alter table store_sub_admins enable row level security;
 create policy fixture_legacy_self_update on store_sub_admins for all to authenticated using(true) with check(true);`);
for(const who of [managed,legacy,contact]) {
 await actor(who);
 await test(`self escalation denied ${who}`,()=>isolated(()=>denied(
   "update store_sub_admins set permissions=array['manageOrders','viewFinance'] where store_id=$1 returning id",[owner])));
 await test(`disguised own-table replay denied ${who}`,()=>assert.rejects(submit(owner,1,'secret-branch2',who),e=>e.code==='42501'));
 await test(`own replay retains exact print jobs ${who}`,async()=>{
   const r=await submit(owner,1,`own-${who}`,who);
   assert.equal(r.order_id,seed[who].order_id);assert.deepEqual(r.print_job_ids,seed[who].print_job_ids);
 });
}
await root();
await db.exec(`select set_config('request.jwt.claim.sub','',false); set role anon;`);
await test('anonymous QR customer table_orders INSERT preserved',()=>isolated(()=>db.query(
 "insert into table_orders(seller_id,table_number,items) values($1,1,'[]')",[owner])));
await root();
await actor(foreign);
await test('authenticated customer QR table_orders INSERT preserved',()=>isolated(()=>db.query(
 "insert into table_orders(seller_id,table_number,items) values($1,1,'[]')",[owner])));
await actor(owner);
await test('owner retains other-branch order access',async()=>assert.equal((await db.query('select id from orders where id=$1',[seed.branch2.order_id])).rows.length,1));
await root();
const ownPrinter='60000000-0000-0000-0000-000000000001';
await db.query('insert into printers(id,restaurant_id,name,is_active) values($1,$2,$3,true)',[ownPrinter,owner,'Own printer']);
await actor(owner);
for(const [label,values] of [
 ['foreign printer',{printer_id:foreignTable}],['foreign order',{order_id:seed.foreign.order_id}],
 ['foreign station',{station_id:foreignTable}],['payload mismatch',{payload:{restaurant_id:foreign}}],
 ['unmapped printer',{station_id:station,printer_id:ownPrinter}]
]) await test(`direct job rejects ${label}`,()=>isolated(()=>assert.rejects(db.query(
 'insert into print_jobs(restaurant_id,order_id,station_id,printer_id,job_type,status,payload) values($1,$2,$3,$4,$5,$6,$7)',
 [owner,values.order_id??seed[managed].order_id,values.station_id??null,values.printer_id??null,'new_order','pending',values.payload??{}]),e=>e.code==='42501')));
for(const status of ['claimed','printing','completed','failed']) {
 await test(`no automatic ${status} to pending`,()=>isolated(async()=>{
   await db.query('update print_jobs set status=$1 where order_id=$2',[status,seed[managed].order_id]);
   await assert.rejects(db.query("update print_jobs set status='pending' where order_id=$1",[seed[managed].order_id]),e=>e.code==='42501');
 }));
}
await test('authorized manual reprint requires fresh token',()=>isolated(async()=>{
 await db.query("update print_jobs set status='failed' where order_id=$1",[seed[managed].order_id]);
 const r=await db.query("update print_jobs set status='pending',payload=payload||'{\"manual_reprint_token\":\"reviewed-fixture\"}'::jsonb where order_id=$1 returning id",[seed[managed].order_id]);
 assert.equal(r.rows.length,1);
}));
await root();
await db.exec(`select set_config('ibul.marketplace_order_rpc','on',false);
 insert into orders(id,user_id,restaurant_id,notes) values
 ('70000000-0000-0000-0000-000000000001','${foreign}',null,'foreign-null'),
 ('70000000-0000-0000-0000-000000000002','${managed}',null,'own-null');
 create policy probe_null_restaurant_orders on orders for select to authenticated using(true);`);
await actor(managed);
await test('null restaurant_id does not open another user order',()=>isolated(()=>denied(
 'select * from orders where id=$1',['70000000-0000-0000-0000-000000000001'])));
await test('staff retains own null restaurant_id consumer order',async()=>assert.equal(
 (await db.query('select id from orders where id=$1',['70000000-0000-0000-0000-000000000002'])).rows.length,1));
await test('null restaurant_id order cannot be updated by staff',()=>isolated(()=>denied(
 "update orders set notes='hack' where id=$1 returning id",['70000000-0000-0000-0000-000000000001'])));
await test('null restaurant_id probe does not reveal foreign restaurant order',()=>isolated(()=>denied(
 'select * from orders where id=$1',[seed.foreign.order_id])));
await db.exec(`reset role; select set_config('request.jwt.claim.sub','',false); select set_config('request.jwt.claim.role','',false);`);
await db.exec('drop policy probe_null_restaurant_orders on orders');
const second='10000000-0000-0000-0000-000000000099';
const secondBranch='30000000-0000-0000-0000-000000000099';
const secondTable='40000000-0000-0000-0000-000000000099';
await db.exec(`insert into stores(seller_id,business_name) values('${second}','Second');
 insert into store_branches(id,store_id,status) values('${secondBranch}','${second}','active');
 insert into store_tables(id,seller_id,table_number,is_active,branch_id) values('${secondTable}','${second}',1,true,'${secondBranch}');
 insert into store_sub_admins(store_id,auth_user_id,email,status,permissions,branch_id,created_at) values
 ('${second}','${managed}','managed@example.test','active',array['manageOrders'],'${secondBranch}',now()+interval '1 minute');`);
await actor(managed);
await test('multi-store membership stays inside each restaurant and branch',async()=>{
 assert.equal((await scalar('select restaurant_has_permission($1,$2) r',[second,'manageOrders'])).r,true);
 assert.equal((await scalar('select restaurant_has_permission($1,$2) r',[foreign,'manageOrders'])).r,false);
 assert.equal((await scalar('select restaurant_table_access($1,$2) r',[owner,table2])).r,false);
 assert.equal((await scalar('select restaurant_table_access($1,$2) r',[second,secondTable])).r,true);
 const access=(await scalar('select get_my_staff_access() r')).r;
 const ids=access.memberships.map((m)=>m.store_id);
 assert.deepEqual(ids,[owner,second]);
});
await root();
await writeFile(new URL('access_results.json',evidence),JSON.stringify({scope:'Isolated PGlite; historical policy expressions; simulated Auth identity; no real JWT verification',results:result},null,2)+'\n');
for(const r of result) console.log(`${r.status} ${r.name}${r.detail?' :: '+r.detail:''}`);
console.log(`${result.filter(r=>r.status==='PASS').length} PASS / ${result.filter(r=>r.status==='FAIL').length} FAIL`);
await db.close();
if(result.some(r=>r.status==='FAIL'))process.exitCode=1;
