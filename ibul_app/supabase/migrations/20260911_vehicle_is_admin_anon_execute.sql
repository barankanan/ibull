-- Public vehicle detail was 42501 for anon.
-- RLS calls vehicle_is_admin(); execute had been revoked from anon,
-- so the policy errored instead of returning false.
-- Function is SECURITY DEFINER and returns false when auth.uid() is null.

revoke all on function public.vehicle_is_admin() from public;
grant execute on function public.vehicle_is_admin() to anon, authenticated;
