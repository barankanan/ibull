-- categories bucket + RLS policies
-- Bu proje Supabase Auth kullanmadan da admin panelden upload yapabildiği için
-- insert/update/delete policy'lerini PUBLIC olarak aciyoruz.
-- Uretimde istenirse sadece authenticated role'a daraltilabilir.

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
create policy "categories_public_insert"
on storage.objects
for insert
to public
with check (bucket_id = 'categories');

drop policy if exists "categories_public_update" on storage.objects;
create policy "categories_public_update"
on storage.objects
for update
to public
using (bucket_id = 'categories')
with check (bucket_id = 'categories');

drop policy if exists "categories_public_delete" on storage.objects;
create policy "categories_public_delete"
on storage.objects
for delete
to public
using (bucket_id = 'categories');
