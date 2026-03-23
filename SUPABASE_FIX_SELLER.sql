
-- Fix missing 'documents' column in seller_applications
alter table public.seller_applications 
add column if not exists documents jsonb default '{}'::jsonb;

-- STORAGE POLICIES
-- We need to enable RLS on objects table for security
-- Note: 'storage' schema is managed by Supabase, we add policies to 'storage.objects'

-- 1. seller-documents (Private Bucket)
-- Allow authenticated users to upload their own documents
create policy "Users can upload their own seller documents"
on storage.objects for insert
with check (
  bucket_id = 'seller-documents' and
  auth.role() = 'authenticated' and
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to read their own documents
create policy "Users can view their own seller documents"
on storage.objects for select
using (
  bucket_id = 'seller-documents' and
  auth.role() = 'authenticated' and
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow Admins to view all seller documents
create policy "Admins can view all seller documents"
on storage.objects for select
using (
  bucket_id = 'seller-documents' and
  exists (
    select 1 from public.users 
    where users.id = auth.uid() and users.role = 'admin'
  )
);

-- 2. store-images (Public Bucket)
-- Allow authenticated users (sellers) to upload
create policy "Authenticated users can upload store images"
on storage.objects for insert
with check (
  bucket_id = 'store-images' and
  auth.role() = 'authenticated'
);

-- Allow everyone to view store images
create policy "Everyone can view store images"
on storage.objects for select
using ( bucket_id = 'store-images' );

-- Allow sellers to update/delete their own images
create policy "Sellers can update their own store images"
on storage.objects for update
using (
  bucket_id = 'store-images' and
  auth.uid()::text = (storage.foldername(name))[1]
);

create policy "Sellers can delete their own store images"
on storage.objects for delete
using (
  bucket_id = 'store-images' and
  auth.uid()::text = (storage.foldername(name))[1]
);

-- 3. product-images (Public Bucket)
-- Allow authenticated users (sellers) to upload
create policy "Authenticated users can upload product images"
on storage.objects for insert
with check (
  bucket_id = 'product-images' and
  auth.role() = 'authenticated'
);

-- Allow everyone to view product images
create policy "Everyone can view product images"
on storage.objects for select
using ( bucket_id = 'product-images' );

-- Allow sellers to update/delete their own images
create policy "Sellers can update their own product images"
on storage.objects for update
using (
  bucket_id = 'product-images' and
  auth.uid()::text = (storage.foldername(name))[1]
);

create policy "Sellers can delete their own product images"
on storage.objects for delete
using (
  bucket_id = 'product-images' and
  auth.uid()::text = (storage.foldername(name))[1]
);
