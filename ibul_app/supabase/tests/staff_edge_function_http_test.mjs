// HTTP checks for the manage-restaurant-staff Edge Function, run with real
// GoTrue logins against a LOCAL, THROWAWAY Supabase stack that carries the real
// migration chain. The function itself is started locally with `deno run` and
// pointed at that stack. Nothing is read from or written to a remote project.
//
// Environment (never embedded here):
//   IBUL_JWT_SECRET   local GoTrue JWT secret
//   IBUL_API_URL      local API gateway, e.g. http://127.0.0.1:55321
//   IBUL_FUNCTION_URL locally served function, e.g. http://127.0.0.1:55390
//   IBUL_DB_CONTAINER throwaway database container
import { execFileSync } from 'node:child_process';
import { createHmac, randomBytes } from 'node:crypto';

const api = process.env.IBUL_API_URL ?? '';
const fnUrl = process.env.IBUL_FUNCTION_URL ?? '';
const container = process.env.IBUL_DB_CONTAINER ?? '';
const secret = process.env.IBUL_JWT_SECRET;
const local = /^http:\/\/(127\.0\.0\.1|localhost)[:/]/;
if (!secret || !container) throw new Error('IBUL_JWT_SECRET and IBUL_DB_CONTAINER are required');
if (!local.test(api + '/') || !local.test(fnUrl + '/')) throw new Error('local API and function only');
if (/local-staging/.test(container)) throw new Error('use a throwaway database, not the shared local one');

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const sign = (role) => {
  const head = b64({ alg: 'HS256', typ: 'JWT' });
  const body = b64({ role, iss: 'supabase-demo', exp: Math.floor(Date.now() / 1000) + 3600 });
  return `${head}.${body}.${createHmac('sha256', secret).update(`${head}.${body}`).digest('base64url')}`;
};
const anon = sign('anon');
const service = sign('service_role');
const run = randomBytes(4).toString('hex');
const mail = (tag) => `edgefn-${run}-${tag}@example.test`;
const newPw = (tag) => `Aa1!${randomBytes(9).toString('base64url')}${tag}`;
const sql = (statement) => execFileSync('docker', ['exec', '-i', container, 'psql', '-U', 'postgres',
  '-X', '-At', '-v', 'ON_ERROR_STOP=1', '-c', statement], { encoding: 'utf8' }).trim();

const http = async (url, { method = 'POST', key = anon, bearer, body } = {}) => {
  const res = await fetch(url, { method,
    headers: { apikey: key, Authorization: `Bearer ${bearer ?? key}`, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* not json */ }
  return { status: res.status, json };
};
const login = (email, password) => http(`${api}/auth/v1/token?grant_type=password`, { body: { email, password } });
const refresh = (token) => http(`${api}/auth/v1/token?grant_type=refresh_token`, { body: { refresh_token: token } });
const fn = (token, body) => http(fnUrl, { bearer: token, body });
const rpc = (token, name, body = {}) => http(`${api}/rest/v1/rpc/${name}`, { bearer: token, body });
const hasPerm = async (token, store, perm = 'manageOrders') =>
  (await rpc(token, 'restaurant_has_permission', { p_restaurant_id: store, p_permission: perm })).json;

const results = [];
const check = (name, ok, detail) => {
  results.push({ name, ok: Boolean(ok) });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}  ${detail ?? ''}`);
};
const st = (r) => `status=${r.status}`;

const users = [];
try {
  // ---- fixtures: two owners with a restaurant store and one branch each ------
  const pw = { a: newPw('a'), b: newPw('b'), sub: newPw('s'), waiter: newPw('w') };
  const email = { a: mail('ownera'), b: mail('ownerb'), sub: mail('sub'), waiter: mail('waiter') };
  const uid = {}; const branch = {};
  for (const k of ['a', 'b']) {
    const r = await http(`${api}/auth/v1/admin/users`, { key: service, body: { email: email[k], password: pw[k], email_confirm: true } });
    if (!r.json?.id) throw new Error(`owner fixture ${r.status}`);
    uid[k] = r.json.id; users.push(uid[k]);
    sql(`insert into public.stores(seller_id, category, business_name) values ('${uid[k]}', 'Restoran', 'edgefn')`);
    branch[k] = sql(`insert into public.store_branches(store_id, name, status, is_primary) values ('${uid[k]}', 'Merkez', 'active', true) returning id`).split('\n')[0];
  }
  const tok = { a: (await login(email.a, pw.a)).json.access_token, b: (await login(email.b, pw.b)).json.access_token };
  const createBody = (k, role, permissions, extra = {}) => ({ operation: 'create', name: `Test ${k}`, email: email[k],
    password: pw[k], staff_role: role, branch_id: branch.a, permissions, request_id: `req-${run}-${k}-${randomBytes(3).toString('hex')}`,
    job_title: role === 'waiter' ? 'Garson' : 'Müdür', ...extra });

  // ---- E1: owner creates a sub-admin and a waiter ----------------------------
  const cSub = await fn(tok.a, createBody('sub', 'sub_admin', ['manageStaff', 'manageOrders', 'managePrintSettings', 'closeBill']));
  const cWaiter = await fn(tok.a, createBody('waiter', 'waiter', ['manageOrders', 'viewOrders']));
  check('E1: owner creates sub-admin and waiter', cSub.status === 200 && cSub.json?.ok && cWaiter.status === 200 && cWaiter.json?.ok, `${st(cSub)} ${st(cWaiter)} ${cWaiter.json?.message ?? ''}`);
  const member = { sub: cSub.json?.id, waiter: cWaiter.json?.id };
  for (const k of ['sub', 'waiter']) {
    uid[k] = sql(`select auth_user_id from public.store_sub_admins where id='${member[k]}'`); users.push(uid[k]);
  }
  const metaW = JSON.parse(sql(`select raw_app_meta_data from auth.users where id='${uid.waiter}'`));
  check('E1: new account is flagged, provisioned by the owner store, no forced password change',
    metaW.managed_restaurant_staff === true && metaW.provisioned_by_store_id === uid.a && metaW.must_change_password === false);
  const rowW = sql(`select store_id, branch_id, staff_role, status, job_title, array_to_string(permissions, ',') from public.store_sub_admins where id='${member.waiter}'`);
  check('E1: membership has store, branch, role, title and permissions', rowW === `${uid.a}|${branch.a}|waiter|active|Garson|manageOrders,viewOrders`, rowW.replaceAll(uid.a, 'A'));

  // ---- E2: staff log in with the normal e-mail / password login -------------
  const sW = (await login(email.waiter, pw.waiter)); const sS = (await login(email.sub, pw.sub));
  check('E2: waiter and sub-admin log in with e-mail + password', sW.status === 200 && sS.status === 200, `${st(sW)} ${st(sS)}`);
  tok.waiter = sW.json?.access_token; tok.sub = sS.json?.access_token;
  const accW = await rpc(tok.waiter, 'get_my_staff_access');
  check('E2: waiter is not gated and sees its own restaurant', (await rpc(tok.waiter, 'staff_must_change_password')).json === false
    && accW.json?.store_id === uid.a && accW.json?.staff_role === 'waiter' && (await hasPerm(tok.waiter, uid.a)) === true);
  check('E2: waiter has no permission in another restaurant, and none it was not given',
    (await hasPerm(tok.waiter, uid.b)) === false && (await hasPerm(tok.waiter, uid.a, 'closeBill')) === false
    && (await hasPerm(tok.sub, uid.a, 'closeBill')) === true && (await hasPerm(tok.sub, uid.a, 'managePrintSettings')) === true
    && (await hasPerm(tok.sub, uid.a, 'viewFinance')) === false);

  // ---- E3: sub-admin with manageStaff is refused the owner-only operations ---
  email.x = mail('x'); pw.x = newPw('x');
  const s1 = await fn(tok.sub, createBody('x', 'waiter', ['manageOrders']));
  check('E3: sub-admin cannot create a staff account', s1.status === 403
    && sql(`select count(*) from auth.users where email='${email.x}'`) === '0', st(s1));
  const hashW = sql(`select encrypted_password from auth.users where id='${uid.waiter}'`);
  const s2 = await fn(tok.sub, { operation: 'set_temporary_password', id: member.waiter, password: newPw('n') });
  const s3 = await fn(tok.sub, { operation: 'change_staff_password', password: newPw('n') });
  const s4 = await fn(tok.waiter, { operation: 'change_staff_password', password: newPw('n') });
  const s5 = await fn(tok.sub, { operation: 'clear_password_change' });
  check('E3: sub-admin / staff cannot set or change any password through the function',
    [s2, s3, s4, s5].every((r) => r.status === 403) && sql(`select encrypted_password from auth.users where id='${uid.waiter}'`) === hashW,
    [s2, s3, s4, s5].map((r) => r.status).join(','));
  const w1 = await fn(tok.waiter, { operation: 'deactivate', id: member.sub });
  const w2 = await fn(tok.waiter, createBody('x', 'waiter', ['manageOrders']));
  check('E4: waiter is refused every staff operation', w1.status === 403 && w2.status === 403, `${st(w1)} ${st(w2)}`);

  // ---- E5: another restaurant's owner ---------------------------------------
  const o1 = await fn(tok.b, { operation: 'deactivate', id: member.waiter });
  const o2 = await fn(tok.b, { operation: 'deactivate', id: member.waiter, store_id: uid.a });
  const o3 = await fn(tok.b, { operation: 'set_temporary_password', id: member.waiter, password: newPw('n') });
  const o4 = await fn(tok.b, { operation: 'delete', id: member.waiter });
  const o5 = await fn(tok.b, { operation: 'permissions', id: member.waiter, permissions: [] });
  check('E5: owner B cannot touch owner A staff (not found / forbidden), nothing changed',
    o1.status === 404 && o2.status === 403 && o3.status === 404 && o4.status === 404 && o5.status >= 400
    && sql(`select status || array_to_string(permissions, ',') from public.store_sub_admins where id='${member.waiter}'`) === 'activemanageOrders,viewOrders'
    && sql(`select encrypted_password from auth.users where id='${uid.waiter}'`) === hashW, [o1, o2, o3, o4, o5].map((r) => r.status).join(','));

  // ---- E6: permission removed -> refused at once with the same session -------
  const p1 = await fn(tok.a, { operation: 'permissions', id: member.waiter, permissions: ['viewOrders'] });
  check('E6: owner removes manageOrders; the same waiter session loses it immediately', p1.status === 200
    && (await hasPerm(tok.waiter, uid.a)) === false && (await hasPerm(tok.waiter, uid.a, 'viewOrders')) === true, st(p1));
  const p2 = await fn(tok.a, { operation: 'permissions', id: member.waiter, permissions: ['viewOrders', 'manageOrders'] });
  check('E6: owner gives it back; no new login needed for a permission change', p2.status === 200 && (await hasPerm(tok.waiter, uid.a)) === true, st(p2));
  const p3 = await fn(tok.sub, { operation: 'permissions', id: member.waiter, permissions: ['viewOrders', 'viewFinance'] });
  const p4 = await fn(tok.sub, { operation: 'permissions', id: member.sub, permissions: ['manageStaff', 'manageOrders', 'viewFinance'] });
  check('E6: sub-admin cannot grant a permission it does not hold, nor edit itself', p3.status === 403 && p4.status === 403, `${st(p3)} ${st(p4)}`);

  // ---- E7: deactivate -> old session dead, login refused; only owner reactivates
  const d1 = await fn(tok.sub, { operation: 'deactivate', id: member.waiter });
  check('E7: deactivate succeeds', d1.status === 200, st(d1));
  const banLogin = await login(email.waiter, pw.waiter);
  check('E7: deactivated waiter: old JWT refused in DB, refresh refused, new login refused (user_banned)',
    (await hasPerm(tok.waiter, uid.a)) === false && (await rpc(tok.waiter, 'get_my_staff_access')).json === null
    && (await refresh(sW.json.refresh_token)).status >= 400 && banLogin.status === 400 && banLogin.json?.error_code === 'user_banned',
    `login=${banLogin.status}/${banLogin.json?.error_code}`);
  const d2 = await fn(tok.waiter, { operation: 'list_branches' });
  check('E7: deactivated waiter old JWT is refused by the function too', d2.status === 401 || d2.status === 403, st(d2));
  const d3 = await fn(tok.sub, { operation: 'activate', id: member.waiter });
  check('E7: sub-admin cannot reactivate', d3.status === 403 && sql(`select status from public.store_sub_admins where id='${member.waiter}'`) === 'inactive', st(d3));
  const d4 = await fn(tok.b, { operation: 'activate', id: member.waiter });
  check('E7: owner B cannot reactivate', d4.status === 404, st(d4));
  const d5 = await fn(tok.a, { operation: 'activate', id: member.waiter });
  check('E7: owner reactivates', d5.status === 200 && sql(`select status from public.store_sub_admins where id='${member.waiter}'`) === 'active', st(d5));
  check('E7: reactivation does not revive the old session or refresh token',
    (await hasPerm(tok.waiter, uid.a)) === false && (await refresh(sW.json.refresh_token)).status >= 400);
  const sW2 = await login(email.waiter, pw.waiter);
  check('E7: a fresh password login works after reactivation', sW2.status === 200 && (await hasPerm(sW2.json.access_token, uid.a)) === true, st(sW2));

  // ---- E8: delete -> relink only by the owner that provisioned the account ----
  const x1 = await fn(tok.a, { operation: 'delete', id: member.waiter });
  check('E8: owner deletes the membership; Auth account kept (order history) but banned', x1.status === 200 && x1.json?.auth_removed === false
    && sql(`select count(*) from public.store_sub_admins where id='${member.waiter}'`) === '0'
    && (await login(email.waiter, pw.waiter)).json?.error_code === 'user_banned', `${st(x1)} removed=${x1.json?.auth_removed}`);
  check('E8: deleted waiter session is dead', (await hasPerm(sW2.json.access_token, uid.a)) === false && (await refresh(sW2.json.refresh_token)).status >= 400);
  const relinkBody = (extra = {}) => createBody('waiter', 'waiter', ['manageOrders'], extra);
  const x2 = await fn(tok.sub, relinkBody({ confirm_link: true }));
  check('E8: sub-admin (manageStaff) cannot relink the old account', x2.status === 403
    && sql(`select count(*) from public.store_sub_admins where auth_user_id='${uid.waiter}'`) === '0', st(x2));
  const x3 = await fn(tok.b, { ...relinkBody({ confirm_link: true }), branch_id: branch.b });
  check('E8: owner B cannot link an account provisioned by owner A', x3.status === 409 && x3.json?.linked === false && x3.json?.link_available === false
    && sql(`select count(*) from public.store_sub_admins where auth_user_id='${uid.waiter}'`) === '0', `${st(x3)} avail=${x3.json?.link_available}`);
  const x4 = await fn(tok.a, relinkBody());
  check('E8: owner A without explicit confirmation is asked first (nothing linked)', x4.status === 409 && x4.json?.link_available === true
    && sql(`select count(*) from public.store_sub_admins where auth_user_id='${uid.waiter}'`) === '0', st(x4));
  const x5 = await fn(tok.a, relinkBody({ confirm_link: true }));
  check('E8: owner A relinks with confirmation; password untouched', x5.status === 200 && x5.json?.linked_existing_auth === true
    && sql(`select encrypted_password from auth.users where id='${uid.waiter}'`) === hashW, `${st(x5)} ${x5.json?.message ?? ''}`);
  member.waiter = x5.json?.id;
  check('E8: relink does not revive old sessions', (await hasPerm(sW2.json.access_token, uid.a)) === false && (await refresh(sW2.json.refresh_token)).status >= 400
    && (await hasPerm(tok.waiter, uid.a)) === false);
  const sW3 = await login(email.waiter, pw.waiter);
  check('E8: fresh login after relink works', sW3.status === 200 && (await hasPerm(sW3.json.access_token, uid.a)) === true, st(sW3));

  // ---- E9: owner sets a password; stale sub-admin JWT cannot use the function -
  const nextPw = newPw('n');
  const q1 = await fn(tok.a, { operation: 'set_temporary_password', id: member.sub, password: nextPw });
  check('E9: owner sets the sub-admin password', q1.status === 200 && (await login(email.sub, pw.sub)).status !== 200, st(q1));
  const q2 = await fn(tok.sub, { operation: 'list_branches' });
  const q3 = await fn(tok.sub, { operation: 'deactivate', id: member.waiter });
  check('E9: sub-admin JWT from before the password change is refused by the function', q2.status === 401 && q3.status === 401
    && sql(`select status from public.store_sub_admins where id='${member.waiter}'`) === 'active', `${st(q2)} ${st(q3)}`);
  const sS2 = await login(email.sub, nextPw);
  const q4 = await fn(sS2.json?.access_token, { operation: 'list_branches' });
  check('E9: sub-admin logs in with the new password, no forced change, function works', sS2.status === 200 && q4.status === 200
    && (await rpc(sS2.json.access_token, 'staff_must_change_password')).json === false, `${st(sS2)} ${st(q4)}`);
  const q5 = await fn(tok.a, { operation: 'set_temporary_password', id: member.waiter, password: 'short' });
  const q6 = await fn(anon, { operation: 'list_branches' });
  check('E9: short password refused; anonymous caller refused', q5.status === 400 && q6.status === 401, `${st(q5)} ${st(q6)}`);
} finally {
  for (const id of users) {
    try { sql(`delete from public.store_sub_admins where auth_user_id='${id}' or store_id='${id}'`); } catch { /* ignore */ }
    try { sql(`delete from public.store_branches where store_id='${id}'`); } catch { /* ignore */ }
    try { sql(`delete from public.users where id='${id}'`); } catch { /* ignore */ }
    try { sql(`delete from public.stores where seller_id='${id}'`); } catch { /* ignore */ }
  }
  for (const id of users) {
    try { await http(`${api}/auth/v1/admin/users/${id}`, { method: 'DELETE', key: service, body: { should_soft_delete: false } }); } catch { /* ignore */ }
  }
  const left = users.length ? sql(`select count(*) from auth.users where id in (${users.map((i) => `'${i}'`).join(',')})`) : '0';
  console.log(`cleanup: leftover auth users = ${left}`);
}
const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} passed`);
process.exit(failed.length ? 1 : 0);
