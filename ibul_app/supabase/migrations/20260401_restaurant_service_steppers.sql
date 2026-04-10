alter table public.products
  add column if not exists service_control_type text,
  add column if not exists min_portion numeric(6,2),
  add column if not exists max_portion numeric(6,2),
  add column if not exists portion_step numeric(6,2);

update public.products
set service_control_type = 'weight_stepper'
where pricing_type = 'weight'
  and coalesce(nullif(service_control_type, ''), '') = '';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'products_service_control_type_check'
  ) then
    alter table public.products
      add constraint products_service_control_type_check
      check (
        service_control_type is null or
        service_control_type in (
          'portion_stepper',
          'skewer_stepper',
          'weight_stepper'
        )
      );
  end if;
end $$;
