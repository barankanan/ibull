-- Eksik parça: admin onayında users RLS.
-- Önceki SQL yalnızca stores INSERT politikasını açtı.
-- SQL Editor'da YENİ sorgu açıp bunun TAMAMINI Run edin.

create or replace function public.admin_can_manage_users()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and (
        lower(coalesce(u.role, '')) in ('admin', 'super_admin')
        or lower(coalesce(u.role, '')) like 'admin_%'
      )
  );
$$;

revoke all on function public.admin_can_manage_users() from public;
revoke all on function public.admin_can_manage_users() from anon;
grant execute on function public.admin_can_manage_users() to authenticated;

alter table public.users enable row level security;

drop policy if exists "Admins can update users for seller approval" on public.users;
create policy "Admins can update users for seller approval"
on public.users
for update
to authenticated
using (public.admin_can_manage_users())
with check (public.admin_can_manage_users());

drop policy if exists "Admins can insert users for seller approval" on public.users;
create policy "Admins can insert users for seller approval"
on public.users
for insert
to authenticated
with check (public.admin_can_manage_users());
