-- Admin Finans modülü sağlamlaştırma patch'i (Faz 6).
-- Idempotent: güvenle tekrar çalıştırılabilir.
-- Mevcut SUPABASE_ADMIN_EXPENSES.sql ve SUPABASE_SELLER_PAYOUTS.sql dosyalarını bozmaz.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- admin_expenses: metin alanı güvenliği
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'admin_expenses_title_nonempty'
      and conrelid = 'public.admin_expenses'::regclass
  ) then
    alter table public.admin_expenses
      add constraint admin_expenses_title_nonempty
      check (char_length(trim(title)) > 0);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'admin_expenses_category_nonempty'
      and conrelid = 'public.admin_expenses'::regclass
  ) then
    alter table public.admin_expenses
      add constraint admin_expenses_category_nonempty
      check (char_length(trim(category)) > 0);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- seller_payouts: duplicate guard (seller + store + dönem)
-- ---------------------------------------------------------------------------
drop index if exists public.idx_seller_payouts_period_unique;

create unique index if not exists idx_seller_payouts_period_unique
  on public.seller_payouts (
    seller_id,
    coalesce(store_id, '00000000-0000-0000-0000-000000000000'::uuid),
    period_start,
    period_end
  )
  where status <> 'cancelled';

-- ---------------------------------------------------------------------------
-- seller_payouts: status transition + paid alan koruması
-- ---------------------------------------------------------------------------
create or replace function public.enforce_seller_payout_status_transition()
returns trigger
language plpgsql
as $$
declare
  allowed boolean := false;
begin
  if tg_op = 'INSERT' then
    if new.status not in ('pending', 'approved', 'paid', 'disputed', 'cancelled') then
      raise exception 'Geçersiz hakediş durumu: %', new.status;
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    -- Ödenmiş kayıt geri alınamaz; ödeme alanları korunur.
    if old.status = 'paid' then
      if new.status is distinct from old.status and new.status <> 'paid' then
        raise exception 'Ödenmiş hakediş durumu değiştirilemez.';
      end if;
      new.status := old.status;
      new.paid_at := old.paid_at;
      new.paid_by := old.paid_by;
      new.payment_method := old.payment_method;
      new.payment_reference := old.payment_reference;
      new.approved_at := old.approved_at;
      new.approved_by := old.approved_by;
    end if;

    if old.status = 'cancelled' and new.status is distinct from old.status then
      raise exception 'İptal edilmiş hakediş durumu değiştirilemez.';
    end if;

    if old.status is distinct from new.status then
      allowed := case
        when old.status = 'pending' and new.status in ('approved', 'disputed', 'cancelled') then true
        when old.status = 'approved' and new.status in ('paid', 'disputed', 'cancelled') then true
        when old.status = 'disputed' and new.status in ('approved', 'cancelled') then true
        else false
      end;
      if not allowed then
        raise exception 'Geçersiz hakediş durum geçişi: % -> %', old.status, new.status;
      end if;
    end if;

    if new.approved_by is not null
      and not exists (select 1 from public.users u where u.id = new.approved_by) then
      new.approved_by := null;
    end if;

    if new.paid_by is not null
      and not exists (select 1 from public.users u where u.id = new.paid_by) then
      new.paid_by := null;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists seller_payouts_status_guard on public.seller_payouts;
create trigger seller_payouts_status_guard
before insert or update on public.seller_payouts
for each row execute function public.enforce_seller_payout_status_transition();

-- ---------------------------------------------------------------------------
-- seller_payouts RLS: seller sadece okur, admin yönetir
-- ---------------------------------------------------------------------------
alter table public.admin_expenses enable row level security;
alter table public.seller_payouts enable row level security;

drop policy if exists "seller_payouts_admin_select" on public.seller_payouts;
drop policy if exists "seller_payouts_admin_manage" on public.seller_payouts;
drop policy if exists "seller_payouts_seller_select" on public.seller_payouts;
drop policy if exists "seller_payouts_admin_insert" on public.seller_payouts;
drop policy if exists "seller_payouts_admin_update" on public.seller_payouts;
drop policy if exists "seller_payouts_admin_delete" on public.seller_payouts;

create policy "seller_payouts_seller_select"
on public.seller_payouts
for select
to authenticated
using (seller_id = auth.uid());

create policy "seller_payouts_admin_select"
on public.seller_payouts
for select
to authenticated
using (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
);

create policy "seller_payouts_admin_insert"
on public.seller_payouts
for insert
to authenticated
with check (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
);

create policy "seller_payouts_admin_update"
on public.seller_payouts
for update
to authenticated
using (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
)
with check (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
);

create policy "seller_payouts_admin_delete"
on public.seller_payouts
for delete
to authenticated
using (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
);

-- admin_expenses: seller erişimi yok (mevcut policy'leri yeniden doğrula)
drop policy if exists "admin_expenses_select" on public.admin_expenses;
drop policy if exists "admin_expenses_manage" on public.admin_expenses;
drop policy if exists "admin_expenses_insert" on public.admin_expenses;
drop policy if exists "admin_expenses_update" on public.admin_expenses;
drop policy if exists "admin_expenses_delete" on public.admin_expenses;

create policy "admin_expenses_select"
on public.admin_expenses
for select
to authenticated
using (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
);

create policy "admin_expenses_insert"
on public.admin_expenses
for insert
to authenticated
with check (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
);

create policy "admin_expenses_update"
on public.admin_expenses
for update
to authenticated
using (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
)
with check (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
);

create policy "admin_expenses_delete"
on public.admin_expenses
for delete
to authenticated
using (
  public.current_admin_has_module('finance')
  or public.current_user_role() = 'super_admin'
);
