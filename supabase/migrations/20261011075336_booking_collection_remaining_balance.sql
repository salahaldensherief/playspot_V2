BEGIN;

-- Confirm cash through the canonical collector. Do not overwrite mixed-receipt history.
CREATE OR REPLACE FUNCTION public.complete_booking_payment(p_booking_id uuid, p_payment_method text DEFAULT 'cash'::text, p_final_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_amount numeric;
  v_paid numeric;
  v_collected jsonb;
  v_commission numeric;
  v_shift_id uuid;
  v_new_status public.booking_status;
  v_voucher_to_consume text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_payment_method IS NULL OR p_payment_method NOT IN (
    'cash','manual_transfer','card','vodafone_cash','fawry','instapay','app_wallet'
  ) THEN
    RAISE EXCEPTION 'Invalid payment method' USING ERRCODE = '22023';
  END IF;

  PERFORM private.require_active_booking_actor();
  IF p_payment_method='app_wallet' THEN
    RAISE EXCEPTION 'USE_VERIFIED_WALLET_PAYMENT' USING ERRCODE='22023';
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'billing_checkout') THEN
    RAISE EXCEPTION 'Not authorized for billing checkout in this lounge' USING ERRCODE = '42501';
  END IF;

  v_paid:=private.booking_collected_amount(p_booking_id,v_booking.lounge_id,v_booking.payment_status,v_booking.total_price);
  IF v_booking.payment_status = 'paid' AND v_paid=v_booking.total_price THEN
    IF v_booking.payment_method IS DISTINCT FROM p_payment_method
      OR (p_final_amount IS NOT NULL AND p_final_amount IS DISTINCT FROM v_booking.total_price) THEN
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
    OR v_booking.total_price::text IN ('NaN','Infinity','-Infinity')
    OR v_booking.total_price<>round(v_booking.total_price,2) THEN
    RAISE EXCEPTION 'Booking has an invalid server-calculated total' USING ERRCODE = '22023';
  END IF;

  IF p_final_amount IS NOT NULL AND p_final_amount IS DISTINCT FROM v_booking.total_price THEN
    RAISE EXCEPTION 'Payment amount must match the booking total; update an approved discount before collecting'
      USING ERRCODE = '22023';
  END IF;

  IF v_paid>v_booking.total_price THEN
    RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
  END IF;
  IF v_paid>0 AND p_payment_method<>'cash' THEN
    RAISE EXCEPTION 'ELECTRONIC_INSTALLMENT_REQUIRES_RECEIPT_LEDGER' USING ERRCODE='55000';
  END IF;
  IF p_payment_method='cash' AND v_paid>0 AND EXISTS(SELECT 1 FROM public.payments
    WHERE booking_id=p_booking_id AND payment_method<>'cash') THEN
    RAISE EXCEPTION 'MIXED_PAYMENT_REQUIRES_RECEIPT_LEDGER' USING ERRCODE='55000';
  END IF;
  v_amount := round(v_booking.total_price, 2);
  v_commission := round(v_amount * 0.15, 2);

  SELECT s.id
  INTO v_shift_id
  FROM public.shifts AS s
  WHERE s.lounge_id = v_booking.lounge_id
    AND s.status = 'open'
    AND s.closed_at IS NULL
    AND (p_payment_method<>'cash' OR (s.cashier_id=auth.uid()
      AND (s.staff_user_id IS NULL OR s.staff_user_id=auth.uid())))
  ORDER BY s.opened_at DESC
  LIMIT 1
  FOR SHARE;

  IF v_shift_id IS NULL THEN
    RAISE EXCEPTION 'An open shift is required to collect payment' USING ERRCODE = '55000';
  END IF;

  IF v_booking.status = 'completed'::public.booking_status THEN
    v_new_status := 'completed'::public.booking_status;
  ELSIF v_booking.status = 'in_progress'::public.booking_status THEN
    v_new_status := 'in_progress'::public.booking_status;
  ELSE
    v_new_status := 'upcoming'::public.booking_status;
  END IF;

  -- Consume attached voucher if exists
  v_voucher_to_consume := COALESCE(
    v_booking.applied_voucher_code,
    CASE
      WHEN v_booking.discount_reason ~* '^voucher:\s*([A-Za-z0-9_-]+)'
      THEN substring(v_booking.discount_reason from '(?i)^voucher:\s*([A-Za-z0-9_-]+)')
      ELSE NULL
    END
  );

  IF v_voucher_to_consume IS NOT NULL AND v_booking.user_id IS NOT NULL THEN
    UPDATE public.user_vouchers
    SET status = 'used',
        used_at = now(),
        used_booking_id = p_booking_id
    WHERE UPPER(TRIM(code)) = UPPER(TRIM(v_voucher_to_consume))
      AND user_id = v_booking.user_id
      AND status = 'active';
  END IF;

  IF p_payment_method='cash' THEN
    IF v_amount>v_paid THEN
      v_collected:=public.collect_booking_cash_partial(p_booking_id,v_shift_id,(v_amount-v_paid)*100,gen_random_uuid());
    END IF;
    UPDATE public.bookings SET status=v_new_status,payment_status='paid',payment_method='cash',
      shift_id=v_shift_id,updated_at=now() WHERE id=p_booking_id;
    RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'room_id',v_booking.room_id,
      'status',v_new_status::text,'amount_paid',v_amount,'amount_collected',v_amount-v_paid,
      'payment_method','cash','shift_id',v_shift_id,'collection',v_collected);
  END IF;

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

  INSERT INTO public.shift_payments (
    shift_id, lounge_id, booking_id, payment_method, category, amount, paid_at
  ) VALUES (
    v_shift_id, v_booking.lounge_id, p_booking_id, p_payment_method, 'gaming_time', v_amount, now()
  );

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
$function$;

REVOKE ALL ON FUNCTION public.complete_booking_payment(uuid,text,numeric) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.complete_booking_payment(uuid,text,numeric) TO authenticated;
COMMIT;
