-- Admin "Başvuruyu Onayla" hatası:
-- function gen_random_bytes(integer) does not exist (42883)
-- SQL Editor'da bunun TAMAMINI Run edin.

create extension if not exists pgcrypto;

create or replace function public.ihiz_generate_business_serial()
returns text
language plpgsql
set search_path = public, extensions
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  bytes bytea;
  code text;
  i int;
  idx int;
begin
  loop
    bytes := gen_random_bytes(6);
    code := 'ISL-';
    for i in 0..5 loop
      idx := get_byte(bytes, i) % length(alphabet);
      code := code || substr(alphabet, idx + 1, 1);
    end loop;
    exit when not exists (
      select 1
      from public.store_business_serials s
      where s.business_serial_no = code
    );
  end loop;
  return code;
end;
$$;

create or replace function public.stores_assign_business_serial()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  insert into public.store_business_serials (store_id, business_serial_no)
  values (new.seller_id, public.ihiz_generate_business_serial())
  on conflict (store_id) do nothing;
  return new;
end;
$$;
