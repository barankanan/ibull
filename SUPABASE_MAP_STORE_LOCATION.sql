-- Mağaza konumu (harita) + işletme logosu için seller_applications ve stores güncellemesi.
-- Bu dosyayı Supabase Dashboard > SQL Editor'da çalıştırın. Başvuru hatası (store_lat bulunamadı) bu migration ile düzelir.

-- 1. Başvuru: mağaza konumu ve logo
alter table public.seller_applications
  add column if not exists store_lat double precision,
  add column if not exists store_lng double precision,
  add column if not exists logo_url text;

comment on column public.seller_applications.store_lat is 'Mağaza enlemi (haritadan işaretlenen)';
comment on column public.seller_applications.store_lng is 'Mağaza boylamı (haritadan işaretlenen)';
comment on column public.seller_applications.logo_url is 'Başvuruda yüklenen işletme logosu URL';

-- 2. Onaylanan mağaza: haritada konum
alter table public.stores
  add column if not exists store_lat double precision,
  add column if not exists store_lng double precision;

comment on column public.stores.store_lat is 'Mağaza enlemi (haritada pin)';
comment on column public.stores.store_lng is 'Mağaza boylamı (haritada pin)';
