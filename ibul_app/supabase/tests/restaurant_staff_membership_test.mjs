// Isolated manage-restaurant-staff handler. No Deno listener, network, or live Auth.
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import assert from 'node:assert/strict';
const read = (file) => readFile(new URL(file, import.meta.url), 'utf8');
const owner = '10000000-0000-0000-0000-000000000001';
const otherOwner = '10000000-0000-0000-0000-000000000002';
const branch = '30000000-0000-0000-0000-000000000001';
const otherBranch = '30000000-0000-0000-0000-000000000002';
const existingAuth = '20000000-0000-0000-0000-000000000099';
const state = {
  stores: [
    { seller_id: owner, category: 'Yemek' },
    { seller_id: otherOwner, category: 'Elektronik' },
  ],
  branches: [
    { id: branch, store_id: owner, status: 'active' },
    { id: otherBranch, store_id: otherOwner, status: 'active' },
  ],
  members: [
    { id: 'invited-1', store_id: owner, email: 'old@example.test', status: 'invited', auth_user_id: null, permissions: ['viewOrders'], staff_role: 'waiter' },
    { id: 'other-membership', store_id: otherOwner, email: 'shared@example.test', status: 'active', auth_user_id: existingAuth, permissions: ['manageOrders'], staff_role: 'waiter', branch_id: otherBranch },
  ],
  users: [],
  auth: [{ id: existingAuth, email: 'shared@example.test', password: 'original-password-12' }],
  passwordChanges: 0,
  orders: [{ id: 'order-1', waiter_id: existingAuth, seller_id: otherOwner, total: 42 }],
  audit: [{ id: 'audit-1', waiter_id: existingAuth, action: 'table_transfer' }],
  failMembership: false,
  blockUsersDelete: false,
  authPolicyMin: 0,
};
globalThis.fetch = async (url, init) => {
  const text = String(url);
  if (text.includes('grant_type=password')) {
    const body = JSON.parse(init?.body ?? '{}');
    const user = state.auth.find((row) => row.email === body.email);
    const ok = Boolean(user) && user.password === body.password;
    return { ok, status: ok ? 200 : 400, json: async () => ({}) };
  }
  const email = decodeURIComponent(text.split('filter=')[1] ?? '');
  const user = state.auth.find((row) => row.email === email);
  return { ok: true, json: async () => ({ users: user ? [{ id: user.id, email: user.email, app_metadata: user.app_metadata ?? {} }] : [] }) };
};
const touched = new Set();
const matches = (row, filters) => filters.every(([key, value]) => row[key] === value);
const serviceClient = {
  from(table) {
    touched.add(table);
    const filters = [];
    let op = 'select';
    let payload = null;
    let countOnly = false;
    const rows = () => table === 'stores' ? state.stores : table === 'store_branches' ? state.branches : table === 'store_sub_admins' ? state.members : state.users;
    const query = {
      select(_columns, options) { countOnly = options?.head === true; return query; },
      eq(key, value) { filters.push([key, value]); return query; },
      update(value) { op = 'update'; payload = value; return query; },
      insert(value) { op = 'insert'; payload = value; return query; },
      upsert(value) { op = 'upsert'; payload = value; return query; },
      delete() { op = 'delete'; return query; },
      async maybeSingle() { return finish('maybe'); },
      async single() { return finish('single'); },
      then(resolve, reject) { return finish('list').then(resolve, reject); },
    };
    const finish = async (mode) => {
      const found = rows().filter((row) => matches(row, filters));
      if (op === 'select') {
        if (countOnly) return { data: null, error: null, count: found.length };
        if (mode === 'list') return { data: found, error: null };
        if (mode === 'maybe') {
          return { data: found.length === 1 ? found[0] : null, error: found.length > 1 ? { message: 'multiple' } : null };
        }
        if (found.length !== 1) return { data: null, error: { message: 'row count' } };
        return { data: found[0], error: null };
      }
      if (op === 'delete') {
        if (table === 'users' && state.blockUsersDelete) return { data: null, error: null };
        const source = rows();
        for (let i = source.length - 1; i >= 0; i -= 1) if (matches(source[i], filters)) source.splice(i, 1);
        return { data: null, error: null };
      }
      if (op === 'insert' || op === 'upsert') {
        if (table === 'store_sub_admins' && state.failMembership) {
          return { data: null, error: { message: 'membership failed' } };
        }
        const existing = payload.id ? rows().find((row) => row.id === payload.id) : null;
        if (op === 'upsert' && existing) {
          Object.assign(existing, payload);
          return { data: existing, error: null };
        }
        const row = { id: payload.id ?? `row-${state.members.length + state.users.length + 1}`, ...payload };
        rows().push(row);
        return { data: row, error: null };
      }
      if (table === 'store_sub_admins' && state.failMembership) {
        return { data: null, error: { message: 'membership failed' } };
      }
      if (found.length !== 1) return { data: null, error: { message: 'row count' } };
      Object.assign(found[0], payload);
      return { data: found[0], error: null };
    };
    return query;
  },
  auth: { admin: {
    async createUser({ email, password, app_metadata }) {
      if (password.length < 6) return { data: null, error: { message: 'weak' } };
      if (state.authPolicyMin && password.length < state.authPolicyMin) {
        return { data: null, error: { message: 'Password should be at least 8 characters' } };
      }
      if (state.auth.some((user) => user.email === email)) return { data: null, error: { message: 'exists' } };
      const user = { id: `auth-${state.auth.length + 1}`, email, password, app_metadata: { ...(app_metadata ?? {}) } };
      state.auth.push(user);
      state.users.push({ id: user.id, email, role: 'user' });
      return { data: { user }, error: null };
    },
    async getUserById(id) {
      const user = state.auth.find((row) => row.id === id);
      return user ? { data: { user }, error: null } : { data: { user: null }, error: { message: 'missing' } };
    },
    async updateUserById(id, attrs) {
      const user = state.auth.find((row) => row.id === id);
      if (!user) return { error: { message: 'missing' } };
      if (attrs?.password) {
        state.passwordChanges += 1;
        user.password = attrs.password;
      }
      if (attrs?.app_metadata) user.app_metadata = { ...(user.app_metadata ?? {}), ...attrs.app_metadata };
      return { data: { user }, error: null };
    },
    async deleteUser(id) {
      if (state.users.some((row) => row.id === id)) return { error: { message: 'users_id_fkey' } };
      const index = state.auth.findIndex((user) => user.id === id);
      if (index < 0) return { error: { message: 'missing' } };
      state.auth.splice(index, 1);
      return { error: null };
    },
  } },
};
globalThis.__edgeCreateClient = (_url, key, options) => key === 'fake-service' ? serviceClient : { auth: { async getUser() {
  const token = options.global.headers.Authorization.slice(7);
  if (token === 'invalid') return { data: { user: null }, error: { message: 'invalid' } };
  const known = state.auth.find((row) => row.id === token);
  return { data: { user: known ?? { id: token, app_metadata: {} } }, error: null };
} } };
globalThis.Deno = { env: { get: (key) => ({ SUPABASE_URL: 'http://localhost.invalid', SUPABASE_ANON_KEY: 'fake-anon', SUPABASE_SERVICE_ROLE_KEY: 'fake-service' })[key] }, serve: (fn) => { globalThis.__staffHandler = fn; } };
const dataUrl = (source) => `data:text/javascript;base64,${Buffer.from(source).toString('base64')}`;
const shared = (await read('../functions/_shared/http.ts')).replace(/import .* from 'jsr:.*';/, 'const createClient=globalThis.__edgeCreateClient;');
const source = (await read('../functions/manage-restaurant-staff/index.ts')).replace("'../_shared/http.ts'", JSON.stringify(dataUrl(stripTypeScriptTypes(shared, { mode: 'transform' }))));
await import(dataUrl(stripTypeScriptTypes(source, { mode: 'transform' })));
const callAs = async (actor, body) => {
  const response = await globalThis.__staffHandler(new Request('http://localhost.invalid', { method: 'POST', headers: { Authorization: `Bearer ${actor}` }, body: JSON.stringify(body) }));
  return { status: response.status, body: await response.json() };
};
const call = (body) => callAs(owner, body);
const created = await call({ operation: 'create', name: 'Ayşe', email: 'waiter@example.test', password: 'gecici-sifre-12', staff_role: 'waiter', branch_id: branch, request_id: 'req-1', permissions: ['viewOrders', 'manageOrders'] });
assert.equal(created.status, 200);
assert.equal(created.body.ok, true);
const member = state.members.find((row) => row.email === 'waiter@example.test');
assert.equal(member.status, 'active');
assert.equal(member.staff_role, 'waiter');
assert.equal(member.branch_id, branch);
assert.deepEqual(member.permissions, ['viewOrders', 'manageOrders']);
assert.equal(state.auth.some((user) => user.email === 'waiter@example.test'), true);
assert.equal(state.auth.find((user) => user.email === 'waiter@example.test').app_metadata.provisioned_by_store_id, owner);
assert.equal(state.auth.find((user) => user.email === 'waiter@example.test').app_metadata.must_change_password, true);
assert.equal(state.users.some((user) => user.email === 'waiter@example.test' && user.role === 'waiter'), true);
const replay = await call({ operation: 'create', name: 'Ayşe', email: 'waiter@example.test', password: 'baska-sifre-1234', staff_role: 'waiter', branch_id: branch, request_id: 'req-1', permissions: ['viewOrders', 'manageOrders'] });
assert.equal(replay.status, 200);
assert.equal(replay.body.replay, true);
assert.equal(state.auth.filter((user) => user.email === 'waiter@example.test').length, 1);
assert.equal(state.passwordChanges, 0);
const weak = await call({ operation: 'create', name: 'Kısa', email: 'short@example.test', password: 'kisa', staff_role: 'waiter', branch_id: branch, request_id: 'req-short', permissions: ['viewOrders'] });
assert.equal(weak.status, 400);
assert.match(weak.body.message, /8 karakter/);
assert.equal(state.auth.some((user) => user.email === 'short@example.test'), false);
const eight = await call({ operation: 'create', name: 'Sekiz', email: 'six@example.test', password: '12345678', staff_role: 'waiter', branch_id: branch, request_id: 'req-six', permissions: ['viewOrders'] });
assert.equal(eight.status, 200);
assert.equal(eight.body.ok, true);
assert.equal(state.auth.find((user) => user.email === 'six@example.test').app_metadata.must_change_password, true);
state.authPolicyMin = 12;
const policy = await call({ operation: 'create', name: 'Politika', email: 'policy@example.test', password: '12345678', staff_role: 'waiter', branch_id: branch, request_id: 'req-policy', permissions: ['viewOrders'] });
state.authPolicyMin = 0;
assert.equal(policy.status, 409);
assert.match(policy.body.message, /politikası/);
assert.equal(state.members.some((row) => row.email === 'policy@example.test'), false);
const promoted = await call({ operation: 'create', name: 'Eski', email: 'old@example.test', password: 'gecici-sifre-12', staff_role: 'sub_admin', branch_id: branch, request_id: 'req-old', permissions: ['manageProducts'] });
assert.equal(promoted.status, 200);
assert.equal(state.members.filter((row) => row.email === 'old@example.test').length, 1);
assert.equal(state.members.find((row) => row.id === 'invited-1').status, 'active');
assert.equal(state.members.find((row) => row.id === 'invited-1').staff_role, 'sub_admin');
const permissions = await call({ operation: 'permissions', id: member.id, permissions: ['viewFinance'] });
assert.equal(permissions.status, 200);
assert.deepEqual(member.permissions, ['viewFinance']);
assert.deepEqual(state.members.find((row) => row.id === 'other-membership').permissions, ['manageOrders']);
const foreignPermissions = await call({ operation: 'permissions', id: 'other-membership', permissions: ['viewOrders'] });
assert.equal(foreignPermissions.status, 400);
assert.deepEqual(state.members.find((row) => row.id === 'other-membership').permissions, ['manageOrders']);
const stranger = await callAs('stranger', { operation: 'delete', id: member.id });
assert.equal(stranger.status, 403);
assert.equal(member.status, 'active');
const deactivated = await call({ operation: 'deactivate', id: member.id });
assert.equal(deactivated.status, 200);
assert.equal(member.status, 'inactive');
const sharedBefore = state.members.filter((row) => row.email === 'shared@example.test').map((row) => ({ ...row }));
const sharedCreate = await call({ operation: 'create', name: 'Ortak', email: 'shared@example.test', password: 'yeni-sifre-1234', staff_role: 'waiter', branch_id: branch, request_id: 'req-shared', permissions: ['viewOrders'] });
assert.equal(sharedCreate.status, 409);
assert.equal(sharedCreate.body.linked, false);
assert.equal(state.passwordChanges, 0);
assert.equal(state.auth.find((user) => user.id === existingAuth).password, 'original-password-12');
assert.deepEqual(state.members.filter((row) => row.email === 'shared@example.test'), sharedBefore);
state.members.push({ id: 'invited-existing', store_id: owner, email: 'shared@example.test', status: 'invited', auth_user_id: null, permissions: ['viewOrders'], staff_role: 'waiter' });
const invitedExisting = await call({ operation: 'create', name: 'Ortak', email: 'shared@example.test', password: 'yeni-sifre-1234', staff_role: 'waiter', branch_id: branch, request_id: 'req-shared-invite', permissions: ['viewOrders'] });
assert.equal(invitedExisting.status, 409);
assert.equal(state.members.find((row) => row.id === 'invited-existing').status, 'invited');
assert.equal(state.members.find((row) => row.id === 'invited-existing').auth_user_id, null);
assert.equal(state.members.some((row) => row.id === 'other-membership' && row.status === 'active' && row.auth_user_id === existingAuth), true);
const removedInvited = await call({ operation: 'delete', id: 'invited-missing' });
assert.equal(removedInvited.status, 404);
assert.match(removedInvited.body.message, /bulunamadı/);
state.members.push({ id: 'invited-2', store_id: owner, email: 'gone@example.test', status: 'invited', auth_user_id: null, permissions: ['viewOrders'], staff_role: 'waiter' });
const deletedInvite = await call({ operation: 'delete', id: 'invited-2' });
assert.equal(deletedInvite.status, 200);
assert.equal(deletedInvite.body.auth_removed, false);
assert.equal(state.members.some((row) => row.id === 'invited-2'), false);
assert.equal(state.members.some((row) => row.id === 'other-membership'), true);
const sharedMember = { id: 'shared-local', store_id: owner, email: 'shared@example.test', status: 'active', auth_user_id: existingAuth, permissions: ['viewOrders'], staff_role: 'waiter', branch_id: branch };
state.members.push(sharedMember);
const deletedShared = await call({ operation: 'delete', id: 'shared-local' });
assert.equal(deletedShared.status, 200);
assert.equal(deletedShared.body.auth_removed, false);
assert.equal(state.auth.some((user) => user.id === existingAuth), true);
assert.equal(state.members.some((row) => row.id === 'other-membership'), true);
assert.equal(state.members.some((row) => row.id === 'shared-local'), false);
const foreignDelete = await call({ operation: 'delete', id: 'other-membership' });
assert.equal(foreignDelete.status, 404);
assert.equal(state.members.some((row) => row.id === 'other-membership' && row.status === 'active'), true);
assert.equal(state.auth.some((user) => user.id === existingAuth), true);
const otherOwnerDelete = await callAs(otherOwner, { operation: 'delete', id: member.id });
assert.equal(otherOwnerDelete.status, 404);
assert.equal(state.members.some((row) => row.id === member.id), true);
state.failMembership = true;
const compensated = await call({ operation: 'create', name: 'Telafi', email: 'rollback@example.test', password: 'gecici-sifre-12', staff_role: 'waiter', branch_id: branch, request_id: 'req-rollback', permissions: ['viewOrders'] });
state.failMembership = false;
assert.equal(compensated.status, 500);
assert.match(compensated.body.message, /geri alındı/);
assert.equal(state.auth.some((user) => user.email === 'rollback@example.test'), false);
assert.equal(state.users.some((user) => user.email === 'rollback@example.test'), false);
assert.equal(state.members.some((row) => row.email === 'rollback@example.test'), false);
assert.equal(state.members.some((row) => row.id === 'other-membership'), true);
const soleAuth = state.auth.find((user) => user.email === 'waiter@example.test').id;
state.orders.push({ id: 'order-2', waiter_id: soleAuth, seller_id: owner, total: 18 });
state.audit.push({ id: 'audit-2', waiter_id: soleAuth, action: 'order_commit' });
const ordersBefore = JSON.stringify(state.orders);
const auditBefore = JSON.stringify(state.audit);
const deletedSole = await call({ operation: 'delete', id: member.id });
assert.equal(deletedSole.status, 200);
assert.equal(deletedSole.body.auth_removed, false);
assert.equal(state.auth.some((user) => user.id === soleAuth), true);
assert.equal(state.members.some((row) => row.id === member.id), false);
assert.equal(JSON.stringify(state.orders), ordersBefore);
assert.equal(JSON.stringify(state.audit), auditBefore);
assert.equal(touched.has('orders'), false);
assert.equal(touched.has('table_transfers_log'), false);
assert.equal(touched.has('print_jobs'), false);
state.blockUsersDelete = true;
state.failMembership = true;
const blocked = await call({ operation: 'create', name: 'Takili', email: 'stuck@example.test', password: 'gecici-sifre-12', staff_role: 'waiter', branch_id: branch, request_id: 'req-stuck', permissions: ['viewOrders'] });
state.failMembership = false;
state.blockUsersDelete = false;
assert.equal(blocked.status, 500);
assert.equal(blocked.body.orphan_detected, true);
assert.equal(state.auth.some((user) => user.email === 'stuck@example.test'), true);
assert.equal(state.passwordChanges, 0);
assert.equal(state.members.some((row) => row.id === 'other-membership'), true);
const stuckPassword = state.auth.find((user) => user.email === 'stuck@example.test').password;
const relink = await call({ operation: 'create', name: 'Takili', email: 'stuck@example.test', password: 'baska-sifre-999', staff_role: 'waiter', branch_id: branch, request_id: 'req-stuck-relink', permissions: ['viewOrders'] });
assert.equal(relink.status, 409);
assert.equal(relink.body.linked, false);
assert.equal(relink.body.link_available, true);
assert.equal(relink.body.password_unchanged, true);
assert.equal(state.auth.find((user) => user.email === 'stuck@example.test').password, stuckPassword);
assert.equal(state.passwordChanges, 0);
assert.equal(state.members.some((row) => row.email === 'stuck@example.test'), false);
const confirmed = await call({ operation: 'create', name: 'Takili', email: 'stuck@example.test', password: 'baska-sifre-999', staff_role: 'waiter', branch_id: branch, request_id: 'req-stuck-relink', permissions: ['viewOrders'], confirm_link: true });
assert.equal(confirmed.status, 200);
assert.equal(confirmed.body.password_unchanged, true);
assert.equal(state.auth.find((user) => user.email === 'stuck@example.test').password, stuckPassword);
assert.equal(state.members.some((row) => row.email === 'stuck@example.test' && row.store_id === owner && row.status === 'active'), true);
assert.equal(state.members.some((row) => row.id === 'other-membership' && row.status === 'active'), true);
state.auth.push({ id: 'customer-1', email: 'customer@example.test', password: 'musteri-sifre-12', app_metadata: {} });
state.users.push({ id: 'customer-1', email: 'customer@example.test', role: 'waiter' });
const claimed = await call({ operation: 'create', name: 'Musteri', email: 'customer@example.test', password: 'baska-sifre-999', staff_role: 'waiter', branch_id: branch, request_id: 'req-customer-claim', permissions: ['viewOrders'], confirm_link: true });
assert.equal(claimed.status, 409);
assert.equal(claimed.body.linked, false);
assert.equal(claimed.body.link_available, false);
assert.equal(state.members.some((row) => row.email === 'customer@example.test'), false);
assert.equal(state.auth.find((user) => user.email === 'customer@example.test').password, 'musteri-sifre-12');
assert.equal(state.auth.some((user) => user.email === 'customer@example.test'), true);
const foreignPassword = await call({ operation: 'set_temporary_password', id: 'other-membership', password: 'yeni-sifre-123456' });
assert.equal(foreignPassword.status, 404);
assert.equal(state.auth.find((user) => user.id === existingAuth).password, 'original-password-12');
const stuckMember = state.members.find((row) => row.email === 'stuck@example.test' && row.store_id === owner);
const changed = await call({ operation: 'set_temporary_password', id: stuckMember.id, password: 'yeni-sifre-123456' });
assert.equal(changed.status, 200);
assert.equal(state.auth.find((user) => user.email === 'stuck@example.test').password, 'yeni-sifre-123456');
assert.equal(state.passwordChanges, 1);
const stuckId = state.auth.find((user) => user.email === 'stuck@example.test').id;
const cleared = await callAs(stuckId, { operation: 'clear_password_change' });
assert.equal(cleared.status, 403);
assert.equal(state.auth.find((user) => user.id === stuckId).app_metadata.must_change_password, true);
assert.equal(state.auth.find((user) => user.id === stuckId).password, 'yeni-sifre-123456');
const wrongPassword = await callAs(stuckId, { operation: 'change_staff_password', current_password: 'yanlis-sifre-000', new_password: 'guclu-sifre-123' });
assert.equal(wrongPassword.status, 401);
assert.equal(state.auth.find((user) => user.id === stuckId).password, 'yeni-sifre-123456');
assert.equal(state.auth.find((user) => user.id === stuckId).app_metadata.must_change_password, true);
const changedOwn = await callAs(stuckId, { operation: 'change_staff_password', current_password: 'yeni-sifre-123456', new_password: 'guclu-sifre-123' });
assert.equal(changedOwn.status, 200);
assert.equal(state.auth.find((user) => user.id === stuckId).password, 'guclu-sifre-123');
assert.equal(state.auth.find((user) => user.id === stuckId).app_metadata.must_change_password, false);
state.members.push({
  id: 'sub-admin-member',
  store_id: owner,
  email: 'lead@example.test',
  status: 'active',
  auth_user_id: 'sub-admin-1',
  staff_role: 'sub_admin',
  permissions: ['manageStaff', 'viewOrders', 'manageOrders', 'closeBill'],
});
const within = await callAs('sub-admin-1', { operation: 'permissions', id: stuckMember.id, permissions: ['viewOrders', 'closeBill'] });
assert.equal(within.status, 200);
assert.deepEqual(state.members.find((row) => row.id === stuckMember.id).permissions, ['viewOrders', 'closeBill']);
const beyond = await callAs('sub-admin-1', { operation: 'permissions', id: stuckMember.id, permissions: ['viewOrders', 'transferTable'] });
assert.equal(beyond.status, 403);
assert.deepEqual(state.members.find((row) => row.id === stuckMember.id).permissions, ['viewOrders', 'closeBill']);
const seize = await callAs('sub-admin-1', {
  operation: 'create',
  name: 'Ele gecirme',
  email: 'seize@example.test',
  password: 'gecici-sifre-12',
  staff_role: 'sub_admin',
  branch_id: branch,
  request_id: 'req-seize',
  permissions: ['manageStoreProfile', 'manageStaff'],
});
assert.equal(seize.status, 403);
assert.equal(state.members.some((row) => row.email === 'seize@example.test'), false);
assert.equal(state.stores.some((row) => row.seller_id === 'sub-admin-1'), false);
state.members.push({
  id: 'waiter-manager',
  store_id: owner,
  email: 'wm@example.test',
  status: 'active',
  auth_user_id: 'waiter-manager',
  staff_role: 'waiter',
  permissions: ['manageStaff', 'manageOrders'],
});
const waiterGrant = await callAs('waiter-manager', { operation: 'permissions', id: stuckMember.id, permissions: ['viewOrders'] });
assert.equal(waiterGrant.status, 403);
assert.deepEqual(state.members.find((row) => row.id === stuckMember.id).permissions, ['viewOrders', 'closeBill']);
const ownerGrant = await call({ operation: 'permissions', id: stuckMember.id, permissions: ['manageStaff', 'viewOrders', 'manageOrders', 'closeBill', 'transferTable', 'takePartialPayment', 'splitBill'] });
assert.equal(ownerGrant.status, 200);
assert.deepEqual(state.members.find((row) => row.id === stuckMember.id).permissions, ['manageStaff', 'viewOrders', 'manageOrders', 'closeBill', 'transferTable', 'takePartialPayment', 'splitBill']);
state.members.push({
  id: 'inactive-lead',
  store_id: owner,
  email: 'inactive-lead@example.test',
  status: 'inactive',
  auth_user_id: 'inactive-lead',
  staff_role: 'sub_admin',
  permissions: ['manageStaff', 'manageOrders', 'closeBill'],
});
const inactiveLead = await callAs('inactive-lead', { operation: 'permissions', id: stuckMember.id, permissions: ['viewOrders'] });
assert.equal(inactiveLead.status, 403);
assert.deepEqual(state.members.find((row) => row.id === stuckMember.id).permissions, ['manageStaff', 'viewOrders', 'manageOrders', 'closeBill', 'transferTable', 'takePartialPayment', 'splitBill']);
const seven = ['manageProducts', 'viewOrders', 'manageOrders', 'manageCampaigns', 'viewFinance', 'manageSupport', 'manageStoreProfile'];
state.members.push({
  id: 'legacy-waiter',
  store_id: owner,
  email: 'legacy@example.test',
  status: 'active',
  staff_role: 'waiter',
  permissions: ['viewOrders', 'manageOrders'],
});
const legacyOnly = await call({ operation: 'permissions', id: 'legacy-waiter', permissions: seven });
assert.equal(legacyOnly.status, 200);
assert.deepEqual(state.members.find((row) => row.id === 'legacy-waiter').permissions, seven);
state.members.push({
  id: 'grant-waiter',
  store_id: owner,
  email: 'grant@example.test',
  status: 'active',
  staff_role: 'waiter',
  permissions: ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport', 'transferTable'],
});
const oldClient = await call({
  operation: 'permissions',
  id: 'grant-waiter',
  permissions: ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport'],
});
assert.equal(oldClient.status, 200);
assert.deepEqual(state.members.find((row) => row.id === 'grant-waiter').permissions, ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport', 'transferTable']);
const explicitClient = await call({
  operation: 'permissions',
  id: 'grant-waiter',
  permissions: ['viewOrders', 'manageOrders', 'closeBill'],
});
assert.equal(explicitClient.status, 200);
assert.deepEqual(state.members.find((row) => row.id === 'grant-waiter').permissions, ['viewOrders', 'manageOrders', 'closeBill']);
state.stores.find((row) => row.seller_id === owner).category = 'Elektronik';
const retailWaiter = await call({
  operation: 'create',
  name: 'Satış',
  email: 'retail@example.test',
  password: 'gecici-sifre-12',
  staff_role: 'waiter',
  branch_id: branch,
  request_id: 'req-retail-waiter',
  permissions: ['viewOrders', 'manageOrders'],
});
assert.equal(retailWaiter.status, 400);
const retailFloor = await call({
  operation: 'permissions',
  id: 'grant-waiter',
  permissions: ['viewOrders', 'transferTable'],
});
assert.equal(retailFloor.status, 403);
assert.deepEqual(state.members.find((row) => row.id === 'grant-waiter').permissions, ['viewOrders', 'manageOrders', 'closeBill']);
const retailSeven = await call({ operation: 'permissions', id: 'legacy-waiter', permissions: seven });
assert.equal(retailSeven.status, 200);
assert.deepEqual(state.members.find((row) => row.id === 'legacy-waiter').permissions, seven);
state.stores.find((row) => row.seller_id === owner).category = 'Yemek';
const grant = state.members.find((row) => row.id === 'grant-waiter');
grant.permissions = ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport', 'transferTable'];
grant.staff_role = 'waiter';
grant.branch_id = branch;
const keptTransfer = await call({
  operation: 'permissions',
  id: 'grant-waiter',
  permissions: ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport'],
  revoked_permissions: [],
});
assert.equal(keptTransfer.status, 200);
assert.deepEqual(grant.permissions, ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport', 'transferTable']);
const removedTransfer = await call({
  operation: 'permissions',
  id: 'grant-waiter',
  permissions: ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport'],
  revoked_permissions: ['transferTable'],
});
assert.equal(removedTransfer.status, 200);
assert.deepEqual(grant.permissions, ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport']);
assert.equal(grant.permissions.includes('closeBill'), false);
assert.equal(grant.permissions.includes('manageStaff'), false);
grant.staff_role = 'sub_admin';
grant.permissions = ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport', 'transferTable', 'closeBill', 'manageStaff'];
const waiterOverflow = await call({
  operation: 'permissions',
  id: 'grant-waiter',
  permissions: ['viewOrders', 'manageOrders'],
  revoked_permissions: [],
  staff_role: 'waiter',
});
assert.equal(waiterOverflow.status, 403);
assert.equal(grant.staff_role, 'sub_admin');
assert.equal(grant.permissions.includes('closeBill'), true);
const waiterTrimmed = await call({
  operation: 'permissions',
  id: 'grant-waiter',
  permissions: ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport'],
  revoked_permissions: ['closeBill', 'manageStaff'],
  staff_role: 'waiter',
});
assert.equal(waiterTrimmed.status, 200);
assert.equal(grant.staff_role, 'waiter');
assert.deepEqual(grant.permissions, ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport', 'transferTable']);
const secondBranch = '30000000-0000-0000-0000-000000000003';
state.branches.push({ id: secondBranch, store_id: owner, status: 'active' });
const moved = await call({
  operation: 'permissions',
  id: 'grant-waiter',
  permissions: ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport'],
  revoked_permissions: [],
  branch_id: secondBranch,
});
assert.equal(moved.status, 200);
assert.equal(grant.branch_id, secondBranch);
assert.equal(grant.permissions.includes('transferTable'), true);
const foreignBranchUpdate = await call({
  operation: 'permissions',
  id: 'grant-waiter',
  permissions: ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport'],
  revoked_permissions: [],
  branch_id: otherBranch,
});
assert.equal(foreignBranchUpdate.status, 400);
assert.equal(grant.branch_id, secondBranch);
const promotedRole = await call({
  operation: 'permissions',
  id: 'grant-waiter',
  permissions: ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport'],
  revoked_permissions: [],
  staff_role: 'sub_admin',
});
assert.equal(promotedRole.status, 200);
assert.equal(grant.staff_role, 'sub_admin');
assert.equal(grant.permissions.includes('closeBill'), false);
assert.equal(grant.permissions.includes('manageStaff'), false);
assert.equal(grant.permissions.includes('transferTable'), true);
state.members.push({
  id: 'lead',
  store_id: owner,
  email: 'lead@example.test',
  status: 'active',
  auth_user_id: 'lead-auth',
  staff_role: 'sub_admin',
  branch_id: branch,
  permissions: ['manageStaff', 'viewOrders'],
});
const selfPromotion = await callAs('lead-auth', {
  operation: 'permissions',
  id: 'lead',
  permissions: ['manageStaff', 'viewOrders'],
  staff_role: 'sub_admin',
  branch_id: secondBranch,
});
assert.equal(selfPromotion.status, 403);
assert.equal(state.members.find((row) => row.id === 'lead').branch_id, branch);
assert.equal(state.members.find((row) => row.id === 'lead').staff_role, 'sub_admin');
console.log('PASS: staff create, link proof, foreign tenant denial, compensation, and password-change gate.');
