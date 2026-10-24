-- Preserve the deployed session contract and repair only partial-payment classification.
-- Refuse to replace a function that drifted after the verified schema-only export.
BEGIN;
DO $contract$
BEGIN
  IF md5(pg_get_functiondef('public.complete_booking_session(uuid,uuid)'::regprocedure))
     NOT IN ('b981afd7650dcc530867b69bdd80f0e9',
             '0f389ab56f751d5e4453a7472402113d') THEN
    RAISE EXCEPTION 'COMPLETE_BOOKING_SESSION_CONTRACT_DRIFT' USING ERRCODE='55000';
  END IF;
END;
$contract$;
CREATE OR REPLACE FUNCTION "public"."complete_booking_session"("p_booking_id" "uuid", "p_action_by" "uuid" DEFAULT NULL::"uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
  v_new_payment_status text := 'unpaid';
  v_snap jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
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
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'sessions_control') THEN
    RAISE EXCEPTION 'Not authorized for session control in this lounge' USING ERRCODE = '42501';
  END IF;

  -- Compute actual cash/online collected payments already recorded
  SELECT COALESCE(SUM(p.amount), 0)
  INTO v_amount_paid
  FROM public.payments AS p
  WHERE p.booking_id = p_booking_id
    AND p.status = 'completed';

  -- Idempotency: if already completed, return existing numbers
  IF v_booking.status = 'completed'::public.booking_status THEN
    v_amount_due := GREATEST(0, COALESCE(v_booking.total_price, 0) - v_amount_paid);
    v_new_payment_status := CASE WHEN v_amount_due = 0 THEN 'paid' WHEN v_amount_paid > 0 THEN 'partial' ELSE 'unpaid' END;
    IF v_booking.payment_status IS DISTINCT FROM v_new_payment_status THEN
      UPDATE public.bookings SET payment_status = v_new_payment_status, updated_at = v_now WHERE id = p_booking_id;
    END IF;

    RETURN json_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'lounge_id', v_booking.lounge_id,
      'status', 'completed',
      'final_total', v_booking.total_price,
      'amount_paid', v_amount_paid,
      'amount_due', v_amount_due,
      'payment_status', v_new_payment_status,
      'idempotent', true
    );
  END IF;

  IF v_booking.status <> 'in_progress'::public.booking_status THEN
    RAISE EXCEPTION 'Only in-progress sessions can be completed' USING ERRCODE = '55000';
  END IF;

  -- If this is an Open Time session, calculate billing
  IF COALESCE(v_booking.is_open_time, false) IS TRUE THEN
    v_snap := v_booking.open_time_pricing_snapshot;

    IF v_snap IS NOT NULL AND v_snap <> '{}'::jsonb THEN
      v_rate := COALESCE((v_snap->>'effective_hourly_rate')::numeric, (v_snap->>'base_hourly_rate')::numeric, 50);
      v_minimum := COALESCE((v_snap->>'minimum_minutes')::integer, 30);
      v_rounding := COALESCE((v_snap->>'rounding_minutes')::integer, 15);
      v_max := COALESCE((v_snap->>'max_minutes')::integer, 720);
    ELSE
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

    IF v_max IS NOT NULL AND v_max > 0 THEN
      v_billable_raw := LEAST(v_elapsed_minutes, v_max);
    ELSE
      v_billable_raw := v_elapsed_minutes;
    END IF;

    v_billable_raw := GREATEST(v_billable_raw, v_minimum);
    v_billable_minutes := CEIL(v_billable_raw::numeric / v_rounding::numeric)::integer * v_rounding;

    v_room_price := ROUND((v_rate / 60.0) * v_billable_minutes, 2);
    v_total_price := v_room_price + COALESCE(v_booking.addons_total, v_booking.addons_price, 0) - COALESCE(v_booking.discount_amount, 0);
    v_amount_due := GREATEST(0, v_total_price - v_amount_paid);

    v_new_payment_status := CASE WHEN v_amount_due = 0 THEN 'paid' WHEN v_amount_paid > 0 THEN 'partial' ELSE 'unpaid' END;

    UPDATE public.bookings
    SET status = 'completed'::public.booking_status,
        payment_status = v_new_payment_status,
        open_time_closed_at = v_now,
        open_time_billing_minutes = v_billable_minutes,
        duration_minutes = v_billable_minutes,
        room_price = v_room_price,
        total_price = v_total_price,
        updated_at = v_now
    WHERE id = p_booking_id;
  ELSE
    v_total_price := v_booking.total_price;
    v_amount_due := GREATEST(0, v_total_price - v_amount_paid);
    v_new_payment_status := CASE WHEN v_amount_due = 0 THEN 'paid' WHEN v_amount_paid > 0 THEN 'partial' ELSE 'unpaid' END;

    UPDATE public.bookings
    SET status = 'completed'::public.booking_status,
        payment_status = v_new_payment_status,
        updated_at = v_now
    WHERE id = p_booking_id;
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

  RETURN json_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'lounge_id', v_booking.lounge_id,
    'status', 'completed',
    'final_total', v_total_price,
    'amount_paid', v_amount_paid,
    'amount_due', v_amount_due,
    'payment_status', v_new_payment_status
  );
END;
$$;
COMMIT;
