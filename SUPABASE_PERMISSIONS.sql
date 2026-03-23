-- Enable RLS on tables if not already enabled
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seller_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- 1. USERS TABLE POLICIES
-- Allow users to read their own data
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
CREATE POLICY "Users can view own profile" 
ON public.users FOR SELECT 
USING (auth.uid() = id);

-- Allow users to update their own data (CRITICAL for upsert to work after trigger)
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile" 
ON public.users FOR UPDATE 
USING (auth.uid() = id);

-- Allow trigger to insert (already covers it since trigger is security definer, but good to be safe)
-- Note: Inserts usually handled by trigger, but if upsert is used, INSERT policy might be needed if row doesn't exist (race condition)
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
CREATE POLICY "Users can insert own profile" 
ON public.users FOR INSERT 
WITH CHECK (auth.uid() = id);

-- 2. SELLER APPLICATIONS POLICIES
-- Allow authenticated users to create an application
DROP POLICY IF EXISTS "Users can create seller application" ON public.seller_applications;
CREATE POLICY "Users can create seller application" 
ON public.seller_applications FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Allow users to view their own applications
DROP POLICY IF EXISTS "Users can view own applications" ON public.seller_applications;
CREATE POLICY "Users can view own applications" 
ON public.seller_applications FOR SELECT 
USING (auth.uid() = user_id);

-- 3. STORAGE POLICIES (CRITICAL for file upload)
-- Create buckets if they don't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('seller-documents', 'seller-documents', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('store-images', 'store-images', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- Policy for seller-documents (Private bucket)
-- Allow authenticated users to upload
DROP POLICY IF EXISTS "Users can upload seller documents" ON storage.objects;
CREATE POLICY "Users can upload seller documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'seller-documents' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Allow authenticated users to view their own documents
DROP POLICY IF EXISTS "Users can view own seller documents" ON storage.objects;
CREATE POLICY "Users can view own seller documents"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'seller-documents' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Allow authenticated users to update/delete their own documents
DROP POLICY IF EXISTS "Users can update own seller documents" ON storage.objects;
CREATE POLICY "Users can update own seller documents"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'seller-documents' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can delete own seller documents" ON storage.objects;
CREATE POLICY "Users can delete own seller documents"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'seller-documents' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Policy for store-images (Public bucket)
DROP POLICY IF EXISTS "Sellers can upload store images" ON storage.objects;
CREATE POLICY "Sellers can upload store images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'store-images'); -- Relaxed for now, or restrict by folder

DROP POLICY IF EXISTS "Public can view store images" ON storage.objects;
CREATE POLICY "Public can view store images"
ON storage.objects FOR SELECT
USING (bucket_id = 'store-images');

-- Policy for product-images (Public bucket)
DROP POLICY IF EXISTS "Sellers can upload product images" ON storage.objects;
CREATE POLICY "Sellers can upload product images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'product-images');

DROP POLICY IF EXISTS "Public can view product images" ON storage.objects;
CREATE POLICY "Public can view product images"
ON storage.objects FOR SELECT
USING (bucket_id = 'product-images');

-- 4. FIX HANDLE_NEW_USER TRIGGER (Ensure it handles metadata correctly)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, display_name, created_at)
  VALUES (
    new.id, 
    new.email, 
    COALESCE(new.raw_user_meta_data->>'display_name', new.email),
    now()
  )
  ON CONFLICT (id) DO UPDATE
  SET 
    email = EXCLUDED.email,
    display_name = COALESCE(EXCLUDED.display_name, public.users.display_name),
    updated_at = now();
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
