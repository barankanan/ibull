-- Manual patch. Not a CLI migration. Do not db push. Do not apply in this change.
-- Public mall logo/cover bucket. Private seller-documents policies stay unchanged.
-- store-images policies stay unchanged.

begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'mall-media',
  'mall-media',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists mall_media_public_read on storage.objects;
create policy mall_media_public_read
on storage.objects
for select
to public
using (bucket_id = 'mall-media');

drop policy if exists mall_media_owner_insert on storage.objects;
create policy mall_media_owner_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'mall-media'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'mall-applications'
  and (storage.foldername(name))[3] ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  and (storage.foldername(name))[4] in ('logo', 'cover')
);

drop policy if exists mall_media_owner_update on storage.objects;
create policy mall_media_owner_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'mall-media'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'mall-applications'
  and (storage.foldername(name))[3] ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  and (storage.foldername(name))[4] in ('logo', 'cover')
)
with check (
  bucket_id = 'mall-media'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'mall-applications'
  and (storage.foldername(name))[3] ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  and (storage.foldername(name))[4] in ('logo', 'cover')
);

drop policy if exists mall_media_owner_delete on storage.objects;
create policy mall_media_owner_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'mall-media'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'mall-applications'
  and (storage.foldername(name))[3] ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  and (storage.foldername(name))[4] in ('logo', 'cover')
);

commit;
