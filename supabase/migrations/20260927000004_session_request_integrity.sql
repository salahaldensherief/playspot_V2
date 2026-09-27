BEGIN;

CREATE OR REPLACE FUNCTION public.request_staff_assistance(
  p_lounge_id uuid,
  p_room_id uuid,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_call_id uuid;
  v_booking_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated request' USING ERRCODE = '28000';
  END IF;

  SELECT b.id
  INTO v_booking_id
  FROM public.bookings AS b
  WHERE b.user_id = auth.uid()
    AND b.lounge_id = p_lounge_id
    AND b.room_id = p_room_id
    AND b.status IN (
      'upcoming'::public.booking_status,
      'in_progress'::public.booking_status
    )
    AND b.booking_period IS NOT NULL
    AND (
      b.status = 'in_progress'::public.booking_status
      OR b.booking_period @> (now() AT TIME ZONE 'Africa/Cairo')
    )
  ORDER BY b.created_at DESC
  LIMIT 1;

  IF v_booking_id IS NULL THEN
    RAISE EXCEPTION 'No active booking found for this lounge and room'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.service_calls (
    lounge_id,
    room_id,
    booking_id,
    user_id,
    notes,
    status,
    created_at
  )
  VALUES (
    p_lounge_id,
    p_room_id,
    v_booking_id,
    auth.uid(),
    NULLIF(btrim(p_notes), ''),
    'pending',
    now()
  )
  RETURNING id INTO v_call_id;

  RETURN jsonb_build_object(
    'success', true,
    'call_id', v_call_id,
    'booking_id', v_booking_id
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.request_staff_assistance(uuid, uuid, text)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.request_staff_assistance(uuid, uuid, text)
TO authenticated, service_role, supabase_auth_admin;

DROP TRIGGER IF EXISTS trg_review_loyalty ON public.lounge_reviews;

COMMIT;
