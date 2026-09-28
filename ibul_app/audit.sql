select json_build_object(
  'rls', (
    select json_agg(row_to_json(t)) from (
      select n.nspname as schema_name, c.relname as table_name, c.relrowsecurity as rls_enabled, c.relforcerowsecurity as force_rls
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind = 'r' order by c.relname
    ) t
  ),
  'policies', (
    select json_agg(row_to_json(t)) from (
      select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
      from pg_policies where schemaname = 'public' order by tablename, policyname
    ) t
  ),
  'triggers', (
    select json_agg(row_to_json(t)) from (
      select event_object_table, trigger_name, action_timing, event_manipulation, action_statement
      from information_schema.triggers where trigger_schema = 'public' order by event_object_table, trigger_name
    ) t
  ),
  'secdef', (
    select json_agg(row_to_json(t)) from (
      select n.nspname as schema_name, p.proname, p.prosecdef as security_definer, pg_get_function_identity_arguments(p.oid) as arguments, p.proconfig, pg_get_functiondef(p.oid) as definition
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.prosecdef = true order by p.proname
    ) t
  ),
  'buckets', (
    select json_agg(row_to_json(t)) from (
      select id, name, public from storage.buckets
    ) t
  ),
  'storage_policies', (
    select json_agg(row_to_json(t)) from (
      select tablename, policyname, roles, cmd, qual from pg_policies where schemaname = 'storage' and tablename = 'objects'
    ) t
  )
);
