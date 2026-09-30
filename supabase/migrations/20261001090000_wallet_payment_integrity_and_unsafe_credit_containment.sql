BEGIN;
CREATE SCHEMA IF NOT EXISTS private;
REVOKE CREATE ON SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.record_verified_booking_payment(
  p_booking_id uuid,
  p_payment_method text DEFAULT 'cash'::text,
  p_final_amount numeric DEFAULT NULL::numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_amount numeric;
  v_commission numeric;
  v_shift_id uuid;
  v_new_status public.booking_status;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_payment_method IS NULL OR p_payment_method NOT IN (
    'cash','manual_transfer','card','vodafone_cash','fawry','instapay','app_wallet'
  ) THEN
    RAISE EXCEPTION 'Invalid payment method' USING ERRCODE = '22023';
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  -- Verify billing_checkout permission rather than mere lounge membership
  IF NOT COALESCE(p_payment_method = 'app_wallet' AND v_booking.user_id = auth.uid(),false)
     AND public.is_super_admin() IS NOT TRUE
     AND public.has_lounge_permission(v_booking.lounge_id, 'billing_checkout') IS NOT TRUE THEN
    RAISE EXCEPTION 'Not authorized for billing checkout in this lounge' USING ERRCODE = '42501';
  END IF;

  -- Idempotency check: if already marked paid, return success without duplicate entries
  IF v_booking.payment_status = 'paid' THEN
    IF v_booking.payment_method IS DISTINCT FROM p_payment_method
       OR (p_final_amount IS NOT NULL AND round(p_final_amount,2) IS DISTINCT FROM round(v_booking.total_price,2)) THEN
      RAISE EXCEPTION 'PAYMENT_REPLAY_PAYLOAD_CONFLICT' USING ERRCODE='22023';
    END IF;
    RETURN jsonb_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'room_id', v_booking.room_id,
      'status', v_booking.status::text,
      'amount_paid', v_booking.total_price,
      'payment_method', v_booking.payment_method,
      'idempotent', true
    );
  END IF;

  IF v_booking.status::text IN ('cancelled', 'rejected') THEN
    RAISE EXCEPTION 'Cannot collect payment for a cancelled or rejected booking' USING ERRCODE = '55000';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.payments AS p
    WHERE p.booking_id = p_booking_id AND p.status = 'refunded'
  ) THEN
    RAISE EXCEPTION 'A refunded payment cannot be completed again through this RPC' USING ERRCODE = '55000';
  END IF;

  IF v_booking.total_price IS NULL OR v_booking.total_price < 0
     OR v_booking.total_price::text IN ('NaN','Infinity','-Infinity') THEN
    RAISE EXCEPTION 'Booking has an invalid server-calculated total' USING ERRCODE = '22023';
  END IF;

  IF p_final_amount IS NOT NULL AND round(p_final_amount, 2) <> round(v_booking.total_price, 2) THEN
    RAISE EXCEPTION 'Payment amount must match the booking total; update an approved discount before collecting'
      USING ERRCODE = '22023';
  END IF;

  v_amount := round(v_booking.total_price, 2);
  v_commission := round(v_amount * 0.15, 2);

  -- Mandatory active shift for the same lounge
  SELECT s.id
  INTO v_shift_id
  FROM public.shifts AS s
  WHERE s.lounge_id = v_booking.lounge_id
    AND s.status = 'open'
    AND s.closed_at IS NULL
  ORDER BY s.opened_at DESC
  LIMIT 1
  FOR SHARE;

  IF v_shift_id IS NULL THEN
    RAISE EXCEPTION 'An open shift is required to collect payment' USING ERRCODE = '55000';
  END IF;

  -- Status preservation: never downgrade a completed session
  IF v_booking.status = 'completed'::public.booking_status THEN
    v_new_status := 'completed'::public.booking_status;
  ELSIF v_booking.status = 'in_progress'::public.booking_status THEN
    v_new_status := 'in_progress'::public.booking_status;
  ELSE
    v_new_status := 'upcoming'::public.booking_status;
  END IF;

  -- Atomic payment recording
  INSERT INTO public.payments (
    booking_id, user_id, lounge_id, amount, commission, net_to_lounge,
    payment_method, status, paid_at, discount_amount, discount_percentage,
    discount_reason, discount_approved_by
  ) VALUES (
    p_booking_id, v_booking.user_id, v_booking.lounge_id, v_amount,
    v_commission, v_amount - v_commission, p_payment_method, 'completed', now(),
    COALESCE(v_booking.discount_amount, 0), COALESCE(v_booking.discount_percentage, 0),
    v_booking.discount_reason, v_booking.discount_approved_by
  )
  ON CONFLICT (booking_id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    lounge_id = EXCLUDED.lounge_id,
    amount = EXCLUDED.amount,
    commission = EXCLUDED.commission,
    net_to_lounge = EXCLUDED.net_to_lounge,
    payment_method = EXCLUDED.payment_method,
    status = 'completed',
    paid_at = EXCLUDED.paid_at,
    discount_amount = EXCLUDED.discount_amount,
    discount_percentage = EXCLUDED.discount_percentage,
    discount_reason = EXCLUDED.discount_reason,
    discount_approved_by = EXCLUDED.discount_approved_by;

  -- Record shift payment atomically
  INSERT INTO public.shift_payments (
    shift_id, lounge_id, booking_id, payment_method, category, amount, paid_at
  ) VALUES (
    v_shift_id, v_booking.lounge_id, p_booking_id, p_payment_method, 'gaming_time', v_amount, now()
  );

  -- Update booking atomically
  UPDATE public.bookings AS b
  SET status = v_new_status,
      payment_status = 'paid',
      payment_method = p_payment_method,
      total_price = v_amount,
      shift_id = v_shift_id,
      updated_at = now()
  WHERE b.id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'room_id', v_booking.room_id,
    'status', v_new_status::text,
    'amount_paid', v_amount,
    'payment_method', p_payment_method,
    'commission', v_commission,
    'net_to_lounge', v_amount - v_commission,
    'shift_id', v_shift_id
  );
END;
$$;

REVOKE ALL ON FUNCTION private.record_verified_booking_payment(uuid,text,numeric)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_or_create_user_wallet(p_user_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_target uuid := COALESCE(p_user_id, v_caller);
  v_wallet public.user_wallets%ROWTYPE;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000';
  END IF;
  IF v_target <> v_caller AND public.is_super_admin() IS NOT TRUE THEN
    RAISE EXCEPTION 'WALLET_ACCESS_DENIED' USING ERRCODE='42501';
  END IF;
  INSERT INTO public.user_wallets(user_id,balance,currency)
    VALUES(v_target,0,'EGP') ON CONFLICT(user_id) DO NOTHING;
  SELECT * INTO STRICT v_wallet FROM public.user_wallets WHERE user_id=v_target;
  RETURN jsonb_build_object('user_id',v_target,'balance',v_wallet.balance,
    'currency',v_wallet.currency,'is_frozen',v_wallet.is_frozen);
END;
$$;

CREATE OR REPLACE FUNCTION public.topup_user_wallet(
  p_amount numeric, p_payment_method text DEFAULT 'cash',
  p_lounge_id uuid DEFAULT NULL, p_idempotency_key text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
BEGIN
  RAISE EXCEPTION 'WALLET_TOPUP_REQUIRES_VERIFIED_SETTLEMENT' USING ERRCODE='55000';
END;
$$;

CREATE OR REPLACE FUNCTION public.pay_with_wallet(
  p_booking_id uuid,p_amount numeric,p_idempotency_key text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_wallet public.user_wallets%ROWTYPE;
  v_previous public.wallet_transactions%ROWTYPE;
  v_total numeric;
  v_transaction uuid;
  v_result jsonb;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 OR p_amount::text IN ('NaN','Infinity','-Infinity')
     OR p_amount <> round(p_amount,2) THEN
    RAISE EXCEPTION 'INVALID_PAYMENT_AMOUNT' USING ERRCODE='22023';
  END IF;
  IF p_idempotency_key IS NULL OR length(btrim(p_idempotency_key)) NOT BETWEEN 1 AND 128 THEN
    RAISE EXCEPTION 'IDEMPOTENCY_KEY_REQUIRED' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_idempotency_key,0));
  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  IF v_booking.user_id IS DISTINCT FROM v_caller THEN
    RAISE EXCEPTION 'WALLET_BOOKING_OWNER_REQUIRED' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_previous FROM public.wallet_transactions WHERE idempotency_key=p_idempotency_key;
  IF FOUND THEN
    IF v_previous.user_id IS DISTINCT FROM v_caller
       OR v_previous.booking_id IS DISTINCT FROM p_booking_id
       OR v_previous.transaction_type <> 'booking_payment'
       OR v_previous.amount IS DISTINCT FROM -p_amount THEN
      RAISE EXCEPTION 'IDEMPOTENCY_PAYLOAD_CONFLICT' USING ERRCODE='22023';
    END IF;
    RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,
      'transaction_id',v_previous.id,'remaining_balance',v_previous.balance_after,
      'amount_deducted',-v_previous.amount,'idempotent',true);
  END IF;
  IF v_booking.payment_status = 'paid' THEN
    RAISE EXCEPTION 'BOOKING_ALREADY_PAID_DIFFERENT_OPERATION' USING ERRCODE='55000';
  END IF;
  IF v_booking.status::text IN ('cancelled','rejected') OR v_booking.payment_status='refunded' THEN
    RAISE EXCEPTION 'BOOKING_NOT_PAYABLE' USING ERRCODE='55000';
  END IF;
  IF COALESCE(v_booking.is_open_time,false) AND v_booking.status::text <> 'completed' THEN
    RAISE EXCEPTION 'OPEN_TIME_MUST_BE_CLOSED_BEFORE_WALLET_PAYMENT' USING ERRCODE='55000';
  END IF;
  v_total := round(v_booking.total_price,2);
  IF v_total IS NULL OR v_total <= 0 OR p_amount <> v_total THEN
    RAISE EXCEPTION 'PAYMENT_AMOUNT_MUST_MATCH_SERVER_TOTAL' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_wallet FROM public.user_wallets WHERE user_id=v_caller FOR UPDATE;
  IF NOT FOUND OR v_wallet.balance < v_total THEN
    RAISE EXCEPTION 'INSUFFICIENT_WALLET_BALANCE' USING ERRCODE='55000';
  END IF;
  IF v_wallet.is_frozen THEN RAISE EXCEPTION 'WALLET_FROZEN' USING ERRCODE='55000'; END IF;
  v_result := private.record_verified_booking_payment(p_booking_id,'app_wallet',v_total);
  UPDATE public.user_wallets SET balance=balance-v_total,updated_at=now()
    WHERE user_id=v_caller RETURNING * INTO v_wallet;
  INSERT INTO public.wallet_transactions(user_id,booking_id,shift_id,amount,balance_after,
    transaction_type,idempotency_key,created_by)
    VALUES(v_caller,p_booking_id,(v_result->>'shift_id')::uuid,-v_total,v_wallet.balance,
      'booking_payment',p_idempotency_key,v_caller) RETURNING id INTO v_transaction;
  RETURN v_result || jsonb_build_object('transaction_id',v_transaction,
    'amount_deducted',v_total,'remaining_balance',v_wallet.balance,
    'final_total',v_total,'amount_due',0,'payment_status','paid');
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_booking_payment(
  p_booking_id uuid,p_payment_method text DEFAULT 'cash',p_final_amount numeric DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
BEGIN
  IF p_payment_method = 'app_wallet' THEN
    RAISE EXCEPTION 'USE_PAY_WITH_WALLET_WITH_IDEMPOTENCY_KEY' USING ERRCODE='22023';
  END IF;
  RETURN private.record_verified_booking_payment(p_booking_id,p_payment_method,p_final_amount);
END;
$$;

CREATE OR REPLACE FUNCTION public.collect_wallet_cash_topup(
  p_customer_id uuid,p_lounge_id uuid,p_amount numeric,p_idempotency_key text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_wallet public.user_wallets%ROWTYPE;
  v_previous public.wallet_transactions%ROWTYPE;
  v_shift_id uuid;
  v_transaction uuid;
BEGIN
  IF v_caller IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  IF p_customer_id IS NULL OR p_lounge_id IS NULL OR p_amount IS NULL OR p_amount <= 0
     OR p_amount::text IN ('NaN','Infinity','-Infinity') OR p_amount <> round(p_amount,2) THEN
    RAISE EXCEPTION 'INVALID_CASH_COLLECTION' USING ERRCODE='22023';
  END IF;
  IF p_idempotency_key IS NULL OR length(btrim(p_idempotency_key)) NOT BETWEEN 1 AND 128 THEN
    RAISE EXCEPTION 'IDEMPOTENCY_KEY_REQUIRED' USING ERRCODE='22023';
  END IF;
  IF public.has_lounge_permission(p_lounge_id,'billing_checkout') IS NOT TRUE THEN
    RAISE EXCEPTION 'BILLING_PERMISSION_REQUIRED' USING ERRCODE='42501';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_idempotency_key,0));
  SELECT * INTO v_previous FROM public.wallet_transactions WHERE idempotency_key=p_idempotency_key;
  IF FOUND THEN
    IF v_previous.user_id IS DISTINCT FROM p_customer_id OR v_previous.created_by IS DISTINCT FROM v_caller
       OR v_previous.transaction_type <> 'topup' OR v_previous.amount IS DISTINCT FROM p_amount
       OR v_previous.notes IS DISTINCT FROM 'confirmed_cash_collection'
       OR NOT EXISTS(SELECT 1 FROM public.shifts WHERE id=v_previous.shift_id AND lounge_id=p_lounge_id) THEN
      RAISE EXCEPTION 'IDEMPOTENCY_PAYLOAD_CONFLICT' USING ERRCODE='22023';
    END IF;
    RETURN jsonb_build_object('success',true,'transaction_id',v_previous.id,
      'customer_id',p_customer_id,'balance',v_previous.balance_after,'idempotent',true);
  END IF;
  INSERT INTO public.user_wallets(user_id,balance,currency)
    VALUES(p_customer_id,0,'EGP') ON CONFLICT(user_id) DO NOTHING;
  SELECT * INTO STRICT v_wallet FROM public.user_wallets WHERE user_id=p_customer_id FOR UPDATE;
  IF v_wallet.is_frozen THEN RAISE EXCEPTION 'WALLET_FROZEN' USING ERRCODE='55000'; END IF;
  SELECT id INTO v_shift_id FROM public.shifts WHERE lounge_id=p_lounge_id
    AND status='open' AND closed_at IS NULL ORDER BY opened_at DESC LIMIT 1 FOR SHARE;
  IF v_shift_id IS NULL THEN RAISE EXCEPTION 'OPEN_SHIFT_REQUIRED' USING ERRCODE='55000'; END IF;
  UPDATE public.user_wallets SET balance=balance+p_amount,updated_at=now()
    WHERE user_id=p_customer_id RETURNING * INTO v_wallet;
  INSERT INTO public.shift_payments(shift_id,lounge_id,payment_method,category,amount,paid_at)
    VALUES(v_shift_id,p_lounge_id,'cash','other',p_amount,now());
  INSERT INTO public.wallet_transactions(user_id,shift_id,amount,balance_after,
    transaction_type,idempotency_key,notes,created_by)
    VALUES(p_customer_id,v_shift_id,p_amount,v_wallet.balance,'topup',p_idempotency_key,
      'confirmed_cash_collection',v_caller) RETURNING id INTO v_transaction;
  RETURN jsonb_build_object('success',true,'transaction_id',v_transaction,
    'customer_id',p_customer_id,'amount_collected',p_amount,'balance',v_wallet.balance,'shift_id',v_shift_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.refund_to_wallet(
  p_booking_id uuid,p_amount numeric,p_reason text DEFAULT 'cancellation')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_previous public.wallet_transactions%ROWTYPE;
  v_payment public.payments%ROWTYPE;
  v_wallet public.user_wallets%ROWTYPE;
  v_paid numeric;
  v_shift_id uuid;
  v_transaction uuid;
  v_key text := 'wallet-refund:' || p_booking_id::text;
BEGIN
  IF v_caller IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  IF p_amount IS NULL OR p_amount <= 0 OR p_amount::text IN ('NaN','Infinity','-Infinity')
     OR p_amount <> round(p_amount,2) OR p_reason IS NULL OR btrim(p_reason)='' THEN
    RAISE EXCEPTION 'INVALID_REFUND' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_key,0));
  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  IF public.has_lounge_permission(v_booking.lounge_id,'billing_checkout') IS NOT TRUE THEN
    RAISE EXCEPTION 'BILLING_PERMISSION_REQUIRED' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_previous FROM public.wallet_transactions WHERE idempotency_key=v_key;
  IF FOUND THEN
    IF v_previous.user_id IS DISTINCT FROM v_booking.user_id
       OR v_previous.booking_id IS DISTINCT FROM p_booking_id OR v_previous.transaction_type <> 'refund'
       OR v_previous.amount IS DISTINCT FROM p_amount OR v_previous.notes IS DISTINCT FROM p_reason
       OR v_previous.created_by IS DISTINCT FROM v_caller THEN
      RAISE EXCEPTION 'IDEMPOTENCY_PAYLOAD_CONFLICT' USING ERRCODE='22023';
    END IF;
    RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,
      'transaction_id',v_previous.id,'refunded_amount',v_previous.amount,'idempotent',true);
  END IF;
  SELECT * INTO v_payment FROM public.payments WHERE booking_id=p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_payment.status <> 'completed' OR v_payment.payment_method <> 'app_wallet'
     OR v_booking.payment_status <> 'paid' THEN
    RAISE EXCEPTION 'VERIFIED_WALLET_PAYMENT_REQUIRED' USING ERRCODE='55000';
  END IF;
  IF EXISTS(SELECT 1 FROM public.wallet_transactions WHERE booking_id=p_booking_id AND transaction_type='refund') THEN
    RAISE EXCEPTION 'EXISTING_REFUND_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
  END IF;
  SELECT -sum(amount) INTO v_paid FROM public.wallet_transactions
    WHERE booking_id=p_booking_id AND user_id=v_booking.user_id AND transaction_type='booking_payment';
  IF v_paid IS NULL OR v_paid <= 0 OR p_amount <> v_paid OR p_amount <> v_payment.amount THEN
    RAISE EXCEPTION 'FULL_VERIFIED_WALLET_REFUND_REQUIRED' USING ERRCODE='22023';
  END IF;
  SELECT * INTO STRICT v_wallet FROM public.user_wallets WHERE user_id=v_booking.user_id FOR UPDATE;
  SELECT id INTO v_shift_id FROM public.shifts WHERE lounge_id=v_booking.lounge_id
    AND status='open' AND closed_at IS NULL ORDER BY opened_at DESC LIMIT 1 FOR SHARE;
  IF v_shift_id IS NULL THEN RAISE EXCEPTION 'OPEN_SHIFT_REQUIRED' USING ERRCODE='55000'; END IF;
  UPDATE public.user_wallets SET balance=balance+p_amount,updated_at=now()
    WHERE user_id=v_booking.user_id RETURNING * INTO v_wallet;
  UPDATE public.payments SET status='refunded' WHERE booking_id=p_booking_id;
  UPDATE public.bookings SET payment_status='refunded',updated_at=now() WHERE id=p_booking_id;
  INSERT INTO public.wallet_transactions(user_id,booking_id,shift_id,amount,balance_after,
    transaction_type,idempotency_key,notes,created_by)
    VALUES(v_booking.user_id,p_booking_id,v_shift_id,p_amount,v_wallet.balance,'refund',v_key,p_reason,v_caller)
    RETURNING id INTO v_transaction;
  RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,
    'transaction_id',v_transaction,'refunded_amount',p_amount,'balance_after',v_wallet.balance,
    'payment_status','refunded','status',v_booking.status::text);
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_create_user_wallet(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.pay_with_wallet(uuid,numeric,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.complete_booking_payment(uuid,text,numeric) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.topup_user_wallet(numeric,text,uuid,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.refund_to_wallet(uuid,numeric,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.collect_wallet_cash_topup(uuid,uuid,numeric,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.collect_wallet_cash_topup(uuid,uuid,numeric,text),public.refund_to_wallet(uuid,numeric,text) TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_or_create_user_wallet(uuid),
  public.pay_with_wallet(uuid,numeric,text),public.complete_booking_payment(uuid,text,numeric)
  TO authenticated,service_role;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE ON public.user_wallets,public.wallet_transactions
  FROM anon,authenticated;
COMMIT;
