-- DRAFT — DO NOT APPLY without explicit operator approval naming this file.
-- Kök neden (üretimde salt-okunur doğrulandı): table_orders.seller_id = TEXT, close_table_orders ise
-- `seller_id = p_seller_id` (uuid) karşılaştırıyor → 42883 "operator does not exist: text = uuid".
-- Fonksiyon bugün her çağrıda düşüyor; uygulama bu yüzden doğrudan DELETE yedeğine iniyor.
-- Düzeltme: iki karşılaştırmaya ::text. Yetki kapısı (restaurant_staff_may_operate) korunur.
-- ÖN KOŞUL: 20261123_table_order_history_write_hardening (yetki kapısı) üretimde uygulanmış (uygulandı).
-- Geri alma: aynı fonksiyonun ::text'siz hâli (= şu anki üretim gövdesi).
begin;
do $$
declare d text := pg_get_functiondef('public.close_table_orders(uuid,integer,text,text,uuid,text,text)'::regprocedure);
begin
  if position('restaurant_staff_may_operate' in d) = 0 then
    raise exception 'close_table_orders yetki kapısı yok; önce sertleştirme uygulanmalı';
  end if;
  if position('WHERE seller_id = p_seller_id AND table_number' in d) = 0 then
    raise exception 'beklenen gövde bulunamadı';
  end if;
  d := replace(d, 'WHERE seller_id = p_seller_id AND table_number', 'WHERE seller_id = p_seller_id::text AND table_number');
  execute d;
end $$;
commit;
