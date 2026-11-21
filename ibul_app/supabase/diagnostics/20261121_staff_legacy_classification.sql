-- READ ONLY. Classifies every staff membership for the owner-only password policy.
-- It changes nothing. Do not turn the result into an automatic backfill: a row is
-- flagged / locked only after the store owner confirmed that account by name.
--
-- class
--   A_protected        linked, flagged, provisioned by this store: nothing to do.
--   B_flag_no_store    flagged but provisioned_by_store_id missing or different:
--                      the owner cannot set its password. Candidate for writing
--                      provisioned_by_store_id when evidence = 'strong'.
--   C_unflagged        linked account without the staff flag: it can still change
--                      its own password / use recovery. Candidate for flagging
--                      only when evidence = 'strong' AND the owner confirms.
--   D_unlinked         legacy e-mail / phone row without an Auth id: never link
--                      automatically; the owner re-creates the person in the panel.
-- evidence
--   strong  membership was written by the create flow (creation_request_id), the
--           Auth account was created within 2 minutes of it, the account has no
--           other membership, owns no store, and its profile role is not a seller.
--   weak    anything else: leave the account as it is.
select
  sa.store_id,
  sa.id                                   as member_id,
  sa.status,
  sa.staff_role,
  left(coalesce(sa.email, ''), 3) || '***' as email_hint,
  case
    when sa.auth_user_id is null then 'D_unlinked'
    when u.raw_app_meta_data ->> 'managed_restaurant_staff' = 'true'
         and u.raw_app_meta_data ->> 'provisioned_by_store_id' = sa.store_id::text then 'A_protected'
    when u.raw_app_meta_data ->> 'managed_restaurant_staff' = 'true' then 'B_flag_no_store'
    else 'C_unflagged'
  end                                     as class,
  case
    when sa.auth_user_id is null or u.id is null then 'n/a'
    when sa.creation_request_id is not null
         and abs(extract(epoch from (sa.created_at - u.created_at))) <= 120
         and not exists(select 1 from public.store_sub_admins o
                        where o.auth_user_id = sa.auth_user_id and o.id <> sa.id)
         and not exists(select 1 from public.stores s where s.seller_id = sa.auth_user_id)
         and coalesce(p.role, 'waiter') not in ('seller', 'admin')
    then 'strong'
    else 'weak'
  end                                     as evidence,
  (u.id is null and sa.auth_user_id is not null) as auth_account_missing,
  u.last_sign_in_at
from public.store_sub_admins sa
left join auth.users u on u.id = sa.auth_user_id
left join public.users p on p.id = sa.auth_user_id
order by sa.store_id, class, sa.created_at;
