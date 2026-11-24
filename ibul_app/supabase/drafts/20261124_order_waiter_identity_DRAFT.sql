-- DRAFT — DO NOT APPLY without explicit operator approval naming this file.
-- Üretimde UYGULANMADI (2026-11-24). Üretime yazma yok; yalnız izole kanıt var:
-- tests/run_isolated_order_waiter_identity.sh
--
-- Sorun (salt-okunur doğrulandı): create_table_order_with_print_jobs_impl, çağıran işletme
-- sahibi (ya da sahibin JWT'siyle çalışan doğrulayıcı Edge fonksiyonu = p_verified_actor) iken
-- p_waiter_id'yi HİÇ doğrulamadan orders.waiter_id'ye yazar: `public.users`'ta var olan HER kimlik
-- (başka işletmenin personeli, müşteri, pasif personel) garson olarak yazılabilir. Mac LAN merkezi
-- siparişleri sahibin oturumuyla senkronladığı için garson kimliği taşıyan tek yol bu alandır; bu
-- alan şimdi doğrulanmadığından istemci tarafı düzeltmesi (doğrulanmış personel kimliği gönderme)
-- tek başına yetmez.
--
-- Düzeltme (en dar): p_waiter_id yalnız şu durumlarda orders.waiter_id olur —
--   * boş ya da çağıranın kendisi (eski davranış), veya
--   * BU işletmenin AKTİF personeli (store_sub_admins.status = 'active', auth_user_id = p_waiter_id),
--     'manageOrders' yetkisi var, şubesi (varsa) aktif ve masanın şubesiyle aynı.
-- Aksi hâlde sipariş REDDEDİLMEZ; garson çağıranın kendisine düşer (bugünkü sonuç). Böylece
-- senkron sırasında pasife alınmış bir personelin eski siparişi kaybolmaz, ama başkasının
-- kimliği de yazılamaz. Sipariş kalemi, toplam, baskı, kimlik/oturum kuralları DEĞİŞMEZ.
-- Gövde: canlı `_impl` (md5 b521ede6…, 18518) içinde tek `where` satırı değişir; beklenen kalıp
-- tam bir kez bulunmazsa hiçbir şey yazılmaz. Geçmiş siparişler DEĞİŞTİRİLMEZ (Teras 8 dahil).
-- Geri alma: 20261124_order_waiter_identity_ROLLBACK_DRAFT.sql
begin;

do $mig$
declare
  v_oid oid := to_regprocedure(
    'public.create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text,text,uuid,uuid)');
  v_def text;
  v_old constant text :=
    E'  from public.users u\n  where u.id = coalesce(p_waiter_id, auth.uid())\n  limit 1;\n';
  v_new constant text := $blk$
  from public.users u
  where u.id = case
    when p_waiter_id is null or p_waiter_id = auth.uid() then auth.uid()
    -- p9: garson kimliği yalnız bu işletmenin aktif, sipariş yetkili personeli olabilir
    when exists (
      select 1 from public.store_sub_admins sa
      where sa.store_id = p_restaurant_id
        and sa.status = 'active'
        and sa.auth_user_id = p_waiter_id
        and 'manageOrders' = any(sa.permissions)
        and (sa.branch_id is null or (
          exists (select 1 from public.store_tables t
                  where t.id = v_table_id and t.branch_id = sa.branch_id)
          and exists (select 1 from public.store_branches b
                      where b.id = sa.branch_id and b.store_id = sa.store_id
                        and b.status = 'active')))
    ) then p_waiter_id
    else auth.uid()
  end
  limit 1;
$blk$;
begin
  if v_oid is null then
    raise exception '12 argümanlı create_table_order_with_print_jobs_impl yok; yeni gövde yazılmadı.';
  end if;
  v_def := pg_get_functiondef(v_oid);
  if position('-- p9: garson kimliği' in v_def) > 0 then
    return; -- zaten uygulanmış
  end if;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'Beklenen garson seçimi kalıbı tam bir kez bulunamadı; gövde değiştirilmedi.';
  end if;
  if position('v_table_id' in v_def) = 0 then
    raise exception 'v_table_id gövdede yok; gövde değiştirilmedi.';
  end if;
  execute replace(v_def, v_old, v_new);
end
$mig$;

commit;
