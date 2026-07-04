-- ============================================================
-- HOME FEATURE ADS — Kart şablonları + ana sayfa öne çıkarma
-- Mevcut campaigns tablosuna home_feature tipi eklenir.
-- Run in Supabase SQL Editor.
-- ============================================================

create extension if not exists pgcrypto;

-- ── 0. ADMIN HELPER (profiles tablosu yok — users / JWT kullan) ─
create or replace function public.is_admin_user(target_user_id uuid default auth.uid())
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  role_key text;
begin
  if target_user_id is null then
    return false;
  end if;

  if coalesce(auth.jwt() ->> 'role', '') in ('admin', 'super_admin')
     or coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'super_admin') then
    return true;
  end if;

  if to_regclass('public.users') is not null then
    execute 'select role from public.users where id = $1 limit 1'
      into role_key
      using target_user_id;

    if role_key = 'admin'
       or role_key = 'super_admin'
       or coalesce(role_key, '') like 'admin_%' then
      return true;
    end if;
  end if;

  if to_regclass('public.admin_user_permissions') is not null then
    return exists (
      select 1
      from public.admin_user_permissions aup
      where aup.user_id = target_user_id
        and aup.is_active = true
    );
  end if;

  return false;
end;
$$;

-- ── 1. HOME CARD TEMPLATES ───────────────────────────────────
create table if not exists public.home_card_templates (
  id            uuid        primary key default gen_random_uuid(),
  title         text        not null,
  category_id   bigint,
  category_name text,
  slug          text        not null unique,
  description   text,
  is_active     boolean     not null default true,
  sort_order    int         not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists idx_home_card_templates_category
  on public.home_card_templates (category_name, sort_order)
  where is_active = true;

create index if not exists idx_home_card_templates_active
  on public.home_card_templates (is_active, sort_order);

-- category_id: public.categories.id (bigint) ile uyumlu — güvenli dönüşüm
-- uuid → bigint doğrudan cast edilmez; staging kolon + category_name backfill kullanılır.
do $$
declare
  v_category_id_udt text;
  v_has_staging_col boolean;
begin
  if to_regclass('public.home_card_templates') is null then
    return;
  end if;

  select c.udt_name
  into v_category_id_udt
  from information_schema.columns c
  where c.table_schema = 'public'
    and c.table_name = 'home_card_templates'
    and c.column_name = 'category_id';

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'home_card_templates'
      and column_name = 'category_id_bigint'
  ) into v_has_staging_col;

  -- Zaten bigint — tamamlanmış
  if v_category_id_udt = 'int8' and not v_has_staging_col then
    return;
  end if;

  -- Yarım kalmış migration: staging kolon var, eski kolon silinmiş
  if v_category_id_udt is null and v_has_staging_col then
    alter table public.home_card_templates
      rename column category_id_bigint to category_id;
    return;
  end if;

  -- uuid → bigint güvenli geçiş
  if v_category_id_udt = 'uuid' then
    if not v_has_staging_col then
      alter table public.home_card_templates
        add column category_id_bigint bigint;
    end if;

    -- category_name ile categories tablosundan eşleştir (uuid değeri atılır)
    if to_regclass('public.categories') is not null then
      update public.home_card_templates h
      set category_id_bigint = matched.cat_id
      from (
        select
          h2.ctid as row_ctid,
          (
            select c.id
            from public.categories c
            where lower(trim(c.name)) = lower(trim(h2.category_name))
            order by c.order_index nulls last, c.id
            limit 1
          ) as cat_id
        from public.home_card_templates h2
        where h2.category_name is not null
          and trim(h2.category_name) <> ''
      ) matched
      where h.ctid = matched.row_ctid
        and matched.cat_id is not null
        and h.category_id_bigint is null;
    end if;

    alter table public.home_card_templates
      drop column if exists category_id;

    alter table public.home_card_templates
      rename column category_id_bigint to category_id;

    return;
  end if;

  -- Kolon hiç yoksa ekle
  if v_category_id_udt is null and not v_has_staging_col then
    alter table public.home_card_templates
      add column if not exists category_id bigint;
    return;
  end if;

  raise notice
    'home_card_templates.category_id beklenmeyen tip (%), dokunulmadi.',
    coalesce(v_category_id_udt, 'null');
end;
$$;

create index if not exists idx_home_card_templates_category_id
  on public.home_card_templates (category_id)
  where category_id is not null;

-- ── 2. UPDATED_AT TRIGGER ─────────────────────────────────────
create or replace function public.set_home_card_templates_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_home_card_templates_updated_at on public.home_card_templates;
create trigger trg_home_card_templates_updated_at
  before update on public.home_card_templates
  for each row execute function public.set_home_card_templates_updated_at();

-- ── 3. RLS ────────────────────────────────────────────────────
alter table public.home_card_templates enable row level security;

grant usage on schema public to anon, authenticated;
grant select on public.home_card_templates to anon, authenticated;
grant insert, update, delete on public.home_card_templates to authenticated;

-- Herkes aktif şablonları okuyabilir (ana sayfa)
drop policy if exists home_card_templates_public_read on public.home_card_templates;
create policy home_card_templates_public_read
  on public.home_card_templates for select
  to anon, authenticated
  using (is_active = true);

-- Admin pasif şablonları da görebilir
drop policy if exists home_card_templates_admin_read on public.home_card_templates;
create policy home_card_templates_admin_read
  on public.home_card_templates for select
  to authenticated
  using (public.is_admin_user());

-- Admin CRUD
drop policy if exists home_card_templates_admin_all on public.home_card_templates;
drop policy if exists home_card_templates_admin_write on public.home_card_templates;
create policy home_card_templates_admin_write
  on public.home_card_templates for all
  to authenticated
  using (public.is_admin_user())
  with check (public.is_admin_user());

-- ── 4. HELPER VIEW: Active home feature campaigns ─────────────
-- campaigns.type = 'home_feature' uses metadata JSONB fields:
--   card_template_id, category_id, category_name, banner_images,
--   selected_product_ids, sort_order, sort_mode, ai_score,
--   home_metrics: { impressions_count, banner_clicks_count, ... }

do $$
begin
  if to_regclass('public.campaigns') is null then
    raise notice 'public.campaigns tablosu yok — view/RPC atlandi. Once SUPABASE_ADS_CAMPAIGNS_SETUP.sql calistirin.';
    return;
  end if;

  execute $view$
    create or replace view public.active_home_feature_ads as
    select
      c.id,
      c.seller_id,
      c.store_id,
      c.name,
      c.status,
      c.starts_at,
      c.ends_at,
      c.metadata,
      (c.metadata->>'card_template_id')::uuid as card_template_id,
      c.metadata->>'category_name' as category_name,
      coalesce((c.metadata->>'sort_order')::int, 0) as sort_order,
      coalesce(c.metadata->>'sort_mode', 'manual') as sort_mode,
      c.approved_at,
      c.created_at,
      c.updated_at
    from public.campaigns c
    where c.type = 'home_feature'
      and coalesce(c.metadata->>'placement', 'home_card') = 'home_card'
      and c.status in ('approved', 'active')
      and c.starts_at <= now()
      and c.ends_at >= now()
  $view$;

  grant select on public.active_home_feature_ads to anon, authenticated;

  create index if not exists campaigns_ends_at_idx
    on public.campaigns (ends_at desc);

  create index if not exists campaigns_home_feature_active_idx
    on public.campaigns (status, starts_at, ends_at)
    where type = 'home_feature';

  create index if not exists campaigns_home_feature_card_template_idx
    on public.campaigns ((metadata->>'card_template_id'))
    where type = 'home_feature';
end;
$$;

-- ── 5. RPC: Increment home feature metric (fire-and-forget safe) ─
create or replace function public.increment_home_feature_metric(
  p_campaign_id text,
  p_metric_key text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_path text[];
begin
  if to_regclass('public.campaigns') is null then
    return;
  end if;

  if p_metric_key not in (
    'impressions_count',
    'banner_clicks_count',
    'profile_opens_count',
    'product_clicks_count',
    'favorites_count',
    'message_clicks_count'
  ) then
    return;
  end if;

  v_path := array['home_metrics', p_metric_key];
  update public.campaigns
  set metadata = jsonb_set(
    coalesce(metadata, '{}'::jsonb),
    v_path,
    to_jsonb(coalesce((metadata #>> v_path)::int, 0) + 1),
    true
  ),
  updated_at = now()
  where id = p_campaign_id
    and type = 'home_feature';
end;
$$;

grant execute on function public.increment_home_feature_metric(text, text)
  to anon, authenticated;

-- ── 6. RPC: Update home feature sort order (admin) ────────────
create or replace function public.update_home_feature_sort_order(
  p_campaign_id text,
  p_sort_order int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin_user() then
    raise exception 'Admin yetkisi gerekli';
  end if;

  if to_regclass('public.campaigns') is null then
    return;
  end if;

  update public.campaigns
  set metadata = jsonb_set(
    coalesce(metadata, '{}'::jsonb),
    '{sort_order}',
    to_jsonb(p_sort_order),
    true
  ),
  updated_at = now()
  where id = p_campaign_id
    and type = 'home_feature';
end;
$$;

grant execute on function public.update_home_feature_sort_order(text, int)
  to authenticated;

-- ── 7. home_feature status guard (seller admin-onay bypass engeli) ─
-- Sadece type = home_feature kampanyaları etkiler; diğer reklam tipleri dokunulmaz.
create or replace function public.can_bypass_home_feature_status_guard()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(auth.jwt() ->> 'role', '') = 'service_role'
      or public.is_admin_user();
$$;

create or replace function public.enforce_home_feature_campaign_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.type, '') <> 'home_feature' then
    return new;
  end if;

  if public.can_bypass_home_feature_status_guard() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.status := 'pending_review';
    new.approved_at := null;
    new.rejected_at := null;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.status is distinct from old.status then
      raise exception
        'home_feature kampanya status degisikligi admin onayi gerektirir'
        using errcode = '42501';
    end if;

    if new.approved_at is distinct from old.approved_at
       or new.rejected_at is distinct from old.rejected_at
       or new.review_notes is distinct from old.review_notes then
      raise exception
        'home_feature kampanya inceleme alanlari admin onayi gerektirir'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

do $$
begin
  if to_regclass('public.campaigns') is null then
    raise notice 'public.campaigns tablosu yok — home_feature status trigger atlandi.';
    return;
  end if;

  drop trigger if exists trg_enforce_home_feature_campaign_status on public.campaigns;
  create trigger trg_enforce_home_feature_campaign_status
    before insert or update on public.campaigns
    for each row
    execute function public.enforce_home_feature_campaign_status();
end;
$$;

notify pgrst, 'reload schema';

-- categories tablosu diagnostik (root neden Erkek/Kadın görünüyordu):
-- select id, name, parent_id, is_active
-- from public.categories
-- order by parent_id nulls first, name;
--
-- Not: Kart Şablonu modalı artık ürün ekleme ile aynı canonical listeyi kullanır
-- (mobile_category_catalog.dart > sellerProductMainCategoryNames).
-- DB'de kategori yoksa category_id null kalır; category_name yine kaydedilir.
--
-- İsteğe bağlı: seller product ana kategorilerini DB'ye seed (idempotent)
-- insert into public.categories (name, order_index, parent_id, is_active)
-- select v.name, v.order_index, null, true
-- from (values
--   ('Elektronik', 1), ('Spor & Outdoor', 2), ('Giyim & Aksesuar', 3),
--   ('Anne & Bebek & Oyuncak', 4), ('Kozmetik & Kişisel Bakım', 5),
--   ('Ev & Yaşam', 6), ('Süpermarket & Petshop', 7), ('Kitap & Hobi', 8),
--   ('2.el Ürünler', 9), ('Yemek', 10)
-- ) as v(name, order_index)
-- where not exists (
--   select 1 from public.categories c
--   where lower(trim(c.name)) = lower(trim(v.name)) and c.parent_id is null
-- );

-- Doğrulama
select count(*) as home_card_template_count from public.home_card_templates;

-- category_id tip kontrolü (beklenen: bigint / int8)
-- select column_name, data_type, udt_name
-- from information_schema.columns
-- where table_schema = 'public'
--   and table_name = 'home_card_templates'
--   and column_name in ('category_id', 'category_name');
--
-- select id, title, category_id, category_name
-- from public.home_card_templates
-- limit 20;

-- ── 8. Manuel doğrulama SQL (SQL Editor'de auth context ile test edin) ─
-- 1) Seller pending_review insert (authenticated seller JWT):
--    insert into public.campaigns (id, seller_id, name, type, status, starts_at, ends_at)
--    values ('hfa-test-1', auth.uid(), 'Test', 'home_feature', 'pending_review', now(), now() + interval '7 days');
--    → başarılı, status = pending_review
--
-- 2) Seller approved ile insert (authenticated seller JWT):
--    insert into public.campaigns (id, seller_id, name, type, status, starts_at, ends_at)
--    values ('hfa-test-2', auth.uid(), 'Test', 'home_feature', 'approved', now(), now() + interval '7 days');
--    → başarılı ama status pending_review'e zorlanır
--
-- 3) Seller status escalation (authenticated seller JWT):
--    update public.campaigns set status = 'approved' where id = 'hfa-test-1' and seller_id = auth.uid();
--    → hata: home_feature kampanya status degisikligi admin onayi gerektirir
--
-- 4) Admin approve (authenticated admin JWT):
--    update public.campaigns set status = 'approved', approved_at = now() where id = 'hfa-test-1';
--    → başarılı
--
-- 5) Ana sayfa görünürlük:
--    select id, status from public.active_home_feature_ads where id = 'hfa-test-1';
--    → approved ise satır döner, pending_review ise dönmez
--
-- 6) Normal reklam tipi etkilenmez:
--    update public.campaigns set status = 'active' where type = 'product_boost' and seller_id = auth.uid();
--    → home_feature dışı kampanyalarda trigger devreye girmez
