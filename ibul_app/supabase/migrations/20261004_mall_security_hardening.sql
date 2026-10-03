-- AVM başvuru güvenlik düzeltmesi.
-- 20261003 daha önce uygulandıysa fonksiyon gövdelerini bununla değiştirir.
-- Fresh install'da 20261003 ile aynı güvenli gövdeyi yeniden yazar (idempotent).
--
-- Application approved != mall published.
-- Approval: malls.is_verified = true AND malls.status = draft.
-- Publication: ileriki publish RPC ile malls.status = active.
--
-- Guard custom GUC kullanmaz. SECURITY DEFINER RPC, current_user'ı
-- fonksiyon sahibine (postgres / supabase_admin) çevirir. INVOKER trigger
-- bu current_user'ı görür. İstemci current_user'ı postgres yapamaz.
-- set_config('ibul....') herhangi bir rol tarafından çağrılabilir; kullanılmaz.

comment on column public.mall_applications.status is
  'Başvuru kararı. approved canlı yayın değildir. Yayın malls.status = active ile olur.';

-- SECURITY INVOKER. Admin JWT ve custom GUC bypass etmez.
-- RPC SECURITY DEFINER owner (postgres / supabase_admin) current_user olarak geçer.
-- Bu, istemcinin set_config ile taklit edebileceği bir bayrak değildir.
create or replace function public.mall_application_guard()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if public.session_is_service_role()
     or current_user in ('postgres', 'supabase_admin') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if auth.uid() is null or new.applicant_user_id is distinct from auth.uid() then
      raise exception 'mall_application_owner_mismatch' using errcode = '42501';
    end if;
    if new.status is distinct from 'draft' then
      raise exception 'mall_application_status_forbidden' using errcode = '42501';
    end if;
    if new.reviewed_by is not null
       or new.reviewed_at is not null
       or new.created_mall_id is not null
       or new.admin_note is not null
       or new.rejection_reason is not null
       or new.submitted_at is not null then
      raise exception 'mall_application_privileged_write' using errcode = '42501';
    end if;
  else
    if old.status not in ('draft', 'needs_info') then
      raise exception 'mall_application_locked' using errcode = '42501';
    end if;
    if new.applicant_user_id is distinct from old.applicant_user_id
       or new.status is distinct from old.status
       or new.reviewed_by is distinct from old.reviewed_by
       or new.reviewed_at is distinct from old.reviewed_at
       or new.created_mall_id is distinct from old.created_mall_id
       or new.admin_note is distinct from old.admin_note
       or new.rejection_reason is distinct from old.rejection_reason
       or new.submitted_at is distinct from old.submitted_at then
      raise exception 'mall_application_privileged_write' using errcode = '42501';
    end if;
  end if;

  if cardinality(new.document_paths) > 0
     and not public.mall_application_documents_valid(
       new.applicant_user_id,
       new.id,
       new.document_paths
     ) then
    raise exception 'mall_application_document_path' using errcode = '22023';
  end if;

  return new;
end;
$$;

revoke all on function public.mall_application_guard() from public;
revoke all on function public.mall_application_guard() from anon;
grant execute on function public.mall_application_guard() to authenticated;

drop trigger if exists mall_applications_guard on public.mall_applications;
create trigger mall_applications_guard
before insert or update on public.mall_applications
for each row execute function public.mall_application_guard();

drop trigger if exists mall_applications_set_updated_at on public.mall_applications;
create trigger mall_applications_set_updated_at
before insert or update on public.mall_applications
for each row execute function public.mall_set_updated_at();

alter table public.mall_applications enable row level security;

revoke all on table public.mall_applications from public;
revoke all on table public.mall_applications from anon, authenticated;
grant select, insert, update on table public.mall_applications to authenticated;

drop policy if exists mall_applications_select_own on public.mall_applications;
create policy mall_applications_select_own
on public.mall_applications
for select
to authenticated
using (applicant_user_id = auth.uid());

drop policy if exists mall_applications_select_admin on public.mall_applications;
create policy mall_applications_select_admin
on public.mall_applications
for select
to authenticated
using (public.is_admin_user());

drop policy if exists mall_applications_insert_own_draft on public.mall_applications;
create policy mall_applications_insert_own_draft
on public.mall_applications
for insert
to authenticated
with check (
  applicant_user_id = auth.uid()
  and status = 'draft'
  and reviewed_by is null
  and reviewed_at is null
  and created_mall_id is null
  and admin_note is null
  and rejection_reason is null
  and submitted_at is null
);

drop policy if exists mall_applications_update_own_open on public.mall_applications;
create policy mall_applications_update_own_open
on public.mall_applications
for update
to authenticated
using (applicant_user_id = auth.uid())
with check (
  applicant_user_id = auth.uid()
  and status in ('draft', 'needs_info')
);

-- ---------------------------------------------------------------------------
-- Bildirim yan etkidir. Başarısızlık başvuruyu geri almaz.
-- Ayrı audit tablosu yok; Postgres uyarısı yeter.
-- ---------------------------------------------------------------------------

create or replace function public.mall_application_notify(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_data jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if to_regclass('public.user_notifications') is null then
    raise warning 'mall_application_notify skipped: user_notifications missing';
    return;
  end if;

  insert into public.user_notifications (user_id, title, body, data)
  values (p_user_id, p_title, p_body, coalesce(p_data, '{}'::jsonb));
exception
  when others then
    raise warning 'mall_application_notify failed: %', sqlerrm;
end;
$$;

revoke all on function public.mall_application_notify(uuid, text, text, jsonb) from public;
revoke all on function public.mall_application_notify(uuid, text, text, jsonb) from anon, authenticated;

-- ---------------------------------------------------------------------------
-- submit: draft | needs_info → pending_review
-- ---------------------------------------------------------------------------

create or replace function public.submit_mall_application(
  p_application_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_app public.mall_applications%rowtype;
begin
  if v_actor is null then
    raise exception 'not authenticated';
  end if;
  if p_application_id is null then
    raise exception 'application not found';
  end if;

  select *
    into v_app
  from public.mall_applications
  where id = p_application_id
  for update;

  if v_app.id is null then
    raise exception 'application not found';
  end if;
  if v_app.applicant_user_id is distinct from v_actor then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if v_app.status not in ('draft', 'needs_info') then
    raise exception 'mall_application_invalid_state';
  end if;
  if char_length(btrim(v_app.mall_name)) < 1
     or char_length(btrim(v_app.city)) < 1
     or char_length(btrim(v_app.district)) < 1
     or char_length(btrim(v_app.address_text)) < 1
     or char_length(btrim(v_app.authorized_person_name)) < 1
     or char_length(btrim(v_app.authorized_person_title)) < 1
     or v_app.latitude is null
     or v_app.longitude is null then
    raise exception 'mall_application_incomplete';
  end if;
  if not public.mall_application_documents_valid(
    v_app.applicant_user_id,
    v_app.id,
    v_app.document_paths
  ) then
    raise exception 'mall_application_documents_required';
  end if;

  update public.mall_applications
  set status = 'pending_review',
      submitted_at = timezone('utc', now())
  where id = v_app.id;

  return jsonb_build_object(
    'ok', true,
    'application_id', v_app.id,
    'status', 'pending_review'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- cancel: draft → cancelled. Owner only.
-- ---------------------------------------------------------------------------

create or replace function public.cancel_mall_application(
  p_application_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_app public.mall_applications%rowtype;
begin
  if v_actor is null then
    raise exception 'not authenticated';
  end if;

  select *
    into v_app
  from public.mall_applications
  where id = p_application_id
  for update;

  if v_app.id is null then
    raise exception 'application not found';
  end if;
  if v_app.applicant_user_id is distinct from v_actor then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if v_app.status is distinct from 'draft' then
    raise exception 'mall_application_invalid_state';
  end if;

  update public.mall_applications
  set status = 'cancelled'
  where id = v_app.id;

  return jsonb_build_object(
    'ok', true,
    'application_id', v_app.id,
    'status', 'cancelled'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- approve. Application approved. Mall draft + is_verified. Yayın değil.
-- Second call returns the existing mall. users.role yazılmaz.
-- ---------------------------------------------------------------------------

create or replace function public.admin_approve_mall_application(
  p_application_id uuid,
  p_admin_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_app public.mall_applications%rowtype;
  v_base text;
  v_slug text;
  v_attempt integer;
  v_mall_id uuid;
  v_note text;
begin
  if v_actor is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_admin_user(v_actor) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select *
    into v_app
  from public.mall_applications
  where id = p_application_id
  for update;

  if v_app.id is null then
    raise exception 'application not found';
  end if;

  if not exists (
    select 1 from public.users u where u.id = v_app.applicant_user_id
  ) then
    raise exception 'mall_applicant_missing';
  end if;

  if v_app.created_mall_id is not null then
    if v_app.status = 'approved' then
      return jsonb_build_object(
        'ok', true,
        'application_id', v_app.id,
        'mall_id', v_app.created_mall_id,
        'idempotent', true
      );
    end if;
    raise exception 'mall_application_mall_already_linked';
  end if;

  if v_app.status is distinct from 'pending_review' then
    raise exception 'mall_application_invalid_state';
  end if;

  v_note := nullif(btrim(coalesce(p_admin_note, '')), '');
  v_base := trim(both '-' from left(public.mall_slugify(v_app.mall_name), 110));
  if v_base is null or v_base = '' then
    v_base := 'avm';
  end if;

  v_mall_id := null;
  for v_attempt in 1..50 loop
    v_slug := case
      when v_attempt = 1 then v_base
      else v_base || '-' || v_attempt
    end;
    begin
      insert into public.malls (
        name,
        slug,
        legal_name,
        status,
        city,
        district,
        address_text,
        latitude,
        longitude,
        phone,
        website,
        logo_url,
        cover_url,
        is_verified
      )
      values (
        btrim(v_app.mall_name),
        v_slug,
        nullif(btrim(coalesce(v_app.legal_name, '')), ''),
        'draft',
        btrim(v_app.city),
        btrim(v_app.district),
        btrim(v_app.address_text),
        v_app.latitude,
        v_app.longitude,
        nullif(btrim(coalesce(v_app.phone, '')), ''),
        nullif(btrim(coalesce(v_app.website, '')), ''),
        nullif(btrim(coalesce(v_app.logo_url, '')), ''),
        nullif(btrim(coalesce(v_app.cover_url, '')), ''),
        true
      )
      returning id into v_mall_id;
      exit;
    exception
      when unique_violation then
        v_mall_id := null;
    end;
  end loop;

  if v_mall_id is null then
    raise exception 'mall_slug_collision';
  end if;

  insert into public.mall_members (
    mall_id,
    user_id,
    role,
    status,
    created_by
  )
  values (
    v_mall_id,
    v_app.applicant_user_id,
    'mall_manager',
    'active',
    v_actor
  );

  update public.mall_applications
  set status = 'approved',
      created_mall_id = v_mall_id,
      reviewed_by = v_actor,
      reviewed_at = timezone('utc', now()),
      admin_note = coalesce(v_note, admin_note)
  where id = v_app.id
    and status = 'pending_review'
    and created_mall_id is null;

  if not found then
    raise exception 'mall_application_invalid_state';
  end if;

  perform public.mall_application_notify(
    v_app.applicant_user_id,
    'AVM başvurunuz onaylandı.',
    btrim(v_app.mall_name) || ' doğrulandı. Henüz yayında değil.',
    jsonb_build_object(
      'type', 'mall_application_approved',
      'application_id', v_app.id,
      'mall_id', v_mall_id
    )
  );

  return jsonb_build_object(
    'ok', true,
    'application_id', v_app.id,
    'mall_id', v_mall_id,
    'idempotent', false
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- reject: pending_review | needs_info → rejected. Approved reddedilmez.
-- ---------------------------------------------------------------------------

create or replace function public.admin_reject_mall_application(
  p_application_id uuid,
  p_rejection_reason text,
  p_admin_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_app public.mall_applications%rowtype;
  v_reason text := nullif(btrim(coalesce(p_rejection_reason, '')), '');
  v_note text := nullif(btrim(coalesce(p_admin_note, '')), '');
begin
  if v_actor is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_admin_user(v_actor) then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if v_reason is null then
    raise exception 'mall_application_rejection_reason_required';
  end if;

  select *
    into v_app
  from public.mall_applications
  where id = p_application_id
  for update;

  if v_app.id is null then
    raise exception 'application not found';
  end if;
  if v_app.status = 'approved' or v_app.created_mall_id is not null then
    raise exception 'mall_application_invalid_state';
  end if;
  if v_app.status not in ('pending_review', 'needs_info') then
    raise exception 'mall_application_invalid_state';
  end if;

  update public.mall_applications
  set status = 'rejected',
      rejection_reason = v_reason,
      admin_note = coalesce(v_note, admin_note),
      reviewed_by = v_actor,
      reviewed_at = timezone('utc', now())
  where id = v_app.id;

  perform public.mall_application_notify(
    v_app.applicant_user_id,
    'AVM başvurunuz reddedildi.',
    v_reason,
    jsonb_build_object(
      'type', 'mall_application_rejected',
      'application_id', v_app.id,
      'rejection_reason', v_reason
    )
  );

  return jsonb_build_object(
    'ok', true,
    'application_id', v_app.id,
    'status', 'rejected'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- needs_info: pending_review → needs_info. Resubmit = submit_mall_application.
-- ---------------------------------------------------------------------------

create or replace function public.admin_request_mall_application_info(
  p_application_id uuid,
  p_admin_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_app public.mall_applications%rowtype;
  v_note text := nullif(btrim(coalesce(p_admin_note, '')), '');
begin
  if v_actor is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_admin_user(v_actor) then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  if v_note is null then
    raise exception 'mall_application_admin_note_required';
  end if;

  select *
    into v_app
  from public.mall_applications
  where id = p_application_id
  for update;

  if v_app.id is null then
    raise exception 'application not found';
  end if;
  if v_app.status is distinct from 'pending_review' then
    raise exception 'mall_application_invalid_state';
  end if;

  update public.mall_applications
  set status = 'needs_info',
      admin_note = v_note,
      reviewed_by = v_actor,
      reviewed_at = timezone('utc', now())
  where id = v_app.id;

  perform public.mall_application_notify(
    v_app.applicant_user_id,
    'AVM başvurunuz için ek bilgi gerekli.',
    v_note,
    jsonb_build_object(
      'type', 'mall_application_needs_info',
      'application_id', v_app.id,
      'admin_note', v_note
    )
  );

  return jsonb_build_object(
    'ok', true,
    'application_id', v_app.id,
    'status', 'needs_info'
  );
end;
$$;

revoke all on function public.submit_mall_application(uuid) from public;
revoke all on function public.cancel_mall_application(uuid) from public;
revoke all on function public.admin_approve_mall_application(uuid, text) from public;
revoke all on function public.admin_reject_mall_application(uuid, text, text) from public;
revoke all on function public.admin_request_mall_application_info(uuid, text) from public;

revoke all on function public.submit_mall_application(uuid) from anon;
revoke all on function public.cancel_mall_application(uuid) from anon;
revoke all on function public.admin_approve_mall_application(uuid, text) from anon;
revoke all on function public.admin_reject_mall_application(uuid, text, text) from anon;
revoke all on function public.admin_request_mall_application_info(uuid, text) from anon;

grant execute on function public.submit_mall_application(uuid) to authenticated;
grant execute on function public.cancel_mall_application(uuid) to authenticated;
grant execute on function public.admin_approve_mall_application(uuid, text) to authenticated;
grant execute on function public.admin_reject_mall_application(uuid, text, text) to authenticated;
grant execute on function public.admin_request_mall_application_info(uuid, text) to authenticated;
