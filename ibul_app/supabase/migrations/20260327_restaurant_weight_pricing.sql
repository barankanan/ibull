alter table if exists public.products
  add column if not exists pricing_type text not null default 'portion',
  add column if not exists portion_price numeric,
  add column if not exists price_per_kg numeric,
  add column if not exists default_weight_grams integer,
  add column if not exists min_weight_grams integer,
  add column if not exists weight_step_grams integer,
  add column if not exists max_weight_grams integer;

update public.products
set
  pricing_type = coalesce(nullif(pricing_type, ''), 'portion'),
  portion_price = coalesce(portion_price, price)
where pricing_type is null
   or pricing_type = ''
   or portion_price is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'products_pricing_type_check'
  ) then
    alter table public.products
      add constraint products_pricing_type_check
      check (pricing_type in ('portion', 'weight'));
  end if;
end $$;
