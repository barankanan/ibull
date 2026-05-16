-- ============================================================
-- Migration: Finans / Muhasebe Modülü
-- Restaurant Management App — Production Grade
-- Supabase SQL Editor'da bir kez çalıştır.
-- Idempotent — IF NOT EXISTS kullanılmaktadır.
-- ============================================================

-- ─────────────────────────────────────────
-- 0. Yardımcı fonksiyon: updated_at trigger
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────
-- 1. finance_suppliers — Tedarikçiler
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.finance_suppliers (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name          text        NOT NULL,
  contact_name  text,
  phone         text,
  email         text,
  address       text,
  tax_number    text,
  notes         text,
  is_active     boolean     NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS finance_suppliers_updated_at ON public.finance_suppliers;
CREATE TRIGGER finance_suppliers_updated_at
  BEFORE UPDATE ON public.finance_suppliers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─────────────────────────────────────────
-- 2. finance_cash_accounts — Kasa & Banka Hesapları
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.finance_cash_accounts (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id       uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name            text        NOT NULL,
  account_type    text        NOT NULL DEFAULT 'cash',
  bank_name       text,
  iban            text,
  currency        text        NOT NULL DEFAULT 'TRY',
  current_balance numeric(15,2) NOT NULL DEFAULT 0,
  is_default      boolean     NOT NULL DEFAULT false,
  is_active       boolean     NOT NULL DEFAULT true,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT finance_cash_accounts_type_check
    CHECK (account_type IN ('cash','bank','pos','courier','branch','partner'))
);

DROP TRIGGER IF EXISTS finance_cash_accounts_updated_at ON public.finance_cash_accounts;
CREATE TRIGGER finance_cash_accounts_updated_at
  BEFORE UPDATE ON public.finance_cash_accounts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─────────────────────────────────────────
-- 3. finance_cash_movements — Kasa Hareketleri
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.finance_cash_movements (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id       uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  account_id      uuid        NOT NULL REFERENCES public.finance_cash_accounts(id) ON DELETE CASCADE,
  movement_type   text        NOT NULL,
  amount          numeric(15,2) NOT NULL CHECK (amount > 0),
  direction       text        NOT NULL,
  reference_id    uuid,
  reference_type  text,
  description     text,
  document_url    text,
  movement_date   date        NOT NULL DEFAULT CURRENT_DATE,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT finance_cash_movements_type_check
    CHECK (movement_type IN ('opening','closing','income','expense','transfer',
                             'salary_payment','supplier_payment','correction','other')),
  CONSTRAINT finance_cash_movements_direction_check
    CHECK (direction IN ('in','out'))
);

-- Trigger: bakiyeyi otomatik güncelle
CREATE OR REPLACE FUNCTION public.finance_update_account_balance()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.direction = 'in' THEN
      UPDATE public.finance_cash_accounts
        SET current_balance = current_balance + NEW.amount
        WHERE id = NEW.account_id;
    ELSE
      UPDATE public.finance_cash_accounts
        SET current_balance = current_balance - NEW.amount
        WHERE id = NEW.account_id;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.direction = 'in' THEN
      UPDATE public.finance_cash_accounts
        SET current_balance = current_balance - OLD.amount
        WHERE id = OLD.account_id;
    ELSE
      UPDATE public.finance_cash_accounts
        SET current_balance = current_balance + OLD.amount
        WHERE id = OLD.account_id;
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS finance_cash_movements_balance ON public.finance_cash_movements;
CREATE TRIGGER finance_cash_movements_balance
  AFTER INSERT OR DELETE ON public.finance_cash_movements
  FOR EACH ROW EXECUTE FUNCTION public.finance_update_account_balance();

-- ─────────────────────────────────────────
-- 4. finance_income_records — Gelir Kayıtları
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.finance_income_records (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id       uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  income_type     text        NOT NULL DEFAULT 'other',
  source          text,
  gross_amount    numeric(15,2) NOT NULL CHECK (gross_amount >= 0),
  net_amount      numeric(15,2) NOT NULL CHECK (net_amount >= 0),
  tax_amount      numeric(15,2) NOT NULL DEFAULT 0,
  is_collected    boolean     NOT NULL DEFAULT false,
  collected_at    timestamptz,
  account_id      uuid        REFERENCES public.finance_cash_accounts(id),
  period_month    smallint    CHECK (period_month BETWEEN 1 AND 12),
  period_year     smallint,
  branch_id       uuid,
  description     text,
  document_url    text,
  income_date     date        NOT NULL DEFAULT CURRENT_DATE,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT finance_income_records_type_check
    CHECK (income_type IN ('sales','delivery','platform','commission','rental','other'))
);

-- ─────────────────────────────────────────
-- 5. finance_expenses — Gider Kayıtları
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.finance_expenses (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id           uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category            text        NOT NULL DEFAULT 'other',
  supplier_id         uuid        REFERENCES public.finance_suppliers(id),
  amount              numeric(15,2) NOT NULL CHECK (amount >= 0),
  is_paid             boolean     NOT NULL DEFAULT false,
  paid_at             timestamptz,
  due_date            date,
  account_id          uuid        REFERENCES public.finance_cash_accounts(id),
  description         text,
  document_url        text,
  expense_date        date        NOT NULL DEFAULT CURRENT_DATE,
  is_recurring        boolean     NOT NULL DEFAULT false,
  recurring_interval  text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT finance_expenses_category_check
    CHECK (category IN ('rent','electricity','water','gas','internet','cleaning',
                        'packaging','advertising','accounting','software','tax',
                        'maintenance','salary','sgk','other')),
  CONSTRAINT finance_expenses_recurring_check
    CHECK (recurring_interval IS NULL OR
           recurring_interval IN ('weekly','monthly','quarterly','yearly'))
);

-- ─────────────────────────────────────────
-- 6. finance_debts — Borç Kayıtları
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.finance_debts (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id       uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  debt_type       text        NOT NULL DEFAULT 'other',
  creditor_name   text        NOT NULL,
  supplier_id     uuid        REFERENCES public.finance_suppliers(id),
  original_amount numeric(15,2) NOT NULL CHECK (original_amount > 0),
  paid_amount     numeric(15,2) NOT NULL DEFAULT 0 CHECK (paid_amount >= 0),
  start_date      date        NOT NULL DEFAULT CURRENT_DATE,
  due_date        date,
  status          text        NOT NULL DEFAULT 'active',
  description     text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT finance_debts_type_check
    CHECK (debt_type IN ('supplier','credit','rent','tax','sgk','partner',
                         'employee_advance','other')),
  CONSTRAINT finance_debts_status_check
    CHECK (status IN ('active','partially_paid','paid','overdue','cancelled')),
  CONSTRAINT finance_debts_paid_not_exceed_original
    CHECK (paid_amount <= original_amount)
);

DROP TRIGGER IF EXISTS finance_debts_updated_at ON public.finance_debts;
CREATE TRIGGER finance_debts_updated_at
  BEFORE UPDATE ON public.finance_debts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Computed column: remaining_amount (view için)
-- Uygulama katmanında: remaining = original - paid hesaplanır.

-- Trigger: debt status otomatik güncelle
CREATE OR REPLACE FUNCTION public.finance_update_debt_status()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.paid_amount >= NEW.original_amount THEN
    NEW.status = 'paid';
  ELSIF NEW.paid_amount > 0 THEN
    NEW.status = 'partially_paid';
  ELSIF NEW.due_date IS NOT NULL AND NEW.due_date < CURRENT_DATE AND NEW.status = 'active' THEN
    NEW.status = 'overdue';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS finance_debts_auto_status ON public.finance_debts;
CREATE TRIGGER finance_debts_auto_status
  BEFORE INSERT OR UPDATE ON public.finance_debts
  FOR EACH ROW EXECUTE FUNCTION public.finance_update_debt_status();

-- ─────────────────────────────────────────
-- 7. finance_debt_payments — Borç Ödemeleri
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.finance_debt_payments (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  debt_id       uuid        NOT NULL REFERENCES public.finance_debts(id) ON DELETE CASCADE,
  amount        numeric(15,2) NOT NULL CHECK (amount > 0),
  payment_date  date        NOT NULL DEFAULT CURRENT_DATE,
  account_id    uuid        REFERENCES public.finance_cash_accounts(id),
  description   text,
  document_url  text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Trigger: borç paid_amount otomatik güncelle
CREATE OR REPLACE FUNCTION public.finance_sync_debt_paid()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_total numeric(15,2);
  v_debt  RECORD;
BEGIN
  IF TG_OP IN ('INSERT','UPDATE','DELETE') THEN
    SELECT SUM(amount) INTO v_total
    FROM public.finance_debt_payments
    WHERE debt_id = COALESCE(NEW.debt_id, OLD.debt_id);

    UPDATE public.finance_debts
    SET paid_amount = COALESCE(v_total, 0)
    WHERE id = COALESCE(NEW.debt_id, OLD.debt_id);
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS finance_debt_payments_sync ON public.finance_debt_payments;
CREATE TRIGGER finance_debt_payments_sync
  AFTER INSERT OR UPDATE OR DELETE ON public.finance_debt_payments
  FOR EACH ROW EXECUTE FUNCTION public.finance_sync_debt_paid();

-- ─────────────────────────────────────────
-- 8. finance_employees — Personel
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.finance_employees (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name     text        NOT NULL,
  position      text,
  base_salary   numeric(15,2) NOT NULL DEFAULT 0 CHECK (base_salary >= 0),
  payment_day   smallint    NOT NULL DEFAULT 1 CHECK (payment_day BETWEEN 1 AND 28),
  is_active     boolean     NOT NULL DEFAULT true,
  hire_date     date,
  phone         text,
  iban          text,
  notes         text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS finance_employees_updated_at ON public.finance_employees;
CREATE TRIGGER finance_employees_updated_at
  BEFORE UPDATE ON public.finance_employees
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─────────────────────────────────────────
-- 9. finance_salary_records — Aylık Maaş Kartı
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.finance_salary_records (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id         uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  employee_id       uuid        NOT NULL REFERENCES public.finance_employees(id) ON DELETE CASCADE,
  period_month      smallint    NOT NULL CHECK (period_month BETWEEN 1 AND 12),
  period_year       smallint    NOT NULL,
  base_salary       numeric(15,2) NOT NULL DEFAULT 0,
  bonus             numeric(15,2) NOT NULL DEFAULT 0,
  overtime          numeric(15,2) NOT NULL DEFAULT 0,
  deduction         numeric(15,2) NOT NULL DEFAULT 0,
  advance_deduction numeric(15,2) NOT NULL DEFAULT 0,
  net_salary        numeric(15,2) NOT NULL DEFAULT 0,
  status            text        NOT NULL DEFAULT 'pending',
  paid_amount       numeric(15,2) NOT NULL DEFAULT 0,
  notes             text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (employee_id, period_month, period_year),
  CONSTRAINT finance_salary_status_check
    CHECK (status IN ('pending','partial','paid'))
);

DROP TRIGGER IF EXISTS finance_salary_records_updated_at ON public.finance_salary_records;
CREATE TRIGGER finance_salary_records_updated_at
  BEFORE UPDATE ON public.finance_salary_records
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- net_salary otomatik hesapla
CREATE OR REPLACE FUNCTION public.finance_calc_net_salary()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.net_salary = NEW.base_salary + NEW.bonus + NEW.overtime
                   - NEW.deduction - NEW.advance_deduction;
  IF NEW.net_salary < 0 THEN NEW.net_salary = 0; END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS finance_salary_calc ON public.finance_salary_records;
CREATE TRIGGER finance_salary_calc
  BEFORE INSERT OR UPDATE ON public.finance_salary_records
  FOR EACH ROW EXECUTE FUNCTION public.finance_calc_net_salary();

-- ─────────────────────────────────────────
-- 10. finance_salary_payments — Maaş Ödemeleri
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.finance_salary_payments (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id         uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  salary_record_id  uuid        NOT NULL REFERENCES public.finance_salary_records(id) ON DELETE CASCADE,
  amount            numeric(15,2) NOT NULL CHECK (amount > 0),
  payment_date      date        NOT NULL DEFAULT CURRENT_DATE,
  account_id        uuid        REFERENCES public.finance_cash_accounts(id),
  description       text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- Trigger: salary paid_amount ve status güncelle
CREATE OR REPLACE FUNCTION public.finance_sync_salary_paid()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_total  numeric(15,2);
  v_net    numeric(15,2);
BEGIN
  SELECT SUM(fp.amount), sr.net_salary
  INTO v_total, v_net
  FROM public.finance_salary_payments fp
  JOIN public.finance_salary_records sr ON sr.id = fp.salary_record_id
  WHERE fp.salary_record_id = COALESCE(NEW.salary_record_id, OLD.salary_record_id)
  GROUP BY sr.net_salary;

  UPDATE public.finance_salary_records
  SET
    paid_amount = COALESCE(v_total, 0),
    status = CASE
               WHEN COALESCE(v_total, 0) <= 0      THEN 'pending'
               WHEN COALESCE(v_total, 0) >= v_net  THEN 'paid'
               ELSE 'partial'
             END
  WHERE id = COALESCE(NEW.salary_record_id, OLD.salary_record_id);

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS finance_salary_payments_sync ON public.finance_salary_payments;
CREATE TRIGGER finance_salary_payments_sync
  AFTER INSERT OR UPDATE OR DELETE ON public.finance_salary_payments
  FOR EACH ROW EXECUTE FUNCTION public.finance_sync_salary_paid();

-- ─────────────────────────────────────────
-- 11. finance_reconciliation_notes — Mutabakat Notları
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.finance_reconciliation_notes (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id           uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject             text        NOT NULL,
  note_date           date        NOT NULL DEFAULT CURRENT_DATE,
  related_account_id  uuid        REFERENCES public.finance_cash_accounts(id),
  expected_amount     numeric(15,2),
  actual_amount       numeric(15,2),
  status              text        NOT NULL DEFAULT 'open',
  responsible_person  text,
  due_date            date,
  description         text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT finance_reconciliation_status_check
    CHECK (status IN ('open','resolved','pending'))
);

DROP TRIGGER IF EXISTS finance_reconciliation_notes_updated_at ON public.finance_reconciliation_notes;
CREATE TRIGGER finance_reconciliation_notes_updated_at
  BEFORE UPDATE ON public.finance_reconciliation_notes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─────────────────────────────────────────
-- 12. finance_company_settings — Şirket Ayarları
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.finance_company_settings (
  id                         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id                  uuid        NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  company_name               text,
  tax_number                 text,
  tax_office                 text,
  address                    text,
  phone                      text,
  email                      text,
  fiscal_year_start          smallint    NOT NULL DEFAULT 1
                               CHECK (fiscal_year_start BETWEEN 1 AND 12),
  default_currency           text        NOT NULL DEFAULT 'TRY',
  platform_commission_rate   numeric(5,4) NOT NULL DEFAULT 0.15,
  default_cash_account_id    uuid        REFERENCES public.finance_cash_accounts(id),
  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS finance_company_settings_updated_at ON public.finance_company_settings;
CREATE TRIGGER finance_company_settings_updated_at
  BEFORE UPDATE ON public.finance_company_settings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─────────────────────────────────────────
-- INDEXES
-- ─────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_fin_suppliers_seller       ON public.finance_suppliers(seller_id);
CREATE INDEX IF NOT EXISTS idx_fin_cash_acc_seller        ON public.finance_cash_accounts(seller_id);
CREATE INDEX IF NOT EXISTS idx_fin_cash_mov_seller        ON public.finance_cash_movements(seller_id);
CREATE INDEX IF NOT EXISTS idx_fin_cash_mov_account       ON public.finance_cash_movements(account_id);
CREATE INDEX IF NOT EXISTS idx_fin_cash_mov_date          ON public.finance_cash_movements(movement_date DESC);
CREATE INDEX IF NOT EXISTS idx_fin_income_seller          ON public.finance_income_records(seller_id);
CREATE INDEX IF NOT EXISTS idx_fin_income_date            ON public.finance_income_records(income_date DESC);
CREATE INDEX IF NOT EXISTS idx_fin_income_period          ON public.finance_income_records(seller_id, period_year, period_month);
CREATE INDEX IF NOT EXISTS idx_fin_expense_seller         ON public.finance_expenses(seller_id);
CREATE INDEX IF NOT EXISTS idx_fin_expense_date           ON public.finance_expenses(expense_date DESC);
CREATE INDEX IF NOT EXISTS idx_fin_expense_due            ON public.finance_expenses(seller_id, due_date) WHERE is_paid = false;
CREATE INDEX IF NOT EXISTS idx_fin_debts_seller           ON public.finance_debts(seller_id);
CREATE INDEX IF NOT EXISTS idx_fin_debts_status           ON public.finance_debts(seller_id, status);
CREATE INDEX IF NOT EXISTS idx_fin_debt_payments_debt     ON public.finance_debt_payments(debt_id);
CREATE INDEX IF NOT EXISTS idx_fin_employees_seller       ON public.finance_employees(seller_id) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_fin_salary_records_seller  ON public.finance_salary_records(seller_id);
CREATE INDEX IF NOT EXISTS idx_fin_salary_records_period  ON public.finance_salary_records(seller_id, period_year DESC, period_month DESC);
CREATE INDEX IF NOT EXISTS idx_fin_salary_payments_record ON public.finance_salary_payments(salary_record_id);
CREATE INDEX IF NOT EXISTS idx_fin_recon_seller           ON public.finance_reconciliation_notes(seller_id);
CREATE INDEX IF NOT EXISTS idx_fin_recon_status           ON public.finance_reconciliation_notes(seller_id, status);

-- ─────────────────────────────────────────
-- ROW LEVEL SECURITY (RLS)
-- ─────────────────────────────────────────
ALTER TABLE public.finance_suppliers             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_cash_accounts         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_cash_movements        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_income_records        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_expenses              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_debts                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_debt_payments         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_employees             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_salary_records        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_salary_payments       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_reconciliation_notes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_company_settings      ENABLE ROW LEVEL SECURITY;

-- Helper: seller check
-- Her tablo için CRUD politikaları (seller kendi verisine tam erişim)
DO $$
DECLARE
  tbl text;
  tbls text[] := ARRAY[
    'finance_suppliers',
    'finance_cash_accounts',
    'finance_cash_movements',
    'finance_income_records',
    'finance_expenses',
    'finance_debts',
    'finance_debt_payments',
    'finance_employees',
    'finance_salary_records',
    'finance_salary_payments',
    'finance_reconciliation_notes',
    'finance_company_settings'
  ];
BEGIN
  FOREACH tbl IN ARRAY tbls LOOP
    EXECUTE format('
      DROP POLICY IF EXISTS "%s_seller_all" ON public.%I;
      CREATE POLICY "%s_seller_all" ON public.%I
        FOR ALL
        TO authenticated
        USING (seller_id = auth.uid())
        WITH CHECK (seller_id = auth.uid());
    ', tbl, tbl, tbl, tbl);
  END LOOP;
END;
$$;

-- ─────────────────────────────────────────
-- RPC: Genel bakış KPI özeti
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.finance_get_overview(p_seller_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
  v_month  int := EXTRACT(MONTH FROM CURRENT_DATE);
  v_year   int := EXTRACT(YEAR FROM CURRENT_DATE);
BEGIN
  -- Yalnızca sahibi çağırabilir
  IF auth.uid() <> p_seller_id THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  SELECT jsonb_build_object(
    'total_cash_balance',
      COALESCE((SELECT SUM(current_balance)
                FROM public.finance_cash_accounts
                WHERE seller_id = p_seller_id AND is_active = true
                  AND account_type = 'cash'), 0),

    'total_bank_balance',
      COALESCE((SELECT SUM(current_balance)
                FROM public.finance_cash_accounts
                WHERE seller_id = p_seller_id AND is_active = true
                  AND account_type IN ('bank','pos')), 0),

    'total_debt',
      COALESCE((SELECT SUM(original_amount - paid_amount)
                FROM public.finance_debts
                WHERE seller_id = p_seller_id
                  AND status NOT IN ('paid','cancelled')), 0),

    'pending_collections',
      COALESCE((SELECT SUM(gross_amount)
                FROM public.finance_income_records
                WHERE seller_id = p_seller_id AND is_collected = false), 0),

    'pending_payments',
      COALESCE((SELECT SUM(amount)
                FROM public.finance_expenses
                WHERE seller_id = p_seller_id AND is_paid = false), 0),

    'month_salary_load',
      COALESCE((SELECT SUM(net_salary)
                FROM public.finance_salary_records
                WHERE seller_id = p_seller_id
                  AND period_month = v_month AND period_year = v_year), 0),

    'month_income',
      COALESCE((SELECT SUM(net_amount)
                FROM public.finance_income_records
                WHERE seller_id = p_seller_id
                  AND EXTRACT(MONTH FROM income_date) = v_month
                  AND EXTRACT(YEAR FROM income_date) = v_year
                  AND is_collected = true), 0),

    'month_expense',
      COALESCE((SELECT SUM(amount)
                FROM public.finance_expenses
                WHERE seller_id = p_seller_id
                  AND EXTRACT(MONTH FROM expense_date) = v_month
                  AND EXTRACT(YEAR FROM expense_date) = v_year
                  AND is_paid = true), 0),

    'overdue_payments',
      COALESCE((SELECT COUNT(*)
                FROM public.finance_expenses
                WHERE seller_id = p_seller_id
                  AND is_paid = false
                  AND due_date < CURRENT_DATE), 0),

    'upcoming_payments',
      COALESCE((SELECT COUNT(*)
                FROM public.finance_expenses
                WHERE seller_id = p_seller_id
                  AND is_paid = false
                  AND due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'), 0),

    'overdue_debts',
      COALESCE((SELECT COUNT(*)
                FROM public.finance_debts
                WHERE seller_id = p_seller_id AND status = 'overdue'), 0)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ─────────────────────────────────────────
-- RPC: Aylık gelir/gider trend (son 6 ay)
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.finance_get_monthly_trend(p_seller_id uuid, p_months int DEFAULT 6)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF auth.uid() <> p_seller_id THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  SELECT jsonb_agg(row_to_json(t)) INTO v_result
  FROM (
    WITH months AS (
      SELECT
        EXTRACT(YEAR FROM d)::int  AS yr,
        EXTRACT(MONTH FROM d)::int AS mo,
        TO_CHAR(d, 'Mon YYYY')    AS label
      FROM generate_series(
        date_trunc('month', CURRENT_DATE) - ((p_months - 1) || ' months')::interval,
        date_trunc('month', CURRENT_DATE),
        '1 month'::interval
      ) AS d
    )
    SELECT
      m.label,
      m.yr,
      m.mo,
      COALESCE(i.total_income, 0) AS income,
      COALESCE(e.total_expense, 0) AS expense,
      COALESCE(i.total_income, 0) - COALESCE(e.total_expense, 0) AS net
    FROM months m
    LEFT JOIN (
      SELECT
        EXTRACT(YEAR FROM income_date)::int  AS yr,
        EXTRACT(MONTH FROM income_date)::int AS mo,
        SUM(net_amount) AS total_income
      FROM public.finance_income_records
      WHERE seller_id = p_seller_id AND is_collected = true
      GROUP BY 1, 2
    ) i ON i.yr = m.yr AND i.mo = m.mo
    LEFT JOIN (
      SELECT
        EXTRACT(YEAR FROM expense_date)::int  AS yr,
        EXTRACT(MONTH FROM expense_date)::int AS mo,
        SUM(amount) AS total_expense
      FROM public.finance_expenses
      WHERE seller_id = p_seller_id AND is_paid = true
      GROUP BY 1, 2
    ) e ON e.yr = m.yr AND e.mo = m.mo
    ORDER BY m.yr, m.mo
  ) t;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ─────────────────────────────────────────
-- Schema cache yenile
-- ─────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
