-- DRAFT — geri alma: 20261124_order_waiter_identity_DRAFT.sql (canlı md5 b521ede6…/18518'e döner).
-- Yazılmış orders.waiter_id değerlerine dokunmaz.
begin;
do $rb$
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
    -- Doğrulanamayan kimlik ASLA başkasına (işletme sahibine) çevrilmez: çağıran bu
    -- işletmenin aktif personeliyse kendi kimliği, aksi hâlde NULL = "doğrulanmamış garson".
    when exists (
      select 1 from public.store_sub_admins me
      where me.store_id = p_restaurant_id
        and me.status = 'active'
        and me.auth_user_id = auth.uid()
    ) then auth.uid()
    else null
  end
  limit 1;
$blk$;
begin
  if v_oid is null then
    raise exception '12 argümanlı create_table_order_with_print_jobs_impl yok.';
  end if;
  v_def := pg_get_functiondef(v_oid);
  if position(v_new in v_def) = 0 then
    raise notice 'Geri alınacak blok bulunamadı; değişiklik yok.';
    return;
  end if;
  execute replace(v_def, v_new, v_old);
end
$rb$;
commit;
