-- SUPABASE_PRINTER_PROFILE_METADATA_REPAIR.sql
-- Idempotent repair for inconsistent printer profile metadata.
-- Example failure: printer_profile_id='pos58' but paper_width_mm=80.
--
-- Run after SUPABASE_PRINTER_PROFILE_CONSTRAINT_FIX.sql if station tests fail with:
--   "Profil metadata tutarsız"
--
-- Prod: run in Supabase SQL editor during maintenance window.
-- Note: public.printers has created_at but no updated_at column in current schema.

BEGIN;

UPDATE public.printers
SET
  printer_profile_id = 'pos80',
  paper_width_mm = 80
WHERE lower(btrim(coalesce(printer_profile_id, ''))) IN ('pos58', 'pos-58', 'kitchen_58mm', 'standard_58mm', 'usb_pos58', 'generic_58mm_escpos')
  AND coalesce(paper_width_mm, 0) >= 80;

UPDATE public.printers
SET
  printer_profile_id = 'pos58',
  paper_width_mm = 58
WHERE lower(btrim(coalesce(printer_profile_id, ''))) IN ('pos80', 'pos-80', 'receipt_80mm', 'standard_80mm', 'network_escpos', 'generic_80mm_escpos')
  AND coalesce(paper_width_mm, 80) <= 58;

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
