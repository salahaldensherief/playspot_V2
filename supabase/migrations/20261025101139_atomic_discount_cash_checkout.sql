-- Exact deployed contract guard. Do not apply if the canonical collector drifted.
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.collect_booking_cash_partial(uuid,uuid,numeric,uuid)'::regprocedure))
      <> 'b2b0d07ad98247c015ef67d43b0665aa' THEN
    RAISE EXCEPTION 'CASH_COLLECTOR_CONTRACT_DRIFT';
  END IF;
END;
$guard$;

-- A request fingerprint prevents an operation ID being replayed with a different
-- discount. Existing plain collection receipts retain NULL here.
ALTER TABLE private.cash_collection_receipts
  ADD COLUMN checkout_request jsonb;

-- The receipt insert holds an FK key-share on the booking. Two distinct requests
-- can otherwise deadlock when both later upgrade that lock to FOR UPDATE.
CREATE OR REPLACE FUNCTION public.collect_booking_cash_partial(
  p_booking_id uuid,p_shift_id uuid,p_amount_minor numeric,p_operation_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_receipt private.cash_collection_receipts%ROWTYPE; v_result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  IF p_operation_id IS NULL OR p_booking_id IS NULL OR p_shift_id IS NULL OR p_amount_minor IS NULL
    OR p_amount_minor::text IN ('NaN','Infinity','-Infinity') OR p_amount_minor<=0
    OR p_amount_minor<>trunc(p_amount_minor) OR p_amount_minor>9007199254740991 THEN
    RAISE EXCEPTION 'INVALID_CASH_COLLECTION_REQUEST' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_booking_id::text,0));
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
END; $function$;

-- One RPC / one database transaction for discount approval and cash collection.
-- All mutations, including the receipt and payment metadata, roll back together.
CREATE FUNCTION public.checkout_booking_cash_atomic(
  p_booking_id uuid,
  p_shift_id uuid,
  p_amount_minor numeric,
  p_operation_id uuid,
  p_discount_amount numeric DEFAULT 0,
  p_discount_percentage numeric DEFAULT 0,
  p_discount_reason text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_request jsonb;
  v_receipt private.cash_collection_receipts%ROWTYPE;
  v_booking public.bookings%ROWTYPE;
  v_result jsonb;
  v_amount_minor numeric;
  v_paid numeric;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  IF p_operation_id IS NULL OR p_booking_id IS NULL OR p_shift_id IS NULL
    OR (p_amount_minor IS NOT NULL AND (p_amount_minor::text IN ('NaN','Infinity','-Infinity')
      OR p_amount_minor<=0 OR p_amount_minor<>trunc(p_amount_minor)
      OR p_amount_minor>9007199254740991))
    OR p_discount_amount IS NULL OR p_discount_percentage IS NULL
    OR p_discount_amount::text IN ('NaN','Infinity','-Infinity')
    OR p_discount_percentage::text IN ('NaN','Infinity','-Infinity')
    OR p_discount_amount<0 OR p_discount_percentage<0 THEN
    RAISE EXCEPTION 'INVALID_ATOMIC_CHECKOUT_REQUEST' USING ERRCODE='22023';
  END IF;
  v_request:=jsonb_build_object('requested_amount_minor',p_amount_minor,'discount_amount',p_discount_amount,
    'discount_percentage',p_discount_percentage,'discount_reason',p_discount_reason);
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_booking_id::text,0));
  SELECT * INTO v_receipt FROM private.cash_collection_receipts
    WHERE operation_id=p_operation_id FOR UPDATE;
  IF FOUND THEN
    IF v_receipt.actor_id IS DISTINCT FROM auth.uid()
      OR v_receipt.booking_id IS DISTINCT FROM p_booking_id
      OR v_receipt.shift_id IS DISTINCT FROM p_shift_id
      OR (p_amount_minor IS NOT NULL AND v_receipt.amount_minor IS DISTINCT FROM p_amount_minor)
      OR v_receipt.checkout_request IS DISTINCT FROM v_request THEN
      RAISE EXCEPTION 'ATOMIC_CHECKOUT_REPLAY_CONFLICT' USING ERRCODE='22023';
    END IF;
    IF v_receipt.result IS NULL THEN
      RAISE EXCEPTION 'ATOMIC_CHECKOUT_UNRESOLVED_RECEIPT' USING ERRCODE='55000';
    END IF;
    PERFORM private.assert_cash_collector(auth.uid(),(v_receipt.result->>'lounge_id')::uuid);
    RETURN v_receipt.result||jsonb_build_object('replayed',true);
  END IF;

  v_booking:=private.lock_cash_collection_booking(p_booking_id);
  PERFORM private.lock_cash_collection_shift(p_shift_id,v_booking.lounge_id);
  IF p_discount_amount>0 OR p_discount_percentage>0 THEN
    IF COALESCE(v_booking.discount_amount,0)>0 OR COALESCE(v_booking.discount_percentage,0)>0 THEN
      RAISE EXCEPTION 'DISCOUNT_ALREADY_APPLIED' USING ERRCODE='55000';
    END IF;
    PERFORM public.apply_booking_discount(p_booking_id,p_discount_amount,
      p_discount_percentage,p_discount_reason,NULL);
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id;
  v_amount_minor:=p_amount_minor;
  IF v_amount_minor IS NULL THEN
    v_paid:=private.cash_collection_paid_amount(p_booking_id,v_booking.lounge_id,v_booking.payment_status);
    v_amount_minor:=(v_booking.total_price-v_paid)*100;
    IF v_amount_minor<=0 OR v_amount_minor<>trunc(v_amount_minor) THEN
      RAISE EXCEPTION 'NO_COLLECTIBLE_BALANCE' USING ERRCODE='22023';
    END IF;
  END IF;
  INSERT INTO private.cash_collection_receipts(
    operation_id,actor_id,booking_id,shift_id,amount_minor,checkout_request)
  VALUES(p_operation_id,auth.uid(),p_booking_id,p_shift_id,v_amount_minor,v_request);
  v_result:=public.collect_booking_cash_partial(p_booking_id,p_shift_id,v_amount_minor,p_operation_id);
  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id;
  INSERT INTO private.cash_collection_context(transaction_id,booking_id)
    VALUES(txid_current(),p_booking_id) ON CONFLICT DO NOTHING;
  UPDATE public.payments SET discount_amount=v_booking.discount_amount,
    discount_percentage=v_booking.discount_percentage,
    discount_reason=v_booking.discount_reason,
    discount_approved_by=v_booking.discount_approved_by
  WHERE booking_id=p_booking_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'CHECKOUT_PAYMENT_MISSING' USING ERRCODE='55000'; END IF;
  DELETE FROM private.cash_collection_context
    WHERE transaction_id=txid_current() AND booking_id=p_booking_id;
  v_result:=v_result||jsonb_build_object('discount_amount',v_booking.discount_amount,
    'discount_percentage',v_booking.discount_percentage,'total_minor',v_booking.total_price*100);
  UPDATE private.cash_collection_receipts SET result=v_result WHERE operation_id=p_operation_id;
  RETURN v_result;
END; $function$;

REVOKE ALL ON FUNCTION public.checkout_booking_cash_atomic(uuid,uuid,numeric,uuid,numeric,numeric,text)
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.checkout_booking_cash_atomic(uuid,uuid,numeric,uuid,numeric,numeric,text)
  TO authenticated;
