-- Manual production patch. Do not place under supabase/migrations.
-- Do not run with supabase db push.
-- Idempotent. One transaction. No table drops, no row deletes.
-- Touches only mall_review catalog membership, two policies, and three RPC auth gates.
-- Remote function bodies match this text except the authorization predicate.

begin;

update public.admin_role_catalog
set modules = modules || array['mall_review']::text[],
    updated_at = timezone('utc', now())
where role_key in ('admin', 'admin_store_ops')
  and not ('mall_review' = any(coalesce(modules, '{}'::text[])));

alter policy mall_applications_select_admin
on public.mall_applications
using (public.current_admin_has_module('mall_review'));

alter policy mall_application_docs_admin_select
on storage.objects
using (
  (bucket_id = 'seller-documents'::text)
  and ((storage.foldername(name))[2] = 'mall-applications'::text)
  and public.current_admin_has_module('mall_review')
);

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
  if not public.current_admin_has_module('mall_review') then
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
  if not public.current_admin_has_module('mall_review') then
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
  if not public.current_admin_has_module('mall_review') then
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

revoke all on function public.admin_approve_mall_application(uuid, text) from public, anon;
revoke all on function public.admin_reject_mall_application(uuid, text, text) from public, anon;
revoke all on function public.admin_request_mall_application_info(uuid, text) from public, anon;

grant execute on function public.admin_approve_mall_application(uuid, text) to authenticated, service_role;
grant execute on function public.admin_reject_mall_application(uuid, text, text) to authenticated, service_role;
grant execute on function public.admin_request_mall_application_info(uuid, text) to authenticated, service_role;

commit;
