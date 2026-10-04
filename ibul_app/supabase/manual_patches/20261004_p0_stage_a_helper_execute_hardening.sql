-- Stage A live delta. Revoke direct EXECUTE on internal helpers only.
-- Signatures were read from pg_proc on ihmixxzqnpamcwmrfibx.
-- Does not change policies, columns, Stage B triggers, or marketplace RPC grants.
-- SECURITY DEFINER owners keep EXECUTE and continue to call these helpers.

revoke execute on function public.marketplace_haversine_km(p_lat1 double precision, p_lng1 double precision, p_lat2 double precision, p_lng2 double precision) from public;
revoke execute on function public.marketplace_haversine_km(p_lat1 double precision, p_lng1 double precision, p_lat2 double precision, p_lng2 double precision) from anon;
revoke execute on function public.marketplace_haversine_km(p_lat1 double precision, p_lng1 double precision, p_lat2 double precision, p_lng2 double precision) from authenticated;

revoke execute on function public.marketplace_parse_station_id(p_value text) from public;
revoke execute on function public.marketplace_parse_station_id(p_value text) from anon;
revoke execute on function public.marketplace_parse_station_id(p_value text) from authenticated;

revoke execute on function public.marketplace_payload_forbidden_key(p_value jsonb) from public;
revoke execute on function public.marketplace_payload_forbidden_key(p_value jsonb) from anon;
revoke execute on function public.marketplace_payload_forbidden_key(p_value jsonb) from authenticated;

revoke execute on function public.marketplace_server_shipping_fee(p_seller_id uuid, p_address jsonb) from public;
revoke execute on function public.marketplace_server_shipping_fee(p_seller_id uuid, p_address jsonb) from anon;
revoke execute on function public.marketplace_server_shipping_fee(p_seller_id uuid, p_address jsonb) from authenticated;
