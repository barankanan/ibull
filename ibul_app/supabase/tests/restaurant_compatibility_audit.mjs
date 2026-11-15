// Offline only. Optional argument: local JSON row export (never a DB URL).
import {readFile,writeFile} from 'node:fs/promises';
const base=new URL('../../../docs/preprod/restaurant_security_20261030/',import.meta.url);
const load=async(n)=>JSON.parse(await readFile(new URL(`historical_${n}.json`,base),'utf8')).rows;
const columns=await load('columns'),indexes=await load('indexes'),constraints=await load('print-job-constraints');
const results=[];
const add=(name,status,detail)=>results.push({name,status,detail});
for(const [table,cols] of Object.entries({orders:['restaurant_id','table_id','local_order_id'],order_items:['station_id','product_id'],printers:['restaurant_id','print_size'],print_jobs:['status','payload','claimed_at','completed_at','order_saved_at','print_job_created_at']})) {
 const missing=cols.filter(c=>!columns.some(r=>r.table_name===table&&r.column_name===c));
 add(`${table} required columns`,missing.length?'FAIL':'PASS',missing.length?missing.join(','):'Present in historical catalog; not refreshed');
}
add('orders idempotency unique index',indexes.some(i=>/UNIQUE INDEX.*\(restaurant_id, local_order_id\).*WHERE \(local_order_id IS NOT NULL\)/.test(i.indexdef))?'PASS':'FAIL','Historical catalog');
add('paused print status',constraints.some(c=>c.definition.includes('paused_by_operator'))?'PASS':'FAIL','Historical CHECK accepts paused_by_operator');
const historicalMembers=await load('realtime');
add('Realtime baseline completeness','BLOCKED',`Historical query returned ${historicalMembers.length} rows for its unknown filter. Publication exists, but a complete membership/settings snapshot was not saved. Do not infer global emptiness.`);
if(!process.argv[2])add('current production order/printer row compatibility','BLOCKED','No complete local production row export supplied. Historical schema and aggregate latency exports cannot prove row compatibility. No production connection made.');
else {
 const path=process.argv[2];
 if(/^[a-z][a-z0-9+.-]*:\/\//i.test(path))throw Error('Only a local JSON file is accepted');
 const d=JSON.parse(await readFile(path,'utf8'));
 const required=['stores','orders','order_items','print_jobs','printers','stations','station_printers','store_sub_admins','store_tables','table_orders','store_branches'];
 for(const t of required)if(!Array.isArray(d[t]))throw Error(`Missing complete row collection: ${t}`);
 if(!d.metadata?.exported_at||d.metadata?.complete!==true)throw Error('Snapshot needs exported_at and complete:true metadata; this is still a caller claim, not live verification');
 const count=(name,rows)=>add(name,rows.length?'FAIL':'PASS',`${rows.length} incompatible row(s); export_time=${d.metadata.exported_at}; completeness unverified`);
 const by=(t,key,id)=>d[t].find(r=>r[key]===id);
 const duplicate=(t,keys,filter=()=>true)=>{const seen=new Set();return d[t].filter(filter).filter(r=>{const k=JSON.stringify(keys.map(x=>r[x]));if(seen.has(k))return true;seen.add(k);return false;});};
 const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
 count('invalid table_orders seller UUID casts',d.table_orders?.filter(r=>!uuid.test(r.seller_id))||[]);
 count('duplicate restaurant/local order ids',duplicate('orders',['restaurant_id','local_order_id'],r=>r.local_order_id!=null));
 count('duplicate staff Auth binding',duplicate('store_sub_admins',['store_id','auth_user_id'],r=>r.auth_user_id!=null));
 count('duplicate staff creation request',duplicate('store_sub_admins',['store_id','creation_request_id'],r=>r.creation_request_id!=null));
 count('unmapped active tables for branch staff',d.store_tables.filter(t=>t.is_active&&!t.branch_id&&d.store_sub_admins.some(s=>s.store_id===t.seller_id&&s.branch_id&&s.status==='active')));
 count('staff foreign or inactive branch',d.store_sub_admins.filter(s=>s.branch_id&&(!by('store_branches','id',s.branch_id)||by('store_branches','id',s.branch_id).store_id!==s.store_id||by('store_branches','id',s.branch_id).status!=='active')));
 count('table foreign or inactive branch',d.store_tables.filter(t=>t.branch_id&&(!by('store_branches','id',t.branch_id)||by('store_branches','id',t.branch_id).store_id!==t.seller_id||by('store_branches','id',t.branch_id).status!=='active')));
 count('duplicate active restaurant table numbers',duplicate('store_tables',['seller_id','table_number'],r=>r.is_active));
 count('invalid printer print_size',d.printers.filter(p=>p.print_size!=null&&!['small','normal','large','xlarge'].includes(p.print_size)));
 count('cross-tenant station/printer mapping',d.station_printers.filter(m=>{const s=by('stations','id',m.station_id),p=by('printers','id',m.printer_id);return !s||!p||s.restaurant_id!==p.restaurant_id;}));
 count('cross-tenant order table',d.orders.filter(o=>o.restaurant_id&&o.table_id&&by('store_tables','id',o.table_id)?.seller_id!==o.restaurant_id));
 count('job/order tenant mismatch',d.print_jobs.filter(j=>!by('orders','id',j.order_id)||by('orders','id',j.order_id).restaurant_id!==j.restaurant_id));
 count('job printer tenant mismatch',d.print_jobs.filter(j=>j.printer_id&&by('printers','id',j.printer_id)?.restaurant_id!==j.restaurant_id));
 count('pending jobs with dispatch evidence',d.print_jobs.filter(j=>j.status==='pending'&&(j.printer_write_started_at||j.printer_write_completed_at||j.printed_at||j.completed_at||j.dispatch_started_at)));
 count('unresolved claimed/printing jobs',d.print_jobs.filter(j=>['claimed','printing'].includes(j.status)));
 add('staff Auth identity/verified-contact/metadata compatibility','BLOCKED','Requires protected local Auth identity export or full isolated clone. No inference from email/profile alone.');
}
await writeFile(new URL('compatibility_results.json',base),JSON.stringify({scope:'Offline historical catalog; optional local rows only',results},null,2)+'\n');
for(const r of results)console.log(`${r.status} ${r.name}: ${r.detail}`);
process.exitCode=results.some(r=>r.status==='FAIL')?1:results.some(r=>r.status==='BLOCKED')?2:0;
