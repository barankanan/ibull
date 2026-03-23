-- Admin panelinden magaza konum onayinda stores tablosu update edilebilsin.
-- Supabase SQL Editor'da bir kez calistirin.

alter table public.stores enable row level security;

drop policy if exists "Admins can update stores" on public.stores;
create policy "Admins can update stores"
on public.stores
for update
to authenticated
using (
  auth.uid() = seller_id
  or exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and (
        users.role = 'admin'
        or users.role = 'super_admin'
        or users.role like 'admin_%'
      )
  )
)
with check (
  auth.uid() = seller_id
  or exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and (
        users.role = 'admin'
        or users.role = 'super_admin'
        or users.role like 'admin_%'
      )
  )
);
