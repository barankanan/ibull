-- DO NOT APPLY to the live project from this workspace.
-- LAN staff authority: one owner-only read that tells the LAN center, in a
-- single answer, whether a staff member may take orders: active membership of
-- this restaurant, the stored permissions and branch, AND whether the account
-- still carries the temporary password (the flag lives in Auth app_metadata,
-- which the owner's client cannot read, so the center never saw it).
--
-- Nothing here grants access. It only reports. The center rejects when the
-- answer is missing, malformed or says the password must change.

begin;

create or replace function public.lan_staff_authority(
  p_restaurant_id uuid,
  p_staff_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $authority$
declare
  v_member public.store_sub_admins%rowtype;
  v_must_change boolean;
begin
  -- Only the restaurant owner (the LAN center runs on the owner session).
  if auth.uid() is null
     or p_restaurant_id is null
     or auth.uid() <> p_restaurant_id then
    raise exception 'Personel yetkisini yalnız işletme sahibi sorgulayabilir.'
      using errcode = '42501';
  end if;
  if p_staff_id is null then
    return jsonb_build_object('found', false);
  end if;

  select * into v_member
  from public.store_sub_admins sa
  where sa.store_id = p_restaurant_id
    and sa.auth_user_id = p_staff_id
  limit 1;
  if not found then
    return jsonb_build_object('found', false);
  end if;

  -- Same rule as staff_must_change_password(), read from the account itself.
  select coalesce(
           (u.raw_app_meta_data ->> 'managed_restaurant_staff') = 'true'
           and (u.raw_app_meta_data ->> 'must_change_password') = 'true',
           false)
    into v_must_change
  from auth.users u
  where u.id = p_staff_id;
  -- No auth account behind the membership: treat as must-change (fail closed).
  v_must_change := coalesce(v_must_change, true);

  return jsonb_build_object(
    'found', true,
    'store_id', v_member.store_id,
    'status', v_member.status,
    'staff_role', v_member.staff_role,
    'permissions', to_jsonb(coalesce(v_member.permissions, '{}'::text[])),
    'branch_id', v_member.branch_id,
    'must_change_password', v_must_change
  );
end;
$authority$;

revoke all on function public.lan_staff_authority(uuid, uuid) from public, anon;
grant execute on function public.lan_staff_authority(uuid, uuid) to authenticated;

commit;
