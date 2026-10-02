-- İBUL Blog v1 — şema, RLS ve medya bucket'ı.
-- Geriye uyumlu: yalnızca yeni tablo/fonksiyon/policy ekler, mevcut veriye dokunmaz.
-- Yetki: blog yöneticisi = mevcut `current_admin_has_module('campaign_content')`
-- (admin_role_catalog seed'inde admin / super_admin / içerik rolü). Yazar =
-- `blog_authors.user_id = auth.uid()` ve aktif.
-- Yazılar tabloya doğrudan yazılamaz; tüm değişiklikler 20261002_blog_3_rpc_write.sql
-- içindeki SECURITY DEFINER RPC'lerden geçer.

-- ---------------------------------------------------------------------------
-- Yardımcılar
-- ---------------------------------------------------------------------------
create or replace function public.blog_normalize(p_value text)
returns text
language sql
immutable
as $$
  select lower(translate(coalesce(p_value, ''),
    'İIĞÜŞÖÇığüşöçÂÎÛâîû',
    'iigusocigusocaiuaiu'));
$$;

create or replace function public.blog_slugify(p_value text)
returns text
language sql
immutable
as $$
  select trim(both '-' from regexp_replace(
    regexp_replace(public.blog_normalize(p_value), '[^a-z0-9]+', '-', 'g'),
    '-{2,}', '-', 'g'));
$$;

create or replace function public.blog_url_is_safe(p_url text)
returns boolean
language sql
immutable
as $$
  select p_url is null
    or btrim(p_url) = ''
    or (btrim(p_url) ~* '^(https?://[^\s/]+|mailto:[^\s]+|/[^/\s]?)' and btrim(p_url) !~ '^//');
$$;

-- ---------------------------------------------------------------------------
-- Tablolar
-- ---------------------------------------------------------------------------
create table if not exists public.blog_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 80),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  description text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.blog_tags (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 60),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  created_at timestamptz not null default now()
);

create table if not exists public.blog_authors (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete set null,
  display_name text not null check (char_length(btrim(display_name)) between 1 and 80),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  bio text,
  avatar_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.blog_posts (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  status text not null default 'draft'
    check (status in ('draft', 'in_review', 'published')),
  title text not null default '',
  subtitle text,
  excerpt text,
  cover_url text,
  cover_alt text,
  category_id uuid references public.blog_categories(id) on delete set null,
  author_id uuid references public.blog_authors(id) on delete set null,
  tag_ids uuid[] not null default '{}'::uuid[],
  is_featured boolean not null default false,
  seo_title text,
  meta_description text,
  content jsonb not null default '{"version":1,"blocks":[]}'::jsonb,
  search_text text not null default '',
  search_document text not null default '',
  reading_minutes integer not null default 1,
  published_at timestamptz,
  first_published_at timestamptz,
  unpublished_at timestamptz,
  review_requested_at timestamptz,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists blog_posts_public_idx
  on public.blog_posts (published_at desc)
  where status = 'published';
create index if not exists blog_posts_category_idx on public.blog_posts (category_id);
create index if not exists blog_posts_author_idx on public.blog_posts (author_id);

-- Yayındaki yazının bekleyen revizyonu. Canlı satır yayınlanana kadar değişmez.
create table if not exists public.blog_post_drafts (
  post_id uuid primary key references public.blog_posts(id) on delete cascade,
  payload jsonb not null,
  status text not null default 'draft' check (status in ('draft', 'in_review')),
  review_requested_at timestamptz,
  updated_by uuid,
  updated_at timestamptz not null default now()
);

-- Yayınlanmış yazının eski slug'ları.
create table if not exists public.blog_slug_redirects (
  old_slug text primary key,
  post_id uuid not null references public.blog_posts(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- İçerik → düz metin, okuma süresi, arama belgesi
-- ---------------------------------------------------------------------------
create or replace function public.blog_content_blocks(p_content jsonb)
returns setof jsonb
language sql
immutable
as $$
  with recursive b(block, depth) as (
    select top.value, 0
    from jsonb_array_elements(
      case when jsonb_typeof(p_content -> 'blocks') = 'array'
        then p_content -> 'blocks' else '[]'::jsonb end
    ) as top(value)
    union all
    select inner_block.value, b.depth + 1
    from b
    cross join lateral jsonb_array_elements(
      case when jsonb_typeof(b.block -> 'columns') = 'array'
        then b.block -> 'columns' else '[]'::jsonb end
    ) as col(value)
    cross join lateral jsonb_array_elements(
      case when jsonb_typeof(col.value -> 'blocks') = 'array'
        then col.value -> 'blocks' else '[]'::jsonb end
    ) as inner_block(value)
    where b.depth < 2
  )
  select block from b;
$$;

create or replace function public.blog_content_plain_text(p_content jsonb)
returns text
language sql
immutable
as $$
  select btrim(regexp_replace(
    replace(
      regexp_replace(coalesce(string_agg(t, ' '), ''), '\[([^\]]*)\]\([^)]*\)', '\1', 'g'),
      '*', ''),
    '\s+', ' ', 'g'))
  from (
    select blk ->> 'text' as t from public.blog_content_blocks(p_content) blk
    union all
    select blk ->> 'caption' from public.blog_content_blocks(p_content) blk
    union all
    select blk ->> 'cite' from public.blog_content_blocks(p_content) blk
    union all
    select blk ->> 'label' from public.blog_content_blocks(p_content) blk
    union all
    select item.value #>> '{}'
    from public.blog_content_blocks(p_content) blk
    cross join lateral jsonb_array_elements(
      case when jsonb_typeof(blk -> 'items') = 'array'
        then blk -> 'items' else '[]'::jsonb end
    ) as item(value)
  ) parts
  where t is not null and btrim(t) <> '';
$$;

-- Blok türleri lib/features/blog/models/blog_content.dart ile aynı olmalı.
create or replace function public.blog_content_is_safe(p_content jsonb)
returns boolean
language plpgsql
immutable
as $$
declare
  blk jsonb;
  link text;
  block_count integer := 0;
begin
  if p_content is null or jsonb_typeof(p_content) <> 'object'
     or jsonb_typeof(p_content -> 'blocks') <> 'array' then
    return false;
  end if;
  if pg_column_size(p_content) > 1048576 then
    return false;
  end if;

  for blk in select * from public.blog_content_blocks(p_content) loop
    block_count := block_count + 1;
    if block_count > 600 then
      return false;
    end if;
    if coalesce(blk ->> 'type', '') not in (
      'paragraph', 'heading', 'list', 'quote', 'image', 'video',
      'button', 'divider', 'columns'
    ) then
      return false;
    end if;
    if blk ->> 'type' = 'columns' then
      if jsonb_typeof(blk -> 'columns') <> 'array'
         or jsonb_array_length(blk -> 'columns') not between 2 and 4 then
        return false;
      end if;
      -- İç içe sütun desteklenmez.
      if exists (
        select 1
        from jsonb_array_elements(blk -> 'columns') col(value),
             jsonb_array_elements(coalesce(col.value -> 'blocks', '[]'::jsonb)) inner_block(value)
        where inner_block.value ->> 'type' = 'columns'
      ) then
        return false;
      end if;
    end if;
    if not public.blog_url_is_safe(blk ->> 'url') then
      return false;
    end if;
    if blk ->> 'type' = 'video'
       and coalesce(blk ->> 'source', '') not in ('upload', 'youtube', 'vimeo') then
      return false;
    end if;
    for link in
      select (r.m)[1]
      from regexp_matches(
        concat_ws(' ', blk ->> 'text', blk ->> 'caption',
          (select string_agg(i.value #>> '{}', ' ')
           from jsonb_array_elements(
             case when jsonb_typeof(blk -> 'items') = 'array'
               then blk -> 'items' else '[]'::jsonb end) i(value))),
        '\]\(([^)]*)\)', 'g') as r(m)
    loop
      if not public.blog_url_is_safe(link) or btrim(coalesce(link, '')) = '' then
        return false;
      end if;
    end loop;
  end loop;
  return true;
end;
$$;

create or replace function public.blog_posts_derive()
returns trigger
language plpgsql
as $$
declare
  word_count integer;
begin
  new.search_text := left(public.blog_content_plain_text(new.content), 200000);
  new.search_document := public.blog_normalize(concat_ws(' ',
    new.title, new.subtitle, new.excerpt, new.search_text));
  word_count := coalesce(array_length(regexp_split_to_array(
    btrim(concat_ws(' ', new.title, new.search_text)), '\s+'), 1), 0);
  new.reading_minutes := greatest(1, ceil(word_count / 200.0)::integer);
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists blog_posts_derive_trg on public.blog_posts;
create trigger blog_posts_derive_trg
  before insert or update of title, subtitle, excerpt, content, status, slug,
    cover_url, cover_alt, category_id, author_id, tag_ids, is_featured,
    seo_title, meta_description, published_at
  on public.blog_posts
  for each row execute function public.blog_posts_derive();

-- ---------------------------------------------------------------------------
-- Yetki
-- ---------------------------------------------------------------------------
create or replace function public.blog_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
    and coalesce(public.current_admin_has_module('campaign_content'), false);
$$;

create or replace function public.blog_current_author_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select a.id
  from public.blog_authors a
  where auth.uid() is not null
    and a.user_id = auth.uid()
    and a.is_active = true
  limit 1;
$$;

revoke all on function public.blog_is_admin() from public;
revoke all on function public.blog_current_author_id() from public;
grant execute on function public.blog_is_admin() to authenticated;
grant execute on function public.blog_current_author_id() to authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.blog_categories enable row level security;
alter table public.blog_tags enable row level security;
alter table public.blog_authors enable row level security;
alter table public.blog_posts enable row level security;
alter table public.blog_post_drafts enable row level security;
alter table public.blog_slug_redirects enable row level security;

drop policy if exists blog_categories_read on public.blog_categories;
create policy blog_categories_read on public.blog_categories
  for select using (is_active = true or public.blog_is_admin());
drop policy if exists blog_categories_admin_write on public.blog_categories;
create policy blog_categories_admin_write on public.blog_categories
  for all to authenticated
  using (public.blog_is_admin()) with check (public.blog_is_admin());

drop policy if exists blog_tags_read on public.blog_tags;
create policy blog_tags_read on public.blog_tags for select using (true);
drop policy if exists blog_tags_admin_write on public.blog_tags;
create policy blog_tags_admin_write on public.blog_tags
  for all to authenticated
  using (public.blog_is_admin()) with check (public.blog_is_admin());

-- Yazar satırı user_id içerdiği için herkese açık değil; okuyucu RPC'leri
-- yalnızca görünen ad / slug / bio / avatar döndürür.
drop policy if exists blog_authors_read on public.blog_authors;
create policy blog_authors_read on public.blog_authors
  for select to authenticated
  using (public.blog_is_admin() or user_id = auth.uid());
drop policy if exists blog_authors_admin_write on public.blog_authors;
create policy blog_authors_admin_write on public.blog_authors
  for all to authenticated
  using (public.blog_is_admin()) with check (public.blog_is_admin());

-- Yazılar: yazma politikası yok (yalnızca RPC). Okuma yalnızca yönetici /
-- kendi yazısının yazarı; herkese açık okuma blog_list_posts / blog_get_post.
drop policy if exists blog_posts_owner_read on public.blog_posts;
create policy blog_posts_owner_read on public.blog_posts
  for select to authenticated
  using (public.blog_is_admin() or author_id = public.blog_current_author_id());

drop policy if exists blog_post_drafts_owner_read on public.blog_post_drafts;
create policy blog_post_drafts_owner_read on public.blog_post_drafts
  for select to authenticated
  using (
    public.blog_is_admin()
    or exists (
      select 1 from public.blog_posts p
      where p.id = post_id and p.author_id = public.blog_current_author_id()
    )
  );

-- blog_slug_redirects: politika yok → yalnızca RPC.

-- ---------------------------------------------------------------------------
-- Medya: public okuma, yazma yalnızca yazar/yönetici ve kendi uid klasörü.
-- Limitler mevcut ürün videosu sınırıyla aynı (30 MB).
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'blog-media', 'blog-media', true, 31457280,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif',
        'video/mp4', 'video/webm', 'video/quicktime']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists blog_media_writer_select on storage.objects;
create policy blog_media_writer_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'blog-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists blog_media_writer_insert on storage.objects;
create policy blog_media_writer_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'blog-media'
    and (storage.foldername(name))[1] = auth.uid()::text
    and (public.blog_is_admin() or public.blog_current_author_id() is not null)
  );

drop policy if exists blog_media_writer_update on storage.objects;
create policy blog_media_writer_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'blog-media'
    and (storage.foldername(name))[1] = auth.uid()::text
    and (public.blog_is_admin() or public.blog_current_author_id() is not null)
  );

drop policy if exists blog_media_writer_delete on storage.objects;
create policy blog_media_writer_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'blog-media'
    and (storage.foldername(name))[1] = auth.uid()::text
    and (public.blog_is_admin() or public.blog_current_author_id() is not null)
  );

notify pgrst, 'reload schema';
