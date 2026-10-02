-- İBUL Blog v1 — yönetim listeleri. 20261002_blog_3_rpc_write.sql sonrasında uygulanır.
-- Hata kodları istemcide `BlogRepository` tarafından kullanıcı mesajına çevrilir.

create or replace function public.blog_admin_list_posts(
  p_search text default null,
  p_status text default null,
  p_limit integer default 30,
  p_offset integer default 0
)
returns table (
  id uuid,
  slug text,
  title text,
  status text,
  revision_status text,
  author_name text,
  category_name text,
  published_at timestamptz,
  updated_at timestamptz,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_admin boolean;
  v_author uuid;
  v_search text := public.blog_normalize(btrim(coalesce(p_search, '')));
begin
  perform public.blog_require_writer();
  v_admin := public.blog_is_admin();
  v_author := public.blog_current_author_id();
  return query
  select
    p.id,
    coalesce(d.payload ->> 'slug', p.slug),
    coalesce(d.payload ->> 'title', p.title),
    p.status,
    d.status,
    a.display_name,
    c.name,
    p.published_at,
    greatest(p.updated_at, coalesce(d.updated_at, p.updated_at)),
    count(*) over ()
  from public.blog_posts p
  left join public.blog_post_drafts d on d.post_id = p.id
  left join public.blog_authors a
    on a.id = coalesce(nullif(d.payload ->> 'author_id', '')::uuid, p.author_id)
  left join public.blog_categories c
    on c.id = case when d.post_id is not null
      then nullif(d.payload ->> 'category_id', '')::uuid else p.category_id end
  where (v_admin or p.author_id = v_author)
    and (
      nullif(p_status, '') is null
      or (p_status = 'in_review' and (p.status = 'in_review' or d.status = 'in_review'))
      or (p_status <> 'in_review' and p.status = p_status)
    )
    and (v_search = '' or position(v_search in public.blog_normalize(
      coalesce(d.payload ->> 'title', p.title) || ' ' || coalesce(d.payload ->> 'slug', p.slug))) > 0)
  order by greatest(p.updated_at, coalesce(d.updated_at, p.updated_at)) desc, p.id
  limit least(greatest(coalesce(p_limit, 30), 1), 100)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function public.blog_admin_list_authors()
returns table (
  id uuid, display_name text, slug text, bio text, avatar_url text,
  is_active boolean, user_id uuid, user_email text, post_count bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.blog_is_admin() then
    raise exception 'blog_forbidden' using errcode = '42501';
  end if;
  return query
  select a.id, a.display_name, a.slug, a.bio, a.avatar_url, a.is_active,
    a.user_id, u.email::text,
    (select count(*) from public.blog_posts p where p.author_id = a.id)
  from public.blog_authors a
  left join public.users u on u.id = a.user_id
  order by a.display_name;
end;
$$;

create or replace function public.blog_admin_upsert_author(
  p_id uuid,
  p_display_name text,
  p_slug text,
  p_bio text,
  p_avatar_url text,
  p_user_email text,
  p_is_active boolean
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_slug text := public.blog_slugify(coalesce(nullif(btrim(p_slug), ''), p_display_name));
  v_id uuid;
begin
  if not public.blog_is_admin() then
    raise exception 'blog_forbidden' using errcode = '42501';
  end if;
  if coalesce(btrim(p_display_name), '') = '' or v_slug = '' then
    raise exception 'blog_author_required' using errcode = '22023';
  end if;
  if not public.blog_url_is_safe(p_avatar_url) then
    raise exception 'blog_invalid_content' using errcode = '22023';
  end if;
  if nullif(btrim(p_user_email), '') is not null then
    select u.id into v_user from public.users u
    where lower(u.email) = lower(btrim(p_user_email)) limit 1;
    if v_user is null then
      raise exception 'blog_user_not_found' using errcode = 'P0002';
    end if;
  end if;

  if p_id is null then
    insert into public.blog_authors (user_id, display_name, slug, bio, avatar_url, is_active)
    values (v_user, btrim(p_display_name), v_slug, nullif(btrim(p_bio), ''),
      nullif(btrim(p_avatar_url), ''), coalesce(p_is_active, true))
    returning id into v_id;
  else
    update public.blog_authors set
      user_id = v_user,
      display_name = btrim(p_display_name),
      slug = v_slug,
      bio = nullif(btrim(p_bio), ''),
      avatar_url = nullif(btrim(p_avatar_url), ''),
      is_active = coalesce(p_is_active, true),
      updated_at = now()
    where id = p_id
    returning id into v_id;
    if v_id is null then
      raise exception 'blog_not_found' using errcode = 'P0002';
    end if;
  end if;
  return v_id;
end;
$$;

-- Yetkiler

revoke all on function public.blog_admin_list_posts(text, text, integer, integer) from public;
revoke all on function public.blog_admin_list_authors() from public;
revoke all on function public.blog_admin_upsert_author(uuid, text, text, text, text, text, boolean) from public;

grant execute on function public.blog_admin_list_posts(text, text, integer, integer) to authenticated;
grant execute on function public.blog_admin_list_authors() to authenticated;
grant execute on function public.blog_admin_upsert_author(uuid, text, text, text, text, text, boolean) to authenticated;

notify pgrst, 'reload schema';
