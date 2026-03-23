create table if not exists public.product_lists (
  id text primary key,
  owner_user_id uuid not null references public.users(id) on delete cascade,
  owner_display_name text,
  owner_photo_url text,
  name text not null,
  description text,
  cover_image_url text,
  visibility text not null default 'private'
    check (visibility in ('private', 'public')),
  share_code text not null unique,
  product_count integer not null default 0,
  follower_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_list_items (
  id bigint generated always as identity primary key,
  list_id text not null references public.product_lists(id) on delete cascade,
  product_key text not null,
  product_id text,
  product_name text not null,
  brand text,
  store_name text,
  seller_id text,
  price_at_save numeric(12,2),
  old_price_at_save numeric(12,2),
  product_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create unique index if not exists idx_product_list_items_unique
  on public.product_list_items(list_id, product_key);

create index if not exists idx_product_list_items_list_id
  on public.product_list_items(list_id, created_at desc);

create table if not exists public.product_list_follows (
  list_id text not null references public.product_lists(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  notifications_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (list_id, user_id)
);

create index if not exists idx_product_list_follows_user_id
  on public.product_list_follows(user_id, created_at desc);

create or replace function public.sync_product_list_stats()
returns trigger
language plpgsql
as $$
declare
  v_list_id text := coalesce(new.list_id, old.list_id);
begin
  if v_list_id is null then
    return coalesce(new, old);
  end if;

  update public.product_lists
  set product_count = (
        select count(*)
        from public.product_list_items
        where list_id = v_list_id
      ),
      updated_at = now()
  where id = v_list_id;

  return coalesce(new, old);
end;
$$;

create or replace function public.sync_product_list_followers()
returns trigger
language plpgsql
as $$
declare
  v_list_id text := coalesce(new.list_id, old.list_id);
begin
  if v_list_id is null then
    return coalesce(new, old);
  end if;

  update public.product_lists
  set follower_count = (
        select count(*)
        from public.product_list_follows
        where list_id = v_list_id
      ),
      updated_at = now()
  where id = v_list_id;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_product_list_items_sync_stats on public.product_list_items;
create trigger trg_product_list_items_sync_stats
after insert or update or delete on public.product_list_items
for each row execute function public.sync_product_list_stats();

drop trigger if exists trg_product_list_follows_sync_stats on public.product_list_follows;
create trigger trg_product_list_follows_sync_stats
after insert or update or delete on public.product_list_follows
for each row execute function public.sync_product_list_followers();

alter table public.product_lists enable row level security;
alter table public.product_list_items enable row level security;
alter table public.product_list_follows enable row level security;

drop policy if exists "product_lists_select_visible" on public.product_lists;
create policy "product_lists_select_visible"
on public.product_lists
for select
to authenticated
using (
  visibility = 'public'
  or owner_user_id = auth.uid()
);

drop policy if exists "product_lists_insert_own" on public.product_lists;
create policy "product_lists_insert_own"
on public.product_lists
for insert
to authenticated
with check (owner_user_id = auth.uid());

drop policy if exists "product_lists_update_own" on public.product_lists;
create policy "product_lists_update_own"
on public.product_lists
for update
to authenticated
using (owner_user_id = auth.uid())
with check (owner_user_id = auth.uid());

drop policy if exists "product_lists_delete_own" on public.product_lists;
create policy "product_lists_delete_own"
on public.product_lists
for delete
to authenticated
using (owner_user_id = auth.uid());

drop policy if exists "product_list_items_select_visible" on public.product_list_items;
create policy "product_list_items_select_visible"
on public.product_list_items
for select
to authenticated
using (
  exists (
    select 1
    from public.product_lists l
    where l.id = list_id
      and (l.visibility = 'public' or l.owner_user_id = auth.uid())
  )
);

drop policy if exists "product_list_items_insert_own" on public.product_list_items;
create policy "product_list_items_insert_own"
on public.product_list_items
for insert
to authenticated
with check (
  exists (
    select 1
    from public.product_lists l
    where l.id = list_id
      and l.owner_user_id = auth.uid()
  )
);

drop policy if exists "product_list_items_update_own" on public.product_list_items;
create policy "product_list_items_update_own"
on public.product_list_items
for update
to authenticated
using (
  exists (
    select 1
    from public.product_lists l
    where l.id = list_id
      and l.owner_user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.product_lists l
    where l.id = list_id
      and l.owner_user_id = auth.uid()
  )
);

drop policy if exists "product_list_items_delete_own" on public.product_list_items;
create policy "product_list_items_delete_own"
on public.product_list_items
for delete
to authenticated
using (
  exists (
    select 1
    from public.product_lists l
    where l.id = list_id
      and l.owner_user_id = auth.uid()
  )
);

drop policy if exists "product_list_follows_select_self_or_owner" on public.product_list_follows;
create policy "product_list_follows_select_self_or_owner"
on public.product_list_follows
for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.product_lists l
    where l.id = list_id
      and l.owner_user_id = auth.uid()
  )
);

drop policy if exists "product_list_follows_insert_self" on public.product_list_follows;
create policy "product_list_follows_insert_self"
on public.product_list_follows
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "product_list_follows_update_self" on public.product_list_follows;
create policy "product_list_follows_update_self"
on public.product_list_follows
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "product_list_follows_delete_self" on public.product_list_follows;
create policy "product_list_follows_delete_self"
on public.product_list_follows
for delete
to authenticated
using (user_id = auth.uid());
