-- Sipariş RPC'si: ürün kimliği işletmeye ait olmalı + kalem fiyat/adet makul sınırlarda.
--
-- Canlıda doğrulanan boşluk (geri alınan prova, 2026-11-22): `create_table_order_with_print_jobs_impl`
-- katalogda OLMAYAN bir product_id'yi ve istemcinin gönderdiği fiyatı olduğu gibi yazıyordu.
-- Repodaki `20261112234500_bill_line_price_authority.sql` (order_items tetikleyicisi) üretimde
-- UYGULANMAMIŞ; ayrıca o migration katalog TABAN fiyatına bağlıdır ve üretim menüsünün
-- boy/gram/ek fiyatlarını (geçmiş kalemlerin ~%6'sı katalogdan türetilemiyor) engellerdi.
--
-- Bu migration YALNIZ şunu ekler (fiyat eşitliği ZORLANMAZ; fiyat modeli ayrı karar):
--  * kalemde product_id varsa bu işletmenin kataloğunda olmalı ("Ürün bu işletmeye ait değil.", 42501),
--  * adet 1–99, fiyat 0–1.000.000 (negatif/absürt değerler 22023).
-- Üretim verisi: product_id'si olup bu işletmenin kataloğunda bulunmayan kalemler yalnız 11 Mart–20 Mayıs
-- 2026 arasında (silinmiş eski ürünler); başka işletmenin ürünü 0; en yüksek adet 4; son 6 ayda ihlal yok.
--
-- Gövde değişikliği: canlı `_impl` gövdesinin (md5 2f942a71…, 17686) istasyon kontrolünden hemen SONRASINA
-- bir blok eklenir; başka hiçbir satır değişmez. Beklenen kalıp yoksa hiçbir şey yazılmaz.
-- Geri alma: rollbacks/20261122150000_order_rpc_product_ownership_guard_rollback.sql

begin;

do $mig$
declare
  v_oid oid := to_regprocedure(
    'public.create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text,text,uuid,uuid)');
  v_def text;
  v_anchor constant text :=
    E'raise exception ''İstasyon bu işletmeye ait değil.'' using errcode = ''42501'';\n  end if;\n';
  v_block constant text := $blk$
  -- p8: ürün sahipliği + kalem sınırları
  if exists (
    select 1 from jsonb_array_elements(p_items) item
    where nullif(btrim(item->>'product_id'), '') is not null
      and not exists (
        select 1 from public.products pr
        where pr.id::text = btrim(item->>'product_id')
          and pr.seller_id = p_restaurant_id)
  ) then
    raise exception 'Ürün bu işletmeye ait değil.' using errcode = '42501';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_items) item
    where coalesce((item->>'price')::numeric, 0) < 0
       or coalesce((item->>'price')::numeric, 0) > 1000000
       or coalesce((item->>'quantity')::numeric, 1) < 1
       or coalesce((item->>'quantity')::numeric, 1) > 99
  ) then
    raise exception 'Sipariş kalemi fiyatı veya adedi geçersiz.' using errcode = '22023';
  end if;
$blk$;
begin
  if v_oid is null then
    raise exception '12 argümanlı create_table_order_with_print_jobs_impl yok; yeni gövde yazılmadı.';
  end if;
  v_def := pg_get_functiondef(v_oid);
  if position('-- p8: ürün sahipliği' in v_def) > 0 then
    return; -- zaten uygulanmış
  end if;
  if (length(v_def) - length(replace(v_def, v_anchor, ''))) / length(v_anchor) <> 1 then
    raise exception 'Beklenen istasyon kontrolü kalıbı tam bir kez bulunamadı; gövde değiştirilmedi.';
  end if;
  v_def := replace(v_def, v_anchor, v_anchor || v_block);
  execute v_def;
end
$mig$;

commit;
