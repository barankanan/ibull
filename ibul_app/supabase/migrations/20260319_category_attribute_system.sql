create extension if not exists pgcrypto;

create table if not exists public.category_attributes (
  id uuid primary key default gen_random_uuid(),
  category_id text not null,
  name text not null,
  type text not null check (type in ('text', 'number', 'select')),
  filterable boolean not null default false,
  options jsonb not null default '[]'::jsonb,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create unique index if not exists idx_category_attributes_unique_name
  on public.category_attributes (category_id, name);

create index if not exists idx_category_attributes_category_sort
  on public.category_attributes (category_id, sort_order, name);

create table if not exists public.product_attributes (
  id uuid primary key default gen_random_uuid(),
  product_id text not null references public.products(id) on delete cascade,
  attribute_id uuid not null references public.category_attributes(id) on delete cascade,
  value text not null,
  created_at timestamptz not null default now()
);

create unique index if not exists idx_product_attributes_unique_product_attribute
  on public.product_attributes (product_id, attribute_id);

create index if not exists idx_product_attributes_attribute_value
  on public.product_attributes (attribute_id, value);

alter table public.category_attributes enable row level security;
alter table public.product_attributes enable row level security;

drop policy if exists "category_attributes_read_all" on public.category_attributes;
create policy "category_attributes_read_all"
on public.category_attributes
for select
using (true);

drop policy if exists "category_attributes_manage_admin" on public.category_attributes;
create policy "category_attributes_manage_admin"
on public.category_attributes
for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

drop policy if exists "product_attributes_read_all" on public.product_attributes;
create policy "product_attributes_read_all"
on public.product_attributes
for select
using (true);

drop policy if exists "product_attributes_manage_owner" on public.product_attributes;
create policy "product_attributes_manage_owner"
on public.product_attributes
for all
using (
  exists (
    select 1
    from public.products p
    where p.id = product_attributes.product_id
      and p.seller_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.products p
    where p.id = product_attributes.product_id
      and p.seller_id = auth.uid()
  )
);

insert into public.category_attributes (
  category_id,
  name,
  type,
  filterable,
  options,
  sort_order
)
values
  ('elektronik::telefonlar', 'Marka', 'select', true, '["Apple","Samsung","Xiaomi","Huawei","Oppo","Vivo","Nothing"]'::jsonb, 1),
  ('elektronik::telefonlar', 'Model', 'text', true, '[]'::jsonb, 2),
  ('elektronik::telefonlar', 'Dahili Hafıza', 'select', true, '["64 GB","128 GB","256 GB","512 GB","1 TB"]'::jsonb, 3),
  ('elektronik::telefonlar', 'RAM', 'select', true, '["4 GB","6 GB","8 GB","12 GB","16 GB"]'::jsonb, 4),
  ('elektronik::telefonlar', 'Ekran Boyutu', 'number', false, '[]'::jsonb, 5),
  ('elektronik::telefonlar', 'Ekran Teknolojisi', 'select', true, '["LCD","IPS LCD","OLED","AMOLED","Dynamic AMOLED"]'::jsonb, 6),
  ('elektronik::telefonlar', 'Yenileme Hızı', 'select', true, '["60 Hz","90 Hz","120 Hz","144 Hz"]'::jsonb, 7),
  ('elektronik::telefonlar', 'İşlemci', 'text', false, '[]'::jsonb, 8),
  ('elektronik::telefonlar', 'İşletim Sistemi', 'select', true, '["iOS","Android"]'::jsonb, 9),
  ('elektronik::telefonlar', 'Batarya Kapasitesi', 'number', true, '[]'::jsonb, 10),
  ('elektronik::telefonlar', 'Hızlı Şarj', 'select', true, '["Var","Yok"]'::jsonb, 11),
  ('elektronik::telefonlar', 'Kamera (Arka)', 'text', false, '[]'::jsonb, 12),
  ('elektronik::telefonlar', 'Kamera (Ön)', 'text', false, '[]'::jsonb, 13),
  ('elektronik::telefonlar', 'Video Kayıt', 'text', false, '[]'::jsonb, 14),
  ('elektronik::telefonlar', '5G Desteği', 'select', true, '["Var","Yok"]'::jsonb, 15),
  ('elektronik::telefonlar', 'NFC', 'select', true, '["Var","Yok"]'::jsonb, 16),
  ('elektronik::telefonlar', 'Bluetooth Versiyonu', 'text', false, '[]'::jsonb, 17),
  ('elektronik::telefonlar', 'SIM Türü', 'select', true, '["Nano SIM","eSIM","Nano SIM + eSIM"]'::jsonb, 18),
  ('elektronik::telefonlar', 'Çift Hat', 'select', true, '["Var","Yok"]'::jsonb, 19),
  ('elektronik::telefonlar', 'Suya Dayanıklılık', 'select', true, '["IP52","IP67","IP68","Yok"]'::jsonb, 20),
  ('elektronik::telefonlar', 'Parmak İzi Sensörü', 'select', true, '["Var","Yok"]'::jsonb, 21),
  ('elektronik::telefonlar', 'Yüz Tanıma', 'select', true, '["Var","Yok"]'::jsonb, 22),
  ('elektronik::telefonlar', 'Garanti Tipi', 'select', true, '["Distribütör Garantili","İthalatçı Garantili","Resmi Garantili"]'::jsonb, 23),
  ('giyim-ve-aksesuar::erkek-giyim', 'Marka', 'text', true, '[]'::jsonb, 1),
  ('giyim-ve-aksesuar::erkek-giyim', 'Beden', 'select', true, '["XS","S","M","L","XL","XXL"]'::jsonb, 2),
  ('giyim-ve-aksesuar::erkek-giyim', 'Renk', 'select', true, '["Siyah","Beyaz","Lacivert","Gri","Mavi","Yeşil"]'::jsonb, 3),
  ('giyim-ve-aksesuar::erkek-giyim', 'Kumaş Türü', 'select', true, '["Pamuk","Polyester","Pamuk-Polyester","Modal","Keten"]'::jsonb, 4),
  ('giyim-ve-aksesuar::erkek-giyim', 'Kalıp', 'select', true, '["Slim Fit","Regular Fit","Oversize"]'::jsonb, 5),
  ('giyim-ve-aksesuar::erkek-giyim', 'Yaka Tipi', 'select', true, '["Bisiklet Yaka","V Yaka","Polo Yaka"]'::jsonb, 6),
  ('giyim-ve-aksesuar::erkek-giyim', 'Kol Tipi', 'select', true, '["Kısa Kol","Uzun Kol","Kolsuz"]'::jsonb, 7),
  ('giyim-ve-aksesuar::erkek-giyim', 'Desen', 'select', true, '["Düz","Baskılı","Çizgili"]'::jsonb, 8),
  ('giyim-ve-aksesuar::erkek-giyim', 'Mevsim', 'select', true, '["Yaz","Kış","İlkbahar/Sonbahar","Dört Mevsim"]'::jsonb, 9),
  ('giyim-ve-aksesuar::erkek-giyim', 'Stil', 'select', true, '["Günlük","Spor","Klasik"]'::jsonb, 10),
  ('giyim-ve-aksesuar::erkek-giyim', 'Kullanım Alanı', 'select', true, '["Günlük","Ofis","Spor","Outdoor"]'::jsonb, 11),
  ('giyim-ve-aksesuar::tisort', 'Marka', 'text', true, '[]'::jsonb, 1),
  ('giyim-ve-aksesuar::tisort', 'Beden', 'select', true, '["XS","S","M","L","XL","XXL"]'::jsonb, 2),
  ('giyim-ve-aksesuar::tisort', 'Renk', 'select', true, '["Siyah","Beyaz","Lacivert","Gri","Mavi","Yeşil"]'::jsonb, 3),
  ('giyim-ve-aksesuar::tisort', 'Kumaş Türü', 'select', true, '["Pamuk","Polyester","Pamuk-Polyester","Modal","Keten"]'::jsonb, 4),
  ('giyim-ve-aksesuar::tisort', 'Kalıp', 'select', true, '["Slim Fit","Regular Fit","Oversize"]'::jsonb, 5),
  ('giyim-ve-aksesuar::tisort', 'Yaka Tipi', 'select', true, '["Bisiklet Yaka","V Yaka","Polo Yaka"]'::jsonb, 6),
  ('giyim-ve-aksesuar::tisort', 'Kol Tipi', 'select', true, '["Kısa Kol","Uzun Kol","Kolsuz"]'::jsonb, 7),
  ('giyim-ve-aksesuar::tisort', 'Desen', 'select', true, '["Düz","Baskılı","Çizgili"]'::jsonb, 8),
  ('giyim-ve-aksesuar::tisort', 'Mevsim', 'select', true, '["Yaz","Kış","İlkbahar/Sonbahar","Dört Mevsim"]'::jsonb, 9),
  ('giyim-ve-aksesuar::tisort', 'Stil', 'select', true, '["Günlük","Spor","Klasik"]'::jsonb, 10),
  ('giyim-ve-aksesuar::tisort', 'Kullanım Alanı', 'select', true, '["Günlük","Ofis","Spor","Outdoor"]'::jsonb, 11),
  ('giyim-ve-aksesuar::ayakkabi', 'Marka', 'text', true, '[]'::jsonb, 1),
  ('giyim-ve-aksesuar::ayakkabi', 'Numara', 'select', true, '["36","37","38","39","40","41","42","43","44","45"]'::jsonb, 2),
  ('giyim-ve-aksesuar::ayakkabi', 'Renk', 'select', true, '["Siyah","Beyaz","Kahverengi","Bej","Gri","Lacivert"]'::jsonb, 3),
  ('giyim-ve-aksesuar::ayakkabi', 'Materyal', 'select', true, '["Deri","Suni Deri","Tekstil","Süet","File"]'::jsonb, 4),
  ('giyim-ve-aksesuar::ayakkabi', 'Taban Türü', 'select', true, '["Kauçuk","Termo","Eva","Poliüretan"]'::jsonb, 5),
  ('giyim-ve-aksesuar::ayakkabi', 'Bağlama Türü', 'select', true, '["Bağcıklı","Bağcıksız","Cırt Cırt","Fermuarlı"]'::jsonb, 6),
  ('giyim-ve-aksesuar::ayakkabi', 'Kullanım Alanı', 'select', true, '["Günlük","Koşu","Antrenman","Outdoor","Ofis"]'::jsonb, 7),
  ('giyim-ve-aksesuar::ayakkabi', 'Topuk Yüksekliği', 'number', false, '[]'::jsonb, 8),
  ('giyim-ve-aksesuar::ayakkabi', 'Su Geçirmezlik', 'select', true, '["Var","Yok"]'::jsonb, 9)
on conflict (category_id, name) do update
set
  type = excluded.type,
  filterable = excluded.filterable,
  options = excluded.options,
  sort_order = excluded.sort_order;
