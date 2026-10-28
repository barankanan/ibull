-- Migration: Product Import Jobs & Tracking System
-- Satıcıların harici sitelerden ürün içe aktarma işlemlerini asenkron olarak takip etmesini sağlar.

CREATE TABLE IF NOT EXISTS public.product_import_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'scanning', 'ready', 'importing', 'completed', 'failed', 'cancelled')),
    source_urls JSONB NOT NULL DEFAULT '[]'::jsonb,
    total_products INTEGER NOT NULL DEFAULT 0,
    processed_products INTEGER NOT NULL DEFAULT 0,
    success_count INTEGER NOT NULL DEFAULT 0,
    error_count INTEGER NOT NULL DEFAULT 0,
    duplicate_count INTEGER NOT NULL DEFAULT 0,
    result_payload JSONB DEFAULT '{}'::jsonb,
    error_log JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Satıcı bazlı sorgular için indeks
CREATE INDEX IF NOT EXISTS idx_product_import_jobs_seller 
ON public.product_import_jobs (seller_id, created_at DESC);

-- RLS etkinleştir
ALTER TABLE public.product_import_jobs ENABLE ROW LEVEL SECURITY;

-- Güvenlik politikaları: Yalnızca ilgili satıcı kendi işlerini görebilir ve yönetebilir
DROP POLICY IF EXISTS "Sellers can view own import jobs" ON public.product_import_jobs;
CREATE POLICY "Sellers can view own import jobs"
ON public.product_import_jobs FOR SELECT
USING (auth.uid() = seller_id);

DROP POLICY IF EXISTS "Sellers can insert own import jobs" ON public.product_import_jobs;
CREATE POLICY "Sellers can insert own import jobs"
ON public.product_import_jobs FOR INSERT
WITH CHECK (auth.uid() = seller_id);

DROP POLICY IF EXISTS "Sellers can update own import jobs" ON public.product_import_jobs;
CREATE POLICY "Sellers can update own import jobs"
ON public.product_import_jobs FOR UPDATE
USING (auth.uid() = seller_id);

DROP POLICY IF EXISTS "Sellers can delete own import jobs" ON public.product_import_jobs;
CREATE POLICY "Sellers can delete own import jobs"
ON public.product_import_jobs FOR DELETE
USING (auth.uid() = seller_id);
