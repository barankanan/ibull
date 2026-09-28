const fs = require('fs');

const raw = fs.readFileSync('audit_results.json', 'utf8');
// the file starts with some cli output, find the boundary and parse the rows
const match = raw.match(/"rows":\s*\[\s*\{\s*"json_build_object":\s*(\{.*?\})\s*\}\s*\]/s);
if (!match) {
  console.log("Could not parse JSON");
  process.exit(1);
}
const data = JSON.parse(match[1]);

console.log("=== RLS STATUS ===");
const targetTables = ['users', 'profiles', 'stores', 'store_sub_admins', 'products', 'orders', 'order_items', 'cart', 'favorites', 'addresses', 'notifications', 'coupons', 'ads', 'campaigns', 'vehicle_listings', 'vehicle_reservations', 'vehicle_kyc_documents'];
data.rls.forEach(t => {
  if (targetTables.includes(t.table_name) || t.table_name.includes('print') || t.table_name.includes('finance') || t.table_name.includes('restaurant')) {
    console.log(`${t.table_name}: RLS=${t.rls_enabled}, Force=${t.force_rls}`);
  }
});

console.log("\n=== ORDER POLICIES ===");
data.policies.filter(p => p.tablename === 'orders').forEach(p => {
  console.log(`- ${p.policyname} (${p.cmd}): roles=${p.roles}, qual=${p.qual}`);
});

console.log("\n=== VEHICLE KYC POLICIES ===");
data.policies.filter(p => p.tablename === 'vehicle_kyc_documents').forEach(p => {
  console.log(`- ${p.policyname} (${p.cmd}): roles=${p.roles}, qual=${p.qual}`);
});

console.log("\n=== USERS PRIVILEGED GUARD TRIGGER ===");
const guard = data.triggers.find(t => t.trigger_name.includes('privileged') || t.event_object_table === 'users' || t.event_object_table === 'profiles');
console.log(guard ? `FOUND: ${guard.trigger_name} on ${guard.event_object_table}` : 'NOT FOUND');

console.log("\n=== STORAGE BUCKETS ===");
data.buckets.forEach(b => {
  console.log(`${b.name}: public=${b.public}`);
});

console.log("\n=== SECURITY DEFINER FUNCTIONS ===");
data.secdef.forEach(f => {
  console.log(`${f.proname}: config=${f.proconfig}`);
});
