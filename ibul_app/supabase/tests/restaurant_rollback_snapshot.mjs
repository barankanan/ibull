// Catalog backup/restore for the two restaurant migrations. No network client.
// Run only against an isolated clone with writers stopped. Keep JSON + SQL offline.
const names = [
  'restaurant_has_permission','user_can_access_restaurant','restaurant_table_access',
  'activate_my_sub_admin_invites','get_my_staff_access','validate_restaurant_staff_membership',
  'is_managed_restaurant_staff','restaurant_table_number_access','restaurant_order_access',
  'restaurant_customer_table_order_target',
  'guard_restaurant_staff_order_write','guard_restaurant_staff_scoped_write',
  'validate_restaurant_print_job',
  'finance_get_overview','finance_get_monthly_trend','close_table_with_history',
  'create_table_order_with_print_jobs','create_table_order_with_print_jobs_impl',
];
const tables = ['store_sub_admins','store_tables','orders','order_items','print_jobs',
  'printers','table_orders','table_order_history','products','stores','store_campaigns',
  'support_tickets','finance_suppliers','finance_cash_accounts','finance_cash_movements',
  'finance_income_records','finance_expenses','finance_debts','finance_debt_payments',
  'finance_employees','finance_salary_records','finance_salary_payments',
  'finance_reconciliation_notes','finance_company_settings'];
const q = (v) => `'${String(v).replaceAll("'", "''")}'`;
const ident = (v) => `"${String(v).replaceAll('"', '""')}"`;
const list = (xs) => xs.map(q).join(',');

export async function capture(db) {
  const rows = async (sql) => (await db.query(sql)).rows;
  return {
    format: 1,
    functions: await rows(`select p.oid::regprocedure::text signature,
      pg_get_functiondef(p.oid) definition, pg_get_userbyid(p.proowner) owner,
      obj_description(p.oid,'pg_proc') comment,
      coalesce((select jsonb_agg(jsonb_build_object('grantee',case when a.grantee=0 then 'PUBLIC'
        else pg_get_userbyid(a.grantee) end,'grantable',a.is_grantable) order by a.grantee)
        from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a), '[]'::jsonb) acl
      from pg_proc p where p.pronamespace='public'::regnamespace
      and p.proname in (${list(names)}) order by 1`),
    policies: await rows(`select tablename,policyname,permissive,roles,cmd,qual,with_check
      from pg_policies where schemaname='public' and tablename in (${list(tables)})
      order by tablename,policyname`),
    triggers: await rows(`select c.relname tablename,t.tgname,pg_get_triggerdef(t.oid) definition,t.tgenabled
      from pg_trigger t join pg_class c on c.oid=t.tgrelid
      where c.relnamespace='public'::regnamespace and not t.tgisinternal
      and c.relname in (${list(tables)}) order by 1,2`),
    tables: await rows(`select relname,relrowsecurity,relforcerowsecurity from pg_class
      where relnamespace='public'::regnamespace and relkind in ('r','p')
      and relname in (${list(tables)}) order by 1`),
    publications: await rows(`select pubname,puballtables,pubinsert,pubupdate,pubdelete,pubtruncate
      from pg_publication order by pubname`),
    members: await rows(`select pubname,schemaname,tablename,attnames,rowfilter
      from pg_publication_tables where schemaname='public'
      and tablename in ('print_jobs','printers') order by 1,2,3`),
    privileges: await rows(`select c.relname, case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end grantee,
      a.privilege_type privilege, a.is_grantable grantable
      from pg_class c
      cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
      where c.relnamespace='public'::regnamespace and c.relkind in ('r','p')
      and c.relname in (${list(tables)})
      order by 1,2,3`),
  };
}

export function rollbackSql(before, after) {
  if (before.format !== 1 || after.format !== 1) throw Error('Unknown snapshot format');
  const sql = ['-- GENERATED from an actual pre-migration catalog snapshot. ISOLATED CLONE ONLY.',
    '-- Preserve additive staff/branch columns and indexes, and ALL operational rows.',
    '-- Roll application/Edge version back separately; this can restore old security flaws.',
    'begin;', "set local lock_timeout='5s';", "set local statement_timeout='60s';"];
  // Refuse a stale restore after another release changed a targeted function.
  for (const f of after.functions) sql.push(`do $drift$ begin
    if to_regprocedure(${q(f.signature)}) is null or
      pg_get_functiondef(to_regprocedure(${q(f.signature)})) is distinct from ${q(f.definition)} then
      raise exception 'Rollback function drift: %',${q(f.signature)};
    end if;
  end $drift$;`);
  const guards = [
    ['policies', `select tablename,policyname,permissive,roles,cmd,qual,with_check
      from pg_policies where schemaname='public' and tablename in (${list(tables)})`, 'tablename,policyname'],
    ['triggers', `select c.relname tablename,t.tgname,pg_get_triggerdef(t.oid) definition,t.tgenabled
      from pg_trigger t join pg_class c on c.oid=t.tgrelid
      where c.relnamespace='public'::regnamespace and not t.tgisinternal
      and c.relname in (${list(tables)})`, 'tablename,tgname'],
    ['publications', 'select pubname,puballtables,pubinsert,pubupdate,pubdelete,pubtruncate from pg_publication', 'pubname'],
    ['members', `select pubname,schemaname,tablename,attnames,rowfilter from pg_publication_tables
      where schemaname='public' and tablename in ('print_jobs','printers')`, 'pubname,schemaname,tablename'],
    ['privileges', `select c.relname, case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end grantee,
      a.privilege_type privilege, a.is_grantable grantable
      from pg_class c
      cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
      where c.relnamespace='public'::regnamespace and c.relkind in ('r','p')
      and c.relname in (${list(tables)})`, 'relname,grantee,privilege'],
  ];
  for (const [key,query,order] of guards) sql.push(`do $drift$ begin
    if (select coalesce(jsonb_agg(to_jsonb(x) order by ${order}),'[]'::jsonb) from (${query}) x)
      is distinct from ${q(JSON.stringify(after[key]))}::jsonb then
      raise exception 'Rollback catalog drift: ${key}';
    end if;
  end $drift$;`);
  // Remove dependent objects before changing function definitions. No CASCADE.
  for (const t of after.triggers) sql.push(`drop trigger ${ident(t.tgname)} on public.${ident(t.tablename)};`);
  for (const p of after.policies) sql.push(`drop policy ${ident(p.policyname)} on public.${ident(p.tablename)};`);
  for (const f of before.functions) {
    sql.push(`${f.definition};`, `alter function ${f.signature} owner to ${ident(f.owner)};`);
    const current = after.functions.find((a) => a.signature === f.signature);
    const roles = new Set(['PUBLIC', ...f.acl.map((a) => a.grantee), ...(current?.acl || []).map((a) => a.grantee)]);
    for (const role of roles) sql.push(`revoke all on function ${f.signature} from ${role === 'PUBLIC' ? role : ident(role)};`);
    for (const a of f.acl) sql.push(`grant execute on function ${f.signature} to ${a.grantee === 'PUBLIC' ? a.grantee : ident(a.grantee)}${a.grantable ? ' with grant option' : ''};`);
    sql.push(`comment on function ${f.signature} is ${f.comment === null ? 'null' : q(f.comment)};`);
  }
  // SQL-body dependencies may order these differently. Retry only dependency errors;
  // any unresolved external dependency aborts the entire rollback transaction.
  const added = after.functions.filter((a) => !before.functions.some((b) => b.signature === a.signature));
  if (added.length) sql.push(`do $rollback$ declare pending text[]:=array[${list(added.map((f) => f.signature))}];
    next_pending text[]; sig text; n integer;
    begin
      loop
        n:=cardinality(pending); exit when n=0; next_pending:='{}';
        foreach sig in array pending loop
          begin execute 'drop function '||sig;
          exception when dependent_objects_still_exist then next_pending:=array_append(next_pending,sig); end;
        end loop;
        if cardinality(next_pending)=n then raise exception 'Rollback external dependencies: %',next_pending; end if;
        pending:=next_pending;
      end loop;
    end $rollback$;`);
  for (const p of before.policies) {
    sql.push(`create policy ${ident(p.policyname)} on public.${ident(p.tablename)} as ${p.permissive}
      for ${p.cmd} to ${p.roles.map((r) => r === 'public' ? 'PUBLIC' : ident(r)).join(',')}
      ${p.qual === null ? '' : `using (${p.qual})`}
      ${p.with_check === null ? '' : `with check (${p.with_check})`};`);
  }
  for (const t of before.triggers) {
    sql.push(`${t.definition};`);
    const action = {O:'enable',D:'disable',R:'enable replica',A:'enable always'}[t.tgenabled];
    sql.push(`alter table public.${ident(t.tablename)} ${action} trigger ${ident(t.tgname)};`);
  }
  const privilegeRoles = new Set([...(before.privileges || []), ...(after.privileges || [])].map((p) => `${p.relname}\t${p.grantee}`));
  for (const key of privilegeRoles) {
    const [relname, grantee] = key.split('\t');
    const old = (before.privileges || []).filter((p) => p.relname === relname && p.grantee === grantee);
    const now = (after.privileges || []).filter((p) => p.relname === relname && p.grantee === grantee);
    if (JSON.stringify(old) === JSON.stringify(now)) continue;
    const role = grantee === 'PUBLIC' ? 'PUBLIC' : ident(grantee);
    sql.push(`revoke all on table public.${ident(relname)} from ${role};`);
    for (const p of old) sql.push(`grant ${p.privilege} on table public.${ident(relname)} to ${role}${p.grantable ? ' with grant option' : ''};`);
  }
  for (const t of before.tables) sql.push(
    `alter table public.${ident(t.relname)} ${t.relrowsecurity ? 'enable' : 'disable'} row level security;`,
    `alter table public.${ident(t.relname)} ${t.relforcerowsecurity ? 'force' : 'no force'} row level security;`);
  for (const pub of before.publications) {
    if (pub.puballtables) continue; // ALL TABLES must never be converted to explicit members.
    for (const table of ['print_jobs','printers']) {
      const old = before.members.find((m) => m.pubname === pub.pubname && m.tablename === table);
      const now = after.members.find((m) => m.pubname === pub.pubname && m.tablename === table);
      if (JSON.stringify(old) === JSON.stringify(now)) continue;
      if (now) sql.push(`alter publication ${ident(pub.pubname)} drop table public.${ident(table)};`);
      if (old) sql.push(`alter publication ${ident(pub.pubname)} add table public.${ident(table)}
        ${old.attnames?.length ? `(${old.attnames.map(ident).join(',')})` : ''}
        ${old.rowfilter ? `where (${old.rowfilter})` : ''};`);
    }
  }
  sql.push("notify pgrst,'reload schema';", 'commit;');
  return sql.join('\n')+'\n';
}
