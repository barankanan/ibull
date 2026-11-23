-- DRAFT — geri alma: 2026-11-23'te üretimden salt-okunur okunan sarmalayıcı gövdesi (birebir).
-- Bu dosya yazılmış toplamları geri SIFIRLAMAZ; yalnız fonksiyonu eski hâline döndürür.
begin;
create or replace function public.create_table_order_with_print_jobs(
  p_restaurant_id uuid,
  p_table_number integer,
  p_items jsonb,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_notes text default null,
  p_job_type text default 'new_order',
  p_order_type text default 'table',
  p_local_order_id text default null,
  p_local_print_evidence text default null,
  p_verified_actor uuid default null,
  p_evidence_branch uuid default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  return public.create_table_order_with_print_jobs_impl(
    p_restaurant_id, p_table_number, p_items, p_waiter_id, p_waiter_name,
    p_notes, p_job_type, p_order_type, p_local_order_id, p_local_print_evidence,
    p_verified_actor, p_evidence_branch
  );
end;
$function$;
commit;
