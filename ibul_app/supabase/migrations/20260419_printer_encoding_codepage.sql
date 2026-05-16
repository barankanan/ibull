-- =============================================================================
-- Migration: printer_encoding_codepage
-- Date: 2026-04-19
-- Purpose:
--   1. Persist per-printer ESC/POS encoding + code_page overrides
--   2. Normalize legacy UTF-8 printer rows to the Turkish-safe default
-- =============================================================================

alter table public.printers
  add column if not exists code_page integer;

alter table public.printers
  alter column charset set default 'cp857';

update public.printers
set charset = 'cp857'
where charset is null
   or btrim(charset) = ''
   or lower(btrim(charset)) in ('utf8', 'utf-8');

update public.printers
set code_page = 13
where code_page is null
  and lower(coalesce(charset, 'cp857')) = 'cp857';

alter table public.printers
  drop constraint if exists printers_charset_check;

alter table public.printers
  add constraint printers_charset_check
    check (charset in ('cp857', 'cp1254', 'iso-8859-9', 'cp437'));

alter table public.printers
  drop constraint if exists printers_code_page_check;

alter table public.printers
  add constraint printers_code_page_check
    check (
      code_page is null
      or (code_page >= 0 and code_page <= 255)
    );

notify pgrst, 'reload schema';
