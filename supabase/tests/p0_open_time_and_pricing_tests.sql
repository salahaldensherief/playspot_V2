-- ============================================================================
-- P0 Open Time & Pricing Engine Test Suite
-- ============================================================================
DO $test$
DECLARE
  v_test_lounge_id uuid := gen_random_uuid();
  v_test_room_id uuid := gen_random_uuid();
  v_test_user_id uuid := gen_random_uuid();
  v_test_shift_id uuid := gen_random_uuid();
  v_test_booking_id uuid;
  v_quote jsonb;
  v_range jsonb;
BEGIN
  -- --------------------------------------------------------------------------
  -- 1. Verify Structure & Function Signatures
  -- --------------------------------------------------------------------------
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'rooms' AND column_name = 'open_time_enabled'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: rooms.open_time_enabled missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'open_time_pricing_snapshot'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: bookings.open_time_pricing_snapshot missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'start_open_time_session'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: start_open_time_session missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'quote_booking_price'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: quote_booking_price missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'get_room_slots_with_prices'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: get_room_slots_with_prices missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'get_lounge_price_range'
  ) THEN
    RAISE EXCEPTION 'TEST FAILED: get_lounge_price_range missing';
  END IF;

  -- --------------------------------------------------------------------------
  -- 2. Verify Privilege Hardening
  -- --------------------------------------------------------------------------
  IF pg_catalog.has_function_privilege('anon', 'public.start_open_time_session(uuid, text, text, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'SECURITY FAILED: start_open_time_session must not be executable by anon';
  END IF;

  IF pg_catalog.has_function_privilege('anon', 'public.quote_booking_price(uuid, date, time, time, text, integer, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'SECURITY FAILED: quote_booking_price must not be executable by anon';
  END IF;

  IF pg_catalog.has_function_privilege('anon', 'public.get_lounge_price_range(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'SECURITY FAILED: get_lounge_price_range must not be executable by anon';
  END IF;

  RAISE NOTICE 'SUCCESS: All P0 Open Time & Pricing Engine tests passed!';
END $test$;
