DO $$
BEGIN
  IF to_regclass('public.finance_cash_accounts') IS NULL
     OR to_regclass('public.finance_cash_movements') IS NULL
     OR to_regclass('public.finance_expenses') IS NULL
     OR to_regclass('public.finance_debts') IS NULL
     OR to_regclass('public.finance_debt_payments') IS NULL THEN
    RAISE EXCEPTION 'Finance base tables are missing. Run SUPABASE_FINANCE_MODULE.sql first.';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.finance_transfer_cash(
  p_seller_id uuid,
  p_from_account_id uuid,
  p_to_account_id uuid,
  p_amount numeric,
  p_description text DEFAULT NULL,
  p_movement_date date DEFAULT CURRENT_DATE
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ref_id uuid := gen_random_uuid();
BEGIN
  IF p_from_account_id IS NULL OR p_to_account_id IS NULL OR p_from_account_id = p_to_account_id THEN
    RAISE EXCEPTION 'Geçerli iki farklı hesap seçilmelidir.';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Transfer tutarı sıfırdan büyük olmalıdır.';
  END IF;

  INSERT INTO public.finance_cash_movements (
    seller_id, account_id, movement_type, amount, direction, reference_id, reference_type, description, movement_date
  ) VALUES (
    p_seller_id, p_from_account_id, 'transfer', p_amount, 'out', v_ref_id, 'account_transfer', COALESCE(p_description, 'Hesaplar arası transfer'), p_movement_date
  );

  INSERT INTO public.finance_cash_movements (
    seller_id, account_id, movement_type, amount, direction, reference_id, reference_type, description, movement_date
  ) VALUES (
    p_seller_id, p_to_account_id, 'transfer', p_amount, 'in', v_ref_id, 'account_transfer', COALESCE(p_description, 'Hesaplar arası transfer'), p_movement_date
  );

  RETURN jsonb_build_object('reference_id', v_ref_id, 'amount', p_amount);
END;
$$;

CREATE OR REPLACE FUNCTION public.finance_record_debt_payment(
  p_seller_id uuid,
  p_debt_id uuid,
  p_amount numeric,
  p_account_id uuid DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_payment_date date DEFAULT CURRENT_DATE,
  p_create_cash_movement boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_payment_id uuid;
  v_ref_id uuid := gen_random_uuid();
  v_debt_type text;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Ödeme tutarı sıfırdan büyük olmalıdır.';
  END IF;

  SELECT debt_type INTO v_debt_type
  FROM public.finance_debts
  WHERE id = p_debt_id AND seller_id = p_seller_id;

  IF v_debt_type IS NULL THEN
    RAISE EXCEPTION 'Borç kaydı bulunamadı.';
  END IF;

  INSERT INTO public.finance_debt_payments (
    seller_id, debt_id, amount, payment_date, account_id, description
  ) VALUES (
    p_seller_id, p_debt_id, p_amount, p_payment_date, p_account_id, p_description
  ) RETURNING id INTO v_payment_id;

  IF p_create_cash_movement AND p_account_id IS NOT NULL THEN
    INSERT INTO public.finance_cash_movements (
      seller_id, account_id, movement_type, amount, direction, reference_id, reference_type, description, movement_date
    ) VALUES (
      p_seller_id,
      p_account_id,
      CASE WHEN v_debt_type = 'supplier' THEN 'supplier_payment' ELSE 'expense' END,
      p_amount,
      'out',
      v_ref_id,
      'debt_payment',
      COALESCE(p_description, 'Borç ödemesi'),
      p_payment_date
    );
  END IF;

  RETURN jsonb_build_object('payment_id', v_payment_id, 'reference_id', v_ref_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.finance_pay_expense(
  p_seller_id uuid,
  p_expense_id uuid,
  p_account_id uuid DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_payment_date date DEFAULT CURRENT_DATE,
  p_create_cash_movement boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_amount numeric;
  v_ref_id uuid := gen_random_uuid();
BEGIN
  SELECT amount INTO v_amount
  FROM public.finance_expenses
  WHERE id = p_expense_id AND seller_id = p_seller_id;

  IF v_amount IS NULL THEN
    RAISE EXCEPTION 'Gider kaydı bulunamadı.';
  END IF;

  UPDATE public.finance_expenses
  SET is_paid = true,
      paid_at = now(),
      account_id = COALESCE(p_account_id, account_id)
  WHERE id = p_expense_id AND seller_id = p_seller_id;

  IF p_create_cash_movement AND p_account_id IS NOT NULL THEN
    INSERT INTO public.finance_cash_movements (
      seller_id, account_id, movement_type, amount, direction, reference_id, reference_type, description, movement_date
    ) VALUES (
      p_seller_id,
      p_account_id,
      'expense',
      v_amount,
      'out',
      v_ref_id,
      'expense_payment',
      COALESCE(p_description, 'Gider ödemesi'),
      p_payment_date
    );
  END IF;

  RETURN jsonb_build_object('reference_id', v_ref_id, 'amount', v_amount);
END;
$$;

GRANT EXECUTE ON FUNCTION public.finance_transfer_cash(uuid, uuid, uuid, numeric, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finance_record_debt_payment(uuid, uuid, numeric, uuid, text, date, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finance_pay_expense(uuid, uuid, uuid, text, date, boolean) TO authenticated;

NOTIFY pgrst, 'reload schema';