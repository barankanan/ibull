-- iBUL Araç / Galerici — RLS
-- Galerici yalnızca kendi stokunu yönetir.
-- Müşteri yalnızca kendi rezervasyon / teklif / randevu / belgelerini görür.
-- KYC object_path satıcıya açılmaz.

alter table public.vehicle_galleries enable row level security;
alter table public.vehicle_listings enable row level security;
alter table public.vehicle_specs enable row level security;
alter table public.vehicle_media enable row level security;
alter table public.vehicle_damage_records enable row level security;
alter table public.vehicle_maintenance_records enable row level security;
alter table public.vehicle_rental_settings enable row level security;
alter table public.vehicle_delivery_zones enable row level security;
alter table public.vehicle_delivery_points enable row level security;
alter table public.vehicle_reservations enable row level security;
alter table public.vehicle_kyc_documents enable row level security;
alter table public.vehicle_returns enable row level security;
alter table public.vehicle_quotes enable row level security;
alter table public.vehicle_quote_events enable row level security;
alter table public.vehicle_appointments enable row level security;
alter table public.vehicle_conversations enable row level security;
alter table public.vehicle_messages enable row level security;
alter table public.vehicle_favorites enable row level security;
alter table public.vehicle_analytics_events enable row level security;

create or replace function public.vehicle_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users u
    where u.id = auth.uid()
      and (
        lower(coalesce(u.role, '')) in ('admin', 'super_admin', 'owner')
        or coalesce(u.role, '') like 'admin_%'
      )
  );
$$;

revoke all on function public.vehicle_is_admin() from public;
grant execute on function public.vehicle_is_admin() to anon, authenticated;

-- Galleries
drop policy if exists vehicle_galleries_select on public.vehicle_galleries;
create policy vehicle_galleries_select on public.vehicle_galleries
for select using (true);

drop policy if exists vehicle_galleries_owner_write on public.vehicle_galleries;
create policy vehicle_galleries_owner_write on public.vehicle_galleries
for all using (auth.uid() = seller_id) with check (auth.uid() = seller_id);

-- Listings: public sees active-like; owner sees all
drop policy if exists vehicle_listings_public_select on public.vehicle_listings;
create policy vehicle_listings_public_select on public.vehicle_listings
for select using (
  status in ('active', 'reserved', 'rented')
  or seller_id = auth.uid()
  or public.vehicle_is_admin()
);

drop policy if exists vehicle_listings_owner_insert on public.vehicle_listings;
create policy vehicle_listings_owner_insert on public.vehicle_listings
for insert with check (auth.uid() = seller_id);

drop policy if exists vehicle_listings_owner_update on public.vehicle_listings;
create policy vehicle_listings_owner_update on public.vehicle_listings
for update using (auth.uid() = seller_id) with check (auth.uid() = seller_id);

drop policy if exists vehicle_listings_owner_delete on public.vehicle_listings;
create policy vehicle_listings_owner_delete on public.vehicle_listings
for delete using (auth.uid() = seller_id);

drop policy if exists vehicle_specs_select on public.vehicle_specs;
create policy vehicle_specs_select on public.vehicle_specs
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

drop policy if exists vehicle_specs_owner_write on public.vehicle_specs;
create policy vehicle_specs_owner_write on public.vehicle_specs
for all using (
  exists (select 1 from public.vehicle_listings l where l.id = listing_id and l.seller_id = auth.uid())
) with check (
  exists (select 1 from public.vehicle_listings l where l.id = listing_id and l.seller_id = auth.uid())
);

drop policy if exists vehicle_media_select on public.vehicle_media;
create policy vehicle_media_select on public.vehicle_media
for select using (
  exists (
    select 1 from public.vehicle_listings l
    where l.id = listing_id
      and (l.status in ('active', 'reserved', 'rented') or l.seller_id = auth.uid())
  )
);

drop policy if exists vehicle_media_owner_write on public.vehicle_media;
create policy vehicle_media_owner_write on public.vehicle_media
for all using (auth.uid() = seller_id) with check (auth.uid() = seller_id);

drop policy if exists vehicle_damage_select on public.vehicle_damage_records;
create policy vehicle_damage_select on public.vehicle_damage_records
for select using (
  exists (
    select 1 from public.vehicle_listings l
    where l.id = listing_id
      and (l.status in ('active', 'reserved', 'rented') or l.seller_id = auth.uid())
  )
);

drop policy if exists vehicle_damage_owner_write on public.vehicle_damage_records;
create policy vehicle_damage_owner_write on public.vehicle_damage_records
for all using (auth.uid() = seller_id) with check (auth.uid() = seller_id);

drop policy if exists vehicle_maintenance_owner on public.vehicle_maintenance_records;
create policy vehicle_maintenance_owner on public.vehicle_maintenance_records
for all using (auth.uid() = seller_id) with check (auth.uid() = seller_id);

drop policy if exists vehicle_rental_settings_select on public.vehicle_rental_settings;
create policy vehicle_rental_settings_select on public.vehicle_rental_settings
for select using (
  exists (
    select 1 from public.vehicle_listings l
    where l.id = listing_id
      and (l.status in ('active', 'reserved', 'rented') or l.seller_id = auth.uid())
  )
);

drop policy if exists vehicle_rental_settings_owner on public.vehicle_rental_settings;
create policy vehicle_rental_settings_owner on public.vehicle_rental_settings
for all using (auth.uid() = seller_id) with check (auth.uid() = seller_id);

drop policy if exists vehicle_delivery_zones_select on public.vehicle_delivery_zones;
create policy vehicle_delivery_zones_select on public.vehicle_delivery_zones
for select using (true);

drop policy if exists vehicle_delivery_zones_owner on public.vehicle_delivery_zones;
create policy vehicle_delivery_zones_owner on public.vehicle_delivery_zones
for all using (auth.uid() = seller_id) with check (auth.uid() = seller_id);

drop policy if exists vehicle_delivery_points_select on public.vehicle_delivery_points;
create policy vehicle_delivery_points_select on public.vehicle_delivery_points
for select using (is_active or auth.uid() = seller_id);

drop policy if exists vehicle_delivery_points_owner on public.vehicle_delivery_points;
create policy vehicle_delivery_points_owner on public.vehicle_delivery_points
for all using (auth.uid() = seller_id) with check (auth.uid() = seller_id);

drop policy if exists vehicle_reservations_party_select on public.vehicle_reservations;
create policy vehicle_reservations_party_select on public.vehicle_reservations
for select using (
  auth.uid() = customer_id or auth.uid() = seller_id or public.vehicle_is_admin()
);

drop policy if exists vehicle_reservations_no_client_insert on public.vehicle_reservations;
create policy vehicle_reservations_no_client_insert on public.vehicle_reservations
for insert with check (false);

drop policy if exists vehicle_reservations_no_client_update on public.vehicle_reservations;
create policy vehicle_reservations_no_client_update on public.vehicle_reservations
for update using (false) with check (false);

drop policy if exists vehicle_kyc_owner_select on public.vehicle_kyc_documents;
create policy vehicle_kyc_owner_select on public.vehicle_kyc_documents
for select using (
  auth.uid() = customer_id or public.vehicle_is_admin()
);

drop policy if exists vehicle_kyc_owner_insert on public.vehicle_kyc_documents;
create policy vehicle_kyc_owner_insert on public.vehicle_kyc_documents
for insert with check (
  auth.uid() = customer_id
  and exists (
    select 1 from public.vehicle_reservations r
    where r.id = reservation_id and r.customer_id = auth.uid()
  )
);

drop policy if exists vehicle_returns_party_select on public.vehicle_returns;
create policy vehicle_returns_party_select on public.vehicle_returns
for select using (
  auth.uid() = customer_id or auth.uid() = seller_id or public.vehicle_is_admin()
);

drop policy if exists vehicle_quotes_party on public.vehicle_quotes;
create policy vehicle_quotes_party on public.vehicle_quotes
for select using (auth.uid() = customer_id or auth.uid() = seller_id);

drop policy if exists vehicle_quotes_customer_insert on public.vehicle_quotes;
create policy vehicle_quotes_customer_insert on public.vehicle_quotes
for insert with check (auth.uid() = customer_id);

drop policy if exists vehicle_quote_events_party on public.vehicle_quote_events;
create policy vehicle_quote_events_party on public.vehicle_quote_events
for select using (
  exists (
    select 1 from public.vehicle_quotes q
    where q.id = quote_id and (q.customer_id = auth.uid() or q.seller_id = auth.uid())
  )
);

drop policy if exists vehicle_quote_events_insert on public.vehicle_quote_events;
create policy vehicle_quote_events_insert on public.vehicle_quote_events
for insert with check (
  auth.uid() = actor_id
  and exists (
    select 1 from public.vehicle_quotes q
    where q.id = quote_id and (q.customer_id = auth.uid() or q.seller_id = auth.uid())
  )
);

drop policy if exists vehicle_appointments_party on public.vehicle_appointments;
create policy vehicle_appointments_party on public.vehicle_appointments
for select using (auth.uid() = customer_id or auth.uid() = seller_id);

drop policy if exists vehicle_appointments_customer_insert on public.vehicle_appointments;
create policy vehicle_appointments_customer_insert on public.vehicle_appointments
for insert with check (auth.uid() = customer_id);

drop policy if exists vehicle_conversations_party on public.vehicle_conversations;
create policy vehicle_conversations_party on public.vehicle_conversations
for select using (auth.uid() = customer_id or auth.uid() = seller_id);

drop policy if exists vehicle_conversations_customer_insert on public.vehicle_conversations;
create policy vehicle_conversations_customer_insert on public.vehicle_conversations
for insert with check (auth.uid() = customer_id);

drop policy if exists vehicle_messages_party on public.vehicle_messages;
create policy vehicle_messages_party on public.vehicle_messages
for select using (
  exists (
    select 1 from public.vehicle_conversations c
    where c.id = conversation_id
      and (c.customer_id = auth.uid() or c.seller_id = auth.uid())
  )
);

drop policy if exists vehicle_messages_sender_insert on public.vehicle_messages;
create policy vehicle_messages_sender_insert on public.vehicle_messages
for insert with check (
  auth.uid() = sender_id
  and exists (
    select 1 from public.vehicle_conversations c
    where c.id = conversation_id
      and (c.customer_id = auth.uid() or c.seller_id = auth.uid())
  )
);

drop policy if exists vehicle_favorites_own on public.vehicle_favorites;
create policy vehicle_favorites_own on public.vehicle_favorites
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists vehicle_analytics_owner_select on public.vehicle_analytics_events;
create policy vehicle_analytics_owner_select on public.vehicle_analytics_events
for select using (auth.uid() = seller_id or public.vehicle_is_admin());

drop policy if exists vehicle_analytics_insert_auth on public.vehicle_analytics_events;
create policy vehicle_analytics_insert_auth on public.vehicle_analytics_events
for insert with check (auth.uid() is not null);

-- Storage buckets
insert into storage.buckets (id, name, public)
values ('vehicle-media', 'vehicle-media', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('vehicle-documents', 'vehicle-documents', false)
on conflict (id) do nothing;

drop policy if exists vehicle_media_public_read on storage.objects;
create policy vehicle_media_public_read on storage.objects
for select using (bucket_id = 'vehicle-media');

drop policy if exists vehicle_media_owner_write on storage.objects;
create policy vehicle_media_owner_write on storage.objects
for insert with check (
  bucket_id = 'vehicle-media'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists vehicle_media_owner_update on storage.objects;
create policy vehicle_media_owner_update on storage.objects
for update using (
  bucket_id = 'vehicle-media'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists vehicle_media_owner_delete on storage.objects;
create policy vehicle_media_owner_delete on storage.objects
for delete using (
  bucket_id = 'vehicle-media'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists vehicle_docs_owner_read on storage.objects;
create policy vehicle_docs_owner_read on storage.objects
for select using (
  bucket_id = 'vehicle-documents'
  and (
    auth.uid()::text = (storage.foldername(name))[1]
    or public.vehicle_is_admin()
  )
);

drop policy if exists vehicle_docs_owner_write on storage.objects;
create policy vehicle_docs_owner_write on storage.objects
for insert with check (
  bucket_id = 'vehicle-documents'
  and auth.uid()::text = (storage.foldername(name))[1]
);

grant select on public.vehicle_galleries to anon, authenticated;
grant select on public.vehicle_listings to anon, authenticated;
grant select on public.vehicle_specs to anon, authenticated;
grant select on public.vehicle_media to anon, authenticated;
grant select on public.vehicle_damage_records to anon, authenticated;
grant select on public.vehicle_rental_settings to anon, authenticated;
grant select on public.vehicle_delivery_zones to anon, authenticated;
grant select on public.vehicle_delivery_points to anon, authenticated;

grant select, insert, update, delete on public.vehicle_galleries to authenticated;
grant select, insert, update, delete on public.vehicle_listings to authenticated;
grant select, insert, update, delete on public.vehicle_specs to authenticated;
grant select, insert, update, delete on public.vehicle_media to authenticated;
grant select, insert, update, delete on public.vehicle_damage_records to authenticated;
grant select, insert, update, delete on public.vehicle_maintenance_records to authenticated;
grant select, insert, update, delete on public.vehicle_rental_settings to authenticated;
grant select, insert, update, delete on public.vehicle_delivery_zones to authenticated;
grant select, insert, update, delete on public.vehicle_delivery_points to authenticated;
grant select on public.vehicle_reservations to authenticated;
grant select, insert, update on public.vehicle_kyc_documents to authenticated;
grant select on public.vehicle_returns to authenticated;
grant select, insert on public.vehicle_quotes to authenticated;
grant select, insert on public.vehicle_quote_events to authenticated;
grant select, insert, update on public.vehicle_appointments to authenticated;
grant select, insert, update on public.vehicle_conversations to authenticated;
grant select, insert on public.vehicle_messages to authenticated;
grant select, insert, delete on public.vehicle_favorites to authenticated;
grant select, insert on public.vehicle_analytics_events to authenticated;
