-- categories bucket + RLS policies
-- Public read stays. Write, update, and delete require public.is_admin_user(),
-- which reads public.users.role. Anonymous clients cannot upload or delete.
-- Live enforcement is Stage B: manual_patches/20261004_p0_money_authority_stage_b_enforce.sql.

insert into storage.buckets (id, name, public)
values ('categories', 'categories', true)
on conflict (id) do nothing;

drop policy if exists "categories_public_read" on storage.objects;
create policy "categories_public_read"
on storage.objects
for select
to public
using (bucket_id = 'categories');

drop policy if exists "categories_public_insert" on storage.objects;
drop policy if exists "categories_public_update" on storage.objects;
drop policy if exists "categories_public_delete" on storage.objects;

drop policy if exists "categories_admin_insert" on storage.objects;
create policy "categories_admin_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'categories'
  and public.is_admin_user()
);

drop policy if exists "categories_admin_update" on storage.objects;
create policy "categories_admin_update"
on storage.objects
for update
to authenticated
using (bucket_id = 'categories' and public.is_admin_user())
with check (bucket_id = 'categories' and public.is_admin_user());

drop policy if exists "categories_admin_delete" on storage.objects;
create policy "categories_admin_delete"
on storage.objects
for delete
to authenticated
using (bucket_id = 'categories' and public.is_admin_user());
