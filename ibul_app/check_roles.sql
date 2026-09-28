BEGIN;
set local role authenticated;
set local request.jwt.claim.sub = '0ca8d272-06be-4252-ab74-44ebf63aaae5';
set local request.jwt.claims = '{"sub":"0ca8d272-06be-4252-ab74-44ebf63aaae5","role":"authenticated"}';

SELECT current_user as "current_user", 
       session_user as "session_user", 
       current_setting('role') as "role", 
       (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) as "is_super",
       (SELECT rolbypassrls FROM pg_roles WHERE rolname = current_user) as "bypasses_rls";

ROLLBACK;
