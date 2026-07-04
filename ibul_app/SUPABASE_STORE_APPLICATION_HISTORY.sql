-- Mağaza başvuru geçmişi: admin onay/red/eksik belge aksiyonları.
-- Idempotent: güvenle tekrar çalıştırılabilir.

create extension if not exists pgcrypto;

create or replace function public.is_admin_user(target_user_id uuid default auth.uid())
returns boolean
language plpgsql
stable
as $$
declare
  role_key text;
begin
  if target_user_id is null then
    return false;
  end if;

  if to_regclass('public.users') is null then
    return false;
  end if;

  execute 'select role from public.users where id = $1 limit 1'
    into role_key
    using target_user_id;

  return role_key = 'admin'
    or role_key = 'super_admin'
    or coalesce(role_key, '') like 'admin_%';
end;
$$;

-- seller_applications: admin red/eksik belge notu (canlı DB'de eksik olabilir).
alter table public.seller_applications
  add column if not exists rejection_reason text;

alter table public.seller_applications
  add column if not exists approved_at timestamptz;

create table if not exists public.store_application_history (
  id uuid primary key default gen_random_uuid(),
  store_id uuid,
  seller_id uuid,
  application_id uuid,
  store_name text,
  action text not null,
  reason text,
  admin_note text,
  previous_status text,
  new_status text,
  acted_by uuid,
  acted_at timestamptz not null default timezone('utc', now()),
  application_created_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  constraint store_application_history_action_check check (
    action in ('approved', 'rejected', 'changes_requested', 'resubmitted')
  )
);

create index if not exists store_application_history_seller_id_idx
  on public.store_application_history (seller_id, acted_at desc);

create index if not exists store_application_history_application_id_idx
  on public.store_application_history (application_id, acted_at desc);

create index if not exists store_application_history_action_idx
  on public.store_application_history (action, acted_at desc);

alter table public.store_application_history enable row level security;

drop policy if exists store_application_history_admin_all
  on public.store_application_history;
create policy store_application_history_admin_all
  on public.store_application_history
  for all
  to authenticated
  using (public.is_admin_user())
  with check (public.is_admin_user());

drop policy if exists store_application_history_seller_read
  on public.store_application_history;
create policy store_application_history_seller_read
  on public.store_application_history
  for select
  to authenticated
  using (seller_id = auth.uid());

-- Admin mağaza başvurusu yönetimi (mevcut panel akışı).
drop policy if exists seller_applications_admin_select
  on public.seller_applications;
create policy seller_applications_admin_select
  on public.seller_applications
  for select
  to authenticated
  using (public.is_admin_user());

drop policy if exists seller_applications_admin_update
  on public.seller_applications;
create policy seller_applications_admin_update
  on public.seller_applications
  for update
  to authenticated
  using (public.is_admin_user())
  with check (public.is_admin_user());

drop policy if exists seller_applications_admin_delete
  on public.seller_applications;
create policy seller_applications_admin_delete
  on public.seller_applications
  for delete
  to authenticated
  using (public.is_admin_user());

-- Güvenli backfill: mevcut seller_applications kayıtlarından geçmiş türet.
insert into public.store_application_history (
  store_id,
  seller_id,
  application_id,
  store_name,
  action,
  reason,
  admin_note,
  previous_status,
  new_status,
  acted_by,
  acted_at,
  application_created_at,
  metadata
)
select
  sa.user_id as store_id,
  sa.user_id as seller_id,
  sa.id as application_id,
  sa.business_name as store_name,
  case
    when sa.status = 'approved' then 'approved'
    when sa.status = 'missing_documents' then 'changes_requested'
    when sa.status = 'rejected' then 'rejected'
    else 'changes_requested'
  end as action,
  sa.rejection_reason as reason,
  null as admin_note,
  'pending' as previous_status,
  sa.status as new_status,
  null as acted_by,
  coalesce(sa.approved_at, sa.created_at, timezone('utc', now())) as acted_at,
  sa.created_at as application_created_at,
  jsonb_build_object('backfill', true) as metadata
from public.seller_applications sa
where sa.status in ('approved', 'missing_documents', 'rejected')
  and not exists (
    select 1
    from public.store_application_history h
    where h.application_id = sa.id
      and h.action = case
        when sa.status = 'approved' then 'approved'
        when sa.status = 'missing_documents' then 'changes_requested'
        when sa.status = 'rejected' then 'rejected'
        else 'changes_requested'
      end
  );
