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
  IF EXISTS(SELECT 1 FROM private.cash_collection_receipts WHERE booking_id=p_booking_id) THEN
    SELECT COALESCE(sum(amount),0) INTO v_cash FROM public.shift_payments
      WHERE booking_id=p_booking_id AND lounge_id=p_lounge_id AND payment_method='cash';
    IF v_payment.payment_method IS DISTINCT FROM 'cash' OR v_payment.amount IS DISTINCT FROM v_cash THEN
      RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
    END IF;
  END IF;
  RETURN v_payment.amount;
END; $$;
REVOKE ALL ON FUNCTION private.booking_collected_amount(uuid,uuid,text,numeric) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.complete_booking_session(p_booking_id uuid, p_action_by uuid DEFAULT NULL::uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_room public.rooms%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_now timestamptz := now();
  v_start_time timestamptz;
  v_elapsed_minutes integer;
  v_billable_raw integer;
  v_billable_minutes integer;
  v_rounding integer := 15;
  v_minimum integer := 30;
  v_max integer := 720;
  v_rate numeric := 50;
  v_room_price numeric;
  v_total_price numeric;
  v_amount_paid numeric := 0;
  v_amount_due numeric := 0;
  v_snap jsonb;
  v_payment_status text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  PERFORM private.require_active_booking_actor();

  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'sessions_control') THEN
    RAISE EXCEPTION 'Not authorized for session control in this lounge' USING ERRCODE = '42501';
  END IF;

  -- Idempotency: if already completed, return existing totals without recalculating
  IF v_booking.status = 'completed'::public.booking_status THEN
    v_amount_paid := private.booking_collected_amount(p_booking_id,v_booking.lounge_id,v_booking.payment_status,v_booking.total_price);
    v_amount_due := GREATEST(0, v_booking.total_price - v_amount_paid);
    v_payment_status := CASE WHEN v_amount_paid>=v_booking.total_price THEN 'paid' WHEN v_amount_paid>0 THEN 'partial' ELSE 'unpaid' END;
    UPDATE public.bookings SET payment_status=v_payment_status,updated_at=v_now
      WHERE id=p_booking_id AND payment_status IS DISTINCT FROM v_payment_status;

    RETURN json_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'lounge_id', v_booking.lounge_id,
      'status', 'completed',
      'final_total', v_booking.total_price,
      'amount_paid', v_amount_paid,
      'amount_due', v_amount_due,
      'payment_status', v_payment_status,
      'idempotent', true
    );
  END IF;

  IF v_booking.status <> 'in_progress'::public.booking_status THEN
    RAISE EXCEPTION 'Only in-progress sessions can be completed' USING ERRCODE = '55000';
  END IF;

  v_amount_paid := private.booking_collected_amount(p_booking_id,v_booking.lounge_id,v_booking.payment_status,v_booking.total_price);

  -- If this is an Open Time session, calculate billing from snapshot
  IF COALESCE(v_booking.is_open_time, false) IS TRUE THEN
    v_snap := v_booking.open_time_pricing_snapshot;

    IF v_snap IS NOT NULL AND v_snap <> '{}'::jsonb THEN
      v_rate := COALESCE((v_snap->>'effective_hourly_rate')::numeric, (v_snap->>'base_hourly_rate')::numeric, 50);
      v_minimum := COALESCE((v_snap->>'minimum_minutes')::integer, 30);
      v_rounding := COALESCE((v_snap->>'rounding_minutes')::integer, 15);
      v_max := COALESCE((v_snap->>'max_minutes')::integer, 720);
    ELSE
      -- Fallback to lounge & room current settings
      SELECT l.* INTO v_lounge FROM public.lounges l WHERE l.id = v_booking.lounge_id;
      SELECT r.* INTO v_room FROM public.rooms r WHERE r.id = v_booking.room_id;
      v_minimum := COALESCE(v_room.open_time_minimum_minutes, v_lounge.open_time_minimum_minutes, 30);
      v_rounding := COALESCE(v_room.open_time_rounding_minutes, v_lounge.open_time_rounding_minutes, 15);
      v_max := COALESCE(v_room.open_time_max_minutes, v_lounge.open_time_max_minutes, 720);
      v_rate := CASE
        WHEN v_booking.play_mode = 'multi' AND COALESCE(v_room.hourly_rate_multi, 0) > 0 THEN v_room.hourly_rate_multi
        ELSE COALESCE(v_room.hourly_rate_single, v_room.hourly_rate, 50)
      END;
    END IF;

    v_start_time := COALESCE(v_booking.open_time_started_at, v_booking.actual_start_time, v_booking.created_at);
    v_elapsed_minutes := GREATEST(1, ROUND(EXTRACT(EPOCH FROM (v_now - v_start_time)) / 60.0)::integer);

    -- Apply max cap as billing ceiling
    IF v_max IS NOT NULL AND v_max > 0 THEN
      v_billable_raw := LEAST(v_elapsed_minutes, v_max);
    ELSE
      v_billable_raw := v_elapsed_minutes;
    END IF;

    -- Apply minimum minutes
    v_billable_raw := GREATEST(v_billable_raw, v_minimum);

    -- Apply rounding
    v_billable_minutes := CEIL(v_billable_raw::numeric / v_rounding::numeric)::integer * v_rounding;

    v_room_price := ROUND((v_rate / 60.0) * v_billable_minutes, 2);
    v_total_price := v_room_price + COALESCE(v_booking.addons_total, 0) - COALESCE(v_booking.discount_amount, 0);

    v_payment_status := CASE WHEN v_amount_paid>=v_total_price THEN 'paid' WHEN v_amount_paid>0 THEN 'partial' ELSE 'unpaid' END;
    UPDATE public.bookings
    SET payment_status=v_payment_status, status = 'completed'::public.booking_status,
        open_time_closed_at = v_now,
        open_time_billing_minutes = v_billable_minutes,
        duration_minutes = v_billable_minutes,
        room_price = v_room_price,
        total_price = v_total_price,
        updated_at = v_now
    WHERE id = p_booking_id;
  ELSE
    -- Standard pre-booked session completion
    v_total_price := v_booking.total_price;
    v_payment_status := CASE WHEN v_amount_paid>=v_total_price THEN 'paid' WHEN v_amount_paid>0 THEN 'partial' ELSE 'unpaid' END;
    UPDATE public.bookings
    SET payment_status=v_payment_status, status = 'completed'::public.booking_status,
        updated_at = v_now
    WHERE id = p_booking_id;
  END IF;

  IF (SELECT total_price FROM public.bookings WHERE id=p_booking_id) IS DISTINCT FROM v_total_price THEN
    RAISE EXCEPTION 'BOOKING_PRICE_CHANGED_DURING_COMPLETION' USING ERRCODE='55000';
  END IF;

  -- Release room
  IF v_booking.room_id IS NOT NULL THEN
    UPDATE public.rooms AS r
    SET status = 'available',
        is_available = true,
        updated_at = v_now
    WHERE r.id = v_booking.room_id
      AND r.lounge_id = v_booking.lounge_id
      AND r.status = 'occupied';
  END IF;

  v_amount_due := GREATEST(0, v_total_price - v_amount_paid);

  RETURN json_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'lounge_id', v_booking.lounge_id,
    'status', 'completed',
    'final_total', v_total_price,
    'amount_paid', v_amount_paid,
    'amount_due', v_amount_due,
    'payment_status', v_payment_status
  );
END;
$function$;


REVOKE ALL ON FUNCTION public.complete_booking_session(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.complete_booking_session(uuid,uuid) TO authenticated;
COMMIT;
