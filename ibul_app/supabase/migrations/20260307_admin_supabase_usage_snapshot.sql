create or replace function public.admin_get_supabase_usage_snapshot()
returns jsonb
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_has_access boolean := false;

  v_database_limit_mb numeric := 500;
  v_storage_limit_mb numeric := 1024;
  v_mau_limit integer := 50000;
  v_egress_limit_gb numeric := 5;
  v_realtime_messages_limit_month integer := 2000000;
  v_realtime_concurrent_limit integer := 200;
  v_edge_invocations_limit_month integer := 500000;
  v_users_recommended_limit integer := 5000;
  v_stores_recommended_limit integer := 1200;
  v_sellers_recommended_limit integer := 1200;
  v_couriers_recommended_limit integer := 500;

  v_database_used_bytes bigint := 0;
  v_storage_used_bytes bigint := 0;
  v_total_users integer := 0;
  v_mau_used_30d integer := 0;
  v_seller_count integer := 0;
  v_approved_courier_count integer := 0;
  v_total_orders integer := 0;
  v_today_orders integer := 0;
  v_notifications_today integer := 0;

  v_egress_used_gb_estimate numeric := 0;
  v_realtime_messages_used_month_estimate integer := 0;
  v_edge_invocations_used_month_estimate integer := 0;
begin
  begin
    select (
      coalesce(public.current_admin_has_module('analytics'), false)
      or coalesce(public.current_user_role(), '') = 'super_admin'
    )
    into v_has_access;
  exception
    when others then
      select coalesce(
        lower(coalesce(u.role, '')) in ('admin', 'super_admin')
        or lower(coalesce(u.role, '')) like 'admin\\_%',
        false
      )
      into v_has_access
      from public.users u
      where u.id = auth.uid()
      limit 1;
  end;

  if not coalesce(v_has_access, false) then
    raise exception 'analytics module access is required'
      using errcode = '42501';
  end if;

  begin
    v_database_used_bytes := pg_database_size(current_database());
  exception
    when others then
      v_database_used_bytes := 0;
  end;

  begin
    select coalesce(
      sum(
        case
          when coalesce(o.metadata ->> 'size', '') ~ '^[0-9]+$'
            then (o.metadata ->> 'size')::bigint
          else 0
        end
      ),
      0
    )
    into v_storage_used_bytes
    from storage.objects o;
  exception
    when others then
      v_storage_used_bytes := 0;
  end;

  begin
    select
      coalesce(count(*), 0),
      coalesce(
        count(*) filter (
          where u.updated_at >= v_now - interval '30 days'
        ),
        0
      ),
      coalesce(
        count(*) filter (
          where lower(coalesce(u.role, '')) = 'seller'
        ),
        0
      )
    into v_total_users, v_mau_used_30d, v_seller_count
    from public.users u;
  exception
    when others then
      v_total_users := 0;
      v_mau_used_30d := 0;
      v_seller_count := 0;
  end;

  begin
    select coalesce(count(*), 0)
    into v_approved_courier_count
    from public.ihiz_courier_applications
    where status = 'approved';
  exception
    when undefined_table then
      v_approved_courier_count := 0;
    when others then
      v_approved_courier_count := 0;
  end;

  begin
    select
      coalesce(count(*), 0),
      coalesce(
        count(*) filter (
          where o.created_at >= date_trunc('day', v_now)
        ),
        0
      )
    into v_total_orders, v_today_orders
    from public.orders o;
  exception
    when others then
      v_total_orders := 0;
      v_today_orders := 0;
  end;

  begin
    select coalesce(count(*), 0)
    into v_notifications_today
    from public.user_notifications n
    where n.created_at >= date_trunc('day', v_now);
  exception
    when undefined_table then
      v_notifications_today := 0;
    when others then
      v_notifications_today := 0;
  end;

  -- Egress, realtime and edge usage are estimated from live operational load.
  v_egress_used_gb_estimate := round(
    (
      (v_mau_used_30d::numeric * 0.045)
      + ((v_storage_used_bytes::numeric / 1024 / 1024) * 0.002)
    )::numeric,
    3
  );

  v_realtime_messages_used_month_estimate := greatest(
    0,
    ((v_today_orders * 8) + (v_notifications_today * 3)) * 30
  );

  v_edge_invocations_used_month_estimate := greatest(
    0,
    ((v_today_orders * 4) + (v_notifications_today * 2)) * 30
  );

  return jsonb_build_object(
    'plan_name', 'free',
    'fetched_at', v_now,
    'database_used_mb', round((v_database_used_bytes::numeric / 1024 / 1024)::numeric, 3),
    'database_limit_mb', v_database_limit_mb,
    'storage_used_mb', round((v_storage_used_bytes::numeric / 1024 / 1024)::numeric, 3),
    'storage_limit_mb', v_storage_limit_mb,
    'mau_used_30d', v_mau_used_30d,
    'mau_limit', v_mau_limit,
    'egress_used_gb_estimate', v_egress_used_gb_estimate,
    'egress_limit_gb', v_egress_limit_gb,
    'realtime_messages_used_month_estimate', v_realtime_messages_used_month_estimate,
    'realtime_messages_limit_month', v_realtime_messages_limit_month,
    'realtime_concurrent_limit', v_realtime_concurrent_limit,
    'edge_invocations_used_month_estimate', v_edge_invocations_used_month_estimate,
    'edge_invocations_limit_month', v_edge_invocations_limit_month,
    'total_users', v_total_users,
    'seller_count', v_seller_count,
    'approved_courier_count', v_approved_courier_count,
    'users_recommended_limit', v_users_recommended_limit,
    'stores_recommended_limit', v_stores_recommended_limit,
    'sellers_recommended_limit', v_sellers_recommended_limit,
    'couriers_recommended_limit', v_couriers_recommended_limit,
    'total_orders', v_total_orders,
    'today_orders', v_today_orders,
    'notifications_today', v_notifications_today,
    'traffic_is_estimated', true
  );
end;
$$;

revoke all on function public.admin_get_supabase_usage_snapshot() from public;
grant execute on function public.admin_get_supabase_usage_snapshot() to authenticated;
