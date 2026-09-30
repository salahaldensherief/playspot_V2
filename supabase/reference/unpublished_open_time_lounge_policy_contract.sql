-- QUARANTINED: do not apply. Superseded by verified live lounge-level policy.
-- This draft assumes room policy columns absent from the live schema and
-- attempts to replace a jsonb RPC with void. Retained only for review history.
BEGIN;

ALTER TABLE public.lounges
  ADD COLUMN IF NOT EXISTS allow_open_time_sessions boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS open_time_rounding_minutes integer NOT NULL DEFAULT 15,
  ADD COLUMN IF NOT EXISTS open_time_min_minutes integer NOT NULL DEFAULT 30,
  ADD COLUMN IF NOT EXISTS open_time_max_minutes integer;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'lounges_open_time_policy_values_check'
      AND conrelid = 'public.lounges'::regclass
  ) THEN
    ALTER TABLE public.lounges
      ADD CONSTRAINT lounges_open_time_policy_values_check
      CHECK (
        open_time_rounding_minutes BETWEEN 1 AND 240
        AND open_time_min_minutes BETWEEN 1 AND 1440
        AND (open_time_max_minutes IS NULL OR open_time_max_minutes BETWEEN open_time_min_minutes AND 1440)
      );
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.update_lounge_open_time_policy(
  p_lounge_id uuid,
  p_allow_open_time_sessions boolean,
  p_open_time_rounding_minutes integer,
  p_open_time_min_minutes integer,
  p_open_time_max_minutes integer DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_old_rounding integer;
  v_old_minimum integer;
  v_old_maximum integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF NOT private.can_operate_playspot_lounge(p_lounge_id) THEN
    RAISE EXCEPTION 'Not authorized for this lounge' USING ERRCODE = '42501';
  END IF;

  IF p_open_time_rounding_minutes NOT BETWEEN 1 AND 240
     OR p_open_time_min_minutes NOT BETWEEN 1 AND 1440
     OR (p_open_time_max_minutes IS NOT NULL
         AND p_open_time_max_minutes NOT BETWEEN p_open_time_min_minutes AND 1440) THEN
    RAISE EXCEPTION 'Invalid open time policy' USING ERRCODE = '22023';
  END IF;

  SELECT l.open_time_rounding_minutes, l.open_time_min_minutes, l.open_time_max_minutes
  INTO v_old_rounding, v_old_minimum, v_old_maximum
  FROM public.lounges AS l
  WHERE l.id = p_lounge_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lounge not found' USING ERRCODE = '22023';
  END IF;

  UPDATE public.lounges
  SET allow_open_time_sessions = p_allow_open_time_sessions,
      open_time_rounding_minutes = p_open_time_rounding_minutes,
      open_time_min_minutes = p_open_time_min_minutes,
      open_time_max_minutes = p_open_time_max_minutes,
      updated_at = now()
  WHERE id = p_lounge_id;

  -- Rooms that still match the previous lounge defaults inherit the new
  -- policy. Explicit room customizations remain untouched.
  UPDATE public.rooms
  SET open_time_rounding_minutes = p_open_time_rounding_minutes,
      open_time_minimum_minutes = p_open_time_min_minutes,
      open_time_max_minutes = p_open_time_max_minutes,
      updated_at = now()
  WHERE lounge_id = p_lounge_id
    AND open_time_rounding_minutes = v_old_rounding
    AND open_time_minimum_minutes = v_old_minimum
    AND open_time_max_minutes IS NOT DISTINCT FROM v_old_maximum;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.update_lounge_open_time_policy(uuid, boolean, integer, integer, integer)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_lounge_open_time_policy(uuid, boolean, integer, integer, integer)
TO authenticated;

CREATE OR REPLACE FUNCTION private.enforce_lounge_open_time_policy()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
BEGIN
  IF NEW.is_open_time IS TRUE AND NOT EXISTS (
    SELECT 1
    FROM public.lounges AS l
    WHERE l.id = NEW.lounge_id
      AND l.allow_open_time_sessions IS TRUE
  ) THEN
    RAISE EXCEPTION 'OPEN_TIME_DISABLED_FOR_LOUNGE' USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS bookings_enforce_lounge_open_time_policy ON public.bookings;
CREATE TRIGGER bookings_enforce_lounge_open_time_policy
BEFORE INSERT OR UPDATE OF is_open_time, lounge_id ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION private.enforce_lounge_open_time_policy();

CREATE OR REPLACE FUNCTION public.complete_open_time_session(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_room public.rooms%ROWTYPE;
  v_ended_at timestamptz := now();
  v_elapsed_minutes integer;
  v_billable_minutes integer;
  v_rounding integer;
  v_minimum integer;
  v_base_rate numeric;
  v_hourly_rate numeric;
  v_room_total numeric;
  v_extras_total numeric := 0;
  v_final_total numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  SELECT b.* INTO v_booking
  FROM public.bookings AS b
  WHERE b.id = p_booking_id
    AND b.is_open_time IS TRUE
    AND b.status = 'in_progress'::public.booking_status
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active open time session not found' USING ERRCODE = '22023';
  END IF;
  IF NOT private.can_operate_playspot_lounge(v_booking.lounge_id) THEN
    RAISE EXCEPTION 'Not authorized for this lounge' USING ERRCODE = '42501';
  END IF;

  SELECT r.* INTO v_room
  FROM public.rooms AS r
  WHERE r.id = v_booking.room_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found' USING ERRCODE = '22023';
  END IF;

  v_elapsed_minutes := GREATEST(
    1,
    CEIL(EXTRACT(EPOCH FROM (v_ended_at - v_booking.open_time_started_at)) / 60.0)::integer
  );
  v_rounding := GREATEST(1, COALESCE(v_room.open_time_rounding_minutes, 15));
  v_minimum := GREATEST(1, COALESCE(v_room.open_time_minimum_minutes, 30));
  v_billable_minutes := GREATEST(
    v_minimum,
    CEIL(v_elapsed_minutes::numeric / v_rounding::numeric)::integer * v_rounding
  );

  -- The maximum is a billing cap. Closing must always succeed so a late
  -- cashier action cannot leave the room permanently occupied.
  IF v_room.open_time_max_minutes IS NOT NULL THEN
    v_billable_minutes := LEAST(v_billable_minutes, v_room.open_time_max_minutes);
  END IF;

  v_base_rate := COALESCE(
    NULLIF((v_booking.open_time_pricing_snapshot->>'base_hourly_rate')::numeric, 0),
    CASE
      WHEN v_booking.play_mode = 'multi' AND COALESCE(v_room.hourly_rate_multi, 0) > 0
        THEN v_room.hourly_rate_multi
      ELSE v_room.hourly_rate_single
    END
  );
  v_hourly_rate := CASE COALESCE(v_room.open_time_pricing_mode, 'same_hourly')
    WHEN 'custom_hourly' THEN COALESCE(v_room.open_time_custom_hourly_rate, v_base_rate)
    WHEN 'hourly_plus_percentage' THEN v_base_rate * COALESCE(v_room.open_time_price_multiplier, 1)
    ELSE v_base_rate
  END;
  IF COALESCE(v_hourly_rate, 0) <= 0 THEN
    RAISE EXCEPTION 'Room has no valid open time rate' USING ERRCODE = '23514';
  END IF;

  SELECT COALESCE(sum(COALESCE(bi.total_price, bi.unit_price * bi.quantity, 0)), 0)
  INTO v_extras_total
  FROM public.booking_items AS bi
  WHERE bi.booking_id = p_booking_id;

  v_room_total := ROUND((v_hourly_rate * v_billable_minutes::numeric / 60.0), 2);
  v_final_total := ROUND(v_room_total + COALESCE(v_extras_total, 0), 2);

  UPDATE public.bookings
  SET status = 'completed'::public.booking_status,
      open_time_ended_at = v_ended_at,
      duration_minutes = v_billable_minutes,
      end_time = to_char(v_ended_at AT TIME ZONE 'Africa/Cairo', 'HH24:MI:SS'),
      room_price = v_room_total,
      total_price = v_final_total,
      payment_status = 'paid',
      open_time_pricing_snapshot = COALESCE(open_time_pricing_snapshot, '{}'::jsonb)
        || jsonb_build_object(
          'ended_at', v_ended_at,
          'elapsed_minutes', v_elapsed_minutes,
          'billable_minutes', v_billable_minutes,
          'maximum_exceeded', v_room.open_time_max_minutes IS NOT NULL
            AND v_elapsed_minutes > v_room.open_time_max_minutes,
          'hourly_rate', v_hourly_rate,
          'room_total', v_room_total,
          'extras_total', v_extras_total,
          'final_total', v_final_total
        ),
      updated_at = now()
  WHERE id = p_booking_id;

  UPDATE public.rooms
  SET status = 'available', is_available = true, updated_at = now()
  WHERE id = v_booking.room_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'elapsed_minutes', v_elapsed_minutes,
    'billable_minutes', v_billable_minutes,
    'maximum_exceeded', v_room.open_time_max_minutes IS NOT NULL
      AND v_elapsed_minutes > v_room.open_time_max_minutes,
    'room_total', v_room_total,
    'extras_total', v_extras_total,
    'final_total', v_final_total
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.complete_open_time_session(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_open_time_session(uuid) TO authenticated;

COMMIT;
