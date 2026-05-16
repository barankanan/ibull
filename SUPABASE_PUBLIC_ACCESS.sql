-- PRODUCTS TABLE POLICIES
-- 1. Public can view APPROVED (Aktif) products
DROP POLICY IF EXISTS "Public can view active products" ON public.products;
CREATE POLICY "Public can view active products"
ON public.products FOR SELECT
USING (status IN ('Aktif', 'pending_approval'));

-- 2. Sellers can view ALL their own products (Approved, Pending, Draft, etc.)
DROP POLICY IF EXISTS "Sellers can view own products" ON public.products;
CREATE POLICY "Sellers can view own products"
ON public.products FOR SELECT
USING (auth.uid() = seller_id);

-- 3. Sellers can INSERT their own products
DROP POLICY IF EXISTS "Sellers can insert own products" ON public.products;
CREATE POLICY "Sellers can insert own products"
ON public.products FOR INSERT
WITH CHECK (auth.uid() = seller_id);

-- 4. Sellers can UPDATE their own products
DROP POLICY IF EXISTS "Sellers can update own products" ON public.products;
CREATE POLICY "Sellers can update own products"
ON public.products FOR UPDATE
USING (auth.uid() = seller_id);

-- 5. Sellers can DELETE their own products
DROP POLICY IF EXISTS "Sellers can delete own products" ON public.products;
CREATE POLICY "Sellers can delete own products"
ON public.products FOR DELETE
USING (auth.uid() = seller_id);


-- STORES TABLE POLICIES
-- 1. Public can view OPEN stores
DROP POLICY IF EXISTS "Public can view open stores" ON public.stores;
CREATE POLICY "Public can view open stores"
ON public.stores FOR SELECT
USING (is_store_open = true);

-- 2. Sellers can view their own store (even if closed)
DROP POLICY IF EXISTS "Sellers can view own store" ON public.stores;
CREATE POLICY "Sellers can view own store"
ON public.stores FOR SELECT
USING (auth.uid() = seller_id);

-- 3. Sellers can UPDATE their own store
DROP POLICY IF EXISTS "Sellers can update own store" ON public.stores;
CREATE POLICY "Sellers can update own store"
ON public.stores FOR UPDATE
USING (auth.uid() = seller_id);
