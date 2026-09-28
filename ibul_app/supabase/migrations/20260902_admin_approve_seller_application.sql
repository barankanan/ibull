-- Admin mağaza başvurusu onayı: stores INSERT RLS 42501 ve users upsert RLS.
-- Supabase SQL Editor'da da güvenle tekrar çalıştırılabilir.

create or replace function public.store_is_gallery_category(p_category text)
returns boolean
language sql
immutable
as $$
  select (
    lower(translate(coalesce(p_category, ''), 'İIıĞğÜüŞşÖöÇç', 'iiigguusssoocc'))
      like '%galeri%'
    or lower(coalesce(p_category, '')) like '%kiralama%'
    or lower(coalesce(p_category, '')) like '%rent%car%'
    or lower(coalesce(p_category, '')) like '%dealer%'
    or lower(coalesce(p_category, '')) like '%dealership%'
  );
$$;

alter table public.stores enable row level security;

drop policy if exists "Admins can insert stores" on public.stores;
create policy "Admins can insert stores"
on public.stores
for insert
to authenticated
with check (
  exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and (
        users.role = 'admin'
        or users.role = 'super_admin'
        or users.role like 'admin_%'
      )
  )
);

create or replace function public.admin_can_manage_users()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and (
        lower(coalesce(u.role, '')) in ('admin', 'super_admin')
        or lower(coalesce(u.role, '')) like 'admin_%'
      )
  );
$$;

revoke all on function public.admin_can_manage_users() from public;
revoke all on function public.admin_can_manage_users() from anon;
grant execute on function public.admin_can_manage_users() to authenticated;

alter table public.users enable row level security;

drop policy if exists "Admins can update users for seller approval" on public.users;
create policy "Admins can update users for seller approval"
on public.users
for update
to authenticated
using (public.admin_can_manage_users())
with check (public.admin_can_manage_users());

drop policy if exists "Admins can insert users for seller approval" on public.users;
create policy "Admins can insert users for seller approval"
on public.users
for insert
to authenticated
with check (public.admin_can_manage_users());

create or replace function public.admin_approve_seller_application(
  p_application_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_is_admin boolean := false;
  v_app jsonb;
  v_seller_id uuid;
  v_email text;
  v_store_exists boolean := false;
begin
  if v_actor is null then
    raise exception 'not authenticated';
  end if;

  select exists (
           select 1
           from public.users u
           where u.id = v_actor
             and (
               lower(coalesce(u.role, '')) in ('admin', 'super_admin')
               or lower(coalesce(u.role, '')) like 'admin_%'
             )
         )
    into v_is_admin;

  if not v_is_admin
     and to_regclass('public.admin_user_permissions') is not null then
    execute
      'select exists (
         select 1
         from public.admin_user_permissions p
         where p.user_id = $1
           and coalesce(p.is_active, true) = true
       )'
      into v_is_admin
      using v_actor;
  end if;

  if not v_is_admin then
    raise exception 'not authorized';
  end if;

  if to_regclass('public.seller_applications') is null then
    raise exception 'seller_applications missing';
  end if;

  select to_jsonb(sa.*)
    into v_app
  from public.seller_applications sa
  where sa.id = p_application_id;

  if v_app is null then
    raise exception 'application not found';
  end if;

  begin
    v_seller_id := nullif(v_app->>'user_id', '')::uuid;
  exception
    when others then
      v_seller_id := null;
  end;

  if v_seller_id is null then
    raise exception 'application user_id missing';
  end if;

  v_email := nullif(
    btrim(coalesce(v_app->>'email', v_app->>'user_email', '')),
    ''
  );

  insert into public.users (
    id,
    email,
    display_name,
    phone,
    address,
    role,
    is_seller_approved,
    updated_at
  )
  values (
    v_seller_id,
    v_email,
    coalesce(
      nullif(btrim(v_app->>'contact_name'), ''),
      nullif(btrim(v_app->>'business_name'), ''),
      'Satıcı'
    ),
    nullif(btrim(v_app->>'phone'), ''),
    nullif(btrim(v_app->>'address'), ''),
    'seller',
    true,
    timezone('utc', now())
  )
  on conflict (id) do update
    set email = coalesce(excluded.email, public.users.email),
        display_name = coalesce(excluded.display_name, public.users.display_name),
        phone = coalesce(excluded.phone, public.users.phone),
        address = coalesce(excluded.address, public.users.address),
        role = case
          when lower(coalesce(public.users.role, '')) in ('admin', 'super_admin')
               or lower(coalesce(public.users.role, '')) like 'admin_%'
          then public.users.role
          else 'seller'
        end,
        is_seller_approved = true,
        updated_at = timezone('utc', now());

  select exists (
    select 1 from public.stores s where s.seller_id = v_seller_id
  ) into v_store_exists;

  if not v_store_exists then
    insert into public.stores (
      seller_id,
      business_name,
      business_type,
      category,
      email,
      phone,
      address,
      city,
      district,
      postal_code,
      tax_number,
      contact_name,
      bank_name,
      iban,
      account_holder,
      logo_url,
      is_store_open,
      accept_new_orders,
      is_verified,
      rating,
      created_at,
      updated_at
    )
    values (
      v_seller_id,
      nullif(btrim(v_app->>'business_name'), ''),
      nullif(btrim(v_app->>'business_type'), ''),
      nullif(btrim(v_app->>'category'), ''),
      v_email,
      nullif(btrim(v_app->>'phone'), ''),
      nullif(btrim(v_app->>'address'), ''),
      nullif(btrim(v_app->>'city'), ''),
      nullif(btrim(v_app->>'district'), ''),
      nullif(btrim(v_app->>'postal_code'), ''),
      nullif(btrim(v_app->>'tax_number'), ''),
      nullif(btrim(v_app->>'contact_name'), ''),
      nullif(btrim(v_app->>'bank_name'), ''),
      nullif(btrim(v_app->>'iban'), ''),
      nullif(btrim(v_app->>'account_holder'), ''),
      nullif(btrim(v_app->>'logo_url'), ''),
      true,
      true,
      true,
      0.0,
      timezone('utc', now()),
      timezone('utc', now())
    );
  else
    update public.stores
    set business_name = coalesce(
          nullif(btrim(v_app->>'business_name'), ''),
          business_name
        ),
        business_type = coalesce(
          nullif(btrim(v_app->>'business_type'), ''),
          business_type
        ),
        category = coalesce(nullif(btrim(v_app->>'category'), ''), category),
        email = coalesce(v_email, email),
        phone = coalesce(nullif(btrim(v_app->>'phone'), ''), phone),
        address = coalesce(nullif(btrim(v_app->>'address'), ''), address),
        city = coalesce(nullif(btrim(v_app->>'city'), ''), city),
        district = coalesce(nullif(btrim(v_app->>'district'), ''), district),
        postal_code = coalesce(
          nullif(btrim(v_app->>'postal_code'), ''),
          postal_code
        ),
        tax_number = coalesce(
          nullif(btrim(v_app->>'tax_number'), ''),
          tax_number
        ),
        contact_name = coalesce(
          nullif(btrim(v_app->>'contact_name'), ''),
          contact_name
        ),
        bank_name = coalesce(nullif(btrim(v_app->>'bank_name'), ''), bank_name),
        iban = coalesce(nullif(btrim(v_app->>'iban'), ''), iban),
        account_holder = coalesce(
          nullif(btrim(v_app->>'account_holder'), ''),
          account_holder
        ),
        logo_url = coalesce(nullif(btrim(v_app->>'logo_url'), ''), logo_url),
        accept_new_orders = true,
        is_verified = true,
        updated_at = timezone('utc', now())
    where seller_id = v_seller_id;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'stores'
      and column_name = 'store_lat'
  ) and nullif(btrim(v_app->>'store_lat'), '') is not null then
    execute
      'update public.stores set store_lat = $1::double precision where seller_id = $2'
      using v_app->>'store_lat', v_seller_id;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'stores'
      and column_name = 'store_lng'
  ) and nullif(btrim(v_app->>'store_lng'), '') is not null then
    execute
      'update public.stores set store_lng = $1::double precision where seller_id = $2'
      using v_app->>'store_lng', v_seller_id;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'stores'
      and column_name = 'has_physical_store'
  ) and nullif(btrim(v_app->>'has_physical_store'), '') is not null then
    execute
      'update public.stores set has_physical_store = $1::boolean where seller_id = $2'
      using v_app->>'has_physical_store', v_seller_id;
  end if;

  update public.seller_applications
  set status = 'approved',
      approved_at = coalesce(approved_at, timezone('utc', now()))
  where id = p_application_id;

  if to_regclass('public.vehicle_galleries') is not null then
    if public.store_is_gallery_category(v_app->>'category') then
      insert into public.vehicle_galleries (seller_id)
      values (v_seller_id)
      on conflict (seller_id) do nothing;
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'seller_id', v_seller_id,
    'store_created', not v_store_exists
  );
end;
$$;

revoke all on function public.admin_approve_seller_application(uuid) from public;
revoke all on function public.admin_approve_seller_application(uuid) from anon;
grant execute on function public.admin_approve_seller_application(uuid)
  to authenticated;
