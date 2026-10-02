-- İBUL Blog v1 — okuyucu RPC'leri. 20261002_blog_1_schema.sql sonrasında uygulanır.
-- Hata kodları istemcide `BlogRepository` tarafından kullanıcı mesajına çevrilir.


-- ---------------------------------------------------------------------------
-- Okuyucu (anon + authenticated)
-- ---------------------------------------------------------------------------
create or replace function public.blog_list_categories()
returns table (id uuid, name text, slug text, description text, sort_order integer)
language sql
stable
security definer
set search_path = public
as $$
  select c.id, c.name, c.slug, c.description, c.sort_order
  from public.blog_categories c
  where c.is_active = true
  order by c.sort_order, c.name;
$$;

create or replace function public.blog_list_posts(
  p_search text default null,
  p_category text default null,
  p_featured boolean default null,
  p_exclude uuid default null,
  p_limit integer default 12,
  p_offset integer default 0
)
returns table (
  id uuid,
  slug text,
  title text,
  subtitle text,
  excerpt text,
  cover_url text,
  cover_alt text,
  category_name text,
  category_slug text,
  author_name text,
  author_slug text,
  is_featured boolean,
  reading_minutes integer,
  published_at timestamptz,
  updated_at timestamptz,
  total_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with terms as (
    select t
    from unnest(string_to_array(public.blog_normalize(left(coalesce(p_search, ''), 120)), ' ')) t
    where t <> ''
  )
  select
    p.id, p.slug, p.title, p.subtitle, p.excerpt, p.cover_url, p.cover_alt,
    c.name, c.slug, a.display_name, a.slug, p.is_featured, p.reading_minutes,
    p.published_at, p.updated_at,
    count(*) over ()
  from public.blog_posts p
  left join public.blog_categories c on c.id = p.category_id
  left join public.blog_authors a on a.id = p.author_id
  where p.status = 'published'
    and p.published_at <= now()
    and (nullif(btrim(p_category), '') is null or c.slug = btrim(p_category))
    and (p_featured is null or p.is_featured = p_featured)
    and (p_exclude is null or p.id <> p_exclude)
    and not exists (
      select 1 from terms where position(terms.t in p.search_document) = 0
    )
  order by p.published_at desc, p.id
  limit least(greatest(coalesce(p_limit, 12), 1), 48)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

create or replace function public.blog_post_json(p public.blog_posts)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', p.id,
    'slug', p.slug,
    'title', p.title,
    'subtitle', p.subtitle,
    'excerpt', p.excerpt,
    'cover_url', p.cover_url,
    'cover_alt', p.cover_alt,
    'is_featured', p.is_featured,
    'seo_title', p.seo_title,
    'meta_description', p.meta_description,
    'content', p.content,
    'reading_minutes', p.reading_minutes,
    'published_at', p.published_at,
    'updated_at', p.updated_at,
    'category', (
      select jsonb_build_object('id', c.id, 'name', c.name, 'slug', c.slug)
      from public.blog_categories c where c.id = p.category_id
    ),
    'author', (
      select jsonb_build_object(
        'id', a.id, 'display_name', a.display_name, 'slug', a.slug,
        'bio', a.bio, 'avatar_url', a.avatar_url)
      from public.blog_authors a where a.id = p.author_id
    ),
    'tags', coalesce((
      select jsonb_agg(jsonb_build_object('id', t.id, 'name', t.name, 'slug', t.slug) order by t.name)
      from public.blog_tags t where t.id = any(p.tag_ids)
    ), '[]'::jsonb)
  );
$$;

-- Yayındaki yazı; değilse eski slug için {"redirect_slug": ...}; yoksa null.
create or replace function public.blog_get_post(p_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_post public.blog_posts;
  v_redirect text;
begin
  select * into v_post
  from public.blog_posts p
  where p.slug = btrim(p_slug)
    and p.status = 'published'
    and p.published_at <= now();
  if found then
    return public.blog_post_json(v_post);
  end if;

  select p.slug into v_redirect
  from public.blog_slug_redirects r
  join public.blog_posts p on p.id = r.post_id
  where r.old_slug = btrim(p_slug)
    and p.status = 'published'
    and p.published_at <= now();
  if v_redirect is not null then
    return jsonb_build_object('redirect_slug', v_redirect);
  end if;
  return null;
end;
$$;

-- Statik ön-render (scripts/prerender_blog.py) için eski → güncel slug.
create or replace function public.blog_list_public_redirects()
returns table (old_slug text, slug text)
language sql
stable
security definer
set search_path = public
as $$
  select r.old_slug, p.slug
  from public.blog_slug_redirects r
  join public.blog_posts p on p.id = r.post_id
  where p.status = 'published' and p.published_at <= now()
  order by r.old_slug;
$$;

-- Yetkiler

revoke all on function public.blog_list_categories() from public;
revoke all on function public.blog_list_posts(text, text, boolean, uuid, integer, integer) from public;
revoke all on function public.blog_get_post(text) from public;
revoke all on function public.blog_list_public_redirects() from public;
revoke all on function public.blog_post_json(public.blog_posts) from public;

grant execute on function public.blog_list_categories() to anon, authenticated;
grant execute on function public.blog_list_posts(text, text, boolean, uuid, integer, integer) to anon, authenticated;
grant execute on function public.blog_get_post(text) to anon, authenticated;
grant execute on function public.blog_list_public_redirects() to anon, authenticated;

notify pgrst, 'reload schema';
