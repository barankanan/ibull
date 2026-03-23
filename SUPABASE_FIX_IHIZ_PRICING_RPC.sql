-- IHIZ courier app can read only active pricing config via RPC (RLS-safe).
-- Run once in Supabase SQL Editor.

create or replace function public.get_active_ihiz_pricing_config()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (
      select config
      from public.ihiz_pricing_rule_versions
      where is_active = true
      order by version desc
      limit 1
    ),
    '{}'::jsonb
  );
$$;

revoke all on function public.get_active_ihiz_pricing_config() from public;
grant execute on function public.get_active_ihiz_pricing_config() to anon, authenticated;
