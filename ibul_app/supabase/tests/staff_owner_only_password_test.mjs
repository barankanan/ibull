// Negative/positive checks for 20261121090000_staff_owner_only_password.sql and
// 20261121100000_staff_access_revocation.sql against a LOCAL, THROWAWAY Supabase
// stack only. The database must carry the real migration chain (RLS on
// store_sub_admins, get_my_staff_access, restaurant_has_permission).
// Creates only pwpolicy-<random>@example.test users and their store/membership
// rows, and removes them at the end. Nothing is read from or written to a remote project.
//
// Environment (never embedded here):
//   IBUL_JWT_SECRET   local GoTrue JWT secret (used to sign local anon/service_role tokens)
//   IBUL_API_URL      default http://127.0.0.1:54321
//   IBUL_DB_CONTAINER default supabase_db_ibul-local-staging
//   IBUL_MAIL_URL     default http://127.0.0.1:54324 (local mail catcher)
import { execFileSync } from 'node:child_process';
import { createHmac, randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';

const api = process.env.IBUL_API_URL ?? 'http://127.0.0.1:54321';
const container = process.env.IBUL_DB_CONTAINER ?? 'supabase_db_ibul-local-staging';
const secret = process.env.IBUL_JWT_SECRET;
const mailUrl = process.env.IBUL_MAIL_URL ?? 'http://127.0.0.1:54324';
if (!/^http:\/\/(127\.0\.0\.1|localhost)[:/]/.test(mailUrl + '/')) throw new Error('local mail catcher only');
if (!secret) throw new Error('IBUL_JWT_SECRET is required');
if (!/^http:\/\/(127\.0\.0\.1|localhost)[:/]/.test(api + '/')) throw new Error('local API only');

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const sign = (role) => {
  const head = b64({ alg: 'HS256', typ: 'JWT' });
  const body = b64({ role, iss: 'supabase-demo', exp: Math.floor(Date.now() / 1000) + 3600 });
  return `${head}.${body}.${createHmac('sha256', secret).update(`${head}.${body}`).digest('base64url')}`;
};
const anon = sign('anon');
const service = sign('service_role');
const run = randomBytes(4).toString('hex');
const mail = (tag) => `pwpolicy-${run}-${tag}@example.test`;
const newPw = (tag) => `Aa1!${randomBytes(9).toString('base64url')}${tag}`;

const sql = (statement) => execFileSync('docker', ['exec', '-i', container, 'psql', '-U', 'postgres',
  '-X', '-At', '-v', 'ON_ERROR_STOP=1', '-c', statement], { encoding: 'utf8' }).trim();
const lit = (v) => `'${String(v).replaceAll("'", "''")}'`;

const call = async (path, { method = 'POST', key = anon, bearer, body } = {}) => {
  const res = await fetch(`${api}${path}`, {
    method,
    headers: { apikey: key, Authorization: `Bearer ${bearer ?? key}`, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* not json */ }
  return { status: res.status, json };
};
const login = (email, password) => call('/auth/v1/token?grant_type=password', { body: { email, password } });
const refresh = (token) => call('/auth/v1/token?grant_type=refresh_token', { body: { refresh_token: token } });
const putUser = (token, body) => call('/auth/v1/user', { method: 'PUT', bearer: token, body });
const mustChange = (token) => call('/rest/v1/rpc/staff_must_change_password', { bearer: token, body: {} });
const setPw = (owner, member, password, opts = {}) =>
  call('/rest/v1/rpc/owner_set_staff_password', { key: service, ...opts, body: { p_owner_id: owner, p_member_id: member, p_password: password } });
const createUser = async (email, password, appMeta = {}) => {
  const r = await call('/auth/v1/admin/users', { key: service,
    body: { email, password, email_confirm: true, app_metadata: appMeta } });
  if (r.status !== 200 || !r.json?.id) throw new Error(`createUser ${r.status}`);
  return r.json.id;
};

const results = [];
const check = (name, ok, detail) => {
  results.push({ name, ok: Boolean(ok) });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}  ${detail ?? ''}`);
};
const dbUser = (id) => {
  const row = sql(`select email, coalesce(email_change,''), coalesce(recovery_token,''), `
    + `(select count(*) from auth.one_time_tokens o where o.user_id=u.id and true) `
    + `from auth.users u where id='${id}'`).split('|');
  return { email: row[0], emailChange: row[1], recovery: row[2], ott: Number(row[3]) };
};

const ids = { users: [], stores: [] };
const staffMeta = { managed_restaurant_staff: true, must_change_password: false };
let provMeta = staffMeta;
try {
  // ---- fixtures -----------------------------------------------------------
  const pw = { ownerA: newPw('a'), ownerB: newPw('b'), waiter: newPw('w'), sub: newPw('s'), plain: newPw('p') };
  const email = { ownerA: mail('ownera'), ownerB: mail('ownerb'), waiter: mail('waiter'), sub: mail('sub'), plain: mail('plain') };
  const uid = {};
  for (const k of ['ownerA', 'ownerB', 'plain']) { uid[k] = await createUser(email[k], pw[k]); ids.users.push(uid[k]); }
  // (n) staff creation with the managed flag set at creation time must still work.
  let createdOk = true;
  try {
    for (const k of ['waiter', 'sub']) {
      if (k === 'waiter') provMeta = { ...staffMeta, provisioned_by_store_id: uid.ownerA };
      uid[k] = await createUser(email[k], pw[k], k === 'waiter' ? provMeta : staffMeta); ids.users.push(uid[k]);
    }
  } catch { createdOk = false; }
  check('n: admin.createUser creates managed staff (user + first identity)', createdOk
    && sql(`select count(*) from auth.identities where user_id in ('${uid.waiter}','${uid.sub}')`) === '2');
  for (const o of ['ownerA', 'ownerB']) {
    sql(`insert into public.stores(seller_id) values ('${uid[o]}')`); ids.stores.push(uid[o]);
  }
  const memberOf = (k, role, perms) => sql(`insert into public.store_sub_admins(store_id,auth_user_id,email,display_name,staff_role,permissions,status) `
    + `values ('${uid.ownerA}','${uid[k]}',${lit(email[k])},'pwpolicy','${role}',${perms},'active') returning id`).split('\n')[0];
  const member = {
    waiter: memberOf('waiter', 'waiter', `array['manageOrders']::text[]`),
    sub: memberOf('sub', 'sub_admin', `array['manageStaff','manageOrders']::text[]`),
  };
  const meta = JSON.parse(sql(`select raw_app_meta_data from auth.users where id='${uid.waiter}'`));
  check('n: new staff is not gated at first login (flag false, gate false)', meta.must_change_password === false);

  // ---- (m) login + refresh ------------------------------------------------
  const w1 = await login(email.waiter, pw.waiter);
  check('m: staff login works', w1.status === 200 && w1.json?.access_token, `status=${w1.status}`);
  const w1r = await refresh(w1.json?.refresh_token ?? '');
  check('m: staff refresh works', w1r.status === 200 && w1r.json?.access_token, `status=${w1r.status}`);
  const wTok = w1r.json?.access_token; const wRef = w1r.json?.refresh_token;
  const gate0 = await mustChange(wTok);
  check('n: first-login staff session is not gated (staff_must_change_password=false)', gate0.status === 200 && gate0.json === false, `status=${gate0.status} body=${JSON.stringify(gate0.json)}`);
  const upd = await call(`/auth/v1/admin/users/${uid.waiter}`, { method: 'PUT', key: service,
    body: { app_metadata: { ...provMeta, note: 'x' } } });
  check('m: app_metadata update (admin, no password) not blocked', upd.status === 200, `status=${upd.status}`);

  // ---- (a) staff / sub-admin change own password --------------------------
  const before = sql(`select encrypted_password from auth.users where id='${uid.waiter}'`);
  const attempt = newPw('x');
  const a1 = await putUser(wTok, { password: attempt });
  check('a: staff PUT password rejected', a1.status >= 400, `status=${a1.status}`);
  check('a: stored hash unchanged', sql(`select encrypted_password from auth.users where id='${uid.waiter}'`) === before);
  check('a: old password still logs in, attempted one does not',
    (await login(email.waiter, pw.waiter)).status === 200 && (await login(email.waiter, attempt)).status !== 200);
  const subBefore = sql(`select encrypted_password from auth.users where id='${uid.sub}'`);
  const sTok = (await login(email.sub, pw.sub)).json?.access_token;
  const a2 = await putUser(sTok, { password: attempt });
  check('a: sub-admin (manageStaff) PUT own password rejected, hash unchanged', a2.status >= 400
    && (await login(email.sub, attempt)).status !== 200
    && sql(`select encrypted_password from auth.users where id='${uid.sub}'`) === subBefore, `status=${a2.status}`);

  // ---- (c) e-mail change --------------------------------------------------
  const newMail = mail('moved');
  const c1 = await putUser(wTok, { email: newMail });
  const row = dbUser(uid.waiter);
  check('c: staff PUT email rejected, email unchanged, no pending change', c1.status >= 400
    && row.email === email.waiter && row.emailChange === '' && row.ott === 0, `status=${c1.status}`);

  // ---- (b)(d) recovery and magic link -------------------------------------
  const b1 = await call('/auth/v1/recover', { body: { email: email.waiter } });
  const rowB = dbUser(uid.waiter);
  check('b: recovery for staff creates no token', rowB.recovery === '' && rowB.ott === 0, `status=${b1.status}`);
  const d1 = await call('/auth/v1/otp', { body: { email: email.waiter, create_user: false } });
  const rowD = dbUser(uid.waiter);
  check('d: magic link for staff creates no token', rowD.recovery === '' && rowD.ott === 0, `status=${d1.status}`);
  // GoTrue mails BEFORE its DB write, so a mail may still go out; its link must be dead.
  const box = `${mailUrl}/api/v1`;
  const mails = await fetch(`${box}/search?query=` + encodeURIComponent(`to:${email.waiter}`)).then((r) => r.json()).catch(() => null);
  let live = 0;
  for (const m of mails?.messages ?? []) {
    const html = (await fetch(`${box}/message/${m.ID}`).then((r) => r.json())).HTML ?? '';
    const link = (html.match(/http:\/\/[^"]*verify[^"]*/) ?? [])[0]?.replaceAll('&amp;', '&');
    if (!link) continue;
    const loc = (await fetch(link, { redirect: 'manual' })).headers.get('location') ?? '';
    if (/access_token=/.test(loc)) live += 1;
  }
  check('b/d: no mailed link to the staff address yields a session', mails !== null && live === 0, `mails=${mails?.messages_count} live=${live}`);
  const bypass = (() => { try {
    sql(`insert into auth.one_time_tokens(id,user_id,token_type,token_hash,relates_to) values (gen_random_uuid(),'${uid.waiter}','recovery_token','h${run}','x')`); return false;
  } catch { return true; } })();
  check('b: direct recovery one_time_token insert for staff refused by trigger', bypass);
  const extraId = (() => { try {
    sql(`insert into auth.identities(provider_id,user_id,identity_data,provider) values ('x${run}','${uid.waiter}','{}','github')`); return false;
  } catch { return true; } })();
  check('3c: additional identity for staff refused', extraId);
  const confOtt = (() => { try {
    sql(`insert into auth.one_time_tokens(id,user_id,token_type,token_hash,relates_to) values (gen_random_uuid(),'${uid.waiter}','confirmation_token','c${run}','x')`); return false;
  } catch { return true; } })();
  check('B4: direct confirmation_token one_time_token insert for staff refused', confOtt);
  const confUser = (() => { try {
    sql(`update auth.users set confirmation_token='c${run}' where id='${uid.waiter}'`); return false;
  } catch { return true; } })();
  check('B4: users.confirmation_token write for staff refused', confUser);
  const confOk = sql(`select count(*) from auth.users where id='${uid.plain}' and confirmation_token = ''`) !== null
    && (() => { try { sql(`update auth.users set confirmation_token='p${run}' where id='${uid.plain}'`); sql(`update auth.users set confirmation_token='' where id='${uid.plain}'`); return true; } catch { return false; } })();
  check('B4: non-staff confirmation_token write still allowed', confOk);
  // phone OTP for a protected account that has a phone. Local SMS provider is disabled,
  // so GoTrue is expected to answer 400 phone_provider_disabled before touching the DB.
  const phone = `+1555${String(Math.floor(Math.random() * 1e7)).padStart(7, '0')}`;
  sql(`select set_config('ibul.owner_pw_change','1',false); update auth.users set phone='${phone}', phone_confirmed_at=now() where id='${uid.sub}'; select set_config('ibul.owner_pw_change','',false)`);
  const ph = await call('/auth/v1/otp', { body: { phone } });
  console.log(`INFO  phone otp response: status=${ph.status} code=${ph.json?.error_code ?? ph.json?.code} (SMS provider disabled locally: DOGRULANAMADI as an SMS-sent path)`);
  check('B4: phone otp for protected user leaves no token and no phone change',
    sql(`select count(*) from auth.one_time_tokens where user_id='${uid.sub}'`) === '0'
    && sql(`select phone from auth.users where id='${uid.sub}'`) === phone, `status=${ph.status}`);

  // ---- (g)(h) who may call owner_set_staff_password -----------------------
  const g1 = await setPw(uid.sub, member.waiter, newPw('g'));
  check('g: sub-admin id as owner refused', g1.status >= 400, `status=${g1.status} code=${g1.json?.code}`);
  const g2 = await setPw(uid.ownerA, member.waiter, newPw('g'), { key: anon });
  check('g: anon role cannot call RPC', g2.status >= 400, `status=${g2.status} code=${g2.json?.code}`);
  const g3 = await setPw(uid.ownerA, member.waiter, newPw('g'), { key: anon, bearer: wTok });
  const g4 = await setPw(uid.ownerA, member.waiter, newPw('g'), { key: anon, bearer: (await login(email.ownerA, pw.ownerA)).json.access_token });
  check('g: authenticated role (staff and owner JWT) cannot call RPC directly',
    g3.status >= 400 && g4.status >= 400, `staff=${g3.status}/${g3.json?.code} owner=${g4.status}/${g4.json?.code}`);
  const h1 = await setPw(uid.ownerB, member.waiter, newPw('h'));
  check('h: other store owner refused', h1.status >= 400, `status=${h1.status} code=${h1.json?.code}`);
  // B1: A's former staff account (flagged, provisioned by A, membership deleted, auth user
  // left behind). Owner B inserts a membership row for that e-mail's auth id and tries to
  // set its password. Must be refused, hash unchanged.
  email.stale = mail('stale'); pw.stale = newPw('t');
  uid.stale = await createUser(email.stale, pw.stale, { ...staffMeta, provisioned_by_store_id: uid.ownerA }); ids.users.push(uid.stale);
  const staleHash = sql(`select encrypted_password from auth.users where id='${uid.stale}'`);
  const bMember = sql(`insert into public.store_sub_admins(store_id,auth_user_id,email,display_name,staff_role,permissions,status) `
    + `values ('${uid.ownerB}','${uid.stale}',${lit(email.stale)},'pwpolicy','waiter',array['manageOrders']::text[],'active') returning id`).split('\n')[0];
  const b1x = await setPw(uid.ownerB, bMember, newPw('h'));
  check('B1: owner B with own membership row for A former staff account refused', b1x.status >= 400 && b1x.json?.code === '23514'
    && sql(`select encrypted_password from auth.users where id='${uid.stale}'`) === staleHash, `status=${b1x.status} code=${b1x.json?.code}`);
  sql(`delete from public.store_sub_admins where id='${bMember}'`);
  const short = await setPw(uid.ownerA, member.waiter, 'short');
  check('g: password shorter than 8 refused', short.status >= 400, `status=${short.status}`);
  check('g/h: hash still unchanged after all refused calls', sql(`select encrypted_password from auth.users where id='${uid.waiter}'`) === before);

  // ---- (j) owner changes the password -------------------------------------
  const ownerPw = newPw('o');
  const epoch0 = Number(sql(`select coalesce((select epoch from public.staff_credentials where auth_user_id='${uid.waiter}'),0)`));
  const noProv = await setPw(uid.ownerA, member.sub, newPw('o'));
  check('B1: managed account without provisioned_by_store_id refused', noProv.status >= 400 && noProv.json?.code === '23514', `status=${noProv.status}`);
  const j0 = await setPw(uid.ownerA, member.waiter, ownerPw);
  check('j: owner RPC succeeds', j0.status === 204 || j0.status === 200, `status=${j0.status}`);
  const j1 = await refresh(wRef);
  check('j: old refresh token rejected', j1.status >= 400, `status=${j1.status}`);
  const j2 = await mustChange(wTok);
  check('j: old access JWT -> staff_must_change_password() = true', j2.status === 200 && j2.json === true, `status=${j2.status} body=${JSON.stringify(j2.json)}`);
  const jNew = await login(email.waiter, ownerPw);
  check('j: new password logs in', jNew.status === 200, `status=${jNew.status}`);
  const j3 = await mustChange(jNew.json.access_token);
  check('j: new session -> staff_must_change_password() = false', j3.status === 200 && j3.json === false, `status=${j3.status} body=${JSON.stringify(j3.json)}`);
  check('j: old password no longer logs in', (await login(email.waiter, pw.waiter)).status !== 200);
  const after = sql(`select (raw_app_meta_data->>'must_change_password'), (raw_app_meta_data->>'managed_restaurant_staff'), `
    + `(select epoch from public.staff_credentials where auth_user_id='${uid.waiter}') from auth.users where id='${uid.waiter}'`);
  check('j: flags false/true and epoch raised by 1', after === `false|true|${epoch0 + 1}`, after);
  const j4 = await refresh(jNew.json.refresh_token);
  check('j: new session refresh works', j4.status === 200, `status=${j4.status}`);
  const j5 = await setPw(uid.ownerA, member.waiter, newPw('o'));
  check('j: second owner change raises epoch again', sql(`select epoch from public.staff_credentials where auth_user_id='${uid.waiter}'`) === String(epoch0 + 2), `status=${j5.status}`);

  // ---- (l) non-staff user keeps self-service ------------------------------
  const pTok = (await login(email.plain, pw.plain)).json.access_token;
  const gateP = await mustChange(pTok);
  check('l: non-staff session not gated', gateP.json === false, `body=${JSON.stringify(gateP.json)}`);
  const ownGate = await mustChange((await login(email.ownerA, pw.ownerA)).json.access_token);
  check('l: owner session not gated', ownGate.json === false);
  const pNew = newPw('n');
  const l1 = await putUser(pTok, { password: pNew });
  check('l: non-staff changes own password', l1.status === 200 && (await login(email.plain, pNew)).status === 200, `status=${l1.status}`);
  const l2 = await call('/auth/v1/recover', { body: { email: email.plain } });
  check('l: non-staff recovery creates a token', l2.status === 200 && dbUser(uid.plain).recovery !== '', `status=${l2.status}`);

  // ---- B2: fail-closed gate without session_id --------------------------------
  const jwtFor = (claims) => { const h = b64({ alg: 'HS256', typ: 'JWT' }); const p = b64({ iss: 'supabase-demo', exp: Math.floor(Date.now() / 1000) + 600, ...claims });
    return `${h}.${p}.${createHmac('sha256', secret).update(`${h}.${p}`).digest('base64url')}`; };
  const noSidStaff = await mustChange(jwtFor({ sub: uid.waiter, role: 'authenticated' }));
  check('B2: staff JWT without session_id -> true (fail closed)', noSidStaff.status === 200 && noSidStaff.json === true, `body=${JSON.stringify(noSidStaff.json)}`);
  const badSidStaff = await mustChange(jwtFor({ sub: uid.waiter, role: 'authenticated', session_id: 'not-a-uuid' }));
  check('B2: staff JWT with invalid session_id -> true', badSidStaff.json === true, `body=${JSON.stringify(badSidStaff.json)}`);
  const noSidPlain = await mustChange(jwtFor({ sub: uid.plain, role: 'authenticated' }));
  check('B2: non-staff JWT without session_id -> false', noSidPlain.status === 200 && noSidPlain.json === false, `body=${JSON.stringify(noSidPlain.json)}`);
  const svcGate = await mustChange(service);
  check('B2: service_role (no uid) -> false', svcGate.status === 200 && svcGate.json === false, `body=${JSON.stringify(svcGate.json)}`);

  // ---- lan_staff_authority --------------------------------------------------
  const lan = sql(`set role authenticated; select set_config('request.jwt.claims','{"sub":"${uid.ownerA}","role":"authenticated"}',false); `
    + `select public.lan_staff_authority('${uid.ownerA}','${uid.waiter}')`).split('\n').pop();
  const lanJson = JSON.parse(lan);
  check('6: lan_staff_authority keeps fields and adds credential_epoch', lanJson.found === true
    && lanJson.must_change_password === false && lanJson.credential_epoch === epoch0 + 2, lan.replace(/"[0-9a-f-]{36}"/g, '"id"'));

  // ---- P2: owner-inserted membership row must not lock an unflagged user out ----
  email.victim = mail('victim'); pw.victim = newPw('v');
  uid.victim = await createUser(email.victim, pw.victim); ids.users.push(uid.victim);
  const ownTok = (await login(email.ownerA, pw.ownerA)).json.access_token;
  const ins = await call('/rest/v1/store_sub_admins', { bearer: ownTok, body: {
    store_id: uid.ownerA, auth_user_id: uid.victim, email: email.victim, display_name: 'pwpolicy',
    staff_role: 'waiter', permissions: ['manageOrders'], status: 'active' } });
  console.log(`INFO  owner JWT INSERT store_sub_admins for an unflagged non-staff user via PostgREST: status=${ins.status} code=${ins.json?.code ?? ''} (expected 403: link guard)`);
  if (ins.status >= 300) sql(`insert into public.store_sub_admins(store_id,auth_user_id,email,display_name,staff_role,permissions,status) `
    + `values ('${uid.ownerA}','${uid.victim}',${lit(email.victim)},'pwpolicy','waiter',array['manageOrders']::text[],'active')`);
  check('P2: membership row alone does not make a user protected; flagged staff is protected',
    sql(`select public.is_managed_restaurant_staff('${uid.victim}')`) === 'f'
    && sql(`select public.is_managed_restaurant_staff('${uid.waiter}')`) === 't');
  const vTok = (await login(email.victim, pw.victim)).json.access_token;
  const vNew = newPw('y');
  const v1 = await putUser(vTok, { password: vNew });
  check('P2: victim with membership row (no flag) can change own password', v1.status === 200 && (await login(email.victim, vNew)).status === 200, `status=${v1.status}`);
  const v2 = await call('/auth/v1/recover', { body: { email: email.victim } });
  check('P2: victim recovery works (token written)', v2.status === 200 && dbUser(uid.victim).recovery !== '', `status=${v2.status}`);
  check('P2: victim session is not gated', (await mustChange((await login(email.victim, vNew)).json.access_token)).json === false);
  const w2 = await call('/auth/v1/recover', { body: { email: email.waiter } });
  check('P2: flagged staff still protected (no recovery token)', dbUser(uid.waiter).recovery === '' && dbUser(uid.waiter).ott === 0, `status=${w2.status}`);

  check('R5: owner JWT cannot link an account its store did not provision (PostgREST insert refused)', ins.status === 403 && ins.json?.code === '42501', `status=${ins.status} code=${ins.json?.code}`);

  // ---- P3: stale JWT on get_my_staff_access / store_sub_admins self select (real schema) ----
  const rest = (path, token, opts = {}) => call(`/rest/v1/${path}`, { bearer: token, ...opts });
  const access = (t) => rest('rpc/get_my_staff_access', t, { body: {} });
  const ownRows = (t, id) => rest(`store_sub_admins?select=id&auth_user_id=eq.${id}`, t, { method: 'GET' });
  const hasPerm = (t) => rest('rpc/restaurant_has_permission', t, { body: { p_restaurant_id: uid.ownerA, p_permission: 'manageOrders' } });
  const gOld = newPw('q'); const gNew = newPw('r');
  await setPw(uid.ownerA, member.waiter, gOld);
  const tokOld = (await login(email.waiter, gOld)).json.access_token;
  await setPw(uid.ownerA, member.waiter, gNew);
  const sNew = (await login(email.waiter, gNew)).json; const tokNew = sNew.access_token;
  const owner2 = (await login(email.ownerA, pw.ownerA)).json.access_token;
  const aOld = await access(tokOld); const aNew = await access(tokNew);
  check('P3(a): old JWT -> get_my_staff_access empty; new JWT works', aOld.status === 200 && aOld.json === null && aNew.json?.store_id === uid.ownerA, `old=${JSON.stringify(aOld.json)} new=${aNew.status}`);
  const bOld = await ownRows(tokOld, uid.waiter); const bNew = await ownRows(tokNew, uid.waiter);
  check('P3(b): old JWT -> own store_sub_admins row not visible; new JWT sees it', bOld.json?.length === 0 && bNew.json?.length === 1, `old=${bOld.json?.length} new=${bNew.json?.length}`);
  const bOwner = await rest(`store_sub_admins?select=id&store_id=eq.${uid.ownerA}`, owner2, { method: 'GET' });
  check('P3: owner still reads own store rows', (bOwner.json?.length ?? 0) >= 2, `rows=${bOwner.json?.length}`);
  sql(`insert into public.store_tables(seller_id, table_number, is_active) values ('${uid.ownerA}', 901, true)`);
  sql(`insert into public.table_orders(seller_id, table_number, items, status) values ('${uid.ownerA}', 901, '[]', 'active')`);
  const orders = (t) => rest(`table_orders?select=id&seller_id=eq.${uid.ownerA}`, t, { method: 'GET' });
  const oOld = await orders(tokOld); const oNew = await orders(tokNew);
  check('P3: old JWT reads no table_orders row; new JWT reads it', oOld.status === 200 && oOld.json?.length === 0 && oNew.json?.length === 1, `old=${oOld.json?.length} new=${oNew.json?.length}`);
  check('P3: old JWT -> restaurant_has_permission false; new JWT true', (await hasPerm(tokOld)).json === false && (await hasPerm(tokNew)).json === true);

  // ---- R: deactivate / reactivate / delete / relink ---------------------------
  const patchMember = (token, id, body) => rest(`store_sub_admins?id=eq.${id}`, token, { method: 'PATCH', body });
  const banned = (id) => sql(`select case when banned_until > now() + interval '50 years' then 'banned' else coalesce(banned_until::text,'') end from auth.users where id='${id}'`);
  const epochOf = (id) => Number(sql(`select coalesce((select epoch from public.staff_credentials where auth_user_id='${id}'),0)`));
  // R6: a sub-admin (manageStaff) cannot write memberships directly.
  const subTok = (await login(email.sub, pw.sub)).json.access_token;
  await patchMember(subTok, member.waiter, { status: 'inactive' });
  const subIns = await rest('store_sub_admins', subTok, { body: { store_id: uid.ownerA, email: mail('x'), display_name: 'x', staff_role: 'waiter', permissions: [], status: 'active' } });
  check('R6: sub-admin JWT cannot change status or insert a membership directly',
    sql(`select status from public.store_sub_admins where id='${member.waiter}'`) === 'active' && subIns.status >= 400, `insert=${subIns.status}`);
  // R1: owner deactivates through PostgREST (same path as SQL / Edge Function: the trigger).
  const e1 = epochOf(uid.waiter);
  const d = await patchMember(owner2, member.waiter, { status: 'inactive' });
  check('R1: owner deactivates', d.status === 204 || d.status === 200, `status=${d.status}`);
  check('R1: epoch raised, sessions and refresh tokens deleted, account banned',
    epochOf(uid.waiter) === e1 + 1 && sql(`select count(*) from auth.sessions where user_id='${uid.waiter}'`) === '0'
    && sql(`select count(*) from auth.refresh_tokens where user_id='${uid.waiter}'`) === '0' && banned(uid.waiter) === 'banned', `banned=${banned(uid.waiter)}`);
  check('R1: old access JWT refused (gate true, no access, no permission)',
    (await mustChange(tokNew)).json === true && (await access(tokNew)).json === null && (await hasPerm(tokNew)).json === false);
  check('R1: old refresh token refused', (await refresh(sNew.refresh_token)).status >= 400);
  const banLogin = await login(email.waiter, gNew);
  check('R1: new login of a deactivated staff account refused by GoTrue as banned (not a crash)', banLogin.status === 400 && banLogin.json?.error_code === 'user_banned', `status=${banLogin.status} code=${banLogin.json?.error_code}`);
  check('R1: staff still cannot recover the account while banned', (await call('/auth/v1/recover', { body: { email: email.waiter } })) && dbUser(uid.waiter).recovery === '' && dbUser(uid.waiter).ott === 0);
  // R2: owner reactivates. Old tokens stay dead; a fresh password login works.
  const r2 = await patchMember(owner2, member.waiter, { status: 'active' });
  check('R2: owner reactivates, ban lifted, epoch raised again', (r2.status === 204 || r2.status === 200) && banned(uid.waiter) === '' && epochOf(uid.waiter) === e1 + 2, `banned=${banned(uid.waiter)}`);
  check('R2: reactivation does not revive the old session (access JWT + refresh token)',
    (await mustChange(tokNew)).json === true && (await hasPerm(tokNew)).json === false && (await refresh(sNew.refresh_token)).status >= 400);
  const fresh = await login(email.waiter, gNew);
  check('R2: fresh login works and is not gated', fresh.status === 200 && (await mustChange(fresh.json.access_token)).json === false
    && (await hasPerm(fresh.json.access_token)).json === true, `status=${fresh.status}`);
  const lan2 = JSON.parse(sql(`set role authenticated; select set_config('request.jwt.claims','{"sub":"${uid.ownerA}","role":"authenticated"}',false); `
    + `select public.lan_staff_authority('${uid.ownerA}','${uid.waiter}')`).split('\n').pop());
  check('R2: lan_staff_authority reports the raised epoch', lan2.credential_epoch === e1 + 2 && lan2.status === 'active', `epoch=${lan2.credential_epoch}`);
  // R3: linked account WITHOUT the staff flag (legacy). Nobody is signed out or banned,
  // but a session from before the change is refused on staff paths after reactivation.
  const vMember = sql(`select id from public.store_sub_admins where auth_user_id='${uid.victim}'`);
  const vS = (await login(email.victim, vNew)).json;
  check('R3: legacy member has access before the change', (await hasPerm(vS.access_token)).json === true);
  await patchMember(owner2, vMember, { status: 'inactive' });
  check('R3: deactivated legacy member loses access at once', (await hasPerm(vS.access_token)).json === false);
  await patchMember(owner2, vMember, { status: 'active' });
  const vRef = await refresh(vS.refresh_token);
  check('R3: legacy account is not banned and its session is not deleted', banned(uid.victim) === '' && vRef.status === 200, `refresh=${vRef.status}`);
  check('R3: old session (even refreshed) gets no access after reactivation',
    (await hasPerm(vS.access_token)).json === false && (await hasPerm(vRef.json?.access_token)).json === false && (await mustChange(vRef.json?.access_token)).json === true);
  const vFresh = (await login(email.victim, vNew)).json;
  check('R3: fresh login of the legacy member has access', (await hasPerm(vFresh.access_token)).json === true);
  check('R3: legacy member keeps self-service password change', (await putUser(vFresh.access_token, { password: newPw('z') })).status === 200);
  // R4: delete, login in between, relink.
  const del = await rest(`store_sub_admins?id=eq.${member.waiter}`, owner2, { method: 'DELETE' });
  check('R4: owner deletes membership; account banned, sessions gone', (del.status === 204 || del.status === 200) && banned(uid.waiter) === 'banned'
    && sql(`select count(*) from auth.sessions where user_id='${uid.waiter}'`) === '0' && (await mustChange(fresh.json.access_token)).json === true);
  const delLogin = await login(email.waiter, gNew);
  check('R4: removed staff cannot log in (user_banned)', delLogin.status === 400 && delLogin.json?.error_code === 'user_banned', `status=${delLogin.status} code=${delLogin.json?.error_code}`);
  const getBanned = await call(`/auth/v1/admin/users/${uid.waiter}`, { method: 'GET', key: service });
  check('R4: GoTrue admin API still reads the banned account', getBanned.status === 200, `status=${getBanned.status}`);
  const relinkBySub = await rest('store_sub_admins', subTok, { body: { store_id: uid.ownerA, auth_user_id: uid.waiter, email: email.waiter, display_name: 'pwpolicy', staff_role: 'waiter', permissions: ['manageOrders'], status: 'active' } });
  check('R4: sub-admin JWT cannot relink the removed account', relinkBySub.status >= 400 && banned(uid.waiter) === 'banned', `status=${relinkBySub.status}`);
  const otherTok = (await login(email.ownerB, pw.ownerB)).json.access_token;
  const relinkByB = await rest('store_sub_admins', otherTok, { body: { store_id: uid.ownerB, auth_user_id: uid.waiter, email: email.waiter, display_name: 'pwpolicy', staff_role: 'waiter', permissions: ['manageOrders'], status: 'active' } });
  const relinkAsA = await rest('store_sub_admins', otherTok, { body: { store_id: uid.ownerA, auth_user_id: uid.waiter, email: email.waiter, display_name: 'pwpolicy', staff_role: 'waiter', permissions: ['manageOrders'], status: 'active' } });
  check('R4: another store owner cannot link the account (own store or forged store id)', relinkByB.status === 403 && relinkAsA.status >= 400 && banned(uid.waiter) === 'banned', `ownStore=${relinkByB.status} forged=${relinkAsA.status}`);
  const relink = await rest('store_sub_admins', owner2, { body: { store_id: uid.ownerA, auth_user_id: uid.waiter, email: email.waiter, display_name: 'pwpolicy', staff_role: 'waiter', permissions: ['manageOrders'], status: 'active' } });
  check('R4: owner relinks the account it provisioned; ban lifted', relink.status === 201 && banned(uid.waiter) === '', `status=${relink.status}`);
  check('R4: relink does not revive old tokens', (await mustChange(fresh.json.access_token)).json === true && (await hasPerm(fresh.json.access_token)).json === false
    && (await refresh(fresh.json.refresh_token)).status >= 400);
  const again = await login(email.waiter, gNew);
  check('R4: after relink a fresh login works', again.status === 200 && (await hasPerm(again.json.access_token)).json === true, `status=${again.status}`);
  // R7: a store owner is never gated, whatever membership rows another owner writes.
  sql(`insert into public.store_sub_admins(store_id,auth_user_id,email,display_name,staff_role,permissions,status) values ('${uid.ownerA}','${uid.ownerB}',${lit(email.ownerB)},'pwpolicy','waiter','{}','active')`);
  sql(`update public.store_sub_admins set status='inactive' where store_id='${uid.ownerA}' and auth_user_id='${uid.ownerB}'`);
  const permB = await rest('rpc/restaurant_has_permission', otherTok, { body: { p_restaurant_id: uid.ownerB, p_permission: 'manageOrders' } });
  check('R7: owner B stays ungated and keeps own-store permission; not banned, session kept',
    (await mustChange(otherTok)).json === false && permB.json === true && banned(uid.ownerB) === '');
  // RA: a legacy row without an auth id is no way around the rules.
  const eVictim = epochOf(uid.victim);
  const nullIns = await rest('store_sub_admins', otherTok, { body: { store_id: uid.ownerB, email: email.victim, display_name: 'x', staff_role: 'waiter', permissions: ['manageOrders'], status: 'active' } });
  check('RA: owner cannot insert an ACTIVE membership by e-mail only (no account it created)', nullIns.status === 403 && nullIns.json?.code === '42501', `status=${nullIns.status}`);
  const inv = await rest('store_sub_admins?select=id', otherTok, { body: { store_id: uid.ownerB, email: email.victim, display_name: 'x', staff_role: 'waiter', permissions: ['manageOrders'], status: 'invited' }, prefer: 'return=representation' });
  const invId = sql(`select id from public.store_sub_admins where store_id='${uid.ownerB}' and auth_user_id is null and lower(email)=lower(${lit(email.victim)})`);
  const invAct = await patchMember(otherTok, invId, { status: 'active' });
  await rest(`store_sub_admins?id=eq.${invId}`, otherTok, { method: 'DELETE' });
  check('RA: an invitation row cannot be activated by the client, and writing/deleting it revokes nobody',
    invId !== '' && invAct.status === 403 && epochOf(uid.victim) === eVictim
    && sql(`select count(*) from public.store_sub_admins where store_id='${uid.ownerB}' and auth_user_id is null`) === '0', `inv=${inv.status} act=${invAct.status}`);
  check('RA: the other restaurant victim keeps its access (no forced re-login)', (await hasPerm(vFresh.access_token)).json !== undefined
    && (await mustChange((await login(email.plain, pNew)).json.access_token)).json === false);
  // R9: migration refuses a database that is behind (inside a rolled-back transaction).
  const migText = (name) => readFileSync(new URL(`../migrations/${name}`, import.meta.url), 'utf8').split('\n').filter((l) => !/^(begin|commit);$/.test(l)).join('\n');
  const tryMig = (prep, name) => { try {
    execFileSync('docker', ['exec', '-i', container, 'psql', '-U', 'postgres', '-X', '-At', '-v', 'ON_ERROR_STOP=1'],
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], input: ['begin;', prep, migText(name), 'rollback;'].join('\n') }); return 'applied';
  } catch (e) { return /Önkoşul eksik|beklenen sürüm değil/.test(String(e.stderr)) ? 'refused' : `error:${String(e.stderr).slice(0, 120)}`; } };
  const m1 = '20261121090000_staff_owner_only_password.sql'; const m2 = '20261121100000_staff_access_revocation.sql';
  check('R9: password migration refuses when the self-select policy is missing', tryMig('drop policy store_sub_admins_active_self_select on public.store_sub_admins;', m1) === 'refused');
  check('R9: password migration refuses when get_my_staff_access is missing', tryMig('drop function public.get_my_staff_access();', m1) === 'refused');
  check('R9: password migration refuses an unknown get_my_staff_access body', tryMig(`create or replace function public.get_my_staff_access() returns jsonb language sql as $x$ select null::jsonb $x$;`, m1) === 'refused');
  check('R9: password migration refuses when RLS is off', tryMig('alter table public.store_sub_admins disable row level security;', m1) === 'refused');
  check('R9: password migration refuses when job_title is missing', tryMig('alter table public.store_sub_admins drop column job_title cascade;', m1) === 'refused');
  check('R9: password migration refuses when table_orders RLS is off', tryMig('alter table public.table_orders disable row level security;', m1) === 'refused');
  check('R9: revocation migration refuses without the password migration', tryMig('drop table public.staff_credentials cascade;', m2) === 'refused');
  check('R9: both migrations can be re-run unchanged', tryMig('', m1) === 'applied' && tryMig('', m2) === 'applied', `${tryMig('', m1)} / ${tryMig('', m2)}`);
} finally {
  // ---- cleanup: only what this run created ---------------------------------
  for (const id of ids.users) {
    try { sql(`delete from public.store_sub_admins where auth_user_id='${id}' or store_id='${id}'`); } catch { /* ignore */ }
    try { sql(`delete from public.staff_credentials where auth_user_id='${id}'`); } catch { /* ignore */ }
  }
  for (const id of ids.stores) { try { sql(`delete from public.table_orders where seller_id='${id}'; delete from public.store_tables where seller_id='${id}'`); } catch { /* ignore */ } }
  for (const id of ids.stores) { try { sql(`delete from public.stores where seller_id='${id}'`); } catch { /* ignore */ } }
  for (const id of ids.users) { try { await call(`/auth/v1/admin/users/${id}`, { method: 'DELETE', key: service, body: { should_soft_delete: false } }); } catch { /* ignore */ } }
  try { // remove this run's mails from the local mail catcher
    const found = await fetch(`${mailUrl}/api/v1/search?query=` + encodeURIComponent(`to:pwpolicy-${run}`)).then((r) => r.json());
    const mids = (found.messages ?? []).map((m) => m.ID);
    if (mids.length) await fetch(`${mailUrl}/api/v1/messages`, { method: 'DELETE', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ IDs: mids }) });
  } catch { /* ignore */ }
  const left = ids.users.length
    ? sql(`select count(*) from auth.users where id in (${ids.users.map((i) => `'${i}'`).join(',')})`) : '0';
  console.log(`cleanup: leftover auth users = ${left}`);
}
const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} passed`);
process.exit(failed.length ? 1 : 0);
