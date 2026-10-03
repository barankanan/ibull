-- AVM başvuru inceleme modülü. Uygulanmadı; katalog güncellemesi.
-- super_admin istemcide AdminModules.all ile zaten görür.
-- admin ve admin_store_ops katalog dizisine mall_review eklenir.

update public.admin_role_catalog
set modules = modules || array['mall_review']::text[],
    updated_at = timezone('utc', now())
where role_key in ('admin', 'super_admin', 'admin_store_ops')
  and not ('mall_review' = any(coalesce(modules, '{}'::text[])));
