-- Primall / Teknosa duplicate cleanup. 2026-10-03: silinecek satır yok.
-- Tek approved bağlantı: 24f6d83a-6d08-4b30-9d4a-45392b90a6ee / unit_code 2.
-- Bu dosya bilinçli olarak hiçbir mall_branch_links satırını silmez.
do $$
declare
  n int;
begin
  select count(*) into n from (
    select mall_id, branch_id from public.mall_branch_links
    where status in ('pending', 'approved') group by 1, 2 having count(*) > 1) d;
  if n > 0 then
    raise exception 'Açık duplicate var (%). Önce precheck çıktısını inceleyin; otomatik DELETE yok.', n;
  end if;
  raise notice 'CLEANUP SKIP: açık duplicate yok. Teknosa tek approved satır.';
end $$;
