-- P0: brand verification identity metadata must not be world-readable to
-- authenticated users via USING(true) admin policies.
--
-- Rollback: drop the is_admin_user policies and restore previous names only
-- after live pg_policies confirms no USING(true) remains.

do $$
begin
  if to_regclass('public.store_brand_verification_applications') is null then
    return;
  end if;

  alter table public.store_brand_verification_applications enable row level security;

  drop policy if exists "brand_verification_admin_select_all"
    on public.store_brand_verification_applications;
  drop policy if exists "brand_verification_admin_update_all"
    on public.store_brand_verification_applications;
  drop policy if exists "brand_verification_admin_select"
    on public.store_brand_verification_applications;
  drop policy if exists "brand_verification_admin_update"
    on public.store_brand_verification_applications;

  execute $sql$
    create policy "brand_verification_admin_select"
    on public.store_brand_verification_applications
    for select
    to authenticated
    using (public.is_admin_user())
  $sql$;

  execute $sql$
    create policy "brand_verification_admin_update"
    on public.store_brand_verification_applications
    for update
    to authenticated
    using (public.is_admin_user())
    with check (public.is_admin_user())
  $sql$;
end;
$$;
