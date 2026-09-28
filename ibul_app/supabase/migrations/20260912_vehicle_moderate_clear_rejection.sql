-- Admin approve must become public `active` and drop leftover rejection flags.
-- Seller persist later reads ai_payload; leftover rejection_reason made
-- some screens treat an active listing as still rejected/pending.

create or replace function public.moderate_vehicle_listing(
  p_listing_id uuid,
  p_action text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_listing public.vehicle_listings%rowtype;
  v_action text := lower(trim(coalesce(p_action, '')));
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_payload jsonb;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if not public.vehicle_is_admin() then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  select * into v_listing from public.vehicle_listings where id = p_listing_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  if v_action = 'approve' then
    perform set_config('ibul.vehicle_moderation', '1', true);
    v_payload := coalesce(v_listing.ai_payload, '{}'::jsonb) - 'rejection_reason';
    v_payload := v_payload || jsonb_build_object(
      'moderation', jsonb_build_object(
        'status', 'approved',
        'reviewed_at', timezone('utc', now()),
        'reviewed_by', auth.uid()
      )
    );
    update public.vehicle_listings
    set
      status = 'active',
      published_at = timezone('utc', now()),
      ai_payload = v_payload
    where id = p_listing_id;
    return jsonb_build_object('ok', true, 'status', 'active');
  end if;

  if v_action = 'reject' then
    if v_reason is null then
      return jsonb_build_object('ok', false, 'error', 'reason_required');
    end if;
    update public.vehicle_listings
    set
      status = 'draft',
      published_at = null,
      ai_payload = coalesce(ai_payload, '{}'::jsonb) || jsonb_build_object(
        'moderation', jsonb_build_object(
          'status', 'rejected',
          'reason', v_reason,
          'reviewed_at', timezone('utc', now()),
          'reviewed_by', auth.uid()
        ),
        'rejection_reason', v_reason
      )
    where id = p_listing_id;
    return jsonb_build_object('ok', true, 'status', 'draft');
  end if;

  return jsonb_build_object('ok', false, 'error', 'invalid_action');
end;
$$;

revoke all on function public.moderate_vehicle_listing(uuid, text, text) from public, anon;
grant execute on function public.moderate_vehicle_listing(uuid, text, text) to authenticated;
