-- REVIEW ONLY: do not apply to production without owner approval.
-- Extends existing memberships and branch registry; Auth remains Supabase Auth.
-- Re-run skips a policy or trigger that already matches. A same-named policy
-- with a different command or expression stops the script and is left in place.
begin;
create or replace function public._ibul_norm(p_text text)
returns text language sql immutable as $$
  select nullif(regexp_replace(regexp_replace(lower(coalesce(p_text,'')), 'public\.', '', 'g'), '[^a-z0-9_]+', '', 'g'), '');
$$;
create or replace function public._ibul_ensure_policy(
  p_table text, p_name text, p_ddl text, p_permissive text, p_cmd text, p_roles text, p_qual text, p_check text
) returns void language plpgsql as $$
declare existing record;
begin
  select permissive, cmd, roles::text as roles, qual, with_check into existing
  from pg_policies where schemaname='public' and tablename=p_table and policyname=p_name;
  if not found then
    execute p_ddl;
    return;
  end if;
  if existing.permissive is distinct from p_permissive
     or existing.cmd is distinct from p_cmd
     or existing.roles is distinct from p_roles
     or public._ibul_norm(existing.qual) is distinct from public._ibul_norm(p_qual)
     or public._ibul_norm(existing.with_check) is distinct from public._ibul_norm(p_check) then
    raise exception 'POLICY_DRIFT %.% mevcut haliyle korunuyor.', p_table, p_name using errcode='42710';
  end if;
end $$;
create or replace function public._ibul_ensure_trigger(p_table text, p_name text, p_ddl text)
returns void language plpgsql as $$
begin
  if exists(select 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname=p_table and t.tgname=p_name and not t.tgisinternal) then
    return;
  end if;
  execute p_ddl;
end $$;
alter table public.store_sub_admins
  add column if not exists auth_user_id uuid references auth.users(id),
  add column if not exists display_name text,
  add column if not exists staff_role text not null default 'sub_admin'
    check (staff_role in ('waiter','sub_admin')),
  add column if not exists branch_id uuid references public.store_branches(id),
  add column if not exists creation_request_id text;
create unique index if not exists store_staff_creation_request
  on public.store_sub_admins(store_id,creation_request_id)
  where creation_request_id is not null;
create unique index if not exists store_staff_auth_identity
  on public.store_sub_admins(store_id,auth_user_id) where auth_user_id is not null;
alter table public.store_tables add column if not exists branch_id uuid references public.store_branches(id);

-- Preserve legacy identity across later Auth contact changes, including revoked
-- memberships. Ambiguous matches stay unbound; duplicate bindings fail the unique
-- index and require an explicit offline reconciliation before rollout.
update public.store_sub_admins sa set auth_user_id=matched.id
from (select sa0.id membership_id,(array_agg(au.id))[1] id
  from public.store_sub_admins sa0 join auth.users au on
    (au.email_confirmed_at is not null and lower(trim(sa0.email))=lower(trim(au.email)))
    or (au.phone_confirmed_at is not null and sa0.phone=au.phone)
  where sa0.auth_user_id is null group by sa0.id having count(*)=1) matched
where sa.id=matched.membership_id and sa.auth_user_id is null;

-- Only verified Auth contacts may match legacy memberships. Never user_metadata,
-- public.users editable contact fields, invited status, or a nonexistent stores.id.
create or replace function public.restaurant_has_permission(p_restaurant_id uuid, p_permission text)
returns boolean language sql stable security definer set search_path = public
as $$
  select auth.uid() is not null and (
    exists(select 1 from public.stores where seller_id=p_restaurant_id and seller_id=auth.uid())
    or exists(
      select 1 from public.store_sub_admins sa join auth.users au on au.id=auth.uid()
      where sa.store_id=p_restaurant_id and sa.status='active'
        and (sa.branch_id is null or exists(select 1 from public.store_branches b
          where b.id=sa.branch_id and b.store_id=sa.store_id and b.status='active'))
        and (p_permission is null or p_permission=any(sa.permissions))
        and (sa.auth_user_id=au.id or (sa.auth_user_id is null and (
          (au.email_confirmed_at is not null and lower(trim(sa.email))=lower(trim(au.email)))
          or (au.phone_confirmed_at is not null and sa.phone=au.phone))))
    )
  );
$$;
create or replace function public.user_can_access_restaurant(p_restaurant_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select public.restaurant_has_permission(p_restaurant_id, 'manageOrders')
  or public.restaurant_has_permission(p_restaurant_id, 'viewOrders'); $$;

create or replace function public.restaurant_table_access(p_restaurant_id uuid,p_table_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select auth.uid()=p_restaurant_id or exists(
    select 1 from public.store_sub_admins sa join auth.users au on au.id=auth.uid()
    join public.store_tables t on t.id=p_table_id and t.seller_id=sa.store_id and t.is_active
    where sa.store_id=p_restaurant_id and sa.status='active'
      and (sa.branch_id is null or (t.branch_id=sa.branch_id and exists(
        select 1 from public.store_branches b where b.id=sa.branch_id
          and b.store_id=sa.store_id and b.status='active')))
      and (sa.auth_user_id=au.id or (sa.auth_user_id is null and (
        (au.email_confirmed_at is not null and lower(trim(sa.email))=lower(trim(au.email)))
        or (au.phone_confirmed_at is not null and sa.phone=au.phone))))
  );
$$;

-- Staff cannot activate, escalate or inspect other members. Owner keeps control.
drop policy if exists store_sub_admins_self_activate_update on public.store_sub_admins;
select public._ibul_ensure_policy('store_sub_admins','store_sub_admins_active_self_select',
  $ddl$create policy store_sub_admins_active_self_select on public.store_sub_admins for select to authenticated using (auth_user_id=auth.uid() or store_id=auth.uid())$ddl$,
  'PERMISSIVE','SELECT','{authenticated}','((auth_user_id = auth.uid()) OR (store_id = auth.uid()))',null);
select public._ibul_ensure_policy('store_sub_admins','staff_membership_insert_guard',
  $ddl$create policy staff_membership_insert_guard on public.store_sub_admins as restrictive for insert to authenticated with check(store_id=auth.uid())$ddl$,
  'RESTRICTIVE','INSERT','{authenticated}',null,'(store_id = auth.uid())');
select public._ibul_ensure_policy('store_sub_admins','staff_membership_update_guard',
  $ddl$create policy staff_membership_update_guard on public.store_sub_admins as restrictive for update to authenticated using(store_id=auth.uid()) with check(store_id=auth.uid())$ddl$,
  'RESTRICTIVE','UPDATE','{authenticated}','(store_id = auth.uid())','(store_id = auth.uid())');
select public._ibul_ensure_policy('store_sub_admins','staff_membership_delete_guard',
  $ddl$create policy staff_membership_delete_guard on public.store_sub_admins as restrictive for delete to authenticated using(store_id=auth.uid())$ddl$,
  'RESTRICTIVE','DELETE','{authenticated}','(store_id = auth.uid())',null);
create or replace function public.activate_my_sub_admin_invites()
returns integer language sql security definer set search_path=public as $$ select 0; $$;

create or replace function public.get_my_staff_access()
returns jsonb language sql stable security definer set search_path=public
as $$
  select case when count(*)=0 then null else jsonb_build_object(
    'store_id',(jsonb_agg(to_jsonb(sa.store_id) order by sa.created_at))->0,
    'branch_id',(jsonb_agg(to_jsonb(sa.branch_id) order by sa.created_at))->0,
    'staff_role',(jsonb_agg(to_jsonb(sa.staff_role) order by sa.created_at))->0,
    'permissions',(jsonb_agg(to_jsonb(sa.permissions) order by sa.created_at))->0,
    'memberships',jsonb_agg(jsonb_build_object(
      'store_id',sa.store_id,'branch_id',sa.branch_id,
      'staff_role',sa.staff_role,'permissions',sa.permissions
    ) order by sa.created_at)
  ) end
  from public.store_sub_admins sa
  join auth.users au on au.id=auth.uid()
  where sa.status='active'
    and (sa.branch_id is null or exists(select 1 from public.store_branches b
      where b.id=sa.branch_id and b.store_id=sa.store_id and b.status='active'))
    and (sa.auth_user_id=au.id or (sa.auth_user_id is null and (
      (au.email_confirmed_at is not null and lower(trim(sa.email))=lower(trim(au.email)))
      or (au.phone_confirmed_at is not null and sa.phone=au.phone))));
$$;

-- Validate branch ownership and Auth binding on every membership write,
-- including requests made by the server. Passwords never enter this table.
create or replace function public.validate_restaurant_staff_membership()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.branch_id is not null and not exists(select 1 from public.store_branches
    where id=new.branch_id and store_id=new.store_id) then
    raise exception 'Şube bu işletmeye ait değil.' using errcode='42501';
  end if;
  if not new.permissions <@ array['manageProducts','viewOrders','manageOrders','manageCampaigns','viewFinance','manageSupport','manageStoreProfile']::text[] then
    raise exception 'Geçersiz yetki.' using errcode='22023';
  end if;
  if new.auth_user_id is not null and not exists(select 1 from auth.users
    where id=new.auth_user_id and lower(email)=lower(new.email)) then
    raise exception 'Auth kimliği uyuşmuyor.' using errcode='42501';
  end if;
  return new;
end; $$;
select public._ibul_ensure_trigger('store_sub_admins','validate_restaurant_staff',
  $ddl$create trigger validate_restaurant_staff before insert or update on public.store_sub_admins for each row execute function public.validate_restaurant_staff_membership()$ddl$);

-- Replace the audited unconditional table-order policies only; preserve customer
-- QR inserts while limiting staff mutation and operational reads to their store.
drop policy if exists "Anyone can insert" on public.table_orders;
drop policy if exists "Seller can delete own" on public.table_orders;
drop policy if exists "Seller can read own" on public.table_orders;
drop policy if exists "Seller can update own" on public.table_orders;
drop policy if exists table_orders_authenticated_all on public.table_orders;
select public._ibul_ensure_policy('table_orders','table_orders_read_staff',
  $ddl$create policy table_orders_read_staff on public.table_orders for select to authenticated using (public.restaurant_has_permission(seller_id::uuid,'viewOrders') or public.restaurant_has_permission(seller_id::uuid,'manageOrders'))$ddl$,
  'PERMISSIVE','SELECT','{authenticated}',
  '(restaurant_has_permission((seller_id)::uuid, ''viewOrders''::text) OR restaurant_has_permission((seller_id)::uuid, ''manageOrders''::text))', null);
-- Existence check runs as the function owner. Anon does not need SELECT on stores.
create or replace function public.restaurant_customer_table_order_target(p_seller_id text)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.stores s where s.seller_id::text=nullif(trim(p_seller_id),''));
$$;
select public._ibul_ensure_policy('table_orders','table_orders_customer_insert',
  $ddl$create policy table_orders_customer_insert on public.table_orders for insert to anon,authenticated with check (public.restaurant_customer_table_order_target(seller_id))$ddl$,
  'PERMISSIVE','INSERT','{anon,authenticated}', null, 'restaurant_customer_table_order_target(seller_id)');
-- Historical "Anyone can insert" depended on this privilege. Keep it explicit.
grant insert on table public.table_orders to anon;
select public._ibul_ensure_policy('table_orders','table_orders_update_staff',
  $ddl$create policy table_orders_update_staff on public.table_orders for update to authenticated using (public.restaurant_has_permission(seller_id::uuid,'manageOrders')) with check (public.restaurant_has_permission(seller_id::uuid,'manageOrders'))$ddl$,
  'PERMISSIVE','UPDATE','{authenticated}',
  'restaurant_has_permission((seller_id)::uuid, ''manageOrders''::text)',
  'restaurant_has_permission((seller_id)::uuid, ''manageOrders''::text)');
select public._ibul_ensure_policy('table_orders','table_orders_delete_staff',
  $ddl$create policy table_orders_delete_staff on public.table_orders for delete to authenticated using (public.restaurant_has_permission(seller_id::uuid,'manageOrders'))$ddl$,
  'PERMISSIVE','DELETE','{authenticated}',
  'restaurant_has_permission((seller_id)::uuid, ''manageOrders''::text)', null);

create or replace function public.is_managed_restaurant_staff()
returns boolean language sql stable security definer set search_path=public as $$
  -- Historical name retained for callers. Identify ALL staff, even inactive
  -- legacy memberships; status is checked by authorization, never classification.
  select exists(select 1 from auth.users au where au.id=auth.uid() and (
    au.raw_app_meta_data->>'managed_restaurant_staff'='true'
    or exists(select 1 from public.store_sub_admins sa where sa.auth_user_id=au.id
      or (sa.auth_user_id is null and (
        (au.email_confirmed_at is not null and lower(trim(sa.email))=lower(trim(au.email)))
        or (au.phone_confirmed_at is not null and sa.phone=au.phone))))));
$$;
create or replace function public.restaurant_table_number_access(p_restaurant_id uuid,p_number integer)
returns boolean language sql stable security definer set search_path=public as $$
  select auth.uid()=p_restaurant_id or exists(select 1 from public.store_tables t
    where t.seller_id=p_restaurant_id and t.table_number=p_number
      and public.restaurant_table_access(p_restaurant_id,t.id));
$$;
select public._ibul_ensure_policy('table_orders','staff_table_orders_branch_guard',
  $ddl$create policy staff_table_orders_branch_guard on public.table_orders as restrictive for all to authenticated using (not public.is_managed_restaurant_staff() or public.restaurant_table_number_access(seller_id::uuid,table_number)) with check (not public.is_managed_restaurant_staff() or public.restaurant_table_number_access(seller_id::uuid,table_number))$ddl$,
  'RESTRICTIVE','ALL','{authenticated}',
  '((NOT is_managed_restaurant_staff()) OR restaurant_table_number_access((seller_id)::uuid, table_number))',
  '((NOT is_managed_restaurant_staff()) OR restaurant_table_number_access((seller_id)::uuid, table_number))');
select public._ibul_ensure_policy('table_order_history','staff_history_read_guard',
  $ddl$create policy staff_history_read_guard on public.table_order_history as restrictive for select to authenticated using (not public.is_managed_restaurant_staff() or ((public.restaurant_has_permission(seller_id::uuid,'viewOrders') or public.restaurant_has_permission(seller_id::uuid,'viewFinance') or public.restaurant_has_permission(seller_id::uuid,'manageOrders')) and public.restaurant_table_number_access(seller_id::uuid,table_number)))$ddl$,
  'RESTRICTIVE','SELECT','{authenticated}',
  '((NOT is_managed_restaurant_staff()) OR ((restaurant_has_permission(seller_id, ''viewOrders''::text) OR restaurant_has_permission(seller_id, ''viewFinance''::text) OR restaurant_has_permission(seller_id, ''manageOrders''::text)) AND restaurant_table_number_access(seller_id, table_number)))',
  null);

-- Existing permissive policies are ORed. Restrictive guards ensure a buyer's
-- own order/user_id shortcut cannot bypass revoked restaurant staff access.
create or replace function public.restaurant_order_access(p_order_id uuid,p_permission text)
returns boolean language sql stable security definer set search_path=public as $$
  -- A missing restaurant_id is a consumer order, never a staff restaurant grant.
  select exists(select 1 from public.orders o where o.id=p_order_id
    and o.restaurant_id is not null
    and public.restaurant_has_permission(o.restaurant_id,p_permission)
    and public.restaurant_table_access(o.restaurant_id,o.table_id));
$$;
select public._ibul_ensure_policy('orders','restaurant_staff_orders_read_guard',
  $ddl$create policy restaurant_staff_orders_read_guard on public.orders as restrictive for select to authenticated using (not public.is_managed_restaurant_staff() or (restaurant_id is null and user_id=auth.uid()) or public.restaurant_order_access(id,'viewOrders') or public.restaurant_order_access(id,'manageOrders'))$ddl$,
  'RESTRICTIVE','SELECT','{authenticated}',
  $q$(((NOT is_managed_restaurant_staff()) OR ((restaurant_id IS NULL) AND (user_id = auth.uid())) OR restaurant_order_access(id, 'viewOrders'::text) OR restaurant_order_access(id, 'manageOrders'::text))$q$, null);
select public._ibul_ensure_policy('orders','restaurant_staff_orders_write_guard',
  $ddl$create policy restaurant_staff_orders_write_guard on public.orders as restrictive for update to authenticated using (not public.is_managed_restaurant_staff() or public.restaurant_order_access(id,'manageOrders')) with check (not public.is_managed_restaurant_staff() or public.restaurant_order_access(id,'manageOrders'))$ddl$,
  'RESTRICTIVE','UPDATE','{authenticated}',
  $q$(((NOT is_managed_restaurant_staff()) OR restaurant_order_access(id, 'manageOrders'::text))$q$,
  $q$(((NOT is_managed_restaurant_staff()) OR restaurant_order_access(id, 'manageOrders'::text))$q$);
select public._ibul_ensure_policy('order_items','restaurant_staff_items_read_guard',
  $ddl$create policy restaurant_staff_items_read_guard on public.order_items as restrictive for select to authenticated using (not public.is_managed_restaurant_staff() or exists(select 1 from public.orders o where o.id=order_id and o.restaurant_id is null and o.user_id=auth.uid()) or public.restaurant_order_access(order_id,'viewOrders') or public.restaurant_order_access(order_id,'manageOrders'))$ddl$,
  'RESTRICTIVE','SELECT','{authenticated}',
  $q$(((NOT is_managed_restaurant_staff()) OR (EXISTS ( SELECT 1 FROM orders o WHERE ((o.id = order_items.order_id) AND (o.restaurant_id IS NULL) AND (o.user_id = auth.uid())))) OR restaurant_order_access(order_id, 'viewOrders'::text) OR restaurant_order_access(order_id, 'manageOrders'::text))$q$, null);
select public._ibul_ensure_policy('print_jobs','restaurant_staff_jobs_write_guard',
  $ddl$create policy restaurant_staff_jobs_write_guard on public.print_jobs as restrictive for all to authenticated using (not public.is_managed_restaurant_staff() or public.restaurant_order_access(order_id,'manageOrders')) with check (not public.is_managed_restaurant_staff() or public.restaurant_order_access(order_id,'manageOrders'))$ddl$,
  'RESTRICTIVE','ALL','{authenticated}',
  $q$(((NOT is_managed_restaurant_staff()) OR restaurant_order_access(order_id, 'manageOrders'::text))$q$,
  $q$(((NOT is_managed_restaurant_staff()) OR restaurant_order_access(order_id, 'manageOrders'::text))$q$);

-- Reject RPC writes too (SECURITY DEFINER bypasses RLS). The actor is derived
-- from Auth, never role/permissions supplied by the client.
create or replace function public.guard_restaurant_staff_order_write()
returns trigger language plpgsql security definer set search_path=public as $$
declare r uuid; t uuid; row_data jsonb;
begin
  if not public.is_managed_restaurant_staff() then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  if tg_op='DELETE' then row_data:=to_jsonb(old); else row_data:=to_jsonb(new); end if;
  if tg_table_name='orders' then
    r:=(row_data->>'restaurant_id')::uuid; t:=(row_data->>'table_id')::uuid;
  elsif tg_table_name in ('order_items','print_jobs') then
    select restaurant_id,table_id into r,t from public.orders where id=(row_data->>'order_id')::uuid;
  else
    r:=(row_data->>'seller_id')::uuid;
    select id into t from public.store_tables where seller_id=r and table_number=(row_data->>'table_number')::integer limit 1;
  end if;
  if tg_op='UPDATE' and (
    (to_jsonb(old)->>'restaurant_id') is distinct from (row_data->>'restaurant_id')
    or (to_jsonb(old)->>'seller_id') is distinct from (row_data->>'seller_id')
    or (to_jsonb(old)->>'order_id') is distinct from (row_data->>'order_id')
    or (to_jsonb(old)->>'table_id') is distinct from (row_data->>'table_id')
  ) then raise exception 'İşletme veya masa kimliği değiştirilemez.' using errcode='42501'; end if;
  if r is null or not public.restaurant_has_permission(r,'manageOrders')
    or not public.restaurant_table_access(r,t) then
    raise exception 'Personel sipariş yetkisi yok.' using errcode='42501';
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end; $$;
do $$ declare tbl text; begin
  foreach tbl in array array['orders','order_items','print_jobs','table_orders','table_order_history'] loop
    perform public._ibul_ensure_trigger(tbl,'restaurant_staff_write_guard',
      format('create trigger restaurant_staff_write_guard before insert or update or delete on public.%I for each row execute function public.guard_restaurant_staff_order_write()',tbl));
  end loop;
end $$;

-- Validate every job, including owner/service-role writes. Existing rows are
-- preserved; malformed historical rows must be reviewed before rollout.
create or replace function public.validate_restaurant_print_job()
returns trigger language plpgsql security definer set search_path=public as $$
declare parent_restaurant uuid; payload_key text;
begin
  if tg_op='UPDATE' and new.status='pending' and old.status in ('claimed','printing','completed') then
    raise exception 'Gönderilmiş veya belirsiz iş otomatik yeniden kuyruğa alınamaz.' using errcode='42501';
  end if;
  if tg_op='UPDATE' and new.status='pending' and old.status='failed' then
    if nullif(new.payload->>'manual_reprint_token','') is null
      or (new.payload->>'manual_reprint_token') is not distinct from (old.payload->>'manual_reprint_token')
      or not public.restaurant_has_permission(new.restaurant_id,'manageOrders') then
      raise exception 'Manuel yeniden baskı için yetkili operatör onayı gerekli.' using errcode='42501';
    end if;
  end if;
  if new.restaurant_id is null or not exists(select 1 from public.stores where seller_id=new.restaurant_id) then
    raise exception 'Baskı işletmesi geçersiz.' using errcode='42501';
  end if;
  if new.order_id is not null then
    select restaurant_id into parent_restaurant from public.orders where id=new.order_id;
    if parent_restaurant is distinct from new.restaurant_id then
      raise exception 'Baskı siparişi farklı işletmeye ait.' using errcode='42501';
    end if;
  elsif coalesce(new.job_type,'') not in ('receipt','test_receipt') then
    raise exception 'Baskı siparişi gerekli.' using errcode='42501';
  end if;
  if new.station_id is not null and not exists(select 1 from public.stations
    where id=new.station_id and restaurant_id=new.restaurant_id) then
    raise exception 'Baskı istasyonu farklı işletmeye ait.' using errcode='42501';
  end if;
  if new.printer_id is not null and not exists(select 1 from public.printers
    where id=new.printer_id and restaurant_id=new.restaurant_id) then
    raise exception 'Baskı yazıcısı farklı işletmeye ait.' using errcode='42501';
  end if;
  if new.station_id is not null and new.printer_id is not null and not exists(
    select 1 from public.station_printers where station_id=new.station_id and printer_id=new.printer_id) then
    raise exception 'Baskı istasyonu ve yazıcısı eşleşmiyor.' using errcode='42501';
  end if;
  foreach payload_key in array array['restaurant_id','order_id','station_id','printer_id'] loop
    if nullif(new.payload->>payload_key,'') is not null
      and (new.payload->>payload_key)::uuid is distinct from (to_jsonb(new)->>payload_key)::uuid then
      raise exception 'Baskı payload kimliği uyuşmuyor: %',payload_key using errcode='42501';
    end if;
  end loop;
  return new;
end; $$;
select public._ibul_ensure_trigger('print_jobs','restaurant_print_job_integrity',
  $ddl$create trigger restaurant_print_job_integrity before insert or update on public.print_jobs for each row execute function public.validate_restaurant_print_job()$ddl$);

-- Apply the existing permission names to each existing management surface.
-- Public product/store browsing remains available; staff mutations are guarded.
create or replace function public.guard_restaurant_staff_scoped_write()
returns trigger language plpgsql security definer set search_path=public as $$
declare d jsonb; r uuid;
begin
  if not public.is_managed_restaurant_staff() then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  if tg_op='DELETE' then d:=to_jsonb(old); else d:=to_jsonb(new); end if;
  r:=(d->>tg_argv[0])::uuid;
  if r=auth.uid() then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  if tg_argv[1]='viewFinance' or not public.restaurant_has_permission(r,tg_argv[1]) then
    raise exception 'Personel işlem yetkisi yok.' using errcode='42501';
  end if;
  if tg_op='UPDATE' and (to_jsonb(old)->>tg_argv[0]) is distinct from (d->>tg_argv[0]) then
    raise exception 'İşletme kimliği değiştirilemez.' using errcode='42501';
  end if;
  if tg_op='DELETE' then return old; else return new; end if;
end; $$;
do $$ declare c record; op text; predicate text; begin
  for c in select * from (values
    ('products','seller_id','manageProducts',false),
    ('stores','seller_id','manageStoreProfile',false),
    ('store_campaigns','seller_id','manageCampaigns',false),
    ('support_tickets','user_id','manageSupport',true),
    ('finance_suppliers','seller_id','viewFinance',true),
    ('finance_cash_accounts','seller_id','viewFinance',true),
    ('finance_cash_movements','seller_id','viewFinance',true),
    ('finance_income_records','seller_id','viewFinance',true),
    ('finance_expenses','seller_id','viewFinance',true),
    ('finance_debts','seller_id','viewFinance',true),
    ('finance_debt_payments','seller_id','viewFinance',true),
    ('finance_employees','seller_id','viewFinance',true),
    ('finance_salary_records','seller_id','viewFinance',true),
    ('finance_salary_payments','seller_id','viewFinance',true),
    ('finance_reconciliation_notes','seller_id','viewFinance',true),
    ('finance_company_settings','seller_id','viewFinance',true)
  ) v(tbl,col,perm,private_read) loop
    if to_regclass('public.'||c.tbl) is null then continue; end if;
    predicate:=format('public.restaurant_has_permission(%I::uuid,%L)',c.col,c.perm);
    perform public._ibul_ensure_policy(c.tbl,'staff_permission_read',
      format('create policy staff_permission_read on public.%I for select to authenticated using (%s)',c.tbl,predicate),
      'PERMISSIVE','SELECT','{authenticated}',
      format('restaurant_has_permission(%I, %L::text)',c.col,c.perm), null);
    if c.private_read then
      perform public._ibul_ensure_policy(c.tbl,'staff_permission_read_guard',
        format('create policy staff_permission_read_guard on public.%I as restrictive for select to authenticated using (not public.is_managed_restaurant_staff() or %s)',c.tbl,predicate),
        'RESTRICTIVE','SELECT','{authenticated}',
        format('((NOT is_managed_restaurant_staff()) OR restaurant_has_permission(%I, %L::text))',c.col,c.perm), null);
    end if;
    foreach op in array array['insert','update','delete'] loop
      if c.perm<>'viewFinance' then
        if op='insert' then
          perform public._ibul_ensure_policy(c.tbl,'staff_permission_insert',
            format('create policy staff_permission_insert on public.%I for insert to authenticated with check (%s)',c.tbl,predicate),
            'PERMISSIVE','INSERT','{authenticated}', null,
            format('restaurant_has_permission(%I, %L::text)',c.col,c.perm));
        elsif op='update' then
          perform public._ibul_ensure_policy(c.tbl,'staff_permission_update',
            format('create policy staff_permission_update on public.%I for update to authenticated using (%s) with check (%s)',c.tbl,predicate,predicate),
            'PERMISSIVE','UPDATE','{authenticated}',
            format('restaurant_has_permission(%I, %L::text)',c.col,c.perm),
            format('restaurant_has_permission(%I, %L::text)',c.col,c.perm));
        else
          perform public._ibul_ensure_policy(c.tbl,'staff_permission_delete',
            format('create policy staff_permission_delete on public.%I for delete to authenticated using (%s)',c.tbl,predicate),
            'PERMISSIVE','DELETE','{authenticated}',
            format('restaurant_has_permission(%I, %L::text)',c.col,c.perm), null);
        end if;
      end if;
    end loop;
    perform public._ibul_ensure_trigger(c.tbl,'staff_scoped_write_guard',
      format('create trigger staff_scoped_write_guard before insert or update or delete on public.%I for each row execute function public.guard_restaurant_staff_scoped_write(%L,%L)',c.tbl,c.col,c.perm));
  end loop;
end $$;

-- Existing SQL finance aggregates must obey the same table RLS as direct reads.
-- Their signatures were verified live; no calculation or response shape changes.
do $$ begin
  if to_regprocedure('public.finance_get_overview(uuid)') is not null then
    alter function public.finance_get_overview(uuid) security invoker;
  end if;
  if to_regprocedure('public.finance_get_monthly_trend(uuid,integer)') is not null then
    alter function public.finance_get_monthly_trend(uuid,integer) security invoker;
  end if;
end $$;

-- Keep each deployed close RPC body/signature intact, adding a permission and
-- branch gate before its legacy contact matching. Fail safely on definition drift.
do $$ declare f record; definition text; body_start integer; gate text; begin
  gate:=E'\n  IF NOT public.restaurant_has_permission(p_seller_id, ''manageOrders'') OR NOT public.restaurant_table_number_access(p_seller_id,p_table_number) THEN\n    RAISE EXCEPTION ''Sipariş yönetme yetkisi yok.'' USING ERRCODE=''42501'';\n  END IF;\n';
  for f in select oid from pg_proc where pronamespace='public'::regnamespace and proname='close_table_with_history' loop
    definition:=pg_get_functiondef(f.oid);
    body_start:=strpos(definition,'BEGIN');
    if body_start=0 or strpos(definition,'p_seller_id')=0 or strpos(definition,'p_table_number')=0 then
      raise exception 'close_table_with_history tanımı değişmiş; migration tekrar incelenmeli.';
    end if;
    if strpos(definition,'restaurant_has_permission(p_seller_id')>0 then
      continue;
    end if;
    definition:=overlay(definition placing ('BEGIN'||gate) from body_start for 5);
    execute definition;
  end loop;
end $$;

-- Expose only authenticated checks. Trigger functions are not API operations.
revoke all on function public.restaurant_has_permission(uuid,text), public.restaurant_table_access(uuid,uuid),
  public.restaurant_order_access(uuid,text),public.restaurant_table_number_access(uuid,integer),public.get_my_staff_access(),public.is_managed_restaurant_staff(),
  public.restaurant_customer_table_order_target(text) from public,anon;
grant execute on function public.restaurant_has_permission(uuid,text), public.restaurant_table_access(uuid,uuid),
  public.restaurant_order_access(uuid,text),public.restaurant_table_number_access(uuid,integer),public.get_my_staff_access(),public.is_managed_restaurant_staff() to authenticated;
grant execute on function public.restaurant_customer_table_order_target(text) to anon,authenticated;
-- Reuse the current realtime publication for job pickup and settings changes.
do $$ declare tbl text; begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    foreach tbl in array array['print_jobs','printers'] loop
      if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime'
        and schemaname='public' and tablename=tbl) then
        execute format('alter publication supabase_realtime add table public.%I',tbl);
      end if;
    end loop;
  end if;
end $$;
drop function public._ibul_ensure_policy(text,text,text,text,text,text,text,text);
drop function public._ibul_ensure_trigger(text,text,text);
drop function public._ibul_norm(text);
notify pgrst,'reload schema';
commit;
