-- Canonical vehicle moderation: seller submit never publishes.
-- Admin can read pending embeds. Does not bulk-publish existing rows.

create or replace function public.publish_vehicle_listing(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.submit_vehicle_listing_for_review(p_listing_id);
end;
$$;

grant execute on function public.publish_vehicle_listing(uuid) to authenticated;

create or replace function public.admin_list_vehicle_listings(p_status text default null)
returns setof public.vehicle_listings
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.vehicle_is_admin() then
    raise exception 'forbidden';
  end if;
  if nullif(trim(coalesce(p_status, '')), '') is null then
    return query
      select * from public.vehicle_listings
      order by created_at desc;
    return;
  end if;
  return query
    select * from public.vehicle_listings
    where status = trim(p_status)
    order by created_at desc;
end;
$$;

revoke all on function public.admin_list_vehicle_listings(text) from public, anon;
grant execute on function public.admin_list_vehicle_listings(text) to authenticated;

-- Re-assert: sellers cannot self-publish to public `active`.
create or replace function public.vehicle_listings_guard_public_status()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE'
     and new.status = 'active'
     and old.status is distinct from 'active'
     and not public.vehicle_is_admin()
     and current_setting('ibul.vehicle_moderation', true) is distinct from '1' then
    raise exception 'seller_cannot_publish';
  end if;
  return new;
end;
$$;

drop trigger if exists vehicle_listings_guard_public_status on public.vehicle_listings;
create trigger vehicle_listings_guard_public_status
before update on public.vehicle_listings
for each row
execute function public.vehicle_listings_guard_public_status();

drop policy if exists vehicle_media_select on public.vehicle_media;
create policy vehicle_media_select on public.vehicle_media
for select using (
  exists (
    select 1 from public.vehicle_listings l
    where l.id = listing_id
      and (
        l.status in ('active', 'reserved', 'rented')
        or l.seller_id = auth.uid()
        or public.vehicle_is_admin()
      )
  )
);

drop policy if exists vehicle_damage_select on public.vehicle_damage_records;
create policy vehicle_damage_select on public.vehicle_damage_records
for select using (
  exists (
    select 1 from public.vehicle_listings l
    where l.id = listing_id
      and (
        l.status in ('active', 'reserved', 'rented')
        or l.seller_id = auth.uid()
        or public.vehicle_is_admin()
      )
  )
);

drop policy if exists vehicle_rental_settings_select on public.vehicle_rental_settings;
create policy vehicle_rental_settings_select on public.vehicle_rental_settings
for select using (
  exists (
    select 1 from public.vehicle_listings l
    where l.id = listing_id
      and (
        l.status in ('active', 'reserved', 'rented')
        or l.seller_id = auth.uid()
        or public.vehicle_is_admin()
      )
  )
);
