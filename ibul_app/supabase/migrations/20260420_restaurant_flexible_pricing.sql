alter table if exists public.products
  add column if not exists pricing_mode text not null default 'base_only',
  add column if not exists base_price numeric,
  add column if not exists size_options jsonb not null default '[]'::jsonb;

update public.products
set
  base_price = coalesce(base_price, portion_price, price),
  pricing_mode = case
    when coalesce(pricing_mode, '') <> '' then pricing_mode
    when pricing_type = 'weight' then 'weight_only'
    else 'base_only'
  end,
  size_options = case
    when size_options is null then '[]'::jsonb
    else size_options
  end
where base_price is null
   or pricing_mode is null
   or pricing_mode = ''
   or size_options is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'products_pricing_mode_check'
  ) then
    alter table public.products
      add constraint products_pricing_mode_check
      check (pricing_mode in ('base_only', 'weight_only', 'size_only', 'hybrid'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'products_size_options_is_array_check'
  ) then
    alter table public.products
      add constraint products_size_options_is_array_check
      check (jsonb_typeof(size_options) = 'array');
  end if;
end $$;
