-- Geri alma: 20261122150000_order_rpc_product_ownership_guard.sql
-- Eklenen bloğu `_impl` gövdesinden çıkarır (canlı md5 2f942a7187c3c68eb7ca9c43459af4b8 / 17686'ya döner).
begin;
do $rb$
declare
  v_oid oid := to_regprocedure(
    'public.create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text,text,uuid,uuid)');
  v_def text;
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
    raise exception '12 argümanlı create_table_order_with_print_jobs_impl yok.';
  end if;
  v_def := pg_get_functiondef(v_oid);
  if position(v_block in v_def) = 0 then
    raise notice 'Geri alınacak blok bulunamadı; değişiklik yok.';
    return;
  end if;
  execute replace(v_def, v_block, '');
end
$rb$;
commit;
