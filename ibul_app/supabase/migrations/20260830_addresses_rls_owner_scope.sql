-- Restrict public.addresses so authenticated users cannot read/write every row.
-- Previous policy addresses_read_write_authenticated used USING (true).

drop policy if exists "addresses_read_write_authenticated" on public.addresses;
drop policy if exists "addresses_select_related" on public.addresses;
drop policy if exists "addresses_insert_own" on public.addresses;
drop policy if exists "addresses_update_own" on public.addresses;
drop policy if exists "addresses_delete_own" on public.addresses;

create policy "addresses_select_related"
on public.addresses
for select
to authenticated
using (
  created_by = auth.uid()
  or public.delivery_is_admin(auth.uid())
  or exists (
    select 1
    from public.user_saved_addresses usa
    where usa.address_id = addresses.id
      and usa.user_id = auth.uid()
  )
  or exists (
    select 1
    from public.seller_locations sl
    where sl.address_id = addresses.id
      and sl.seller_id = auth.uid()
  )
  or exists (
    select 1
    from public.delivery_quotes q
    where q.customer_address_id = addresses.id
      and (q.user_id = auth.uid() or q.seller_id = auth.uid())
  )
);

create policy "addresses_insert_own"
on public.addresses
for insert
to authenticated
with check (
  created_by = auth.uid()
  or public.delivery_is_admin(auth.uid())
);

create policy "addresses_update_own"
on public.addresses
for update
to authenticated
using (
  created_by = auth.uid()
  or public.delivery_is_admin(auth.uid())
)
with check (
  created_by = auth.uid()
  or public.delivery_is_admin(auth.uid())
);

create policy "addresses_delete_own"
on public.addresses
for delete
to authenticated
using (
  created_by = auth.uid()
  or public.delivery_is_admin(auth.uid())
);

create index if not exists idx_addresses_created_by
  on public.addresses (created_by);

create index if not exists idx_user_saved_addresses_user_address
  on public.user_saved_addresses (user_id, address_id);
