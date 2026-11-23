-- DRAFT — DO NOT APPLY without explicit operator approval naming this file.
-- Kök neden (üretimde salt-okunur doğrulandı, 2026-11-23): create_table_order_with_print_jobs_impl
-- sipariş başlığını subtotal_amount = 0 / total_amount = 0 sabitleriyle yazıyor ve order_items'a
-- total_price / line_total HİÇ yazmıyor (yalnız unit_price). Sonuç: garson siparişlerinde başlık
-- toplamı 0,00; kapanışta table_order_history.grand_total 0,00 ("(kalemlerden)" görünümü).
-- Düzeltme (en dar): 19 bin karakterlik _impl gövdesine DOKUNULMAZ. Yalnız 13 satırlık sarmalayıcı
-- (wrapper) değişir: _impl döndükten sonra, AYNI işlem içinde, YENİ oluşturulan siparişin kalem
-- ve başlık toplamları unit_price * quantity'den yazılır. Fiyat kaynağı değişmez (_impl'in
-- doğruladığı ve yazdığı unit_price). Tekrar (idempotent_replay) çağrısında HİÇBİR ŞEY yazılmaz:
-- eski/kapanmış siparişlerin tutarı geriye dönük değişmez.
-- Yetki: sarmalayıcı zaten SECURITY DEFINER; _impl yetki/masa/istasyon/ürün kapılarını geçmeden
-- buraya gelinmez (hata fırlatır). Para kilidi tetikleyicileri _impl'in açtığı işlem-yerel
-- ibul.marketplace_order_rpc bayrağıyla geçilir; bayrak burada da işlem-yerel açılır.
-- ETKİ UYARISI (uygulamadan önce karar verilmeli): bugüne kadar 0 olan masa siparişi başlık
-- toplamları bundan sonra gerçek tutarı taşır. orders.total_amount'u toplayan finans/gelir
-- sorguları (masa tahsilatı table_payments ile ayrıca sayılıyorsa) çift sayım açısından
-- ÖNCE salt-okunur denetlenmelidir. Geçmiş kayıtlar bu dosyayla DÜZELTİLMEZ.
-- Geri alma: 20261124_table_order_totals_ROLLBACK_DRAFT.sql (bugünkü üretim sarmalayıcısı).
begin;
do $$
begin
  if to_regprocedure('public.create_table_order_with_print_jobs_impl(uuid,integer,jsonb,uuid,text,text,text,text,text,text,uuid,uuid)') is null then
    raise exception 'on iki argümanlı _impl yok; bu taslak bu şemaya göre değil';
  end if;
end $$;

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
declare
  v_result jsonb;
  v_order_id uuid;
  v_total numeric;
begin
  v_result := public.create_table_order_with_print_jobs_impl(
    p_restaurant_id, p_table_number, p_items, p_waiter_id, p_waiter_name,
    p_notes, p_job_type, p_order_type, p_local_order_id, p_local_print_evidence,
    p_verified_actor, p_evidence_branch
  );

  -- Yalnız bu çağrının YENİ oluşturduğu sipariş. Tekrar yanıtı: dokunma.
  if jsonb_typeof(v_result) is distinct from 'object'
     or coalesce(v_result ->> 'idempotent_replay', 'false') = 'true' then
    return v_result;
  end if;
  begin
    v_order_id := nullif(v_result ->> 'order_id', '')::uuid;
  exception when others then
    v_order_id := null;
  end;
  if v_order_id is null then
    return v_result;
  end if;

  perform set_config('ibul.marketplace_order_rpc', 'on', true);

  update public.order_items oi
     set total_price = round(oi.unit_price * oi.quantity, 2),
         line_total  = round(oi.unit_price * oi.quantity, 2)
   where oi.order_id = v_order_id
     and coalesce(oi.total_price, 0) = 0
     and oi.line_total is null;

  select coalesce(sum(round(oi.unit_price * oi.quantity, 2)), 0)
    into v_total
    from public.order_items oi
   where oi.order_id = v_order_id;

  update public.orders o
     set subtotal_amount = v_total,
         total_amount    = v_total
   where o.id = v_order_id
     and o.restaurant_id = p_restaurant_id
     and coalesce(o.subtotal_amount, 0) = 0
     and coalesce(o.total_amount, 0) = 0
     and v_total > 0;

  return v_result;
end;
$function$;
commit;
