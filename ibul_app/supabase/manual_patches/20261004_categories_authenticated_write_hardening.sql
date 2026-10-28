-- Emergency categories write hardening.
-- Drops broad authenticated write policies. Recreates admin write
-- with is_admin_user(auth.uid()). Does not touch orders, checkout RPCs,
-- money triggers, or public read.

drop policy if exists "categories_auth_insert" on storage.objects;
drop policy if exists "categories_auth_update" on storage.objects;
drop policy if exists "categories_auth_delete" on storage.objects;

drop policy if exists "categories_admin_insert" on storage.objects;
drop policy if exists "categories_admin_update" on storage.objects;
drop policy if exists "categories_admin_delete" on storage.objects;

create policy "categories_admin_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'categories'
  and public.is_admin_user(auth.uid())
);

create policy "categories_admin_update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'categories'
  and public.is_admin_user(auth.uid())
)
with check (
  bucket_id = 'categories'
  and public.is_admin_user(auth.uid())
);

create policy "categories_admin_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'categories'
  and public.is_admin_user(auth.uid())
);
