-- Additive AVM company fields, private document rows, and member invites.
-- Not a CLI migration. Do not db push.
-- Does not replace approve/reject RPCs. Does not change users.role.

begin;

alter table public.mall_applications
  add column if not exists tax_number text,
  add column if not exists tax_office text,
  add column if not exists mersis_no text,
  add column if not exists trade_registry_no text,
  add column if not exists kep_address text,
  add column if not exists authorized_person_phone text,
  add column if not exists authorized_person_email text;

alter table public.mall_applications drop constraint if exists mall_applications_tax_number_chk;
alter table public.mall_applications
  add constraint mall_applications_tax_number_chk check (
    tax_number is null or tax_number ~ '^[0-9]{10,11}$'
  );

alter table public.mall_applications drop constraint if exists mall_applications_mersis_chk;
alter table public.mall_applications
  add constraint mall_applications_mersis_chk check (
    mersis_no is null or mersis_no ~ '^[0-9]{16}$'
  );

create table if not exists public.mall_application_documents (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.mall_applications (id) on delete cascade,
  document_type text not null,
  storage_path text not null,
  original_filename text not null,
  mime_type text,
  size_bytes integer,
  created_at timestamptz not null default timezone('utc', now()),
  constraint mall_application_documents_type_chk check (
    document_type in (
      'authorization_letter',
      'trade_registry_gazette',
      'tax_certificate',
      'activity_certificate',
      'signature_circular',
      'authorized_person_identity',
      'other'
    )
  ),
  constraint mall_application_documents_path_unique unique (application_id, storage_path)
);

alter table public.mall_application_documents enable row level security;
revoke all on table public.mall_application_documents from public, anon, authenticated;
grant select, insert, delete on table public.mall_application_documents to authenticated;

drop policy if exists mall_application_documents_owner on public.mall_application_documents;
create policy mall_application_documents_owner
on public.mall_application_documents
for all
to authenticated
using (
  exists (
    select 1 from public.mall_applications a
    where a.id = application_id and a.applicant_user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.mall_applications a
    where a.id = application_id and a.applicant_user_id = auth.uid()
  )
);

drop policy if exists mall_application_documents_admin on public.mall_application_documents;
create policy mall_application_documents_admin
on public.mall_application_documents
for select
to authenticated
using (public.is_admin_user());

create table if not exists public.mall_invitations (
  id uuid primary key default gen_random_uuid(),
  mall_id uuid not null references public.malls (id) on delete cascade,
  email text not null,
  role text not null,
  status text not null default 'pending',
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint mall_invitations_role_chk check (
    role in ('mall_manager', 'mall_ad_manager', 'mall_content_editor', 'mall_store_manager')
  ),
  constraint mall_invitations_status_chk check (
    status in ('pending', 'accepted', 'cancelled')
  ),
  constraint mall_invitations_email_mall_unique unique (mall_id, email)
);

alter table public.mall_invitations enable row level security;
revoke all on table public.mall_invitations from public, anon, authenticated;
grant select on table public.mall_invitations to authenticated;

drop policy if exists mall_invitations_manager_select on public.mall_invitations;
create policy mall_invitations_manager_select
on public.mall_invitations
for select
to authenticated
using (
  public.mall_member_has_role(mall_id, array['mall_manager'])
  or lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
);

create or replace function public.invite_mall_member(
  p_mall_id uuid,
  p_email text,
  p_role text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(btrim(p_email));
  v_user uuid;
begin
  if not public.mall_member_has_role(p_mall_id, array['mall_manager']) then
    raise exception 'Bu AVM için yönetim yetkiniz bulunmuyor.' using errcode = '42501';
  end if;
  if p_role not in ('mall_manager', 'mall_ad_manager', 'mall_content_editor', 'mall_store_manager') then
    raise exception 'Geçersiz rol.';
  end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Geçerli bir e-posta girin.';
  end if;

  insert into public.mall_invitations (mall_id, email, role, status, created_by)
  values (p_mall_id, v_email, p_role, 'pending', auth.uid())
  on conflict (mall_id, email) do update
    set role = excluded.role, status = 'pending';

  select u.id into v_user
  from public.users u
  where lower(u.email) = v_email
  limit 1;

  if v_user is null then
    return jsonb_build_object(
      'status', 'pending_account',
      'message', 'Bu e-posta için İBUL hesabı oluşturulduktan sonra davet kabul edilebilir.'
    );
  end if;

  insert into public.mall_members (mall_id, user_id, role, status, created_by)
  values (p_mall_id, v_user, p_role, 'invited', auth.uid())
  on conflict (mall_id, user_id) do update
    set role = excluded.role,
        status = case
          when public.mall_members.status = 'active' then 'active'
          else 'invited'
        end;

  return jsonb_build_object('status', 'invited', 'user_id', v_user);
end;
$$;

create or replace function public.accept_mall_invitation(p_mall_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
  if auth.uid() is null then
    raise exception 'Bu AVM için yönetim yetkiniz bulunmuyor.' using errcode = '42501';
  end if;
  update public.mall_members
  set status = 'active'
  where mall_id = p_mall_id
    and user_id = auth.uid()
    and status = 'invited';
  update public.mall_invitations
  set status = 'accepted'
  where mall_id = p_mall_id
    and lower(email) = v_email
    and status = 'pending';
end;
$$;

revoke all on function public.invite_mall_member(uuid, text, text) from public, anon;
revoke all on function public.accept_mall_invitation(uuid) from public, anon;
grant execute on function public.invite_mall_member(uuid, text, text) to authenticated;
grant execute on function public.accept_mall_invitation(uuid) to authenticated;

commit;
