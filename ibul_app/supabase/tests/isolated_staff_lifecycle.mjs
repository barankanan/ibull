// Real manage-restaurant-staff handler against throwaway PostgreSQL.
// No production connection, dump, or customer row.
import { execFileSync } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import assert from 'node:assert/strict';
const fxPw = (k, n) => `Aa1!${k}-fixture-fixture-fixture`.slice(0, n); // test-only deterministic fake, not a real password

const psql = process.env.IBUL_PSQL;
const host = process.env.IBUL_PGHOST;
const port = process.env.IBUL_PGPORT;
const database = process.env.IBUL_PGDATABASE;
assert.ok(psql && host && port && database);

const sql = (statement) => {
  try {
    const out = execFileSync(psql, [
      '-h', host, '-p', port, '-U', 'postgres', '-d', database,
      '-v', 'ON_ERROR_STOP=1', '-At', '-c', statement,
    ], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    return { ok: true, out: out.trim() };
  } catch (error) {
    const detail = `${error.stderr ?? ''}\n${error.stdout ?? ''}`;
    return { ok: false, error: detail };
  }
};

const lit = (value) => {
  if (value == null) return 'null';
  if (Array.isArray(value)) return `array[${value.map(lit).join(',')}]::text[]`;
  if (typeof value === 'number') return Number.isFinite(value) ? String(value) : 'null';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'object') {
    return `${lit(JSON.stringify(value))}::jsonb`;
  }
  return `'${String(value).replaceAll("'", "''")}'`;
};
const ident = (name) => {
  if (!/^[a-z_]+$/.test(name)) throw new Error(`unsafe identifier ${name}`);
  return name;
};

const setup = sql(`
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
create table auth.users (
  id uuid primary key,
  email text unique,
  encrypted_password text,
  raw_app_meta_data jsonb not null default '{}'::jsonb,
  email_confirmed_at timestamptz,
  phone text,
  phone_confirmed_at timestamptz
);
create table public.stores (seller_id uuid primary key, category text);
create table public.store_branches (
  id uuid primary key, store_id uuid not null, name text, status text not null
);
create table public.users (
  id uuid primary key, email text, display_name text, role text
);
create table public.store_sub_admins (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null,
  email text,
  auth_user_id uuid,
  display_name text,
  staff_role text check (staff_role in ('waiter','sub_admin')),
  branch_id uuid,
  permissions text[] not null default '{}',
  status text not null,
  creation_request_id text,
  created_at timestamptz not null default now()
);
create or replace function public.validate_restaurant_staff_membership()
returns trigger language plpgsql as $$
begin
  if new.branch_id is not null and not exists(
    select 1 from public.store_branches
    where id = new.branch_id and store_id = new.store_id
  ) then
    raise exception 'Şube bu işletmeye ait değil.' using errcode = '42501';
  end if;
  if not new.permissions <@ array['manageProducts','viewOrders','manageOrders','manageCampaigns','viewFinance','manageSupport','manageStoreProfile']::text[] then
    raise exception 'Geçersiz yetki.' using errcode = '22023';
  end if;
  if new.auth_user_id is not null and not exists(
    select 1 from auth.users
    where id = new.auth_user_id and lower(email) = lower(new.email)
  ) then
    raise exception 'Auth kimliği uyuşmuyor.' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger validate_restaurant_staff
  before insert or update on public.store_sub_admins
  for each row execute function public.validate_restaurant_staff_membership();
create or replace function public.get_my_staff_access()
returns jsonb language sql stable as $$
  select case when count(*)=0 then null else jsonb_build_object(
    'store_id',(jsonb_agg(to_jsonb(sa.store_id) order by sa.created_at))->0,
    'branch_id',(jsonb_agg(to_jsonb(sa.branch_id) order by sa.created_at))->0,
    'staff_role',(jsonb_agg(to_jsonb(sa.staff_role) order by sa.created_at))->0,
    'permissions',(jsonb_agg(to_jsonb(sa.permissions) order by sa.created_at))->0
  ) end
  from public.store_sub_admins sa
  join auth.users au on au.id = auth.uid()
  where sa.status = 'active'
    and (sa.branch_id is null or exists(
      select 1 from public.store_branches b
      where b.id = sa.branch_id and b.store_id = sa.store_id and b.status = 'active'
    ))
    and sa.auth_user_id = au.id;
$$;
`);
assert.equal(setup.ok, true, setup.error);

const owner = '10000000-0000-4000-8000-000000000001';
const other = '10000000-0000-4000-8000-000000000002';
const branch = '30000000-0000-4000-8000-000000000001';
const second = '30000000-0000-4000-8000-000000000002';
const foreignBranch = '30000000-0000-4000-8000-000000000099';
assert.equal(sql(`
insert into public.stores values ('${owner}','Yemek'), ('${other}','Elektronik');
insert into public.store_branches values
  ('${branch}','${owner}','Salon','active'),
  ('${second}','${owner}','Teras','active'),
  ('${foreignBranch}','${other}','Diger','active');
`).ok, true);

const rowsOf = (table, filters) => {
  const where = filters.length === 0
    ? 'true'
    : filters.map(([key, value]) => `${ident(key)} = ${lit(value)}`).join(' and ');
  const result = sql(`select coalesce(json_agg(row_to_json(t)), '[]'::json) from (select * from ${ident(table)} where ${where}) t`);
  if (!result.ok) return { rows: null, error: result.error };
  return { rows: JSON.parse(result.out || '[]'), error: null };
};

const serviceClient = {
  from(table) {
    const filters = [];
    let op = 'select';
    let payload = null;
    let countOnly = false;
    const query = {
      select(_columns, options) {
        countOnly = options?.head === true;
        return query;
      },
      eq(key, value) { filters.push([key, value]); return query; },
      update(value) { op = 'update'; payload = value; return query; },
      insert(value) { op = 'insert'; payload = value; return query; },
      upsert(value) { op = 'upsert'; payload = value; return query; },
      delete() { op = 'delete'; return query; },
      maybeSingle() { return finish('maybe'); },
      single() { return finish('single'); },
      then(resolve, reject) { return finish('list').then(resolve, reject); },
    };
    const finish = async (mode) => {
      if (op === 'select' && countOnly) {
        const found = rowsOf(table, filters);
        if (found.error) return { data: null, error: { message: found.error }, count: null };
        return { data: null, error: null, count: found.rows.length };
      }
      if (op === 'select') {
        const found = rowsOf(table, filters);
        if (found.error) return { data: null, error: { message: found.error } };
        if (mode === 'list') return { data: found.rows, error: null };
        if (mode === 'maybe') {
          return {
            data: found.rows.length === 1 ? found.rows[0] : null,
            error: found.rows.length > 1 ? { message: 'multiple' } : null,
          };
        }
        if (found.rows.length !== 1) return { data: null, error: { message: 'row count' } };
        return { data: found.rows[0], error: null };
      }
      if (op === 'delete') {
        const result = sql(`delete from ${ident(table)} where ${filters.map(([key, value]) => `${ident(key)} = ${lit(value)}`).join(' and ')}`);
        return { data: null, error: result.ok ? null : { message: result.error } };
      }
      const assignments = Object.entries(payload).map(([key, value]) => `${ident(key)} = ${lit(value)}`);
      if (op === 'update') {
        const where = filters.map(([key, value]) => `${ident(key)} = ${lit(value)}`).join(' and ');
        const result = sql(`with changed as (update ${ident(table)} set ${assignments.join(', ')} where ${where} returning *) select row_to_json(changed) from changed`);
        if (!result.ok) return { data: null, error: { message: result.error } };
        const lines = result.out.split('\n').filter((line) => line.startsWith('{'));
        if (lines.length !== 1) return { data: null, error: { message: 'row count' } };
        return { data: JSON.parse(lines[0]), error: null };
      }
      const columns = Object.keys(payload);
      const values = columns.map((key) => lit(payload[key]));
      const conflict = op === 'upsert'
        ? ` on conflict (id) do update set ${columns.filter((key) => key !== 'id').map((key) => `${ident(key)} = excluded.${ident(key)}`).join(', ')}`
        : '';
      const result = sql(`with changed as (insert into ${ident(table)} (${columns.map(ident).join(',')}) values (${values.join(',')})${conflict} returning *) select row_to_json(changed) from changed`);
      if (!result.ok) return { data: null, error: { message: result.error } };
      const line = result.out.split('\n').find((item) => item.startsWith('{'));
      if (!line) return { data: null, error: { message: 'Üyelik satırı dönmedi.' } };
      return { data: JSON.parse(line), error: null };
    };
    return query;
  },
  auth: { admin: {
    async createUser({ email, password, app_metadata }) {
      const id = crypto.randomUUID();
      const result = sql(`insert into auth.users (id, email, encrypted_password, raw_app_meta_data, email_confirmed_at) values (${lit(id)}, ${lit(email)}, ${lit(password)}, ${lit(app_metadata ?? {})}, now())`);
      if (!result.ok) return { data: null, error: { message: result.error } };
      return { data: { user: { id, email, app_metadata: app_metadata ?? {} } }, error: null };
    },
    async getUserById(id) {
      const result = sql(`select row_to_json(u) from auth.users u where id = ${lit(id)}`);
      if (!result.ok || !result.out) return { data: { user: null }, error: { message: 'missing' } };
      const row = JSON.parse(result.out);
      return { data: { user: { id: row.id, email: row.email, app_metadata: row.raw_app_meta_data ?? {} } }, error: null };
    },
    async updateUserById(id, attrs) {
      const sets = [];
      if (attrs?.password) sets.push(`encrypted_password = ${lit(attrs.password)}`);
      if (attrs?.app_metadata) sets.push(`raw_app_meta_data = ${lit(attrs.app_metadata)}`);
      const result = sql(`update auth.users set ${sets.join(', ')} where id = ${lit(id)}`);
      return result.ok ? { error: null } : { error: { message: result.error } };
    },
    async deleteUser(id) {
      const result = sql(`delete from auth.users where id = ${lit(id)}`);
      return result.ok ? { error: null } : { error: { message: result.error } };
    },
  } },
};

globalThis.fetch = async (url, init) => {
  const text = String(url);
  if (text.includes('grant_type=password')) {
    const body = JSON.parse(init?.body ?? '{}');
    const result = sql(`select encrypted_password from auth.users where lower(email) = lower(${lit(body.email)})`);
    const ok = result.ok && result.out === body.password;
    return { ok, status: ok ? 200 : 400, json: async () => ({}) };
  }
  const email = decodeURIComponent(text.split('filter=')[1] ?? '');
  const result = sql(`select row_to_json(u) from auth.users u where lower(email) = lower(${lit(email)})`);
  if (!result.ok || !result.out) return { ok: true, json: async () => ({ users: [] }) };
  const row = JSON.parse(result.out);
  return { ok: true, json: async () => ({ users: [{ id: row.id, email: row.email, app_metadata: row.raw_app_meta_data ?? {} }] }) };
};
globalThis.__edgeCreateClient = (_url, key, options) => key === 'fake-service' ? serviceClient : { auth: { async getUser() {
  const token = options.global.headers.Authorization.slice(7);
  if (!token || token === 'invalid') return { data: { user: null }, error: { message: 'invalid' } };
  const result = sql(`select row_to_json(u) from auth.users u where id = ${lit(token)}`);
  if (!result.ok || !result.out) return { data: { user: { id: token, email: '', app_metadata: {} } }, error: null };
  const row = JSON.parse(result.out);
  return { data: { user: { id: row.id, email: row.email, app_metadata: row.raw_app_meta_data ?? {} } }, error: null };
} } };
globalThis.Deno = {
  env: { get: (key) => ({ SUPABASE_URL: 'http://127.0.0.1.invalid', SUPABASE_ANON_KEY: 'fake-anon', SUPABASE_SERVICE_ROLE_KEY: 'fake-service' })[key] },
  serve: (fn) => { globalThis.__staffHandler = fn; },
};
const read = (file) => readFile(new URL(file, import.meta.url), 'utf8');
const dataUrl = (source) => `data:text/javascript;base64,${Buffer.from(source).toString('base64')}`;
const shared = (await read('../functions/_shared/http.ts')).replace(/import .* from 'jsr:.*';/, 'const createClient=globalThis.__edgeCreateClient;');
const source = (await read('../functions/manage-restaurant-staff/index.ts')).replace("'../_shared/http.ts'", JSON.stringify(dataUrl(stripTypeScriptTypes(shared, { mode: 'transform' }))));
await import(dataUrl(stripTypeScriptTypes(source, { mode: 'transform' })));

const callAs = async (actor, body) => {
  const response = await globalThis.__staffHandler(new Request('http://127.0.0.1.invalid', {
    method: 'POST',
    headers: { Authorization: `Bearer ${actor}` },
    body: JSON.stringify(body),
  }));
  return { status: response.status, body: await response.json() };
};
const member = () => {
  const result = sql(`select row_to_json(t) from (select * from public.store_sub_admins where email = 'staff@isolated.invalid' order by created_at desc limit 1) t`);
  if (!result.ok || !result.out) throw new Error(result.error || 'personel satırı yok');
  const line = result.out.split('\n').find((item) => item.startsWith('{'));
  if (!line) throw new Error('personel satırı okunamadı');
  return JSON.parse(line);
};
const accessAs = (userId) => sql(`select public.get_my_staff_access() from (select set_config('request.jwt.claim.sub', ${lit(userId)}, true)) s`).out;
const report = [];
const check = (name, ok) => {
  report.push(`${name} ${ok ? 'PASS' : 'FAIL'}`);
  return ok;
};

const password = fxPw('p1', 15);
const nextPassword = fxPw('p2', 15);
const created = await callAs(owner, {
  operation: 'create', name: 'Ayse Test', email: 'staff@isolated.invalid', password,
  staff_role: 'waiter', branch_id: branch, request_id: 'isolated-1',
  permissions: ['viewOrders', 'manageOrders'],
});
if (created.status !== 200) {
  console.error(`CREATE_RESPONSE ${created.status} ${created.body.message ?? ''}`);
}
const createdRow = created.status === 200 ? member() : null;
const authCount = Number(sql(`select count(*) from auth.users where email = 'staff@isolated.invalid'`).out);
let ok = created.status === 200 && createdRow?.status === 'active' && createdRow?.staff_role === 'waiter'
  && createdRow?.branch_id === branch && authCount === 1
  && createdRow.permissions.includes('viewOrders') && createdRow.permissions.includes('manageOrders')
  && !createdRow.permissions.includes('closeBill') && !createdRow.permissions.includes('manageStaff');
check('CREATE', ok);
const badEmail = await callAs(owner, {
  operation: 'create', name: 'Bozuk', email: 'not-an-email', password,
  staff_role: 'waiter', branch_id: branch, request_id: 'isolated-bad',
  permissions: ['viewOrders'],
});
const duplicate = await callAs(owner, {
  operation: 'create', name: 'Ayse Test', email: 'staff@isolated.invalid', password: nextPassword,
  staff_role: 'waiter', branch_id: branch, request_id: 'isolated-2',
  permissions: ['viewOrders'],
});
const stranger = await callAs('40000000-0000-4000-8000-000000000099', {
  operation: 'create', name: 'Yabanci', email: 'other@isolated.invalid', password,
  staff_role: 'waiter', branch_id: branch, request_id: 'isolated-foreign',
  permissions: ['viewOrders'],
});
check('CREATE_GUARDS', badEmail.status === 400 && duplicate.status === 200
  && duplicate.body.password_unchanged === true && stranger.status === 403
  && Number(sql(`select count(*) from auth.users`).out) === 1
  && Number(sql(`select count(*) from public.store_sub_admins`).out) === 1);

const staffId = createdRow?.auth_user_id;
const meta = staffId ? JSON.parse(sql(`select raw_app_meta_data::text from auth.users where id = ${lit(staffId)}`).out) : {};
const login = await fetch('http://127.0.0.1.invalid/auth/v1/token?grant_type=password', {
  method: 'POST', body: JSON.stringify({ email: 'staff@isolated.invalid', password }),
});
const wrongLogin = await fetch('http://127.0.0.1.invalid/auth/v1/token?grant_type=password', {
  method: 'POST', body: JSON.stringify({ email: 'staff@isolated.invalid', password: fxPw('p3', 15) }),
});
const opened = accessAs(staffId);
check('LOGIN', login.ok && !wrongLogin.ok && meta.must_change_password === true && opened.includes(owner) && !opened.includes(other));

const changed = await callAs(staffId, {
  operation: 'change_staff_password', current_password: password, new_password: nextPassword,
});
const changedMeta = JSON.parse(sql(`select raw_app_meta_data::text from auth.users where id = ${lit(staffId)}`).out);
const oldRejected = await fetch('http://127.0.0.1.invalid/auth/v1/token?grant_type=password', {
  method: 'POST', body: JSON.stringify({ email: 'staff@isolated.invalid', password }),
});
const newAccepted = await fetch('http://127.0.0.1.invalid/auth/v1/token?grant_type=password', {
  method: 'POST', body: JSON.stringify({ email: 'staff@isolated.invalid', password: nextPassword }),
});
check('PASSWORD_CHANGE', changed.status === 200 && changedMeta.must_change_password === false && !oldRejected.ok && newAccepted.ok);

const edited = await callAs(owner, {
  operation: 'permissions', id: createdRow.id,
  permissions: ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport'],
  revoked_permissions: [], staff_role: 'sub_admin', branch_id: second,
});
const editedRow = member();
check('EDIT', edited.status === 200 && editedRow.staff_role === 'sub_admin'
  && !editedRow.permissions.includes('closeBill') && !editedRow.permissions.includes('manageStaff')
  && !editedRow.permissions.includes('transferTable'));
check('BRANCH_CHANGE', edited.status === 200 && editedRow.branch_id === second);
const foreignMove = await callAs(owner, {
  operation: 'permissions', id: createdRow.id,
  permissions: ['viewOrders', 'manageOrders'], revoked_permissions: [], branch_id: foreignBranch,
});
check('BRANCH_GUARD', foreignMove.status === 400 && member().branch_id === second);

const premature = await callAs(owner, {
  operation: 'permissions', id: createdRow.id,
  permissions: ['viewOrders', 'manageOrders', 'transferTable'],
});
check('PRE_MIGRATION_SEVEN', premature.status === 400 && !member().permissions.includes('transferTable'));
assert.equal(sql(`create or replace function public.validate_restaurant_staff_membership()
returns trigger language plpgsql as $$
begin
  if new.branch_id is not null and not exists(select 1 from public.store_branches where id = new.branch_id and store_id = new.store_id) then
    raise exception 'Şube bu işletmeye ait değil.' using errcode = '42501';
  end if;
  if not new.permissions <@ array['manageProducts','viewOrders','manageOrders','manageCampaigns','viewFinance','manageSupport','manageStoreProfile','transferTable','splitBill','takePartialPayment','closeBill','managePrintSettings']::text[] then
    raise exception 'Geçersiz yetki.' using errcode = '22023';
  end if;
  if new.auth_user_id is not null and not exists(select 1 from auth.users where id = new.auth_user_id and lower(email) = lower(new.email)) then
    raise exception 'Auth kimliği uyuşmuyor.' using errcode = '42501';
  end if;
  return new;
end $$;`).ok, true);
const granted = await callAs(owner, {
  operation: 'permissions', id: createdRow.id,
  permissions: ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport', 'transferTable'],
  staff_role: 'waiter',
});
check('TRANSFER_GRANT', granted.status === 200 && member().permissions.includes('transferTable')
  && !member().permissions.includes('closeBill') && !member().permissions.includes('manageStaff')
  && member().staff_role === 'waiter');
const kept = await callAs(owner, {
  operation: 'permissions', id: createdRow.id,
  permissions: ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport'],
  revoked_permissions: [],
});
check('TRANSFER_KEEP', kept.status === 200 && member().permissions.includes('transferTable'));
const revoked = await callAs(owner, {
  operation: 'permissions', id: createdRow.id,
  permissions: ['viewOrders', 'manageOrders', 'manageProducts', 'manageSupport'],
  revoked_permissions: ['transferTable'],
});
const revokedRow = member();
check('REVOKE_PERMISSION', revoked.status === 200 && !revokedRow.permissions.includes('transferTable')
  && !revokedRow.permissions.includes('closeBill') && !revokedRow.permissions.includes('manageStaff'));

const self = await callAs(staffId, {
  operation: 'permissions', id: createdRow.id,
  permissions: ['manageStaff', 'viewOrders'], staff_role: 'sub_admin', branch_id: branch,
});
check('SELF_PROMOTION', self.status === 403 && member().staff_role === 'waiter' && !member().permissions.includes('manageStaff'));

const deactivated = await callAs(owner, { operation: 'deactivate', id: createdRow.id });
const after = member();
const closed = accessAs(staffId);
const blocked = await callAs(staffId, {
  operation: 'permissions', id: createdRow.id, permissions: ['viewOrders'], revoked_permissions: [],
});
const stillLogsIn = await fetch('http://127.0.0.1.invalid/auth/v1/token?grant_type=password', {
  method: 'POST', body: JSON.stringify({ email: 'staff@isolated.invalid', password: nextPassword }),
});
check('DEACTIVATE', deactivated.status === 200 && after.status === 'inactive');
check('SESSION_SECURITY', closed === '' && blocked.status === 403 && stillLogsIn.ok);
const reactivate = await callAs(owner, { operation: 'activate', id: createdRow.id });
check('REACTIVATE_UNSUPPORTED', reactivate.status === 400 && member().status === 'inactive');

console.log(report.join('\n'));
if (report.some((line) => line.endsWith('FAIL'))) process.exit(1);
