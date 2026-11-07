-- =============================================================================
-- Migration: staff_permission_enforcement
-- Date: 2026-11-07
--
-- Binds restaurant collection to the staff grant and stops a staff member
-- from changing their own permissions.
--
-- Owner path stays open.
-- An active staff member with manageOrders or Tam Erişim (fullAccess) can
-- still be collected for by the security-definer payment function, because
-- the insert trigger allows that grant. Direct inserts stay owner-only via
-- the existing table_payments policy.
--
-- This migration does not drop or replace guard_table_payment or
-- trg_guard_table_payment. That existing BEFORE INSERT trigger remains the
-- overpayment cap. The trigger added here only checks who may collect.
--
-- Do not apply this file to production from automation.
-- =============================================================================

begin;

create or replace function public.normalize_staff_permission(p_token text)
returns text
language sql
immutable
as $$
  select case folded
    when 'fullaccess' then 'fullAccess'
    when 'tamerisim' then 'fullAccess'
    when 'tam_erisim' then 'fullAccess'
    when 'tam erisim' then 'fullAccess'
    when 'tam erişim' then 'fullAccess'
    when 'manageproducts' then 'manageProducts'
    when 'vieworders' then 'viewOrders'
    when 'manageorders' then 'manageOrders'
    when 'managecampaigns' then 'manageCampaigns'
    when 'viewfinance' then 'viewFinance'
    when 'managesupport' then 'manageSupport'
    when 'managestoreprofile' then 'manageStoreProfile'
    else null
  end
  from (
    select lower(translate(btrim(coalesce(p_token, '')), 'İIı', 'iii')) as folded
  ) token
  where folded <> '';
$$;

create or replace function public.store_sub_admin_caller_matches(
  p_email text,
  p_phone text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return false;
  end if;
  return exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and (
        (
          p_email is not null
          and btrim(p_email) <> ''
          and lower(btrim(coalesce(u.email, ''))) = lower(btrim(p_email))
        )
        or (
          p_phone is not null
          and btrim(p_phone) <> ''
          and btrim(coalesce(u.phone, '')) = btrim(p_phone)
        )
      )
  );
end;
$$;

create or replace function public.user_can_collect_table_payment(
  p_seller_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or p_seller_id is null then
    return false;
  end if;
  if auth.uid() = p_seller_id then
    return true;
  end if;
  return exists (
    select 1
    from public.store_sub_admins sa
    join public.users u
      on u.id = auth.uid()
    where sa.store_id = p_seller_id
      and sa.status = 'active'
      and (
        (
          sa.email is not null
          and btrim(sa.email) <> ''
          and lower(btrim(coalesce(u.email, ''))) = lower(btrim(sa.email))
        )
        or (
          sa.phone is not null
          and btrim(sa.phone) <> ''
          and btrim(coalesce(u.phone, '')) = btrim(sa.phone)
        )
      )
      and exists (
        select 1
        from unnest(coalesce(sa.permissions, '{}'::text[])) as token(value)
        where public.normalize_staff_permission(token.value) in (
          'manageOrders',
          'fullAccess'
        )
      )
  );
end;
$$;

create or replace function public.guard_table_payment_staff_access()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.user_can_collect_table_payment(new.seller_id) then
    raise exception 'Bu restoran için ödeme yetkiniz yok.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create or replace function public.guard_store_sub_admin_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    raise exception 'Personel kaydı için oturum gerekli.'
      using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    if v_actor is distinct from new.store_id then
      raise exception 'Personel ekleme yalnızca işletme sahibine aittir.'
        using errcode = '42501';
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    if v_actor is distinct from old.store_id then
      raise exception 'Personel silme yalnızca işletme sahibine aittir.'
        using errcode = '42501';
    end if;
    return old;
  end if;

  if v_actor = old.store_id and v_actor = new.store_id then
    return new;
  end if;

  if new.store_id is distinct from old.store_id
     or new.id is distinct from old.id
     or new.permissions is distinct from old.permissions
     or btrim(coalesce(new.email, '')) is distinct from btrim(coalesce(old.email, ''))
     or btrim(coalesce(new.phone, '')) is distinct from btrim(coalesce(old.phone, ''))
  then
    raise exception 'Personel kendi yetkisini değiştiremez.'
      using errcode = '42501';
  end if;

  if old.status = 'invited'
     and new.status = 'active'
     and public.store_sub_admin_caller_matches(old.email, old.phone)
  then
    return new;
  end if;

  raise exception 'Personel kendi yetkisini değiştiremez.'
    using errcode = '42501';
end;
$$;

create or replace function public.activate_own_store_sub_admin_invites()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Oturum gerekli.' using errcode = '42501';
  end if;

  update public.store_sub_admins sa
  set status = 'active'
  where sa.status = 'invited'
    and public.store_sub_admin_caller_matches(sa.email, sa.phone);

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

do $$
begin
  if to_regclass('public.table_payments') is not null then
    drop trigger if exists trg_guard_table_payment_staff_access
      on public.table_payments;
    create trigger trg_guard_table_payment_staff_access
      before insert on public.table_payments
      for each row
      execute function public.guard_table_payment_staff_access();
  end if;

  if to_regclass('public.store_sub_admins') is not null then
    drop trigger if exists trg_guard_store_sub_admin_mutation
      on public.store_sub_admins;
    create trigger trg_guard_store_sub_admin_mutation
      before insert or update or delete on public.store_sub_admins
      for each row
      execute function public.guard_store_sub_admin_mutation();

    drop policy if exists store_sub_admins_self_read_invite
      on public.store_sub_admins;
    create policy store_sub_admins_self_read_invite
      on public.store_sub_admins
      for select
      to authenticated
      using (
        status = 'invited'
        and public.store_sub_admin_caller_matches(email, phone)
      );

    drop policy if exists store_sub_admins_self_activate
      on public.store_sub_admins;
    create policy store_sub_admins_self_activate
      on public.store_sub_admins
      for update
      to authenticated
      using (
        status = 'invited'
        and public.store_sub_admin_caller_matches(email, phone)
      )
      with check (
        status = 'active'
        and public.store_sub_admin_caller_matches(email, phone)
      );
  end if;
end
$$;

revoke all on function public.normalize_staff_permission(text) from public;
revoke all on function public.store_sub_admin_caller_matches(text, text) from public;
revoke all on function public.user_can_collect_table_payment(uuid) from public;
revoke all on function public.guard_table_payment_staff_access() from public;
revoke all on function public.guard_store_sub_admin_mutation() from public;
revoke all on function public.activate_own_store_sub_admin_invites() from public;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.normalize_staff_permission(text)
      to authenticated;
    grant execute on function public.store_sub_admin_caller_matches(text, text)
      to authenticated;
    grant execute on function public.user_can_collect_table_payment(uuid)
      to authenticated;
    grant execute on function public.activate_own_store_sub_admin_invites()
      to authenticated;
  end if;
end
$$;

comment on function public.user_can_collect_table_payment(uuid) is
  'Owner, or active staff with manageOrders / Tam Erişim, may record a table payment.';

comment on function public.activate_own_store_sub_admin_invites() is
  'Marks the caller''s own invited staff rows active. Does not change permissions.';

commit;
