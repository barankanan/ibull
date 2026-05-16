alter table if exists public.products
  add column if not exists size_options jsonb not null default '[]'::jsonb,
  add column if not exists selected_size_name text,
  add column if not exists selected_size_price numeric;

with normalized_products as (
  select
    id,
    coalesce(size_options, '[]'::jsonb) as size_options
  from public.products
),
resolved_defaults as (
  select
    p.id,
    coalesce(
      (
        select option_item ->> 'name'
        from jsonb_array_elements(p.size_options) as option_item
        where coalesce((option_item ->> 'is_default')::boolean, false)
        order by
          coalesce((option_item ->> 'sort_order')::int, 0),
          lower(coalesce(option_item ->> 'name', ''))
        limit 1
      ),
      p.size_options -> 0 ->> 'name'
    ) as default_size_name,
    coalesce(
      (
        select (option_item ->> 'price')::numeric
        from jsonb_array_elements(p.size_options) as option_item
        where coalesce((option_item ->> 'is_default')::boolean, false)
        order by
          coalesce((option_item ->> 'sort_order')::int, 0),
          lower(coalesce(option_item ->> 'name', ''))
        limit 1
      ),
      (p.size_options -> 0 ->> 'price')::numeric
    ) as default_size_price
  from normalized_products p
  where jsonb_typeof(p.size_options) = 'array'
    and jsonb_array_length(p.size_options) > 0
)
update public.products as products
set
  selected_size_name = coalesce(products.selected_size_name, resolved_defaults.default_size_name),
  selected_size_price = coalesce(products.selected_size_price, resolved_defaults.default_size_price)
from resolved_defaults
where products.id = resolved_defaults.id
  and (
    products.selected_size_name is null
    or nullif(trim(products.selected_size_name), '') is null
    or products.selected_size_price is null
  );

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'products_selected_size_price_non_negative_check'
  ) then
    alter table public.products
      add constraint products_selected_size_price_non_negative_check
      check (
        selected_size_price is null
        or selected_size_price >= 0
      );
  end if;
end $$;
