BEGIN;

CREATE OR REPLACE FUNCTION public.request_booking_extension(
  p_booking_id uuid,
  p_requested_minutes integer
)
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

  IF p_requested_minutes IS NULL
     OR p_requested_minutes <= 0
     OR p_requested_minutes > 720 THEN
    RAISE EXCEPTION 'Invalid extension minutes' USING ERRCODE = '22023';
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
    AND b.user_id = auth.uid()
    AND b.status = 'in_progress'::public.booking_status
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active booking not found for current user'
      USING ERRCODE = '42501';
  END IF;

  IF COALESCE(v_booking.extension_status, 'none') = 'pending' THEN
    RAISE EXCEPTION 'Extension request already pending'
      USING ERRCODE = '55000';
  END IF;

  UPDATE public.bookings
  SET extension_status = 'pending',
      requested_extension_minutes = p_requested_minutes,
      updated_at = now()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'extension_status', 'pending',
    'requested_extension_minutes', p_requested_minutes
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.request_booking_extension(uuid, integer)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.request_booking_extension(uuid, integer)
TO authenticated, service_role, supabase_auth_admin;

CREATE OR REPLACE FUNCTION public.submit_lounge_review(
  p_lounge_id uuid,
  p_booking_id uuid,
  p_rating numeric,
  p_comment text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_review_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
    RAISE EXCEPTION 'Rating must be between 1 and 5'
      USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.bookings AS b
    WHERE b.id = p_booking_id
      AND b.user_id = auth.uid()
      AND b.lounge_id = p_lounge_id
      AND b.status = 'completed'::public.booking_status
  ) THEN
    RAISE EXCEPTION 'Completed booking not found for current user'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.lounge_reviews (
    lounge_id,
    booking_id,
    user_id,
    rating,
    comment,
    created_at
  )
  VALUES (
    p_lounge_id,
    p_booking_id,
    auth.uid(),
    p_rating,
    NULLIF(btrim(p_comment), ''),
    now()
  )
  ON CONFLICT (user_id, booking_id)
  DO UPDATE SET
    rating = EXCLUDED.rating,
    comment = EXCLUDED.comment
  RETURNING id INTO v_review_id;

  RETURN jsonb_build_object(
    'success', true,
    'review_id', v_review_id,
    'booking_id', p_booking_id,
    'lounge_id', p_lounge_id
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.submit_lounge_review(
  uuid, uuid, numeric, text
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.submit_lounge_review(
  uuid, uuid, numeric, text
) TO authenticated, service_role, supabase_auth_admin;


CREATE OR REPLACE FUNCTION public.request_staff_assistance_for_booking(
  p_booking_id uuid,
  p_call_type text,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_call_id uuid;
  v_call_type text := NULLIF(btrim(p_call_type), '');
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF v_call_type IS NULL THEN
    RAISE EXCEPTION 'Call type is required' USING ERRCODE = '22023';
  END IF;

  SELECT b.*
  INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
    AND b.user_id = auth.uid()
    AND b.status = 'in_progress'::public.booking_status
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active booking not found for current user'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.service_calls (
    lounge_id,
    room_id,
    booking_id,
    user_id,
    call_type,
    request_type,
    note,
    notes,
    status,
    is_attended,
    created_at
  )
  VALUES (
    v_booking.lounge_id,
    v_booking.room_id,
    v_booking.id,
    auth.uid(),
    v_call_type,
    v_call_type,
    NULLIF(btrim(p_notes), ''),
    NULLIF(btrim(p_notes), ''),
    'pending',
    false,
    now()
  )
  RETURNING id INTO v_call_id;

  RETURN jsonb_build_object(
    'success', true,
    'call_id', v_call_id,
    'booking_id', v_booking.id,
    'lounge_id', v_booking.lounge_id,
    'room_id', v_booking.room_id,
    'call_type', v_call_type
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.request_staff_assistance_for_booking(
  uuid, text, text
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.request_staff_assistance_for_booking(
  uuid, text, text
) TO authenticated, service_role, supabase_auth_admin;

COMMIT;
