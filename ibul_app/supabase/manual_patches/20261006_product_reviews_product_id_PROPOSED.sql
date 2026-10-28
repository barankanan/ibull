-- APPLIED 2026-10-06 on ihmixxzqnpamcwmrfibx by controlled SQL.
-- Not applied with supabase db push. Do not re-run.
-- NO LEGACY BACKFILL
-- No db push. No UPDATE of existing review rows. No RLS change.
--
-- products.id is text. product_reviews.product_id must use that same type,
-- stay nullable, and must not be filled from product_name, store_name,
-- seller_id, or product_code. The two existing reviews stay NULL.

-- PRECHECK
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'product_reviews'
  and column_name in (
    'id', 'product_id', 'product_name', 'store_name', 'seller_id', 'product_code'
  )
order by column_name;

-- Expected: product_id is absent.
-- Confirm products.id is still text before the foreign key:
-- select data_type
-- from information_schema.columns
-- where table_schema = 'public'
--   and table_name = 'products'
--   and column_name = 'id';

-- PATCH
-- PROPOSED / DO NOT RUN
-- alter table public.product_reviews
--   add column if not exists product_id text;
--
-- alter table public.product_reviews
--   drop constraint if exists product_reviews_product_id_fkey;
-- alter table public.product_reviews
--   add constraint product_reviews_product_id_fkey
--   foreign key (product_id) references public.products (id);
--
-- create index if not exists idx_product_reviews_product_id
--   on public.product_reviews (product_id);
--
-- Existing policies stay as they are:
--   product_reviews_public_read  SELECT using (true)
--   product_reviews_auth_insert  INSERT with check (auth.uid() = user_id)
-- No new anon insert, no cross-user update, no NOT NULL.

-- POSTCHECK
-- PROPOSED / DO NOT RUN
-- select column_name, data_type, is_nullable
-- from information_schema.columns
-- where table_schema = 'public'
--   and table_name = 'product_reviews'
--   and column_name = 'product_id';
--
-- select count(*) as total,
--        count(product_id) as filled,
--        count(*) filter (where product_id is null) as still_null
-- from public.product_reviews;
-- Expected immediately after the patch: filled = 0, still_null = total.

-- ROLLBACK
-- PROPOSED / DO NOT RUN
-- Revert application code before dropping the column.
-- This does not delete review rows.
-- alter table public.product_reviews
--   drop constraint if exists product_reviews_product_id_fkey;
-- drop index if exists public.idx_product_reviews_product_id;
-- alter table public.product_reviews drop column if exists product_id;
