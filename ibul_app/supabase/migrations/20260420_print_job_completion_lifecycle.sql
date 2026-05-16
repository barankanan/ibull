begin;

alter table public.print_jobs
  drop constraint if exists print_jobs_status_check;

update public.print_jobs
set status = 'completed'
where status = 'printed';

alter table public.print_jobs
  add constraint print_jobs_status_check
  check (status in ('pending', 'claimed', 'printing', 'completed', 'failed'));

create index if not exists idx_print_jobs_restaurant_status_created
  on public.print_jobs(restaurant_id, status, created_at);

comment on column public.print_jobs.status
is 'Lifecycle: pending -> claimed -> printing -> completed|failed';

commit;