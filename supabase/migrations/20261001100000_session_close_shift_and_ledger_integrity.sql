BEGIN;
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_open_time_billing_minutes_check;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_open_time_billing_minutes_check
  CHECK(open_time_billing_minutes IS NULL OR open_time_billing_minutes>=1) NOT VALID;

CREATE OR REPLACE FUNCTION private.booking_completion_receipt(p_booking_id uuid,p_idempotent boolean)
RETURNS json LANGUAGE sql SECURITY DEFINER SET search_path TO '' AS $$
 SELECT json_build_object('success',true,'booking_id',b.id,'lounge_id',b.lounge_id,
   'status',b.status::text,'final_total',b.total_price,
   'amount_paid',COALESCE(p.amount_paid,0),
   'amount_due',CASE WHEN b.payment_status='refunded' THEN 0
     ELSE GREATEST(0,b.total_price-COALESCE(p.amount_paid,0)) END,
   'payment_status',b.payment_status,'idempotent',p_idempotent,
   'closed_at',b.open_time_closed_at,'billing_minutes',b.open_time_billing_minutes)
 FROM public.bookings b LEFT JOIN LATERAL (
   SELECT sum(amount) AS amount_paid FROM public.payments
   WHERE booking_id=b.id AND status='completed'
 ) p ON true WHERE b.id=p_booking_id;
$$;
REVOKE ALL ON FUNCTION private.booking_completion_receipt(uuid,boolean) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.complete_booking_session(
  p_booking_id uuid,
  p_action_by uuid DEFAULT NULL::uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
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
  v_rate numeric := 50;
  v_room_price numeric;
  v_total_price numeric;
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

  IF public.has_lounge_permission(v_booking.lounge_id, 'sessions_control') IS NOT TRUE THEN
    RAISE EXCEPTION 'Not authorized for session control in this lounge' USING ERRCODE = '42501';
  END IF;

  IF p_action_by IS NOT NULL AND p_action_by IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'ACTION_ACTOR_MISMATCH' USING ERRCODE='42501';
  END IF;

  -- Idempotency: if already completed, return existing totals without recalculating
  IF v_booking.status = 'completed'::public.booking_status THEN
    RETURN private.booking_completion_receipt(p_booking_id,true);
  END IF;

  IF v_booking.status <> 'in_progress'::public.booking_status THEN
    RAISE EXCEPTION 'Only in-progress sessions can be completed' USING ERRCODE = '55000';
  END IF;

  PERFORM 1 FROM public.shifts WHERE lounge_id=v_booking.lounge_id
    AND status='open' AND closed_at IS NULL ORDER BY opened_at DESC LIMIT 1 FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'OPEN_SHIFT_REQUIRED' USING ERRCODE='55000'; END IF;

  -- If this is an Open Time session, calculate billing from snapshot
  IF COALESCE(v_booking.is_open_time, false) IS TRUE THEN
    v_snap := v_booking.open_time_pricing_snapshot;

    IF v_snap IS NOT NULL AND v_snap <> '{}'::jsonb THEN
      v_rate := COALESCE((v_snap->>'effective_hourly_rate')::numeric, (v_snap->>'base_hourly_rate')::numeric, 50);
      v_minimum := COALESCE((v_snap->>'minimum_minutes')::integer, 30);
      v_rounding := COALESCE((v_snap->>'rounding_minutes')::integer, 15);
    ELSE
      -- Fallback to lounge & room current settings
      SELECT l.* INTO v_lounge FROM public.lounges l WHERE l.id = v_booking.lounge_id;
      SELECT r.* INTO v_room FROM public.rooms r WHERE r.id = v_booking.room_id;
      v_minimum := COALESCE(v_room.open_time_minimum_minutes, v_lounge.open_time_minimum_minutes, 30);
      v_rounding := COALESCE(v_room.open_time_rounding_minutes, v_lounge.open_time_rounding_minutes, 15);
      v_rate := CASE
        WHEN v_booking.play_mode = 'multi' AND COALESCE(v_room.hourly_rate_multi, 0) > 0 THEN v_room.hourly_rate_multi
        ELSE COALESCE(v_room.hourly_rate_single, v_room.hourly_rate, 50)
      END;
    END IF;

    v_start_time := COALESCE(v_booking.open_time_started_at, v_booking.actual_start_time, v_booking.created_at);
    v_elapsed_minutes := GREATEST(1, CEIL(EXTRACT(EPOCH FROM (v_now - v_start_time)) / 60.0)::integer);

    IF v_rate IS NULL OR v_rate < 0 OR v_rate::text IN ('NaN','Infinity','-Infinity')
       OR v_rounding IS NULL OR v_rounding < 1 OR v_minimum IS NULL OR v_minimum < 1 THEN
      RAISE EXCEPTION 'INVALID_PRICING_SNAPSHOT' USING ERRCODE='22023';
    END IF;
    v_billable_raw := v_elapsed_minutes;

    -- Apply minimum minutes
    v_billable_raw := GREATEST(v_billable_raw, v_minimum);

    -- Apply rounding
    v_billable_minutes := CEIL(v_billable_raw::numeric / v_rounding::numeric)::integer * v_rounding;

    v_room_price := ROUND((v_rate / 60.0) * v_billable_minutes, 2);
    v_total_price := GREATEST(0, v_room_price + COALESCE(v_booking.addons_total, 0) - COALESCE(v_booking.discount_amount, 0));

    UPDATE public.bookings
    SET status = 'completed'::public.booking_status,
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
    UPDATE public.bookings
    SET status = 'completed'::public.booking_status,
        updated_at = v_now
    WHERE id = p_booking_id;
  END IF;

  PERFORM 1 FROM public.rooms WHERE id=v_booking.room_id AND lounge_id=v_booking.lounge_id FOR UPDATE;

  -- Release room
  IF v_booking.room_id IS NOT NULL THEN
    UPDATE public.rooms AS r
    SET status = 'available',
        is_available = true,
        updated_at = v_now
    WHERE r.id = v_booking.room_id
      AND r.lounge_id = v_booking.lounge_id
      AND r.status = 'occupied'
      AND NOT EXISTS(SELECT 1 FROM public.bookings AS active
        WHERE active.room_id=r.id AND active.lounge_id=r.lounge_id
          AND active.id<>p_booking_id AND active.status='in_progress'::public.booking_status);
  END IF;

  RETURN private.booking_completion_receipt(p_booking_id,false);
END;
$$;

REVOKE ALL ON FUNCTION public.complete_booking_session(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_booking_session(uuid, uuid) TO authenticated, service_role;


COMMIT;
