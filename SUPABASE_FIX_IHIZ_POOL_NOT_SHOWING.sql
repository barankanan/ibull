-- IHIZ havuzunda siparişlerin görünmemesi için hızlı düzeltme
-- Neden: login onayı ihiz_courier_applications.status üzerinden, RLS helper
-- is_ihiz_courier_user ise sadece users.is_ihiz_approved üzerinden çalışıyordu.
-- Bu script, helper'ı iki kaynağı da okuyacak şekilde günceller ve mevcut kullanıcıları senkronlar.

begin;

create or replace function public.is_ihiz_courier_user(target_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = target_user_id
      and coalesce(u.is_ihiz_approved, false) = true
  ) or exists (
    select 1
    from public.ihiz_courier_applications app
    where app.user_id = target_user_id
      and lower(coalesce(app.status, '')) = 'approved'
  );
$$;

grant execute on function public.is_ihiz_courier_user(uuid) to authenticated;

update public.users u
set
  is_ihiz_approved = true,
  updated_at = now()
from public.ihiz_courier_applications app
where app.user_id = u.id
  and lower(coalesce(app.status, '')) = 'approved'
  and coalesce(u.is_ihiz_approved, false) = false;

commit;
