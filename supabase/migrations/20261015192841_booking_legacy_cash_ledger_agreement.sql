-- Require ledger agreement for legacy cash as well as receipted collections.
-- No accounting records are changed by this migration.
BEGIN;

CREATE OR REPLACE FUNCTION private.booking_collected_amount(p_booking_id uuid,p_lounge_id uuid,p_legacy_status text,p_total numeric)
RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_payment public.payments%ROWTYPE;v_cash numeric;
BEGIN
  SELECT * INTO v_payment FROM public.payments WHERE booking_id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    IF (p_legacy_status IS DISTINCT FROM 'unpaid' AND p_total<>0)
      OR EXISTS(SELECT 1 FROM public.shift_payments WHERE booking_id=p_booking_id AND amount<>0) THEN
      RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
    END IF;
    RETURN 0;
  END IF;
  IF v_payment.lounge_id IS DISTINCT FROM p_lounge_id OR v_payment.status IS DISTINCT FROM 'completed'
    OR v_payment.amount IS NULL OR v_payment.amount<0 OR v_payment.amount<>round(v_payment.amount,2)
    OR v_payment.amount::text IN ('NaN','Infinity','-Infinity') THEN
    RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
  END IF;
  -- Legacy cash aggregates also need matching ledger evidence; lack of a new receipt is not proof.
  IF v_payment.payment_method = 'cash'
    OR EXISTS(SELECT 1 FROM private.cash_collection_receipts WHERE booking_id=p_booking_id) THEN
    SELECT COALESCE(sum(amount),0) INTO v_cash FROM public.shift_payments
      WHERE booking_id=p_booking_id AND lounge_id=p_lounge_id AND payment_method='cash';
    IF v_payment.payment_method IS DISTINCT FROM 'cash' OR v_payment.amount IS DISTINCT FROM v_cash THEN
      RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
    END IF;
  END IF;
  RETURN v_payment.amount;
END; $$;
REVOKE ALL ON FUNCTION private.booking_collected_amount(uuid,uuid,text,numeric) FROM PUBLIC,anon,authenticated;

COMMIT;
