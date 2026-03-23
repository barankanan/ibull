-- Admin panelin onay bekleyen urunleri gorebilmesi ve onaylayabilmesi icin.

alter table if exists public.products enable row level security;

drop policy if exists "products_admin_select_all" on public.products;
create policy "products_admin_select_all"
on public.products
for select
to authenticated
using (
  coalesce(auth.jwt() ->> 'role', '') in ('admin', 'super_admin')
  or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'super_admin')
  or exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role in ('admin', 'super_admin')
  )
);

drop policy if exists "products_admin_update_all" on public.products;
create policy "products_admin_update_all"
on public.products
for update
to authenticated
using (
  coalesce(auth.jwt() ->> 'role', '') in ('admin', 'super_admin')
  or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'super_admin')
  or exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role in ('admin', 'super_admin')
  )
)
with check (
  coalesce(auth.jwt() ->> 'role', '') in ('admin', 'super_admin')
  or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'super_admin')
  or exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role in ('admin', 'super_admin')
  )
);
