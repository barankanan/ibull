-- =============================================================================
-- table_order_history — DELETE + UPDATE RLS policies
-- Date: 2026-06-13
-- Purpose: Garson "Geçmiş Masalar" ekranında tek kayıt silme ve
--          restore→re-close sonrası eksik identity alanlarını patch etme.
-- Idempotent: güvenle tekrar çalıştırılabilir.
-- =============================================================================

begin;

alter table public.table_order_history enable row level security;

-- Seller / delegated restaurant access may delete a single history row.
drop policy if exists "table_order_history_seller_delete" on public.table_order_history;
create policy "table_order_history_seller_delete"
  on public.table_order_history
  for delete
  using (
    seller_id = auth.uid()
    or public.user_can_access_restaurant(seller_id)
  );

-- Patch missing display_table_label / table_area_name after RPC close.
drop policy if exists "table_order_history_seller_update" on public.table_order_history;
create policy "table_order_history_seller_update"
  on public.table_order_history
  for update
  using (
    seller_id = auth.uid()
    or public.user_can_access_restaurant(seller_id)
  )
  with check (
    seller_id = auth.uid()
    or public.user_can_access_restaurant(seller_id)
  );

commit;
