-- AVM başvuru belgeleri. seller-documents private bucket.
-- Mevcut satıcı belge policy'leri silinmez ve genişletilmez.
-- Public okuma yok. Anon yok.
-- Path: {auth.uid}/mall-applications/{application_id}/{filename}

insert into storage.buckets (id, name, public)
values ('seller-documents', 'seller-documents', false)
on conflict (id) do nothing;

drop policy if exists mall_application_docs_owner_insert on storage.objects;
create policy mall_application_docs_owner_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'seller-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'mall-applications'
);

drop policy if exists mall_application_docs_owner_select on storage.objects;
create policy mall_application_docs_owner_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'seller-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'mall-applications'
);

drop policy if exists mall_application_docs_owner_update on storage.objects;
create policy mall_application_docs_owner_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'seller-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'mall-applications'
)
with check (
  bucket_id = 'seller-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'mall-applications'
);

drop policy if exists mall_application_docs_owner_delete on storage.objects;
create policy mall_application_docs_owner_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'seller-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'mall-applications'
);

drop policy if exists mall_application_docs_admin_select on storage.objects;
create policy mall_application_docs_admin_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'seller-documents'
  and (storage.foldername(name))[2] = 'mall-applications'
  and public.is_admin_user()
);
