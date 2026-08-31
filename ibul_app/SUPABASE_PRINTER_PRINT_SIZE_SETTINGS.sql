-- Idempotent: per-printer print text size (Yazıcı Ayarları > Baskı Boyutu).
-- Safe to run multiple times. Default `normal` keeps existing physical output.

alter table public.printers
  add column if not exists print_size text not null default 'normal';

alter table public.printers
  drop constraint if exists printers_print_size_check;

alter table public.printers
  add constraint printers_print_size_check
    check (print_size in ('small', 'normal', 'large', 'xlarge'));

update public.printers
set print_size = 'normal'
where print_size is null
   or btrim(print_size) = '';

notify pgrst, 'reload schema';
