-- ============================================================
-- Migration: Add new columns to printers table
-- Run this in Supabase SQL editor ONCE.
-- Idempotent — safe to run multiple times (IF NOT EXISTS).
-- ============================================================

ALTER TABLE public.printers
  ADD COLUMN IF NOT EXISTS supports_cut       boolean     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS charset            text        NOT NULL DEFAULT 'cp857',
  ADD COLUMN IF NOT EXISTS code_page          integer,
  ADD COLUMN IF NOT EXISTS assigned_roles     jsonb       NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS last_test_print_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_error         text,
  ADD COLUMN IF NOT EXISTS test_print_status  text,
  -- Printer profile ID referencing a built-in profile key (e.g. 'standard_80mm').
  -- NULL for legacy printers created before the profile system was introduced.
  ADD COLUMN IF NOT EXISTS printer_profile_id text;

-- Optional: add a check constraint so test_print_status only holds known values
ALTER TABLE public.printers
  DROP CONSTRAINT IF EXISTS printers_test_print_status_check;

ALTER TABLE public.printers
  ADD CONSTRAINT printers_test_print_status_check
    CHECK (test_print_status IS NULL
        OR test_print_status IN ('ok', 'failed', 'pending'));

-- Optional: add a check constraint for charset
ALTER TABLE public.printers
  DROP CONSTRAINT IF EXISTS printers_charset_check;

ALTER TABLE public.printers
  ADD CONSTRAINT printers_charset_check
    CHECK (charset IN ('cp857', 'cp1254', 'iso-8859-9', 'cp437'));

ALTER TABLE public.printers
  DROP CONSTRAINT IF EXISTS printers_code_page_check;

ALTER TABLE public.printers
  ADD CONSTRAINT printers_code_page_check
    CHECK (code_page IS NULL OR (code_page >= 0 AND code_page <= 255));

-- Printer profile ID: validate against known built-in profile keys.
ALTER TABLE public.printers
  DROP CONSTRAINT IF EXISTS printers_printer_profile_id_check;

ALTER TABLE public.printers
  ADD CONSTRAINT printers_printer_profile_id_check
    CHECK (printer_profile_id IS NULL
        OR printer_profile_id IN (
            'standard_58mm', 'standard_80mm', 'usb_pos58',
            'network_escpos', 'receipt_80mm', 'kitchen_58mm'
        ));

-- Refresh the Supabase schema cache immediately
-- (Run in SQL editor or trigger a schema refresh from Supabase Dashboard → API → Reload schema)
NOTIFY pgrst, 'reload schema';
UPDATE public.printers
SET charset = 'cp857'
WHERE charset IS NULL
   OR btrim(charset) = ''
   OR lower(btrim(charset)) IN ('utf8', 'utf-8');

UPDATE public.printers
SET code_page = 13
WHERE code_page IS NULL
  AND lower(coalesce(charset, 'cp857')) = 'cp857';
