-- mall_management_runtime_fix.sql sonrası. Primall new yöneticisi JWT claim ile simüle edilir; sonda ROLLBACK.
-- Beklenen: her satır OK; mall_setup_summary missing listesi gerçek eksikleri gösterir; direkt status yazımı geri alınır.

begin;

create temp table post_result (name text, code text, msg text) on commit drop;
grant all on post_result to authenticated;

select set_config('request.jwt.claims',
  '{"sub":"7b02727f-c24e-494e-b355-a5f2883a1721","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  m uuid := '6076965d-e3d2-452a-93ae-784e9fc6a021';
  calls text[] := array[
    'select mall_store_links($1)',
    'select mall_setup_summary($1)',
    'select public_mall_detail($1)',
    'select mall_find_store_branches($1, ''tek'')',
    'select mall_event_stats($1, 30)',
    'select mall_member_directory($1)',
    'select mall_recent_activity($1, 20)',
    'select mall_ad_campaigns($1)'];
  c text;
  v jsonb;
  e_code text;
  e_msg text;
begin
  foreach c in array calls loop
    begin
      execute c into v using m;
      insert into post_result values (c, 'OK', left(coalesce(v::text, 'null'), 300));
    exception when others then
      get stacked diagnostics e_code = returned_sqlstate, e_msg = message_text;
      insert into post_result values (c, e_code, e_msg);
    end;
  end loop;

  -- Yönetici status'u doğrudan yazamaz (tetikleyici eski değeri korur).
  begin
    update public.malls set status = 'active' where id = m;
    insert into post_result
    select 'direct status write blocked', case when status <> 'active' then 'OK' else 'FAIL' end, status
    from public.malls where id = m;
  exception when others then
    get stacked diagnostics e_code = returned_sqlstate, e_msg = message_text;
    insert into post_result values ('direct status write blocked', 'OK', e_code || ' ' || e_msg);
  end;
end $$;

reset role;

insert into post_result
select 'note_column', case when count(*) = 1 then 'OK' else 'FAIL' end, ''
from information_schema.columns
where table_schema = 'public' and table_name = 'mall_branch_links' and column_name = 'note';

insert into post_result
select 'rpcs_present', case when count(*) = 8 then 'OK' else 'FAIL' end, count(*)::text
from pg_proc p
where p.pronamespace = 'public'::regnamespace
  and p.proname in ('request_mall_store_link', 'mall_setup_summary', 'mall_publication_missing',
                    'request_mall_publication', 'cancel_mall_publication', 'admin_mall_publication_queue',
                    'admin_review_mall_publication', 'public_mall_detail');

select * from post_result;

rollback;
