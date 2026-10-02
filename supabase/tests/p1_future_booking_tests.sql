-- ============================================================================
-- P1 Future Booking Requests & Capacity Test Suite
-- ============================================================================
DO $test$
DECLARE
  v_test_lounge_id uuid := gen_random_uuid();
  v_test_room_id uuid := gen_random_uuid();
  v_test_user_id uuid := gen_random_uuid();
  v_test_shift_id uuid := gen_random_uuid();
  v_caps jsonb;
BEGIN
  -- --------------------------------------------------------------------------
  -- 1. Verify Schema Additions
  -- --------------------------------------------------------------------------
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'lounges' AND column_name = 'allow_future_bookings'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: lounges.allow_future_bookings missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'confirmation_status'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: bookings.confirmation_status missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'bookings_confirmation_status_check'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: bookings_confirmation_status_check constraint missing';
  END IF;

  -- --------------------------------------------------------------------------
  -- 2. Verify RPC Functions Existence
  -- --------------------------------------------------------------------------
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'get_lounge_booking_capabilities'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: get_lounge_booking_capabilities missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'get_booking_payment_destination'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: get_booking_payment_destination missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'confirm_future_booking_request'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: confirm_future_booking_request missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'check_and_alert_unconfirmed_future_bookings'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: check_and_alert_unconfirmed_future_bookings missing';
  END IF;

  -- --------------------------------------------------------------------------
  -- 3. Verify Privilege Hardening
  -- --------------------------------------------------------------------------
  IF pg_catalog.has_function_privilege('anon', 'public.get_booking_payment_destination(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'SECURITY FAILED: get_booking_payment_destination must not be executable by anon';
  END IF;

  IF pg_catalog.has_function_privilege('anon', 'public.confirm_future_booking_request(uuid, text, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'SECURITY FAILED: confirm_future_booking_request must not be executable by anon';
  END IF;

  IF pg_catalog.has_function_privilege('authenticated', 'public.check_and_alert_unconfirmed_future_bookings()', 'EXECUTE') THEN
    RAISE EXCEPTION 'SECURITY FAILED: check_and_alert_unconfirmed_future_bookings must be service_role only';
  END IF;

  RAISE NOTICE 'SUCCESS: All P1 Future Booking Requests & Capacity tests passed!';
END $test$;
