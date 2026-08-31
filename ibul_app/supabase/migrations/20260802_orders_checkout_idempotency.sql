-- orders.idempotency_key: checkout çift-sipariş koruması için DB-seviyesi altyapı.
-- Tamamen additive: yalnız kolon + partial unique index. Flutter checkout akışı
-- (wallet reserve, delivery fee, notification, order history) DEĞİŞMEZ; RPC/function/
-- trigger/policy/RLS'e dokunulmaz. Kolon NULL bırakılabilir; index yalnız non-null
-- key'lerde çalışır, dolayısıyla mevcut siparişler etkilenmez.
-- Not: create_order_from_cart RPC bilinçli olarak TAŞINMADI (davranış-uyumsuz).

begin;

alter table public.orders
  add column if not exists idempotency_key text;

comment on column public.orders.idempotency_key is
  'Checkout idempotency anahtarı (client-üretimli). NULL = eski/anahtarsız sipariş. '
  'Aynı user_id için tekrar kullanımı idx_orders_user_idempotency ile engellenir.';

-- Partial unique index: yalnız non-null key'lerde tekilliği zorlar.
-- NULL key'ler distinct sayılır → mevcut/eski siparişler ve anahtarsız akışlar serbest.
create unique index if not exists idx_orders_user_idempotency
  on public.orders (user_id, idempotency_key)
  where idempotency_key is not null;

-- PostgREST schema cache (Supabase): DDL sonrası reload.
notify pgrst, 'reload schema';

commit;
