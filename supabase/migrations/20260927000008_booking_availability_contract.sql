BEGIN;

CREATE OR REPLACE FUNCTION public.get_room_bookings_for_operational_date(
  p_lounge_id uuid,
  p_date date
)
RETURNS TABLE(
  room_id uuid,
  start_at timestamp without time zone,
  end_at timestamp without time zone,
  status text,
  expires_at timestamp with time zone
)
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $function$
DECLARE
  v_opening time without time zone;
  v_closing time without time zone;
  v_start timestamp without time zone;
  v_end timestamp without time zone;
BEGIN
  SELECT l.opening_time, l.closing_time
  INTO v_opening, v_closing
  FROM public.lounges AS l
  WHERE l.id = p_lounge_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lounge not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_opening IS NULL OR v_closing IS NULL THEN
    v_start := p_date::timestamp;
    v_end := (p_date + 1)::timestamp;
  ELSE
    v_start := p_date + v_opening;
    v_end := p_date + v_closing;

    IF v_closing <= v_opening THEN
      v_end := v_end + interval '1 day';
    END IF;
  END IF;

  RETURN QUERY
  SELECT
    b.room_id,
    lower(b.booking_period) AS start_at,
    upper(b.booking_period) AS end_at,
    b.status::text,
    b.expires_at
  FROM public.bookings AS b
  WHERE b.lounge_id = p_lounge_id
    AND b.booking_period IS NOT NULL
    AND b.status IN (
      'pending'::public.booking_status,
      'upcoming'::public.booking_status,
      'in_progress'::public.booking_status
    )
    AND (
      b.status <> 'pending'::public.booking_status
      OR b.expires_at IS NULL
      OR b.expires_at > now()
    )
    AND b.booking_period && pg_catalog.tsrange(v_start, v_end, '[)')
  ORDER BY b.room_id, lower(b.booking_period);
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_room_bookings_for_operational_date(uuid, date)
FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_room_bookings_for_operational_date(uuid, date)
TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.check_room_availability_local(
  p_room_id uuid,
  p_start_time timestamp without time zone,
  p_end_time timestamp without time zone
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT
    p_room_id IS NOT NULL
    AND p_start_time IS NOT NULL
    AND p_end_time IS NOT NULL
    AND p_end_time > p_start_time
    AND NOT EXISTS (
      SELECT 1
      FROM public.bookings AS b
      WHERE b.room_id = p_room_id
        AND b.booking_period IS NOT NULL
        AND b.status IN (
          'pending'::public.booking_status,
          'upcoming'::public.booking_status,
          'in_progress'::public.booking_status
        )
        AND (
          b.status <> 'pending'::public.booking_status
          OR b.expires_at IS NULL
          OR b.expires_at > now()
        )
        AND b.booking_period && pg_catalog.tsrange(
          p_start_time,
          p_end_time,
          '[)'
        )
    );
$function$;

REVOKE EXECUTE ON FUNCTION public.check_room_availability_local(
  uuid, timestamp without time zone, timestamp without time zone
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.check_room_availability_local(
  uuid, timestamp without time zone, timestamp without time zone
) TO authenticated, service_role;

COMMIT;
