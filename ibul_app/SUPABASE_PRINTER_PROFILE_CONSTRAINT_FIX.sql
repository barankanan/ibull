-- SUPABASE_PRINTER_PROFILE_CONSTRAINT_FIX.sql
-- Idempotent fix for printers.printer_profile_id_check (23514 on save).
-- Run in Supabase SQL editor on production when Ethernet save fails with:
--   printers_printer_profile_id_check
--
-- Canonical ids used by Flutter PrinterProfile.canonicalDatabaseId():
--   pos58, pos80, generic_58mm_escpos, generic_80mm_escpos
-- plus legacy built-ins.

BEGIN;

-- Normalize legacy label aliases before tightening constraint.
UPDATE public.printers
SET printer_profile_id = 'pos80'
WHERE lower(btrim(printer_profile_id)) = 'pos-80';

UPDATE public.printers
SET printer_profile_id = 'pos58'
WHERE lower(btrim(printer_profile_id)) = 'pos-58';

UPDATE public.printers
SET printer_profile_id = 'pos80'
WHERE printer_profile_id IS NOT NULL
  AND lower(btrim(printer_profile_id)) NOT IN (
    'standard_58mm',
    'standard_80mm',
    'usb_pos58',
    'network_escpos',
    'receipt_80mm',
    'kitchen_58mm',
    'pos58',
    'pos80',
    'generic_58mm_escpos',
    'generic_80mm_escpos'
  )
  AND coalesce(paper_width_mm, 80) > 58;

UPDATE public.printers
SET printer_profile_id = 'pos58'
WHERE printer_profile_id IS NOT NULL
  AND lower(btrim(printer_profile_id)) NOT IN (
    'standard_58mm',
    'standard_80mm',
    'usb_pos58',
    'network_escpos',
    'receipt_80mm',
    'kitchen_58mm',
    'pos58',
    'pos80',
    'generic_58mm_escpos',
    'generic_80mm_escpos'
  )
  AND coalesce(paper_width_mm, 58) <= 58;

ALTER TABLE public.printers
  DROP CONSTRAINT IF EXISTS printers_printer_profile_id_check;

ALTER TABLE public.printers
  ADD CONSTRAINT printers_printer_profile_id_check
    CHECK (
      printer_profile_id IS NULL
      OR printer_profile_id IN (
        'standard_58mm',
        'standard_80mm',
        'usb_pos58',
        'network_escpos',
        'receipt_80mm',
        'kitchen_58mm',
        'pos58',
        'pos80',
        'generic_58mm_escpos',
        'generic_80mm_escpos'
      )
    );

NOTIFY pgrst, 'reload schema';

COMMIT;
