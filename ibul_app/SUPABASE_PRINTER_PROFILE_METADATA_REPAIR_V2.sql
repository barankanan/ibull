-- SUPABASE_PRINTER_PROFILE_METADATA_REPAIR_V2.sql
-- Idempotent repair for stale pos58 profile labels on 80mm printers.
-- Safe: does not change printer id or station_printers mappings.
--
-- Run after:
--   ibul_app/SUPABASE_PRINTER_PROFILE_CONSTRAINT_FIX.sql
--   ibul_app/SUPABASE_PRINTER_PROFILE_METADATA_REPAIR.sql

BEGIN;

-- pos58 label + 80mm paper → canonical pos80
UPDATE public.printers
SET
  printer_profile_id = 'pos80',
  paper_width_mm = 80
WHERE lower(btrim(coalesce(printer_profile_id, ''))) IN (
  'pos58', 'pos-58', 'kitchen_58mm', 'standard_58mm', 'usb_pos58', 'generic_58mm_escpos'
)
AND coalesce(paper_width_mm, 0) >= 80;

-- generic_80mm_escpos with wrong width
UPDATE public.printers
SET
  printer_profile_id = 'generic_80mm_escpos',
  paper_width_mm = 80
WHERE lower(btrim(coalesce(printer_profile_id, ''))) = 'generic_80mm_escpos'
  AND coalesce(paper_width_mm, 0) != 80;

-- pos80 label + 58mm paper → canonical pos58
UPDATE public.printers
SET
  printer_profile_id = 'pos58',
  paper_width_mm = 58
WHERE lower(btrim(coalesce(printer_profile_id, ''))) IN (
  'pos80', 'pos-80', 'receipt_80mm', 'standard_80mm', 'network_escpos', 'generic_80mm_escpos'
)
AND coalesce(paper_width_mm, 80) <= 58;

-- Empty profile id: derive from paper width
UPDATE public.printers
SET
  printer_profile_id = CASE
    WHEN coalesce(paper_width_mm, 80) <= 58 THEN 'pos58'
    ELSE 'pos80'
  END,
  paper_width_mm = CASE
    WHEN coalesce(paper_width_mm, 80) <= 58 THEN 58
    ELSE 80
  END
WHERE printer_profile_id IS NULL
   OR btrim(printer_profile_id) = '';

NOTIFY pgrst, 'reload schema';

COMMIT;
