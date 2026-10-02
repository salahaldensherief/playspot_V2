-- ============================================================================
-- Migration: 20260930160000_p1_waitlist_and_smart_rebook.sql
-- Description: Phase 4 (P1) Waitlist Engine, Multi-Room Batch Intent,
--              10-Minute Fair Claim Window & Smart Rebook Engine (7-14 Days).
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Schema Upgrades for public.booking_waitlist
-- ----------------------------------------------------------------------------

-- Add required columns if not already present
ALTER TABLE public.booking_waitlist
  ADD COLUMN IF NOT EXISTS start_at timestamp without time zone,
  ADD COLUMN IF NOT EXISTS end_at timestamp without time zone,
  ADD COLUMN IF NOT EXISTS intent_id uuid DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS claim_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS hold_id uuid REFERENCES public.booking_holds(id) ON DELETE SET NULL;

-- Update status check constraint to support all client and engine lifecycle states
ALTER TABLE public.booking_waitlist
  DROP CONSTRAINT IF EXISTS booking_waitlist_status_check;

ALTER TABLE public.booking_waitlist
  ADD CONSTRAINT booking_waitlist_status_check
  CHECK (status IN ('waiting', 'active', 'notified', 'booked', 'claimed', 'cancelled', 'expired'));

-- Ensure dates and timestamps remain fully synchronized
CREATE OR REPLACE FUNCTION public.fn_sync_booking_waitlist_dates()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  -- 1. Bi-directional sync between start_at/end_at and requested_date/duration_minutes
  IF NEW.start_at IS NOT NULL AND NEW.end_at IS NOT NULL THEN
    IF NEW.end_at <= NEW.start_at THEN
      RAISE EXCEPTION 'end_at must be strictly after start_at' USING ERRCODE = '22023';
    END IF;
    NEW.requested_date := NEW.start_at::date;
    NEW.preferred_start_time := NEW.start_at::time;
    NEW.duration_minutes := GREATEST(15, LEAST(1440, ROUND(EXTRACT(EPOCH FROM (NEW.end_at - NEW.start_at)) / 60)::integer));
  ELSIF NEW.requested_date IS NOT NULL THEN
    NEW.start_at := NEW.requested_date + COALESCE(NEW.preferred_start_time, '00:00:00'::time);
    NEW.duration_minutes := GREATEST(15, LEAST(1440, COALESCE(NEW.duration_minutes, 60)));
    NEW.end_at := NEW.start_at + make_interval(mins => NEW.duration_minutes);
  END IF;

  -- 2. Defaults
  IF NEW.expires_at IS NULL THEN
    NEW.expires_at := now() + interval '14 days';
  END IF;

  IF NEW.intent_id IS NULL THEN
    NEW.intent_id := gen_random_uuid();
  END IF;

  NEW.updated_at := now();

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_sync_booking_waitlist_dates ON public.booking_waitlist;
CREATE TRIGGER trg_sync_booking_waitlist_dates
  BEFORE INSERT OR UPDATE ON public.booking_waitlist
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_sync_booking_waitlist_dates();

-- Ensure unique index covers waiting, active, and notified states without duplicate spam
DROP INDEX IF EXISTS public.booking_waitlist_active_unique_idx;
DROP INDEX IF EXISTS public.booking_waitlist_user_room_slot_active_idx;

CREATE UNIQUE INDEX booking_waitlist_user_room_slot_active_idx
ON public.booking_waitlist (user_id, room_id, requested_date, duration_minutes, COALESCE(preferred_start_time, '00:00:00'::time))
WHERE (status IN ('active', 'waiting', 'notified'));

CREATE INDEX IF NOT EXISTS booking_waitlist_intent_idx
ON public.booking_waitlist (intent_id);

CREATE INDEX IF NOT EXISTS booking_waitlist_fifo_dispatch_idx
ON public.booking_waitlist (created_at ASC, id ASC)
WHERE (status IN ('waiting', 'active'));

CREATE INDEX IF NOT EXISTS booking_waitlist_notified_claim_idx
ON public.booking_waitlist (room_id, status, claim_expires_at)
WHERE (status = 'notified');

-- ----------------------------------------------------------------------------
-- 2. View public.slot_waitlist (Resilience Fallback for Mobile Client)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.slot_waitlist AS
SELECT
  id,
  user_id,
  lounge_id,
  room_id,
  requested_date AS date,
  preferred_start_time AS slot_time,
  status,
  created_at
FROM public.booking_waitlist;

CREATE OR REPLACE FUNCTION public.fn_slot_waitlist_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := COALESCE(NEW.user_id, auth.uid());
  v_date date := NEW.date;
  v_time time without time zone := COALESCE(NEW.slot_time, '18:00:00'::time);
  v_start_at timestamp without time zone := v_date + v_time;
  v_end_at timestamp without time zone := v_start_at + interval '60 minutes';
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  INSERT INTO public.booking_waitlist (
    user_id,
    lounge_id,
    room_id,
    requested_date,
    duration_minutes,
    preferred_start_time,
    start_at,
    end_at,
    status
  ) VALUES (
    v_user_id,
    NEW.lounge_id,
    NEW.room_id,
    v_date,
    60,
    v_time,
    v_start_at,
    v_end_at,
    COALESCE(NEW.status, 'waiting')
  )
  RETURNING id INTO NEW.id;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_slot_waitlist_insert ON public.slot_waitlist;
CREATE TRIGGER trg_slot_waitlist_insert
  INSTEAD OF INSERT ON public.slot_waitlist
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_slot_waitlist_insert();

REVOKE ALL ON public.slot_waitlist FROM PUBLIC, anon;
GRANT SELECT, INSERT ON public.slot_waitlist TO authenticated;
GRANT ALL ON public.slot_waitlist TO service_role;

-- ----------------------------------------------------------------------------
-- 3. RPC: join_slot_waitlist (Multi-Room Single Intent Batch Support)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.join_slot_waitlist(
  p_lounge_id uuid,
  p_room_ids uuid[],
  p_date text,
  p_slot_time text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_date date;
  v_time time without time zone;
  v_start_at timestamp without time zone;
  v_end_at timestamp without time zone;
  v_duration_minutes integer := 60;
  v_room_id uuid;
  v_distinct_rooms uuid[];
  v_room_count integer;
  v_valid_room_count integer;
  v_lounge public.lounges%ROWTYPE;
  v_intent_id uuid := gen_random_uuid();
  v_waitlist_ids uuid[] := '{}'::uuid[];
  v_inserted_id uuid;
  v_today date := (now() AT TIME ZONE 'Africa/Cairo')::date;
  v_user_active_count integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_lounge_id IS NULL OR p_room_ids IS NULL OR cardinality(p_room_ids) = 0 THEN
    RAISE EXCEPTION 'Lounge and at least one room are required' USING ERRCODE = '22023';
  END IF;

  BEGIN
    v_date := p_date::date;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Invalid date format' USING ERRCODE = '22023';
  END;

  BEGIN
    v_time := p_slot_time::time;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Invalid time format' USING ERRCODE = '22023';
  END;

  IF v_date < v_today THEN
    RAISE EXCEPTION 'Waitlist date cannot be in the past' USING ERRCODE = '22023';
  END IF;

  v_start_at := v_date + v_time;
  v_end_at := v_start_at + make_interval(mins => v_duration_minutes);

  IF v_start_at < (now() AT TIME ZONE 'Africa/Cairo') + interval '10 minutes' THEN
    RAISE EXCEPTION 'Waitlist slot must be at least 10 minutes in the future'
      USING ERRCODE = '22023';
  END IF;

  -- Verify lounge
  SELECT l.* INTO v_lounge
  FROM public.lounges l
  WHERE l.id = p_lounge_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lounge not found' USING ERRCODE = 'P0002';
  END IF;

  IF COALESCE(v_lounge.is_active, true) IS FALSE
     OR COALESCE(v_lounge.status, 'approved') IN ('deleted', 'rejected', 'suspended') THEN
    RAISE EXCEPTION 'Lounge is not available for waitlist' USING ERRCODE = '55000';
  END IF;

  -- Normalize distinct rooms
  SELECT array_agg(r_id ORDER BY r_id), count(*)
  INTO v_distinct_rooms, v_room_count
  FROM (
    SELECT DISTINCT unnest(p_room_ids) AS r_id
  ) AS distinct_sub;

  IF v_room_count > 20 THEN
    RAISE EXCEPTION 'Cannot join waitlist for more than 20 rooms at once' USING ERRCODE = '22023';
  END IF;

  -- Verify rooms belong to lounge and are active
  SELECT count(*)
  INTO v_valid_room_count
  FROM public.rooms r
  WHERE r.id = ANY(v_distinct_rooms)
    AND r.lounge_id = p_lounge_id
    AND COALESCE(r.is_active, true) IS TRUE
    AND COALESCE(r.status, 'available') <> 'deleted';

  IF v_valid_room_count <> v_room_count THEN
    RAISE EXCEPTION 'One or more rooms are unavailable or do not belong to this lounge'
      USING ERRCODE = '23514';
  END IF;

  -- Check max active waitlist requests per user (limit 20)
  SELECT count(*)
  INTO v_user_active_count
  FROM public.booking_waitlist w
  WHERE w.user_id = v_user_id
    AND w.status IN ('waiting', 'active', 'notified');

  IF (v_user_active_count + v_room_count) > 25 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'WAITLIST_LIMIT',
      'message', 'Exceeded maximum active waitlist requests'
    );
  END IF;

  -- Advisory lock on user waitlist requests to prevent race condition duplicates
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('waitlist-user:' || v_user_id::text, 0)
  );

  FOREACH v_room_id IN ARRAY v_distinct_rooms
  LOOP
    INSERT INTO public.booking_waitlist (
      user_id,
      lounge_id,
      room_id,
      requested_date,
      duration_minutes,
      preferred_start_time,
      start_at,
      end_at,
      status,
      intent_id,
      expires_at
    )
    VALUES (
      v_user_id,
      p_lounge_id,
      v_room_id,
      v_date,
      v_duration_minutes,
      v_time,
      v_start_at,
      v_end_at,
      'waiting',
      v_intent_id,
      now() + interval '14 days'
    )
    ON CONFLICT (
      user_id,
      room_id,
      requested_date,
      duration_minutes,
      (COALESCE(preferred_start_time, '00:00:00'::time))
    )
    WHERE status IN ('active', 'waiting', 'notified')
    DO UPDATE SET
      updated_at = now(),
      intent_id = v_intent_id,
      expires_at = now() + interval '14 days'
    RETURNING id INTO v_inserted_id;

    IF v_inserted_id IS NOT NULL THEN
      v_waitlist_ids := array_append(v_waitlist_ids, v_inserted_id);
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'intent_id', v_intent_id,
    'lounge_id', p_lounge_id,
    'room_ids', to_jsonb(v_distinct_rooms),
    'waitlist_ids', to_jsonb(v_waitlist_ids),
    'date', p_date,
    'slot_time', p_slot_time,
    'message', 'notifyMeSuccess'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.join_slot_waitlist(uuid, uuid[], text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_slot_waitlist(uuid, uuid[], text, text) TO authenticated;

-- ----------------------------------------------------------------------------
-- 4. RPC: join_room_waitlist (Single Room Fallback)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.join_room_waitlist(
  p_lounge_id uuid,
  p_room_id uuid,
  p_date text,
  p_slot_time text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN public.join_slot_waitlist(
    p_lounge_id,
    ARRAY[p_room_id],
    p_date,
    p_slot_time
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.join_room_waitlist(uuid, uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_room_waitlist(uuid, uuid, text, text) TO authenticated;

-- ----------------------------------------------------------------------------
-- 5. RPC: join_booking_waitlist (Timestamp Overload for Mobile Booking Waitlist)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.join_booking_waitlist(
  p_room_id uuid,
  p_start_at timestamp without time zone,
  p_end_at timestamp without time zone
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_lounge_id uuid;
  v_opening time without time zone;
  v_closing time without time zone;
  v_operational_date date;
  v_operational_start timestamp without time zone;
  v_operational_end timestamp without time zone;
  v_duration_minutes integer;
  v_id uuid;
  v_waitlist public.booking_waitlist%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_room_id IS NULL OR p_start_at IS NULL OR p_end_at IS NULL
     OR p_end_at <= p_start_at
     OR p_end_at - p_start_at > interval '24 hours'
     OR p_end_at - p_start_at < interval '15 minutes'
     OR p_start_at < (now() AT TIME ZONE 'Africa/Cairo') + interval '10 minutes'
     OR p_start_at > (now() AT TIME ZONE 'Africa/Cairo') + interval '30 days' THEN
    RAISE EXCEPTION 'Invalid waitlist slot' USING ERRCODE = '22023';
  END IF;

  v_duration_minutes := ROUND(EXTRACT(EPOCH FROM (p_end_at - p_start_at)) / 60)::integer;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_room_id::text, 0)
  );

  SELECT r.lounge_id, l.opening_time, l.closing_time
  INTO v_lounge_id, v_opening, v_closing
  FROM public.rooms r
  JOIN public.lounges l ON l.id = r.lounge_id
  WHERE r.id = p_room_id
    AND COALESCE(r.is_active, true) IS TRUE
    AND COALESCE(r.status, 'available') <> 'deleted'
    AND COALESCE(l.is_active, true) IS TRUE;

  IF v_lounge_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'ROOM_UNAVAILABLE');
  END IF;

  IF v_opening IS NOT NULL AND v_closing IS NOT NULL THEN
    v_operational_date := p_start_at::date;
    IF v_closing <= v_opening AND p_start_at::time < v_closing THEN
      v_operational_date := v_operational_date - 1;
    END IF;
    v_operational_start := v_operational_date + v_opening;
    v_operational_end := v_operational_date + v_closing;
    IF v_closing <= v_opening THEN
      v_operational_end := v_operational_end + interval '1 day';
    END IF;

    IF p_start_at < v_operational_start OR p_end_at > v_operational_end THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'OUTSIDE_WORKING_HOURS');
    END IF;
  END IF;

  -- Check if slot is available now
  IF NOT EXISTS (
    SELECT 1 FROM public.bookings b
    WHERE b.room_id = p_room_id
      AND b.status IN ('pending'::public.booking_status,
                       'upcoming'::public.booking_status,
                       'in_progress'::public.booking_status)
      AND (b.status <> 'pending'::public.booking_status
           OR b.expires_at IS NULL OR b.expires_at > now())
      AND b.booking_period && pg_catalog.tsrange(p_start_at, p_end_at, '[)')
  ) AND NOT EXISTS (
    SELECT 1 FROM public.booking_holds h
    WHERE h.room_id = p_room_id AND h.released_at IS NULL
      AND h.expires_at > now()
      AND pg_catalog.tsrange(h.start_at, h.end_at, '[)')
          && pg_catalog.tsrange(p_start_at, p_end_at, '[)')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'SLOT_AVAILABLE_NOW');
  END IF;

  -- Check existing active waitlist request for this exact slot
  SELECT w.id INTO v_id FROM public.booking_waitlist w
  WHERE w.user_id = v_user_id AND w.room_id = p_room_id
    AND w.requested_date = p_start_at::date
    AND w.preferred_start_time = p_start_at::time
    AND w.duration_minutes = v_duration_minutes
    AND w.status IN ('waiting', 'active', 'notified');

  IF v_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'waitlist_id', v_id, 'status', 'waiting');
  END IF;

  IF (SELECT count(*) FROM public.booking_waitlist w
      WHERE w.user_id = v_user_id AND w.status IN ('waiting', 'active', 'notified')) >= 20 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'WAITLIST_LIMIT');
  END IF;

  INSERT INTO public.booking_waitlist (
    user_id,
    lounge_id,
    room_id,
    start_at,
    end_at,
    requested_date,
    duration_minutes,
    preferred_start_time,
    status
  )
  VALUES (
    v_user_id,
    v_lounge_id,
    p_room_id,
    p_start_at,
    p_end_at,
    p_start_at::date,
    v_duration_minutes,
    p_start_at::time,
    'waiting'
  )
  ON CONFLICT (
    user_id,
    room_id,
    requested_date,
    duration_minutes,
    (COALESCE(preferred_start_time, '00:00:00'::time))
  )
  WHERE status IN ('active', 'waiting', 'notified')
  DO UPDATE SET
    updated_at = now(),
    expires_at = now() + interval '14 days'
  RETURNING * INTO v_waitlist;

  RETURN jsonb_build_object(
    'success', true,
    'waitlist_id', v_waitlist.id,
    'status', v_waitlist.status,
    'room_id', v_waitlist.room_id,
    'start_at', v_waitlist.start_at,
    'end_at', v_waitlist.end_at
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.join_booking_waitlist(uuid, timestamp without time zone, timestamp without time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_booking_waitlist(uuid, timestamp without time zone, timestamp without time zone) TO authenticated;

-- Maintain backwards compatibility for join_booking_waitlist with date/duration parameters
CREATE OR REPLACE FUNCTION public.join_booking_waitlist(
  p_room_id uuid,
  p_requested_date date,
  p_duration_minutes integer DEFAULT 60,
  p_preferred_start_time time without time zone DEFAULT NULL::time without time zone
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_time time without time zone := COALESCE(p_preferred_start_time, '18:00:00'::time);
  v_start_at timestamp without time zone := p_requested_date + v_time;
  v_end_at timestamp without time zone := v_start_at + make_interval(mins => COALESCE(p_duration_minutes, 60));
BEGIN
  RETURN public.join_booking_waitlist(p_room_id, v_start_at, v_end_at);
END;
$function$;

REVOKE ALL ON FUNCTION public.join_booking_waitlist(uuid, date, integer, time without time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_booking_waitlist(uuid, date, integer, time without time zone) TO authenticated;

-- ----------------------------------------------------------------------------
-- 6. RPC: cancel_booking_waitlist & cancel_my_booking_waitlist
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cancel_booking_waitlist(p_waitlist_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_entry public.booking_waitlist%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_entry
  FROM public.booking_waitlist
  WHERE id = p_waitlist_id
    AND user_id = v_user_id
    AND status IN ('waiting', 'active', 'notified')
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  UPDATE public.booking_waitlist
  SET status = 'cancelled', updated_at = now()
  WHERE id = v_entry.id;

  -- If entry was part of an intent batch, cancel all sibling waiting rooms
  IF v_entry.intent_id IS NOT NULL THEN
    UPDATE public.booking_waitlist
    SET status = 'cancelled', updated_at = now()
    WHERE intent_id = v_entry.intent_id
      AND user_id = v_user_id
      AND status IN ('waiting', 'active', 'notified');
  END IF;

  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.cancel_booking_waitlist(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_booking_waitlist(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.cancel_my_booking_waitlist(p_waitlist_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_success boolean;
BEGIN
  v_success := public.cancel_booking_waitlist(p_waitlist_id);
  IF NOT v_success THEN
    RAISE EXCEPTION 'Active waitlist request not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'waitlist_id', p_waitlist_id,
    'status', 'cancelled'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.cancel_my_booking_waitlist(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_my_booking_waitlist(uuid) TO authenticated;

-- ----------------------------------------------------------------------------
-- 7. RPC: claim_waitlist_slot (10-Minute Fair Claim Window Atomicity)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.claim_waitlist_slot(p_waitlist_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_entry public.booking_waitlist%ROWTYPE;
  v_room public.rooms%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_hold_token uuid := gen_random_uuid();
  v_hold_id uuid;
  v_expires_at timestamptz;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  SELECT w.* INTO v_entry
  FROM public.booking_waitlist w
  WHERE w.id = p_waitlist_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Waitlist request not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_entry.user_id <> v_user_id THEN
    RAISE EXCEPTION 'Unauthorized to claim this waitlist slot' USING ERRCODE = '42501';
  END IF;

  IF v_entry.status NOT IN ('notified', 'waiting', 'active') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'NOT_CLAIMABLE',
      'message', 'Waitlist request is not in a claimable state'
    );
  END IF;

  -- Enforce 10-minute fair claim window if entry was notified
  IF v_entry.status = 'notified' AND COALESCE(v_entry.claim_expires_at, v_entry.notified_at + interval '10 minutes') <= now() THEN
    UPDATE public.booking_waitlist
    SET status = 'expired', updated_at = now()
    WHERE id = v_entry.id;

    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'CLAIM_EXPIRED',
      'message', 'Claim window has expired'
    );
  END IF;

  -- Lock room
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_entry.room_id::text, 0)
  );

  SELECT r.* INTO v_room
  FROM public.rooms r
  WHERE r.id = v_entry.room_id;

  IF NOT FOUND OR COALESCE(v_room.is_active, true) IS FALSE
     OR COALESCE(v_room.status, 'available') = 'deleted' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'ROOM_UNAVAILABLE',
      'message', 'Room is currently unavailable'
    );
  END IF;

  -- Check for existing confirmed or active bookings
  IF EXISTS (
    SELECT 1 FROM public.bookings b
    WHERE b.room_id = v_entry.room_id
      AND b.status IN ('pending'::public.booking_status,
                       'upcoming'::public.booking_status,
                       'in_progress'::public.booking_status)
      AND (b.status <> 'pending'::public.booking_status
           OR b.expires_at IS NULL OR b.expires_at > now())
      AND b.booking_period && pg_catalog.tsrange(v_entry.start_at, v_entry.end_at, '[)')
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'SLOT_ALREADY_BOOKED',
      'message', 'Slot has already been reserved'
    );
  END IF;

  -- Check for competing holds by other users
  IF EXISTS (
    SELECT 1 FROM public.booking_holds h
    WHERE h.room_id = v_entry.room_id
      AND h.user_id <> v_user_id
      AND h.released_at IS NULL
      AND h.expires_at > now()
      AND pg_catalog.tsrange(h.start_at, h.end_at, '[)')
          && pg_catalog.tsrange(v_entry.start_at, v_entry.end_at, '[)')
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'SLOT_HELD_BY_ANOTHER_USER',
      'message', 'Slot is currently held by another customer'
    );
  END IF;

  -- Release any older active hold for this user
  UPDATE public.booking_holds
  SET released_at = now()
  WHERE user_id = v_user_id
    AND released_at IS NULL
    AND expires_at > now();

  -- Create 10-minute hold token
  v_expires_at := now() + interval '10 minutes';

  INSERT INTO public.booking_holds (
    hold_token,
    user_id,
    lounge_id,
    room_id,
    start_at,
    end_at,
    expires_at
  ) VALUES (
    v_hold_token,
    v_user_id,
    v_entry.lounge_id,
    v_entry.room_id,
    v_entry.start_at,
    v_entry.end_at,
    v_expires_at
  )
  RETURNING id INTO v_hold_id;

  -- Update waitlist entry to claimed
  UPDATE public.booking_waitlist
  SET status = 'claimed',
      hold_id = v_hold_id,
      updated_at = now()
  WHERE id = v_entry.id;

  -- Automatically cancel other waiting rooms for the same intent batch
  IF v_entry.intent_id IS NOT NULL THEN
    UPDATE public.booking_waitlist
    SET status = 'cancelled', updated_at = now()
    WHERE intent_id = v_entry.intent_id
      AND id <> v_entry.id
      AND status IN ('waiting', 'active', 'notified');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'waitlist_id', v_entry.id,
    'hold_token', v_hold_token,
    'hold_expires_at', v_expires_at,
    'room_id', v_entry.room_id,
    'lounge_id', v_entry.lounge_id,
    'start_at', v_entry.start_at,
    'end_at', v_entry.end_at
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.claim_waitlist_slot(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_waitlist_slot(uuid) TO authenticated;

-- ----------------------------------------------------------------------------
-- 8. Background Worker: process_booking_waitlist (FIFO & Fair Claim Window)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.process_booking_waitlist()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_entry public.booking_waitlist%ROWTYPE;
  v_sent integer := 0;
BEGIN
  -- 1. Housekeeping: expire stale waiting requests whose slot time has passed
  UPDATE public.booking_waitlist
  SET status = 'expired', updated_at = now()
  WHERE status IN ('waiting', 'active')
    AND start_at <= (now() AT TIME ZONE 'Africa/Cairo') + interval '10 minutes';

  -- 2. Housekeeping: expire notified entries whose 10-minute claim window elapsed
  UPDATE public.booking_waitlist
  SET status = 'expired', updated_at = now()
  WHERE status = 'notified'
    AND COALESCE(claim_expires_at, notified_at + interval '10 minutes') <= now();

  -- 3. FIFO Dispatch: loop over earliest waiting requests
  FOR v_entry IN
    SELECT w.*
    FROM public.booking_waitlist w
    WHERE w.status IN ('waiting', 'active')
      AND w.start_at > (now() AT TIME ZONE 'Africa/Cairo') + interval '10 minutes'
      AND NOT EXISTS (
        -- Protect fair claim window: skip slot if another user was notified and claim window is active
        SELECT 1 FROM public.booking_waitlist w2
        WHERE w2.room_id = w.room_id
          AND w2.id <> w.id
          AND w2.status = 'notified'
          AND COALESCE(w2.claim_expires_at, w2.notified_at + interval '10 minutes') > now()
          AND pg_catalog.tsrange(w2.start_at, w2.end_at, '[)')
              && pg_catalog.tsrange(w.start_at, w.end_at, '[)')
      )
    ORDER BY w.created_at ASC, w.id ASC
    LIMIT 50
    FOR UPDATE OF w SKIP LOCKED
  LOOP
    -- Advisory lock on room
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_entry.room_id::text, 0)
    );

    -- Verify room & lounge validity
    IF NOT EXISTS (
      SELECT 1 FROM public.rooms r
      JOIN public.lounges l ON l.id = r.lounge_id
      WHERE r.id = v_entry.room_id
        AND r.lounge_id = v_entry.lounge_id
        AND COALESCE(r.is_active, true) IS TRUE
        AND COALESCE(r.status, 'available') <> 'deleted'
        AND COALESCE(l.is_active, true) IS TRUE
    ) THEN
      CONTINUE;
    END IF;

    -- Check for conflicting bookings
    IF EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.room_id = v_entry.room_id
        AND b.status IN ('pending'::public.booking_status,
                         'upcoming'::public.booking_status,
                         'in_progress'::public.booking_status)
        AND (b.status <> 'pending'::public.booking_status
             OR b.expires_at IS NULL OR b.expires_at > now())
        AND b.booking_period && pg_catalog.tsrange(v_entry.start_at, v_entry.end_at, '[)')
    ) THEN
      CONTINUE;
    END IF;

    -- Check for conflicting active holds
    IF EXISTS (
      SELECT 1 FROM public.booking_holds h
      WHERE h.room_id = v_entry.room_id
        AND h.released_at IS NULL
        AND h.expires_at > now()
        AND pg_catalog.tsrange(h.start_at, h.end_at, '[)')
            && pg_catalog.tsrange(v_entry.start_at, v_entry.end_at, '[)')
    ) THEN
      CONTINUE;
    END IF;

    -- Intent de-duplication: do not send simultaneous notifications for same intent
    IF v_entry.intent_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.booking_waitlist s
      WHERE s.intent_id = v_entry.intent_id
        AND s.id <> v_entry.id
        AND s.status = 'notified'
        AND COALESCE(s.claim_expires_at, s.notified_at + interval '10 minutes') > now()
    ) THEN
      CONTINUE;
    END IF;

    -- Mark notified with 10-minute claim window
    UPDATE public.booking_waitlist
    SET status = 'notified',
        notified_at = now(),
        claim_expires_at = now() + interval '10 minutes',
        updated_at = now()
    WHERE id = v_entry.id;

    -- Dispatch localized notification
    INSERT INTO public.notifications (
      user_id,
      lounge_id,
      title,
      body,
      title_ar,
      title_en,
      body_ar,
      body_en,
      type,
      is_read,
      metadata,
      created_at
    ) VALUES (
      v_entry.user_id,
      v_entry.lounge_id,
      'الموعد الذي انتظرته أصبح متاحًا!',
      'أمامك 10 دقائق لتأكيد حجزك قبل إتاحة الموعد للآخرين.',
      'الموعد الذي انتظرته أصبح متاحًا!',
      'Your waitlisted slot is now available!',
      'أمامك 10 دقائق لتأكيد حجزك قبل إتاحة الموعد للآخرين.',
      'You have 10 minutes to claim your slot before it opens to others.',
      'booking',
      false,
      jsonb_build_object(
        'event', 'waitlist_available',
        'waitlist_id', v_entry.id,
        'intent_id', v_entry.intent_id,
        'lounge_id', v_entry.lounge_id,
        'room_id', v_entry.room_id,
        'start_at', v_entry.start_at,
        'end_at', v_entry.end_at,
        'claim_expires_at', now() + interval '10 minutes'
      ),
      now()
    );

    v_sent := v_sent + 1;
  END LOOP;

  RETURN v_sent;
END;
$function$;

REVOKE ALL ON FUNCTION public.process_booking_waitlist() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_booking_waitlist() TO service_role;

-- Schedule cron job if pg_cron is available
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('playspot-booking-waitlist')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'playspot-booking-waitlist');

    PERFORM cron.schedule(
      'playspot-booking-waitlist',
      '* * * * *',
      'SELECT public.process_booking_waitlist();'
    );
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 9. RPC: get_smart_rebook_slots (Smart Rebook Engine across 7-14 Days)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_smart_rebook_slots(
  p_past_booking_id uuid,
  p_days_ahead integer DEFAULT 14
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_past RECORD;
  v_duration_minutes integer := 60;
  v_target_time time without time zone;
  v_target_hour integer;
  v_target_minute integer;
  v_target_total_minutes integer;
  v_preferred_dow integer;
  v_days_ahead integer;
  v_today date := (now() AT TIME ZONE 'Africa/Cairo')::date;
  v_candidate_dates date[] := '{}'::date[];
  v_d date;
  v_i integer;
  v_recommendations jsonb := '[]'::jsonb;
  v_opening time without time zone;
  v_closing time without time zone;
  v_operational_date date;
  v_operational_start timestamp without time zone;
  v_operational_end timestamp without time zone;
  v_cursor timestamp without time zone;
  v_slot_end timestamp without time zone;
  v_slots_for_date text[];
  v_closest_slot text;
  v_min_diff integer;
  v_slot_time time without time zone;
  v_slot_total_minutes integer;
  v_diff integer;
  v_quote jsonb;
  v_closest_start timestamp without time zone;
  v_closest_end timestamp without time zone;
  v_rec_count integer := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  -- 1. Fetch past booking
  SELECT
    b.id,
    b.user_id,
    b.lounge_id,
    b.room_id,
    b.date,
    b.start_time,
    b.end_time,
    b.booking_period,
    b.duration_hours,
    b.open_time_billing_minutes,
    r.name AS room_name,
    r.name_ar AS room_name_ar,
    r.hourly_rate AS room_hourly_rate,
    l.name AS lounge_name,
    l.name_ar AS lounge_name_ar,
    l.opening_time,
    l.closing_time
  INTO v_past
  FROM public.bookings b
  JOIN public.rooms r ON r.id = b.room_id
  JOIN public.lounges l ON l.id = b.lounge_id
  WHERE b.id = p_past_booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_past.user_id <> v_user_id
     AND NOT public.is_super_admin()
     AND NOT public.is_lounge_member_or_admin(v_past.lounge_id) THEN
    RAISE EXCEPTION 'Unauthorized to view this booking' USING ERRCODE = '42501';
  END IF;

  -- 2. Determine target duration
  IF v_past.booking_period IS NOT NULL THEN
    v_duration_minutes := ROUND(EXTRACT(EPOCH FROM (upper(v_past.booking_period) - lower(v_past.booking_period))) / 60)::integer;
  ELSIF v_past.duration_hours IS NOT NULL THEN
    v_duration_minutes := ROUND(v_past.duration_hours * 60)::integer;
  ELSIF v_past.open_time_billing_minutes IS NOT NULL THEN
    v_duration_minutes := v_past.open_time_billing_minutes;
  ELSE
    v_duration_minutes := 60;
  END IF;
  v_duration_minutes := GREATEST(15, LEAST(1440, v_duration_minutes));

  -- 3. Determine target time
  v_target_time := COALESCE(
    v_past.start_time,
    CASE WHEN v_past.booking_period IS NOT NULL THEN lower(v_past.booking_period)::time ELSE NULL END,
    '18:00:00'::time
  );
  v_target_hour := EXTRACT(HOUR FROM v_target_time)::integer;
  v_target_minute := EXTRACT(MINUTE FROM v_target_time)::integer;
  v_target_total_minutes := v_target_hour * 60 + v_target_minute;

  -- 4. Determine preferred day-of-week (0 = Sunday, 1 = Monday, ..., 6 = Saturday)
  v_preferred_dow := EXTRACT(DOW FROM COALESCE(
    v_past.date,
    CASE WHEN v_past.booking_period IS NOT NULL THEN lower(v_past.booking_period)::date ELSE NULL END,
    v_today
  ))::integer;

  v_days_ahead := LEAST(GREATEST(COALESCE(p_days_ahead, 14), 1), 30);

  -- 5. Build prioritized candidate dates:
  -- First: Same weekday in next 7-14 days
  FOR v_i IN 1..v_days_ahead LOOP
    v_d := v_today + v_i;
    IF EXTRACT(DOW FROM v_d)::integer = v_preferred_dow THEN
      v_candidate_dates := array_append(v_candidate_dates, v_d);
    END IF;
  END LOOP;

  -- Second: Remaining calendar days in order
  FOR v_i IN 1..v_days_ahead LOOP
    v_d := v_today + v_i;
    IF NOT (v_d = ANY(v_candidate_dates)) THEN
      v_candidate_dates := array_append(v_candidate_dates, v_d);
    END IF;
  END LOOP;

  -- 6. Evaluate each candidate date for available slots
  v_opening := COALESCE(v_past.opening_time, '00:00:00'::time);
  v_closing := COALESCE(v_past.closing_time, '23:59:59'::time);

  FOREACH v_d IN ARRAY v_candidate_dates
  LOOP
    EXIT WHEN v_rec_count >= 5; -- Return up to 5 best recommended dates

    v_operational_date := v_d;
    IF v_closing <= v_opening THEN
      v_operational_start := v_operational_date + v_opening;
      v_operational_end := v_operational_date + interval '1 day' + v_closing;
    ELSE
      v_operational_start := v_operational_date + v_opening;
      v_operational_end := v_operational_date + v_closing;
    END IF;

    v_slots_for_date := '{}'::text[];
    v_cursor := v_operational_start;

    WHILE (v_cursor + make_interval(mins => v_duration_minutes)) <= v_operational_end LOOP
      v_slot_end := v_cursor + make_interval(mins => v_duration_minutes);

      -- Check future lead time (at least 10 minutes from now)
      IF v_cursor >= (now() AT TIME ZONE 'Africa/Cairo') + interval '10 minutes' THEN
        -- Check no conflicting booking
        IF NOT EXISTS (
          SELECT 1 FROM public.bookings b
          WHERE b.room_id = v_past.room_id
            AND b.status IN ('pending'::public.booking_status,
                             'upcoming'::public.booking_status,
                             'in_progress'::public.booking_status)
            AND (b.status <> 'pending'::public.booking_status
                 OR b.expires_at IS NULL OR b.expires_at > now())
            AND b.booking_period && pg_catalog.tsrange(v_cursor, v_slot_end, '[)')
        ) AND NOT EXISTS (
          -- Check no conflicting hold
          SELECT 1 FROM public.booking_holds h
          WHERE h.room_id = v_past.room_id
            AND h.released_at IS NULL
            AND h.expires_at > now()
            AND pg_catalog.tsrange(h.start_at, h.end_at, '[)')
                && pg_catalog.tsrange(v_cursor, v_slot_end, '[)')
        ) THEN
          v_slots_for_date := array_append(v_slots_for_date, to_char(v_cursor::time, 'HH24:MI:SS'));
        END IF;
      END IF;

      v_cursor := v_cursor + interval '30 minutes';
    END LOOP;

    -- If date has available slots, calculate closest slot and price quote
    IF cardinality(v_slots_for_date) > 0 THEN
      v_closest_slot := v_slots_for_date[1];
      v_min_diff := 999999;

      FOREACH v_closest_slot IN ARRAY v_slots_for_date
      LOOP
        v_slot_time := v_closest_slot::time;
        v_slot_total_minutes := (EXTRACT(HOUR FROM v_slot_time)::integer * 60) + EXTRACT(MINUTE FROM v_slot_time)::integer;
        v_diff := abs(v_slot_total_minutes - v_target_total_minutes) % 1440;
        IF v_diff > 720 THEN
          v_diff := 1440 - v_diff;
        END IF;

        IF v_diff < v_min_diff THEN
          v_min_diff := v_diff;
          v_closest_slot := to_char(v_slot_time, 'HH24:MI:SS');
        END IF;
      END LOOP;

      v_closest_start := v_d + v_closest_slot::time;
      v_closest_end := v_closest_start + make_interval(mins => v_duration_minutes);

      -- Authoritative server pricing quote
      BEGIN
        v_quote := public.quote_booking_price(
          v_past.room_id,
          v_closest_start,
          v_closest_end
        );
      EXCEPTION WHEN OTHERS THEN
        v_quote := jsonb_build_object(
          'base_price', ROUND((COALESCE(v_past.room_hourly_rate, 50) * (v_duration_minutes::numeric / 60.0)), 2),
          'final_total', ROUND((COALESCE(v_past.room_hourly_rate, 50) * (v_duration_minutes::numeric / 60.0)), 2),
          'currency', 'EGP'
        );
      END;

      v_recommendations := v_recommendations || jsonb_build_object(
        'date', to_char(v_d, 'YYYY-MM-DD'),
        'day_name', TRIM(to_char(v_d, 'Day')),
        'is_same_weekday', (EXTRACT(DOW FROM v_d)::integer = v_preferred_dow),
        'available_slots', to_jsonb(v_slots_for_date),
        'closest_slot', v_closest_slot,
        'quoted_price', v_quote
      );

      v_rec_count := v_rec_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'past_booking_id', p_past_booking_id,
    'room_id', v_past.room_id,
    'room_name', v_past.room_name,
    'room_name_ar', v_past.room_name_ar,
    'lounge_id', v_past.lounge_id,
    'lounge_name', v_past.lounge_name,
    'lounge_name_ar', v_past.lounge_name_ar,
    'target_time', to_char(v_target_time, 'HH24:MI:SS'),
    'duration_minutes', v_duration_minutes,
    'preferred_weekday', v_preferred_dow,
    'recommendations', v_recommendations
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_smart_rebook_slots(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_smart_rebook_slots(uuid, integer) TO authenticated;

COMMIT;
