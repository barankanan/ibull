-- One phase of run_isolated_order_waiter_identity.sh (:phase = before | after the draft).
\set ON_ERROR_STOP on
select public.t_wi_send(:'phase', 'efe_staff',  'cccccccc-cccc-cccc-cccc-cccccccccccc');                 -- active, manageOrders, table-1 branch
select public.t_wi_send(:'phase', 'empty',      '');                                                      -- no waiter given
select public.t_wi_send(:'phase', 'self',       'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');                  -- the owner itself
select public.t_wi_send(:'phase', 'inactive',   'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee');                  -- deactivated since the order
select public.t_wi_send(:'phase', 'other_rest', 'ffffffff-ffff-ffff-ffff-ffffffffffff');                  -- staff of another restaurant
select public.t_wi_send(:'phase', 'other_branch','10101010-1010-1010-1010-101010101010');                 -- active, but another branch than table 1
select public.t_wi_send(:'phase', 'noperm',     'dddddddd-dddd-dddd-dddd-dddddddddddd');                  -- active, no manageOrders
select public.t_wi_send(:'phase', 'customer',   'abababab-abab-abab-abab-abababababab');                  -- a user that is staff nowhere
select public.t_wi_send(:'phase', 'not_a_user', '99999999-9999-9999-9999-999999999990');                  -- id that exists nowhere
-- the staff member sends it themself
select public.t_wi_send(:'phase', 'staff_self', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 1, 'cccccccc-cccc-cccc-cccc-cccccccccccc');
-- the staff member tries to name someone else
select public.t_wi_send(:'phase', 'staff_names_other', 'abababab-abab-abab-abab-abababababab', 1, 'cccccccc-cccc-cccc-cccc-cccccccccccc');
-- the evidence verifier path: service role, verified actor = the owner, waiter = the staff
select public.t_wi_send(:'phase', 'verifier_staff', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 1, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'service_role', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
select public.t_wi_send(:'phase', 'verifier_customer', 'abababab-abab-abab-abab-abababababab', 1, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'service_role', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
-- a resend of the first order: still one order, waiter unchanged
select public.t_wi_send(:'phase', 'efe_staff_again', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 1, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '', null, 'wi-' || :'phase' || '-efe_staff');
