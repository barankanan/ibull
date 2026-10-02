-- İBUL Blog v1 — yazar/editör RPC'leri. 20261002_blog_2_rpc_public.sql sonrasında uygulanır.
-- Hata kodları istemcide `BlogRepository` tarafından kullanıcı mesajına çevrilir.

-- ---------------------------------------------------------------------------
-- Yönetim (authenticated)
-- ---------------------------------------------------------------------------
create or replace function public.blog_my_access()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'is_admin', public.blog_is_admin(),
    'author_id', a.id,
    'author_name', a.display_name
  )
  from (select 1) one
  left join public.blog_authors a
    on a.id = public.blog_current_author_id();
$$;

create or replace function public.blog_require_writer()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'blog_not_authenticated' using errcode = '42501';
  end if;
  if not public.blog_is_admin() and public.blog_current_author_id() is null then
    raise exception 'blog_forbidden' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.blog_load_post_for_write(p_post_id uuid)
returns public.blog_posts
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post public.blog_posts;
begin
  perform public.blog_require_writer();
  select * into v_post from public.blog_posts where id = p_post_id for update;
  if not found then
    raise exception 'blog_not_found' using errcode = 'P0002';
  end if;
  if not public.blog_is_admin()
     and v_post.author_id is distinct from public.blog_current_author_id() then
    raise exception 'blog_forbidden' using errcode = '42501';
  end if;
  return v_post;
end;
$$;

-- Editörün gördüğü hâl: bekleyen revizyon varsa onun içeriği.
create or replace function public.blog_get_editable_post(p_post_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_post public.blog_posts;
  v_draft public.blog_post_drafts;
  v_base jsonb;
begin
  perform public.blog_require_writer();
  select * into v_post from public.blog_posts where id = p_post_id;
  if not found then
    raise exception 'blog_not_found' using errcode = 'P0002';
  end if;
  if not public.blog_is_admin()
     and v_post.author_id is distinct from public.blog_current_author_id() then
    raise exception 'blog_forbidden' using errcode = '42501';
  end if;

  v_base := public.blog_post_json(v_post) || jsonb_build_object(
    'status', v_post.status,
    'category_id', v_post.category_id,
    'author_id', v_post.author_id,
    'tag_ids', to_jsonb(v_post.tag_ids),
    'revision_status', null,
    'live_slug', case when v_post.status = 'published' then v_post.slug end
  );

  select * into v_draft from public.blog_post_drafts where post_id = p_post_id;
  if found then
    v_base := v_base || v_draft.payload || jsonb_build_object(
      'revision_status', v_draft.status,
      'updated_at', v_draft.updated_at,
      'category', (
        select jsonb_build_object('id', c.id, 'name', c.name, 'slug', c.slug)
        from public.blog_categories c
        where c.id = nullif(v_draft.payload ->> 'category_id', '')::uuid
      ),
      'author', (
        select jsonb_build_object('id', a.id, 'display_name', a.display_name,
          'slug', a.slug, 'bio', a.bio, 'avatar_url', a.avatar_url)
        from public.blog_authors a
        where a.id = nullif(v_draft.payload ->> 'author_id', '')::uuid
      )
    );
  end if;
  return v_base;
end;
$$;

-- Payload'ı doğrular ve kanonik biçime çevirir.
create or replace function public.blog_normalize_payload(
  p_payload jsonb,
  p_existing public.blog_posts
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_admin boolean := public.blog_is_admin();
  v_title text := left(btrim(coalesce(p_payload ->> 'title', '')), 200);
  v_slug text;
  v_author uuid;
  v_category uuid;
  v_tags uuid[];
  v_published_at timestamptz;
  v_featured boolean;
begin
  if v_title = '' then
    raise exception 'blog_title_required' using errcode = '22023';
  end if;
  if not public.blog_content_is_safe(p_payload -> 'content') then
    raise exception 'blog_invalid_content' using errcode = '22023';
  end if;
  if not public.blog_url_is_safe(p_payload ->> 'cover_url') then
    raise exception 'blog_invalid_content' using errcode = '22023';
  end if;

  v_slug := left(public.blog_slugify(
    coalesce(nullif(btrim(p_payload ->> 'slug'), ''), v_title)), 120);
  v_slug := btrim(v_slug, '-');
  if v_slug = '' or v_slug in ('onizleme', 'yazar', 'kategori', 'etiket', 'arama') then
    raise exception 'blog_invalid_slug' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.blog_posts
    where slug = v_slug and id is distinct from p_existing.id
  ) or exists (
    select 1 from public.blog_slug_redirects
    where old_slug = v_slug and post_id is distinct from p_existing.id
  ) or exists (
    select 1 from public.blog_post_drafts d
    where d.payload ->> 'slug' = v_slug and d.post_id is distinct from p_existing.id
  ) then
    raise exception 'blog_slug_taken' using errcode = '23505';
  end if;

  if v_admin then
    v_author := coalesce(
      nullif(p_payload ->> 'author_id', '')::uuid,
      p_existing.author_id,
      public.blog_current_author_id());
    v_featured := coalesce((p_payload ->> 'is_featured')::boolean, false);
    -- Editör mevcut tarihi geri gönderir; boş = yayınlanınca şimdi.
    v_published_at := nullif(p_payload ->> 'published_at', '')::timestamptz;
  else
    -- Yazar başkası adına yazamaz; öne çıkarma ve yayın tarihi yönetici kararı.
    v_author := coalesce(p_existing.author_id, public.blog_current_author_id());
    v_featured := coalesce(p_existing.is_featured, false);
    v_published_at := p_existing.published_at;
  end if;
  if v_author is null or not exists (select 1 from public.blog_authors where id = v_author) then
    raise exception 'blog_author_required' using errcode = '22023';
  end if;

  v_category := nullif(p_payload ->> 'category_id', '')::uuid;
  if v_category is not null
     and not exists (select 1 from public.blog_categories where id = v_category) then
    raise exception 'blog_invalid_category' using errcode = '22023';
  end if;

  select coalesce(array_agg(t.id), '{}'::uuid[]) into v_tags
  from public.blog_tags t
  where t.id in (
    select value::uuid
    from jsonb_array_elements_text(
      case when jsonb_typeof(p_payload -> 'tag_ids') = 'array'
        then p_payload -> 'tag_ids' else '[]'::jsonb end)
  );

  return jsonb_build_object(
    'title', v_title,
    'subtitle', nullif(left(btrim(coalesce(p_payload ->> 'subtitle', '')), 300), ''),
    'slug', v_slug,
    'excerpt', nullif(left(btrim(coalesce(p_payload ->> 'excerpt', '')), 600), ''),
    'cover_url', nullif(btrim(coalesce(p_payload ->> 'cover_url', '')), ''),
    'cover_alt', nullif(left(btrim(coalesce(p_payload ->> 'cover_alt', '')), 300), ''),
    'category_id', v_category,
    'author_id', v_author,
    'tag_ids', to_jsonb(v_tags),
    'is_featured', v_featured,
    'published_at', v_published_at,
    'seo_title', nullif(left(btrim(coalesce(p_payload ->> 'seo_title', '')), 120), ''),
    'meta_description', nullif(left(btrim(coalesce(p_payload ->> 'meta_description', '')), 320), ''),
    'content', p_payload -> 'content'
  );
end;
$$;

-- Kanonik payload'ı canlı satıra uygular; daha önce yayınlanmış yazının
-- slug'ı değişirse eski slug yönlendirmeye eklenir.
create or replace function public.blog_apply_payload(p_post public.blog_posts, p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_slug text := p_payload ->> 'slug';
begin
  if p_post.first_published_at is not null and p_post.slug <> v_new_slug then
    insert into public.blog_slug_redirects (old_slug, post_id)
    values (p_post.slug, p_post.id)
    on conflict (old_slug) do update set post_id = excluded.post_id;
  end if;
  delete from public.blog_slug_redirects where old_slug = v_new_slug;

  update public.blog_posts set
    title = p_payload ->> 'title',
    subtitle = p_payload ->> 'subtitle',
    slug = v_new_slug,
    excerpt = p_payload ->> 'excerpt',
    cover_url = p_payload ->> 'cover_url',
    cover_alt = p_payload ->> 'cover_alt',
    category_id = nullif(p_payload ->> 'category_id', '')::uuid,
    author_id = (p_payload ->> 'author_id')::uuid,
    tag_ids = coalesce(array(select jsonb_array_elements_text(p_payload -> 'tag_ids'))::uuid[], '{}'),
    is_featured = coalesce((p_payload ->> 'is_featured')::boolean, false),
    published_at = nullif(p_payload ->> 'published_at', '')::timestamptz,
    seo_title = p_payload ->> 'seo_title',
    meta_description = p_payload ->> 'meta_description',
    content = p_payload -> 'content',
    updated_by = auth.uid()
  where id = p_post.id;
end;
$$;

create or replace function public.blog_save_post(p_post_id uuid, p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post public.blog_posts;
  v_payload jsonb;
  v_id uuid;
begin
  perform public.blog_require_writer();
  if p_post_id is null then
    v_payload := public.blog_normalize_payload(p_payload, null::public.blog_posts);
    insert into public.blog_posts (slug, title, author_id, created_by, updated_by)
    values (v_payload ->> 'slug', v_payload ->> 'title',
      (v_payload ->> 'author_id')::uuid, auth.uid(), auth.uid())
    returning * into v_post;
    perform public.blog_apply_payload(v_post, v_payload);
    v_id := v_post.id;
  else
    v_post := public.blog_load_post_for_write(p_post_id);
    v_payload := public.blog_normalize_payload(p_payload, v_post);
    v_id := v_post.id;
    if v_post.status = 'published' then
      insert into public.blog_post_drafts (post_id, payload, status, updated_by, updated_at)
      values (v_id, v_payload, 'draft', auth.uid(), now())
      on conflict (post_id) do update
        set payload = excluded.payload,
            updated_by = excluded.updated_by,
            updated_at = excluded.updated_at;
    else
      perform public.blog_apply_payload(v_post, v_payload);
    end if;
  end if;
  return public.blog_get_editable_post(v_id);
end;
$$;

create or replace function public.blog_submit_for_review(p_post_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post public.blog_posts;
begin
  v_post := public.blog_load_post_for_write(p_post_id);
  if v_post.status = 'published' then
    update public.blog_post_drafts
    set status = 'in_review', review_requested_at = now()
    where post_id = p_post_id;
    if not found then
      raise exception 'blog_no_revision' using errcode = '22023';
    end if;
  else
    update public.blog_posts
    set status = 'in_review', review_requested_at = now(), updated_by = auth.uid()
    where id = p_post_id;
  end if;
  return public.blog_get_editable_post(p_post_id);
end;
$$;

create or replace function public.blog_publish_post(p_post_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post public.blog_posts;
  v_draft public.blog_post_drafts;
begin
  if not public.blog_is_admin() then
    raise exception 'blog_forbidden' using errcode = '42501';
  end if;
  v_post := public.blog_load_post_for_write(p_post_id);
  select * into v_draft from public.blog_post_drafts where post_id = p_post_id;
  if found then
    -- Revizyonun yazarı/tarihi yeniden doğrulanır (arada slug alınmış olabilir).
    perform public.blog_apply_payload(v_post,
      public.blog_normalize_payload(v_draft.payload, v_post));
    delete from public.blog_post_drafts where post_id = p_post_id;
  end if;
  if coalesce(btrim((select title from public.blog_posts where id = p_post_id)), '') = '' then
    raise exception 'blog_title_required' using errcode = '22023';
  end if;
  update public.blog_posts set
    status = 'published',
    published_at = coalesce(published_at, now()),
    first_published_at = coalesce(first_published_at, now()),
    unpublished_at = null,
    updated_by = auth.uid()
  where id = p_post_id;
  return public.blog_get_editable_post(p_post_id);
end;
$$;

-- Yayından kaldırır ya da incelemedeki yazıyı/revizyonu taslağa döndürür.
create or replace function public.blog_unpublish_post(p_post_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post public.blog_posts;
begin
  if not public.blog_is_admin() then
    raise exception 'blog_forbidden' using errcode = '42501';
  end if;
  v_post := public.blog_load_post_for_write(p_post_id);
  update public.blog_post_drafts set status = 'draft' where post_id = p_post_id;
  update public.blog_posts set
    status = 'draft',
    unpublished_at = case when v_post.status = 'published' then now() else unpublished_at end,
    updated_by = auth.uid()
  where id = p_post_id;
  return public.blog_get_editable_post(p_post_id);
end;
$$;

-- Yetkiler

revoke all on function public.blog_my_access() from public;
revoke all on function public.blog_require_writer() from public;
revoke all on function public.blog_load_post_for_write(uuid) from public;
revoke all on function public.blog_get_editable_post(uuid) from public;
revoke all on function public.blog_normalize_payload(jsonb, public.blog_posts) from public;
revoke all on function public.blog_apply_payload(public.blog_posts, jsonb) from public;
revoke all on function public.blog_save_post(uuid, jsonb) from public;
revoke all on function public.blog_submit_for_review(uuid) from public;
revoke all on function public.blog_publish_post(uuid) from public;
revoke all on function public.blog_unpublish_post(uuid) from public;

grant execute on function public.blog_my_access() to authenticated;
grant execute on function public.blog_get_editable_post(uuid) to authenticated;
grant execute on function public.blog_save_post(uuid, jsonb) to authenticated;
grant execute on function public.blog_submit_for_review(uuid) to authenticated;
grant execute on function public.blog_publish_post(uuid) to authenticated;
grant execute on function public.blog_unpublish_post(uuid) to authenticated;

notify pgrst, 'reload schema';
