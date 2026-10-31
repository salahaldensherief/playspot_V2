-- Preserved local schema-only contract; no records or credentials.
CREATE OR REPLACE FUNCTION public.start_booking_session(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_shift_id uuid;
  v_now timestamptz := now();
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

  -- Idempotency: if already running, return success
  IF v_booking.status = 'in_progress'::public.booking_status THEN
    RETURN jsonb_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'status', 'in_progress',
      'idempotent', true
    );
  END IF;

  IF v_booking.status NOT IN ('upcoming'::public.booking_status, 'pending'::public.booking_status) THEN
    RAISE EXCEPTION 'Booking is not startable from current status: %', v_booking.status
      USING ERRCODE = '55000';
  END IF;

  -- Require active shift for the lounge
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
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'NO_OPEN_SHIFT';
  END IF;

  -- Security check: Non-open-time bookings require full payment before starting
  IF COALESCE(v_booking.payment_status, 'unpaid') <> 'paid'
     AND COALESCE(v_booking.is_open_time, false) IS FALSE THEN
    RAISE EXCEPTION 'PAYMENT_REQUIRED_BEFORE_SESSION_START' USING ERRCODE = '55000';
  END IF;

  UPDATE public.bookings AS b
  SET status = 'in_progress'::public.booking_status,
      checked_in_at = COALESCE(b.checked_in_at, v_now),
      actual_start_time = COALESCE(b.actual_start_time, v_now),
      shift_id = COALESCE(b.shift_id, v_shift_id),
      updated_at = v_now
  WHERE b.id = p_booking_id;

  IF v_booking.room_id IS NOT NULL THEN
    UPDATE public.rooms AS r
    SET status = 'occupied',
        is_available = false,
        updated_at = v_now
    WHERE r.id = v_booking.room_id
      AND r.status NOT IN ('maintenance', 'deleted');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'status', 'in_progress',
    'shift_id', v_shift_id
  );
END;
$function$;
