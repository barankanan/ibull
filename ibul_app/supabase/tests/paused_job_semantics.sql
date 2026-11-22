-- Proves what `paused_by_operator` means for a job whose ticket the LAN center
-- already handed to the printer: the hub never claims it (it claims only
-- `pending`), the operator can release it exactly once, and a job in any other
-- state is never released. Uses the exact compare-and-set updates of
-- desktop_print_hub._claimJob and print_station_service.resumePausedPrintJob.
-- Run on an isolated database that holds one paused job; everything rolls back.
begin;
create temp table _r(step text, rows_affected int, expected int);
do $t$
declare
  v_id uuid; v_n int;
begin
  select id into v_id from public.print_jobs where status = 'paused_by_operator' and last_error = 'local_forwarded' limit 1;
  if v_id is null then raise exception 'no paused local_forwarded job to test'; end if;
  -- 1. hub claim (status must still be pending): must not take it
  update public.print_jobs set status='claimed' where id=v_id and status='pending'; get diagnostics v_n = row_count;
  insert into _r values ('hub claim of a paused job', v_n, 0);
  -- 2. operator release (only a paused job): once
  update public.print_jobs set status='pending', last_error=null where id=v_id and status='paused_by_operator'; get diagnostics v_n = row_count;
  insert into _r values ('operator release', v_n, 1);
  update public.print_jobs set status='pending' where id=v_id and status='paused_by_operator'; get diagnostics v_n = row_count;
  insert into _r values ('second release of the same job', v_n, 0);
  -- 3. after release the hub claims it exactly once
  update public.print_jobs set status='claimed' where id=v_id and status='pending'; get diagnostics v_n = row_count;
  insert into _r values ('hub claim after release', v_n, 1);
  update public.print_jobs set status='claimed' where id=v_id and status='pending'; get diagnostics v_n = row_count;
  insert into _r values ('second hub claim', v_n, 0);
  -- 4. a claimed (in flight) job is never put back by the operator button
  update public.print_jobs set status='pending' where id=v_id and status='paused_by_operator'; get diagnostics v_n = row_count;
  insert into _r values ('release of an in-flight job', v_n, 0);
end $t$;
select case when rows_affected = expected then 'PASS' else 'FAIL' end as result, step, rows_affected, expected from _r;
rollback;
