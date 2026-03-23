begin;

drop policy if exists "return_pickup_tasks_select_related" on public.ihiz_return_pickup_tasks;
create policy "return_pickup_tasks_select_related"
on public.ihiz_return_pickup_tasks
for select
to authenticated
using (
  buyer_user_id = auth.uid()
  or seller_id = auth.uid()
  or exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and lower(coalesce(u.role, '')) in ('admin', 'super_admin', 'courier', 'ihiz_courier')
  )
  or exists (
    select 1
    from public.ihiz_courier_applications app
    where app.user_id = auth.uid()
      and lower(coalesce(app.status, '')) = 'approved'
  )
);

drop policy if exists "return_pickup_tasks_update_admin_or_courier" on public.ihiz_return_pickup_tasks;
create policy "return_pickup_tasks_update_admin_or_courier"
on public.ihiz_return_pickup_tasks
for update
to authenticated
using (
  exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and lower(coalesce(u.role, '')) in ('admin', 'super_admin', 'courier', 'ihiz_courier')
  )
  or exists (
    select 1
    from public.ihiz_courier_applications app
    where app.user_id = auth.uid()
      and lower(coalesce(app.status, '')) = 'approved'
  )
)
with check (
  exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and lower(coalesce(u.role, '')) in ('admin', 'super_admin', 'courier', 'ihiz_courier')
  )
  or exists (
    select 1
    from public.ihiz_courier_applications app
    where app.user_id = auth.uid()
      and lower(coalesce(app.status, '')) = 'approved'
  )
);

commit;
