begin;

create table if not exists public.store_sub_admins (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(seller_id) on delete cascade,
  email text,
  phone text,
  permissions text[] not null default '{}'::text[],
  status text not null default 'invited',
  created_at timestamptz not null default timezone('utc'::text, now())
);

create index if not exists idx_store_sub_admins_store_id
  on public.store_sub_admins(store_id);

create index if not exists idx_store_sub_admins_email_lower
  on public.store_sub_admins (lower(trim(email)))
  where email is not null and trim(email) <> '';

create index if not exists idx_store_sub_admins_phone_trim
  on public.store_sub_admins (trim(phone))
  where phone is not null and trim(phone) <> '';

alter table public.store_sub_admins enable row level security;

grant select, insert, update, delete on public.store_sub_admins to authenticated;

drop policy if exists "store_sub_admins_owner_all" on public.store_sub_admins;
create policy "store_sub_admins_owner_all"
on public.store_sub_admins
for all
to authenticated
using (auth.uid() = store_id)
with check (auth.uid() = store_id);

drop policy if exists "store_sub_admins_active_self_select" on public.store_sub_admins;
create policy "store_sub_admins_active_self_select"
on public.store_sub_admins
for select
to authenticated
using (
  status = 'active'
  and exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and (
        (
          store_sub_admins.email is not null
          and trim(store_sub_admins.email) <> ''
          and lower(trim(u.email)) = lower(trim(store_sub_admins.email))
        )
        or (
          store_sub_admins.phone is not null
          and trim(store_sub_admins.phone) <> ''
          and trim(coalesce(u.phone, '')) = trim(store_sub_admins.phone)
        )
      )
  )
);

comment on table public.store_sub_admins is
'Waiter/sub-admin membership records used by seller tools and kitchen-print authorization.';

commit;
