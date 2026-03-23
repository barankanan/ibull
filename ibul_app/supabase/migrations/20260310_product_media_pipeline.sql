-- Product media pipeline (video + thumbnail) for performance-first upload/playback

alter table if exists public.products
  add column if not exists video_path text,
  add column if not exists video_public_url text,
  add column if not exists thumbnail_path text,
  add column if not exists thumbnail_public_url text,
  add column if not exists video_duration_seconds integer,
  add column if not exists video_size_bytes bigint,
  add column if not exists thumbnail_size_bytes bigint,
  add column if not exists video_status text;

create index if not exists idx_products_video_status on public.products(video_status);
create index if not exists idx_products_video_path on public.products(video_path);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'products_video_status_check'
  ) then
    alter table public.products
      add constraint products_video_status_check
      check (video_status is null or video_status in ('uploading', 'ready', 'failed'));
  end if;
end $$;

-- Optional: keep legacy compatibility where older screens still read video_url.
-- App code writes both video_public_url and video_url.

-- Storage bucket for product media files.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-media',
  'product-media',
  true,
  83886080,
  array['video/mp4', 'image/jpeg']::text[]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Seller can upload only to products/{sellerId}/{productId}/... and only allowed mime types.
-- NOTE: adapt policy to your auth model if seller_id is not auth.uid().
drop policy if exists "product-media-insert-own" on storage.objects;
create policy "product-media-insert-own"
on storage.objects
for insert
with check (
  bucket_id = 'product-media'
  and auth.uid()::text = split_part(name, '/', 2)
  and split_part(name, '/', 1) = 'products'
  and split_part(name, '/', 4) in ('video.mp4', 'thumb.jpg')
  and coalesce((metadata->>'mimetype')::text, '') in ('video/mp4', 'image/jpeg')
);

drop policy if exists "product-media-update-own" on storage.objects;
create policy "product-media-update-own"
on storage.objects
for update
using (
  bucket_id = 'product-media'
  and auth.uid()::text = split_part(name, '/', 2)
)
with check (
  bucket_id = 'product-media'
  and auth.uid()::text = split_part(name, '/', 2)
  and coalesce((metadata->>'mimetype')::text, '') in ('video/mp4', 'image/jpeg')
);

drop policy if exists "product-media-delete-own" on storage.objects;
create policy "product-media-delete-own"
on storage.objects
for delete
using (
  bucket_id = 'product-media'
  and auth.uid()::text = split_part(name, '/', 2)
);

-- Public read (if bucket is public this is optional but explicit policy keeps intent clear).
drop policy if exists "product-media-select-public" on storage.objects;
create policy "product-media-select-public"
on storage.objects
for select
using (bucket_id = 'product-media');
