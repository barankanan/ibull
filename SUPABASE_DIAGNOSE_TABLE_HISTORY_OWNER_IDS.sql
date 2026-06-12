-- Diagnose table_order_history rows that may have been archived under a
-- waiter/sub-admin auth UID instead of the canonical restaurant owner seller_id.
--
-- Why this matters:
-- - dashboard / finance reload queries read table_order_history by seller_id
-- - if a close was archived under the wrong UID, the amount may appear in the
--   same session via optimistic state, then disappear after app restart
--
-- Usage:
-- 1. Run the read-only queries below first.
-- 2. Review suspicious seller_id values that do not exist in public.stores.
-- 3. If needed, use the explicit mapping template at the bottom.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1) Summary: seller_ids in history that do not resolve to an owner store row
-- ─────────────────────────────────────────────────────────────────────────────
select
  h.seller_id,
  count(*) as row_count,
  min(coalesce(h.closed_at, h.created_at)) as first_seen_at,
  max(coalesce(h.closed_at, h.created_at)) as last_seen_at,
  count(distinct h.waiter_id) as distinct_waiter_ids,
  count(distinct h.table_number) as distinct_tables
from public.table_order_history h
left join public.stores s
  on s.seller_id = h.seller_id
where s.seller_id is null
group by h.seller_id
order by last_seen_at desc nulls last;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2) Detail view: suspicious rows ordered by most recent close time
-- ─────────────────────────────────────────────────────────────────────────────
select
  h.id,
  h.seller_id,
  h.waiter_id,
  h.waiter_name,
  h.table_number,
  h.grand_total,
  h.payment_method,
  h.session_key,
  h.original_order_id,
  h.closed_at,
  h.created_at
from public.table_order_history h
left join public.stores s
  on s.seller_id = h.seller_id
where s.seller_id is null
order by coalesce(h.closed_at, h.created_at) desc nulls last
limit 500;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3) Optional focused check for a single suspicious seller_id
--    Replace the placeholder before running.
-- ─────────────────────────────────────────────────────────────────────────────
-- select
--   h.*
-- from public.table_order_history h
-- where h.seller_id = 'REPLACE_WRONG_SELLER_ID'
-- order by coalesce(h.closed_at, h.created_at) desc nulls last;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4) Manual backfill template
--
-- IMPORTANT:
-- - This is intentionally NOT automatic.
-- - Fill the mapping table only after you manually verify each wrong -> owner
--   relationship.
-- - Restricting the update to seller_ids that are absent from public.stores
--   prevents rewriting already-correct owner rows.
-- ─────────────────────────────────────────────────────────────────────────────
-- with seller_id_fix_map as (
--   select
--     'REPLACE_WRONG_SELLER_ID_1'::uuid as wrong_seller_id,
--     'REPLACE_OWNER_SELLER_ID_1'::uuid as correct_seller_id
--   union all
--   select
--     'REPLACE_WRONG_SELLER_ID_2'::uuid,
--     'REPLACE_OWNER_SELLER_ID_2'::uuid
-- ),
-- candidates as (
--   select h.id, h.seller_id, m.correct_seller_id
--   from public.table_order_history h
--   join seller_id_fix_map m
--     on m.wrong_seller_id = h.seller_id
--   left join public.stores s
--     on s.seller_id = h.seller_id
--   where s.seller_id is null
-- )
-- update public.table_order_history h
-- set seller_id = c.correct_seller_id
-- from candidates c
-- where h.id = c.id;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5) Verify after backfill
-- ─────────────────────────────────────────────────────────────────────────────
-- select
--   h.seller_id,
--   count(*) as row_count
-- from public.table_order_history h
-- left join public.stores s
--   on s.seller_id = h.seller_id
-- where s.seller_id is null
-- group by h.seller_id
-- order by row_count desc;
