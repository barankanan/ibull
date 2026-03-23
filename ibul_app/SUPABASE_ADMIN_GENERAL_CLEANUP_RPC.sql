begin;

create or replace function public.admin_general_cleanup()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_is_admin boolean := false;
  v_deleted_history integer := 0;
  v_deleted_items integer := 0;
  v_deleted_orders integer := 0;
  v_deleted_notifications integer := 0;
begin
  if v_actor is null then
    raise exception 'not authenticated';
  end if;

  select exists (
           select 1
           from public.users u
           where u.id = v_actor
             and (
               lower(coalesce(u.role, '')) in ('admin', 'super_admin')
               or lower(coalesce(u.role, '')) like 'admin_%'
             )
         )
         or exists (
           select 1
           from public.admin_user_permissions p
           where p.user_id = v_actor
             and coalesce(p.is_active, true) = true
         )
    into v_is_admin;

  if not v_is_admin then
    raise exception 'not authorized';
  end if;

  if to_regclass('public.order_item_status_history') is not null then
    delete from public.order_item_status_history
    where id is not null;
    get diagnostics v_deleted_history = row_count;
  end if;

  if to_regclass('public.order_items') is not null then
    delete from public.order_items
    where id is not null;
    get diagnostics v_deleted_items = row_count;
  end if;

  if to_regclass('public.orders') is not null then
    delete from public.orders
    where id is not null;
    get diagnostics v_deleted_orders = row_count;
  end if;

  if to_regclass('public.user_notifications') is not null then
    delete from public.user_notifications
    where id is not null;
    get diagnostics v_deleted_notifications = row_count;
  end if;

  return jsonb_build_object(
    'ok', true,
    'deleted_order_item_status_history', v_deleted_history,
    'deleted_order_items', v_deleted_items,
    'deleted_orders', v_deleted_orders,
    'deleted_notifications', v_deleted_notifications
  );
end;
$$;

revoke all on function public.admin_general_cleanup() from public;
grant execute on function public.admin_general_cleanup() to authenticated;

commit;
