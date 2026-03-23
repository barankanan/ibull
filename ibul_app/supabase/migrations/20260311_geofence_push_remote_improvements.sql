alter table if exists public.user_product_interests
drop constraint if exists user_product_interests_interest_type_check;

alter table if exists public.user_product_interests
add constraint user_product_interests_interest_type_check
check (interest_type in ('searched', 'favorite', 'saved', 'cart'));
