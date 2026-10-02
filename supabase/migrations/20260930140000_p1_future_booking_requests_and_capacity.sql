BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ============================================================================
-- 1. Lounge Policy Schema Additions for Future Booking Requests
-- ============================================================================
ALTER TABLE public.lounges
  ADD COLUMN IF NOT EXISTS allow_future_bookings boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS allow_request_without_shift boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS future_booking_max_days_advance integer NOT NULL DEFAULT 14,
  ADD COLUMN IF NOT EXISTS unconfirmed_alert_lead_minutes integer NOT NULL DEFAULT 60,
  ADD COLUMN IF NOT EXISTS require_deposit_for_future boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS future_deposit_percentage integer NOT NULL DEFAULT 20;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'lounges_future_booking_limits_check'
      AND conrelid = 'public.lounges'::regclass
  ) THEN
    ALTER TABLE public.lounges
      ADD CONSTRAINT lounges_future_booking_limits_check
      CHECK (
        future_booking_max_days_advance BETWEEN 1 AND 90
        AND unconfirmed_alert_lead_minutes BETWEEN 15 AND 1440
        AND future_deposit_percentage BETWEEN 0 AND 100
      );
  END IF;
END $$;

-- ============================================================================
-- 2. Bookings Table Schema Additions for Confirmation Status
-- ============================================================================
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS confirmation_status text NOT NULL DEFAULT 'confirmed',
  ADD COLUMN IF NOT EXISTS deposit_required boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS deposit_amount numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS deposit_paid boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS confirmation_sent_at timestamptz,
  ADD COLUMN IF NOT EXISTS contact_alert_sent_at timestamptz;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'bookings_confirmation_status_check'
      AND conrelid = 'public.bookings'::regclass
  ) THEN
    ALTER TABLE public.bookings
      ADD CONSTRAINT bookings_confirmation_status_check
      CHECK (confirmation_status IN (
        'confirmed',
        'pending_confirmation',
        'rejected_by_lounge',
        'expired_unconfirmed'
      ));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_bookings_pending_confirmation
  ON public.bookings (lounge_id, confirmation_status, date)
  WHERE confirmation_status = 'pending_confirmation';

-- ============================================================================
-- 3. Lounge Booking Capabilities RPC
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_lounge_booking_capabilities(
  p_lounge_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_lounge public.lounges%ROWTYPE;
  v_has_open_shift boolean;
BEGIN
  IF p_lounge_id IS NULL THEN
    RAISE EXCEPTION 'Lounge ID is required' USING ERRCODE = '22023';
  END IF;

  SELECT l.* INTO v_lounge FROM public.lounges l WHERE l.id = p_lounge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lounge not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.shifts s
    WHERE s.lounge_id = p_lounge_id
      AND s.status = 'open'
      AND s.closed_at IS NULL
  ) INTO v_has_open_shift;

  RETURN jsonb_build_object(
    'lounge_id', p_lounge_id,
    'is_open', COALESCE(v_lounge.is_open, false),
    'has_open_shift', v_has_open_shift,
    'allow_future_bookings', COALESCE(v_lounge.allow_future_bookings, true),
    'allow_request_without_shift', COALESCE(v_lounge.allow_request_without_shift, true),
    'future_booking_max_days_advance', COALESCE(v_lounge.future_booking_max_days_advance, 14),
    'unconfirmed_alert_lead_minutes', COALESCE(v_lounge.unconfirmed_alert_lead_minutes, 60),
    'require_deposit_for_future', COALESCE(v_lounge.require_deposit_for_future, false),
    'future_deposit_percentage', COALESCE(v_lounge.future_deposit_percentage, 20),
    'allow_open_time_sessions', COALESCE(v_lounge.allow_open_time_sessions, false),
    'allow_cash_payment', COALESCE(v_lounge.allow_cash_payment, true)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_lounge_booking_capabilities(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_lounge_booking_capabilities(uuid) TO authenticated, anon, service_role;

-- ============================================================================
-- 4. Protected Payment Destination RPC (Strict Gatekeeping)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_booking_payment_destination(
  p_booking_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_has_open_shift boolean;
  v_amount_due numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  SELECT b.* INTO v_booking FROM public.bookings b WHERE b.id = p_booking_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_booking.user_id IS DISTINCT FROM auth.uid()
     AND NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'billing_checkout') THEN
    RAISE EXCEPTION 'Not authorized to view payment details for this booking' USING ERRCODE = '42501';
  END IF;

  SELECT l.* INTO v_lounge FROM public.lounges l WHERE l.id = v_booking.lounge_id;

  SELECT EXISTS (
    SELECT 1 FROM public.shifts s
    WHERE s.lounge_id = v_booking.lounge_id
      AND s.status = 'open'
      AND s.closed_at IS NULL
  ) INTO v_has_open_shift;

  -- Security Gate: Cannot view payment destinations or submit receipts if unconfirmed or no shift
  IF v_booking.confirmation_status = 'pending_confirmation' OR v_has_open_shift IS FALSE THEN
    RETURN jsonb_build_object(
      'can_pay', false,
      'booking_id', p_booking_id,
      'confirmation_status', v_booking.confirmation_status,
      'has_open_shift', v_has_open_shift,
      'reason', 'SHIFT_NOT_OPEN_OR_NOT_CONFIRMED',
      'message_ar', 'لا يمكن تحويل الأموال أو إرسال الإيصال قبل فتح الشيفت وتأكيد الصالة للحجز',
      'message_en', 'Payment destination is withheld until the lounge opens a shift and confirms your booking request.'
    );
  END IF;

  IF v_booking.deposit_required AND NOT v_booking.deposit_paid THEN
    v_amount_due := v_booking.deposit_amount;
  ELSE
    v_amount_due := GREATEST(0, v_booking.total_price);
  END IF;

  RETURN jsonb_build_object(
    'can_pay', true,
    'booking_id', p_booking_id,
    'lounge_id', v_lounge.id,
    'lounge_name', v_lounge.name,
    'confirmation_status', v_booking.confirmation_status,
    'has_open_shift', true,
    'amount_due', v_amount_due,
    'deposit_required', v_booking.deposit_required,
    'instapay_account', v_lounge.instapay_account,
    'instapay_handle', v_lounge.instapay_handle,
    'vodafone_cash_number', v_lounge.vodafone_cash_number,
    'wallet_number', v_lounge.wallet_number
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_booking_payment_destination(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_booking_payment_destination(uuid) TO authenticated, service_role;

-- ============================================================================
-- 5. Updated acquire_booking_hold for Future Booking Requests
-- ============================================================================
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
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_room_ids uuid[];
  v_room_id uuid;
  v_room_count integer;
  v_found_count integer;
  v_lounge_count integer;
  v_lounge_id uuid;
  v_lounge public.lounges%ROWTYPE;
  v_has_open_shift boolean;
  v_is_future boolean;
  v_tz text := 'Africa/Cairo';
  v_local_now timestamp without time zone;
  v_hold_token uuid := gen_random_uuid();
  v_expires_at timestamptz;
  v_is_request_only boolean := false;
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

  -- Advisory lock on room IDs in deterministic order to prevent race conditions
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
    RAISE EXCEPTION 'All held rooms must belong to the same lounge' USING ERRCODE = '22023';
  END IF;

  SELECT l.* INTO v_lounge FROM public.lounges l WHERE l.id = v_lounge_id;

  IF COALESCE(v_lounge.is_active, false) IS FALSE THEN
    RAISE EXCEPTION 'Lounge is not active' USING ERRCODE = '55000';
  END IF;

  v_tz := COALESCE(NULLIF(btrim(v_lounge.timezone), ''), 'Africa/Cairo');
  v_local_now := now() AT TIME ZONE v_tz;

  -- Determine if this is a future request
  v_is_future := (p_start_at::date > v_local_now::date)
                 OR (p_start_at > (v_local_now + interval '2 hours'));

  SELECT EXISTS (
    SELECT 1 FROM public.shifts s
    WHERE s.lounge_id = v_lounge_id
      AND s.status = 'open'
      AND s.closed_at IS NULL
  ) INTO v_has_open_shift;

  -- Shift & Future booking policy evaluations
  IF NOT v_has_open_shift THEN
    IF NOT v_is_future THEN
      RAISE EXCEPTION 'Lounge currently has no active shift open for immediate walk-ins'
        USING ERRCODE = '55000';
    END IF;

    IF COALESCE(v_lounge.allow_future_bookings, true) IS FALSE THEN
      RAISE EXCEPTION 'Future bookings are disabled for this lounge' USING ERRCODE = '55000';
    END IF;

    IF COALESCE(v_lounge.allow_request_without_shift, true) IS FALSE THEN
      RAISE EXCEPTION 'Lounge does not accept requests while shifts are closed' USING ERRCODE = '55000';
    END IF;

    v_is_request_only := true;
  END IF;

  -- Check advance days limit
  IF v_is_future AND (p_start_at::date - v_local_now::date) > COALESCE(v_lounge.future_booking_max_days_advance, 14) THEN
    RAISE EXCEPTION 'Requested date exceeds lounge advance booking limit of % days',
      v_lounge.future_booking_max_days_advance USING ERRCODE = '22023';
  END IF;

  -- Check operating hours against operational day
  IF v_lounge.opening_time IS NOT NULL AND v_lounge.closing_time IS NOT NULL THEN
    IF v_lounge.closing_time <= v_lounge.opening_time THEN
      -- Overnight hours: valid if after opening or before closing
      IF NOT (p_start_at::time >= v_lounge.opening_time OR p_start_at::time < v_lounge.closing_time) THEN
        RAISE EXCEPTION 'Selected range is outside lounge working hours' USING ERRCODE = '22023';
      END IF;
    ELSE
      IF p_start_at::time < v_lounge.opening_time OR p_end_at::time > v_lounge.closing_time THEN
        RAISE EXCEPTION 'Selected range is outside lounge working hours' USING ERRCODE = '22023';
      END IF;
    END IF;
  END IF;

  -- Release existing user holds
  UPDATE public.booking_holds
  SET released_at = now()
  WHERE user_id = v_user_id
    AND released_at IS NULL
    AND expires_at > now();

  -- Conflict check against existing confirmed bookings
  IF EXISTS (
    SELECT 1
    FROM public.bookings AS b
    WHERE b.room_id = ANY(v_room_ids)
      AND b.booking_period IS NOT NULL
      AND b.status IN ('upcoming'::public.booking_status, 'in_progress'::public.booking_status)
      AND b.confirmation_status = 'confirmed'
      AND b.booking_period && pg_catalog.tsrange(p_start_at, p_end_at, '[)')
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'SLOT_OVERLAP_CONFLICT',
      'message', 'Slot is already booked'
    );
  END IF;

  -- Conflict check against other user active holds
  IF EXISTS (
    SELECT 1
    FROM public.booking_holds AS h
    WHERE h.room_id = ANY(v_room_ids)
      AND h.user_id IS DISTINCT FROM v_user_id
      AND h.released_at IS NULL
      AND h.expires_at > now()
      AND pg_catalog.tsrange(h.start_at, h.end_at, '[)') && pg_catalog.tsrange(p_start_at, p_end_at, '[)')
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'SLOT_HELD_BY_ANOTHER_USER',
      'message', 'Slot is temporarily held by another customer'
    );
  END IF;

  v_expires_at := now() + make_interval(mins => LEAST(GREATEST(p_hold_minutes, 3), 30));

  INSERT INTO public.booking_holds (
    hold_token, user_id, lounge_id, room_id, start_at, end_at, expires_at
  )
  SELECT
    v_hold_token, v_user_id, v_lounge_id, room_id, p_start_at, p_end_at, v_expires_at
  FROM unnest(v_room_ids) AS room_id;

  RETURN jsonb_build_object(
    'success', true,
    'hold_token', v_hold_token,
    'lounge_id', v_lounge_id,
    'room_ids', v_room_ids,
    'start_at', p_start_at,
    'end_at', p_end_at,
    'expires_at', v_expires_at,
    'is_request_only', v_is_request_only,
    'has_open_shift', v_has_open_shift
  );
END;
$$;

REVOKE ALL ON FUNCTION public.acquire_booking_hold(uuid[], timestamp without time zone, timestamp without time zone, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.acquire_booking_hold(uuid[], timestamp without time zone, timestamp without time zone, integer) TO authenticated, service_role;

-- ============================================================================
-- 6. Staff Confirmation & Rejection of Future Booking Requests
-- ============================================================================
CREATE OR REPLACE FUNCTION public.confirm_future_booking_request(
  p_booking_id uuid,
  p_action text,
  p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_shift_id uuid;
  v_action text := lower(btrim(COALESCE(p_action, '')));
  v_deposit_amount numeric := 0;
  v_deposit_required boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF v_action NOT IN ('confirm', 'reject') THEN
    RAISE EXCEPTION 'Invalid action: must be confirm or reject' USING ERRCODE = '22023';
  END IF;

  SELECT b.* INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'bookings_create')
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'billing_checkout') THEN
    RAISE EXCEPTION 'Not authorized to moderate booking requests for this lounge' USING ERRCODE = '42501';
  END IF;

  IF v_booking.confirmation_status <> 'pending_confirmation' THEN
    RAISE EXCEPTION 'Booking is already moderated with status: %', v_booking.confirmation_status
      USING ERRCODE = '55000';
  END IF;

  SELECT l.* INTO v_lounge FROM public.lounges l WHERE l.id = v_booking.lounge_id;

  IF v_action = 'confirm' THEN
    -- Verify active shift exists for the lounge
    SELECT s.id INTO v_shift_id
    FROM public.shifts s
    WHERE s.lounge_id = v_booking.lounge_id
      AND s.status = 'open'
      AND s.closed_at IS NULL
    ORDER BY s.opened_at DESC
    LIMIT 1
    FOR SHARE;

    IF v_shift_id IS NULL THEN
      RAISE EXCEPTION 'Cannot confirm request: An open shift is required in the lounge to accept bookings'
        USING ERRCODE = '55000';
    END IF;

    -- Verify slot is still available and not taken
    IF EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.room_id = v_booking.room_id
        AND b.id <> v_booking.id
        AND b.confirmation_status = 'confirmed'
        AND b.status IN ('upcoming'::public.booking_status, 'in_progress'::public.booking_status)
        AND b.booking_period && v_booking.booking_period
    ) THEN
      RAISE EXCEPTION 'Room slot conflict: another confirmed booking now occupies this time'
        USING ERRCODE = '55000';
    END IF;

    -- Check if deposit is required
    IF COALESCE(v_lounge.require_deposit_for_future, false) IS TRUE THEN
      v_deposit_required := true;
      v_deposit_amount := ROUND(v_booking.total_price * (COALESCE(v_lounge.future_deposit_percentage, 20) / 100.0), 2);
    END IF;

    UPDATE public.bookings
    SET confirmation_status = 'confirmed',
        status = 'upcoming'::public.booking_status,
        shift_id = v_shift_id,
        approved_at = now(),
        approved_by = auth.uid(),
        deposit_required = v_deposit_required,
        deposit_amount = v_deposit_amount,
        updated_at = now()
    WHERE id = p_booking_id;

    -- Notify customer
    IF v_booking.user_id IS NOT NULL THEN
      INSERT INTO public.notifications (
        user_id, title, title_ar, title_en, body, body_ar, body_en, type, metadata
      ) VALUES (
        v_booking.user_id,
        'Booking Confirmed',
        'تم تأكيد حجزك بنجاح! 🎉',
        'Your booking has been confirmed! 🎉',
        'وافقت الصالة على طلب حجزك للغرفة ' || v_booking.room_name || '. نتمنى لك وقتاً ممتعاً!',
        'وافقت الصالة على طلب حجزك للغرفة ' || v_booking.room_name || '. نتمنى لك وقتاً ممتعاً!',
        'The lounge confirmed your booking request for room ' || v_booking.room_name || '.',
        'booking_confirmed',
        jsonb_build_object(
          'booking_id', p_booking_id,
          'deposit_required', v_deposit_required,
          'deposit_amount', v_deposit_amount
        )
      );
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'confirmation_status', 'confirmed',
      'deposit_required', v_deposit_required,
      'deposit_amount', v_deposit_amount,
      'shift_id', v_shift_id
    );

  ELSE
    -- Reject
    UPDATE public.bookings
    SET confirmation_status = 'rejected_by_lounge',
        status = 'rejected'::public.booking_status,
        cancellation_reason = COALESCE(p_notes, 'اعتذرت الصالة عن قبول الحجز في هذا التوقيت'),
        cancelled_at = now(),
        cancelled_by = auth.uid(),
        updated_at = now()
    WHERE id = p_booking_id;

    IF v_booking.user_id IS NOT NULL THEN
      INSERT INTO public.notifications (
        user_id, title, title_ar, title_en, body, body_ar, body_en, type, metadata
      ) VALUES (
        v_booking.user_id,
        'Booking Request Rejected',
        'عذراً، لم تتمكن الصالة من قبول طلبك',
        'Booking request could not be accepted',
        COALESCE(p_notes, 'اعتذرت الصالة عن قبول الحجز في هذا التوقيت. يمكنك اختيار موعد آخر.'),
        COALESCE(p_notes, 'اعتذرت الصالة عن قبول الحجز في هذا التوقيت. يمكنك اختيار موعد آخر.'),
        'The lounge was unable to accept your request. Please choose an alternative slot.',
        'booking_rejected',
        jsonb_build_object('booking_id', p_booking_id)
      );
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'confirmation_status', 'rejected_by_lounge'
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_future_booking_request(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_future_booking_request(uuid, text, text) TO authenticated, service_role;

-- ============================================================================
-- 7. Update Legacy 30-Minute Pending Cancellation Function
--    Fix: Do NOT cancel requests awaiting lounge confirmation!
-- ============================================================================
CREATE OR REPLACE FUNCTION public.cancel_expired_pending_bookings()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_count integer := 0;
BEGIN
  -- Only cancel confirmed bookings that had payment timeouts or explicit expired_at
  UPDATE public.bookings
  SET status = 'cancelled'::booking_status,
      cancellation_reason = 'Payment deadline expired',
      updated_at = now()
  WHERE status = 'pending'::booking_status
    AND confirmation_status = 'confirmed'
    AND (
      (expires_at IS NOT NULL AND expires_at < now())
      OR (expires_at IS NULL AND created_at < now() - interval '30 minutes' AND payment_method <> 'cash')
    );

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ============================================================================
-- 8. Lead Time Alerts for Staff: check_and_alert_unconfirmed_future_bookings
-- ============================================================================
CREATE OR REPLACE FUNCTION public.check_and_alert_unconfirmed_future_bookings()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
DECLARE
  v_booking record;
  v_alerted_count integer := 0;
BEGIN
  FOR v_booking IN
    SELECT
      b.id,
      b.lounge_id,
      b.user_name,
      b.user_phone,
      b.room_name,
      b.date,
      b.start_time,
      l.unconfirmed_alert_lead_minutes,
      l.timezone
    FROM public.bookings b
    JOIN public.lounges l ON l.id = b.lounge_id
    WHERE b.confirmation_status = 'pending_confirmation'
      AND b.contact_alert_sent_at IS NULL
      AND (b.date + b.start_time) <= (
        (now() AT TIME ZONE COALESCE(NULLIF(btrim(l.timezone),''), 'Africa/Cairo'))
        + make_interval(mins => COALESCE(l.unconfirmed_alert_lead_minutes, 60))
      )
  LOOP
    -- Insert staff notification task
    INSERT INTO public.notifications (
      user_id, title, title_ar, title_en, body, body_ar, body_en, type, metadata
    )
    SELECT
      ls.user_id,
      'Action Required: Unconfirmed Booking Approaching',
      'تنبيه: حجز بانتظار التأكيد قرب موعده!',
      'Urgent: Unconfirmed booking request approaching start time!',
      'العميل ' || COALESCE(v_booking.user_name, 'زائر') || ' طلب حجز الغرفة ' || v_booking.room_name || ' والموعد اقترب. يرجى التواصل معه لتأكيد الحجز أو إلغائه.',
      'العميل ' || COALESCE(v_booking.user_name, 'زائر') || ' طلب حجز الغرفة ' || v_booking.room_name || ' والموعد اقترب. يرجى التواصل معه لتأكيد الحجز أو إلغائه.',
      'Customer ' || COALESCE(v_booking.user_name, 'Guest') || ' has an unconfirmed request for room ' || v_booking.room_name || '. Please contact them.',
      'staff_action_required',
      jsonb_build_object(
        'booking_id', v_booking.id,
        'user_phone', v_booking.user_phone,
        'action', 'contact_customer_for_confirmation'
      )
    FROM public.lounge_staff ls
    WHERE ls.lounge_id = v_booking.lounge_id
      AND ls.status = 'active';

    UPDATE public.bookings
    SET contact_alert_sent_at = now()
    WHERE id = v_booking.id;

    v_alerted_count := v_alerted_count + 1;
  END LOOP;

  RETURN v_alerted_count;
END;
$$;

REVOKE ALL ON FUNCTION public.check_and_alert_unconfirmed_future_bookings() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_and_alert_unconfirmed_future_bookings() TO service_role;

COMMIT;
