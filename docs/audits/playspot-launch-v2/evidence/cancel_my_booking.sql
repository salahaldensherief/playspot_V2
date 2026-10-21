-- AUDIT SNAPSHOT ONLY. Captured read-only 2026-10-21. Do not deploy.
CREATE OR REPLACE FUNCTION public.cancel_my_booking(p_booking_id uuid, p_reason text DEFAULT 'Cancelled by user'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
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

  IF v_booking.user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;

  IF v_booking.status NOT IN (
    'pending'::public.booking_status,
    'upcoming'::public.booking_status
  ) THEN
    RAISE EXCEPTION 'Booking cannot be cancelled in its current status'
      USING ERRCODE = '55000';
  END IF;

  UPDATE public.bookings
  SET status = 'cancelled'::public.booking_status,
      cancellation_reason = COALESCE(NULLIF(btrim(p_reason), ''), 'Cancelled by user'),
      cancelled_at = now(),
      cancelled_by = auth.uid(),
      updated_at = now()
  WHERE id = p_booking_id;

  IF v_booking.room_id IS NOT NULL THEN
    PERFORM public.sync_room_status(v_booking.room_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'status', 'cancelled'
  );
END;
$function$
