BEGIN;

CREATE TABLE IF NOT EXISTS public.booking_holds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hold_token uuid NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  start_at timestamp without time zone NOT NULL,
  end_at timestamp without time zone NOT NULL,
  expires_at timestamp with time zone NOT NULL,
  released_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT booking_holds_valid_range CHECK (end_at > start_at),
  CONSTRAINT booking_holds_token_room_unique UNIQUE (hold_token, room_id)
);

CREATE INDEX IF NOT EXISTS booking_holds_room_window_idx
  ON public.booking_holds (room_id, start_at, end_at);

CREATE INDEX IF NOT EXISTS booking_holds_expiry_idx
  ON public.booking_holds (expires_at)
  WHERE released_at IS NULL;

ALTER TABLE public.booking_holds ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.booking_holds FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.booking_holds TO service_role;

CREATE OR REPLACE FUNCTION public.acquire_booking_hold(
  p_room_ids uuid[],
  p_start_at timestamp without time zone,
  p_end_at timestamp without time zone,
  p_hold_minutes integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_room_ids uuid[];
  v_room_id uuid;
  v_room_count integer;
  v_found_count integer;
  v_lounge_count integer;
  v_lounge_id uuid;
  v_hold_token uuid := gen_random_uuid();
  v_expires_at timestamptz;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_start_at IS NULL OR p_end_at IS NULL OR p_end_at <= p_start_at THEN
    RAISE EXCEPTION 'Invalid booking hold range' USING ERRCODE = '22023';
  END IF;

  IF p_end_at - p_start_at > interval '24 hours' THEN
    RAISE EXCEPTION 'Booking hold range is too long' USING ERRCODE = '22023';
  END IF;

  IF p_room_ids IS NULL OR cardinality(p_room_ids) = 0 THEN
    RAISE EXCEPTION 'At least one room is required' USING ERRCODE = '22023';
  END IF;

  SELECT array_agg(room_id ORDER BY room_id), count(*)
  INTO v_room_ids, v_room_count
  FROM (
    SELECT DISTINCT unnest(p_room_ids) AS room_id
  ) AS requested_rooms;

  IF v_room_count > 20 THEN
    RAISE EXCEPTION 'Too many rooms requested' USING ERRCODE = '22023';
  END IF;

  FOR v_room_id IN
    SELECT unnest(v_room_ids)
    ORDER BY 1
  LOOP
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_room_id::text, 0)
    );
  END LOOP;

  SELECT
    count(*),
    count(DISTINCT r.lounge_id),
    (array_agg(r.lounge_id ORDER BY r.lounge_id))[1]
  INTO v_found_count, v_lounge_count, v_lounge_id
  FROM public.rooms AS r
  WHERE r.id = ANY(v_room_ids)
    AND r.is_active IS TRUE
    AND r.is_available IS TRUE
    AND COALESCE(r.status, '') <> 'deleted';

  IF v_found_count <> v_room_count THEN
    RAISE EXCEPTION 'One or more rooms are unavailable' USING ERRCODE = '23514';
  END IF;

  IF v_lounge_count <> 1 THEN
    RAISE EXCEPTION 'All held rooms must belong to the same lounge'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.booking_holds
  SET released_at = now()
  WHERE user_id = v_user_id
    AND released_at IS NULL
    AND expires_at > now();

  IF EXISTS (
    SELECT 1
    FROM public.bookings AS b
    WHERE b.room_id = ANY(v_room_ids)
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
        p_start_at,
        p_end_at,
        '[)'
      )
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'SLOT_OVERLAP_CONFLICT'
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.booking_holds AS h
    WHERE h.room_id = ANY(v_room_ids)
      AND h.user_id IS DISTINCT FROM v_user_id
      AND h.released_at IS NULL
      AND h.expires_at > now()
      AND pg_catalog.tsrange(h.start_at, h.end_at, '[)')
          && pg_catalog.tsrange(p_start_at, p_end_at, '[)')
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'SLOT_HELD_BY_ANOTHER_USER'
    );
  END IF;

  v_expires_at := now()
    + make_interval(mins => LEAST(GREATEST(COALESCE(p_hold_minutes, 10), 1), 30));

  INSERT INTO public.booking_holds (
    hold_token,
    user_id,
    lounge_id,
    room_id,
    start_at,
    end_at,
    expires_at
  )
  SELECT
    v_hold_token,
    v_user_id,
    v_lounge_id,
    requested_room_id,
    p_start_at,
    p_end_at,
    v_expires_at
  FROM unnest(v_room_ids) AS requested_room_id;

  RETURN jsonb_build_object(
    'success', true,
    'hold_token', v_hold_token,
    'hold_expires_at', v_expires_at,
    'room_ids', to_jsonb(v_room_ids)
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.acquire_booking_hold(
  uuid[], timestamp without time zone, timestamp without time zone, integer
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.acquire_booking_hold(
  uuid[], timestamp without time zone, timestamp without time zone, integer
) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.release_booking_hold(
  p_hold_token uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  UPDATE public.booking_holds
  SET released_at = COALESCE(released_at, now())
  WHERE hold_token = p_hold_token
    AND user_id = v_user_id
    AND released_at IS NULL;

  RETURN FOUND;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.release_booking_hold(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.release_booking_hold(uuid)
TO authenticated, service_role;

CREATE OR REPLACE FUNCTION private.guard_booking_against_active_holds()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_start_at timestamp without time zone;
  v_end_at timestamp without time zone;
BEGIN
  IF NEW.room_id IS NULL
     OR NEW.date IS NULL
     OR NEW.start_time IS NULL
     OR NEW.end_time IS NULL
     OR NEW.status NOT IN (
       'pending'::public.booking_status,
       'upcoming'::public.booking_status,
       'in_progress'::public.booking_status
     ) THEN
    RETURN NEW;
  END IF;

  v_start_at := NEW.date::timestamp + NEW.start_time;
  v_end_at := NEW.date::timestamp + NEW.end_time;

  IF NEW.end_time <= NEW.start_time THEN
    v_end_at := v_end_at + interval '1 day';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(NEW.room_id::text, 0)
  );

  IF EXISTS (
    SELECT 1
    FROM public.booking_holds AS h
    WHERE h.room_id = NEW.room_id
      AND h.user_id IS DISTINCT FROM NEW.user_id
      AND h.released_at IS NULL
      AND h.expires_at > now()
      AND pg_catalog.tsrange(h.start_at, h.end_at, '[)')
          && pg_catalog.tsrange(v_start_at, v_end_at, '[)')
  ) THEN
    RAISE EXCEPTION 'SLOT_HELD_BY_ANOTHER_USER'
      USING ERRCODE = '23P01';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_guard_booking_against_active_holds
  ON public.bookings;

CREATE TRIGGER trg_guard_booking_against_active_holds
BEFORE INSERT OR UPDATE OF
  room_id,
  user_id,
  date,
  start_time,
  end_time,
  status
ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION private.guard_booking_against_active_holds();

CREATE OR REPLACE FUNCTION public.verify_and_hold_slot(
  p_room_id uuid,
  p_start_time timestamp with time zone,
  p_end_time timestamp with time zone,
  p_user_id uuid,
  p_hold_minutes integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF auth.uid() IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;

  RETURN public.acquire_booking_hold(
    ARRAY[p_room_id],
    p_start_time AT TIME ZONE 'Africa/Cairo',
    p_end_time AT TIME ZONE 'Africa/Cairo',
    p_hold_minutes
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.verify_and_hold_slot(
  uuid, timestamp with time zone, timestamp with time zone, uuid, integer
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.verify_and_hold_slot(
  uuid, timestamp with time zone, timestamp with time zone, uuid, integer
) TO authenticated, service_role;

COMMIT;
