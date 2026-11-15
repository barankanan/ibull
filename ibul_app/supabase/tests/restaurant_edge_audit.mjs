// Execute actual Edge handlers + shared Auth helper offline with mocked Auth/REST.
// No Deno listener, credentials, network, Auth creation or deployment.
import {readFile,writeFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import assert from 'node:assert/strict';
const {PGlite}=await import(process.env.IBUL_PGLITE_MODULE || '@electric-sql/pglite');
const db=new PGlite();
const read=(p)=>readFile(new URL(p,import.meta.url),'utf8');
const owner='10000000-0000-0000-0000-000000000001',foreign='10000000-0000-0000-0000-000000000002',inactive='20000000-0000-0000-0000-000000000001';
let currentHandler, writes=0, forwarded=[];
const results=[];
const test=async(name,fn)=>{try{await fn();results.push({name,status:'PASS'});}catch(e){results.push({name,status:'FAIL',detail:e.message});}};
// Exercise the repository's real seller access SQL, not an always-deny RPC mock.
const sellerSource=await read('../../SUPABASE_SELLER_ORDER_MANAGEMENT.sql');
await db.exec(`create schema seller_ops; create table seller_ops.sellers(id uuid,owner_user_id uuid);
 create table seller_ops.orders(id uuid,seller_id uuid,status text,buyer_user_id uuid,order_no text);
 insert into seller_ops.sellers values('${owner}','${owner}'),('${foreign}','${foreign}');
 insert into seller_ops.orders values('${owner}','${owner}','NEW',null,'fixture');
 create function seller_ops.is_valid_order_transition(text,text) returns boolean language sql as $$select true$$;
 create function seller_ops.log_order_transition(uuid,uuid,text,text,text,text) returns void language sql as $$select$$;
 create function seller_ops.create_notification(uuid,text,text,text,jsonb) returns void language sql as $$select$$;`);
for(const name of ['current_seller_id','assert_seller_access','seller_accept_order']) {
 const start=sellerSource.indexOf(`create or replace function seller_ops.${name}(`);
 const end=sellerSource.indexOf('$$;',sellerSource.indexOf('as $$',start))+3;
 assert.ok(start>=0&&end>start);await db.exec(sellerSource.slice(start,end));
}
const serviceClient={
 from(table){
  const filters={};let op='select';
  const query={select(){return query;},eq(k,v){filters[k]=v;return query;},update(){op='update';return query;},
   async maybeSingle(){
    if(table==='stores')return {data:filters.seller_id===owner||filters.seller_id===foreign?{seller_id:filters.seller_id}:null,error:null};
    if(table==='store_branches')return {data:filters.store_id===owner&&filters.id==='own-branch'?{id:'own-branch'}:null,error:null};
    return {data:null,error:null};
   },async single(){
    if(op==='update'&&filters.store_id===owner&&filters.id==='own-member'){writes++;return {data:{id:'own-member'},error:null};}
    return {data:null,error:{message:'no matching row'}};
   }};return query;
 },
 async rpc(name,params){
  forwarded.push({name,params});
  if(name==='seller_ops.seller_accept_order'){
   try{return {data:(await db.query('select seller_ops.seller_accept_order($1,$2) r',[params.p_actor_user_id,params.p_order_id])).rows[0].r,error:null};}
   catch(e){return {data:null,error:{message:e.message}};}
  }
  // create_order is a legacy buyer endpoint. Missing full seller_ops clone is
  // an explicit limitation, not permission to invent a security PASS.
  return {data:null,error:{message:'ISOLATED_SELLER_OPS_CREATE_NOT_AVAILABLE'}};
 }
};
globalThis.__edgeCreateClient=(_url,key,options)=>key==='fake-service'?serviceClient:{auth:{async getUser(){
 const token=options.global.headers.Authorization.slice(7);
 return ['expired',''].includes(token)?{data:{user:null},error:{message:'invalid'}}:{data:{user:{id:token}},error:null};
}}};
globalThis.Deno={env:{get:(k)=>({SUPABASE_URL:'http://localhost.invalid',SUPABASE_ANON_KEY:'fake-anon',SUPABASE_SERVICE_ROLE_KEY:'fake-service'})[k]},serve:(fn)=>{currentHandler=fn;}};
const dataUrl=(s)=>'data:text/javascript;base64,'+Buffer.from(s).toString('base64');
const shared=(await read('../functions/_shared/http.ts')).replace(/import .* from 'jsr:.*';/,'const createClient=globalThis.__edgeCreateClient;');
const sharedUrl=dataUrl(stripTypeScriptTypes(shared,{mode:'transform'}));
const load=async(name)=>{
 const source=(await read(`../functions/${name}/index.ts`)).replace("'../_shared/http.ts'",JSON.stringify(sharedUrl));
 await import(dataUrl(stripTypeScriptTypes(source,{mode:'transform'})));
};
const request=(id,body)=>currentHandler(new Request('http://localhost.invalid',{method:'POST',headers:id?{Authorization:`Bearer ${id}`}: {},body:JSON.stringify(body)}));
await load('manage-restaurant-staff');
for(const operation of ['create','permissions','deactivate'])await test(`manage-restaurant-staff inactive ${operation}`,async()=>{
 const before=writes;assert.equal((await request(inactive,{operation,id:'own-member'})).status,403);assert.equal(writes,before);
});
for(const operation of ['permissions','deactivate'])await test(`manage-restaurant-staff owner foreign member ${operation}`,async()=>{
 const before=writes;assert.equal((await request(owner,{operation,id:'foreign-member',permissions:[]})).status,400);assert.equal(writes,before);
});
await test('manage-restaurant-staff owner foreign branch create',async()=>assert.equal((await request(owner,{operation:'create',name:'Fixture',email:'fixture@example.test',password:'dummy-password-123',staff_role:'waiter',permissions:[],request_id:'fixture',branch_id:'foreign-branch'})).status,400));
await test('manage-restaurant-staff owner own member positive control',async()=>assert.equal((await request(owner,{operation:'deactivate',id:'own-member'})).status,200));
for(const name of ['manage-restaurant-staff','seller_accept_order','create_order']) {
 await load(name);
 for(const token of [null,'expired'])await test(`${name} ${token||'missing'} token`,async()=>assert.equal((await request(token,{})).status,401));
 if(name==='seller_accept_order'){
  for(const id of [inactive,foreign])await test(`${name} ${id===inactive?'inactive waiter':'foreign owner'}`,async()=>{
   const response=await request(id,{order_id:owner,p_actor_user_id:owner});
   assert.equal(response.status,400);assert.match(JSON.stringify(await response.json()),/SELLER_ACCESS_DENIED/);
   assert.equal(forwarded.at(-1).params.p_actor_user_id,id);
  });
  await test(`${name} own owner positive control`,async()=>assert.equal((await request(owner,{order_id:owner})).status,200));
 }
 if(name==='create_order'){
  await test('create_order ignores spoofed actor at RPC boundary',async()=>{
   await request(inactive,{seller_id:foreign,p_actor_user_id:owner,items:[{product_id:'fixture',quantity:1}]});
   assert.equal(forwarded.at(-1).params.p_actor_user_id,inactive);
  });
  results.push({name:'create_order inactive / branch / foreign tenant end-to-end',status:'BLOCKED',detail:'Legacy buyer RPC seller_ops.create_pending_order requires full schema clone. Handler only validates Auth and forwards actor; restaurant membership is not checked here. No deployed Edge/Auth test.'});
 }
}
await writeFile(new URL('../../../docs/preprod/restaurant_security_20261030/edge_results.json',import.meta.url),JSON.stringify({scope:'Actual handlers/shared helper transpiled by Node; mocked Auth/REST; seller access SQL real in PGlite; no deployed Edge runtime',results},null,2)+'\n');
for(const r of results)console.log(`${r.status} ${r.name}${r.detail?' :: '+r.detail:''}`);
await db.close();
process.exitCode=results.some(r=>r.status==='FAIL')?1:results.some(r=>r.status==='BLOCKED')?2:0;
