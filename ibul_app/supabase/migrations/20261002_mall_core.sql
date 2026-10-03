-- AVM çekirdeği: malls + mall_members.
-- malls bir seller store değildir. stores / users / campaigns tablolarına dokunulmaz.
-- mall_members.role, public.users.role yerine geçmez. Aynı kişi seller ve mall_manager olabilir.
-- mall_members için client INSERT/UPDATE/DELETE yok.
-- malls yazımı yalnız is_admin_user(). Mall manager update policy yok.
-- Sonraki faz: admin approval RPC mall satırını ve mall_manager üyeliğini üretir.

create extension if not exists pgcrypto;

-- Ortak updated_at helper yok. Bu feature için tek fonksiyon; iki tablo aynı trigger'ı kullanır.
create or replace function public.mall_set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

-- İstemci JWT'si status / is_verified değiştiremesin.
-- Admin (is_admin_user), service role ve postgres/supabase_admin oturumu serbest.
-- Fonksiyon SECURITY INVOKER: current_user, SECURITY DEFINER owner'a dönmesin.
create or replace function public.mall_protect_privileged_columns()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if public.session_is_service_role()
     or public.is_admin_user(auth.uid())
     or current_user in ('postgres', 'supabase_admin') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.is_verified := false;
    new.status := 'draft';
    return new;
  end if;

  new.status := old.status;
  new.is_verified := old.is_verified;
  return new;
end;
$$;

revoke all on function public.mall_set_updated_at() from public;
revoke all on function public.mall_protect_privileged_columns() from public;
revoke all on function public.mall_set_updated_at() from anon;
revoke all on function public.mall_protect_privileged_columns() from anon;
grant execute on function public.mall_set_updated_at() to authenticated;
grant execute on function public.mall_protect_privileged_columns() to authenticated;

-- ---------------------------------------------------------------------------
-- malls
-- ---------------------------------------------------------------------------

create table if not exists public.malls (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null,
  legal_name text,
  status text not null default 'draft',
  city text not null,
  district text not null,
  address_text text not null,
  latitude double precision not null,
  longitude double precision not null,
  phone text,
  website text,
  logo_url text,
  cover_url text,
  is_verified boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint malls_name_not_blank check (char_length(btrim(name)) between 1 and 160),
  constraint malls_slug_format check (
    slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
    and char_length(slug) between 1 and 120
  ),
  constraint malls_legal_name_not_blank check (
    legal_name is null or char_length(btrim(legal_name)) between 1 and 200
  ),
  constraint malls_status_check check (
    status in ('draft', 'pending_review', 'active', 'suspended', 'archived')
  ),
  constraint malls_city_not_blank check (char_length(btrim(city)) between 1 and 80),
  constraint malls_district_not_blank check (char_length(btrim(district)) between 1 and 80),
  constraint malls_address_not_blank check (char_length(btrim(address_text)) between 1 and 500),
  constraint malls_latitude_range check (latitude >= -90 and latitude <= 90),
  constraint malls_longitude_range check (longitude >= -180 and longitude <= 180),
  constraint malls_phone_not_blank check (
    phone is null or char_length(btrim(phone)) between 1 and 40
  ),
  constraint malls_website_not_blank check (
    website is null or char_length(btrim(website)) between 1 and 300
  ),
  constraint malls_logo_url_not_blank check (
    logo_url is null or char_length(btrim(logo_url)) between 1 and 2000
  ),
  constraint malls_cover_url_not_blank check (
    cover_url is null or char_length(btrim(cover_url)) between 1 and 2000
  ),
  constraint malls_slug_unique unique (slug)
);

create index if not exists idx_malls_status on public.malls (status);

comment on table public.malls is
  'AVM organizasyonu. Seller store değildir. public.stores ile FK/inheritance yok.';
comment on column public.malls.slug is
  'Benzersiz, küçük harf slug. Format blog_slugify çıktısıyla aynıdır; üretim bu dosyada yok.';
comment on column public.malls.status is
  'draft | pending_review | active | suspended | archived. Client yükseltmesi kapalı.';
comment on column public.malls.is_verified is
  'Client tarafından yükseltilemez. Admin / service role / postgres oturumu değiştirebilir.';

drop trigger if exists malls_protect_privileged_columns on public.malls;
create trigger malls_protect_privileged_columns
before insert or update on public.malls
for each row execute function public.mall_protect_privileged_columns();

drop trigger if exists malls_set_updated_at on public.malls;
create trigger malls_set_updated_at
before insert or update on public.malls
for each row execute function public.mall_set_updated_at();

-- ---------------------------------------------------------------------------
-- mall_members
-- ---------------------------------------------------------------------------

create table if not exists public.mall_members (
  id uuid primary key default gen_random_uuid(),
  mall_id uuid not null references public.malls (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  role text not null,
  status text not null default 'active',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  created_by uuid references public.users (id) on delete set null,
  constraint mall_members_role_check check (
    role in (
      'mall_manager',
      'mall_ad_manager',
      'mall_content_editor',
      'mall_store_manager'
    )
  ),
  constraint mall_members_status_check check (
    status in ('active', 'invited', 'suspended', 'removed')
  ),
  constraint mall_members_mall_user_unique unique (mall_id, user_id)
);

create index if not exists idx_mall_members_user_status
  on public.mall_members (user_id, status);

create index if not exists idx_mall_members_mall_status
  on public.mall_members (mall_id, status);

comment on table public.mall_members is
  'AVM üyelik kaydı. public.users.role kolonuna yazılmaz.';
comment on column public.mall_members.role is
  'mall_manager | mall_ad_manager | mall_content_editor | mall_store_manager. users.role değildir.';
comment on column public.mall_members.user_id is
  'public.users.id. Bu id auth.users.id ile aynı uuid''dir.';

drop trigger if exists mall_members_set_updated_at on public.mall_members;
create trigger mall_members_set_updated_at
before insert or update on public.mall_members
for each row execute function public.mall_set_updated_at();

-- ---------------------------------------------------------------------------
-- Role check. Boolean only. SECURITY DEFINER so mall RLS policies do not recurse.
-- Caller cannot pass a user id; membership is always auth.uid().
-- ---------------------------------------------------------------------------

create or replace function public.mall_member_has_role(
  p_mall_id uuid,
  p_roles text[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_mall_id is not null
    and auth.uid() is not null
    and coalesce(cardinality(p_roles), 0) > 0
    and exists (
      select 1
      from public.mall_members m
      where m.mall_id = p_mall_id
        and m.user_id = auth.uid()
        and m.status = 'active'
        and m.role = any (p_roles)
    );
$$;

comment on function public.mall_member_has_role(uuid, text[]) is
  'auth.uid() aktif ve istenen rollerden birine sahip mi? Satır döndürmez.';

revoke all on function public.mall_member_has_role(uuid, text[]) from public;
revoke all on function public.mall_member_has_role(uuid, text[]) from anon;
grant execute on function public.mall_member_has_role(uuid, text[]) to authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.malls enable row level security;
alter table public.mall_members enable row level security;

revoke all on table public.malls from public;
revoke all on table public.malls from anon, authenticated;
grant select on table public.malls to anon, authenticated;
grant insert, update, delete on table public.malls to authenticated;

revoke all on table public.mall_members from public;
revoke all on table public.mall_members from anon, authenticated;
grant select on table public.mall_members to authenticated;

drop policy if exists malls_select_active on public.malls;
create policy malls_select_active
on public.malls
for select
to anon, authenticated
using (status = 'active');

drop policy if exists malls_select_member on public.malls;
create policy malls_select_member
on public.malls
for select
to authenticated
using (
  public.mall_member_has_role(
    id,
    array[
      'mall_manager',
      'mall_ad_manager',
      'mall_content_editor',
      'mall_store_manager'
    ]
  )
);

drop policy if exists malls_admin_select on public.malls;
create policy malls_admin_select
on public.malls
for select
to authenticated
using (public.is_admin_user());

drop policy if exists malls_admin_insert on public.malls;
create policy malls_admin_insert
on public.malls
for insert
to authenticated
with check (public.is_admin_user());

drop policy if exists malls_admin_update on public.malls;
create policy malls_admin_update
on public.malls
for update
to authenticated
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists malls_admin_delete on public.malls;
create policy malls_admin_delete
on public.malls
for delete
to authenticated
using (public.is_admin_user());

drop policy if exists mall_members_select_own on public.mall_members;
create policy mall_members_select_own
on public.mall_members
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists mall_members_select_manager on public.mall_members;
create policy mall_members_select_manager
on public.mall_members
for select
to authenticated
using (
  public.mall_member_has_role(mall_id, array['mall_manager'])
);

drop policy if exists mall_members_select_admin on public.mall_members;
create policy mall_members_select_admin
on public.mall_members
for select
to authenticated
using (public.is_admin_user());
