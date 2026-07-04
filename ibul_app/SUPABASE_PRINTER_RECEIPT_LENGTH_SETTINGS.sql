-- Idempotent: per-printer receipt tail length (Yazıcı Merkezi > Fiş Uzunluğu).
-- Safe to run multiple times.

alter table public.printers
  add column if not exists receipt_length_preset text not null default 'normal';

alter table public.printers
  add column if not exists receipt_bottom_feed_lines integer;

alter table public.printers
  add column if not exists receipt_cut_feed_lines integer;

alter table public.printers
  add column if not exists receipt_min_trailing_blank_lines integer;

alter table public.printers
  add column if not exists receipt_bottom_padding_px integer;
  
alter table public.printers
  add column if not exists receipt_min_receipt_height_px integer;

alter table public.printers
  drop constraint if exists printers_receipt_length_preset_check;

alter table public.printers
  add constraint printers_receipt_length_preset_check
    check (receipt_length_preset in ('short', 'normal', 'long', 'custom'));

alter table public.printers
  drop constraint if exists printers_receipt_bottom_feed_lines_check;

alter table public.printers
  add constraint printers_receipt_bottom_feed_lines_check
    check (
      receipt_bottom_feed_lines is null
      or (receipt_bottom_feed_lines >= 0 and receipt_bottom_feed_lines <= 30)
    );

alter table public.printers
  drop constraint if exists printers_receipt_cut_feed_lines_check;

alter table public.printers
  add constraint printers_receipt_cut_feed_lines_check
    check (
      receipt_cut_feed_lines is null
      or (receipt_cut_feed_lines >= 0 and receipt_cut_feed_lines <= 30)
    );

alter table public.printers
  drop constraint if exists printers_receipt_min_trailing_blank_lines_check;

alter table public.printers
  add constraint printers_receipt_min_trailing_blank_lines_check
    check (
      receipt_min_trailing_blank_lines is null
      or (
        receipt_min_trailing_blank_lines >= 0
        and receipt_min_trailing_blank_lines <= 30
      )
    );

alter table public.printers
  drop constraint if exists printers_receipt_bottom_padding_px_check;

alter table public.printers
  add constraint printers_receipt_bottom_padding_px_check
    check (
      receipt_bottom_padding_px is null
      or (receipt_bottom_padding_px >= 0 and receipt_bottom_padding_px <= 700)
    );

alter table public.printers
  drop constraint if exists printers_receipt_min_receipt_height_px_check;

alter table public.printers
  add constraint printers_receipt_min_receipt_height_px_check
    check (
      receipt_min_receipt_height_px is null
      or (
        receipt_min_receipt_height_px >= 400
        and receipt_min_receipt_height_px <= 1600
      )
    );

update public.printers
set receipt_length_preset = 'normal'
where receipt_length_preset is null
   or btrim(receipt_length_preset) = '';

notify pgrst, 'reload schema';
