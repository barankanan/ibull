-- DO NOT APPLY to the live project from this workspace.
-- Live function bodies were not read. This file does not install a replacement
-- body for close_table_with_history or transfer_table_orders.
-- It stores the current definition, then replaces only the recognized
-- authorization gate. An unrecognized body aborts the transaction.
-- Existing membership rows are not updated. New permission names stay closed
-- until an owner selects them.

begin;

create table if not exists public.restaurant_staff_operation_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null,
  seller_id uuid not null,
  table_number integer,
  operation text not null,
  summary jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.restaurant_staff_operation_log enable row level security;

drop policy if exists restaurant_staff_operation_log_read on public.restaurant_staff_operation_log;
create policy restaurant_staff_operation_log_read
  on public.restaurant_staff_operation_log
  for select to authenticated
  using (seller_id = auth.uid() or actor_id = auth.uid());

revoke insert, update, delete on public.restaurant_staff_operation_log from public, anon, authenticated;

create table if not exists public.ibul_function_patch_backup (
  patch_name text not null,
  signature text not null,
  definition text not null,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (patch_name, signature)
);

revoke all on public.ibul_function_patch_backup from public, anon, authenticated;

create or replace function public.restaurant_staff_may_operate(
  p_restaurant_id uuid,
  p_permission text,
  p_table_number integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_must_change boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;
  if to_regprocedure('public.staff_must_change_password()') is not null then
    execute 'select public.staff_must_change_password()' into v_must_change;
    if coalesce(v_must_change, false) then
      raise exception 'Önce geçici şifre değiştirilmeli.' using errcode = '42501';
    end if;
  end if;
  if not public.restaurant_has_permission(p_restaurant_id, p_permission) then
    raise exception 'Bu işlem için yetkiniz yok.' using errcode = '42501';
  end if;
  if p_table_number is not null
     and not public.restaurant_table_number_access(p_restaurant_id, p_table_number) then
    raise exception 'Bu masada işlem yetkiniz yok.' using errcode = '42501';
  end if;
end;
$$;

revoke all on function public.restaurant_staff_may_operate(uuid, text, integer) from public, anon;
grant execute on function public.restaurant_staff_may_operate(uuid, text, integer) to authenticated;

create or replace function public._ibul_patch_named_function(
  p_name text,
  p_calls text
)
returns void
language plpgsql
as $$
declare
  rec record;
  original text;
  patched text;
  seen boolean := false;
begin
  for rec in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = p_name
  loop
    seen := true;
    original := pg_get_functiondef(rec.signature);
    if position('restaurant_staff_may_operate' in original) > 0 then
      continue;
    end if;
    patched := original;
    patched := regexp_replace(
      patched,
      'IF NOT public\.restaurant_has_permission\(p_seller_id, ''manageOrders''\) OR NOT public\.restaurant_table_number_access\(p_seller_id,p_table_number\) THEN[[:space:]]*RAISE EXCEPTION ''Sipariş yönetme yetkisi yok\.'' USING ERRCODE=''42501'';[[:space:]]*END IF;',
      '',
      'in'
    );
    patched := regexp_replace(
      patched,
      'if[[:space:]]+p_seller_id[[:space:]]*<>[[:space:]]*auth\.uid\(\)[[:space:]]+then[[:space:]]+raise[[:space:]]+exception[[:space:]]+[^;]*;[[:space:]]*end[[:space:]]+if;',
      p_calls,
      'in'
    );
    patched := regexp_replace(
      patched,
      'IF[[:space:]]+auth\.uid\(\)[[:space:]]+IS[[:space:]]+NULL[[:space:]]+OR[[:space:]]+NOT[[:space:]]+v_actor_authorized[[:space:]]+THEN[[:space:]]+RAISE[[:space:]]+EXCEPTION[[:space:]]+''Yetkisiz işlem\.''[[:space:]]+USING[[:space:]]+ERRCODE[[:space:]]*=[[:space:]]*''42501'';[[:space:]]*END[[:space:]]+IF;',
      p_calls,
      'in'
    );
    if position('restaurant_staff_may_operate' in patched) = 0
       or patched = original then
      raise exception '% yetki kapısı tanınmadı; fonksiyon gövdesi yazılmadı.', rec.signature;
    end if;
    insert into public.ibul_function_patch_backup (patch_name, signature, definition)
    values ('2026110117', rec.signature::text, original)
    on conflict (patch_name, signature) do nothing;
    execute patched;
  end loop;
  if not seen then
    raise exception '% kurulu değil; yeni gövde oluşturulmadı.', p_name;
  end if;
end;
$$;

select public._ibul_patch_named_function(
  'close_table_with_history',
  E'  perform public.restaurant_staff_may_operate(p_seller_id, ''closeBill'', p_table_number);\n'
);
select public._ibul_patch_named_function(
  'transfer_table_orders',
  E'  perform public.restaurant_staff_may_operate(p_seller_id, ''transferTable'', p_from_table);\n  perform public.restaurant_staff_may_operate(p_seller_id, ''transferTable'', p_to_table);\n'
);

do $$
declare
  original text;
  patched text;
  fn_signature text;
begin
  select p.oid::regprocedure::text, pg_get_functiondef(p.oid)
  into fn_signature, original
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'validate_restaurant_staff_membership'
  limit 1;
  if fn_signature is null then
    raise exception 'validate_restaurant_staff_membership kurulu değil; yeni doğrulayıcı yazılmadı.';
  end if;
  if position('transferTable' in original) > 0 then
    return;
  end if;
  if position(
    '[''manageProducts'',''viewOrders'',''manageOrders'',''manageCampaigns'',''viewFinance'',''manageSupport'',''manageStoreProfile'']'
    in replace(original, ' ', '')
  ) = 0 then
    raise exception 'Personel izin listesi tanınmadı; doğrulayıcı yazılmadı.';
  end if;
  patched := replace(
    original,
    '''manageStoreProfile''',
    '''manageStoreProfile'',''transferTable'',''splitBill'',''takePartialPayment'',''closeBill'',''managePrintSettings'''
  );
  if patched = original then
    raise exception 'Personel izin listesi genişletilemedi.';
  end if;
  insert into public.ibul_function_patch_backup (patch_name, signature, definition)
  values ('2026110117', fn_signature, original)
  on conflict (patch_name, signature) do nothing;
  execute patched;
end $$;

drop function public._ibul_patch_named_function(text, text);

alter table public.table_payments
  add column if not exists client_request_id text;

create unique index if not exists table_payments_client_request_uidx
  on public.table_payments (seller_id, client_request_id)
  where client_request_id is not null;

create or replace function public.guard_table_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_owner boolean;
  v_order_total numeric(12,2) := 0;
  v_paid numeric(12,2) := 0;
  v_remaining numeric(12,2);
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;
  v_is_owner := exists (
    select 1 from public.stores s
    where s.seller_id = auth.uid()
      and s.seller_id = new.seller_id
  );
  if not v_is_owner then
    perform public.restaurant_staff_may_operate(
      new.seller_id, 'takePartialPayment', new.table_number
    );
    if new.client_request_id is null or btrim(new.client_request_id) = '' then
      raise exception 'Ödeme isteği kimliği zorunlu.' using errcode = '22023';
    end if;
    if new.waiter_id is not null and new.waiter_id is distinct from auth.uid() then
      raise exception 'Garson kimliği geçersiz.' using errcode = '42501';
    end if;
  end if;
  if new.amount is null or new.amount <= 0 then
    raise exception 'Ödeme tutarı geçersiz.' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(
    hashtextextended(
      new.seller_id::text || ':' || new.table_number::text || ':' || coalesce(new.session_key, ''),
      0
    )
  );
  if new.client_request_id is not null and exists (
    select 1 from public.table_payments
    where seller_id = new.seller_id
      and client_request_id = new.client_request_id
  ) then
    raise exception 'IBUL_PAYMENT_REPLAY' using errcode = 'P0002';
  end if;
  perform 1
  from public.table_orders
  where seller_id = new.seller_id::text
    and table_number = new.table_number
  for update;
  select coalesce(sum(
    coalesce(
      nullif(item ->> 'line_total', '')::numeric,
      coalesce(nullif(item ->> 'price', '')::numeric, 0)
      * coalesce(nullif(item ->> 'quantity', '')::numeric, 1)
    )
  ), 0)
  into v_order_total
  from public.table_orders o
  cross join lateral jsonb_array_elements(coalesce(o.items, '[]'::jsonb)) item
  where o.seller_id = new.seller_id::text
    and o.table_number = new.table_number;
  select coalesce(sum(amount), 0)
  into v_paid
  from public.table_payments
  where seller_id = new.seller_id
    and table_number = new.table_number
    and session_key = new.session_key;
  v_remaining := v_order_total - v_paid;
  if not v_is_owner or v_order_total > 0 then
    if new.amount > v_remaining + 0.009 then
      raise exception 'Ödeme kalan bakiyeyi aşıyor.' using errcode = '22023';
    end if;
  end if;
  insert into public.restaurant_staff_operation_log (
    actor_id, seller_id, table_number, operation, summary
  ) values (
    auth.uid(), new.seller_id, new.table_number, 'takePartialPayment',
    jsonb_build_object(
      'amount', new.amount,
      'remaining_after', v_remaining - new.amount
    )
  );
  return new;
end;
$$;

drop trigger if exists guard_table_payment on public.table_payments;
create trigger guard_table_payment
  before insert on public.table_payments
  for each row execute function public.guard_table_payment();

drop policy if exists table_payments_staff_insert on public.table_payments;
create policy table_payments_staff_insert
  on public.table_payments
  for insert to authenticated
  with check (
    public.restaurant_has_permission(seller_id, 'takePartialPayment')
    and public.restaurant_table_number_access(seller_id, table_number)
  );

drop policy if exists table_payments_staff_select on public.table_payments;
create policy table_payments_staff_select
  on public.table_payments
  for select to authenticated
  using (
    public.restaurant_has_permission(seller_id, 'takePartialPayment')
    and public.restaurant_table_number_access(seller_id, table_number)
  );

create or replace function public.record_table_payment(
  p_seller_id uuid,
  p_table_number integer,
  p_session_key text,
  p_amount numeric,
  p_method text,
  p_is_closing boolean default false,
  p_client_request_id text default null,
  p_paid_by text default null,
  p_waiter_id uuid default null,
  p_waiter_name text default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.table_payments;
  v_owner boolean;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz istek.' using errcode = '42501';
  end if;
  if p_seller_id is null or p_table_number is null or p_table_number <= 0 then
    raise exception 'Geçersiz masa.' using errcode = '22023';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Ödeme tutarı geçersiz.' using errcode = '22023';
  end if;
  v_owner := exists (
    select 1 from public.stores s
    where s.seller_id = auth.uid()
      and s.seller_id = p_seller_id
  );
  if not v_owner then
    perform public.restaurant_staff_may_operate(
      p_seller_id, 'takePartialPayment', p_table_number
    );
  end if;
  if p_client_request_id is not null and btrim(p_client_request_id) <> '' then
    select * into v_row
    from public.table_payments
    where seller_id = p_seller_id
      and client_request_id = btrim(p_client_request_id);
    if found then
      return to_jsonb(v_row) || jsonb_build_object('idempotent_replay', true);
    end if;
  end if;
  insert into public.table_payments (
    seller_id, table_number, session_key, amount, method, is_closing,
    client_request_id, paid_by, waiter_id, waiter_name, note
  ) values (
    p_seller_id, p_table_number, p_session_key, p_amount, p_method, p_is_closing,
    nullif(btrim(p_client_request_id), ''), p_paid_by, p_waiter_id, p_waiter_name, p_note
  )
  returning * into v_row;
  return to_jsonb(v_row) || jsonb_build_object('idempotent_replay', false);
exception
  when unique_violation or sqlstate 'P0002' then
    select * into v_row
    from public.table_payments
    where seller_id = p_seller_id
      and client_request_id = btrim(p_client_request_id);
    if not found then
      raise;
    end if;
    return to_jsonb(v_row) || jsonb_build_object('idempotent_replay', true);
end;
$$;

revoke all on function public.record_table_payment(
  uuid, integer, text, numeric, text, boolean, text, text, uuid, text, text
) from public, anon;
grant execute on function public.record_table_payment(
  uuid, integer, text, numeric, text, boolean, text, text, uuid, text, text
) to authenticated;

commit;
