-- Fix: store_tables tablosuna anonim kullanıcıların erişimini düzelt.
-- Müşteriler mağaza sayfasında masaları göremiyorsa bu scripti çalıştır.
--
-- Supabase SQL Editor'de çalıştır.

-- 1. anon ve authenticated rollere SELECT izni ver (RLS politikası tek başına yetmez)
grant usage on schema public to anon, authenticated;
grant select on public.store_tables to anon, authenticated;

-- 2. Mevcut politikaları kaldır ve yeniden oluştur
drop policy if exists "Public can read active store tables for QR" on public.store_tables;

create policy "Public can read active store tables for QR"
  on public.store_tables
  for select
  to anon, authenticated
  using (is_active = true);

-- 3. Satıcı kendi masalarını yönetebilmeli (tüm işlemler)
drop policy if exists "Seller can manage own store tables" on public.store_tables;

create policy "Seller can manage own store tables"
  on public.store_tables
  for all
  to authenticated
  using (auth.uid() = seller_id)
  with check (auth.uid() = seller_id);

-- 4. Doğru kurulduğunu test et (active masa sayısını döner)
select seller_id, count(*) as active_table_count
from public.store_tables
where is_active = true
group by seller_id;
