-- Taslak kaydı yazar imzası ve başlık beklemez. Yayın ayrı doğrulanır.
-- 20261002_blog_3_rpc_write.sql daha önce uygulandıysa bu dosya iki
-- fonksiyonu günceller. Yeni kurulumda 3. dosyadaki tanımla aynıdır.

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
  if not public.blog_content_is_safe(p_payload -> 'content') then
    raise exception 'blog_invalid_content' using errcode = '22023';
  end if;
  if not public.blog_url_is_safe(p_payload ->> 'cover_url') then
    raise exception 'blog_invalid_content' using errcode = '22023';
  end if;

  v_slug := left(public.blog_slugify(
    coalesce(nullif(btrim(p_payload ->> 'slug'), ''), v_title)), 120);
  v_slug := btrim(v_slug, '-');
  -- Taslakta başlık/slug boş olabilir; yayın kontrolü blog_publish_post içindedir.
  if v_slug = '' then
    v_slug := 'taslak-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 10);
  elsif v_slug in ('onizleme', 'yazar', 'kategori', 'etiket', 'arama') then
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
  -- Yazar imzası taslakta boş kalabilir. Geçersiz bir id yine reddedilir.
  -- created_by / updated_by oturum kullanıcısıdır; imzayla karışmaz.
  if v_author is not null
     and not exists (select 1 from public.blog_authors where id = v_author) then
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
  if (select author_id from public.blog_posts where id = p_post_id) is null then
    raise exception 'blog_author_required' using errcode = '22023';
  end if;
  if coalesce(btrim((select cover_url from public.blog_posts where id = p_post_id)), '') <> ''
     and coalesce(btrim((select cover_alt from public.blog_posts where id = p_post_id)), '') = '' then
    raise exception 'blog_cover_alt_required' using errcode = '22023';
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

notify pgrst, 'reload schema';
