-- Adisyon / Fiş Bilgileri: mağaza sahibinin adisyon fişinde göstereceği
-- serbest metin alanları. İkisi de opsiyonel (nullable) — boşsa fişte
-- ilgili satır hiç basılmaz, asla demo/fallback metin kullanılmaz.
--
-- Güvenli / idempotent: tekrar çalıştırılabilir, mevcut mağaza satırlarını
-- bozmaz (yeni kolonlar NULL başlar). RLS değiştirilmez; kolonlar mevcut
-- `stores` update politikası (auth.uid() = seller_id) üzerinden güncellenir.

alter table public.stores
  add column if not exists receipt_branch_label text;

alter table public.stores
  add column if not exists receipt_footer_note text;

comment on column public.stores.receipt_branch_label is
  'Adisyon fişinde mağaza adının altında görünen serbest şube/konum etiketi '
  '(ör. "Arsuz / Gökmeydan"). NULL/boş ise fişe basılmaz.';

comment on column public.stores.receipt_footer_note is
  'Adisyon fişinin en altında görünen serbest alt not '
  '(ör. "Afiyet olsun, yine bekleriz."). NULL/boş ise fişe basılmaz.';
