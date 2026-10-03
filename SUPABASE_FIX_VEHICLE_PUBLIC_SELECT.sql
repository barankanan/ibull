-- HOTFIX: public /arac/:id and nested vehicle selects fail for logged-out users.
-- Error: permission denied for function vehicle_is_admin (42501)
-- Cause: RLS uses vehicle_is_admin() but EXECUTE was granted only to authenticated.
-- Safe: SECURITY DEFINER, returns false for anon (auth.uid() is null).

revoke all on function public.vehicle_is_admin() from public;
grant execute on function public.vehicle_is_admin() to anon, authenticated;
