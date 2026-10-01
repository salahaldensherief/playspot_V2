BEGIN;
CREATE TABLE IF NOT EXISTS private.cash_collection_receipts (
  operation_id uuid PRIMARY KEY,
  actor_id uuid NOT NULL,
  booking_id uuid NOT NULL REFERENCES public.bookings(id),
  shift_id uuid NOT NULL REFERENCES public.shifts(id),
  amount_minor numeric NOT NULL CHECK (amount_minor>0 AND amount_minor=trunc(amount_minor)),
  result jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS cash_collection_receipts_booking ON private.cash_collection_receipts(booking_id);
ALTER TABLE private.cash_collection_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.cash_collection_receipts FROM PUBLIC,anon,authenticated;

CREATE TABLE IF NOT EXISTS private.cash_collection_context (
  transaction_id bigint NOT NULL,
  booking_id uuid NOT NULL,
  PRIMARY KEY(transaction_id,booking_id)
);
ALTER TABLE private.cash_collection_context ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.cash_collection_context FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.guard_partial_cash_payment()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM private.cash_collection_receipts WHERE booking_id=NEW.booking_id)
    AND NOT EXISTS (SELECT 1 FROM private.cash_collection_context
      WHERE transaction_id=txid_current() AND booking_id=NEW.booking_id) THEN
    RAISE EXCEPTION 'CASH_LEDGER_REQUIRES_CANONICAL_COLLECTION' USING ERRCODE='55000';
  END IF;
  RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION private.guard_partial_cash_payment() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS guard_partial_cash_payment ON public.payments;
CREATE TRIGGER guard_partial_cash_payment BEFORE INSERT OR UPDATE ON public.payments
FOR EACH ROW EXECUTE FUNCTION private.guard_partial_cash_payment();

CREATE OR REPLACE FUNCTION private.assert_cash_collector(p_actor uuid,p_lounge uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM 1 FROM public.profiles p JOIN auth.users u ON u.id=p.id
    WHERE p.id=p_actor AND p.is_active IS TRUE AND p.is_banned IS FALSE FOR SHARE OF p,u;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_NOT_ELIGIBLE' USING ERRCODE='42501'; END IF;
  IF public.is_super_admin() IS NOT TRUE
      AND public.has_lounge_permission(p_lounge,'billing_checkout') IS NOT TRUE THEN
    RAISE EXCEPTION 'CASH_COLLECTION_PERMISSION_DENIED' USING ERRCODE='42501';
  END IF;
  PERFORM 1 FROM public.lounges WHERE id=p_lounge AND is_active IS TRUE AND status='active' FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'LOUNGE_NOT_APPROVED' USING ERRCODE='42501'; END IF;
END; $$;
REVOKE ALL ON FUNCTION private.assert_cash_collector(uuid,uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.lock_cash_collection_booking(p_booking_id uuid)
RETURNS public.bookings LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_booking public.bookings%ROWTYPE;v_lounge_id uuid;
BEGIN
  SELECT lounge_id INTO v_lounge_id FROM public.bookings WHERE id=p_booking_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  PERFORM private.assert_cash_collector(auth.uid(),v_lounge_id);
  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.lounge_id IS DISTINCT FROM v_lounge_id THEN
    RAISE EXCEPTION 'BOOKING_SCOPE_CHANGED' USING ERRCODE='55000';
  END IF;
  IF v_booking.status::text IN ('cancelled','rejected')
    OR (v_booking.is_open_time IS TRUE AND v_booking.status::text<>'completed') THEN
    RAISE EXCEPTION 'BOOKING_NOT_READY_FOR_COLLECTION' USING ERRCODE='55000';
  END IF;
  IF v_booking.total_price IS NULL OR v_booking.total_price<0
    OR v_booking.total_price::text IN ('NaN','Infinity','-Infinity')
    OR v_booking.total_price<>round(v_booking.total_price,2) THEN
    RAISE EXCEPTION 'INVALID_BOOKING_TOTAL' USING ERRCODE='22023';
  END IF;
  RETURN v_booking;
END; $$;
REVOKE ALL ON FUNCTION private.lock_cash_collection_booking(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.lock_cash_collection_shift(p_shift_id uuid,p_lounge_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_shift public.shifts%ROWTYPE;
BEGIN
  SELECT * INTO v_shift FROM public.shifts WHERE id=p_shift_id FOR SHARE;
  IF NOT FOUND OR v_shift.lounge_id IS DISTINCT FROM p_lounge_id
    OR v_shift.status IS DISTINCT FROM 'open' OR v_shift.closed_at IS NOT NULL
    OR v_shift.cashier_id IS DISTINCT FROM auth.uid()
    OR (v_shift.staff_user_id IS NOT NULL AND v_shift.staff_user_id IS DISTINCT FROM auth.uid()) THEN
    RAISE EXCEPTION 'OWN_OPEN_SHIFT_REQUIRED' USING ERRCODE='55000';
  END IF;
END; $$;
REVOKE ALL ON FUNCTION private.lock_cash_collection_shift(uuid,uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.cash_collection_paid_amount(p_booking_id uuid,p_lounge_id uuid,p_payment_status text)
RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_payment public.payments%ROWTYPE;v_cash numeric;
BEGIN
  SELECT COALESCE(sum(amount),0) INTO v_cash FROM public.shift_payments
    WHERE booking_id=p_booking_id AND lounge_id=p_lounge_id AND payment_method='cash';
  SELECT * INTO v_payment FROM public.payments WHERE booking_id=p_booking_id FOR UPDATE;
  IF FOUND THEN
    IF v_payment.payment_method IS DISTINCT FROM 'cash' OR v_payment.status IS DISTINCT FROM 'completed'
      OR v_payment.lounge_id IS DISTINCT FROM p_lounge_id OR v_payment.payout_id IS NOT NULL
      OR v_payment.amount IS NULL OR v_payment.amount<0
      OR v_payment.amount::text IN ('NaN','Infinity','-Infinity')
      OR v_payment.amount<>round(v_payment.amount,2) OR v_payment.amount IS DISTINCT FROM v_cash THEN
      RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
    END IF;
    RETURN v_payment.amount;
  ELSIF p_payment_status IS DISTINCT FROM 'unpaid' OR v_cash<>0 THEN
    RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
  END IF;
  RETURN 0;
END; $$;
REVOKE ALL ON FUNCTION private.cash_collection_paid_amount(uuid,uuid,text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.apply_partial_cash_collection(
  p_booking_id uuid,p_shift_id uuid,p_amount_minor numeric
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_amount numeric := p_amount_minor/100;
  v_paid numeric;
  v_rate numeric := private.platform_commission_rate();
  v_shift_payment uuid;
BEGIN
  v_booking:=private.lock_cash_collection_booking(p_booking_id);
  PERFORM private.lock_cash_collection_shift(p_shift_id,v_booking.lounge_id);
  v_paid:=private.cash_collection_paid_amount(p_booking_id,v_booking.lounge_id,v_booking.payment_status);
  IF v_amount>v_booking.total_price-v_paid THEN
    RAISE EXCEPTION 'CASH_EXCEEDS_OUTSTANDING_BALANCE' USING ERRCODE='22023';
  END IF;
  IF v_rate IS NULL OR v_rate<0 OR v_rate>1 OR v_rate::text IN ('NaN','Infinity','-Infinity') THEN
    RAISE EXCEPTION 'INVALID_COMMISSION_POLICY' USING ERRCODE='55000';
  END IF;
  INSERT INTO private.cash_collection_context VALUES(txid_current(),p_booking_id) ON CONFLICT DO NOTHING;
  INSERT INTO public.payments(booking_id,user_id,lounge_id,amount,commission_rate,commission,
    net_to_lounge,payment_method,status,paid_at)
  VALUES(p_booking_id,v_booking.user_id,v_booking.lounge_id,v_paid+v_amount,v_rate,
    round((v_paid+v_amount)*v_rate,2),(v_paid+v_amount)-round((v_paid+v_amount)*v_rate,2),'cash','completed',now())
  ON CONFLICT(booking_id) DO UPDATE SET amount=EXCLUDED.amount,commission_rate=EXCLUDED.commission_rate,
    commission=EXCLUDED.commission,net_to_lounge=EXCLUDED.net_to_lounge,paid_at=EXCLUDED.paid_at;
  INSERT INTO public.shift_payments(shift_id,lounge_id,booking_id,payment_method,category,amount,paid_at)
  VALUES(p_shift_id,v_booking.lounge_id,p_booking_id,'cash','gaming_time',v_amount,now()) RETURNING id INTO v_shift_payment;
  UPDATE public.bookings SET payment_status=CASE WHEN v_paid+v_amount=total_price THEN 'paid' ELSE 'partial' END,
    payment_method='cash',updated_at=now() WHERE id=p_booking_id;
  DELETE FROM private.cash_collection_context WHERE transaction_id=txid_current() AND booking_id=p_booking_id;
  RETURN jsonb_build_object('booking_id',p_booking_id,'lounge_id',v_booking.lounge_id,
    'shift_id',p_shift_id,'shift_payment_id',v_shift_payment,'collected_minor',p_amount_minor,
    'paid_minor',(v_paid+v_amount)*100,'due_minor',(v_booking.total_price-v_paid-v_amount)*100,
    'payment_status',CASE WHEN v_paid+v_amount=v_booking.total_price THEN 'paid' ELSE 'partial' END);
END; $$;
REVOKE ALL ON FUNCTION private.apply_partial_cash_collection(uuid,uuid,numeric) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.collect_booking_cash_partial(
  p_booking_id uuid,p_shift_id uuid,p_amount_minor numeric,p_operation_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_receipt private.cash_collection_receipts%ROWTYPE; v_result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  IF p_operation_id IS NULL OR p_booking_id IS NULL OR p_shift_id IS NULL OR p_amount_minor IS NULL
    OR p_amount_minor::text IN ('NaN','Infinity','-Infinity') OR p_amount_minor<=0
    OR p_amount_minor<>trunc(p_amount_minor) OR p_amount_minor>9007199254740991 THEN
    RAISE EXCEPTION 'INVALID_CASH_COLLECTION_REQUEST' USING ERRCODE='22023';
  END IF;
  INSERT INTO private.cash_collection_receipts(operation_id,actor_id,booking_id,shift_id,amount_minor)
    VALUES(p_operation_id,auth.uid(),p_booking_id,p_shift_id,p_amount_minor) ON CONFLICT DO NOTHING;
  SELECT * INTO STRICT v_receipt FROM private.cash_collection_receipts WHERE operation_id=p_operation_id FOR UPDATE;
  IF v_receipt.actor_id IS DISTINCT FROM auth.uid() OR v_receipt.booking_id IS DISTINCT FROM p_booking_id
    OR v_receipt.shift_id IS DISTINCT FROM p_shift_id OR v_receipt.amount_minor IS DISTINCT FROM p_amount_minor THEN
    RAISE EXCEPTION 'CASH_COLLECTION_REPLAY_CONFLICT' USING ERRCODE='22023';
  END IF;
  IF v_receipt.result IS NOT NULL THEN
    PERFORM private.assert_cash_collector(auth.uid(),(v_receipt.result->>'lounge_id')::uuid);
    RETURN v_receipt.result||jsonb_build_object('replayed',true);
  END IF;
  v_result:=private.apply_partial_cash_collection(p_booking_id,p_shift_id,p_amount_minor)
    ||jsonb_build_object('operation_id',p_operation_id,'replayed',false);
  UPDATE private.cash_collection_receipts SET result=v_result WHERE operation_id=p_operation_id;
  RETURN v_result;
END; $$;
REVOKE ALL ON FUNCTION public.collect_booking_cash_partial(uuid,uuid,numeric,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.collect_booking_cash_partial(uuid,uuid,numeric,uuid) TO authenticated;
COMMIT;
