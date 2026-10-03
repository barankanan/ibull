-- Cleanup hiçbir satır silmediği için geri alınacak veri yok.
do $$ begin
  raise notice 'ROLLBACK NO-OP: mall_store_duplicate_cleanup.sql veri değiştirmedi.';
end $$;
