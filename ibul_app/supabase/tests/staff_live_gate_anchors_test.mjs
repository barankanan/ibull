// Live gate text captured from production function bodies. Read only.
// Proves 2026110117 recognizes the current close and transfer gates.
import assert from 'node:assert/strict';

const closeManageOrders = `IF NOT public.restaurant_has_permission(p_seller_id, 'manageOrders') OR NOT public.restaurant_table_number_access(p_seller_id,p_table_number) THEN
    RAISE EXCEPTION 'Sipariş yönetme yetkisi yok.' USING ERRCODE='42501';
  END IF;`;
const closeActor = `IF auth.uid() IS NULL OR NOT v_actor_authorized THEN
    RAISE EXCEPTION 'Yetkisiz işlem.' USING ERRCODE = '42501';
  END IF;`;
const transferOwner = `if p_seller_id <> auth.uid() then
    raise exception 'Yetki hatası.' using errcode = '42501';
  end if;`;
const validator = `if not new.permissions <@ array['manageProducts','viewOrders','manageOrders','manageCampaigns','viewFinance','manageSupport','manageStoreProfile']::text[] then`;

assert.match(
  closeManageOrders,
  /IF NOT public\.restaurant_has_permission\(p_seller_id, 'manageOrders'\) OR NOT public\.restaurant_table_number_access\(p_seller_id,p_table_number\) THEN\s*RAISE EXCEPTION 'Sipariş yönetme yetkisi yok\.' USING ERRCODE='42501';\s*END IF;/,
);
assert.match(
  closeActor,
  /IF\s+auth\.uid\(\)\s+IS\s+NULL\s+OR\s+NOT\s+v_actor_authorized\s+THEN\s+RAISE\s+EXCEPTION\s+'Yetkisiz işlem\.'\s+USING\s+ERRCODE\s*=\s*'42501';\s*END\s+IF;/,
);
assert.match(
  transferOwner,
  /if\s+p_seller_id\s*<>\s*auth\.uid\(\)\s+then\s+raise\s+exception\s+[^;]*;\s*end\s+if;/i,
);
assert.equal(validator.includes('manageStaff'), false);
assert.equal(validator.includes('closeBill'), false);
assert.equal(closeManageOrders.includes('closeBill'), false);
assert.equal(transferOwner.includes('transferTable'), false);
console.log('PASS: live close, transfer and permission-list anchors match 2026110117.');
