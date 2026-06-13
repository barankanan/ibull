-- Hotfix: narrow search_telemetry SELECT to own rows + admin analytics.
-- Safe to run on prod; idempotent policy drops/recreates.

begin;

drop policy if exists "search_telemetry_select_authenticated" on public.search_telemetry;
drop policy if exists "search_telemetry_select_own" on public.search_telemetry;
drop policy if exists "search_telemetry_select_admin" on public.search_telemetry;

create policy "search_telemetry_select_own"
on public.search_telemetry
for select
to authenticated
using (user_id is not null and auth.uid() = user_id);

create policy "search_telemetry_select_admin"
on public.search_telemetry
for select
to authenticated
using (
  exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and (
        lower(coalesce(u.role, '')) in ('admin', 'super_admin')
        or lower(coalesce(u.role, '')) like 'admin_%'
      )
  )
);

commit;
