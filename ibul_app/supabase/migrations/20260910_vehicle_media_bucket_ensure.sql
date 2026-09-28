-- Ensure gallery vehicle photo bucket + owner-path RLS exist.
-- Idempotent. Does not change product-images / restaurant upload.

insert into storage.buckets (id, name, public)
values ('vehicle-media', 'vehicle-media', true)
on conflict (id) do update set public = true;

drop policy if exists vehicle_media_public_read on storage.objects;
create policy vehicle_media_public_read on storage.objects
for select using (bucket_id = 'vehicle-media');

drop policy if exists vehicle_media_owner_write on storage.objects;
create policy vehicle_media_owner_write on storage.objects
for insert with check (
  bucket_id = 'vehicle-media'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists vehicle_media_owner_update on storage.objects;
create policy vehicle_media_owner_update on storage.objects
for update using (
  bucket_id = 'vehicle-media'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists vehicle_media_owner_delete on storage.objects;
create policy vehicle_media_owner_delete on storage.objects
for delete using (
  bucket_id = 'vehicle-media'
  and auth.uid()::text = (storage.foldername(name))[1]
);
