-- printers: columns that PrinterModel.toMap() writes but a database built
-- without the stand-alone hotfix files does not have.
--
-- Symptom: saving an Ethernet printer fails with
--   PGRST204 Could not find the 'code_page' column of 'printers'
-- while the connection test and the test receipt succeed (they go through the
-- local print bridge and never touch Postgres).
--
-- Sources of truth (unchanged, still valid):
--   SUPABASE_PRINTERS_MIGRATION.sql
--   ibul_app/SUPABASE_PRINTER_RECEIPT_LENGTH_SETTINGS.sql
--
-- Additive and idempotent: no column is dropped, no row is rewritten, and
-- every column is nullable, so existing data and running apps are unaffected.

alter table public.printers
  add column if not exists code_page                     integer,
  add column if not exists last_test_print_at            timestamptz,
  add column if not exists last_error                    text,
  add column if not exists test_print_status             text,
  add column if not exists printer_profile_id            text,
  add column if not exists receipt_bottom_feed_lines     integer,
  add column if not exists receipt_cut_feed_lines        integer,
  add column if not exists receipt_min_trailing_blank_lines integer,
  add column if not exists receipt_bottom_padding_px     integer,
  add column if not exists receipt_min_receipt_height_px integer;

alter table public.printers drop constraint if exists printers_code_page_check;
alter table public.printers add constraint printers_code_page_check
  check (code_page is null or (code_page >= 0 and code_page <= 255));

alter table public.printers drop constraint if exists printers_test_print_status_check;
alter table public.printers add constraint printers_test_print_status_check
  check (test_print_status is null or test_print_status in ('ok', 'failed', 'pending'));

alter table public.printers drop constraint if exists printers_printer_profile_id_check;
alter table public.printers add constraint printers_printer_profile_id_check
  check (
    printer_profile_id is null
    or printer_profile_id in (
      'standard_58mm', 'standard_80mm', 'usb_pos58',
      'network_escpos', 'receipt_80mm', 'kitchen_58mm',
      'pos58', 'pos80'
    )
  );

alter table public.printers drop constraint if exists printers_receipt_bottom_feed_lines_check;
alter table public.printers add constraint printers_receipt_bottom_feed_lines_check
  check (receipt_bottom_feed_lines is null
         or (receipt_bottom_feed_lines >= 0 and receipt_bottom_feed_lines <= 30));

alter table public.printers drop constraint if exists printers_receipt_cut_feed_lines_check;
alter table public.printers add constraint printers_receipt_cut_feed_lines_check
  check (receipt_cut_feed_lines is null
         or (receipt_cut_feed_lines >= 0 and receipt_cut_feed_lines <= 30));

alter table public.printers drop constraint if exists printers_receipt_min_trailing_blank_lines_check;
alter table public.printers add constraint printers_receipt_min_trailing_blank_lines_check
  check (receipt_min_trailing_blank_lines is null
         or (receipt_min_trailing_blank_lines >= 0 and receipt_min_trailing_blank_lines <= 30));

-- The repository saves with ON CONFLICT (restaurant_id, code) and
-- ON CONFLICT (station_id, printer_id). Without these unique indexes Postgres
-- answers 42P10 ("no unique or exclusion constraint matching the ON CONFLICT
-- specification") even after the columns exist.
-- Definitions are the ones in ibul_app/SUPABASE_KITCHEN_PRINT_ROUTING.sql.
create unique index if not exists idx_printers_restaurant_code_unique
  on public.printers(restaurant_id, code);
create index if not exists idx_printers_restaurant_id
  on public.printers(restaurant_id);
create index if not exists idx_printers_restaurant_active
  on public.printers(restaurant_id, is_active);

create unique index if not exists idx_station_printers_unique
  on public.station_printers(station_id, printer_id);
create index if not exists idx_station_printers_station_id
  on public.station_printers(station_id, is_primary);
create index if not exists idx_station_printers_printer_id
  on public.station_printers(printer_id);

-- Make PostgREST see the new columns without a restart.
notify pgrst, 'reload schema';
