alter table public.product_lists
  add column if not exists seller_id text,
  add column if not exists store_name text;

create index if not exists idx_product_lists_seller_visibility
  on public.product_lists(seller_id, visibility, updated_at desc);

create index if not exists idx_product_lists_store_visibility
  on public.product_lists(store_name, visibility, updated_at desc);

update public.product_lists as lists
set seller_id = coalesce(lists.seller_id, source.seller_id, lists.owner_user_id::text),
    store_name = coalesce(lists.store_name, source.store_name)
from (
  select
    list_id,
    max(nullif(trim(seller_id), '')) as seller_id,
    max(nullif(trim(store_name), '')) as store_name
  from public.product_list_items
  group by list_id
) as source
where lists.id = source.list_id
  and (
    coalesce(lists.seller_id, '') = ''
    or coalesce(lists.store_name, '') = ''
  );

update public.product_lists
set seller_id = owner_user_id::text
where coalesce(seller_id, '') = '';

drop policy if exists "product_lists_select_visible" on public.product_lists;
create policy "product_lists_select_visible"
on public.product_lists
for select
to public
using (
  visibility = 'public'
  or owner_user_id = auth.uid()
);

drop policy if exists "product_list_items_select_visible" on public.product_list_items;
create policy "product_list_items_select_visible"
on public.product_list_items
for select
to public
using (
  exists (
    select 1
    from public.product_lists l
    where l.id = list_id
      and (l.visibility = 'public' or l.owner_user_id = auth.uid())
  )
);
