-- ============================================================
-- Migration: Ensure finance RPC functions exist
-- Purpose: Fix "finance_get_monthly_trend(...) not found"
-- Safe to run multiple times.
-- IMPORTANT:
--   Run SUPABASE_FINANCE_MODULE.sql first.
--   This file only creates RPC functions after core tables exist.
-- ============================================================

DO $$
BEGIN
	IF to_regclass('public.finance_cash_accounts') IS NULL
		 OR to_regclass('public.finance_income_records') IS NULL
		 OR to_regclass('public.finance_expenses') IS NULL
		 OR to_regclass('public.finance_debts') IS NULL
		 OR to_regclass('public.finance_salary_records') IS NULL THEN
		RAISE EXCEPTION
			'Finance tables are missing. Run SUPABASE_FINANCE_MODULE.sql first.';
	END IF;
END $$;

DROP FUNCTION IF EXISTS public.finance_get_overview(uuid);
DROP FUNCTION IF EXISTS public.finance_get_monthly_trend(uuid, int);

CREATE OR REPLACE FUNCTION public.finance_get_overview(p_seller_id uuid)
RETURNS TABLE (
	total_cash_balance numeric,
	total_bank_balance numeric,
	pending_collections numeric,
	pending_payments numeric,
	total_debt numeric,
	month_salary_load numeric,
	month_income numeric,
	month_expense numeric,
	overdue_payments integer,
	upcoming_payments integer,
	overdue_debts integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
WITH current_month AS (
	SELECT
		date_trunc('month', now())::date AS month_start,
		(date_trunc('month', now()) + interval '1 month - 1 day')::date AS month_end,
		current_date AS today,
		(current_date + interval '7 day')::date AS next_week
),
cash_accounts AS (
	SELECT
		COALESCE(sum(CASE WHEN account_type = 'cash' THEN current_balance ELSE 0 END), 0) AS total_cash_balance,
		COALESCE(sum(CASE WHEN account_type <> 'cash' THEN current_balance ELSE 0 END), 0) AS total_bank_balance
	FROM public.finance_cash_accounts
	WHERE seller_id = p_seller_id
		AND is_active = true
),
income_stats AS (
	SELECT
		COALESCE(sum(CASE WHEN is_collected = false THEN net_amount ELSE 0 END), 0) AS pending_collections,
		COALESCE(sum(CASE
			WHEN income_date BETWEEN (SELECT month_start FROM current_month)
					 AND (SELECT month_end FROM current_month)
			THEN net_amount ELSE 0 END), 0) AS month_income
	FROM public.finance_income_records
	WHERE seller_id = p_seller_id
),
expense_stats AS (
	SELECT
		COALESCE(sum(CASE WHEN is_paid = false THEN amount ELSE 0 END), 0) AS pending_payments,
		COALESCE(sum(CASE
			WHEN expense_date BETWEEN (SELECT month_start FROM current_month)
					 AND (SELECT month_end FROM current_month)
			THEN amount ELSE 0 END), 0) AS month_expense,
		count(*) FILTER (
			WHERE is_paid = false
				AND due_date IS NOT NULL
				AND due_date < (SELECT today FROM current_month)
		)::int AS overdue_payments,
		count(*) FILTER (
			WHERE is_paid = false
				AND due_date IS NOT NULL
				AND due_date >= (SELECT today FROM current_month)
				AND due_date <= (SELECT next_week FROM current_month)
		)::int AS upcoming_expense_payments
	FROM public.finance_expenses
	WHERE seller_id = p_seller_id
),
debt_stats AS (
	SELECT
		COALESCE(sum(CASE
			WHEN status NOT IN ('paid', 'cancelled')
			THEN greatest(original_amount - paid_amount, 0)
			ELSE 0 END), 0) AS total_debt,
		count(*) FILTER (
			WHERE status NOT IN ('paid', 'cancelled')
				AND due_date IS NOT NULL
				AND due_date < (SELECT today FROM current_month)
				AND greatest(original_amount - paid_amount, 0) > 0
		)::int AS overdue_debts,
		count(*) FILTER (
			WHERE status NOT IN ('paid', 'cancelled')
				AND due_date IS NOT NULL
				AND due_date >= (SELECT today FROM current_month)
				AND due_date <= (SELECT next_week FROM current_month)
				AND greatest(original_amount - paid_amount, 0) > 0
		)::int AS upcoming_debt_payments
	FROM public.finance_debts
	WHERE seller_id = p_seller_id
),
salary_stats AS (
	SELECT
		COALESCE(sum(net_salary), 0) AS month_salary_load
	FROM public.finance_salary_records
	WHERE seller_id = p_seller_id
		AND period_year = extract(year from now())::int
		AND period_month = extract(month from now())::int
)
SELECT
	cash_accounts.total_cash_balance,
	cash_accounts.total_bank_balance,
	income_stats.pending_collections,
	expense_stats.pending_payments,
	debt_stats.total_debt,
	salary_stats.month_salary_load,
	income_stats.month_income,
	expense_stats.month_expense,
	expense_stats.overdue_payments,
	(expense_stats.upcoming_expense_payments + debt_stats.upcoming_debt_payments)::int AS upcoming_payments,
	debt_stats.overdue_debts
FROM cash_accounts, income_stats, expense_stats, debt_stats, salary_stats;
$$;

CREATE OR REPLACE FUNCTION public.finance_get_monthly_trend(
	p_seller_id uuid,
	p_months int DEFAULT 6
)
RETURNS TABLE (
	label text,
	yr int,
	mo int,
	income numeric,
	expense numeric,
	net numeric
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
WITH months AS (
	SELECT
		gs::date AS month_start,
		extract(year from gs)::int AS yr,
		extract(month from gs)::int AS mo
	FROM generate_series(
		date_trunc('month', now())::date - ((greatest(p_months, 1) - 1) * interval '1 month'),
		date_trunc('month', now())::date,
		interval '1 month'
	) AS gs
),
income_by_month AS (
	SELECT
		extract(year from income_date)::int AS yr,
		extract(month from income_date)::int AS mo,
		COALESCE(sum(net_amount), 0) AS income
	FROM public.finance_income_records
	WHERE seller_id = p_seller_id
	GROUP BY 1, 2
),
expense_by_month AS (
	SELECT
		extract(year from expense_date)::int AS yr,
		extract(month from expense_date)::int AS mo,
		COALESCE(sum(amount), 0) AS expense
	FROM public.finance_expenses
	WHERE seller_id = p_seller_id
	GROUP BY 1, 2
),
salary_by_month AS (
	SELECT
		period_year AS yr,
		period_month AS mo,
		COALESCE(sum(net_salary), 0) AS salary_expense
	FROM public.finance_salary_records
	WHERE seller_id = p_seller_id
	GROUP BY 1, 2
)
SELECT
	to_char(months.month_start, 'Mon') AS label,
	months.yr,
	months.mo,
	COALESCE(income_by_month.income, 0) AS income,
	COALESCE(expense_by_month.expense, 0) + COALESCE(salary_by_month.salary_expense, 0) AS expense,
	COALESCE(income_by_month.income, 0)
		- (COALESCE(expense_by_month.expense, 0) + COALESCE(salary_by_month.salary_expense, 0)) AS net
FROM months
LEFT JOIN income_by_month
	ON income_by_month.yr = months.yr AND income_by_month.mo = months.mo
LEFT JOIN expense_by_month
	ON expense_by_month.yr = months.yr AND expense_by_month.mo = months.mo
LEFT JOIN salary_by_month
	ON salary_by_month.yr = months.yr AND salary_by_month.mo = months.mo
ORDER BY months.month_start;
$$;

GRANT EXECUTE ON FUNCTION public.finance_get_overview(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finance_get_monthly_trend(uuid, int) TO authenticated;

NOTIFY pgrst, 'reload schema';
